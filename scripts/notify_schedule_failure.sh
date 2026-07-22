#!/usr/bin/env bash
# notify_schedule_failure.sh — la lane programada roja no puede morir en el
# email default de Actions (QM8-1: «la lane roja solo notifica por el email
# default» — señal que nadie mira). Los jobs de aviso de los dos workflows
# programados (integration.yml y suite-integral.yml) lo ejecutan cuando la
# corrida de schedule falla O se cancela (concurrency): abre O actualiza un
# issue, sin duplicar.
#
# Uso: bash scripts/notify_schedule_failure.sh <workflow> <run_url>
#
# Dedupe (MAQ-4/(b)): la búsqueda es SERVER-SIDE y ACOTADA — no un escaneo de
# `gh issue list --limit 100` sin filtro (que con >100 issues abiertos se salta
# el issue del schedule y DUPLICA). Los issues de este canal llevan la etiqueta
# estable `lane-schedule-failure`; la búsqueda filtra por esa etiqueta Y por el
# nombre del workflow en el título, ambos server-side. El prefijo estable lleva
# corchetes (`[lane] …`) que rompen la sintaxis de search de GitHub, así que el
# término de búsqueda es la parte SIN corchetes (`fallo del schedule <workflow>`)
# y el prefijo exacto se confirma en cliente sobre el set ya reducido.
#
# Requiere `gh` autenticado (en Actions: GH_TOKEN=${{ github.token }} y
# permissions: issues: write en el job). DRY_RUN=1 imprime las mutaciones en
# vez de ejecutarlas (prueba local de la lógica sin abrir issues de verdad).
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "uso: $0 <workflow> <run_url>" >&2
  exit 2
fi

workflow=$1
run_url=$2
fecha=$(date -u +%F)
LABEL="lane-schedule-failure"
prefix="[lane] fallo del schedule $workflow"
title="$prefix $fecha"
body="Corrida programada de \`$workflow\` en ROJO o CANCELADA ($fecha, UTC): $run_url

La corrida del schedule existe para que la deriva EXTERNA aflore sin esperar a
un PR (tags nuevos en los remotos, set que deja de compilar, \`go install @tag\`
roto). Un rojo aquí sin PR que lo explique es el disparador de mini-pasada del
runbook (docs/AUDITORIA_CONTINUA.md §6): dos corridas rojas seguidas → mini-
pasada dirigida. Cerrar este issue al dejar la lane en verde, enlazando el fix."

run_mut() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "DRY-RUN: gh $*"
  else
    gh "$@"
  fi
}

# 0. La etiqueta estable del canal debe existir (el dedup server-side y el
#    `issue create --label` se apoyan en ella). Idempotente: si ya existe, gh
#    devuelve error y se ignora (best-effort — no aborta el aviso).
ensure_label() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo "DRY-RUN: gh label create $LABEL (idempotente; se ignora si ya existe)"
    return 0
  fi
  gh label create "$LABEL" \
     --description "Aviso automático de schedule rojo/cancelado (QM8-1/MAQ-4)" \
     --color B60205 >/dev/null 2>&1 || true
}
ensure_label

# 1. Issue abierto existente de ESTE workflow — búsqueda server-side acotada por
#    etiqueta + término de título (bracket-free), luego confirmación del prefijo
#    exacto en cliente sobre el set ya reducido. `|| true`: sin resultados, grep
#    sale 1 y el `set -e` lo tomaría como fallo.
search_term="fallo del schedule $workflow in:title"
existing=$(gh issue list --state open --label "$LABEL" --search "$search_term" \
             --limit 100 --json number,title \
             --jq '.[] | "\(.number)\t\(.title)"' \
           | { grep -F "$prefix" || true; } | head -1 | cut -f1)

if [[ -n "$existing" ]]; then
  echo "issue abierto existente #$existing (etiqueta $LABEL) — se añade la corrida de hoy como comentario (sin duplicar)"
  run_mut issue comment "$existing" --body "$body"
else
  echo "sin issue abierto para '$prefix' (etiqueta $LABEL) — se crea"
  run_mut issue create --title "$title" --label "$LABEL" --body "$body"
fi
