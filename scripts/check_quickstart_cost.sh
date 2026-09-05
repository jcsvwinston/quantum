#!/usr/bin/env bash
# check_quickstart_cost.sh — el quickstart de la suite cabe en 5 comandos y 5
# conceptos (gate del arco A2: «starter de suite y primer endpoint en 5 min»).
#
# La página website/docs/quickstart.md era «the suite in ~15 minutes»: 22
# líneas de shell (5× `go mod tidy`, 5× `go run .`, 4× `go get`), tres
# ficheros escritos a mano y una docena de APIs que explicar antes del primer
# curl (auditoría de madurez 2026-09-03, suite.md:162). Nadie medía el coste,
# así que crecía. Este guard lo mide sobre la FUENTE markdown —no sobre el HTML
# construido: Docusaurus no arranca en todos los entornos y la fuente es lo que
# el autor edita— con el parser compartido con la lane quickstart-smoke
# (scripts/lib/quickstart-fences.sh): lo que aquí cuenta como comando es
# exactamente lo que la lane ejecuta.
#
# Qué cuenta y por qué es defendible:
#   - COMANDOS: líneas de las fences ```bash/```sh/```shell, con las
#     continuaciones `\` unidas, sin vacías ni comentarios, más un comando por
#     `<GoInstallCLI />` (renderiza `go install …@<tag>`). Techo
#     QUICKSTART_MAX_COMMANDS=5: go install · nucleus new · cd + go run · curl
#     GET · curl POST. Abrir /admin es prosa, no un comando.
#   - CONCEPTOS: identificadores cualificados de la suite que la página nombra
#     (`nucleus.New`, `orbit.Module`…), AGRUPADOS por reglas fijas, impresas,
#     para que el número no sea un juicio:
#       · una cadena de builder cuenta como su constructor: `nucleus.New()
#         .FromConfigFile().Mount().Start()` = 1 (los métodos no son
#         identificadores cualificados, así que el parser ya no los ve);
#       · `<pkg>.Config` cuenta con el constructor de su paquete
#         (`orbit.Module` + `orbit.Config` = 1);
#       · `<pkg>.Register` (genérico) cuenta con su `New`
#         (`quarkdatasource.New` + `Register[T]` = 1);
#       · el paquete del lector (`shop.*`) no es de la suite y no cuenta;
#       · lo que una fence `file=…` importa en build NO está en la fuente y
#         no cuenta: es «leer lo que se generó».
#     La página DECLARA sus conceptos en el front matter (`concepts:`, espejo
#     del `covers:` de nucleus) y el guard cruza en las dos direcciones: un
#     grupo presente sin declarar es FAIL (concepto de contrabando) y un
#     concepto declarado que la página no nombra es FAIL (declaración
#     colgante, como los `covers:` colgantes de nucleus). Techo
#     QUICKSTART_MAX_CONCEPTS=5.
#
# Salida: `quickstart-cost: N comandos (max 5) · M conceptos (max 5): …`.
#   EXIT 1 — un techo superado o el cruce con `concepts:` roto (lista al lado).
#   EXIT 2 — la página no existe o no declara `concepts:` (verde-vacío vetado,
#            QM8-4: una página sin manifiesto no se puede contar).
#
# Transición AUTO-EXPIRANTE ligada al pin de nucleus (mismo mecanismo que
# check_retired_claims.sh): la página no puede bajar a 5 comandos hasta que
# `nucleus new --with …` exista, y eso llega con el tag de nucleus posterior a
# TRANSITIONAL_MAX. Mientras `modules.nucleus` de versions.yaml sea ≤ ese pin,
# el guard MIDE e informa (AVISO, EXIT 0) — la cifra ya queda en cada corrida;
# al re-pinar, la excepción muere sola y el techo se exige (la lane
# quickstart-smoke se enciende con el mismo pin, por el mismo criterio). Para
# exigirlo antes en local (quien reescriba la página): QUICKSTART_COST_ENFORCE=1.
#
# Uso: bash scripts/check_quickstart_cost.sh website/docs/quickstart.md
set -uo pipefail

