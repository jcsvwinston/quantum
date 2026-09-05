#!/usr/bin/env bash
# quickstart_smoke.sh — gate del arco A2: el quickstart de la suite, ejecutado
# de verdad contra el set pinado, con presupuesto de tiempo.
#
# Hasta esta lane, el paraguas sólo COMPILABA y arrancaba una app ya escrita
# (showcase_smoke.sh). Aquí se hace lo que el lector del quickstart hace:
#
#   1. `nucleus new blog --template suite --with orbit,quark,quarkbridge,
#      quarkdatasource --db sqlite --offline` con el CLI compilado del
#      submódulo PINADO (no del proxy: el gate certifica el set, no la red);
#   2. build del proyecto generado resolviendo los hermanos por una COPIA del
#      go.work (`go work edit -use`), sin red — el mismo pin que ejerce
#      showcase_smoke. Ojo: el tren taggea nucleus antes que orbit, así que
#      `nucleus new --with orbit` al tag vN resuelve por el proxy el orbit del
#      set anterior hasta que orbit re-pina; la lane enmascara ese lag a
#      propósito resolviendo por go.work (certifica el set pinado, que es lo
#      que el paraguas publica). El lag lo vigila manifest-guard §5.
#   3. arranque, y los `curl` EXTRAÍDOS de website/docs/quickstart.md con el
#      parser compartido con el guard umbrella-quickstart-cost
#      (scripts/lib/quickstart-fences.sh): página y lane no pueden divergir —
#      lo que la página manda teclear es lo que aquí se ejecuta, con
#      localhost:8080 reescrito al puerto libre del job;
#   4. sondas propias de la lane: /nope → 404 (rutas desconocidas dejan de
#      esconderse tras un 403 uniforme), login en /admin, el feed SQL en vivo
#      vio el INSERT de Quark sobre `articles`, Data Studio lista Author y
#      Article;
#   5. aserciones sobre app.log: 0 WARN (el scaffold limpio arranca y sirve
#      su primer endpoint sin avisos) en las DOS gramáticas que conviven en
#      el log — la de nucleus (`level=WARN`) y la del logger por defecto de Go
#      que usa Quark (`… WARN List() called without explicit Limit()…`, vista
#      en el ensayo sobre showcase_demo) — y ≥1 `module route mounted` (el
#      módulo generado montó rutas). NO se exige `migration applied`: nucleus no aplica
#      migraciones SQL al arrancar (eso es `nucleus migrate up`) y el módulo
#      de la plantilla migra con `MigrateRegistered` de Quark, que no loguea;
#      el seed se prueba por HTTP (GET /api/articles con count ≥ 1).
#   6. PRESUPUESTO: scaffold + build + arranque + curls ≤
#      QUICKSTART_BUDGET_SECONDS (60), medido con la caché de módulos
#      RESTAURADA (setup-go con cache-dependency-path '**/go.sum'). Con caché
#      virgen no es alcanzable (`go install …@tag` frío costó 46 s el
#      2026-09-05; showcase_demo compila con ~67 s de CPU) — por eso el job
#      go-install-tag (cache:false) corre este mismo script con
#      QUICKSTART_BUDGET_SECONDS=0 (sólo informa) para que la cifra fría sea
#      visible cada lunes sin gatear con ella. Franja de AVISO entre
#      QUICKSTART_BUDGET_WARN (45) y el techo, para ver la deriva antes del
#      rojo. El desglose se imprime SIEMPRE (stdout y $GITHUB_STEP_SUMMARY).
#   7. tras el presupuesto: `go test ./...` del proyecto generado (la
#      plantilla emite un test con nucleustest) y el guard
#      check_quickstart_cost.sh sobre la página — un job, las dos cifras.
#
# SALVAGUARDA hasta el re-pin: si el nucleus pinado no conoce `--with`, la
# lane sale 0 con ::notice — así se fusiona ANTES del tren y se enciende sola
# al re-pinar nucleus. El criterio es UNO y compartido con el guard
# umbrella-quickstart-cost: qs_nucleus_knows_with (scripts/lib/
# quickstart-fences.sh) lee de la FUENTE pinada si `nucleus new` registra el
# flag; la lane, que además compila el CLI, exige que `nucleus new --help`
# diga lo mismo — si la fuente y el binario discrepan, muere aquí (el
# predicado se quedó ciego o el flag cambió de forma) en vez de dejar al guard
# midiendo en silencio. Los dos gates se encienden con el mismo pin porque
# leen la misma capacidad, no un número de versión.
#
# MODO ENSAYO (no es el gate): QUICKSTART_SMOKE_PROJECT=<dir> salta el CLI y
# el scaffold y ejecuta el resto del arnés (pasos 2-7) sobre una copia del
# proyecto dado — para ensayar el arnés antes del re-pin y para depurar en
# local; QUICKSTART_ADMIN_PASSWORD (por defecto `quickstart`, la de la
# plantilla) para un proyecto con otra credencial. Con showcase_demo hoy se
# espera rojo en WARN (jwt de nucleus + Limit() de quark): exactamente lo que
# el arco cierra.
#
# Se ejecuta desde la RAÍZ del paraguas. Uso: bash scripts/ci/quickstart_smoke.sh
# Fallo: FAIL <motivo> + últimas 40 líneas de app.log; el trap mata la app y
# borra el temporal.
set -uo pipefail

