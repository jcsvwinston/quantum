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
# Por eso el guard comprueba las DOS mitades de la misma decisión: los pines
# de los workflows y que `.github/dependabot.yml` siga declarando el
# ecosistema `github-actions` que los mueve. Borrar ese bloque es un cambio de
# tres líneas que no rompe ninguna corrida y deja los pines congelados.
#
# Alcance: los workflows de ESTE repositorio. Los de nucleus, quark y orbit
# los fija cada producto en su propio PR del arco A3; el paraguas no reescribe
# ficheros del submódulo. Del bloque de Dependabot comprueba que EXISTE, no su
# contenido: la deriva realista es que desaparezca, no que se afine mal.
#
# LO QUE ESTA REGLA NO ALCANZA (excepción real, no hipótesis). Fijar el SHA de
# una acción fija su ÁRBOL, y para una acción JavaScript o compuesta eso es
# todo el código que corre. Para una acción DOCKER no: su `action.yaml` dice
# qué imagen ejecuta, y si la nombra por tag, el tag se puede reapuntar sin
# que el SHA cambie. El paraguas tiene hoy un caso, `ossf/scorecard-action`:
# su action.yaml al SHA fijado dice
#   runs: {using: docker, image: "docker://ghcr.io/ossf/scorecard-action:v2.4.4"}
# —un tag de ghcr.io—. El pin congela los metadatos; el contenedor lo trae el
# runner por tag. Este guard no puede verlo (leer el action.yaml ajeno exige
# red, y un guard no sale a la red), así que la excepción se sostiene por
# escrito: docs/AUDITORIA_CONTINUA.md §8 la nombra, dice la exposición que
# queda y las salidas que existen. Las otras siete referencias del paraguas no
# la tienen: seis son `using: node24` y `actions/upload-pages-artifact` es
# compuesta y fija por SHA su propio upload-artifact.
#
# Dónde muerde: `scripts/suite-integral.sh` (registro de guards), que en CI
# corre desde `.github/workflows/suite-integral.yml` — cuyo filtro de rutas
# incluye '.github/workflows/**' y '.github/dependabot.yml' justamente para
# que este guard corra en el PR que puede deshacerlo, no una semana después.
set -uo pipefail
cd "$(dirname "$0")/.."

DIR=${1:-.github/workflows}
DEPENDABOT=${2:-.github/dependabot.yml}
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
  # La clave `uses:` se busca en CUALQUIER posición, no sólo como primer token
  # de la línea: la forma en flujo —`steps: [{uses: actions/checkout@v7}]`— es
  # YAML legal y con el patrón anclado se escapaba entera, que es un falso
  # negativo (un tag móvil pasando en verde). Las líneas que son sólo
  # comentario se descartan antes, para no confundir una mención en prosa con
  # una referencia. Se conserva el número de línea del fichero real.
  while IFS=: read -r lineno rest; do
    [ -n "$lineno" ] || continue
    # Una misma línea puede llevar más de un `uses:` en forma de flujo, así que
    # se parte por cada aparición.
    while IFS= read -r ref; do
      ref=$(printf '%s\n' "$ref" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
      [ -n "$ref" ] || continue
      refs=$((refs + 1))
      target=${ref%%[[:space:]]*}
      # En forma de flujo el valor arrastra el cierre del mapa/secuencia y las
      # comas; y puede venir entrecomillado en cualquiera de las dos formas.
      target=$(printf '%s\n' "$target" | sed -e 's/^["'"'"']//' -e 's/[]},"'"'"']*$//')
      comment=$(printf '%s\n' "$ref" | sed -n 's/^[^[:space:]]*[[:space:]]*//p')

      case "$target" in
        ./*|.)
          # Acción local del propio repositorio: viaja en el checkout, no hay
          # nada ajeno que fijar.
          continue
          ;;
        docker://*)
          # Imagen referida DIRECTAMENTE por un paso: aquí sí se puede exigir
          # el digest. Lo que este guard no ve es la imagen que una acción
          # ajena declara dentro de su propio action.yaml (ver la excepción de
          # la cabecera): eso vive en otro repositorio y sólo se sabe leyéndolo.
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
    done <<EOF2
$(printf '%s\n' "$rest" | awk '{ n = split($0, part, /uses:/); for (i = 2; i <= n; i++) print part[i] }')
EOF2
  done <<EOF
$(grep -nE '(^|[[:space:]{,])uses:[[:space:]]*[^[:space:]]' "$f" | grep -vE '^[0-9]+:[[:space:]]*#')
EOF
done

if [ "$refs" -eq 0 ]; then
  echo "FAIL: $DIR no contiene ninguna referencia «uses:» — ¿ruta equivocada o workflows renombrados?" >&2
  exit 2
fi

# La otra mitad: quien mueve el pin. Un pin por SHA que nadie sube congela
# también los fallos de seguridad de su versión —para siempre—, así que es
# peor que el tag móvil al que sustituyó. El bloque `github-actions` de
# Dependabot es lo que lo evita, y sin esta comprobación su borrado no rompe
# nada visible.
if [ ! -f "$DEPENDABOT" ]; then
  echo "FAIL: no existe $DEPENDABOT — los $refs pines por SHA quedan sin nadie que los suba, congelados con los fallos de seguridad de su versión (docs/AUDITORIA_CONTINUA.md §8)" >&2
  status=1
elif ! grep -qE '^[[:space:]]*-?[[:space:]]*package-ecosystem:[[:space:]]*"?'"'"'?github-actions'"'"'?"?[[:space:]]*$' "$DEPENDABOT"; then
  echo "FAIL: $DEPENDABOT no declara el ecosistema «github-actions» — el pin y el bot son una sola decisión: sin el bloque, los $refs pines se fosilizan con los fallos de seguridad de su versión (docs/AUDITORIA_CONTINUA.md §8)" >&2
  status=1
fi

[ "$status" -eq 0 ] && echo "OK: $refs referencias «uses:» en $files workflows, todas fijadas por SHA con su tag en el comentario; $DEPENDABOT declara el ecosistema github-actions que las mantiene"
exit $status
