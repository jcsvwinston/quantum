---
title: Why Quantum
sidebar_label: Why Quantum
description: "What the suite ships in the box compared with Gin + GORM, Echo, Django, Rails, Laravel and Spring Boot, axis by axis — and where each of them is ahead. Every figure links to the measurement it comes from."
---

# Why Quantum

A web application in Go usually starts from one of these shapes. You assemble
it from separate libraries — a router such as Gin or Echo, an ORM such as GORM,
and a library each for migrations, authentication, jobs and API documentation
— or you take the shape that Django, Rails, Laravel and Spring Boot have in
other languages: one framework that ships those pieces together. Quantum is
the second shape, in Go: [Nucleus](/nucleus/) hosts the application,
[Quark](/quark/intro/) is its data layer and [Orbit](/orbit/) mounts an admin
panel inside the same process.

This page compares the suite with those alternatives on concrete axes, and
says where each of them is ahead. By the end of it you should know
whether the suite fits what you are building, or which of the others does.

## Where the figures come from

Every figure about the suite on this page links to the measurement it comes
from. Most of them are **benches**: a list of controls a product keeps, each
with a probe that runs in that product's test suite and a recorded verdict —
*present*, *partial* or *absent*. A bench figure counts the controls somebody
wrote down that a probe exercises and finds present. It does not mean the
surface is complete, and it is not a score against another framework:
nothing on this page measures the others, so what it says about them is a
description, not a figure.

The suite's CI compares each figure here with its source at the
[certified set](certified-sets.md), and fails when this page stops matching.

## At a glance

| | Quantum | Gin + GORM | Echo | Django | Rails | Laravel | Spring Boot |
|---|---|---|---|---|---|---|---|
| ORM | Quark, or `pkg/db` | GORM | bring one | built in | built in | built in | JPA, Hibernate |
| Migrations | built in | `AutoMigrate`, or a tool | a tool | built in | built in | built in | Flyway, Liquibase |
| Admin panel | built in | third-party | third-party | built in | third-party | Nova (paid), Filament | none for data |
| Authentication | built in | third-party | third-party | built in | generator, gems | first-party kits | Spring Security |
| Testing kit | built in | `httptest`, assembled | `httptest`, assembled | built in | built in | built in | built in |
| OpenAPI | built in, enforced | third-party | third-party | third-party | third-party | third-party | community library |
| Background jobs | built in | third-party | third-party | task API, third-party workers | built in | built in | scheduling built in |
| Multi-tenancy | built in | by hand | by hand | third-party | third-party | third-party | Hibernate |
| You deploy | one Go binary | one Go binary | one Go binary | Python runtime, server | Ruby runtime, server | PHP runtime, server | JVM, or native image |
| Ecosystem | small, young | large | large | large | large | large | large |

"Built in" means the framework or its first-party packages; "third-party"
means a library you choose and add. The rest of this page goes through each
row.

## In the box, or assembled

With Gin or Echo you choose every piece yourself and wire it: the ORM, the
migration tool, the session store, the job queue, the OpenAPI generator. Each
piece has its own release cadence, its own configuration and its own
documentation, and keeping them compatible is your job. That is also the
strength of the approach: you can replace any one of them, and each is used
by many more applications than the suite is.

Quantum ships those pieces as Nucleus, Quark and Orbit, whose versions are
tested together and published as a [certified set](certified-sets.md). The
[quickstart](quickstart.md) gets an application with the products wired
together — the domain on Quark, the Orbit panel mounted, both bridges between
them in place — in **5** commands.

The box has a cost. A freshly scaffolded Nucleus application with the SQLite
driver resolves **138** modules and links to a **60 MB** binary, **45 MB**
stripped ([installation](/nucleus/getting-started/installation/)). A Gin or
Echo binary that carries only a router is smaller, and has fewer
dependencies to keep up to date.

