#!/usr/bin/env bash
# merge-bot-pr.sh — fusiona UN release PR del bot, con las trampas conocidas
# del tren resueltas (RT-1; ver scripts/train/README.md):
#
#   1. Los PRs de release-please NO disparan CI (los crea el GITHUB_TOKEN y
#      GitHub bloquea workflows recursivos): quedan BLOCKED con «no checks
#      reported». El disparador MÁS determinista es un push humano de commit
#      VACÍO a la rama del release (release-please filtra los commits vacíos,
#      así que no ensucia el changelog); close/reopen es el fallback y a veces
#      no dispara.
#   2. Con main exigiendo ramas al día, cada merge deja a los demás PRs en
#      BEHIND: aquí se hace `gh pr update-branch` y otra vuelta de checks.
#   3. release-please puede AUTO-BLOQUEARSE tras fusionar («There are
#      untagged, merged release PRs outstanding») y dejar el PR merged con
#      `autorelease: pending` SIN tag: tras el merge se espera el tag y, si no
#      llega, se imprime la receta de recuperación.
#
# Uso: merge-bot-pr.sh <repo> <numero-pr> [--dry-run] [--sin-commit-vacio]
#   <repo>  owner/nombre, o nombre corto (se asume jcsvwinston/<nombre>).
#
# Imprime SIEMPRE lo que va a hacer antes de hacerlo, y para en seco al
# primer rojo. No decide nada: fusiona el PR que le digas, en el estado en
# que el CI lo apruebe.
set -euo pipefail

OWNER_DEFAULT="jcsvwinston"
DRY=0
EMPTY_COMMIT=1
REPO=""
PR=""

for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --sin-commit-vacio) EMPTY_COMMIT=0 ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) if [ -z "$REPO" ]; then REPO="$a"; elif [ -z "$PR" ]; then PR="$a"; else
         echo "argumento de más: $a" >&2; exit 64; fi ;;
  esac
done
if [ -z "$REPO" ] || [ -z "$PR" ]; then
  echo "uso: merge-bot-pr.sh <repo> <numero-pr> [--dry-run] [--sin-commit-vacio]" >&2
  exit 64
