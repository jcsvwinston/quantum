#!/usr/bin/env bash
# Fixture de nucleus-adr-index.
#
# Rotura: se borra del índice la entrada de un ADR que sigue en el directorio,
# que es exactamente cómo el índice se pudrió — se quedó en ADR-022 con
# veintinueve records, y diecisiete decisiones sólo eran alcanzables listando
# la carpeta. El guard debe morir nombrando el ADR ausente.
#
# Árbol completo del repo: el guard recorre docs/adrs/ anclándose a su propia
# ubicación (dirname/../..).
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy_tree "$ROOT/nucleus" "$TREE"

# Quita la ÚLTIMA entrada del índice; el fichero que enlaza sigue en disco.
victim=$(grep -oE '\(ADR-[0-9]+[^)]*\.md\)' "$TREE/docs/adrs/README.md" | tr -d '()' | tail -1)
grep -v "($victim)" "$TREE/docs/adrs/README.md" > "$TREE/docs/adrs/README.md.tmp"
mv "$TREE/docs/adrs/README.md.tmp" "$TREE/docs/adrs/README.md"

# La víctima tiene que seguir existiendo, o la rotura no sería la que dice.
[ -f "$TREE/docs/adrs/$victim" ] || { echo "fixture: $victim no existe en el árbol copiado" >&2; exit 1; }
if grep -q "($victim)" "$TREE/docs/adrs/README.md"; then
  echo "fixture: la entrada de $victim sigue en el índice — la rotura no se aplicó" >&2
  exit 1
fi

echo "workdir=$TREE"
