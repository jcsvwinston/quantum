# Deuda: registrar `umbrella-release-assets` cuando nucleus vuelva a publicar

**Cuándo se aplica: EN el PR de set que re-pine `nucleus` a un tag cuya release
tenga activos.** Hoy no, y el porqué está en el propio guard.

## Por qué espera

`scripts/check_release_assets.sh` está escrito y verificado: corrido contra el
set 1.30.0 caza exactamente el fallo que lo motivó.

```
OK:   quark v1.13.0 — 15 activo(s), con checksums.txt firmado y su certificado
FAIL: nucleus v1.26.0 — la release existe y NO tiene ningún activo.
OK:   orbit v1.9.4 — 15 activo(s), con checksums.txt firmado y su certificado
OK:   quantum v1.30.0 — 7 activo(s), con checksums.txt firmado y su certificado
```

Ese FAIL es cierto. Un bump había subido `cosign-installer` a v4, cosign v3
cambió `sign-blob` —escribe un bundle y `--bundle` no tiene valor por defecto—
y la firma murió en una ruta vacía: nucleus v1.26.0 salió con cero activos y el
paquete del set tampoco. Los 47 guards pasaron, porque leen el ÁRBOL, que
seguía declarando `sboms:` y `signs:`.

El propietario decidió el 2026-09-10 que nucleus **recupera activos en su
release siguiente** en vez de re-cortar (su tag no puede moverse: el set pina
su commit). Registrar el guard ahora pondría roja la certificación por un hecho
ya decidido, y un guard rojo por decisión es un guard que se aprende a ignorar.

Mientras tanto está en `GUARD_SCAN_EXCLUDE` con ese porqué, que es lo único que
impide que el escaneo anti-fósil lo llame fósil.

**Comprobación antes de registrar**, con el gitlink de nucleus ya movido:

```
bash scripts/check_release_assets.sh   # tiene que salir EXIT=0
```

Si sale rojo, el pin todavía no trae una release con activos: no registrar y no
forzar.

## 1. Entrada del registro

Va con las demás del paraguas en `scripts/lib/guard-registry.sh`, junto a
`umbrella-supply-chain`:

```
  # La release del tag que el set pina publicó DE VERDAD lo que el árbol
  # promete firmar: checksums.txt, su firma y su certificado, en los tres
  # pilares y en el paraguas. Es el complemento de umbrella-supply-chain, que
  # mira la configuración: aquella dice que se promete firmar, esta que la
  # corrida cumplió. Único guard del registro que pregunta a la red; si no
  # puede preguntar, FALLA.
  "umbrella-release-assets|.|bash scripts/check_release_assets.sh"
```

Y su fila en la tabla de `docs/AUDITORIA_CONTINUA.md`:

```
| umbrella-release-assets | . | `bash scripts/check_release_assets.sh` | Una release del set que no publica su fichero de sumas firmado: la firma falló y la release salió igual. |
```

## 2. Fixture

Va en `tests/guard-fixtures/umbrella-release-assets/fixture.sh`, **en el mismo
commit que la entrada del registro y no antes**: `guard-of-guards` falla con
una fixture huérfana igual que con un guard sin fixture. Verificada el
2026-09-10 contra el guard real — sobre la release doctorada muere con la causa
que declara.

```bash
#!/usr/bin/env bash
# Fixture de umbrella-release-assets.
#
# Rotura: una release del set publica sus archivos y su fichero de sumas, y se
# queda SIN la firma. Es la forma en que la cadena de suministro se desarma sin
# que nada se ponga rojo: los binarios están, el checksums.txt está, y lo único
# que falta es lo que nadie mira hasta que lo necesita.
#
# Este guard es el único del registro que pregunta a la red, así que la fixture
# no doctora un árbol: sustituye el CLIENTE. QUANTUM_GH apunta a un `gh` de
# mentira que contesta con una release doctorada, y así la rotura se prueba sin
# depender de lo que GitHub esté sirviendo hoy.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_release_assets.sh versions.yaml

# El `gh` de mentira: para quark, nucleus y el paraguas contesta una release
# completa; para orbit, la misma sin `checksums.txt.sig`. Una sola rotura, en
# un solo repositorio, que es como ocurre de verdad.
mkdir -p "$TREE/bin"
cat > "$TREE/bin/gh" <<'GHEOF'
#!/usr/bin/env bash
# gh de mentira para la fixture: sólo entiende la llamada que el guard hace.
repo=""
for a in "$@"; do
  case "$prev" in -R) repo="$a" ;; esac
  prev="$a"
done
completa=$'checksums.txt\nchecksums.txt.pem\nchecksums.txt.sig\nalgo_1.0.0_linux_amd64.tar.gz'
case "$repo" in
  */orbit) printf '%s\n' "checksums.txt" "checksums.txt.pem" "algo_1.0.0_linux_amd64.tar.gz" ;;
  *)       printf '%s\n' "$completa" ;;
esac
GHEOF
chmod +x "$TREE/bin/gh"

fx_assert_doctored "$TREE/bin/gh" 'checksums.txt.pem'

echo "workdir=$TREE"
echo "env=QUANTUM_GH=$TREE/bin/gh"
echo "expect=orbit .* la release no publica: checksums.txt.sig"
```

## 3. Lo que este guard NO cubre

Dicho aquí para que no se lea de más:

- **No verifica la firma criptográficamente.** Eso es `cosign verify-blob`, que
  exige descargar los activos; este guard sólo afirma que están.
- **No mira la atestación de procedencia**, que no es un activo de la release:
  vive en la API de atestaciones. Comprobarla es `gh attestation verify`.
- **No sustituye a `check_supply_chain.sh`.** Aquel dice que la configuración
  promete firmar; este, que la corrida cumplió. Hacen falta los dos: sin el
  primero, alguien borra cuatro líneas de YAML y nadie se entera hasta el corte
  siguiente.
