# /next-session — arranque de sesión para Quantum (paraguas)

> Comando de arranque para Claude Code en el repo **`quantum`** (el paraguas).
> Audita el estado real de la suite y ancla la sesión al foco correcto.
> No es el `/next-session` de Quark ni el `/resume` de Nucleus: aquí coordinas
> la suite, no tocas el código de los productos.

## 0. Qué es Quantum (recordatorio de una frase)

Suite de tres productos Go que se desarrollan por separado y se coordinan bajo un
paraguas: **Nucleus** (framework web, el host), **Quark** (ORM, usable en solitario)
y **Orbit** (admin que monta in-process en Nucleus). El repo `quantum`
**coordina, no contiene**: fija el trío compatible (`versions.yaml`) y da un
`go.work`. Detalle en [`README.md`](../../README.md) y [`docs/ROADMAP.md`](../../docs/ROADMAP.md).

## 1. Protocolo de arranque (hazlo SIEMPRE antes de tocar nada)

1. **Lee** [`docs/ROADMAP.md`](../../docs/ROADMAP.md) (las fases) y
   [`versions.yaml`](../../versions.yaml) (el trío declarado).
2. **Audita el estado real** con bash:
   - `git submodule status` — ¿siguen los submódulos en el trío de `versions.yaml`?
   - `git -C quark describe --tags`, idem `nucleus`, `orbit` — ¿coinciden con `workspace_pins`?
   - `go build ./quark/... ./nucleus/... ./orbit/... ./orbit/agent/... ./orbit/proto/... ./orbit/server/...`
     (el root del workspace no es un módulo; patrones explícitos).
3. **Reconcilia** con el §3 de abajo (estado al cierre): ¿qué fase toca?
4. **Propón el foco** de la sesión (una fase concreta del roadmap) antes de trabajar,
   y deja que el responsable lo confirme.

## 2. Reglas duras que NO se rompen (mismas que el brief de Fase 0 y los QADR)

1. **Cada producto en su repo; `quantum` solo coordina** (no contiene código). [QADR-0001]
2. **Versionado en dos niveles**: el número Quantum nunca falsea el `vX.Y.Z` real
   que la gente instala. [QADR-0002]
3. **Docs**: la fuente vive en cada repo; el sitio unificado *ensambla*, no posee. [QADR-0003]
4. **Anti-hype**: sin superlativos de marketing —afirmaciones exageradas de
   madurez o de rendimiento— en commits, README, ADRs ni roadmap. La cultura
   anti-hype se hereda de Quark; el grep de esos términos debe seguir vacío (por
   eso este propio fichero no los nombra en literal).
5. **`go.work` es solo dev local**; sin `replace` en los `go.mod` de los productos.
6. **Quark sigue usable en solitario**; nada lo obliga a depender de Nucleus/Orbit.
7. **Conventional Commits**; trabaja en rama y abre PR (no commitees directo a `main`).

## 3. Estado al cierre (2026-06-24)

