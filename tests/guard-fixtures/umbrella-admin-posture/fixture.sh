#!/usr/bin/env bash
# Fixture de umbrella-admin-posture. Tres roturas, todas de la misma clase:
# una medición a la que alguien le cambia el resultado sin cambiar lo que
# mide.
#
# (A) la página del banco publica una cifra que la tabla no dice. El
#     numerador vive en un markdown y la verdad en un fichero Go, a dos
#     directorios: es la edición más fácil de hacer y la más difícil de ver.
#
# (B) el CI de orbit deja de exigir el instrumento del navegador
#     (ORBIT_BENCH_BROWSER=required). Sin eso la lane se pone VERDE cuando el
#     navegador no está instalado, que es peor que no tener lane: dice que se
#     midió lo que nadie midió.
#
# (C) el spec que planta una violación deliberada desaparece. Es el control
#     que comprueba que el motor de accesibilidad muerde; sin él, un motor
#     mal configurado informa de cero violaciones y TODOS los demás controles
#     pasan midiendo nada.
#
# El árbol parte del estado real al pin, conforme, así que el EXIT!=0 es
# atribuible a las roturas.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_admin_posture.sh
mkdir -p "$TREE/orbit/internal/adminbench/browser/specs" "$TREE/orbit/docs" "$TREE/orbit/.github/workflows"

cp "$ROOT/orbit/internal/adminbench/adminbench_cases_test.go" "$TREE/orbit/internal/adminbench/"
cp "$ROOT/orbit/internal/adminbench/browserbench_test.go" "$TREE/orbit/internal/adminbench/"
cp "$ROOT/orbit/internal/adminbench/browser/package.json" "$TREE/orbit/internal/adminbench/browser/"
cp "$ROOT/orbit/internal/adminbench/browser/playwright.config.ts" "$TREE/orbit/internal/adminbench/browser/"
cp "$ROOT"/orbit/internal/adminbench/browser/specs/*.spec.ts "$TREE/orbit/internal/adminbench/browser/specs/"
cp "$ROOT/orbit/docs/admin-bench.md" "$TREE/orbit/docs/"
cp "$ROOT/orbit/.github/workflows/ci.yml" "$TREE/orbit/.github/workflows/"

# (A) la página publica otra cifra.
perl -0pi -e 's/\*\*\d+ of (\d+) controls present/**11 of $1 controls present/' "$TREE/orbit/docs/admin-bench.md"

# (B) el CI deja de exigir el instrumento.
perl -0pi -e 's/ORBIT_BENCH_BROWSER: required/ORBIT_BENCH_BROWSER: optional/' "$TREE/orbit/.github/workflows/ci.yml"

# (C) el control que prueba el instrumento desaparece de los specs.
perl -0pi -e 's/UIX-00/UIX-XX/g' "$TREE"/orbit/internal/adminbench/browser/specs/*.spec.ts

fx_assert_doctored "$TREE/orbit/docs/admin-bench.md" '11 of 59 controls present'
fx_assert_doctored "$TREE/orbit/.github/workflows/ci.yml" 'ORBIT_BENCH_BROWSER: optional'

echo "workdir=$TREE"
echo "expect=la página dice 11/59 y el banco mide"
echo "expect=ORBIT_BENCH_BROWSER=required"
echo "expect=planta una violación"
