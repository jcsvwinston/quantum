#!/usr/bin/env bash
# Fixture de umbrella-audit-backlog. Cuatro roturas y una aceptación, sobre una
# copia del guard, el registro y los seis informes:
#
# (A) un hallazgo abierto pierde su arco. Es la clase exacta que el guard
#     existe para impedir: un hallazgo sin dueño que nadie vuelve a mirar.
# (B) una fila del registro aparece dos veces con el mismo id. Hubo dos NU-50
#     hasta el 2026-10-04 y nada lo vio: la comprobación de cobertura compara
#     conjuntos, y en un conjunto los repetidos desaparecen (QM-21).
# (C) una fila de la tabla de defectos de un informe aparece dos veces: el
#     mismo agujero del lado de los informes, por donde entró el NU-50 doble.
# (D) un informe de re-auditoría (docs/auditoria/reauditoria/<fecha>/) trae un
#     hallazgo sin fila en el registro, y otro que conserva el id provisional
#     con el que lo escribió su auditor («quark.1»). El registro es uno para
#     todo el plan: si el guard dejara de leer esos informes, o no viera una
#     fila cuyo id no tiene forma de id, R1 consolidaría a ciegas.
# (E) ACEPTACIÓN: un hallazgo abierto pasa a A13. Lo que la re-auditoría deje
#     abierto va a un arco nuevo (A12 R2), y un guard con techo en A12 lo
#     rechazaría como «sin arco». El harness sólo sabe exigir que algo SALGA,
#     así que lo que se exige es la línea INFO de A13: el guard la imprime
#     sólo para los arcos que acepta, con la misma regla que valida la fila.
#
# Las filas se eligen por posición y estado, no por id: la fixture nombraba
# QK-14, QK-14 se cerró en 1.30.0 y la fixture murió preparándose. Si un día no
# queda ninguna fila abierta, se abren filas cerradas en la copia.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_audit_backlog.sh docs/auditoria/madurez-2026-09-03
D="$TREE/docs/auditoria/madurez-2026-09-03"

python3 - "$D/registro.csv" <<'PYEOF'
import sys

p = sys.argv[1]
lineas = open(p, encoding='utf-8').read().splitlines(keepends=True)
datos = [i for i, ln in enumerate(lineas) if not ln.startswith('#') and not ln.startswith('id,') and ln.strip()]
abiertas = [i for i in datos if lineas[i].split(',')[4] == 'abierto']
cerradas = [i for i in datos if i not in abiertas]
candidatas = abiertas + cerradas
if len(candidatas) < 3:
    raise SystemExit('fixture: el registro tiene menos de tres filas que romper')
a, e = candidatas[0], candidatas[1]
b = next(i for i in datos if i not in (a, e))
copia = lineas[b] if lineas[b].endswith('\n') else lineas[b] + '\n'


def poner(i, arco):
    campos = lineas[i].split(',')
    campos[3], campos[4] = arco, 'abierto'
    lineas[i] = ','.join(campos)
    return campos[0]


print('fixture: (A) arco borrado en', poner(a, ''))
print('fixture: (E) pasa a A13', poner(e, 'A13'))
if not lineas[-1].endswith('\n'):
    lineas[-1] += '\n'
lineas.append(copia)
print('fixture: (B) fila duplicada', copia.split(',')[0])
open(p, 'w', encoding='utf-8').write(''.join(lineas))
PYEOF

# (C) la primera fila de defectos de suite.md, dos veces.
python3 - "$D/suite.md" <<'PYEOF'
import re
import sys

p = sys.argv[1]
lineas = open(p, encoding='utf-8').read().splitlines(keepends=True)
for i, ln in enumerate(lineas):
    if re.match(r'^\| QM-[0-9]+ \| \**P[0-3]', ln):
        lineas.insert(i + 1, ln)
        print('fixture: (C) fila repetida en suite.md:', ln.split('|')[1].strip())
        break
else:
    raise SystemExit('fixture: suite.md no tiene filas de defectos QM- que repetir')
open(p, 'w', encoding='utf-8').write(''.join(lineas))
PYEOF

# (D) un informe de re-auditoría con un hallazgo que el registro no tiene.
mkdir -p "$TREE/docs/auditoria/reauditoria/2099-01-01"
cat > "$TREE/docs/auditoria/reauditoria/2099-01-01/quark.md" <<'MDEOF'
# Quark — re-auditoría de prueba

| id | Sev | Fichero:línea | Evidencia | Corrección propuesta |
|---|---|---|---|---|
| QK-9999 | **P2** | `client.go:1` | hallazgo de la fixture | ninguna |
| quark.1 | P3 | `client.go:2` | id provisional que la consolidación no cambió | ninguna |
MDEOF

fx_assert_doctored "$D/registro.csv" ',A13,abierto,'

echo "workdir=$TREE"
echo "expect=abierto y sin arco del plan"
echo "expect=id duplicado en registro.csv"
echo "expect=id repetido en las tablas de los informes: QM-"
echo "expect=sin fila en registro.csv: .*QK-9999"
echo "expect=fila de defecto sin id válido .*quark\\.1"
echo "expect=INFO: A13 abiertos"
