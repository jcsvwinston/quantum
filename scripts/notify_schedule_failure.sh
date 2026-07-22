#!/usr/bin/env bash
# notify_schedule_failure.sh — la lane programada roja no puede morir en el
# email default de Actions (QM8-1: «la lane roja solo notifica por el email
# default» — señal que nadie mira). Los jobs de aviso de los dos workflows
# programados (integration.yml y suite-integral.yml) lo ejecutan con
# `if: failure()` en corridas de schedule: abre O actualiza un issue, sin
# duplicar.
#
# Uso: bash scripts/notify_schedule_failure.sh <workflow> <run_url>
#
# Dedupe por título: se busca un issue ABIERTO cuyo título empiece por el
# prefijo estable "[lane] fallo del schedule <workflow>". Si existe, se añade
# un comentario con la fecha y el run nuevos (el issue acumula la historia de
# la racha roja — útil para el disparador «lane roja 2 corridas» del runbook
# §6); si no, se crea con la fecha en el título. El filtrado se hace sobre
# `gh issue list --json` en local (sin sintaxis de search de GitHub: los
# corchetes del prefijo la rompen).
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
prefix="[lane] fallo del schedule $workflow"
title="$prefix $fecha"
body="Corrida programada de \`$workflow\` en ROJO ($fecha, UTC): $run_url

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

# Issue abierto existente con el prefijo estable (el más reciente primero).
existing=$(gh issue list --state open --limit 100 --json number,title \
             --jq '.[] | "\(.number)\t\(.title)"' \
           | { grep -F "$prefix" || true; } | head -1 | cut -f1)

if [[ -n "$existing" ]]; then
  echo "issue abierto existente #$existing — se añade la corrida de hoy como comentario (sin duplicar)"
  run_mut issue comment "$existing" --body "$body"
else
  echo "sin issue abierto para '$prefix' — se crea"
  run_mut issue create --title "$title" --body "$body"
fi
