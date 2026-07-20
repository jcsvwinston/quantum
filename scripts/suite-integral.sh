#!/usr/bin/env bash
# suite-integral.sh — la certificación MECÁNICA de la suite Quantum.
#
# Ejecuta contra el árbol pinado (submódulos tal y como los fija versions.yaml)
# todo lo que un auditor comprobaría mecánicamente en un cierre de ronda:
#
#   0. Precondiciones: registro de guards íntegro (aserción anti-fósil),
#      declared_lags VACÍO en versions.yaml (estado certificable), submódulos
#      con historia completa y tags, y el sitio construido (npm ci + build).
#   1. TODOS los guards de scripts/lib/guard-registry.sh, en orden, capturando
#      el EXIT de cada uno SIN abortar al primero.
#   2. Tabla final guard → EXIT con conteo veraz: se cuentan solo guards
#      ejecutados, sin líneas-resumen infladas (lección QM7-2).
#
# EXIT global != 0 si cualquier precondición o guard falló.
#
# Semántica: los guards de producto corren AL PIN. Un fallo aquí no es «el CI
# de otro repo está roto»: es «el set que versions.yaml certifica no pasa sus
# propios guards», que es exactamente lo que un auditor reportaría.
#
# Escapes documentados (solo para uso A MITAD de ronda; en el cierre ninguno):
#   QUANTUM_ALLOW_DECLARED_LAGS=1  — no falla aunque declared_lags no esté
#       vacío. Entre el arranque de una ronda y su tren de releases los lags
#       declarados son un estado legítimo; al certificar deben quedar vacíos.
#   QUANTUM_SKIP_BUILD=1 — reutiliza website/build existente (iteración local;
#       en CI siempre se construye).
set -uo pipefail

cd "$(dirname "$0")/.."

# shellcheck source=scripts/lib/guard-registry.sh
source scripts/lib/guard-registry.sh

overall=0
fail_pre() { echo "FAIL(pre): $*" >&2; overall=1; }

echo "== suite-integral: certificación mecánica del set $(grep -m1 '^quantum:' versions.yaml | awk '{print $2}' | tr -d '"') =="
echo

# ---------------------------------------------------------------------------
# 0a. Registro íntegro (anti-fósil). Si esto falla, la tabla de abajo estaría
# certificando un subconjunto sin saberlo — se falla, pero se sigue ejecutando
# lo registrado para dar el cuadro completo.
# ---------------------------------------------------------------------------
echo "-- precondición: registro de guards (anti-fósil)"
if ! guard_registry_selfcheck; then
  fail_pre "hay guards sin registrar (ver arriba)"
fi
echo

# ---------------------------------------------------------------------------
# 0b. declared_lags vacío. Un lag declarado es DISCLOSURE honesta a mitad de
# ronda, pero un set CERTIFICADO no puede llevar requires rancios declarados:
# el tren de releases de cada ronda los vacía antes del re-pin final.
# ---------------------------------------------------------------------------
echo "-- precondición: declared_lags vacío en versions.yaml"
lags=$(awk '/^declared_lags:/{inb=1; next} /^[a-zA-Z_]/{inb=0} inb && $1 ~ /^[a-z]+:$/ {print $1 $2}' versions.yaml)
if [[ -n "$lags" ]]; then
  if [[ "${QUANTUM_ALLOW_DECLARED_LAGS:-0}" == "1" ]]; then
    echo "AVISO: declared_lags NO está vacío ($(tr '\n' ' ' <<<"$lags")) — permitido por QUANTUM_ALLOW_DECLARED_LAGS=1 (estado de mitad de ronda, NO certificable)"
  else
    fail_pre "declared_lags no está vacío: $(tr '\n' ' ' <<<"$lags") — el set no es certificable (el tren de la ronda debe alinear los requires y vaciar la lista; para una corrida a mitad de ronda exporta QUANTUM_ALLOW_DECLARED_LAGS=1)"
  fi
else
  echo "OK: declared_lags vacío"
