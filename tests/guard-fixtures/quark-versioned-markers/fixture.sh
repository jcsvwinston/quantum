#!/usr/bin/env bash
# Fixture de quark-versioned-markers.
#
# Rotura: se baja el marcador `x-release-please-version` de un snapshot a una
# versión que no es la suya — la forma exacta en que salió el defecto aquí. El
# marcador lo sube release-please en la rama del release, así que un snapshot
# cortado antes de ese bump congela la versión anterior y la publica como si
# fuera la suya: el archivo de 1.6.0 anunciaba «Quark is v1.5.2».
#
# Sólo se ve desde fuera, y ningún otro guard lo mira, porque la copia es
# coherente CONSIGO MISMA. El guard debe morir nombrando el fichero, lo que
# afirma y lo que debería.
#
# Árbol completo del repo: el guard se ancla a su propia ubicación
# (dirname/../..) y recorre website/versioned_docs/.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy_tree "$ROOT/quark" "$TREE"

# Víctima: el primer fichero con marcador de cualquier snapshot versionado.
victim=$(grep -rl "x-release-please-version" "$TREE"/website/versioned_docs/version-* 2>/dev/null | head -1)
[ -n "$victim" ] || { echo "fixture: ningún snapshot lleva el marcador — ¿cambió el árbol?" >&2; exit 1; }

before=$(grep "x-release-please-version" "$victim" | head -1)

# Sustituye la versión de la línea del marcador por una que no puede ser la
# del snapshot. El marcador va DETRÁS de la versión en la línea
# (`> v1.11.0 {/* x-release-please-version */}`), así que se sustituye la
# PRIMERA versión de la línea marcada: escribirlo al revés no rompe nada y
# dejaría la fixture en verde sin haber roto el árbol — por eso comprueba
# abajo que el marcador cambió de verdad.
perl -i -pe 's/v[0-9]+\.[0-9]+\.[0-9]+/v0.0.1/ if /x-release-please-version/' "$victim"

after=$(grep "x-release-please-version" "$victim" | head -1)
if [ "$before" = "$after" ]; then
  echo "fixture: el marcador no cambió — la rotura no se aplicó ($victim)" >&2
  exit 1
fi
grep -q "v0\.0\.1" <<<"$after" || { echo "fixture: el marcador no quedó en v0.0.1: $after" >&2; exit 1; }

echo "workdir=$TREE"
echo "expect=afirma v0.0.1, pero es el snapshot de"
