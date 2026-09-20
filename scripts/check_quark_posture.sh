#!/usr/bin/env bash
# check_quark_posture.sh — el gate del arco A8: lo que la suite AFIRMA sobre
# Quark como capa de datos enterprise tiene que ser lo que sus propias medidas
# dicen.
#
# A8 dejó un banco y una página en quark, y el problema que cierra este guard
# es el de A5, A6 y A7: un documento medido sigue siendo un fichero de texto.
# Nada impide subir la cifra publicada, borrar la nota de un control que no
# está, quitar un caso del banco, o retirar de la suite compartida una de las
# pruebas que el arco corre en los seis motores — y el resultado seguiría
# leyéndose como una medición.
#
#   quark/internal/enterprisebench/cases_*_test.go   69 controles, cada uno con su sonda y su veredicto
#   quark/docs/enterprise-bench.md                    la página que publica el numerador
#   quark/internal/enginesuite/suite_test.go          SharedSuite: lo que cada lane de motor corre
#
# Lo que comprueba, en el ÁRBOL PINADO:
#
#   1. el banco existe, tiene sus 69 controles, y cada uno que no está
#      `present` lleva nota que diga qué falta;
#   2. la cifra de la página coincide con la que cuenta la tabla del banco;
#   3. las seis pruebas que el arco añadió a SharedSuite siguen ahí —
#      LikeEscape, PlanConstraints, AlterColumn, ModelTypesAndChecks,
#      NativeTypes, Keyset— porque son lo único del arco que se prueba en un
#      motor real y no en SQLite: tres veces la lane de un motor enseñó lo que
#      ninguna sonda podía ver (ORA-01424, el índice de respaldo de MySQL, el
#      literal de rango de PostgreSQL). Sin ellas el banco sigue verde y los
#      motores dejan de medirse.
#
# Lo que NO comprueba: que las sondas pasen. Eso lo hace `go test` en el CI de
# quark, que es donde se ejecuta lo que mide. Este guard vigila la frontera
# entre lo medido y lo publicado, que es donde una cifra se vuelve mentira sin
# que ninguna suite se ponga roja.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

BENCH_DIR=quark/internal/enterprisebench
BENCH_DOC=quark/docs/enterprise-bench.md
SHARED_SUITE=quark/internal/enginesuite/suite_test.go
EXPECTED_CONTROLS=69
ARC_SUITE_TESTS=(LikeEscape PlanConstraints AlterColumn ModelTypesAndChecks NativeTypes Keyset)

fail=0
report() { echo "FAIL: quark-posture — $1" >&2; fail=1; }

# 1. El banco existe y cada caso lleva veredicto (y nota si no es present).
if ! ls "$BENCH_DIR"/cases_*_test.go >/dev/null 2>&1; then
  report "faltan los casos del banco en $BENCH_DIR — el numerador del gate de A8 no está en el pin"
  echo "quark-posture: sin banco, no hay nada más que comprobar" >&2
  exit 1
fi

counts=$(cat "$BENCH_DIR"/cases_*_test.go | awk '
  /id: +"[A-Z0-9-]+"/ { block = $0; collecting = 1; next }
  collecting { block = block " " $0 }
  collecting && /probe: +probe[A-Za-z0-9_]+,/ {
    collecting = 0
    verdict = "unknown"
    if (block ~ /want: +present/) verdict = "present"
    else if (block ~ /want: +partial/) verdict = "partial"
    else if (block ~ /want: +absent/)  verdict = "absent"
    has_note = (block ~ /note: +"/)
    match(block, /id: +"[A-Z0-9-]+"/)
    id = substr(block, RSTART, RLENGTH); sub(/id: +"/, "", id); sub(/"$/, "", id)
    if (verdict == "unknown") { print "BAD " id; next }
    if (verdict != "present" && !has_note) print "NONOTE " id
    print verdict
  }
')

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
  report "el banco tiene $total controles; se registraron $EXPECTED_CONTROLS en A8 — ¿se borró alguno?"
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

# 3. Las pruebas del arco siguen en la suite que cada lane de motor corre.
if [[ ! -f "$SHARED_SUITE" ]]; then
  report "falta $SHARED_SUITE — no se puede comprobar qué corren las lanes de motor"
else
  for name in "${ARC_SUITE_TESTS[@]}"; do
    if ! grep -qE "t\.Run\(\"$name\"" "$SHARED_SUITE"; then
      report "SharedSuite ya no corre $name: esa prueba es lo único del arco que se ejercía en un motor real y no en SQLite"
    fi
  done
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "OK: quark-posture — $present/$total controles presentes, la página publica la misma cifra, y SharedSuite corre las ${#ARC_SUITE_TESTS[@]} pruebas del arco en cada motor"
