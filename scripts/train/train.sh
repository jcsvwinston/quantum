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
#                        y lo FUSIONA con merge-group.sh sin preguntar. Ese
#                        commit va a main sin que nadie mire su diff, así que
#                        sale de main al día y lleva SOLO las rutas del re-pin
#                        (ver RUTAS_REPIN y --incluye).
#   cierre               tras fusionar el PR de re-pin: tag de suite EN HEAD,
#                        suite-integral --cierre (MAQ-1/MAQ-2) y el anuncio
#                        del set al consumidor externo quantum-app (D6/RT-5).
#
# Uso: train.sh [--dry-run] [--desde <fase>] [--hasta <fase>]
#   --dry-run   imprime los pasos sin efectos sobre los remotos ni sobre el set:
#               no fusiona, no empuja, no abre PRs, no escribe el re-pin y no
#               toca el reloj (usa un temporal). En las fases de repo sí toca
#               los checkouts hermanos EN LOCAL, a propósito, para que el
#               ensayo diga la verdad: align-orbit-pins.sh --check hace un
#               pull ff-only de ../orbit y quark-doc-debt.sh --dry-run añade
#               un worktree temporal en ../quark. La línea con la que el
#               ensayo termina nombra los que ha tocado: es lo último que se
#               lee, y decir ahí «nada» sería mentir en esas fases.
#   --desde     retoma el tren en esa fase (default: preflight).
#   --hasta     última fase a ejecutar (default: paraguas; «cierre» solo corre
#               pedido explícitamente — exige el PR de re-pin ya fusionado).
#   --solo-suelos  en las fases de repo, sube los suelos (QM-19) y para: no
#               fusiona release PRs. Es el primer commit de un corte que aún
#               no se va a cerrar (arranque de un arco).
#   --incluye <ruta>  añade una ruta a lo que el PR de re-pin puede llevar
#               (repetible; el fichero o el directorio que lo contiene). Por
#               defecto solo entran las rutas que el re-pin escribe; cualquier
#               otra cosa PARA el tren con los ficheros por delante —uno por
#               línea, y con la orden de relanzamiento ya escrita, que
#               reimprime los --incluye ya aceptados y entrecomilla lo que el
#               shell miraría— en vez de colarse en un PR que se fusiona solo.
#               Nombrarla es la revisión, así que la ruta que se imprime es la
#               de verdad: el árbol y las ramas se leen con `-z`, sin el
#               entrecomillado con que git escapa lo no-ASCII. Se mira el árbol
#               sin commitear (camino de creación) y también lo que lleva
#               commiteado la rama que se retoma o el PR de set ya abierto:
#               los tres acaban en main sin que nadie mire el diff.
#   --reloj     imprime el reloj del tren en vuelo (desglose por fase, total
#               conducido y espera del propietario) y sale. Sin efectos.
#   --reloj-cero  archiva el reloj en vuelo y sale: el tren siguiente empieza
#               de cero. No lo hace nadie por su cuenta. Con --dry-run imprime
#               qué archivaría, sin moverlo.
#
# «--desde paraguas --hasta cierre» encadena el re-pin y el cierre en una sola
# invocación: desde que la fase paraguas fusiona su PR, entre las dos no queda
# ninguna decisión humana. Encadenar sube el precio de equivocarse en «¿está
# el re-pin en main?»: esa pregunta se le hace a origin y a GitHub —la versión
# que declara origin/main y los PRs chore/set-* abiertos—, nunca al árbol. Un
# árbol limpio no distingue «fusionado» de «parado en el merge sobre la rama
# del set», y leerlo como lo primero certificaría y anunciaría el set ANTERIOR
# con el nuevo aún sin fusionar. Y si GitHub no contesta, la pregunta se queda
# SIN responder y el tren para: un gh que falla no es «no hay ningún PR de set
# abierto», y tratarlo como tal abre justo el gate que lo impide.
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
# Un array, no una cadena separada por espacios: `--incluye "docs/mis notas.md"`
# se partía en dos rutas que no existen, y ninguna de las dos casaba con la que
# el árbol trae.
INCLUYE=()
SOLO_RELOJ=0
RELOJ_CERO=0
FROM="preflight"
TO="paraguas"
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    # Un flag con valor y sin valor («--incluye» al final de la línea) añadía
    # una entrada vacía y moría en el `shift` de abajo con $#=0: EXIT=1 y NI UNA
    # línea, indistinguible de una parada en seco del tren.
    --desde) shift; [ $# -gt 0 ] || { echo "--desde necesita una fase (ver --help)" >&2; exit 64; }; FROM="$1" ;;
    --hasta) shift; [ $# -gt 0 ] || { echo "--hasta necesita una fase (ver --help)" >&2; exit 64; }; TO="$1" ;;
    --solo-suelos) SOLO_SUELOS=1 ;;
    --incluye) shift; [ $# -gt 0 ] || { echo "--incluye necesita una ruta (ver --help)" >&2; exit 64; }; INCLUYE+=("$1") ;;
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
#
# La plantilla va entera y con XXXXXX: `mktemp -t <prefijo>` es la forma de
# BSD, y el mktemp de GNU la rechaza («too few X's in template»). En Linux —el
# runner del CI, y cualquier máquina que no sea el mac del propietario— el
# ensayo se quedaba con el fallback RELOJ=/dev/null y moría al salir intentando
# borrarlo: `--dry-run` salía EXIT=1 después de haber recorrido bien sus fases.
RELOJ_TMP=0
if [ "$DRY" -eq 1 ] && [ "$SOLO_RELOJ" -eq 0 ] && [ "$RELOJ_CERO" -eq 0 ]; then
  RELOJ=$(mktemp "${TMPDIR:-/tmp}/quantum-tren-reloj.XXXXXX") || RELOJ=/dev/null
  RELOJ_TMP=1
fi
OBJETIVO_MIN="${QUANTUM_TREN_OBJETIVO_MIN:-30}"

# Los checkouts HERMANOS que se han llegado a tocar. Se anotan donde se ejecuta
# el script que los toca, y el cierre de un ensayo los nombra: la última línea
# que el operador lee no puede decir «nada» cuando ../quark o ../orbit se han
# movido, ni nombrarlos cuando no.
TOCADO_QUARK=0
TOCADO_ORBIT=0

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
  # Retirar el temporal no puede decidir el código de salida del tren: con
  # `set -e`, un `rm` que falla sale del trap por la puerta de atrás —sin
  # llegar al `return`— y bash se queda con ESE código, convirtiendo un ensayo
  # bueno en EXIT=1.
  if [ "$RELOJ_TMP" -eq 1 ] && [ "$RELOJ" != /dev/null ]; then rm -f "$RELOJ" || true; fi
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
  # El reloj de --reloj-cero es el REAL (el temporal del ensayo lo dejaría sin
  # nada que archivar), así que aquí el ensayo tiene que decirlo y no moverlo:
  # «--dry-run» promete no ejecutar nada con efectos, y archivar el reloj del
  # tren en vuelo lo es.
  if [ "$DRY" -eq 1 ]; then
    say "Reloj del tren (dry-run): esto es lo que archivaría — no lo muevo."
    if [ -s "$RELOJ" ]; then
      marcas=$(grep -c . "$RELOJ" || true)
      pal_m=marcas; [ "$marcas" -eq 1 ] && pal_m=marca
      say "  $RELOJ → ${RELOJ%.tsv}-<fecha>.tsv ($marcas $pal_m)"
    else
      say "  (el reloj está vacío: no habría nada que archivar — $RELOJ)"
    fi
    exit 0
  fi
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

# version_suite_en <ref> — la versión de suite que declara el versions.yaml de
# una REF (no la del árbol). Dónde está el re-pin se lee de las refs y de los
# PRs: el árbol de trabajo no distingue «fusionado» de «commiteado en su rama
# y sin fusionar», y las dos cosas se ven exactamente igual (limpio).
version_suite_en() {
  local yaml
  # No poder leer el versions.yaml de una ref es una RESPUESTA («no lo pude
  # leer»), y los llamantes la tratan como tal —imprimen «<no lo pude leer>» y
  # paran—; con set -euo pipefail, en cambio, el fallo de git show mataría al
  # driver sin decir dónde.
  yaml=$(git show "$1:versions.yaml" 2>/dev/null) || return 0
  printf '%s\n' "$yaml" | sed -nE 's/^quantum:[[:space:]]+"([^"]+)".*/\1/p' | head -1
}

# repin_pr_abierto — los PRs de set abiertos en el paraguas, uno por línea,
# «número rama». Distingue DOS respuestas que antes se veían igual:
#
#   EXIT=0 y salida vacía  GitHub contestó y no hay ninguno.
#   EXIT≠0                 la consulta FALLÓ (503, token caducado a mitad de
#                          tren, rate limit, corte de red). El error de gh sale
#                          por stderr y quien pregunta PARA.
#
# La versión anterior (`2>/dev/null || true`) convertía cualquier fallo de la
# API en «no hay ninguno», sin un solo aviso. De esta respuesta cuelgan los dos
# guards que impiden certificar un set con su re-pin sin fusionar (fase cierre
# y fase paraguas), así que el fallo abría el gate en vez de cerrarlo: un gate
# que contesta «todo en orden» cuando no ha podido preguntar no es un gate.
#
# Se descuentan los PRs que ESTA invocación ya fusionó y comprobó MERGED
# (PR_REPIN_FUSIONADO): el listado de GitHub puede ir un instante por detrás
# del merge que acabamos de verificar, y esa demora no es un re-pin pendiente.
PR_REPIN_FUSIONADO=""
repin_pr_abierto() {
  local salida rc=0 linea n
  # El stderr de gh NO se redirige: si falla, su error se lee en el terminal
  # junto a la parada. Y solo su stdout se captura, para no parsear como PRs
  # los avisos que gh escribe por stderr.
  salida=$(gh pr list -R jcsvwinston/quantum --state open --json number,headRefName \
    --jq '.[] | select(.headRefName | startswith("chore/set-")) | "\(.number) \(.headRefName)"') || rc=$?
  [ "$rc" -eq 0 ] || return "$rc"
  while IFS= read -r linea; do
    [ -n "$linea" ] || continue
    n=${linea%% *}
    case " $PR_REPIN_FUSIONADO " in *" $n "*) continue ;; esac
    printf '%s\n' "$linea"
  done <<EOF
$salida
EOF
}

