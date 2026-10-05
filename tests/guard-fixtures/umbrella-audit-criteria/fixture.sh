#!/usr/bin/env bash
# Fixture de umbrella-audit-criteria. El árbol parte del estado real —el
# guard, la escala, los informes del 2026-09-03 y cada instrumento que la
# escala nombra, copiado de su sitio al pin—, así que el EXIT!=0 es atribuible
# a las roturas. Las cinco son la misma clase: la escala de la re-auditoría
# sigue leyéndose como completa y medida cuando ya no lo es.
#
# (A) el instrumento de una fila apunta a una ruta que ya no existe: un banco
#     renombrado deja la fila nombrando algo que nadie puede abrir.
# (B) falta una dimensión: una escala con 35 filas compara 35 con 36 y la
#     re-auditoría «completa» deja una sin puntuar.
# (C) una fila sin instrumento: ni ruta ni «juicio», la fila no dice cómo se
#     mide.
# (D) la nota del 2026-09-03 de una fila no es la del informe: la línea base
#     contra la que R1 mide el avance se corre en silencio.
# (E) una re-auditoría consolidada (notas.csv) se deja una dimensión y da una
#     nota fuera de la escala: es lo que R1 escribe, y el guard tiene que
#     verlo antes de que exista la primera.
#
# Las filas se eligen por posición, no por nombre: la escala puede ganar
# notas o instrumentos sin que la fixture caduque.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_audit_criteria.sh docs/auditoria/criterios-5.csv \
  docs/auditoria/madurez-2026-09-03

# Cada instrumento de la escala, de su sitio real; una ruta dentro de otra ya
# copiada no se vuelve a copiar (cp -R la anidaría).
copiadas=""
while IFS= read -r ruta; do
  [[ -n "$ruta" ]] || continue
  dentro=0
  for c in $copiadas; do
    [[ "$ruta" == "$c"/* ]] && dentro=1
  done
  [[ $dentro -eq 1 ]] && continue
  fx_copy "$ROOT" "$TREE" "$ruta"
  copiadas+=" $ruta"
done < <(python3 - "$ROOT/docs/auditoria/criterios-5.csv" <<'PYEOF'
import csv
import sys

rutas = set()
for r in csv.DictReader(open(sys.argv[1], encoding='utf-8', newline='')):
    for e in r['instrumento'].split(';'):
        e = e.strip()
        if e and e != 'juicio':
            rutas.add(e)
print('\n'.join(sorted(rutas)))
PYEOF
)

python3 - "$TREE/docs/auditoria/criterios-5.csv" "$TREE/docs/auditoria/reauditoria/2099-01-01/notas.csv" <<'PYEOF'
import csv
import os
import sys

p, notas = sys.argv[1], sys.argv[2]
filas = list(csv.reader(open(p, encoding='utf-8', newline='')))
cab, datos = filas[0], filas[1:]
col = {c: i for i, c in enumerate(cab)}
if len(datos) < 5:
    raise SystemExit('fixture: la escala tiene menos de cinco filas que romper')

# (A) la primera fila con una ruta: esa ruta deja de existir.
a = next(f for f in datos if any(e.strip() not in ('', 'juicio') for e in f[col['instrumento']].split(';')))
elems = [e.strip() for e in a[col['instrumento']].split(';')]
k = next(i for i, e in enumerate(elems) if e not in ('', 'juicio'))
elems[k] += '-retirado'
a[col['instrumento']] = '; '.join(elems)
print('fixture: (A) instrumento inexistente en', a[col['dimension']], '→', elems[k])

resto = [f for f in datos if f is not a]
# (C) otra fila, sin instrumento.
c = resto[0]
c[col['instrumento']] = ''
print('fixture: (C) sin instrumento en', c[col['dimension']])
# (D) otra, con una nota del 2026-09-03 que no es la del informe.
d = resto[1]
d[col['nota_2026_09_03']] = '5' if d[col['nota_2026_09_03']] != '5' else '1'
print('fixture: (D) nota cambiada en', d[col['dimension']])
# (B) la última fila desaparece.
b = resto[-1]
datos.remove(b)
print('fixture: (B) dimensión borrada', b[col['dimension']])

with open(p, 'w', encoding='utf-8', newline='') as f:
    w = csv.writer(f, lineterminator='\n')
    w.writerow(cab)
    w.writerows(datos)

# (E) la re-auditoría puntúa todas las de la escala menos una, y una fuera
# de la escala.
os.makedirs(os.path.dirname(notas), exist_ok=True)
with open(notas, 'w', encoding='utf-8', newline='') as f:
    w = csv.writer(f, lineterminator='\n')
    w.writerow(['pilar', 'dimension', 'nota', 'evidencia'])
    for i, fila in enumerate(datos[:-1]):
        w.writerow([fila[col['pilar']], fila[col['dimension']], '6' if i == 0 else '4', 'fixture'])
print('fixture: (E) notas.csv sin', datos[-1][col['dimension']], 'y con un 6')
PYEOF

fx_assert_doctored "$TREE/docs/auditoria/criterios-5.csv" -retirado

echo "workdir=$TREE"
echo "expect=el instrumento .*-retirado» no existe en el árbol"
echo "expect=falta la dimensión «"
echo "expect=sin instrumento: nombra una ruta"
echo "expect=la nota del 2026-09-03 es"
echo "expect=notas.csv: falta la nota de «"
echo "expect=nota «6» fuera de la escala"
