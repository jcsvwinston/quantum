#!/usr/bin/env bash
# Fixture de orbit-internal-pins.
#
# Rotura: server/go.mod pina el módulo hermano agent a v0.0.9 — un pin
# envejecido respecto al último tag publicado de agent. Es la clase OR5-1:
# server/v0.8.1 llegó a tag pinando el agent SIN el fix que su propio test de
# regresión comprobaba. El guard debe morir con "agent pinned at v0.0.9,
# latest published tag is v<latest>".
#
# El árbol es un clon --shared del submódulo al pin (worktree completo — el
# guard lee los go.mod de los 6 módulos — y con los tags, que son la referencia
# contra la que compara).
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_clone_at "$ROOT/orbit" "$TREE" "$(git -C "$ROOT/orbit" rev-parse HEAD)"

if [[ -z "$(git -C "$TREE" tag -l 'agent/v*')" ]]; then
  echo "fixture: el clon de orbit no tiene tags agent/v* — fetchea tags en el submódulo (git -C orbit fetch --tags origin)" >&2
  exit 1
fi

sed -E 's#(github\.com/jcsvwinston/orbit/agent) v[0-9]+\.[0-9]+\.[0-9]+#\1 v0.0.9#' \
  "$TREE/server/go.mod" > "$TREE/server/go.mod.tmp"
mv "$TREE/server/go.mod.tmp" "$TREE/server/go.mod"
fx_assert_doctored "$TREE/server/go.mod" 'agent v0\.0\.9'

echo "workdir=$TREE"
echo "expect=agent pinned at v0\.0\.9, latest published tag is"
