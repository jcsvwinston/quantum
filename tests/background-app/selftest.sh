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
#   4. bg_stop sin PID o con un PID ya muerto es inocuo (devuelve 0);
#   5. bg_stop tiene COTA: con un servidor que ignora SIGTERM (la app cuya
#      parada limpia se atasca) vuelve en ~5 s con el proceso matado a KILL
#      y el puerto libre — no bloquea el trap EXIT de la lane hasta el
#      timeout del job.
# Rojo-antes: con el patrón `(cd d && cmd) &` sin exec, bajo bash 3.2 la
# aserción 1 falla (BG_PID tiene un hijo: el servidor) y la 3 también (el
# puerto sigue escuchando tras «parar»). Con el bg_stop que hacía
# `wait "$pid"` a secas antes de sondear, la 5 falla: para un HIJO de la
# shell `wait` bloquea sin límite y el KILL de después era código muerto —
# aquí la red de seguridad del test mata al servidor a los 10 s y bg_stop
# vuelve tarde (≈10 s > 8), en vez de colgar el test. Las dos lanes lo
# corren como paso 0; a mano desde la raíz del paraguas:
# bash tests/background-app/selftest.sh
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
  if [[ -n "${NET:-}" ]]; then kill "$NET" 2>/dev/null; fi
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

# 5. Cota de bg_stop con un servidor que ignora TERM: KILL a los 5 s.
mkdir -p "$DIR"
bg_start "$DIR" app.log python3 -c "
import signal, http.server, socketserver
signal.signal(signal.SIGTERM, signal.SIG_IGN)
socketserver.TCPServer.allow_reuse_address = True
socketserver.TCPServer(('127.0.0.1', $PORT), http.server.SimpleHTTPRequestHandler).serve_forever()
"
STUBBORN=$BG_PID
for _ in $(seq 1 100); do listening && break; sleep 0.1; done
listening || { fail "el servidor que ignora TERM no levantó en $PORT en 10 s"; exit 1; }
# Red de seguridad: si bg_stop se cuelga en `wait`, matar al servidor a los
# 10 s para que el test termine en rojo (tarde) en vez de bloquearse.
( sleep 10; kill -9 "$STUBBORN" 2>/dev/null ) &
NET=$!
t0=$(date +%s)
bg_stop "$STUBBORN"; rc=$?
elapsed=$(( $(date +%s) - t0 ))
kill "$NET" 2>/dev/null; wait "$NET" 2>/dev/null
if [[ $rc -eq 0 ]]; then pass "bg_stop devuelve 0 con un servidor que ignora TERM"; else fail "bg_stop devuelve $rc con un servidor que ignora TERM"; fi
if [[ $elapsed -le 8 ]]; then pass "bg_stop volvió en $elapsed s (cota: TERM, 5 s, KILL)"; else fail "bg_stop tardó $elapsed s: el KILL de los 5 s no llegó (wait sin cota)"; fi
if listening; then fail "tras bg_stop el servidor que ignora TERM sigue ESCUCHANDO en $PORT"; else pass "tras bg_stop nada escucha en $PORT (servidor que ignora TERM)"; fi
if kill -0 "$STUBBORN" 2>/dev/null; then fail "tras bg_stop el PID $STUBBORN (ignora TERM) sigue existiendo"; else pass "tras bg_stop el PID $STUBBORN (ignora TERM) no existe"; fi

if [[ $fails -eq 0 ]]; then
  echo "background-app selftest: OK (12 aserciones)"
else
  echo "background-app selftest: FALLO ($fails aserciones)" >&2
  exit 1
fi
