#!/usr/bin/env bash
# Construye el playground de consultas de quark (quark compilado a WebAssembly)
# para que el sitio unificado lo sirva en /quark-playground/. La fuente vive en
# el submódulo quark AL PIN (QADR-0003: el sitio ensambla, no posee); el pin
# anterior a la sesión DX-Q4 no trae el script, y entonces no hay nada que
# construir ni página que lo referencie: se sale en silencio con 0.
#
# Uso: bash scripts/build_quark_playground.sh [dir-de-salida]
#   dir-de-salida: por defecto website/static/quark-playground (gitignored).
#
# El presupuesto de peso (gzip ≤ 3,5 MB) lo aplica el propio script de quark,
# que falla si el .wasm engorda: aquí no se duplica la cifra.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=${1:-website/static/quark-playground}
BUILDER=quark/scripts/ci/build_playground.sh
if [ ! -f "$BUILDER" ]; then
  echo "build_quark_playground: el pin de quark no trae $BUILDER (anterior a DX-Q4); nada que construir" >&2
  exit 0
fi
command -v go >/dev/null || { echo "build_quark_playground: falta go en el PATH (el workflow debe traer setup-go)" >&2; exit 1; }

mkdir -p "$OUT"
# Ruta absoluta: el script de quark se ejecuta desde su propio módulo.
OUT_ABS=$(cd "$OUT" && pwd)
bash "$BUILDER" "$OUT_ABS"
ls -l "$OUT_ABS"
