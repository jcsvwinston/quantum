#!/usr/bin/env bash
# check_site_posture.sh — el gate del sitio en el arco A11: lo que el banco del
# sitio REGISTRA es lo que MIDE, y lo que el arco dejó en él no retrocede sin
# que alguien lo escriba.
#
# A11 dejó en el paraguas un banco de 12 controles sobre el sitio de la suite:
# la página que explica por qué elegirla, con sus cifras atadas a su fuente;
# tres tutoriales y dos guías de migración ejecutados en una lane; la
# referencia de la API, el catálogo de `nucleus add` y un post por set,
# generados del pin. W1…W4 lo llevaron de 0 a 12 de 12.
#
#   tests/sitebench/sitebench.sh   12 controles, cada uno con su sonda y su veredicto registrado
#
# Hasta este guard el banco no lo corría nadie: ni la certificación ni ningún
# workflow. Sus sondas se apoyan en otros guards (umbrella-why-quantum,
# umbrella-generated-pages) y en la lane tutorials-smoke, pero lo que sólo el
# banco comprueba —que una página siga en el sidebar, que un script de
# tutoriales lo siga llamando un workflow, que la frase del catálogo no vuelva—
# podía romperse sin que nada se pusiera rojo.
#
# A diferencia de los bancos de producto, el del sitio no publica su cifra en
# una página: la frontera que vigila este guard es la de la tabla registrada
# con lo que las sondas miden hoy, y la del suelo que el arco alcanzó.
#
# Lo que comprueba, en el ÁRBOL PINADO:
#
#   1. el banco existe, tiene sus 12 controles sin ids repetidos, cada uno con
#      un veredicto reconocible, y cada uno que no está `present` lleva nota
#      que diga qué falta;
#   2. el suelo: 12 controles `present` registrados. Bajar un veredicto
#      registrado para que el banco vuelva a verde (la salida fácil cuando una
#      sonda se pone roja) exige bajar también este suelo, en el mismo cambio y
#      a la vista;
#   3. el banco corre y sale con 0 —lo medido es lo registrado, su propio
#      contrato—, y la cifra que imprime es la que cuenta su tabla.
#
# Lo que NO comprueba: el HTML construido. El banco lee las fuentes del sitio
# (website/docs, los sidebars, los workflows) y los guards que llama leen el
# árbol al pin; no necesita `npm run build` ni red. Los posts por set sí
# necesitan los tags de suite del paraguas (en CI, checkout con
# fetch-depth: 0), como umbrella-generated-pages.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

BENCH=tests/sitebench/sitebench.sh
EXPECTED_CONTROLS=12
# El suelo de A11: W1…W4 cerraron el banco con 12 de 12 (quantum#257, #255,
# #260, #266).
PRESENT_FLOOR=12

fail=0
report() { echo "FAIL: site-posture — $1" >&2; fail=1; }

# 1. El banco existe y cada control lleva veredicto (y nota si no es present).
if [[ ! -f "$BENCH" ]]; then
  report "falta $BENCH — el numerador del sitio de A11 no está en el árbol"
  echo "site-posture: sin banco, no hay nada más que comprobar" >&2
  exit 1
fi

# Las filas de CONTROLS: "id|familia|veredicto|título|nota".
rows=$(sed -nE 's/^[[:space:]]*"(ST-[0-9]+\|[^"]*)"[[:space:]]*$/\1/p' "$BENCH")
counts=$(printf '%s\n' "$rows" | awk -F'|' 'NF {
  v = $3
  if (v != "present" && v != "partial" && v != "absent") { print "BAD " $1; next }
  if (v != "present" && $5 == "") print "NONOTE " $1
  print v
}')

bad=$(printf '%s\n' "$counts" | grep '^BAD ' | sed 's/^BAD //' | tr '\n' ' ')
nonote=$(printf '%s\n' "$counts" | grep '^NONOTE ' | sed 's/^NONOTE //' | tr '\n' ' ')
dups=$(printf '%s\n' "$rows" | cut -d'|' -f1 | sort | uniq -d | tr '\n' ' ')
present=$(printf '%s\n' "$counts" | grep -c '^present$' || true)
partial=$(printf '%s\n' "$counts" | grep -c '^partial$' || true)
absent=$(printf '%s\n' "$counts" | grep -c '^absent$' || true)
total=$((present + partial + absent))

[[ -n "${bad// /}" ]] && report "controles sin veredicto reconocible (present/partial/absent): $bad"
[[ -n "${nonote// /}" ]] && report "controles sin nota que diga qué falta: $nonote"
[[ -n "${dups// /}" ]] && report "ids repetidos en el banco: $dups"
if [[ "$total" -lt "$EXPECTED_CONTROLS" ]]; then
  report "el banco tiene $total controles; se registraron $EXPECTED_CONTROLS en A11 — ¿se borró alguno?"
fi

# 2. El suelo.
if [[ "$present" -lt "$PRESENT_FLOOR" ]]; then
  report "el banco registra $present controles present; el suelo de A11 es $PRESENT_FLOOR — si el retroceso es real, bájalo aquí en el mismo cambio y escribe por qué"
fi

# 3. El banco corre y lo medido es lo registrado.
out=$(bash "$BENCH" 2>&1)
ec=$?
if [[ "$ec" -ne 0 ]]; then
  report "el banco del sitio falla (EXIT=$ec): lo medido no es lo registrado"
  printf '%s\n' "$out" | grep -E '^(FAIL|  )' | head -20 | sed 's/^/    /' >&2
else
  measured=$(printf '%s\n' "$out" | sed -nE 's/^OK: sitebench — ([0-9]+)\/([0-9]+) presentes.*/\1 \2/p' | tail -1)
  if [[ -z "$measured" ]]; then
    report "el banco salió con 0 sin imprimir su cifra («OK: sitebench — N/M presentes»)"
  elif [[ "$measured" != "$present $total" ]]; then
    report "el banco imprime ${measured/ //} y su tabla registra $present/$total"
  fi
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "OK: site-posture — banco del sitio $present/$total present (suelo $PRESENT_FLOOR), lo medido es lo registrado"