# SET_EN_CURSO — la versión de suite que la fase paraguas dejó FUSIONADA en
# main en esta invocación. La fase de cierre se niega a certificar otra: con
# «--desde paraguas --hasta cierre» las dos fases encadenan sin que nadie mire
# entre medias.
SET_EN_CURSO=""

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
  # El título y el cuerpo del PR salen de ESTE commit, no del último: en
  # squash-only el título del PR ES el commit que llega a main, y si lo pone
  # el re-pin de los ejemplos (un `chore`) release-please no ve el `fix(deps)`
  # y no corta el patch de cada módulo. Entonces sus go.mod cambian sin tag y
  # manifest-guard §3b rechaza el set entero. Pasó en el corte de 1.30.0 con
  # los doce módulos de nucleus, y costó revertirlos.
  local title body url n
  title=$(git -C "$dir" log -1 --format=%s)
  body=$(git -C "$dir" log -1 --format=%b | sed '/^Co-Authored-By/d')
  run git -C "$dir" push -q -u origin "$br" || return 1
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
      TOCADO_QUARK=1
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
    TOCADO_ORBIT=1
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
  say "PASO: rama del paraguas (el PR de re-pin sale de main, y de un main al día)"
  local rama
  rama=$(git rev-parse --abbrev-ref HEAD)
  if [ "$rama" = "main" ]; then
    say "  → main"
  else
    say "  AVISO: estás en «$rama». A las fases de repo les da igual; la fase paraguas"
    say "  PARARÁ EN SECO ahí nada más entrar —antes de escribir el re-pin— salvo que sea"
    say "  la rama chore/set-* del camino de recuperación: desde una rama de trabajo, el PR"
    say "  del set arrastraría a main lo que esa rama traiga, y se fusiona sin que nadie lo mire."
  fi
  say "PASO: árbol del paraguas limpio (QM8-5 — la certificación lo exigirá)"
  if [ "$DRY" -eq 0 ] && [ -n "$(git status --porcelain)" ]; then
    say "  AVISO: árbol sucio. Las fases de repo no lo necesitan limpio, pero"
    say "  la fase paraguas/cierre sí: commitea o guarda antes de llegar ahí."
    say "  El PR de re-pin lleva SOLO las rutas del re-pin: lo demás para el tren"
    say "  (RUTAS_REPIN, --incluye), no se cuela en un PR que se fusiona solo."
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

