#!/usr/bin/env bash
# Fixture de nucleus-contract-freeze.
#
# Rotura: la baseline de símbolos estables (contracts/baseline/
# api_exported_symbols.txt) gana un símbolo INVENTADO, insertado en orden para
# no disparar el check de sorted-unique. Para el freeze eso es indistinguible
# de una regresión real: «la API congelada tenía este símbolo y el código ya
# no lo exporta» (un removal). El guard debe morir en
# TestContractFreeze_APIExportedSymbols_NoRemovals con
# "stable API contract regression: missing exported symbol(s)".
#
# Árbol completo del módulo: el guard compila y ejecuta los tests de contracts,
# así que necesita el módulo Go entero, no un subárbol.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy_tree "$ROOT/nucleus" "$TREE"

baseline="$TREE/contracts/baseline/api_exported_symbols.txt"
printf '%s\n' "github.com/jcsvwinston/nucleus/pkg/model func:InventedByGuardOfGuards" >> "$baseline"
sort -u -o "$baseline" "$baseline"
fx_assert_doctored "$baseline" 'InventedByGuardOfGuards'

echo "workdir=$TREE"
echo "expect=stable API contract regression: missing exported symbol"
