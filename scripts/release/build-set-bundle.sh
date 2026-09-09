#!/usr/bin/env bash
# build-set-bundle.sh — arma el paquete del set que la release del paraguas
# publica como activos verificables.
#
# EL PROBLEMA QUE CIERRA. El paraguas certifica un SET: un trío de versiones
# que compilan y pasan sus guards juntas. Los tres productos publican desde el
# arco A3 binarios con SBOM, firma sin clave y atestación de procedencia, así
# que un consumidor puede comprobar de dónde salió cada uno. Del set —la única
# afirmación que hace ESTE repositorio— no podía comprobar nada: el tren corta
# `git tag -a` (anotado, sin firmar) y lo que llega al otro lado es un tag y un
# fichero YAML dentro de un repo. Nada de eso resiste que alguien con permiso
# de escritura reescriba el manifiesto o mueva el tag.
#
# Lo que este script produce no es una garantía por sí solo: es el CONTENIDO
# sobre el que la release firma. La firma y la atestación las pone el runner
# (`.github/workflows/release-set.yml`), que es quien tiene el token OIDC.
#
# QUÉ ENTRA EN EL PAQUETE, y por qué cada pieza:
#   versions.yaml  el manifiesto TAL CUAL del árbol etiquetado — la afirmación.
#   require.txt    el bloque `require` pegable que emite print-requires.sh; es
#                  lo que el consumidor instala de verdad, con la ruta de cada
#                  módulo resuelta del árbol (no adivinada del nombre).
#   gitlinks.txt   el commit EXACTO de cada submódulo en ese tag. Es la pieza
#                  que hace el set reproducible: versions.yaml nombra TAGS, y
#                  un tag es un puntero móvil en otro repositorio; un commit
#                  de 40 hex no se puede reapuntar. Con estos tres SHA se
#                  reconstruye el árbol certificado aunque los tags cambien.
#   SET.md         el índice legible: qué set es, qué commit del paraguas, qué
#                  ficheros lleva y dónde está el procedimiento de verificación.
#   checksums.txt  SHA-256 de los cuatro. Es el ÚNICO fichero que se firma:
#                  cubre a los demás, igual que hacen los tres productos con el
#                  checksums.txt de GoReleaser, y así hay una firma y no cuatro.
#
# Idioma: los comentarios y los mensajes van en español (el paraguas), pero el
# CONTENIDO del paquete —SET.md— va en inglés: es superficie de consumidor, la
# misma frontera que pone el sitio publicado en inglés.
#
# POR QUÉ VIVE EN scripts/release/ Y NO EN scripts/. La aserción anti-fósil del
# registro de guards (guard_registry_selfcheck) recorre scripts/, scripts/ci/ y
# scripts/website/ de los cuatro repos y exige que todo *.sh que encuentre ahí
# esté registrado como guard o excluido con su porqué. Esto no es un guard: no
# emite veredicto, produce un artefacto. Moverlo a scripts/ pondría roja la lane
# de certificación hasta inventarle una fixture de fallo que no tiene sentido.
#
# Uso:
#   bash scripts/release/build-set-bundle.sh [<directorio-de-salida>]
# Sin argumento escribe en `dist/` (relativo a la raíz del paraguas). Se puede
# ejecutar a mano sobre cualquier árbol con los submódulos inicializados: no
# necesita red, ni token, ni runner.
set -euo pipefail
cd "$(dirname "$0")/../.."

OUT=${1:-dist}

# Los submódulos tienen que estar inicializados: print-requires.sh resuelve la
# ruta de cada módulo hermano contra el árbol pinado y se niega a emitir una
# línea cuyo go.mod no exista. Sin ellos el paquete saldría con un `require`
# incompleto y con pinta de correcto.
for repo in quark nucleus orbit; do
  if [ ! -f "$repo/go.mod" ]; then
    echo "build-set-bundle: falta $repo/go.mod — los submódulos no están inicializados (git submodule update --init)" >&2
    exit 1
  fi
done

ver=$(sed -nE 's/^quantum:[[:space:]]+"([^"]+)".*/\1/p' versions.yaml | head -1)
released=$(sed -nE 's/^released:[[:space:]]+([0-9-]+).*/\1/p' versions.yaml | head -1)
if [ -z "$ver" ]; then
  echo "build-set-bundle: versions.yaml no declara 'quantum:' — sin versión de set no hay paquete que armar" >&2
  exit 1
fi
commit=$(git rev-parse HEAD)

