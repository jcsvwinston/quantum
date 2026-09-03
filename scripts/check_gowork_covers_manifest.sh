#!/usr/bin/env bash
# check_gowork_covers_manifest.sh — el go.work cubre TODO módulo publicable.
#
# El go.work del paraguas enlazaba diez módulos mientras el árbol tenía
# veintiocho y el manifiesto certificaba veinticinco (QM-7, auditoría
# 2026-09-03): los doce hermanos de nucleus y los cinco drivers de quark
# publicados en el arco D3 no estaban en el workspace, así que `go build
# ./nucleus/drivers/postgres/...` desde la raíz fallaba con «does not contain
# modules listed in go.work» y el build/vet/lockstep del CI nunca los
# compilaba — con EXIT=0, porque `go build` con módulos de menos no protesta.
#
# Qué exige (go.work ⊇ módulos publicables):
#   1. La raíz de cada repo (./quark ./nucleus ./orbit) está en `use`.
#   2. Cada módulo DESCUBIERTO en el árbol (todo go.mod salvo examples/,
#      website/, benchmarks/ y bugbash/ — el mismo filtro que manifest-guard
#      §3b) está en `use`.
#   3. Cada clave de quark_modules/nucleus_modules/orbit_modules resuelve a un
#      módulo del árbol (scripts/lib/manifest-modules.sh) y ese módulo está en
#      `use` — el manifiesto no puede certificar lo que el workspace no compila.
#   4. Cada entrada de `use` apunta a un directorio con go.mod (una entrada
#      colgante rompe el workspace entero).
# Lo que el go.work lleva DE MÁS (showcase_demo, la única app de ejemplo que la
# lane showcase-smoke arranca en modo workspace) no es fallo: se exige
# cobertura, no igualdad. Las exclusiones y su porqué están en el propio
# go.work.
set -uo pipefail

cd "$(dirname "$0")/.."

# shellcheck source=scripts/lib/manifest-modules.sh
source scripts/lib/manifest-modules.sh

status=0
uses=$(awk '/^use \(/ { inuse = 1; next } inuse && /^\)/ { inuse = 0 } inuse && $1 ~ /^\.\// { print $1 }' go.work)
if [[ -z "$uses" ]]; then
  echo "FAIL: go.work no tiene bloque use ( … ) con entradas ./… — sin workspace no hay set que compilar" >&2
  exit 1
fi

in_use() { grep -qx -- "./$1" <<<"$uses"; }

# 4. Entradas colgantes.
while read -r u; do
  [[ -n "$u" ]] || continue
  if [[ ! -f "${u#./}/go.mod" ]]; then
    echo "FAIL: go.work usa $u pero ${u#./}/go.mod no existe (¿módulo movido o submódulo sin inicializar?)" >&2
    status=1
  fi
done <<<"$uses"

for repo in quark nucleus orbit; do
  if [[ ! -f "$repo/go.mod" ]]; then
    echo "FAIL: $repo/go.mod no existe — submódulo sin inicializar (git submodule update --init)" >&2
    status=1
    continue
  fi
  # 1. Raíz.
  if in_use "$repo"; then
    echo "OK: go.work usa ./$repo (raíz)"
  else
    echo "FAIL: go.work no usa ./$repo — la raíz del repo es el módulo que el set certifica" >&2
    status=1
  fi
  # 2. Descubiertos en el árbol.
  for mod in $(mm_discover "$repo"); do
    if in_use "$repo/$mod"; then
      echo "OK: go.work usa ./$repo/$mod (módulo publicable del árbol)"
    else
      echo "FAIL: go.work no usa ./$repo/$mod (módulo publicable del árbol de $repo; añádelo al bloque use del go.work)" >&2
      status=1
    fi
  done
  # 3. Declarados en el manifiesto.
  for key in $(mm_keys "${repo}_modules"); do
    dir=$(mm_path_for_key "$repo" "$key") || { status=1; continue; }
    if [[ -z "$dir" ]]; then
      echo "FAIL: versions.yaml ${repo}_modules.$key no corresponde a ningún go.mod del árbol de $repo" >&2
      status=1
    elif ! in_use "$repo/$dir"; then
      echo "FAIL: go.work no usa ./$repo/$dir (declarado en versions.yaml ${repo}_modules.$key)" >&2
      status=1
    fi
  done
done

if [[ $status -ne 0 ]]; then
  echo >&2
  echo "check_gowork_covers_manifest: FALLO — el go.work no cubre todos los módulos publicables (ver arriba). Regla: go.work ⊇ {raíz de cada repo} ∪ {todo go.mod del árbol salvo examples/benchmarks/bugbash} ∪ {claves del manifiesto}." >&2
  exit 1
fi
echo "check_gowork_covers_manifest: OK — el go.work ($(grep -c . <<<"$uses") entradas) cubre la raíz de los tres repos, todo módulo publicable del árbol y toda clave de *_modules del manifiesto"
