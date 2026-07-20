#!/usr/bin/env bash
# Fixture de nucleus-product-voice.
#
# Rotura: una página bajo website/docs/ referencia "ADR-999" — vocabulario
# interno en la superficie publicada, la clase de fuga que el linter existe
# para vetar. El guard debe morir con "Internal vocabulary found in the
# published docs".
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

# El guard escanea website/docs/**: basta el script, una página real de
# contexto y la página doctorada.
fx_copy "$ROOT/nucleus" "$TREE" \
  scripts/ci/check_docs_product_voice.sh \
  website/docs/intro.md

cat > "$TREE/website/docs/qm7-fixture-probe.md" <<'MD'
# Probe page (guard-of-guards fixture)

The change is recorded in ADR-999 for future reference.
MD

echo "workdir=$TREE"
echo "expect=Internal vocabulary found in the published docs"
