---
title: Install the certified set
sidebar_label: Install
sidebar_position: 3
description: "The go get lines and the full require block for the current certified set — generated from the suite manifest at build time, never hand-copied."
---

import {SuiteVersion, CertifiedRequire, GoGetPillar} from '@site/src/components/CertifiedSet';

# Install the certified set

The current certified set is **Quantum <SuiteVersion of="quantum" />**:
Quark <SuiteVersion of="quark" />, Nucleus <SuiteVersion of="nucleus" />
and Orbit <SuiteVersion of="orbit" />, tested together. Every version on
this page is generated from the suite manifest
([`versions.yaml`](https://github.com/jcsvwinston/quantum/blob/main/versions.yaml))
when the site is built — nothing here is copied by hand, so it cannot go
stale.

There is no "suite installer": each pillar is an ordinary Go module you
`go get`. What the set gives you is the answer to *which versions*.

## One pillar at a time

Only the data layer:

<GoGetPillar pillar="quark" />

The web framework (and its CLI):

<GoGetPillar pillar="nucleus" />

```bash
go install github.com/jcsvwinston/nucleus/cmd/nucleus@latest
```

The admin panel (requires Nucleus in the same app):

<GoGetPillar pillar="orbit" />

## The whole set, as a require block

Nine modules make up a certified set: the three pillars, Nucleus's
LDAP provider, and Orbit's five submodules (the fleet trio plus the two
Quark bridges). Paste what you need into your `go.mod`:

<CertifiedRequire />

Two honest notes about that block:

- **`go mod tidy` will prune what you don't import.** That is fine — the
  block's job is to pin the modules you *do* use at certified versions,
  not to force nine dependencies on every app.
- **Go may resolve higher, never lower.** These are minimum versions:
  another dependency can pull a pillar above the certified set (Go's
  version selection takes the maximum of the minimums). Between sets each
  product keeps releasing on its own — see
  [certified sets](certified-sets.md) for the upgrade policy.

## Which module do I actually need?

| If you use… | Add |
|---|---|
| Quark alone, or as a Nucleus app's data layer | `quark` |
| A web application | `nucleus` |
| The admin panel on a Nucleus app | `orbit` |
| Data Studio over Quark models | `orbit/quarkdatasource` |
| Quark SQL in Orbit's live feed | `orbit/quarkbridge` |
| Fleet observability (multi-node admin) | `orbit/agent`, `orbit/server`, `orbit/proto` |
| LDAP authentication in Nucleus | `nucleus/providers/ldap` |

The [quickstart](quickstart.md) uses the first five and shows where each
one enters.

## Developing against the suite source

To work on the products themselves (or run the integration examples from
source), clone the umbrella repo with submodules — it pins each product's
checkout to the certified set and ships a ready `go.work`:

```bash
git clone --recurse-submodules https://github.com/jcsvwinston/quantum.git
```
