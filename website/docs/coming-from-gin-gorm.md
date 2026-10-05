---
title: "Coming from Gin + GORM"
sidebar_label: From Gin + GORM
description: "What each piece of a Gin + GORM service becomes in Nucleus and Quark, a small service ported and called with the same HTTP requests as before, and what has no equivalent yet."
---

# Coming from Gin + GORM

A Gin + GORM service already has most of what the suite is made of: `net/http`
underneath, a `context.Context` on every request, structs with tags, and one Go
binary at the end. What changes is who wires the pieces. The router becomes a
[Nucleus](/nucleus/) application whose modules register routes and middleware;
GORM becomes [Quark](/quark/intro/); and the admin panel, sign-in, jobs and test
kit you would otherwise pick and add one library at a time come with them.

The first half of this page maps each piece. The second ports a small service —
a bookmarks API with a token on its write routes, soft deletes and a title
search — and makes the same HTTP requests its clients make. The Gin + GORM
listings are there to compare with, and this site's CI does not run them. The
Quantum commands, files and outputs are executed in order by CI against the
[current certified set](install.md) before they are published.

## The concept map

### Routing and handlers

| Gin | Nucleus | Notes |
| --- | --- | --- |
| `r := gin.Default()` … `r.Run(":8080")` | `nucleus.New().FromConfigFile("nucleus.yml")` … `.Start()` | The port is `port` in `nucleus.yml`, or `NUCLEUS_PORT`. Request IDs, the request log, panic recovery, a request timeout, compression and security headers are on in every application, and `Start` drains the server on `SIGINT` or `SIGTERM`. |
| `r.GET("/bookmarks/:id", h)` | `r.Get("/bookmarks/{id}", h)`, inside a module's `Routes` | Path parameters are written `{id}`. |
| `r.Group("/api")` | the module's `Prefix`, or `r.Group("/api", func(g nucleus.Router) { … })` | |
| `gin.HandlerFunc` middleware with `c.Next()` and `c.Abort()` | `func(http.Handler) http.Handler`: call `next.ServeHTTP` to go on, return without calling it to stop | For every route of a module, `Module.Middleware`; for some, `r.With(mw)`. Any `net/http` middleware works as it is. |
| `c.Param("id")`, `c.Query("q")` | `c.Param("id")`, `c.Query("q")` | Or declare them on the input type of a typed endpoint: `path:"id"`, `query:"q"`. |
| `c.ShouldBindJSON(&in)` with `binding:"required"` | `c.BindJSON(&in)`, or the input of a typed endpoint, with `validate:"required"` | The same validator library, go-playground/validator, under another tag name. A body that fails answers 422 and names each field. |
| `c.JSON(http.StatusOK, v)` | return `v` from a typed endpoint | `nucleus.Status(http.StatusCreated)` sets the success status, and an output of `struct{}` answers 204. A plain handler still has `c.JSON`. |
| `c.JSON(http.StatusNotFound, gin.H{"error": …})` | return `nucleusErrors.NotFound(…)`, `Conflict`, `Unauthorized`… | Every error, the framework's own included, leaves in one JSON shape — or as RFC 9457 problem details for a client that asks for them. |
| OpenAPI from comments, with swaggo | derived from the typed endpoints and served at `/openapi.json` | `nucleus openapi --check` fails on a change that breaks a client. |
| `c.HTML` after `LoadHTMLGlob` | `Module.Templates` and `c.Render` | Go's `html/template` in both. |

### Data: GORM to Quark

