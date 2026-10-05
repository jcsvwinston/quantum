#!/usr/bin/env bash
# tutorials_smoke.sh — los tutoriales y las guías de migración del sitio de la
# suite, EJECUTADOS paso a paso contra el set pinado (arco A11, sesiones W2 y
# W3).
#
# Un tutorial es una página que manda teclear comandos y escribir ficheros.
# Una guía de migración (W3: desde Gin + GORM, desde Django) es lo mismo para
# su lado Quantum, y además enseña el código de la pila de origen para
# compararlo: ese código va en fences SIN título (```go, ```python), que
# qs_steps no toma por fichero, y la página dice que el CI no lo ejecuta. Un
# comando de la pila de origen no va nunca en una fence de shell: la lane lo
# ejecutaría.
# Esta lane hace lo que haría el lector, en el orden de la página, con el
# parser compartido con el quickstart (scripts/lib/quickstart-fences.sh,
# qs_steps): no hay un segundo lector de markdown que pueda entender otra cosa.
#
#   - Un COMANDO (línea de una fence ```bash/sh/shell) se evalúa en ESTA shell,
#     así que `cd` y las variables que la página asigna (`token=$(curl …)`)
#     duran hasta el comando siguiente, como en la terminal del lector. Sale
#     distinto de 0 → la lane cae en ese paso.
#   - Un FICHERO (fence con title="<ruta>") se escribe con su contenido exacto,
#     relativo al directorio en el que la página está en ese momento.
#   - Una SALIDA (fence json/text pegada a la fence de shell) se compara con
#     lo que imprimió el último comando: json por igualdad de documentos
#     (orden de claves y espacios no cuentan), text línea a línea sin los
#     espacios de los bordes.
#
# Lo que la lane cambia de lo que el lector teclea, y por qué:
#
#   - `nucleus …` es el CLI compilado del submódulo PINADO, y `nucleus new` y
#     `nucleus generate module` llevan `--offline`: el gate certifica el set,
#     no la red. El proyecto que `new` escribe entra en una COPIA del go.work
#     (`go work edit -use`), y los hermanos se resuelven por ahí, al pin —
#     lo mismo que hace quickstart_smoke.sh.
#   - `go mod tidy` y `go get …` no hacen nada (lo dicen en el log): buscarían
#     en el proxy lo que el go.work ya resuelve al pin.
#   - `nucleus add` hace que la lane caiga: instala desde el proxy.
#   - `go run .` no bloquea: el lector lo lanza en otra terminal; aquí se
#     compila, se arranca en segundo plano en un puerto libre
#     (NUCLEUS_PORT) y se espera a /healthz. Un segundo `go run .` en la misma
#     página para el anterior y arranca el nuevo.
#   - `localhost:8080` y `127.0.0.1:8080` en un comando pasan al puerto libre.
#     En los FICHEROS no se reescribe nada: un tutorial que necesite la URL en
#     un fichero la recibe por la línea de comandos.
#   - `curl` lleva `--fail-with-body` (un 4xx o 5xx tumba el paso) salvo que
#     el comando imprima su propio código (`-w`) o que su salida la compare
#     la fence siguiente: en esos dos casos la página ya dice qué espera.
#
# Después de los pasos, cada página tiene sus SONDAS (sondas_<página>, abajo):
# lo que el lector hace en el navegador y la página sólo cuenta en prosa
# (entrar en /admin, mirar el feed en vivo). Y la app de cada tutorial
# arranca y sirve sin una sola línea WARN, como el quickstart.
#
# PRESUPUESTO por tutorial (desde el primer paso hasta la última sonda, con el
# CLI ya compilado): TUTORIALS_BUDGET_SECONDS (60), con franja de aviso desde
# TUTORIALS_BUDGET_WARN (45) — las cifras del quickstart. La caché de módulos
# restaurada es la condición del número, como en quickstart_smoke.sh; el
# desglose se imprime siempre (stdout y $GITHUB_STEP_SUMMARY). Medido en local
# el 2026-10-05 con caché caliente: 8,3 s, 7,9 s y 2,5 s los tutoriales;
# 5,2 s (Gin + GORM) y 8,0 s (Django) las guías.
#
# Requisitos: go (el del go.work), python3 (comparar salidas), curl ≥ 7.76
# (--fail-with-body) y node ≥ 22.18 (el tutorial API-only ejecuta un .ts con
# el cliente generado, sin paso de build).
#
# Uso, desde la RAÍZ del paraguas: bash scripts/ci/tutorials_smoke.sh
# ENSAYO: TUTORIALS_PAGES="ruta/a.md ruta/b.md" sustituye la lista (para
# depurar una página o romper un paso a propósito y ver caer la lane).
# Fallo: «FAIL tutorials_smoke: <página>:<línea>» con el paso, su salida y la
# cola del log de la app; el trap para la app y borra el temporal. Cuando la
# salida del paso nombra un fichero que escribió una fence de la página (un
# error de compilación en el `go run .`, un test rojo en el `go test`), la
# línea «en la página: <página>:<línea>» dice dónde está el fallo en la fence,
# no sólo qué comando lo destapó (fence_lines, abajo).
#
# Compatibilidad: bash 3.2 (macOS) — sin mapfile, sin arrays asociativos.
set -uo pipefail

