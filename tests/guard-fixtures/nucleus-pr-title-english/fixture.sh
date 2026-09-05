#!/usr/bin/env bash
# Fixture de nucleus-pr-title-english (QM-18).
#
# Rotura: un título de PR en español — el título del squash es la línea del
# changelog y la nota de release de un producto cuya voz es inglesa
# (QADR-0007). El guard recibe el título por PR_TITLE (env= de esta fixture)
# y debe morir nombrando la palabra que lo delata.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT/nucleus" "$TREE" scripts/ci/check_pr_title_english.sh

echo "workdir=$TREE"
echo "env=PR_TITLE=fix(router): arregla el arranque de los módulos"
echo "expect=write it in English"
