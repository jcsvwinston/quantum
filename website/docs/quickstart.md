---
title: "Quickstart: the suite in ~15 minutes"
sidebar_label: Quickstart
sidebar_position: 2
description: "One small app, all three pillars: scaffold a Nucleus app, mount the Orbit admin, put the domain on Quark, browse it in Data Studio and watch the SQL arrive in the live feed."
---

# The suite in ~15 minutes

By the end of this page you'll have one small application with all three
pillars working together: a **Nucleus** app whose domain runs on the
**Quark** ORM, with the **Orbit** admin mounted on top — where you can
browse your models in Data Studio and watch every SQL statement arrive in
the live feed as you `curl` the API.

It takes about fifteen minutes. Everything runs on SQLite, so there is
nothing to install beyond Go and one CLI. Every snippet below was compiled
and run against the [current certified set](install.md) before being
published, and the outputs shown are real.

If you only want **one** pillar, this is not your page:
[Quark alone](/quark/guides/getting-started/) or
[Nucleus alone](/nucleus/getting-started/quickstart/) each have their own
quickstart. This one exists to show the seams — the two small bridges that
make three separate products behave like a suite.

## 0 — Prerequisites

Go 1.26 or newer, and the Nucleus CLI:

```bash
go install github.com/jcsvwinston/nucleus/cmd/nucleus@latest
```

## 1 — Scaffold a Nucleus app (2 min)

```bash
nucleus new blog
cd blog
go mod tidy
go run .
```

`nucleus new` writes a minimal skeleton: a composition-root `main.go`,
`nucleus.yml`, an RBAC policy file, and an empty `migrations/` directory.
No feature code — the first module will be yours. It serves on port `8080`:

```bash
curl -s localhost:8080/healthz
```

```json
{"status":"healthy","checked_at":"2026-08-31T04:13:13Z","checks":[{"name":"db:default","status":"healthy"},{"name":"storage","status":"healthy"}]}
```

:::note Any other route answers 403, and that's intentional
The scaffold ships with a **default-deny** authorizer: a route that no
policy grants is forbidden, even before it exists. You'll see how this
quickstart deals with that in step 3 — and what to do instead in a real
app.
:::

## 2 — Mount the Orbit admin (3 min)

Orbit is one dependency and one `Mount(...)` call. Edit `main.go`:

```go
package main

import (
	"log"

	"github.com/jcsvwinston/nucleus/pkg/nucleus"
	"github.com/jcsvwinston/orbit"
)

func main() {
	if err := nucleus.New().
		FromConfigFile("nucleus.yml").
		Mount(orbit.Module(orbit.Config{
			Prefix: "/admin",
			Title:  "Blog",

			// Local demo credentials — change them anywhere beyond a laptop.
			BootstrapUsername: "admin",
			BootstrapEmail:    "admin@example.com",
			BootstrapPassword: "quickstart",
		})).
		Start(); err != nil {
		log.Fatalf("blog: %v", err)
	}
}
```

```bash
go get github.com/jcsvwinston/orbit
go mod tidy
go run .
```

The startup log now includes:

```
level=INFO msg="orbit: admin panel ready" prefix=/admin
```

Open **http://localhost:8080/admin** and log in (`admin` / `quickstart` —
the bootstrap credentials above; Orbit created the user on first boot).
The panel is already live: request feed, sessions, system metrics. Data
Studio is still empty — there are no models yet. Let's fix that.

:::note The panel is embedded, not deployed
The React interface ships inside the Orbit Go module (`go:embed`). There
is no asset pipeline, no separate process, no database of Orbit's own —
it reads everything from the running app.
:::

## 3 — Put the domain on Quark (5 min)

Now the data layer. Two models and three routes, in a `shop` package.

**`shop/models.go`** — Quark models are plain structs with tags:

```go
// Package shop is the application's domain: two Quark models and the HTTP
// routes that use them.
package shop

// Author is a Quark model: a plain Go struct with tags.
type Author struct {
	ID   int64  `db:"id" pk:"true"`
	Name string `db:"name" quark:"not_null"`
}

// Article belongs to an Author. The rel tag lets Orbit's Data Studio surface
// the relationship.
type Article struct {
	ID       int64  `db:"id" pk:"true"`
	AuthorID int64  `db:"author_id" quark:"not_null"`
	Title    string `db:"title" quark:"not_null"`
	Body     string `db:"body"`

	Author Author `rel:"belongs_to" join:"author_id"`
}
```

**`shop/module.go`** — a Nucleus module that carries the Quark client and
registers the routes. `Migrate` creates the tables and seeds one
author/article pair so the app has data on first boot:

