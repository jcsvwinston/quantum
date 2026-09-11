#!/usr/bin/env bash
# estado.sh — «¿dónde estamos?» en un comando, para arrancar una sesión.
#
# El contrato de sesión (docs/planes/README.md §1) manda correr cinco cosas
# antes de tocar nada: el set certificado, los arcos cerrados y los hallazgos
# abiertos, la cabecera del RUMBO, qué arcos tienen troceado, y si el checkout
# ha derivado. Escribirlas a mano cada vez es exactamente lo que se automatiza.
#
# NO ESCRIBE NADA. Ni toca el árbol, ni los remotos, ni el reloj del tren. Se
# puede correr en cualquier momento y tantas veces como haga falta.
#
# Uso:
#   bash scripts/estado.sh          # el estado completo
#   bash scripts/estado.sh --breve  # sólo el titular: set, arco y siguiente sesión
#
# Lo que NO hace, a propósito: no certifica. Para eso está
# `scripts/suite-integral.sh --cierre`, que corre los guards y tarda minutos.
# Esto responde en segundos y sólo lee.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

BREVE=0; [ "${1:-}" = "--breve" ] && BREVE=1
tit() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

# ---------------------------------------------------------------------------
# 1. El set certificado. La fuente es versions.yaml, siempre.
# ---------------------------------------------------------------------------
suite=$(sed -nE 's/^quantum:[[:space:]]+"([^"]+)".*/\1/p' versions.yaml | head -1)
fecha=$(sed -nE 's/^released:[[:space:]]*([0-9-]+).*/\1/p' versions.yaml | head -1)
printf '\033[1mQuantum %s\033[0m (certificado %s) — ' "$suite" "$fecha"
for m in quark nucleus orbit; do
  printf '%s %s  ' "$m" "$(awk -v k="$m:" '/^modules:/{i=1;next} i&&/^[^[:space:]]/{i=0} i&&$1==k{gsub(/"/,"",$2);print $2}' versions.yaml)"
done
echo

# ---------------------------------------------------------------------------
# 2. Arcos y hallazgos. El registro es quien manda sobre «qué arco toca».
# ---------------------------------------------------------------------------
reg=docs/auditoria/madurez-2026-09-03/registro.csv
cerrados=$(sed -nE '1s/^# arcos_cerrados:[[:space:]]*//p' "$reg")
abiertos=$(awk -F, 'NR>2 && $5=="abierto" {print $4}' "$reg" | sort | uniq -c | awk '{printf "%s(%s) ", $2, $1}')
printf 'Arcos cerrados: \033[1m%s\033[0m · abiertos por arco: %s\n' "$cerrados" "${abiertos:-ninguno}"

# El siguiente arco es el primero de A1..A12 que no está en la lista de
# cerrados. Se deriva, no se escribe: una lista escrita se queda vieja.
siguiente=""
for n in $(seq 1 12); do
  case " $cerrados " in *" A$n "*) continue ;; esac
  siguiente="A$n"; break
