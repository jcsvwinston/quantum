---
title: "Tutorial: an API-only service"
sidebar_label: API-only service
description: "A JSON service on the lightweight core of Nucleus: typed endpoints, the OpenAPI document derived from them, a check that fails on a breaking change, and a TypeScript client generated from the document."
---

# An API-only service

You will build `todo`, a JSON API and nothing else: no pages, no admin
panel. Its routes are **typed endpoints** — each handler's signature says
what it reads and what it answers — and from those signatures Nucleus binds
and validates the input, writes the output, and derives the API's OpenAPI
document. From the document you get a check for breaking changes and a
TypeScript client.

Everything runs on SQLite. The commands, files and outputs on this page are
executed in order by this site's CI against the
[current certified set](install.md) before they are published.

You need Go 1.26 or newer, the Nucleus CLI at the certified tag — the
[quickstart](quickstart.md) installs it in one command — and, for the last
step, Node.js 22.18 or newer.

## 1 — Scaffold

```bash
nucleus new todo --template api --with quark
cd todo
```

`--template api` is the lightweight core: configuration, logger, router,
database and sessions. It has no admin panel, storage, mail or authorizer,
so **every route you add is open to anyone who can reach it** — add access
control before the service faces a network. `--with quark` fetches Quark
and its SQLite driver.

## 2 — The resource, as typed endpoints

```go title="tasks/tasks.go"
// Package tasks is a JSON API over one Quark model. Every route is a typed
// endpoint: the handler's signature says what it reads and what it answers,
// so the framework binds and validates the input, writes the output and
// describes both in the application's OpenAPI document.
package tasks

import (
	"context"
	"errors"
	"fmt"
	"net/http"

	nucleusErrors "github.com/jcsvwinston/nucleus/pkg/errors"
	"github.com/jcsvwinston/nucleus/pkg/nucleus"
	"github.com/jcsvwinston/quark"

	// Quark's SQLite driver module, with the engine's error classifier.
	_ "github.com/jcsvwinston/quark/drivers/sqlite"
)

// Task is the Quark model and the JSON the API answers with.
type Task struct {
	ID    int64  `db:"id" pk:"true" json:"id"`
	Title string `db:"title" quark:"not_null" json:"title"`
	Done  bool   `db:"done" json:"done"`
}

// TaskList is what GET /tasks answers.
type TaskList struct {
	Tasks []Task `json:"tasks"`
	Count int    `json:"count"`
}

// TaskFilter is the query GET /tasks reads.
type TaskFilter struct {
	Done *bool `query:"done" doc:"Only the tasks in this state"`
}

// NewTask is the body POST /tasks reads.
type NewTask struct {
	Title string `json:"title" validate:"required,max=200"`
}

// TaskRef is the path of the routes on one task.
type TaskRef struct {
	ID int64 `path:"id"`
}

// TaskChange is the path and the body PATCH /tasks/{id} reads.
type TaskChange struct {
	ID   int64 `path:"id"`
	Done bool  `json:"done"`
}

type module struct {
	db *quark.Client
}

// Module returns the tasks API as a nucleus module.
func Module() nucleus.ModuleSpec {
	m := &module{}
	return nucleus.Module[struct{}]{
		Name: "tasks",

		// Quark over the database the framework opened from nucleus.yml;
		// the table is created from the model on start.
		OnStart: func(ctx context.Context, rt nucleus.Runtime, _ struct{}) error {
			db, err := quark.NewWithDB("sqlite", rt.DB())
			if err != nil {
				return fmt.Errorf("tasks: quark client: %w", err)
			}
			if err := db.RegisterModel(&Task{}); err != nil {
				return err
			}
			if err := db.MigrateRegistered(ctx); err != nil {
				return err
			}
			m.db = db
			return nil
		},

		Routes: func(r nucleus.Router, _ struct{}) {
			nucleus.Handle(r, http.MethodGet, "/tasks", m.listTasks)
			nucleus.Handle(r, http.MethodPost, "/tasks", m.createTask, nucleus.Status(http.StatusCreated))
			nucleus.Handle(r, http.MethodGet, "/tasks/{id}", m.showTask)
			nucleus.Handle(r, http.MethodPatch, "/tasks/{id}", m.updateTask)
			nucleus.Handle(r, http.MethodDelete, "/tasks/{id}", m.deleteTask)
		},
	}.Build()
}

func (m *module) listTasks(c *nucleus.Context, f TaskFilter) (TaskList, error) {
	q := quark.For[Task](c.Request.Context(), m.db).OrderBy("id", "ASC").Limit(100)
	if f.Done != nil {
		q = q.Where("done", "=", *f.Done)
	}
	tasks, err := q.List()
	if err != nil {
		return TaskList{}, err
	}
	return TaskList{Tasks: tasks, Count: len(tasks)}, nil
}

func (m *module) createTask(c *nucleus.Context, in NewTask) (Task, error) {
	t := Task{Title: in.Title}
	if err := quark.For[Task](c.Request.Context(), m.db).Create(&t); err != nil {
		return Task{}, err
	}
	return t, nil
}

func (m *module) showTask(c *nucleus.Context, in TaskRef) (Task, error) {
	return m.find(c.Request.Context(), in.ID)
}

func (m *module) updateTask(c *nucleus.Context, in TaskChange) (Task, error) {
	t, err := m.find(c.Request.Context(), in.ID)
	if err != nil {
		return Task{}, err
	}
	t.Done = in.Done
	if _, err := quark.For[Task](c.Request.Context(), m.db).UpdateFields(&t, "done"); err != nil {
		return Task{}, err
	}
	return t, nil
}

// deleteTask answers 204: an output of struct{} has no body.
func (m *module) deleteTask(c *nucleus.Context, in TaskRef) (struct{}, error) {
	t, err := m.find(c.Request.Context(), in.ID)
	if err != nil {
		return struct{}{}, err
	}
	_, err = quark.For[Task](c.Request.Context(), m.db).Delete(&t)
	return struct{}{}, err
}

func (m *module) find(ctx context.Context, id int64) (Task, error) {
	t, err := quark.For[Task](ctx, m.db).Find(id)
	if errors.Is(err, quark.ErrNotFound) {
		return Task{}, nucleusErrors.NotFound("task", fmt.Sprint(id))
	}
	return t, err
}
```

