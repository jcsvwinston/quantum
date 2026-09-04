#!/usr/bin/env bash
# dispatch-app-bump.sh — última pieza mecánica del tren: avisa al consumidor
# EXTERNO de referencia (quantum-app) de que hay set certificado, y le pasa el
# bloque require que scripts/print-requires.sh deriva de versions.yaml.
#
# Por qué (RT-5 / decisión D6 de la auditoría, QADR-0008): quantum-app se
# describe como «reference application consuming the Quantum suite as a real
# external integrator», pero mientras su bump fue manual se quedó pinado al
# set 1.10.0 con el set vigente en 1.24.0. Catorce sets sin que ningún
# consumidor externo compilara contra ellos: la validación externa del set
# certificado no existía. Este script la vuelve mecánica.
#
# Qué NO hace: no reescribe nada en quantum-app ni fusiona nada. Manda un
# repository_dispatch; el workflow de allí (.github/workflows/set-bump.yml)
# reescribe el pin, corre SUS gates y abre un PR que un humano revisa. Los
# rojos de ese PR son deuda de quantum-app contra el set, no de este script.
#
# Qué SÍ hace desde la auditoría 2026-09-03 (QM-2): ESPERA el run que el
# dispatch provoca y exige que termine en PR. El anuncio de 1.26.0 se aceptó
# (HTTP 204), el run falló con «GitHub Actions is not permitted to create or
# approve pull requests», la rama chore/set-1.26.0 quedó sin PR y el tren dio
# el cierre por bueno: fire-and-forget convertía un permiso del repo en un
# consumidor de referencia silenciosamente sin set. REQUISITO del tren, lo
# activa Carlos en quantum-app: Settings → Actions → General → Workflow
# permissions → «Allow GitHub Actions to create and approve pull requests»
# (o el secreto QUANTUM_APP_PR_TOKEN, que además hace que el PR lleve CI).
#
# Como el resto de scripts/train/, es un ESCRITOR/CONDUCTOR, no un guard: no
# está en el registro de guards ni en el escaneo anti-fósil.
#
# Uso: dispatch-app-bump.sh [--dry-run] [--repo owner/nombre] [--sin-tag] [--sin-esperar]
#   --dry-run      imprime la llamada exacta sin mandarla.
#   --repo         repositorio destino (por defecto jcsvwinston/quantum-app).
#   --sin-tag      no exigir que el tag de suite exista ya en origin (para
#                  ensayar un set antes de cortarlo; el tren normal NO lo usa).
#   --sin-esperar  manda el dispatch y termina sin esperar el run (fire-and-
#                  forget, el comportamiento anterior; el tren normal NO lo usa).
#   ESPERA_MAX     segundos máximos de espera del run (env; 1800 por defecto).
set -euo pipefail
cd "$(dirname "$0")/../.."

DRY=0
REPO="jcsvwinston/quantum-app"
EXIGE_TAG=1
ESPERA=1
ESPERA_MAX="${ESPERA_MAX:-1800}"
WORKFLOW="set-bump.yml"
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --repo) shift; REPO="${1:-}" ;;
    --sin-tag) EXIGE_TAG=0 ;;
    --sin-esperar) ESPERA=0 ;;
    -h|--help) sed -n '2,42p' "$0"; exit 0 ;;
    *) echo "dispatch-app-bump.sh: argumento desconocido: $1 (ver --help)" >&2; exit 64 ;;
  esac
  shift
done

die() { echo "dispatch-app-bump.sh: $*" >&2; exit 1; }

# ---- 1. el set que vamos a anunciar ----------------------------------------
VER=$(sed -nE 's/^quantum:[[:space:]]+"([^"]+)".*/\1/p' versions.yaml | head -1)
[ -n "$VER" ] || die "no pude leer la versión de suite de versions.yaml"
ESTADO=$(sed -nE 's/^status:[[:space:]]+([a-z-]+).*/\1/p' versions.yaml | head -1)
[ "$ESTADO" = "certified" ] \
  || die "versions.yaml declara status: '${ESTADO:-?}' — solo se anuncia un set CERTIFICADO (el bump del consumidor externo sigue al set, no al mid-tren)"

if [ "$EXIGE_TAG" -eq 1 ]; then
  git fetch --tags --quiet origin || true
  git rev-parse -q --verify "refs/tags/v$VER" >/dev/null \
    || die "no existe el tag de suite v$VER — el anuncio va DESPUÉS del tag (fase cierre). Con --sin-tag se puede ensayar."
fi

REQUIRES=$(bash scripts/print-requires.sh) || die "print-requires.sh falló — sin bloque require no hay nada que anunciar"

echo "== anuncio del set certificado Quantum $VER a $REPO =="
printf '%s\n' "$REQUIRES" | sed 's/^/  /'
echo
# El cuerpo se construye AQUÍ, no con la notación de corchetes de `gh -f`:
# así el JSON exacto que se manda es visible en --dry-run y verificable, en
# vez de depender de cómo serialice una versión concreta de gh un valor
# multilínea. json_str escapa lo único que puede aparecer (barras, comillas,
# tabuladores y saltos): el bloque require lleva tabuladores por construcción.
# El tabulador va como carácter LITERAL en el patrón: `\t` dentro de un
# script sed no es portable (el sed de macOS no lo interpreta y los
# tabuladores del bloque require se colaban crudos, dejando el JSON inválido).
TAB=$(printf '\t')
json_str() {
  printf '%s' "$1" \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e "s/$TAB/\\\\t/g" \
    | awk 'NR > 1 { printf "%s", "\\n" } { printf "%s", $0 }'
}
BODY="{\"event_type\":\"quantum-set-certified\",\"client_payload\":{\"set\":\"$(json_str "$VER")\",\"requires\":\"$(json_str "$REQUIRES")\"}}"

