---
title: "Tutorial: a multi-tenant SaaS"
sidebar_label: Multi-tenant SaaS
description: "One application, many customers: Nucleus resolves the tenant of each request, Quark confines the queries to it, and the Orbit panel gives the operator the view across all of them."
---

# A multi-tenant SaaS

You will build `tracker`, a project tracker that several companies share.
Each request names its company — its **tenant** — and the three products
split the work:

- **Nucleus** resolves the tenant of every request before a handler runs;
- **Quark** adds that tenant to the queries the API runs, and fills it in on
  every row it creates;
- **Orbit** gives the operator one panel across all tenants, and a live view
  of the SQL each request ran.

Everything runs on SQLite. The commands, files and outputs on this page are
executed in order by this site's CI against the
[current certified set](install.md) before they are published.

You need Go 1.26 or newer and the Nucleus CLI at the certified tag — the
[quickstart](quickstart.md) installs it in one command.

## 1 — Scaffold

```bash
nucleus new tracker --template mvc --with orbit,quark,quarkbridge,quarkdatasource
cd tracker
```

`--template mvc` is the full application: a default-deny authorizer, sessions
and CSRF protection are on from the first request. `--with` fetches Orbit,
Quark and the two bridges between them at their published tags; nothing in
the scaffold imports them yet — the next three files do.

## 2 — Tell Nucleus where the tenant comes from

Replace `nucleus.yml` with this shorter version (every key it leaves out keeps
its default):

```yaml title="nucleus.yml"
databases:
  default:
    url: sqlite://app.db
port: 8080
env: development
log_format: text
rbac_policy_file: rbac_policy.csv
csrf_enabled: true
csrf_exempt_paths: ["/api/"]

# Resolve a tenant for every request, from the X-Tenant-ID header. All
# tenants share the default database: isolation is by rows, in Quark.
multitenant:
  enabled: true
  resolver: header
  header: X-Tenant-ID
  require_isolated_db: false
  database_alias_template: ""
```

With `multitenant.enabled`, Nucleus resolves the tenant of each request in
its middleware, before routing; handlers read it with
`app.TenantFromContext`. `resolver: subdomain` would read it from the host
name (`acme.tracker.example`) instead of a header. The last two keys say that
every tenant lives in the same database — the other mode gives each tenant a
database of its own and routes the request to it.

## 3 — The tenant-owned model and its API

