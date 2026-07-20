#!/usr/bin/env bash
# Fixture de nucleus-bodycheck.
#
# Rotura: una página de website/docs afirma "requires Go 1.99" — una versión
# de Go que no es la del go.mod del módulo. Es una de las tres falsedades P0
# que motivaron bodycheck (§9), y es una violación DURA (la clase advisory —
# claves YAML — no mata al binario, por eso la rotura elegida es la de versión
# de Go, que sí muerde con -strict).
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

# Árbol completo: bodycheck se compila con `go run` contra el módulo real
# (importa pkg/model para validar tags db: con el parser de verdad).
fx_copy_tree "$ROOT/nucleus" "$TREE"

cat > "$TREE/website/docs/qm7-fixture-probe.md" <<'MD'
# Probe page (guard-of-guards fixture)

This framework requires Go 1.99 or newer.
MD
fx_assert_doctored "$TREE/website/docs/qm7-fixture-probe.md" 'Go 1\.99'

echo "workdir=$TREE"
echo "expect=body-content falsehood"
