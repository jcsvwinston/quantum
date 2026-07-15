#!/usr/bin/env bash
# manifest-guard.sh — the manifest cannot claim what git does not back.
#
# versions.yaml certifies a trio by three coordinates per module: a published
# version (`modules`), the exact commit the workspace pins (`workspace_pins`),
# and the submodule gitlink the umbrella actually checks out. This guard fails
# CI unless all three agree, for every module:
#
#   1. gitlink == workspace_pin   — the submodule the umbrella records is the
#      commit the manifest pins. (Catches "bumped the submodule, forgot the
#      manifest" and vice versa.)
#   2. tag(version) == workspace_pin — the pinned commit is exactly the commit
#      the module's published tag points at. (Catches "pinned a commit that
#      isn't the release" — the drift QM-P0-1 was written against.)
#
# Without this, versions.yaml is prose: it can assert a set that does not build
# or that pins commits no released tag stands behind.
set -uo pipefail

cd "$(dirname "$0")/.."

manifest=versions.yaml
status=0

# yaml_value SECTION KEY — reads a `KEY: "value"` line from under a top-level
# `SECTION:` block. No yq dependency: the manifest is a flat, hand-maintained
# file and awk over its two known sections is enough (and portable to the CI
# runner). Strips surrounding quotes and any trailing comment.
yaml_value() {
  local section=$1 key=$2
  awk -v sec="$section" -v key="$key" '
    $0 ~ "^"sec":" { inblock=1; next }
    /^[a-zA-Z_]/   { inblock=0 }
    inblock && $1 == key":" {
      v=$2
      gsub(/"/, "", v)
      print v
      exit
    }
  ' "$manifest"
}

for module in quark nucleus orbit; do
  version=$(yaml_value modules "$module")
  pin=$(yaml_value workspace_pins "$module")

  if [[ -z "$version" || -z "$pin" ]]; then
    echo "FAIL: $module — missing version ('$version') or pin ('$pin') in $manifest" >&2
    status=1
    continue
  fi

  if [[ ! -d "$module/.git" && ! -f "$module/.git" ]]; then
    echo "FAIL: $module — submodule not checked out (run: git submodule update --init)" >&2
    status=1
    continue
  fi

  # 1. gitlink (what the umbrella records) must start with the pin.
  gitlink=$(git -C "$module" rev-parse HEAD 2>/dev/null)
  if [[ "$gitlink" != "$pin"* ]]; then
    echo "FAIL: $module — submodule is at ${gitlink:0:8}, but versions.yaml pins $pin" >&2
    status=1
  fi

  # 2. the pinned commit must be exactly the commit the published tag points at.
  git -C "$module" fetch --tags --quiet origin 2>/dev/null || true
  tag_commit=$(git -C "$module" rev-list -n1 "$version" 2>/dev/null)
  if [[ -z "$tag_commit" ]]; then
    echo "FAIL: $module — tag $version does not exist in the submodule" >&2
    status=1
  elif [[ "$tag_commit" != "$pin"* ]]; then
    echo "FAIL: $module — pin $pin is not tag $version (${tag_commit:0:8})" >&2
    status=1
  fi

  if [[ $status -eq 0 ]]; then
    echo "OK: $module $version — pin $pin matches the tag and the gitlink"
  fi
done

if [[ $status -ne 0 ]]; then
  echo >&2
  echo "The manifest and git disagree. versions.yaml may only certify a set that" >&2
  echo "git actually backs: each pin must equal both the submodule gitlink and the" >&2
  echo "commit its published tag points at." >&2
  exit 1
fi

echo "manifest-guard OK: pin ↔ tag ↔ gitlink agree for quark, nucleus, orbit"