```go
package shop

import (
	"context"
	"encoding/json"
	"net/http"

	"github.com/jcsvwinston/nucleus/pkg/nucleus"
	"github.com/jcsvwinston/quark"
)

type module struct {
	client *quark.Client
}

// Module returns the shop feature as a nucleus module.
func Module(client *quark.Client) nucleus.ModuleSpec {
	m := &module{client: client}

	return nucleus.Module[struct{}]{
		Name: "shop",

		Routes: func(r nucleus.Router, _ struct{}) {
			r.Get("/api/authors", m.listAuthors)
			r.Get("/api/articles", m.listArticles)
			r.Post("/api/articles", m.createArticle)
		},
	}.Build()
}

func (m *module) listAuthors(c *nucleus.Context) error {
	authors, err := quark.For[Author](c.Request.Context(), m.client).OrderBy("name", "ASC").List()
	if err != nil {
		return err
	}
	return c.JSON(http.StatusOK, map[string]any{"authors": authors, "count": len(authors)})
}

func (m *module) listArticles(c *nucleus.Context) error {
	q := quark.For[Article](c.Request.Context(), m.client).OrderBy("id", "DESC")
	if author := c.Query("author_id"); author != "" {
		q = q.Where("author_id", "=", author)
	}
	articles, err := q.List()
	if err != nil {
		return err
	}
	return c.JSON(http.StatusOK, map[string]any{"articles": articles, "count": len(articles)})
}

func (m *module) createArticle(c *nucleus.Context) error {
	var in struct {
		AuthorID int64  `json:"author_id"`
		Title    string `json:"title"`
		Body     string `json:"body"`
	}
	if err := json.NewDecoder(c.Request.Body).Decode(&in); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid JSON"})
	}
	if in.Title == "" || in.AuthorID == 0 {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "author_id and title are required"})
	}
	a := Article{AuthorID: in.AuthorID, Title: in.Title, Body: in.Body}
	if err := quark.For[Article](c.Request.Context(), m.client).Create(&a); err != nil {
		return err
	}
	return c.JSON(http.StatusCreated, a)
}

// Migrate creates the tables and seeds a first author/article pair when the
// database is empty, so the app has data on first boot.
func Migrate(ctx context.Context, client *quark.Client) error {
	if err := client.RegisterModel(&Author{}, &Article{}); err != nil {
		return err
	}
	if err := client.MigrateRegistered(ctx); err != nil {
		return err
	}
	n, err := quark.For[Author](ctx, client).Count()
	if err != nil {
		return err
	}
	if n > 0 {
		return nil
	}
	ada := Author{Name: "Ada Lovelace"}
	if err := quark.For[Author](ctx, client).Create(&ada); err != nil {
		return err
	}
	first := Article{AuthorID: ada.ID, Title: "Hello, Quantum", Body: "Nucleus, Quark and Orbit wired together."}
	return quark.For[Article](ctx, client).Create(&first)
}
```

**`main.go`** — build the Quark client, migrate, and mount the module.
This is the whole file at this point:

```go
// Command blog is the entry point for your Nucleus application.
package main

import (
	"context"
	"log"

	"github.com/jcsvwinston/nucleus/pkg/nucleus"
	"github.com/jcsvwinston/orbit"
	"github.com/jcsvwinston/quark"
	_ "modernc.org/sqlite"

	"example.com/blog/shop"
)

func main() {
	ctx := context.Background()

	// Quark owns the domain schema. It shares the sqlite file with the app
	// database that Nucleus manages (nucleus.yml: sqlite://app.db).
	client, err := quark.New("sqlite", "app.db")
	if err != nil {
		log.Fatalf("blog: quark client: %v", err)
	}
	defer client.Close()

	if err := shop.Migrate(ctx, client); err != nil {
		log.Fatalf("blog: migrate/seed: %v", err)
	}

	app, err := nucleus.New().
		FromConfigFile("nucleus.yml").
		Mount(shop.Module(client)).
		Mount(orbit.Module(orbit.Config{
			Prefix: "/admin",
			Title:  "Blog",

			// Local demo credentials — change them anywhere beyond a laptop.
			BootstrapUsername: "admin",
			BootstrapEmail:    "admin@example.com",
			BootstrapPassword: "quickstart",
		})).
		Build()
	if err != nil {
		log.Fatalf("blog: %v", err)
	}

	// The shop API is public in this demo: skip the framework's default-deny
	// RBAC. Orbit still enforces its own session auth under /admin.
	app.Options = append(app.Options, nucleus.WithOpenAuthz())

	if err := nucleus.Run(app); err != nil {
		log.Fatalf("blog: %v", err)
	}
}
```

```bash
go get github.com/jcsvwinston/quark modernc.org/sqlite
go mod tidy
go run .
```

Try the API:

```bash
curl -s localhost:8080/api/articles
```

```json
{"articles":[{"ID":1,"AuthorID":1,"Title":"Hello, Quantum","Body":"Nucleus, Quark and Orbit wired together.","Author":{"ID":0,"Name":""}}],"count":1}
```

```bash
curl -s -X POST localhost:8080/api/articles \
    -H 'Content-Type: application/json' \
    -d '{"author_id":1,"title":"probe","body":"written over curl"}'
```

```json
{"ID":2,"AuthorID":1,"Title":"probe","Body":"written over curl","Author":{"ID":0,"Name":""}}
```

