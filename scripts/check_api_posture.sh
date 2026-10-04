#!/usr/bin/env bash
# check_api_posture.sh — el gate del arco A10: lo que la suite AFIRMA sobre
# cómo se prueba una aplicación Nucleus y cómo se describe su API tiene que
# ser lo que sus propias medidas dicen.
#
# A10 dejó un banco y una página en nucleus, y además una afirmación que no se
# comprueba leyendo: que el starter que genera `nucleus new --template suite`
# publica su documento OpenAPI y que un cliente TypeScript GENERADO desde él
# consume su API en un test que corre en el CI de nucleus.
#
#   nucleus/internal/apibench/           46 controles, cada uno con su sonda y su veredicto
#   nucleus/docs/api-bench.md            la página que publica el numerador
#   nucleus/contracts/baseline/starter_openapi.json   el documento del starter, congelado
#   nucleus/.github/workflows/ci.yml     la lane que genera el starter, le genera el cliente y lo usa
#
# Lo que comprueba, en el ÁRBOL PINADO:
#
#   1. el banco existe, tiene sus 46 controles, y cada uno que no está
#      `present` lleva nota que diga qué falta;
#   2. la cifra de la página coincide con la que cuenta la tabla del banco, y
#      la tabla por familias también (la de A9 se quedó tres sesiones rancia
#      bajo un titular al día);
#   3. el starter publica su documento: su main.go llama a WithOpenAPIDocument
#      y sus rutas son endpoints tipados, que son los que dan esquemas al
#      documento y tipos al cliente;
#   4. el test del gate existe, consume la API A TRAVÉS del cliente generado
#      —incluido el 409 de un duplicado: una lista que sólo lee pasa aunque los
#      errores no lleguen al cliente— y el CI de nucleus lo corre con node;
#   5. el documento del starter está congelado en contracts/baseline y el CI
#      corre la comparación que pone rojo un cambio rompiente;
#   6. el test que el starter genera habla por el cliente del kit, no por un
#      *http.Client a mano.
#
# Lo que NO comprueba: que las sondas o el test pasen. Eso lo hace el CI de
# nucleus, que es donde se ejecuta lo que mide. Este guard vigila la frontera
# entre lo medido y lo publicado, y que la lane del gate siga existiendo.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

BENCH_CASES=nucleus/internal/apibench/apibench_cases_test.go
BENCH_DOC=nucleus/docs/api-bench.md
STARTER_MAIN=nucleus/internal/cli/scaffold/templates/suite/main.go.tmpl
STARTER_MODULE=nucleus/internal/cli/scaffold/templates/suite/shop/module.go.tmpl
STARTER_TEST=nucleus/internal/cli/scaffold/templates/suite/shop/module_test.go.tmpl
GATE_TEST=nucleus/internal/cli/new_suite_client_test.go
GATE_SCRIPT=nucleus/internal/cli/testdata/starter_client/e2e.ts
BASELINE=nucleus/contracts/baseline/starter_openapi.json
NUCLEUS_CI=nucleus/.github/workflows/ci.yml
EXPECTED_CONTROLS=46

fail=0
report() { echo "FAIL: api-posture — $1" >&2; fail=1; }

# 1. El banco existe y cada caso lleva veredicto (y nota si no es present).
if [[ ! -f "$BENCH_CASES" ]]; then
  report "falta $BENCH_CASES — el numerador del gate de A10 no está en el pin"
  echo "api-posture: sin banco, no hay nada más que comprobar" >&2
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
    match(block, /family: "[a-z]+"/)
    fam = substr(block, RSTART + 9, RLENGTH - 10)
    if (verdict == "unknown") { print "BAD " id; next }
    if (verdict != "present" && !has_note) { print "NONOTE " id; next }
    print verdict " " fam
  }
' "$BENCH_CASES")

bad=$(printf '%s\n' "$counts" | grep -c '^BAD ' || true)
nonote=$(printf '%s\n' "$counts" | grep '^NONOTE ' | sed 's/^NONOTE //' | tr '\n' ' ')
present=$(printf '%s\n' "$counts" | grep -c '^present ' || true)
partial=$(printf '%s\n' "$counts" | grep -c '^partial ' || true)
absent=$(printf '%s\n' "$counts" | grep -c '^absent ' || true)
total=$((present + partial + absent))

[[ "$bad" -gt 0 ]] && report "$bad caso(s) del banco sin veredicto reconocible"
[[ -n "${nonote// /}" ]] && report "casos sin nota que diga qué falta: $nonote"
if [[ "$total" -lt "$EXPECTED_CONTROLS" ]]; then
  report "el banco tiene $total controles; se registraron $EXPECTED_CONTROLS en A10 — ¿se borró alguno?"
fi

# 2. La página publica la misma cifra que la tabla cuenta, total y por familia.
if [[ ! -f "$BENCH_DOC" ]]; then
  report "falta $BENCH_DOC — la cifra no se publica en ninguna parte"
