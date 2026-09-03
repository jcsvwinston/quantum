#!/usr/bin/env bash
# gowork-patterns.sh — los patrones `./modulo/...` de TODOS los módulos del
# go.work, en una línea, para `go build` / `go vet` desde la raíz del paraguas.
#
# El root del workspace no es un módulo Go, así que `go build ./...` falla
# («does not contain modules listed in go.work») y hay que pasar un patrón
# por módulo. Un módulo anidado (drivers/sqlite, providers/ldap, quarkbridge…)
# es un módulo aparte y NO lo cubre el patrón de su padre: `./nucleus/...`
# compila 1 de los 14 módulos de nucleus y sale igualmente con EXIT=0. La
# lista escrita a mano en integration.yml y en el README fue una atrás dos
# veces (RT-7, QM-7); desde aquí sale del go.work, que es la única fuente.
#
#   go build $(bash scripts/gowork-patterns.sh)
#
# Utillaje, no guard: no tiene veredicto sobre el árbol (excluido del escaneo
# anti-fósil con su porqué en scripts/lib/guard-registry.sh).
set -euo pipefail
cd "$(dirname "$0")/.."

# Cada línea `\t./ruta` del bloque use ( … ) → `./ruta/...`
awk '
  /^use \(/ { inuse = 1; next }
  inuse && /^\)/ { inuse = 0 }
  inuse && $1 ~ /^\.\// { printf "%s/... ", $1 }
' go.work | sed 's/ $//'
echo
