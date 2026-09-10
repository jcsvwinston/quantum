#!/usr/bin/env bash
# Fixture de quark-action-pins.
#
# Rotura: una referencia `uses:` del CI de quark vuelve a su TAG móvil — el SHA
# fijado se sustituye por la etiqueta que llevaba al lado, que es exactamente lo
# que el guard existe para impedir (un tag lo mueve su dueño, bajo un job que ya
# tiene este repositorio checkouteado). El guard debe morir nombrando el tag.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

# El árbol mínimo que el guard lee: su propio script y los workflows.
fx_copy "$ROOT/quark" "$TREE" \
  scripts/ci/check_action_pins.sh \
  .github/workflows

# El PRIMER `uses: actions/checkout@<sha> # <tag>` pasa a `uses: actions/checkout@v5`.
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
