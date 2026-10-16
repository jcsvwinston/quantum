#!/usr/bin/env bash
# Fixture de umbrella-deprecations. Cinco roturas: las dos formas en que una
# MARCA de deprecación deja de ser una promesa, y las tres en que un AVISO o
# la lista cerrada del major dejan de contar lo mismo (M0-G de A12, QM-20):
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
# (C) un aviso `active` sin versión ni fecha cuya fila del §3.0 está en
#     `publicado`. Es el caso que se distingue del tolerado: DEP-2026-003 de
#     nucleus (filas de política de 3 columnas) está `active` sin fecha AL
#     PIN y se AVISA porque su fila está `en main` (D2 se decidió el
#     2026-10-16, nucleus#630 escribió la fecha y el set la trae); aquí se le quita la viñeta
#     «Behaviour flip» a DEP-2026-013, cuya fila dice `publicado`, y eso
#     tiene que FALLAR. Si el guard dejara de distinguir los dos casos, o
#     tolerara cualquier aviso sin fecha, esta rotura pasaría.
#
# (D) una fila `publicado` del §3.0 cuyo fichero no está al pin: se borra
#     el aviso DEP-2026-014 de la copia de nucleus. Es la mitad «la tabla no
#     afirma lo que el pin no tiene».
#
# (E) un aviso `active` al pin que nombra el major y no está en la tabla:
#     se quita la fila 1 (quark DEP-2026-001) de la copia del contrato. Es
#     la mitad «el guard ve el 100 % de lo que va al major»: sin ella, un
#     aviso publicado fuera de la lista cerrada saldría verde.
#
# El árbol parte del estado REAL al pin, que es conforme, así que el EXIT!=0
# es atribuible a las roturas y no al punto de partida. Las cinco son
# independientes —cada una muerde en un fichero o una fila distintos— y el
# harness exige las cinco causas, así que ninguna tapa a otra.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

# El guard lee el pin de cada producto del manifiesto, la tabla del §3.0 del
# contrato del 2.0, y exige que los tres submódulos existan, así que todo
# eso viaja en la copia. De orbit basta un fichero: lo que se comprueba es
# que el guard lo recorre sin tropezar y dice que no tiene docs/deprecations/.
fx_copy "$ROOT" "$TREE" versions.yaml scripts/check_deprecations.sh docs/planes/quantum-2.0.md
# Las marcas de quark y los avisos de quark y nucleus viajan enteros: el
# guard exige que el DEP-YYYY-NNN que cita cada marca exista, que cada fila
# `publicado` tenga su fichero y que cada aviso `active` esté en la tabla;
# sin ellos la copia moriría por una causa de setup en vez de por las
# roturas declaradas. Las marcas de nucleus no hacen falta (ninguna rotura
# las toca) y un .go vacío basta para que el recorrido de A no tropiece.
fx_copy "$ROOT" "$TREE" quark/quarkdriver/listener.go quark/tenant_router.go quark/docs/deprecations nucleus/docs/deprecations
mkdir -p "$TREE/nucleus" "$TREE/orbit"
: > "$TREE/nucleus/vacio.go"
: > "$TREE/orbit/vacio.go"

python3 - "$TREE/quark/quarkdriver/listener.go" "$TREE/quark/tenant_router.go" \
          "$TREE"/nucleus/docs/deprecations/DEP-2026-013-*.md "$TREE/docs/planes/quantum-2.0.md" <<'PY'
import re, sys

listener, tenant, dep013, contrato = sys.argv[1:5]

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

# (C) el aviso DEP-2026-013 pierde la viñeta entera que dice cuándo voltea
# (con sus líneas de continuación sangradas): queda `active`, con fila
# `publicado`, y sin versión ni fecha.
d = open(dep013, encoding='utf-8').read()
d, n = re.subn(r'\n- Behaviour flip:[^\n]*(?:\n  [^\n]*)*', '', d, count=1)
assert n == 1, 'la fixture no encontró la viñeta «Behaviour flip» de DEP-2026-013'
assert 'no earlier than' not in d.split('\n## ', 1)[0], 'la cabecera de DEP-2026-013 sigue diciendo cuándo'
open(dep013, 'w', encoding='utf-8').write(d)

# (E) la fila 1 del §3.0 (quark DEP-2026-001, publicado) desaparece de la
# tabla: el aviso sigue al pin, nombra v2.0.0 y ya no está en la lista.
c = open(contrato, encoding='utf-8').read()
c, n = re.subn(r'\n\| 1 \| quark \|[^\n]*DEP-2026-001[^\n]*', '', c, count=1)
assert n == 1, 'la fixture no encontró la fila 1 (quark DEP-2026-001) del §3.0'
open(contrato, 'w', encoding='utf-8').write(c)
PY

# (D) la fila 15 del §3.0 dice `publicado` y su fichero no está en la copia.
rm "$TREE"/nucleus/docs/deprecations/DEP-2026-014-*.md

fx_assert_doctored "$TREE/quark/tenant_router.go" 'removal in v1\.0\.0, no earlier than 2020-01-01\.'
fx_assert_doctored "$TREE/docs/planes/quantum-2.0.md" '^\| 2 \| quark \|'
if grep -q '^| 1 | quark |' "$TREE/docs/planes/quantum-2.0.md"; then
  echo "fixture: la fila 1 del §3.0 sigue en la copia del contrato" >&2
  exit 1
fi
if ls "$TREE"/nucleus/docs/deprecations/DEP-2026-014-*.md >/dev/null 2>&1; then
  echo "fixture: el aviso DEP-2026-014 sigue en la copia de nucleus" >&2
  exit 1
fi

echo "workdir=$TREE"
echo "expect=listener\.go:[0-9]+ — la deprecación no dice cuándo se retira"
echo "expect=tenant_router\.go:[0-9]+ — promete retirarse en v1\.0\.0 y quark ya va por v"
echo "expect=DEP-2026-013-[^ ]*\.md — el aviso no dice cuándo se retira o cambia"
echo "expect=§3\.0 fila 15 — nucleus DEP-2026-014 dice \`publicado\` y no hay nucleus/docs/deprecations/DEP-2026-014-\*\.md al pin"
echo "expect=DEP-2026-001-rowlevelsecurity-alias\.md — nombra v2\.0\.0 \(el major\) y no está en la tabla del §3\.0"
