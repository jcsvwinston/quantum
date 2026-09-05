#!/usr/bin/env bash
# untag-recipe.sh <repo|repo-dir> <pr> [--dry-run] — la receta del auto-bloqueo
# de release-please, mecanizada.
#
# El auto-bloqueo («There are untagged, merged release PRs outstanding») es el
# SÍNTOMA: un release PR fusionado que se quedó con `autorelease: pending` y
# sin tag. La CAUSA, leída en el log de la corrida (orbit#399, nucleus#466):
#
#   ⚠ PR component: undefined does not match configured component: github.com/jcsvwinston/orbit
#
# release-please 17.x (src/strategies/base.ts, buildRelease) trata un PR cuyo
# cuerpo lleva UNA sola release sin componente —la raíz— como «standalone» y
# compara el componente de la rama (ninguno: con separate-pull-requests: false
# la rama es release-please--branches--main) con el `package-name` de la raíz.
# No casan, todas las estrategias descartan el PR y no sale ningún tag. Un PR
# con dos o más releases va por la otra rama del código y funciona. La causa
# se quita en la config de cada repo (sin `package-name` en la raíz: orbit#426,
# nucleus#467, quark#347); esta receta queda para el día en que vuelva.
#
# Qué hace: por cada tag que el .release-please-manifest.json del commit de
# merge declara y que NO existe en origin, tag anotado en ese commit + release
# de GitHub con la sección del CHANGELOG del paquete + relabel del PR a
# `autorelease: tagged` (sin el relabel, el SIGUIENTE corte vuelve a abortar).
#
# No hace checkout de nada: lee los ficheros con `git show <sha>:<ruta>` y
# etiqueta por SHA, así que vale sobre el checkout hermano (../<repo>), sobre
# el submódulo pinado del paraguas o sobre un clon temporal (si no hay
# checkout, lo clona en un directorio temporal).
#
# Uso: untag-recipe.sh orbit 399           # checkout en ../orbit (o REPO_CHECKOUT)
#      untag-recipe.sh /ruta/a/orbit 399
#      untag-recipe.sh nucleus 466 --dry-run
set -uo pipefail
OWNER=jcsvwinston
DRY=0; ARG=""; PR=""
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    -h|--help) sed -n '2,33p' "$0"; exit 0 ;;
    *) if [ -z "$ARG" ]; then ARG=$a; elif [ -z "$PR" ]; then PR=$a; else echo "argumento de más: $a" >&2; exit 64; fi ;;
  esac
done
[ -n "$ARG" ] && [ -n "$PR" ] || { echo "uso: untag-recipe.sh <repo|repo-dir> <pr> [--dry-run]" >&2; exit 64; }

Q=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
if [ -e "$ARG/.git" ]; then
  dir=$(cd "$ARG" && pwd); name=$(basename "$dir")
else
  name=${ARG#*/}; dir=${REPO_CHECKOUT:-$Q/../$name}
fi
repo="$OWNER/$name"
tmpd=$(mktemp -d); trap 'rm -rf "$tmpd"' EXIT
if ! git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
  echo "sin checkout de $name en $dir: clono en temporal"
  git clone -q --filter=blob:none "https://github.com/$repo.git" "$tmpd/clone" || { echo "no pude clonar $repo" >&2; exit 1; }
  dir="$tmpd/clone"
fi

sha=$(gh pr view "$PR" -R "$repo" --json mergeCommit --jq .mergeCommit.oid 2>/dev/null)
[ -n "$sha" ] && [ "$sha" != "null" ] || { echo "$repo#$PR sin merge commit (¿no está fusionado?)" >&2; exit 1; }
git -C "$dir" fetch -q origin --tags 2>/dev/null
git -C "$dir" cat-file -e "$sha^{commit}" 2>/dev/null || git -C "$dir" fetch -q origin "$sha" || { echo "no encuentro el commit de merge $sha" >&2; exit 1; }

git -C "$dir" show "$sha:.release-please-manifest.json" | python3 -c '
import json,sys
m=json.load(sys.stdin)
for k,v in sorted(m.items()):
    print(("v"+v) if k=="." else f"{k}/v{v}", k, v)' > "$tmpd/expected"
[ -s "$tmpd/expected" ] || { echo "el manifest del commit $sha no declara paquetes" >&2; exit 1; }

echo "== untag-recipe: $repo#$PR @ ${sha:0:8} =="
cut=0; fail=0
while read -r tag pkg ver; do
  if git -C "$dir" ls-remote --tags origin "refs/tags/$tag" | grep -q .; then echo "ya existe: $tag"; continue; fi
  cl=$([ "$pkg" = "." ] && echo CHANGELOG.md || echo "$pkg/CHANGELOG.md")
  esc=$(printf '%s' "$ver" | sed 's/\./\\./g')
  git -C "$dir" show "$sha:$cl" 2>/dev/null | awk -v v="$esc" '$0 ~ "^## \\[?"v"\\]?" {f=1;print;next} /^## /{if(f)exit} f' > "$tmpd/notes.md"
  [ -s "$tmpd/notes.md" ] || echo "Release $tag" > "$tmpd/notes.md"
  if [ "$DRY" -eq 1 ]; then echo "(dry-run) cortaría: $tag en ${sha:0:8} con $(wc -l < "$tmpd/notes.md" | tr -d ' ') líneas de notas"; continue; fi
  if git -C "$dir" rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    [ "$(git -C "$dir" rev-parse "$tag^{commit}")" = "$sha" ] || { echo "el tag local $tag apunta a otro commit; revísalo antes de seguir" >&2; fail=1; continue; }
  else
    git -C "$dir" tag -a "$tag" "$sha" -m "$tag" || { fail=1; continue; }
  fi
  if git -C "$dir" push -q origin "refs/tags/$tag" \
     && gh release create "$tag" -R "$repo" --title "$tag" --notes-file "$tmpd/notes.md" --target "$sha" >/dev/null; then
    echo "cortado: $tag"; cut=$((cut+1))
  else
    echo "FALLO al cortar $tag" >&2; fail=1
  fi
done < "$tmpd/expected"

if [ "$DRY" -eq 1 ]; then echo "(dry-run) relabel: -autorelease: pending +autorelease: tagged en $repo#$PR"; exit 0; fi
[ "$fail" -eq 0 ] || exit 1
gh pr edit "$PR" -R "$repo" --add-label "autorelease: tagged" >/dev/null || { echo "no pude etiquetar $repo#$PR como tagged" >&2; exit 1; }
gh pr edit "$PR" -R "$repo" --remove-label "autorelease: pending" >/dev/null 2>&1 || true
echo "relabel hecho en $repo#$PR (tags cortados aquí: $cut)"
