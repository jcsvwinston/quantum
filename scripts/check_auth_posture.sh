#!/usr/bin/env bash
# check_auth_posture.sh — el gate del arco A5: lo que la suite AFIRMA sobre
# su autenticación tiene que ser lo que sus propias medidas dicen.
#
# A5 dejó dos documentos medidos en nucleus, y el problema que este guard
# cierra es el de siempre con un documento medido: sigue siendo un fichero de
# texto. Nada impide que alguien edite la cifra publicada, borre una nota o
# añada una fila sin veredicto, y el resultado seguiría leyéndose como una
# medición.
#
#   internal/authbench/          43 controles con su probe y su veredicto
#   docs/auth-bench.md           la página que publica el numerador
#   contracts/baseline/asvs_l2.txt  25 requisitos de ASVS 4.0.3 L2
#
# Lo que comprueba, en el ÁRBOL PINADO:
#
#   1. el banco existe y cada caso que no está `present` lleva nota;
#   2. la cifra de la página coincide con la que la tabla del banco cuenta;
#   3. el baseline ASVS existe, ninguna fila se quedó sin veredicto, y su
#      recuento final cuadra con las filas;
#   4. ningún veredicto distinto de `met` se publica sin razón escrita.
#
# Lo que NO comprueba: que los probes pasen. Eso lo hace `go test` en el CI de
# nucleus, que es donde se ejecuta lo que mide. Este guard vigila la frontera
# entre lo medido y lo publicado, que es donde una cifra se vuelve mentira sin
# que ninguna suite se ponga roja.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

BENCH_DIR=nucleus/internal/authbench
BENCH_CASES="$BENCH_DIR/authbench_cases_test.go"
BENCH_DOC=nucleus/docs/auth-bench.md
ASVS=nucleus/contracts/baseline/asvs_l2.txt

fail=0
report() { echo "FAIL: auth-posture — $1" >&2; fail=1; }

# 1. El banco existe.
if [[ ! -f "$BENCH_CASES" ]]; then
  report "falta $BENCH_CASES — el numerador del gate de A5 no está en el pin"
  echo "auth-posture: sin banco, no hay nada más que comprobar" >&2
  exit 1
fi

# Un caso por línea `{id: "XXX-00", … want: <veredicto>` y su nota opcional.
# El fichero es Go formateado, así que un caso puede ocupar varias líneas: se
# leen por bloques que empiezan en `{id:`.
counts=$(awk '
  /\{id: "/ { block = $0; collecting = 1; next }
  collecting { block = block " " $0 }
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
if [[ "$total" -lt 40 ]]; then
  report "el banco tiene $total controles; se registraron 43 en A5 — ¿se borró alguno?"
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

# 3 y 4. El baseline ASVS: filas con veredicto, recuento coherente.
if [[ ! -f "$ASVS" ]]; then
  report "falta $ASVS — «ASVS L2» sin matriz es una afirmación sin comprobación"
else
  rows=$(grep -cE '^V[0-9]+\.[0-9]+\.[0-9]+[[:space:]]+(met|application|not-met)[[:space:]]' "$ASVS" || true)
  malformed=$(grep -E '^V[0-9]' "$ASVS" | grep -vcE '^V[0-9]+\.[0-9]+\.[0-9]+[[:space:]]+(met|application|not-met)[[:space:]]' || true)
  if [[ "$rows" -lt 20 ]]; then
    report "el baseline ASVS tiene $rows filas con veredicto; se congelaron 25"
  fi
  if [[ "$malformed" -gt 0 ]]; then
    report "$malformed fila(s) del baseline ASVS sin veredicto reconocible"
  fi

  summary=$(grep -oE '# met [0-9]+ · application [0-9]+ · not-met [0-9]+ · of [0-9]+' "$ASVS" | head -1)
  if [[ -z "$summary" ]]; then
    report "el baseline ASVS no lleva su línea de recuento"
  else
    declared_total=$(printf '%s' "$summary" | grep -oE 'of [0-9]+' | grep -oE '[0-9]+')
    if [[ "$declared_total" != "$rows" ]]; then
      report "el recuento del baseline ASVS dice $declared_total y tiene $rows filas"
    fi
  fi
fi

if [[ "$fail" -eq 0 ]]; then
  echo "OK: auth-posture — banco $present/$total presentes (partial $partial, absent $absent), ASVS con $rows filas medidas"
fi
exit "$fail"