else
  headline=$(grep -oE '\*\*[0-9]+ of [0-9]+ controls present' "$BENCH_DOC" | head -1)
  published=$(printf '%s' "$headline" | grep -oE '^\*\*[0-9]+' | tr -d '*')
  published_total=$(printf '%s' "$headline" | grep -oE 'of [0-9]+' | grep -oE '[0-9]+')
  if [[ -z "$published" ]]; then
    report "$BENCH_DOC no publica la cifra en la forma «**N of M controls present**»"
  elif [[ "$published" != "$present" || "$published_total" != "$total" ]]; then
    report "la página dice $published/$published_total y el banco mide $present/$total"
  fi
  for fam in $(printf '%s\n' "$counts" | awk 'NF==2 {print $2}' | sort -u); do
    want_p=$(printf '%s\n' "$counts" | grep -c "^present $fam$" || true)
    want_pa=$(printf '%s\n' "$counts" | grep -c "^partial $fam$" || true)
    want_a=$(printf '%s\n' "$counts" | grep -c "^absent $fam$" || true)
    row=$(grep -E "^\| $fam \| [0-9]+ \| [0-9]+ \| [0-9]+ \|" "$BENCH_DOC" | head -1)
    if [[ -z "$row" ]]; then
      report "la tabla por familias de $BENCH_DOC no tiene la fila de $fam"
      continue
    fi
    got=$(printf '%s' "$row" | awk -F'|' '{gsub(/ /,"",$3); gsub(/ /,"",$4); gsub(/ /,"",$5); print $3" "$4" "$5}')
    if [[ "$got" != "$want_p $want_pa $want_a" ]]; then
      report "la fila de $fam en $BENCH_DOC dice «$got» (present partial absent) y el banco mide «$want_p $want_pa $want_a»"
    fi
  done
fi

# 3. El starter publica su documento, y sus rutas son endpoints tipados.
if [[ ! -f "$STARTER_MAIN" ]] || ! grep -q 'WithOpenAPIDocument(' "$STARTER_MAIN"; then
  report "el main.go del starter suite no llama a WithOpenAPIDocument: la aplicación generada no publica su documento (NU-98)"
fi
if [[ ! -f "$STARTER_MODULE" ]] || ! grep -qE 'nucleus\.Handle\(r, http\.Method' "$STARTER_MODULE"; then
  report "las rutas del starter no son endpoints tipados: el documento lista sus caminos sin esquemas y el cliente generado no tiene tipos"
fi

# 4. El test del gate consume la API por el cliente generado, y el CI lo corre.
if [[ ! -f "$GATE_TEST" ]]; then
  report "falta $GATE_TEST — el gate del arco no tiene test"
else
  grep -q -- '--client", "typescript"' "$GATE_TEST" || report "el test del gate no genera el cliente con nucleus openapi --client typescript"
fi
if [[ ! -f "$GATE_SCRIPT" ]]; then
  report "falta $GATE_SCRIPT — el script que usa el cliente generado"
else
  grep -q 'from "./client.ts"' "$GATE_SCRIPT" || report "el script del gate no importa el cliente generado"
  grep -q '409' "$GATE_SCRIPT" || report "el script del gate no comprueba que un error (el 409 de un duplicado) llegue al cliente: una lista que sólo lee pasa aunque los errores no lleguen"
fi

# 5. El documento del starter, congelado, y la comparación en el CI.
if [[ ! -f "$BASELINE" ]]; then
  report "falta $BASELINE — el documento del starter no está bajo contrato"
elif ! grep -q '"openapi": "3.1.0"' "$BASELINE"; then
  report "$BASELINE no es un documento OpenAPI 3.1"
fi

if [[ -f "$NUCLEUS_CI" ]]; then
  grep -q 'TestSuiteStarterTypeScriptClient' "$NUCLEUS_CI" || report "el CI de nucleus no corre el test del gate: el cliente generado puede dejar de servir y la lane sigue verde"
  grep -q 'TestSuiteStarterDocumentUnderContract' "$NUCLEUS_CI" || report "el CI de nucleus no compara el documento del starter con su baseline: un cambio rompiente no pone nada rojo"
  grep -q 'actions/setup-node' "$NUCLEUS_CI" || report "el CI de nucleus no instala node: el test del gate se salta sin él"
  grep -q 'NUCLEUS_TSC' "$NUCLEUS_CI" || report "el CI de nucleus no comprueba los tipos del cliente generado (NUCLEUS_TSC)"
else
  report "falta $NUCLEUS_CI — no se puede comprobar que la lane exija el gate"
fi

# 6. El test que el starter genera habla por el cliente del kit.
if [[ ! -f "$STARTER_TEST" ]]; then
  report "falta $STARTER_TEST — el starter no genera test"
elif grep -qE 'srv\.Client\(\)|\*http\.Client' "$STARTER_TEST"; then
  report "el test que genera el starter usa un *http.Client a mano en vez del cliente del kit"
fi

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "OK: api-posture — $present/$total controles presentes, la página y la tabla por familias publican la misma cifra, el starter publica su documento con endpoints tipados, y el CI corre el cliente TypeScript generado contra él y la comparación con su baseline"
