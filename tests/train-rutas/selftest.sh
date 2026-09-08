#!/usr/bin/env bash
# selftest.sh — autotest del reparto del árbol de scripts/train/train.sh: la
# fase paraguas para (EXIT=2) cuando el árbol o la rama traen algo que no es del
# re-pin, y la orden de relanzamiento que IMPRIME esa parada tiene que poder
# ejecutarse LITERALMENTE y converger.
#
# Por qué existe: el PR de re-pin se fusiona sin que nadie mire su diff, así que
# la parada es el único sitio donde una ruta ajena se ve. Si la ruta que la
# parada imprime no es la ruta real —git CITA las que llevan caracteres
# no-ASCII, comillas o backslash, y una cadena separada por espacios parte en
# dos las que llevan espacios—, `--incluye` no la reconoce al volver, el tren
# vuelve a parar por lo mismo y el operador queda en un ping-pong que ejecuta
# justo la orden que el driver le acaba de dar.
#
# Cómo: un paraguas de MENTIRA (origin bare + clon, submódulos de pega, guards
# y `gh` de pega) sobre el que corre el driver DE VERDAD. Cada caso: se ensucia
# el árbol o la rama con una ruta que git trataría mal, se comprueba la parada,
# se EXTRAE la orden que imprime y se ejecuta tal cual; el caso pasa si la
# segunda vuelta sale EXIT=0 y la ruta nombrada llega a main.
#
# Desde la raíz del paraguas: bash tests/train-rutas/selftest.sh
set -uo pipefail

cd "$(dirname "$0")/../.."
RAIZ=$PWD
DRIVER="$RAIZ/scripts/train/train.sh"
[ -f "$DRIVER" ] || { echo "no encuentro $DRIVER" >&2; exit 1; }

fails=0
aserciones=0
ok()  { aserciones=$((aserciones + 1)); echo "    ok — $1"; }
bad() { aserciones=$((aserciones + 1)); fails=$((fails + 1)); echo "    FALLO — $1" >&2; }

BASE=$(mktemp -d "${TMPDIR:-/tmp}/quantum-tren-lab.XXXXXX") || exit 1
trap 'rm -rf "$BASE"' EXIT

# monta <dir> — un paraguas de mentira con origin/main declarando 9.9.0 y el
# re-pin de 9.10.0 escrito (sin commitear) en el árbol.
monta() {
  local lab=$1 t="$1/paraguas" o="$1/origin.git"
  mkdir -p "$t" "$lab/bin"
  git init -q --bare "$o"
  git init -q -b main "$t"
  git -C "$t" config user.email tren@example.com
  git -C "$t" config user.name "Tren de mentira"
  git -C "$t" config commit.gpgsign false
  mkdir -p "$t/scripts/train" "$t/docs" "$t/quark" "$t/nucleus" "$t/orbit"
  manifiesto "$t/versions.yaml" 9.9.0
  printf 'paraguas de mentira\n' > "$t/README.md"
  printf '# CHANGELOG\n' > "$t/CHANGELOG.md"
  printf '# RUMBO\n' > "$t/docs/RUMBO.md"
  printf 'go 1.22\n' > "$t/go.work"
  local m
  for m in quark nucleus orbit; do printf 'module %s\n' "$m" > "$t/$m/go.mod"; done
  # Guards y bump-set de pega: esta prueba es sobre el reparto del árbol, no
  # sobre lo que ellos comprueban.
  local g
  for g in bump-set manifest-guard check_rumbo_estado check_gowork_covers_manifest; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$t/scripts/$g.sh"
    chmod +x "$t/scripts/$g.sh"
  done
  cp "$DRIVER" "$t/scripts/train/train.sh"
  # «Fusionar», en el laboratorio, es empujar la rama a main.
  cat > "$t/scripts/train/merge-group.sh" <<'EOF'
#!/usr/bin/env bash
set -e
git push -q origin HEAD:main
EOF
  chmod +x "$t/scripts/train/merge-group.sh"
  # gh de pega: ningún PR de set abierto, y el que se abre queda MERGED.
  cat > "$lab/bin/gh" <<'EOF'
#!/usr/bin/env bash
case "${1:-} ${2:-}" in
  "pr list")   exit 0 ;;
  "pr create") echo "https://github.com/jcsvwinston/quantum/pull/777"; exit 0 ;;
  "pr view")   echo MERGED; exit 0 ;;
esac
exit 0
EOF
  chmod +x "$lab/bin/gh"
  git -C "$t" add -A
  git -C "$t" commit -q -m "paraguas de mentira en 9.9.0"
  git -C "$t" remote add origin "$o"
  git -C "$t" push -q -u origin main
  # El re-pin, sin commitear: es lo que la fase paraguas va a commitear.
  manifiesto "$t/versions.yaml" 9.10.0
}