# RUTAS_REPIN — lo ÚNICO que el PR de re-pin puede llevar: los tres gitlinks
# y los ficheros que escriben bump-set (versions.yaml, README.md, CHANGELOG.md)
# y la parada de prosa (docs/RUMBO.md), más el go.work del `use` de un módulo
# nuevo del pin (1.26.2). Hasta A3 el diff de este commit lo veía la persona
# que abría el PR; ahora se fusiona sin que nadie lo mire, así que un
# `git add -A` metería en main cualquier fichero suelto del árbol —una nota de
# trabajo, un .orig de un conflicto, la salida de un script— sin que ningún
# guard del paraguas se entere. `--incluye <ruta>` amplía la lista a
# propósito: nombrar el fichero es la revisión que el paso automático quitó.
RUTAS_REPIN=(versions.yaml README.md CHANGELOG.md docs/RUMBO.md go.work go.work.sum quark nucleus orbit)

# ruta_del_repin <ruta> — ¿está en RUTAS_REPIN (o bajo una de ellas) o en las
# que se pasaron con --incluye?
#
# La barra final se normaliza en los DOS lados. Una ruta de directorio llega
# con barra («docs/handoff/»), y esa barra viajaba tal cual a la orden de
# relanzamiento que imprime para_por_rutas_ajenas, con lo que --incluye la
# recibía de vuelta: el directorio pasaba al repartir el árbol y su contenido
# moría después contra el patrón «docs/handoff//*», que no casa con
# docs/handoff/set.md. La misma orden aceptaba la ruta en un sitio y la
# rechazaba en el otro.
ruta_del_repin() {
  local r p=${1%/}
  for r in "${RUTAS_REPIN[@]}" ${INCLUYE[@]+"${INCLUYE[@]}"}; do
    r=${r%/}
    [ "$p" = "$r" ] && return 0
    case "$p" in "$r"/*) return 0 ;; esac
  done
  return 1
}

# lee_rutas_git <qué> <argumentos de git...> — las rutas que devuelve un git
# con `-z`, ENTERAS, en RUTAS_LEIDAS.
#
# Dos razones para el `-z` y para el fichero temporal, y las dos son la misma:
# lo que se lee aquí decide qué entra en un PR que se fusiona sin que nadie
# mire su diff.
#
#   - Sin `-z`, git CITA la ruta que lleva caracteres no-ASCII, comillas o
#     backslash: `docs/handoff/año.md` sale como el literal
#     `"docs/handoff/a\303\261o.md"` (comillas incluidas). Esa cadena viajaba
#     a la orden de relanzamiento y al escape --incluye, donde ya no casa con
#     la ruta real: el operador copiaba la orden, el tren volvía a parar por lo
#     mismo y no convergía nunca. Con `-z` no cita, y separa por NUL, así que
#     una ruta con espacios llega de una pieza.
#   - Y el fichero temporal (en vez de `$(...)`) porque la sustitución de
#     órdenes se COME los NUL —quedaría todo pegado en una sola ruta— y porque
#     dentro de ella el código de salida de git se pierde: un git que falla se
#     leería como «no hay nada ajeno», que es la forma de fallar que este gate
#     existe para cerrar.
RUTAS_LEIDAS=()
lee_rutas_git() {
  local que=$1; shift
  local tmp ruta rc=0
  RUTAS_LEIDAS=()
  tmp=$(mktemp "${TMPDIR:-/tmp}/quantum-tren-rutas.XXXXXX") ||
    die "no pude crear el fichero temporal donde leo $que"
  git "$@" >"$tmp" || rc=$?
  if [ "$rc" -ne 0 ]; then
    rm -f "$tmp"
    die "no pude leer $que (git $1 EXIT=$rc, su error justo arriba): sin esa respuesta daría por bueno lo que no he podido mirar, y esto se fusiona sin que nadie mire su diff"
  fi
  while IFS= read -r -d '' ruta; do
    [ -n "$ruta" ] || continue
    RUTAS_LEIDAS+=("$ruta")
  done <"$tmp"
  rm -f "$tmp"
}

# reparte_el_arbol — clasifica lo que el árbol tiene sin commitear en rutas
# DEL re-pin y AJENAS (RUTAS_DENTRO / RUTAS_FUERA), en arrays: una ruta con
# espacios se partía en dos al acumularla en una cadena, y las dos mitades
# llegaban rotas a la parada y al escape --incluye.
#
# `-uall` (en vez del `-unormal` por defecto) porque un directorio entero sin
# rastrear se colapsa en una sola línea —«?? docs/handoff/»— y ese resumen
# viajaba a --incluye como si fuera una ruta: el fichero que de verdad va en el
# set no aparecía por ninguna parte. Con los ficheros uno a uno, la orden de
# relanzamiento los nombra —que es la revisión que el paso automático quitó— y
# --incluye acepta tanto el fichero como el directorio que lo contiene.
RUTAS_DENTRO=()
RUTAS_FUERA=()
reparte_el_arbol() {
  RUTAS_DENTRO=(); RUTAS_FUERA=()
  local registro ruta origen tmp rc=0
  tmp=$(mktemp "${TMPDIR:-/tmp}/quantum-tren-arbol.XXXXXX") ||
    die "no pude crear el fichero temporal donde leo el árbol"
  git status --porcelain -z -uall >"$tmp" || rc=$?
  if [ "$rc" -ne 0 ]; then
    rm -f "$tmp"
    die "no pude leer el árbol (git status EXIT=$rc, su error justo arriba): sin esa respuesta no sé qué llevaría el commit, y este PR se fusiona sin que nadie mire su diff"
  fi
  while IFS= read -r -d '' registro; do
    # «XY ruta»: los tres primeros caracteres son el estado y su espacio.
    [ ${#registro} -gt 3 ] || continue
    # Con `-z`, un rename o una copia emiten DOS registros: primero el destino
    # —que es por donde este reparto ya juzgaba— y detrás el origen. Se consume
    # aquí para no contarlo como una ruta más.
    case ${registro:0:2} in [RC]?|?[RC]) IFS= read -r -d '' origen || origen="" ;; esac
    ruta=${registro:3}
    if ruta_del_repin "$ruta"; then
      RUTAS_DENTRO+=("$ruta")
    else
      RUTAS_FUERA+=("$ruta")
    fi
  done <"$tmp"
  rm -f "$tmp"
}

# cita <ruta> — la ruta escrita para pegarla en un shell. La orden de
# relanzamiento se copia y se ejecuta TAL CUAL, así que la ruta tiene que
# llegar entera al --incluye de la vuelta siguiente: `docs/mis notas.md` sin
# comillas son dos argumentos, y el escape acaba nombrando dos rutas que no
# existen. Se entrecomilla todo lo que no sea del alfabeto llano de una ruta
# (una acentuada incluida: entre comillas simples se lee igual de bien y no
# hay que decidir qué mira el shell).
cita() {
  case "$1" in
    *[!A-Za-z0-9/._+,:@=-]*) printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")" ;;
    *) printf '%s' "$1" ;;
  esac
}

# orden_de_relanzamiento <rutas ajenas...> — la orden con la que se retoma la
# fase, ya escrita para copiar y pegar.
#
# Se siembra con lo que el operador YA traía aceptado ($INCLUYE) y solo después
# se le añaden las rutas que ahora se le enseñan. Sin esa siembra, aceptar dos
# rutas ajenas de una en una perdía la primera: la vuelta 1 imprimía
# «--incluye B», ejecutarla literalmente hacía que la vuelta 2 imprimiera
# «--incluye A», y la 3 volvía a B — ping-pong infinito ejecutando justo la
# orden que el driver imprime, en el paso que este driver automatiza.
#
# Sin la barra final del directorio: la orden se copia y se pega tal cual, y
# --incluye compara rutas, no prefijos con barra.
orden_de_relanzamiento() {
  local r orden="bash scripts/train/train.sh --desde paraguas"
  for r in ${INCLUYE[@]+"${INCLUYE[@]}"} "$@"; do orden="$orden --incluye $(cita "${r%/}")"; done
  printf '%s' "$orden"
}

# para_por_rutas_ajenas — la parada (EXIT=2) cuando el árbol trae algo que no
# es del re-pin: se enseñan los ficheros en vez de arrastrarlos. Uno por línea,
# que es lo que promete --help: en una sola línea, con un árbol sucio de
# verdad, no se leen justo cuando hay que leerlos.
para_por_rutas_ajenas() {
  local ruta
  local -a lineas=()
  for ruta in ${RUTAS_FUERA[@]+"${RUTAS_FUERA[@]}"}; do lineas+=("  ${ruta%/}"); done
  [ ${#lineas[@]} -gt 0 ] || lineas=("  (ninguna)")
  MANUAL_DESDE=paraguas
  manual \
    "El árbol del paraguas trae cambios que NO son del re-pin:" \
    "${lineas[@]}" \
    "El PR de re-pin se fusiona a main sin que nadie mire su diff, así que no los arrastro." \
    "Sácalos del árbol (git stash / git checkout -- / rm) — o, si van EN el set, nómbralos:" \
    "  $(orden_de_relanzamiento ${RUTAS_FUERA[@]+"${RUTAS_FUERA[@]}"})"
}

# exige_main_al_dia — el re-pin sale de main y de un main al día. La rama se
# creaba desde el HEAD que hubiera: conducido desde una rama de trabajo, el PR
# del set arrastraba a main los commits de esa rama, y nadie los miraba.
#
# Se llama DOS veces y es idempotente: al entrar en la fase (por
# exige_punto_de_partida, antes de que bump-set escriba el re-pin en la rama
# equivocada) y otra vez justo antes de crear la rama.
exige_main_al_dia() {
  local rama local_sha remoto_sha
  rama=$(git rev-parse --abbrev-ref HEAD)
  [ "$rama" = "main" ] ||
    die "el PR de re-pin sale de main y estás en «$rama»: desde aquí el PR llevaría a main lo que traiga esta rama. Ponte en main (git checkout main) y relanza --desde paraguas"
  git fetch -q origin main || die "no pude traer origin/main: sin eso no sé si main está al día"
  local_sha=$(git rev-parse HEAD)
  remoto_sha=$(git rev-parse origin/main)
  [ "$local_sha" = "$remoto_sha" ] ||
    die "main local ($(git rev-parse --short HEAD)) no es origin/main ($(git rev-parse --short origin/main)): ponlo al día con git pull --ff-only —o saca de main lo que tenga de más, que iría en el PR del set— y relanza --desde paraguas"
}

# exige_punto_de_partida — el control de DÓNDE está el tren, al ENTRAR en la
# fase y no cinco pasos después. Solo hay dos puntos de partida legítimos:
#
#   main al día            el camino de creación (rama, commit, PR, fusión).
#   una rama chore/set-*   el camino de recuperación (se retoma esa rama).
#
# Comprobarlo dentro de abre_y_fusiona_repin llegaba tarde: desde una rama de
# trabajo, la fase corría antes bump-set (que mueve los tres gitlinks y
# reescribe versions.yaml/README/CHANGELOG), la parada de prosa —con lo que el
# propietario redactaba las notes enteras— y los guards locales, y SOLO
# entonces paraba en seco con un «ponte en main» que dejaba todo ese trabajo en
# la rama equivocada.
exige_punto_de_partida() {
  local rama
  rama=$(git rev-parse --abbrev-ref HEAD)
  case "$rama" in
    chore/set-*)
      say "  → «$rama»: la rama del re-pin (camino de recuperación). Lo que lleve se revisa antes de empujarla."
      ;;
    *)
      exige_main_al_dia
      say "  → main al día ($(git rev-parse --short HEAD) = origin/main)"
      ;;
  esac
}

# cuerpo_notas — las notes del manifiesto, sin la clave ni la indentación del
# bloque. Son el cuerpo del commit y del PR: la explicación del set ya la
# redactó una persona, y repetirla en otras palabras abriría una segunda
# versión de la verdad.
cuerpo_notas() { sed -n '/^notes: >/,$p' versions.yaml | sed '1d;s/^  //'; }

# crea_pr_repin <título> <cuerpo> — abre el PR del set desde la rama actual y
# deja su número en PR_REPIN.
PR_REPIN=""
crea_pr_repin() {
  local url
  url=$(gh pr create -R jcsvwinston/quantum --base main --head "$(git rev-parse --abbrev-ref HEAD)" --title "$1" --body "$2

Abierto por el tren: las notes ya están redactadas, así que en el re-pin no queda ninguna decisión: los pines son los tags recién cortados y el resto lo escribió bump-set. La lane suite-integral corre en modo normal (tolera el mid-tren sin tag) y el driver fusiona en cuanto salga verde.

🤖 Generated with [Claude Code](https://claude.com/claude-code)") || return 1
  PR_REPIN=${url##*/}
  say "  → PR quantum#$PR_REPIN abierto: $url"
}

