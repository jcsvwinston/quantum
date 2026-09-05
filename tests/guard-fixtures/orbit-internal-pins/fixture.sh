#!/usr/bin/env bash
# Fixture de orbit-internal-pins.
#
# Rotura: agent/go.mod pina el módulo hermano proto a v0.0.9 — un pin
# envejecido respecto al último tag publicado de proto. Es la clase OR5-1:
# server/v0.8.1 llegó a tag pinando el agent SIN el fix que su propio test de
# regresión comprobaba. Desde orbit ADR-006 (v1.9.0) server ya no requiere
# agent, así que la arista que queda entre hermanos —y la que esta fixture
# rompe— es agent → proto. El guard debe morir con "proto pinned at v0.0.9,
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

if [[ -z "$(git -C "$TREE" tag -l 'proto/v*')" ]]; then
  echo "fixture: el clon de orbit no tiene tags proto/v* — fetchea tags en el submódulo (git -C orbit fetch --tags origin)" >&2
  exit 1
fi

sed -E 's#(github\.com/jcsvwinston/orbit/proto) v[0-9]+\.[0-9]+\.[0-9]+#\1 v0.0.9#' \
  "$TREE/agent/go.mod" > "$TREE/agent/go.mod.tmp"
mv "$TREE/agent/go.mod.tmp" "$TREE/agent/go.mod"
fx_assert_doctored "$TREE/agent/go.mod" 'proto v0\.0\.9'

echo "workdir=$TREE"
echo "expect=proto pinned at v0\.0\.9, latest published tag is"