```go title="projects/projects.go"
// Package projects is the tracker's tenant-owned data: every project belongs
// to one customer, and every query the API runs is confined to the customer
// that made the request.
package projects

import (
	"context"
	"errors"
	"fmt"
	"net/http"

	"github.com/jcsvwinston/nucleus/pkg/app"
	nucleusErrors "github.com/jcsvwinston/nucleus/pkg/errors"
	"github.com/jcsvwinston/nucleus/pkg/nucleus"
	"github.com/jcsvwinston/orbit/quarkbridge"
	"github.com/jcsvwinston/quark"
)

// Project is a Quark model. tenant_id is the column the tenant router
// filters on and fills in.
type Project struct {
	ID       int64  `db:"id" pk:"true" json:"id"`
	TenantID string `db:"tenant_id" quark:"not_null,index" json:"tenant_id"`
	Name     string `db:"name" quark:"not_null" json:"name"`
}

// Migrate creates the projects table. main.go calls it before the server
// starts.
func Migrate(ctx context.Context, client *quark.Client) error {
	if err := client.RegisterModel(&Project{}); err != nil {
		return err
	}
	return client.MigrateRegistered(ctx)
}

// ProjectList is what GET /api/projects answers.
type ProjectList struct {
	Projects []Project `json:"projects"`
	Count    int       `json:"count"`
}

// NewProject is the body POST /api/projects reads.
type NewProject struct {
	Name string `json:"name" validate:"required,max=120"`
}

// ProjectRef is the path GET /api/projects/{id} reads.
type ProjectRef struct {
	ID int64 `path:"id"`
}

type module struct {
	base   *quark.Client
	router *quark.TenantRouter
}

// Module returns the projects API as a nucleus module.
func Module(base *quark.Client) nucleus.ModuleSpec {
	m := &module{base: base}
	return nucleus.Module[struct{}]{
		Name: "projects",

		// Development defaults: anonymous callers may read and create. In
		// production the tenant comes from who is signed in, not from a
		// header any client can set (see "Before production" below).
		Policies: []nucleus.PolicyRule{
			{Subject: "anonymous", Object: "/api/projects", Action: "read"},
			{Subject: "anonymous", Object: "/api/projects", Action: "create"},
			{Subject: "anonymous", Object: "/api/projects/*", Action: "read"},
		},
		CSRFExempt: []string{"/api/"},

		OnStart: func(ctx context.Context, rt nucleus.Runtime, _ struct{}) error {
			// The API's statements go to Orbit's live view...
			bridged, err := m.base.WithOptions(quark.WithMiddleware(quarkbridge.New(rt.Observability())))
			if err != nil {
				return fmt.Errorf("projects: bridged client: %w", err)
			}
			// ...through a router that confines each one to the tenant
			// Nucleus resolved for the request.
			cfg := quark.DefaultTenantConfig()
			cfg.Strategy = quark.RowLevelSecurityClient
			cfg.BaseClient = bridged
			cfg.TenantColumn = "tenant_id"
			m.router = quark.NewTenantRouter(cfg, app.TenantFromContext, nil)
			return nil
		},

		Routes: func(r nucleus.Router, _ struct{}) {
			nucleus.Handle(r, http.MethodGet, "/api/projects", m.list)
			nucleus.Handle(r, http.MethodPost, "/api/projects", m.create, nucleus.Status(http.StatusCreated))
			nucleus.Handle(r, http.MethodGet, "/api/projects/{id}", m.show)
		},
	}.Build()
}

// tenant returns the request's context when it names a valid tenant, and a
// 400 before any SQL is built when it does not.
func (m *module) tenant(c *nucleus.Context) (context.Context, error) {
	ctx := c.Request.Context()
	if _, err := m.router.ResolveTenant(ctx); err != nil {
		return nil, nucleusErrors.BadRequest("name a tenant in the X-Tenant-ID header")
	}
	return ctx, nil
}

func (m *module) list(c *nucleus.Context, _ struct{}) (ProjectList, error) {
	ctx, err := m.tenant(c)
	if err != nil {
		return ProjectList{}, err
	}
	projects, err := quark.For[Project](ctx, m.router).OrderBy("id", "ASC").Limit(100).List()
	if err != nil {
		return ProjectList{}, err
	}
	return ProjectList{Projects: projects, Count: len(projects)}, nil
}

func (m *module) create(c *nucleus.Context, in NewProject) (Project, error) {
	ctx, err := m.tenant(c)
	if err != nil {
		return Project{}, err
	}
	p := Project{Name: in.Name} // the router fills in TenantID
	if err := quark.For[Project](ctx, m.router).Create(&p); err != nil {
		return Project{}, err
	}
	return p, nil
}

func (m *module) show(c *nucleus.Context, in ProjectRef) (Project, error) {
	ctx, err := m.tenant(c)
	if err != nil {
		return Project{}, err
	}
	// Find looks the key up inside the request's tenant: another tenant's
	// id is not found.
	p, err := quark.For[Project](ctx, m.router).Find(in.ID)
	if errors.Is(err, quark.ErrNotFound) {
		return Project{}, nucleusErrors.NotFound("project", fmt.Sprint(in.ID))
	}
	return p, err
}
```

**The model carries its tenant.** `TenantID` maps to `tenant_id`. The API
never sets it: the router fills it in on `Create` from the tenant of the
context, and adds `tenant_id = ?` to every query it builds — reads and writes
by primary key included. `show` reads with `Find`, which looks the key up
inside the tenant, so an id that belongs to another tenant answers
`quark.ErrNotFound` and the handler turns it into a 404; the key-based
`Update(&row)` and `Delete(&row)` are confined the same way.

**The router is where the confinement lives.** `quark.NewTenantRouter` with
the `RowLevelSecurityClient` strategy wraps a client;
`quark.For[T](ctx, router)` is the same call as with a plain client, and the query it returns
is already limited to the tenant that `app.TenantFromContext` reads from the
context — the one Nucleus resolved from the header. The router wraps the
client bridged to Orbit, so the statements it runs appear in the panel's
live view.