# fusiona_pr_repin <n> — fusiona el PR del set y COMPRUEBA que quedó MERGED.
# quantum fusiona con MERGE COMMIT (no squash): el historial del paraguas
# guarda el re-pin y su PR.
fusiona_pr_repin() {
  local n=$1 br
  br=$(git rev-parse --abbrev-ref HEAD)
  run bash scripts/train/merge-group.sh quantum --merge "$n" || return 1
  gh pr view "$n" -R jcsvwinston/quantum --json state --jq .state | grep -q MERGED ||
    { say "  quantum#$n no quedó fusionado (mira sus checks)"; return 1; }
  PR_REPIN_FUSIONADO="$PR_REPIN_FUSIONADO $n"
  run git checkout -q main || return 1
  run git pull -q --ff-only || return 1
  case "$br" in chore/set-*) git branch -q -D "$br" 2>/dev/null || true ;; esac
  say "OK: re-pin fusionado (quantum#$n)."
}

# abre_y_fusiona_repin <versión> — la parte MECÁNICA del re-pin del paraguas
# (A3): rama, commit, PR y fusión. Sin preguntar nada: el único juicio de esta
# fase es la prosa de las notes, y cuando esto corre ya está escrita. Lo que sí
# comprueba, porque nadie va a mirar el diff, es de DÓNDE sale la rama y QUÉ
# entra en el commit.
abre_y_fusiona_repin() {
  local ver=$1 br="chore/set-$1" msg puesta
  exige_main_al_dia
  reparte_el_arbol
  [ ${#RUTAS_FUERA[@]} -eq 0 ] || para_por_rutas_ajenas
  [ ${#RUTAS_DENTRO[@]} -gt 0 ] ||
    die "no hay nada del re-pin sin commitear y main no lo declara: no sé qué commitear (relanza bump-set.sh)"
  msg="chore(set): $ver — re-pin del set: quark $(manifiesto_valor modules quark), nucleus $(manifiesto_valor modules nucleus) y orbit $(manifiesto_valor modules orbit)"
  say "  Lo que va en el commit (solo rutas del re-pin):"
  git -c core.quotePath=false status --short -- "${RUTAS_DENTRO[@]}" | sed 's/^/    /'
  if git rev-parse -q --verify "refs/heads/$br" >/dev/null 2>&1 ||
     git ls-remote --exit-code --heads origin "$br" >/dev/null 2>&1; then
    br="$br-$(date +%m%d-%H%M)"
    say "  (chore/set-$ver ya existe: uso $br)"
  fi
  # El índice se mira ANTES de crear la rama y antes de apuntar nada. `git add
  # -- <rutas>` no desapunta lo que el índice ya llevara y `git commit`
  # commitea el índice ENTERO, así que un fichero ajeno ya apuntado entraría en
  # el commit aunque el árbol esté repartido; y comprobarlo después del
  # checkout dejaba, al rechazar, media rama chore/set-X.Y.Z con el índice
  # apuntado detrás —un estado que había que deshacer a mano y que en el
  # relanzamiento siguiente moría con otro mensaje distinto. Lo que se apunta
  # luego no hace falta volver a mirarlo: el pathspec son las rutas que
  # reparte_el_arbol ya dio por del re-pin.
  lee_rutas_git "lo que el índice lleva apuntado" diff --cached --name-only -z
  for puesta in ${RUTAS_LEIDAS[@]+"${RUTAS_LEIDAS[@]}"}; do
    ruta_del_repin "$puesta" ||
      die "el índice lleva $puesta, que no es del re-pin, y el commit se fusiona sin que nadie lo mire: git reset y relanza --desde paraguas"
  done
  run git checkout -q -b "$br" || return 1
  run git add -A -- "${RUTAS_DENTRO[@]}" || return 1
  say "  → git commit -m \"$msg\" (cuerpo: las notes del manifiesto)"
  git commit -q -m "$msg" -m "$(cuerpo_notas)" \
    -m "Co-Authored-By: ${TRAIN_CO_AUTHOR:-Claude Opus 5 <noreply@anthropic.com>}" || return 1
  run git push -q -u origin "$br" || return 1
  crea_pr_repin "$msg" "$(cuerpo_notas)" || return 1
  fusiona_pr_repin "$PR_REPIN"
}

# exige_rama_sobre_main_al_dia <rama> — la gemela de exige_main_al_dia para el
# camino de recuperación: allí HEAD no es main (es la rama del set), así que lo
# que se exige es que la rama DESCIENDA de un origin/main al día. Si main se
# movió por debajo —la ola de PRs de la ronda se sigue fusionando mientras el
# tren corre—, el merge del PR mezclaría el re-pin con un main que nadie
# comparó, y este PR se fusiona sin que nadie mire su diff.
exige_rama_sobre_main_al_dia() {
  local br=$1 rc=0
  git fetch -q origin main || die "no pude traer origin/main: sin eso no sé sobre qué main está $br"
  # EXIT=1 es la RESPUESTA «no desciende»; cualquier otro código es que la
  # pregunta no se pudo hacer, y eso no se lee como un sí (el stderr de git
  # sale por delante de la parada).
  git merge-base --is-ancestor origin/main HEAD || rc=$?
  case "$rc" in
    0) : ;;
    1) die "la rama $br no desciende de origin/main ($(git rev-parse --short origin/main)): main se movió por debajo y el PR del set se fusiona sin que nadie mire su diff. Rebásala (git rebase origin/main), comprueba que sigue limpia y relanza --desde paraguas" ;;
    *) die "no pude comparar $br con origin/main (git merge-base EXIT=$rc, su error justo arriba): sin esa respuesta no sé sobre qué main está la rama que voy a fusionar" ;;
  esac
}

# revisa_lo_que_lleva <qué> <ref> — la gemela del filtro RUTAS_REPIN para los
# caminos en los que el contenido ya está COMMITEADO. Ahí reparte_el_arbol (que
# mira el árbol sin commitear) no ve nada: la rama se empujaba, se abría el PR
# y se FUSIONABA entera sin mirar su diff. Bastaba con que el propietario, al
# arreglar la causa de una fusión roja, dejara un fichero suelto commiteado en
# la rama para que main se llevara el re-pin Y «wip: nota suelta» de un tirón.
#
# Se compara lo que la ref AÑADE sobre origin/main
# (`git diff --name-only origin/main...<ref>`), con el mismo predicado
# (ruta_del_repin), el mismo escape (--incluye) y la misma parada (EXIT=2) que
# el camino de creación. La llaman los dos caminos que fusionan algo ya
# commiteado: la rama que se retoma en local y la rama del PR que ya está
# abierto en GitHub (que pudo crecer desde que la abrimos).
revisa_lo_que_lleva() {
  local que=$1 ref=$2 ruta
  local -a ajenas=() lineas=()
  # El diff se pide con su código de salida a la vista (lee_rutas_git PARA si
  # git falla): un `git diff` que falla dentro de una sustitución no se
  # distingue de «no añade nada», y este gate se leería como «limpio» sin haber
  # podido mirar — que es justo la forma de fallar que esta revisión existe
  # para cerrar. Y con `-z`, para que la ruta que se imprime y se nombra sea la
  # de verdad y no la que git cita.
  lee_rutas_git "qué lleva $que sobre origin/main" diff -z --name-only "origin/main...$ref"
  for ruta in ${RUTAS_LEIDAS[@]+"${RUTAS_LEIDAS[@]}"}; do
    ruta_del_repin "$ruta" && continue
    ajenas+=("$ruta")
    lineas+=("  $ruta")
  done
  [ ${#ajenas[@]} -gt 0 ] || return 0
  MANUAL_DESDE=paraguas
  manual \
    "$que lleva commiteado, sobre origin/main, algo que NO es del re-pin:" \
    "${lineas[@]}" \
    "El PR de re-pin se fusiona a main sin que nadie mire su diff, así que no lo arrastro." \
    "Sácalo de esa rama (git reset / git rebase -i, y empuja la corrección si ya está en origin)" \
    "— o, si va EN el set, nómbralo:" \
    "  $(orden_de_relanzamiento "${ajenas[@]}")"
}

# reanuda_rama_repin <versión> — el camino de recuperación que el propio A3
# crea: abre_y_fusiona_repin murió DESPUÉS del commit (en el push, en el
# gh pr create o en la fusión) y el árbol quedó LIMPIO sobre chore/set-X.Y.Z
# con el re-pin sin fusionar. Se retoma ESA rama; no se abre otra ni se da el
# re-pin por hecho.
#
# Y se retoma REVISADA: empujar, abrir el PR y fusionarlo es exactamente lo
# mismo que hace el camino de creación, así que pasa por los mismos dos
# controles —de dónde sale y qué lleva—, solo que aplicados a lo ya commiteado.
reanuda_rama_repin() {
  local ver=$1 br msg ver_rama
  br=$(git rev-parse --abbrev-ref HEAD)
  ver_rama=$(version_suite_en HEAD)
  [ "$ver_rama" = "$ver" ] ||
    die "la rama $br no lleva commiteado el re-pin de $ver (su versions.yaml declara ${ver_rama:-nada legible}): mírala antes de seguir"
  if [ -n "$(git status --porcelain)" ]; then
    say "  la rama $br tiene además cambios sin commitear:"
    git -c core.quotePath=false status --short | sed 's/^/    /'
    die "no los mezclo con un re-pin ya commiteado: commítealos tú en $br (o sácalos del árbol) y relanza --desde paraguas"
  fi
  exige_rama_sobre_main_al_dia "$br"
  revisa_lo_que_lleva "la rama $br" HEAD
  say "  Lo que la rama lleva sobre origin/main (solo rutas del re-pin):"
  git -c core.quotePath=false diff --name-only origin/main...HEAD | sed 's/^/    /'
  run git push -q -u origin "$br" || die "no pude empujar $br"
  msg=$(git log -1 --format=%s)
  crea_pr_repin "$msg" "$(cuerpo_notas)" || die "no pude abrir el PR de re-pin desde $br"
  fusiona_pr_repin "$PR_REPIN" ||
    die "quantum#$PR_REPIN no quedó fusionado (ver arriba). El re-pin sigue en $br: arregla la causa y relanza --desde paraguas"
}

fase_paraguas() {
  banner "paraguas"
  if [ ! -f nucleus/go.mod ] || [ ! -f quark/go.mod ] || [ ! -f orbit/go.mod ]; then
    die "submódulos sin inicializar (git submodule update --init --recursive)"
  fi
  if [ "$DRY" -eq 1 ]; then
    # El ensayo no escribe: ni bump-set, ni rama, ni PR. Lo que sí dice es la
    # BIFURCACIÓN, que es lo que cambia en esta fase (A3).
    say "PASO: de dónde sale el re-pin — main AL DÍA, o la rama chore/set-* del camino de"
    say "      recuperación; desde cualquier otra rama la fase para en seco AQUÍ, antes de que"
    say "      bump-set escriba el re-pin (y el propietario redacte la prosa) en la rama equivocada"
    say "PASO: re-pin mecánico del set, si el manifiesto no lo lleva ya escrito"
    say "  → bash scripts/bump-set.sh"
    say "PASO: manifest-guard sobre el re-pin (tolera el marcador REDACTAR; el CI no)"
    say "  → env QUANTUM_ALLOW_NOTES_SKELETON=1 bash scripts/manifest-guard.sh"
    say "PASO: la bifurcación de esta fase, según los marcadores REDACTAR de versions.yaml:"
    say "  CON marcadores → PARADA (EXIT=2): la prosa de las notes, el título del CHANGELOG y"
    say "                   la cabecera de docs/RUMBO.md; se retoma con --desde paraguas."
    say "  SIN marcadores → guards locales del re-pin y, según DÓNDE esté el re-pin:"
    say "PASO: dónde está el re-pin — se le pregunta a origin/main y a los PRs chore/set-* abiertos,"
    say "      NUNCA al árbol (limpio no distingue «fusionado» de «parado en el merge sobre su rama»)"
    say "      y si GitHub no contesta se PARA: un gh que falla no es «no hay ningún PR abierto»"
    say "  origin/main ya declara el set  → nada que abrir."
    say "  hay un PR chore/set-* abierto  → se retoma SU fusión; no se abre otro."
    say "  HEAD en una rama chore/set-*   → se retoma esa rama (push, PR, fusión)."
    say "  si no                          → desde main AL DÍA: rama, commit de SOLO las rutas del"
    say "                                   re-pin (RUTAS_REPIN; lo ajeno PARA el tren), PR y"
    say "                                   merge-group.sh quantum --merge."
    say "  Y al final se exige que origin/main DECLARE el set: no se da por fusionado."
    say "OK: fase paraguas (dry-run) — nada escrito."
    return 0
  fi
  # ANTES de escribir nada: desde una rama de trabajo, todo lo que viene
  # después (bump-set, la prosa de las notes, los guards) se escribiría en la
  # rama equivocada para parar en seco al final.
  say "PASO: de dónde sale el re-pin — main al día, o la rama chore/set-* del camino de recuperación"
  exige_punto_de_partida

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

  # DÓNDE está el re-pin no se infiere del árbol. Un árbol limpio significaba
  # aquí «ya está en main», y es falso justo en el camino de recuperación que
  # esta fase crea: si la fusión murió (check rojo, protección de rama), el
  # árbol queda LIMPIO sobre chore/set-X.Y.Z con el PR abierto. Dar eso por
  # fusionado manda al cierre, que certifica y anuncia a quantum-app el set
  # ANTERIOR mientras el nuevo sigue sin fusionar. Se pregunta a origin y a
  # GitHub, que son los que lo saben.
  say "PASO: ¿está el re-pin de $ver en main? (se le pregunta a origin y a GitHub, no al árbol)"
  run git fetch -q origin main || die "no pude leer origin/main: sin eso no sé si el re-pin está fusionado"
  local ver_main rama pend pend_n pend_br
  ver_main=$(version_suite_en origin/main)
  rama=$(git rev-parse --abbrev-ref HEAD)
  # Si GitHub no contesta, no se sigue con la mitad de la respuesta: sin saber
  # si ya hay un PR de set abierto, el camino de abajo abriría un SEGUNDO PR
  # (con sufijo de fecha) sobre el mismo re-pin.
  pend=$(repin_pr_abierto) ||
    die "no pude preguntar a GitHub por los PRs chore/set-* (el error de gh, justo arriba): sin esa respuesta no sé si el re-pin de $ver ya tiene un PR abierto, y abrir otro dejaría dos PRs de set. Relanza --desde paraguas cuando gh conteste"
  say "  origin/main declara Quantum ${ver_main:-<no lo pude leer>} · rama actual «$rama» · PR de set abierto: ${pend:-ninguno}"

  if [ -n "$pend" ]; then
    [ "$(printf '%s\n' "$pend" | grep -c .)" -eq 1 ] ||
      die "hay más de un PR chore/set-* abierto en el paraguas ($(printf '%s' "$pend" | tr '\n' ';')): cierra los que sobren y relanza --desde paraguas"
    pend_n=${pend%% *}; pend_br=${pend#* }
    case "$pend_br" in
      "chore/set-$ver"|"chore/set-$ver"-*) : ;;
      *) die "el PR de set abierto (quantum#$pend_n, rama $pend_br) no es el de $ver: míralo antes de seguir — no fusiono un set que no es el de este tren" ;;
    esac
    say "PASO: quantum#$pend_n sigue abierto — retomo SU fusión (no abro otro PR)"
    # El tercer camino que fusiona sin que nadie mire el diff. La rama la abrió
    # una invocación anterior de esta fase (revisada), pero pudo crecer después:
    # arreglar el rojo que impidió la fusión se hace empujando A ESA rama. Lo
    # que se mira es su contenido; su base es cosa del merge de GitHub.
    say "  → qué lleva la rama $pend_br sobre origin/main (solo rutas del re-pin)"
    run git fetch -q origin "$pend_br" ||
      die "no pude traer la rama $pend_br del PR quantum#$pend_n: sin ella no puedo mirar qué lleva, y se fusiona sin que nadie la mire"
    revisa_lo_que_lleva "la rama $pend_br (PR quantum#$pend_n)" FETCH_HEAD
    git -c core.quotePath=false diff --name-only "origin/main...FETCH_HEAD" | sed 's/^/    /'
    fusiona_pr_repin "$pend_n" ||
      die "quantum#$pend_n sigue sin fusionar (ver arriba: sus checks o la protección de rama). Arregla la causa y relanza --desde paraguas"
  elif [ "$ver_main" = "$ver" ]; then
    say "PASO: nada que abrir — origin/main ya declara Quantum $ver y no queda ningún PR de set abierto"
    if [ -n "$(git status --porcelain)" ]; then
      say "  AVISO: el árbol tiene cambios que no están en el re-pin fusionado:"
      git -c core.quotePath=false status --short | sed 's/^/    /'
      say "  La fase de cierre exige árbol limpio (el tag captura HEAD): resuélvelos antes."
    fi
  else
    case "$rama" in
      chore/set-*)
        say "PASO: el re-pin está commiteado en «$rama» y NO ha llegado a main — retomo esa rama"
        reanuda_rama_repin "$ver"
        ;;
      *)
        [ -n "$(git status --porcelain)" ] ||
          die "origin/main declara Quantum ${ver_main:-?}, el manifiesto local declara $ver, y no hay ni cambios que commitear ni PR abierto: el re-pin no está en ninguna parte. Mira qué pasó con la rama chore/set-$ver antes de relanzar"
        say "PASO: abrir y fusionar el PR de re-pin (rama, commit, gh pr create, merge-group.sh)"
        abre_y_fusiona_repin "$ver" || die "el PR de re-pin no quedó fusionado (ver arriba). El re-pin sigue en su rama: arregla la causa y relanza --desde paraguas"
        ;;
    esac
  fi

  # Y tampoco se da por hecho que salió bien: main tiene que DECLARARLO.
  ver_main=$(version_suite_en origin/main)
  [ "$ver_main" = "$ver" ] ||
    die "tras la fusión origin/main sigue declarando Quantum ${ver_main:-?} y no $ver: el re-pin NO está en main. No sigas al cierre — certificaría el set anterior"
  SET_EN_CURSO="$ver"
  say "OK: fase paraguas completa — Quantum $ver re-pinado en main (lo declara origin/main)."
  say "  Siguiente: bash scripts/train/train.sh --desde cierre --hasta cierre"
}

