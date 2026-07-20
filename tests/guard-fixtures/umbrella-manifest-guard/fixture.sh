#!/usr/bin/env bash
# Fixture de umbrella-manifest-guard.
#
# Rotura: versions.yaml declara quark "v0.0.1" en `modules:` — una versión
# cuyo tag NO existe en el submódulo. Es la mentira exacta contra la que se
# escribió el guard (QM-P0-1): un manifiesto que certifica lo que git no
# respalda. El guard debe morir en §2 («tag(version) == workspace_pin») con
# "tag v0.0.1 does not exist in the submodule".
#
# El árbol doctorado lleva submódulos git REALES (clones --shared al pin, con
# sus tags), así que §1/§3/§5 operan sobre datos de verdad y solo la rotura
# introducida mata al guard.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/manifest-guard.sh versions.yaml README.md

for m in quark nucleus orbit; do
  fx_clone_at "$ROOT/$m" "$TREE/$m" "$(git -C "$ROOT/$m" rev-parse HEAD)"
done

# Doctorado: la entrada quark de `modules:` pasa a "v0.0.1" (sea cual sea la
# versión certificada — no se hardcodea, para que la fixture sobreviva a los
# re-pins). Las entradas quark de workspace_pins/declared_lags no se tocan.
awk '
  /^modules:/            { inmod=1 }
  /^[a-zA-Z_]/ && !/^modules:/ { inmod=0 }
  {
    if (inmod && $1 == "quark:") sub(/"v[0-9.]+"/, "\"v0.0.1\"")
    print
  }
' "$TREE/versions.yaml" > "$TREE/versions.yaml.tmp"
mv "$TREE/versions.yaml.tmp" "$TREE/versions.yaml"
fx_assert_doctored "$TREE/versions.yaml" 'quark: *"v0\.0\.1"'

echo "workdir=$TREE"
echo "expect=quark — tag v0\.0\.1 does not exist in the submodule"
