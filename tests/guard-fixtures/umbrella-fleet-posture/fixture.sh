#!/usr/bin/env bash
# Fixture de umbrella-fleet-posture. Cuatro roturas, todas de la misma clase:
# una medición a la que alguien le cambia el resultado sin cambiar lo que mide.
#
# (A) la página del banco publica una cifra que el catálogo no dice. El
#     numerador vive en un markdown y la verdad en seis ficheros Go: la
#     edición más fácil de hacer y la más difícil de ver.
#
# (B) la tabla por familias de la página se queda rancia bajo un titular al
#     día. Pasó de verdad: tres sesiones diciendo 26/3/21 mientras el titular
#     decía 49 de 50. Aquí se retoca UNA fila.
#
# (C) la lane de navegador deja de exigir el navegador para el driver del
#     fleet. Sin `required`, el driver se salta cuando Playwright falta y la
#     lane se pone verde sin medir nada.
#
# (D) el test del clúster de tres agentes cambia de nombre. Es lo único del
#     arco que mide una flota y no un servidor; renombrado, nadie lo echa en
#     falta hasta que la flota falla en producción.
#
# El árbol parte del estado real al pin, conforme, así que el EXIT!=0 es
# atribuible a las roturas.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_fleet_posture.sh
mkdir -p "$TREE/orbit/internal/fleettest/fleetbench" "$TREE/orbit/internal/adminbench/browser/specs" \
  "$TREE/orbit/docs" "$TREE/orbit/.github/workflows"

cp "$ROOT"/orbit/internal/fleettest/fleetbench/cases_*_test.go "$TREE/orbit/internal/fleettest/fleetbench/"
cp "$ROOT/orbit/internal/fleettest/fleetbench/browserbench_test.go" "$TREE/orbit/internal/fleettest/fleetbench/"
cp "$ROOT/orbit/internal/fleettest/fleetbench/cluster_test.go" "$TREE/orbit/internal/fleettest/fleetbench/"
cp "$ROOT/orbit/internal/adminbench/browser/specs/fleet.spec.ts" "$TREE/orbit/internal/adminbench/browser/specs/"
cp "$ROOT/orbit/docs/fleet-bench.md" "$TREE/orbit/docs/"
cp "$ROOT/orbit/.github/workflows/ci.yml" "$TREE/orbit/.github/workflows/"

# (A) la página publica otra cifra.
perl -0pi -e 's/\*\*\d+ of (\d+) controls present/**7 of $1 controls present/' "$TREE/orbit/docs/fleet-bench.md"

# (B) la fila `alerts` de la tabla por familias vuelve a la línea de base de S0.
perl -0pi -e 's/^\| alerts \| \d+ \| \d+ \| \d+ \|$/| alerts | 2 | 0 | 4 |/m' "$TREE/orbit/docs/fleet-bench.md"

# (C) el driver del fleet deja de exigir el navegador. Sólo el suyo: la línea
#     `required` que sigue a TestFleetBrowserBench.
perl -0pi -e 's/(TestFleetBrowserBench.*?ORBIT_BENCH_BROWSER: )required/${1}optional/s' "$TREE/orbit/.github/workflows/ci.yml"

# (D) el test del clúster cambia de nombre.
perl -0pi -e 's/func TestFleetParityThreeAgents\(/func TestFleetParityTwoAgents(/' "$TREE/orbit/internal/fleettest/fleetbench/cluster_test.go"

fx_assert_doctored "$TREE/orbit/docs/fleet-bench.md" '7 of 50 controls present'
fx_assert_doctored "$TREE/orbit/docs/fleet-bench.md" '\| alerts \| 2 \| 0 \| 4 \|'
fx_assert_doctored "$TREE/orbit/.github/workflows/ci.yml" 'ORBIT_BENCH_BROWSER: optional'
fx_assert_doctored "$TREE/orbit/internal/fleettest/fleetbench/cluster_test.go" 'func TestFleetParityTwoAgents\('

echo "workdir=$TREE"
echo "expect=la página dice 7/50 y el banco mide"
echo "expect=la tabla por familias dice alerts 2/0/4"
echo "expect=TestFleetBrowserBench con ORBIT_BENCH_BROWSER=required"
echo "expect=ya no define TestFleetParityThreeAgents"