fase_cierre() {
  banner "cierre"
  # De qué set arranca esta invocación, ANTES de tocar la rama: el checkout y
  # el pull de abajo abandonan en silencio un re-pin que no llegó a main, y a
  # partir de ahí la fase certificaría —y anunciaría a quantum-app— el set
  # ANTERIOR, que ya tiene tag («voy directo a la certificación»).
  local head_antes ver_antes pend rc_pend=0
  head_antes=$(git rev-parse HEAD 2>/dev/null || echo "")
  ver_antes=$(version_suite_en HEAD)
  # «No lo pude leer» es una RESPUESTA, y sin ella el gate de abajo —el que
  # impide certificar el set ANTERIOR con el re-pin nuevo sin fusionar— no
  # tiene con qué decidir. Estaba condicionado a `[ -n "$ver_antes" ]`, así que
  # un versions.yaml ilegible en HEAD lo desactivaba sin una línea de aviso:
  # un fallo ABIERTO en el gate alrededor del que gira esta fase.
  if [ -z "$ver_antes" ]; then
    say "  el HEAD del que arranca el cierre ($(git rev-parse --short HEAD 2>/dev/null || echo '?')) declara Quantum <no lo pude leer>"
    if [ "$DRY" -eq 1 ]; then
      say "  AVISO (dry-run): sin esa respuesta el gate del set en curso no se puede evaluar — en real esto sería una parada en seco; el ensayo no certifica nada."
    else
      die "no pude leer el versions.yaml del HEAD del que arranca el cierre: sin él no puedo comprobar que el set que traía el tren es el que main declara, y certificar a ciegas publicaría el set anterior como si fuera el nuevo. Ponte en un HEAD con manifiesto (git checkout main) y relanza --desde cierre --hasta cierre"
    fi
  fi
  say "PASO: que no quede ningún PR de set sin fusionar (si lo hay, el re-pin no está en main)"
  pend=$(repin_pr_abierto) || rc_pend=$?
  if [ "$rc_pend" -ne 0 ]; then
    # gh mudo NO se lee como «no hay ninguno»: este es el guard que impide
    # certificar y anunciar el set ANTERIOR con el re-pin nuevo sin fusionar,
    # y sin respuesta de GitHub no tiene con qué decidir. El ensayo, que no
    # certifica nada, lo dice y sigue.
    if [ "$DRY" -eq 1 ]; then
      say "  AVISO (dry-run): GitHub no contestó (el error de gh, justo arriba) — en real esto sería una parada en seco; el ensayo no certifica nada."
    else
      die "no pude preguntar a GitHub por los PRs chore/set-* (el error de gh, justo arriba): sin esa respuesta no sé si queda un re-pin sin fusionar, y certificar a ciegas publicaría el set anterior como si fuera el nuevo. Reintenta --desde cierre --hasta cierre cuando gh conteste"
    fi
  elif [ -n "$pend" ]; then
    if [ "$DRY" -eq 1 ]; then
      say "  AVISO (dry-run): hay un PR de set abierto ($(printf '%s' "$pend" | tr '\n' ';')) — en real esto sería una parada en seco."
    else
      die "hay un PR de set sin fusionar (quantum#${pend%% *}, rama ${pend#* }): el re-pin no está en main. Fusiónalo (--desde paraguas) antes de certificar"
    fi
  else
    say "  → ninguno abierto"
  fi
  say "PASO: main al día y árbol limpio (el tag se corta EN HEAD)"
  run git checkout main
  run git pull --ff-only
  if [ "$DRY" -eq 0 ] && [ -n "$(git status --porcelain)" ]; then
    die "árbol sucio — el tag debe capturar un HEAD limpio"
  fi
  local ver
  ver=$(sed -nE 's/^quantum:[[:space:]]+"([^"]+)".*/\1/p' versions.yaml | head -1)
  [ -n "$ver" ] || die "no pude leer la versión de suite de versions.yaml"
  # El set que se certifica es el que traía el tren, no el que main tuviera.
  # Si el manifiesto del que arrancó esta invocación declaraba OTRO set y su
  # commit no está en main, el re-pin se quedó fuera: certificar aquí sería
  # publicar el set anterior como si fuera el nuevo.
  if [ "$DRY" -eq 0 ] && [ -n "$ver_antes" ] && [ "$ver_antes" != "$ver" ] &&
     ! git merge-base --is-ancestor "$head_antes" HEAD 2>/dev/null; then
    die "arranqué sobre un manifiesto que declara Quantum $ver_antes, main declara $ver y ese HEAD ($(git rev-parse --short "$head_antes")) no está en main: el re-pin de $ver_antes NO se fusionó. No certifico el set anterior"
  fi
  if [ -n "$SET_EN_CURSO" ] && [ "$SET_EN_CURSO" != "$ver" ]; then
    die "la fase paraguas dejó Quantum $SET_EN_CURSO fusionado y en main leo $ver: no certifico un set distinto del que acaba de re-pinarse"
  fi
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
  # Esta es la ÚLTIMA línea que el operador lee de un ensayo, así que dice el
  # mismo alcance que --help y que el README. «NADA se ha ejecutado con
  # efectos» era falso en las fases de repo: ahí el ensayo toca a propósito los
  # checkouts hermanos EN LOCAL —si no los tocara, mentiría sobre lo que esas
  # dos comprobaciones van a decir—, y quien lea solo el cierre no se enteraría
  # de que ../quark y ../orbit se han movido.
  #
  # Y se nombra lo que de verdad se ha tocado, anotado donde se ejecuta y no
  # deducido de las fases pedidas: con --solo-suelos la fase quark termina
  # antes de llamar a quark-doc-debt.sh, y ../quark no llega a moverse.
  say "Tren (DRY-RUN): fases $FROM..$TO recorridas — sin efectos sobre los remotos ni sobre el set: no se ha empujado, ni fusionado, ni abierto ningún PR, ni escrito el re-pin, ni etiquetado nada."
  TOCADOS=0
  if [ "$TOCADO_QUARK" -eq 1 ]; then
    TOCADOS=1
    say "  En local sí se ha tocado ../quark: quark-doc-debt.sh --dry-run trae sus refs (git fetch) y abre un worktree temporal donde mergea origin/main y commitea el esqueleto de notas. No lo empuja, y el worktree se retira al salir."
  fi
  if [ "$TOCADO_ORBIT" -eq 1 ]; then
    TOCADOS=1
    say "  En local sí se ha tocado ../orbit: align-orbit-pins.sh --check lo pone al día con un git pull --ff-only antes de comparar (solo si está en main y limpio)."
  fi
  [ "$TOCADOS" -eq 1 ] ||
    say "  Ningún checkout hermano se ha tocado en este recorrido."
else
  say "Tren: fases $FROM..$TO terminadas."
fi
