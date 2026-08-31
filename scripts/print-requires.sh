#!/usr/bin/env bash
# print-requires.sh — DX-25: translate the certified set into a pasteable
# go.mod `require` block. Before this, the user opened versions.yaml and
# transcribed the versions by hand (the orbit submodules lived in a prose
# comment). Reads EVERY key of the modules:, nucleus_modules: and
# orbit_modules: blocks of versions.yaml, so a module added to the manifest
# cannot go silently missing here (RT-6: nucleus_modules entered the manifest
# with providers/ldap and this script kept printing 8 lines while the
# manifest promised 9). A final self-check compares emitted lines against the
# keys the manifest certifies and fails loudly on any mismatch.
set -euo pipefail
cd "$(dirname "$0")/.."

# keys <block> — every key of a top-level mapping block, in manifest order.
keys() {
  awk -v blk="$1" '
    /^[a-z_]+:/ { inblk = ($0 ~ "^" blk ":") }
    inblk && /^  [a-zA-Z0-9_]+:/ {
      line = $0; sub(/^  /, "", line); sub(/:.*/, "", line); print line
    }' versions.yaml
}

# val <block> <key> — quoted value of a key inside a top-level block.
val() {
  awk -v blk="$1" -v key="$2" '
    /^[a-z_]+:/ { inblk = ($0 ~ "^" blk ":") }
    inblk && $0 ~ "^  " key ":" {
      if (match($0, /"[^"]+"/)) { print substr($0, RSTART + 1, RLENGTH - 2); exit }
    }' versions.yaml
}

# req <module-path> <block> <key> — one require line; empty value = hard fail.
lines=""
count=0
req() {
  local v
  v=$(val "$2" "$3")
  if [ -z "$v" ]; then
    echo "print-requires.sh: no version for '$3' in block '$2' of versions.yaml" >&2
    exit 1
  fi
  lines+="	$1 $v"$'\n'
  count=$((count + 1))
}

req github.com/jcsvwinston/quark   modules quark
req github.com/jcsvwinston/nucleus modules nucleus
# nucleus_modules keys live under providers/ in the nucleus repo (today the
# single one, ldap — see the nucleus_modules comment in versions.yaml).
while read -r m; do
  req "github.com/jcsvwinston/nucleus/providers/$m" nucleus_modules "$m"
done < <(keys nucleus_modules)
req github.com/jcsvwinston/orbit modules orbit
while read -r m; do
  req "github.com/jcsvwinston/orbit/$m" orbit_modules "$m"
done < <(keys orbit_modules)

# Self-check: one require line per version the manifest certifies.
expected=$(( $(keys modules | wc -l) + $(keys nucleus_modules | wc -l) + $(keys orbit_modules | wc -l) ))
if [ "$count" -ne "$expected" ]; then
  echo "print-requires.sh: emitted $count require lines but versions.yaml certifies $expected versions" >&2
  exit 1
fi

echo "require ("
printf '%s' "$lines"
echo ")"