ROOT=$(pwd)
[[ -f go.work && -d nucleus/cmd/nucleus ]] || { echo "FAIL tutorials_smoke: ejecutar desde la raíz del paraguas (go.work + nucleus/cmd/nucleus)" >&2; exit 1; }

# shellcheck source=scripts/lib/quickstart-fences.sh
source scripts/lib/quickstart-fences.sh
# shellcheck source=scripts/lib/background-app.sh
source scripts/lib/background-app.sh

# Las páginas que la lane ejecuta. El banco del sitio (tests/sitebench/
# sitebench.sh, ST-04…ST-08) busca el nombre de cada página (con su .md) en
# una línea de este script que no sea comentario, y que un workflow llame al
# script: quitar una de aquí la deja «sin lane». Por eso el resto del script
# nombra las páginas sin la extensión (sondas_<página>, tolerated_warn).
TUTORIAL_PAGES=(
  website/docs/tutorial-multi-tenant-saas.md
  website/docs/tutorial-api-only.md
  website/docs/tutorial-mvc-monolith.md
  website/docs/coming-from-gin-gorm.md
  website/docs/coming-from-django.md
)
if [[ -n "${TUTORIALS_PAGES:-}" ]]; then
  # shellcheck disable=SC2206
  TUTORIAL_PAGES=(${TUTORIALS_PAGES})
fi

BUDGET="${TUTORIALS_BUDGET_SECONDS:-60}"
BUDGET_WARN="${TUTORIALS_BUDGET_WARN:-45}"
# Ruta FÍSICA: en macOS mktemp devuelve /var/… (enlace a /private/var) y el
# go.work con `use /var/…` no casa con el cwd físico del build.
TMP=$(cd "$(mktemp -d "${TMPDIR:-/tmp}/tutorials-smoke.XXXXXX")" && pwd -P)
APP_PID=""

cleanup() {
  bg_stop "$APP_PID" || echo "tutorials_smoke: la app ($APP_PID) sobrevivió a TERM y KILL — queda un servidor huérfano" >&2
  rm -rf "$TMP"
}
trap cleanup EXIT

now_ms() { python3 -c 'import time; print(int(time.time()*1000))'; }
secs() { python3 -c "print('%.1f' % ($1/1000.0))"; }
summary() {
  echo "$*"
  [[ -n "${GITHUB_STEP_SUMMARY:-}" ]] && echo "$*" >> "$GITHUB_STEP_SUMMARY"
  return 0
}
free_port() {
  python3 - <<'EOF'
import socket
s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()
EOF
}

# ¿Sigue abierto un hallazgo en el registro de la auditoría? Las dos
# excepciones de esta lane (abajo) viven mientras su hallazgo esté abierto y
# mueren solas cuando alguien lo marca hecho: sin lista que recordar vaciar.
REGISTRO="$ROOT/docs/auditoria/madurez-2026-09-03/registro.csv"
registry_open() { grep -qE "^$1,[^,]*,[^,]*,[^,]*,abierto," "$REGISTRO"; }

# tolerated_warn <página> — el regex de la línea WARN que el set pinado emite
# por un defecto REGISTRADO del producto, o nada. NU-111: en una aplicación
# multi-tenant, la sonda de storage de /healthz lista el almacén sin tenant y
# dispara el aviso de «degradado al espacio compartido» que existe para los
# jobs sin ámbito de petición (y con require_tenant_storage: true, /healthz
# responde 503). El lector no lo ve —el tutorial no llama a /healthz—, pero un
# orquestador sí, y esta lane también.
tolerated_warn() {
  if [[ "$(basename "$1" .md)" == tutorial-multi-tenant-saas ]] && registry_open NU-111; then
    echo 'storage: operation with no tenant in context degraded to the SHARED'
  fi
}

# Estado del tutorial en curso (lo leen fail y las sondas).
PAGE=""; PAGE_FILE=""; WORK=""; PORT=""; STEP_DESC=""; STEP_OUT=""; STEP_ERR=""; APP_STARTS=0

app_logs() { ls "$WORK"/app.*.log 2>/dev/null; }