**A typed endpoint is a function from a request type to a response type.**
`nucleus.Handle` registers `func(*nucleus.Context, In) (Out, error)`. The
input is bound by its tags — `path:"id"` from the path, `query:"done"` from
the query string, `json` fields from the body — and checked against its
`validate` tags before the handler runs; a request that fails answers 400 or
422 naming the field. The output is written as JSON with the status the
route declares (`nucleus.Status`, 200 by default; `struct{}` answers 204).

**Errors keep one shape.** `nucleusErrors.NotFound` becomes a 404 with the
framework's error envelope, the same envelope the validation errors use, so
a client reads one format.

**The model is a Quark struct.** `quark.NewWithDB` puts Quark over the
database the framework already opened; `RegisterModel` and
`MigrateRegistered` create the table from the struct when the module starts.

## 3 — Mount it

Replace `main.go`:

```go title="main.go"
// Command todo serves a JSON API: the tasks module on the lightweight core
// of Nucleus, with the OpenAPI document derived from its routes.
package main

import (
	"log"

	"github.com/jcsvwinston/nucleus/pkg/nucleus"

	_ "github.com/jcsvwinston/nucleus/drivers/sqlite"

	"example.com/todo/tasks"
)

func main() {
	if err := nucleus.New().
		FromConfigFile("nucleus.yml").
		WithOpenAPIDocument("/openapi.json").
		WithoutDefaults().
		Mount(tasks.Module()).
		Start(); err != nil {
		log.Fatalf("todo: %v", err)
	}
}
```

## 4 — Run it and call it

Start the service, and leave it running in its own terminal:

```bash
go run .
```

From a second terminal, create two tasks:

```bash
curl -s -X POST localhost:8080/tasks \
    -H 'Content-Type: application/json' \
    -d '{"title":"Write the tutorial"}'
```

```json
{"id":1,"title":"Write the tutorial","done":false}
```

```bash
curl -s -X POST localhost:8080/tasks \
    -H 'Content-Type: application/json' \
    -d '{"title":"Run it in CI"}'
```

