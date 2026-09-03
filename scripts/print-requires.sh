#!/usr/bin/env bash
# print-requires.sh — DX-25: translate the certified set into a pasteable
# go.mod `require` block. Before this, the user opened versions.yaml and
# transcribed the versions by hand (the orbit submodules lived in a prose
# comment). Reads EVERY key of the modules:, quark_modules:, nucleus_modules:
# and orbit_modules: blocks of versions.yaml, so a module added to the
# manifest cannot go silently missing here (RT-6: nucleus_modules entered the
# manifest with providers/ldap and this script kept printing 8 lines while
# the manifest promised 9).
#
# The module PATH is discovered from the submodule tree, never assumed from
# the key (QM-1, 2026-09-03 audit): the manifest keys are last path segments
# (`sqlite`, `otlp`, `storage-s3`) and the old code prefixed every one of them
# with `providers/`, emitting `nucleus/providers/mssql` and
# `nucleus/providers/otlp` — modules that do not exist — while skipping
# quark_modules altogether. quantum-app received those lines and discarded
# them. Two self-checks now stand behind the output: every emitted path has a
# go.mod at that location in the pinned submodule, and the line count equals
# the number of versions the manifest certifies.
set -euo pipefail
cd "$(dirname "$0")/.."

# shellcheck source=scripts/lib/manifest-modules.sh
source scripts/lib/manifest-modules.sh

lines=""
count=0
# req <import-path> <block> <key> — one require line; empty value = hard fail.
req() {
  local v
  v=$(mm_val "$2" "$3")
  if [ -z "$v" ]; then
    echo "print-requires.sh: no version for '$3' in block '$2' of versions.yaml" >&2
    exit 1
  fi
  lines+="	$1 $v"$'\n'
  count=$((count + 1))
}

# sibling <repo> — every key of <repo>_modules, resolved to its path in the tree.
sibling() {
  local repo=$1 m path
  while read -r m; do
    [ -n "$m" ] || continue
    path=$(mm_module_path "$repo" "$m") || exit 1
    req "$path" "${repo}_modules" "$m"
  done < <(mm_keys "${repo}_modules")
}

req github.com/jcsvwinston/quark   modules quark
sibling quark
req github.com/jcsvwinston/nucleus modules nucleus
sibling nucleus
req github.com/jcsvwinston/orbit   modules orbit
sibling orbit

# Self-check 1: every emitted path exists as a module in the pinned tree.
while read -r path _; do
  [ -n "$path" ] || continue
  rel=${path#github.com/jcsvwinston/}
  if [ ! -f "$rel/go.mod" ]; then
    echo "print-requires.sh: emitted $path but $rel/go.mod does not exist in the pinned submodule" >&2
    exit 1
  fi
done <<<"$lines"

# Self-check 2: one require line per version the manifest certifies.
expected=$(( $(mm_keys modules | wc -l) + $(mm_keys quark_modules | wc -l) + $(mm_keys nucleus_modules | wc -l) + $(mm_keys orbit_modules | wc -l) ))
if [ "$count" -ne "$expected" ]; then
  echo "print-requires.sh: emitted $count require lines but versions.yaml certifies $expected versions" >&2
  exit 1
fi

echo "require ("
printf '%s' "$lines"
echo ")"
