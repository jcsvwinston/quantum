---
title: "Quickstart: the suite in five commands"
sidebar_label: Quickstart
sidebar_position: 2
description: "One command writes a Nucleus app with the domain on Quark and the Orbit admin mounted, both bridges wired; go run boots it. Then read the files it wrote."
concepts:
  - nucleus.New
  - orbit.Module
  - quark.New
  - quarkdatasource.New
  - quarkbridge.New
embeds:
  - 'main.go | ^// Command blog | nucleus.New( | quark.New( | shop.Migrate( | quarkdatasource.New( | quarkdatasource.Register[ | orbit.Module( | DataSource: | Mount( | Start()'
  - 'shop/models.go | type Author struct | type Article struct | rel:"belongs_to" | db:"'
  - 'shop/module.go#L24-L66 | ^// Module returns | func Module( | Policies: | CSRFExempt: | OnStart: | quarkbridge.New(rt.Observability()) | Routes: | }.Build() | }$'
---

import {GoInstallCLI} from '@site/src/components/CertifiedSet';

# The suite in five commands

One command writes a small application with all three pillars wired: a
**Nucleus** app whose domain runs on the **Quark** ORM, with the **Orbit**
admin panel mounted on top and the two bridges between them. `go run .`
boots it. The rest of this page reads the files the command wrote — five
ideas, one paragraph each.

Everything runs on SQLite, so there is nothing to install beyond Go and one
CLI. The commands and outputs below are run against the
[current certified set](install.md) by this site's CI before they are
published.

If you only want one pillar, [Quark alone](/quark/guides/getting-started/)
and [Nucleus alone](/nucleus/getting-started/quickstart/) have their own
pages. The same scaffold told from the framework's side, flag by flag, is
[Start a suite app](/nucleus/getting-started/suite-app/).

## 1 — Install the CLI

Go 1.26 or newer, and the Nucleus CLI at the certified tag (`@latest` can
run ahead of the set this page was verified against):

<GoInstallCLI />

## 2 — Scaffold and run

```bash
nucleus new blog --template suite --with orbit,quark,quarkbridge,quarkdatasource
```

`--template suite` already implies the four `--with` modules; naming them
says what arrives. The command fetches them from the module proxy at their
published tags, together with the SQLite driver module of each product,
and leaves `go.mod` tidy: the project builds as written. `--db postgres`
(or `mysql`, `sqlserver`, `oracle`) moves both products to another engine;
`--offline` skips the network and prints the `go get` line to run later.

```bash
cd blog && go run .
```

The last lines look like this. Every line is `INFO` — a clean scaffold boots with
zero warnings:

```
level=INFO msg="nucleus: module policies loaded into the live enforcer (in-memory only — the host policy file is never written; a host deny row overrides these)" module=shop declarations=3 rules=3
level=INFO msg="orbit: admin panel ready" prefix=/admin
level=INFO msg="shop: quark client bridged to the live SQL feed"
level=INFO msg="nucleus: module route mounted" module=orbit method=* pattern=/admin/*
level=INFO msg="nucleus: module route mounted" module=shop method=GET pattern=/api/authors
level=INFO msg="nucleus: module route mounted" module=shop method=GET pattern=/api/articles
level=INFO msg="nucleus: module route mounted" module=shop method=POST pattern=/api/articles
level=INFO msg="nucleus: server listening" addr=0.0.0.0:8080 url=http://0.0.0.0:8080
```

## 3 — Try the API

```bash
curl -s localhost:8080/api/articles
```

```json
{"articles":[{"ID":1,"AuthorID":1,"Title":"Hello, Quantum","Body":"Nucleus + Quark + Orbit, wired together.","Author":{"ID":0,"Name":""}}],"count":1}
```

```bash
curl -s -X POST localhost:8080/api/articles \
    -H 'Content-Type: application/json' \
    -d '{"author_id":1,"title":"probe","body":"live feed"}'
```

```json
{"ID":2,"AuthorID":1,"Title":"probe","Body":"live feed","Author":{"ID":0,"Name":""}}
```

That answered `201`. Post the same title again and it answers `409`:
titles are unique, and the Quark driver module that recognises the engine's
duplicate-key error is linked. A path nothing serves — `localhost:8080/nope`
— answers `404`: routing runs before the authorizer, so a route that does
not exist says so; a route that exists and that no policy grants answers
`403`.

Then open **http://localhost:8080/admin** — user `admin`, password
`quickstart` (`ADMIN_BOOTSTRAP_PASSWORD`, read on first boot, replaces it;
the fallback is a development credential for a laptop). The **live view**
shows the Quark statements the two calls above ran, each correlated to its
request; **Data Studio** browses and edits `Author` and `Article`.

## 4 — Read what was generated

Ten files (eleven with `go.sum`). The three below are the whole wiring;
`nucleus.yml` and `rbac_policy.csv` are the framework's own configuration,
and `shop/module_test.go` boots the module in-process (`go test ./...`).
The listings are what the command you just ran writes, checked against it on
every run of the suite's quickstart lane.

