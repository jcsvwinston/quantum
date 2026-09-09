# Deuda: dos guards del paraguas que esperan al próximo pin

El arco A3 deja dos guards escritos, verificados y **sin registrar** en
`scripts/lib/guard-registry.sh`, los dos por el mismo motivo: al pin de
1.29.0 fallan con razón, porque lo que comprueban entró en los productos
DESPUÉS del corte. Los dos se registran en el **mismo PR de set** que mueva
los gitlinks, y ese PR es el que lleva sus fixtures.

Mientras tanto están en `GUARD_SCAN_EXCLUDE` con su porqué, que es lo único
que impide que el escaneo anti-fósil los llame fósiles.

---

## A. `umbrella-deprecations`

**Cuándo se aplica: EN el PR del set que re-pine `quark` a un tag que
contenga las cinco marcas `// Deprecated:` reescritas y su
`docs/deprecations/`. Nunca antes.**

A diferencia de `quark-action-pins`, aquí el guard es del PARAGUAS y ya está
en el árbol: `scripts/check_deprecations.sh`, con su fixture en
`tests/guard-fixtures/umbrella-deprecations/`. Lo que falta no es el fichero,
es que el pin lo deje pasar. Con el pin de 1.29.0 (quark v1.12.0) el guard
falla cinco veces, con razón: la nota de `RowLevelSecurity` promete retirarse
en v1.0 y quark va por v1.12.0, y las cuatro de `quarkdriver/listener.go` no
dicen cuándo se retiran.

Comprobación antes de registrar, desde la raíz del paraguas y con el gitlink
de quark ya movido:

```
bash scripts/check_deprecations.sh   # tiene que salir EXIT=0
```

Si sale rojo, el pin todavía no trae el arreglo: no registrar y no forzar.

### A.1 Entrada del registro

Va con las demás del paraguas en `scripts/lib/guard-registry.sh`, junto a
`umbrella-actions-pinned`:

```
  # Toda deprecación escrita a mano en los tres productos nombra su recambio,
  # su aviso DEP-YYYY-NNN y una versión de retirada que todavía no ha salido
  # (docs/gobernanza/POLITICA_DEPRECACION.md §5). Entra al set con la release
  # de quark que trae docs/deprecations/ y las marcas reescritas.
  "umbrella-deprecations|.|bash scripts/check_deprecations.sh"
```

### A.2 La fixture

Va en `tests/guard-fixtures/umbrella-deprecations/fixture.sh`, **en el mismo
commit que la entrada del registro y no antes**: `guard-of-guards` falla con
una fixture huérfana —una fixture cuyo guard no está registrado— igual que
con un guard sin fixture. Verificada a mano el 2026-09-09 sobre el pin de
1.29.0: las dos `expect=` casan con la salida del guard sobre el árbol
doctorado.

```bash
#!/usr/bin/env bash
# Fixture de umbrella-deprecations. Dos roturas, las dos formas en que una
# nota de deprecación deja de ser una promesa:
#
# (A) la nota no dice cuándo se retira el símbolo. Es el estado por defecto —
#     `// Deprecated: use X.` es lo que sale de escribirlo sin pensar en el
#     calendario—, y es el que convierte la deprecación en una etiqueta
#     permanente: nadie puede planificar contra ella y nadie tiene motivo
#     para quitarla.
#
# (B) la nota promete una versión que YA está publicada. Es peor que (A)
#     porque parece un compromiso: el lector entiende que el símbolo ya no
#     debería existir, y existe. Lo tenía quark de verdad —el alias
#     `RowLevelSecurity` prometía retirarse «in v1.0» con quark en v1.12.0—,
#     que es por lo que este guard se escribió.
#
# El árbol de la fixture parte del estado CONFORME (las notas reales
# reescritas a la forma que exige la política) para que el EXIT!=0 sea
# atribuible a la rotura y no al punto de partida.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

