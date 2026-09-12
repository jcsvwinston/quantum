#!/usr/bin/env bash
# Fixture de umbrella-auth-posture. Tres roturas, y las tres son la MISMA
# clase de fallo: un documento medido al que alguien le cambia el resultado
# sin cambiar lo que mide.
#
# (A) la página del banco publica una cifra que la tabla no dice. Es la
#     edición más fácil de hacer y la más difícil de ver: el numerador vive
#     en un markdown y la verdad en un fichero Go, a dos directorios.
#
# (B) un control que no está `present` pierde su nota. Sin ella el banco
#     deja de decir QUÉ falta, que es la mitad de su valor: un "absent"
#     sin razón es indistinguible de un olvido.
#
# (C) el baseline ASVS gana una fila sin veredicto. Una fila así se lee
#     como un requisito cubierto por quien no mire la columna.
#
# El árbol parte del estado real al pin, conforme, así que el EXIT!=0 es
# atribuible a las roturas.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_auth_posture.sh
mkdir -p "$TREE/nucleus/internal/authbench" "$TREE/nucleus/docs" "$TREE/nucleus/contracts/baseline"

cp "$ROOT/nucleus/internal/authbench/authbench_cases_test.go" "$TREE/nucleus/internal/authbench/"
cp "$ROOT/nucleus/docs/auth-bench.md" "$TREE/nucleus/docs/"
cp "$ROOT/nucleus/contracts/baseline/asvs_l2.txt" "$TREE/nucleus/contracts/baseline/"

# (A) la página publica otra cifra.
perl -0pi -e 's/\*\*\d+ of (\d+) controls present/**43 of $1 controls present/' "$TREE/nucleus/docs/auth-bench.md"

# (B) un control sin nota: se le quita a SES-06, el único partial.
perl -0pi -e 's/(\{id: "SES-06"[^}]*?)note: "[^"]*",\s*\n/$1/s' "$TREE/nucleus/internal/authbench/authbench_cases_test.go"

# (C) una fila ASVS sin veredicto.
printf 'V9.9.9  something nobody judged\n' >> "$TREE/nucleus/contracts/baseline/asvs_l2.txt"

fx_assert_doctored "$TREE/nucleus/docs/auth-bench.md" '43 of 43 controls present'
fx_assert_doctored "$TREE/nucleus/contracts/baseline/asvs_l2.txt" 'V9.9.9'

echo "workdir=$TREE"
echo "expect=la página dice 43/43 y el banco mide"
echo "expect=casos sin nota que diga qué falta: SES-06"
echo "expect=fila\(s\) del baseline ASVS sin veredicto reconocible"
