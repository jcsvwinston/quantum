#!/usr/bin/env bash
# sitebench.sh — el banco del sitio de la suite (arco A11, S0).
#
# La mitad del arco A11 que vive en el paraguas: lo que el sitio explica a
# quien todavía no ha elegido la suite («Why Quantum», con cifras), lo que le
# enseña a construir (tres tutoriales ejecutados), cómo llegar desde otra pila
# (guías de migración desde Gin+GORM y desde Django), la referencia generada,
# el registro de sets publicados y el catálogo de `nucleus add`.
#
# Mismo contrato que los bancos Go de los productos (apibench, adminbench,
# enterprisebench…): cada control tiene un id, una familia, un título, el
# veredicto REGISTRADO (present/partial/absent), una nota si no es present, y
# una sonda que MIDE. El banco falla cuando lo medido no es lo registrado:
# cerrar un hueco lo pone rojo pidiendo mover la cifra, que es lo que mantiene
# honesta la página. Para un hueco, la sonda busca la capacidad bajo los
# nombres que usan otros sitios y dice qué buscó — la forma honesta de medir
# una ausencia.
#
# Uso: bash tests/sitebench/sitebench.sh [--table]   (desde la raíz del paraguas)
#   --table  imprime la tabla por familias y el catálogo en markdown.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

DOCS=website/docs
SIDEBAR=website/sidebarsStart.ts
CONFIG=website/docusaurus.config.ts
WF=.github/workflows

# ---- sondas: cada una imprime su veredicto en la última línea y explica en las anteriores

