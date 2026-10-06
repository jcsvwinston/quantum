---
title: "Coming from Django"
sidebar_label: From Django
description: "What each piece of a Django project becomes in Nucleus, Quark and Orbit, a polls app ported and called with the same HTTP requests as before, and what has no equivalent yet."
---

# Coming from Django

Django ships an application's pieces in one framework: settings, URLs, views,
middleware, the ORM and its migrations, the admin, authentication, templates,
forms and a test client. The suite splits the same pieces between three Go
products made to be used together: [Nucleus](/nucleus/) hosts the application —
settings, routes, middleware, sign-in, templates, jobs and the test kit —
[Quark](/quark/intro/) is the ORM, and [Orbit](/orbit/) is the admin. The
language changes, from Python to compiled and statically typed Go, so code does
not carry over; the shape of a project mostly does.

The first half of this page maps each piece. The second ports a small polls
app — two models, three JSON views and the admin — and makes the same HTTP
requests its clients make. The Django listings are there to compare with: this
site's CI does not run Python. The Go side's commands, files and outputs are
executed in order by CI against the [current certified set](install.md) before
they are published.

## The concept map

### The project

| Django | Quantum | Notes |
| --- | --- | --- |
| `django-admin startproject mysite` | `nucleus new mysite` | The default `mvc` template has sessions, CSRF protection and a default-deny authorizer from the first request. `--with orbit,quark,quarkdatasource` adds the admin panel and the ORM. |
| `python manage.py startapp polls` | a Go package that returns a `nucleus.Module` | `nucleus generate module polls --mount` writes one, with its policy rows, its migration and a test, and mounts it. |
| `settings.py` | `nucleus.yml`, with `NUCLEUS_*` environment overrides | A module's own settings live under `modules.<name>` and bind to a typed struct that is validated on start. |
| `INSTALLED_APPS` | `.Mount(polls.Module(…))` in `main.go` | |
| `python manage.py runserver` | `go run .`, or `nucleus dev` to rebuild and restart on every change | |

### URLs, views and middleware

| Django | Nucleus | Notes |
| --- | --- | --- |
| `path("questions/<int:pk>", views.detail)` in `urls.py` | `nucleus.Handle(r, http.MethodGet, "/questions/{id}", m.detail)` in the module's `Routes` | The input type declares `ID int64` with `path:"id"`: the conversion `<int:pk>` makes, with a 400 for a value that is not a number. |
| `include("polls.urls")` under `api/` | the module's `Prefix: "/api"` | |
| a view that returns `JsonResponse` | a typed endpoint, `func(*nucleus.Context, In) (Out, error)` | The input is bound and validated before the handler runs, and the output is written as JSON. A view that renders a template is a plain handler that calls `c.Render`. |
| `@require_POST`, `@require_http_methods` | the method the route is registered with | Another method answers 405. |
| `get_object_or_404` | return `nucleusErrors.NotFound("question", id)` | Every error leaves as JSON, in one shape. |
| `MIDDLEWARE` | `func(http.Handler) http.Handler`, for a module (`Module.Middleware`) or for some routes (`r.With`) | |
| Django REST framework: serializers and viewsets | typed endpoints, and `r.Resource` for a controller with the REST verbs | The OpenAPI document is derived from the endpoints and served at `/openapi.json`. |

### Models and the ORM

