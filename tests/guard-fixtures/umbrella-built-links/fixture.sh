#!/usr/bin/env bash
# Fixture de umbrella-built-links.
#
# Rotura: DOS páginas sonda en el build dir, una por cada clase que el guard
# comprueba:
#   - probe-edit:     un «Edit this page» a una ruta que NO existe en el repo
#                     nucleus (la clase exacta que vivió meses en producción),
#   - probe-internal: un enlace interno /quantum/… a una página no construida.
# El expect exige AMBAS líneas: si alguien rompiera solo una de las dos
# comprobaciones, el harness lo cazaría.
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
# El recuento prueba que AMBAS clases se cazaron (1 enlace a repo + 1 interno):
# si alguien rompiera una de las dos comprobaciones, el guard vería 1 y el
# harness moriría aquí. Mismo patrón que la fixture de jerga servida.
echo "expect=2 enlace\(s\) rotos en el sitio construido"
# Y la archivada se ve, como aviso, en la misma corrida.
echo "expect=doc ARCHIVADA"
