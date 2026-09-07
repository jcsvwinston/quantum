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
# Los tags acaban de cortarse y el proxy de Go (y sum.golang.org) tardan
# unos minutos en servirlos: el `go mod tidy` de align_set.sh moría con
# «404 Not Found … unknown revision» (tren de 1.29.0). En modo escritura se
# espera a que el proxy resuelva los dos antes de tocar nada (hasta 10 min).
if [ "$MODE" = write ]; then
  probe=$(mktemp -d); ( cd "$probe" && go mod init probe >/dev/null 2>&1
    for i in $(seq 1 20); do
      if GOFLAGS=-mod=mod go list -m "github.com/jcsvwinston/nucleus@$nt" >/dev/null 2>&1 \
         && GOFLAGS=-mod=mod go list -m "github.com/jcsvwinston/quark@$qt" >/dev/null 2>&1; then exit 0; fi
      [ "$i" -eq 1 ] && echo "  el proxy de Go aún no sirve $nt/$qt: esperando"
      sleep 30
    done; exit 1 ) || { echo "el proxy de Go no sirve nucleus $nt / quark $qt tras 10 min; reintenta más tarde" >&2; rm -rf "$probe"; exit 1; }
  rm -rf "$probe"
fi
cd "$Q/../orbit" || exit 1
# El check compara contra el árbol del checkout: en main y limpio, se pone al
# día primero (un main rancio diría que los pines van atrás cuando ya no).
if [ "$(git branch --show-current)" = main ] && [ -z "$(git status --porcelain)" ]; then
  git pull -q --ff-only origin main || true
elif [ "$MODE" = check ]; then
  echo "FAIL: ../orbit no está en main limpio (rama $(git branch --show-current)); el check compararía otro árbol — vuelve a main o guarda los cambios" >&2
  exit 1
fi
if [ "$MODE" = check ]; then
  bash scripts/release/align_set.sh --nucleus "$nt" --quark "$qt" --check
else
  bash scripts/release/align_set.sh --nucleus "$nt" --quark "$qt"
fi
