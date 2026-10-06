#!/usr/bin/env bash
# Fixture de umbrella-generated-pages. Tres roturas, una por familia de
# páginas generadas, y las tres de la misma clase: la fuente al pin se movió
# (o el set no escribió lo suyo) y el sitio sigue publicando lo de antes.
#
# (A) api: el producto congela un símbolo más —una línea nueva en
#     nucleus/contracts/baseline/api_exported_symbols.txt, como la que trae
#     cualquier re-pin de nucleus con API añadida— y la página de la API no
#     se regeneró.
#
# (B) catalog: la tabla que lee `nucleus add` gana una entrada —una variable
#     más de tipo map[string]Provider en internal/knownproviders, la forma
#     que las dos versiones de la tabla aceptan— y la página del catálogo no
#     la tiene.
#
# (C) releases: el set que declara versions.yaml se queda sin post —el PR de
#     set que no corrió el generador—, que es lo que impide certificar un set
#     sin su entrada en «Releases».
#
# El árbol parte de las fuentes REALES al pin, de las páginas tal cual y de
# los tags de suite del paraguas (traídos a un repo git propio de la copia:
# los posts salen del versions.yaml de cada tag); el guard pasa sobre él sin
# doctorar, así que el EXIT!=0 es atribuible a las tres roturas.
set -euo pipefail
source tests/guard-fixtures/lib.sh
source scripts/lib/manifest-modules.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" \
  scripts/check_generated_pages.sh scripts/lib/site-pages.py \
  versions.yaml website/docs/reference website/releases \
  nucleus/contracts/baseline/api_exported_symbols.txt \
  nucleus/contracts/baseline/extension_surface.txt \
  quark/acceptance/apisurface.json \
  orbit/contracts/baseline/api_exported_symbols.txt \
  nucleus/internal/knownproviders

# Los go.mod de cada producto: el generador resuelve el módulo (y su versión
# en el set) de cada paquete de la API y de cada entrada del catálogo con el
# mismo descubrimiento que manifest-guard.
for repo in nucleus quark orbit; do
  fx_copy "$ROOT" "$TREE" "$repo/go.mod"
  for dir in $(mm_discover "$repo"); do
    fx_copy "$ROOT" "$TREE" "$repo/$dir/go.mod"
  done
done

# Los tags de suite: un post por cada uno.
(
  cd "$TREE"
  git init --quiet
  git fetch --quiet "$ROOT" 'refs/tags/v*:refs/tags/v*'
)
[[ -n "$(git -C "$TREE" tag --list 'v1.*')" ]] || { echo "fixture: no llegaron los tags de suite a la copia" >&2; exit 1; }

# Sin doctorar, el guard pasa: si no, el EXIT!=0 de abajo no demostraría nada.
if ! (cd "$TREE" && bash scripts/check_generated_pages.sh >/dev/null 2>&1); then
  echo "fixture: el guard ya falla sobre la copia SIN doctorar — regenera las páginas (python3 scripts/lib/site-pages.py) antes de probar la mordida" >&2
  (cd "$TREE" && bash scripts/check_generated_pages.sh) >&2 || true
  exit 1
fi

# (A) un símbolo congelado más en nucleus.
echo 'github.com/jcsvwinston/nucleus/pkg/accounts func:FixtureFrozenSymbol' \
  >>"$TREE/nucleus/contracts/baseline/api_exported_symbols.txt"
fx_assert_doctored "$TREE/nucleus/contracts/baseline/api_exported_symbols.txt" 'FixtureFrozenSymbol'

# (B) una entrada más en la tabla del CLI.
cat >>"$TREE/nucleus/internal/knownproviders/knownproviders.go" <<'GO'

// fixture umbrella-generated-pages: una entrada que la página no tiene.
var fixtureEntries = map[string]Provider{
	"fixture-entry": {
		Kind:   "framework capability",
		Name:   "fixture-entry",
		Module: "github.com/jcsvwinston/nucleus",
	},
}
GO
fx_assert_doctored "$TREE/nucleus/internal/knownproviders/knownproviders.go" 'fixture-entry'

# (C) el set vigente sin post.
ver=$(sed -nE 's/^quantum:[[:space:]]+"([^"]+)".*/\1/p' "$TREE/versions.yaml" | head -1)
post="$TREE/website/releases/quantum-${ver//./-}.md"
[[ -f "$post" ]] || { echo "fixture: no encuentro el post de Quantum $ver ($post)" >&2; exit 1; }
rm "$post"

echo "workdir=$TREE"
echo "expect=\[api\] website/docs/reference/api-nucleus.md no es lo que el pin genera"
echo "expect=\[catalog\] website/docs/reference/catalog.md no es lo que el pin genera"
echo "expect=\[releases\] Quantum [0-9.]+, el set que declara versions.yaml, no tiene post"