# fence_lines <fichero>… — los «ruta.go:N» que nombra la salida de un paso
# fallido, traducidos a líneas de la PÁGINA. Cada fichero del proyecto lo
# escribió una fence con título (write_file lo apunta en $WORK/files.tsv con
# la línea de la fence), y la línea N del fichero es la línea fence+N de la
# página: un error de compilación o un test rojo en un fichero que la página
# manda escribir apunta así a donde se edita, no a la línea del `go run .` o
# del `go test` que lo destapó. Rutas relativas al directorio del paso, o sólo
# el nombre del fichero (así cita `go test` la línea de un t.Errorf) cuando un
# único fichero escrito se llama así.
fence_lines() {
  [[ -n "$WORK" && -s "$WORK/files.tsv" ]] || return 0
  python3 - "$WORK/files.tsv" "$PWD" "$PAGE" "$@" <<'EOF'
import os, re, sys
tsv, cwd, page = sys.argv[1:4]
files = {}
for row in open(tsv):
    path, line = row.rstrip("\n").split("\t")
    files[path] = int(line)
by_base = {}
for path in files:
    by_base.setdefault(os.path.basename(path), []).append(path)
seen = []
for src in sys.argv[4:]:
    try:
        text = open(src, errors="replace").read()
    except OSError:
        continue
    for m in re.finditer(r"([\w./-]+\.\w+):(\d+)(?::\d+)?:", text):
        ref, n = m.group(1), int(m.group(2))
        path = ref if os.path.isabs(ref) else os.path.normpath(os.path.join(cwd, ref))
        if path not in files:
            cands = by_base.get(ref, []) if "/" not in ref else []
            if len(cands) != 1:
                continue
            path = cands[0]
        hit = "%s:%d (%s:%d)" % (page, files[path] + n, ref, n)
        if hit not in seen:
            seen.append(hit)
for hit in seen[:5]:
    print(hit)
EOF
}

fail() {
  local where w
  where=$(fence_lines "$STEP_OUT" "$STEP_ERR" 2>/dev/null || true)
  echo "FAIL tutorials_smoke: $*" >&2
  if [[ -n "$where" ]]; then
    while IFS= read -r w; do echo "  en la página: $w" >&2; done <<<"$where"
  fi
  if [[ -n "$STEP_DESC" ]]; then
    echo "  paso: $STEP_DESC" >&2
  fi
  if [[ -n "$STEP_OUT" && -s "$STEP_OUT" ]]; then
    echo "--- salida del paso (últimas 30 líneas) ---" >&2
    tail -30 "$STEP_OUT" >&2
  fi
  if [[ -n "$STEP_ERR" && -s "$STEP_ERR" ]]; then
    echo "--- stderr del paso (últimas 30 líneas) ---" >&2
    tail -30 "$STEP_ERR" >&2
  fi
  local log
  log=$(app_logs | tail -1)
  if [[ -n "$log" && -s "$log" ]]; then
    echo "--- últimas 40 líneas del log de la app ---" >&2
    tail -40 "$log" >&2
  fi
  [[ -n "${GITHUB_STEP_SUMMARY:-}" ]] && echo "tutorials-smoke: FALLO — $*${where:+ — en la página: $(head -1 <<<"$where")}${STEP_DESC:+ (paso: $STEP_DESC)}" >> "$GITHUB_STEP_SUMMARY"
  exit 1
}

# --- Lo que la página teclea, con los cambios de la cabecera ----------------
# La lane llama a los binarios reales con `command`, así que estas funciones
# sólo las alcanzan los comandos de la página.

nucleus() {
  local sub=${1:-} a has_offline=0
  for a in "$@"; do [[ "$a" == "--offline" || "$a" == "-offline" ]] && has_offline=1; done
  case "$sub" in
    new)
      shift
      local args=("$@") name="" out="." i=0 skip=0
      # Nombre del proyecto: el primer argumento que no es flag ni valor de
      # una flag con valor; --out decide el directorio padre.
      while [[ $i -lt ${#args[@]} ]]; do
        a=${args[$i]}
        if [[ $skip -eq 1 ]]; then skip=0
        else
          case "$a" in
            --out=*|-out=*) out=${a#*=} ;;
            --out|-out) out=${args[$((i+1))]:-.}; skip=1 ;;
            --module|-module|--port|-port|--template|-template|--db|-db|--with|-with) skip=1 ;;
            -*) ;;
            *) [[ -z "$name" ]] && name=$a ;;
          esac
        fi
        i=$((i+1))
      done
      [[ -n "$name" ]] || { echo "tutorials_smoke: \`nucleus new\` sin nombre de proyecto" >&2; return 2; }
      # --offline va detrás del nombre si la página lo pone primero (las flags
      # que lo siguen se leen), y delante si empieza por flags: el paquete flag
      # de Go deja de leer flags en el primer argumento posicional.
      if [[ $has_offline -eq 1 ]]; then "$NUCLEUS_BIN" new "$@"
      elif [[ "${1:-}" == -* ]]; then "$NUCLEUS_BIN" new --offline "$@"
      else "$NUCLEUS_BIN" new "$@" --offline
      fi || return
      local dir
      dir=$(cd "$out/$name" && pwd -P) || return
      command go work edit -use "$dir" "$GOWORK" || return
      echo "(lane) $dir entra en la copia del go.work: los hermanos se resuelven al pin, sin red"
      ;;
    generate)
      if [[ "${2:-}" == module && $has_offline -eq 0 ]]; then "$NUCLEUS_BIN" "$@" --offline; else "$NUCLEUS_BIN" "$@"; fi
      ;;
    add)
      echo "tutorials_smoke: la lane no ejecuta \`nucleus add\`: instala desde el proxy de módulos y la lane certifica el set pinado" >&2
      return 2
      ;;
    *) "$NUCLEUS_BIN" "$@" ;;
  esac
}

