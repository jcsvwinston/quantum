#!/usr/bin/env bash
# guard-of-guards.sh — prueba que cada guard registrado sigue MORDIENDO.
#
# Un guard que siempre pasa es indistinguible de un guard muerto: la lección
# de las siete rondas es que los checks también se fosilizan (regex que dejan
# de enganchar, ficheros renombrados, flags que pierden el modo estricto).
# Este harness ejecuta cada guard del registro contra una fixture de FALLO
# (tests/guard-fixtures/<guard>/fixture.sh): una copia doctorada del árbol
# mínimo que el guard valida, con una rotura concreta. El contrato:
#
#   - El guard debe salir con EXIT != 0 sobre la copia doctorada. Si
#     «sobrevive» (EXIT=0), el guard ha muerto y el harness FALLA.
#   - Además su salida debe contener el regex `expect=` que declara la
#     fixture — la causa de muerte esperada. Un EXIT != 0 por OTRA causa
#     (p. ej. un error de setup) no cuenta: sería un falso «muerde».
#
# Cobertura en las dos direcciones:
#   - guard registrado sin fixture → FALLO (todo guard nuevo trae fixture).
#   - fixture huérfana sin guard registrado → FALLO (la fixture de un guard
#     retirado se retira con él, no se queda de fósil).
#
# Además ejecuta la aserción anti-fósil del registro (ningún script de guard
# sin registrar en los 4 repos) — ver scripts/lib/guard-registry.sh.
set -uo pipefail

cd "$(dirname "$0")/.."

# shellcheck source=scripts/lib/guard-registry.sh
source scripts/lib/guard-registry.sh

FIXTURES_DIR=tests/guard-fixtures
overall=0

echo "== guard-of-guards =="
echo

# ---------------------------------------------------------------------------
# 0. Registro íntegro + cobertura de fixtures en ambas direcciones.
# ---------------------------------------------------------------------------
echo "-- registro de guards (anti-fósil)"
if ! guard_registry_selfcheck; then
  overall=1
fi
echo

echo "-- cobertura: cada guard registrado tiene fixture, y viceversa"
registered_names=$(guard_names)
cov_ok=1
for name in $(guard_names); do
  if [[ ! -f "$FIXTURES_DIR/$name/fixture.sh" ]]; then
    echo "FAIL: el guard '$name' no tiene fixture ($FIXTURES_DIR/$name/fixture.sh) — todo guard registrado necesita su prueba de mordida" >&2
    cov_ok=0
  fi