echo "  → gh api repos/$REPO/dispatches --method POST --input - <<<"
printf '      %s\n' "$BODY"

if [ "$DRY" -eq 1 ]; then
  echo
  echo "DRY-RUN: no se ha mandado nada."
  exit 0
fi

# ---- 2. el dispatch --------------------------------------------------------
SINCE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '%s' "$BODY" | gh api "repos/$REPO/dispatches" --method POST --input - \
  || die "el dispatch a $REPO falló. Relánzalo cuando esté resuelto:
    bash scripts/train/dispatch-app-bump.sh
  o dispara el bump a mano desde la pestaña Actions de $REPO
  (workflow «Bump al set certificado», con set=$VER y el bloque require de
  scripts/print-requires.sh)."

echo "OK: anunciado. El workflow de $REPO reescribe el pin, corre sus gates y"
echo "abre el PR del bump — que NO se fusiona solo:"
echo "  gh run list -R $REPO --workflow '$WORKFLOW' --limit 3"
echo "  gh pr list -R $REPO --head chore/set-$VER"

if [ "$ESPERA" -eq 0 ]; then
  echo "AVISO(--sin-esperar): no se espera el run; comprueba tú que termina en PR."
  exit 0
fi

# ---- 3. esperar el run y EXIGIR el PR -------------------------------------
# El dispatch se acepta con 204 aunque el workflow vaya a fallar; el único
# veredicto real es «hay PR en chore/set-$VER». Se localiza el run creado
# después del dispatch, se espera (gh run watch), y se decide por el PR:
#   - PR abierto                 → OK (si el run salió rojo, el PR está en
#                                  borrador con gates en rojo: deuda de
#                                  quantum-app contra el set, no del tren).
#   - run verde y sin PR         → bump idempotente (el árbol ya estaba en el
#                                  set); OK con aviso.
#   - run rojo y sin PR          → FAIL: el bump no llegó a PR. Causa típica:
#                                  el permiso del repo (ver cabecera).
#   - sin run en 90 s            → FAIL: el dispatch no despertó al workflow.
echo
echo "PASO: esperar el run de $WORKFLOW en $REPO (creado tras $SINCE; máx. ${ESPERA_MAX}s)"
run_id=""
for _ in $(seq 1 18); do
  run_id=$(gh run list -R "$REPO" --workflow "$WORKFLOW" --event repository_dispatch --limit 5 \
    --json databaseId,createdAt --jq "map(select(.createdAt >= \"$SINCE\")) | sort_by(.createdAt) | last | .databaseId // empty" 2>/dev/null || true)
  [ -n "$run_id" ] && break
  sleep 5
done
[ -n "$run_id" ] || die "el dispatch se aceptó pero ningún run de $WORKFLOW apareció en $REPO en 90 s — ¿workflow renombrado, event_type distinto de quantum-set-certified, o Actions deshabilitado en el repo? Mira: gh run list -R $REPO --limit 5"
echo "  run: https://github.com/$REPO/actions/runs/$run_id"

# gh run watch sale !=0 si el run termina en rojo; el veredicto se toma por el
# PR, así que aquí solo se captura el resultado.
run_ok=1
timeout_cmd=""
if command -v timeout >/dev/null 2>&1; then timeout_cmd="timeout $ESPERA_MAX"; fi
$timeout_cmd gh run watch "$run_id" -R "$REPO" --exit-status --interval 15 >/dev/null 2>&1 || run_ok=0
conclusion=$(gh run view "$run_id" -R "$REPO" --json conclusion,status --jq '.conclusion // .status' 2>/dev/null || echo "desconocida")
echo "  run $run_id: $conclusion"

pr_url=$(gh pr list -R "$REPO" --head "chore/set-$VER" --state open --json url --jq '.[0].url // empty' 2>/dev/null || true)
if [ -n "$pr_url" ]; then
  if [ "$run_ok" -eq 1 ]; then
    echo "OK: PR del bump abierto y gates en verde: $pr_url"
  else
    echo "AVISO: PR del bump abierto EN BORRADOR con gates en rojo (deuda de $REPO contra el set $VER, no del tren): $pr_url"
    echo "  gh run view $run_id -R $REPO --log-failed"
  fi
  exit 0
fi

if [ "$run_ok" -eq 1 ]; then
  echo "AVISO: run verde y sin PR — $REPO ya estaba en el set $VER (bump idempotente). Nada que revisar."
  exit 0
fi

die "el run $run_id de $REPO terminó en '$conclusion' y NO abrió el PR chore/set-$VER — el consumidor de referencia se ha quedado sin el set $VER.
  Causa típica: «GitHub Actions is not permitted to create or approve pull requests».
  REQUISITO del tren (lo activa Carlos, una vez): en $REPO, Settings → Actions →
  General → Workflow permissions → marcar «Allow GitHub Actions to create and
  approve pull requests» — o definir el secreto QUANTUM_APP_PR_TOKEN.
  Otras causas: go mod tidy en rojo (el set no resuelve: tags sin publicar).
  Log:    gh run view $run_id -R $REPO --log-failed
  Relanza: bash scripts/train/dispatch-app-bump.sh"