done
plan=$(ls docs/planes/ 2>/dev/null | grep -E "^${siguiente}-" | head -1)
if [ -n "$plan" ]; then
  # La primera fila del registro de sesiones que no está hecha. Se lee SOLO
  # bajo «## Registro de sesiones»: un fichero de arco puede llevar otras
  # tablas cuya primera celda también empieza por Sn — la de A4 lleva la de
  # qué cambió el troceado— y antes se colaba la primera que apareciera.
  ses=$(awk -F'|' '
    /^## Registro de sesiones/ {en=1; next}
    en && /^\| S[0-9]+ /{
      gsub(/ /,"",$2); gsub(/^ +| +$/,"",$3)
      sub(/\*\*/,"",$3); sub(/\*\*.*/,"",$3)
      if ($3 != "hecha") {print $2 " (" $3 ")"; exit}
    }' "docs/planes/$plan")
  printf 'Siguiente: \033[1m%s\033[0m → docs/planes/%s' "$siguiente" "$plan"
  [ -n "$ses" ] && printf ' · próxima sesión: \033[1m%s\033[0m' "$ses"
  echo
else
  printf 'Siguiente: \033[1m%s\033[0m — SIN troceado todavía. Se escribe al empezarlo, y empieza por una sesión de medición (docs/planes/README.md §5).\n' "$siguiente"
fi

[ "$BREVE" -eq 1 ] && exit 0

# ---------------------------------------------------------------------------
# 3. ¿El checkout es el set, o ha derivado? Lo segundo invalida cualquier
#    medición que se haga encima.
# ---------------------------------------------------------------------------
tit "checkout"
# `git submodule status` marca el estado en la PRIMERA columna, y para un
# submódulo que SÍ está en el commit del set esa columna es un espacio. Sin
# IFS= vacío, `read` se lo come y la marca pasaba a ser el primer dígito del
# SHA: el caso bueno —el normal— se imprimía como «?», que se lee como alarma.
git submodule status 2>/dev/null | while IFS= read -r linea; do
  marca=${linea:0:1}
  case "$marca" in
    ' ') printf '  ok   %s\n' "$(echo "$linea" | awk '{print $2, $3}')" ;;
    '+') printf '  \033[33mDERIVADO\033[0m %s — el submódulo NO está en el commit del set\n' "$(echo "$linea" | awk '{print $2}')" ;;
    '-') printf '  \033[31mSIN INICIAR\033[0m %s — git submodule update --init --recursive\n' "$(echo "$linea" | awk '{print $2}')" ;;
    *)   printf '  ?    %s\n' "$linea" ;;
  esac
done
sucio=$(git status --porcelain | wc -l | tr -d ' ')
[ "$sucio" != "0" ] && printf '  \033[33m%s fichero(s) sin commitear en el paraguas\033[0m\n' "$sucio"
rama=$(git branch --show-current)
[ "$rama" != "main" ] && printf '  \033[33mrama %s\033[0m (el tren y el re-pin salen de main al día)\n' "$rama"

# ---------------------------------------------------------------------------
# 4. Qué quedó abierto en los cinco repos. Necesita red; si gh no contesta se
#    dice, en vez de imprimir un cero que se lee como «nada pendiente».
# ---------------------------------------------------------------------------
tit "PRs abiertos"
for r in quantum quark nucleus orbit quantum-app; do
  salida=$(gh pr list -R "jcsvwinston/$r" --json number,title,isDraft --jq '.[] | "   #\(.number)\(if .isDraft then " [borrador]" else "" end) \(.title)"' 2>/dev/null)
  rc=$?
  if [ $rc -ne 0 ]; then
    printf '  %-12s \033[33mno pude preguntar a GitHub\033[0m\n' "$r"
  elif [ -z "$salida" ]; then
    printf '  %-12s ninguno\n' "$r"
  else
    printf '  %-12s\n%s\n' "$r" "$(echo "$salida" | cut -c1-100)"
  fi
done

# ---------------------------------------------------------------------------
# 5. Lo que espera al propietario. Se MIDE por API, no se copia de una lista:
#    una lista escrita dice «pendiente» mucho después de estar hecho.
# ---------------------------------------------------------------------------
tit "esperando al propietario (medido, no copiado)"
for r in quark nucleus orbit quantum; do
  am=$(gh api "repos/jcsvwinston/$r" --jq '.allow_auto_merge' 2>/dev/null || echo '?')
  lic=$(gh api "repos/jcsvwinston/$r" --jq '.license.spdx_id // "—"' 2>/dev/null || echo '?')
  if gh api "repos/jcsvwinston/$r/branches/main/protection" >/dev/null 2>&1; then prot=sí; else prot=NO; fi
  printf '  %-9s main protegida=%-3s allow_auto_merge=%-5s licencia=%s\n' "$r" "$prot" "$am" "$lic"
done

tit "para arrancar"
cat <<'FIN'
  docs/planes/README.md          el contrato de sesión (qué manda, qué no decides tú)
  docs/planes/A<N>-*.md          el arco en curso, troceado en sesiones
  .claude/commands/next-session.md §3   estado vigente y las dos últimas sesiones
  scripts/train/README.md        las trampas del tren, antes de cortar un set
FIN
