#!/usr/bin/env bash
# check_quickstart_embeds.sh — lo que el quickstart de la suite EMBEBE dice lo
# que su prosa explica, resuelto contra el submódulo PINADO.
#
# La página website/docs/quickstart.md no copia código: sus tres listados son
# fences ```go file=<rootDir>/examples/showcase_demo/…``` que remark-code-import
# resuelve en build contra el submódulo nucleus del paraguas (rootDir =
# ../nucleus en website/docusaurus.config.ts, instancia `start`). Eso ata el
# texto de la página a un ÁRBOL que la página no controla, y la deriva no
# avisa:
#
#   - un rango `#L24-L66` que hoy es exactamente `func Module` se desplaza
#     en silencio con cualquier edición de la plantilla por encima de la
#     línea 24 (el test de frescura de nucleus ata plantilla↔ejemplo, no
#     números de línea);
#   - el pin del submódulo puede ir POR DETRÁS de la página: el ejemplo
#     existe con el mismo nombre en un pin anterior, así que el build sale
#     verde (check_built_codeblocks sólo caza bloques VACÍOS) y publica el
#     listado viejo bajo un párrafo que explica el nuevo — en el arco A2, un
#     `Module` sin `Policies`/`CSRFExempt` bajo el texto que los explica, y
#     un main.go con vocabulario interno en su comentario de cabecera;
#   - un fichero que ya no existe al pin es ENOENT en build (rojo, pero
#     tarde: en website-ci, no en la fuente).
#
# Este guard resuelve cada fence `file=` de la página con las MISMAS reglas
# que el plugin (ruta con `<rootDir>` o relativa a la página; `#Lx`, `#Lx-`,
# `#Lx-Ly` 1-based inclusivo; sangría común eliminada como
# removeRedundantIndentations) y exige, sobre el texto resultante:
#
#   1. que el fichero exista y el rango quepa en él (no vacío, sin pasarse
#      del final — el plugin trunca sin avisar);
#   2. que NO contenga jerga interna — la misma regex que
#      check_served_jargon.sh aplica al HTML servido, leída de ese script en
#      tiempo de ejecución para que no haya dos listas que mantener; aquí
#      muerde ANTES del build y nombra el pin;
#   3. que diga lo que la página DECLARA en su front matter (`embeds:`, espejo
#      del `concepts:` que cuenta el guard de coste): una entrada por fence,
#      `'<ruta tal cual en la fence, sin <rootDir>/> | token | token…'`, donde
#      `^texto` exige que la PRIMERA línea del bloque empiece así, `texto$`
#      que la ÚLTIMA termine así, y cualquier otro token es una subcadena
#      literal que el bloque debe contener. Así el rango queda atado a su
#      contenido (primera y última línea) y no a un número.
#
# Cruce en las dos direcciones, como el guard de coste: una fence `file=` sin
# entrada en `embeds:` es FAIL (embed de contrabando: nadie declara qué debe
# decir), y una entrada sin fence es FAIL (declaración colgante). Sin
# `embeds:` es EXIT 2 (verde-vacío vetado, QM8-4); sin la página o sin el
# árbol del submódulo, EXIT 2: no hay contra qué resolver.
#
# Sin transición: a diferencia del guard de coste (que espera a que el nucleus
# pinado conozca `--with`), aquí un pin por detrás de la página ES el defecto
# que se caza — la página del arco A2 sólo puede fusionarse en el PR del set
# que re-pina nucleus con la plantilla suite; sola, este guard la pone en rojo
# con el pin en el mensaje. Es información de certificación, no ruido (mismo
# régimen que umbrella-exit0-regressions con pines anteriores al fix).
#
# Uso: bash scripts/check_quickstart_embeds.sh [website/docs/quickstart.md]
#   QUICKSTART_NUCLEUS_DIR — el árbol que hace de <rootDir> (por defecto
#   `nucleus`, el submódulo pinado; apuntarlo a un checkout de main permite
#   comprobar la página contra el pin que VIENE antes del re-pin).
set -uo pipefail

cd "$(dirname "$0")/.."

# shellcheck source=scripts/lib/quickstart-fences.sh
source scripts/lib/quickstart-fences.sh

PAGE="${1:-website/docs/quickstart.md}"
NUCLEUS_DIR="${QUICKSTART_NUCLEUS_DIR:-nucleus}"
JARGON_SRC=scripts/check_served_jargon.sh

if [[ ! -f "$PAGE" ]]; then
  echo "check_quickstart_embeds: $PAGE no existe — el quickstart de la suite es un entregable, no se resuelve sobre nada" >&2
  exit 2
