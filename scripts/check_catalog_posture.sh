#!/usr/bin/env bash
# check_catalog_posture.sh — el gate de nucleus en el arco A11: lo que la suite
# AFIRMA sobre su catálogo de `nucleus add` y sobre lo que una aplicación
# puede extender (plugins, módulos, comandos externos) tiene que ser lo que
# sus propias medidas dicen.
#
# NO REGISTRADO TODAVÍA. Se registra en el PR del set del 2026-10-12 (sesión
# S-fin del plan de A11, parte b): el banco vive en el main de nucleus y NO
# en el pin de Quantum 1.40.0 (nucleus v1.31.0), así que al pin de hoy este
# guard falla por «falta el banco». Espera en la rama
# feat/a11-sfin-catalog-posture, fuera de main, porque la aserción anti-fósil
# del registro tumba un check_*.sh sin registrar y guard-of-guards, una
# fixture sin guard. Al registrarlo, en el commit del set que mueve el
# gitlink de nucleus:
#   - la línea "umbrella-catalog-posture|.|bash scripts/check_catalog_posture.sh"
#     en scripts/lib/guard-registry.sh, con su comentario;
#   - la fixture, que ya está en tests/guard-fixtures/umbrella-catalog-posture/;
#   - PRESENT_FLOOR al número de present que mida el pin;
#   - la cuenta de guards (docs/RUMBO.md, el handoff) y este párrafo fuera.
#
# A11 dejó un banco y una página en nucleus, y el problema que cierra este
# guard es el de A5…A10: un documento medido sigue siendo un fichero de texto.
# Nada impide subir la cifra publicada, retocar una fila de la tabla por
# familias, borrar la nota de un control que no está o quitar un caso del
# banco, y el resultado seguiría leyéndose como una medición.
#
#   nucleus/internal/catalogbench/catalogbench_cases_test.go   38 controles (catalog, entries, plugins), cada uno con su sonda y su veredicto
#   nucleus/docs/catalog-bench.md                              la página que publica el numerador y su tabla por familias
#
# Lo que comprueba, en el ÁRBOL PINADO:
#
#   1. el banco existe, tiene sus 38 controles, cada uno con un veredicto
#      reconocible, y cada uno que no está `present` lleva nota que diga qué
#      falta. Un `absent` CON nota es un veredicto legítimo: el gate del arco
#      pide «sin ausentes sin razón escrita», no «sin ausentes» —EN-08
#      (Stripe) quedó fuera del alcance de la suite por decisión del
#      propietario (2026-10-06), con la decisión escrita en su nota—;
#   2. el suelo de controles `present` (ver PRESENT_FLOOR): bajar un
#      veredicto registrado exige bajar también el suelo, a la vista;
#   3. la cifra de la página («**N of M controls present. P partial. A
#      absent.**») es la que cuenta la tabla del banco, y la tabla por
#      familias también —la de A9 se quedó tres sesiones rancia bajo un
#      titular al día—.
#
# Lo que NO comprueba: que las sondas pasen. Eso lo hace `go test` en el CI de
# nucleus, que es donde se ejecuta lo que mide (incluida la entrada
# redis-cache contra un Redis real). Este guard vigila la frontera entre lo
# medido y lo publicado, que es donde una cifra se vuelve mentira sin que
# ninguna suite se ponga roja.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

BENCH_CASES=nucleus/internal/catalogbench/catalogbench_cases_test.go
BENCH_DOC=nucleus/docs/catalog-bench.md
EXPECTED_CONTROLS=38
# El suelo del main de nucleus el 2026-10-06 (fe02dd9e, tras retirar Stripe en
# nucleus#606): 36 present, 1 partial (CAT-04), 1 absent con nota (EN-08). Si
# el corte de nucleus del set mide otra cosa, el suelo es lo que el pin mida.
PRESENT_FLOOR=36

fail=0
report() { echo "FAIL: catalog-posture — $1" >&2; fail=1; }

# 1. El banco existe y cada caso lleva veredicto (y nota si no es present).
if [[ ! -f "$BENCH_CASES" ]]; then
  report "falta $BENCH_CASES — el numerador del catálogo de A11 no está en el pin"
  echo "catalog-posture: sin banco, no hay nada más que comprobar" >&2
  exit 1
fi