go() {
  if [[ $# -eq 2 && "$1" == run && "$2" == . ]]; then
    start_app
    return
  fi
  if [[ "${1:-}" == mod && "${2:-}" == tidy ]] || [[ "${1:-}" == get ]]; then
    echo "(lane) go $*: no se ejecuta — el go.work del set pinado resuelve los módulos, sin red"
    return 0
  fi
  command go "$@"
}

curl() {
  local a enforce=1
  for a in "$@"; do
    case "$a" in -w|--write-out|--write-out=*) enforce=0 ;; esac
  done
  [[ "${NEXT_IS_OUT:-0}" == 1 ]] && enforce=0
  if [[ $enforce -eq 1 ]]; then
    command curl --fail-with-body --max-time 30 "$@"
  else
    command curl --max-time 30 "$@"
  fi
}

# start_app — el `go run .` de la página: compilar en el directorio actual,
# arrancar en segundo plano y esperar a /healthz.
start_app() {
  if [[ -n "$APP_PID" ]]; then
    bg_stop "$APP_PID" || { echo "tutorials_smoke: la app anterior ($APP_PID) no murió" >&2; return 1; }
    APP_PID=""
  fi
  command go build -o "$WORK/app" . || { echo "tutorials_smoke: \`go run .\` no compila en $PWD" >&2; return 1; }
  APP_STARTS=$((APP_STARTS + 1))
  local log="$WORK/app.$APP_STARTS.log"
  bg_start "$PWD" "$log" env NUCLEUS_PORT="$PORT" "$WORK/app"
  APP_PID=$BG_PID
  local i
  for i in $(seq 1 100); do
    command curl -sf "http://127.0.0.1:$PORT/healthz" >/dev/null 2>&1 && break
    if ! kill -0 "$APP_PID" 2>/dev/null; then
      echo "tutorials_smoke: la app murió durante el arranque" >&2
      tail -40 "$log" >&2
      APP_PID=""
      return 1
    fi
    sleep 0.3
  done
  command curl -sf "http://127.0.0.1:$PORT/healthz" >/dev/null 2>&1 || { echo "tutorials_smoke: la app no levantó /healthz en 30 s" >&2; return 1; }
  echo "(lane) go run . → compilada y arrancada en segundo plano en :$PORT (log $log)"
}

# --- Los tres tipos de paso -------------------------------------------------

run_cmd() {
  local cmd=$1 line=$2 rc
  cmd=${cmd//localhost:8080/localhost:$PORT}
  cmd=${cmd//127.0.0.1:8080/127.0.0.1:$PORT}
  : > "$STEP_OUT"; : > "$STEP_ERR"
  set +u
  eval "$cmd" < /dev/null > "$STEP_OUT" 2> "$STEP_ERR"
  rc=$?
  set -u
  [[ $rc -eq 0 ]] || fail "$PAGE:$line: el comando salió con $rc"
  if [[ -s "$STEP_OUT" ]]; then sed -e 's/^/     | /' "$STEP_OUT" | head -8; fi
}

write_file() {
  local rel=$1 line=$2
  case "$rel" in
    /*|..|../*|*/../*|*/..) fail "$PAGE:$line: la ruta del fichero ($rel) sale del directorio del proyecto" ;;
  esac
  mkdir -p "$(dirname "$rel")" || fail "$PAGE:$line: no se pudo crear el directorio de $rel"
  qs_fence_body "$PAGE_FILE" "$line" > "$rel" || fail "$PAGE:$line: qs_fence_body no leyó la fence de $rel"
  printf '%s\t%s\n' "$PWD/$rel" "$line" >> "$WORK/files.tsv"
  echo "     escrito $PWD/$rel ($(wc -l < "$rel" | tr -d ' ') líneas)"
}

check_out() {
  local lang=$1 line=$2 expected="$WORK/expected"
  qs_fence_body "$PAGE_FILE" "$line" > "$expected" || fail "$PAGE:$line: qs_fence_body no leyó la salida"
  python3 - "$lang" "$expected" "$STEP_OUT" <<'EOF' || fail "$PAGE:$line: lo que imprimió el comando no es la salida que la página enseña"
import json, sys
lang, exp_path, act_path = sys.argv[1:4]
exp_raw = open(exp_path).read()
act_raw = open(act_path).read()
def lines(s):
    out = [l.strip() for l in s.splitlines()]
    while out and out[0] == "": out.pop(0)
    while out and out[-1] == "": out.pop()
    return out
if lang == "json":
    try:
        exp = json.loads(exp_raw)
    except ValueError as e:
        print("  la fence json de la página no es JSON: %s" % e, file=sys.stderr); sys.exit(1)
    try:
        act = json.loads(act_raw)
    except ValueError:
        print("  el comando no imprimió JSON:\n    %s" % act_raw.strip()[:600], file=sys.stderr); sys.exit(1)
    if exp != act:
        print("  la página:  %s\n  el comando: %s" % (json.dumps(exp, sort_keys=True), json.dumps(act, sort_keys=True)), file=sys.stderr)
        sys.exit(1)
else:
    if lines(exp_raw) != lines(act_raw):
        print("  la página:\n    " + "\n    ".join(lines(exp_raw)) + "\n  el comando:\n    " + "\n    ".join(lines(act_raw)), file=sys.stderr)
        sys.exit(1)
EOF
  echo "     = salida igual a la fence $lang de la página"
}

# --- Sondas: lo que la página cuenta en prosa y el lector hace en el navegador ---

admin_login() {
  local jar=$1 code
  command curl -s -c "$jar" -b "$jar" -o /dev/null "http://127.0.0.1:$PORT/admin/login"
  # Sec-Fetch-Site: same-origin es la cabecera que el navegador manda; sin
  # ella el formulario del panel responde 419 (ver quickstart_smoke.sh).
  code=$(command curl -s -c "$jar" -b "$jar" -o "$WORK/login.out" -w '%{http_code}' \
    -X POST "http://127.0.0.1:$PORT/admin/login" -H 'Sec-Fetch-Site: same-origin' \
    --data-urlencode 'username=admin' --data-urlencode 'password=quickstart')
  case "$code" in 200|302|303) ;; *) head -c 600 "$WORK/login.out" >&2; echo >&2; fail "$PAGE: login en /admin (admin/quickstart) devolvió HTTP $code" ;; esac
}

