#!/usr/bin/env bash
# Fixture de umbrella-why-quantum. Cinco roturas, todas de la misma clase: la
# página «Why Quantum» afirma una cifra que su fuente al pin ya no dice, o una
# que no tiene fuente.
#
# (A) una cifra de banco cambiada en la página: «46 of 46» pasa a «45 of 46».
#     Es la mutación con la que se verificó el gate W1, y la deriva más fácil
#     de cometer: el número vive en el paraguas y su verdad en un submódulo.
#
# (B) una cifra nueva sin fuente: una frase con un número que ninguna
#     afirmación del guard ata. El contrato de la página es «toda cifra tiene
#     fuente»; sin este control, bastaría con escribirla fuera de las frases
#     que el guard conoce.
#
# (C) la frase de what-is-quantum.md que sustituyó a «not breadth of plugins»
#     dice un número de módulos que no es el del set (→ 11).
#
# (D) el catálogo de `nucleus add` gana, en el pin, una capacidad del core
#     (una entrada que `add` cablea sin módulo). Las dos frases del sitio
#     dan el número de las de antes, y la de la página las nombra una a una:
#     el guard tiene que decir las tres cosas, la cuenta en cada página y el
#     nombre que falta.
#
# (E) el set certifica un segundo reportero de errores, otro
#     `providers/errors-*`. La página nombra a Sentry: contarlo bajo su nombre
#     diría algo falso, así que tiene que caer como una clase que la página no
#     nombra.
#
# El árbol parte de las fuentes REALES al pin y de las páginas tal cual, en
# las que el guard pasa; el EXIT!=0 es atribuible a las cuatro roturas.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" \
  scripts/check_why_quantum.sh scripts/lib/quickstart-fences.sh scripts/lib/manifest-modules.sh \
  versions.yaml \
  website/docs/why-quantum.md website/docs/what-is-quantum.md website/docs/quickstart.md \
  nucleus/docs/api-bench.md nucleus/docs/auth-bench.md nucleus/docs/jobs-bench.md \
  orbit/docs/admin-bench.md \
  quark/docs/query-bench.md quark/docs/enterprise-bench.md \
  quark/website/docs/reference/benchmarks.mdx \
  nucleus/website/docs/getting-started/installation.md \
  nucleus/internal/knownproviders

# Los go.mod de los módulos hermanos de nucleus: el guard clasifica cada
# entrada de nucleus_modules por su directorio en el árbol, con el mismo
# descubrimiento que manifest-guard (scripts/lib/manifest-modules.sh).
source scripts/lib/manifest-modules.sh
for dir in $(mm_discover nucleus); do
  fx_copy "$ROOT" "$TREE" "nucleus/$dir/go.mod"
done

# El árbol sin doctorar tiene que pasar: si no, el EXIT!=0 de abajo no
# demostraría nada (fixture rota por un cambio del árbol real).
if ! (cd "$TREE" && bash scripts/check_why_quantum.sh >/dev/null 2>&1); then
  echo "fixture: el guard ya falla sobre la copia SIN doctorar — la página o una fuente del pin cambió; arréglalo antes de probar la mordida" >&2
  (cd "$TREE" && bash scripts/check_why_quantum.sh) >&2 || true
  exit 1
fi

# (A) una cifra de banco cambiada.
perl -pi -e 's/\*\*46 of 46\*\*/**45 of 46**/' "$TREE/website/docs/why-quantum.md"
fx_assert_doctored "$TREE/website/docs/why-quantum.md" '\*\*45 of 46\*\*'

# (B) una cifra sin fuente.
printf '\nThe suite has 7 maintainers.\n' >>"$TREE/website/docs/why-quantum.md"

# (C) la frase del catálogo en what-is-quantum.md, con otro número.
perl -pi -e 's/(`nucleus add` installs the )\d+/${1}11/' "$TREE/website/docs/what-is-quantum.md"
fx_assert_doctored "$TREE/website/docs/what-is-quantum.md" '`nucleus add` installs the 11'

# (D) el catálogo al pin gana una capacidad del core. La cuenta de las que
# había se lee antes, de la tabla sin doctorar.
n_core=$(cat "$TREE"/nucleus/internal/knownproviders/*.go | grep -cE 'Ships:[[:space:]]*InCore' || true)
[[ "${n_core:-0}" -gt 0 ]] || { echo "fixture: la tabla de nucleus add al pin no tiene entradas Ships: InCore (¿cambió el formato?)" >&2; exit 1; }
cat >>"$TREE/nucleus/internal/knownproviders/knownproviders.go" <<'GO'

// fixture umbrella-why-quantum: una entrada que `nucleus add` cablea sin ser
// un módulo, como las del catálogo de A11.
var fixtureCoreEntry = Entry{Name: "fixture-core", Ships: InCore}
GO

# (E) un segundo reportero de errores en el set y en el árbol.
mkdir -p "$TREE/nucleus/providers/errors-rollbar"
printf 'module github.com/jcsvwinston/nucleus/providers/errors-rollbar\n\ngo 1.26\n' \
  >"$TREE/nucleus/providers/errors-rollbar/go.mod"
perl -pi -e 's/^(nucleus_modules:\n)/$1  errors-rollbar: "v0.1.0"\n/' "$TREE/versions.yaml"
fx_assert_doctored "$TREE/versions.yaml" '^  errors-rollbar: "v0\.1\.0"'

echo "workdir=$TREE"
echo "expect=\[api-bench\] .*45 of 46"
echo "expect=cifra sin fuente .*7"
echo "expect=\[catalog-intro\] website/docs/what-is-quantum.md dice .*11"
echo "expect=\[catalog-core\] website/docs/why-quantum.md dice «$n_core» y su fuente dice «$((n_core + 1))»"
echo "expect=\[catalog-intro-core\] website/docs/what-is-quantum.md dice «$n_core» y su fuente dice «$((n_core + 1))»"
echo "expect=\[catalog-core-names\] .*fixture-core"
echo "expect=nucleus_modules\.errors-rollbar vive en providers/errors-rollbar, una clase de módulo que la página no nombra"
