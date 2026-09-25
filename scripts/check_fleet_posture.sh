#!/usr/bin/env bash
# check_fleet_posture.sh — el gate del arco A9: lo que la suite AFIRMA sobre el
# plano fleet de Orbit —un fleet, una UI web— tiene que ser lo que sus propias
# medidas dicen.
#
# A9 dejó un banco de 50 controles y una página en orbit, la mitad de navegador
# del banco sobre la UI del fleet, y un test que pone TRES agentes detrás de
# DOS servidores y pregunta a los dos lo que el panel de A6 responde para una
# aplicación. El problema que cierra este guard es el de A5, A6, A7 y A8: un
# documento medido sigue siendo un fichero de texto. Nada impide subir la cifra
# publicada, dejar la tabla por familias tres sesiones rancia bajo un titular
# al día (pasó), borrar la nota de un control que no está, quitar el test del
# clúster, o dejar la lane de navegador en verde cuando el navegador falta — y
# el resultado seguiría leyéndose como una medición.
#
#   orbit/internal/fleettest/fleetbench/cases_*_test.go     50 controles, cada uno con su sonda y su veredicto
#   orbit/docs/fleet-bench.md                                la página que publica el numerador y el resumen por familia
#   orbit/internal/fleettest/fleetbench/browserbench_test.go la mitad de navegador (proyecto `fleet` del instrumento de A6)
#   orbit/internal/adminbench/browser/specs/fleet.spec.ts    sus controles UIF, con la violación plantada que prueba el motor
#   orbit/internal/fleettest/fleetbench/cluster_test.go      el clúster de tres agentes: la paridad de A6 sobre una flota
#   orbit/.github/workflows/ci.yml                           la lane que exige el navegador y la que corre internal/fleettest
#
# Lo que comprueba, en el ÁRBOL PINADO:
#
#   1. el banco existe, tiene sus 50 controles, y cada uno que no está
#      `present` lleva nota que diga qué falta;
#   2. la página publica la MISMA cifra que cuenta el catálogo, y su tabla por
#      familias dice lo mismo familia a familia — es la parte que se retipaba;
#   3. la mitad de navegador está en el pin, planta una violación para probar
#      que el motor muerde (UIF-00), y el CI de orbit corre su driver con
#      ORBIT_BENCH_BROWSER=required — sin eso la lane se pone verde cuando el
#      navegador falta, que es decir que se midió lo que nadie midió;
#   4. el test del clúster de tres agentes está en el pin, no se salta, y la
#      lane de tests del CI de orbit corre internal/fleettest, que es donde
#      vive; es lo único del arco que mide una FLOTA y no un servidor, y fue lo
#      que encontró el node_id vacío que cincuenta sondas no podían ver.
#
# Lo que NO comprueba: que las sondas pasen. Eso lo hace `go test` en el CI de
# orbit, que es donde se ejecuta lo que mide. Este guard vigila la frontera
# entre lo medido y lo publicado, que es donde una cifra se vuelve mentira sin
# que ninguna suite se ponga roja.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

BENCH_DIR=orbit/internal/fleettest/fleetbench
BENCH_DOC=orbit/docs/fleet-bench.md
BROWSER_DRIVER=$BENCH_DIR/browserbench_test.go
BROWSER_SPEC=orbit/internal/adminbench/browser/specs/fleet.spec.ts
CLUSTER_TEST=$BENCH_DIR/cluster_test.go
CLUSTER_FUNC=TestFleetParityThreeAgents
ORBIT_CI=orbit/.github/workflows/ci.yml
EXPECTED_CONTROLS=50

fail=0
report() { echo "FAIL: fleet-posture — $1" >&2; fail=1; }

# 1. El banco existe y cada caso lleva veredicto (y nota si no es present).
if ! ls "$BENCH_DIR"/cases_*_test.go >/dev/null 2>&1; then
  report "faltan los casos del banco en $BENCH_DIR — el numerador del gate de A9 no está en el pin"
  echo "fleet-posture: sin banco, no hay nada más que comprobar" >&2
  exit 1
fi