manifiesto() {
  cat > "$1" <<EOF
quantum: "$2"
modules:
  quark: "v1.0.0"
  nucleus: "v1.0.0"
  orbit: "v1.0.0"
notes: >
  El set de mentira del autotest.
EOF
}

# tren <lab> <args...> — el driver, en el paraguas de mentira. Deja la salida en
# SALIDA y el código en RC.
SALIDA=""
RC=0
tren() {
  local lab=$1; shift
  RC=0
  SALIDA=$(cd "$lab/paraguas" && PATH="$lab/bin:$PATH" QUANTUM_TREN_RELOJ="$lab/reloj.tsv" \
    bash scripts/train/train.sh "$@" 2>&1) || RC=$?
}

# tren_literal <lab> <orden> — la orden TAL CUAL la imprimió la parada.
tren_literal() {
  local lab=$1 orden=$2
  RC=0
  SALIDA=$(cd "$lab/paraguas" && PATH="$lab/bin:$PATH" QUANTUM_TREN_RELOJ="$lab/reloj.tsv" \
    bash -c "$orden" 2>&1) || RC=$?
}

# orden_impresa — la orden de relanzamiento de la última salida.
orden_impresa() { printf '%s\n' "$SALIDA" | sed -n 's/^ *\(bash scripts\/train\/train\.sh --desde .*\)$/\1/p' | tail -1; }

# `-c core.quotePath=false` porque git CITA también aquí: sin eso la propia
# comprobación del autotest buscaría «docs/handoff/ñandú.md» en un listado que
# dice `"docs/handoff/\303\261and\303\272.md"` — la misma trampa que este
# autotest existe para vigilar.
en_main() { git -C "$1/paraguas" -c core.quotePath=false ls-tree -r --name-only origin/main | grep -qxF "$2"; }
set_en_main() { git -C "$1/paraguas" show origin/main:versions.yaml 2>/dev/null | sed -n 's/^quantum: "\(.*\)"/\1/p'; }

# caso_arbol <título> <ruta ajena...> — el camino de CREACIÓN: main al día, el
# re-pin sin commitear y una o más rutas ajenas en el árbol.
caso_arbol() {
  local titulo=$1; shift
  local lab; lab=$(mktemp -d "$BASE/caso.XXXXXX")
  echo "-- $titulo (árbol, camino de creación)"
  monta "$lab"
  local r
  for r in "$@"; do
    mkdir -p "$lab/paraguas/$(dirname "$r")"
    printf 'contenido ajeno\n' > "$lab/paraguas/$r"
  done
  tren "$lab" --desde paraguas --hasta paraguas
  [ "$RC" -eq 2 ] || bad "$titulo: la parada por rutas ajenas debía ser EXIT=2 y fue EXIT=$RC"
  for r in "$@"; do
    case "$SALIDA" in *"$r"*) ok "la parada nombra $r tal cual" ;; *) bad "$titulo: la parada no nombra $r (lo que imprime: $(printf '%s\n' "$SALIDA" | grep -c .) líneas)" ;; esac
  done
  local orden; orden=$(orden_impresa)
  [ -n "$orden" ] || { bad "$titulo: la parada no imprimió orden de relanzamiento"; return; }
  echo "    orden impresa: $orden"
  tren_literal "$lab" "$orden"
  if [ "$RC" -eq 0 ]; then ok "la orden impresa, ejecutada literalmente, converge (EXIT=0)"
  else bad "$titulo: la orden impresa vuelve a parar (EXIT=$RC): el tren no converge"; fi
  [ "$(set_en_main "$lab")" = "9.10.0" ] || bad "$titulo: origin/main no declara 9.10.0 tras la segunda vuelta"
  for r in "$@"; do
    en_main "$lab" "$r" && ok "$r entró en main por haberlo nombrado" || bad "$titulo: $r no llegó a main"
  done
}

