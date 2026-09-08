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
#                        CHANGELOG y esqueleto de las nuevas) + manifest-guard.
#                        Si quedan marcadores REDACTAR, PARA (regla 3: la
#                        prosa no se delega); si no quedan, no queda juicio
#                        humano que ejercer y el driver abre el PR de re-pin
#                        y lo FUSIONA con merge-group.sh sin preguntar.
#   cierre               tras fusionar el PR de re-pin: tag de suite EN HEAD,
#                        suite-integral --cierre (MAQ-1/MAQ-2) y el anuncio
#                        del set al consumidor externo quantum-app (D6/RT-5).
#
# Uso: train.sh [--dry-run] [--desde <fase>] [--hasta <fase>]
#   --dry-run   imprime todos los pasos sin ejecutar nada con efectos.
#   --desde     retoma el tren en esa fase (default: preflight).
#   --hasta     última fase a ejecutar (default: paraguas; «cierre» solo corre
#               pedido explícitamente — exige el PR de re-pin ya fusionado).
#   --solo-suelos  en las fases de repo, sube los suelos (QM-19) y para: no
#               fusiona release PRs. Es el primer commit de un corte que aún
#               no se va a cerrar (arranque de un arco).
#   --reloj     imprime el reloj del tren en vuelo (desglose por fase, total
#               conducido y espera del propietario) y sale. Sin efectos.
#   --reloj-cero  archiva el reloj en vuelo y sale: el tren siguiente empieza
#               de cero. No lo hace nadie por su cuenta.
#
# «--desde paraguas --hasta cierre» encadena el re-pin y el cierre en una sola
# invocación: desde que la fase paraguas fusiona su PR, entre las dos no queda
# ninguna decisión humana.
#
# Deudas de doc por minor (RT-9): el driver NO las salda (son escritura), pero
# las imprime antes de cada repo y el CI del release PR las exige — un release
# PR sin ellas es un rojo que para el tren, no una sorpresa dos vueltas de CI
# después. Saldarlas EN la rama del release PR (el push humano además dispara
# el CI del bot).
#
# EL RELOJ DEL TREN (A3). Nadie medía cuánto cuesta cortar un set, así que
# «el tren tarda demasiado» era una impresión y no un número. El driver se
# cronometra por fase. Como el tren se lanza varias veces (--desde quark,
# --desde nucleus…), un cronómetro dentro de una invocación no mediría nada:
# las marcas se acumulan en un fichero de ESTADO que sobrevive entre
# invocaciones.
#
#   Dónde     <git-common-dir>/quantum-train/reloj.tsv — dentro de .git, así
#             que ni ensucia el árbol ni lo ve el guard de árbol limpio de la
#             certificación (QM8-5). QUANTUM_TREN_RELOJ=<fichero> lo mueve.
#   Formato   TSV sin cabecera, una línea por fase EJECUTADA, seis columnas:
#               corrida   epoch en que arrancó la invocación (agrupa las
#                         fases de una misma llamada y las cuenta).
#               fase      preflight|quark|nucleus|orbit|paraguas|cierre.
#               inicio    epoch UNIX de entrada en la fase.
#               fin       epoch UNIX de salida.
#               segundos  fin - inicio.
#               resultado ok        la fase terminó,
#                         manual    parada de prosa (EXIT=2),
#                         rojo      parada en seco (EXIT=1),
#                         interrumpido  cualquier otra salida (Ctrl-C…).
#   Ciclo     la fase de cierre imprime el desglose y ARCHIVA el reloj como
#             reloj-vX.Y.Z.tsv: el tren siguiente empieza en cero y el
#             anterior queda para comparar.
#
# Qué cuenta como CONDUCIDO: la suma de las fases. Lo que el propietario tarda
# ENTRE invocaciones (redactar las notes, revisar, dormir) queda fuera por
# construcción —es el hueco entre el `fin` de una fase y el `inicio` de la
# siguiente— y se imprime aparte, para que el descuento sea explícito y no un
# recorte silencioso. La espera de CI SÍ cuenta: el driver está bloqueado en
# `gh pr checks --watch` y esconderla daría un número bonito y falso.
#
# El reloj MIDE; no manda. Por encima del objetivo imprime un AVISO y sigue:
# en la fase de cierre el set ya está certificado, y un cronómetro no puede
# descertificar un set por haber tardado.
set -euo pipefail
cd "$(dirname "$0")/../.."

