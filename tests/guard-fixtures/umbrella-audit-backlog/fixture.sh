#!/usr/bin/env bash
# Fixture de umbrella-audit-backlog.
#
# Rotura: un hallazgo abierto (OR-14) pierde su arco. Es la clase exacta que
# el guard existe para impedir: un hallazgo sin dueño que nadie vuelve a
# mirar. El árbol doctorado copia el guard, el registro y los seis informes.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_audit_backlog.sh docs/auditoria/madurez-2026-09-03
sed -i.bak -E 's/^(OR-14,P2,orbit,)A1,/\1,/' "$TREE/docs/auditoria/madurez-2026-09-03/registro.csv"
rm -f "$TREE/docs/auditoria/madurez-2026-09-03/registro.csv.bak"
if ! grep -q '^OR-14,P2,orbit,,abierto' "$TREE/docs/auditoria/madurez-2026-09-03/registro.csv"; then
  echo "fixture: la rotura no se aplicó — OR-14 sigue con arco" >&2
  exit 1
fi

echo "workdir=$TREE"
echo "expect=OR-14 .*abierto y sin arco"
