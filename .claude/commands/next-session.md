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

## 3. Estado al cierre (2026-06-27)

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
- **Fase 2 pulido ✅**: tema de marca (PR #12), navbar contextual «Quantum · Quark»
  (swizzle de `@theme/Navbar/Logo`, PR #16), fix del 404 de Quark en navegación SPA
  (PR #13) y enlace al sitio en el About del repo + README (PR #15).
- **Fase 3 EN CURSO** (arrancada 2026-06-26):
  - **(1) CI de integración ✅** (PR #17): `.github/workflows/integration.yml` hace
    `go build`+`go vet` de los seis patrones del workspace tras checkout de
    submódulos (el plano "de integración" del ROADMAP §6; sustituye la verificación
    a mano). Verde en PR y en main.
  - **(2) Docs de Orbit ✅** (orbit#1 + PR #18): primera instancia Docusaurus de
    Orbit — 9 páginas (intro con `slug:/`, quick-start, configuration, features,
    how-it-works + cluster/{overview,proto,agent,server}) desde sus READMEs, con los
    paths de módulo corregidos a `github.com/jcsvwinston/orbit/...`. Montada como 3ª
    sección: `/quantum/orbit/` live, navbar «Quantum · Orbit», pilar clicable. El
    submódulo orbit pasó de `v0.1.0` a `de14c20` (= v0.1.0 + docs, código Go
    idéntico) → `workspace_pins.orbit` es pseudo-version como nucleus; `modules.orbit`
    sigue `v0.1.0`. Las docs de Orbit son `website/docs/` (sin sitio standalone).
  - **(3) release-please** en Nucleus/Orbit — pendiente (toca productos, requiere OK).
  - **(4) Quantum 0.1.0** certificado — pendiente: requiere que Nucleus taggee la
    línea que Orbit consume, luego limpiar los pines de nucleus+orbit a tags y
    cambiar el `status` de `versions.yaml`.
- **Fase 2 cleanup** (sesión 2026-06-27, foco elegido por Carlos):
  - **Enlaces rotos heredados ✅** (PR #20): las docs de Quark enlazan en absoluto a
    `/docs/*` (su routeBasePath standalone es `docs`); en el unificado Quark vive en
    `/quark/*`, así que caían en `/quantum/docs/*` → 80 enlaces rotos + 404 en SPA. Un
    remark plugin (`remarkQuarkDocsBase`) los reescribe a `/quark/*` en el ENSAMBLAJE
    (AST en memoria, antes de los remark por defecto): no toca la fuente (QADR-0003) y
    emite rutas reales → 80→0 y SPA OK. De paso, `onBrokenMarkdownLinks` movido a
    `markdown.hooks` (deprecation 2→0). Quedan 8 ANCLAS rotas en snapshots versionados
    CONGELADOS de Quark (`#tx`, `#raw-sql`): historia inmutable, rotas también en su
    sitio standalone; `onBrokenAnchors: 'warn'`.
  - **Búsqueda local ✅** (PR #21, apilado sobre #20): el bloqueo NO era el SSR de
    React 19 (la nota previa estaba desfasada: el plugin lo soporta desde v0.47.0; aquí
    0.55.2). Era que `@easyops-cn/docusaurus-search-local` asume una instancia de docs
    `default` y usamos `docs:false` + 3 instancias con id propio → fallaba la SSG de /,
    /search y /404. Solución: Nucleus pasa a `id: 'default'` (sin cambio de URL ni de
    navbar; el swizzle detecta por segmento de ruta). Offline, sin dependencia externa;
    el índice cubre las 3 instancias (nucleus 14 + quark 41 + orbit 8 = 63 rutas) + un
    índice por versión de Quark.
  - **Retirar los Pages de Quark/Nucleus + redirects — PENDIENTE**: plan documentado en
    `docs/RETIRE_PRODUCT_PAGES.md` (mapa de URLs + redirector index.html/404.html +
    cambio de workflow por repo). Toca repos de PRODUCTO y es outward-facing → lo
    ejecuta el responsable en sus sesiones, no en quantum.
  - **Hueco de CI anotado**: no hay check que construya `website/` en PRs (solo
    `integration.yml` Go + `deploy.yml` en main); un sitio roto se vería al desplegar.
    Posible job `npm run build` en PRs que toquen `website/`.

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
- **CI de integración ✅**: `.github/workflows/integration.yml` (Fase 3, PR #17) hace
  `go build`+`go vet` del trío en cada push/PR. `status: pre-fusion` sigue en
  `versions.yaml` hasta certificar Quantum 0.1.0 (limpiar los pines a tag).
- **Docs unificadas (Fase 2)**: `website/` (Docusaurus 3.10.1) ensambla los TRES
  productos, con doble selector de versión, **tema de marca pulido (UI/UX)**,
  **búsqueda local offline** (PR #21) y **deploy live** en
  https://jcsvwinston.github.io/quantum/. Enlaces `/docs/*` heredados de Quark
  reescritos en el ensamblaje (PR #20). Pendiente: retirar los Pages standalone de
  Quark/Nucleus + redirects (plan en `docs/RETIRE_PRODUCT_PAGES.md`; toca repos de
  producto) y el hueco de CI de website en PRs. `cd website && npm install && npm run build`.

## 6. Cómo cerrar la sesión

Actualiza el §3 de este archivo (estado al cierre) con lo que avanzaste y el
próximo foco, para no romper el contexto a la siguiente sesión. Si cambia una
decisión de coordinación, abre un QADR sucesor (no reabras uno aceptado).