PHASES="preflight quark nucleus orbit paraguas cierre"
DRY=0
SOLO_SUELOS=0
SOLO_RELOJ=0
RELOJ_CERO=0
FROM="preflight"
TO="paraguas"
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --desde) shift; FROM="${1:-}" ;;
    --hasta) shift; TO="${1:-}" ;;
    --solo-suelos) SOLO_SUELOS=1 ;;
    --reloj) SOLO_RELOJ=1 ;;
    --reloj-cero) RELOJ_CERO=1 ;;
    -h|--help) sed -n '2,/^set -e/p' "$0" | sed '$d'; exit 0 ;;
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
# MANUAL_DESDE — la fase con la que se RETOMA el tren tras la parada. La de
# prosa del paraguas se retoma en la PROPIA fase paraguas (el driver abre y
# fusiona el PR de re-pin al volver), no en la siguiente.
MANUAL_DESDE=""
manual() {
  say ""
  say "== PASO MANUAL PENDIENTE =="
  while [ $# -gt 0 ]; do say "  $1"; shift; done
  say "Cuando esté hecho: bash scripts/train/train.sh --desde ${MANUAL_DESDE:-<fase-siguiente>}"
  exit 2
}
banner() { say ""; say "==== FASE: $1 ===="; }

# --- el reloj (ver la cabecera para el formato y qué cuenta como conducido) --
RELOJ_CORRIDA=$(date +%s)
if [ -n "${QUANTUM_TREN_RELOJ:-}" ]; then
  RELOJ="$QUANTUM_TREN_RELOJ"
else
  RELOJ_GITDIR=$(git rev-parse --git-common-dir 2>/dev/null || echo .git)
  case "$RELOJ_GITDIR" in /*) : ;; *) RELOJ_GITDIR="$PWD/$RELOJ_GITDIR" ;; esac
  RELOJ="$RELOJ_GITDIR/quantum-train/reloj.tsv"
fi
# El ensayo no toca el estado real: reloj temporal que se borra al salir.
RELOJ_TMP=0
if [ "$DRY" -eq 1 ] && [ "$SOLO_RELOJ" -eq 0 ] && [ "$RELOJ_CERO" -eq 0 ]; then
  RELOJ=$(mktemp -t quantum-tren-reloj) || RELOJ=/dev/null
  RELOJ_TMP=1
fi
OBJETIVO_MIN="${QUANTUM_TREN_OBJETIVO_MIN:-30}"

FASE_ACTUAL=""
FASE_INICIO=0

hms() { # segundos → 1h04m10s | 4m10s | 10s
  local s=$1 h m
  h=$((s / 3600)); m=$(((s % 3600) / 60)); s=$((s % 60))
  if [ "$h" -gt 0 ]; then printf '%dh%02dm%02ds' "$h" "$m" "$s"
  elif [ "$m" -gt 0 ]; then printf '%dm%02ds' "$m" "$s"
  else printf '%ds' "$s"; fi
}

reloj_abre() { FASE_ACTUAL="$1"; FASE_INICIO=$(date +%s); }

# reloj_marca <resultado> — cierra la fase EN VUELO. Idempotente: una segunda
# llamada (la del trap de salida tras un cierre normal) no escribe nada.
reloj_marca() {
  [ -n "$FASE_ACTUAL" ] || return 0
  local fin
  fin=$(date +%s)
  mkdir -p "$(dirname "$RELOJ")" 2>/dev/null || true
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$RELOJ_CORRIDA" "$FASE_ACTUAL" "$FASE_INICIO" "$fin" "$((fin - FASE_INICIO))" "$1" >> "$RELOJ" 2>/dev/null || true
  FASE_ACTUAL=""
}

# El trap traduce la salida a resultado: el tren muere por manual() (EXIT=2) o
# por die() (EXIT=1) mucho más a menudo que por terminar sus fases, y una fase
# que no se anota es tiempo conducido que desaparece del reloj.
reloj_al_salir() {
  local rc=$?
  case "$rc" in
    0) reloj_marca ok ;;
    2) reloj_marca manual ;;
    1) reloj_marca rojo ;;
    *) reloj_marca interrumpido ;;
  esac
  [ "$RELOJ_TMP" -eq 1 ] && rm -f "$RELOJ"
  return 0
}
trap reloj_al_salir EXIT

reloj_resumen() {
  if [ ! -s "$RELOJ" ]; then
    say "  (el reloj está vacío: ninguna fase anotada todavía — $RELOJ)"
    return 0
  fi
  local ph veces seg total=0 corridas paradas transcurrido espera
  say ""
  say "== RELOJ DEL TREN =="
  say "  fase        veces   conducido"
  for ph in $PHASES; do
    veces=$(awk -F'\t' -v p="$ph" '$2 == p' "$RELOJ" | grep -c . || true)
    [ "$veces" -gt 0 ] || continue
    seg=$(awk -F'\t' -v p="$ph" '$2 == p { s += $5 } END { print s + 0 }' "$RELOJ")
    total=$((total + seg))
    printf '  %-10s %5d   %s\n' "$ph" "$veces" "$(hms "$seg")"
  done
  corridas=$(awk -F'\t' '{ print $1 }' "$RELOJ" | sort -u | grep -c . || true)
  paradas=$(awk -F'\t' '$6 == "manual"' "$RELOJ" | grep -c . || true)
  local pal_c="invocaciones" pal_p="paradas de prosa"
  [ "$corridas" -eq 1 ] && pal_c="invocación"
  [ "$paradas" -eq 1 ] && pal_p="parada de prosa"
  transcurrido=$(awk -F'\t' 'NR == 1 { min = $3; max = $4 } { if ($3 < min) min = $3; if ($4 > max) max = $4 } END { print max - min }' "$RELOJ")
  espera=$((transcurrido - total))
  [ "$espera" -ge 0 ] || espera=0
  say "  ------------------------------"
  say "  CONDUCIDO por el driver        $(hms "$total")   ($corridas $pal_c, $paradas $pal_p)"
  say "  Espera del propietario         $(hms "$espera")   (entre invocaciones: la prosa y lo que la rodea; NO conducido)"
  say "  Transcurrido de punta a punta  $(hms "$transcurrido")"
  say "  Dentro de «conducido» va la espera de CI: el driver está bloqueado en"
  say "  «gh pr checks --watch», y descontarla daría un número que no paga nadie."
  if [ "$total" -gt "$((OBJETIVO_MIN * 60))" ]; then
    say "  AVISO: por encima del objetivo de ${OBJETIVO_MIN}m (+$(hms "$((total - OBJETIVO_MIN * 60))")). El reloj mide; no descertifica."
  else
    say "  Dentro del objetivo de ${OBJETIVO_MIN}m."
  fi
  say "  (reloj: $RELOJ)"
}

# reloj_archiva <sufijo> — el reloj de un tren cerrado se guarda al lado, para
# poder comparar trenes; el fichero en vuelo desaparece y el siguiente empieza
# en cero.
reloj_archiva() {
  if [ "$RELOJ_TMP" -eq 1 ]; then say "  (dry-run: el reloj es temporal — ni se archiva ni deja rastro)"; return 0; fi
  [ -s "$RELOJ" ] || { say "  (reloj vacío: nada que archivar)"; return 0; }
  local dest="${RELOJ%.tsv}-$1.tsv"
  [ -e "$dest" ] && dest="${RELOJ%.tsv}-$1-$(date +%H%M%S).tsv"
  mv "$RELOJ" "$dest" && say "  reloj archivado en $dest"
}

if [ "$SOLO_RELOJ" -eq 1 ]; then reloj_resumen; exit 0; fi
if [ "$RELOJ_CERO" -eq 1 ]; then
  say "Reloj del tren: archivo el que hubiera en vuelo y empiezo de cero."
  reloj_archiva "$(date +%Y%m%d-%H%M%S)"
  exit 0
fi

# manifiesto_valor <sección> <clave> — lee `clave: "valor"` bajo una clave de
# primer nivel de versions.yaml (el mismo lector que manifest-guard: el
# manifiesto es plano y no merece una dependencia de yq).
manifiesto_valor() {
  awk -v sec="$1" -v key="$2" '
    $0 ~ "^"sec":" { inblock = 1; next }
    /^[a-zA-Z_]/   { inblock = 0 }
    inblock && $1 == key":" { v = $2; gsub(/"/, "", v); print v; exit }
  ' versions.yaml
}

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
      say "    - filas de la tabla de versiones soportadas de SECURITY.md (release-please solo bumpa su línea marcada)"
      say "    (el tren corre gen_release_notes_skeleton.sh en la rama del release: quark-doc-debt.sh; escribe notas, línea marcada de CLAUDE.md, puntero del README y esas filas; solo para si queda prosa)"
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

# sube_suelos <repo> — el primer commit de cada corte (decisión 2026-09-05):
# rama desde main en el checkout hermano (../<repo>), align-module-floors.sh
# (commit fix(deps)), PR, fusión en serie (merge-group.sh) y espera de la
# corrida de «Release Please» del commit de merge, que regenera el release PR
# con los módulos dentro. Deja el checkout en main al día.
sube_suelos() {
  local repo=$1 dir="../$repo" br="fix/module-floors-$(date +%Y%m%d-%H%M)"
  if [ ! -e "$dir/.git" ]; then say "  sin checkout hermano en $dir"; return 1; fi
  if [ "$DRY" -eq 1 ]; then
    say "  → (dry-run) rama $br en $dir · align-module-floors.sh $repo · PR · merge-group · espera de Release Please"
    return 0
  fi
  if [ -n "$(git -C "$dir" status --porcelain)" ]; then say "  el checkout $dir está sucio: guarda o descarta antes"; return 1; fi
  run git -C "$dir" checkout -q main || return 1
  run git -C "$dir" pull -q --ff-only || return 1
  run git -C "$dir" checkout -q -b "$br" || return 1
  run bash scripts/train/align-module-floors.sh "$repo" --checkout "$dir" || return 1
  if [ "$repo" = nucleus ] && [ -x "$dir/scripts/release/repin_examples.sh" ]; then
    # Un minor de quark deja rojo check_example_pins.sh (lane Showcase Example
    # Smoke) hasta re-pinar examples/*/go.mod; `Repin Showcase` sólo corre tras
    # las releases de nucleus. Va en el mismo PR de suelos (1.29.0: nucleus#485).
    say "  → re-pin de los ejemplos de nucleus a los últimos tags hermanos (repin_examples.sh)"
    ( cd "$dir" && bash scripts/release/repin_examples.sh >/dev/null 2>&1 ) || say "  AVISO: repin_examples.sh falló; los ejemplos pueden quedar por detrás"
    if [ -n "$(git -C "$dir" status --porcelain)" ]; then
      run git -C "$dir" add -A && run git -C "$dir" commit -q -m "chore(examples): re-pin the examples to the latest published sibling tags

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>" || return 1
    fi
  fi
  run git -C "$dir" push -q -u origin "$br" || return 1
  local title body url n
  title=$(git -C "$dir" log -1 --format=%s)
  body=$(git -C "$dir" log -1 --format=%b | sed '/^Co-Authored-By/d')
  url=$(gh pr create -R "jcsvwinston/$repo" --head "$br" --title "$title" --body "$body
Opened by the release train: the sibling module floors are raised as the first commit of every cut (QM-19), so the modules cut together with the root.

🤖 Generated with [Claude Code](https://claude.com/claude-code)") || return 1
  n=${url##*/}
  say "  → PR $repo#$n abierto: $url"
  run bash scripts/train/merge-group.sh "$repo" --squash "$n" || return 1
  gh pr view "$n" -R "jcsvwinston/$repo" --json state --jq .state | grep -q MERGED || { say "  $repo#$n no quedó fusionado"; return 1; }
  local sha i rp
  sha=$(gh pr view "$n" -R "jcsvwinston/$repo" --json mergeCommit --jq .mergeCommit.oid)
  say "  → esperar la corrida de «Release Please» de ${sha:0:8} (regenera el release PR con los módulos)"
  for i in 1 2 3 4 5 6 7 8; do
    rp=$(gh run list -R "jcsvwinston/$repo" --limit 20 --json workflowName,headSha,status \
      --jq ".[] | select(.workflowName == \"Release Please\") | select(.headSha == \"$sha\") | .status" 2>/dev/null | head -1 || true)
    [ "$rp" = "completed" ] && break
    if [ -z "$rp" ] && [ "$i" -eq 4 ]; then
      say "  AVISO: el push no disparó «Release Please» — lo disparo a mano"
      run gh workflow run 'Release Please' -R "jcsvwinston/$repo" --ref main || true
    fi
    sleep 30
  done
  [ "$rp" = "completed" ] || say "  AVISO: «Release Please» no terminó en 4 min; el release PR puede no llevar aún los módulos"
  run git -C "$dir" checkout -q main
  run git -C "$dir" pull -q --ff-only
  git -C "$dir" branch -q -D "$br" 2>/dev/null || true
  say "OK: suelos de $repo subidos ($repo#$n)."
}

# alinea_pines_orbit — gemela de sube_suelos para los pines CRUZADOS de orbit:
# rama desde main en ../orbit, align-orbit-pins.sh (que llama al align_set.sh
# de orbit con los últimos tags de ../quark y ../nucleus), PR, merge-group y
# espera de «Release Please». Deja el checkout en main al día.
alinea_pines_orbit() {
  local dir="../orbit" br="chore/align-set-$(date +%Y%m%d-%H%M)"
  if [ ! -e "$dir/.git" ]; then say "  sin checkout hermano en $dir"; return 1; fi
  if [ "$DRY" -eq 1 ]; then say "  → (dry-run) rama $br en $dir · align-orbit-pins.sh · PR · merge-group · espera de Release Please"; return 0; fi
  if [ -n "$(git -C "$dir" status --porcelain)" ]; then say "  el checkout $dir está sucio: guarda o descarta antes"; return 1; fi
  run git -C "$dir" checkout -q main || return 1
  run git -C "$dir" pull -q --ff-only || return 1
  run git -C "$dir" checkout -q -b "$br" || return 1
  run bash scripts/train/align-orbit-pins.sh || return 1
  run git -C "$dir" push -q -u origin "$br" || return 1
  local title url n
  title=$(git -C "$dir" log -1 --format=%s)
  url=$(gh pr create -R jcsvwinston/orbit --head "$br" --title "$title" --body "Opened by the release train: orbit's cross-repo pins move to the Quark and Nucleus tags cut in this train, so the root and the modules are cut requiring the certified versions (manifest-guard §5 fails otherwise).

🤖 Generated with [Claude Code](https://claude.com/claude-code)") || return 1
  n=${url##*/}
  say "  → PR orbit#$n abierto: $url"
  run bash scripts/train/merge-group.sh orbit --squash "$n" || return 1
  gh pr view "$n" -R jcsvwinston/orbit --json state --jq .state | grep -q MERGED || { say "  orbit#$n no quedó fusionado"; return 1; }
  local sha i rp
  sha=$(gh pr view "$n" -R jcsvwinston/orbit --json mergeCommit --jq .mergeCommit.oid)
  say "  → esperar la corrida de «Release Please» de ${sha:0:8} (regenera el release PR con los pines)"
  for i in 1 2 3 4 5 6 7 8; do
    rp=$(gh run list -R jcsvwinston/orbit --limit 20 --json workflowName,headSha,status \
      --jq ".[] | select(.workflowName == \"Release Please\") | select(.headSha == \"$sha\") | .status" 2>/dev/null | head -1 || true)
    [ "$rp" = "completed" ] && break
    if [ -z "$rp" ] && [ "$i" -eq 4 ]; then
      say "  AVISO: el push no disparó «Release Please» — lo disparo a mano"
      run gh workflow run 'Release Please' -R jcsvwinston/orbit --ref main || true
    fi
    sleep 30
  done
  [ "$rp" = "completed" ] || say "  AVISO: «Release Please» no terminó en 4 min; el release PR puede no llevar aún los pines"
  run git -C "$dir" checkout -q main
  run git -C "$dir" pull -q --ff-only
  git -C "$dir" branch -q -D "$br" 2>/dev/null || true
  # RT-9 de una release de alineación: la sección de notas del root, en la
  # rama del bot (1.28.0 y 1.29.0 pararon aquí por una sección de tres líneas).
  say "  → orbit-align-notes.sh (sección ## vX.Y.Z de la release de alineación en la rama del bot)"
  run bash scripts/train/orbit-align-notes.sh || say "  AVISO: no pude escribir las notas de alineación; merge-bot-pr parará si el guard las exige"
  say "OK: pines cruzados de orbit alineados (orbit#$n)."
}

# fase_repo <repo> — fusiona los release PRs del bot en orden módulos→root.
fase_repo() {
  local repo=$1
  banner "$repo"
  imprime_deudas "$repo"
  if [ "$repo" != "orbit" ]; then
    # QM-19: los suelos módulo→raíz se suben AL PRINCIPIO de cada corte
    # (decisión de Carlos, 2026-09-05): el fix(deps) entra en el mismo
    # release PR que el trabajo real y los módulos salen con la raíz.
    say "PASO: suelos de los módulos hermanos hacia la raíz (QM-19: primer commit de cada corte)"
    if run bash scripts/train/align-module-floors.sh "$repo" --check; then
      say "  → suelos al día"
    else
      sube_suelos "$repo" || die "no pude subir los suelos de $repo (ver arriba); súbelos a mano: bash scripts/train/align-module-floors.sh $repo"
    fi
    if [ "$SOLO_SUELOS" -eq 1 ]; then say "OK: --solo-suelos — fase $repo termina aquí (release PRs sin tocar)."; return 0; fi
  fi

  if [ "$repo" = "quark" ]; then
    # RT-9 mecanizado (2026-09-05): el esqueleto de notas + menciones se
    # escribe EN la rama del release PR; el tren solo para si queda prosa.
    say "PASO: deuda de doc de quark en la rama del release (quark-doc-debt.sh)"
    local rc=0
    if [ "$DRY" -eq 1 ]; then
      bash scripts/train/quark-doc-debt.sh --dry-run || rc=$?
      case "$rc" in
        0) say "  → (dry-run) nada que pagar" ;;
        2) say "  → (dry-run) el tren PARARÁ aquí para redactar la prosa (marcadores TODO, ver arriba)" ;;
        *) say "  → (dry-run) quark-doc-debt.sh falló (EXIT=$rc, ver arriba)" ;;
      esac
    else
      run bash scripts/train/quark-doc-debt.sh || rc=$?
      case "$rc" in
        0) ;;
        2) MANUAL_DESDE=quark; manual "Redacta la prosa en los ficheros listados arriba (marcadores TODO): el esqueleto YA está empujado a release-please--branches--main. Empuja la prosa a esa rama y relanza: bash scripts/train/train.sh --desde quark" ;;
        *) die "la deuda de doc de quark no quedó pagada (ver arriba)" ;;
      esac
    fi
  fi
  if [ "$repo" = "orbit" ]; then
    # Pines CRUZADOS (2026-09-05): si quark/nucleus se cortaron en este tren,
    # orbit cortaría requiriendo los tags viejos y manifest-guard §5 FALLA
    # (no avisa). align_set.sh los sube en un commit antes de la fase.
    say "PASO: pines cruzados de orbit hacia los tags de quark y nucleus (align_set.sh)"
    # El check es de solo lectura (un ff-only de ../orbit main): se ejecuta
    # también en dry-run, para que el ensayo diga la verdad.
    say "  → bash scripts/train/align-orbit-pins.sh --check"
    if bash scripts/train/align-orbit-pins.sh --check; then
      say "  → pines al día"
    else
      alinea_pines_orbit || die "no pude alinear los pines de orbit (ver arriba); hazlo a mano: bash scripts/train/align-orbit-pins.sh"
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
  say "PASO: reloj del tren (el desglose se imprime en la fase de cierre)"
  if [ -s "$RELOJ" ]; then
    say "  AVISO: el reloj ya lleva $(grep -c . "$RELOJ" || true) marcas de un tren sin cerrar."
    say "  Se acumulan a las de este; para empezar de cero: bash scripts/train/train.sh --reloj-cero"
  else
    say "  → reloj en cero ($RELOJ)"
  fi
  say "RECORDATORIO del orden del tren (docs/AUDITORIA_CONTINUA.md §3 + 1.24.0):"
  say "  quark → nucleus (ldap antes que root) → orbit (módulos → root EL ÚLTIMO,"
  say "  re-pinando TODOS sus módulos Y el root en el mismo tren) → re-pin del paraguas."
}

