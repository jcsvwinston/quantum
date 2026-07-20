#!/usr/bin/env bash
# Fixture de quark-lint-docs.
#
# Rotura: README.md (superficie user-facing, NO exenta) gana la frase
# "battle-tested", sin negación — el lenguaje de marketing que el linter F0-10
# veta mientras Quark no sea v1.0. El guard debe morir con
# "marketing-language".
#
# Árbol completo del repo (menos .git y artefactos): el linter escanea todos
# los .md/.mdx del árbol y resuelve enlaces relativos contra ficheros reales,
# así que un subárbol recortado daría falsos broken-links.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy_tree "$ROOT/quark" "$TREE"

printf '\nQuark is battle-tested in production environments.\n' >> "$TREE/README.md"
fx_assert_doctored "$TREE/README.md" 'battle-tested'

echo "workdir=$TREE"
echo "expect=marketing-language.*README"