# El guard lee el pin de cada producto del manifiesto y exige que los tres
# submódulos existan, así que los tres viajan en la copia. De nucleus y orbit
# basta un fichero: lo que se comprueba es que el guard los recorre sin
# tropezar, no lo que contienen (ninguno tiene deprecaciones a mano).
fx_copy "$ROOT" "$TREE" versions.yaml scripts/check_deprecations.sh
fx_copy "$ROOT" "$TREE" quark/quarkdriver/listener.go quark/tenant_router.go
mkdir -p "$TREE/nucleus" "$TREE/orbit"
: > "$TREE/nucleus/vacio.go"
: > "$TREE/orbit/vacio.go"

python3 - "$TREE/quark/quarkdriver/listener.go" "$TREE/quark/tenant_router.go" <<'PY'
import re, sys

listener, tenant = sys.argv[1], sys.argv[2]

# Punto de partida CONFORME: toda nota de listener.go gana su cláusula de
# retirada con una versión por delante del pin y una fecha lejana.
s = open(listener, encoding='utf-8').read()
s, n = re.subn(
    r'(// Deprecated: [^\n]*(?:\n//[^\n]*)*?)\.\n',
    r'\1. Scheduled for removal in v1.99.0, no earlier than 2099-01-01.\n',
    s)
assert n >= 4, f'la fixture esperaba al menos 4 notas en listener.go, encontró {n}'

# (A) UNA de ellas pierde la cláusula: la nota vuelve a no decir cuándo.
s, n = re.subn(
    r'// Deprecated: use LookupListenerFactory\. Scheduled for removal in v1\.99\.0, no earlier than 2099-01-01\.',
    '// Deprecated: use LookupListenerFactory.',
    s, count=1)
assert n == 1, 'la fixture no encontró la nota de LookupListenerFactory'
open(listener, 'w', encoding='utf-8').write(s)

# (B) la nota del alias promete una versión que el manifiesto ya pina como
# publicada (quark v1.12.0 > v1.0.0).
t = open(tenant, encoding='utf-8').read()
t, n = re.subn(
    r'scheduled for\n// removal in v1\.0\.',
    'scheduled for\n// removal in v1.0.0, no earlier than 2020-01-01.',
    t, count=1)
assert n == 1, 'la fixture no encontró la nota de RowLevelSecurity'
open(tenant, 'w', encoding='utf-8').write(t)
PY

fx_assert_doctored "$TREE/quark/quarkdriver/listener.go" '// Deprecated: use LookupListenerFactory\.$'
fx_assert_doctored "$TREE/quark/tenant_router.go" 'removal in v1\.0\.0, no earlier than 2020-01-01\.'

echo "workdir=$TREE"
echo "expect=listener\.go:[0-9]+ — la deprecación no dice cuándo se retira"
echo "expect=tenant_router\.go:[0-9]+ — promete retirarse en v1\.0\.0 y quark ya va por v1\.12\.0"
```

### A.3 Lo demás que se rellena en ese mismo PR

- El §6 de `docs/gobernanza/POLITICA_DEPRECACION.md` ya nombra los dos avisos
  reales (`DEP-2026-001` y `DEP-2026-002`, de quark#373); si quark abre alguno
  más antes del corte, se añade su fila.
- La fixture no necesita tocarse: parte del estado conforme y lo rompe ella
  misma, así que sigue valiendo con el pin nuevo.

---

## B. `umbrella-supply-chain`

**Cuándo se aplica: EN el PR del set que re-pine los TRES productos por
encima de sus PRs de cadena de suministro.** Los tres ya están en `main`
(orbit#445 fusionado el 2026-09-09); lo que falta es sólo el corte.

Al pin de 1.29.0 el guard falla siete veces y todas son ciertas: quark y
orbit no tenían `.goreleaser.yaml` cuando se cortó, y el de nucleus no
llevaba `sboms:` ni `signs:`. La mitad del PARAGUAS ya sale en verde: con
quantum#166 fusionado, `release-set.yml` firma el fichero de sumas y atesta
la procedencia, y el guard lo comprueba en el árbol de trabajo (el paraguas
no está pinado a sí mismo).

Comprobación antes de registrar, con los tres gitlinks ya movidos:

```
bash scripts/check_supply_chain.sh   # tiene que salir EXIT=0
```

Verificado el 2026-09-09 contra los tres `main` reales (`git archive` de
`origin/main` de cada repo sobre una copia del guard) más el
`release-set.yml` del paraguas: **EXIT=0**, y rojo al comentar el permiso
`attestations: write` del paraguas.

### B.1 Entrada del registro

Va con las demás del paraguas en `scripts/lib/guard-registry.sh`, junto a
`umbrella-actions-pinned`:

```
  # Los tres productos siguen publicando con SBOM, firma sin clave y
  # atestación de procedencia, y el paraguas sigue publicando el set firmado
  # y atestado, todos con los permisos que esas dos cosas necesitan (QM-14).
  # Un release sin firma sale VERDE: por eso esto se comprueba en el árbol y
  # no en la corrida.
  "umbrella-supply-chain|.|bash scripts/check_supply_chain.sh"