# repin_ya_escrito — ¿versions.yaml declara ya el último tag de los tres
# submódulos? Entonces bump-set corrió en una invocación anterior de esta fase
# y NO se repite: sin movimiento, set-notes.py sale en error («ningún pilar ni
# módulo hermano se mueve»), y sobre unas notes ya redactadas las mandaría al
# CHANGELOG y escribiría otro esqueleto encima. El re-pin se escribe una vez
# por tren; la fase, en cambio, se entra tantas veces como haga falta.
repin_ya_escrito() {
  local m t v
  for m in quark nucleus orbit; do
    git -C "$m" fetch --tags --quiet origin >/dev/null 2>&1 || true
    t=$(git -C "$m" tag --list 'v*' --sort=-v:refname | head -1)
    v=$(manifiesto_valor modules "$m")
    [ -n "$t" ] && [ "$t" = "$v" ] || return 1
  done
  return 0
}

# abre_y_fusiona_repin <versión> — la parte MECÁNICA del re-pin del paraguas
# (A3): rama, commit, PR y fusión. Sin preguntar nada: el único juicio de esta
# fase es la prosa de las notes, y cuando esto corre ya está escrita. El PR
# lleva esas notes por cuerpo — la explicación del set ya la redactó una
# persona, y repetirla en otras palabras solo abriría una segunda versión de
# la verdad.
abre_y_fusiona_repin() {
  local ver=$1 br="chore/set-$1" n url msg notas
  if git rev-parse -q --verify "refs/heads/$br" >/dev/null 2>&1 ||
     git ls-remote --exit-code --heads origin "$br" >/dev/null 2>&1; then
    br="$br-$(date +%m%d-%H%M)"
    say "  (chore/set-$ver ya existe: uso $br)"
  fi
  msg="chore(set): $ver — re-pin del set: quark $(manifiesto_valor modules quark), nucleus $(manifiesto_valor modules nucleus) y orbit $(manifiesto_valor modules orbit)"
  # Las notes del manifiesto, sin la clave ni la indentación del bloque.
  notas=$(sed -n '/^notes: >/,$p' versions.yaml | sed '1d;s/^  //')
  say "  Lo que va en el commit:"
  git status --short | sed 's/^/    /'
  run git checkout -q -b "$br" || return 1
  run git add -A || return 1
  say "  → git commit -m \"$msg\" (cuerpo: las notes del manifiesto)"
  git commit -q -m "$msg" -m "$notas" \
    -m "Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>" || return 1
  run git push -q -u origin "$br" || return 1
  url=$(gh pr create -R jcsvwinston/quantum --base main --head "$br" --title "$msg" --body "$notas

Abierto por el tren: las notes ya están redactadas, así que en el re-pin no queda ninguna decisión: los pines son los tags recién cortados y el resto lo escribió bump-set. La lane suite-integral corre en modo normal (tolera el mid-tren sin tag) y el driver fusiona en cuanto salga verde.

🤖 Generated with [Claude Code](https://claude.com/claude-code)") || return 1
  n=${url##*/}
  say "  → PR quantum#$n abierto: $url"
  # quantum fusiona con MERGE COMMIT (no squash): el historial del paraguas
  # guarda el re-pin y su PR.
  run bash scripts/train/merge-group.sh quantum --merge "$n" || return 1
  gh pr view "$n" -R jcsvwinston/quantum --json state --jq .state | grep -q MERGED ||
    { say "  quantum#$n no quedó fusionado (mira sus checks)"; return 1; }
  run git checkout -q main || return 1
  run git pull -q --ff-only || return 1
  git branch -q -D "$br" 2>/dev/null || true
  say "OK: re-pin fusionado (quantum#$n)."
}

fase_paraguas() {
  banner "paraguas"
  if [ ! -f nucleus/go.mod ] || [ ! -f quark/go.mod ] || [ ! -f orbit/go.mod ]; then
    die "submódulos sin inicializar (git submodule update --init --recursive)"
  fi
  if [ "$DRY" -eq 1 ]; then
    # El ensayo no escribe: ni bump-set, ni rama, ni PR. Lo que sí dice es la
    # BIFURCACIÓN, que es lo que cambia en esta fase (A3).
    say "PASO: re-pin mecánico del set, si el manifiesto no lo lleva ya escrito"
    say "  → bash scripts/bump-set.sh"
    say "PASO: manifest-guard sobre el re-pin (tolera el marcador REDACTAR; el CI no)"
    say "  → env QUANTUM_ALLOW_NOTES_SKELETON=1 bash scripts/manifest-guard.sh"
    say "PASO: la bifurcación de esta fase, según los marcadores REDACTAR de versions.yaml:"
    say "  CON marcadores → PARADA (EXIT=2): la prosa de las notes, el título del CHANGELOG y"
    say "                   la cabecera de docs/RUMBO.md; se retoma con --desde paraguas."
    say "  SIN marcadores → guards locales del re-pin, rama chore/set-<versión>, commit con las"
    say "                   notes por cuerpo, PR y merge-group.sh quantum --merge: sin preguntar."
    say "OK: fase paraguas (dry-run) — nada escrito."
    return 0
  fi
  if repin_ya_escrito; then
    say "PASO: re-pin mecánico — los tres pines ya están en el último tag: NO repito bump-set"
    say "  (lo escribió una invocación anterior de esta fase; repetirlo mandaría las notes ya"
    say "   redactadas al CHANGELOG y escribiría otro esqueleto encima)"
  else
    say "PASO: re-pin mecánico del set (bump-set.sh: submódulos al tag, versions.yaml/README, versión"
    say "      de suite por QADR-0002, notes anteriores al CHANGELOG y esqueleto de las nuevas)"
    run bash scripts/bump-set.sh || die "bump-set.sh falló"
  fi
  say "PASO: manifest-guard sobre lo que bump-set escribió (tolera el marcador REDACTAR del esqueleto; el CI no)"
  run env QUANTUM_ALLOW_NOTES_SKELETON=1 bash scripts/manifest-guard.sh || die "manifest-guard rechaza el re-pin"

  # La ÚNICA parada de esta fase: la prosa. Lo demás —abrir el PR y fusionarlo—
  # no es juicio humano, y desde A3 lo hace el driver.
  if grep -q 'REDACTAR' versions.yaml; then
    MANUAL_DESDE=paraguas
    manual \
      "La prosa del set, que no se delega. Todo lo demás de esta fase lo hace el driver al volver." \
      "1. Redacta las notes de versions.yaml: bump-set dejó versión de suite, released, status y los" \
      "   movimientos del set; sustituye cada REDACTAR (manifest-guard §0 lo rechaza) y revisa el título" \
      "   que puso a la entrada anterior en CHANGELOG.md (DX-25). Si el número de suite no es el que" \
      "   toca (corte deliberado): bash scripts/bump-set.sh --set X.Y.Z (solo cambia el número)." \
      "2. Actualiza la cabecera «Estado real» de docs/RUMBO.md con el set nuevo (regla de" \
      "   mantenimiento del RUMBO; check_rumbo_estado está en el registro y el PR saldría rojo)." \
      "3. Si el workflow llevaba QUANTUM_ALLOW_DECLARED_LAGS, quítalo: el PR de re-pin sale verde SIN escapes." \
      "Al volver, el driver abre el PR de re-pin y lo fusiona él (y con --hasta cierre, sigue al cierre)."
  fi

  local ver
  ver=$(sed -nE 's/^quantum:[[:space:]]+"([^"]+)".*/\1/p' versions.yaml | head -1)
  [ -n "$ver" ] || die "no pude leer la versión de suite de versions.yaml"
  say "PASO: notes redactadas (sin marcadores REDACTAR) — el re-pin de Quantum $ver ya no tiene nada que decidir"

  # Los guards del re-pin que corren en local y en segundos: abrir un PR que ya
  # se sabe rojo es gastar una vuelta de CI y la atención de quien mira.
  say "PASO: los guards locales que la lane del PR va a exigir, ANTES de abrirlo"
  run bash scripts/manifest-guard.sh \
    || die "manifest-guard en rojo sin escapes: el PR de re-pin saldría rojo. Arregla y relanza --desde paraguas"
  run bash scripts/check_rumbo_estado.sh \
    || die "docs/RUMBO.md no declara el set del manifiesto (regla de mantenimiento del RUMBO): actualiza su cabecera «Estado real» y relanza --desde paraguas"
  run bash scripts/check_gowork_covers_manifest.sh \
    || die "el go.work no cubre el manifiesto: el «use» de un módulo nuevo del pin va EN el PR de re-pin (1.26.2). Añádelo y relanza --desde paraguas"

  if [ -z "$(git status --porcelain)" ]; then
    say "PASO: abrir y fusionar el PR de re-pin"
    say "  El árbol está limpio: el re-pin ya está en main, no hay PR que abrir."
  else
    say "PASO: abrir y fusionar el PR de re-pin (rama, commit, gh pr create, merge-group.sh)"
    abre_y_fusiona_repin "$ver" || die "el PR de re-pin no quedó fusionado (ver arriba). El re-pin sigue en su rama: arregla la causa y relanza --desde paraguas"
  fi
  say "OK: fase paraguas completa — Quantum $ver re-pinado en main."
  say "  Siguiente: bash scripts/train/train.sh --desde cierre --hasta cierre"
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
  say "de docs/AUDITORIA_CONTINUA.md §6 (conteos COPIADOS de las tablas de las lanes)."
  # El reloj se cierra AQUÍ (la fase en vuelo es «cierre») para que su propio
  # tiempo entre en el desglose, y se archiva con la versión del set.
  reloj_marca ok
  reloj_resumen
  reloj_archiva "v$ver"
}

started=0
for ph in $PHASES; do
  [ "$ph" = "$FROM" ] && started=1
  [ "$started" -eq 1 ] || continue
  # «cierre» nunca arranca por arrastre: exige pedirse explícitamente
  # (--desde/--hasta cierre) porque presupone el PR de re-pin fusionado —
  # que desde A3 fusiona la fase paraguas, así que «--desde paraguas --hasta
  # cierre» encadena las dos sin volver a arrancar el tren.
  if [ "$ph" = "cierre" ] && [ "$FROM" != "cierre" ] && [ "$TO" != "cierre" ]; then continue; fi
  reloj_abre "$ph"
  case "$ph" in
    preflight) fase_preflight ;;
    quark|nucleus|orbit) fase_repo "$ph" ;;
    paraguas) fase_paraguas ;;
    cierre) fase_cierre ;;
  esac
  reloj_marca ok
  [ "$ph" = "$TO" ] && break
done
say ""
if [ "$DRY" -eq 1 ]; then
  say "Tren (DRY-RUN): fases $FROM..$TO recorridas — NADA se ha ejecutado con efectos."
else
  say "Tren: fases $FROM..$TO terminadas."
fi