# SaaS multi-tenant: el panel lee por el cliente base —la vista del operador,
# los dos clientes— y el feed en vivo enseña que cada SELECT de las rutas
# lleva el predicado del tenant (un Find por clave sin él se vería aquí).
sondas_tutorial-multi-tenant-saas() {
  local jar="$WORK/cookies.admin"
  admin_login "$jar"
  python3 - "$(command curl -s -b "$jar" "http://127.0.0.1:$PORT/admin/api/models")" <<'EOF' || fail "$PAGE: Data Studio no ve los proyectos de los dos tenants"
import json, sys
models = {m["name"]: m for m in json.loads(sys.argv[1])["models"]}
p = models.get("Project")
if p is None:
    print("  Data Studio no lista el modelo Project: %s" % sorted(models), file=sys.stderr); sys.exit(1)
if p.get("count") != 2:
    print("  Project tiene count=%r; la página crea un proyecto en cada tenant (2)" % p.get("count"), file=sys.stderr); sys.exit(1)
EOF
  echo "     sonda: Data Studio lista Project con los 2 proyectos (los dos tenants)"
  python3 - "$(command curl -s -b "$jar" "http://127.0.0.1:$PORT/admin/api/live/snapshot")" <<'EOF' || fail "$PAGE: el feed en vivo enseña una consulta sobre projects sin el predicado del tenant"
import json, sys
qs = [q.get("query", "") for q in json.loads(sys.argv[1]).get("queries", [])]
reads = [q for q in qs if q.lstrip().upper().startswith("SELECT") and '"projects"' in q]
if not reads:
    print("  el feed no vio ningún SELECT sobre projects (¿quarkbridge sin cablear?): %s" % qs[:5], file=sys.stderr); sys.exit(1)
loose = [q for q in reads if "tenant_id" not in q]
if loose:
    print("  SELECT sin tenant_id:\n    " + "\n    ".join(loose), file=sys.stderr); sys.exit(1)
print("     sonda: feed en vivo — %d SELECT sobre projects, todos con tenant_id" % len(reads))
EOF
  # QK-42: en el set pinado, Find(id) sobre un TenantRouter con
  # RowLevelSecurityClient lee la fila de otro tenant. La página lo avisa y
  # usa Where(...).First(); el aviso vive mientras el hallazgo esté abierto.
  if registry_open QK-42; then
    grep -qF 'Find(id)' "$PAGE_FILE" || fail "$PAGE: QK-42 sigue abierto y la página ya no avisa de que Find(id) no lleva el predicado del tenant"
    echo "     sonda: la página avisa de Find(id) mientras QK-42 siga abierto"
  else
    ! grep -qF 'Find(id)' "$PAGE_FILE" || fail "$PAGE: QK-42 está hecho y la página sigue avisando de Find(id): quitar la nota y volver a Find en show"
  fi
}

# API-only: el documento describe cada operación con su respuesta de éxito
# tipada. Un handler plano deja sólo la respuesta `default` («Not
# described»); un endpoint tipado declara además su 2xx.
sondas_tutorial-api-only() {
  python3 - "$(command curl -s "http://127.0.0.1:$PORT/openapi.json")" <<'EOF' || fail "$PAGE: el documento OpenAPI no describe todas las operaciones del tutorial"
import json, sys
doc = json.loads(sys.argv[1])
ops = [(p, m, op) for p, item in doc.get("paths", {}).items() for m, op in item.items()]
if len(ops) < 5:
    print("  %d operaciones en el documento; el tutorial registra cinco" % len(ops), file=sys.stderr); sys.exit(1)
loose = ["%s %s" % (m.upper(), p) for p, m, op in ops if not any(k.startswith("2") for k in op.get("responses", {}))]
if loose:
    print("  sin describir: " + ", ".join(loose), file=sys.stderr); sys.exit(1)
print("     sonda: /openapi.json describe las %d operaciones (petición y respuesta tipadas)" % len(ops))
EOF
}