# La página «Why Quantum»: un fichero de la instancia start cuyo título
# hable del porqué o compare, y que esté en el recorrido del lector.
why_page() {
  grep -lEi '^title:.*(why|compar|versus| vs\.? )' "$DOCS"/*.md "$DOCS"/*.mdx 2>/dev/null | head -1
}

probe_ST01() {
  local p; p=$(why_page)
  if [[ -z "$p" ]]; then echo "  sin página: ningún title de $DOCS habla de why/compar/versus"; echo absent; return; fi
  local id; id=$(basename "${p%.*}")
  if grep -q "'$id'" "$SIDEBAR"; then echo present; else echo "  $p existe y no está en $SIDEBAR"; echo partial; fi
}

probe_ST02() {
  local p; p=$(why_page)
  [[ -n "$p" ]] || { echo "  sin página que medir"; echo absent; return; }
  # Cada cifra de la página con su fuente, y un guard que las cruce.
  if grep -lq "$(basename "$p")" scripts/check_*.sh 2>/dev/null; then echo present
  else echo "  ningún guard de scripts/ lee $p: sus cifras no tienen quien las compruebe"; echo partial; fi
}

probe_ST03() {
  local p; p=$(why_page)
  [[ -n "$p" ]] || { echo "  sin página que medir"; echo absent; return; }
  local n=0 alt
  for alt in Gin GORM Echo Django Rails Laravel Spring; do grep -q "$alt" "$p" && n=$((n+1)); done
  if [[ $n -ge 4 ]]; then echo present; else echo "  la página nombra $n de 7 alternativas (Gin, GORM, Echo, Django, Rails, Laravel, Spring)"; echo partial; fi
}

# Un tutorial: una página cuyo título lo diga, y una lane que ejecute sus
# bloques (el patrón del quickstart: scripts/ci/quickstart_smoke.sh extrae los
# curl de la página).
tutorial_probe() {
  local what=$1 re=$2 page lane
  page=$(grep -lEi "^title:.*($re)" "$DOCS"/*.md "$DOCS"/*.mdx 2>/dev/null | head -1)
  if [[ -z "$page" ]]; then echo "  sin página: ningún title de $DOCS casa /$re/ ($what)"; echo absent; return; fi
  lane=$(grep -l "$(basename "$page")" "$WF"/*.yml scripts/ci/*.sh 2>/dev/null | head -1)
  if [[ -n "$lane" ]]; then echo present; else echo "  $page existe y ninguna lane la ejecuta"; echo partial; fi
}
probe_ST04() { tutorial_probe "SaaS multi-tenant" 'multi-?tenant'; }
probe_ST05() { tutorial_probe "API-only" 'api[- ]only|json api'; }
probe_ST06() { tutorial_probe "monolito MVC" 'mvc|monolith'; }
probe_ST07() { tutorial_probe "migración desde Gin+GORM" 'gin|gorm'; }
probe_ST08() { tutorial_probe "migración desde Django" 'django'; }

probe_ST09() {
  # Referencia generada: un generador en scripts/ que escriba páginas de API
  # desde las superficies congeladas de los productos, y un drift check.
  local gen; gen=$(grep -lE 'api_exported_symbols|apisurface\.json' scripts/*.sh scripts/ci/*.sh scripts/website/*.sh 2>/dev/null | head -1)
  if [[ -z "$gen" ]]; then echo "  ningún script lee nucleus/contracts/baseline/api_exported_symbols.txt ni quark/acceptance/apisurface.json para generar referencia"; echo absent; return; fi
  echo "  $gen lee una superficie congelada"; echo partial
}

probe_ST10() {
  if grep -qE 'blog:[[:space:]]*false' "$CONFIG"; then echo "  $CONFIG: blog: false — las notas de cada set sólo viven en las releases de GitHub"; echo absent; return; fi
  local sets posts
  sets=$(git tag -l 'v1.*' | grep -cE '^v[0-9]+\.[0-9]+\.[0-9]+$')
  posts=$(ls website/blog 2>/dev/null | grep -c . || true)
  if [[ ${posts:-0} -ge $sets ]]; then echo present; else echo "  $posts entradas para $sets sets"; echo partial; fi
}

probe_ST11() {
  # El catálogo de `nucleus add` en el sitio, generado desde la tabla del CLI.
  if grep -rlqiE 'nucleus add' "$DOCS" 2>/dev/null && grep -rlqiE '^title:.*catalog' "$DOCS" 2>/dev/null; then echo partial; return; fi
  echo "  ninguna página de $DOCS es el catálogo (title /catalog/); la lista vive sólo en internal/knownproviders de nucleus"; echo absent
}

probe_ST12() {
  # La frase que A11 contradice: el sitio dice que la suite no compite en
  # amplitud de plugins. Mientras el catálogo no exista es cierta; al
  # cerrar A11 tiene que reconciliarse con lo que el catálogo publica.
  if grep -qi 'breadth of plugins' "$DOCS/what-is-quantum.md"; then
    echo "  $DOCS/what-is-quantum.md: «not breadth of plugins» — el catálogo de A11 la deja en duda; reconciliarla con un guard de afirmaciones"; echo partial
  else echo present; fi
}

# ---- el banco: id|familia|veredicto registrado|título|nota
CONTROLS=(
  "ST-01|why|absent|a «Why Quantum» page in the reader's path|ningún title de website/docs habla de por qué o compara; what-is-quantum.md tiene un «cuándo no usarla» sin cifras"
  "ST-02|why|absent|every number on it has a source a guard checks|no hay página, así que no hay cifras ni guard que las ate a su fuente"
  "ST-03|why|absent|the comparison names its alternatives|no hay comparación en el sitio de la suite (quark tiene la suya propia en reference/comparison.mdx)"
  "ST-04|tutorials|absent|a multi-tenant SaaS tutorial executed in CI|no existe; sólo el quickstart se ejecuta (quickstart_smoke.sh)"
  "ST-05|tutorials|absent|an API-only tutorial executed in CI|no existe en el sitio de la suite; nucleus minimal-api.md es la página más cercana y no es un tutorial"
  "ST-06|tutorials|absent|an MVC monolith tutorial executed in CI|no existe"
  "ST-07|migration|absent|a migration guide from Gin+GORM with executed snippets|no existe; «coming from»/«migrating from» sólo encuentra notas de versión"
  "ST-08|migration|absent|a migration guide from Django with executed snippets|no existe"
  "ST-09|reference|absent|an API reference generated from the frozen surfaces, with a drift check|las páginas de API de quark se escriben a mano y las de nucleus (docs/reference/api) son prosa interna fuera del sitio"
  "ST-10|reference|absent|one post per certified set|docusaurus.config.ts tiene blog: false; las notas del set sólo están en las releases de GitHub"
  "ST-11|catalog|absent|the catalog of nucleus add on the site, generated from the CLI's table|no hay página de catálogo; la lista vive compilada en nucleus/internal/knownproviders"
  "ST-12|catalog|partial|no claim on the site contradicts the catalog|what-is-quantum.md dice que la suite no compite en «breadth of plugins»: el catálogo de A11 la pone en duda y nada la reconcilia"
)

table=0
[[ "${1:-}" == "--table" ]] && table=1
fail=0
declare -a ROWS
for c in "${CONTROLS[@]}"; do
  IFS='|' read -r id fam want title note <<<"$c"
  out=$("probe_${id/-/}")
  got=$(printf '%s\n' "$out" | tail -1)
  why=$(printf '%s\n' "$out" | sed '$d')
  if [[ "$want" != "present" && -z "$note" ]]; then echo "FAIL: $id es $want sin nota" >&2; fail=1; fi
  if [[ "$got" != "$want" ]]; then
    echo "FAIL: $id ($title) mide «$got» y el banco registra «$want».${why:+
$why}
  Si acaba de ganar terreno, de eso se trata: mueve el veredicto registrado y la cifra de la página en el mismo cambio." >&2
    fail=1
  fi
  ROWS+=("$id|$fam|$got|$title|$note")
done

present=0; partial=0; absent=0
for r in "${ROWS[@]}"; do case "$(cut -d'|' -f3 <<<"$r")" in present) present=$((present+1));; partial) partial=$((partial+1));; absent) absent=$((absent+1));; esac; done
total=${#ROWS[@]}

if [[ $table -eq 1 ]]; then
  echo "**$present of $total controls present. $partial partial. $absent absent.**"
  echo
  echo "| family | present | partial | absent |"
  echo "|---|---|---|---|"
  for fam in $(printf '%s\n' "${ROWS[@]}" | cut -d'|' -f2 | awk '!s[$0]++'); do
    p=0; pa=0; a=0
    for r in "${ROWS[@]}"; do
      [[ "$(cut -d'|' -f2 <<<"$r")" == "$fam" ]] || continue
      case "$(cut -d'|' -f3 <<<"$r")" in present) p=$((p+1));; partial) pa=$((pa+1));; absent) a=$((a+1));; esac
    done
    echo "| $fam | $p | $pa | $a |"
  done
  echo
  echo "| id | control | verdict | what is missing |"
  echo "|---|---|---|---|"
  for r in "${ROWS[@]}"; do IFS='|' read -r id fam got title note <<<"$r"; echo "| \`$id\` | $title | **$got** | ${note:-—} |"; done
fi

[[ $fail -eq 0 ]] || exit 1
echo "OK: sitebench — $present/$total presentes ($partial partial, $absent absent), lo medido es lo registrado"
