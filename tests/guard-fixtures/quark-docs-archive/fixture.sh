#!/usr/bin/env bash
# Fixture de quark-docs-archive.
#
# Rotura: se borra del archivo el snapshot de la minor publicada, dejando el
# desplegable con el hueco que este guard existe para impedir (doc actual, y
# de ahí un salto a versiones viejas sin nada en medio). El guard debe morir
# diciendo que el archivo va por detrás de lo publicado.
#
# Árbol completo del repo: el guard lee .release-please-manifest.json y
# website/versions.json anclándose a su propia ubicación (dirname/../..).
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy_tree "$ROOT/quark" "$TREE"

# Quita la PRIMERA entrada de versions.json (Docusaurus las guarda de más
# reciente a más antigua): el snapshot de la minor publicada desaparece.
python3 - "$TREE/website/versions.json" <<'PY'
import json, sys
p = sys.argv[1]
v = json.load(open(p))
json.dump(v[1:], open(p, "w"), indent=2)
PY
fx_assert_doctored "$TREE/.release-please-manifest.json" '"\.":'

echo "workdir=$TREE"
echo "expect=el archivo de documentación va por detrás de lo publicado"
