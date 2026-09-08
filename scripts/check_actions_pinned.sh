#!/usr/bin/env bash
# check_actions_pinned.sh — toda referencia `uses:` de los workflows del
# PARAGUAS está fijada por SHA de commit y lleva su tag en el comentario.
#
# Por qué el SHA y no el tag: un tag de Git es un puntero móvil en un
# repositorio ajeno. Quien controle esa cuenta puede reapuntar `v7` a otro
# commit y ese commit corre dentro de nuestro CI con el token del repo, sin
# que aquí cambie una línea. El SHA de 40 hex no se puede reapuntar: nombra
# un árbol concreto.
#
# Por qué el comentario `# vX.Y.Z` es parte del contrato y no adorno: es lo
# que hace el pin MANTENIBLE. Dependabot (ecosistema github-actions) lee el
# comentario para saber en qué versión está el pin, y al proponer la subida
# reescribe SHA y comentario a la vez. Sin comentario el pin queda opaco:
# nadie sabe qué versión corre y el bot no tiene de dónde partir. Un pin sin
# mantenimiento es peor que un tag —se queda con los fallos de seguridad de
# su versión para siempre—, así que aquí se exigen las dos cosas juntas.
#
# Alcance: los workflows de ESTE repositorio. Los de nucleus, quark y orbit
# los fija cada producto en su propio PR del arco A3; el paraguas no reescribe
# ficheros del submódulo.
set -uo pipefail
cd "$(dirname "$0")/.."

DIR=${1:-.github/workflows}
status=0
refs=0
files=0

if [ ! -d "$DIR" ]; then
  echo "FAIL: no existe el directorio de workflows $DIR" >&2
  exit 2
fi

for f in "$DIR"/*.yml "$DIR"/*.yaml; do
  [ -e "$f" ] || continue
  files=$((files + 1))
  # Sólo las líneas de acción (`uses:` como clave), no las menciones en prosa
  # de los comentarios: el patrón exige la clave al principio del token.
  while IFS=: read -r lineno rest; do
    ref=$(printf '%s\n' "$rest" | sed -e 's/^[[:space:]]*-\{0,1\}[[:space:]]*uses:[[:space:]]*//' -e 's/[[:space:]]*$//')
    [ -n "$ref" ] || continue
    refs=$((refs + 1))
    target=${ref%%[[:space:]]*}
    comment=$(printf '%s\n' "$ref" | sed -n 's/^[^[:space:]]*[[:space:]]*//p')

    case "$target" in
      ./*|.)
        # Acción local del propio repositorio: viaja en el checkout, no hay
        # nada ajeno que fijar.
        continue
        ;;
      docker://*)
        if ! printf '%s\n' "$target" | grep -qE '@sha256:[0-9a-f]{64}$'; then
          echo "FAIL: $f:$lineno — «$target» es una imagen sin digest; fíjala con @sha256:<64 hex>" >&2
          status=1
        fi
        continue
        ;;
    esac

    if ! printf '%s\n' "$target" | grep -qE '@[0-9a-f]{40}$'; then
      echo "FAIL: $f:$lineno — «$target» no está fijada por SHA de commit; usa owner/accion@<40 hex> # <tag> (resuelve el tag con: gh api repos/<owner>/<accion>/commits/<tag> --jq .sha)" >&2
      status=1
      continue
    fi
    if ! printf '%s\n' "$comment" | grep -qE '^#[[:space:]]*v?[0-9][A-Za-z0-9._+-]*'; then
      echo "FAIL: $f:$lineno — «$target» está fijada por SHA pero sin el comentario «# <tag>»; Dependabot lo lee para mantener el pin, y sin él nadie sabe qué versión corre" >&2
      status=1
    fi
  done <<EOF
$(grep -nE '^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*[^[:space:]]' "$f")
EOF
done

if [ "$refs" -eq 0 ]; then
  echo "FAIL: $DIR no contiene ninguna referencia «uses:» — ¿ruta equivocada o workflows renombrados?" >&2
  exit 2
fi

[ "$status" -eq 0 ] && echo "OK: $refs referencias «uses:» en $files workflows, todas fijadas por SHA con su tag en el comentario"
exit $status
