#!/usr/bin/env bash
# Fixture de umbrella-schedule-notify.
#
# Rotura: una lane con disparador `schedule:` se queda SIN su job
# `notify-schedule-failure` —la deriva exacta que este guard existe para
# cazar, y que no es hipotética: la tercera lane programada del paraguas
# (scorecard.yml) nació así en la primera versión de este mismo PR, y la
# certificación salió verde con la omisión dentro. El cron rojo degradaba al
# email por defecto de Actions, que QM8-1 declaró insuficiente.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_schedule_notify.sh .github/workflows
python3 - "$TREE/.github/workflows/scorecard.yml" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
marker = '  notify-schedule-failure:'
assert marker in s, 'la fixture no encontró el job de aviso en scorecard.yml'
# El job es el último del fichero: cortar desde su cabecera lo deja fuera
# entero, junto con los comentarios que lo preceden.
head = s[:s.index(marker)]
head = head[:head.rindex('\n  # QM8-1')] + '\n'
open(p, 'w', encoding='utf-8').write(head)
PY
fx_assert_doctored "$TREE/.github/workflows/scorecard.yml" '^  analysis:'
if grep -q 'notify-schedule-failure' "$TREE/.github/workflows/scorecard.yml"; then
  echo "fixture: el job de aviso sigue en la copia — la rotura no se aplicó" >&2
  exit 1
fi

echo "workdir=$TREE"
echo "expect=no tiene el job «notify-schedule-failure»"
