#!/usr/bin/env bash
# Fixture de nucleus-version-claims.
#
# Rotura: la línea con marcador x-release-please-version de
# website/docs/intro.md pasa a reclamar v0.0.1 mientras
# .release-please-manifest.json declara la versión real — el drift NU-P0-2
# (documento canónico afirmando una versión que no es la publicada). El guard
# debe morir con "claims v0.0.1 but the released version is vX.Y.Z".
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

# El árbol mínimo que el guard lee: manifiesto de release-please, los cinco
# ficheros con marcador, go.mod (directivas del scaffold) y el inventario de
# contratos (coherencia de estados con el README).
fx_copy "$ROOT/nucleus" "$TREE" \
  scripts/ci/check_version_claims.sh \
  .release-please-manifest.json \
  README.md \
  SPEC.md \
  website/docs/intro.md \
  website/docs/reference/release-notes.md \
  internal/cli/new.go \
  go.mod \
  docs/reference/API_CONTRACT_INVENTORY.md

# Doctorado: solo las líneas-marcador de intro.md, versión → v0.0.1 (sin
# hardcodear la versión actual, para sobrevivir a los re-pins).
sed '/x-release-please-version/s/v[0-9][0-9.]*[0-9]/v0.0.1/' \
  "$TREE/website/docs/intro.md" > "$TREE/website/docs/intro.md.tmp"
mv "$TREE/website/docs/intro.md.tmp" "$TREE/website/docs/intro.md"
fx_assert_doctored "$TREE/website/docs/intro.md" 'v0\.0\.1'

echo "workdir=$TREE"
echo "expect=claims v0\.0\.1 but the released version is"