# caso_rama <título> <ruta ajena> — el camino de RECUPERACIÓN: el re-pin y la
# ruta ajena ya COMMITEADOS en chore/set-9.10.0.
caso_rama() {
  local titulo=$1 r=$2
  local lab; lab=$(mktemp -d "$BASE/caso.XXXXXX")
  echo "-- $titulo (rama chore/set-*, camino de recuperación)"
  monta "$lab"
  mkdir -p "$lab/paraguas/$(dirname "$r")"
  printf 'contenido ajeno\n' > "$lab/paraguas/$r"
  git -C "$lab/paraguas" checkout -q -b chore/set-9.10.0
  git -C "$lab/paraguas" add -A
  git -C "$lab/paraguas" commit -q -m "chore(set): 9.10.0 — re-pin del set"
  tren "$lab" --desde paraguas --hasta paraguas
  [ "$RC" -eq 2 ] || bad "$titulo: la revisión de la rama debía parar con EXIT=2 y fue EXIT=$RC"
  case "$SALIDA" in *"$r"*) ok "la parada nombra $r tal cual" ;; *) bad "$titulo: la parada no nombra $r" ;; esac
  local orden; orden=$(orden_impresa)
  [ -n "$orden" ] || { bad "$titulo: la parada no imprimió orden de relanzamiento"; return; }
  echo "    orden impresa: $orden"
  tren_literal "$lab" "$orden"
  if [ "$RC" -eq 0 ]; then ok "la orden impresa, ejecutada literalmente, converge (EXIT=0)"
  else bad "$titulo: la orden impresa vuelve a parar (EXIT=$RC): el tren no converge"; fi
  [ "$(set_en_main "$lab")" = "9.10.0" ] || bad "$titulo: origin/main no declara 9.10.0 tras la segunda vuelta"
  en_main "$lab" "$r" && ok "$r entró en main por haberlo nombrado" || bad "$titulo: $r no llegó a main"
}

# caso_rename — un rename APUNTADO. Con `-z`, git emite DOS registros (primero
# el destino, luego el origen); el reparto juzga por el destino —como ya hacía—
# y el registro de origen se consume, no se lee como una ruta más: leído como
# si fuera un «XY ruta» saldría trozeado por sus tres primeros caracteres. Lo
# que la parada nombre tiene que ser la ruta de verdad en las dos vueltas.
caso_rename() {
  local lab; lab=$(mktemp -d "$BASE/caso.XXXXXX")
  local vieja="docs/handoff/vieja.md" nueva="docs/handoff/ñandú.md"
  echo "-- rename apuntado con destino acentuado (dos registros por ruta)"
  monta "$lab"
  mkdir -p "$lab/paraguas/docs/handoff"
  printf 'nota vieja\n' > "$lab/paraguas/$vieja"
  git -C "$lab/paraguas" add "$vieja"
  git -C "$lab/paraguas" commit -q -m "nota vieja"
  git -C "$lab/paraguas" push -q origin main
  git -C "$lab/paraguas" mv "$vieja" "$nueva"
  tren "$lab" --desde paraguas --hasta paraguas
  [ "$RC" -eq 2 ] || bad "rename: la parada por rutas ajenas debía ser EXIT=2 y fue EXIT=$RC"
  case "$SALIDA" in *"$nueva"*) ok "la parada juzga y nombra el destino ($nueva)" ;; *) bad "rename: la parada no nombra el destino $nueva" ;; esac
  # «docs/handoff/vieja.md» leído como un registro de estado daría este trozo.
  case "$SALIDA" in *"s/handoff/vieja.md"*) bad "rename: el registro de origen se coló trozeado en la parada" ;; *) ok "el registro de origen no se cuela trozeado" ;; esac
  local orden; orden=$(orden_impresa)
  [ -n "$orden" ] || { bad "rename: la parada no imprimió orden de relanzamiento"; return; }
  echo "    orden impresa: $orden"
  tren_literal "$lab" "$orden"
  if [ "$RC" -eq 0 ]; then ok "la orden impresa, ejecutada literalmente, converge (EXIT=0)"
  else bad "rename: la orden impresa vuelve a parar (EXIT=$RC): el tren no converge"; fi
  en_main "$lab" "$nueva" && ok "$nueva entró en main por haberlo nombrado" || bad "rename: $nueva no llegó a main"
  en_main "$lab" "$vieja" && bad "rename: $vieja sigue en main (el rename no entró entero)" || ok "el rename entró entero (el origen ya no está en main)"
}

echo "== autotest del reparto del árbol del tren =="
echo
caso_arbol "ruta ASCII"        "docs/handoff/nota.md"
caso_arbol "ruta acentuada"    "docs/handoff/ñandú.md"
caso_arbol "ruta con espacios" "docs/handoff/nota de trabajo.md"
caso_arbol "ruta con comilla"  "docs/handoff/no'che.md"
caso_arbol "dos rutas ajenas, una con espacios" "NOTA SUELTA.txt" "docs/handoff/año.md"
caso_rama  "ruta acentuada commiteada" "docs/handoff/ñandú.md"
caso_rama  "ruta con espacios commiteada" "docs/handoff/nota de trabajo.md"
caso_rename

echo
if [ "$fails" -eq 0 ]; then
  echo "train-rutas selftest: OK ($aserciones aserciones) — la orden que imprime la parada se ejecuta literalmente y converge"
else
  echo "train-rutas selftest: FALLO ($fails de $aserciones aserciones)" >&2
  exit 1
fi
