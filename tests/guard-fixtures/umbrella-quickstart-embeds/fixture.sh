#!/usr/bin/env bash
# Fixture de umbrella-quickstart-embeds.
#
# Rotura: la página embebe `shop/module.go#L3-L14` y DECLARA que ese bloque
# contiene `Policies:` y `CSRFExempt:` (lo que su prosa explica), pero el
# módulo del «submódulo pinado» de la copia es el `Module` ANTERIOR — sin
# reglas propias ni exención: exactamente lo que el paraguas publicaría si la
# página del arco A2 se fusionara sola, con el pin de nucleus por detrás
# (el ejemplo existe con el mismo nombre, el build sale verde y
# check_built_codeblocks no lo ve porque el bloque no está vacío). El rango
# cabe, no hay jerga y la primera/última línea cuadran, para que el guard
# muera por la aserción de contenido —la esencia del guard— y no por otra
# capa.
#
# Las demás causas de muerte (fichero ausente al pin → ENOENT anunciado,
# rango que se pasa del final, jerga interna en lo embebido con la regex de
# check_served_jargon.sh, fence sin entrada en `embeds:`, entrada sin fence,
# `embeds:` ausente → EXIT 2, página ausente → EXIT 2) se probaron por
# comando en la ronda que trajo el guard (rama docs/a2-quickstart); el
# harness ejecuta UNA fixture por guard y la rotura permanente elegida es la
# del pin por detrás de la página.
#
# El árbol es SINTÉTICO a propósito: copiar el ejemplo real del submódulo
# haría que la fixture cambiara de veredicto con cada re-pin (hoy el pin
# real va por detrás; mañana no) — una fixture tiene que morir por la misma
# causa en todos los pines.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_quickstart_embeds.sh scripts/lib/quickstart-fences.sh scripts/check_served_jargon.sh

mkdir -p "$TREE/nucleus/examples/showcase_demo/shop" "$TREE/website/docs"
cat > "$TREE/nucleus/examples/showcase_demo/shop/module.go" <<'GO'
package shop

// Module returns the shop feature as a nucleus module.
func Module(base *quark.Client) nucleus.ModuleSpec {
	m := &module{base: base}

	return nucleus.Module[struct{}]{
		Name: "shop",
		Routes: func(r nucleus.Router, _ struct{}) {
			r.Get("/api/articles", m.listArticles)
		},
	}.Build()
}

func (m *module) listArticles(c *nucleus.Context) error { return nil }
GO
fx_assert_doctored "$TREE/nucleus/examples/showcase_demo/shop/module.go" '^func Module\('
if grep -q 'Policies:' "$TREE/nucleus/examples/showcase_demo/shop/module.go"; then
  echo "fixture: el módulo doctorado no debía declarar Policies (es el Module ANTERIOR)" >&2; exit 1
fi

cat > "$TREE/website/docs/quickstart.md" <<'MD'
---
title: "Quickstart (sonda)"
embeds:
  - 'examples/showcase_demo/shop/module.go#L3-L13 | ^// Module returns | func Module( | Policies: | CSRFExempt: | }$'
---

# Sonda

```go file=<rootDir>/examples/showcase_demo/shop/module.go#L3-L13
```

**A module carries its own rules.** `Policies` are the rows the enforcer
needs; `CSRFExempt` frees the JSON API from the origin check.
MD
fx_assert_doctored "$TREE/website/docs/quickstart.md" '^```go file=<rootDir>/examples/showcase_demo/shop/module.go#L3-L13$'

echo "workdir=$TREE"
echo "expect=no contiene .Policies:."