- **Fase 0 ✅ COMPLETA y mergeada** (PR #1): repo paraguas con `versions.yaml`,
  `go.work`, `README`, `LICENSE`, `QADR-0001..0004` y los tres productos como
  submódulos pinneados al trío — `quark v1.1.5`, `orbit v0.1.0`, y `nucleus` al
  commit `8714882c` (post-`v0.9.0`, el que exige Orbit v0.1.0; ver `workspace_pins`).
- **Fase 1 ✅ COMPLETA**: identidad textual (tagline + narrativa en `README`) y
  visual — marca **"el estado fijado"** (niveles de energía / estética de
  osciloscopio; verde señal + mono). Assets en `docs/brand/`: brand board HTML,
  `quantum-mark.svg` (logo/favicon) y guía de marca; el logo va en la portada.
  Lo que queda es opcional y propio de Fase 2: derivar favicon real a tamaños y
  llevar la paleta/tipografía al sitio como tokens.
- **Trabajo colateral hecho** (en el repo de Nucleus, no aquí): doc-sync de la
  extracción del admin a Orbit (Nucleus ADR-019) — PRs nucleus #164–#167 mergeados
  (README, scaffold, SPEC, guías). Esto NO cambió APIs.
- **Fase 2 EN CURSO**: sitio Docusaurus unificado en `website/` (3.10.1, baseUrl
  `/quantum/`). Hecho (pasos 1-2): esqueleto + dos instancias `plugin-content-docs`
  que **ensamblan** las docs de Nucleus (`../nucleus/website/docs`) y Quark
  (`../quark/website/docs`) — `npm run build` OK, sirve `/quantum/nucleus/` (20
  págs) y `/quantum/quark/` (41 págs); product switcher + paleta de marca aplicados.
  `node_modules/build/.docusaurus` gitignored.
- **Fase 2 paso 5 (deploy) ✅ LIVE**: el sitio está publicado en
  https://jcsvwinston.github.io/quantum/ (`.github/workflows/deploy.yml`, Pages vía
  Actions, checkout con submódulos). `/quantum/` y `/quantum/nucleus/` → 200.
  `/quantum/quark/` (raíz) redirige a `/quantum/quark/intro` vía
  `@docusaurus/plugin-client-redirects` (el intro de Quark no declara `slug: /`,
  el de Nucleus sí; no se toca la fuente, QADR-0003). **Matiz (PR #13):** ese
  redirect es un fichero ESTÁTICO (meta-refresh), no una ruta del router —cubre el
  acceso directo a `/quark/` pero un `<Link to="/quark/">` navega por SPA y cae en
  el 404. Por eso TODOS los enlaces internos a Quark (portada, footer, dropdown)
  van directos a `/quark/intro/`; nunca a la raíz pelada. Aprendido también: el
  PRIMER workflow de un repo no se registra al añadirlo — hizo falta un segundo
  push (PR #9) para que GitHub lo activara.
- **Fase 2 paso 3 (doble selector) ✅**: navbar con selector «Quantum 0.1.0-dev»
  (de `versions.yaml`) + los tres pilares con su tag real, y selector de versión de
  Quark (Next + 13 versiones; el histórico se sincroniza en build desde su submódulo
  vía `website/sync-versions.mjs`, gitignored). Nucleus aún sin versionar (Fase 3).
- **SIGUIENTE → cerrar Fase 2**: (4) instancia de Orbit (bloqueada por Fase 3 =
  escribir sus docs); retirar los Pages actuales de Quark/Nucleus + redirects desde
  ellos; pulir anclas/enlaces rotos heredados de las docs (son warnings, no bloquean).

## 4. Las fases (resumen; el detalle y el "hecho cuando" están en docs/ROADMAP.md)

| Fase | Objetivo | Hecho cuando |
|---|---|---|
| 1 | **Identidad/marca Quantum**, portada de la suite | Front page que nombra y enlaza los tres pilares y aclara el uso standalone de Quark |
| 2 | **Docs unificadas**: Docusaurus multi-instancia en `website/`, product switcher, doble selector de versión, un solo deploy en `/quantum/` | Un sitio sirve las tres docs bajo una marca, sin sacar la fuente de cada repo |
| 3 | **Convenciones + primera release**: `release-please` a Nucleus/Orbit, instancia de docs de Orbit, **Quantum 0.1.0** con CI de integración | Set Quantum reproducible y verificado por CI |
| 4 | **Integración demostrada**: ejemplo Nucleus+Quark+Orbit + CI que ejerce los tres | Hay un ejemplo ejecutable y CI del set |
| 5 | **Convergencia Quantum 1.0**: Nucleus y Orbit a v1.0, régimen de majors en lockstep | Los tres en major 1 bajo un manifiesto Quantum 1.0 |

## 5. Pendientes técnicos anotados (revísalos cuando apliquen)

- **Pin de Nucleus**: hoy `workspace_pins.nucleus = 8714882c` (pre-release de v0.9.1)
  porque Orbit v0.1.0 lo exige. Cuando Nucleus **tague la línea que Orbit consume**
  (será v0.10.0 — la extracción del admin ya está en su `main`), actualiza
  `workspace_pins.nucleus` a ese tag y revisa si `modules.nucleus` sube. [QADR-0004]
- **CI de integración**: aún no existe (llega en Fase 3); hoy el trío se verifica a
  mano con el `go build` de §1. `status: pre-fusion` en `versions.yaml` lo refleja.
- **Docs unificadas (Fase 2)**: `website/` (Docusaurus 3.10.1) ensambla Nucleus+Quark,
  con doble selector de versión, **tema de marca pulido (UI/UX)** y **deploy live** en
  https://jcsvwinston.github.io/quantum/. Pendiente: **búsqueda** (el plugin
  `@easyops-cn/docusaurus-search-local` rompe el SSR con React 19 — reevaluar o usar
  Algolia DocSearch), instancia de Orbit (Fase 3), retirar los Pages de los productos
  + redirects. `cd website && npm install && npm run build`.

## 6. Cómo cerrar la sesión

Actualiza el §3 de este archivo (estado al cierre) con lo que avanzaste y el
próximo foco, para no romper el contexto a la siguiente sesión. Si cambia una
decisión de coordinación, abre un QADR sucesor (no reabras uno aceptado).
