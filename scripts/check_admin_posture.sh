#!/usr/bin/env bash
# check_admin_posture.sh — el gate del arco A6: lo que la suite AFIRMA sobre
# su panel de administración tiene que ser lo que sus propias medidas dicen.
#
# A6 dejó dos instrumentos y una página en orbit, y el problema que este guard
# cierra es el mismo que el de A5: un documento medido sigue siendo un fichero
# de texto. Nada impide subir la cifra publicada, borrar la nota de un control
# ausente o quitar un caso del banco, y el resultado seguiría leyéndose como
# una medición.
#
#   orbit/internal/adminbench/           59 controles con su sonda y su veredicto
#   orbit/internal/adminbench/browser/   el instrumento que corre en un navegador
#   orbit/docs/admin-bench.md            la página que publica los dos numeradores
#
# Lo que comprueba, en el ÁRBOL PINADO:
#
#   1. el banco existe, tiene sus 59 controles y cada uno que no está
#      `present` lleva nota que diga qué falta;
#   2. la cifra de la página coincide con la que la tabla del banco cuenta;
#   3. el instrumento del navegador está en el pin (sus specs, su
#      configuración y el arnés en Go que lo ejecuta), y el CI de orbit lo
#      corre con ORBIT_BENCH_BROWSER=required — sin eso, la lane se pone
#      verde cuando el navegador falta, que es el peor de los dos mundos;
#   4. el arnés del navegador prueba su PROPIO instrumento (el control que
#      planta una violación), porque un motor de accesibilidad mal
#      configurado informa de cero violaciones y todo lo demás pasa midiendo
#      nada.
#
# Lo que NO comprueba: que las sondas pasen. Eso lo hace `go test` en el CI de
# orbit, que es donde se ejecuta lo que mide. Este guard vigila la frontera
# entre lo medido y lo publicado, que es donde una cifra se vuelve mentira sin
# que ninguna suite se ponga roja.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

BENCH_CASES=orbit/internal/adminbench/adminbench_cases_test.go
BENCH_DOC=orbit/docs/admin-bench.md
BROWSER_DIR=orbit/internal/adminbench/browser
BROWSER_HARNESS=orbit/internal/adminbench/browserbench_test.go
ORBIT_CI=orbit/.github/workflows/ci.yml

fail=0
report() { echo "FAIL: admin-posture — $1" >&2; fail=1; }

# 1. El banco existe y cada caso lleva veredicto (y nota si no es present).
if [[ ! -f "$BENCH_CASES" ]]; then
  report "falta $BENCH_CASES — el numerador del gate de A6 no está en el pin"
  echo "admin-posture: sin banco, no hay nada más que comprobar" >&2
  exit 1
fi

counts=$(awk '
  /\{id: "/ { block = $0; collecting = 1 }
  collecting && !/\{id: "/ { block = block " " $0 }
  collecting && /probe: probe[A-Za-z0-9_]+\},/ {
    collecting = 0
    verdict = "unknown"
    if (block ~ /want: present/) verdict = "present"
    else if (block ~ /want: partial/) verdict = "partial"
    else if (block ~ /want: absent/)  verdict = "absent"
    has_note = (block ~ /note: "/)
    match(block, /\{id: "[A-Z0-9-]+"/)
    id = substr(block, RSTART + 6, RLENGTH - 7)
    if (verdict == "unknown") { print "BAD " id; next }
    if (verdict != "present" && !has_note) { print "NONOTE " id; next }
    print verdict
  }
' "$BENCH_CASES")

bad=$(printf '%s\n' "$counts" | grep -c '^BAD ' || true)
nonote=$(printf '%s\n' "$counts" | grep '^NONOTE ' | sed 's/^NONOTE //' | tr '\n' ' ')
present=$(printf '%s\n' "$counts" | grep -c '^present$' || true)
partial=$(printf '%s\n' "$counts" | grep -c '^partial$' || true)
absent=$(printf '%s\n' "$counts" | grep -c '^absent$' || true)
total=$((present + partial + absent))

if [[ "$bad" -gt 0 ]]; then
  report "$bad caso(s) del banco sin veredicto reconocible"
fi
if [[ -n "${nonote// /}" ]]; then
  report "casos sin nota que diga qué falta: $nonote"
fi
if [[ "$total" -lt 59 ]]; then
  report "el banco tiene $total controles; se registraron 59 en A6 — ¿se borró alguno?"
fi

# 2. La página publica la misma cifra que la tabla cuenta.
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
fi

# 3. El instrumento del navegador está en el pin y el CI lo exige.
for f in "$BROWSER_HARNESS" "$BROWSER_DIR/playwright.config.ts" "$BROWSER_DIR/package.json"; do
  [[ -f "$f" ]] || report "falta $f — la mitad que sólo un navegador puede medir no está en el pin"
done

specs=$(ls "$BROWSER_DIR"/specs/*.spec.ts 2>/dev/null | wc -l | tr -d ' ')
if [[ "$specs" -lt 1 ]]; then
  report "el instrumento del navegador no tiene specs: no mide nada"
fi

if [[ -f "$ORBIT_CI" ]]; then
  # El `required` tiene que ser el del driver del PANEL (`-run 'TestBrowserBench'`):
  # desde A9 S10 la lane corre también el driver del fleet con su propio
  # `required`, y un grep suelto se daba por satisfecho con cualquiera de los dos.
  if ! awk '/-run .TestBrowserBench./ { seen = NR } seen && NR <= seen + 4 && /ORBIT_BENCH_BROWSER: required/ { found = 1 } END { exit found ? 0 : 1 }' "$ORBIT_CI"; then
    report "el CI de orbit no corre el arnés del panel (TestBrowserBench) con ORBIT_BENCH_BROWSER=required — sin eso se pone verde cuando el navegador falta"
  fi
  if ! grep -q 'admin-browser-bench' "$ORBIT_CI"; then
    report "la lane del arnés de navegador no está en el CI de orbit"
  fi
else
  report "falta $ORBIT_CI — no se puede comprobar que el arnés se ejecute"
fi

# 4. El arnés se mide a sí mismo.
if [[ -f "$BROWSER_HARNESS" ]]; then
  if ! grep -q 'UIX-00' "$BROWSER_HARNESS"; then
    report "el arnés no registra el control que prueba su propio instrumento (UIX-00)"
  fi
fi
if ! grep -rq 'UIX-00' "$BROWSER_DIR"/specs 2>/dev/null; then
  report "ningún spec planta una violación para comprobar que el motor de accesibilidad muerde"
fi

uix=$(grep -cE '\{id: "UIX-[0-9]+"' "$BROWSER_HARNESS" 2>/dev/null || true)
if [[ "$uix" -lt 5 ]]; then
  report "el arnés del navegador registra $uix controles; se registraron 7 en A6"
fi

if [[ "$fail" -eq 0 ]]; then
  echo "OK: admin-posture — banco $present/$total presentes (partial $partial, absent $absent), instrumento de navegador con $uix controles y lane exigida"
fi
exit "$fail"