```

### B.2 La fixture

Va en `tests/guard-fixtures/umbrella-supply-chain/fixture.sh`, en el mismo
commit que la entrada del registro. Verificada el 2026-09-09 sobre el árbol
descrito arriba: dos fallos, uno por cada `expect=`.

```bash
#!/usr/bin/env bash
# Fixture de umbrella-supply-chain. Dos roturas, las dos formas en que la
# cadena de suministro se desarma sin que ninguna corrida se ponga roja:
#
# (A) desaparece el bloque `signs:` de la config de GoReleaser. Es un borrado
#     de cuatro líneas: la release sigue saliendo, con sus binarios y su
#     checksum, y lo único que falta es la firma que nadie mira hasta que la
#     necesita.
#
# (B) el workflow de release conserva el paso de atestación y pierde el
#     permiso `attestations: write`. Es la variante cara: el paso existe, así
#     que la config parece completa, y falla en la corrida del tag — cuando ya
#     no hay marcha atrás sin retirar el tag.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_supply_chain.sh
for repo in quark nucleus orbit; do
  fx_copy "$ROOT" "$TREE" "$repo/.goreleaser.yaml" "$repo/.github/workflows/release.yml"
done

# (A) quark se queda sin firma.
python3 - "$TREE/quark/.goreleaser.yaml" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s, n = re.subn(r'(?m)^signs:', '# signs:', s, count=1)
assert n == 1, 'la fixture no encontró el bloque signs: de quark'
open(p, 'w', encoding='utf-8').write(s)
PY

# (B) nucleus conserva el paso y pierde el permiso.
python3 - "$TREE/nucleus/.github/workflows/release.yml" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s, n = re.subn(r'(?m)^([ \t]*)attestations: write[ \t]*$', r'\1# attestations: write', s, count=1)
assert n == 1, 'la fixture no encontró el permiso attestations: write de nucleus'
assert 'actions/attest-build-provenance' in s, 'la fixture quiere el paso INTACTO: es lo que hace creíble la rotura'
open(p, 'w', encoding='utf-8').write(s)
PY

fx_assert_doctored "$TREE/quark/.goreleaser.yaml" '^# signs:'
fx_assert_doctored "$TREE/nucleus/.github/workflows/release.yml" '# attestations: write'

