#!/usr/bin/env bash
# orbit-converge.sh <root-version> <notes-fleet-tags> <branch> — un corte de
# convergencia de pines internos de orbit (ADR-006): alinea agent/server a los
# tags que el corte anterior acaba de publicar (align_set.sh, con los pines de
# nucleus/quark leídos del manifiesto del paraguas), escribe las notas del root,
# abre y fusiona el PR, espera el release PR único, lo fusiona y espera los
# tags (receta del auto-bloqueo si faltan). Se llama desde la raíz del paraguas.
#   bash scripts/train/orbit-converge.sh 1.8.23 '`agent/v0.6.14`, `server/v0.10.16`' fix/align-siblings-3
set -uo pipefail
ver=$1; fleet=$2; br=$3
S=$(cd "$(dirname "$0")" && pwd)
# Rutas: el paraguas es el padre de scripts/train; orbit es su submódulo hermano en checkout aparte.
Q=$(cd "$S/../.." && pwd); O=${ORBIT_CHECKOUT:-$(cd "$Q/../orbit" && pwd)}
cd "$O" && git checkout -q main && git pull -q --ff-only && git fetch -q --tags && git checkout -q -b "$br" || exit 1
GOWORK=off GOFLAGS=-mod=mod GOPROXY=https://proxy.golang.org bash scripts/release/align_set.sh --manifest "$Q/versions.yaml" --no-commit 2>&1 | grep "^align:"
[ -n "$(git status --porcelain)" ] || { echo "nada que alinear"; exit 2; }
python3 - "$ver" "$fleet" <<'PY'
import sys
ver, fleet = sys.argv[1], sys.argv[2]
p='website/docs/reference/release-notes.md'; s=open(p).read()
import re
first = re.search(r'^## v(\d+\.\d+\.\d+) — ', s, re.M).group(0)
new = f'''## v{ver} — $(date +%Y-%m-%d)

Convergence cut for the internal module pins after v1.8.22: the modules are
tagged from the same commit as the ones they depend on, so each is cut still
requiring the previous tag of its sibling. This release moves those pins
forward. Nothing else changes.

Fleet tags cut alongside: {fleet}.

'''
s = s.replace(first, new + first, 1); open(p,'w').write(s)
PY
bash scripts/ci/check_docs_product_voice.sh | tail -1
git add -A && git commit -qm "fix(deps): move the internal sibling pins to the tags cut in the previous release

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>" && git push -q -u origin "$br" && \
pr=$(gh pr create --title "fix(deps): move the internal sibling pins to the tags cut in the previous release (v$ver)" --body "Convergence cut for the internal pins after the previous release (check_internal_pins.sh fails at the umbrella pin). Written by align_set.sh; v$ver notes in the same commit so the root is cut alongside.

🤖 Generated with [Claude Code](https://claude.com/claude-code)" | tail -1 | sed 's|.*/||') && echo "PR #$pr" && git checkout -q main
cd "$Q" && bash "$S/merge-group.sh" orbit --squash "$pr" 2>&1 | grep -E "FUSIONADO|ROJO|falló"
gh pr view "$pr" -R jcsvwinston/orbit --json state --jq .state | grep -q MERGED || { echo "PR #$pr no fusionado"; exit 3; }
sha=$(gh pr view "$pr" -R jcsvwinston/orbit --json mergeCommit --jq .mergeCommit.oid)
until r=$(gh run list -R jcsvwinston/orbit --event push --limit 4 --json workflowName,status,headSha --jq ".[] | select(.workflowName==\"Release Please\" and .headSha==\"$sha\") | .status" | head -1); [ "$r" = "completed" ]; do sleep 20; done
rp=$(gh pr list -R jcsvwinston/orbit --state open --label "autorelease: pending" --json number --jq '.[0].number')
echo "release PR #$rp: $(gh api "repos/jcsvwinston/orbit/contents/.release-please-manifest.json?ref=release-please--branches--main" --jq '.content' | base64 -d | tr -d '\n ')"
bash scripts/train/merge-bot-pr.sh orbit "$rp" 2>&1 | grep -E "OK:|AVISO|PARADA|faltan" | tail -3
if gh pr view "$rp" -R jcsvwinston/orbit --json state --jq .state | grep -q MERGED && ! git -C "$O" ls-remote --tags origin "refs/tags/v$ver" | grep -q .; then echo "== receta"; bash "$S/untag-recipe.sh" "$O" "$rp"; fi
cd "$O" && bash scripts/ci/check_internal_pins.sh 2>&1 | tail -2