### `main.go` — the composition root

```go
// Command blog is a Quantum suite application, generated by
// `nucleus new --template suite`: a Nucleus application whose domain runs on
// the Quark ORM, with the Orbit admin panel mounted on top and both bridges
// between them wired.
//
//   - The shop module's HTTP handlers query Quark through a client wrapped
//     with orbit/quarkbridge, so every statement appears in Orbit's live SQL
//     feed, correlated to the request.
//   - Orbit's Data Studio is backed by orbit/quarkdatasource over the same
//     Quark models, so /admin browses and edits them.
//
// # Run
//
//	go run .
//
//	curl -s localhost:8080/api/articles
//	curl -s -X POST localhost:8080/api/articles \
//	    -H 'Content-Type: application/json' \
//	    -d '{"author_id":1,"title":"probe","body":"live feed"}'
//
// Admin: http://localhost:8080/admin — user admin, password from
// ADMIN_BOOTSTRAP_PASSWORD (default "quickstart"). Watch the live SQL view
// while hitting the API; browse Author and Article in Data Studio.
package main

import (
	"context"
	"log"
	"os"

	"github.com/jcsvwinston/nucleus/pkg/nucleus"
	"github.com/jcsvwinston/orbit"
	"github.com/jcsvwinston/orbit/quarkdatasource"
	"github.com/jcsvwinston/quark"

	// Both products link their database driver as a module, and each
	// module registers more than the driver: the error classifier that
	// turns a duplicate key into "that title is taken" (409) instead of an
	// internal error. Importing the bare database/sql driver would boot just
	// the same — and silently lose both classifiers.
	_ "github.com/jcsvwinston/nucleus/drivers/sqlite"
	_ "github.com/jcsvwinston/quark/drivers/sqlite"

	"example.com/blog/shop"
)

func main() {
	ctx := context.Background()

	// Quark owns the domain schema. It opens the same sqlite database
	// nucleus.yml names (databases.default.url), which Orbit uses for its
	// admin_users table; switch both when you move to another engine.
	client, err := quark.New("sqlite", "app.db")
	if err != nil {
		log.Fatalf("blog: quark client: %v", err)
	}
	defer client.Close()

	if err := shop.Migrate(ctx, client); err != nil {
		log.Fatalf("blog: migrate/seed: %v", err)
	}

	// Data Studio speaks Orbit's datasource contract; back it with Quark.
	ds := quarkdatasource.New(client)
	if err := quarkdatasource.Register[shop.Author](ds); err != nil {
		log.Fatalf("blog: register Author: %v", err)
	}
	if err := quarkdatasource.Register[shop.Article](ds); err != nil {
		log.Fatalf("blog: register Article: %v", err)
	}

	// Full app (no WithoutDefaults): the default-deny enforcer is active.
	// rbac_policy.csv grants anonymous the framework endpoints; the shop
	// module carries its own rows for /api (module.go), and Orbit enforces
	// its own session login under /admin, so neither needs a row here.
	if err := nucleus.New().
		FromConfigFile("nucleus.yml").
		Mount(shop.Module(client)).
		Mount(orbit.Module(orbit.Config{
			Prefix:     "/admin",
			Title:      "blog",
			DataSource: ds,

			// The first admin account, created on first boot when the
			// admin_users table is empty. The password comes from the
			// environment; the fallback is a development credential for a
			// laptop, never for a network.
			BootstrapUsername: "admin",
			BootstrapEmail:    "admin@example.com",
			BootstrapPassword: bootstrapPassword(),
		})).
		Start(); err != nil {
		log.Fatalf("blog: %v", err)
	}
}

// bootstrapPassword is ADMIN_BOOTSTRAP_PASSWORD, or "quickstart" when the
// variable is unset — the credential the docs and the smoke tests log in
// with. Set the variable before the app faces anyone but you.
func bootstrapPassword() string {
	if p := os.Getenv("ADMIN_BOOTSTRAP_PASSWORD"); p != "" {
		return p
	}
	return "quickstart"
}
```

**`nucleus.New()` is the application.** The builder reads `nucleus.yml`,
mounts modules and starts the server: everything the application is made
of enters through a `Mount(...)` call, and the chain ends in `Start()`.
Nothing is registered globally, which is why the test in `shop/` can build
the same chain with the shop module alone on a temporary database.

**`quark.New(...)` opens the domain database.** The client takes a dialect
and a DSN — here the same SQLite file `nucleus.yml` names, so one database
holds the framework's tables, Orbit's admin accounts and your models.
`shop.Migrate` registers the two models, creates their tables and seeds an
author/article pair when the tables are empty.

**`quarkdatasource.New(client)` puts the models in Data Studio.** Data
Studio speaks Orbit's datasource contract, not Quark's; the datasource
implements that contract over the Quark client, `quarkdatasource.Register[T]`
names each model, and `orbit.Config.DataSource` hands it to the panel.

