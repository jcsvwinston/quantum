#!/usr/bin/env bash
# print-requires.sh — DX-25: translate the certified set into a pasteable
# go.mod `require` block. Before this, the user opened versions.yaml and
# transcribed nine versions by hand (the six orbit submodules lived in a
# prose comment). Reads modules: and orbit_modules: from versions.yaml.
set -euo pipefail
cd "$(dirname "$0")/.."

val() { sed -nE "s/^  $1:[[:space:]]+\"([^\"]+)\".*/\1/p" versions.yaml | head -1; }

echo "require ("
echo "	github.com/jcsvwinston/quark $(val quark)"
echo "	github.com/jcsvwinston/nucleus $(val nucleus)"
echo "	github.com/jcsvwinston/orbit $(val orbit)"
for m in proto agent server quarkbridge quarkdatasource; do
  v=$(val "$m")
  [ -n "$v" ] && echo "	github.com/jcsvwinston/orbit/$m $v"
done
echo ")"