```json
{"id":2,"title":"Run it in CI","done":false}
```

Close the first one, and list what is still open:

```bash
curl -s -X PATCH localhost:8080/tasks/1 \
    -H 'Content-Type: application/json' \
    -d '{"done":true}'
```

```json
{"id":1,"title":"Write the tutorial","done":true}
```

```bash
curl -s 'localhost:8080/tasks?done=false'
```

```json
{"tasks":[{"id":2,"title":"Run it in CI","done":false}],"count":1}
```

A body that breaks the rules of `NewTask` never reaches the handler:

```bash
curl -s -X POST localhost:8080/tasks \
    -H 'Content-Type: application/json' \
    -d '{"title":""}'
```

```json
{"error":{"code":"VALIDATION_FAILED","message":"validation failed","details":{"title":"this field is required"}}}
```

And a task that does not exist is a 404 in the same envelope:

```bash
curl -s localhost:8080/tasks/9
```

```json
{"error":{"code":"NOT_FOUND","message":"task '9' not found"}}
```

Delete the second task:

```bash
curl -s -o /dev/null -w '%{http_code}\n' -X DELETE localhost:8080/tasks/2
```

```text
204
```

## 5 — The document, and a check that keeps it

The service describes itself at `/openapi.json`. `nucleus openapi` exports
the same document without starting a server — it boots the application
without listening and reads it back:

```bash
nucleus openapi --out openapi.json
```

Each route appears with its parameters, its request body and its response,
and the schemas come from the Go types: `Task` has `id`, `title` and `done`,
all required; `NewTask.title` is a required string of at most 200
characters; `done` on `GET /tasks` is an optional boolean query parameter.

Commit that file. From then on, `--check` compares what the application
serves with it:

```bash
nucleus openapi --check openapi.json
```

```text
OpenAPI document compatible with openapi.json: no change breaks a client written against it
```

Additions pass. A change that breaks a client written against the committed
document fails the command and names the change: an operation removed, a
new required field or parameter, a narrower type or a tighter bound, a
response field removed. Run it in CI, and re-export the file when you mean
to change the contract.

## 6 — A TypeScript client

Generate a client from the document the application serves:

```bash
nucleus openapi --client typescript --out web/api.ts
```

It is one file over `fetch` with no dependency: a type for each schema and a
`Client` with one method per operation, named after the handler —
`createTask`, `listTasks`, `updateTask`… An answer outside 2xx throws
`ApiError`, with the status and the code from the error envelope.

A small script that uses it — the `package.json` makes `web/` an ES module
package, so the script can import the client by its `.ts` name and use
top-level `await`:

```json title="web/package.json"
{ "type": "module", "private": true }
```

```ts title="web/main.ts"
import { ApiError, Client } from "./api.ts";

const api = new Client({ baseUrl: process.argv[2] ?? "http://localhost:8080" });

const task = await api.createTask({ title: "Call the API from TypeScript" });
const open = await api.listTasks({ done: false });
console.log(`created task ${task.id}; ${open.count} open`);

try {
  await api.createTask({ title: "" });
} catch (err) {
  if (!(err instanceof ApiError)) throw err;
  console.log(`refused: ${err.status} ${err.code}`);
}
```

Node.js 22.18 and newer run a `.ts` file directly:

```bash
node web/main.ts http://localhost:8080
```

```text
created task 3; 1 open
refused: 422 VALIDATION_FAILED
```

In a frontend project the same file goes through the project's own build;
regenerate it whenever the document changes, and type-check it with
`tsc --strict` like the rest of your code.

## Where to next

| You want to… | Read |
| --- | --- |
| Everything the derived document contains, and how to give it a hand-written base | [The OpenAPI document](/nucleus/concepts/routing/#the-openapi-document) |
| Reject requests that depart from the document before the handler runs | [Enforcing the document](/nucleus/concepts/routing/#enforcing-the-document) |
| Hold every response of a test to the document | [Testing](/nucleus/getting-started/testing/#holding-a-response-to-the-api-document) |
| Put access control in front of the routes | [RBAC and the middleware chain](/nucleus/features/auth/rbac-and-middleware/) |
| One database per customer, or rows per customer | [A multi-tenant SaaS](tutorial-multi-tenant-saas.md) |
