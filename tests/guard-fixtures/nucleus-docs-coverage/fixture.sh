#!/usr/bin/env bash
# Fixture de nucleus-docs-coverage.
#
# Rotura: una página de website/docs referencia el símbolo estable
# pkg/model.InventedByGuardOfGuardsQM7, que NO existe en la baseline del
# freeze — una referencia colgante: la doc promete documentar un símbolo que
# el producto no exporta. El guard (--strict) debe morir con "DANGLING".
#
# Árbol completo del módulo: la sección 4 del guard ejecuta bodycheck con
# `go run`, que compila contra el módulo real.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy_tree "$ROOT/nucleus" "$TREE"

cat > "$TREE/website/docs/qm7-fixture-probe.md" <<'MD'
# Probe page (guard-of-guards fixture)

Use pkg/model.InventedByGuardOfGuardsQM7 to configure the feature.
MD
fx_assert_doctored "$TREE/website/docs/qm7-fixture-probe.md" 'InventedByGuardOfGuardsQM7'

echo "workdir=$TREE"
echo "expect=DANGLING.*InventedByGuardOfGuardsQM7"