fi

# La regex de jerga es la del guard del HTML servido, leída de su fuente: una
# sola lista. Si la línea REGEX='…' cambia de forma, mejor EXIT 2 aquí que un
# guard que «no encuentra jerga» porque busca con una regex vacía.
JARGON_RE=$(sed -n "s/^REGEX='\(.*\)'\$/\1/p" "$JARGON_SRC" | head -1)
if [[ -z "$JARGON_RE" ]]; then
  echo "check_quickstart_embeds: no se pudo leer REGEX='…' de $JARGON_SRC — sin la regex de jerga del guard servido este guard quedaría ciego (¿cambió la forma de la línea?)" >&2
  exit 2
fi

declared=$(qs_front_matter_list "$PAGE" embeds)
if [[ -z "$declared" ]]; then
  echo "FAIL quickstart-embeds: $PAGE no declara \`embeds:\` en el front matter — cada fence \`file=…\` necesita su entrada ('<ruta[#Lx-Ly]> | token | …'): sin manifiesto no se puede decir si lo embebido es lo que la prosa explica (QM8-4)" >&2
  exit 2
fi

fences=$(qs_embeds "$PAGE")
n_fences=0
[[ -n "$fences" ]] && n_fences=$(printf '%s\n' "$fences" | wc -l | tr -d ' ')

pin=$(git -C "$NUCLEUS_DIR" log -1 --format='%h' 2>/dev/null || echo '?')

status=0
problems=""
problem() { problems+="FAIL quickstart-embeds: $*"$'\n'; status=1; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/quickstart-embeds.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
BLOCK="$TMP/block"

# resolve_block <file=…> — deja en $BLOCK el texto que el plugin embebería y
# en RESOLVED_PATH el fichero; si no puede, deja el motivo en RESOLVE_ERR y
# devuelve 1. Se llama SIN subshell (las variables tienen que sobrevivir).
# Réplica de remark-code-import 1.2.0:
# `^file=(.+?)(?:#(?:L(from)(-)?)?(?:L(to))?)?$`.
RESOLVE_ERR=""
RESOLVED_PATH=""
resolve_block() {
  local meta=$1 spec path from dash to abs total
  RESOLVE_ERR=""; RESOLVED_PATH=""; : > "$BLOCK"
  spec=${meta#file=}
  path=${spec%%#*}
  from=""; dash=""; to=""
  if [[ "$spec" == *"#"* ]]; then
    local range=${spec#*#}
    if [[ "$range" =~ ^L([0-9]+)(-)?(L([0-9]+))?$ ]]; then
      from=${BASH_REMATCH[1]}; dash=${BASH_REMATCH[2]}; to=${BASH_REMATCH[4]}
    elif [[ "$range" =~ ^L([0-9]+)$ ]]; then
      from=${BASH_REMATCH[1]}
    else
      RESOLVE_ERR="rango '#$range' que el plugin no sabe leer (formas válidas: #Lx, #Lx-, #Lx-Ly)"
      return 1
    fi
  fi
  case "$path" in
    "<rootDir>/"*) abs="$NUCLEUS_DIR/${path#<rootDir>/}" ;;
    /*) abs="$path" ;;
    *) abs="$(dirname "$PAGE")/$path" ;;
  esac
  RESOLVED_PATH=$abs
  if [[ ! -f "$abs" ]]; then
    RESOLVE_ERR="$abs no existe al pin $pin — en build sería ENOENT (remark-code-import) y website-ci rojo"
    return 1
  fi
  total=$(awk 'END{print NR}' "$abs")
  local start=${from:-1} end
  if [[ -z "$from" ]]; then
    end=$total
  elif [[ -z "$dash" ]]; then
    end=$start
  elif [[ -n "$to" ]]; then
    end=$to
  else
    end=$total
  fi
  if [[ $start -gt $total ]]; then
    RESOLVE_ERR="el rango empieza en L$start pero $abs tiene $total líneas al pin $pin — el bloque saldría VACÍO"
    return 1
  fi
  if [[ $end -gt $total ]]; then
    RESOLVE_ERR="el rango llega a L$end pero $abs tiene $total líneas al pin $pin — el plugin truncaría en silencio (el rango ya no describe el fichero)"
    return 1
  fi
  # removeRedundantIndentations: la sangría común de las líneas no vacías.
  sed -n "${start},${end}p" "$abs" | awk '
    { lines[NR] = $0
      if ($0 ~ /[^[:space:]]/) { match($0, /^[[:space:]]*/); if (min == "" || RLENGTH < min) min = RLENGTH } }
    END { if (min == "") min = 0; for (i = 1; i <= NR; i++) print substr(lines[i], min + 1) }
  ' > "$BLOCK"
}