counts=$(awk '
  /\{id: "/ { block = $0; collecting = 1 }
  collecting && !/\{id: "/ { block = block " " $0 }
  collecting && /probe: +probe[A-Za-z0-9_]+\},/ {
    collecting = 0
    verdict = "unknown"
    if (block ~ /want: +present,/) verdict = "present"
    else if (block ~ /want: +partial,/) verdict = "partial"
    else if (block ~ /want: +absent,/)  verdict = "absent"
    has_note = (block ~ /note: +"[^"]/)
    match(block, /\{id: "[A-Z0-9-]+"/)
    id = substr(block, RSTART + 6, RLENGTH - 7)
    fam = "?"
    if (match(block, /family: "[a-z]+"/)) fam = substr(block, RSTART + 9, RLENGTH - 10)
    if (verdict == "unknown") { print "BAD " id; next }
    if (verdict != "present" && !has_note) print "NONOTE " id
    print verdict " " fam
  }
' "$BENCH_CASES")

bad=$(printf '%s\n' "$counts" | grep '^BAD ' | sed 's/^BAD //' | tr '\n' ' ')
nonote=$(printf '%s\n' "$counts" | grep '^NONOTE ' | sed 's/^NONOTE //' | tr '\n' ' ')
present=$(printf '%s\n' "$counts" | grep -c '^present ' || true)
partial=$(printf '%s\n' "$counts" | grep -c '^partial ' || true)
absent=$(printf '%s\n' "$counts" | grep -c '^absent ' || true)
total=$((present + partial + absent))

[[ -n "${bad// /}" ]] && report "casos del banco sin veredicto reconocible: $bad"
[[ -n "${nonote// /}" ]] && report "casos sin nota que diga qué falta: $nonote"
if [[ "$total" -lt "$EXPECTED_CONTROLS" ]]; then
  report "el banco tiene $total controles; se registraron $EXPECTED_CONTROLS en A11 — ¿se borró alguno?"
fi

# 2. El suelo.
if [[ "$present" -lt "$PRESENT_FLOOR" ]]; then
  report "el banco registra $present controles present; el suelo de A11 es $PRESENT_FLOOR — si el retroceso es real, bájalo aquí en el mismo cambio y escribe por qué"
fi

# 3. La página publica la misma cifra que la tabla cuenta, total y por familia.
if [[ ! -f "$BENCH_DOC" ]]; then
  report "falta $BENCH_DOC — la cifra no se publica en ninguna parte"
else
  headline=$(grep -oE '\*\*[0-9]+ of [0-9]+ controls present\. [0-9]+ partial\. [0-9]+ absent\.\*\*' "$BENCH_DOC" | head -1)
  if [[ -z "$headline" ]]; then
    report "$BENCH_DOC no publica la cifra en la forma «**N of M controls present. P partial. A absent.**»"
  else
    got=$(printf '%s' "$headline" | tr -d '*' | awk '{print $1 "/" $3 " " $6 " " $8}')
    want="$present/$total $partial $absent"
    if [[ "$got" != "$want" ]]; then
      report "la página dice ${got%% *} (partial y absent: ${got#* }) y el banco mide $present/$total (partial y absent: $partial $absent)"
    fi
  fi
  for fam in $(printf '%s\n' "$counts" | awk 'NF==2 && $1 != "BAD" && $1 != "NONOTE" {print $2}' | sort -u); do
    want_p=$(printf '%s\n' "$counts" | grep -c "^present $fam$" || true)
    want_pa=$(printf '%s\n' "$counts" | grep -c "^partial $fam$" || true)
    want_a=$(printf '%s\n' "$counts" | grep -c "^absent $fam$" || true)
    row=$(grep -E "^\| $fam \| [0-9]+ \| [0-9]+ \| [0-9]+ \|" "$BENCH_DOC" | head -1)
    if [[ -z "$row" ]]; then
      report "la tabla por familias de $BENCH_DOC no tiene la fila de $fam"
      continue
    fi
    got_f=$(printf '%s' "$row" | awk -F'|' '{gsub(/ /,"",$3); gsub(/ /,"",$4); gsub(/ /,"",$5); print $3" "$4" "$5}')
    if [[ "$got_f" != "$want_p $want_pa $want_a" ]]; then
      report "la fila de $fam en $BENCH_DOC dice «$got_f» (present partial absent) y el banco mide «$want_p $want_pa $want_a»"
    fi
  done
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "OK: catalog-posture — $present/$total controles presentes (suelo $PRESENT_FLOOR; partial $partial, absent $absent, todos con nota), la página y la tabla por familias publican la misma cifra"
