#!/usr/bin/env bash
# train.sh — el DRIVER del tren de releases de la suite (RT-1).
#
# Cortar un set eran ~12 fases manuales y 15-25 PRs conducidos a mano, con el
# procedimiento viviendo en prosa (docs/AUDITORIA_CONTINUA.md §3 + memoria de
# sesiones). Este driver ejecuta la parte MECÁNICA de ese procedimiento, en el
# orden de dependencias, y con tres reglas fijas:
#
#   1. Imprime SIEMPRE qué va a hacer antes de hacerlo.
#   2. Para EN SECO al primer rojo (un check rojo, un guard rojo, un estado
#      inesperado): no hay «seguir a ver si cuela».
#   3. Donde el procedimiento exige juicio o escritura humana (notas de
#      release, versión de suite, decidir si un lag se alinea), NO lo imita:
#      imprime la instrucción exacta y se detiene con EXIT=2 («paso manual
#      pendiente»). Se retoma con --desde <fase>.
#
# Fases (en orden): preflight → quark → nucleus → orbit → paraguas → cierre.
#   quark/nucleus/orbit  fusionan los release PRs del bot del repo, módulos
#                        antes que root, con el check de rama anclada antes
#                        del root (las trampas: commits vacíos para disparar
#                        CI, BEHIND, cascada DIRTY, rama anclada, tag que no
#                        llega — ver merge-bot-pr.sh y
#                        check-anchored-release-branch.sh).
#   paraguas             re-pin mecánico (bump-set.sh) + manifest-guard, y
#                        parada manual: versión de suite, notes, CHANGELOG,
#                        PR de re-pin.
#   cierre               tras fusionar el PR de re-pin: tag de suite EN HEAD,
#                        suite-integral --cierre (MAQ-1/MAQ-2) y el anuncio
#                        del set al consumidor externo quantum-app (D6/RT-5).
#
# Uso: train.sh [--dry-run] [--desde <fase>] [--hasta <fase>]
#   --dry-run   imprime todos los pasos sin ejecutar nada con efectos.
#   --desde     retoma el tren en esa fase (default: preflight).
#   --hasta     última fase a ejecutar (default: paraguas; «cierre» solo corre
#               pedido explícitamente — exige el PR de re-pin ya fusionado).
#
# Deudas de doc por minor (RT-9): el driver NO las salda (son escritura), pero
# las imprime antes de cada repo y el CI del release PR las exige — un release
# PR sin ellas es un rojo que para el tren, no una sorpresa dos vueltas de CI
# después. Saldarlas EN la rama del release PR (el push humano además dispara
# el CI del bot).
set -euo pipefail
cd "$(dirname "$0")/../.."

PHASES="preflight quark nucleus orbit paraguas cierre"
DRY=0
FROM="preflight"
TO="paraguas"
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --desde) shift; FROM="${1:-}" ;;
    --hasta) shift; TO="${1:-}" ;;
    -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "argumento desconocido: $1 (ver --help)" >&2; exit 64 ;;
  esac
  shift
done
case " $PHASES " in *" $FROM "*) : ;; *) echo "fase desconocida: $FROM" >&2; exit 64 ;; esac
case " $PHASES " in *" $TO "*) : ;; *) echo "fase desconocida: $TO" >&2; exit 64 ;; esac

say() { printf '%s\n' "$*"; }
run() {
  say "  → $*"
  if [ "$DRY" -eq 1 ]; then return 0; fi
  "$@"
}
die() { say ""; say "PARADA EN SECO: $*" >&2; exit 1; }
manual() {
  say ""
  say "== PASO MANUAL PENDIENTE =="
  while [ $# -gt 0 ]; do say "  $1"; shift; done
  say "Cuando esté hecho: bash scripts/train/train.sh --desde <fase-siguiente>"
  exit 2
}
banner() { say ""; say "==== FASE: $1 ===="; }

MERGE_BOT="bash scripts/train/merge-bot-pr.sh"
CHECK_ANCHORED="bash scripts/train/check-anchored-release-branch.sh"
DRYFLAG=""
[ "$DRY" -eq 1 ] && DRYFLAG="--dry-run"

# imprime_deudas <repo> — el recordatorio RT-9, antes de tocar el repo.
imprime_deudas() {
  case "$1" in
    quark)
      say "  DEUDAS DE DOC de un minor de quark (check-version-coherence las exige):"
      say "    - sección ## vX.Y.0 en las release notes del sitio + docs/RELEASE_NOTES_vX.Y.0.md"
      say "    - menciones de la versión en README/SECURITY/CLAUDE.md (CLAUDE.md NO está en extra-files)"
      ;;
    nucleus)
      say "  DEUDAS DE DOC de un minor de nucleus (check_version_claims + check_docs_archive_freshness):"
      say "    - sección ## vX.Y.Z en website/docs/reference/release-notes.md"
      say "    - snapshot de docs versionadas (scripts/release/cut_docs_snapshot.sh) EN la rama del release"
      ;;
    orbit)
      say "  DEUDAS DE DOC de un minor del root de orbit:"
      say "    - sección ## vX.Y.Z en sus release notes"
      ;;
  esac
  say "  Saldarlas EN la rama del release PR: ahorra 2 vueltas de CI por repo (RT-9)."
}

