---
title: "Tutorial: an MVC monolith"
sidebar_label: MVC monolith
description: "Server-rendered pages on the full template of Nucleus: an HTML form protected against cross-site requests, a session that remembers the visitor, a one-request flash message, and the records on Quark."
---

# An MVC monolith

You will build `guestbook`: one page, rendered on the server, that lists
what visitors wrote and has a form to sign it. Along the way it uses the
pieces a server-rendered application needs and an API does not — templates,
a form with its CSRF token, a session, and a message that lives for exactly
one request.

Everything runs on SQLite. The commands, files and outputs on this page are
executed in order by this site's CI against the
[current certified set](install.md) before they are published.

You need Go 1.26 or newer and the Nucleus CLI at the certified tag — the
[quickstart](quickstart.md) installs it in one command.

## 1 — Scaffold

```bash
nucleus new guestbook --template mvc --with quark
cd guestbook
```

`--template mvc` is the full application: a default-deny authorizer (with
`rbac_policy.csv`), sessions, and CSRF protection on every request that
changes something (`csrf_enabled: true` in `nucleus.yml`). `--with quark`
fetches Quark and its SQLite driver.

## 2 — The page

```html title="entries/templates/index.html"
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>Guestbook</title></head>
<body>
  <h1>Guestbook</h1>
  {{if .Notice}}<p class="notice">{{.Notice}}</p>{{end}}
  {{if .Problem}}<p class="problem">{{.Problem}}</p>{{end}}
  <form method="post" action="/guestbook">
    <input type="hidden" name="_csrf_token" value="{{.CSRF}}">
    <label>Name <input name="name" value="{{.Name}}"></label>
    <label>Message <textarea name="message"></textarea></label>
    <button type="submit">Sign</button>
  </form>
  <ul>
    {{range .Entries}}<li><strong>{{.Name}}</strong>: {{.Message}}</li>
    {{else}}<li>Nobody has signed yet.</li>{{end}}
  </ul>
</body>
</html>
```

A Go `html/template`: everything it prints is escaped for HTML, so a message
with markup in it shows as text. The hidden `_csrf_token` field is what lets
the form's `POST` through the CSRF protection.

## 3 — The module: model, page and form

```go title="entries/entries.go"
// Package entries is the guestbook: a page that lists what visitors wrote
// and a form to sign it, rendered on the server.
package entries

import (
	"context"
	"embed"
	"fmt"
	"io/fs"
	"net/http"

	"github.com/jcsvwinston/nucleus/pkg/auth"
	"github.com/jcsvwinston/nucleus/pkg/nucleus"
	"github.com/jcsvwinston/nucleus/pkg/router"
	"github.com/jcsvwinston/quark"

	// Quark's SQLite driver module, with the engine's error classifier.
	_ "github.com/jcsvwinston/quark/drivers/sqlite"
)

//go:embed templates/*.html
var templates embed.FS

// Entry is one signature in the guestbook.
type Entry struct {
	ID      int64  `db:"id" pk:"true"`
	Name    string `db:"name" quark:"not_null"`
	Message string `db:"message" quark:"not_null"`
}

// Signature is the form POST /guestbook reads.
type Signature struct {
	Name    string `form:"name" validate:"required,max=60"`
	Message string `form:"message" validate:"required,max=500"`
}

type module struct {
	db       *quark.Client
	sessions *auth.SessionManager
}

// Module returns the guestbook as a nucleus module.
func Module() nucleus.ModuleSpec {
	m := &module{}
	views, err := fs.Sub(templates, "templates")
	if err != nil {
		panic(err) // the embed pattern above guarantees the directory
	}
	return nucleus.Module[struct{}]{
		Name: "entries",
		// The module's templates, rendered as "entries/<file>".
		Templates: views,

		// Anyone may read the page and sign it. The authorizer is
		// default-deny: without these rows both routes answer 403.
		Policies: []nucleus.PolicyRule{
			{Subject: "anonymous", Object: "/guestbook", Action: "read"},
			{Subject: "anonymous", Object: "/guestbook", Action: "create"},
		},

		OnStart: func(ctx context.Context, rt nucleus.Runtime, _ struct{}) error {
			db, err := quark.NewWithDB("sqlite", rt.DB())
			if err != nil {
				return fmt.Errorf("entries: quark client: %w", err)
			}
			if err := db.RegisterModel(&Entry{}); err != nil {
				return err
			}
			if err := db.MigrateRegistered(ctx); err != nil {
				return err
			}
			m.db = db
			m.sessions = rt.Session()
			return nil
		},

		Routes: func(r nucleus.Router, _ struct{}) {
			r.Get("/guestbook", m.page)
			r.Post("/guestbook", m.sign)
		},
	}.Build()
}

func (m *module) page(c *nucleus.Context) error {
	return m.render(c, http.StatusOK, "")
}

// sign handles the form: validate, store, remember the name, flash a
// notice, and redirect — so a reload does not post the form twice.
func (m *module) sign(c *nucleus.Context) error {
	var in Signature
	if err := c.BindForm(&in); err != nil {
		return m.render(c, http.StatusUnprocessableEntity,
			"Write a name (up to 60 characters) and a message (up to 500).")
	}
	ctx := c.Request.Context()
	e := Entry{Name: in.Name, Message: in.Message}
	if err := quark.For[Entry](ctx, m.db).Create(&e); err != nil {
		return err
	}
	if err := c.SessionPutString("name", in.Name); err != nil {
		return err
	}
	m.sessions.Flash(ctx, "notice", "Thanks for signing, "+in.Name+".")
	return c.Redirect(http.StatusSeeOther, "/guestbook")
}

func (m *module) render(c *nucleus.Context, status int, problem string) error {
	ctx := c.Request.Context()
	entries, err := quark.For[Entry](ctx, m.db).OrderBy("id", "DESC").Limit(50).List()
	if err != nil {
		return err
	}
	return c.Render(status, "entries/index.html", map[string]any{
		"Entries": entries,
		"Notice":  m.sessions.GetFlash(ctx, "notice"),
		"Problem": problem,
		"Name":    c.SessionGetString("name"),
		"CSRF":    router.CSRFToken(c.Request),
	})
}
```

