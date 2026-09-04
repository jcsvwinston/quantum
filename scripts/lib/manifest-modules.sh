#!/usr/bin/env bash
# manifest-modules.sh — de la CLAVE del manifiesto a la RUTA del módulo.
#
# versions.yaml declara los módulos hermanos por su último segmento de ruta
# (`sqlite`, `otlp`, `storage-s3`, `quarkbridge`…) y NO por su ruta completa,
# que en los repos es `drivers/sqlite`, `exporters/otlp`,
# `providers/storage-s3`. Quien necesite la ruta (el bloque require de
# print-requires.sh, los comentarios de pin de bump-set.sh, el guard del
# go.work) la DESCUBRE aquí del árbol del submódulo — no de una tabla escrita a
# mano, que es lo que dejó a print-requires emitiendo `providers/mssql` y
# `providers/otlp` para módulos que nunca vivieron ahí (auditoría 2026-09-03,
# QM-1): la lista fija sabía de un solo módulo hermano y el árbol tenía doce.
#
# El filtro de descubrimiento es el MISMO que aplica manifest-guard §3b (y
# scripts/check_gowork_covers_manifest.sh): todo go.mod del repo salvo los de
# examples/, website/, benchmarks/ y bugbash/ es un módulo del que el set
# responde. Si ese filtro cambia, cambia en los dos sitios.
#
# Compatibilidad: bash 3.2 (macOS) — sin arrays asociativos.

# mm_manifest — ruta del manifiesto; sobreescribible para fixtures.
: "${MM_MANIFEST:=versions.yaml}"

# mm_keys <bloque> — claves de un bloque de nivel superior, en orden del fichero.
mm_keys() {
  awk -v blk="$1" '
    /^[a-z_]+:/ { inblk = ($0 ~ "^" blk ":") }
    inblk && /^  [a-zA-Z0-9_-]+:/ {
      line = $0; sub(/^  /, "", line); sub(/:.*/, "", line); print line
    }' "$MM_MANIFEST"
}

# mm_val <bloque> <clave> — valor entrecomillado de una clave del bloque.
mm_val() {
  awk -v blk="$1" -v key="$2" '
    /^[a-z_]+:/ { inblk = ($0 ~ "^" blk ":") }
    inblk && $0 ~ "^  " key ":" {
      if (match($0, /"[^"]+"/)) { print substr($0, RSTART + 1, RLENGTH - 2); exit }
    }' "$MM_MANIFEST"
}

# mm_discover <repo> — rutas (relativas al repo, sin `./`) de todo go.mod
# publicable del árbol, la raíz excluida, ordenadas.
mm_discover() {
  local repo=$1
  (cd "$repo" && find . -name go.mod \
      -not -path './examples/*' -not -path './website/*' \
      -not -path './benchmarks/*' -not -path './bugbash/*' -not -path './.git/*' \
    | sed 's|/go.mod$||; s|^\./||' | grep -v '^\.$' | sort)
}

# mm_path_for_key <repo> <clave> — la ruta cuyo último segmento es la clave.
# Vacío si no hay ninguna (el manifiesto declara un módulo que el árbol no
# tiene); EXIT 1 y mensaje si hay MÁS de una (ambigüedad: el manifiesto no
# podría distinguirlas y el esquema de claves habría que cambiarlo).
mm_path_for_key() {
  local repo=$1 key=$2 hits
  hits=$(mm_discover "$repo" | awk -v k="$key" -F/ '$NF == k')
  if [ "$(printf '%s\n' "$hits" | grep -c .)" -gt 1 ]; then
    echo "manifest-modules: la clave '$key' casa con varios módulos en $repo: $(printf '%s' "$hits" | tr '\n' ' ')" >&2
    return 1
  fi
  printf '%s\n' "$hits"
}

# mm_module_path <repo> <clave> — ruta de importación completa
# (github.com/jcsvwinston/<repo>/<ruta>). Falla si la clave no resuelve.
mm_module_path() {
  local repo=$1 key=$2 dir
  dir=$(mm_path_for_key "$repo" "$key") || return 1
  if [ -z "$dir" ]; then
    echo "manifest-modules: la clave '$key' del bloque ${repo}_modules no corresponde a ningún go.mod en $repo/ (¿módulo declarado que el árbol no tiene, o submódulo sin inicializar?)" >&2
    return 1
  fi
  printf 'github.com/jcsvwinston/%s/%s\n' "$repo" "$dir"
}