echo "workdir=$TREE"
echo "expect=quark/\.goreleaser\.yaml no declara el bloque .signs:"
echo "expect=nucleus/\.github/workflows/release\.yml no pide .attestations: write"
```

---

## C. `nucleus-action-pins`

**Cuándo se aplica: EN el PR del set que re-pine `nucleus` a un tag que
contenga `scripts/ci/check_action_pins.sh` (nucleus#499, fusionado el
2026-09-09).**

Mismo mecanismo exacto que el de quark
(`docs/handoff/deuda-registro-quark-action-pins.md`): el escaneo anti-fósil
recorre `scripts/ci/` de los tres productos AL PIN, así que con el pin nuevo y
sin registrar muere `suite-integral` con «guard sin registrar», y con el pin
viejo la fixture no encuentra el guard y muere `guard-of-guards`. Los dos
ficheros van en el mismo commit que mueve el gitlink de nucleus.

Nucleus lleva además, en el mismo PR, un paso de `actionlint` fijado en
`v1.7.12` dentro del job `Test And Smoke`, que el agregador `CI Required Gate`
sí cubre. Eso NO se registra como guard del paraguas: es un linter del
producto, de la misma familia que los arneses que ya están en
`GUARD_SCAN_EXCLUDE`, y no tiene veredicto sobre el árbol del set.

### C.1 Entrada del registro

Va junto a las demás de nucleus en `scripts/lib/guard-registry.sh`:

```
  # Toda Action de GitHub que corre el CI de nucleus está fijada por SHA de
  # commit, con su tag escrito al lado (el comentario es lo que Dependabot
  # reescribe y lo que hace legible el pin). Entra al set con la release de
  # nucleus que traiga scripts/ci/check_action_pins.sh.
  "nucleus-action-pins|nucleus|bash scripts/ci/check_action_pins.sh"
```

### C.2 La fixture

`tests/guard-fixtures/nucleus-action-pins/fixture.sh`. Verificada el
2026-09-09 contra el guard real de `origin/main`: revierte el primer `uses:`
fijado a su tag móvil y el guard muere con el mensaje que declara el
`expect=`.

```bash
#!/usr/bin/env bash
# Fixture de nucleus-action-pins.
#
# Rotura: una referencia `uses:` del CI de nucleus vuelve a su TAG móvil — el
# SHA fijado se sustituye por la etiqueta que llevaba al lado, que es
# exactamente lo que el guard existe para impedir (un tag lo mueve su dueño,
# bajo un job que ya tiene este repositorio checkouteado). El guard debe morir
# nombrando el tag.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT/nucleus" "$TREE" \
  scripts/ci/check_action_pins.sh \
  .github/workflows

awk 'BEGIN{done=0}
{
  if (!done && $0 ~ /uses:[ \t]*actions\/checkout@/) {
    sub(/actions\/checkout@.*/, "actions/checkout@v5")
    done=1
  }
  print
}' "$TREE/.github/workflows/ci.yml" > "$TREE/.github/workflows/ci.yml.tmp"
mv "$TREE/.github/workflows/ci.yml.tmp" "$TREE/.github/workflows/ci.yml"
fx_assert_doctored "$TREE/.github/workflows/ci.yml" 'uses:[ \t]*actions/checkout@v5$'

echo "workdir=$TREE"
echo "expect=is pinned to 'v5', which is a moving tag"
```

---

## D. `orbit-action-pins`

**Cuándo se aplica: EN el PR del set que re-pine `orbit` a un tag que
contenga `scripts/ci/check_action_pins.sh` (orbit#447).**

Con esto los tres productos tienen el mismo guard y el paraguas los tres
registrados, que es lo que cierra el frente de pines del arco A3: hasta hoy
sólo quark lo tenía, y en los otros dos la disciplina se sostenía por
revisión.

Orbit es el caso con más trabajo por debajo: sus acciones no estaban barridas,
así que el PR además las fija. El guard, como en los hermanos, muerde por las
dos mitades — el tag móvil y el SHA sin comentario — y orbit lo cuelga de un
job que el agregador `CI Required Gate` (orbit#446) cubre.

### D.1 Entrada del registro

```
  # Toda Action de GitHub que corre el CI de orbit está fijada por SHA de
  # commit, con su tag escrito al lado. Entra al set con la release de orbit
  # que traiga scripts/ci/check_action_pins.sh.
  "orbit-action-pins|orbit|bash scripts/ci/check_action_pins.sh"
