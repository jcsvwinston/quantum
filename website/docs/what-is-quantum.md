---
title: What is Quantum?
slug: /
sidebar_position: 1
description: "Three Go products — a web framework, an ORM, an admin panel — and the certified set that ties their versions together. What each one is for, and when not to use the suite."
---

# What is Quantum?

Quantum is three Go products that work together, plus the piece that keeps
them working together:

- **[Nucleus](/nucleus/)** — an MVC/REST web framework built on the standard
  library (`net/http`, `database/sql`, `log/slog`). It is the **host**: your
  application is a Nucleus app, and the other two plug into it.
- **[Quark](/quark/intro/)** — a type-safe ORM for six SQL engines
  (PostgreSQL, MySQL, MariaDB, SQLite, SQL Server, Oracle). It is the **data
  layer** — and the one pillar that also works completely on its own, in any
  Go app, with no trace of the other two.
- **[Orbit](/orbit/)** — an admin panel that mounts **in-process** into a
  Nucleus app: browse and edit your models, watch requests and SQL live,
  manage sessions and access control. One dependency, one `Mount(...)` call,
  no sidecar.

The fourth piece is not a product but a promise: a **certified set** — a
trio of versions of the three products that were tested together and
published as one manifest. You install the set, not three guesses.
[More on that here](certified-sets.md).

## Who mounts on whom

<svg viewBox="0 0 680 372" role="img" aria-label="Topology: Orbit mounts in-process on Nucleus inside your application; Quark talks to the SQL database and also works standalone; Quantum pins the three versions as a certified set." style={{maxWidth: '680px', width: '100%', height: 'auto', display: 'block', margin: '1rem auto'}}>
  {/* certified-set frame */}
  <rect x="10" y="10" width="660" height="296" rx="10" fill="none" stroke="var(--qtm-signal)" strokeWidth="1.2" strokeDasharray="6 5" opacity="0.75" />
  <text x="26" y="34" fill="var(--qtm-signal)" fontFamily="var(--ifm-font-family-monospace)" fontSize="12.5">Quantum — a certified set: three versions tested together</text>
  {/* application process */}
  <rect x="34" y="52" width="612" height="196" rx="8" fill="none" stroke="currentColor" strokeWidth="1" opacity="0.5" />
  <text x="50" y="76" fill="currentColor" opacity="0.65" fontFamily="var(--ifm-font-family-monospace)" fontSize="12">your Go application — one process, one binary</text>
  {/* Nucleus box */}
  <rect x="58" y="94" width="252" height="72" rx="6" fill="none" stroke="currentColor" strokeWidth="1.4" />
  <text x="76" y="120" fill="currentColor" fontFamily="var(--ifm-font-family-monospace)" fontSize="15" fontWeight="600">Nucleus</text>
  <text x="76" y="140" fill="currentColor" opacity="0.75" fontSize="12.5">web framework — the host</text>
  <text x="76" y="156" fill="currentColor" opacity="0.75" fontSize="12.5">routing · modules · auth · CLI</text>
  {/* Orbit box */}
  <rect x="408" y="94" width="212" height="72" rx="6" fill="none" stroke="currentColor" strokeWidth="1.4" />
  <text x="426" y="120" fill="currentColor" fontFamily="var(--ifm-font-family-monospace)" fontSize="15" fontWeight="600">Orbit</text>
  <text x="426" y="140" fill="currentColor" opacity="0.75" fontSize="12.5">admin panel — Data Studio,</text>
  <text x="426" y="156" fill="currentColor" opacity="0.75" fontSize="12.5">live feed, sessions, RBAC</text>
  {/* Orbit -> Nucleus arrow */}
  <line x1="408" y1="130" x2="318" y2="130" stroke="var(--qtm-signal)" strokeWidth="1.6" />
  <polygon points="318,130 328,125.5 328,134.5" fill="var(--qtm-signal)" />
  <text x="316" y="120" fill="currentColor" opacity="0.75" fontSize="11">mounts in-process</text>
  {/* Quark box — inside the app, NOT inside Nucleus: a sibling library */}
  <rect x="58" y="186" width="252" height="40" rx="6" fill="none" stroke="currentColor" strokeWidth="1.4" />
  <circle cx="76" cy="206" r="3.4" fill="var(--qtm-signal)" />
  <text x="86" y="211" fill="currentColor" fontFamily="var(--ifm-font-family-monospace)" fontSize="13">Quark — ORM, the data layer</text>
  {/* Quark -> DB arrow */}
  <line x1="310" y1="206" x2="402" y2="206" stroke="currentColor" strokeWidth="1.2" opacity="0.7" />
  <polygon points="402,206 392,201.5 392,210.5" fill="currentColor" opacity="0.7" />
  {/* database cylinder */}
  <ellipse cx="470" cy="196" rx="56" ry="10" fill="none" stroke="currentColor" strokeWidth="1.1" opacity="0.8" />
  <path d="M414 196 v22 a56 10 0 0 0 112 0 v-22" fill="none" stroke="currentColor" strokeWidth="1.1" opacity="0.8" />
  <text x="470" y="214" textAnchor="middle" fill="currentColor" opacity="0.75" fontSize="12">SQL database</text>
  {/* standalone note */}
  <text x="58" y="276" fill="currentColor" opacity="0.7" fontSize="12.5">Quark also works on its own, in any Go app — no Nucleus, no Orbit.</text>
  <text x="58" y="294" fill="currentColor" opacity="0.7" fontSize="12.5">Orbit requires Nucleus. Nucleus requires neither.</text>
  {/* manifest note */}
  <text x="26" y="336" fill="currentColor" opacity="0.65" fontFamily="var(--ifm-font-family-monospace)" fontSize="12">versions.yaml — the manifest that pins the set</text>
  <line x1="26" y1="344" x2="380" y2="344" stroke="currentColor" strokeWidth="0.5" opacity="0.3" />
</svg>

The only hard dependency between products is **Orbit → Nucleus**. Quark is
independent; Nucleus has its own SQL-first data layer (`pkg/db` +
`pkg/model`), so even inside a Nucleus app, Quark is a choice, not a
requirement — [here is how to choose](choosing-a-data-layer.md).

## Where do I start?

| You want… | Start with |
|---|---|
| Just a data layer for any Go app | [Quark's getting started](/quark/guides/getting-started/) — no framework involved |
| A web application | [Nucleus's quickstart](/nucleus/getting-started/quickstart/) — add Quark and Orbit later if you want them |
| To see the whole suite working | [The suite quickstart](quickstart.md) — one small app, all three pillars, about 15 minutes |

## When *not* to use the suite

Honest boundaries save everyone time:

- **You already have a framework you like.** Quark still works for you — it
  is a standalone ORM. Nucleus and Orbit are not for you.
- **You want an admin panel for a non-Nucleus app.** Orbit only mounts on
  Nucleus. There is no standalone Orbit.
- **You need NoSQL.** Quark is relational only, and Nucleus's data layer is
  `database/sql`. Six SQL engines, zero document stores.
- **You want a big-vendor ecosystem.** These are three focused products from
  a small project. The trade-off is coherence and a small surface, not
  breadth of plugins.

Still here? [The quickstart](quickstart.md) takes about 15 minutes.
