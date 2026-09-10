#!/usr/bin/env bash
# Fixture de umbrella-audit-backlog.
#
# Rotura: un hallazgo abierto (QK-14, diferido a A3) pierde su arco. Es la clase exacta que
# el guard existe para impedir: un hallazgo sin dueño que nadie vuelve a
# mirar. El árbol doctorado copia el guard, el registro y los seis informes.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_audit_backlog.sh docs/auditoria/madurez-2026-09-03
# Se le quita el arco a la PRIMERA fila abierta, sea cual sea: la fixture
# nombraba QK-14, y QK-14 se cerró en el set 1.30.0 —con lo que la rotura dejó
# de aplicarse y la fixture murió preparándose—. Un hallazgo concreto caduca;
# «la primera que siga abierta» no.
python3 - "$TREE/docs/auditoria/madurez-2026-09-03/registro.csv" <<'PYEOF'
import sys

p = sys.argv[1]
lineas = open(p, encoding='utf-8').read().splitlines(keepends=True)
for i, ln in enumerate(lineas):
    campos = ln.split(',')
    if len(campos) > 4 and campos[4] == 'abierto':
        campos[3] = ''
        lineas[i] = ','.join(campos)
        print('fixture: arco borrado en', campos[0])
        break
else:
    raise SystemExit('fixture: no queda ninguna fila abierta que romper')
open(p, 'w', encoding='utf-8').write(''.join(lineas))
PYEOF

echo "workdir=$TREE"
echo "expect=abierto y sin arco del plan"
