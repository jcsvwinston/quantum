#!/usr/bin/env bash
# showcase_smoke.sh — DX-27: smoke FUNCIONAL de los tres productos juntos.
#
# Hasta este script, integration.yml solo COMPILABA showcase_demo. Aquí se
# ejecuta lo que el ejemplo promete (QADR-0006): arranca la app, crea un
# artículo por la API pública y exige que
#
#   (a) el feed SQL en vivo de Orbit (Caso 1, quarkbridge) haya visto el
#       INSERT de Quark sobre `articles`, y
#   (b) Data Studio (Caso 2, quarkdatasource) liste los modelos Author y
#       Article.
#
# El CI falla si el feed en vivo deja de ver SQL de Quark — el criterio
# literal del informe DX (§6, DX-27).
#
# Se ejecuta desde la RAÍZ del paraguas, en modo workspace (go.work resuelve
# los checkouts hermanos al pin). Uso: bash scripts/ci/showcase_smoke.sh
set -uo pipefail

ROOT=$(pwd)
TMP=$(mktemp -d)
APP_PID=""
cleanup() {
  [ -n "$APP_PID" ] && kill "$APP_PID" 2>/dev/null && wait "$APP_PID" 2>/dev/null
  rm -rf "$TMP"
}
trap cleanup EXIT

fail() { echo "FAIL $*" >&2; exit 1; }

# Puerto libre para no chocar con otros jobs del runner.
PORT=$(python3 - <<'EOF'
import socket
s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()
EOF
)
BASE="http://127.0.0.1:$PORT"

echo "== build del showcase (workspace, al pin)"
go build -o "$TMP/showcase" ./nucleus/examples/showcase_demo || fail "showcase_demo no compila"

# La app escribe showcase_demo.db en el cwd y lee nucleus.yaml de ahí.
cp "$ROOT/nucleus/examples/showcase_demo/nucleus.yaml" "$TMP/"
(cd "$TMP" && NUCLEUS_PORT="$PORT" ./showcase > app.log 2>&1) &
APP_PID=$!

echo "== esperando /healthz en $BASE"
for _ in $(seq 1 100); do
  if curl -sf "$BASE/healthz" >/dev/null 2>&1; then break; fi
  if ! kill -0 "$APP_PID" 2>/dev/null; then
    tail -20 "$TMP/app.log" >&2
    fail "la app murió durante el arranque"
  fi
  sleep 0.3
done
curl -sf "$BASE/healthz" >/dev/null || { tail -20 "$TMP/app.log" >&2; fail "la app no levantó en 30s"; }

echo "== POST /api/articles (la API pública del shop)"
CREATE=$(curl -s -w '\n%{http_code}' -X POST "$BASE/api/articles" \
  -H 'Content-Type: application/json' \
  -d '{"author_id":1,"title":"smoke probe","body":"live feed check"}')
CODE=$(echo "$CREATE" | tail -1)
case "$CODE" in
  200|201) echo "   creado (HTTP $CODE)" ;;
  *) echo "$CREATE" >&2; fail "POST /api/articles devolvió HTTP $CODE" ;;
esac

echo "== login en el admin de Orbit"
JAR="$TMP/cookies.txt"
curl -s -c "$JAR" -b "$JAR" -o /dev/null "$BASE/admin/login"
LOGIN_CODE=$(curl -s -c "$JAR" -b "$JAR" -o "$TMP/login.out" -w '%{http_code}' \
  -X POST "$BASE/admin/login" \
  --data-urlencode 'username=admin' \
  --data-urlencode 'password=showcase-demo')
case "$LOGIN_CODE" in
  200|302|303) ;;
  *) cat "$TMP/login.out" >&2; fail "login del admin devolvió HTTP $LOGIN_CODE" ;;
esac

echo "== (a) el feed SQL en vivo vio el INSERT de Quark"
SNAPSHOT=$(curl -s -b "$JAR" "$BASE/admin/api/live/snapshot")
if ! echo "$SNAPSHOT" | grep -qi "articles"; then
  echo "$SNAPSHOT" | head -c 2000 >&2
  fail "el feed en vivo no contiene SQL sobre 'articles' — el puente quarkbridge (Caso 1) no ve el SQL de Quark"
fi
if ! echo "$SNAPSHOT" | grep -qiE "INSERT|SELECT"; then
  echo "$SNAPSHOT" | head -c 2000 >&2
  fail "el feed en vivo no contiene sentencias SQL"
fi
echo "   feed OK (SQL de Quark presente)"

echo "== (b) Data Studio lista los modelos Quark"
MODELS=$(curl -s -b "$JAR" "$BASE/admin/api/models")
for model in Author Article; do
  if ! echo "$MODELS" | grep -q "$model"; then
    echo "$MODELS" | head -c 2000 >&2
    fail "Data Studio no lista el modelo $model — el datasource quarkdatasource (Caso 2) no expone los modelos"
  fi
done
echo "   Data Studio OK (Author y Article listados)"

echo "showcase_smoke: OK — la app arranca, la API crea, el feed en vivo ve el SQL de Quark y Data Studio lista los modelos."
