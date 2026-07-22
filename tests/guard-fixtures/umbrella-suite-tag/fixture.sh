#!/usr/bin/env bash
# Fixture de umbrella-suite-tag.
#
# Rotura: el tag de suite v<quantum> existe y su versions.yaml declara la
# versión correcta, pero el GITLINK de quark en el árbol del tag no es el
# workspace_pin que ese mismo versions.yaml certifica — el tag apunta a un
# estado que no es el certificado. Es la clase QM7-3 exacta (tag cortado sobre
# un árbol que aún iba a cambiar), que hasta la 8ª ronda solo cazaba un humano.
#
# El árbol doctorado es un repo git REAL construido aquí: versions.yaml y el
# script copiados del árbol al pin, gitlinks de nucleus/orbit con sus pins de
# verdad (leídos de los submódulos reales, para que SOLO la rotura introducida
# mate al guard) y el de quark envenenado a dddddddd…, todo COMMITEADO y
# tageado v<versión actual> — sin hardcodear la versión, para que la fixture
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

BAD_SHA=dddddddddddddddddddddddddddddddddddddddd

(
  cd "$TREE"
  git init --quiet
  git config user.email fixture@guard-of-guards.local
  git config user.name "guard-of-guards fixture"
  git add scripts/check_suite_tag.sh versions.yaml
  # Gitlinks: nucleus y orbit al pin REAL; quark envenenado (la rotura).
  git update-index --add --cacheinfo "160000,$BAD_SHA,quark"
  git update-index --add --cacheinfo "160000,$(git -C "$ROOT/nucleus" rev-parse HEAD),nucleus"
  git update-index --add --cacheinfo "160000,$(git -C "$ROOT/orbit" rev-parse HEAD),orbit"
  git commit --quiet -m "fixture: árbol del tag con gitlink de quark envenenado"
  git tag "v$version"
)

echo "workdir=$TREE"
echo "expect=el gitlink de quark es dddddddd"
