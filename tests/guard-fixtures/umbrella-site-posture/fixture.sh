#!/usr/bin/env bash
# Fixture de umbrella-site-posture. Tres roturas del banco del sitio, todas de
# la misma clase: lo que A11 dejó en el sitio retrocede y la cifra no lo dice.
#
# (A) un control retrocede en lo MEDIDO y nadie toca lo registrado: la página
#     «Why Quantum» sale del sidebar de inicio. ST-01 mide partial y el banco
#     registra present; antes de este guard, nada corría el banco y el
#     retroceso pasaba en verde.
#
# (B) un control retrocede en lo medido Y en lo registrado, con su nota: el
#     post de un set viejo (Quantum 1.0.0) desaparece y ST-10 se registra
#     partial. El banco vuelve a verde —lo medido es lo registrado—, así que
#     sólo el suelo de 12 present lo caza.
#
# (C) un control desaparece del banco: ST-09 (la referencia de la API) sale
#     de la tabla. El banco sigue verde con 11; sólo la cuenta de controles lo
#     caza.
#
# El árbol lleva lo que el banco lee —las fuentes del sitio, los workflows,
# los scripts de las lanes, los dos guards a los que llama con sus fuentes al
# pin y los tags de suite del paraguas, que dan un post por set— y el guard
# pasa sobre él sin doctorar, así que el EXIT!=0 es atribuible a las tres
# roturas.
set -euo pipefail
source tests/guard-fixtures/lib.sh
source scripts/lib/manifest-modules.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

# El banco y lo que lee del paraguas.
fx_copy "$ROOT" "$TREE" \
  scripts/check_site_posture.sh tests/sitebench/sitebench.sh \
  scripts/check_why_quantum.sh scripts/check_generated_pages.sh \
  scripts/lib/guard-registry.sh scripts/lib/quickstart-fences.sh \
  scripts/lib/manifest-modules.sh scripts/lib/site-pages.py \
  scripts/ci .github/workflows versions.yaml \
  website/docs website/releases website/sidebarsStart.ts website/docusaurus.config.ts

# Las fuentes al pin de umbrella-why-quantum (ST-02, ST-12) y de
# umbrella-generated-pages (ST-09…ST-11): las mismas que copian sus fixtures.
fx_copy "$ROOT" "$TREE" \
  nucleus/docs/api-bench.md nucleus/docs/auth-bench.md nucleus/docs/jobs-bench.md \
  orbit/docs/admin-bench.md \
  quark/docs/query-bench.md quark/docs/enterprise-bench.md \
  quark/website/docs/reference/benchmarks.mdx \
  nucleus/website/docs/getting-started/installation.md \
  nucleus/internal/knownproviders \
  nucleus/contracts/baseline/api_exported_symbols.txt \
  nucleus/contracts/baseline/extension_surface.txt \
  quark/acceptance/apisurface.json \
  orbit/contracts/baseline/api_exported_symbols.txt
for repo in nucleus quark orbit; do
  fx_copy "$ROOT" "$TREE" "$repo/go.mod"
  for dir in $(mm_discover "$repo"); do
    fx_copy "$ROOT" "$TREE" "$repo/$dir/go.mod"
  done
done

# Los tags de suite: ST-10 pide un post por cada uno.
(
  cd "$TREE"
  git init --quiet
  git fetch --quiet "$ROOT" 'refs/tags/v*:refs/tags/v*'
)
[[ -n "$(git -C "$TREE" tag --list 'v1.*')" ]] || { echo "fixture: no llegaron los tags de suite a la copia" >&2; exit 1; }

# Sin doctorar, el guard pasa: si no, el EXIT!=0 de abajo no demostraría nada.
if ! (cd "$TREE" && bash scripts/check_site_posture.sh >/dev/null 2>&1); then
  echo "fixture: el guard ya falla sobre la copia SIN doctorar — el banco del sitio o una de sus fuentes cambió; arréglalo antes de probar la mordida" >&2
  (cd "$TREE" && bash scripts/check_site_posture.sh) >&2 || true
  exit 1
fi

BENCH="$TREE/tests/sitebench/sitebench.sh"

# (A) «Why Quantum» sale del sidebar.
perl -0pi -e "s/^[ \t]*'why-quantum',\n//m" "$TREE/website/sidebarsStart.ts"
if grep -q "'why-quantum'" "$TREE/website/sidebarsStart.ts"; then
  echo "fixture: la rotura (A) no se aplicó — la página sigue en el sidebar (¿cambió el formato de sidebarsStart.ts?)" >&2
  exit 1
fi

# (B) el post de 1.0.0 desaparece y ST-10 se registra partial, con nota.
rm "$TREE/website/releases/quantum-1-0-0.md"
perl -pi -e 's/^(\s*"ST-10\|[a-z]+\|)present\|([^|]*)\|"/${1}partial|$2|fixture: falta el post de 1.0.0"/' "$BENCH"
fx_assert_doctored "$BENCH" '"ST-10\|[a-z]+\|partial\|'

# (C) ST-09 sale de la tabla.
perl -ni -e 'print unless /^\s*"ST-09\|/' "$BENCH"
if grep -qE '^[[:space:]]*"ST-09\|' "$BENCH"; then
  echo "fixture: la rotura (C) no se aplicó — ST-09 sigue en la tabla del banco" >&2
  exit 1
fi

echo "workdir=$TREE"
echo "expect=ST-01 .*mide «partial» y el banco registra «present»"
echo "expect=registra 10 controles present; el suelo de A11 es 12"
echo "expect=el banco tiene 11 controles; se registraron 12"
