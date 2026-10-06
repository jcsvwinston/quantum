#!/usr/bin/env bash
# check_generated_pages.sh — lo que el sitio publica como generado del pin es lo que el pin da.
#
# El arco A11 (W4) puso en el sitio tres familias de páginas que NADIE escribe
# a mano, porque cada una repite algo que ya vive en otro sitio y se quedaría
# vieja en cuanto ese otro sitio se moviera:
#
#   - la referencia de la API congelada de cada producto
#     (website/docs/reference/api-*.md), sacada de los ficheros con los que el
#     CI de cada producto compara su código: nucleus y orbit
#     contracts/baseline/api_exported_symbols.txt, quark
#     acceptance/apisurface.json;
#   - el catálogo de `nucleus add` (website/docs/reference/catalog.md), sacado
#     de la tabla que lee el CLI, nucleus/internal/knownproviders;
#   - un post por set certificado (website/releases/), sacado de los tags de
#     suite y de versions.yaml.
#
# Las escribe scripts/lib/site-pages.py; este guard lo corre con --check, que
# las regenera en memoria y falla con la deriva: una página que no es lo que
# su fuente al pin dice, una que falta, una que sobra en un directorio que es
# del generador. El caso que motivó el guard es el del tren: un re-pin mueve
# las fuentes y el sitio seguiría publicando la API y el catálogo del set
# anterior; y un set nuevo sin su post. bump-set.sh corre el generador, así
# que el PR de set ya los lleva; si alguien lo salta, este guard pone el PR
# rojo (y la certificación, que corre el registro entero) hasta que estén.
#
# Las fuentes de los productos se leen AL PIN (los submódulos tal y como los
# fija versions.yaml). Los posts necesitan los tags de suite del paraguas: en
# CI, checkout con fetch-depth: 0. Sin ningún tag FALLA, no pasa: comparar
# cero posts con cero posts sería un verde vacío.
#
# Cuando falle: regenera con `python3 scripts/lib/site-pages.py` y commitea.
# Si el generador no sabe leer la fuente (la tabla del catálogo cambió de
# forma, un fichero congelado cambió de formato), lo dice con fichero y línea:
# se amplía el lector, no se edita la página.
#
# Uso: bash scripts/check_generated_pages.sh [api|catalog|releases]...
#      (sin argumentos, las tres familias; las sondas del banco del sitio
#      piden una cada una)
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: generated-pages — python3 no está en el PATH: sin él no hay con qué regenerar las páginas para compararlas" >&2
  exit 1
fi
python3 scripts/lib/site-pages.py --check "$@"
