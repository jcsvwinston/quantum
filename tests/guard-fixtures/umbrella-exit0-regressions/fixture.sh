#!/usr/bin/env bash
# Fixture de umbrella-exit0-regressions (guard nº16).
#
# Rotura: el aviso DX-14 de `nucleus routes` ("listing framework-owned routes
# only") desaparece de internal/cli/routes.go — la herramienta vuelve a
# presentar la lista parcial como completa, que es exactamente el §4.A7 del
# informe DX. El guard debe morir con "FAIL A7".
#
# Nota de época: con pines anteriores a Quantum 1.12.0 (quark < v1.5.0,
# nucleus < v1.8.0) el aviso aún no existe en el árbol pinado y el guard ya
# muere en A7 (y en A1..A6) por sí solo — el doctorado se aplica solo cuando
# el marcador está presente, así que la fixture vale en ambas épocas y la
# causa de muerte esperada es la misma.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_exit0_regressions.sh

for m in quark nucleus; do
  fx_clone_at "$ROOT/$m" "$TREE/$m" "$(git -C "$ROOT/$m" rev-parse HEAD)"
done

ROUTES="$TREE/nucleus/internal/cli/routes.go"
if grep -q "listing framework-owned routes only" "$ROUTES"; then
  perl -pi -e 's/listing framework-owned routes only/listing routes/' "$ROUTES"
  fx_assert_doctored "$ROUTES" 'listing routes\.'
fi

echo "workdir=$TREE"
echo "expect=FAIL A7"