**`orbit.Module(orbit.Config{...})` is the admin panel.** One `Mount` with a
prefix, the datasource and the first admin account. The interface is
embedded in the Orbit module and reads everything from the running app —
no assets to deploy, no database of its own — and it brings its own session
login under `/admin`, so it needs no policy row.

### `shop/models.go` — two Quark models

```go
// Package shop is the application's domain: two Quark models and the HTTP
// routes that exercise them, so Orbit's live SQL feed has real traffic to
// show and Data Studio has rows to browse. Replace it with your own feature;
// the wiring in main.go stays the same.
package shop

// Author is a Quark model (an Active Record struct with Quark tags).
type Author struct {
	ID   int64  `db:"id" pk:"true"`
	Name string `db:"name" quark:"not_null"`
}

// Article belongs to an Author. The rel tag lets Data Studio surface the
// relationship (quarkdatasource maps belongs_to to a foreign key).
type Article struct {
	ID       int64  `db:"id" pk:"true"`
	AuthorID int64  `db:"author_id" quark:"not_null"`
	Title    string `db:"title" quark:"not_null,unique"`
	Body     string `db:"body"`

	Author Author `rel:"belongs_to" join:"author_id"`
}
```

Plain structs with tags. `rel:"belongs_to"` is what lets Data Studio show
the relationship between an article and its author.

### `shop/module.go` — the module and its rules

```go
// Module returns the shop feature as a nucleus module. The request handlers
// use the bridged client; Data Studio (wired in main via quarkdatasource)
// uses the base client, so admin browsing does not flood the live feed.
func Module(base *quark.Client) nucleus.ModuleSpec {
	m := &module{base: base}

	return nucleus.Module[struct{}]{
		Name: "shop",

		// The module opens its own routes under the default-deny enforcer;
		// nothing in rbac_policy.csv mentions /api. Anonymous callers can
		// read both lists and CREATE an article — the create row is a
		// development default so the first `curl -X POST` lands; scope it
		// to a role ({Subject: "editor", ...}) before the app faces a
		// network. An operator deny in the host CSV always overrides.
		Policies: []nucleus.PolicyRule{
			{Subject: "anonymous", Object: "/api/authors", Action: "read"},
			{Subject: "anonymous", Object: "/api/articles", Action: "read"},
			{Subject: "anonymous", Object: "/api/articles", Action: "create"},
		},
		// A header-token JSON API is not CSRF-forgeable; the exemption keeps
		// curl and SDK clients working while the browser routes stay guarded.
		CSRFExempt: []string{"/api/"},

		OnStart: func(ctx context.Context, rt nucleus.Runtime, _ struct{}) error {
			bridged, err := m.base.WithOptions(
				quark.WithMiddleware(quarkbridge.New(rt.Observability())),
			)
			if err != nil {
				return fmt.Errorf("shop: derive bridged quark client: %w", err)
			}
			m.bridged = bridged
			rt.Logger().Info("shop: quark client bridged to the live SQL feed")
			return nil
		},

		Routes: func(r nucleus.Router, _ struct{}) {
			r.Get("/api/authors", m.listAuthors)
			r.Get("/api/articles", m.listArticles)
			r.Post("/api/articles", m.createArticle)
		},
	}.Build()
}
```

**A module carries its own rules.** `Policies` are the rows the
default-deny enforcer needs for `/api/…`; nothing in `rbac_policy.csv`
mentions the API, and an operator deny there always overrides. Anonymous
`create` is a development default so the `curl -X POST` above lands —
scope it to a role before the app faces a network. `CSRFExempt` frees the
JSON API from the origin check: a header-token API cannot be forged by a
cross-site form, while the admin login form stays guarded.

**`quarkbridge.New(rt.Observability())` is the live SQL feed.** Orbit sees
every request the app serves, but the SQL Quark runs is invisible to it
until Quark publishes its statements onto the framework's observability
bus. The bridge is a Quark middleware that does exactly that. `OnStart`
derives a second client wrapped with it once the runtime exists, and the
handlers use that one; the base client from `main.go` stays unbridged, so
browsing in Data Studio does not flood the feed you are watching.

## Where to next

| You want to… | Read |
| --- | --- |
| The same scaffold from the framework's side: `--db`, `--offline`, `--with` on the other templates | [Start a suite app](/nucleus/getting-started/suite-app/) |
| Rebuild and restart on every save | `nucleus dev` in the [CLI overview](/nucleus/cli/overview/) |
| Add your next feature | `nucleus generate module notes --mount --data quark` writes a slice on the same ORM and mounts it in `main.go` — [CLI overview](/nucleus/cli/overview/) |
| Browse and edit the models from the panel | [Data Studio](/orbit/features/#data-studio) |
| Watch the SQL arrive, request by request | [Bridging Quark statements](/orbit/features/#bridging-quark-orm-statements) into the live view |
| Pin the exact versions this page was verified against | [Install the certified set](install.md) |
| Decide whether Quark or `pkg/db` fits your app | [Choosing a data layer](choosing-a-data-layer.md) |
| Understand what "certified set" means | [Certified sets](certified-sets.md) |
