#!/usr/bin/env bash
# check_audit_criteria.sh — la escala de la re-auditoría está en el repo, es
# completa y cada fila nombra con qué se mide (arco A12, sesión R0; QM-21).
#
# La auditoría de madurez del 2026-09-03 puntuó 36 dimensiones de 1 a 5, y lo
# que significaba un 5 en cada una vivía sólo en un artefacto fuera del repo:
# repetirla obligaba a reconstruir la escala. Ahora vive en
# docs/auditoria/criterios-5.csv, y este guard falla si:
#
#   1. el fichero no existe o su cabecera no es la convenida;
#   2. falta una dimensión que los informes del 2026-09-03 puntuaron, sobra
#      una que no puntuaron, o una está repetida. La lista sale de los
#      PROPIOS informes (la tabla «Dimensión | Nota (1-5)» de nucleus, orbit
#      y suite, y la línea «Notas de madurez» de quark), no de una lista
#      escrita aquí: una escala con una dimensión de menos compara 35 con 36;
#   3. la nota del 2026-09-03 de una fila no es la que el informe le dio;
#   4. una fila deja vacío el listón, el 1, el 3 o el 5, o lleva un arco que
#      no es A<n> ni «—»;
#   5. una fila no dice con qué se mide: cada elemento de `instrumento`
#      (separados por «;») es una ruta que EXISTE en el árbol —del paraguas o
#      de un producto al pin— o la palabra «juicio». Un instrumento que nadie
#      puede abrir es un juicio con otro nombre;
#   6. una re-auditoría ya consolidada (docs/auditoria/reauditoria/<fecha>/
#      notas.csv) no puntúa exactamente esas dimensiones, da una nota fuera
#      de la escala (1 a 5, en medios puntos) o una sin evidencia.
#
# Lo que NO comprueba: que la nota sea justa. Eso es la re-auditoría.
#
# Uso: bash scripts/check_audit_criteria.sh   (desde la raíz del paraguas,
#      con los submódulos al pin: las rutas de producto se buscan en ellos)
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

python3 - <<'PYEOF'
import csv
import glob
import os
import re
import sys

CRIT = "docs/auditoria/criterios-5.csv"
INF = "docs/auditoria/madurez-2026-09-03"
HEADER = ["pilar", "dimension", "nota_2026_09_03", "liston", "uno", "tres",
          "cinco", "arcos", "instrumento", "notas"]
NOTAS_HEADER = ["pilar", "dimension", "nota", "evidencia"]
PILARES = ("quark", "nucleus", "orbit", "suite")
fails = []


def fail(msg):
    fails.append(msg)
    print("FAIL: " + msg, file=sys.stderr)


def nota(txt):
    t = txt.strip().strip("*").replace(",", ".")
    try:
        return float(t)
    except ValueError:
        return None


# --- La lista de dimensiones, leída de los informes del 2026-09-03 ---------
def tabla_notas(path):
    """Filas de la tabla «| Dimensión | Nota (1-5) | …» de un informe."""
    dims = []
    with open(path, encoding="utf-8") as f:
        lineas = f.read().splitlines()
    for i, ln in enumerate(lineas):
        if re.match(r"^\|\s*Dimensión\s*\|\s*Nota \(1-5\)\s*\|", ln):
            for fila in lineas[i + 2:]:
                if not fila.startswith("|"):
                    break
                celdas = [c.strip() for c in fila.strip().strip("|").split("|")]
                dims.append((celdas[0], nota(celdas[1])))
            break
    return dims


def linea_quark(path):
    """«Notas de madurez (1-5): **API/query 4 · migraciones 3 · …**»."""
    with open(path, encoding="utf-8") as f:
        for ln in f:
            m = re.match(r"^Notas de madurez \(1-5\):\s*\*\*(.+)\*\*", ln.strip())
            if not m:
                continue
            dims = []
            for parte in m.group(1).split(" · "):
                parte = re.sub(r"\([^)]*\)", "", parte).strip()
                mm = re.match(r"^(.*\S)\s+([0-9]+(?:[.,][0-9])?)$", parte)
                if mm:
                    dims.append((mm.group(1), nota(mm.group(2))))
            return dims
    return []


esperadas = {}
fuentes = {"quark": linea_quark, "nucleus": tabla_notas,
           "orbit": tabla_notas, "suite": tabla_notas}
for pilar, lector in fuentes.items():
    path = f"{INF}/{pilar}.md"
    if not os.path.isfile(path):
        fail(f"falta el informe {path}: sin él no se sabe qué dimensiones puntuó la auditoría")
        continue
    dims = lector(path)
    if not dims:
        fail(f"{path}: no se encontró la tabla de notas (¿cambió su formato?) — la lista de dimensiones sale de ahí")
    for d, n in dims:
        esperadas[(pilar, d)] = n

# --- La escala ---------------------------------------------------------------
if not os.path.isfile(CRIT):
    fail(f"falta {CRIT}: la escala de la re-auditoría no está en el repo (QM-21)")
    sys.exit(1)

with open(CRIT, encoding="utf-8", newline="") as f:
    filas = list(csv.reader(f))
if not filas or filas[0] != HEADER:
    fail(f"{CRIT}: la cabecera tiene que ser «{','.join(HEADER)}»")
    sys.exit(1)

