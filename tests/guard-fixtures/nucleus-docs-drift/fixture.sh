#!/usr/bin/env bash
# Fixture de nucleus-docs-drift.
#
# Rotura: una página VIVA de la documentación interna gana un enlace relativo
# a un fichero que no existe — la clase exacta que este guard nació para cazar
# (un manual que sigue apuntando a algo ya movido o nunca escrito). El guard
# debe morir contando la referencia rota.
#
# Árbol completo del repo: el guard resuelve rutas contra el árbol real y se
# ancla a su propia ubicación (dirname/../..), así que necesita el repo entero,
# copia del propio script incluida.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy_tree "$ROOT/nucleus" "$TREE"

printf '\nVer el [manual de despliegue](manual-que-no-existe.md) para el detalle.\n' >> "$TREE/docs/MODULARIZATION.md"
fx_assert_doctored "$TREE/docs/MODULARIZATION.md" 'manual-que-no-existe\.md'

echo "workdir=$TREE"
echo "expect=referencia\\(s\\) rotas en la documentación interna"