# El paquete afirma «umbrella tag: v$ver». Eso es cierto por construcción en el
# runner —la release corre EN el tag y check_suite_tag.sh --cierre lo exige
# antes de llegar aquí— pero no en una ejecución a mano sobre un HEAD mid-tren.
# Se avisa por stderr en vez de fallar: armar el paquete a mano para mirarlo es
# un uso legítimo, publicarlo con esa línea equivocada no.
tag_commit=$(git rev-parse -q --verify "refs/tags/v$ver^{commit}" 2>/dev/null || true)
if [ "$tag_commit" != "$commit" ]; then
  echo "AVISO: el tag v$ver no existe o no apunta a este commit (${commit:0:8}) — SET.md dirá «umbrella tag: v$ver» igualmente. En la release del paraguas esto no puede pasar (check_suite_tag.sh --cierre corre antes)." >&2
fi

rm -rf "$OUT"
mkdir -p "$OUT"

cp versions.yaml "$OUT/versions.yaml"
bash scripts/print-requires.sh > "$OUT/require.txt"

# Gitlinks: `git ls-tree` sobre HEAD da el commit con el que el árbol etiquetado
# fija cada submódulo. Se exigen los tres: un ls-tree que devuelva dos líneas
# (submódulo renombrado, árbol a medias) publicaría un set incompleto en verde.
git ls-tree HEAD quark nucleus orbit \
  | awk '$2 == "commit" { printf "%s  %s\n", $3, $4 }' \
  | sort -k2,2 > "$OUT/gitlinks.txt"
n=$(wc -l < "$OUT/gitlinks.txt" | tr -d ' ')
if [ "$n" -ne 3 ]; then
  echo "build-set-bundle: esperaba 3 gitlinks (quark, nucleus, orbit) y encontré $n — el árbol no es el del paraguas" >&2
  exit 1
fi

{
  echo "# Quantum $ver — certified set"
  echo
  echo "The package published with the umbrella tag \`v$ver\`. It records which"
  echo "three product versions were certified together, which commits of each"
  echo "product that means, and the \`require\` block that installs them."
  echo
  echo "| | |"
  echo "|---|---|"
  echo "| Suite version | $ver |"
  echo "| Certified on | ${released:-unknown} |"
  echo "| Umbrella tag | v$ver |"
  echo "| Umbrella commit | $commit |"
  echo "| Repository | https://github.com/jcsvwinston/quantum |"
  echo
  echo "## Files"
  echo
  echo "| File | What it is |"
  echo "|---|---|"
  echo "| \`versions.yaml\` | The manifest, verbatim from the tagged tree. |"
  echo "| \`require.txt\` | A pasteable \`go.mod\` require block for the whole set. |"
  echo "| \`gitlinks.txt\` | The commit of each product repository at this tag. |"
  echo "| \`SET.md\` | This file. |"
  echo "| \`checksums.txt\` | SHA-256 of the four files above. |"
  echo "| \`checksums.txt.sig\`, \`checksums.txt.pem\` | Keyless signature over \`checksums.txt\` and the short-lived certificate that made it. |"
  echo
  echo "## Gitlinks"
  echo
  echo '```'
  cat "$OUT/gitlinks.txt"
  echo '```'
  echo
  echo "\`versions.yaml\` names *tags*; these are *commits*. A tag is a movable"
  echo "pointer in another repository, a commit is not — so these three lines are"
  echo "what makes the set reproducible. To rebuild the exact tree that was"
  echo "certified:"
  echo
  echo '```bash'
  echo "git clone https://github.com/jcsvwinston/quantum"
  echo "cd quantum && git checkout v$ver && git submodule update --init"
  echo "git ls-tree HEAD quark nucleus orbit   # must match gitlinks.txt"
  echo '```'
  echo
  echo "## Verifying this package"
  echo
  echo "Signature and provenance are checked with \`cosign\` and \`gh attestation\`."
  echo "The commands, with the identity to require, are on"
  echo "<https://jcsvwinston.github.io/quantum/start/verifying-a-set>."
} > "$OUT/SET.md"

# checksums.txt se genera DENTRO del directorio de salida para que lleve los
# nombres desnudos: así `sha256sum -c checksums.txt` funciona en el directorio
# donde el consumidor descarga los activos, sin reescribir rutas.
sha256_de() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$@"
  else
    shasum -a 256 "$@"   # macOS: mismo formato «<hash>  <nombre>»
  fi
}
( cd "$OUT" && sha256_de SET.md gitlinks.txt require.txt versions.yaml > checksums.txt )

echo "OK: paquete del set Quantum $ver en $OUT/"
ls -1 "$OUT"
