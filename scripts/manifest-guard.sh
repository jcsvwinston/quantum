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
  # Per-module flag: the old code keyed the OK line on the GLOBAL status, so
  # after the first failing module every healthy one went silent — the log
  # then under-reported what was actually checked.
  mod_ok=1

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
    status=1; mod_ok=0
  fi

  # 2. the pinned commit must be exactly the commit the published tag points at.
  git -C "$module" fetch --tags --quiet origin 2>/dev/null || true
  tag_commit=$(git -C "$module" rev-list -n1 "$version" 2>/dev/null)
  if [[ -z "$tag_commit" ]]; then
    echo "FAIL: $module — tag $version does not exist in the submodule" >&2
    status=1; mod_ok=0
  elif [[ "$tag_commit" != "$pin"* ]]; then
    echo "FAIL: $module — pin $pin is not tag $version (${tag_commit:0:8})" >&2
    status=1; mod_ok=0
  fi

  if [[ $mod_ok -eq 1 ]]; then
    echo "OK: $module $version — pin $pin matches the tag and the gitlink"
  fi
done

# 3. Orbit is six modules in one repo; the certification covers the five
# module tags too, not only the root pin. For each module, its LATEST
# published tag must be an ancestor of the pinned root commit AND code-
# identical to it inside the module directory — i.e. the pin does not carry
# unreleased module code, and no module tag is ahead of the pin. Until now
# this was checked by hand each audit (QM5-6); when a sibling repo cuts a new
# module tag, this goes red until the umbrella re-pins — that pressure is the
# point (the OR5-1 class of drift: a tag nobody re-pinned).
orbit_pin=$(yaml_value workspace_pins orbit)
for mod in proto agent server quarkbridge quarkdatasource; do
  latest=$(git -C orbit tag -l "$mod/v*" | grep -E "^$mod/v[0-9]+\.[0-9]+\.[0-9]+$" | sort -V | tail -1)
  if [[ -z "$latest" ]]; then
    echo "FAIL: orbit/$mod — no published tag found (did the checkout fetch tags?)" >&2
    status=1
    continue
  fi
  mod_ok=1
  if ! git -C orbit merge-base --is-ancestor "$latest" "$orbit_pin" 2>/dev/null; then
    echo "FAIL: orbit/$mod — latest tag $latest is not an ancestor of the pinned root $orbit_pin (re-pin the umbrella?)" >&2
    status=1; mod_ok=0
  fi
  if [[ $mod_ok -eq 1 && -n $(git -C orbit diff "$latest".."$orbit_pin" -- "$mod/" 2>/dev/null) ]]; then
    echo "FAIL: orbit/$mod — the pinned root carries $mod/ changes not covered by $latest (unreleased module code in the certified set)" >&2
    status=1; mod_ok=0
  fi
  # DX-25: the declared orbit_modules: version must equal the latest tag —
  # the six submodule versions used to live in a prose comment that nothing
  # enforced; now the manifest certifies 9 module versions, not 3.
  declared=$(yaml_value orbit_modules "$mod")
  if [[ -z "$declared" ]]; then
    echo "FAIL: versions.yaml orbit_modules has no entry for $mod (all six orbit modules must be declared)" >&2
    status=1; mod_ok=0
  elif [[ "$mod/$declared" != "$latest" ]]; then
    echo "FAIL: versions.yaml orbit_modules.$mod = $declared but the latest published tag is $latest" >&2
    status=1; mod_ok=0
  fi
  if [[ $mod_ok -eq 1 ]]; then
    echo "OK: orbit/$mod $latest — ancestor of the root pin, module tree identical, declared in orbit_modules"
  fi
done

# 3b. Nucleus became multi-module in v1.15.0: providers/ldap ships the LDAP
# authentication backend as its own module, so the framework does not carry an
# LDAP client. The certification covers its tag the same way it covers orbit's
# five — the manifest now certifies 10 module versions, not 9.
#
# The ancestor rule is not bureaucracy here: a module tag cut AFTER the root
# tag cannot be certified at all, because the pin must be exactly the root
# tag's commit (check 2 above). That is what forces a new module's bump to
# ride INSIDE the root's release rather than trailing it — the cascade orbit
# learned to collapse into one round.
nucleus_pin=$(yaml_value workspace_pins nucleus)
quark_pin=$(yaml_value workspace_pins quark)

# The module list is DISCOVERED from the tree, not written here. A hardcoded
# list is the same failure that let eleven modules reach `main` without a
# release-please entry: they existed, and nothing that enumerates modules
# knew it. Anything with its own go.mod under the repo (examples aside) is a
# module the set has to account for.
discover_modules() {
  local repo=$1
  (cd "$repo" && find . -name go.mod -not -path './examples/*' -not -path './website/*' \
      -not -path './benchmarks/*' -not -path './bugbash/*' -not -path './.git/*' \
    | sed 's|/go.mod$||; s|^\./||' | grep -v '^\.$' | sort)
}