**The page is a template the module carries.** `Templates` hands the
embedded directory to the framework's template engine, and
`c.Render(status, "entries/index.html", data)` renders it: the name is the
module's name plus the file's path.

**The form is bound like a JSON body.** `c.BindForm` reads the
URL-encoded fields by their `form` tags and checks the `validate` tags. A
signature that fails them gets the page again, with status 422 and a line
saying what to fix.

**The CSRF token travels in the form.** `router.CSRFToken(c.Request)` is the
token the CSRF middleware issued for this visitor; the template puts it in
the hidden `_csrf_token` field. The middleware compares it with the cookie
it set, and a `POST` without a matching token is refused before `sign`
runs.

**The session remembers, the flash tells once.** `c.SessionPutString`
stores the visitor's name in their session, and the next render puts it back
in the form. `Flash` stores a notice that the next request reads and the
one after does not see: the confirmation shows once, after the redirect.

## 4 — Mount it

Replace `main.go`:

```go title="main.go"
// Command guestbook is a server-rendered application: the entries module
// on the full template of Nucleus, with its pages, form, session and CSRF
// protection.
package main

import (
	"log"

	"github.com/jcsvwinston/nucleus/pkg/nucleus"

	_ "github.com/jcsvwinston/nucleus/drivers/sqlite"

	"example.com/guestbook/entries"
)

func main() {
	if err := nucleus.New().
		FromConfigFile("nucleus.yml").
		Mount(entries.Module()).
		Start(); err != nil {
		log.Fatalf("guestbook: %v", err)
	}
}
```

## 5 — Run it

```bash
go run .
```

Open **http://localhost:8080/guestbook**, sign it, and the page comes back
with your entry, a thank-you line and your name already in the form. Reload,
and the thank-you line is gone; the name stays.

## 6 — What the browser did, from the terminal

The browser kept two cookies — the session and the CSRF token — and sent the
token back in the form. With `curl` and a cookie file, the same exchange is
three commands. Fetch the page, keeping the cookies and the token the form
carries:

```bash
token=$(curl -s -c cookies.txt localhost:8080/guestbook | sed -n 's/.*name="_csrf_token" value="\([^"]*\)".*/\1/p')
```

Sign with the token. The answer is the redirect back to the page:

```bash
curl -s -b cookies.txt -c cookies.txt -o /dev/null -w '%{http_code}\n' \
    -X POST localhost:8080/guestbook \
    --data-urlencode "_csrf_token=$token" \
    --data-urlencode 'name=Ada' \
    --data-urlencode 'message=Signed from the terminal'
```

```text
303
```

Follow it, with the same cookies:

```bash
curl -s -b cookies.txt localhost:8080/guestbook | grep -E 'class="notice"|name="name"|<li>'
```

```text
<p class="notice">Thanks for signing, Ada.</p>
<label>Name <input name="name" value="Ada"></label>
<li><strong>Ada</strong>: Signed from the terminal</li>
```

The flash, the name the session remembered, and the entry. A `POST` from
anywhere else — no cookie, no token — is refused with 419 before the
handler runs:

```bash
curl -s -o /dev/null -w '%{http_code}\n' -X POST localhost:8080/guestbook \
    --data-urlencode 'name=Mallory' \
    --data-urlencode 'message=No token'
```

```text
419
```

## Before production

- **Cookies on plain HTTP.** Session cookies are `Secure` by default.
  Browsers and `curl` accept them from `localhost` over plain HTTP; on any
  other host, serve the application over TLS.
- **Who may sign.** The policy rows let anonymous visitors write. For
  signed-in users only, add a login (link below) and grant `create` to a role
  instead of `anonymous`.

## Where to next

| You want to… | Read |
| --- | --- |
| A login for this application's own users | [Your first login](/nucleus/features/auth/your-first-login/) |
| Sessions, flash data and the CSRF protection in detail | [Sessions and passwords](/nucleus/features/auth/sessions-and-passwords/) |
| Test a form with its CSRF token in-process | [Testing](/nucleus/getting-started/testing/#cookies-csrf-and-sessions) |
| A JSON API with typed endpoints and a generated client | [An API-only service](tutorial-api-only.md) |
| An admin panel over these entries | [The quickstart](quickstart.md) mounts Orbit on a Quark model |