| GORM | Quark | Notes |
| --- | --- | --- |
| `gorm.Open(sqlite.Open("app.db"), &gorm.Config{})` | `quark.New("sqlite", "app.db")`, or `quark.NewWithDB("sqlite", rt.DB())` over the pool Nucleus opened | Blank-import Quark's driver module for the engine: it registers the error classifier behind `quark.IsUniqueViolation`. |
| `gorm.Model` | `ID`, `CreatedAt`, `UpdatedAt` and `DeletedAt *time.Time`, written out | `created_at` and `updated_at` fill themselves, and a nullable `deleted_at` turns on soft deletes. |
| `gorm:"uniqueIndex;not null"`, `gorm:"index"`, `gorm:"size:200"` | `quark:"unique,not_null"`, `quark:"index"`, `db:"title,size=200"` | Every column has a `db:"name"` tag; a field without one is not a column. |
| `db.AutoMigrate(&Bookmark{})` | `client.RegisterModel(&Bookmark{})` and `client.MigrateRegistered(ctx)` | `MigrateRegistered` creates the tables that are missing and never alters one. A new column on an existing table is `client.Sync` or a [versioned migration](/quark/guides/migrations/). |
| `db.WithContext(ctx).Where("done = ?", false).Find(&list)` | `quark.For[Bookmark](ctx, client).Where("done", "=", false).List()` | Column and operator are separate arguments, and both are validated before any SQL is built. The result is a `[]Bookmark`. |
| `Where("title LIKE ?", "%"+s+"%")` | `.WhereContains("title", s)` | Escapes `%` and `_` in the text the user typed. |
| `db.First(&b, id)` and `gorm.ErrRecordNotFound` | `.Find(id)` and `quark.ErrNotFound` | |
| `db.Create(&b)` and `gorm.ErrDuplicatedKey` | `.Create(&b)` and `quark.IsUniqueViolation(err)` | GORM translates the error only with `TranslateError: true`. |
| `db.Model(&b).Updates(b)`, `db.Save(&b)` | `.Update(&b)`, `.UpdateFields(&b, "title")`, `.UpdateMap(…)` | `Update` skips zero values, like `Updates` with a struct. `Save` writes every field, zeros included; in Quark, name the columns with `UpdateFields`. |
| `db.Delete(&b)`, soft with a `DeletedAt`; `Unscoped()` | `.Delete(&b)`, soft with a `deleted_at`; `WithTrashed()` | `Restore` and `HardDelete` exist too. A delete by condition, `DeleteBy`, is always a hard delete — GORM's `Where(…).Delete(&Bookmark{})` is soft. |
| `Preload("Tags")`, `Joins(…)` | `Preload("Tags")`, `Join`, `LeftJoin` | `Preload` loads a relation with batched queries, not one query per row. |
| `db.Transaction(func(tx *gorm.DB) error { … })` | `client.Tx(ctx, func(tx *quark.Tx) error { … })` | Inside it, `quark.ForTx[T](ctx, tx)` instead of `quark.For`. |
| `db.Scopes(f)` | `.Apply(f)` | |
| `BeforeCreate(tx *gorm.DB) error` and the other hooks | `BeforeCreate(ctx context.Context) error` and the other hooks | See [lifecycle hooks](/quark/guides/hooks/) for the list and when each runs. |

### What Gin and GORM leave to you

| With Gin + GORM you add | In the suite |
| --- | --- |
| an admin panel from a third party, or none | [Orbit](/orbit/), mounted by `nucleus new --with orbit` |
| sessions, sign-in and roles: middleware you write, or a library | sessions, password and OIDC sign-in, JWT, API keys and role-based access control in Nucleus. On the `mvc` template every route is refused until a policy row allows it. |
| a job queue such as asynq or River | a module's `Jobs` on a schedule, `rt.Tasks()` for one-off work, and a durable queue in the application's own database with `jobs_provider: sql` |
| tests on `httptest.NewRecorder` | `nucleustest.Start`, which boots the whole application in the test process and gives a client that keeps cookies |
| configuration from environment variables, flags or a library such as viper | `nucleus.yml` with `NUCLEUS_*` overrides, and each module's own settings under `modules.<name>` |

## The service before the port

`bookmarks` keeps links. Anyone may read them; writing needs a token, which the
service reads from `BOOKMARKS_TOKEN`. Deleting is soft: the row stays, marked.
This is its whole Gin + GORM version, in one `main.go`:

```go
// Command bookmarks is the service before the port: Gin and GORM.
package main

import (
	"errors"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
)

type Bookmark struct {
	ID        uint           `gorm:"primaryKey" json:"id"`
	URL       string         `gorm:"uniqueIndex;not null" json:"url"`
	Title     string         `gorm:"not null" json:"title"`
	CreatedAt time.Time      `json:"-"`
	UpdatedAt time.Time      `json:"-"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
}

