#!/usr/bin/env bash
# Fixture de umbrella-quark-posture. Tres roturas, todas de la misma clase: una
# medición a la que alguien le cambia el resultado sin cambiar lo que mide.
#
# (A) la página del banco publica una cifra que la tabla no dice. El numerador
#     vive en un markdown y la verdad en cinco ficheros Go: la edición más
#     fácil de hacer y la más difícil de ver.
#
# (B) SharedSuite deja de correr una de las pruebas del arco (Keyset). Las
#     sondas del banco corren sobre SQLite; lo que el arco prueba en los seis
#     motores está SOLO ahí, y tres veces una lane de motor enseñó lo que
#     ninguna sonda vio.
#
# (C) un control que no está `present` pierde su nota. Un hueco sin razón
#     escrita es un hueco que nadie tiene que cerrar.
#
# El árbol parte del estado real al pin, conforme, así que el EXIT!=0 es
# atribuible a las roturas.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_quark_posture.sh
mkdir -p "$TREE/quark/internal/enterprisebench" "$TREE/quark/docs" "$TREE/quark/internal/enginesuite"

cp "$ROOT"/quark/internal/enterprisebench/cases_*_test.go "$TREE/quark/internal/enterprisebench/"
cp "$ROOT/quark/docs/enterprise-bench.md" "$TREE/quark/docs/"
cp "$ROOT/quark/internal/enginesuite/suite_test.go" "$TREE/quark/internal/enginesuite/"

# (A) la página publica otra cifra.
perl -0pi -e 's/\*\*\d+ of (\d+) controls present/**7 of $1 controls present/' "$TREE/quark/docs/enterprise-bench.md"

# (B) SharedSuite deja de correr Keyset.
perl -0pi -e 's/t\.Run\("Keyset"/t.Run("Nothing"/' "$TREE/quark/internal/enginesuite/suite_test.go"

# (C) el primer control partial/absent pierde su nota: RLS-01 es partial y
#     lleva nota; se le quita.
perl -0pi -e 's/(id: +"RLS-01",.*?want: +partial,\n)\s*note: .*?,\n(\s*probe:)/$1$2/s' "$TREE/quark/internal/enterprisebench/cases_rls_test.go"

fx_assert_doctored "$TREE/quark/docs/enterprise-bench.md" '7 of 69 controls present'
fx_assert_doctored "$TREE/quark/internal/enginesuite/suite_test.go" 't.Run\("Nothing"'

echo "workdir=$TREE"
echo "expect=la página dice 7/69 y el banco mide"
echo "expect=ya no corre Keyset"
echo "expect=casos sin nota que diga qué falta: RLS-01"
