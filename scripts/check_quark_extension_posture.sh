#!/usr/bin/env bash
# check_quark_extension_posture.sh — el gate de quark en el arco A11: lo que la
# suite AFIRMA sobre lo que un tercero puede construir sobre Quark (su
# contrato de extensión, un driver de fuera, las integraciones oficiales)
# tiene que ser lo que sus propias medidas dicen.
#
# A11 dejó un banco y una página en quark, y el problema que cierra este guard
# es el de A5…A10: un documento medido sigue siendo un fichero de texto. Nada
# impide subir la cifra publicada, retocar la cabecera de una familia, borrar
# la nota de un control que no está o quitar un caso del banco, y el
# resultado seguiría leyéndose como una medición.
#
#   quark/internal/extbench/cases_*_test.go   22 controles (contract, drivers, integrations), cada uno con su sonda y su veredicto
#   quark/docs/extension-bench.md             la página que publica el numerador y una cabecera por familia
#
# Es un banco aparte del de A8 (internal/enterprisebench, que vigila
# umbrella-quark-posture) a propósito: así cada cifra dice de qué arco es.
#
# Lo que comprueba, en el ÁRBOL PINADO:
#
#   1. el banco existe, tiene sus 22 controles, cada uno con un veredicto
#      reconocible, y cada uno que no está `present` lleva nota que diga qué
#      falta;
#   2. el suelo de controles `present` del pin (ver PRESENT_FLOOR): bajar un
#      veredicto registrado exige bajar también el suelo, a la vista;
#   3. la cifra de la página («**N of M controls present. P partial. A
#      absent.**») es la que cuenta la tabla del banco, y la cabecera de cada
#      familia («### familia — p present · q partial · a absent») también —la
#      tabla por familias de A9 se quedó tres sesiones rancia bajo un titular
#      al día—.
#
# Lo que NO comprueba: que las sondas pasen. Eso lo hace `go test` en el CI de
# quark, que es donde se ejecuta lo que mide. Este guard vigila la frontera
# entre lo medido y lo publicado, que es donde una cifra se vuelve mentira sin
# que ninguna suite se ponga roja.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

BENCH_DIR=quark/internal/extbench
BENCH_DOC=quark/docs/extension-bench.md
EXPECTED_CONTROLS=22
# El suelo es el del pin: quark v1.16.0 (Quantum 1.40.0) mide 14 de 22
# —Q1…Q3 y Q8…Q10 fusionadas; Q4…Q7 en el main de quark, sin publicar—. El
# main de quark ya mide 22 de 22: el suelo sube a 22 en el re-pin del set del
# 2026-10-12 (sesión S-fin del plan de A11, parte b).
PRESENT_FLOOR=14

fail=0
report() { echo "FAIL: quark-extension-posture — $1" >&2; fail=1; }

# 1. El banco existe y cada caso lleva veredicto (y nota si no es present).
if ! ls "$BENCH_DIR"/cases_*_test.go >/dev/null 2>&1; then
  report "faltan los casos del banco en $BENCH_DIR — el numerador de quark en A11 no está en el pin"
  echo "quark-extension-posture: sin banco, no hay nada más que comprobar" >&2
  exit 1
fi

counts=$(cat "$BENCH_DIR"/cases_*_test.go | awk '
  /id: +"[A-Z]+-[0-9]+"/ { block = $0; collecting = 1; next }
  collecting { block = block " " $0 }
  collecting && /probe: +probe[A-Za-z0-9_]+,/ {
    collecting = 0
    verdict = "unknown"
    if (block ~ /want: +present,/) verdict = "present"
    else if (block ~ /want: +partial,/) verdict = "partial"
    else if (block ~ /want: +absent,/)  verdict = "absent"
    has_note = (block ~ /note: +"[^"]/)
    match(block, /id: +"[A-Z]+-[0-9]+"/)
    id = substr(block, RSTART, RLENGTH); sub(/id: +"/, "", id); sub(/"$/, "", id)
    fam = "?"
    if (match(block, /family: +"[a-z]+"/)) { fam = substr(block, RSTART, RLENGTH); sub(/family: +"/, "", fam); sub(/"$/, "", fam) }
    if (verdict == "unknown") { print "BAD " id; next }
    if (verdict != "present" && !has_note) print "NONOTE " id
    print verdict " " fam
  }
')

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
  report "el banco registra $present controles present; el suelo al pin es $PRESENT_FLOOR — si el retroceso es real, bájalo aquí en el mismo cambio y escribe por qué"
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
    heading=$(grep -E "^### $fam — [0-9]+ present · [0-9]+ partial · [0-9]+ absent" "$BENCH_DOC" | head -1)
    if [[ -z "$heading" ]]; then
      report "$BENCH_DOC no tiene la cabecera de la familia $fam («### $fam — p present · q partial · a absent»)"
      continue
    fi
    got_f=$(printf '%s' "$heading" | grep -oE '[0-9]+' | tr '\n' ' ' | sed 's/ $//')
    if [[ "$got_f" != "$want_p $want_pa $want_a" ]]; then
      report "la cabecera de $fam en $BENCH_DOC dice «$got_f» (present partial absent) y el banco mide «$want_p $want_pa $want_a»"
    fi
  done
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "OK: quark-extension-posture — $present/$total controles presentes (suelo $PRESENT_FLOOR; partial $partial, absent $absent), la página y las cabeceras por familia publican la misma cifra"