fi
echo

# ---------------------------------------------------------------------------
# 0c. Submódulos: historia completa y tags. manifest-guard §3 hace merge-base
# entre tags de módulo y el pin (imposible en un clone shallow), y
# check_internal_pins de orbit compara go.mods contra `git tag`. Sin red se
# avisa y se sigue: si faltan tags, el guard afectado hablará por sí mismo.
# ---------------------------------------------------------------------------
echo "-- precondición: submódulos con historia completa y tags"
subs_ok=1
for m in quark nucleus orbit; do
  if [[ ! -e "$m/.git" ]]; then
    fail_pre "$m no está inicializado (git submodule update --init)"
    subs_ok=0
    continue
  fi
  if [[ "$(git -C "$m" rev-parse --is-shallow-repository 2>/dev/null)" == "true" ]]; then
    echo "   $m: clone shallow — fetch --unshallow"
    if ! git -C "$m" fetch --unshallow --tags --quiet origin; then
      fail_pre "$m: no se pudo completar la historia (¿sin red?)"
      subs_ok=0
    fi
  else
    git -C "$m" fetch --tags --quiet origin \
      || echo "   AVISO: $m: fetch de tags falló (¿sin red?) — se usan los tags locales"
  fi
done
[[ $subs_ok -eq 1 ]] && echo "OK: submódulos preparados"
echo

# ---------------------------------------------------------------------------
# 0d. Build del sitio (una vez). umbrella-served-jargon lintea el HTML EMITIDO,
# así que el build es parte de la certificación: si no construye, el set
# tampoco certifica.
# ---------------------------------------------------------------------------
echo "-- precondición: build del sitio (website/)"
if [[ "${QUANTUM_SKIP_BUILD:-0}" == "1" && -d website/build ]]; then
  echo "AVISO: QUANTUM_SKIP_BUILD=1 — se reutiliza website/build existente (solo iteración local)"
else
  if (cd website && npm ci --no-audit --no-fund && npm run build); then
    echo "OK: sitio construido"
  else
    fail_pre "el build del sitio falló — umbrella-served-jargon no podrá evaluarse sobre HTML fresco"
  fi
fi
echo

# ---------------------------------------------------------------------------
# 1. Guards del registro, todos, sin abortar al primero.
# ---------------------------------------------------------------------------
# GOCACHE explícito: check_contract_freeze exporta GOCACHE=$PWD/.cache si no
# viene definido, lo que dejaría ~800 MB dentro del submódulo pinado. Se fija
# el del host para no ensuciar el árbol certificado.
if command -v go >/dev/null 2>&1; then
  GOCACHE="${GOCACHE:-$(go env GOCACHE)}"
  export GOCACHE
fi

names=$(guard_names)
total=0
failed=0
results=""

for name in $names; do
  dir=$(guard_dir "$name")
  cmd=$(guard_cmd "$name")
  echo "== guard: $name (cwd=$dir) =="
  echo "   \$ $cmd"
  ( cd "$dir" && eval "$cmd" )
  ec=$?
  echo "-- $name EXIT=$ec"
  echo
  total=$((total + 1))
  [[ $ec -ne 0 ]] && failed=$((failed + 1))
  results+="$(printf '%-28s %s' "$name" "$ec")"$'\n'
done

# ---------------------------------------------------------------------------
# 2. Tabla final. Conteo veraz: N guards registrados, N ejecutados — nada más.
# ---------------------------------------------------------------------------
echo "== resultado: guard → EXIT =="
printf '%s' "$results"
echo
echo "guards registrados: $(guard_names | wc -l | tr -d ' ') · ejecutados: $total · con fallo: $failed"

if [[ $failed -gt 0 ]]; then
  overall=1
fi

if [[ $overall -ne 0 ]]; then
  echo
  echo "suite-integral: FALLO — el set pinado NO certifica (ver arriba)." >&2
  exit 1
fi

echo "suite-integral: OK — los $total guards pasan sobre el árbol pinado."