# key_of <file=…> — la clave con la que la página declara la fence: la ruta
# tal cual, sin `file=` ni `<rootDir>/`.
key_of() { local k=${1#file=}; printf '%s\n' "${k#<rootDir>/}"; }

# --- cada fence: existe, cabe, sin jerga, dice lo declarado -----------------
seen_keys=""
summary=""
if [[ -n "$fences" ]]; then
  while IFS=$'\t' read -r line lang meta; do
    [[ -n "$meta" ]] || continue
    key=$(key_of "$meta")
    seen_keys+="$key"$'\n'
    decl=$(printf '%s\n' "$declared" | awk -F'[[:space:]]*\\|[[:space:]]*' -v k="$key" '$1 == k { print; exit }')
    if [[ -z "$decl" ]]; then
      problem "la fence \`$lang $meta\` (línea $line del cuerpo) no tiene entrada en \`embeds:\` (embed de contrabando — declara qué debe decir: '$key | token | …')"
      continue
    fi
    if ! resolve_block "$meta"; then
      problem "\`$meta\`: $RESOLVE_ERR"
      continue
    fi
    n_lines=$(wc -l < "$BLOCK" | tr -d ' ')
    hits=$(grep -noE "$JARGON_RE" "$BLOCK" | head -3 | paste -sd, - || true)
    if [[ -n "$hits" ]]; then
      problem "\`$meta\` embebe jerga interna al pin $pin ($hits; regex de $JARGON_SRC) — el HTML servido la publicaría; ¿el submódulo pinado va por detrás de la página?"
    fi
    first=$(head -1 "$BLOCK")
    last=$(tail -1 "$BLOCK")
    # tokens: campos 2..N separados por ` | `.
    toks=$(printf '%s\n' "$decl" | awk -F'[[:space:]]*\\|[[:space:]]*' '{ for (i = 2; i <= NF; i++) if ($i != "") print $i }')
    missing=""
    while IFS= read -r tok; do
      [[ -n "$tok" ]] || continue
      case "$tok" in
        ^*)
          want=${tok#^}
          [[ "$first" == "$want"* ]] || missing+="    primera línea no empieza por \`$want\` (es: \`$first\`)"$'\n'
          ;;
        *\$)
          want=${tok%\$}
          [[ "$last" == *"$want" ]] || missing+="    última línea no termina en \`$want\` (es: \`$last\`)"$'\n'
          ;;
        *)
          grep -qF -- "$tok" "$BLOCK" || missing+="    no contiene \`$tok\`"$'\n'
          ;;
      esac
    done <<<"$toks"
    if [[ -n "$missing" ]]; then
      problem "\`$meta\` ($n_lines líneas de $RESOLVED_PATH al pin $pin) no dice lo que la página explica:"$'\n'"$missing"
    fi
    summary+="$key ($n_lines líneas), "
  done <<<"$fences"
fi

# --- declaraciones colgantes -------------------------------------------------
while IFS= read -r d; do
  [[ -n "$d" ]] || continue
  k=$(printf '%s\n' "$d" | awk -F'[[:space:]]*\\|[[:space:]]*' '{ print $1 }')
  grep -qxF -- "$k" <<<"$seen_keys" || problem "\`embeds:\` declara '$k' pero la página no tiene ninguna fence \`file=<rootDir>/$k\` (declaración colgante)"
done <<<"$declared"

if [[ $n_fences -eq 0 ]]; then
  problem "$PAGE no tiene ninguna fence \`file=…\` — el arco A2 embebe lo generado; sin embeds no hay «lee lo que se generó» (verde-vacío vetado)"
fi

echo "quickstart-embeds: $n_fences fences file= resueltas contra $NUCLEUS_DIR (pin $pin): ${summary%, }"
if [[ $status -eq 0 ]]; then
  echo "check_quickstart_embeds: OK — lo que $PAGE embebe existe al pin y dice lo que su prosa explica"
  exit 0
fi
printf '%s' "$problems" >&2
echo >&2
echo "check_quickstart_embeds: FALLO — $PAGE embebe al pin $pin algo distinto de lo que explica (ver arriba). Si el submódulo nucleus va por detrás de la página, esta rama sólo puede fusionarse dentro del PR del set que lo re-pina." >&2
exit $status
