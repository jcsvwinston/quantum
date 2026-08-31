---
title: Certified sets
sidebar_position: 5
description: "What versions.yaml is, what a suite version number means, and how to upgrade: move between certified sets, not between individual tags."
---

import {SuiteVersion} from '@site/src/components/CertifiedSet';

# Certified sets

Three products with independent release cadences will drift apart — unless
someone regularly picks a trio of versions, tests them together, and
publishes the result. That is what a **certified set** is, and it is the
entire job of the umbrella repo.

## The manifest, in twenty lines

The source of truth is one file,
[`versions.yaml`](https://github.com/jcsvwinston/quantum/blob/main/versions.yaml)
in the `quantum` repo. Reduced to its skeleton:

```yaml
quantum: "1.24.0"        # the SUITE's version — the manifest's, not any module's
released: 2026-08-30
status: certified

modules:                  # the real versions people install with `go get`
  quark:   "v1.7.1"
  nucleus: "v1.21.0"
  orbit:   "v1.8.13"

nucleus_modules:          # separately-published modules of each repo
  ldap: "v0.2.3"
orbit_modules:
  proto: "v0.4.2"
  agent: "v0.6.8"
  server: "v0.10.8"
  quarkbridge: "v0.4.8"
  quarkdatasource: "v0.2.17"
```

(The versions above are a frozen illustration; the live set is
Quantum <SuiteVersion of="quantum" /> — always current on the
[install page](install.md), which is generated from this same file.)

Every certified set is a change to this file: CI builds the pinned trio
together, runs the cross-product integration suite, and verifies each
declared version against the real published tags before the set number
moves. The analogy is a Linux distribution: the distro doesn't write the
packages, it publishes a manifest of versions known to work as a whole.

## Two version numbers, two meanings

- **`quark v1.7.1`** is a real module version — what `go get` installs,
  with ordinary SemVer guarantees from that product.
- **`Quantum 1.24.0`** is the manifest's version. It names a *combination*.
  No Go module is ever `quantum@1.24.0`, and the suite number never
  substitutes for a module's own tag.

Between sets, each product keeps releasing on its own cadence — a Quark
patch may exist for days before a set certifies it alongside the others.

## Upgrade policy

- **Upgrade by set.** When you use two or more pillars together, move all
  of them to the versions of one certified set in one commit — the
  [install page](install.md) has the current set as a pasteable `require`
  block. That is the combination that was tested; mixing "this set's
  Nucleus with last month's Orbit" is exactly the state the manifest
  exists to avoid.
- **Single-pillar apps can ignore all of this.** If you only use Quark,
  follow Quark's own releases; the set adds no information for you.
- **A newer patch of one pillar is usually safe** — Go's version
  resolution may force one on you before the next set certifies it. Sets
  certify combinations frequently enough that you rarely need to wait
  long for an official trio.
- **Majors move in lockstep.** A major version bump of any pillar only
  lands through a coordinated suite release, with migration notes in the
  products' own release notes.

The full history of sets lives in the manifest's git log — every certified
combination since the first one, one commit each.
