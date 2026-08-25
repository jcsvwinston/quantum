#!/usr/bin/env bash
# Fixture de orbit-docs-archive.
#
# Rotura: se borra del archivo el snapshot de la minor publicada, dejando el
# desplegable con el hueco que este guard existe para impedir. Misma rotura
# que en quark y nucleus; orbit llegó el último a versionar su documentación.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy_tree "$ROOT/orbit" "$TREE"

# Quita la PRIMERA entrada de versions.json (más reciente primero): el
# snapshot de la minor publicada desaparece. Con una sola entrada el fichero
# queda vacío, que es el otro camino al mismo veredicto.
python3 - "$TREE/website/versions.json" <<'PY'
import json, sys
p = sys.argv[1]
v = json.load(open(p))
json.dump(v[1:], open(p, "w"), indent=2)
PY
fx_assert_doctored "$TREE/.release-please-manifest.json" '"\.":'

echo "workdir=$TREE"
echo "expect=el archivo no contiene ningún snapshot|va por detrás de lo publicado"
