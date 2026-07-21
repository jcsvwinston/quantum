#!/usr/bin/env bash
# Fixture de umbrella-sidebar-sync.
#
# DOS roturas en el mismo árbol, una por regla del guard (patrón de la fixture
# de served-jargon: el expect exige el conteo, así que AMBAS tienen que morder):
#
#   1. Deriva (QM7-4): el espejo website/sidebarsNucleus.ts pierde UN id de
#      documento que el sidebar del producto sí tiene — página servida pero
#      invisible en la navegación del paraguas tras un re-pin. Se borra la
#      primera línea-id del espejo, sea cual sea (sin depender de un id
#      concreto).
#   2. Parser sin ids (QM8-3): el espejo website/sidebarsQuark.ts queda sin
#      NINGUNA string-id parseable — el verde-vacío que el guard vetó en la 8ª
#      ronda (0 ids en ambos lados comparaba vacío con vacío y «sincronizado»).
#
# expect exige "2 fallo(s)": si cualquiera de las dos reglas dejara de morder,
# el conteo sería 1 y el harness fallaría por causa equivocada.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" \
  scripts/check_sidebar_sync.sh \
  website/sidebarsNucleus.ts \
  website/sidebarsQuark.ts \
  nucleus/website/sidebars.ts \
  quark/website/sidebars.ts

# Rotura 1 — deriva: primera línea que es SOLO un id ('ruta/doc',) — la misma
# forma que parsea la heurística del guard.
mirror="$TREE/website/sidebarsNucleus.ts"
line=$(grep -nE "^[[:space:]]*'[^' ]+',?[[:space:]]*$" "$mirror" | head -1 | cut -d: -f1)
if [[ -z "$line" ]]; then
  echo "fixture: no se encontró ninguna línea-id en $mirror (¿cambió el formato del espejo?)" >&2
  exit 1
fi
sed "${line}d" "$mirror" > "$mirror.tmp"
mv "$mirror.tmp" "$mirror"

# Rotura 2 — parser sin ids: el espejo de quark pasa a no contener ninguna
# string entrecomillada sin espacios (nada que la heurística pueda extraer).
cat > "$TREE/website/sidebarsQuark.ts" <<'TS'
// Espejo vaciado por la fixture: cero strings-id parseables (rotura QM8-3).
const sidebars = {};
export default sidebars;
TS

echo "workdir=$TREE"
echo "expect=check_sidebar_sync: 2 fallo\(s\)"