cd "$(dirname "$0")/.."

# shellcheck source=scripts/lib/quickstart-fences.sh
source scripts/lib/quickstart-fences.sh

PAGE="${1:-website/docs/quickstart.md}"
MAX_COMMANDS="${QUICKSTART_MAX_COMMANDS:-5}"
MAX_CONCEPTS="${QUICKSTART_MAX_CONCEPTS:-5}"

if [[ ! -f "$PAGE" ]]; then
  echo "check_quickstart_cost: $PAGE no existe — el quickstart de la suite es un entregable, no se cuenta sobre nada" >&2
  exit 2
fi

# --- transición ligada al pin (ver cabecera) --------------------------------
# El último pin de nucleus cuyo `nucleus new` NO conoce `--with`: v1.24.0
# (verificado con `nucleus new --help` al pin, Quantum 1.28.0). Subirlo es una
# decisión con porqué (el tag que trae --with se retrasó), no una limpieza.
TRANSITIONAL_MAX='v1.24.0'
NUCLEUS_PIN=$(sed -n 's/^  nucleus:[[:space:]]*"\(v[0-9.]*\)".*/\1/p' versions.yaml 2>/dev/null | head -1)
enforce=1
if [[ "${QUICKSTART_COST_ENFORCE:-0}" != "1" && -n "$NUCLEUS_PIN" \
      && "$(printf '%s\n' "$NUCLEUS_PIN" "$TRANSITIONAL_MAX" | sort -V | tail -1)" == "$TRANSITIONAL_MAX" ]]; then
  enforce=0
fi

# --- comandos ---------------------------------------------------------------
commands=$(qs_commands "$PAGE")
n_commands=0
[[ -n "$commands" ]] && n_commands=$(printf '%s\n' "$commands" | wc -l | tr -d ' ')

# --- conceptos: identificadores → grupos ------------------------------------
ids=$(qs_identifiers "$PAGE")

# constructor_of <pkg> — el identificador constructor del paquete SI la página
# lo nombra: Module (orbit, nucleus) antes que New. Vacío si no hay ninguno.
constructor_of() {
  local pkg=$1 c
  for c in Module New; do
    if grep -qxF "$pkg.$c" <<<"$ids"; then printf '%s.%s\n' "$pkg" "$c"; return 0; fi
  done
  return 1
}

# group_of <ident> — el grupo (concepto) al que pertenece un identificador.
group_of() {
  local id=$1 pkg=${1%%.*} name=${1#*.} ctor
  case "$name" in
    Config|Register)
      if ctor=$(constructor_of "$pkg"); then printf '%s\n' "$ctor"; return; fi
      ;;
  esac
  printf '%s\n' "$id"
}

groups=""       # "grupo" por línea, sin repetir, en orden de aparición
members=""      # "grupo<TAB>ident" por línea (para imprimir el porqué)
if [[ -n "$ids" ]]; then
  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    g=$(group_of "$id")
    members+="$g"$'\t'"$id"$'\n'
    grep -qxF -- "$g" <<<"$groups" || groups+="$g"$'\n'
  done <<<"$ids"
fi
groups=${groups%$'\n'}
n_groups=0
[[ -n "$groups" ]] && n_groups=$(printf '%s\n' "$groups" | wc -l | tr -d ' ')

# group_label <grupo> — «orbit.Module (+orbit.Config)» para que el conteo
# explique de dónde sale.
group_label() {
  local g=$1 extra
  extra=$(printf '%s' "$members" | awk -F'\t' -v g="$g" '$1 == g && $2 != g { printf "%s%s", (n++ ? ", " : ""), $2 }')
  if [[ -n "$extra" ]]; then printf '%s (+%s)' "$g" "$extra"; else printf '%s' "$g"; fi
}