ROOT=$(pwd)
[[ -f go.work && -d nucleus/cmd/nucleus ]] || { echo "FAIL quickstart_smoke: ejecutar desde la raíz del paraguas (go.work + nucleus/cmd/nucleus)" >&2; exit 1; }

# shellcheck source=scripts/lib/quickstart-fences.sh
source scripts/lib/quickstart-fences.sh

PAGE="${QUICKSTART_PAGE:-website/docs/quickstart.md}"
BUDGET="${QUICKSTART_BUDGET_SECONDS:-60}"
BUDGET_WARN="${QUICKSTART_BUDGET_WARN:-45}"
PROJECT_NAME=blog
ADMIN_PASSWORD="${QUICKSTART_ADMIN_PASSWORD:-quickstart}"
# Ruta FÍSICA: en macOS mktemp devuelve /var/… (enlace a /private/var) y el
# go.work con `use /var/…` no casa con el cwd físico del build.
TMP=$(cd "$(mktemp -d "${TMPDIR:-/tmp}/quickstart-smoke.XXXXXX")" && pwd -P)
APP_PID=""
APP_LOG="$TMP/$PROJECT_NAME/app.log"

cleanup() {
  if [[ -n "$APP_PID" ]] && kill -0 "$APP_PID" 2>/dev/null; then
    kill "$APP_PID" 2>/dev/null
    wait "$APP_PID" 2>/dev/null
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT

fail() {
  echo "FAIL quickstart_smoke: $*" >&2
  if [[ -f "$APP_LOG" ]]; then
    echo "--- últimas 40 líneas de app.log ---" >&2
    tail -40 "$APP_LOG" >&2
  fi
  exit 1
}
now_ms() { python3 -c 'import time; print(int(time.time()*1000))'; }
secs() { python3 -c "print('%.1f' % ($1/1000.0))"; }
summary() {
  echo "$*"
  [[ -n "${GITHUB_STEP_SUMMARY:-}" ]] && echo "$*" >> "$GITHUB_STEP_SUMMARY"
  return 0
}

# --- 0. el parser compartido se prueba a sí mismo -----------------------------
echo "== 0. autotest del parser de fences compartido con el guard"
bash tests/quickstart-fences/selftest.sh || fail "el parser compartido no pasa su autotest — ni el guard ni la lane pueden fiarse de lo que leen"

if [[ ! -f "$PAGE" ]]; then
  fail "$PAGE no existe — los curl de la lane salen de la página"
fi

REHEARSAL="${QUICKSTART_SMOKE_PROJECT:-}"

# --- 1. CLI del submódulo pinado + salvaguarda --------------------------------
if [[ -z "$REHEARSAL" ]]; then
  echo "== 1. build del CLI de nucleus desde el submódulo pinado (workspace)"
  go build -o "$TMP/nucleus" ./nucleus/cmd/nucleus || fail "nucleus/cmd/nucleus no compila al pin"
  pin=$(git -C nucleus log -1 --format='%h' 2>/dev/null || echo '?')
  # El predicado compartido con el guard (fuente) y el binario tienen que
  # coincidir: es lo que garantiza que guard y lane se encienden a la vez.
  qs_nucleus_knows_with nucleus; source_knows=$?
  [[ $source_knows -ne 2 ]] || fail "nucleus/internal/cli/new.go no existe — ¿checkout sin submódulos? sin la fuente pinada no hay predicado de encendido"
  binary_knows=1
  "$TMP/nucleus" new --help 2>&1 | grep -qE -- '(^|[[:space:]])-+with([[:space:]=]|$)' && binary_knows=0
  if [[ $source_knows -ne $binary_knows ]]; then
    fail "el predicado de encendido y el CLI discrepan al pin $pin: qs_nucleus_knows_with (fuente, new.go) dice $([[ $source_knows -eq 0 ]] && echo SÍ || echo NO) y \`nucleus new --help\` dice $([[ $binary_knows -eq 0 ]] && echo SÍ || echo NO) — el guard umbrella-quickstart-cost se enciende con la fuente; ajustar el regex de qs_nucleus_knows_with (scripts/lib/quickstart-fences.sh) a cómo registra nucleus el flag"
  fi
  if [[ $binary_knows -ne 0 ]]; then
    echo "::notice title=quickstart-smoke inactiva::el nucleus pinado ($pin) no conoce \`nucleus new --with\` (fuente y binario coinciden); la lane sale 0 y el guard umbrella-quickstart-cost mide sin exigir, por el mismo criterio; los dos se encienden solos al re-pinar nucleus con el starter de suite (arco A2)."
    summary "quickstart-smoke: INACTIVA — el nucleus pinado ($pin) no conoce \`nucleus new --with\`; se enciende al re-pinar (mismo criterio que el guard de coste)."
    exit 0
  fi
fi

# Puerto libre para no chocar con otros jobs del runner (como showcase_smoke).
PORT=$(python3 - <<'EOF'
import socket
s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()
EOF
)
BASE="http://127.0.0.1:$PORT"

# --- 2. scaffold (T0) --------------------------------------------------------
T0=$(now_ms)
if [[ -z "$REHEARSAL" ]]; then
  echo "== 2. nucleus new $PROJECT_NAME --template suite --with orbit,quark,quarkbridge,quarkdatasource --db sqlite --offline"
  (cd "$TMP" && "$TMP/nucleus" new "$PROJECT_NAME" \
      --template suite \
      --with orbit,quark,quarkbridge,quarkdatasource \
      --db sqlite \
      --offline \
      --out "$TMP") > "$TMP/new.out" 2>&1 || { cat "$TMP/new.out" >&2; fail "nucleus new falló"; }
else
  echo "== 2. (ensayo) copia de $REHEARSAL como proyecto"
  [[ -d "$REHEARSAL" ]] || fail "QUICKSTART_SMOKE_PROJECT=$REHEARSAL no es un directorio"
  REHEARSAL=$(cd "$REHEARSAL" && pwd)
  cp -R "$REHEARSAL" "$TMP/$PROJECT_NAME"
  rm -f "$TMP/$PROJECT_NAME"/*.db
fi
[[ -f "$TMP/$PROJECT_NAME/go.mod" ]] || fail "el scaffold no dejó go.mod en $TMP/$PROJECT_NAME"
T_SCAFFOLD=$(now_ms)

# --- 3. hermanos por copia del go.work, build ---------------------------------
echo "== 3. build del proyecto con los hermanos del go.work (al pin, sin red)"
sed -e "s#^\([[:space:]]*\)\./#\1$ROOT/#" "$ROOT/go.work" > "$TMP/go.work"
if [[ -n "$REHEARSAL" ]]; then
  # El proyecto de ensayo puede estar ya en el workspace (showcase_demo lo
  # está): dos rutas con el mismo module path no caben en un go.work.
  (cd "$TMP" && go work edit -dropuse "$REHEARSAL" go.work)
fi
(cd "$TMP" && go work edit -use "$TMP/$PROJECT_NAME" go.work) || fail "go work edit -use falló"
export GOWORK="$TMP/go.work"
(cd "$TMP/$PROJECT_NAME" && go build -o app .) > "$TMP/build.out" 2>&1 || { cat "$TMP/build.out" >&2; fail "el proyecto generado no compila contra el set pinado"; }
T_BUILD=$(now_ms)

# --- 4. arranque --------------------------------------------------------------
echo "== 4. arranque en $BASE"
(cd "$TMP/$PROJECT_NAME" && NUCLEUS_PORT="$PORT" ADMIN_BOOTSTRAP_PASSWORD="$ADMIN_PASSWORD" ./app > app.log 2>&1) &
APP_PID=$!
for _ in $(seq 1 100); do
  if curl -sf "$BASE/healthz" >/dev/null 2>&1; then break; fi
  if ! kill -0 "$APP_PID" 2>/dev/null; then fail "la app murió durante el arranque"; fi
  sleep 0.3
done
curl -sf "$BASE/healthz" >/dev/null || fail "la app no levantó en 30 s"
T_BOOT=$(now_ms)

# --- 5. los curl de la página ---------------------------------------------------
echo "== 5. los curl de $PAGE, contra la app generada"
page_curls=$(qs_commands "$PAGE" | grep -E '^curl([[:space:]]|$)' || true)
[[ -n "$page_curls" ]] || fail "$PAGE no tiene ningún curl en sus fences — sin curls no hay quickstart que ejecutar (verde-vacío vetado)"

# `curl` sombreado: captura código y cuerpo aunque la página redirija la
# salida (`> /dev/null`): la redirección interna gana a la externa.
BODY="$TMP/body"; CODE="$TMP/code"
run_page_curl() {
  local cmd=$1
  cmd=${cmd//localhost:8080/127.0.0.1:$PORT}
  cmd=${cmd//127.0.0.1:8080/127.0.0.1:$PORT}
  curl() { command curl "$@" -o "$BODY" -w '%{http_code}' > "$CODE"; }
  : > "$BODY"; : > "$CODE"
  eval "$cmd" 2>/dev/null
  unset -f curl
}
n_curls=0
saw_articles=0
while IFS= read -r c; do
  [[ -n "$c" ]] || continue
  n_curls=$((n_curls + 1))
  run_page_curl "$c"
  code=$(cat "$CODE")
  if [[ "$c" == *"-X POST"* || "$c" == *"--request POST"* ]]; then
    case "$code" in
      200|201) ;;
      *) echo "   $c" >&2; head -c 600 "$BODY" >&2; echo >&2; fail "el POST del quickstart devolvió HTTP $code (esperado 201)" ;;
    esac
  else
    [[ "$code" == "200" ]] || { echo "   $c" >&2; head -c 600 "$BODY" >&2; echo >&2; fail "el GET del quickstart devolvió HTTP $code (esperado 200)"; }
    if [[ "$c" == *"/api/articles"* ]]; then
      grep -q '"articles"' "$BODY" || fail "GET /api/articles no devuelve \"articles\""
      grep -qE '"count":[[:space:]]*[1-9]' "$BODY" || { head -c 600 "$BODY" >&2; echo >&2; fail "GET /api/articles no trae el artículo sembrado (count 0): la plantilla no migró ni sembró"; }
      saw_articles=1
    fi
  fi
  echo "   HTTP $code ← $c"
done <<<"$page_curls"
[[ $saw_articles -eq 1 ]] || fail "ningún curl de la página lee /api/articles — el quickstart tiene que enseñar el primer endpoint"

# --- 5b. sondas propias de la lane -------------------------------------------
echo "== 5b. sondas de la lane: /nope, admin, feed en vivo, Data Studio"
code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/nope")
[[ "$code" == "404" ]] || fail "GET /nope devolvió HTTP $code (esperado 404: una ruta que no existe no se esconde tras un 403)"
echo "   HTTP 404 ← GET /nope"

JAR="$TMP/cookies.txt"
curl -s -c "$JAR" -b "$JAR" -o /dev/null "$BASE/admin/login"
LOGIN_CODE=$(curl -s -c "$JAR" -b "$JAR" -o "$TMP/login.out" -w '%{http_code}' \
  -X POST "$BASE/admin/login" \
  --data-urlencode 'username=admin' \
  --data-urlencode "password=$ADMIN_PASSWORD")
case "$LOGIN_CODE" in
  200|302|303) echo "   HTTP $LOGIN_CODE ← POST /admin/login (admin/$ADMIN_PASSWORD)" ;;
  *) head -c 600 "$TMP/login.out" >&2; echo >&2; fail "login del admin devolvió HTTP $LOGIN_CODE" ;;
esac

SNAPSHOT=$(curl -s -b "$JAR" "$BASE/admin/api/live/snapshot")
echo "$SNAPSHOT" | grep -qi "articles" || { echo "$SNAPSHOT" | head -c 1500 >&2; echo >&2; fail "el feed en vivo no contiene SQL sobre 'articles' (quarkbridge no ve el SQL de Quark)"; }
echo "$SNAPSHOT" | grep -qi "INSERT" || { echo "$SNAPSHOT" | head -c 1500 >&2; echo >&2; fail "el feed en vivo no vio el INSERT del POST del quickstart"; }
echo "   feed en vivo: INSERT sobre articles presente"

MODELS=$(curl -s -b "$JAR" "$BASE/admin/api/models")
for model in Author Article; do
  echo "$MODELS" | grep -q "$model" || { echo "$MODELS" | head -c 1500 >&2; echo >&2; fail "Data Studio no lista el modelo $model (quarkdatasource no expone los modelos)"; }
done
echo "   Data Studio: Author y Article listados"
T1=$(now_ms)

# --- 6. desglose (SIEMPRE, antes de cualquier veredicto posterior) ------------
t_scaffold=$((T_SCAFFOLD - T0)); t_build=$((T_BUILD - T_SCAFFOLD)); t_boot=$((T_BOOT - T_BUILD)); t_curls=$((T1 - T_BOOT)); t_total=$((T1 - T0))
breakdown="scaffold $(secs $t_scaffold) s · build $(secs $t_build) s · boot $(secs $t_boot) s · curls $(secs $t_curls) s · total $(secs $t_total) s"
total_s=$((t_total / 1000))
if [[ "$BUDGET" == "0" ]]; then
  summary "quickstart-smoke: $breakdown (sólo informa: QUICKSTART_BUDGET_SECONDS=0, caché de módulos ${QUICKSTART_CACHE_LABEL:-según el job})"
else
  summary "quickstart-smoke: $breakdown (presupuesto $BUDGET s, caché de módulos ${QUICKSTART_CACHE_LABEL:-según el job})"
fi

# --- 7. app.log: 0 WARN (dos gramáticas), rutas del módulo montadas -----------
echo "== 7. app.log: 0 WARN, rutas del módulo montadas"
WARN_RE='level=WARN|^[0-9/]+ [0-9:]+ WARN '
n_warn=$(grep -cE "$WARN_RE" "$APP_LOG" || true)
if [[ "$n_warn" != "0" ]]; then
  grep -E "$WARN_RE" "$APP_LOG" | cut -c1-200 >&2
  fail "el scaffold limpio arrancó y sirvió su primer endpoint con $n_warn línea(s) WARN (esperado 0)"
fi
grep -q 'module route mounted' "$APP_LOG" || fail "app.log no registra ningún 'module route mounted': el módulo generado no montó rutas"
echo "   0 WARN · $(grep -c 'module route mounted' "$APP_LOG") rutas de módulo montadas"

# --- 8. veredicto del presupuesto ---------------------------------------------
if [[ "$BUDGET" != "0" ]]; then
  if [[ $total_s -gt $BUDGET ]]; then
    slowest="build $(secs $t_build) s"
    [[ $t_scaffold -gt $t_build ]] && slowest="scaffold $(secs $t_scaffold) s"
    [[ $t_boot -gt $t_build && $t_boot -gt $t_scaffold ]] && slowest="boot $(secs $t_boot) s"
    fail "$total_s s > $BUDGET s ($slowest)"
  elif [[ $total_s -ge $BUDGET_WARN ]]; then
    echo "::warning title=quickstart-smoke cerca del techo::$total_s s, franja de aviso $BUDGET_WARN-$BUDGET s ($breakdown)"
  fi
fi

# --- 9. tras el presupuesto: el test emitido y el guard de coste ---------------
echo "== 9. go test ./... del proyecto generado"
(cd "$TMP/$PROJECT_NAME" && go test ./...) > "$TMP/test.out" 2>&1 || { cat "$TMP/test.out" >&2; fail "go test ./... del proyecto generado falla (el test que emite la plantilla)"; }
grep -q 'ok' "$TMP/test.out" || { cat "$TMP/test.out" >&2; fail "go test ./... no ejecutó ningún paquete con tests ([no test files] en todos): la plantilla no emitió su test"; }
unset GOWORK

echo "== 10. guard umbrella-quickstart-cost sobre $PAGE"
bash scripts/check_quickstart_cost.sh "$PAGE" || fail "check_quickstart_cost.sh en rojo sobre $PAGE"

echo "quickstart_smoke: OK — nucleus new --with al set pinado, arranca sin WARN, los curl de la página responden, /nope es 404, el feed ve el INSERT y Data Studio lista los modelos; $breakdown"