# Monolito MVC: lo que el navegador hace con el formulario y la página no
# repite — una firma inválida vuelve a pintar el formulario (HTML, 422) con
# su mensaje, y la página es HTML servido por el motor de plantillas.
sondas_tutorial-mvc-monolith() {
  local jar="$WORK/cookies.form" token code ctype
  token=$(command curl -s -c "$jar" -b "$jar" "http://localhost:$PORT/guestbook" | sed -n 's/.*name="_csrf_token" value="\([^"]*\)".*/\1/p')
  [[ -n "$token" ]] || fail "$PAGE: GET /guestbook no trae el campo _csrf_token"
  code=$(command curl -s -c "$jar" -b "$jar" -o "$WORK/invalid.html" -w '%{http_code} %{content_type}' \
    -X POST "http://localhost:$PORT/guestbook" --data-urlencode "_csrf_token=$token" \
    --data-urlencode 'name=' --data-urlencode 'message=')
  ctype=${code#* }; code=${code%% *}
  [[ "$code" == 422 ]] || fail "$PAGE: una firma vacía devolvió HTTP $code (esperado 422)"
  [[ "$ctype" == text/html* ]] || fail "$PAGE: una firma vacía devolvió $ctype (esperado el formulario en HTML)"
  grep -q 'name="_csrf_token"' "$WORK/invalid.html" || fail "$PAGE: la respuesta a una firma vacía no vuelve a pintar el formulario"
  echo "     sonda: una firma vacía vuelve a pintar el formulario (HTML, 422)"
}

# Desde Gin + GORM (W3): lo que la página cuenta y no teclea. El borrado es
# suave —la fila sigue en la tabla, con deleted_at— y un `%` en la búsqueda
# busca un signo de porcentaje en vez de casar con todo (la diferencia con la
# versión de Gin que la página declara). La base es la del proyecto: la app
# arranca en el directorio de la página y nucleus.yml nombra sqlite://app.db.
sondas_coming-from-gin-gorm() {
  local db="$PWD/app.db"
  [[ -f "$db" ]] || fail "$PAGE: no está $db — la app no escribió en la base que nombra nucleus.yml"
  python3 - "$db" <<'EOF' || fail "$PAGE: la página dice que el bookmark borrado sigue en la tabla con deleted_at, y la base dice otra cosa"
import sqlite3, sys
row = sqlite3.connect(sys.argv[1]).execute("SELECT deleted_at FROM bookmarks WHERE id = 1").fetchone()
if row is None:
    print("  el bookmark 1 ya no está en la tabla: el DELETE lo borró de verdad", file=sys.stderr); sys.exit(1)
if row[0] is None:
    print("  el bookmark 1 sigue en la tabla sin deleted_at", file=sys.stderr); sys.exit(1)
EOF
  echo "     sonda: el bookmark borrado sigue en la tabla, con deleted_at (borrado suave)"
  python3 - "$(command curl -s "http://127.0.0.1:$PORT/api/bookmarks?q=%25")" <<'EOF' || fail "$PAGE: la página dice que ?q=% busca un signo de porcentaje, y la búsqueda casó con otra cosa"
import json, sys
doc = json.loads(sys.argv[1])
if doc.get("count") != 0:
    print("  ?q=%% devolvió %s" % json.dumps(doc), file=sys.stderr); sys.exit(1)
EOF
  echo "     sonda: ?q=% no casa con ningún título (WhereContains escapa el comodín)"
}

# Desde Django (W3): el admin que la página sólo cuenta —Data Studio lista
# los dos modelos con las filas que crearon los curl, y edita Choice inline
# con su Question, el TabularInline del original— y el hueco que declara: la
# relación no crea FOREIGN KEY. Si Quark empieza a crearla, la página miente
# en «What has no equivalent yet» y la lane lo dice.
sondas_coming-from-django() {
  local jar="$WORK/cookies.admin"
  admin_login "$jar"
  python3 - "$(command curl -s -b "$jar" "http://127.0.0.1:$PORT/admin/api/models")" \
    "$(command curl -s -b "$jar" "http://127.0.0.1:$PORT/admin/api/models/Question/schema")" <<'EOF' || fail "$PAGE: Data Studio no enseña los modelos del port como la página dice"
import json, sys
models = {m["name"]: m for m in json.loads(sys.argv[1])["models"]}
for name, want in (("Question", 2), ("Choice", 5)):
    m = models.get(name)
    if m is None:
        print("  Data Studio no lista %s: %s" % (name, sorted(models)), file=sys.stderr); sys.exit(1)
    if m.get("count") != want:
        print("  %s tiene count=%r; los curl de la página crean %d" % (name, m.get("count"), want), file=sys.stderr); sys.exit(1)
inlines = [i.get("model") for i in (json.loads(sys.argv[2]).get("inlines") or [])]
if "Choice" not in inlines:
    print("  el esquema de Question no trae Choice como inline: %r" % inlines, file=sys.stderr); sys.exit(1)
EOF
  echo "     sonda: Data Studio lista Question (2) y Choice (5) y edita Choice inline con su Question"
  python3 - "$PWD/app.db" <<'EOF' || fail "$PAGE: la página dice que la relación no crea FOREIGN KEY y la tabla choices la tiene — corrige «What has no equivalent yet»"
import sqlite3, sys
fks = sqlite3.connect(sys.argv[1]).execute("PRAGMA foreign_key_list(choices)").fetchall()
if fks:
    print("  choices tiene FOREIGN KEY: %r" % (fks,), file=sys.stderr); sys.exit(1)
EOF
  echo "     sonda: choices sin FOREIGN KEY, el hueco que la página declara"
}

# --- Un tutorial ------------------------------------------------------------

run_tutorial() {
  PAGE=$1
  local slug k n kind line value t_step slowest_ms=0 slowest="" t0 t1
  slug=$(basename "$PAGE" .md)
  [[ -f "$PAGE" ]] || fail "$PAGE no existe — la lista TUTORIAL_PAGES nombra una página que no está"
  # La página se lee después de los `cd` del propio tutorial: ruta absoluta.
  PAGE_FILE="$(cd "$(dirname "$PAGE")" && pwd -P)/$(basename "$PAGE")"
  WORK="$TMP/$slug"
  mkdir -p "$WORK/run"
  cp "$TMP/go.work.base" "$WORK/go.work"
  export GOWORK="$WORK/go.work"
  PORT=$(free_port)
  STEP_OUT="$WORK/step.out"; STEP_ERR="$WORK/step.err"; STEP_DESC=""
  APP_STARTS=0

  local steps
  steps=$(qs_steps "$PAGE_FILE")
  [[ -n "$steps" ]] || fail "$PAGE no tiene ningún paso que ejecutar (verde-vacío vetado)"
  KINDS=(); LINES=(); VALUES=()
  n=0
  while IFS=$'\t' read -r kind line value; do
    KINDS[n]=$kind; LINES[n]=$line; VALUES[n]=$value
    n=$((n + 1))
  done <<<"$steps"

  echo "== $PAGE — $n pasos (puerto $PORT)"
  t0=$(now_ms)
  cd "$WORK/run" || fail "no se pudo entrar en $WORK/run"
  for ((k = 0; k < n; k++)); do
    kind=${KINDS[k]}; line=${LINES[k]}; value=${VALUES[k]}
    t_step=$(now_ms)
    case "$kind" in
      cmd)
        STEP_DESC="$PAGE:$line \$ $value"
        echo "-- [$((k + 1))/$n] $PAGE:$line \$ $value"
        NEXT_IS_OUT=0
        [[ "${KINDS[k + 1]:-}" == out ]] && NEXT_IS_OUT=1
        run_cmd "$value" "$line"
        ;;
      file)
        STEP_DESC="$PAGE:$line (fichero $value)"
        echo "-- [$((k + 1))/$n] $PAGE:$line fichero $value"
        write_file "$value" "$line"
        ;;
      out)
        [[ $k -gt 0 && "${KINDS[k - 1]}" == cmd ]] || fail "$PAGE:$line: una fence de salida sin comando delante"
        STEP_DESC="$PAGE:$line (la salida $value de \$ ${VALUES[k - 1]})"
        check_out "$value" "$line"
        ;;
      cli)
        fail "$PAGE:$line: un tutorial no usa <GoInstallCLI />: la lane compila el CLI del pin y la instalación vive en el quickstart"
        ;;
      *) fail "$PAGE:$line: paso desconocido «$kind» (¿qs_steps cambió de formato?)" ;;
    esac
    t_step=$(( $(now_ms) - t_step ))
    if [[ $t_step -gt $slowest_ms ]]; then slowest_ms=$t_step; slowest="$PAGE:$line"; fi
  done
  STEP_DESC=""

  [[ -n "$APP_PID" ]] || fail "$PAGE: la página nunca arranca la app (\`go run .\`) — no hay tutorial que servir"
  echo "-- sondas de la lane"
  "sondas_$slug"

  # El log de cada arranque: 0 WARN en las tres gramáticas que conviven
  # (texto de nucleus, JSON de nucleus, log por defecto de Go que usa Quark).
  local warn_re='level=WARN|"level":"WARN"|^[0-9/]+ [0-9:]+ WARN ' logs n_warn tolerated n_tol=0
  logs=$(app_logs)
  tolerated=$(tolerated_warn "$PAGE")
  # shellcheck disable=SC2086
  cat $logs | grep -E "$warn_re" > "$WORK/warn.all" || true
  if [[ -n "$tolerated" ]]; then
    n_tol=$(grep -cF "$tolerated" "$WORK/warn.all" || true)
    grep -vF "$tolerated" "$WORK/warn.all" > "$WORK/warn.left" || true
  else
    cp "$WORK/warn.all" "$WORK/warn.left"
  fi
  n_warn=$(grep -c . "$WORK/warn.left" || true)
  if [[ "$n_warn" != 0 ]]; then
    cut -c1-220 "$WORK/warn.left" >&2
    fail "$PAGE: la app del tutorial arrancó y sirvió con $n_warn línea(s) WARN (esperado 0)"
  fi
  if [[ "$n_tol" != 0 ]]; then
    echo "     0 WARN en $APP_STARTS arranque(s), salvo $n_tol tolerado(s) mientras su hallazgo siga abierto: «$tolerated…»"
  else
    echo "     0 WARN en $APP_STARTS arranque(s)"
  fi

  bg_stop "$APP_PID" || fail "$PAGE: la app ($APP_PID) no murió al parar"
  APP_PID=""
  cd "$ROOT" || exit 1
  unset GOWORK

  t1=$(( $(now_ms) - t0 ))
  local total_s=$((t1 / 1000))
  summary "tutorials-smoke: $(basename "$PAGE") — $n pasos en $(secs $t1) s (el más lento: $slowest, $(secs $slowest_ms) s; presupuesto $BUDGET s, caché de módulos ${TUTORIALS_CACHE_LABEL:-según el job})"
  if [[ "$BUDGET" != 0 ]]; then
    if [[ $total_s -gt $BUDGET ]]; then
      fail "$PAGE: $total_s s > $BUDGET s (el paso más lento: $slowest, $(secs $slowest_ms) s)"
    elif [[ $total_s -ge $BUDGET_WARN ]]; then
      echo "::warning title=tutorials-smoke cerca del techo::$(basename "$PAGE"): $total_s s, franja de aviso $BUDGET_WARN-$BUDGET s"
    fi
  fi
}

