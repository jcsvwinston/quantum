#!/usr/bin/env bash
# Fixture de umbrella-built-links.
#
# Rotura: DOS páginas sonda en el build dir, una por cada clase que el guard
# comprueba:
#   - probe-edit:     un «Edit this page» a una ruta que NO existe en el repo
#                     nucleus (la clase exacta que vivió meses en producción),
#   - probe-internal: un enlace interno /quantum/… a una página no construida,
#   - probe.js:       un bundle con un `href:"guides/frameworks"` RELATIVO (la
#                     clase que el HTML no enseña: QM-45, 2026-11-16).
# El expect exige las TRES: si alguien rompiera solo una de las comprobaciones,
# el harness lo cazaría.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_built_links.sh

# El guard resuelve las rutas contra el checkout de cada repo: basta con que el
# directorio exista para que la comprobación sea significativa (la ruta
# enlazada, en cambio, no existe).
mkdir -p "$TREE/nucleus" "$TREE/quark" "$TREE/orbit"

mkdir -p "$TREE/website/build/probe-edit" "$TREE/website/build/probe-internal"
cat > "$TREE/website/build/index.html" <<'HTML'
<html><body><p>root</p></body></html>
HTML
cat > "$TREE/website/build/probe-edit/index.html" <<'HTML'
<html><body><a href="https://github.com/jcsvwinston/nucleus/edit/main/website/docs/no-existe.md">Edit this page</a></body></html>
HTML
cat > "$TREE/website/build/probe-internal/index.html" <<'HTML'
<html><body><a href="/quantum/pagina-que-no-existe/">interno</a></body></html>
HTML
# El bundle sonda lleva un href absoluto, uno con esquema y uno con ancla (que
# NO cuentan) y un relativo (que SÍ): sólo el relativo tiene que aparecer.
mkdir -p "$TREE/website/build/assets/js"
cat > "$TREE/website/build/assets/js/probe.js" <<'JS'
e("a",{href:"/quantum/quark/intro"}),e("a",{href:"https://example.invalid/x"}),e("a",{href:"#top"}),e("a",{href:"guides/frameworks"})
JS

# Tercera sonda: el MISMO enlace roto, pero emitido desde una página de
# documentación ARCHIVADA. Ésa no se reescribe —la copia es de cuando la ruta
# existía—, así que el guard debe AVISAR y no contarla entre las que tumban la
# certificación. Si alguien la contara, el recuento del expect subiría a 3 y el
# harness moriría aquí.
mkdir -p "$TREE/website/build/nucleus/1.15.0/getting-started"
cat > "$TREE/website/build/nucleus/1.15.0/getting-started/index.html" <<'HTML'
<html><body><a href="https://github.com/jcsvwinston/nucleus/tree/main/examples/mvc_api">examples/mvc_api</a></body></html>
HTML

echo "workdir=$TREE"
# El recuento prueba que las TRES clases se cazaron (1 enlace a repo + 1
# interno + 1 relativo en el bundle): si alguien rompiera una de las
# comprobaciones, el guard vería 2 y el harness moriría aquí. Mismo patrón que
# la fixture de jerga servida.
echo "expect=3 enlace\(s\) rotos en el sitio construido"
echo "expect=relativo en el MDX compilado: href 'guides/frameworks'"
# Y la archivada se ve, como aviso, en la misma corrida.
echo "expect=doc ARCHIVADA"
