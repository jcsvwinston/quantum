#!/usr/bin/env bash
# Fixture de orbit-versioned-markers.
#
# Rotura: se baja el marcador `x-release-please-version` de un snapshot de
# orbit a una versión que no es la suya — que es LITERALMENTE cómo salió el
# defecto (los snapshots 1.7.0 y 1.8.0 anunciaban «v1.6.7» y «v1.7.4», rancios
# en producción). El guard de orbit usa el marcador HTML `<!-- ... -->`, pero
# la versión va igual en la línea, así que la rotura es la misma que en
# nucleus.
#
# El guard debe morir nombrando el fichero, lo que afirma y lo que debería.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy_tree "$ROOT/orbit" "$TREE"

# Víctima: el primer fichero con marcador de cualquier snapshot versionado.
victim=$(grep -rl "x-release-please-version" "$TREE"/website/versioned_docs/version-* 2>/dev/null | head -1)
[ -n "$victim" ] || { echo "fixture: ningún snapshot lleva el marcador — ¿cambió el árbol?" >&2; exit 1; }

before=$(grep "x-release-please-version" "$victim" | head -1)

# Sustituye la versión de la línea del marcador por una que no puede ser la
# del snapshot.
perl -i -pe 's/v[0-9]+\.[0-9]+\.[0-9]+/v0.0.1/ if /x-release-please-version/' "$victim"

after=$(grep "x-release-please-version" "$victim" | head -1)
if [ "$before" = "$after" ]; then
  echo "fixture: el marcador no cambió — la rotura no se aplicó ($victim)" >&2
  exit 1
fi
grep -q "v0\.0\.1" <<<"$after" || { echo "fixture: el marcador no quedó en v0.0.1: $after" >&2; exit 1; }

echo "workdir=$TREE"
echo "expect=claims v0.0.1"
