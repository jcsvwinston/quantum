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

## The manifest, in forty lines

The source of truth is one file,
[`versions.yaml`](https://github.com/jcsvwinston/quantum/blob/main/versions.yaml)
in the `quantum` repo. Reduced to its skeleton:

```yaml
quantum: "1.26.0"        # the SUITE's version — the manifest's, not any module's
released: 2026-09-03
status: certified

modules:                  # the three pillars — what `go get` installs
  quark:   "v1.10.0"
  nucleus: "v1.23.0"
  orbit:   "v1.8.17"

quark_modules:            # one driver module per engine
  mssql:    "v0.1.0"
  mysql:    "v0.1.0"
  oracle:   "v0.1.0"
  postgres: "v0.1.0"
  sqlite:   "v0.1.0"

nucleus_modules:          # drivers, exporters and providers, each its own module
  mssql:         "v0.1.0"
  mysql:         "v0.1.0"
  oracle:        "v0.1.0"
  postgres:      "v0.1.0"
  sqlite:        "v0.1.0"
  otlp:          "v0.1.0"
  prometheus:    "v0.1.0"
  ldap:          "v0.2.4"
  secrets-aws:   "v0.1.0"
  storage-azure: "v0.1.0"
  storage-gcs:   "v0.1.0"
  storage-s3:    "v0.1.0"

orbit_modules:            # the fleet trio and the two Quark bridges
  proto:           "v0.4.2"
  agent:           "v0.6.10"
  server:          "v0.10.11"
  quarkbridge:     "v1.8.17"
  quarkdatasource: "v1.8.17"
```

A key in a `*_modules` block is the module's last path segment: `sqlite`
under `nucleus_modules` is `github.com/jcsvwinston/nucleus/drivers/sqlite`,
`otlp` is `…/exporters/otlp`, `storage-s3` is `…/providers/storage-s3`. The
[install page](install.md) resolves every key to its full path for you.

(The versions above are a frozen illustration; the live set is
Quantum <SuiteVersion of="quantum" /> — always current on the
[install page](install.md), which is generated from this same file.)

Every certified set is a change to this file: CI builds the pinned trio
together, runs the cross-product integration suite, and verifies each
declared version against the real published tags before the set number
moves. The analogy is a Linux distribution: the distro doesn't write the
packages, it publishes a manifest of versions known to work as a whole.

## Two version numbers, two meanings

- **`quark v1.10.0`** is a real module version — what `go get` installs,
  with ordinary SemVer guarantees from that product.
- **`Quantum 1.26.0`** is the manifest's version. It names a *combination*.
  No Go module is ever `quantum@1.26.0`, and the suite number never
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
