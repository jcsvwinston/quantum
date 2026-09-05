#!/usr/bin/env bash
# untag-recipe.sh <repo-dir> <pr> — receta del auto-bloqueo de release-please
# («There are untagged, merged release PRs outstanding», visto 3 veces con
# release PRs únicos que llevaban paquetes sin cambios):
# por cada tag del manifest del commit de merge que falte, tag anotado en el
# merge + release de GitHub con la sección del CHANGELOG del paquete + relabel.
set -uo pipefail
dir=$1; pr=$2; repo=jcsvwinston/$(basename "$dir")
cd "$dir" && git fetch -q origin --tags && git checkout -q main && git pull -q --ff-only
sha=$(gh pr view "$pr" -R "$repo" --json mergeCommit --jq .mergeCommit.oid)
[ -n "$sha" ] || { echo "PR $pr sin merge commit"; exit 1; }
python3 - "$sha" <<'PY' > /tmp/expected-tags.txt
import json,subprocess,sys
sha=sys.argv[1]
m=json.loads(subprocess.check_output(['git','show',f'{sha}:.release-please-manifest.json']))
for k,v in sorted(m.items()):
    print(('v'+v) if k=='.' else f'{k}/v{v}', k, v)
PY
while read -r tag pkg ver; do
  if git ls-remote --tags origin "refs/tags/$tag" | grep -q .; then echo "ya existe: $tag"; continue; fi
  cl=$([ "$pkg" = "." ] && echo CHANGELOG.md || echo "$pkg/CHANGELOG.md")
  awk -v v="$ver" '$0 ~ "^## \\[?"v"\\]?" {f=1;print;next} /^## /{if(f)exit} f' "$cl" > /tmp/notes-$$.md
  [ -s /tmp/notes-$$.md ] || echo "Release $tag" > /tmp/notes-$$.md
  git tag -a "$tag" "$sha" -m "$tag" && git push -q origin "$tag" && gh release create "$tag" -R "$repo" --title "$tag" --notes-file /tmp/notes-$$.md --target "$sha" >/dev/null && echo "cortado: $tag"
done < /tmp/expected-tags.txt
gh pr edit "$pr" -R "$repo" --remove-label "autorelease: pending" --add-label "autorelease: tagged" >/dev/null && echo "relabel hecho en $repo#$pr"
