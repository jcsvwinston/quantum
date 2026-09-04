#!/usr/bin/env bash
# Fixture de umbrella-retired-claims.
#
# Rotura: el build dir servido contiene DOS páginas sonda, cada una con una
# afirmación retirada de clase distinta:
#   - probe-tags:   «add -tags mssql to include the driver» (D3: no hay build tags)
#   - probe-module: «ships as a single Go module»            (nucleus es multi-módulo)
# y DOS páginas que el guard debe IGNORAR con porqué documentado:
#   - nucleus/1.2.0/…: snapshot versionado (historia; entonces era verdad)
#   - quark/reference/release-notes/…: release notes (narrativa de cambio)
# El expect exige exactamente «2 página(s)»: si el guard dejara de ignorar
# los excluidos cazaría 4 y el harness fallaría por causa equivocada; si una
# de las dos alternancias muriera, cazaría 1. La fixture prueba las reglas y
# las exclusiones a la vez.
#
# El versions.yaml real se copia para que el guard lea el pin de nucleus (la
# transición ligada al pin solo afecta a rutas bajo nucleus/ no versionadas;
# las sondas están fuera, así que muerden con cualquier pin).
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_retired_claims.sh versions.yaml

B="$TREE/website/build"
mkdir -p "$B/probe-tags" "$B/probe-module" "$B/nucleus/1.2.0/concepts/models" "$B/quark/reference/release-notes"
cat > "$B/probe-tags/index.html" <<'HTML'
<html><body><p>SQL Server support is opt-in: add <code>-tags mssql</code> to include the driver.</p></body></html>
HTML
cat > "$B/probe-module/index.html" <<'HTML'
<html><body><p>The framework ships as a single Go module with a single CLI binary.</p></body></html>
HTML
cat > "$B/nucleus/1.2.0/concepts/models/index.html" <<'HTML'
<html><body><p>MSSQL and Oracle are opt-in via Go build tags (<code>-tags oracle</code>).</p></body></html>
HTML
cat > "$B/quark/reference/release-notes/index.html" <<'HTML'
<html><body><p><code>-tags mssql</code> and <code>-tags oracle</code> are gone: drivers are modules now.</p></body></html>
HTML

echo "workdir=$TREE"
echo "expect=2 página\(s\) servidas afirman lo retirado"
