#!/usr/bin/env bash
# Fixture de nucleus-retired-claims.
#
# Rotura: una página VIVA del sitio de nucleus vuelve a afirmar que SQL Server
# vive tras un build tag — la frase exacta que la auditoría de madurez
# 2026-09-03 encontró en siete páginas servidas (NU-24, QM-4) después de que
# ADR-031 retirase los build tags. El guard debe morir nombrando el fichero y
# la línea; una mención deliberada se marca con `retired-claims-allow` en la
# línea anterior, y la fixture también comprueba que ESA vía sigue abierta
# (una segunda página con la marca no debe contar).
#
# Árbol completo del repo: el guard se ancla a su propia ubicación
# (dirname/../..) y lista README/SPEC/docs/website/docs del árbol real.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy_tree "$ROOT/nucleus" "$TREE"

mkdir -p "$TREE/website/docs/probe"
cat > "$TREE/website/docs/probe/index.md" <<'MD'
# Probe

SQL Server support is opt-in: add `-tags mssql` to include the driver.
MD
cat > "$TREE/website/docs/probe/allowed.md" <<'MD'
# Allowed

<!-- retired-claims-allow -->
Until v1.23.0 SQL Server sat behind `-tags mssql`; today it is drivers/mssql.
MD
fx_assert_doctored "$TREE/website/docs/probe/index.md" '\-tags mssql'

echo "workdir=$TREE"
echo "expect=Retired claims found in the living documentation"
