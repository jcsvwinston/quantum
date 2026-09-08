#!/usr/bin/env bash
# Fixture de umbrella-actions-pinned. Dos roturas, cada una con su causa de
# muerte declarada (`expect=` admite varias):
#
# (A) un paso vuelve al tag móvil (`actions/checkout@v7`) en lugar del SHA —la
#     deriva exacta que este guard existe para cazar: el pin se pone una vez y
#     el siguiente workflow escrito a mano nace sin él, o un `git revert` lo
#     deshace sin que nadie lo note.
#
# (B) el mismo tag móvil, pero escrito en FORMA DE FLUJO
#     (`steps: [{uses: actions/setup-node@v7}]`). Es YAML legal y el patrón
#     anclado al principio de línea no lo veía: la referencia no se contaba
#     siquiera, así que el tag móvil pasaba en verde. Va en la fixture porque
#     es un falso negativo, la dirección que hace daño en un guard de pines.
#     El job doctorado es un workflow válido —lo confirman un parser de YAML y
#     actionlint—: la deriva creíble no es YAML ilegal, es la otra forma legal
#     de escribir lo mismo.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

# `.github/dependabot.yml` viaja en la copia aunque no sea lo que se rompe: el
# guard exige también esa mitad (el bot que sube el pin), y sin el fichero la
# copia moriría por DOS causas — un EXIT!=0 por la de setup no demuestra que
# la mordida sea la del pin sin fijar.
fx_copy "$ROOT" "$TREE" scripts/check_actions_pinned.sh .github/workflows .github/dependabot.yml
python3 - "$TREE/.github/workflows/deploy.yml" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s, n = re.subn(r'uses: actions/checkout@[0-9a-f]{40} # v[0-9.]+', 'uses: actions/checkout@v7', s, count=1)
assert n == 1, 'la fixture no encontró el pin de actions/checkout en deploy.yml'
open(p, 'w', encoding='utf-8').write(s)
PY
python3 - "$TREE/.github/workflows/website-ci.yml" <<'PY2'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
assert 'jobs:' in s, 'la fixture no encontró el bloque jobs: de website-ci.yml'
# Un job MÁS, con su único paso escrito en forma de flujo. Es un workflow
# válido (lo confirma un parser de YAML y actionlint), que es justo lo que hace
# creíble la deriva: nadie escribe YAML ilegal, escribe la otra forma legal.
s = s.rstrip('\n') + """

  audita-dependencias:
    name: paso escrito en forma de flujo
    runs-on: ubuntu-latest
    steps: [{uses: actions/setup-node@v7}]
"""
open(p, 'w', encoding='utf-8').write(s)
PY2
fx_assert_doctored "$TREE/.github/workflows/deploy.yml" 'uses: actions/checkout@v7$'
fx_assert_doctored "$TREE/.github/workflows/website-ci.yml" 'steps: \[\{uses: actions/setup-node@v7\}\]'

echo "workdir=$TREE"
echo "expect=deploy\.yml.*«actions/checkout@v7» no está fijada por SHA de commit"
echo "expect=website-ci\.yml.*«actions/setup-node@v7» no está fijada por SHA de commit"
