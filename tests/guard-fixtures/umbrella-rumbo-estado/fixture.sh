#!/usr/bin/env bash
# Fixture de umbrella-rumbo-estado.
#
# Rotura: la cabecera «Estado real» de docs/RUMBO.md afirma «Set certificado:
# Quantum 0.0.0» mientras versions.yaml certifica otra versión — la deriva
# exacta que motivó el guard (QM-6, auditoría 2026-09-03: el RUMBO decía
# 1.25.0 con el manifiesto en 1.26.0, y su propio §1 decía 1.26.0). La versión
# real no se hardcodea: se doctora la que el fichero traiga, para que la
# fixture sobreviva a los re-pins.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_rumbo_estado.sh docs/RUMBO.md versions.yaml

sed -E 's/(Set certificado: Quantum )[0-9]+\.[0-9]+\.[0-9]+/\10.0.0/' "$TREE/docs/RUMBO.md" > "$TREE/docs/RUMBO.md.tmp"
mv "$TREE/docs/RUMBO.md.tmp" "$TREE/docs/RUMBO.md"
fx_assert_doctored "$TREE/docs/RUMBO.md" 'Set certificado: Quantum 0\.0\.0'

echo "workdir=$TREE"
echo "expect=RUMBO\.md afirma «Set certificado: Quantum 0\.0\.0»"
