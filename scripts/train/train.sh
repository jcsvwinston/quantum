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
#   paraguas             re-pin mecánico (bump-set.sh: submódulos, pines,
#                        versión de suite por QADR-0002, notes anteriores al
#                        CHANGELOG y esqueleto de las nuevas) + manifest-guard,
#                        y parada manual: redactar las notes, PR de re-pin.
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
  if [ "$repo" != "orbit" ]; then
    # QM-19: los suelos módulo→raíz. Informativo: manifest-guard §5b avisa,
    # no falla, y subirlos es un fix(deps) que corta un patch por módulo —
    # va en la rama del trabajo real del corte, no en un corte propio.
    say "PASO: suelos de los módulos hermanos hacia la raíz (QM-19; informativo)"
    if run bash scripts/train/align-module-floors.sh "$repo" --check; then
      say "  → suelos al día"
    else
      say "  AVISO: suelos por detrás del set certificado. Para subirlos EN este corte:"
      say "    bash scripts/train/align-module-floors.sh $repo   # fix(deps) en la rama del trabajo, antes del release PR"
    fi
  fi

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

  # Clasificación por título — GENÉRICA, sin lista de módulos (QM-8: la lista
  # fija conocía seis módulos y el tren de D3 trajo diecisiete; un «release
  # drivers/postgres 0.1.0» quedaba sin clasificar y el driver moría):
  #   «chore(main): release 1.10.0»                                → root
  #   «chore(main): release github.com/jcsvwinston/orbit 1.8.13»  → root
  #     (el componente del ROOT multi-módulo es la ruta completa del módulo)
  #   «chore(main): release drivers/postgres 0.1.0»               → módulo
  #   «chore(main): release github.com/jcsvwinston/nucleus/providers/ldap 0.2.4» → módulo
  #   «chore: release main»                                        → PR ÚNICO
  #     (separate-pull-requests: false — nucleus y orbit desde D3): todos los
  #     módulos y el root salen del mismo commit; se trata como root.
  # Orden: módulos primero, hojas → dependientes según los `require` entre
  # hermanos del go.mod de cada uno (leído del submódulo al pin; un módulo
  # nuevo sin go.mod local cuenta como hoja), ROOT EL ÚLTIMO — su tag debe
  # contener los tags de módulo como ancestros (manifest-guard §3/§3b).
  local mods="" roots="" line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    local n=${line%%	*} t=${line#*	} comp ver
    if printf '%s\n' "$t" | grep -qE '^chore(\([^)]*\))?: release main$'; then
      roots="$roots $n:"
      continue
    fi
    comp=$(printf '%s\n' "$t" | sed -nE 's/^chore(\([^)]*\))?: release ([^ ]+ )?([0-9]+\.[0-9]+\.[0-9]+)$/\2/p' | sed 's/ $//')
    ver=$(printf '%s\n' "$t" | sed -nE 's/^chore(\([^)]*\))?: release ([^ ]+ )?([0-9]+\.[0-9]+\.[0-9]+)$/\3/p')
    [ -n "$ver" ] || continue   # no es un título de release-please: sin clasificar
    case "$comp" in
      "github.com/jcsvwinston/$repo") comp="" ;;
      "github.com/jcsvwinston/$repo"/*) comp="${comp#github.com/jcsvwinston/$repo/}" ;;
    esac
    if [ -z "$comp" ]; then roots="$roots $n:"; else mods="$mods $n:$comp"; fi
  done <<EOF
$listing
EOF

  # Topológico simple (bash 3.2, sin arrays asociativos): en cada pasada entra
  # todo módulo cuyas dependencias hermanas (las que también tienen PR abierto)
  # ya están colocadas. Una pasada sin avance = ciclo → en seco.
  local ordered="" pending="$mods" item n comp deps dep ok progressed
  while [ -n "$(printf '%s' "$pending" | tr -d ' ')" ]; do
    progressed=0
    local rest=""
    for item in $pending; do
      n=${item%%:*}; comp=${item#*:}
      deps=""
      if [ -f "$repo/$comp/go.mod" ]; then
        deps=$(awk -v p="github.com/jcsvwinston/$repo/" 'index($1, p) == 1 && $NF != "indirect" { sub(p, "", $1); print $1 }' "$repo/$comp/go.mod")
      fi
      ok=1
      for dep in $deps; do
        # Solo bloquea una dependencia que TAMBIÉN se está cortando ahora.
        case " $pending " in *":$dep "*) ok=0 ;; esac
      done
      if [ "$ok" -eq 1 ]; then
        ordered="$ordered $n:$repo:mod:$comp"
        progressed=1
      else
        rest="$rest $item"
      fi
    done
    pending="$rest"
    [ "$progressed" -eq 1 ] || die "ciclo de dependencias entre los módulos con release PR en $repo:$pending"
  done
  for item in $roots; do
    ordered="$ordered ${item%%:*}:$repo:root"
  done
  if [ -n "$(printf '%s' "$roots" | tr -d ' ')" ] && [ "$(printf '%s\n' $roots | grep -c .)" -gt 1 ]; then
    die "más de un release PR de ROOT abierto en $repo ($roots) — cierra el zombi antes de seguir"
  fi

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

  if [ -n "$ordered" ]; then
    say "  Orden de fusión (hojas → dependientes → root):"
    for item in $ordered; do say "    #$(printf '%s' "$item" | awk -F: '{printf "%s %s%s", $1, $3, ($4 != "" ? " " $4 : "")}')"; done
  fi

  for item in $ordered; do
    local n=${item%%:*} kind
    kind=$(printf '%s' "$item" | cut -d: -f3)
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
  say "PASO: re-pin mecánico del set (bump-set.sh: submódulos al tag, versions.yaml/README, versión"
  say "      de suite por QADR-0002, notes anteriores al CHANGELOG y esqueleto de las nuevas)"
  run bash scripts/bump-set.sh || die "bump-set.sh falló"
  say "PASO: manifest-guard sobre lo que bump-set escribió (tolera el marcador REDACTAR del esqueleto; el CI no)"
  run env QUANTUM_ALLOW_NOTES_SKELETON=1 bash scripts/manifest-guard.sh || die "manifest-guard rechaza el re-pin"
  manual \
    "1. Redacta las notes de versions.yaml: bump-set dejó versión de suite, released, status y los" \
    "   movimientos del set; sustituye cada REDACTAR (manifest-guard §0 lo rechaza) y revisa el título" \
    "   que puso a la entrada anterior en CHANGELOG.md (DX-25). Si el número de suite no es el que" \
    "   toca (corte deliberado): bash scripts/bump-set.sh --set X.Y.Z (solo cambia el número)." \
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
  # dispatch-app-bump.sh ESPERA el run de quantum-app y exige que termine en
  # PR (QM-2: el dispatch de 1.26.0 se aceptó, el run falló con «GitHub Actions
  # is not permitted to create or approve pull requests» y nadie lo vio). El
  # ajuste «Allow GitHub Actions to create and approve pull requests» de
  # quantum-app es un REQUISITO del tren — scripts/train/README.md.
  run bash scripts/train/dispatch-app-bump.sh $DRYFLAG \
    || die "el anuncio a quantum-app NO terminó en PR (ver arriba: run rojo, permiso del repo o dispatch sin run). El set SIGUE certificado (esto es el paso de después); arregla la causa y relanza solo esta pieza:
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
