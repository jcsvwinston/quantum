#!/usr/bin/env bash
# align-orbit-pins.sh [--check] — sube los pines CRUZADOS de orbit (nucleus y
# quark en los seis go.mod, más los hermanos) a los ÚLTIMOS TAGS publicados de
# ../quark y ../nucleus, llamando al escritor de orbit
# (scripts/release/align_set.sh, un solo commit conventional). Con --check solo
# verifica (EXIT=1 si algún pin va por detrás). Corre desde la raíz del
# paraguas; opera sobre el checkout hermano ../orbit en la rama que tenga.
set -uo pipefail
MODE=write; [ "${1:-}" = "--check" ] && MODE=check
Q=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
for r in quark nucleus orbit; do [ -e "$Q/../$r/.git" ] || { echo "sin checkout hermano en $Q/../$r" >&2; exit 1; }; git -C "$Q/../$r" fetch -q --tags origin || true; done
qt=$(git -C "$Q/../quark" tag -l 'v[0-9]*' | sort -V | tail -1)
nt=$(git -C "$Q/../nucleus" tag -l 'v[0-9]*' | sort -V | tail -1)
[ -n "$qt" ] && [ -n "$nt" ] || { echo "no encuentro tags de raíz en quark/nucleus" >&2; exit 1; }
echo "== align-orbit-pins ($MODE): nucleus $nt · quark $qt =="
cd "$Q/../orbit" || exit 1
# El check compara contra el árbol del checkout: en main y limpio, se pone al
# día primero (un main rancio diría que los pines van atrás cuando ya no).
if [ "$(git branch --show-current)" = main ] && [ -z "$(git status --porcelain)" ]; then git pull -q --ff-only origin main || true; fi
if [ "$MODE" = check ]; then
  bash scripts/release/align_set.sh --nucleus "$nt" --quark "$qt" --check
else
  bash scripts/release/align_set.sh --nucleus "$nt" --quark "$qt"
fi
