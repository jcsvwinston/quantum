#!/usr/bin/env bash
# check_sidebar_sync.sh — las sidebars espejadas no pueden derivar del producto.
#
# La 7ª auditoría (QM7-4) señaló que website/sidebarsNucleus.ts y
# website/sidebarsQuark.ts son COPIAS manuales del sidebar curado de cada
# producto: si el producto añade una página a su sidebar y el paraguas re-pina
# el submódulo, la página se sirve pero queda invisible en la navegación del
# paraguas — exactamente la clase de deriva silenciosa que ningún build rompe.
#
# Este check compara el CONJUNTO de ids de documento del espejo con el del
# sidebar del submódulo pinado. Ambos ficheros se parsean con la MISMA
# heurística (strings entrecomilladas sin espacios, fuera de las claves de
# presentación label/title/description/type/dirName), así que el ruido
# estructural se cancela: lo que queda son los ids. Orbit no participa — su
# sidebar del paraguas es autogenerado desde el directorio de docs y no puede
# derivar.
#
# Falla (EXIT=1) ante cualquier id presente en un lado y ausente en el otro,
# nombrando el fichero y la dirección de la deriva. Requiere submódulos
# inicializados (el mismo requisito que el build del sitio).
set -uo pipefail

cd "$(dirname "$0")/.."

# extract_ids <fichero.ts> — ids de documento del sidebar, uno por línea, orden
# alfabético. Heurística compartida por espejo y producto (ver cabecera).
extract_ids() {
  grep -v -E 'label:|title:|description:|type:|dirName|import |SidebarsConfig' "$1" \
    | grep -oE "'[^' ]+'" \
    | tr -d "'" \
    | sort -u
}

status=0
for pair in "website/sidebarsNucleus.ts:nucleus/website/sidebars.ts" \
            "website/sidebarsQuark.ts:quark/website/sidebars.ts"; do
  mirror="${pair%%:*}"
  product="${pair##*:}"

  if [[ ! -f "$product" ]]; then
    echo "check_sidebar_sync: $product no existe — inicializa los submódulos (git submodule update --init)" >&2
    exit 2
  fi

  mirror_ids=$(extract_ids "$mirror")
  product_ids=$(extract_ids "$product")

  only_product=$(comm -13 <(printf '%s\n' "$mirror_ids") <(printf '%s\n' "$product_ids"))
  only_mirror=$(comm -23 <(printf '%s\n' "$mirror_ids") <(printf '%s\n' "$product_ids"))

  if [[ -n "$only_product" ]]; then
    status=1
    echo "FAIL: $product tiene ids que faltan en el espejo $mirror (página servida pero invisible en la navegación del paraguas):" >&2
    printf '  %s\n' $only_product >&2
  fi
  if [[ -n "$only_mirror" ]]; then
    status=1
    echo "FAIL: $mirror tiene ids que no existen en $product (entrada de navegación rota tras el re-pin):" >&2
    printf '  %s\n' $only_mirror >&2
  fi
done

if [[ $status -eq 0 ]]; then
  echo "OK: sidebars espejadas sincronizadas con los sidebars de los submódulos pinados (nucleus, quark)"
fi
exit $status