type newBookmark struct {
	URL   string `json:"url" binding:"required,url"`
	Title string `json:"title" binding:"required,max=200"`
}

type bookmarkRef struct {
	ID uint `uri:"id" binding:"required"`
}

func newRouter(db *gorm.DB, token string) *gin.Engine {
	r := gin.Default()
	api := r.Group("/api")

	api.GET("/bookmarks", func(c *gin.Context) {
		q := db.WithContext(c.Request.Context()).Order("id").Limit(100)
		if s := c.Query("q"); s != "" {
			q = q.Where("title LIKE ?", "%"+s+"%")
		}
		var list []Bookmark
		if err := q.Find(&list).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"bookmarks": list, "count": len(list)})
	})

	api.GET("/bookmarks/:id", func(c *gin.Context) {
		var ref bookmarkRef
		if err := c.ShouldBindUri(&ref); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		var b Bookmark
		err := db.WithContext(c.Request.Context()).First(&b, ref.ID).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "bookmark not found"})
			return
		}
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, b)
	})

	writes := api.Group("", requireToken(token))

	writes.POST("/bookmarks", func(c *gin.Context) {
		var in newBookmark
		if err := c.ShouldBindJSON(&in); err != nil {
			c.JSON(http.StatusUnprocessableEntity, gin.H{"error": err.Error()})
			return
		}
		b := Bookmark{URL: in.URL, Title: in.Title}
		err := db.WithContext(c.Request.Context()).Create(&b).Error
		if errors.Is(err, gorm.ErrDuplicatedKey) {
			c.JSON(http.StatusConflict, gin.H{"error": in.URL + " is already bookmarked"})
			return
		}
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusCreated, b)
	})

	writes.DELETE("/bookmarks/:id", func(c *gin.Context) {
		var ref bookmarkRef
		if err := c.ShouldBindUri(&ref); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		res := db.WithContext(c.Request.Context()).Delete(&Bookmark{}, ref.ID)
		if res.Error != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": res.Error.Error()})
			return
		}
		if res.RowsAffected == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "bookmark not found"})
			return
		}
		c.Status(http.StatusNoContent)
	})

	return r
}

func requireToken(token string) gin.HandlerFunc {
	return func(c *gin.Context) {
		if c.GetHeader("Authorization") != "Bearer "+token {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "send the API token as a Bearer token"})
			return
		}
		c.Next()
	}
}

func main() {
	token := os.Getenv("BOOKMARKS_TOKEN")
	if token == "" {
		log.Fatal("bookmarks: set BOOKMARKS_TOKEN to the token that writes")
	}
	db, err := gorm.Open(sqlite.Open("app.db"), &gorm.Config{TranslateError: true})
	if err != nil {
		log.Fatal(err)
	}
	if err := db.AutoMigrate(&Bookmark{}); err != nil {
		log.Fatal(err)
	}
	if err := newRouter(db, token).Run(":8080"); err != nil {
		log.Fatal(err)
	}
}
```

Its clients rely on this contract, and the port keeps it:

| Request | Answers |
| --- | --- |
| `GET /api/bookmarks?q=…` | 200 with the bookmarks whose title contains `q`, and their count |
| `GET /api/bookmarks/{id}` | 200 with the bookmark, or 404 |
| `POST /api/bookmarks` | 201 with the new bookmark; 401 without the token; 409 for a URL already kept; 422 for a body that breaks the rules |
| `DELETE /api/bookmarks/{id}` | 204, and the bookmark stops being listed; 401 without the token; 404 |

## 1 — Scaffold

```bash
nucleus new bookmarks --template api --with quark
cd bookmarks
```

`--template api` is the lightweight core — configuration, logger, router,
database and sessions, with no admin panel, mail or authorizer — the closest
thing to a bare `gin.Default()`. `--with quark` fetches Quark and its SQLite
driver.

## 2 — The model and the routes

```go title="bookmarks/bookmarks.go"
// Package bookmarks is the bookmarks API, ported from Gin + GORM: the same
// routes, the same status codes and the same JSON, on a Nucleus module with
// a Quark model.
package bookmarks

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"os"
	"time"

	nucleusErrors "github.com/jcsvwinston/nucleus/pkg/errors"
	"github.com/jcsvwinston/nucleus/pkg/nucleus"
	"github.com/jcsvwinston/quark"

	// Quark's SQLite driver module, with the engine's error classifier:
	// without it a duplicate URL is a 500 instead of a 409.
	_ "github.com/jcsvwinston/quark/drivers/sqlite"
)