vistas = {}
n_juicio = n_instr = 0
for num, fila in enumerate(filas[1:], start=2):
    if not any(c.strip() for c in fila):
        continue
    if len(fila) != len(HEADER):
        fail(f"{CRIT}:{num}: {len(fila)} columnas, se esperaban {len(HEADER)}")
        continue
    r = dict(zip(HEADER, (c.strip() for c in fila)))
    clave = (r["pilar"], r["dimension"])
    etiqueta = f"{r['pilar']} · {r['dimension']}"
    if r["pilar"] not in PILARES:
        fail(f"{CRIT}:{num}: pilar «{r['pilar']}» no es {'|'.join(PILARES)}")
    if clave in vistas:
        fail(f"{CRIT}:{num}: dimensión repetida «{etiqueta}» (ya en la línea {vistas[clave]})")
        continue
    vistas[clave] = num
    if clave not in esperadas:
        fail(f"{CRIT}:{num}: «{etiqueta}» no es una dimensión que la auditoría del 2026-09-03 puntuara (el nombre es el de la tabla de notas de su informe)")
    else:
        n = nota(r["nota_2026_09_03"])
        if n is None or n != esperadas[clave]:
            fail(f"{CRIT}:{num}: «{etiqueta}» — la nota del 2026-09-03 es {esperadas[clave]:g} según {INF}/{r['pilar']}.md, y la fila dice «{r['nota_2026_09_03']}»")
    for col in ("liston", "uno", "tres", "cinco"):
        if not r[col]:
            fail(f"{CRIT}:{num}: «{etiqueta}» — la columna «{col}» está vacía: la escala dice qué es un 1, un 3 y un 5, y contra qué")
    for a in r["arcos"].split():
        if a != "—" and not re.fullmatch(r"A[1-9][0-9]*", a):
            fail(f"{CRIT}:{num}: «{etiqueta}» — arco «{a}» no es A<n> ni «—»")
    elementos = [e.strip() for e in r["instrumento"].split(";") if e.strip()]
    if not elementos:
        fail(f"{CRIT}:{num}: «{etiqueta}» — sin instrumento: nombra una ruta del árbol que lo mida, o di «juicio»")
        continue
    solo_juicio = True
    for e in elementos:
        if e == "juicio":
            continue
        solo_juicio = False
        if e.startswith("/") or ".." in e.split("/"):
            fail(f"{CRIT}:{num}: «{etiqueta}» — instrumento «{e}»: una ruta relativa a la raíz del paraguas, sin «..»")
        elif not os.path.exists(e):
            fail(f"{CRIT}:{num}: «{etiqueta}» — el instrumento «{e}» no existe en el árbol (¿al pin? ¿submódulos sin iniciar?)")
    if solo_juicio:
        n_juicio += 1
    else:
        n_instr += 1

for clave in esperadas:
    if clave not in vistas:
        fail(f"{CRIT}: falta la dimensión «{clave[0]} · {clave[1]}», que la auditoría del 2026-09-03 puntuó con {esperadas[clave]:g}")

# --- Las re-auditorías consolidadas -------------------------------------------
escala = {x / 2 for x in range(2, 11)}  # 1, 1.5, … 5
n_notas = 0
for path in sorted(glob.glob("docs/auditoria/reauditoria/*/notas.csv")):
    n_notas += 1
    with open(path, encoding="utf-8", newline="") as f:
        nfilas = list(csv.reader(f))
    if not nfilas or nfilas[0] != NOTAS_HEADER:
        fail(f"{path}: la cabecera tiene que ser «{','.join(NOTAS_HEADER)}»")
        continue
    puntuadas = {}
    for num, fila in enumerate(nfilas[1:], start=2):
        if not any(c.strip() for c in fila):
            continue
        if len(fila) != len(NOTAS_HEADER):
            fail(f"{path}:{num}: {len(fila)} columnas, se esperaban {len(NOTAS_HEADER)}")
            continue
        r = dict(zip(NOTAS_HEADER, (c.strip() for c in fila)))
        clave = (r["pilar"], r["dimension"])
        etiqueta = f"{r['pilar']} · {r['dimension']}"
        if clave in puntuadas:
            fail(f"{path}:{num}: dimensión puntuada dos veces «{etiqueta}»")
        puntuadas[clave] = num
        if clave not in vistas:
            fail(f"{path}:{num}: «{etiqueta}» no está en {CRIT}: una re-auditoría puntúa las mismas dimensiones, con los mismos nombres")
        if nota(r["nota"]) not in escala:
            fail(f"{path}:{num}: «{etiqueta}» — nota «{r['nota']}» fuera de la escala (1 a 5, en medios puntos)")
        if not r["evidencia"]:
            fail(f"{path}:{num}: «{etiqueta}» — nota sin evidencia: qué se corrió o qué se leyó")
    for clave in vistas:
        if clave not in puntuadas:
            fail(f"{path}: falta la nota de «{clave[0]} · {clave[1]}»: una re-auditoría puntúa las {len(vistas)} dimensiones de la escala")

if fails:
    sys.exit(1)
por_pilar = " · ".join(f"{p} {sum(1 for k in vistas if k[0] == p)}" for p in PILARES)
print(f"OK: audit-criteria — {len(vistas)} dimensiones ({por_pilar}), las mismas que puntuó la auditoría del 2026-09-03; "
      f"{n_instr} con instrumento en el árbol, {n_juicio} sólo con juicio; {n_notas} re-auditoría(s) consolidada(s)")
PYEOF
