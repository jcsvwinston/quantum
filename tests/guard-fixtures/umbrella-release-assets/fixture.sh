#!/usr/bin/env bash
# Fixture de umbrella-release-assets.
#
# Rotura: una release del set publica sus archivos y su fichero de sumas, y se
# queda SIN la firma. Es la forma en que la cadena de suministro se desarma sin
# que nada se ponga rojo: los binarios están, el checksums.txt está, y lo único
# que falta es lo que nadie mira hasta que lo necesita. Le pasó a nucleus
# v1.26.0 con cero activos y los 47 guards de entonces en verde, porque leían
# el ÁRBOL.
#
# Este guard es el único del registro que pregunta a la red, así que la fixture
# no doctora un árbol: sustituye el CLIENTE. QUANTUM_GH apunta a un `gh` de
# mentira que contesta con una release doctorada, y así la rotura se prueba sin
# depender de lo que GitHub esté sirviendo hoy.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_release_assets.sh versions.yaml

# El `gh` de mentira: para quark, nucleus y el paraguas contesta una release
# completa; para orbit, la misma sin `checksums.txt.sig`. Una sola rotura, en
# un solo repositorio, que es como ocurre de verdad.
mkdir -p "$TREE/bin"
cat > "$TREE/bin/gh" <<'GHEOF'
#!/usr/bin/env bash
# gh de mentira para la fixture: sólo entiende la llamada que el guard hace.
repo=""
prev=""
for a in "$@"; do
  case "$prev" in -R) repo="$a" ;; esac
  prev="$a"
done
completa=$'checksums.txt\nchecksums.txt.pem\nchecksums.txt.sig\nalgo_1.0.0_linux_amd64.tar.gz'
case "$repo" in
  */orbit) printf '%s\n' "checksums.txt" "checksums.txt.pem" "algo_1.0.0_linux_amd64.tar.gz" ;;
  *)       printf '%s\n' "$completa" ;;
esac
GHEOF
chmod +x "$TREE/bin/gh"

fx_assert_doctored "$TREE/bin/gh" 'checksums.txt.pem'

echo "workdir=$TREE"
echo "env=QUANTUM_GH=$TREE/bin/gh"
echo "expect=orbit .* la release no publica: checksums.txt.sig"
