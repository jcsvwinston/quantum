#!/usr/bin/env bash
# Fixture de umbrella-quark-extension-posture. Tres roturas, todas de la misma
# clase: una medición a la que alguien le cambia el resultado sin cambiar lo
# que mide.
#
# (A) la página del banco publica un titular que la tabla no dice. El
#     numerador vive en un markdown y la verdad en tres ficheros Go: la
#     edición más fácil de hacer y la más difícil de ver.
#
# (B) la cabecera de una familia se queda con otra cifra bajo un titular al
#     día: la deriva que la tabla por familias de A9 arrastró tres sesiones.
#
# (C) un control `present` (CON-03, los ocho hooks del modelo) pasa a
#     `absent` sin nota. Un hueco sin razón escrita es un hueco que nadie
#     tiene que cerrar; y como baja un present, también lo caza el suelo.
#
# Las tres se escriben contra lo que el pin publica —el total se lee de la
# página, la familia y el control existen en v1.16.0 y en el main de quark—,
# así que la fixture sobrevive al re-pin que sube el banco a 22 de 22.
#
# El árbol parte del estado real al pin, conforme, así que el EXIT!=0 es
# atribuible a las roturas.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_quark_extension_posture.sh quark/docs/extension-bench.md
mkdir -p "$TREE/quark/internal/extbench"
cp "$ROOT"/quark/internal/extbench/cases_*_test.go "$TREE/quark/internal/extbench/"

# El árbol sin doctorar tiene que pasar: si no, el EXIT!=0 de abajo no
# demostraría nada.
if ! (cd "$TREE" && bash scripts/check_quark_extension_posture.sh >/dev/null 2>&1); then
  echo "fixture: el guard ya falla sobre la copia SIN doctorar — la página o el banco al pin cambiaron; arréglalo antes de probar la mordida" >&2
  (cd "$TREE" && bash scripts/check_quark_extension_posture.sh) >&2 || true
  exit 1
fi

DOC="$TREE/quark/docs/extension-bench.md"
total=$(grep -oE '\*\*[0-9]+ of [0-9]+ controls present' "$DOC" | head -1 | grep -oE 'of [0-9]+' | grep -oE '[0-9]+')
[[ -n "$total" ]] || { echo "fixture: $DOC no publica «**N of M controls present**» al pin" >&2; exit 1; }

# (A) el titular dice otra cifra.
perl -0pi -e 's/\*\*\d+ of (\d+) controls present/**7 of $1 controls present/' "$DOC"
fx_assert_doctored "$DOC" "\*\*7 of $total controls present"

# (B) la cabecera de integrations, con otra cifra.
perl -0pi -e 's/^### integrations — \d+ present/### integrations — 0 present/m' "$DOC"
fx_assert_doctored "$DOC" '^### integrations — 0 present'

# (C) CON-03 pasa a absent sin nota.
perl -0pi -e 's/(id: +"CON-03",.*?want: +)present,/${1}absent,/s' "$TREE/quark/internal/extbench/cases_contract_test.go"
# fx_assert_doctored mira línea a línea y absent ya hay al pin: se comprueba
# el bloque de CON-03 entero.
perl -0ne 'exit(/id: +"CON-03",[^}]*want: +absent,/s ? 0 : 1)' "$TREE/quark/internal/extbench/cases_contract_test.go" \
  || { echo "fixture: la rotura (C) no se aplicó — CON-03 sigue sin estar absent (¿cambió el formato del caso?)" >&2; exit 1; }

echo "workdir=$TREE"
echo "expect=la página dice 7/$total"
echo "expect=la cabecera de integrations .* dice «0 "
echo "expect=casos sin nota que diga qué falta: CON-03"
echo "expect=registra [0-9]+ controles present; el suelo al pin es [0-9]+"
