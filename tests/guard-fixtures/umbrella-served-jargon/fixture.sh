#!/usr/bin/env bash
# Fixture de umbrella-served-jargon.
#
# Rotura: el build dir servido contiene DOS páginas sonda, cada una con una
# clase distinta de jerga interna:
#   - probe-adr:      "ADR-010"  (regla original QM5-1 — vocabulario interno)
#   - probe-hallazgo: "QK5-2"    (regla nueva de la 7ª ronda — IDs de hallazgo)
# El expect exige "2 página(s)": si alguien rompiera SOLO la alternancia nueva
# de IDs de hallazgo, el guard cazaría 1 página y el harness fallaría —
# la fixture prueba que AMBAS reglas muerden, no solo la vieja.
#
# La precondición QM8-4 (0 HTML escaneados → FAIL) NO cabe en este árbol: es
# mutuamente excluyente con las sondas (un dir no puede estar vacío y tener 2
# páginas), y el harness ejecuta UNA fixture por guard. La rotura elegida como
# permanente es la de las reglas de jerga (la esencia del guard); el negativo
# de QM8-4 se probó por comando en su ronda (build dir con 0 HTML → EXIT=1
# «verde-vacío, no un veredicto») y su regresión la delataría además esta
# misma fixture: si el contador de escaneados se rompiera hacia 0, el guard
# dejaría de ver las sondas y moriría aquí por SOBREVIVIÓ/causa equivocada.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_served_jargon.sh

mkdir -p "$TREE/website/build/probe-adr" "$TREE/website/build/probe-hallazgo"
cat > "$TREE/website/build/probe-adr/index.html" <<'HTML'
<html><body><p>The rationale is recorded in ADR-010.</p></body></html>
HTML
cat > "$TREE/website/build/probe-hallazgo/index.html" <<'HTML'
<html><body><p>This regression was fixed as QK5-2 during the audit.</p></body></html>
HTML

echo "workdir=$TREE"
echo "expect=2 página\(s\) servidas contienen jerga interna"
