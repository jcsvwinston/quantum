#!/usr/bin/env bash
# Fixture de quark-version-coherence.
#
# Rotura: README.md deja de mencionar la versión publicada (todas sus
# menciones v<actual> pasan a v0.0.0) mientras .release-please-manifest.json
# sigue declarándola — el drift H-Q6 exacto (v1.2.0 salió con README diciendo
# v1.1.5). El guard debe morir con "README.md does not mention v<actual>".
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

ver=$(sed -nE 's/.*"\.": *"([0-9]+\.[0-9]+\.[0-9]+)".*/\1/p' "$ROOT/quark/.release-please-manifest.json")
if [[ -z "$ver" ]]; then
  echo "fixture: no se pudo leer la versión del manifiesto de quark" >&2
  exit 1
fi

# El árbol mínimo que el guard lee: manifiesto, los cuatro ficheros con
# mención de versión, las notas narrativas del minor y el roadmap (check de
# versiones hardcodeadas).
fx_copy "$ROOT/quark" "$TREE" \
  scripts/check-version-coherence.sh \
  .release-please-manifest.json \
  README.md \
  SECURITY.md \
  CLAUDE.md \
  website/docs/reference/release-notes.mdx \
  website/docs/reference/roadmap.mdx \
  "docs/RELEASE_NOTES_v${ver%.*}.0.md"

sed "s/v${ver}/v0.0.0/g" "$TREE/README.md" > "$TREE/README.md.tmp"
mv "$TREE/README.md.tmp" "$TREE/README.md"
fx_assert_doctored "$TREE/README.md" 'v0\.0\.0'

echo "workdir=$TREE"
echo "expect=README\.md does not mention v${ver//./\\.}"