// Bookmark is gorm.Model's four fields written out, plus the bookmark's
// own. A *time.Time named deleted_at turns on soft deletes.
type Bookmark struct {
	ID        int64      `db:"id" pk:"true" json:"id"`
	URL       string     `db:"url" quark:"unique,not_null" json:"url"`
	Title     string     `db:"title" quark:"not_null" json:"title"`
	CreatedAt time.Time  `db:"created_at" json:"-"`
	UpdatedAt time.Time  `db:"updated_at" json:"-"`
	DeletedAt *time.Time `db:"deleted_at" json:"-"`
}

// BookmarkList is what GET /api/bookmarks answers.
type BookmarkList struct {
	Bookmarks []Bookmark `json:"bookmarks"`
	Count     int        `json:"count"`
}

// Search is the query GET /api/bookmarks reads.
type Search struct {
	Q string `query:"q" doc:"Only the bookmarks whose title contains this text"`
}

// NewBookmark is the body POST /api/bookmarks reads. The rules are the Gin
// version's binding rules: the same validator, under the tag name validate.
type NewBookmark struct {
	URL   string `json:"url" validate:"required,url"`
	Title string `json:"title" validate:"required,max=200"`
}

// BookmarkRef is the path of the routes on one bookmark.
type BookmarkRef struct {
	ID int64 `path:"id"`
}

type module struct {
	db    *quark.Client
	token string
}

// Module returns the bookmarks API as a nucleus module.
func Module() nucleus.ModuleSpec {
	m := &module{}
	return nucleus.Module[struct{}]{
		Name:   "bookmarks",
		Prefix: "/api",

		OnStart: func(ctx context.Context, rt nucleus.Runtime, _ struct{}) error {
			m.token = os.Getenv("BOOKMARKS_TOKEN")
			if m.token == "" {
				return errors.New("bookmarks: set BOOKMARKS_TOKEN to the token that writes")
			}
			db, err := quark.NewWithDB("sqlite", rt.DB())
			if err != nil {
				return fmt.Errorf("bookmarks: quark client: %w", err)
			}
			if err := db.RegisterModel(&Bookmark{}); err != nil {
				return err
			}
			if err := db.MigrateRegistered(ctx); err != nil {
				return err
			}
			m.db = db
			return nil
		},

		Routes: func(r nucleus.Router, _ struct{}) {
			nucleus.Handle(r, http.MethodGet, "/bookmarks", m.list)
			nucleus.Handle(r, http.MethodGet, "/bookmarks/{id}", m.show)

			// The writes go through the token check: Gin's route group
			// with a middleware is a Router with one.
			w := r.With(m.requireToken)
			nucleus.Handle(w, http.MethodPost, "/bookmarks", m.create, nucleus.Status(http.StatusCreated))
			nucleus.Handle(w, http.MethodDelete, "/bookmarks/{id}", m.remove)
		},
	}.Build()
}

