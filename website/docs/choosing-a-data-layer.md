---
title: Choosing a data layer
sidebar_position: 4
description: "Nucleus ships its own SQL-first data layer; Quark is a full ORM. An honest comparison, including when you don't need Quark at all."
---

# Choosing a data layer

A Nucleus app has two good options for talking to its database, and this
page exists because the honest answer is **not** "always use the suite's
ORM". Nucleus was designed SQL-first on purpose; Quark earns its place
only when its features are ones you'll actually use.

## The two options

**`pkg/db` + `pkg/model`** — what Nucleus ships. A thin, deliberate layer
over `database/sql`: connection management, health checks, telemetry, and
struct metadata for scaffolding. You write SQL. Migrations are SQL files
applied by the CLI (`nucleus migrate`), reviewable in a PR diff and
reversible. There is no query builder and no ORM — that is a design
decision of the framework, not a gap.

**Quark** — a full ORM, and a product of its own. Typed queries through
Go generics (`quark.For[User](ctx, client).Where(...).List()` returns
`[]User`, no casts), the same query code across six SQL engines,
relations with eager loading, soft deletes, batch operations, an L2
cache, and native multi-tenancy up to PostgreSQL row-level security.
Schema comes from struct tags; migrations can be derived or versioned.

## When `pkg/db` is enough

- **You like SQL.** If your team reads and reviews SQL comfortably, the
  framework's migration discipline (SQL files in the repo, applied in
  order, drift detection) is a feature, not friction.
- **The queries are few and known.** A service with a dozen well-understood
  statements doesn't amortize an ORM's concepts.
- **You want the smallest dependency surface.** `pkg/db` is already in the
  framework; Quark is a second data-access vocabulary to learn and keep
  consistent.
- **One database engine, forever.** Cross-engine portability is one of
  Quark's main dividends; if you'll never leave PostgreSQL, you're not
  collecting it.

Orbit note: Data Studio browses the models in the app's `pkg/model`
registry out of the box — you don't need Quark for an admin CRUD.

## When Quark earns its place

- **Typed reads and writes.** No `Scan` boilerplate, no `interface{}`;
  the compiler checks what the database returns.
- **More than one engine.** The same query code runs on PostgreSQL,
  MySQL, MariaDB, SQLite, SQL Server and Oracle — switching is one
  connection string. (Tests on SQLite, production on Postgres, with the
  caveats that always implies.)
- **Relations you'd otherwise hand-join.** `belongs_to` / eager loading
  (`Preload`) replace a family of repetitive JOINs and N+1 traps.
- **Multi-tenancy as a first-class concern.** Database-per-tenant,
  schema-per-tenant, or row-level security — client-side or PostgreSQL
  native — without threading tenant IDs through every query by hand.
- **The operational extras** — L2 cache with stampede protection, read
  replicas, audit hooks — when you'd otherwise build them around
  `database/sql` yourself.

With Quark you add the two small bridges when you want the suite
experience: `orbit/quarkdatasource` puts Quark models in Data Studio,
`orbit/quarkbridge` puts Quark's SQL in the live feed. Both are shown in
the [quickstart](quickstart.md), steps 4 and 5.

## Can I mix them?

Yes, and the [quickstart](quickstart.md) app does: Nucleus manages its
own app database (auth, sessions, framework tables) through `pkg/db`
while the domain runs on Quark — in that demo, sharing one SQLite file.
The two layers don't fight; they just don't share a vocabulary. What you
should *not* do is access the same tables through both layers and expect
either one's caching or hooks to see the other's writes.

## Deciding in one sentence

If you'd describe your data needs as "SQL plus discipline", stay on
`pkg/db` and enjoy the smaller surface. If you'd describe them as "typed
models with relations, possibly across engines or tenants", take Quark —
[its getting started](/quark/guides/getting-started/) is ten minutes.
