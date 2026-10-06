#!/usr/bin/env bash
# Fixture de umbrella-catalog-posture. Cuatro roturas, todas de la misma
# clase: una medición a la que alguien le cambia el resultado sin cambiar lo
# que mide.
#
# (A) la página del banco publica un titular que la tabla no dice. El
#     numerador vive en un markdown y la verdad en un fichero Go: la edición
#     más fácil de hacer y la más difícil de ver.
#
# (B) una fila de la tabla por familias se queda con otra cifra bajo un
#     titular al día: la deriva que la tabla de A9 arrastró tres sesiones.
#
# (C) EN-08 (Stripe) pierde su nota. Un absent con la razón escrita es un
#     veredicto legítimo —la decisión del propietario de dejar los pagos
#     fuera de la suite—; sin ella es un hueco que nadie tiene que cerrar.
#
# (D) un control present (CAT-02, la ayuda de `nucleus add`) se registra
#     partial, con su nota: la salida fácil cuando una sonda se pone roja. La
#     nota está, así que sólo el suelo lo caza.
#
# El árbol parte del estado real al pin, conforme, así que el EXIT!=0 es
# atribuible a las roturas.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_catalog_posture.sh \
  nucleus/internal/catalogbench/catalogbench_cases_test.go nucleus/docs/catalog-bench.md

# El árbol sin doctorar tiene que pasar: si no, el EXIT!=0 de abajo no
# demostraría nada.
if ! (cd "$TREE" && bash scripts/check_catalog_posture.sh >/dev/null 2>&1); then
  echo "fixture: el guard ya falla sobre la copia SIN doctorar — la página o el banco al pin cambiaron; arréglalo antes de probar la mordida" >&2
  (cd "$TREE" && bash scripts/check_catalog_posture.sh) >&2 || true
  exit 1
fi

DOC="$TREE/nucleus/docs/catalog-bench.md"
CASES="$TREE/nucleus/internal/catalogbench/catalogbench_cases_test.go"
total=$(grep -oE '\*\*[0-9]+ of [0-9]+ controls present' "$DOC" | head -1 | grep -oE 'of [0-9]+' | grep -oE '[0-9]+')
[[ -n "$total" ]] || { echo "fixture: $DOC no publica «**N of M controls present**» al pin" >&2; exit 1; }

# (A) el titular dice otra cifra.
perl -0pi -e 's/\*\*\d+ of (\d+) controls present/**7 of $1 controls present/' "$DOC"
fx_assert_doctored "$DOC" "\*\*7 of $total controls present"

# (B) la fila de plugins, con otra cifra.
perl -0pi -e 's/^\| plugins \| \d+ \|/| plugins | 0 |/m' "$DOC"
fx_assert_doctored "$DOC" '^\| plugins \| 0 \|'

# (C) EN-08 sin su nota.
perl -0pi -e 's/(\{id: "EN-08",.*?want: +absent,) note: .*?",\n(\s*probe:)/$1\n$2/s' "$CASES"
perl -0ne 'exit(/\{id: "EN-08",[^}]*note:/s ? 1 : 0)' "$CASES" \
  || { echo "fixture: la rotura (C) no se aplicó — EN-08 sigue con nota (¿cambió el formato del caso, o dejó de ser absent?)" >&2; exit 1; }

# (D) CAT-02 pasa de present a partial con nota.
perl -0pi -e 's/(\{id: "CAT-02",.*?want: +)present,/${1}partial, note: "fixture: retrocede a la vista",/s' "$CASES"
fx_assert_doctored "$CASES" 'want: partial, note: "fixture: retrocede a la vista"'

echo "workdir=$TREE"
echo "expect=la página dice 7/$total"
echo "expect=la fila de plugins .* dice «0 "
echo "expect=casos sin nota que diga qué falta: EN-08"
echo "expect=registra [0-9]+ controles present; el suelo de A11 es [0-9]+"