// requireToken is the Gin middleware as net/http middleware: calling next
// is Gin's c.Next, returning without calling it is c.Abort.
func (m *module) requireToken(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer "+m.token {
			nucleusErrors.WriteError(w, r, nucleusErrors.Unauthorized("send the API token as a Bearer token"), nil)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (m *module) list(c *nucleus.Context, in Search) (BookmarkList, error) {
	q := quark.For[Bookmark](c.Request.Context(), m.db).OrderBy("id", "ASC").Limit(100)
	if in.Q != "" {
		q = q.WhereContains("title", in.Q)
	}
	list, err := q.List()
	if err != nil {
		return BookmarkList{}, err
	}
	return BookmarkList{Bookmarks: list, Count: len(list)}, nil
}

func (m *module) show(c *nucleus.Context, in BookmarkRef) (Bookmark, error) {
	return m.find(c.Request.Context(), in.ID)
}

func (m *module) create(c *nucleus.Context, in NewBookmark) (Bookmark, error) {
	b := Bookmark{URL: in.URL, Title: in.Title}
	err := quark.For[Bookmark](c.Request.Context(), m.db).Create(&b)
	if quark.IsUniqueViolation(err) {
		return Bookmark{}, nucleusErrors.Conflict(in.URL + " is already bookmarked")
	}
	return b, err
}

// remove soft-deletes: the row stays, with deleted_at set, and every read
// hides it. It answers 204: an output of struct{} has no body.
func (m *module) remove(c *nucleus.Context, in BookmarkRef) (struct{}, error) {
	b, err := m.find(c.Request.Context(), in.ID)
	if err != nil {
		return struct{}{}, err
	}
	_, err = quark.For[Bookmark](c.Request.Context(), m.db).Delete(&b)
	return struct{}{}, err
}

func (m *module) find(ctx context.Context, id int64) (Bookmark, error) {
	b, err := quark.For[Bookmark](ctx, m.db).Find(id)
	if errors.Is(err, quark.ErrNotFound) {
		return Bookmark{}, nucleusErrors.NotFound("bookmark", fmt.Sprint(id))
	}
	return b, err
}
```

What moved where:

**The handlers became typed endpoints.** `nucleus.Handle` registers
`func(*nucleus.Context, In) (Out, error)`. The input is bound by its tags —
`path:"id"` where Gin had `uri:"id"`, `query:"q"` where it had `c.Query`, the
`json` fields from the body — and checked against its `validate` tags before
the handler runs. The output is written as JSON with the status the route
declares. What is left in each handler is the query.

**The token check is `net/http` middleware.** `r.With(m.requireToken)`
returns a router whose routes all go through it, which is what
`api.Group("", requireToken(token))` did. `nucleusErrors.WriteError` writes
the refusal in the same shape as every other error.

**The model is a Quark struct.** `quark.NewWithDB` puts Quark over the
database Nucleus opened from `nucleus.yml`; `RegisterModel` and
`MigrateRegistered` create the table on start, where `AutoMigrate` did.
`Delete` sets `deleted_at` and the reads skip the row, as GORM did with
`gorm.DeletedAt`.

## 3 — Mount it

Replace `main.go`:

```go title="main.go"
// Command bookmarks serves the bookmarks API on the lightweight core of
// Nucleus.
package main

import (
	"log"

	"github.com/jcsvwinston/nucleus/pkg/nucleus"

	_ "github.com/jcsvwinston/nucleus/drivers/sqlite"

	"example.com/bookmarks/bookmarks"
)

func main() {
	if err := nucleus.New().
		FromConfigFile("nucleus.yml").
		WithOpenAPIDocument("/openapi.json").
		WithoutDefaults().
		Mount(bookmarks.Module()).
		Start(); err != nil {
		log.Fatalf("bookmarks: %v", err)
	}
}
```

## 4 — Run it

Set the token the write routes expect, start the service and leave it running
in its own terminal:

```bash
export BOOKMARKS_TOKEN=dev-token
go run .
```

## 5 — The same requests

From a second terminal, make the requests the service's clients make. Without
the token, a write is refused:

```bash
curl -s -X POST localhost:8080/api/bookmarks \
    -H 'Content-Type: application/json' \
    -d '{"url":"https://go.dev","title":"The Go programming language"}'
```

```json
{"error":{"code":"UNAUTHORIZED","message":"send the API token as a Bearer token"}}
```

With it, two bookmarks go in:

```bash
curl -s -X POST localhost:8080/api/bookmarks \
    -H 'Authorization: Bearer dev-token' \
    -H 'Content-Type: application/json' \
    -d '{"url":"https://go.dev","title":"The Go programming language"}'
```

```json
{"id":1,"url":"https://go.dev","title":"The Go programming language"}
```

```bash
curl -s -X POST localhost:8080/api/bookmarks \
    -H 'Authorization: Bearer dev-token' \
    -H 'Content-Type: application/json' \
    -d '{"url":"https://pkg.go.dev","title":"Go packages"}'
```

```json
{"id":2,"url":"https://pkg.go.dev","title":"Go packages"}
```

A URL that is already kept is a conflict, and a body that breaks the rules
never reaches the handler:

```bash
curl -s -X POST localhost:8080/api/bookmarks \
    -H 'Authorization: Bearer dev-token' \
    -H 'Content-Type: application/json' \
    -d '{"url":"https://go.dev","title":"Go, again"}'
```

```json
{"error":{"code":"CONFLICT","message":"https://go.dev is already bookmarked"}}
```

```bash
curl -s -X POST localhost:8080/api/bookmarks \
    -H 'Authorization: Bearer dev-token' \
    -H 'Content-Type: application/json' \
    -d '{"url":"not a url","title":""}'
```

```json
{"error":{"code":"VALIDATION_FAILED","message":"validation failed","details":{"title":"this field is required","url":"must be a valid URL"}}}
```

The search, and one bookmark by its id:

```bash
curl -s 'localhost:8080/api/bookmarks?q=packages'
```

```json
{"bookmarks":[{"id":2,"url":"https://pkg.go.dev","title":"Go packages"}],"count":1}
```

```bash
curl -s localhost:8080/api/bookmarks/1
```

```json
{"id":1,"url":"https://go.dev","title":"The Go programming language"}
```

Delete it. The answer has no body, and the bookmark is gone for every read:

```bash
curl -s -o /dev/null -w '%{http_code}\n' -X DELETE localhost:8080/api/bookmarks/1 \
    -H 'Authorization: Bearer dev-token'
```

```text
204
```

```bash
curl -s localhost:8080/api/bookmarks/1
```

```json
{"error":{"code":"NOT_FOUND","message":"bookmark '1' not found"}}
```

The row is still in the table, with `deleted_at` set — the soft delete GORM
did.

## 6 — The test

The Gin version's test built each request by hand and ran it through the
engine with a recorder:

```go
func TestWritesNeedTheToken(t *testing.T) {
	db, err := gorm.Open(sqlite.Open(filepath.Join(t.TempDir(), "test.db")), &gorm.Config{TranslateError: true})
	if err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(&Bookmark{}); err != nil {
		t.Fatal(err)
	}
	r := newRouter(db, "test-token")

	req := httptest.NewRequest(http.MethodPost, "/api/bookmarks",
		strings.NewReader(`{"url":"https://go.dev","title":"Go"}`))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("POST without the token: got HTTP %d, want 401", w.Code)
	}
	// … and the same again with the header, for each case.
}
```

The port's test boots the whole application — its `nucleus.yml`, its module,
a temporary database — and talks to it through a client:

```go title="bookmarks/bookmarks_test.go"
package bookmarks_test