```

### D.2 La fixture

`tests/guard-fixtures/orbit-action-pins/fixture.sh`, idéntica a la de nucleus
salvo el repositorio. El mensaje de muerte es el mismo en los tres guards,
comprobado en el diff de orbit#447 y ejecutado contra el de nucleus.

```bash
#!/usr/bin/env bash
# Fixture de orbit-action-pins.
#
# Rotura: una referencia `uses:` del CI de orbit vuelve a su TAG móvil. Mismo
# razonamiento que en quark y nucleus: un tag lo mueve su dueño, bajo un job
# que ya tiene este repositorio checkouteado.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT/orbit" "$TREE" \
  scripts/ci/check_action_pins.sh \
  .github/workflows

awk 'BEGIN{done=0}
{
  if (!done && $0 ~ /uses:[ \t]*actions\/checkout@/) {
    sub(/actions\/checkout@.*/, "actions/checkout@v5")
    done=1
  }
  print
}' "$TREE/.github/workflows/ci.yml" > "$TREE/.github/workflows/ci.yml.tmp"
mv "$TREE/.github/workflows/ci.yml.tmp" "$TREE/.github/workflows/ci.yml"
fx_assert_doctored "$TREE/.github/workflows/ci.yml" 'uses:[ \t]*actions/checkout@v5$'

echo "workdir=$TREE"
echo "expect=is pinned to 'v5', which is a moving tag"
```

---

## Resumen: qué lleva el PR de set que cierre A3

Cuatro guards nuevos en `scripts/lib/guard-registry.sh` y sus cuatro fixtures,
más el de quark que ya estaba anotado aparte:

| Guard | Directorio | Desbloqueado por |
|---|---|---|
| `umbrella-deprecations` | `.` | quark#373 |
| `umbrella-supply-chain` | `.` | quark, nucleus y orbit#445 |
| `quark-action-pins` | `quark` | quark#364 (ver `deuda-registro-quark-action-pins.md`) |
| `nucleus-action-pins` | `nucleus` | nucleus#499 |
| `orbit-action-pins` | `orbit` | orbit#447 |

Y dos líneas que salen de `GUARD_SCAN_EXCLUDE`: `scripts/check_deprecations.sh`
y `scripts/check_supply_chain.sh`. El registro pasa de 41 a 46 guards.

## Lo que el propietario decidió el 2026-09-09, y que el mismo PR de set anota

1. **Política de soporte**: aprobados S1, S2 y S4–S8. **S3 (la LTS) no**, y no
   se declara hasta que exista el carril de mantenimiento del §7.1. La cabecera
   del documento ya lo dice.
2. **Política de deprecación**: aprobadas D1, D2 y D3 tal cual. El guard
   `umbrella-deprecations` entra en este mismo PR, que es lo que la pone en
   vigor.
3. **QK-14**: **se trocea** `cmd/quark` en su propio módulo, entero y como
   manda `quark/docs/adr/0024-cli-en-modulo-propio.md` (CLI, `examples/superapp`,
   `internal/driverclassify` y las suites por motor). QK-14 se cierra en el
   registro **cuando ese troceado llegue al pin**, no antes.

### Una trampa de nombre que este PR tiene que resolver a conciencia

`manifest-guard.sh` descubre los módulos del árbol y deriva la clave del
manifiesto como el **último segmento de la ruta** (`key=${mod##*/}`). Para
`cmd/quark` esa clave es `quark`, así que el bloque queda:

```yaml
modules:
  quark:   "v1.13.0"      # el pilar
quark_modules:
  quark:   "v0.1.0"       # ← el CLI, no el pilar
```

Mecánicamente no choca —son secciones distintas y `yaml_value` busca dentro de
la suya—, pero se lee mal y es exactamente la clase de ambigüedad que cuesta un
tren. Al añadir la entrada, dejar el comentario al lado. Si se prefiere
resolverlo de raíz, la vía es que `check_sibling_modules` use la ruta completa
como clave para los módulos anidados, y eso renombra también las claves de los
`drivers/*` de quark y de los `providers/*` y `exporters/*` de nucleus: es un
cambio aparte, no del PR de set.