:::note About `WithOpenAuthz`
The scaffold's authorizer denies any route that no policy grants — without
that option, these `curl`s would answer `403`. `WithOpenAuthz()` turns the
default-deny authorizer off so a demo API is reachable without setting up
policies; authentication still runs (a bearer token is still decoded and
visible to handlers), and Orbit keeps its own session auth under `/admin`.
In a real app, keep default-deny and grant your routes in the scaffold's
`rbac_policy.csv` instead — see
[authorization in Nucleus](/nucleus/features/auth/).
:::

:::note Two data layers, one honest choice
Nucleus has its own SQL-first data layer (`pkg/db` + `pkg/model`) and this
app would work fine on it — Quark is a choice, not a requirement. What the
choice buys you (and what it costs) is a short read:
[choosing a data layer](choosing-a-data-layer.md).
:::

## 4 — Models in Data Studio, via quarkdatasource (2 min)

Orbit's Data Studio doesn't know about Quark; it speaks Orbit's datasource
contract. `orbit/quarkdatasource` implements that contract over Quark
models. Three additions to `main.go`:

```go
import (
	// ...existing imports...
	"github.com/jcsvwinston/orbit/quarkdatasource"
)

	// After shop.Migrate(...): back Data Studio with the same Quark models.
	ds := quarkdatasource.New(client)
	if err := quarkdatasource.Register[shop.Author](ds); err != nil {
		log.Fatalf("blog: register Author: %v", err)
	}
	if err := quarkdatasource.Register[shop.Article](ds); err != nil {
		log.Fatalf("blog: register Article: %v", err)
	}
```

…and hand `ds` to Orbit in the config:

```go
		Mount(orbit.Module(orbit.Config{
			Prefix:     "/admin",
			Title:      "Blog",
			DataSource: ds,
			// ...bootstrap credentials as before...
		})).
```

```bash
go get github.com/jcsvwinston/orbit/quarkdatasource
go mod tidy
go run .
```

Reload **/admin** → **Data Studio**. `Author` and `Article` are there:
browse them, edit the seeded article, create an author — then `curl
localhost:8080/api/authors` and see your edit come back through the public
API. Same models, same database, two doors.

## 5 — SQL in the live feed, via quarkbridge (2 min)

The second bridge. Orbit's live feed shows every request the app serves —
but the SQL that Quark runs is invisible to it until you tell Quark to
publish its statements onto the framework's observability bus. That is
`orbit/quarkbridge`: a Quark middleware, derived once at startup.

Add an `OnStart` hook to the module in `shop/module.go`:

```go
import (
	// ...existing imports...
	"fmt"

	"github.com/jcsvwinston/orbit/quarkbridge"
)

		OnStart: func(ctx context.Context, rt nucleus.Runtime, _ struct{}) error {
			bridged, err := m.client.WithOptions(
				quark.WithMiddleware(quarkbridge.New(rt.Observability())),
			)
			if err != nil {
				return fmt.Errorf("shop: derive bridged quark client: %w", err)
			}
			m.client = bridged
			return nil
		},
```

`OnStart` runs before `Routes`, so every handler already uses the bridged
client. The client in `main.go` stays unbridged on purpose: Data Studio
uses it, so admin browsing doesn't flood the feed you're about to watch.

```bash
go get github.com/jcsvwinston/orbit/quarkbridge
go mod tidy
go run .
```

Open **/admin** → **Live** view, then hit the API a few times:

```bash
curl -s localhost:8080/api/articles > /dev/null
curl -s -X POST localhost:8080/api/articles \
    -H 'Content-Type: application/json' \
    -d '{"author_id":1,"title":"watch the feed","body":"this insert shows up"}'
```

Each request arrives in the feed with the SQL it ran — `SELECT`s and the
`INSERT` — correlated to the request by its `request_id`, with bind
arguments redacted by default.

## What you just built

One process. Nucleus hosts the app and owns HTTP, config, auth and
lifecycle; Quark owns the domain schema and the queries; Orbit watches and
administers all of it from `/admin`. The two bridges —
`quarkdatasource` for Data Studio, `quarkbridge` for the live feed — are
the only glue, and each one was one import plus a couple of lines.

The finished app is maintained as a runnable example,
[`showcase_demo` in the Nucleus repo](https://github.com/jcsvwinston/nucleus/tree/main/examples/showcase_demo),
exercised against every certified set — if this page and that example ever
disagree, the example is right (and please tell us).

## Where to next

| You want to… | Read |
| --- | --- |
| Pin the exact versions this page was verified against | [Install the certified set](install.md) |
| Decide whether Quark or `pkg/db` fits your app | [Choosing a data layer](choosing-a-data-layer.md) |
| Understand what "certified set" means | [Certified sets](certified-sets.md) |
| Go deeper on the host framework | [Nucleus docs](/nucleus/) |
| Use Quark seriously (relations, migrations, tenancy) | [Quark docs](/quark/intro/) |
| Everything the admin can do | [Orbit docs](/orbit/) |
