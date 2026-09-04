#!/usr/bin/env bash
# check_served_jargon.sh — el gate de docs se pasa sobre lo que el lector VE.
#
# La 5ª auditoría (QM5-1) encontró que el sitio publicado servía por defecto
# snapshots viejos cargados de vocabulario interno mientras el linter de docs
# juraba «0 fugas»: el linter leía la FUENTE (website/docs, la doc "Next") y el
# lector veía OTRA cosa (el último snapshot versionado). Este check corre tras
# `npm run build` y escanea el HTML emitido — la superficie real — con la misma
# regex de jerga que usan los linters de fuente de los tres productos.
#
# Falla el build ante cualquier hit fuera de la lista de exclusiones. La lista
# existe SOLO como transición: los snapshots servidos se limpiaron en sus repos
# fuente, pero el paraguas los ensambla desde el submódulo PINADO, y el pin no
# avanza hasta re-certificar el set. Al re-pinar, esta lista debe quedar VACÍA.
#
# Verde-vacío vetado (QM8-4): un build dir que existe pero no contiene NINGÚN
# HTML no es «0 fugas» — es que no hay superficie que escanear (build roto o
# ruta equivocada). 0 ficheros escaneados es FAIL con su causa.
set -uo pipefail

cd "$(dirname "$0")/.."

BUILD_DIR="${1:-website/build}"

if [[ ! -d "$BUILD_DIR" ]]; then
  echo "check_served_jargon: $BUILD_DIR no existe — ejecuta 'npm run build' antes" >&2
  exit 2
fi

# La alternancia (QK|NU|OR|QM)[0-9]+-[0-9]+ veta los IDs de hallazgo de
# auditoría (QK5-2, NU7-1, …) en el HTML servido — 7ª ronda, regla espejo de
# la de orbit: la voz de producto describe el cambio, nunca el expediente.
REGEX='ADR-[0-9]+|\bP[0-3]\b|SPEC\.md|CLAUDE\.md|V1_GATE|TASKS\.md|PROFILING\.md|BACKLOG|\b(QK|NU|OR|QM)[0-9]+-[0-9]+\b'

# Rutas de snapshot excluidas (ver cabecera). VACÍA desde el re-pin de Quantum
# 1.7.1: los submódulos pinan tags con la limpieza de snapshots (quark v1.3.1,
# nucleus v1.3.2), así que TODO lo servido queda bajo el gate, sin excepciones.
# Solo debe repoblarse como transición documentada si vuelve a servirse un
# snapshot anterior a esa limpieza.
EXCLUDES=()

# Transición AUTO-EXPIRANTE (auditoría 2026-08-30, quantum#119 + nucleus#397):
# el pin v1.21.0 de nucleus trae «ADR-010» en comentarios de examples/mvc_api,
# y remark-code-import (quantum#119) ahora sirve ese código dentro de las
# páginas de getting-started. nucleus#397 reescribe los comentarios en prosa
# en main, pero el paraguas ensambla desde el submódulo PINADO. La excepción
# solo aplica mientras modules.nucleus siga en v1.21.0: al re-pinar, muere
# sola — sin lista que recordar vaciar.
#
# Segunda transición, misma forma (set 1.26.1, 2026-09-04): el pin v1.23.1 de
# nucleus trae «ADR-031» en el comentario del driver de examples/mvc_api/main.go,
# que el quickstart de TODAS las versiones del sitio incrusta. nucleus#465 lo
# reescribe en prosa y sale en v1.23.2 (solo documentación); re-pinar a
# v1.23.2 en este set habría exigido tres cortes más de orbit (manifest-guard
# §5: sus módulos requieren nucleus v1.23.1). La excepción vive mientras el pin
# sea v1.23.1 y muere sola en el siguiente re-pin, como la de ADR-010.
NUCLEUS_PIN=$(sed -n 's/^  nucleus:[[:space:]]*"\(v[0-9.]*\)".*/\1/p' versions.yaml | head -1)
TRANSITIONAL_TOKEN=''
if [[ "$NUCLEUS_PIN" == "v1.21.0" ]]; then
  TRANSITIONAL_TOKEN='ADR-010'
elif [[ "$NUCLEUS_PIN" == "v1.23.1" ]]; then
  TRANSITIONAL_TOKEN='ADR-031'
fi

# ${arr[@]+...} para que la lista VACÍA (el estado final tras el re-pin) no
# tropiece con set -u en bash 3.2 (macOS).
find_args=("$BUILD_DIR" -name '*.html')
for e in ${EXCLUDES[@]+"${EXCLUDES[@]}"}; do
  find_args+=(-not -path "$BUILD_DIR/$e/*")
done

status=0
count=0
scanned=0
while IFS= read -r -d '' f; do
  scanned=$((scanned + 1))
  out=$(grep -noE "$REGEX" "$f" || true)
  # La transición de arriba: solo el token exacto, solo en las páginas de
  # getting-started de la instancia de nucleus (el resto de la página sigue
  # bajo el gate completo).
  if [[ -n "$TRANSITIONAL_TOKEN" && "$f" == *"/nucleus/"*"getting-started/"* ]]; then
    out=$(grep -v ":${TRANSITIONAL_TOKEN}\$" <<<"$out" || true)
  fi
  out=$(head -3 <<<"$out")
  if [[ -n "$out" ]]; then
    if [[ $status -eq 0 ]]; then
      echo "Vocabulario interno en el HTML servido:" >&2
      echo >&2
    fi
    status=1
    count=$((count + 1))
    printf '  %s\n%s\n' "$f" "$(sed 's/^/    /' <<<"$out")" >&2
  fi
done < <(find "${find_args[@]}" -print0)

if [[ $status -ne 0 ]]; then
  echo >&2
  echo "$count página(s) servidas contienen jerga interna. La fuente está en el" >&2
  echo "repo del producto (website/docs o versioned_docs del snapshot): límpiala" >&2
  echo "allí — este check no se pasa editando el HTML." >&2
  exit 1
fi

# QM8-4: 0 HTML escaneados no es un sitio limpio, es un sitio ausente.
if [[ $scanned -eq 0 ]]; then
  echo "FAIL: 0 ficheros HTML escaneados en $BUILD_DIR — build vacío o ruta equivocada; un «0 fugas» sin superficie escaneada es verde-vacío, no un veredicto (QM8-4)" >&2
  exit 1
fi

n_excl=${EXCLUDES[@]+${#EXCLUDES[@]}}
echo "OK: 0 fugas de jerga en el HTML servido ($scanned HTML escaneados en $BUILD_DIR; ${n_excl:-0} rutas de snapshot excluidas transitoriamente)"