**A request without a tenant never reaches the database.**
`router.ResolveTenant` refuses a missing tenant and one that does not match
`^[a-z0-9_-]+$`; the handler turns that into a 400. The routes are typed
endpoints (`nucleus.Handle`), so the input types are bound and validated
before the handler runs and the API is described in `/openapi.json`.

## 4 — Wire it in `main.go`

Replace `main.go`:

```go title="main.go"
// Command tracker is a multi-tenant project tracker: Nucleus resolves the
// tenant of each request, Quark confines the API's queries to it, and the
// Orbit panel under /admin shows the operator every tenant.
package main

import (
	"context"
	"log"
	"os"

	"github.com/jcsvwinston/nucleus/pkg/nucleus"
	"github.com/jcsvwinston/orbit"
	"github.com/jcsvwinston/orbit/quarkdatasource"
	"github.com/jcsvwinston/quark"

	// Each product links its SQLite driver module, which also registers the
	// error classifier for the engine.
	_ "github.com/jcsvwinston/nucleus/drivers/sqlite"
	_ "github.com/jcsvwinston/quark/drivers/sqlite"

	"example.com/tracker/projects"
)

func main() {
	ctx := context.Background()

	// The same database file nucleus.yml names.
	client, err := quark.New("sqlite", "app.db")
	if err != nil {
		log.Fatalf("tracker: quark client: %v", err)
	}
	defer client.Close()
	if err := projects.Migrate(ctx, client); err != nil {
		log.Fatalf("tracker: migrate: %v", err)
	}

	// Data Studio reads through the base client, not the tenant router:
	// the operator sees every tenant's rows.
	ds := quarkdatasource.New(client)
	if err := quarkdatasource.Register[projects.Project](ds); err != nil {
		log.Fatalf("tracker: register Project: %v", err)
	}

	if err := nucleus.New().
		FromConfigFile("nucleus.yml").
		WithOpenAPIDocument("/openapi.json").
		Mount(projects.Module(client)).
		Mount(orbit.Module(orbit.Config{
			Prefix:            "/admin",
			Title:             "tracker",
			DataSource:        ds,
			BootstrapUsername: "admin",
			BootstrapEmail:    "admin@example.com",
			BootstrapPassword: bootstrapPassword(),
		})).
		Start(); err != nil {
		log.Fatalf("tracker: %v", err)
	}
}

// bootstrapPassword is ADMIN_BOOTSTRAP_PASSWORD, or "quickstart" for a
// laptop. Set the variable before the app faces anyone but you.
func bootstrapPassword() string {
	if p := os.Getenv("ADMIN_BOOTSTRAP_PASSWORD"); p != "" {
		return p
	}
	return "quickstart"
}
```

Two clients over one database, on purpose: the API goes through the tenant
router, the panel through the base client. The panel is the operator's tool,
behind its own login; the API is what each customer reaches.

## 5 — Run it and create a project for two tenants

Start the application, and leave it running in its own terminal:

```bash
go run .
```

From a second terminal, create a project as `acme`:

```bash
curl -s -X POST localhost:8080/api/projects \
    -H 'X-Tenant-ID: acme' \
    -H 'Content-Type: application/json' \
    -d '{"name":"Website relaunch"}'
```

```json
{"id":1,"tenant_id":"acme","name":"Website relaunch"}
```

and one as `globex`:

```bash
curl -s -X POST localhost:8080/api/projects \
    -H 'X-Tenant-ID: globex' \
    -H 'Content-Type: application/json' \
    -d '{"name":"Billing migration"}'
```

```json
{"id":2,"tenant_id":"globex","name":"Billing migration"}
```

Neither body names a tenant: `tenant_id` comes from the header, through
Nucleus and the router.

## 6 — Each tenant sees its own

`acme` lists one project:

```bash
curl -s localhost:8080/api/projects -H 'X-Tenant-ID: acme'
```

```json
{"projects":[{"id":1,"tenant_id":"acme","name":"Website relaunch"}],"count":1}
```

Project 2 exists, but it is `globex`'s, so for `acme` it does not:

```bash
curl -s -o /dev/null -w '%{http_code}\n' localhost:8080/api/projects/2 -H 'X-Tenant-ID: acme'
```

```text
404
```

And a request that names no tenant is refused before a query is built:

