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
  # `go list -m` puede contestar desde la caché local o de GitHub; lo que
  # muere en el tidy es la VERIFICACIÓN contra sum.golang.org, así que se
  # pregunta a la sumdb directamente (200 = ya lo sirve).
  for i in $(seq 1 60); do
    ok=1
    for m in "nucleus@$nt" "quark@$qt"; do
      code=$(curl -s -o /dev/null -w '%{http_code}' "https://sum.golang.org/lookup/github.com/jcsvwinston/$m" || echo 000)
      [ "$code" = "200" ] || ok=0
    done
    [ "$ok" -eq 1 ] && break
    [ "$i" -eq 1 ] && echo "  sum.golang.org aún no sirve nucleus $nt / quark $qt: esperando (hasta 30 min)"
    sleep 30
  done
  [ "$ok" -eq 1 ] || { echo "sum.golang.org no sirve nucleus $nt / quark $qt tras 30 min; reintenta más tarde" >&2; exit 1; }
fi
cd "$Q/../orbit" || exit 1
# Los módulos de quark que orbit pina (hoy quarkdatasource → drivers/sqlite)
# tienen SERIE PROPIA: su versión no sale de la de la raíz, así que se lee del
# checkout de quark, que es quien la tiene, y se le pasa a align_set.sh. No es
# cosmético: quark v1.13.0 sacó `internal/driverclassify` del módulo raíz y
# `drivers/sqlite v0.1.0` lo importa, así que el pin viejo contra la raíz nueva
# NO COMPILA —ahí paró el tren de 1.30.0—.
qmods=()
while IFS= read -r sub; do
  [ -n "$sub" ] || continue
  qtag=$(git -C "$Q/../quark" tag -l "$sub/v[0-9]*" | grep -E "^$sub/v[0-9]+\.[0-9]+\.[0-9]+$" | sort -V | tail -1)
  [ -n "$qtag" ] || { echo "sin tag publicado para quark/$sub, que orbit pina" >&2; exit 1; }
  qmods+=(--quark-module "$sub=${qtag##*/}")
done < <(grep -rhoE "github\.com/jcsvwinston/quark/[a-z0-9/._-]+" --include=go.mod . | sed 's|github.com/jcsvwinston/quark/||' | sort -u)
[ ${#qmods[@]} -eq 0 ] || echo "  módulos de quark pinados por orbit: ${qmods[*]}"
# El check compara contra el árbol del checkout: en main y limpio, se pone al
# día primero (un main rancio diría que los pines van atrás cuando ya no).
if [ "$(git branch --show-current)" = main ] && [ -z "$(git status --porcelain)" ]; then
  git pull -q --ff-only origin main || true
elif [ "$MODE" = check ]; then
  echo "FAIL: ../orbit no está en main limpio (rama $(git branch --show-current)); el check compararía otro árbol — vuelve a main o guarda los cambios" >&2
  exit 1
fi
if [ "$MODE" = check ]; then
  bash scripts/release/align_set.sh --nucleus "$nt" --quark "$qt" ${qmods[@]+"${qmods[@]}"} --check
else
  bash scripts/release/align_set.sh --nucleus "$nt" --quark "$qt" ${qmods[@]+"${qmods[@]}"}
fi
