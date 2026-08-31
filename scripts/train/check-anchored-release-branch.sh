#!/usr/bin/env bash
# check-anchored-release-branch.sh — detecta la RAMA DE RELEASE ANCLADA al
# main viejo (RT-1; la trampa que ya mordió dos veces: nucleus #391→#395 y
# orbit #338→#339).
#
# El escenario: en un repo multi-módulo se fusiona primero el release PR de un
# módulo (providers/ldap, agent, quarkdatasource…) y release-please NO rebasa
# la rama del release del ROOT, que quedó cortada del main ANTERIOR. Si ese PR
# se fusiona tal cual, el tag del root sale SIN el tag del módulo como
# ancestro — y el manifest-guard §3/§3b del paraguas rechaza el set entero.
#
# Qué hace: para el release PR del root abierto (o el PR que se le pase),
# comprueba con `git merge-base --is-ancestor` que el ÚLTIMO tag de CADA
# módulo (<prefijo>/vX.Y.Z) es ancestro del head del PR. Si alguno no lo es,
# imprime la receta cerrar+borrar+re-dispatch y sale con EXIT=1.
#
# Uso: check-anchored-release-branch.sh <repo> [<numero-pr>]
#   <repo>  owner/nombre o nombre corto (se asume jcsvwinston/<nombre>).
#   Sin <numero-pr>, busca el release PR abierto del root (el de título
#   «chore(main): release [github.com/…] X.Y.Z» sin subdirectorio de módulo).
#
# Solo LEE (clona a un directorio temporal): no toca los submódulos del
# paraguas ni el remoto. Es un verificador de un estado del tren, no un guard
# de certificación — su momento es JUSTO ANTES de fusionar el root.
set -euo pipefail

OWNER_DEFAULT="jcsvwinston"
REPO="${1:-}"
PRNUM="${2:-}"
if [ -z "$REPO" ]; then
  echo "uso: check-anchored-release-branch.sh <repo> [<numero-pr>]" >&2
  exit 64
fi
case "$REPO" in */*) : ;; *) REPO="$OWNER_DEFAULT/$REPO" ;; esac

say() { printf '%s\n' "$*"; }

say "== check-anchored-release-branch: $REPO =="

# --- 1. Localizar el release PR del root ------------------------------------
if [ -z "$PRNUM" ]; then
  say "  → gh pr list -R $REPO --label 'autorelease: pending' (buscando el PR del root)"
  # El PR del root es el que NO nombra un subdirectorio de módulo en el
  # título: «release X.Y.Z» o «release github.com/<owner>/<repo> X.Y.Z».
  PRNUM=$(gh pr list -R "$REPO" --label "autorelease: pending" \
      --json number,title \
      --jq "[.[] | select(.title | test(\"^chore\\\\([^)]*\\\\): release (github.com/$REPO )?[0-9]+\\\\.[0-9]+\\\\.[0-9]+\$\"))] | .[0].number // empty")
  if [ -z "$PRNUM" ]; then
    say "OK: no hay release PR del root abierto en $REPO — nada que verificar."
    exit 0
  fi
fi

head_ref=$(gh pr view "$PRNUM" -R "$REPO" --json headRefName --jq .headRefName)
head_oid=$(gh pr view "$PRNUM" -R "$REPO" --json headRefOid --jq .headRefOid)
title=$(gh pr view "$PRNUM" -R "$REPO" --json title --jq .title)
say "  PR del root: #$PRNUM «$title» (rama: $head_ref, head: ${head_oid:0:8})"

# --- 2. Clon temporal con tags + head del PR --------------------------------
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
say "  → git clone --filter=blob:none (temporal, solo lectura) + fetch de tags y del head"
git clone --quiet --filter=blob:none --no-checkout "https://github.com/$REPO.git" "$tmp/clone"
# El head se trae por la ref del PR (refs/pull/N/head), que existe siempre —
# también con la rama del bot ya borrada.
git -C "$tmp/clone" fetch --quiet --tags origin "refs/pull/$PRNUM/head"
git -C "$tmp/clone" rev-parse -q --verify "$head_oid^{commit}" >/dev/null \
  || { say "MAL: el head del PR ($head_oid) no llegó con refs/pull/$PRNUM/head"; exit 1; }

# --- 3. Último tag de cada módulo → ¿ancestro del head? ---------------------
# Prefijos de módulo = todo lo que taggea como <prefijo>/vX.Y.Z (agent,
# server, proto, quarkbridge, quarkdatasource, providers/ldap…).
prefixes=$(git -C "$tmp/clone" tag -l '*/v*' \
  | grep -E '/v[0-9]+\.[0-9]+\.[0-9]+$' \
  | sed -E 's|/v[0-9]+\.[0-9]+\.[0-9]+$||' | sort -u)

if [ -z "$prefixes" ]; then
  say "OK: $REPO no tiene tags de módulo (<prefijo>/vX.Y.Z) — nada que anclar."
  exit 0
fi

st=0
anchored=""
for p in $prefixes; do
  last=$(git -C "$tmp/clone" tag -l "$p/v*" \
    | grep -E "^$p/v[0-9]+\.[0-9]+\.[0-9]+$" | sort -V | tail -1)
  [ -n "$last" ] || continue
  if git -C "$tmp/clone" merge-base --is-ancestor "$last" "$head_oid"; then
    say "  OK  $last es ancestro del head del PR"
  else
    say "  MAL $last NO es ancestro del head del PR — rama anclada al main viejo"
    anchored="$anchored $last"
    st=1
  fi
done

if [ "$st" -ne 0 ]; then
  say ""
  say "RAMA DE RELEASE ANCLADA: si fusionas #$PRNUM tal cual, el tag del root"
  say "saldrá sin$anchored como ancestro y el manifest-guard §3/§3b del"
  say "paraguas rechazará el set."
  say ""
  say "PRIMERO, la vía NO destructiva — traer main a la rama:"
  say ""
  say "  gh pr update-branch $PRNUM -R $REPO"
  say "  # si update-branch falla por conflicto (el manifest compartido suele"
  say "  # chocar), merge a mano y resolver por UNIÓN: el bump propio del PR"
  say "  # + las versiones que main ya avanzó. VALIDA el JSON antes de"
  say "  # commitear (un manifest roto se fusiona sin que nadie lo vea)."
  say ""
  say "SOLO si la rama no lleva trabajo humano, la receta destructiva:"
  say ""
  say "  gh pr close $PRNUM -R $REPO"
  say "  git push https://github.com/$REPO.git --delete '$head_ref'"
  say "  gh workflow run 'Release Please' -R $REPO"
  say "  # espera al PR nuevo y RE-EJECUTA este check antes de fusionarlo:"
  say "  bash scripts/train/check-anchored-release-branch.sh ${REPO#$OWNER_DEFAULT/}"
  say ""
  say "CUIDADO (mordió en el tren de 1.25.0): la rama del release del ROOT"
  say "suele llevar las deudas de doc escritas a mano —notas de la versión,"
  say "snapshot de docs, sidebar—. Cerrarla y borrarla las DESTRUYE. Comprueba"
  say "antes qué hay encima del commit del bot:"
  say ""
  say "  git log --oneline origin/main..$head_ref"
  exit 1
fi

say "OK: el head del release PR del root contiene los últimos tags de módulo."
