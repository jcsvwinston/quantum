#!/usr/bin/env bash
# Fixture de umbrella-manifest-guard.
#
# Rotura: versions.yaml declara quark "v0.0.1" en `modules:` — una versión
# cuyo tag NO existe en el submódulo. Es la mentira exacta contra la que se
# escribió el guard (QM-P0-1): un manifiesto que certifica lo que git no
# respalda. El guard debe morir en §2 («tag(version) == workspace_pin») con
# "tag v0.0.1 does not exist in the submodule".
#
# Segunda rotura (Quantum 1.45.0): orbit/quarkbridge/go.mod requiere quark
# en un `require` de UNA línea —la forma en que `go mod tidy` escribe el único
# require directo de un módulo— y a una versión rancia (v1.2.1, la que
# quarkbridge publicó una vez sin declararla). El guard debe morir también en
# §5 con "orbit/quarkbridge/go.mod — requires quark v1.2.1": hasta 1.45.0 su
# awk sólo leía la forma en bloque y un require así era invisible
# (providers/tasks-asynq quedó dos minors atrás sin aviso).
#
# El árbol doctorado lleva submódulos git REALES (clones --shared al pin, con
# sus tags), así que §1/§3/§5 operan sobre datos de verdad y solo las roturas
# introducidas matan al guard.
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

# Doctorado 2: el require de quark en quarkbridge pasa del bloque a una
# línea suelta y a v1.2.1. Se quita la línea del bloque (sea cual sea la
# versión) y se añade la forma de una línea al final del fichero.
QB="$TREE/orbit/quarkbridge/go.mod"
awk '$1 == "github.com/jcsvwinston/quark" && $NF != "indirect" { next } { print }' "$QB" > "$QB.tmp"
mv "$QB.tmp" "$QB"
printf '\nrequire github.com/jcsvwinston/quark v1.2.1\n' >> "$QB"
fx_assert_doctored "$QB" '^require github\.com/jcsvwinston/quark v1\.2\.1$'
if grep -qE '^\s+github\.com/jcsvwinston/quark v' "$QB"; then
  echo "fixture: quarkbridge/go.mod conserva el require de quark en bloque; la rotura 2 no aplica" >&2
  exit 1
fi

echo "workdir=$TREE"
echo "expect=quark — tag v0\.0\.1 does not exist in the submodule"
echo "expect=orbit/quarkbridge/go.mod — requires quark v1\.2\.1"