done
for d in "$FIXTURES_DIR"/*/; do
  [[ -d "$d" ]] || continue
  fx_name=$(basename "$d")
  # `grep -q` cierra la tubería al primer match y el printf de guard_names
  # muere con «Broken pipe»; bajo pipefail eso convierte un guard registrado
  # en «huérfana» al azar (quantum#151 en CI). Se compara sobre una copia.
  if ! grep -qxF -- "$fx_name" <<<"$registered_names"; then
    echo "FAIL: fixture huérfana '$fx_name' — no hay guard registrado con ese nombre (¿guard retirado sin retirar su fixture?)" >&2
    cov_ok=0
  fi
done
if [[ $cov_ok -eq 1 ]]; then
  echo "OK: $(guard_names | wc -l | tr -d ' ') guards registrados, todos con fixture, sin huérfanas"
else
  overall=1
fi
echo

# ---------------------------------------------------------------------------
# 1. Cada guard contra su fixture: preparar copia doctorada, ejecutar, exigir
#    EXIT != 0 con la causa de muerte declarada.
# ---------------------------------------------------------------------------
# Entorno de ejecución de los guards sobre las copias:
#  - GOWORK=off: los árboles doctorados son copias standalone fuera del
#    workspace del paraguas — la misma semántica con la que el CI de cada
#    producto ejecuta sus guards.
#  - GOCACHE explícito: check_contract_freeze se fabrica un GOCACHE dentro del
#    árbol si no viene definido — sería una recompilación completa por corrida.
if command -v go >/dev/null 2>&1; then
  GOCACHE="${GOCACHE:-$(go env GOCACHE)}"
  export GOCACHE
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/guard-of-guards.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

total=0
bitten=0
results=""

for name in $(guard_names); do
  fixture="$FIXTURES_DIR/$name/fixture.sh"
  [[ -f "$fixture" ]] || continue   # ya reportado arriba como fallo de cobertura

  total=$((total + 1))
  tmp="$WORK/$name"
  mkdir -p "$tmp"
  echo "== $name =="

  # 1a. Preparar la copia doctorada.
  fx_out="$tmp/fixture.out"
  if ! bash "$fixture" "$tmp" > "$fx_out" 2>&1; then
    echo "FAIL: la fixture de '$name' falló al prepararse:" >&2
    sed 's/^/    /' "$fx_out" >&2
    results+="$(printf '%-28s %s' "$name" "FIXTURE-ROTA")"$'\n'
    overall=1
    continue
  fi
  workdir=$(sed -n 's/^workdir=//p' "$fx_out" | tail -1)
  expect=$(sed -n 's/^expect=//p' "$fx_out" | tail -1)
  # env= (opcional, 0..N líneas KEY=VALUE): entorno con el que se invoca el
  # guard sobre la copia. Un guard con MODOS (p. ej. check_suite_tag.sh, cuyo
  # assert de captura de HEAD y trato del mid-tren dependen de
  # QUANTUM_CERTIFYING) necesita probarse EN el modo donde muerde: sin este
  # canal el harness solo lo correría en el modo por defecto. Solo afecta a la
  # subshell de ESTE guard; las fixtures que no lo declaran no cambian.
  guard_env=$(sed -n 's/^env=//p' "$fx_out")
  if [[ -z "$workdir" || -z "$expect" || ! -d "$workdir" ]]; then
    echo "FAIL: la fixture de '$name' no declaró workdir=/expect= válidos" >&2
    results+="$(printf '%-28s %s' "$name" "FIXTURE-ROTA")"$'\n'
    overall=1
    continue
  fi

  # 1b. Ejecutar el guard REAL (el comando del registro, sobre la copia), con
  #     el entorno que la fixture pida (env=), además de GOWORK=off.
  cmd=$(guard_cmd "$name")
  guard_out="$tmp/guard.out"
  (
    cd "$workdir"
    export GOWORK=off
    if [[ -n "$guard_env" ]]; then
      while IFS= read -r _kv; do
        [[ -n "$_kv" ]] && export "$_kv"
      done <<<"$guard_env"
    fi
    eval "$cmd"
  ) > "$guard_out" 2>&1
  ec=$?

  # 1c. Veredicto.
  if [[ $ec -eq 0 ]]; then
    echo "FAIL: el guard '$name' SOBREVIVIÓ a su fixture (EXIT=0) — el guard ha muerto: la rotura que debía cazar ya no lo mata" >&2
    sed 's/^/    /' "$guard_out" | tail -20 >&2
    results+="$(printf '%-28s %s' "$name" "SOBREVIVIO(0)")"$'\n'
    overall=1
  elif ! grep -qE "$expect" "$guard_out"; then
    echo "FAIL: el guard '$name' salió EXIT=$ec pero SIN la causa esperada (/$expect/) — murió por otra razón, eso no demuestra que muerda:" >&2
    sed 's/^/    /' "$guard_out" | tail -20 >&2
    results+="$(printf '%-28s %s' "$name" "CAUSA-EQUIVOCADA($ec)")"$'\n'
    overall=1
  else
    echo "OK: muerde (EXIT=$ec, causa esperada presente)"
    bitten=$((bitten + 1))
    results+="$(printf '%-28s %s' "$name" "muerde($ec)")"$'\n'
  fi
  echo
done

# ---------------------------------------------------------------------------
# 2. Tabla final. Conteo veraz: fixtures ejecutadas, guards que mordieron.
# ---------------------------------------------------------------------------
echo "== resultado: guard → veredicto =="
printf '%s' "$results"
echo
echo "guards registrados: $(guard_names | wc -l | tr -d ' ') · fixtures ejecutadas: $total · muerden: $bitten"

if [[ $overall -ne 0 ]]; then
  echo
  echo "guard-of-guards: FALLO — hay guards muertos, fixtures rotas o cobertura incompleta (ver arriba)." >&2
  exit 1
fi

echo "guard-of-guards: OK — los $bitten guards muerden sobre sus fixtures de fallo."
