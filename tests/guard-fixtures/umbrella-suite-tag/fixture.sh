#!/usr/bin/env bash
# Fixture de umbrella-suite-tag.
#
# Rotura: un tag de suite RANCIO pero AUTOCONSISTENTE — la clase QM7-3 exacta
# (tag cortado antes del re-pin final, que congela un set viejo bajo el nombre
# correcto). Es la variante que verify_tag NO caza: el tag es coherente consigo
# mismo (su gitlink == su propio workspace_pin, su versión == su nombre, es
# ancestro de HEAD), así que los asserts 2-4 pasan; solo el assert 5 (captura de
# HEAD, MAQ-1/B.1) lo mata, y solo en modo certificación. Por eso la fixture
# corre el guard con QUANTUM_CERTIFYING=1 (línea env= del protocolo): fuera de
# ese modo el tag rancio pasa EXIT=0 — justo el agujero que B.1 cierra.
#
# Antes (8ª ronda) esta fixture cubría la variante INCONSISTENTE (gitlink != su
# propio pin), que verify_tag ya cazaba sin modo. Esa sigue viva en el código
# (verify_tag) y probada por los negativos del PR; esta fixture pasa a la
# variante más sutil, la que el guard "decía cazar" y solo cubría a medias.
#
# El árbol doctorado es un repo git REAL con DOS commits:
#   commit1 (el tag v<versión>): set RANCIO — gitlink de quark = OLD (aaaa…) y
#     su versions.yaml pina quark "aaaaaaaa" (AUTOCONSISTENTE: gitlink viejo +
#     su propio manifiesto viejo). nucleus/orbit al pin real.
#   commit2 (HEAD): set REAL re-pinado — gitlink de quark = el pin real y su
#     versions.yaml pina quark real. nucleus/orbit iguales.
# El tag es ancestro de HEAD y autoconsistente; solo difiere de HEAD en el set
# de quark — la deriva mínima que demuestra que el assert 5 muerde. La versión
# no se hardcodea (se lee del versions.yaml al pin), para que la fixture
# sobreviva a los re-pins. Sin remoto origin: el guard usa los tags locales
# (comportamiento documentado para árboles desconectados).
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_suite_tag.sh versions.yaml

version=$(awk '$1 == "quantum:" { v=$2; gsub(/"/, "", v); print v; exit }' "$TREE/versions.yaml")
if [[ -z "$version" ]]; then
  echo "fixture: no se pudo leer 'quantum:' de versions.yaml (¿cambió el formato?)" >&2
  exit 1
fi

# Gitlinks reales de los submódulos (para que SOLO la deriva de quark diferencie
# el tag de HEAD). quark rancio = 40×'a'; su pin autoconsistente = "aaaaaaaa".
QSHA=$(git -C "$ROOT/quark" rev-parse HEAD)
NSHA=$(git -C "$ROOT/nucleus" rev-parse HEAD)
OSHA=$(git -C "$ROOT/orbit" rev-parse HEAD)
OLDQ=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

# versions.yaml del tag (commit1): quark pin viejo, AUTOCONSISTENTE con OLDQ.
# Solo se toca la línea de quark DENTRO del bloque workspace_pins.
awk '
  $0 ~ "^workspace_pins:" { inb=1; print; next }
  /^[a-zA-Z_]/            { inb=0 }
  inb && $1 == "quark:"   { sub(/"[0-9a-fA-F]+"/, "\"aaaaaaaa\"") }
  { print }
' "$TREE/versions.yaml" > "$TREE/versions.stale.yaml"
fx_assert_doctored "$TREE/versions.stale.yaml" '^[[:space:]]*quark:[[:space:]]*"aaaaaaaa"'

(
  cd "$TREE"
  git init --quiet
  git config user.email fixture@guard-of-guards.local
  git config user.name "guard-of-guards fixture"

  # commit1 = el tag: versions.yaml rancio + gitlink de quark viejo (coherentes).
  cp versions.stale.yaml versions.yaml
  git add scripts/check_suite_tag.sh versions.yaml
  git update-index --add --cacheinfo "160000,$OLDQ,quark"
  git update-index --add --cacheinfo "160000,$NSHA,nucleus"
  git update-index --add --cacheinfo "160000,$OSHA,orbit"
  git commit --quiet -m "fixture: tag rancio autoconsistente (quark viejo)"
  git tag "v$version"

  # commit2 = HEAD: set real re-pinado (quark al pin de verdad).
  sed "s/\"aaaaaaaa\"/\"${QSHA:0:8}\"/" versions.stale.yaml > versions.yaml
  git add versions.yaml
  git update-index --add --cacheinfo "160000,$QSHA,quark"
  git commit --quiet -m "fixture: HEAD con el set real (re-pin)"
)

rm -f "$TREE/versions.stale.yaml"

echo "workdir=$TREE"
echo "expect=no apunta al set que HEAD certifica"
echo "env=QUANTUM_CERTIFYING=1"
