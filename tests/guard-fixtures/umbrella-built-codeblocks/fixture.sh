#!/usr/bin/env bash
# Fixture de umbrella-built-codeblocks.
#
# Rotura: el build dir servido contiene una página sonda con DOS bloques de
# código del tema (clase codeBlockLines_<hash>): uno LLENO y uno VACÍO — la
# firma exacta que dejó SD-01 (fence ```go file=<rootDir>/…``` sin
# remark-code-import cableado en el ensamblaje: Docusaurus emite <code></code>
# y el build sale verde). El bloque LLENO importa: garantiza que el guard muere
# por la regla de bloques vacíos (la esencia del guard) y no por la capa
# anti-verde-vacío de «0 bloques reconocidos».
#
# Las precondiciones QM8-4 (0 HTML escaneados → FAIL; 0 bloques reconocidos →
# FAIL) NO caben en este árbol: son mutuamente excluyentes con la sonda (un
# build no puede a la vez estar vacío y contener el bloque hueco), y el harness
# ejecuta UNA fixture por guard. La rotura elegida como permanente es la del
# bloque vacío; los dos negativos de QM8-4 se probaron por comando en su ronda
# (dir sin HTML → EXIT=1 «verde-vacío»; HTML sin codeBlockLines → EXIT=1
# «selector ciego») y su regresión la delataría esta misma fixture: si el
# escaneo o el selector se rompieran hacia 0, el guard dejaría de ver la sonda
# y moriría aquí por SOBREVIVIÓ/causa equivocada.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_built_codeblocks.sh

mkdir -p "$TREE/website/build/probe-quickstart"
cat > "$TREE/website/build/probe-quickstart/index.html" <<'HTML'
<html><body>
<pre><code class="codeBlockLines_e6Vv"><span class="token-line"><span class="token keyword">package</span> main</span></code></pre>
<p>Entry point (main.go)</p>
<pre><code class="codeBlockLines_e6Vv"></code></pre>
</body></html>
HTML

echo "workdir=$TREE"
echo "expect=1 bloque\(s\) de código vacíos en 1 página\(s\) del HTML servido"
