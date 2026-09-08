# Deuda: registrar `quark-action-pins` al re-pinar quark

**Cuándo se aplica: EN el PR del set que re-pine `quark` a un tag que
contenga `scripts/ci/check_action_pins.sh` (quark#364, fusionado el
2026-09-08). Nunca antes y nunca después.**

Por qué no puede entrar antes: el escaneo anti-fósil de
`scripts/lib/guard-registry.sh` recorre `scripts/ci/` de los tres productos
**al pin**, y el registro exige que todo guard tenga fixture. Con el pin
actual (`c59850ac`, anterior al fichero) la fixture no encuentra el guard y
`guard-of-guards` muere; con el pin nuevo y sin registrar, el que muere es
`suite-integral` con «guard sin registrar». Los dos ficheros de abajo van en
el mismo commit que mueve el gitlink de quark.

Y por qué no se puede olvidar: al re-pinar sin esto, la lane del set falla
con el texto exacto de la remediación.

## 1. Entrada del registro

Va junto a las demás de quark en `scripts/lib/guard-registry.sh`, antes de
`quark-pr-title-english`:

```
  # Toda Action de GitHub que corre el CI de quark está fijada por SHA de
  # commit, con su tag escrito al lado (el comentario es lo que Dependabot
  # reescribe y lo que hace legible el pin). Entra al set con la release de
  # quark que traiga scripts/ci/check_action_pins.sh.
  "quark-action-pins|quark|bash scripts/ci/check_action_pins.sh"
```

Y su fila en la tabla de `docs/AUDITORIA_CONTINUA.md`:

```
| quark-action-pins | quark | bash scripts/ci/check_action_pins.sh | Toda Action del CI de quark está fijada por SHA de commit, con su tag en el comentario |
```

## 2. Fixture

`tests/guard-fixtures/quark-action-pins/fixture.sh`, verificada contra el
guard real (revierte un `uses:` fijado a su tag móvil y el guard muere con
«is pinned to 'v5', which is a moving tag»):

```bash
#!/usr/bin/env bash
# Fixture de quark-action-pins.
#
# Rotura: una referencia `uses:` del CI de quark vuelve a su TAG móvil — el SHA
# fijado se sustituye por la etiqueta que llevaba al lado, que es exactamente lo
# que el guard existe para impedir (un tag lo mueve su dueño, bajo un job que ya
# tiene este repositorio checkouteado). El guard debe morir nombrando el tag.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

# El árbol mínimo que el guard lee: su propio script y los workflows.
fx_copy "$ROOT/quark" "$TREE" \
  scripts/ci/check_action_pins.sh \
  .github/workflows

# El PRIMER `uses: actions/checkout@<sha> # <tag>` pasa a `uses: actions/checkout@v5`.
awk 'BEGIN{done=0}
{
  if (!done && $0 ~ /uses:[ \t]*actions\/checkout@/) {
    sub(/actions\/checkout@.*/, "actions/checkout@v5")
    done=1
  }
  print
}' "$TREE/.github/workflows/ci.yml" > "$TREE/.github/workflows/ci.yml.tmp"
mv "$TREE/.github/workflows/ci.yml.tmp" "$TREE/.github/workflows/ci.yml"
fx_assert_doctored "$TREE/.github/workflows/ci.yml" 'uses:[ \t]*actions/checkout@v5$'

echo "workdir=$TREE"
echo "expect=is pinned to 'v5', which is a moving tag"
```
