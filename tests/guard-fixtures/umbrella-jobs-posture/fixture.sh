#!/usr/bin/env bash
# Fixture de umbrella-jobs-posture. Tres roturas, todas de la misma clase: una
# medición a la que alguien le cambia el resultado sin cambiar lo que mide.
#
# (A) la página del banco publica una cifra que la tabla no dice. El numerador
#     vive en un markdown y la verdad en un fichero Go, a dos directorios: la
#     edición más fácil de hacer y la más difícil de ver.
#
# (B) el CI de nucleus deja de correr la prueba de durabilidad. Es la única
#     afirmación del arco que no se puede comprobar leyendo —10 000 jobs con
#     el worker muerto a mitad—, así que sin la lane el proveedor puede dejar
#     de recuperar y todo lo demás sigue verde.
#
# (C) la prueba deja de exigir que hubiera trabajo EN VUELO al matar. Matar un
#     proceso ocioso también pasa, y mide nada: es la misma trampa que UIX-00
#     cerró en A6 para el motor de accesibilidad.
#
# El árbol parte del estado real al pin, conforme, así que el EXIT!=0 es
# atribuible a las roturas.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_jobs_posture.sh
mkdir -p "$TREE/nucleus/internal/jobsbench" "$TREE/nucleus/docs" \
         "$TREE/nucleus/pkg/tasks/providers/sql" "$TREE/nucleus/.github/workflows"

cp "$ROOT/nucleus/internal/jobsbench/jobsbench_cases_test.go" "$TREE/nucleus/internal/jobsbench/"
cp "$ROOT/nucleus/docs/jobs-bench.md" "$TREE/nucleus/docs/"
cp "$ROOT/nucleus/pkg/tasks/providers/sql/durability_test.go" "$TREE/nucleus/pkg/tasks/providers/sql/"
cp "$ROOT/nucleus/.github/workflows/ci.yml" "$TREE/nucleus/.github/workflows/"

# (A) la página publica otra cifra.
perl -0pi -e 's/\*\*\d+ of (\d+) controls present/**7 of $1 controls present/' "$TREE/nucleus/docs/jobs-bench.md"

# (B) el CI deja de correr la prueba de durabilidad.
perl -0pi -e 's/TestSQLProvider_GateDurabilityUnderCrash/TestSomethingElse/g' "$TREE/nucleus/.github/workflows/ci.yml"

# (C) la prueba deja de exigir trabajo en vuelo al matar.
perl -0pi -e 's/snap\.TotalCompleted > 100 && snap\.TotalActive > 0/snap.TotalCompleted > 100/' "$TREE/nucleus/pkg/tasks/providers/sql/durability_test.go"

fx_assert_doctored "$TREE/nucleus/docs/jobs-bench.md" '7 of 40 controls present'
fx_assert_doctored "$TREE/nucleus/.github/workflows/ci.yml" 'TestSomethingElse'

echo "workdir=$TREE"
echo "expect=la página dice 7/40 y el banco mide"
echo "expect=no corre la prueba de durabilidad"
echo "expect=trabajo EN VUELO"
