#!/usr/bin/env bash
# Fixture de umbrella-handoff-size.
#
# Rotura: el §3 del handoff vuelve a acumular sesiones (tres, una más de las
# permitidas) — la deriva exacta que lo llevó a 203 KB y a cargarse truncado.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_handoff_size.sh .claude/commands/next-session.md
python3 - "$TREE/.claude/commands/next-session.md" <<'PY'
import sys
p=sys.argv[1]; s=open(p,encoding='utf-8').read()
i=s.index('## 4. Las fases')
s=s[:i]+'### Sesión 2000-01-01 — sesión de prueba de la fixture\n\n- nada\n\n'+s[i:]
open(p,'w',encoding='utf-8').write(s)
PY
fx_assert_doctored "$TREE/.claude/commands/next-session.md" '### Sesión 2000-01-01'

echo "workdir=$TREE"
echo "expect=lleva [0-9]+ sesiones \(> 2\)"
