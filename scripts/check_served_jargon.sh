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
set -uo pipefail

cd "$(dirname "$0")/.."

BUILD_DIR="${1:-website/build}"

if [[ ! -d "$BUILD_DIR" ]]; then
  echo "check_served_jargon: $BUILD_DIR no existe — ejecuta 'npm run build' antes" >&2
  exit 2
fi

REGEX='ADR-[0-9]+|\bP[0-3]\b|SPEC\.md|CLAUDE\.md|V1_GATE|TASKS\.md|PROFILING\.md|BACKLOG'

# Rutas de snapshot excluidas TRANSITORIAMENTE (ver cabecera). Cada entrada es
# un directorio bajo BUILD_DIR. Vaciar esta lista al re-pinar los submódulos a
# tags que contengan la limpieza de snapshots (quark > v1.3.0, nucleus > v1.3.1).
EXCLUDES=(
  "quark/1.0.0"
  "quark/1.1.0"
  "quark/1.2.2"
  "nucleus/1.0.0"
  "nucleus/1.2.0"
)

# ${arr[@]+...} para que la lista VACÍA (el estado final tras el re-pin) no
# tropiece con set -u en bash 3.2 (macOS).
find_args=("$BUILD_DIR" -name '*.html')
for e in ${EXCLUDES[@]+"${EXCLUDES[@]}"}; do
  find_args+=(-not -path "$BUILD_DIR/$e/*")
done

status=0
count=0
while IFS= read -r -d '' f; do
  if out=$(grep -noE "$REGEX" "$f" | head -3); then
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

n_excl=${EXCLUDES[@]+${#EXCLUDES[@]}}
echo "OK: 0 fugas de jerga en el HTML servido ($BUILD_DIR; ${n_excl:-0} rutas de snapshot excluidas transitoriamente)"