# check_sibling_modules verifies §3b for one repo: each module's latest tag is
# an ANCESTOR of the pinned root, the pinned root carries no module code the
# tag does not cover, and versions.yaml declares the version. The key in the
# manifest is the module's last path segment.
check_sibling_modules() {
  local repo=$1 pin=$2 section=$3
  local mod key latest mod_ok declared
  for mod in $(discover_modules "$repo"); do
    key=${mod##*/}
    latest=$(git -C "$repo" tag -l "$mod/v*" | grep -E "^$mod/v[0-9]+\.[0-9]+\.[0-9]+$" | sort -V | tail -1)
    if [[ -z "$latest" ]]; then
      echo "FAIL: $repo/$mod — no published tag found (a module in the tree with no tag is a module nobody can `go get`; did the checkout fetch tags?)" >&2
      status=1
      continue
    fi
    mod_ok=1
    if ! git -C "$repo" merge-base --is-ancestor "$latest" "$pin" 2>/dev/null; then
      echo "FAIL: $repo/$mod — latest tag $latest is not an ancestor of the pinned root $pin (a module tag cut after the root tag cannot be certified: cut them together)" >&2
      status=1; mod_ok=0
    fi
    if [[ $mod_ok -eq 1 && -n $(git -C "$repo" diff "$latest".."$pin" -- "$mod/" 2>/dev/null) ]]; then
      echo "FAIL: $repo/$mod — the pinned root carries $mod/ changes not covered by $latest (unreleased module code in the certified set)" >&2
      status=1; mod_ok=0
    fi
    declared=$(yaml_value "$section" "$key")
    if [[ -z "$declared" ]]; then
      echo "FAIL: versions.yaml $section has no entry for $key" >&2
      status=1; mod_ok=0
    elif [[ "$mod/$declared" != "$latest" ]]; then
      echo "FAIL: versions.yaml $section.$key = $declared but the latest published tag is $latest" >&2
      status=1; mod_ok=0
    fi
    if [[ $mod_ok -eq 1 ]]; then
      echo "OK: $repo/$mod $latest — ancestor of the root pin, module tree identical, declared in $section"
    fi
  done
}

check_sibling_modules nucleus "$nucleus_pin" nucleus_modules
check_sibling_modules quark "$quark_pin" quark_modules

# 5 (checked before 4 for output grouping with the orbit sections). Cross-repo
# disclosure (QM6-1): every DIRECT require of jcsvwinston/{quark,nucleus} in
# orbit's six module go.mods must equal the certified version above OR be
# listed in declared_lags. quarkbridge shipped requiring quark v1.2.1 — two
# minors behind the certified set — while the manifest's "honest note" only
# disclosed the nucleus lag: staleness was not the lie, the omission was.
# Undisclosed staleness fails; a declared lag passes (MVS raises the version
# in any app that also requires the certified one).
for mod in . proto agent server quarkbridge quarkdatasource; do
  gomod="orbit/$mod/go.mod"
  [[ "$mod" == "." ]] && gomod="orbit/go.mod"
  for dep in quark nucleus; do
    ver=$(awk -v p="github.com/jcsvwinston/$dep" '$1 == p && $NF != "indirect" {print $2}' "$gomod")
    [[ -z "$ver" ]] && continue
    want=$(yaml_value modules "$dep")
    lag=$(yaml_value declared_lags "$dep")
    if [[ "$ver" == "$want" ]]; then
      echo "OK: $gomod — $dep $ver == certified"
    elif [[ -n "$lag" && "$ver" == "$lag" ]]; then
      echo "OK: $gomod — $dep $ver (lag DECLARED in versions.yaml; certified is $want)"
    else
      echo "FAIL: $gomod — requires $dep $ver, but the certified version is $want and no matching declared_lags entry exists (undisclosed staleness)" >&2
      status=1
    fi
  done
done

# 5b. A sibling module requires the ROOT of its own repository, and that edge
# can never be perfectly current: any release that CONTAINS the module's
# require statement is by definition later than it.
#
# It used to FAIL beyond one release behind. It no longer does, and the reason
# is worth writing down because the old rule cost a release round to fix a
# number nothing reads:
#
#   A `require` is a FLOOR, not a pin. Go picks the maximum across the build
#   (MVS), so an application using nucleus v1.23.0 together with
#   providers/ldap compiles ldap against v1.23.0 whatever ldap's go.mod says.
#   Verified with a real consumer against the public proxy, not reasoned:
#   ldap's floor read v1.21.0 and the resolved version was v1.23.0.
#
# What actually matters — that the module builds and passes against the
# CERTIFIED root — is proved by each repo's per-module CI lane, which links
# the tree under review with `go work init` precisely so the module is tested
# against the change and not against a published artefact. Measuring the floor
# was measuring a proxy for that.
#
# What stays HARD is §3b above: the module's TAG must be an ancestor of the
# pinned root. MVS does not fix that one — a tag cut after the root's is code
# the certified set does not contain.
#
# So this is an AVISO, and it carries what makes it actionable: how long the
# floor has gone unrevised, and the version that would clear it.
for gomod in $(find nucleus quark orbit -name go.mod -not -path '*/examples/*' -not -path '*/website/*' -not -path '*/benchmarks/*' -not -path '*/bugbash/*' 2>/dev/null | grep -vE '^(nucleus|quark|orbit)/go.mod$'); do
  repo=${gomod%%/*}
  case "$repo" in
    nucleus) parent="github.com/jcsvwinston/nucleus" ;;
    quark)   parent="github.com/jcsvwinston/quark" ;;
    orbit)   parent="github.com/jcsvwinston/orbit" ;;
  esac
  ver=$(awk -v p="$parent" '$1 == p && $NF != "indirect" {print $2}' "$gomod")
  # A module that does not require its own root is not a gap: drivers that
  # only register a database/sql driver need nothing from the framework.
  [[ -z "$ver" ]] && continue

  want=$(yaml_value modules "$repo")
  if [[ "$ver" == "$want" ]]; then
    echo "OK: $gomod — $repo $ver == certified"
    continue
  fi

  # How long the floor has gone unrevised, measured from the tag it names.
  when=$(git -C "$repo" log -1 --format=%cI "$ver" 2>/dev/null || true)
  age="antigüedad desconocida"
  if [[ -n "$when" ]]; then
    days=$(( ( $(date +%s) - $(date -j -f '%Y-%m-%dT%H:%M:%S%z' "${when%%+*}+0000" +%s 2>/dev/null || date -d "$when" +%s 2>/dev/null || echo 0) ) / 86400 ))
    [[ "$days" -ge 0 ]] && age="$days día(s) sin revisar"
  fi

  prev=$(git -C "$repo" tag -l 'v[0-9]*.[0-9]*.[0-9]*' | sort -V | grep -B1 -x "$want" | head -1)
  if [[ "$ver" == "$prev" ]]; then
    echo "AVISO: $gomod — $repo $ver, una release por detrás de la certificada $want ($age). Es el borde topológico forzado: una release del root no puede preceder al require que contiene. Se deja al día subiéndolo a $want en el tren siguiente."
  else
    echo "AVISO: $gomod — $repo $ver, VARIAS releases por detrás de la certificada $want ($age). El require es un SUELO y MVS resuelve al máximo, así que un consumidor compila igual contra $want; lo que sí falta es haberlo revisado. Se deja al día subiéndolo a $want."
  fi
done

# 4b. The README's orbit module table repeats the five sibling versions —
# hardcoded, they drifted within one train of being added (DX-17, when only
# the two bridges carried a version). Since the 2026-09-03 audit (QM-15) the
# README has ONE table for orbit's five siblings, every row with its version,
# and each must equal the declared orbit_modules version. bump-set.sh rewrites
# the same rows.
for mod in proto agent server quarkbridge quarkdatasource; do
  readme_v=$(grep "orbit/$mod\`" README.md | grep -o 'v[0-9][0-9.]*[0-9]' | head -1 || true)
  declared=$(yaml_value orbit_modules "$mod")
  if [[ -z "$readme_v" ]]; then
    echo "FAIL: README.md — orbit module table row for $mod not found or carries no version" >&2
    status=1
  elif [[ "$readme_v" != "$declared" ]]; then
    echo "FAIL: README.md orbit module table says $mod $readme_v but versions.yaml declares $declared" >&2
    status=1
  else
    echo "OK: README orbit module table — $mod $readme_v matches orbit_modules"
  fi
done

# 4. The README's pillar table repeats the three module versions. It drifted
# once already (fixed by hand in the 1.4.0 certification) and nothing guarded
# it — a hardcoded version with no check, the exact failure class of the 5ª
# ronda. Each row's first version must equal the manifest's.
for module in quark nucleus orbit; do
  # Row format: | **Nucleus** | … | `v1.3.1` | …
  cap=$(printf '%s' "$module" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
  readme_v=$(grep -i "^| \*\*$cap\*\*" README.md | grep -o 'v[0-9][0-9.]*[0-9]' | head -1 || true)
  manifest_v=$(yaml_value modules "$module")
  if [[ -z "$readme_v" ]]; then
    echo "FAIL: README.md — pillar table row for $cap not found or carries no version" >&2
    status=1
  elif [[ "$readme_v" != "$manifest_v" ]]; then
    echo "FAIL: README.md pillar table says $cap $readme_v but versions.yaml certifies $manifest_v" >&2
    status=1
  else
    echo "OK: README pillar table — $cap $readme_v matches the manifest"
  fi
done

if [[ $status -ne 0 ]]; then
  echo >&2
  echo "The manifest and git disagree. versions.yaml may only certify a set that" >&2
  echo "git actually backs: each pin must equal both the submodule gitlink and the" >&2
  echo "commit its published tag points at." >&2
  exit 1
fi

echo "manifest-guard OK: pin ↔ tag ↔ gitlink agree for quark, nucleus, orbit — and every sibling module tag DISCOVERED in the three trees backs its pinned root"
