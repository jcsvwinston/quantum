#!/usr/bin/env bash
# Fixture de quark-product-voice.
#
# Rotura: una página bajo website/docs/ referencia "ADR-999" — vocabulario
# interno en la superficie publicada. El guard debe morir con "Internal
# vocabulary found in the published docs".
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT/quark" "$TREE" \
  scripts/ci/check_docs_product_voice.sh \
  website/docs/intro.mdx

cat > "$TREE/website/docs/qm7-fixture-probe.md" <<'MD'
# Probe page (guard-of-guards fixture)

The change is recorded in ADR-999 for future reference.
MD

echo "workdir=$TREE"
echo "expect=Internal vocabulary found in the published docs"
