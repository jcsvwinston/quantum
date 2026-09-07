#!/usr/bin/env bash
# merge-group.sh <repo> <método> <pr>... — fusiona en serie: update-branch si BEHIND, espera checks, merge.
set -uo pipefail
TMPBODY=$(mktemp); trap 'rm -f "$TMPBODY"' EXIT
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
    # Con --squash, el cuerpo del commit lo compone GitHub con la lista de
    # commits del PR, y una línea «Palabra: texto» de esos cuerpos la lee el
    # parser de conventional commits como pie de página y aborta: release-please
    # descartó quark#355 (feat) y propuso un patch (1.11.1) con un minor en
    # main. Aquí el squash lleva título = título del PR y un cuerpo controlado:
    # el del PR con esas líneas neutralizadas, más el trailer de coautoría.
    extra=()
    if [ "$method" = "--squash" ]; then
      title=$(gh pr view "$n" -R "jcsvwinston/$repo" --json title --jq .title)
      body=$(gh pr view "$n" -R "jcsvwinston/$repo" --json body --jq .body | sed -E 's/^([A-Za-z][A-Za-z -]*): /\1 — /' | grep -v '^🤖 Generated with' )
      body=$(printf '%s\n\nCo-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>\n' "$body")
      printf '%s' "$body" > "$TMPBODY"
      extra=(--subject "$title (#$n)" --body-file "$TMPBODY")
    fi
    if gh pr merge "$n" -R "jcsvwinston/$repo" "$method" --delete-branch ${extra[@]+"${extra[@]}"} >/dev/null 2>&1; then
      echo "  FUSIONADO $repo#$n"; break
    else
      st=$(gh pr view "$n" -R "jcsvwinston/$repo" --json state,mergeStateStatus --jq '"\(.state) \(.mergeStateStatus)"'); echo "  merge falló (intento $attempt): $st"
      [ "${st%% *}" = "MERGED" ] && break
      sleep 20
    fi
  done
done