```bash
curl -s localhost:8080/api/projects
```

```json
{"error":{"code":"BAD_REQUEST","message":"name a tenant in the X-Tenant-ID header"}}
```

Now open **http://localhost:8080/admin** and sign in as `admin` with the
password `quickstart`. **Data Studio** lists both projects, with their
`tenant_id` column: the operator's view across tenants. The **live view**
shows the statements the API ran, each one correlated to its request and
each `SELECT` with `"tenant_id" = ?` in its `WHERE`.

## 7 — Pin the isolation down with a test

```go title="projects/projects_test.go"
package projects_test

import (
	"context"
	"fmt"
	"net/http"
	"path/filepath"
	"testing"

	"github.com/jcsvwinston/nucleus/pkg/app"
	"github.com/jcsvwinston/nucleus/pkg/nucleus"
	"github.com/jcsvwinston/nucleus/pkg/nucleustest"
	"github.com/jcsvwinston/quark"

	_ "github.com/jcsvwinston/nucleus/drivers/sqlite"
	_ "github.com/jcsvwinston/quark/drivers/sqlite"

	"example.com/tracker/projects"
)

// TestATenantSeesOnlyItsProjects boots the application in-process on its
// own nucleus.yml and a temporary database, creates a project as one tenant
// and reads it as another.
func TestATenantSeesOnlyItsProjects(t *testing.T) {
	// From the project root, the way `go run .` starts, so the test reads
	// nucleus.yml and rbac_policy.csv as they are.
	t.Chdir("..")
	file := filepath.Join(t.TempDir(), "test.db")

	client, err := quark.New("sqlite", file)
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()
	if err := projects.Migrate(context.Background(), client); err != nil {
		t.Fatal(err)
	}
	srv := nucleustest.Start(t, nucleus.New().
		FromConfigFile("nucleus.yml").
		WithDatabases(map[string]app.DatabaseConfig{"default": {URL: "sqlite://" + file}}).
		Mount(projects.Module(client)))

	acme := nucleustest.WithHeader("X-Tenant-ID", "acme")
	globex := nucleustest.WithHeader("X-Tenant-ID", "globex")

	var created projects.Project
	srv.Post("/api/projects", map[string]string{"name": "Roadmap"}, globex).JSON(t, &created)
	if created.TenantID != "globex" {
		t.Fatalf("the router filled tenant_id with %q, want globex", created.TenantID)
	}

	if got := srv.Get(fmt.Sprintf("/api/projects/%d", created.ID), acme).Status; got != http.StatusNotFound {
		t.Errorf("acme reading globex's project: got HTTP %d, want 404", got)
	}
	var list projects.ProjectList
	srv.Get("/api/projects", acme).JSON(t, &list)
	if list.Count != 0 {
		t.Errorf("acme's list: got %+v, want no projects", list.Projects)
	}
}
```

```bash
go test ./...
```

The test runs the same boot path as `main.go` — the same `nucleus.yml`, the
same authorizer, the same router — against a temporary SQLite file.

## Before production

- **Where the tenant comes from.** A header is the shortest way to show the
  mechanism, and any client can set it. In production, resolve the tenant
  from what the request proves: the account that signed in (put it on the
  context in a middleware and have the router's resolver read it), or the
  subdomain (`resolver: subdomain`) behind your own TLS.
- **The boundary of row-level isolation.** `RowLevelSecurityClient` filters
  the queries Quark builds on all six engines; `client.Raw()` and
  `client.Exec()` are not filtered. On PostgreSQL,
  [native row-level security](/quark/advanced/row-level-native/) moves the
  filter into the engine, raw SQL included.
- **The panel sees every tenant.** That is the point of an operator view;
  give `/admin` accounts only to your own staff.

## Where to next

| You want to… | Read |
| --- | --- |
| Schema-per-tenant or database-per-tenant instead of rows | [Multi-tenant strategies in Quark](/quark/advanced/multi-tenant/) |
| Sign users in and put the account on the request | [Your first login](/nucleus/features/auth/your-first-login/) |
| Typed endpoints, the OpenAPI document and its client | [An API-only service](tutorial-api-only.md) |
| Everything Data Studio and the live view can do | [Orbit features](/orbit/features/#data-studio) |
