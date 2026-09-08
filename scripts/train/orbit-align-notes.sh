#!/usr/bin/env bash
# orbit-align-notes.sh [--dry-run] — la deuda RT-9 de una release de ALINEACIÓN
# de orbit, escrita en la rama del bot: el release PR sube la marca «current
# release is vX.Y.Z» de website/docs/reference/release-notes.md y
# check_docs_version_claims.sh exige la sección `## vX.Y.Z`. Una release que
# sólo mueve pines (align_set.sh tras cortar quark/nucleus) no tiene prosa
# que redactar: la sección dice exactamente eso, con los tags que salen a la
# vez, leídos del manifest de la rama. Costó una vuelta en 1.28.0 y otra en
# 1.29.0 (orbit#434, orbit#438).
#
# Si la rama del bot lleva un cambio de producto además de la alineación, la
# sección sigue siendo verdad para los pines pero corta: el humano la amplía.
set -uo pipefail
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
Q=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
dir="$Q/../orbit"; br=release-please--branches--main
[ -e "$dir/.git" ] || { echo "sin checkout hermano en $dir" >&2; exit 1; }
[ -z "$(git -C "$dir" status --porcelain)" ] || { echo "el checkout $dir está sucio" >&2; exit 1; }
git -C "$dir" fetch -q origin main "$br" || { echo "no pude traer $br (¿no hay release PR?)" >&2; exit 1; }
wt=$(mktemp -d)
git -C "$dir" worktree add -q "$wt" "origin/$br" || { echo "no pude abrir un worktree de $br" >&2; exit 1; }
trap 'git -C "$dir" worktree remove --force "$wt" >/dev/null 2>&1; git -C "$dir" worktree prune' EXIT
cd "$wt" || exit 1
ver=$(python3 -c "import json;print(json.load(open('.release-please-manifest.json'))['.'])")
notes=website/docs/reference/release-notes.md
if grep -qE "^## v${ver//./\\.}( |$)" "$notes"; then echo "  ya hay sección ## v$ver en la rama: nada que escribir"; exit 0; fi
nt=$(awk '/github.com\/jcsvwinston\/nucleus / {print $2; exit}' go.mod)
qt=$(awk '/github.com\/jcsvwinston\/quark / {print $2; exit}' quarkdatasource/go.mod)
prev=$(grep -oE '^## v[0-9]+\.[0-9]+\.[0-9]+' "$notes" | head -1 | sed 's/^## //')
mods=$(python3 - <<'PY'
import json
m=json.load(open('.release-please-manifest.json'))
mods=[f"`{k}/v{v}`" for k,v in m.items() if k!='.']
print(', '.join(mods))
PY
)
python3 - "$notes" "$ver" "$prev" "$nt" "$qt" "$mods" "$(date +%Y-%m-%d)" <<'PY'
import sys,re
p,ver,prev,nt,qt,mods,today=sys.argv[1:]
s=open(p).read()
m=re.search(r'^## v\d', s, re.M)
sec=f"""## v{ver} — {today}

An alignment release with no product change: every module now requires
Nucleus {nt} and Quark {qt}, the versions the suite certifies next, and
`quarkdatasource` pins the root at {prev}. Nothing in the binaries or the
panel behaves differently from {prev}.

Fleet and bridge tags cut alongside: {mods}.

"""
s=s[:m.start()]+sec+s[m.start():]
open(p,'w').write(s); print(f"  sección ## v{ver} escrita (alineación a nucleus {nt}, quark {qt})")
PY
bash scripts/ci/check_docs_product_voice.sh >/dev/null 2>&1 || { echo "la sección no pasa la voz de producto" >&2; exit 1; }
bash scripts/ci/check_docs_version_claims.sh >/dev/null 2>&1 || { echo "check_docs_version_claims sigue en rojo" >&2; bash scripts/ci/check_docs_version_claims.sh 2>&1 | tail -3 >&2; exit 1; }
git add -A && git commit -q -m "docs(release): notes for v$ver

Written by the release train (orbit-align-notes.sh): an alignment release
with no product change.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>" || exit 1
if [ "$DRY" -eq 1 ]; then echo "  (dry-run) empujaría: docs(release): notes for v$ver"; else git push -q origin "HEAD:$br" || exit 1; echo "  empujado a $br: docs(release): notes for v$ver"; fi
