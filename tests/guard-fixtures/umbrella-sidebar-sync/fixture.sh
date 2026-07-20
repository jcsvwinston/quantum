#!/usr/bin/env bash
# Fixture de umbrella-sidebar-sync.
#
# Rotura: el espejo website/sidebarsNucleus.ts pierde UN id de documento que el
# sidebar del producto (nucleus/website/sidebars.ts) sí tiene — la deriva
# silenciosa exacta de QM7-4: página servida pero invisible en la navegación
# del paraguas tras un re-pin. Se borra la primera línea-id del espejo (una
# string entrecomillada sin espacios, fuera de claves de presentación), sea
# cual sea — la fixture no depende de un id concreto.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" \
  scripts/check_sidebar_sync.sh \
  website/sidebarsNucleus.ts \
  website/sidebarsQuark.ts \
  nucleus/website/sidebars.ts \
  quark/website/sidebars.ts

mirror="$TREE/website/sidebarsNucleus.ts"
# Primera línea que es SOLO un id ('ruta/doc',) — la misma forma que parsea la
# heurística del guard.
line=$(grep -nE "^[[:space:]]*'[^' ]+',?[[:space:]]*$" "$mirror" | head -1 | cut -d: -f1)
if [[ -z "$line" ]]; then
  echo "fixture: no se encontró ninguna línea-id en $mirror (¿cambió el formato del espejo?)" >&2
  exit 1
fi
sed "${line}d" "$mirror" > "$mirror.tmp"
mv "$mirror.tmp" "$mirror"

echo "workdir=$TREE"
echo "expect=ids que faltan en el espejo"
