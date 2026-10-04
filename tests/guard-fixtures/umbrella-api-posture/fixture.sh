#!/usr/bin/env bash
# Fixture de umbrella-api-posture. Tres roturas, todas de la misma clase: el
# gate de A10 sigue leyéndose como cumplido cuando ya no lo está.
#
# (A) la página del banco publica una cifra que la tabla no dice. El numerador
#     vive en un markdown y la verdad en un fichero Go, a dos directorios: la
#     edición más fácil de hacer y la más difícil de ver.
#
# (B) el CI de nucleus deja de correr el test del gate. El cliente TypeScript
#     generado contra el starter es la única afirmación del arco que no se
#     comprueba leyendo; sin la lane, el generador o el starter pueden
#     romperse y todo lo demás sigue verde.
#
# (C) el script del gate deja de comprobar que un error llegue al cliente.
#     Una lista que sólo lee pasa aunque el cliente no sepa leer el sobre ni
#     problem+json: es la misma trampa que la sonda de durabilidad de A7
#     cerró exigiendo trabajo EN VUELO.
#
# El árbol parte del estado real al pin, conforme, así que el EXIT!=0 es
# atribuible a las roturas.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_api_posture.sh
for f in internal/apibench/apibench_cases_test.go docs/api-bench.md \
         internal/cli/scaffold/templates/suite/main.go.tmpl \
         internal/cli/scaffold/templates/suite/shop/module.go.tmpl \
         internal/cli/scaffold/templates/suite/shop/module_test.go.tmpl \
         internal/cli/new_suite_client_test.go \
         internal/cli/testdata/starter_client/e2e.ts \
         contracts/baseline/starter_openapi.json \
         .github/workflows/ci.yml; do
  mkdir -p "$TREE/nucleus/$(dirname "$f")"
  cp "$ROOT/nucleus/$f" "$TREE/nucleus/$f"
done

# (A) la página publica otra cifra.
perl -0pi -e 's/\*\*\d+ of (\d+) controls present/**7 of $1 controls present/' "$TREE/nucleus/docs/api-bench.md"

# (B) el CI deja de correr el test del gate.
perl -0pi -e 's/TestSuiteStarterTypeScriptClient/TestSomethingElse/g' "$TREE/nucleus/.github/workflows/ci.yml"

# (C) el script del gate deja de comprobar que el 409 llegue al cliente.
perl -0pi -e 's/409/4xx/g' "$TREE/nucleus/internal/cli/testdata/starter_client/e2e.ts"

fx_assert_doctored "$TREE/nucleus/docs/api-bench.md" '7 of 46 controls present'
fx_assert_doctored "$TREE/nucleus/.github/workflows/ci.yml" 'TestSomethingElse'

echo "workdir=$TREE"
echo "expect=la página dice 7/46 y el banco mide"
echo "expect=el CI de nucleus no corre el test del gate"
echo "expect=el 409 de un duplicado"