# --- 0. los autotests de lo que la lane usa ---------------------------------
echo "== 0. autotest del parser de fences compartido con el quickstart"
bash tests/quickstart-fences/selftest.sh > "$TMP/selftest.out" 2>&1 || { cat "$TMP/selftest.out" >&2; fail "el parser compartido no pasa su autotest — la lane no puede fiarse de los pasos que lee"; }
tail -1 "$TMP/selftest.out"
echo "== 0b. autotest del arranque en segundo plano"
bash tests/background-app/selftest.sh > "$TMP/bg.out" 2>&1 || { cat "$TMP/bg.out" >&2; fail "background-app.sh no pasa su autotest — la lane dejaría la app huérfana escuchando al salir"; }
tail -1 "$TMP/bg.out"

# --- 1. herramientas ---------------------------------------------------------
echo "== 1. herramientas: node para el cliente TypeScript, curl con --fail-with-body"
node_v=$(node --version 2>/dev/null || true)
python3 - "$node_v" <<'EOF' || fail "la lane necesita node ≥ 22.18 en el PATH (encontrado: «${node_v:-ninguno}»): el tutorial API-only ejecuta un .ts sin paso de build"
import re, sys
m = re.match(r"v(\d+)\.(\d+)", sys.argv[1])
sys.exit(0 if m and (int(m.group(1)), int(m.group(2))) >= (22, 18) else 1)
EOF
command curl --help all 2>/dev/null | grep -q -- '--fail-with-body' || fail "la lane necesita curl ≥ 7.76 (--fail-with-body)"
echo "   node $node_v · $(command curl --version | head -1 | cut -d' ' -f1-2)"

# --- 2. CLI del submódulo pinado y go.work de base ---------------------------
echo "== 2. CLI de nucleus desde el submódulo pinado, y la copia del go.work"
NUCLEUS_BIN="$TMP/bin/nucleus"
command go build -o "$NUCLEUS_BIN" ./nucleus/cmd/nucleus || fail "nucleus/cmd/nucleus no compila al pin"
sed -e "s#^\([[:space:]]*\)\./#\1$ROOT/#" "$ROOT/go.work" > "$TMP/go.work.base"
echo "   nucleus al pin $(git -C nucleus log -1 --format='%h' 2>/dev/null || echo '?')"

# --- 3. los tutoriales --------------------------------------------------------
T_ALL=$(now_ms)
for p in "${TUTORIAL_PAGES[@]}"; do
  run_tutorial "$p"
done
summary "tutorials-smoke: ${#TUTORIAL_PAGES[@]} páginas (tutoriales y guías de migración) en $(secs $(( $(now_ms) - T_ALL ))) s"
echo "tutorials_smoke: OK — cada paso de ${#TUTORIAL_PAGES[@]} página(s) ejecutado al set pinado, sus salidas iguales a las de la página, sus sondas en verde y 0 WARN"
