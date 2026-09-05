#!/usr/bin/env bash
# merge-group.sh <repo> <método> <pr>... — fusiona en serie: update-branch si BEHIND, espera checks, merge.
set -uo pipefail
repo=$1; method=$2; shift 2
for n in "$@"; do
  echo "== $repo#$n"
  for attempt in 1 2 3; do
    st=$(gh pr view "$n" -R "jcsvwinston/$repo" --json mergeStateStatus --jq .mergeStateStatus)
    if [ "$st" = "BEHIND" ]; then
      echo "  BEHIND → update-branch"; gh pr update-branch "$n" -R "jcsvwinston/$repo" >/dev/null 2>&1 || true; sleep 45
    fi
    until s=$(gh pr checks "$n" -R "jcsvwinston/$repo" 2>/dev/null | awk -F'\t' '{print $2}' | sort | uniq -c | tr '\n' ' '); [ -n "$s" ] && ! echo "$s" | grep -q pending; do sleep 30; done
    echo "  checks: $s"
    if echo "$s" | grep -q fail; then echo "  ROJO: no fusiono $repo#$n"; break; fi
    if gh pr merge "$n" -R "jcsvwinston/$repo" "$method" --delete-branch >/dev/null 2>&1; then
      echo "  FUSIONADO $repo#$n"; break
    else
      st=$(gh pr view "$n" -R "jcsvwinston/$repo" --json state,mergeStateStatus --jq '"\(.state) \(.mergeStateStatus)"'); echo "  merge falló (intento $attempt): $st"
      [ "${st%% *}" = "MERGED" ] && break
      sleep 20
    fi
  done
done
