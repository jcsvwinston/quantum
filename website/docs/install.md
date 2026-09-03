---
title: Install the certified set
sidebar_label: Install
sidebar_position: 3
description: "The go get lines and the full require block for the current certified set — generated from the suite manifest at build time, never hand-copied."
---

import {SuiteVersion, CertifiedRequire, GoGetPillar, GoInstallCLI} from '@site/src/components/CertifiedSet';

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

The web framework (and its CLI, at the same certified tag — `@latest` can
run ahead of the set):

<GoGetPillar pillar="nucleus" />

<GoInstallCLI />

The admin panel (requires Nucleus in the same app):

<GoGetPillar pillar="orbit" />

## The whole set, as a require block

A certified set is more than the three pillars. Each product ships its
optional pieces as separate modules — database drivers, telemetry exporters,
cloud storage and LDAP for Nucleus; one driver module per engine for Quark;
the fleet trio and the two Quark bridges for Orbit — and the set pins every
one of them. This is the full block, generated from the manifest's four
module blocks. Paste what you need into your `go.mod`:

<CertifiedRequire />

Two honest notes about that block:

- **`go mod tidy` will prune what you don't import.** That is fine — the
  block's job is to pin the modules you *do* use at certified versions,
  not to force every dependency on every app.
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
| **A database, in Nucleus** (one module per engine; no app starts without one) | `nucleus/drivers/{postgres,mysql,sqlite,mssql,oracle}` |
| **A database, in Quark** (registers the driver *and* its error classifier) | `quark/drivers/{postgres,mysql,sqlite,mssql,oracle}` |
| Data Studio over Quark models | `orbit/quarkdatasource` |
| Quark SQL in Orbit's live feed | `orbit/quarkbridge` |
| Fleet observability (multi-node admin) | `orbit/agent`, `orbit/server`, `orbit/proto` |
| A `/metrics` endpoint for Prometheus to scrape | `nucleus/exporters/prometheus` |
| Traces and metrics pushed to an OTLP collector | `nucleus/exporters/otlp` |
| S3 (or compatible), Google Cloud Storage, Azure Blob | `nucleus/providers/storage-{s3,gcs,azure}` |
| AWS Secrets Manager | `nucleus/providers/secrets-aws` |
| LDAP authentication in Nucleus | `nucleus/providers/ldap` |

Every optional module is a `go get` plus a blank import, and the import is
the step people forget — the build succeeds without it and the failure
arrives at run time. The Nucleus CLI does both in one step:

```bash
nucleus add sqlite prometheus    # go get + the `_` import, for each name
nucleus add --help               # the list of names it knows
```

Configuration does not change when you add a module: `database_url`,
`otlp_endpoint`, `metrics_path` and `storage.provider` mean what they
always meant. If the module a setting needs is not linked, startup stops
with the two lines that fix it.

The [quickstart](quickstart.md) uses the pillars, both SQLite driver
modules and the two bridges, and shows where each one enters.

## Developing against the suite source

To work on the products themselves (or run the integration examples from
source), clone the umbrella repo with submodules — it pins each product's
checkout to the certified set and ships a ready `go.work`:

```bash
git clone --recurse-submodules https://github.com/jcsvwinston/quantum.git
```
