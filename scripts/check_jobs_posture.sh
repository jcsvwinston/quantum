#!/usr/bin/env bash
# check_jobs_posture.sh — el gate del arco A7: lo que la suite AFIRMA sobre su
# trabajo en segundo plano, sus eventos y su tiempo real tiene que ser lo que
# sus propias medidas dicen.
#
# A7 dejó un banco y una página en nucleus, y el problema que cierra este guard
# es el de A5 y A6: un documento medido sigue siendo un fichero de texto. Nada
# impide subir la cifra publicada, borrar la nota de un control que no está, o
# quitar un caso del banco, y el resultado seguiría leyéndose como una medición.
#
#   nucleus/internal/jobsbench/      40 controles, cada uno con su sonda y su veredicto
#   nucleus/docs/jobs-bench.md       la página que publica el numerador
#   nucleus/.github/workflows/ci.yml la lane que corre la prueba de durabilidad
#
# Lo que comprueba, en el ÁRBOL PINADO:
#
#   1. el banco existe, tiene sus 40 controles, y cada uno que no está
#      `present` lleva nota que diga qué falta;
#   2. la cifra de la página coincide con la que cuenta la tabla del banco;
#   3. la prueba de durabilidad del gate está en el pin Y el CI la corre —
#      10 000 jobs con el worker muerto a mitad es la única afirmación del
#      arco que no se puede comprobar leyendo, y sin la lane el proveedor
#      podría dejar de recuperar mientras todo lo demás sigue verde;
#   4. esa prueba asserta que el proceso murió CON TRABAJO EN VUELO. Matar un
#      proceso ocioso también pasa, y mide nada — es la misma trampa que el
#      instrumento del navegador de A6 (UIX-00) cerró para la accesibilidad.
#
# Lo que NO comprueba: que las sondas pasen. Eso lo hace `go test` en el CI de
# nucleus, que es donde se ejecuta lo que mide. Este guard vigila la frontera
# entre lo medido y lo publicado, que es donde una cifra se vuelve mentira sin
# que ninguna suite se ponga roja.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

BENCH_CASES=nucleus/internal/jobsbench/jobsbench_cases_test.go
BENCH_DOC=nucleus/docs/jobs-bench.md
DURABILITY_TEST=nucleus/pkg/tasks/providers/sql/durability_test.go
NUCLEUS_CI=nucleus/.github/workflows/ci.yml
EXPECTED_CONTROLS=40

fail=0
report() { echo "FAIL: jobs-posture — $1" >&2; fail=1; }

# 1. El banco existe y cada caso lleva veredicto (y nota si no es present).
if [[ ! -f "$BENCH_CASES" ]]; then
  report "falta $BENCH_CASES — el numerador del gate de A7 no está en el pin"
  echo "jobs-posture: sin banco, no hay nada más que comprobar" >&2
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
if [[ "$total" -lt "$EXPECTED_CONTROLS" ]]; then
  report "el banco tiene $total controles; se registraron $EXPECTED_CONTROLS en A7 — ¿se borró alguno?"
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

# 3. La prueba de durabilidad está en el pin y el CI la corre.
if [[ ! -f "$DURABILITY_TEST" ]]; then
  report "falta $DURABILITY_TEST — la única afirmación del arco que no se puede comprobar leyendo"
else
  # 4. Y mide de verdad: mata con trabajo EN VUELO, y no da por bueno un
  #    proceso ocioso.
  if ! grep -q 'TotalActive > 0' "$DURABILITY_TEST"; then
    report "la prueba de durabilidad no exige que hubiera trabajo EN VUELO al matar: matar un proceso ocioso también pasa, y mide nada"
  fi
  if ! grep -qE 'Process\.Kill|SIGKILL' "$DURABILITY_TEST"; then
    report "la prueba de durabilidad no mata el proceso: un cierre ordenado libera los leases, que es justo lo que un fallo NO hace"
  fi
  if ! grep -qE 'durabilityJobs *= *10000' "$DURABILITY_TEST"; then
    report "la prueba de durabilidad no usa los 10 000 jobs que el gate del arco fija"
  fi
fi

if [[ -f "$NUCLEUS_CI" ]]; then
  if ! grep -q 'TestSQLProvider_GateDurabilityUnderCrash' "$NUCLEUS_CI"; then
    report "el CI de nucleus no corre la prueba de durabilidad: sin ella el proveedor puede dejar de recuperar y la lane sigue verde"
  fi
  if ! grep -q 'TestSQLMatrix_JobsProvider' "$NUCLEUS_CI"; then
    report "el CI de nucleus no corre la cola durable contra motores reales: su DDL y su claim sólo se habrían ejercido en SQLite, que es la forma exacta de NU-85"
  fi
else
  report "falta $NUCLEUS_CI — no se puede comprobar que la lane exija la prueba"
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "OK: jobs-posture — $present/$total controles presentes, la página publica la misma cifra, y el CI corre la prueba de durabilidad (10 000 jobs, worker muerto a mitad)"