declared=$(qs_front_matter_list "$PAGE" concepts)
n_declared=0
[[ -n "$declared" ]] && n_declared=$(printf '%s\n' "$declared" | wc -l | tr -d ' ')

# --- veredicto --------------------------------------------------------------
status=0
problems=""

if [[ $n_commands -gt $MAX_COMMANDS ]]; then
  problems+="FAIL quickstart-cost: $n_commands comandos > $MAX_COMMANDS (max) — los comandos de la página:"$'\n'
  problems+="$(printf '%s\n' "$commands" | sed 's/^/    /')"$'\n'
  status=1
fi

if [[ $n_declared -eq 0 ]]; then
  problems+="FAIL quickstart-cost: $PAGE no declara \`concepts:\` en el front matter — sin manifiesto de conceptos no hay conteo honesto (QM8-4); los grupos que la página nombra hoy:"$'\n'
  if [[ -n "$groups" ]]; then
    while IFS= read -r g; do problems+="    $(group_label "$g")"$'\n'; done <<<"$groups"
  else
    problems+="    (ninguno)"$'\n'
  fi
  [[ $status -eq 0 ]] && status=2
else
  if [[ $n_declared -gt $MAX_CONCEPTS ]]; then
    problems+="FAIL quickstart-cost: $n_declared conceptos declarados > $MAX_CONCEPTS (max): $(printf '%s\n' "$declared" | paste -sd, - | sed 's/,/, /g')"$'\n'
    status=1
  fi
  undeclared=""
  if [[ -n "$groups" ]]; then
    while IFS= read -r g; do
      grep -qxF -- "$g" <<<"$declared" || undeclared+="    $(group_label "$g")"$'\n'
    done <<<"$groups"
  fi
  if [[ -n "$undeclared" ]]; then
    problems+="FAIL quickstart-cost: la página nombra conceptos que \`concepts:\` no declara (concepto de contrabando — decláralo o quítalo de la página):"$'\n'"$undeclared"
    status=1
  fi
  dangling=""
  while IFS= read -r d; do
    [[ -n "$d" ]] || continue
    grep -qxF -- "$d" <<<"$groups" || dangling+="    $d"$'\n'
  done <<<"$declared"
  if [[ -n "$dangling" ]]; then
    problems+="FAIL quickstart-cost: \`concepts:\` declara conceptos que la página no nombra (declaración colgante):"$'\n'"$dangling"
    status=1
  fi
fi

summary_concepts="(ninguno)"
if [[ -n "$groups" ]]; then
  summary_concepts=""
  while IFS= read -r g; do summary_concepts+="$(group_label "$g"), "; done <<<"$groups"
  summary_concepts=${summary_concepts%, }
fi
echo "quickstart-cost: $n_commands comandos (max $MAX_COMMANDS) · $n_groups conceptos (max $MAX_CONCEPTS, declarados $n_declared): $summary_concepts"

if [[ $status -eq 0 ]]; then
  echo "check_quickstart_cost: OK — $PAGE cabe en $MAX_COMMANDS comandos y $MAX_CONCEPTS conceptos declarados"
  exit 0
fi

if [[ $enforce -eq 0 ]]; then
  echo "AVISO: el techo no se exige todavía — modules.nucleus=$NUCLEUS_PIN ≤ $TRANSITIONAL_MAX (el pin aún no trae \`nucleus new --with\`); al re-pinar por encima, lo que sigue es FAIL:" >&2
  printf '%s' "$problems" | sed 's/^FAIL /  /' >&2
  echo "check_quickstart_cost: OK (transición ligada al pin — medido, no exigido)"
  exit 0
fi

printf '%s' "$problems" >&2
echo >&2
echo "check_quickstart_cost: FALLO — $PAGE supera el techo o su \`concepts:\` no cuadra con lo que nombra (ver arriba)." >&2
exit $status
