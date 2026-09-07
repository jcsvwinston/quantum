#!/usr/bin/env bash
# selftest.sh — autotest de scripts/lib/background-app.sh: el servidor que una
# lane arranca en segundo plano MUERE cuando la lane lo para.
#
# Lo que prueba, con un servidor HTTP real (python3 -m http.server) en un
# directorio temporal, como hacen showcase_smoke y quickstart_smoke con su
# app:
#   1. BG_PID es el servidor, no un subshell intermedio (no tiene hijos y
#      sigue vivo tras responder — el subshell habría muerto con el exec);
#   2. el log se escribe donde se pidió (relativo al directorio del arranque);
#   3. tras bg_stop nada escucha en el puerto y el PID ya no existe, aunque
#      el directorio se haya borrado (el trap de las lanes hace rm -rf);
#   4. bg_stop sin PID o con un PID ya muerto es inocuo (devuelve 0).
# Rojo-antes: con el patrón `(cd d && cmd) &` sin exec, bajo bash 3.2 la
# aserción 1 falla (BG_PID tiene un hijo: el servidor) y la 3 también (el
# puerto sigue escuchando tras «parar»). Las dos lanes lo corren como paso 0;
# a mano desde la raíz del paraguas: bash tests/background-app/selftest.sh
set -uo pipefail

cd "$(dirname "$0")/../.."
# shellcheck source=scripts/lib/background-app.sh
source scripts/lib/background-app.sh

TMP=$(mktemp -d "${TMPDIR:-/tmp}/background-app.XXXXXX")
DIR="$TMP/app"
mkdir -p "$DIR"
fails=0
pass() { echo "ok   - $*"; }
fail() { echo "FAIL - $*" >&2; fails=$((fails + 1)); }

PORT=$(python3 - <<'PY'
import socket
s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()
PY
)
listening() { curl -s -o /dev/null "http://127.0.0.1:$PORT/"; }

cleanup() {
  # Red de seguridad del propio test: si el servidor sobrevivió, no dejar
  # nosotros el huérfano que venimos a cazar.
  if [[ -n "${BG_PID:-}" ]]; then kill -9 "$BG_PID" 2>/dev/null; fi
  if listening; then
    for p in $(lsof -nP -t -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null); do kill -9 "$p" 2>/dev/null; done
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT

bg_start "$DIR" app.log env PROBE=1 python3 -m http.server --bind 127.0.0.1 "$PORT"
for _ in $(seq 1 100); do listening && break; sleep 0.1; done
listening || { fail "el servidor de prueba no levantó en $PORT en 10 s"; exit 1; }

# 1. BG_PID es el servidor.
if kill -0 "$BG_PID" 2>/dev/null; then pass "BG_PID ($BG_PID) sigue vivo mientras el servidor responde"; else fail "BG_PID ($BG_PID) ya no existe con el servidor respondiendo: era un subshell que hizo fork"; fi
children=$(pgrep -P "$BG_PID" 2>/dev/null || true)
if [[ -z "$children" ]]; then pass "BG_PID no tiene hijos: es el propio servidor"; else fail "BG_PID tiene hijos ($(echo "$children" | tr '\n' ' ')): es un subshell y el servidor es otro proceso"; fi

# 2. El log, relativo al directorio del arranque.
if [[ -f "$DIR/app.log" ]]; then pass "el log está en <dir>/app.log"; else fail "no hay $DIR/app.log"; fi

# 3. Parar, borrar el directorio, y que no quede nada.
rm -rf "$DIR"
if bg_stop "$BG_PID"; then pass "bg_stop devuelve 0"; else fail "bg_stop devuelve 1: el PID $BG_PID sobrevivió a TERM y KILL"; fi
if listening; then fail "tras bg_stop algo sigue ESCUCHANDO en $PORT (huérfano)"; else pass "tras bg_stop nada escucha en $PORT"; fi
if kill -0 "$BG_PID" 2>/dev/null; then fail "tras bg_stop el PID $BG_PID sigue existiendo"; else pass "tras bg_stop el PID $BG_PID no existe"; fi

# 4. Inocuo sin PID o con PID muerto.
if bg_stop ""; then pass "bg_stop sin PID devuelve 0"; else fail "bg_stop sin PID devuelve 1"; fi
if bg_stop "$BG_PID"; then pass "bg_stop con un PID ya muerto devuelve 0"; else fail "bg_stop con un PID ya muerto devuelve 1"; fi

if [[ $fails -eq 0 ]]; then
  echo "background-app selftest: OK (8 aserciones)"
else
  echo "background-app selftest: FALLO ($fails aserciones)" >&2
  exit 1
fi
