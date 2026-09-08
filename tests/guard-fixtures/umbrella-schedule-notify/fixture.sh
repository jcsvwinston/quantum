#!/usr/bin/env bash
# Fixture de umbrella-schedule-notify. Tres roturas, una por lane programada,
# y una causa de muerte declarada para cada una (`expect=` admite varias):
# con una sola, el EXIT!=0 de la primera taparía que las otras dejaran de
# cazarse.
#
# (A) scorecard.yml se queda SIN su job `notify-schedule-failure` — la deriva
#     exacta que este guard existe para cazar, y que no es hipotética: la
#     tercera lane programada del paraguas nació así en el arco A3 y la
#     certificación salió verde con la omisión dentro. El cron rojo degradaba
#     al email por defecto de Actions, que QM8-1 declaró insuficiente.
#
# (B) suite-integral.yml gana un job cuya clave lleva COMENTARIO al final
#     (`  publica-la-nota:  # …`) y que no está en el `needs` del aviso. Es
#     YAML legal y el guard tiene que verlo: el patrón original exigía fin de
#     línea tras los dos puntos, así que un job escrito así era invisible —
#     ni se exigía en `needs` (RT-8) ni se reportaba, y el guard salía verde.
#     En este guard el falso NEGATIVO es el peligroso: deja una lane sin
#     aviso efectivo y en verde.
#
# (C) integration.yml pierde el `issues: write` del job de aviso y, justo
#     después, gana un job con la clave comentada que sí lo declara. Es la
#     otra mitad del mismo defecto: si esa clave no cierra el bloque del job
#     anterior, el permiso del job de ABAJO valía por el del aviso.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_schedule_notify.sh .github/workflows
python3 - "$TREE/.github/workflows" <<'PY'
import sys, os
wf = sys.argv[1]

# (A) scorecard.yml sin el job de aviso.
p = os.path.join(wf, 'scorecard.yml')
s = open(p, encoding='utf-8').read()
marker = '  notify-schedule-failure:'
assert marker in s, 'la fixture no encontró el job de aviso en scorecard.yml'
# El job es el último del fichero: cortar desde su cabecera lo deja fuera
# entero, junto con los comentarios que lo preceden.
head = s[:s.index(marker)]
head = head[:head.rindex('\n  # QM8-1')] + '\n'
open(p, 'w', encoding='utf-8').write(head)

# (B) suite-integral.yml con un job de clave comentada fuera de `needs`.
p = os.path.join(wf, 'suite-integral.yml')
s = open(p, encoding='utf-8').read()
assert '  notify-schedule-failure:' in s, 'la fixture no encontró el job de aviso en suite-integral.yml'
s = s.rstrip('\n') + """

  publica-la-nota:  # clave con comentario: YAML legal, y el guard debe verla
    name: publica la nota de la corrida
    runs-on: ubuntu-latest
    steps:
      - run: echo "un job más, fuera del needs del aviso"
"""
open(p, 'w', encoding='utf-8').write(s)

# (C) integration.yml: al aviso se le cae issues: write y lo aporta un job
#     posterior de clave comentada.
p = os.path.join(wf, 'integration.yml')
s = open(p, encoding='utf-8').read()
perms = '    permissions:\n      contents: read\n      issues: write\n'
assert s.count(perms) == 1, 'la fixture esperaba un solo bloque de permisos con issues: write en integration.yml'
s = s.replace(perms, '    permissions:\n      contents: read\n', 1)
s = s.rstrip('\n') + """

  limpia-issues:  # clave con comentario: su permiso NO vale por el del aviso
    name: limpieza semanal de issues
    runs-on: ubuntu-latest
    permissions:
      issues: write
    steps:
      - run: echo limpieza
"""
open(p, 'w', encoding='utf-8').write(s)
PY

fx_assert_doctored "$TREE/.github/workflows/scorecard.yml" '^  analysis:'
if grep -q 'notify-schedule-failure' "$TREE/.github/workflows/scorecard.yml"; then
  echo "fixture: el job de aviso sigue en la copia — la rotura (A) no se aplicó" >&2
  exit 1
fi
fx_assert_doctored "$TREE/.github/workflows/suite-integral.yml" '^  publica-la-nota:[[:space:]]+#'
fx_assert_doctored "$TREE/.github/workflows/integration.yml" '^  limpia-issues:[[:space:]]+#'

echo "workdir=$TREE"
echo "expect=scorecard\.yml.*no tiene el job «notify-schedule-failure»"
echo "expect=suite-integral\.yml.*no incluye el job «publica-la-nota»"
echo "expect=integration\.yml.*no declara «issues: write»"