import (
	"fmt"
	"net/http"
	"testing"

	"github.com/jcsvwinston/nucleus/pkg/nucleus"
	"github.com/jcsvwinston/nucleus/pkg/nucleustest"

	_ "github.com/jcsvwinston/nucleus/drivers/sqlite"

	"example.com/bookmarks/bookmarks"
)

// TestWritesNeedTheToken starts the application in the test process, on
// its own nucleus.yml and a temporary SQLite database.
func TestWritesNeedTheToken(t *testing.T) {
	t.Chdir("..") // the project root, where nucleus.yml is
	t.Setenv("BOOKMARKS_TOKEN", "test-token")
	srv := nucleustest.Start(t, nucleus.New().
		FromConfigFile("nucleus.yml").
		WithDatabases(nucleustest.TempSQLite(t)).
		WithoutDefaults().
		Mount(bookmarks.Module()))

	body := map[string]string{"url": "https://go.dev", "title": "Go"}
	if got := srv.Post("/api/bookmarks", body).Status; got != http.StatusUnauthorized {
		t.Fatalf("POST without the token: got HTTP %d, want 401", got)
	}

	resp := srv.Post("/api/bookmarks", body, nucleustest.WithBearer("test-token"))
	if resp.Status != http.StatusCreated {
		t.Fatalf("POST with the token: got HTTP %d: %s", resp.Status, resp)
	}
	var created bookmarks.Bookmark
	resp.JSON(t, &created)

	if got := srv.Post("/api/bookmarks", body, nucleustest.WithBearer("test-token")).Status; got != http.StatusConflict {
		t.Errorf("the same URL twice: got HTTP %d, want 409", got)
	}
	if got := srv.Get(fmt.Sprintf("/api/bookmarks/%d", created.ID)).Status; got != http.StatusOK {
		t.Errorf("GET the new bookmark: got HTTP %d, want 200", got)
	}
}
```

```bash
go test ./...
```

## What a client sees change

The routes, the status codes and the success bodies are the ones the Gin
version answered. Two things are not:

- **Error bodies.** Gin's handlers wrote `{"error": "…"}`, each its own way;
  the port answers `{"error": {"code": …, "message": …}}` from every route,
  with the failing fields under `details` for a 422. A client that only reads
  the status code sees no change; one that parses the error text does.
- **A `%` in the search.** The Gin version put the user's text into a `LIKE`
  pattern as it came, so `?q=%` matched every bookmark. `WhereContains`
  escapes it: `?q=%` finds the titles that contain a percent sign.

## Porting a larger service in steps

A service with many routes does not have to move in one change.

**The data layer first.** Quark does not need Nucleus: it runs under Gin with
the request's context, as [Quark's framework guide](/quark/guides/frameworks/#gin)
shows. Moving model by model from GORM to Quark while the router stays is a
change you can ship on its own.

**Then the routes, behind a Nucleus that serves the rest.** A
`*gin.Engine` is an `http.Handler`, and a module's `Router.Mount` takes any.
Mounted at `/`, the engine receives every request that no module route
matches, with its path unchanged, while each route you port to a module is
served by Nucleus:

```go
legacy := newRouter(db, token) // the *gin.Engine from before the port