| Django | Quark | Notes |
| --- | --- | --- |
| `class Question(models.Model)` | a struct whose fields carry `db` tags | `CharField(max_length=200)` is a `string` with `db:"text,size=200"`; `IntegerField(default=0)` an `int` with `default:"0"`; `auto_now_add=True` a `CreatedAt time.Time` on `created_at`. |
| `ForeignKey(Question, related_name="choices")` | `rel:"belongs_to"` on `Choice`, `rel:"has_many"` on `Question` | The relation loads and saves. `MigrateRegistered` creates the column, not a database constraint (see [what has no equivalent](#what-has-no-equivalent-yet)). |
| `makemigrations`, then `migrate` | `MigrateRegistered` on start for a young schema; `quark migrate create <name> --from-models <dir>` writes a migration from the models, and `quark migrate diff` lists where models and database differ | `nucleus makemigrations` is an alias of `nucleus migrate create`: an empty pair of SQL files, not a migration read from the models. |
| `Choice.objects.filter(votes__gte=1)` | `quark.For[Choice](ctx, db).Where("votes", ">=", 1).List()` | Column and operator are validated before any SQL is built. |
| `.exclude(…)`, `Q(…) \| Q(…)` | `.WhereNot(…)`, `.Or(func(q *quark.Query[T]) *quark.Query[T] { … })` | |
| `.order_by("-id")[:20]` | `.OrderBy("id", "DESC").Limit(20)` | |
| `.get(pk=1)` and `DoesNotExist` | `.Find(1)` and `quark.ErrNotFound` | |
| `prefetch_related("choices")`, `select_related("question")` | `.Preload("Choices")`, `.Preload("Question")` | `Preload` runs batched queries, where `select_related` joins. |
| `.update(votes=F("votes") + 1)` | `.UpdateMap(map[string]any{"votes": quark.Add(quark.Col("votes"), quark.Lit(1))})` | One `UPDATE` that adds in the database. |
| `.count()`, `.aggregate(Sum("votes"))` | `.Count()`, `.Sum("votes")` | |
| `with transaction.atomic():` | `client.Tx(ctx, func(tx *quark.Tx) error { … })` | Inside it, `quark.ForTx[T](ctx, tx)` instead of `quark.For`. |
| `bulk_create` | `CreateBatch`, or `Create` on a parent that carries its children | |
| `post_save` and the other model signals | lifecycle hooks on the model (`AfterCreate`…), or Quark's event bus (`client.UseEventBus`) | |

### The admin

| Django | Orbit | Notes |
| --- | --- | --- |
| `admin.site.register(Question)` | `quarkdatasource.Register[Question](ds)`, with `orbit.Module` mounted on `DataSource: ds` | |
| `TabularInline` | nothing to declare | A model whose `belongs_to` names another is edited inline with it. |
| admin actions | `ModelAction` in `orbit.Config.Actions`, run on the selected rows | |
| `python manage.py createsuperuser` | `nucleus createsuperuser`, or `BootstrapUsername` and `BootstrapPassword` on the first start | |

### Sign-in, templates and forms

| Django | Nucleus | Notes |
| --- | --- | --- |
| `django.contrib.auth`, `@login_required` | sessions, password and OIDC sign-in, JWT and API keys | [Your first login](/nucleus/features/auth/your-first-login/) |
| permissions and groups, `@permission_required` | role-based access control: `Policies` rows on the module, and `rbac_policy.csv` | A Django view is open until a decorator closes it; on the `mvc` template a route is refused until a policy row allows it. |
| `CsrfViewMiddleware`, `{% csrf_token %}`, `@csrf_exempt` | `csrf_enabled: true`, `router.CSRFToken(r)` in the form, `CSRFExempt` on the module | |
| templates and `render()` | Go's `html/template`: `Module.Templates` and `c.Render` | |
| `forms.Form` | a struct with `form` and `validate` tags, bound by `c.BindForm` | |
| the messages framework | `Flash` and `GetFlash` on the session | |
| `makemessages`, `compilemessages` | the same two commands in the `nucleus` CLI, on `.po` catalogs | |

### Background work and tests

| Django | Nucleus | Notes |
| --- | --- | --- |
| Celery, or Django's tasks | a module's `Jobs` on a schedule, `rt.Tasks()` for one-off work | `jobs_provider: sql` keeps a durable queue in the application's own database. |
| Channels | WebSocket and SSE channels | |
| `TestCase` and `self.client` | `nucleustest.Start`: the application in the test process, and a client that keeps cookies and fetches CSRF tokens | |
| `dumpdata`, `loaddata` | `nucleus dumpdata`, `nucleus loaddata` | JSON fixtures, by table. |

## The app before the port

`polls` keeps questions and their choices, and counts votes. Its models:

```python
# polls/models.py
from django.db import models


class Question(models.Model):
    text = models.CharField(max_length=200)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.text


class Choice(models.Model):
    question = models.ForeignKey(Question, on_delete=models.CASCADE, related_name="choices")
    text = models.CharField(max_length=200)
    votes = models.IntegerField(default=0)

    class Meta:
        ordering = ["id"]

    def __str__(self):
        return self.text
```

its admin, with the choices edited inside their question:

```python
# polls/admin.py
from django.contrib import admin

from .models import Choice, Question


class ChoiceInline(admin.TabularInline):
    model = Choice


@admin.register(Question)
class QuestionAdmin(admin.ModelAdmin):
    inlines = [ChoiceInline]


admin.site.register(Choice)
```

and its JSON views with their URLs, which the project's `urls.py` includes
under `api/`:

```python
# polls/views.py
import json

from django.db import transaction
from django.db.models import F
from django.http import JsonResponse
from django.shortcuts import get_object_or_404
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_http_methods, require_POST

from .models import Choice, Question


def as_json(question):
    return {
        "id": question.id,
        "text": question.text,
        "choices": [{"id": c.id, "text": c.text, "votes": c.votes} for c in question.choices.all()],
    }


@csrf_exempt
@require_http_methods(["GET", "POST"])
def questions(request):
    if request.method == "GET":
        latest = Question.objects.prefetch_related("choices").order_by("-id")[:20]
        return JsonResponse([as_json(q) for q in latest], safe=False)
    body = json.loads(request.body)
    text, choices = body.get("text", ""), body.get("choices", [])
    if not text or len(text) > 200 or len(choices) < 2 or not all(choices):
        return JsonResponse({"error": "a question needs text and two choices or more"}, status=422)
    with transaction.atomic():
        question = Question.objects.create(text=text)
        Choice.objects.bulk_create([Choice(question=question, text=c) for c in choices])
    return JsonResponse(as_json(question), status=201)


@require_GET
def detail(request, pk):
    return JsonResponse(as_json(get_object_or_404(Question, pk=pk)))


@csrf_exempt
@require_POST
def vote(request, pk):
    question = get_object_or_404(Question, pk=pk)
    choice = json.loads(request.body).get("choice")
    if not question.choices.filter(pk=choice).update(votes=F("votes") + 1):
        return JsonResponse({"error": "no such choice"}, status=404)
    return JsonResponse(as_json(question))
```

```python
# polls/urls.py
from django.urls import path

from . import views

urlpatterns = [
    path("questions", views.questions),
    path("questions/<int:pk>", views.detail),
    path("questions/<int:pk>/vote", views.vote),
]
```

Its clients rely on this contract, and the port keeps it:

| Request | Answers |
| --- | --- |
| `POST /api/questions` | 201 with the question and its choices; 422 for a question without text or with fewer than two choices |
| `GET /api/questions` | 200 with the latest questions, newest first |
| `GET /api/questions/{id}` | 200 with the question, or 404 |
| `POST /api/questions/{id}/vote` | 200 with the question and its new counts, or 404 for a choice that is not one of the question's |

## 1 — Scaffold

```bash
nucleus new mysite --with orbit,quark,quarkdatasource
cd mysite
```

`nucleus new` is `startproject`: it writes `main.go`, `nucleus.yml`,
`rbac_policy.csv` and a Dockerfile, on the full `mvc` template. `--with` fetches Orbit, Quark
and the adapter that lets Orbit's Data Studio edit Quark models, and the
scaffold already mounts the admin panel under `/admin`.

## 2 — The models

Go does not care what the files of a package are called; these two follow the
names Django gives them.

```go title="polls/models.go"
// Package polls is the Django polls app, ported to Go: the models here,
// the views and their URLs in views.go.
package polls

import (
	"context"
	"time"

	"github.com/jcsvwinston/quark"
)

// Question is models.Question. CreatedAt is auto_now_add: Quark fills
// created_at on Create.
type Question struct {
	ID        int64     `db:"id" pk:"true" json:"id"`
	Text      string    `db:"text,size=200" quark:"not_null" json:"text"`
	CreatedAt time.Time `db:"created_at" json:"-"`
	// The reverse side of Choice.Question: related_name="choices".
	Choices []Choice `rel:"has_many" join:"question_id" json:"choices"`
}

// Choice is models.Choice. The belongs_to relation is the ForeignKey: it
// tells Quark how to load the question, and tells Orbit's Data Studio to
// edit the choices inline with their question.
type Choice struct {
	ID         int64     `db:"id" pk:"true" json:"id"`
	QuestionID int64     `db:"question_id" quark:"not_null,index" json:"-"`
	Question   *Question `rel:"belongs_to" join:"question_id" json:"-"`
	Text       string    `db:"text,size=200" quark:"not_null" json:"text"`
	Votes      int       `db:"votes" default:"0" json:"votes"`
}

// Migrate creates the tables that are missing — manage.py migrate for a
// young schema. main.go calls it before the server starts.
func Migrate(ctx context.Context, client *quark.Client) error {
	if err := client.RegisterModel(&Question{}, &Choice{}); err != nil {
		return err
	}
	return client.MigrateRegistered(ctx)
}
```

A field is a column when it has a `db` tag, and a relation when it has a `rel`
tag. The `json` tags give the views the same keys `as_json` wrote.

## 3 — The views and their URLs

```go title="polls/views.go"
package polls

import (
	"cmp"
	"context"
	"errors"
	"fmt"
	"net/http"
	"slices"

	nucleusErrors "github.com/jcsvwinston/nucleus/pkg/errors"
	"github.com/jcsvwinston/nucleus/pkg/nucleus"
	"github.com/jcsvwinston/quark"
)

// NewQuestion is the body POST /api/questions reads: the checks the Django
// view wrote by hand, as validate tags.
type NewQuestion struct {
	Text    string   `json:"text" validate:"required,max=200"`
	Choices []string `json:"choices" validate:"min=2,dive,required,max=200"`
}

// QuestionRef is the path of GET /api/questions/{id}: <int:pk>.
type QuestionRef struct {
	ID int64 `path:"id"`
}

// Ballot is the path and the body of POST /api/questions/{id}/vote.
type Ballot struct {
	ID     int64 `path:"id"`
	Choice int64 `json:"choice" validate:"required"`
}

type module struct {
	db *quark.Client
}

// Module returns the polls app as a nucleus module: what INSTALLED_APPS and
// the project's urls.py did for it.
func Module(client *quark.Client) nucleus.ModuleSpec {
	m := &module{db: client}
	return nucleus.Module[struct{}]{
		Name:   "polls",
		Prefix: "/api",

		// A Django view is open until a decorator closes it. Nucleus
		// refuses a route until a policy row allows it, so the module says
		// who may call what: here, anyone may read, ask and vote.
		Policies: []nucleus.PolicyRule{
			{Subject: "anonymous", Object: "/questions", Action: "read"},
			{Subject: "anonymous", Object: "/questions", Action: "create"},
			{Subject: "anonymous", Object: "/questions/*", Action: "read"},
			{Subject: "anonymous", Object: "/questions/*", Action: "create"},
		},
		// @csrf_exempt: a JSON API whose clients send no session cookie.
		CSRFExempt: []string{"/"},

		Routes: func(r nucleus.Router, _ struct{}) {
			nucleus.Handle(r, http.MethodGet, "/questions", m.index)
			nucleus.Handle(r, http.MethodPost, "/questions", m.create, nucleus.Status(http.StatusCreated))
			nucleus.Handle(r, http.MethodGet, "/questions/{id}", m.detail)
			nucleus.Handle(r, http.MethodPost, "/questions/{id}/vote", m.vote)
		},
	}.Build()
}

// index is prefetch_related("choices").order_by("-id")[:20].
func (m *module) index(c *nucleus.Context, _ struct{}) ([]Question, error) {
	qs, err := quark.For[Question](c.Request.Context(), m.db).
		Preload("Choices").OrderBy("id", "DESC").Limit(20).List()
	for i := range qs {
		sortChoices(&qs[i])
	}
	return qs, err
}

// create is the question and its choices in one transaction, as
// transaction.atomic() around create and bulk_create was.
func (m *module) create(c *nucleus.Context, in NewQuestion) (Question, error) {
	ctx := c.Request.Context()
	q := Question{Text: in.Text}
	for _, text := range in.Choices {
		q.Choices = append(q.Choices, Choice{Text: text})
	}
	err := m.db.Tx(ctx, func(tx *quark.Tx) error {
		// Create saves the question, then each choice with its key.
		return quark.ForTx[Question](ctx, tx).Create(&q)
	})
	return q, err
}

func (m *module) detail(c *nucleus.Context, in QuestionRef) (Question, error) {
	return m.load(c.Request.Context(), in.ID)
}

// vote is choices.filter(pk=…).update(votes=F("votes") + 1): one UPDATE
// that adds in the database, so two votes at the same time both count, and
// that only matches a choice of this question.
func (m *module) vote(c *nucleus.Context, in Ballot) (Question, error) {
	ctx := c.Request.Context()
	n, err := quark.For[Choice](ctx, m.db).
		Where("id", "=", in.Choice).
		Where("question_id", "=", in.ID).
		UpdateMap(map[string]any{"votes": quark.Add(quark.Col("votes"), quark.Lit(1))})
	if err != nil {
		return Question{}, err
	}
	if n == 0 {
		return Question{}, nucleusErrors.NotFound("choice", fmt.Sprint(in.Choice))
	}
	return m.load(ctx, in.ID)
}

// load is get_object_or_404(Question, pk=id), with its choices.
func (m *module) load(ctx context.Context, id int64) (Question, error) {
	q, err := quark.For[Question](ctx, m.db).Preload("Choices").Find(id)
	if errors.Is(err, quark.ErrNotFound) {
		return Question{}, nucleusErrors.NotFound("question", fmt.Sprint(id))
	}
	sortChoices(&q)
	return q, err
}

// sortChoices is Meta.ordering = ["id"]: a model has no default order in
// Quark, and a preloaded relation comes in whatever order the database
// returns it.
func sortChoices(q *Question) {
	slices.SortFunc(q.Choices, func(a, b Choice) int { return cmp.Compare(a.ID, b.ID) })
}
```

What moved where:

**`urls.py` and the decorators are the routes.** Each `nucleus.Handle` names
the method, the path and the view; the module's `Prefix` is the `include`
under `api/`. A request with another method is answered 405 before any view
runs, which is what `@require_POST` did.

**The checks are tags.** `NewQuestion` carries the rules the Django view
tested by hand. A body that breaks them never reaches `create`: the answer is
a 422 that names the field.

**The queries keep their shape.** `Preload` is `prefetch_related`,
`UpdateMap` with `quark.Add` is the `F()` expression, and `client.Tx` is
`transaction.atomic()`. `Create` on a question that carries its choices saves
all of them, so the `bulk_create` has no line of its own.

## 4 — Register the models and mount the app

Replace `main.go`. It does what the project's `settings.py`, `urls.py` and
`admin.py` did together:

```go title="main.go"
// Command mysite is the Django project, ported: the polls app and the
// admin panel in one Nucleus application.
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

	"example.com/mysite/polls"
)

func main() {
	ctx := context.Background()

	// The same database file nucleus.yml names.
	client, err := quark.New("sqlite", "app.db")
	if err != nil {
		log.Fatalf("mysite: quark client: %v", err)
	}
	defer client.Close()
	if err := polls.Migrate(ctx, client); err != nil {
		log.Fatalf("mysite: migrate: %v", err)
	}

	// admin.py: both models in the admin, the choices inline with their
	// question because Choice belongs to Question.
	ds := quarkdatasource.New(client)
	if err := quarkdatasource.Register[polls.Question](ds); err != nil {
		log.Fatalf("mysite: register Question: %v", err)
	}
	if err := quarkdatasource.Register[polls.Choice](ds); err != nil {
		log.Fatalf("mysite: register Choice: %v", err)
	}

	if err := nucleus.New().
		FromConfigFile("nucleus.yml").
		WithOpenAPIDocument("/openapi.json").
		Mount(polls.Module(client)).
		Mount(orbit.Module(orbit.Config{
			Prefix:            "/admin",
			Title:             "mysite",
			DataSource:        ds,
			BootstrapUsername: "admin",
			BootstrapEmail:    "admin@example.com",
			BootstrapPassword: bootstrapPassword(),
		})).
		Start(); err != nil {
		log.Fatalf("mysite: %v", err)
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

`BootstrapUsername` and `BootstrapPassword` create the first admin account
when there is none — `createsuperuser`, done on the first start.

## 5 — Run it

`go run .` is `runserver`, and the `polls.Migrate` call in `main.go` is the
`migrate` that runs before it. Leave it running in its own terminal:

```bash
go run .
```

## 6 — The same requests

From a second terminal, ask two questions:

```bash
curl -s -X POST localhost:8080/api/questions \
    -H 'Content-Type: application/json' \
    -d '{"text":"Tabs or spaces?","choices":["Tabs","Spaces"]}'
```

```json
{"id":1,"text":"Tabs or spaces?","choices":[{"id":1,"text":"Tabs","votes":0},{"id":2,"text":"Spaces","votes":0}]}
```

```bash
curl -s -X POST localhost:8080/api/questions \
    -H 'Content-Type: application/json' \
    -d '{"text":"Which editor?","choices":["Vim","Emacs","Something else"]}'
```

```json
{"id":2,"text":"Which editor?","choices":[{"id":3,"text":"Vim","votes":0},{"id":4,"text":"Emacs","votes":0},{"id":5,"text":"Something else","votes":0}]}
```

A question with one choice is refused before the view runs:

```bash
curl -s -X POST localhost:8080/api/questions \
    -H 'Content-Type: application/json' \
    -d '{"text":"Only one?","choices":["Yes"]}'
```

```json
{"error":{"code":"VALIDATION_FAILED","message":"validation failed","details":{"choices":"must be at least 2 items"}}}
```

Vote, twice:

```bash
curl -s -X POST localhost:8080/api/questions/1/vote \
    -H 'Content-Type: application/json' \
    -d '{"choice":2}'
```

```json
{"id":1,"text":"Tabs or spaces?","choices":[{"id":1,"text":"Tabs","votes":0},{"id":2,"text":"Spaces","votes":1}]}
```

```bash
curl -s -X POST localhost:8080/api/questions/1/vote \
    -H 'Content-Type: application/json' \
    -d '{"choice":2}'
```

```json
{"id":1,"text":"Tabs or spaces?","choices":[{"id":1,"text":"Tabs","votes":0},{"id":2,"text":"Spaces","votes":2}]}
```

Choice 3 belongs to the other question, so it is not a choice of this one:

```bash
curl -s -X POST localhost:8080/api/questions/1/vote \
    -H 'Content-Type: application/json' \
    -d '{"choice":3}'
```

```json
{"error":{"code":"NOT_FOUND","message":"choice '3' not found"}}
```

The latest questions, newest first, and one that does not exist:

```bash
curl -s localhost:8080/api/questions
```

```json
[{"id":2,"text":"Which editor?","choices":[{"id":3,"text":"Vim","votes":0},{"id":4,"text":"Emacs","votes":0},{"id":5,"text":"Something else","votes":0}]},{"id":1,"text":"Tabs or spaces?","choices":[{"id":1,"text":"Tabs","votes":0},{"id":2,"text":"Spaces","votes":2}]}]
```

```bash
curl -s localhost:8080/api/questions/9
```

```json
{"error":{"code":"NOT_FOUND","message":"question '9' not found"}}
```

## 7 — The admin

Open **http://localhost:8080/admin** and sign in as `admin` with the password
`quickstart`. **Data Studio** lists `Question` and `Choice`; open a question
and its choices are there to edit with it, as the `ChoiceInline` showed them.
The list columns, the search and the filters come from the models' fields.

## 8 — The test

The Django test case, using the test client against a test database:

```python
# polls/tests.py
from django.test import TestCase


class VoteTests(TestCase):
    def post(self, url, data):
        return self.client.post(url, data, content_type="application/json")

    def test_vote(self):
        q = self.post("/api/questions", {"text": "Tabs or spaces?", "choices": ["Tabs", "Spaces"]}).json()
        voted = self.post(f"/api/questions/{q['id']}/vote", {"choice": q["choices"][1]["id"]}).json()
        self.assertEqual(voted["choices"][1]["votes"], 1)

        other = self.post("/api/questions", {"text": "Which editor?", "choices": ["Vim", "Emacs"]}).json()
        r = self.post(f"/api/questions/{q['id']}/vote", {"choice": other["choices"][0]["id"]})
        self.assertEqual(r.status_code, 404)
```

The port, with the application started in the test process on its own
`nucleus.yml` and a temporary database:

```go title="polls/polls_test.go"
package polls_test

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

	"example.com/mysite/polls"
)

// TestVote is the Django test case, ported.
func TestVote(t *testing.T) {
	t.Chdir("..") // the project root, where nucleus.yml is
	file := filepath.Join(t.TempDir(), "test.db")
	client, err := quark.New("sqlite", file)
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()
	if err := polls.Migrate(context.Background(), client); err != nil {
		t.Fatal(err)
	}
	srv := nucleustest.Start(t, nucleus.New().
		FromConfigFile("nucleus.yml").
		WithDatabases(map[string]app.DatabaseConfig{"default": {URL: "sqlite://" + file}}).
		Mount(polls.Module(client)))

	var q polls.Question
	srv.Post("/api/questions", map[string]any{
		"text": "Tabs or spaces?", "choices": []string{"Tabs", "Spaces"},
	}).JSON(t, &q)

	var voted polls.Question
	srv.Post(fmt.Sprintf("/api/questions/%d/vote", q.ID),
		map[string]int64{"choice": q.Choices[1].ID}).JSON(t, &voted)
	if got := voted.Choices[1].Votes; got != 1 {
		t.Errorf("votes for %q after one vote: got %d, want 1", voted.Choices[1].Text, got)
	}

	var other polls.Question
	srv.Post("/api/questions", map[string]any{
		"text": "Which editor?", "choices": []string{"Vim", "Emacs"},
	}).JSON(t, &other)
	resp := srv.Post(fmt.Sprintf("/api/questions/%d/vote", q.ID),
		map[string]int64{"choice": other.Choices[0].ID})
	if resp.Status != http.StatusNotFound {
		t.Errorf("voting with another question's choice: got HTTP %d, want 404", resp.Status)
	}
}
```

```bash
go test ./...
```

## What a client sees change

The routes, the status codes and the success bodies are the ones the Django
views answered. Two things are not:

- **Error bodies.** The Django views wrote `{"error": "…"}` themselves, and
  `get_object_or_404` answered with an HTML page. The port answers every error
  with `{"error": {"code": …, "message": …}}`, with the failing fields under
  `details` for a 422.
- **An id that is not a number.** `/api/questions/abc` matches no
  `<int:pk>` pattern, so Django answers 404; the port's route matches it and
  refuses the value with a 400 that names the parameter.

## What has no equivalent yet

- **A foreign key in the database.** `ForeignKey` creates a constraint and
  `on_delete=CASCADE` removes a question's choices with it. A Quark relation
  creates neither: `MigrateRegistered` makes the column and its index, and
  deleting a question leaves its choices. `quark migrate create --from-models`
  writes the `FOREIGN KEY` clause into a migration; the `ON DELETE` rule is
  yours to add to it.
- **A default ordering on the model.** There is no `Meta.ordering`: each query
  says its order, and a preloaded relation is sorted in Go, as `sortChoices`
  does.
- **Migrations written for you as the models change.** `quark migrate create
  --from-models` writes the tables the models declare, and `quark migrate diff`
  lists where the models and the database differ; the migration for a change
  is yours to write.
- **A `ModelAdmin`.** Data Studio derives the list columns, the search and the
  filters from the model's fields, and there is no per-model class to choose
  them. An admin action that asks for input on a form is not available in this
  set.
- **Forms built from a model.** There is no `ModelForm`: a form is a struct
  with `form` and `validate` tags that you write.
- **The template language.** Templates are Go's `html/template`; Django's tags,
  filters and `{% extends %}` do not carry over.
- **An interactive shell.** Go has no counterpart of `manage.py shell`;
  `nucleus shell` is a SQL prompt on the configured database.

## Where to next

| You want to… | Read |
| --- | --- |
| Pages rendered on the server, a form with its CSRF token, a session and a flash message | [An MVC monolith](tutorial-mvc-monolith.md) |
| Typed endpoints, the OpenAPI document and a generated client | [An API-only service](tutorial-api-only.md) |
| Relations, preloading and recursive saves in Quark | [Relations](/quark/guides/relations/) |
| Versioned migrations instead of creating tables on start | [Migrations and Sync](/quark/guides/migrations/) |
| Everything Data Studio can do | [Orbit features](/orbit/features/#data-studio) |
