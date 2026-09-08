#!/usr/bin/env bash
# selftest.sh — autotest del CIERRE de un ensayo (`--dry-run`) de
# scripts/train/train.sh: la última línea que el operador lee tiene que decir
# la verdad sobre lo que el ensayo ha tocado.
#
# Por qué existe: el ensayo no toca los remotos ni el set, pero en las fases de
# repo sí toca los checkouts HERMANOS en local, a propósito —si no los tocara,
# mentiría sobre lo que van a decir `align-orbit-pins.sh --check` y
# `quark-doc-debt.sh --dry-run`—. El cierre decía «NADA se ha ejecutado con
# efectos» sin condición de fase, así que quien leía solo esa línea no se
# enteraba de que ../quark y ../orbit se habían movido. Aquí se comprueba que
# nombra los checkouts que el recorrido ha tocado, y solo esos.
#
# Cómo: un paraguas de MENTIRA con el driver DE VERDAD y los dos scripts
# hermanos sustituidos por testigos que dejan una marca al ejecutarse. Se
# compara lo que el cierre DICE con las marcas que quedaron.
#
# Desde la raíz del paraguas: bash tests/train-dry-run/selftest.sh
set -uo pipefail

cd "$(dirname "$0")/../.."
DRIVER="$PWD/scripts/train/train.sh"
[ -f "$DRIVER" ] || { echo "no encuentro $DRIVER" >&2; exit 1; }

fails=0
aserciones=0
ok()  { aserciones=$((aserciones + 1)); echo "    ok — $1"; }
bad() { aserciones=$((aserciones + 1)); fails=$((fails + 1)); echo "    FALLO — $1" >&2; }
dice()    { case "$SALIDA" in *"$1"*) ok "el cierre dice «$1»" ;; *) bad "el cierre NO dice «$1»" ;; esac; }
no_dice() { case "$SALIDA" in *"$1"*) bad "el cierre dice «$1», y no debía" ;; *) ok "el cierre no dice «$1»" ;; esac; }
marcado()    { [ -f "$LAB/marcas/$1" ] && ok "$1 se ejecutó en el ensayo" || bad "$1 NO se ejecutó en el ensayo"; }
sin_marcar() { [ -f "$LAB/marcas/$1" ] && bad "$1 se ejecutó en el ensayo, y no debía" || ok "$1 no se ejecutó en el ensayo"; }

BASE=$(mktemp -d "${TMPDIR:-/tmp}/quantum-tren-dry.XXXXXX") || exit 1
trap 'rm -rf "$BASE"' EXIT

# monta — un paraguas de mentira donde los dos scripts que el ensayo SÍ ejecuta
# (y el que NO, porque pasa por `run`) dejan una marca al correr.
monta() {
  LAB=$(mktemp -d "$BASE/lab.XXXXXX")
  local t="$LAB/paraguas"
  mkdir -p "$t/scripts/train" "$LAB/bin" "$LAB/marcas"
  git init -q -b main "$t"
  git -C "$t" config user.email tren@example.com
  git -C "$t" config user.name "Tren de mentira"
  cat > "$t/versions.yaml" <<'EOF'
quantum: "9.9.0"
declared_lags: {}
EOF
  cp "$DRIVER" "$t/scripts/train/train.sh"
  local s
  for s in quark-doc-debt align-orbit-pins align-module-floors; do
    cat > "$t/scripts/train/$s.sh" <<EOF
#!/usr/bin/env bash
: > "$LAB/marcas/$s.sh"
exit 0
EOF
    chmod +x "$t/scripts/train/$s.sh"
  done
  # gh de pega: autenticado y sin release PRs abiertos (la fase de repo termina
  # ahí, que es todo lo que este autotest necesita de ella).
  printf '#!/usr/bin/env bash\nexit 0\n' > "$LAB/bin/gh"
  chmod +x "$LAB/bin/gh"
  git -C "$t" add -A
  git -C "$t" commit -q -m "paraguas de mentira"
}

# tren <args...> — el driver en el paraguas de mentira. Deja SALIDA y RC.
SALIDA=""; RC=0
tren() {
  RC=0
  SALIDA=$(cd "$LAB/paraguas" && PATH="$LAB/bin:$PATH" QUANTUM_TREN_RELOJ="$LAB/reloj.tsv" \
    bash scripts/train/train.sh "$@" 2>&1) || RC=$?
}

echo "== autotest del cierre de un ensayo del tren =="
echo

echo "-- las dos fases de repo que tocan un checkout hermano (--desde quark --hasta orbit)"
monta
tren --dry-run --desde quark --hasta orbit
[ "$RC" -eq 0 ] || bad "el ensayo debía salir EXIT=0 y salió EXIT=$RC"
no_dice "NADA se ha ejecutado con efectos"
dice "sin efectos sobre los remotos ni sobre el set"
dice "En local sí se ha tocado ../quark"
dice "En local sí se ha tocado ../orbit"
marcado quark-doc-debt.sh
marcado align-orbit-pins.sh
# Lo que pasa por `run` no se ejecuta en un ensayo; el cierre tampoco lo nombra.
sin_marcar align-module-floors.sh

echo "-- solo la fase que toca ../quark (--desde quark --hasta quark)"
monta
tren --dry-run --desde quark --hasta quark
[ "$RC" -eq 0 ] || bad "el ensayo debía salir EXIT=0 y salió EXIT=$RC"
dice "En local sí se ha tocado ../quark"
no_dice "En local sí se ha tocado ../orbit"
marcado quark-doc-debt.sh
sin_marcar align-orbit-pins.sh

echo "-- ninguna fase de repo (--hasta preflight)"
monta
tren --dry-run --hasta preflight
[ "$RC" -eq 0 ] || bad "el ensayo debía salir EXIT=0 y salió EXIT=$RC"
dice "Sin fases de repo en el recorrido"
no_dice "En local sí se ha tocado"
sin_marcar quark-doc-debt.sh
sin_marcar align-orbit-pins.sh

echo
if [ "$fails" -eq 0 ]; then
  echo "train-dry-run selftest: OK ($aserciones aserciones) — el cierre del ensayo nombra los checkouts hermanos que ha tocado, y solo esos"
else
  echo "train-dry-run selftest: FALLO ($fails de $aserciones aserciones)" >&2
  exit 1
fi
