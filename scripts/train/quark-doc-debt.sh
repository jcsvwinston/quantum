#!/usr/bin/env bash
# quark-doc-debt.sh [--dry-run] — paga la deuda de doc de una release de quark
# EN la rama del release PR (RT-9), antes de que merge-bot-pr.sh la fusione.
#
# check-version-coherence.sh exige, con la versión que el manifest de la rama
# declara: la mención en README/SECURITY/CLAUDE.md, la sección «## vX.Y.Z» de
# las notas del sitio, docs/RELEASE_NOTES_vX.Y.0.md y que el README apunte a
# ese fichero. release-please bumpa README/SECURITY; lo demás lo escribe
# scripts/release/gen_release_notes_skeleton.sh de quark (idempotente). Aquí
# se corre ese esqueleto sobre la rama del bot y se empuja lo que cambie.
#
# Dos detalles que costaron una vuelta de CI el 2026-09-05:
#   - un `docs(release):` fusionado DESPUÉS de que el bot generase la rama NO
#     la regenera (los docs no cambian el changelog), así que la rama no trae
#     las notas ni el snapshot de main: se le mete main con un merge antes.
#   - el esqueleto deja marcadores TODO cuando las notas no existían: el
#     tren PARA y los lista, porque la prosa no se delega en un script.
set -uo pipefail
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
Q=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
dir="$Q/../quark"; repo=jcsvwinston/quark; br=release-please--branches--main
[ -e "$dir/.git" ] || { echo "sin checkout hermano en $dir" >&2; exit 1; }
[ -z "$(git -C "$dir" status --porcelain)" ] || { echo "el checkout $dir está sucio" >&2; exit 1; }
git -C "$dir" fetch -q origin main "$br" || { echo "no pude traer $br (¿no hay release PR?)" >&2; exit 1; }
wt=$(mktemp -d)
git -C "$dir" worktree add -q "$wt" "origin/$br" || { echo "no pude abrir un worktree de $br" >&2; exit 1; }
trap 'git -C "$dir" worktree remove --force "$wt" >/dev/null 2>&1; git -C "$dir" worktree prune' EXIT
cd "$wt" || exit 1
ver=$(python3 -c "import json;print(json.load(open('.release-please-manifest.json'))['.'])")
echo "== quark-doc-debt: rama $br en v$ver =="
if ! git merge-base --is-ancestor origin/main HEAD; then
  echo "  la rama no trae main (release-please no regenera por un docs(release)): merge de main"
  git merge --no-edit origin/main >/dev/null || { echo "el merge de main en la rama conflictúa: resuélvelo a mano" >&2; exit 1; }
fi
bash scripts/release/gen_release_notes_skeleton.sh || exit 1
todos=$(grep -l "TODO" "docs/RELEASE_NOTES_v${ver%.*}.0.md" website/docs/reference/release-notes.mdx 2>/dev/null || true)
if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git -c user.name="${GIT_AUTHOR_NAME:-$(git -C "$dir" config user.name)}" commit -q -m "docs(release): notes skeleton and version mentions for v$ver

Written by the release train (quark-doc-debt.sh) in the release branch.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>" || exit 1
  if [ "$DRY" -eq 1 ]; then echo "  (dry-run) empujaría: $(git log -1 --format=%s)"; else git push -q origin "HEAD:$br" || exit 1; echo "  empujado a $br: $(git log -1 --format=%s)"; fi
else
  echo "  nada que pagar: la rama ya lleva las notas y las menciones"
fi
bash scripts/check-version-coherence.sh >/dev/null 2>&1 && echo "  check-version-coherence: OK" || { echo "  check-version-coherence sigue en rojo:" >&2; bash scripts/check-version-coherence.sh 2>&1 | sed 's/^/    /' >&2; exit 1; }
if [ -n "$todos" ]; then
  echo "PARADA: el esqueleto dejó marcadores TODO (la prosa no se delega) en:" >&2
  printf '    %s\n' $todos >&2
  echo "  redacta, empuja a $br y relanza: bash scripts/train/train.sh --desde quark" >&2
  exit 2
fi
