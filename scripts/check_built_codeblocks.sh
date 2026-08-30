#!/usr/bin/env bash
# check_built_codeblocks.sh — ningún bloque de código VACÍO en el HTML servido.
#
# SD-01 (9ª ronda): el quickstart de nucleus se publicó con sus 3 bloques de
# código vacíos — 56 bloques en 28 páginas, snapshots versionados incluidos —
# porque las fences ```go file=<rootDir>/…``` de sus docs las resuelve
# remark-code-import SOLO donde el config lo cablea: el sitio standalone de
# nucleus lo tenía y el ensamblaje del paraguas no. Docusaurus no avisa: emite
# <code class="codeBlockLines_…"></code> y el build sale verde. Este check
# corre tras `npm run build` y escanea el HTML emitido — la superficie real,
# la misma disciplina que check_served_jargon.sh — buscando exactamente esa
# clase de hueco.
#
# Verde-vacío vetado (QM8-4), en dos capas:
#   - 0 ficheros HTML escaneados → FAIL (build vacío o ruta equivocada).
#   - 0 bloques de código EN TOTAL → FAIL (si el tema de Docusaurus renombrara
#     la clase codeBlockLines, el selector quedaría ciego y su «0 vacíos»
#     sería un fósil, no un veredicto).
set -uo pipefail

cd "$(dirname "$0")/.."

BUILD_DIR="${1:-website/build}"

if [[ ! -d "$BUILD_DIR" ]]; then
  echo "check_built_codeblocks: $BUILD_DIR no existe — ejecuta 'npm run build' antes" >&2
  exit 2
fi

# Un bloque de código emitido por el tema es <code class="codeBlockLines_<hash>">.
# El hash del CSS-module cambia entre versiones del tema: se matchea el prefijo,
# nunca un hash concreto.
BLOCK_RE='<code class="codeBlockLines[^"]*">'
EMPTY_RE='<code class="codeBlockLines[^"]*"></code>'

status=0
scanned=0
blocks_total=0
empty_total=0
empty_pages=0
while IFS= read -r -d '' f; do
  scanned=$((scanned + 1))
  n_blocks=$(grep -oE "$BLOCK_RE" "$f" | wc -l | tr -d ' ')
  blocks_total=$((blocks_total + n_blocks))
  n_empty=$(grep -oE "$EMPTY_RE" "$f" | wc -l | tr -d ' ')
  if [[ $n_empty -gt 0 ]]; then
    if [[ $status -eq 0 ]]; then
      echo "Bloques de código vacíos en el HTML servido:" >&2
      echo >&2
    fi
    status=1
    empty_pages=$((empty_pages + 1))
    empty_total=$((empty_total + n_empty))
    printf '  %s (%s bloque(s) vacío(s))\n' "$f" "$n_empty" >&2
  fi
done < <(find "$BUILD_DIR" -name '*.html' -print0)

if [[ $status -ne 0 ]]; then
  echo >&2
  echo "$empty_total bloque(s) de código vacíos en $empty_pages página(s) del HTML servido." >&2
  echo "La causa típica es una fence \`\`\`lang file=…\`\`\` sin resolver: el plugin" >&2
  echo "remark-code-import no está cableado (o perdió su rootDir) en la instancia" >&2
  echo "correspondiente de website/docusaurus.config.ts. Este check no se pasa" >&2
  echo "editando el HTML: arregla el cableado o la fence en el repo fuente." >&2
  exit 1
fi

# QM8-4, capa 1: 0 HTML escaneados no es un sitio limpio, es un sitio ausente.
if [[ $scanned -eq 0 ]]; then
  echo "FAIL: 0 ficheros HTML escaneados en $BUILD_DIR — build vacío o ruta equivocada; un «0 vacíos» sin superficie escaneada es verde-vacío, no un veredicto (QM8-4)" >&2
  exit 1
fi

# QM8-4, capa 2: si NINGÚN bloque de código matchea el selector, el tema cambió
# de clase y este guard quedó ciego — eso es un guard muerto, no un sitio sano.
if [[ $blocks_total -eq 0 ]]; then
  echo "FAIL: 0 bloques de código reconocidos en $scanned HTML — el selector codeBlockLines ya no matchea el tema (¿cambió la clase en el upgrade de Docusaurus?); un «0 vacíos» con el selector ciego es verde-vacío, no un veredicto (QM8-4)" >&2
  exit 1
fi

echo "OK: 0 bloques de código vacíos en el HTML servido ($scanned HTML escaneados, $blocks_total bloques de código reconocidos en $BUILD_DIR)"
