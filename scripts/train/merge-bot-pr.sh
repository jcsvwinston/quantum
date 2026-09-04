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
# «chore: release main» (separate-pull-requests: false — nucleus, orbit y
# quark desde el tren de 1.26.1): el PR corta el root Y todos los módulos del
# mismo commit, así que los tags esperados se LEEN del manifest de la rama
# fusionada — root → vX.Y.Z, módulo → <ruta>/vX.Y.Z — en vez de deducirse
# del título. En el tren de 1.26.1 el driver lo trataba como «no es de
# release-please» y daba el merge por bueno sin esperar ningún tag.
expected_tags=""
if [ -z "$expected_tag" ] && printf '%s\n' "$title" | grep -qE '^chore(\([^)]*\))?: release main$'; then
  merge_sha=$(gh pr view "$PR" -R "$REPO" --json mergeCommit --jq .mergeCommit.oid 2>/dev/null || true)
  manifest=$(gh api "repos/$REPO/contents/.release-please-manifest.json?ref=${merge_sha:-main}" --jq .content 2>/dev/null | base64 -d 2>/dev/null || true)
  expected_tags=$(printf '%s' "$manifest" | python3 -c '
import json,sys
m=json.load(sys.stdin)
print(" ".join(("v"+v) if k=="." else (k+"/v"+v) for k,v in sorted(m.items())))' 2>/dev/null || true)
fi
if [ -n "$expected_tag" ]; then expected_tags="$expected_tag"; fi
if [ -n "$expected_tags" ] && [ "$DRY" -eq 0 ]; then
  say "PASO: esperar los tags ($(printf '%s\n' $expected_tags | wc -l | tr -d ' ')): $expected_tags"
  say "  (hasta 5 min; el token del bot puede atascarse, y un push de merge puede NO"
  say "   disparar «Release Please» — a los 2 min sin corrida por push se dispara a mano)"
  found=0; dispatched=0
  for i in 1 2 3 4 5 6 7 8 9 10; do
    missing=""
    for t in $expected_tags; do
      git ls-remote --tags "https://github.com/$REPO.git" "refs/tags/$t" | grep -q . || missing="$missing $t"
    done
    if [ -z "$missing" ]; then found=1; break; fi
    if [ "$i" -ge 4 ] && [ "$dispatched" -eq 0 ]; then
      if ! gh run list -R "$REPO" --event push --limit 5 --json workflowName,headSha \
           --jq ".[] | select(.workflowName == \"Release Please\") | select(.headSha == \"${merge_sha:-x}\") | .headSha" 2>/dev/null | grep -q .; then
        say "  AVISO: el push del merge no disparó «Release Please» (pasó con nucleus#456 y quark#346 en el tren de 1.26.1) — lo disparo a mano"
        run gh workflow run 'Release Please' -R "$REPO" --ref main || true
        dispatched=1
      fi
    fi
    sleep 30
  done
  if [ "$found" -eq 1 ]; then
    say "OK: tags cortados: $expected_tags"
  else
    say "AVISO: faltan tags tras 5 min:$missing. Receta de recuperación"
    say "  (el auto-bloqueo «untagged, merged release PRs outstanding» de release-please):"
    say "  1. verificar que el .release-please-manifest.json del commit de merge declara las versiones"
    say "  2. git tag -a <tag> <sha-del-merge> && git push origin <tag>, por cada tag que falte"
    say "  3. gh release create <tag> (con las notas del CHANGELOG)"
    say "  4. re-etiquetar el PR: quitar 'autorelease: pending', poner 'autorelease: tagged'"
    say "     (sin el relabel, el SIGUIENTE corte vuelve a abortar)"
    exit 1
  fi
elif [ -z "$expected_tags" ]; then
  say "AVISO: el título no parece de release-please — no se espera ningún tag."
fi

say "OK: $REPO#$PR fusionado."