nucleus.New().
	FromConfigFile("nucleus.yml").
	WithoutDefaults().
	Mount(bookmarks.Module()). // the routes already ported
	Mount(nucleus.Module[struct{}]{
		Name:   "legacy",
		Routes: func(r nucleus.Router, _ struct{}) { r.Mount("/", legacy) },
	}.Build()).
	Start()
```

This site's CI does not run that listing, because it needs Gin. On the `api`
template, as here, there is no authorizer in front of the engine. On the `mvc`
template the default-deny authorizer refuses every path that no policy row
allows, the engine's paths included.

## What has no equivalent yet

- **Gin middleware.** A `gin.HandlerFunc` — the gin-contrib packages
  included — does not run in Nucleus. Each one becomes `net/http` middleware,
  or is replaced by a `net/http` package that does the same.
- **Bodies in YAML, TOML, Protocol Buffers or MessagePack.** Gin binds them;
  Nucleus binds JSON, XML and forms, plus the query, the path and the headers.
- **GORM's association mode.** Appending to, replacing or clearing a
  many-to-many relation has no counterpart: Quark writes the join rows when it
  saves the parent and never removes one, so unlinking is a statement of your
  own on the join table.
- **An update that writes every field.** `Save` has no single equivalent; name
  the columns with `UpdateFields`, or write them with `UpdateMap`.
- **A soft delete by condition.** `DeleteBy` is always a hard delete. Load the
  rows and `Delete` each one.
- **Other databases.** Quark runs on PostgreSQL, MySQL, MariaDB, SQLite, SQL
  Server and Oracle; GORM has community drivers for more.

## Where to next

| You want to… | Read |
| --- | --- |
| Typed endpoints, the OpenAPI document and a generated client | [An API-only service](tutorial-api-only.md) |
| Everything a query can do in Quark | [Query builder](/quark/guides/querying/) |
| Versioned migrations instead of creating tables on start | [Migrations and Sync](/quark/guides/migrations/) |
| Middleware, groups and the error shape in detail | [Routing & middleware](/nucleus/concepts/routing/) |
| An admin panel over these bookmarks | [The quickstart](quickstart.md) mounts Orbit on a Quark model |