fi
case "$REPO" in */*) : ;; *) REPO="$OWNER_DEFAULT/$REPO" ;; esac

say() { printf '%s\n' "$*"; }
run() {
  say "  → $*"
  if [ "$DRY" -eq 1 ]; then return 0; fi
  "$@"
}
die() { say "PARADA EN SECO: $*" >&2; exit 1; }

say "== merge-bot-pr: $REPO#$PR =="

# --- 1. Estado del PR -------------------------------------------------------
say "  → gh pr view $PR -R $REPO --json state,title,headRefName,author,mergeStateStatus"
state=$(gh pr view "$PR" -R "$REPO" --json state --jq .state)
title=$(gh pr view "$PR" -R "$REPO" --json title --jq .title)
head_ref=$(gh pr view "$PR" -R "$REPO" --json headRefName --jq .headRefName)
author=$(gh pr view "$PR" -R "$REPO" --json author --jq .author.login)
say "  PR: «$title» (autor: $author, rama: $head_ref, estado: $state)"
[ "$state" = "OPEN" ] || die "el PR no está abierto (estado: $state)"

# --- 2. Push humano de commit vacío (dispara el CI del PR del bot) ----------
if [ "$EMPTY_COMMIT" -eq 1 ]; then
  say "PASO: push humano de commit vacío a $head_ref (dispara el CI que el token del bot no puede disparar)"
  tmp=$(mktemp -d)
  run git clone --quiet --filter=blob:none --branch "$head_ref" \
    "https://github.com/$REPO.git" "$tmp/clone"
  if [ "$DRY" -eq 0 ]; then
    git -C "$tmp/clone" commit --quiet --allow-empty \
      -m "chore: dispara el CI del release PR (push humano; release-please filtra los commits vacíos)"
    say "  → git -C <tmp> push origin HEAD:$head_ref"
    git -C "$tmp/clone" push --quiet origin "HEAD:$head_ref"
  else
    say "  → git commit --allow-empty && git push origin HEAD:$head_ref"
  fi
  rm -rf "$tmp"
fi

# --- 3. Espera de checks (para en seco al primer rojo) ----------------------
say "PASO: esperar los checks del PR (rojo = parada, no se fusiona nada)"
say "  → gh pr checks $PR -R $REPO --watch --fail-fast"
if [ "$DRY" -eq 0 ]; then
  sleep 10 # deja que el push registre sus check-runs antes de mirar
  gh pr checks "$PR" -R "$REPO" --watch --fail-fast \
    || die "checks en rojo en $REPO#$PR — arregla la causa (¿deuda de doc del minor? ver README §deudas) y relanza"
fi

# --- 4. BEHIND → update-branch y otra vuelta --------------------------------
if [ "$DRY" -eq 0 ]; then
  mss=$(gh pr view "$PR" -R "$REPO" --json mergeStateStatus --jq .mergeStateStatus)
  say "  mergeStateStatus: $mss"
  if [ "$mss" = "BEHIND" ]; then
    say "PASO: la rama quedó BEHIND (otro merge entró antes) — update-branch + otra vuelta de checks"
    run gh pr update-branch "$PR" -R "$REPO"
    sleep 10
    gh pr checks "$PR" -R "$REPO" --watch --fail-fast \
      || die "checks en rojo tras update-branch en $REPO#$PR"
  elif [ "$mss" = "DIRTY" ]; then
    die "la rama está DIRTY (conflicto — la cascada del manifest compartido): reconciliar a mano el .release-please-manifest.json (main + el bump propio del PR), push, y relanzar"
  fi
fi

# --- 5. Merge ---------------------------------------------------------------
# Método según el repo: merge commit si el repo lo permite; si es squash-only,
# squash (el título del PR ES el commit convencional que release-please parsea).
allow_merge=$(gh api "repos/$REPO" --jq .allow_merge_commit)
if [ "$allow_merge" = "true" ]; then method="--merge"; else method="--squash"; fi
say "PASO: fusionar ($method según la configuración del repo)"
run gh pr merge "$PR" -R "$REPO" "$method" || die "gh pr merge falló en $REPO#$PR"

# --- 6. Esperar el tag (release-please puede auto-bloquearse) ---------------
# El tag esperado sale del título del release PR:
#   «chore(main): release 1.21.0»               → v1.21.0
#   «chore(main): release providers/ldap 0.2.3» → providers/ldap/v0.2.3
#   «chore(main): release github.com/jcsvwinston/orbit 1.8.13» → v1.8.13
#     (el componente del ROOT multi-módulo es la ruta completa del módulo)
expected_tag=""
comp=$(printf '%s\n' "$title" | sed -nE 's/^chore\([^)]*\): release ([^ ]+ )?([0-9]+\.[0-9]+\.[0-9]+)$/\1/p' | sed 's/ $//')
ver=$(printf '%s\n' "$title" | sed -nE 's/^chore\([^)]*\): release ([^ ]+ )?([0-9]+\.[0-9]+\.[0-9]+)$/\2/p')
case "$comp" in
  "github.com/$REPO") comp="" ;;                       # componente == root
  "github.com/$REPO"/*) comp="${comp#github.com/$REPO/}" ;; # ruta → subdir
esac
if [ -n "$ver" ]; then
  if [ -n "$comp" ]; then expected_tag="$comp/v$ver"; else expected_tag="v$ver"; fi
fi
if [ -n "$expected_tag" ] && [ "$DRY" -eq 0 ]; then
  say "PASO: esperar el tag $expected_tag (hasta 5 min; el token del bot puede atascarse)"
  found=0
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if git ls-remote --tags "https://github.com/$REPO.git" "refs/tags/$expected_tag" | grep -q .; then
      found=1; break
    fi
    sleep 30
  done
  if [ "$found" -eq 1 ]; then
    say "OK: tag $expected_tag cortado."
  else
    say "AVISO: el tag $expected_tag NO ha aparecido en 5 min. Receta de recuperación"
    say "  (el auto-bloqueo «untagged, merged release PRs outstanding» de release-please):"
    say "  1. verificar que el .release-please-manifest.json del commit de merge declara $ver"
    say "  2. git tag -a $expected_tag <sha-del-merge> && git push origin $expected_tag"
    say "  3. gh release create $expected_tag (con las notas del CHANGELOG)"
    say "  4. re-etiquetar el PR: quitar 'autorelease: pending', poner 'autorelease: tagged'"
    say "     (sin el relabel, el SIGUIENTE corte vuelve a abortar)"
    exit 1
  fi
elif [ -z "$expected_tag" ]; then
  say "AVISO: el título no parece de release-please — no se espera ningún tag."
fi

say "OK: $REPO#$PR fusionado."