# Cada bloque va de `{id: "` a `probe: probeX},`; el veredicto y la nota
# pueden estar en líneas distintas, así que se acumula el bloque entero.
counts=$(cat "$BENCH_DIR"/cases_*_test.go | awk '
  /\{id: "/ { block = $0; collecting = 1; next }
  collecting { block = block " " $0 }
  collecting && /probe: +probe[A-Za-z0-9_]+\},/ {
    collecting = 0
    verdict = "unknown"
    if (block ~ /want: +present/) verdict = "present"
    else if (block ~ /want: +partial/) verdict = "partial"
    else if (block ~ /want: +absent/)  verdict = "absent"
    has_note = (block ~ /note: +"/)
    match(block, /\{id: "[A-Z0-9-]+"/)
    id = substr(block, RSTART + 6, RLENGTH - 7)
    family = ""
    if (match(block, /family: +"[a-z]+"/)) {
      family = substr(block, RSTART, RLENGTH); sub(/family: +"/, "", family); sub(/"$/, "", family)
    }
    if (verdict == "unknown") { print "BAD " id; next }
    if (verdict != "present" && !has_note) print "NONOTE " id
    print verdict " " family
  }
')

bad=$(printf '%s\n' "$counts" | grep -c '^BAD ' || true)
nonote=$(printf '%s\n' "$counts" | grep '^NONOTE ' | sed 's/^NONOTE //' | tr '\n' ' ')
present=$(printf '%s\n' "$counts" | grep -c '^present ' || true)
partial=$(printf '%s\n' "$counts" | grep -c '^partial ' || true)
absent=$(printf '%s\n' "$counts" | grep -c '^absent ' || true)
total=$((present + partial + absent))

if [[ "$bad" -gt 0 ]]; then
  report "$bad caso(s) del banco sin veredicto reconocible"
fi
if [[ -n "${nonote// /}" ]]; then
  report "casos sin nota que diga qué falta: $nonote"
fi
if [[ "$total" -lt "$EXPECTED_CONTROLS" ]]; then
  report "el banco tiene $total controles; se registraron $EXPECTED_CONTROLS en A9 — ¿se borró alguno?"
fi

# 2. La página publica la misma cifra que la tabla cuenta, y su resumen por
#    familias dice lo mismo que el catálogo, familia a familia.
if [[ ! -f "$BENCH_DOC" ]]; then
  report "falta $BENCH_DOC — la cifra no se publica en ninguna parte"
else
  published=$(grep -oE '\*\*[0-9]+ of [0-9]+ controls present' "$BENCH_DOC" | head -1 | grep -oE '^\*\*[0-9]+' | tr -d '*')
  published_total=$(grep -oE '\*\*[0-9]+ of [0-9]+ controls present' "$BENCH_DOC" | head -1 | grep -oE 'of [0-9]+' | grep -oE '[0-9]+')
  if [[ -z "$published" ]]; then
    report "$BENCH_DOC no publica la cifra en la forma «**N of M controls present**»"
  elif [[ "$published" != "$present" || "$published_total" != "$total" ]]; then
    report "la página dice $published/$published_total y el banco mide $present/$total"
  fi

  # Las filas entre la cabecera `| family |` y la fila `**total**`.
  rows=$(awk -F'|' '
    /^\| family \|/ { inb = 1; next }
    inb && /^\|---/ { next }
    inb && /^\| \*\*total\*\*/ { gsub(/[* ]/, "", $3); gsub(/[* ]/, "", $4); gsub(/[* ]/, "", $5); print "TOTAL " $3 " " $4 " " $5; inb = 0; next }
    inb && /^\|/ { gsub(/ /, "", $2); gsub(/ /, "", $3); gsub(/ /, "", $4); gsub(/ /, "", $5); print "ROW " $2 " " $3 " " $4 " " $5; next }
    inb { inb = 0 }
  ' "$BENCH_DOC")
  if ! printf '%s\n' "$rows" | grep -q '^TOTAL '; then
    report "$BENCH_DOC no lleva la tabla por familias con su fila **total**"
  else
    while read -r _ fam p q r; do
      [[ -n "$fam" ]] || continue
      bp=$(printf '%s\n' "$counts" | grep -c "^present $fam\$" || true)
      bq=$(printf '%s\n' "$counts" | grep -c "^partial $fam\$" || true)
      br=$(printf '%s\n' "$counts" | grep -c "^absent $fam\$" || true)
      if [[ "$p" != "$bp" || "$q" != "$bq" || "$r" != "$br" ]]; then
        report "la tabla por familias dice $fam $p/$q/$r y el banco mide $bp/$bq/$br (present/partial/absent)"
      fi
    done < <(printf '%s\n' "$rows" | grep '^ROW ')
    read -r _ tp tq tr < <(printf '%s\n' "$rows" | grep '^TOTAL ')
    if [[ "$tp" != "$present" || "$tq" != "$partial" || "$tr" != "$absent" ]]; then
      report "la fila total de la tabla dice $tp/$tq/$tr y el banco mide $present/$partial/$absent"
    fi
    for fam in $(printf '%s\n' "$counts" | grep -E '^(present|partial|absent) ' | awk '{print $2}' | sort -u); do
      if ! printf '%s\n' "$rows" | grep -q "^ROW $fam "; then
        report "la familia $fam está en el banco y no en la tabla de la página"
      fi
    done
  fi
fi

# 3. La mitad de navegador está en el pin, se prueba a sí misma y el CI la exige.
if [[ ! -f "$BROWSER_DRIVER" ]]; then
  report "falta $BROWSER_DRIVER — lo que sólo un navegador puede medir de la UI del fleet no está en el pin"
else
  if ! grep -q 'UIF-00' "$BROWSER_DRIVER"; then
    report "el driver del navegador no registra el control que prueba su propio instrumento (UIF-00)"
  fi
  uif=$(grep -cE '\{id: "UIF-[0-9]+"' "$BROWSER_DRIVER" || true)
  if [[ "$uif" -lt 5 ]]; then
    report "el driver del navegador registra $uif controles UIF; se registraron 6 en A9"
  fi
fi
if [[ ! -f "$BROWSER_SPEC" ]]; then
  report "falta $BROWSER_SPEC — el proyecto fleet del instrumento no está en el pin"
elif ! grep -q 'UIF-00' "$BROWSER_SPEC"; then
  report "el spec del fleet no planta una violación para comprobar que el motor de accesibilidad muerde (UIF-00)"
fi

if [[ ! -f "$ORBIT_CI" ]]; then
  report "falta $ORBIT_CI — no se puede comprobar qué corre el CI de orbit"
else
  # El `required` tiene que ser el del driver del FLEET: la lane corre dos
  # drivers, y el del panel ya lo vigila admin-posture.
  if ! awk '/TestFleetBrowserBench/ { seen = NR } seen && NR <= seen + 4 && /ORBIT_BENCH_BROWSER: required/ { found = 1 } END { exit found ? 0 : 1 }' "$ORBIT_CI"; then
    report "el CI de orbit no corre TestFleetBrowserBench con ORBIT_BENCH_BROWSER=required — sin eso la lane se pone verde cuando el navegador falta"
  fi
  if ! grep -q 'working-directory: internal/fleettest' "$ORBIT_CI"; then
    report "la lane de tests del CI de orbit no corre internal/fleettest, que es donde viven el banco y el clúster"
  fi
fi

# 4. El clúster de tres agentes está en el pin y no se salta.
if [[ ! -f "$CLUSTER_TEST" ]]; then
  report "falta $CLUSTER_TEST — el gate de A9 pedía la paridad de A6 sobre un clúster de tres agentes y no está en el pin"
else
  if ! grep -qE "^func $CLUSTER_FUNC\(" "$CLUSTER_TEST"; then
    report "$CLUSTER_TEST ya no define $CLUSTER_FUNC: el test del clúster de tres agentes no existe"
  fi
  if grep -qE 't\.Skip' "$CLUSTER_TEST"; then
    report "el test del clúster se salta (t.Skip): un test que no corre no mide"
  fi
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "OK: fleet-posture — banco $present/$total presentes (partial $partial, absent $absent), la página y su tabla por familias publican lo mismo, el navegador exigido sobre el fleet con $uif controles, y el clúster de tres agentes en la lane"
