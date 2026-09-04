#!/usr/bin/env bash
# Fixture de umbrella-gowork-covers-manifest.
#
# Rotura: el go.work pierde la línea `./nucleus/drivers/sqlite` — un módulo
# publicable del árbol de nucleus, declarado en nucleus_modules. Es la clase
# exacta que motivó el guard (QM-7, auditoría 2026-09-03): el go.work llevaba
# diez módulos con veinticinco certificados, y `go build` con módulos de menos
# sale igualmente con EXIT=0, así que nada lo veía.
#
# El árbol doctorado copia el go.work, el manifiesto, el guard con su lib, y
# SOLO los go.mod de los tres repos (el guard descubre módulos por la presencia
# del fichero; no necesita el código). Los go.mod se copian de la ruta real
# del submódulo al pin, así que si el árbol gana un módulo la fixture lo lleva
# sola.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_gowork_covers_manifest.sh scripts/lib/manifest-modules.sh go.work versions.yaml
for repo in quark nucleus orbit; do
  while IFS= read -r gm; do
    [[ -n "$gm" ]] || continue
    fx_copy "$ROOT" "$TREE" "$repo/${gm#./}"
  done < <(cd "$ROOT/$repo" && find . -name go.mod -not -path './.git/*' -not -path './website/*')
done

grep -v '^	\./nucleus/drivers/sqlite$' "$TREE/go.work" > "$TREE/go.work.tmp"
mv "$TREE/go.work.tmp" "$TREE/go.work"
if grep -q 'nucleus/drivers/sqlite' "$TREE/go.work"; then
  echo "fixture: la rotura no se aplicó — go.work sigue usando ./nucleus/drivers/sqlite" >&2
  exit 1
fi

echo "workdir=$TREE"
echo "expect=go.work no usa \./nucleus/drivers/sqlite"
