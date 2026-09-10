#!/usr/bin/env bash
# Fixture de umbrella-deprecations. Dos roturas, las dos formas en que una
# nota de deprecación deja de ser una promesa:
#
# (A) la nota pierde su cláusula de retirada. Es el estado por defecto —
#     `// Deprecated: use X.` es lo que sale de escribirlo sin pensar en el
#     calendario— y convierte la deprecación en una etiqueta permanente:
#     nadie puede planificar contra ella y nadie tiene motivo para quitarla.
#
# (B) la nota promete una versión que YA está publicada. Es peor que (A)
#     porque parece un compromiso: el lector entiende que el símbolo ya no
#     debería existir, y existe. Lo tenía quark de verdad —el alias
#     `RowLevelSecurity` prometía retirarse «in v1.0» con quark en v1.12.0—,
#     que es por lo que este guard se escribió.
#
# El árbol parte del estado REAL al pin, que desde quark#373 es conforme, así
# que el EXIT!=0 es atribuible a la rotura y no al punto de partida.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

# El guard lee el pin de cada producto del manifiesto y exige que los tres
# submódulos existan, así que los tres viajan en la copia. De nucleus y orbit
# basta un fichero: lo que se comprueba es que el guard los recorre sin
# tropezar, no lo que contienen (ninguno tiene deprecaciones a mano).
fx_copy "$ROOT" "$TREE" versions.yaml scripts/check_deprecations.sh
# Los avisos DEP viajan también: el guard exige que el DEP-YYYY-NNN que cita
# cada marca exista en <repo>/docs/deprecations/, y sin ellos la copia moriría
# por una causa de setup en vez de por la rotura declarada.
fx_copy "$ROOT" "$TREE" quark/quarkdriver/listener.go quark/tenant_router.go quark/docs/deprecations
mkdir -p "$TREE/nucleus" "$TREE/orbit"
: > "$TREE/nucleus/vacio.go"
: > "$TREE/orbit/vacio.go"

python3 - "$TREE/quark/quarkdriver/listener.go" "$TREE/quark/tenant_router.go" <<'PY'
import re, sys

listener, tenant = sys.argv[1], sys.argv[2]

# (A) UNA nota pierde su cláusula: vuelve a no decir cuándo se retira.
s = open(listener, encoding='utf-8').read()
s, n = re.subn(r'\n// Scheduled for removal in v[0-9.]+, no earlier than [0-9-]+\.', '', s, count=1)
assert n == 1, 'la fixture no encontró ninguna cláusula de retirada en listener.go'
open(listener, 'w', encoding='utf-8').write(s)

# (B) la nota del alias promete una versión que el manifiesto ya pina como
# publicada. v1.0.0 es anterior a cualquier pin de quark que este repo haya
# certificado, así que la rotura no caduca con el set.
t = open(tenant, encoding='utf-8').read()
t, n = re.subn(r'Scheduled for removal in v[0-9.]+, no earlier than [0-9-]+\.',
               'Scheduled for removal in v1.0.0, no earlier than 2020-01-01.', t, count=1)
assert n == 1, 'la fixture no encontró la cláusula de RowLevelSecurity'
open(tenant, 'w', encoding='utf-8').write(t)
PY

fx_assert_doctored "$TREE/quark/tenant_router.go" 'removal in v1\.0\.0, no earlier than 2020-01-01\.'

echo "workdir=$TREE"
echo "expect=listener\.go:[0-9]+ — la deprecación no dice cuándo se retira"
echo "expect=tenant_router\.go:[0-9]+ — promete retirarse en v1\.0\.0 y quark ya va por v"
