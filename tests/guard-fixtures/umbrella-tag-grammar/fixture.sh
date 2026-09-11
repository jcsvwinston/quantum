#!/usr/bin/env bash
# Fixture de umbrella-tag-grammar. Dos roturas, una por repo, que son las dos
# direcciones en que las gramáticas del tag `db` se cruzan:
#
# (A) un modelo de quark escrito a la manera de nucleus. Es la dirección
#     DESTRUCTIVA: quark lee el tag entero como nombre de columna, así que
#     creaba una columna llamada literalmente `column:email;unique;not null`
#     —consultable por nadie— sin error y sin aviso. Es lo que midió A4/S0
#     y lo que abrió NU-50.
#
# (B) un modelo de nucleus con las opciones de dimensionado de quark. Es la
#     dirección SILENCIOSA: pkg/model no las reconoce, la columna se queda
#     con el nombre derivado del campo Go, y el único rastro es un WARN de
#     arranque que nadie lee en CI.
#
# El árbol parte del estado REAL al pin, que es conforme, así que el EXIT!=0
# es atribuible a las roturas y no al punto de partida.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_tag_grammar.sh
mkdir -p "$TREE/quark" "$TREE/nucleus"

# (A) quark con la gramática de nucleus.
cat > "$TREE/quark/fixture_model.go" <<'GO'
package fixture

type Account struct {
	ID    uint   `db:"pk" json:"id"`
	Email string `db:"column:email;unique;not null" json:"email"`
}
GO

# (B) nucleus con las opciones de quark.
cat > "$TREE/nucleus/fixture_model.go" <<'GO'
package fixture

type Profile struct {
	ID   int64  `db:"column:id;pk"`
	Name string `db:"name,size=255"`
}
GO

fx_assert_doctored "$TREE/quark/fixture_model.go" 'column:email;unique;not null'
fx_assert_doctored "$TREE/nucleus/fixture_model.go" 'name,size=255'

echo "workdir=$TREE"
echo "expect=quark/fixture_model.go:[0-9]+ — db:\"column:email;unique;not null\""
echo "expect=nucleus/fixture_model.go:[0-9]+ — db:\"name,size=255\" lleva opciones de dimensionado"