# fase_repo <repo> — fusiona los release PRs del bot en orden módulos→root.
fase_repo() {
  local repo=$1
  banner "$repo"
  imprime_deudas "$repo"

  say "  → gh pr list -R jcsvwinston/$repo --label 'autorelease: pending'"
  local listing
  listing=$(gh pr list -R "jcsvwinston/$repo" --label "autorelease: pending" \
    --json number,title --jq '.[] | "\(.number)\t\(.title)"')
  if [ -z "$listing" ]; then
    say "  Sin release PRs abiertos en $repo. Si esperabas uno:"
    say "    gh workflow run 'Release Please' -R jcsvwinston/$repo"
    say "  (y ojo al auto-bloqueo: un PR ya merged con 'autorelease: pending' sin tag lo atasca)"
    return 0
  fi
  say "  Release PRs abiertos:"
  printf '%s\n' "$listing" | sed 's/^/    #/'

  # Orden: módulos primero (hoja → dependientes), ROOT EL ÚLTIMO — su tag debe
  # contener los tags de módulo como ancestros (manifest-guard §3/§3b).
  local ordered=""
  local pat
  for pat in 'proto ' 'agent ' 'server ' 'quarkbridge ' 'quarkdatasource ' 'providers/ldap ' ''; do
    local line
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      local n=${line%%	*} t=${line#*	}
      if [ -n "$pat" ]; then
        # componente corto («release agent 0.6.8») o con ruta de módulo
        # («release github.com/jcsvwinston/orbit/agent 0.6.8»)
        case "$t" in
          *": release $pat"*|*"/$pat"*) ordered="$ordered $n:$repo:mod" ;;
        esac
      else
        # root: título sin subdirectorio de módulo
        if printf '%s\n' "$t" | grep -qE "^chore\([^)]*\): release (github\.com/jcsvwinston/$repo )?[0-9]+\.[0-9]+\.[0-9]+$"; then
          ordered="$ordered $n:$repo:root"
        fi
      fi
    done <<EOF
$listing
EOF
  done

  # Un PR listado que el clasificador no reconoce NO se salta en silencio:
  # el driver para y lo deja en manos humanas (regla 2: en seco, no «a ver
  # si cuela»).
  local total_listed total_ordered
  total_listed=$(printf '%s\n' "$listing" | grep -c .)
  total_ordered=$(printf '%s\n' $ordered | grep -c . || true)
  if [ "$total_listed" -ne "$total_ordered" ]; then
    say "  Clasificados: $total_ordered de $total_listed PRs."
    die "hay release PRs con título que no reconozco en $repo — fusiónalos a mano (merge-bot-pr.sh $repo <n>) o corrige el clasificador"
  fi

  local item
  for item in $ordered; do
    local n=${item%%:*} kind=${item##*:}
    if [ "$kind" = "root" ]; then
      say "PASO: el siguiente es el ROOT — verificar que su rama no quedó anclada al main viejo"
      run $CHECK_ANCHORED "$repo" "$n" \
        || die "rama del root anclada en $repo#$n — aplica la receta impresa arriba y relanza esta fase"
    fi
    say "PASO: fusionar $repo#$n (merge-bot-pr.sh: commit vacío → checks → merge → tag)"
    run $MERGE_BOT "$repo" "$n" $DRYFLAG \
      || die "merge-bot-pr.sh falló en $repo#$n"
    # La cascada DIRTY del manifest compartido: tras cada merge, los PRs
    # restantes pueden quedar en conflicto; merge-bot-pr.sh la detecta y para.
  done
  say "OK: fase $repo completa."
}

fase_preflight() {
  banner "preflight"
  say "PASO: gh autenticado"
  run gh auth status || die "gh sin autenticar"
  say "PASO: árbol del paraguas limpio (QM8-5 — la certificación lo exigirá)"
  if [ "$DRY" -eq 0 ] && [ -n "$(git status --porcelain)" ]; then
    say "  AVISO: árbol sucio. Las fases de repo no lo necesitan limpio, pero"
    say "  la fase paraguas/cierre sí: commitea o guarda antes de llegar ahí."
  else
    say "  → git status --porcelain (limpio)"
  fi
  say "PASO: declared_lags del manifiesto"
  if grep -q '^declared_lags: {}' versions.yaml; then
    say "  → declared_lags vacío (el estado que exige certificar)"
  else
    say "  AVISO: declared_lags NO está vacío — el tren debe alinearlos y vaciarlo."
  fi
  say "RECORDATORIO del orden del tren (docs/AUDITORIA_CONTINUA.md §3 + 1.24.0):"
  say "  quark → nucleus (ldap antes que root) → orbit (módulos → root EL ÚLTIMO,"
  say "  re-pinando TODOS sus módulos Y el root en el mismo tren) → re-pin del paraguas."
}

fase_paraguas() {
  banner "paraguas"
  if [ ! -f nucleus/go.mod ] || [ ! -f quark/go.mod ] || [ ! -f orbit/go.mod ]; then
    die "submódulos sin inicializar (git submodule update --init --recursive)"
  fi
  say "PASO: re-pin mecánico del set (bump-set.sh mueve submódulos y reescribe versions.yaml/README)"
  run bash scripts/bump-set.sh || die "bump-set.sh falló"
  say "PASO: manifest-guard sobre lo que bump-set escribió"
  run bash scripts/manifest-guard.sh || die "manifest-guard rechaza el re-pin"
  manual \
    "1. Sube la versión de SUITE en versions.yaml (QADR-0002: minor de pilar → minor de suite)," \
    "   actualiza released/status, redacta notes y mueve las notes anteriores al CHANGELOG (DX-25)." \
    "2. Si el workflow llevaba QUANTUM_ALLOW_DECLARED_LAGS, quítalo: el PR de re-pin sale verde SIN escapes." \
    "3. Abre el PR de re-pin; su lane suite-integral corre en modo normal (tolera el mid-tren sin tag)." \
    "4. Fusiona el PR (quantum usa MERGE COMMIT; puedes usar merge-bot-pr.sh quantum <n> si es del bot)." \
    "5. Después: bash scripts/train/train.sh --desde cierre --hasta cierre"
}

fase_cierre() {
  banner "cierre"
  say "PASO: main al día y árbol limpio (el tag se corta EN HEAD)"
  run git checkout main
  run git pull --ff-only
  if [ "$DRY" -eq 0 ] && [ -n "$(git status --porcelain)" ]; then
    die "árbol sucio — el tag debe capturar un HEAD limpio"
  fi
  local ver
  ver=$(sed -nE 's/^quantum:[[:space:]]+"([^"]+)".*/\1/p' versions.yaml | head -1)
  [ -n "$ver" ] || die "no pude leer la versión de suite de versions.yaml"
  if git rev-parse -q --verify "refs/tags/v$ver" >/dev/null; then
    say "  El tag v$ver ya existe — voy directo a la certificación."
  else
    say "PASO: cortar el tag de suite v$ver EN HEAD (tras el ÚLTIMO PR de la ronda, nunca antes)"
    run git tag -a "v$ver" -m "Quantum $ver"
    run git push origin "v$ver"
  fi
  say "PASO: certificación en modo CIERRE (tag existe + captura HEAD + sin escapes; MAQ-1/MAQ-2)"
  run bash scripts/suite-integral.sh --cierre || die "suite-integral --cierre en rojo — el set NO queda certificado"
  say "PASO: anunciar el set al consumidor EXTERNO de referencia (D6/RT-5)"
  say "  quantum-app se re-pina en cada corte: el dispatch le pasa este set y el"
  say "  bloque require de print-requires.sh; allí un workflow reescribe el pin,"
  say "  corre SUS gates y abre un PR (no fusiona). Va DESPUÉS de certificar: el"
  say "  consumidor externo sigue al set certificado, nunca al mid-tren."
  run bash scripts/train/dispatch-app-bump.sh $DRYFLAG \
    || die "el anuncio a quantum-app falló. El set SIGUE certificado (esto es el paso de después); relanza solo esta pieza:
    bash scripts/train/dispatch-app-bump.sh"
  say ""
  say "OK: set v$ver certificado. Queda lo humano: CIERRE de ronda con la plantilla"
  say "de docs/AUDITORIA_CONTINUA.md §6 (conteos COPIADOS de las tablas de las lanes),"
  say "y actualizar docs/RUMBO.md (regla de mantenimiento del arco)."
}

started=0
for ph in $PHASES; do
  [ "$ph" = "$FROM" ] && started=1
  [ "$started" -eq 1 ] || continue
  case "$ph" in
    preflight) fase_preflight ;;
    quark|nucleus|orbit) fase_repo "$ph" ;;
    paraguas) fase_paraguas ;;
    cierre)
      # «cierre» nunca arranca por arrastre: exige pedirse explícitamente
      # (--desde/--hasta cierre) porque presupone el PR de re-pin fusionado.
      if [ "$FROM" = "cierre" ] || [ "$TO" = "cierre" ]; then fase_cierre; fi
      ;;
  esac
  [ "$ph" = "$TO" ] && break
done
say ""
if [ "$DRY" -eq 1 ]; then
  say "Tren (DRY-RUN): fases $FROM..$TO recorridas — NADA se ha ejecutado con efectos."
else
  say "Tren: fases $FROM..$TO terminadas."
fi