Beyond Nucleus, Quark and Orbit, `nucleus add` installs the **12** optional
modules the project publishes itself — **5** database drivers, **2**
telemetry exporters, **3** object-storage providers, an LDAP backend and an
AWS Secrets Manager resolver — fetching each one and writing the import that
registers it
([the certified set](https://github.com/jcsvwinston/quantum/blob/main/versions.yaml)).
There is no registry of third-party plugins: what the suite offers is what
the project publishes and certifies.

## Admin panel

Orbit mounts inside the Nucleus process: Data Studio browses and edits your
models with their validation, search, sorting, bulk actions, import and
export; a live feed shows each request with the SQL it ran; operators get
their own sessions, role-based access control and an audit trail. The web UI
is embedded in its Go module, so there are no assets to deploy. An
application extends it from Go: actions that ask the operator for input in a
form before they run, actions on one record that answer with a page of the
panel or a file to download, cards that draw a value, a list, a table or a
line or bar chart, dashboards beyond the overview, and its own scripts and
field renderers, served under the panel's Content Security Policy; the
actions, cards and screens it adds answer to the panel's role-based access
control. The theme the panel opens in and its palette are set from
configuration. Its bench: **72 of 72** controls present
([admin bench](https://github.com/jcsvwinston/orbit/blob/main/docs/admin-bench.md)).

**Where the others are ahead.** Django's admin is the closest equivalent, has
been in production use far longer, and has a large set of third-party
extensions. Rails applications add ActiveAdmin, Administrate or Avo; Spring
Boot has nothing for editing data (Spring Boot Admin, a community project,
monitors applications). Laravel's Nova and Filament still let an application
reshape more of the interface, and have plugin ecosystems Orbit lacks: in
Orbit, a field renderer draws a value while the panel's own input still edits
it, and a screen of the application's own that is more than cards is a page
its own handler writes, linked from the panel's navigation rather than drawn
inside it. And Orbit only mounts on Nucleus: there is no standalone Orbit for
an application built on anything else.

## ORM

Quark gives typed queries through Go generics —
`quark.For[User](ctx, client).Where(...).List()` returns users, not
`interface{}` — and the same query code on PostgreSQL, MySQL, MariaDB,
SQLite, SQL Server and Oracle. Relations, soft deletes, batch writes, a cache,
read replicas, schema-diff migrations and multi-tenancy are part of the
library. Of the queries in its query bench, **58 of 60** are expressed with
the typed API, and **2** run but emit SQL that only SQLite accepts
([query bench](https://github.com/jcsvwinston/quark/blob/main/docs/query-bench.md)).
Its enterprise bench has **48 of 69** controls present, **17** partial and
**4** absent, each partial or absent row saying what is missing
([enterprise bench](https://github.com/jcsvwinston/quark/blob/main/docs/enterprise-bench.md)).

Quark's speed is measured against hand-written SQL on real PostgreSQL and
MySQL servers, not against other ORMs. On its engine bench a single-row insert
takes **1.26** times as long as through `database/sql` and **1.31** times as
long as through pgx's own pool, and a read by primary key **1.24** and
**1.30** times. The project proposes a target of at most **1.15** times each
baseline, and has not adopted it yet; **0 of 6** of its controls meet it, and
the benchmarks page says what each distance is made of
([benchmarks](/quark/reference/benchmarks/)). The comparison with GORM, ent
and sqlc that the same page keeps is dated — measured once, on SQLite,
against a release from before Quark's first stable version — and is not
quoted here.

You do not have to use Quark at all: Nucleus has its own SQL-first data layer,
and [choosing a data layer](choosing-a-data-layer.md) explains when it is
enough.

Migrations come in both styles: SQL files applied by `nucleus migrate`, or
Quark's schema diff, plan and versioned migrations. GORM has `AutoMigrate`
and leaves versioned files to a tool such as Atlas or golang-migrate; Django,
Rails and Laravel have migrations built in; Spring Boot auto-configures
Flyway or Liquibase.

**Where the others are ahead.** Hibernate, Active Record, the Django ORM and
Eloquent have run far more applications for far longer, and GORM has a much
larger user base and set of plugins in Go. The gaps Quark's own bench records
— an audit log that covers single-row writes only, optimistic locking that
does not guard deletes, a test kit with no path to engines other than SQLite
— are the kind that a long production history closes.

## Testing and OpenAPI

Nucleus's test kit boots the whole application in the test process and talks
to it over HTTP: a client that keeps cookies, fetches CSRF tokens and signs
in as a user; factories; a transaction per test; doubles for mail, storage,
the job queue and the HTTP the application makes to other services; and a
contract check for modules. The API bench that covers the kit and the
OpenAPI document has **46 of 46** controls present
([API bench](https://github.com/jcsvwinston/nucleus/blob/main/docs/api-bench.md)).

The OpenAPI document is derived from the routes, the typed handlers and the
security the application enforces. The application can validate requests
against it, a test can assert that responses conform, `nucleus openapi
--check` compares it with a baseline to catch breaking changes, and `nucleus
openapi --client typescript` generates a client. The bench's OpenAPI family:
**10 of 10** present
([API bench](https://github.com/jcsvwinston/nucleus/blob/main/docs/api-bench.md)).

Elsewhere the document comes from a library you add: swaggo, from comments,
or oapi-codegen, from a spec, for Gin and Echo; drf-spectacular for Django;
rswag for Rails; Scribe or L5-Swagger for Laravel; springdoc-openapi for
Spring Boot. Django, Rails, Laravel and Spring Boot have their test kits
built in — Django's test client and test database, Rails' fixtures and system
tests, Laravel's HTTP tests and fakes, Spring's test slices and MockMvc —
while with Gin and Echo you start from the standard library's `httptest` and
assemble the rest.

**Where the others are ahead.** Those kits are established and documented
in books and articles, and Rails and Laravel drive a real browser in their
system tests; Nucleus's kit has no browser driver. For
OpenAPI, Spring's springdoc and Django's drf-spectacular are used by far more
APIs. Nucleus generates a TypeScript client itself; for other languages you
use a generator that reads the document.

## Authentication

Nucleus serves sign-in, registration with email verification, password reset,
magic links, TOTP with recovery codes, step-up re-authentication, API keys
with scopes, OIDC sign-in and role-based access control with explicit deny
and per-object permissions. Its auth bench: **40 of 43** controls present
([auth bench](https://github.com/jcsvwinston/nucleus/blob/main/docs/auth-bench.md)).

Django ships authentication, with OIDC and MFA from packages; Rails has a
generator in recent releases and gems such as Devise; Laravel has
first-party starter kits, Fortify and Sanctum; Spring Boot has Spring
Security; Gin and Echo applications add middleware.

**Where the others are ahead.** The rows that are not present are passkeys
(WebAuthn), SAML sign-in, and an inactivity timeout that is on by default
(the setting exists and ships off).
Spring Security covers far more protocols, and Django, Rails and Laravel have
mature packages for each of them.

## Background jobs, events and real time

Nucleus ships a job queue with in-process, SQL and Redis providers — the SQL
one is durable on the database the application already has, with no broker —
a typed event bus with a transactional outbox, and WebSocket and SSE channels
with a relay between replicas. Its jobs bench: **40 of 40** controls present
([jobs bench](https://github.com/jcsvwinston/nucleus/blob/main/docs/jobs-bench.md)).

Gin and Echo applications add a queue such as asynq or River. Recent Django
releases define a task API whose workers come from a third-party backend;
Celery is the usual choice.

**Where the others are ahead.** Rails' Active Job (with Solid Queue as the
default backend in new applications), Laravel's queues and scheduler, and
Spring's scheduling and Spring Batch are built in too, and the queues people run behind them —
Sidekiq and Solid Queue for Rails, Laravel's Redis queues with Horizon,
Celery for Django — have run at a scale and for a time the suite's queue has
not.

## Multi-tenancy

Nucleus resolves the tenant of each request, Quark confines the queries to it
— a database per tenant, a schema per tenant, or rows tagged with the tenant:
added to each query by Quark on every engine, or enforced by PostgreSQL's
row-level security — and Orbit confines its views to it. When Quark adds the
tenant itself, it adds it to the operations that address a row by its key as
well: `Find` looks the key up inside the tenant, so another tenant's id is
not found; the key-based `Update` and `Delete`, the batch writes, upserts and
map updates change only the tenant's rows; and every insert and update writes
the resolved tenant, whatever the entity carried
([multi-tenant strategies](/quark/advanced/multi-tenant/)). Raw SQL is outside
that scoping — PostgreSQL's row-level security filters it in the engine — and
so are reads through a sharded client, which ignore the tenant; the
[enterprise bench](https://github.com/jcsvwinston/quark/blob/main/docs/enterprise-bench.md)
records both. The [multi-tenant tutorial](tutorial-multi-tenant-saas.md)
builds an application on it and pins the isolation down with a test.

**Where the others are ahead.** Hibernate has multi-tenancy built in — per
database, per schema or by a discriminator column — and Rails has multiple
databases and horizontal sharding built in. django-tenants, acts_as_tenant
and Tenancy for Laravel are third-party, with long production records. With
GORM or Echo you scope each query yourself, or through a plugin.

## Deployment

A Quantum application is one Go binary with the admin UI inside it. Gin and
Echo applications are one Go binary too, and smaller. Spring Boot builds an
executable JAR that runs on a JVM, or a GraalVM native image, which is one
native binary at the price of longer builds and reflection configuration.
Django, Rails and Laravel deploy a language runtime, an application server
and the dependencies — usually inside a container image.

## Ecosystem, maturity and community

Here every alternative on this page is ahead, and plainly. They have run in
production for far longer and in far more applications; they have large
communities, third-party packages for most needs, books, courses, hosting
integrations and a hiring pool. Their security processes have handled many more reports.
Quantum is a small project. What it offers in exchange is narrower: its
products' versions are tested together before they are published as a set,
and each product keeps benches that say what it cannot do yet — the figures
on this page are taken from them.

## When to choose something else

- **You need a large ecosystem, or the hiring pool of a mainstream
  framework.** Choose Django, Rails, Laravel or Spring Boot.
- **You want a router and full control over every other piece.** Choose Gin
  or Echo. Quark still works on its own in such an application.
- **You need passkeys or SAML sign-in today.** Spring Security has them, and
  Django, Rails and Laravel have packages for them.
- **You need a document database.** Quark and Nucleus are relational only.

Still here? [The quickstart](quickstart.md) builds the whole suite in a few
commands; [what is Quantum](what-is-quantum.md) explains how the products fit
together. Moving an application you already have? The guides for coming from
[Gin + GORM](coming-from-gin-gorm.md) and from [Django](coming-from-django.md)
map each piece onto the suite and port a small app.
