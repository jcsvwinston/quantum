#!/usr/bin/env bash
# Fixture de orbit-docs-version-claims.
#
# Rotura: la línea con marcador x-release-please-version de
# website/docs/intro.md reclama v0.0.1 mientras .release-please-manifest.json
# declara la versión real — el drift QM5-3 (la web de orbit dijo v1.2.1
# durante tres minors). El guard debe morir con "claims v0.0.1 but the
# released version is vX.Y.Z".
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT/orbit" "$TREE" \
  scripts/ci/check_docs_version_claims.sh \
  .release-please-manifest.json \
  README.md \
  CLAUDE.md \
  website/docs/intro.md \
  website/docs/quick-start.md \
  website/docs/reference/release-notes.md

sed '/x-release-please-version/s/v[0-9][0-9.]*[0-9]/v0.0.1/' \
  "$TREE/website/docs/intro.md" > "$TREE/website/docs/intro.md.tmp"
mv "$TREE/website/docs/intro.md.tmp" "$TREE/website/docs/intro.md"
fx_assert_doctored "$TREE/website/docs/intro.md" 'v0\.0\.1'

echo "workdir=$TREE"
echo "expect=claims v0\.0\.1 but the released version is"
