#!/usr/bin/env bash
# Fixture de umbrella-actions-pinned.
#
# Rotura: un paso vuelve al tag móvil (`actions/checkout@v7`) en lugar del SHA
# —la deriva exacta que este guard existe para cazar: el pin se pone una vez y
# el siguiente workflow escrito a mano nace sin él, o un `git revert` lo
# deshace sin que nadie lo note.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_actions_pinned.sh .github/workflows
python3 - "$TREE/.github/workflows/deploy.yml" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s, n = re.subn(r'uses: actions/checkout@[0-9a-f]{40} # v[0-9.]+', 'uses: actions/checkout@v7', s, count=1)
assert n == 1, 'la fixture no encontró el pin de actions/checkout en deploy.yml'
open(p, 'w', encoding='utf-8').write(s)
PY
fx_assert_doctored "$TREE/.github/workflows/deploy.yml" 'uses: actions/checkout@v7$'

echo "workdir=$TREE"
echo "expect=no está fijada por SHA de commit"
