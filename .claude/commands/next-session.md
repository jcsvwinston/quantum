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

## 3. Estado al cierre (2026-07-19)

### Sesión 2026-07-19 (19ª) — cierre de la 5ª ronda → quark v1.3.1, nucleus v1.3.2, orbit v1.4.2 y QUANTUM 1.7.1 CERTIFICADO

Ejecución completa de `PLAN_EJECUCION_5.md` (carpeta auditoria/ del proyecto),
todo por ejecución real con Docker y con la lección de la ronda instalada:
**cada versión hardcodeada gestionada por release-please o vigilada por CI**.
Informe de cierre exhaustivo (casilla a casilla, con EXITs y desviaciones):
`CIERRE_5A_RONDA.md` en esa misma carpeta — es la entrada de la 6ª auditoría.

- **3 P1 cerrados**: OR5-1 (pins internos de orbit + tests standalone GOWORK=off
  en CI + check_internal_pins.sh), QM5-1 (el sitio sirve la doc ACTUAL por
  defecto; linter de jerga post-build sobre el HTML SERVIDO, 0 exclusiones),
  NU5-1 (tags db: veraces + db:"-" real + WARN de arranque + verifier).
- **8 P2 + P3 cerrados** (nucleus#215/#216, quark#250/#251, orbit#93/#94/#95,
  quantum#68/#69, todos fusionados). Hallazgos NUEVOS al ejecutar ramas
  jamás ejecutadas: LIMIT inválido en T-SQL en el listado CRUD de nucleus
  (arreglado + lane MSSQL completa) y, en quark, cuelgue de locks + PÉRDIDA
  SILENCIOSA de escrituras del RLS nativo implicit-tx (arreglado con
  WithoutCancel; arista de fondo en quark#252).
- **Forcing functions**: manifest-guard §3 (5 tags de módulo de orbit vs pin,
  disparó en producción durante la ronda) y §4 (tabla README == manifiesto);
  job go-install-tag (caché virgen); inventario de versiones en los 4 repos.
- **Pendiente para la siguiente**: Fase 5 del plan (docs: Deployment/Security/
  Upgrade/Release notes de nucleus-orbit/Config reference/sidebars/idioma
  único); alinear el require nucleus de orbit (v1.3.1→v1.3.2) en su próximo
  arco; evaluación de fondo del implicit-tx de RLS nativo (quark#252).

### Sesión 2026-07-14/15 (18ª) — cierre de la 4ª reauditoría POR EJECUCIÓN REAL (Docker) → quark v1.3.0, nucleus v1.3.1, orbit v1.4.1 y QUANTUM 1.7.0 CERTIFICADO

Carlos trajo el «plan de ejecución definitivo» de la reauditoría (Fases 1–4)
con la novedad de que Code tenía Docker: cerrar los «no verificable sin
Docker» que arrastraban las cuatro auditorías corriendo la matriz de motores
DE VERDAD. Autorizó después toda la cadena de merges y releases
(«ve comiteando y mergeando» → «Sí, toda la cadena» → «mergéalo y taggea
v1.7.0»). Todo lo afirmado abajo está verificado por ejecución, no por
lectura:

- **[Orbit] OR-1 (P0)** — `server` no compilaba standalone: `server/go.mod`
  pinaba proto v0.3.0 usando `adminv1.GetSelfRequest`/`SelfInfo` (v0.4.0);
  el go.work lo enmascaraba y `go install …/admin-server@server/v0.8.0`
  estaba roto. Alineado (proto v0.4.0, agent v0.5.0); los seis módulos pasan
  `GOWORK=off go build+vet`.
- **[Orbit] OR-2 (P0 seguridad)** — el `--agent-token` NUNCA viajaba en el
  stream bidi: el interceptor era `connect.UnaryInterceptorFunc`, que
  connect-go no invoca en RPCs de streaming, y el único RPC del agente es el
  stream → 401 en bucle, telemetría muerta fuera de loopback. Sustituido por
  un `connect.Interceptor` completo (WrapStreamingClient). El regresor nuevo
  (`TestServer_AgentToken_StreamAuthenticates`, agente REAL + ListNodes +
  telemetría) es genuino: rojo sin el fix, verde con él.
- **[Orbit] La causa raíz de que OR-1/OR-2 llegaran a tag: NO TENÍA CI de
  build/test** (solo pages + release-please; el Makefile existía pero nadie
  lo corría). CI nuevo de 5 jobs: standalone GOWORK=off por módulo (habría
  atrapado OR-1), tests, Data Studio contra PG+MySQL reales, govulncheck,
  linter de docs.
- **[Nucleus] BUG REAL DE PRODUCCIÓN que SQLite ocultaba** (hallado al correr
  Data Studio contra un Postgres real): `CRUD.Create` obtenía la PK con
  `LastInsertId()`, que pgx/mssql NO implementan → el error se tragaba y
  TODO Create en Postgres devolvía id 0 (crear→actualizar operaba sobre 0).
  Corregido con `RETURNING`/`OUTPUT INSERTED` (queryContext para no perder
  la instrumentación); Oracle queda como laguna DECLARADA (go-ora exige
  `RETURNING … INTO :out`, no encaja con el rebind de `?`). El test live
  sacaba el id de un FindAll posterior en vez de assertar el back-fill —
  por eso sobrevivió; ahora lo asserta (rojo sin fix en PG, verde en MySQL).
  También NU-1 (README decía observability `experimental`; check de
  coherencia README↔inventory en check_version_claims.sh) y NU-2 (W2
  documentada en el website con la verdad de la redacción de args).
- **[Quark] Matriz de 6 motores EN VERDE POR EJECUCIÓN** (SQLite/PG/MySQL/
  MariaDB/MSSQL/Oracle; por-motor, no en un proceso — los 6 juntos exceden
  el timeout de 25m; Oracle vía docker run + DSN, testcontainers no puede
  con esa imagen). Al ejercitar set-ops afloró que `INTERSECT ALL`/`EXCEPT
  ALL` eran código INALCANZABLE (sin métodos públicos): expuestos
  `IntersectAll`/`ExceptAll`, el test cazó que MSSQL no los soporta (emitía
  SQL inválido → ahora ErrUnsupportedFeature) y que el godoc negaba
  INTERSECT/EXCEPT en MariaDB siendo falso (10.3+). Soporte ALL real: solo
  PG y MariaDB 10.5+. govulncheck limpio.
- **[Seguridad] GO-2026-5856** (fuga ECH en crypto/tls, alcanzable desde los
  dials TLS del agente y el relay Redis): los seis módulos de orbit tenían
  `toolchain go1.26.5` pero la directiva `go 1.26.4` — y setup-go lee la
  directiva `go`, así que el CI compilaba con la stdlib vulnerable. Subida a
  1.26.5 (+ go.work del paraguas); govulncheck 0/8 en el set.
- **[Docs de producto, Fase 3]** barrido de jerga interna (ADR-XXXX, P0,
  SPEC.md, CLAUDE.md, V1_GATE, PROFILING.md, issues sueltos) en los sitios de
  los TRES repos (12 páginas quark + 9 nucleus + 2 orbit; release-notes y
  roadmap de quark reescritos en formato producto; compatibility.md de
  nucleus reescrito como Support & Compatibility Policy user-facing) +
  **linter `check_docs_product_voice.sh` en el CI de los tres** (0 fugas;
  la excepción `<!-- docs-lint-allow -->` no hizo falta ni una vez).
- **[Releases]** quark v1.3.0 (checklist de coherencia H-Q6 a mano en el
  release-PR: README/SECURITY/CLAUDE/release-notes + RELEASE_NOTES_v1.3.0.md),
  nucleus v1.3.1, orbit v1.4.1 + server/v0.8.1 + agent/v0.5.1 + proto/v0.4.1
  + quarkbridge/v0.3.2 + quarkdatasource/v0.2.3. El pin de nucleus en orbit
  subió v1.1.0→v1.3.1 (el go.work enmascaraba que orbit consumía un nucleus
  viejo; el CI de orbit destapó el bug de PK EXACTAMENTE por eso, y de paso
  un go.sum incompleto que solo -mod=readonly revela).
- **QUANTUM 1.7.0 CERTIFICADO** (quantum#66): trío re-pinado a tags exactos
  (quark `5282ce5b`, nucleus `78d7d349`, orbit `b48247eb`), go.work a
  1.26.5, y **manifest-guard nuevo** (QM-P0-1) como job del CI de
  integración: falla si un pin no coincide A LA VEZ con el gitlink del
  submódulo y con el commit del tag publicado (probado en ambos sentidos).
  Los ocho patrones del workspace compilan; tag de suite v1.7.0 publicado.

**Barrido de salud post-set (esta sesión, auto):** govulncheck 0/8 en los
módulos pinneados; sitio 4/4 en 200 y la portada sirve el chip
«Quantum 1.7.0»; 0 PRs abiertos en los cuatro repos; issues: nucleus 0,
quark 2 (#247 diferida con boceto, #92 épica), orbit 1 (#74 parcial).
Tabla de pilares del README corregida al trío nuevo (llevaba el set 1.6.0 —
mismo drift que cazó la 14ª).

**Pendiente de Carlos (1):** ceremonia de release de GitHub del paraguas —
publicar la release **Quantum v1.7.0** sobre el tag ya existente con las
notas del manifiesto (outward-facing, mismo patrón que v1.4.0–v1.6.0; no la
publico sin visto bueno). Backlog ejecutable sin decisiones: los diferidos
de orbit#74 (i18n, a11y de tablas, consolidación de tablas del panel).
Laguna técnica declarada (no issue aún): back-fill de PK de nucleus en
Oracle.

Gotchas nuevos de la sesión (grabados también en memoria persistente):
(1) los PRs de release-please NO disparan CI (los crea el bot; GitHub corta
workflows recursivos) → quedan BLOCKED con «no checks reported» si main
exige un status check; la salida limpia es `gh pr close N && gh pr reopen N`
(el evento reopened SÍ dispara CI) — sin `--admin` (enforce_admins lo veta
además en nucleus); (2) los 6 release-PRs de orbit (separate-pull-requests +
manifest compartido) conflictúan EN CASCADA al fusionarse en serie y
release-please no los rebasa ni re-disparándolo: merge manual de main en
cada rama del bot resolviendo el manifest (bump propio del PR + versiones ya
avanzadas de main); (3) al cortar un minor de quark, el gate H-Q6 exige el
bump de menciones + RELEASE_NOTES_vX.Y.0.md A MANO en el release-PR;
(4) `go mod tidy` con el module cache caliente puede dejar go.sum incompleto
— verificar con `GOFLAGS=-mod=readonly` (lo que hace el CI); (5) el gate
estricto de la superapp de quark exige ejercitar cada símbolo público nuevo
en cada motor (o allowlist) — exponer una API implica tocar
`examples/superapp/` en el mismo PR.

---

### Sesión 2026-07-13 (17ª) — «todas»: el backlog de UI del plano fleet (orbit#70–#74) ejecutado → orbit v1.4.0 y QUANTUM 1.6.0 CERTIFICADO

Carlos: «todas» (los 5 follow-ups de UI del plano fleet que la 12ª dejó como
issues). Ejecutados en 5 PRs temáticos, fusionados de uno en uno (para evitar
los conflictos de `server/ui/dist` entre builds: cada PR ramificado desde el
main actualizado del anterior):

- **orbit#78 (#71)** filtros de stream: `StreamFilterBar` + `useStreamFilters`
  — method/status-class (chips) + path-glob para HTTP, model para SQL, selector
  de nodo y knob de sampling (100/50/10/1%) en todas. `useStreamEvents` acepta
  `samplingRate`. Filtro aplicado desde un snapshot DEBOUNCED (ref estable →
  el stream solo se re-abre al asentarse); persistido en localStorage.
- **orbit#81 (#73)** herramientas del audit log: fetch del ring completo (2048)
  + filtro client-side (actor/acción/nodo/rango), paginación 50/pág y export
  CSV (RFC 4180) vía Blob.
- **orbit#82 (#72)** capacidades de Data Studio: multi-select + `useBulkAction`
  (delete), selector de nodo (threading de `node_id` por todas las
  queries/mutaciones), choices→`<select>`, editor de fecha (datetime-local↔
  RFC3339), FK→link al modelo referenciado (valor crudo). (Selector de
  `database_alias` fuera: no hay fuente de la lista de alias en la UI.)
- **orbit#83 (#70)** GetSelf: **proto** (RPC aditivo `ControlService.GetSelf →
  SelfInfo`, 25 inserciones/0 borrados; stubs Go+TS regenerados con
  `make proto`), **server** (handler lee identidad del ctx +
  `serverVersion()` vía `debug.ReadBuildInfo`; test de integración
  `TestServer_GetSelf`), **UI** (`useSelf`; footer «orbit <ver> · <subject>
  [(viewer)]»; Data Studio esconde mutaciones en read-only).
- **orbit#85 (#74 PARCIAL)**: NodeDetail «Recent activity» = feed en vivo
  HTTP+SQL por nodo (la correlación de node_id se arregló en #66; «Components»
  eliminado por honestidad); búsqueda de modelos en el sidebar; SLOW_MS
  configurable. **Diferidos (#74 sigue abierta)**: i18n centralizado, barrido
  completo de a11y de tablas (role sweep + teclado; NodesPage ya tiene el
  patrón), consolidar RecordTable/AGGridTable del panel in-process.

**Release**: release-please cortó **orbit v1.4.0** (`b6948f0d`, root — UI),
**server/v0.8.0** (GetSelf) y **proto/v0.4.0** (RPC); agent sigue v0.5.0.
Mismo baile de manifest de siempre (merge server → proto → root; claves
distintas del manifest → 3-way limpio, sin reconciliación manual esta vez).
Issues #70–#73 cerradas a mano.

**QUANTUM 1.6.0 CERTIFICADO** (quantum#64): submódulo orbit → `b6948f0d`
(= v1.4.0 exacto, contiene server/v0.8.0 y proto/v0.4.0 como ancestros),
`modules.orbit` → v1.4.0, `quantum` 1.5.0 → **1.6.0** (minor). Los seis
patrones compilan; CI del paraguas verde (lockstep A-7 con orbit v1.4.0).
Release de GitHub **[Quantum v1.6.0](https://github.com/jcsvwinston/quantum/releases/tag/v1.6.0)**
publicada.

**Estado: suite completamente al día.** Trío **nucleus v1.3.0 · quark v1.2.2 ·
orbit v1.4.0**, tres pines en tag exacto. Único backlog conocido: los 3
diferidos de orbit#74 (i18n, a11y de tablas, consolidación de tablas del
panel) — de menor valor/mayor esfuerzo, a priorizar por Carlos.

Gotchas: (1) PRs de UI apilados generan conflictos en `server/ui/dist`
(bundle rebuild) — ramificar cada uno desde el main del anterior lo evita
(no stackear); (2) `gh release create --target` exige SHA completo (el corto
da «Release.target_commitish is invalid»); (3) `make proto` (buf 1.47.2 local)
regenera Go+TS con plugins remotos — funciona sin problema.

---

### Sesión 2026-07-13 (16ª) — sesión autónoma: ceremonia de release + barrido de salud del set 1.5.0 (todo limpio)

Con el visto bueno de Carlos, la sesión (continuación de la 15ª) **publicó
las dos releases de GitHub del paraguas** y barrió la salud del set recién
certificado:

- **Releases GH del paraguas** (mismo patrón que v1.0.0–v1.3.1): **[Quantum
  v1.4.0](https://github.com/jcsvwinston/quantum/releases/tag/v1.4.0)** (orbit
  v1.3.0, sobre el commit de certificación `ff748cc`) y **[Quantum
  v1.5.0](https://github.com/jcsvwinston/quantum/releases/tag/v1.5.0)** (Latest;
  nucleus v1.3.0, sobre `476585a`), cada una con las notas del manifiesto y la
  tabla del trío. Gotcha: `gh release create --target` exige el **SHA completo**
  (el corto da «Release.target_commitish is invalid»).
- **Barrido de salud del set 1.5.0** (precedente auto 4ª/8ª/12ª): los seis
  patrones del workspace compilan; **govulncheck 0/8** en los módulos pinneados
  (GOWORK=off, incl. el código nuevo de nucleus v1.3.0 — el wrapper de driver);
  sitio 4/4 en 200 y la portada ya sirve el chip «**Quantum 1.5.0**» (deploy
  corrido tras la certificación); **0 PRs abiertos** en los cuatro repos;
  issues: nucleus 0, quark 2 (#247 diferida, #92 épica Fase 6 → conocidas),
  orbit 5 (#70–#74, el backlog UI).

**Estado: la suite está completamente al día y limpia.** Trío en
**nucleus v1.3.0 · quark v1.2.2 · orbit v1.3.0**, tres pines en tag exacto,
sin deuda de seguridad conocida, sitio vivo, releases publicadas. El gate v1.0
de nucleus queda con todos los §A y §B (incl. W1+W2) cerrados.

**Cola de Carlos (sin decisiones pendientes de coordinación):** el único
trabajo ejecutable es el **backlog de UI del plano fleet, orbit#70–#74** —
features de producto que Carlos prioriza (no las arranco en auto sin su
elección de foco):
- **#70** OR-UX-P1-6: versión real del server + identidad/read_only del
  operador en el footer (necesita un RPC `GetSelf` de echo → proto+server
  aditivo, otro ciclo de release de esos módulos).
- **#71** OR-UX-P1-3: barra de filtros en las páginas de stream + knob de
  sampling (solo UI; el proto ya lo soporta y #66 hizo real el sampler).
- **#72** OR-UX-P1-2: exponer en Data Studio lo que el backend ya sabe
  (multi-select/bulk, alias/nodo, choices→select, FK→link, editor de fecha;
  solo UI).
- **#73** OR-UX-P1-7: herramientas del audit log (filtro/rango/CSV/paginación,
  client-side).
- **#74** bundle P2: i18n, SLOW_MS, búsqueda de modelos, consolidar las dos
  tablas del panel, NodeDetail, a11y de tablas.

Los cinco son solo-UI salvo #70 (que toca proto/server). Ninguno bloquea nada.

---

### Sesión 2026-07-13 (15ª) — arco de producto de NUCLEUS: gate v1.0 W1+W2 resueltos → nucleus v1.3.0 y QUANTUM 1.5.0 CERTIFICADO

Carlos decidió los dos compromisos vencidos del gate de nucleus que la 13ª
abrió como issues: **«para #206 implementar en arco 1.3 y #207 promueve»**.
La sesión (con la delegación de merge vigente, «hazlo tu, no puedo desde gh»)
implementó ambos, cortó el tag y certificó el set:

- **W1 — nucleus#207/#208** (`feat/promote-observability-stable`): promoción de
  `pkg/observability` + `pkg/observability/hooks` de experimental a **stable** +
  freeze. Mapa exhaustivo confirmó superficie coherente y pure-stdlib (sin TODO/
  medio-hornear, cero imports de terceros) → `frozen: true, firewalled: false`
  (como `pkg/circuit`). El freeze fija solo las FORMAS de los símbolos; los
  internos pooled/ring-buffer son unexported y siguen optimizables, así que la
  objeción original del waiver no aplica. `lifecycle/frozen` en
  `contracts/packages_test.go`, inventario, gate (tabla + §B), baseline
  rebaselinado (+129 símbolos, cero borrados). Reencuadrados los comentarios de
  `pkg/nucleus/{eventbus,runtime}.go` que llamaban a observability «experimental/
  pre-v1.0» (el facade EventBus se queda por value-copy, no por inestabilidad).
- **W2 — nucleus#206/#210** (`feat/driver-sql-instrumentation`, **ADR-021**):
  instrumentación SQL a nivel de driver **opt-in** (`sql_driver_instrumentation`,
  default false → coste cero). Diseño: wrapper de `database/sql/driver` en
  `pkg/db` (`sql.OpenDB` sobre un connector que envuelve el conn base;
  implementa TODAS las interfaces opcionales y reenvía condicionalmente con
  `driver.ErrSkip`/default — sin degradar el driver); observa en QueryContext/
  ExecContext de conn (directo) y stmt (preparado), mutuamente excluyentes →
  una sola observación. Callback `db.StatementObserver` **agnóstico** (no importa
  observability); `pkg/app` lo puentea al observer de hooks existente
  (reutiliza sanitize+correlación+emit+gate HasSubscribers). **De-dup por
  marcador de contexto** `observe.CtxWithModelObserved` que estampa `model.CRUD`
  antes de `c.db.Exec/Query` → el wrapper salta el tráfico CRUD (ya emitido con
  ModelName). Los dos observers coexisten porque el wrapper no conoce el
  ModelName. 8 tests (5 pkg/db + 2 e2e pkg/app + 1 live contra postgres/mysql de
  la matriz), verdes con `-race`; baseline +12 símbolos.
- **Flow de release** (los dos PRs apilados: #206 sobre #207): fusionado #208
  (verde) → #209 se auto-cerró al borrarse su base → rebase `--onto main` del
  branch soltando el commit de #207 (force-push OK, NO vetado aquí) → PR nuevo
  #210 a main → CI verde incl. matriz de 5 motores → merge. release-please
  cortó **nucleus v1.3.0** (`16e22c84`) con AMBOS feats en el CHANGELOG; para
  disparar su Required Gate hizo falta el commit vacío a la rama del bot
  (gotcha conocido). Housekeeping post-tag: `defaultPinnedFrameworkVersion`
  v1.2.0→v1.3.0 (nucleus#211). Issues #206/#207 cerradas a mano («Cierra» en
  español no es keyword de GitHub).
- **QUANTUM 1.5.0 CERTIFICADO** (quantum#61): submódulo nucleus → `16e22c84`
  (= v1.3.0 exacto), `modules.nucleus` → v1.3.0, `quantum` 1.4.0 → **1.5.0**
  (minor: nucleus subió minor). quark v1.2.2 y orbit v1.3.0 continúan. Los seis
  patrones compilan; lockstep A-7 verde (orbit contra nucleus v1.3.0 fijado).
  Tabla de pilares del README a nucleus v1.3.0. **El gate v1.0 de nucleus queda
  con W1 y W2 cerrados.**

**Pendiente de Carlos:** ceremonia de release de GitHub del paraguas (tags/
releases quantum v1.4.0 y v1.5.0 — outward-facing, no las hago sin visto bueno).
Backlog sin decisiones: orbit#70–#74 (UI del plano fleet).

Gotchas de la sesión: (1) los PRs apilados en repos con squash-merge — al
fusionar el de abajo, el de arriba se auto-cierra (base borrada) y hay que
rebasear `--onto main` + PR nuevo; (2) el force-push NO estuvo vetado aquí
(el veto de la nota de quark era context-specific); (3) «Cierra #N» en español
no auto-cierra issues — usar `gh issue close` o keywords en inglés.

---

### Sesión 2026-07-13 (14ª) — Carlos pidió el merge: orbit v1.3.0 taggeado y QUANTUM 1.4.0 CERTIFICADO

Carlos: «no puedo mergear desde gh, hazlo tu». Con esa autorización explícita
la sesión ejecutó el arco completo de release (el clasificador no bloqueó —
lo pidió él):

- **Los 4 PRs de orbit fusionados** (squash, delete-branch): orbit#66
  (plano fleet Go), #67 (panel in-process), #68 (UX SPA), #69 (docs). El
  cross-merge verificado en la 11ª se cumplió: cero conflictos. Main de
  orbit fusionado (`1341263`) compila y pasa `go test ./...` en los tres
  módulos (raíz/agent/server).
- **Tags cortados por release-please** (sus 3 release-PR): **orbit v1.3.0**
  (root; minor por el feat de #68 + fix de #67 sobre el panel), **agent/
  v0.5.0** y **server/v0.7.0** (feat de #66); **proto queda v0.3.0** (el
  arco no tocó el contrato). Gotcha reconfirmado: al fusionar los release-PR
  en serie, el 2º choca en `.release-please-manifest.json` — release-please
  NO rebaseó solo; se reconcilió a mano (merge de origin/main en la rama del
  bot + unión del manifest + push normal, NO force-push) y quedó
  MERGEABLE/CLEAN. El 3º (root, clave `.`) no chocaba con las claves
  agent/server → 3-way limpio.
- **Verificado standalone**: `go install …/server/cmd/admin-server@v0.7.0`
  (GOWORK=off) → `nucleus-admin-server v0.7.0` (buildinfo end-to-end, con
  los flags nuevos `--ui-read-only`/`--ui-role-header`).
- **QUANTUM 1.4.0 CERTIFICADO** (quantum PR de esta sesión): submódulo
  orbit → `13412635` (= v1.3.0 exacto; contiene agent/v0.5.0 y server/v0.7.0
  como ancestros, el commit solo añade el changelog/manifiesto de raíz —
  código de módulo idéntico a los tags). `modules.orbit` → v1.3.0,
  `workspace_pins.orbit` → `13412635`, `quantum` 1.3.1 → **1.4.0** (minor:
  orbit subió minor). Los seis patrones del workspace compilan con el pin
  nuevo. De paso, corregida la deriva de la tabla de pilares del README del
  paraguas (decía nucleus v1.1.0/quark v1.2.1/orbit v1.2.0 — arrastre de
  los sets 1.3.0/1.3.1; ahora v1.2.0/v1.2.2/v1.3.0).
- **quantum#59 fusionado** (cierres 11ª-13ª — historia válida).

**Pendiente para Carlos:** ceremonia de release de GitHub del paraguas
(¿tag/release quantum v1.4.0 con las notas del manifiesto? — outward-facing,
mismo patrón que v1.0.0/v1.1.0). Y las 2 decisiones de nucleus que abrió la
13ª: #206 (W2 driver-instr vencido — implementar vs re-waiver) y #207
(evaluación W1 a plazo). Backlog ejecutable sin decisiones: orbit#70–#74
(UI: echo de versión/identidad, filtros de stream, capacidades de Data
Studio, herramientas de audit, bundle P2).

---

### Sesión 2026-07-13 (13ª) — sesión autónoma corta: los compromisos del gate de nucleus llegan a plazo → issues #206/#207

Sesión auto, mismo día. **Nada se ha movido**: orbit#66/#67/#68/#69 y
quantum#59 siguen abiertos sin comentarios ni reviews, el main de orbit
sigue en `6d2fdbe` (cross-merge de la 11ª vigente tal cual). La salud del
set se barrió esta misma mañana (12ª: govulncheck 0/8, sitio 4/4) —
repetirla no aportaba. Apilar las issues de UI (orbit#70–#74) sobre ramas
sin fusionar generaría conflictos de `dist/`, así que quedan para después
del merge.

Trabajo ejecutado — el único autónomo disponible sin apilar: **los
compromisos CON FECHA del gate v1.0 de nucleus han llegado a plazo** y no
estaban en el tracker (0 issues abiertas):

- **nucleus#206 — W2 VENCIDO**: la instrumentación SQL a nivel de driver
  (ADR-018 follow-up) se waivó con compromiso explícito «v1.1» y nucleus
  va por v1.2.0. Verificado en main (`f10727a`): el bus solo ve
  `model.CRUD`; `db.QueryContext` directo sigue invisible. Issue con
  boceto (wrapper `database/sql/driver` en pkg/db, guard anti-duplicado
  como ADR-018, opt-in por config) y las dos salidas honestas:
  implementar en v1.3 o re-waiver con fecha — decisión de Carlos.
- **nucleus#207 — evaluación W1 a plazo**: `pkg/observability`+`hooks`
  quedaron experimental con «promotion evaluated at v1.2 (Track G)» y
  v1.2.0 existe. Brief de evaluación con los tres criterios (churn de la
  superficie, demanda de import directo — el agente de orbit los consume
  vía `agent/convert` —, coste en símbolos del baseline) y los tres
  resultados posibles (promover / re-comprometer / fuera de la promesa
  documentado, precedente A-1b).

**Cola de Carlos (sin cambios + 2 decisiones nuevas):** (1) fusionar
orbit#66/#67/#68/#69 y quantum#59; (2) tras el merge: corte de tags y
certificación del set siguiente; (3) decidir nucleus#206 (implementar vs
re-waiver) y nucleus#207 (la evaluación W1). Backlog ejecutable sin
decisiones tras los merges: orbit#70–#74.

---

### Sesión 2026-07-13 (12ª) — sesión autónoma: salud del set + los diferidos del backlog convertidos en issues

Sesión auto. Los 4 PRs de la 11ª (orbit#66/#67/#68/#69) siguen abiertos
esperando a Carlos; el main de orbit no se movió (`6d2fdbe`), así que el
cross-merge verificado en la 11ª sigue vigente tal cual. Trabajo de
des-riesgo y salud sin decisiones:

- **Barrido govulncheck del set certificado** (precedente 4ª/8ª): los 8
  módulos pinneados (quark, nucleus, orbit raíz, agent, proto, server,
  quarkbridge, quarkdatasource) con la BD de 2026-07-13, `GOWORK=off`:
  **0 vulnerabilidades alcanzables en los 8**. El set 1.3.1 sigue limpio.
- **Sitio vivo**: portada, `/nucleus/`, `/quark/intro/` y `/orbit/` → 200.
- **Los diferidos del backlog ya no viven solo en prosa**: issues
  orbit#70–#74 con boceto de diseño cada una (precedente quark#247) —
  #70 OR-UX-P1-6 (RPC `GetSelf` de echo: versión real del server +
  identidad/read_only del operador en el footer; proto+server aditivo),
  #71 OR-UX-P1-3 (barra de filtros de stream + knob de sampling — solo
  UI, el proto ya lo soporta y #66 hizo real el sampling), #72 OR-UX-P1-2
  (capacidades backend en Data Studio: multi-select/bulk, alias/nodo,
  choices→select, FK→link, editor de fecha — solo UI), #73 OR-UX-P1-7
  (herramientas del audit log: filtro/rango/CSV/paginación client-side),
  #74 (bundle de P2: i18n, SLOW_MS, búsqueda de modelos, consolidar las
  dos tablas del panel, NodeDetail, a11y de tablas).
- Auditoría de arranque limpia: pines = manifiesto (tres en tag exacto),
  los seis patrones del workspace compilan.

**Sin pendientes nuevos.** La cola sigue siendo de Carlos: (1) fusionar
orbit#66/#67/#68/#69 (cross-merge verificado, main sin mover); (2) tras
el merge, corte de tags (probable minor de raíz/agent/server; proto sin
cambios) y certificación del set Quantum siguiente. El tracker de orbit
tiene ahora 5 issues (#70–#74) como backlog post-merge, ejecutables en
sesiones siguientes sin decisiones nuevas.

---

### Sesión 2026-07-13 (11ª) — backlog de auditoría de ORBIT (fleet v1.2.1/server v0.6.0) ejecutado: 4 PRs abiertos

Carlos trajo el backlog curado de la auditoría de orbit (fakes/bugs +
mejoras de seguridad y UX). Reconocimiento del brief: el **plano fleet es
real de punta a punta** (verificado en vivo por la auditoría); los
problemas eran dos botones fake, un audit roto bajo auth, dos bugs de
telemetría fleet, y UX incipiente. Ejecutado en **4 PRs temáticos en
`jcsvwinston/orbit`, todos PENDIENTES DE MERGE por Carlos** (las sesiones
no auto-fusionan PRs propios — [[session-cannot-self-merge-prs]]):

- **orbit#66 (plano fleet Go)** rama `fix/fleet-plane-audit-backlog`:
  OR-SEC-P1-5 (`State.OnAgentSubMode` nunca se asignaba → un agente que
  reconecta con streams de UI abiertos no reanudaba telemetría hasta
  reabrir una UI; ahora `server.New` cablea `services.PushAggregate`, con
  test de reconexión). OR-UX-P0-1 (el evento salía con el NodeID del bus
  in-process ≠ UUID del registro → tarjetas por nodo a 0; el stream del
  agente sobreescribe `Event.NodeId`). OR-FLEET-1 (sampling_rate por sub
  ahora SE APLICA en el fanout con muestreo residual `rate/aggRate`; el
  Subscribe agregado propaga el máx por tipo; `Stats.Sampled`).
  OR-FLEET-2 (GetSnapshot deja de ser stub: providers GO_RUNTIME +
  REGISTERED_MODELS; resto = error por tipo). OR-SEC-P1-3 (operador
  read-only: `X-Auth-Role: viewer` / `--ui-read-only` → mutaciones de
  Data Studio PermissionDenied, lecturas siguen). OR-SEC-P1-4 (CSP+nosniff+
  X-Frame-Options+Referrer-Policy en el listener UI). OR-SEC-P2-1 (lockout
  por IP de credenciales presentadas-y-erróneas; las sin credencial no
  cuentan). OR-SEC-P2-3 (IdleTimeout h2c; Read/WriteTimeout fuera por los
  streams largos). OR-SEC-P2-4 (`AgentInactivityTimeout` deja de ser
  config muerta: janitor `MarkStale` + revive en `Touch`). `go test -race`
  verde en server+agent, 9 tests nuevos.
- **orbit#67 (panel in-process)** rama `fix/inprocess-panel-audit-backlog`:
  OR-SEC-P1-1 (el `auditMiddleware` colgaba SOLO del branch SPA GET-only →
  bajo auth, la postura de producción, las escrituras de Data Studio NO se
  auditaban; ahora el grupo `/api` lo lleva, con test). OR-SEC-P1-2
  (redacción del `OldValue`: campos IsExcluded + nombres tipo credencial).
  OR-SEC-P2-1 (lockout de login por IP y username). OR-SEC-P2-2 (gate de
  Content-Type en escrituras `/api` → 415 a form-encoded/multipart fuera
  del import; documentado SameSite=Lax; `session_cookie_secure:false` de
  los ejemplos anotado solo-dev). OR-UX-P0-2 (`DELETE /api/sessions/{token}`
  EXISTE — el botón «terminate» de la SPA fallaba en cada click; destruye
  la sesión, 404 honesto, audita el token abreviado). OR-UX-P0-3 (la SPA
  llamaba `/api/export` inexistente → 404 en todo export; alineado a
  `/api/exports` + `/api/exports/download?key=`; import `/api/import/upload`
  → `/api/imports`; bundle dist del panel reconstruido). `go test ./...`
  raíz verde, 6 tests nuevos.
- **orbit#68 (UX de la SPA fleet, `ui/`)** rama `feat/fleet-ui-ux-backlog`:
  OR-UX-P0-4 (feedback de error en Data Studio + `deleting…` + recordCount<0
  → «—»), P1-1 (toasts aria-live), P1-4 (pausa con buffer + «N new» al
  reanudar), P1-5 (interceptor Unauthenticated → pantalla de no-autorizado),
  P1-8 parcial (modal role=dialog/Escape/focus-trap), P1-9 (token `--t26`
  subido a AA en ambos temas), P2 (claves de lista estables por ts-ns;
  título/branding «Orbit · Nucleus admin» + favicon; `format.ts` purgado;
  footer sin el hardcode falso «orbit v0.2.0»). `tsc`+`eslint --max-warnings 0`+
  `vite build` verde; tests de server (embeben el dist) verdes.
- **orbit#69 (docs)** rama `docs/audit-backlog-fakes`: versiones v1.2.0→
  v1.2.1 (README/intro/quick-start/CLAUDE); CLAUDE «agent/server esqueleto»
  corregido (es plano fleet real); aviso de superusuario + knobs read-only +
  guía de reverse proxy OIDC añadidos a `website/docs/cluster/server.md`;
  sección de identidad de nodo (mismatch node_id) en `agent.md`; ui/README
  con las 10 rutas reales (antes `/#/dashboard` inexistente).

**Cross-merge verificado** (precedente de sesiones previas): las 4 ramas
fusionan limpias en secuencia sobre main (cero conflictos) y el árbol
COMBINADO pasa `go build`+`go vet`+`go test ./...` en los tres módulos
(raíz/agent/server). Carlos puede fusionar en cualquier orden.

**Diferido a follow-ups (por tamaño, anotado en orbit#68):** OR-UX-P1-6
(versión real del server + identidad del operador — necesita un RPC de
echo, proto/server), P1-3 (barra de filtros de stream), P1-2 (exponer en
Data Studio multi-select/bulk/alias/nodo/choices→select/FK-link/date
editor), P1-7 (herramientas del audit log: filtros/rango/CSV/paginación).
Otros P2 sin tocar: i18n centralizado, `SLOW_MS` configurable,
búsqueda/virtualización del sidebar de modelos, consolidar las dos tablas
del panel, NodeDetail Components/Recent activity.

**Cola de Carlos:** (1) fusionar orbit#66/#67/#68/#69 (cross-merge ya
verificado); (2) tras el merge, decidir el corte de tags (server sube por
los feats → probable `server/vX`, `agent/vX`; la raíz sube por internal/
admin + ui → minor de raíz; proto sin cambios) y certificar el set Quantum
siguiente (bump de `modules.orbit`/`workspace_pins.orbit` + release del
paraguas). El plano fleet Go y el panel son cambios de comportamiento
(nuevos flags, audit, headers) → probable **minor** de los módulos
tocados.

---

### Sesión 2026-07-13 (10ª) — backlog de auditoría de quark v1.2.1 EJECUTADO: quark v1.2.2 + Quantum 1.3.1

Carlos trajo el backlog curado de la auditoría (4 P0, 8 P1, 7 P2) y la
sesión lo ejecutó completo en 4 PRs temáticos + release:

- **quark#242 (P0)**: inyección SQL en `tenant provision` (id/strategy
  validados ANTES de conectar, DDL con `dialect.Quote`, INSERT
  parametrizado); `Count()`/`Paginate` sobre set-ops contaban solo el
  operando base → `SELECT COUNT(*) FROM (<compound>)` con CTE izado
  (MSSQL no acepta WITH en subquery); `Upsert`/`UpsertBatch` con
  conflictCols vacío → `ErrInvalidQuery` uniforme (antes: panic
  MySQL/MariaDB, DO NOTHING silencioso PG); `Offset` sin `Limit` →
  sentinels (`LIMIT -1` SQLite; max-uint64 MySQL/MariaDB — el backlog
  sugería -1 para MariaDB pero MariaDB rechaza LIMIT negativo). Dos
  tests fósiles corregidos.
- **quark#243 (docs)**: aviso de savepoint-rollback INVERTIDO (el código
  trunca las colas de hooks — decía lo contrario), roadmap v1.1.5→real,
  `Cast` inexistente borrado, claim de chunking del README honesto,
  requisito pgx/stdlib del listener LISTEN/NOTIFY (lib/pq falla en
  Listen), tabla de opciones con las 10 `With*` que faltaban, snapshot
  1.2.1 congelado (el P2-6 pendiente del release anterior).
- **quark#245 (CLI)**: `migrate up`/`down` y `seed run` con registro
  vacío salen non-zero con la receta de embebido (nuevo
  `migrate.RegisteredCount()`); `validate` REAL con go/packages
  (reutiliza codegen, nuevo `LoadDir`; compara columnas en ambas
  direcciones); `tenant migrate` resuelve el DSN del tenant vía
  `tenant.dsn_template` con `{tenant}` (schema_per_tenant: error
  explícito, antes migraba la BD por defecto); inspect/model con tabla
  inexistente → non-zero; flags fantasma fuera (`--skip-seed`,
  `--tenant-id`, `--env`); registro de tenants dialect-aware
  (MSSQL/Oracle); `init --dialect bogus` falla antes de escribir.
- **quark#246 (query-builder)**: `UpsertBatch` chunkea como CreateBatch;
  techos de bind-params POR DIALECTO (PG/MySQL/MariaDB 65000, SQLite
  32000, MSSQL 2000 — `batchBindParamCeiling`); Upsert MSSQL
  back-fillea el PK con `MERGE … OUTPUT INSERTED` (Oracle: MERGE sin
  RETURNING, documentado); INTERSECT/EXCEPT habilitados en MariaDB
  10.3+ (MySQL sigue bloqueado: los ganó en 8.0.31, no asumible sin
  probe). El gate de superapp en MariaDB validó el cambio EN VIVO (la
  celda esperaba el sentinel y el motor ejecutó INTERSECT de verdad →
  capability actualizada). Suite nueva `UpsertBackfillsGeneratedPK`
  contra los 6 motores.
- **QK-P2-7 diferido** con boceto de diseño → quark#247 (única issue
  abierta en quark).
- **quark v1.2.2 taggeado** (release-PR #244 + bump de coherencia
  README/SECURITY/CLAUDE/release-notes/roadmap + snapshot 1.2.2 EN el
  release-PR — el paso 4 ya no se queda atrás). Tag `fc81f4cf`.
  Verificado como usuario: `go install …@v1.2.2` → `quark version` =
  v1.2.2; `migrate up` sin registro → exit 1 con guía.
- **QUANTUM 1.3.1** (este PR): modules.quark → v1.2.2, pin `fc81f4cf` =
  tag exacto; nucleus v1.2.0 y orbit v1.2.1 continúan del 1.3.0. Los
  seis patrones del workspace compilan con el pin nuevo.

Gotchas nuevos de la sesión: (1) el gate estricto de superapp exige
cubrir o allowlistar cada símbolo público nuevo — `RegisteredCount` se
cubrió ejercitándolo (y el manifiesto `apisurface.json` se regenera con
`go run ./examples/superapp/cmd/gen-apisurface && … gen-allowlist`,
no con `go generate`); (2) un commit colado en rama equivocada se mueve
con `git revert` + `cherry-pick` — el force-push está vetado por el
clasificador incluso con `--force-with-lease`; (3) los merges con la
regla simple allowlisted pasan, pero comandos COMPUESTOS de
verificación posteriores pueden caer al clasificador y denegarse —
verificar con `git fetch` + `git log origin/main` en invocaciones
simples.

**Foco siguiente (mandato de Carlos, sin cambios):** issues de nucleus
y orbit, avanzando los tres módulos juntos — el trabajo vendrá de los
prompts de Carlos. Trackers: quark 1 issue (#247, diferida a
propósito), nucleus/orbit por re-verificar al arrancar.

---

### Sesión 2026-07-12 (9ª) — decisiones de Carlos ejecutadas: quark v1.2.1 taggeado y QUANTUM 1.2.1 certificado

Carlos decidió sobre los 3 puntos y autorizó los merges («mergea, haz
resumen de 11 advisories y decido» → «1. como recomiendas; 2. taggealo;
3. aprobamos v1.2.1 y certifica»):

- **Merges**: quark#237/#238/#239 y quantum#53 fusionados (squash, título
  conventional). El cross-merge verificado en la 8ª evitó sorpresas.
- **Las «11 advisories» CONFIRMADAS**: govulncheck contra el tag v1.1.5
  (worktree, BD de 2026-07-12) reproduce EXACTAMENTE 11 vulnerabilidades
  alcanzables — 10 stdlib (GO-2026-5856/4870 crypto/tls, GO-2026-5037/
  4947/4946/4866/4600/4599 crypto/x509, GO-2026-4971 net, GO-2026-4601
  net/url) + GO-2026-5004 (pgx v5.5.5, la inyección SQL por dollar-quoted
  strings). Las dos serias: la de pgx y el auth bypass de x509 (4866).
  Decisión de Carlos: las release notes del tag v1.2.0 se quedan como
  están (la cifra es verificable; el CHANGELOG ya explica el matiz).
- **quark v1.2.1 taggeado** (release-PR #240 + bump de coherencia): el
  check de coherencia de versión, estrenado en su primer release, exigía
  el bump de docs en el MISMO PR — README/SECURITY/CLAUDE/release-notes
  .mdx a v1.2.1 + sección v1.2.1 en el sitio, empujado a la rama del bot
  (que además dispara el CI, la lección conocida). Tag `8ff89a1f` +
  release publicada. Verificado como usuario real: `go install
  …/cmd/quark@v1.2.1` → `quark version` imprime v1.2.1 (fallback de
  buildinfo end-to-end) y `quark sync --dry-run` → unknown flag, exit 1.
- **QUANTUM 1.2.1 CERTIFICADO** (este PR): modules.quark → v1.2.1, pin
  `8ff89a1f` = tag EXACTO (sin matiz de docs — el snapshot 1.2.0 ya viene
  dentro del tag), nucleus/orbit continúan del set 1.2.0. Set compilado en
  local + lockstep de los 6 módulos de orbit contra el pin nuevo en verde;
  release de GitHub del paraguas con las notas del manifiesto.

**Foco siguiente (mandato de Carlos):** avanzar con issues de nucleus y
orbit — «pule bien el trabajo para avanzar con los otros módulos e ir
avanzando todo junto». Estado de partida: los tres pilares sin deuda
conocida (govulncheck 8/8 limpio, auditoría de quark curada), pines en
tag, sitio vivo, los tres checkouts standalone sincronizados a main.

**Inventario de issues abiertas (verificado 2026-07-12 vía API, mismo
día del cierre): CERO en ambos repos** — `open_issues_count: 0` en
nucleus y en orbit (issues habilitadas; tampoco hay PRs abiertos). No
hay backlog en el tracker: el trabajo del arco vendrá de los **prompts
que Carlos tiene preparados para las próximas sesiones** — esperar su
prompt, no inventar foco. (Los deferrals conocidos de los gates —
nucleus: observability→eval v1.2, driver instr prometido «v1.1»; orbit:
colectores propios en /metrics, RBAC Revoke real, `tenant onboard` —
quedan como contexto de fondo, NO como foco elegido.)

---

### Sesión 2026-07-12 (8ª) — sesión autónoma: fusión cruzada de los 3 PRs de quark + barrido de salud del set

Sesión auto. Los 4 PRs de la 7ª (quark#237/#238/#239 + quantum#53) siguen
abiertos esperando a Carlos — todo el pipeline principal está en sus manos,
así que la sesión hizo el trabajo de des-riesgo y salud que no requiere
decisiones:

- **Fusión cruzada verificada** (precedente de las sesiones de nucleus):
  las tres ramas de quark#237+#238+#239 fusionan limpias en secuencia
  sobre main (cero conflictos) y el árbol COMBINADO pasa `go build`,
  `go vet`, los 18 paquetes de `go test -short`, `lint-docs.sh` y
  `check-version-coherence.sh`. Carlos puede fusionar en cualquier orden
  sin sorpresas.
- **Barrido govulncheck del set certificado** (precedente 4ª sesión): los
  8 módulos pinneados (quark, nucleus, orbit raíz, agent, proto, server,
  quarkbridge, quarkdatasource) con la BD de hoy (2026-07-12), `GOWORK=off`:
  **0 vulnerabilidades alcanzables en los 8**. El set 1.2.0 sigue limpio.
- **Sitio vivo**: portada, `/nucleus/`, `/quark/intro/` y `/orbit/` → 200.
- Auditoría de arranque: pines = manifiesto (tres en tag+docs), los seis
  patrones del workspace compilan.

**Sin pendientes nuevos.** La cola sigue siendo de Carlos: (1) fusionar
quark#237/#238/#239 (cross-merge ya verificado) y quantum#53; (2) decidir
pin de quark post-merge y si toca v1.2.1 con el checklist nuevo; (3) las
release notes de GitHub del tag quark v1.2.0 (el «11 advisories»).

---

### Sesión 2026-07-12 (7ª) — el brief de corrección de Quark ejecutado: 12 hallazgos → 3 PRs

Carlos entregó el brief de auditoría de quark (12 hallazgos H-Q1..H-Q12
sobre el pin `5d8c99ce` = v1.2.0). Los 12 quedaron cubiertos en 3 PRs,
**pendientes de merge por Carlos** (la sesión no puede auto-fusionar):

- **quark#237 — CLI** (H-Q1 crítica, H-Q2/H-Q3 altas, H-Q8/Q11/Q12):
  `quark init` generaba proyecto roto (`driver: postgresql` vs driver
  registrado `pgx`) → mapping dialecto→driver en la CLI + import de go-ora
  (el driver `oracle` no estaba registrado en el binario); migrate/inspect/
  tenant/seed/init pasan a `RunE` (fallos ya salen con exit≠0 — antes
  exit 0, rompía gating de CI); `sync` pierde sus 4 flags no-op y dice la
  verdad (guía para `client.Sync`, que necesita los modelos compilados);
  `inspect --format json|yaml` implementado; `quark version`/`--version`
  nuevos; `inspect sql` re-etiquetado. Verificado end-to-end con binario
  local (sqlite feliz; pg/oracle llegan a conectar y exit 1).
- **quark#238 — docs/versionado** (H-Q4/H-Q5 altas, H-Q6/H-Q9 medias):
  3 snippets del README que no compilaban corregidos; drift v1.1.5/v1.1.2/
  v1.1.0 → v1.2.0 en README/SECURITY/CLAUDE/release-notes (+ snapshot
  1.2.0 del sitio, que decía v1.1.5); `docs/RELEASE_NOTES_v1.2.0.md`
  escrito desde ADR-0020/21/22; **govulncheck en CI** (0 alcanzables hoy)
  + sección de advisories en SECURITY.md; **check de coherencia de versión
  en CI** (`scripts/check-version-coherence.sh` — la forcing function que
  faltó al taggear v1.2.0); comandos fantasma (`schema verify/diff`,
  `tenant onboard/install-rls-policies`) marcados como planned/librería.
  Matiz: el «11 advisories» del commit quark#235 SÍ tenía origen (este §3,
  sesión 5ª: govulncheck 11→0) pero no vivía en el repo quark — el
  CHANGELOG ahora lo explica y omite el conteo perecedero.
- **quark#239 — hardening** (H-Q7 media, H-Q10 baja): los 5 `Quote()`
  ahora auto-escapan el carácter de cierre (defensa en profundidad;
  sin bypass explotable previo); `ValidateRawQuery` enmascara el contenido
  de literales `'...'` para los patrones estructurales — `'range--max'`
  (falso positivo documentado) ya pasa, `--` fuera de literal se sigue
  rechazando; mensajes de rechazo específicos; regex precompilados.

También en este PR de quantum: la nota del manifiesto 1.2.0 matiza el
«11 advisories» y reconoce la deuda encontrada post-tag. Pendiente para
la próxima sesión: tras el merge de los 3 PRs, decidir si mover el pin de
quark (los fixes son CLI/docs/guard — la superficie de librería solo
cambia en `Quote`, aditivamente seguro) y si toca release v1.2.1 con el
checklist nuevo. Las release notes de GitHub del tag quark v1.2.0 aún
dicen «11 advisories» (editarlas es acción pública — decisión de Carlos).

---

### Sesión 2026-07-11 (6ª) — el botón de Orbit en el hero de la portada

Pedido directo de Carlos. El hero del sitio tenía solo dos CTAs (Nucleus,
Quark) desde la Fase 2 — la instancia de Orbit llegó después (Fase 3) y las
tarjetas de pilares se enlazaron, pero la fila de botones nunca se
actualizó. quantum#51: «Orbit →» como botón secundario a `/orbit/` directo
(su intro declara `slug: /`, ruta real del router — no aplica la trampa SPA
que obliga a `/quark/intro/`). Verificado EN VIVO tras el deploy: los tres
botones en orden con sus hrefs correctos.

**Sin pendientes nuevos.** Los flecos siguen siendo decisiones de Carlos
(próximos arcos de producto; nada bloqueado).

---

### Sesión 2026-07-11 (5ª) — los 3 puntos de Carlos ejecutados: quark curado, ceremonia, y el arco W1/W2 completo — Quantum 1.2.0

Carlos dio el "Adelante" a los 3 pendientes + el mandato de barrer TODA la
documentación publicada al terminar (tarea siguiente, EN CURSO al cierre).

- **[Quark] v1.2.0** (quark#235 + release-PR #225): las 11 advisories
  curadas (toolchain go1.26.5 + pgx v5.9.2; matriz de 6 motores 13/13
  verde; govulncheck 11→0) — el release recoge además el drift acumulado
  (+37 commits: scatter-gather de sharding ADR-0022 etc.), por eso el
  número honesto fue v1.2.0, no v1.1.6.
- **Ceremonia del paraguas**: releases de GitHub quantum v1.0.0 (en el
  commit de la convergencia) y v1.1.0, con las notas del manifiesto.
- **[Orbit] W1 — Access control y Audit log REALES** (orbit#42): frames
  RbacRequest/Response append-only + ManageService (GetRbac/ListAudit);
  el agent toma `app.Authorizer` SOLO en Attach (cero config nueva) y
  sirve el snapshot Casbin read-only vía una interfaz estrecha
  PolicySource; el server registra las mutaciones que él mismo rutea
  (ring acotado del plano fleet, actor del UI auth chain — la identidad
  viaja ahora en el contexto — y nodo destino). 3 tests de integración
  sobre stream real + sesión de navegador en vivo (roles/policies
  renderizados; audit con estado vacío honesto). La app sigue siendo el
  único escritor RBAC — el Revoke placeholder se quitó en vez de fingir.
- **[Nucleus] v1.1.0 — la mitad de W2** (nucleus#196): SQLEvent.
  RowsAffected aditivo (nace en los exec del CRUD, best-effort del
  driver; 0 = no reportado), rebaseline deliberado +2, inventario al
  día; RC validado por el lane (quantum#48, 5ª ejecución A-7) → tag →
  housekeeping #198 (pinned v1.1.0).
- **[Orbit] W2 — columna Rows real** (orbit#49): rows_affected en el
  proto (field 10, breaking-check verde), conversión del agent, y la
  columna del stream SQL (placeholder desde el rediseño) mostrando el
  conteo (guion honesto para 0). Repin nucleus v1.1.0 en los seis
  go.mod. De paso: restaurada la afirmación VERDADERA de
  RequireConnection en el README del agent (el barrido A-4 la borró por
  un grep truncado con `head -5` — lección: no truncar greps de
  verificación).
- **Tags del arco**: proto/v0.3.0, agent/v0.4.0, server/v0.5.0,
  quarkbridge/v0.3.0 y **orbit v1.2.0** (#45). Bumps post-tag (#47,
  #48-orbit, #54) — resolución standalone verificada en cada eslabón.
- **QUANTUM 1.2.0 certificado** (este PR): quark v1.2.0 + nucleus
  v1.1.0 + orbit v1.2.0, tres pines EN TAG, sin deuda de seguridad
  conocida en ningún pilar.

**EN CURSO al cierre**: tarea #20 — el barrido completo de la
documentación publicada (mandato explícito de Carlos: "es fundamental
poner al día toda la documentación publicada (docusaurus), subsanando
cualquier incongruencia"). Alcance: 3 instancias del sitio (nucleus
14+versioned, quark 41, orbit 9 páginas) + portada; las correcciones van
por PR a cada repo fuente (QADR-0003). Ya anotado para el barrido: las
páginas de orbit deben recoger W1/W2 (Access control/Audit log ya no son
huecos declarados; columna Rows), versiones citadas, y el precedente de
falsedades del barrido A-4.

**Foco siguiente:** terminar la tarea #20 y considerar la ceremonia del
release quantum v1.2.0 (mismo patrón que v1.0.0/v1.1.0).

**BARRIDO EJECUTADO (misma sesión, continuación):** hallazgos REALES en
las tres instancias, todos corregidos por PR en su repo fuente:
- **[Nucleus, el gordo]** el intro publicado decía «Status: pre-1.0
  (v0.x)», installation avisaba de roturas v0.X+1 y compatibility decía
  que el reloj del SLO no había arrancado — TODO falso desde el major, y
  **el snapshot 1.0.0 congeló esas falsedades como docs oficiales del
  major**. Corregido en current Y en el snapshot (nucleus#199; excepción
  deliberada a la inmutabilidad: un snapshot que miente sobre el estado
  de SU propia versión es un bug material, no historia — distinto de las
  anclas rotas de quark). También features/admin.md: «orbit primer tag
  v0.1.0, pre-1.0» → v1.2.0 + promesa v1.x congelada.
- **[Quark]** v1.2.0 salió con el overhaul de docs (37 ficheros) SIN
  snapshot — el sitio servía por defecto 1.1.0 pre-overhaul. Snapshot
  1.2.0 cortado (quark#236, matriz 13/13).
- **[Orbit]** server.md documenta la Manage surface real (snapshot RBAC
  + ring de audit del plano fleet), agent.md el cableado automático del
  authorizer, versiones a v1.2.0, y una incongruencia previa (la tabla
  del README del server nunca listó DataStudioService) (orbit#55).
- **[Paraguas]** pines bumpeados a los commits post-barrido con matices
  documentados (librerías idénticas a los tags — el sitio ensambla desde
  el pin); `.claude/launch.json` (colado por un `git add -A` en la
  certificación 1.2.0) fuera del repo y al .gitignore.

---

### Sesión 2026-07-11 (4ª) — barrido de seguridad: GO-2026-5856 curada en orbit; Quantum 1.1.0; BRIEF de quark

Sesión autónoma (auto). Sin trabajo de flecos pendiente (ambos eran de
Carlos), la sesión hizo un barrido de salud que orbit no tiene en CI
propio — y encontró cosas:

- **[Orbit] GO-2026-5856 ALCANZADA en el pin v1.0.0** (govulncheck): la
  fuga de privacidad de Encrypted Client Hello en crypto/tls (fix
  go1.26.5) con trazas reales (dial TLS del relay Redis del live feed,
  Panel.Loaddata→io.ReadAll, rutas TLS de agent/server). Los seis go.mod
  no llevaban `toolchain` → compilaban con go1.26.4. **Fix orbit#36**:
  `toolchain go1.26.5` en los seis (mismo remedio que nucleus#185);
  govulncheck limpio tras el pin; build+test verdes en los seis.
- **Tags de mantenimiento**: proto/v0.1.1, agent/v0.2.1, server/v0.3.1,
  quarkbridge/v0.2.1, quarkdatasource/v0.2.1 y **orbit v1.1.0** (el PR
  rodante #34 recogió el minor: el feat del listener /metrics + el fix de
  seguridad — changelog honesto). El baile del manifest ×5, ya rutinario.
  (Incidencia propia: una función zsh perdió args y empujó una rama
  basura al remoto — borrada; los pasos de reconciliación van INLINE, no
  en funciones.)
- **QUANTUM 1.1.0 certificado** (este PR): modules.orbit → v1.1.0, pin
  = tag, lane A-7 verde con el set. El `go.work` de la suite también fija
  `toolchain go1.26.5` (el plano de integración compila con la stdlib
  corregida). README al día.
- **[Quark] BRIEF DE SEGURIDAD para Carlos** (decisión suya — nunca he
  tocado el repo quark y es su producto más maduro): quark v1.1.5 (el pin
  certificado) y también su MAIN están en `go 1.25.7` y ALCANZAN 11
  vulnerabilidades: 10 de stdlib (todas curadas en la línea go1.26.x:
  GO-2026-5856 crypto/tls, GO-2026-5037/4947/4946/4866/4600 crypto/x509,
  GO-2026-4971 net, GO-2026-4870 crypto/tls, GO-2026-4601 net/url, +1) y
  **pgx v5.5.5 → v5.9.2 (GO-2026-5004 — la MISMA que nucleus curó en
  #169)**. Remedio propuesto: v1.1.6 de mantenimiento en quark (bump de
  `go`/`toolchain` a 1.26.5 + pgx v5.9.2 + su matriz de 6 motores en CI)
  → después, set Quantum 1.1.1 con quark v1.1.6. Su main lleva +37
  commits sin taggear (drift normal), así que el corte lo decide él.

**Pendientes de decisión de Carlos (3):**
1. **Quark v1.1.6 de mantenimiento** (el brief de arriba) — recomendado
   pronto: 2 de las 11 son las mismas advisories que ya se curaron en
   nucleus.
2. Ceremonia de release de GitHub para quantum (¿release/tag v1.0.0 o
   v1.1.0 del paraguas?) — outward-facing.
3. El arco v1.1→v1.2 de orbit (waivers W1/W2: RPCs RBAC/audit y row
   count) — nota: orbit ya está en v1.1.0 por el set de mantenimiento;
   los waivers apuntaban "a v1.1" como "siguiente minor", que ahora es
   v1.2.

**Foco siguiente sugerido:** el brief de quark es el más urgente de los
tres (seguridad); los otros dos, en el orden que Carlos prefiera.

---

### Sesión 2026-07-11 (3ª) — fleco 1 cerrado: /metrics opt-in y --version honesto en el admin-server

Sesión autónoma corta (auto). Auditoría limpia. De los tres flecos, el 2
(ceremonia de release del paraguas) y el 3 (arco v1.1 de orbit) son
decisión de Carlos; se ejecutó el 1:

- **[Orbit] Hallazgo al abrir la menudencia** (orbit#33): `Config.
  MetricsAddr` era config MUERTA — `withDefaults` la coercionaba a
  `:9091` y el godoc prometía un listener, pero NADA consumía el campo
  (la nota del barrido A-4 se quedó corta: no era solo "sin flag", no
  existía la implementación).
- **Listener de métricas real, estrictamente opt-in** (mismo PR): tercer
  listener (vacío = desactivado; la coerción fantasma fuera) con el
  registro Prometheus por defecto (`go_*`/`process_*`; colectores propios
  del server = trabajo futuro) + `/healthz`, shutdown graceful junto a los
  otros dos, `--metrics-addr`/`NUCLEUS_ADMIN_METRICS_ADDR` en el CLI.
  2 tests de integración nuevos + smoke en vivo. Sin auth por diseño
  (documentado: interfaz privada).
- **`--version` honesto**: fuera el "(phase 4)" — lee
  `debug.ReadBuildInfo`; verificado end-to-end: `go install …@v0.3.0`
  imprime `nucleus-admin-server v0.3.0`; builds de fuente, `devel`.
- **server/v0.3.0 taggeado** (release-PR #35). **orbit#34 (root 1.1.0)
  queda ABIERTO A PROPÓSITO**: el feat tocó `website/docs/` (bajo el
  paquete raíz) y el bot propone 1.1.0 sin cambio real de librería —
  taggear eso inflaría el número; el PR rodante espera al primer feat
  real de raíz (precedente: orbit#11 en Fase 3).
- Sin cambios de pines: el server no está en `workspace_pins` (la raíz de
  orbit sigue = v1.0.0) y el trío no se ve afectado.

**Flecos que quedan (decisión de Carlos):**
1. Ceremonia de release de GitHub para quantum (¿release/tag v1.0.0 del
   paraguas con las notas del manifiesto?) — outward-facing.
2. El arco v1.1 de orbit (waivers W1/W2: RPCs RBAC/audit de las pantallas
   Manage y row count en SqlStatementEvent). Al cortar ese arco, el PR
   rodante orbit#34 recogerá el minor de raíz legítimamente.

**Foco siguiente sugerido:** los dos flecos de arriba, en el orden que
Carlos prefiera; sin él, no hay trabajo autónomo pendiente en la suite.

---

### Sesión 2026-07-11 (2ª) — post-hito: portada honesta + docs de nucleus versionadas en el sitio

Sesión autónoma corta tras la certificación. Auditoría de arranque limpia
(pines = tags, trío compila, deploy del sitio con la certificación verde).

- **Portada corregida** (quantum#43): el README afirmaba "Sitio de docs
  unificado: pendiente" — FALSO desde 2026-06-26 (live). La nota de cierre
  del ROADMAP y el fleco 1 del §3 (escritos en la certificación) repetían
  el error; corregidos. Verificado en vivo: la navbar del sitio ya muestra
  «Quantum 1.0.0» y los chips v1.0.0/v1.1.5 — se auto-actualizó desde
  versions.yaml en el deploy de la certificación, como fue diseñado.
- **Docs de nucleus versionadas** (nucleus#195 + quantum#44): primer
  snapshot Docusaurus de nucleus (1.0.0), cortado con main == estado del
  tag (el único delta era el housekeeping del CLI, no docs). El sitio de la
  suite lo consume con el mecanismo de quark generalizado:
  `sync-versions.mjs` acepta la instancia `default` (destino SIN prefijo) y
  renombra el sidebar `tutorialSidebar`→`nucleusSidebar` al ensamblar (la
  fuente no se toca, QADR-0003); dropdown de versión de nucleus en la
  navbar (1.0.0 + Next). Pin de nucleus: v1.0.0 → `a5fc3565` (= tag +
  snapshot + housekeeping CLI; librería idéntica al tag) — matiz
  documentado en versions.yaml, precedente del pin de orbit en 0.1.0.
  `/nucleus/` sirve 1.0.0 y `/nucleus/next/` el current.
- Con esto, los flecos 1 y 2 de la lista post-hito quedan CERRADOS.

**Flecos que quedan (decisión de Carlos):**
1. Menudencias orbit: `admin-server --version` imprime "(phase 4)"
   (string estancado); exponer `--metrics-addr` en el CLI del server.
2. Ceremonia de release de GitHub para quantum (¿release/tag v1.0.0 del
   paraguas con las notas del manifiesto?).
3. El arco v1.1 de orbit (waivers W1/W2: RPCs RBAC/audit de las pantallas
   Manage y row count en SqlStatementEvent).

**Foco siguiente sugerido:** decidir con Carlos el orden post-1.0 entre
esos tres (el 1 es S y puede colarse en cualquier sesión; el 3 es el arco
de producto natural).

---

### Sesión 2026-07-11 — LA CONVERGENCIA: orbit v1.0.0 y QUANTUM 1.0.0 — los tres pilares en major 1

Sesión autónoma (continuación de la del 2026-07-10; Carlos había aprobado el
alcance del gate de orbit y los waivers W1/W2 con un "ok"). El arco completo
de orbit (gate slices 1–4) ejecutado de una tirada:

- **[Orbit] Slice 1 — freeze guard** (orbit#21): `contracts/freeze_test.go`
  (puerto a escala del de nucleus, con sus dos lecciones: constructores y
  consts tipadas van bajo el TIPO en go/doc) fija `orbit` raíz +
  `orbit/datasource` contra un baseline de 100 símbolos; falla en ambas
  direcciones (borrados Y adiciones sin revisar); regen con
  `ORBIT_UPDATE_CONTRACT_BASELINE=1`. Contrato datasource declarado FINAL
  en ADR-001 (sección de congelación). El lane orbit-lockstep cubre
  `./orbit/...`, así que el guard corre en cada push/PR de la suite. A-1 ✅.
- **[Orbit] Slice 2 — pata fleet standalone** (orbit#22, #24–#30):
  proto/agent/server en release-please con tags de componente
  (`release-as: 0.1.0` para el primer corte). Decisión de distribución del
  server: TAMBIÉN se taggea — es un deployable (binario `admin-server`,
  go-install-able); su API Go queda sin promesa. `replace` intra-repo
  eliminados (orbit#27); tags finales: proto/v0.1.0, agent/v0.2.0,
  server/v0.2.0. Verificado el criterio de cierre con módulo scratch
  (agent-only resuelve por tags) y `go install …/admin-server@v0.2.0`. A-2 ✅.
  Deuda pagada de paso: los `release-as` consumidos se RETIRAN de la config
  (el de los bridges habría forzado 0.1.0 eternamente; mordió con los
  0.1.0 duplicados #28/#29 antes del fix #30).
- **[Orbit] Slice 3 — Config congelada + barrido anti-falsedad** (orbit#23):
  los 21 campos de `Config` revisados uno a uno (todos congelables tal
  cual; godoc con la promesa v1.0 explícita). Barrido de 9 páginas del
  sitio + 4 READMEs + doc.go + go.work + CLAUDE.md con hallazgos SERIOS:
  el mito de la contraseña de bootstrap (P0 — los docs prometían password
  aleatoria con `bootstrap_password` vacío; el código OMITE el bootstrap:
  el operador del quick-start quedaba fuera del panel), wiring del agent
  incompilable (`cfg.AdminAgent`/`app.MustLoadConfig` fantasmas; lo real:
  `agent.ExtensionConfig` + `app.LoadConfig`), flag `--metrics-addr`
  fantasma, `make build` no produce `bin/admin-server`, claim falso de CI
  de regeneración, rutas `admin/*` pre-extracción, doc.go "Phase-1
  skeleton" en módulos implementados, badge `status: complete` (anti-hype)
  fuera. A-3 ✅, A-4 ✅.
- **[Orbit] Slice 4 — el tag** (orbit#31, #18): waivers W1/W2 formalizados
  como APROBADOS (2026-07-10); merge con `Release-As: 1.0.0` en el footer →
  release-PR #18 retitulado a 1.0.0; **RC validado por el lane** (quantum#41,
  4ª ejecución A-7, verde) → merge de #18 → **orbit v1.0.0 TAGGEADO**
  (`b72ae024`, 2026-07-10T22:38Z). Housekeeping post-tag mismo día
  (orbit#32: menciones de versión + promesa v1.0 en README/sitio/CLAUDE.md;
  header del gate con outcome). Bridges retaggeados sobre nucleus v1.0.0:
  quarkbridge/v0.2.0, quarkdatasource/v0.2.0 (#19/#20).
- **QUANTUM 1.0.0 CERTIFICADO** (este PR): los tres pilares en major 1
  (quark v1.1.5, nucleus v1.0.0, orbit v1.0.0), tres pines en tag, régimen
  de majors en lockstep ACTIVADO (QADR-0002). README del paraguas al día
  (tabla de pilares, nota de pines reescrita — la del pseudo-version de
  nucleus llevaba tres sets obsoleta); ROADMAP con nota de cierre: Fases
  0–5 CERRADAS. QADR-0005 cumplido.
- **LECCIONES nuevas**: (1) el pie `BREAKING CHANGE:` es un MARCADOR — nunca
  usarlo en prosa aclaratoria ("BREAKING CHANGE: none…" convirtió un fix en
  minor bump: agent/server saltaron a 0.2.0); (2) las ramas de release-please
  multi-paquete conflictan entre sí en `.release-please-manifest.json` al
  fusionar en serie — reconciliar la rama del bot a mano (merge de main +
  manifest unión) es el procedimiento; (3) `release-as` consumido se retira
  en el PR siguiente, siempre.

**Flecos abiertos (trabajo post-hito, no bloquea nada):**
1. ~~Sitio unificado~~ — CORRECCIÓN (2026-07-11, 2ª sesión): el sitio YA
   está vivo desde la Fase 2 (jcsvwinston.github.io/quantum, tres
   instancias + búsqueda + doble selector); la certificación lo
   auto-actualizó a «Quantum 1.0.0» vía `versions.yaml` (verificado en
   vivo). El fleco real es solo el punto 2.
2. **Versionado de docs de nucleus** en su Docusaurus (primer snapshot
   versionado al corte v1.0.0; la instancia nucleus del sitio unificado
   sigue sin versionar, a diferencia de la de quark con 13 versiones) —
   repo nucleus.
3. Menudencias orbit: el binario `admin-server --version` imprime
   "(phase 4)" (string interno estancado); exponer `--metrics-addr` en el
   CLI del server (Config.MetricsAddr ya existe en la API Go).
4. Ceremonia de release de GitHub para quantum (¿release/tag v1.0.0 del
   propio paraguas con las notas del manifiesto?) — decidir con Carlos.

**Foco siguiente sugerido:** decidir con Carlos el orden post-1.0 — sitio
unificado (Fase 2 §5) vs. v1.1 de orbit (waivers W1/W2: RPCs RBAC/audit y
row count) vs. ceremonia de release del paraguas.

---

### Sesión 2026-07-10 — EL HITO: nucleus v1.0.0, el primer major; Quantum 0.5.0

Con Carlos presente (aprobó los 6 waivers §B con un "ok" tras los textos).

- **[Nucleus] Flip de CORS fusionado** (nucleus#191, `feat!`): un router/app
  sin configurar DENIEGA cross-origin (cero cabeceras CORS) — la promesa de
  ADR-013 R4 cumplida en su major. `WithCORSOrigins()` explícito conserva su
  semántica documentada; `cors_origins: ["*"]` reproduce el allow-all
  histórico (4 tests fijan la matriz). DEP-2026-007 → completed; nota de
  cierre en ADR-013 R4; de paso: routing.md afirmaba claves fantasma
  `cors.*` — corregido. (Incidencia menor: flake del proxy de Go en la lane
  postgres; rerun y verde.)
- **[Nucleus] Gate cerrado al completo** (nucleus#193): los 6 waivers §B
  formalizados con la aprobación de Carlos (W1 observability→eval v1.2,
  fuera de la promesa + nota en inventario; W2 driver instr→v1.1; W3 campos
  reservados ADR-010 by-design; W4 generadores→backlog DX; W5 Oracle
  quoting→limitación conocida documentada en la guía multi-BD; W6 wizard).
  Slice 9: `rehearse_rc.sh` 5/5 (tests + goreleaser check + snapshot) y
  artefactos del checklist commiteados en docs/reports/ (compatibilidad
  READY 3/3, dependencias críticas 0). Header del gate refrescado.
- **Merge con `Release-As: 1.0.0`** en el footer del squash → el release-PR
  rodante #192 (que había salido como 0.13.0 por el `feat!` del flip) se
  retituló a **release 1.0.0** — el mecanismo para saltar del tren 0.x al
  major con release-please + bump-minor-pre-major.
- **RC del major validado por el lane** (quantum#39, 3ª ejecución de A-7;
  el flip no toca a orbit — monta in-process, mismo origen) → release-PR
  #192 (CI vía commit vacío) → **nucleus v1.0.0 TAGGEADO** (`d87e9181`,
  release publicada 2026-07-10T18:20Z).
- **Housekeeping post-tag** (nucleus#194): `defaultPinnedFrameworkVersion`
  → v1.0.0.
- **Quantum 0.5.0 certificado** (este PR): modules.nucleus → v1.0.0 — DOS
  de los tres pilares en major 1 (quark v1.1.5, nucleus v1.0.0).

**Lo que queda hasta Quantum 1.0** (el arco final):
1. **Orbit v1.0 en lockstep** (2-3 sesiones, QADR-0005): repin de orbit a
   nucleus v1.0.0 por tag (quarkbridge/quarkdatasource actualizan go.mod);
   **freeze del contrato `datasource`** (su ADR-001 lo fija en v1.0);
   mini-gate de orbit (alcance: decisión de Carlos — candidatos: RPCs
   RBAC/audit de las pantallas Manage, row count en SqlStatementEvent, tags
   de agent/proto en release-please para la pata fleet standalone);
   Release-As 1.0.0 + RC por el lane → tag.
2. **Quantum 1.0.0** (1 sesión): certificación del manifiesto con los tres
   en major 1, régimen de majors en lockstep activado (QADR-0002), 
   versionado de docs de nucleus en el sitio + portada. Fases 0-5 CERRADAS.

**Foco siguiente sugerido:** el arco de orbit — proponer a Carlos el alcance
del mini-gate de orbit (redactarlo como docs/V1_GATE.md de orbit con la
misma disciplina) y arrancar con el repin a nucleus v1.0.0.

- **[Nucleus] Los borrados del tren fusionados** (nucleus#187, 5 commits, uno
  por DEP + governance): alias rbac (DEP-004), claves storage planas
  (DEP-005; el default efectivo `storage/` se preserva — el seeding legacy
  era peso muerto para YAML), `CookieSessionStore` (DEP-006), miembros
  OpenAPI provider-typed (DEP-008 — **pkg/app ya no importa pkg/openapi**) y
  `NewJSONTask`. Rebaseline deliberado: −17 símbolos, −2 claves. Gate:
  **A-2 ✅, A-3 ✅, A-1a ✅ — el §A entero cerrado o esperando solo la rama
  v1.0.0**. Componente de health renombrado `deploy.storage_provider`.
- **LECCIÓN NUEVA (tropiezo reparado)**: el squash-merge usa el TÍTULO del
  PR como mensaje, y release-please solo parsea ese mensaje — #187 con
  título no-conventional fue invisible (sin release-PR), y #177/#178/#182
  faltaban en las notas de v0.11.0 por lo mismo. Arreglo: PR-disparador
  #188 fusionado con `--subject "feat!: ..." --body "BREAKING CHANGE: ..."`
  (mensaje de squash explícito), convención grabada en el CLAUDE.md de
  nucleus, y las notas de v0.11.0 enmendadas con adenda (`gh release edit`).
  **Los títulos de PR deben ser conventional commits, siempre.**
- **RC v0.12 validado por el lane** (quantum#37 ✅, 2ª ejecución del
  procedimiento A-7; los borrados no tocan la superficie Tier-1 de orbit) →
  release-PR #189 (CI vía commit vacío a la rama del bot) → **v0.12.0
  taggeado** (`6ab88201`).
- **Housekeeping post-tag** (nucleus#190): `defaultPinnedFrameworkVersion`
  → v0.12.0 (esta vez sin retraso).
- **Quantum 0.4.0 certificado** (este PR): modules.nucleus → v0.12.0, tres
  pines en tag.

**Lo que queda hasta Quantum 1.0** (mapa acordado con Carlos):
1. **Nucleus v1.0** (1-2 sesiones): rama v1.0.0 con el flip de CORS (A-5a,
   decidido), los 6 waivers §B formalizados (REQUIEREN visto bueno de Carlos
   — preparar textos para aprobación en lote), slice 9 (`rehearse_rc.sh` +
   artefactos del checklist) + validación RC por el lane → tag v1.0.0.
2. **Orbit v1.0 en lockstep** (2-3 sesiones): mini-gate propio (freeze del
   contrato `datasource`, repin a nucleus v1.0, RPCs RBAC/audit, row count,
   tags de agent/proto en release-please). Alcance del gate: decisión de
   Carlos.
3. **Quantum 1.0** (1 sesión): certificación del manifiesto 1.0.0, régimen
   de majors en lockstep, versionado de docs de nucleus en el sitio, portada.

**Foco siguiente sugerido:** la rama v1.0.0 de nucleus — preparar los textos
de los 6 waivers §B para el visto bueno de Carlos, implementar el flip de
CORS, y el slice 9 con su RC por el lane.

Con Carlos presente: autorizó los merges y aceptó las TRES recomendaciones de
los briefs (A-3 remove, A-5a flip, A-1a/b stdlib+exclusión).

- **Cola histórica fusionada** (nucleus#177/178/179/180, quantum#33/34) —
  cadena con update-branch + CI entre cada uno (protección estricta).
- **Lote v0.11 implementado y fusionado** (decisiones → código):
  - nucleus#182 (A-3): `CookieSessionStore` deprecado + DEP/MA-2026-006;
    borrado en v0.12. Cierra también **A-7** en el gate.
  - nucleus#183 (A-5a): WARN de arranque con `cors_origins` vacío +
    DEP/MA-2026-007; el flip a deny aterriza en la rama v1.0.0. De paso:
    puntero fantasma `docs/guides/security.md` corregido.
  - nucleus#184 (A-1a/b): `WithOpenAPIHandler`/`MountOpenAPIHandler`/
    `OpenAPISpec.Handler` (stdlib; baseline +3 intencional); los 3 miembros
    provider-typed deprecados (DEP/MA-2026-008, borrado v0.12); openapi y
    outbox documentados FUERA de la promesa v1.0 en el inventario.
  - nucleus#185 (incidencia): en mitad del lote publicó **GO-2026-5856**
    (crypto/tls, go1.26.4→1.26.5) y el govulncheck bloqueante tumbó el CI —
    bump de toolchain + 2 guards del scaffolder actualizados
    (`scaffoldToolchain` y el smoke test que fijaba el estado sin toolchain).
- **Validación RC estrenada** (quantum#35): submódulo nucleus al RC y el lane
  `orbit-lockstep` verde contra el candidato ANTES del tag — el procedimiento
  A-7 funcionando de verdad. También verde en local (16 pkgs de orbit).
- **nucleus v0.11.0 taggeado** (release-PR #181; para disparar su CI: commit
  vacío a la rama del bot — el close/reopen está bloqueado por el clasificador
  y update-branch fue no-op; LECCIÓN nueva anotada).
- **Quantum 0.3.0 certificado** (este PR): modules.nucleus → v0.11.0,
  **primer set con los TRES pines en tag** (nucleus v0.11.0, orbit v0.3.0,
  quark v1.1.5).
- **Permisos**: Carlos añadió `gh pr merge`/`gh pr update-branch` al allowlist
  (settings.local.json) — las cadenas de merge ya no piden autorización.

**Estado del gate v1.0 tras hoy**: §A completamente resuelto — A-4/A-5b/A-1d/
A-6/A-7 cerrados; A-3/A-5a/A-1a en el tren (borrados v0.12, flip v1.0);
A-2 con WARNs verificados (borrados v0.12). Falta: **v0.12** (borrados
DEP-2026-004..006/008 + rebaseline deliberado), **flip de CORS** en la rama
v1.0.0, y **slice 9** (rehearsal + checklist + tag v1.0.0).

**Foco siguiente sugerido:** (1) housekeeping post-tag en nucleus:
`defaultPinnedFrameworkVersion` v0.9.0→v0.11.0 (lección del handoff, lleva
DOS tags de retraso); (2) los borrados de v0.12 (slice §C-5 segunda mitad +
A-3/A-1a) — mecánicos, sin decisiones; (3) tras v0.12: rama v1.0.0 con el
flip de CORS y el slice 9. Orbit en lockstep: cada RC pasa por el lane antes
del tag (procedimiento probado hoy).

---

### Sesión 2026-07-07 (5ª) — slice 5 prep (A-2): WARN de storage legacy + DEP/MA-2026-005

- **[Nucleus] Mitad v0.11 del slice 5 implementada** (nucleus#180): la
  verificación de A-2 encontró que de las tres deudas, dos ya avisan
  (`admin_rbac_policy_file` con WARN; `NewJSONTask` error-stub) pero las
  claves planas `storage_driver`/`storage_path` se consumían EN SILENCIO
  (fallback de `toStorageConfig` + lecturas de doctor/health).
  `warnLegacyStorageKeys` emite ahora el WARN one-time — solo cuando el valor
  se desvía de los defaults de `DefaultConfig` ("local", "uploads/"), porque
  la mera presencia no es señal (DefaultConfig las pre-puebla). DEP-2026-005 +
  MA-2026-005 formalizan el aviso en el mismo tren de borrado v0.12 que
  DEP-2026-004; el DEP anota los consumidores internos que el borrado debe
  migrar (fallback, seeding de DefaultConfig, doctor/health). 3 tests nuevos;
  freeze verde; fusiones cruzadas limpias contra #177/#178/#179. A-2 sigue
  abierto (cierra con los borrados de v0.12).
- **Con esto, TODO lo restante del gate está bloqueado en Carlos**: los
  borrados de v0.12 requieren que el tren arranque (merges → v0.10.1 → tag
  → v0.11), y los slices 2/4/6 requieren las decisiones A-3/A-1a/b/A-5a
  (briefs en las sesiones 3ª y 4ª). No hay más trabajo ejecutable sin él.
- **Cola de merges (6 PRs verdes)**: nucleus#177 (slice 1), #178 (slice 3),
  #179 (slice 7), #180 (slice 5 prep), quantum#33 (cierres ×5), quantum#34
  (lane lockstep).

**Foco siguiente sugerido:** exclusivamente de Carlos — (1) los 6 merges;
(2) release-PR v0.10.1 → tag → bump/certificación de pines + PR pequeño
cerrando A-7 en el gate; (3) las 3 decisiones (A-3, A-5a, A-1a/b) con los
briefs. Con eso, las sesiones siguientes pueden ejecutar slices 2/4/6 y los
borrados v0.12 sin fricción.

---

### Sesión 2026-07-07 (4ª) — slice 7 ejecutado (fixtures/SLO, A-6) + briefs A-5a y A-1a/b

- **[Nucleus] Slice 7 del §C implementado** (nucleus#179): el SLO de
  fixture-apps (≥95%) llevaba inmedible desde la purga de ejemplos de
  2026-05-16 — pero los ejemplos volvieron (mvc_api, showcase_demo), así que
  el harness recupera perfiles reales: `core-build` (se mantiene), `mvc-api`
  (build+tests de examples/mvc_api contra el árbol actual, `GOWORK=off` para
  medir lo mismo dentro y fuera del workspace de la suite) y `showcase-suite`
  (showcase_demo compilado contra el árbol actual vía go.work efímero, con
  quark/orbit en sus tags). Del trío histórico: admin-heavy obsoleto
  (ADR-019), plugin-heavy vuelve con los ejemplos de plugins (ADR-010 F4).
  RELEASE_CHECKLIST §2 y gate (A-6, slice 7) actualizados. Local: 3/3 (100%).
  Fusión cruzada verificada contra las ramas de #177 y #178 (los tres tocan
  V1_GATE §C) — cualquier orden de merge funciona.
- **[Nucleus] Briefs de decisión A-5a y A-1a/b preparados** (con el de A-3 de
  la 3ª sesión, las TRES decisiones del gate están analizadas; recomendaciones):
  - **A-5a CORS: flip en v1.0** — ADR-013 R4 ya prometió el endurecimiento
    "para un major" y v1.0 es el primero desde entonces; el peligro real
    (credenciales) lo cerró ADR-014, el escape hatch explícito
    (`cors_origins: ["*"]`) existe con tests, y el tren v0.11→v1.0 da la
    ventana de WARN gratis. Waiver = aplazar la promesa un major entero.
  - **A-1a openapi: re-firmar a stdlib** — `WithOpenAPI` estable nombra
    `openapi.DocumentProvider` (experimental) que es `func() *Document`:
    promoverlo congelaría ~40 símbolos del modelo OpenAPI. El adaptador
    `openapi.Handler(provider) http.Handler` YA existe → firma nueva
    `http.Handler` vía el tren (v0.11 añade+depreca, v0.12 borra).
  - **A-1b outbox: excluir de la promesa v1.0** (documentado) — el propio
    inventario lo declara temprano y nadie ha listado qué ergonomía falta;
    promover sin esa lista es congelar a ciegas. Matiz detectado: `pkg/app`
    estable contiene `OutboxConfig` (acople config-estable→transitional
    análogo en especie al de openapi; documentarlo con la exclusión).
- **Cola de merges de Carlos (5 PRs verdes)**: nucleus#177 (slice 1),
  nucleus#178 (slice 3), nucleus#179 (slice 7), quantum#33 (cierres ×4),
  quantum#34 (lane lockstep). Tras los de nucleus: release-PR v0.10.1 → tag
  → bump de pines. Progreso del gate: A-4, A-5b, A-1d, A-6 cerrados en PRs;
  A-7 cierra al fusionar quantum#34; quedan las 3 decisiones (briefs listos).

**Foco siguiente sugerido:** (1) los 5 merges + release-PR v0.10.1 → tag →
certificar pines + PR pequeño en nucleus cerrando A-7 en el gate; (2) las 3
decisiones con los briefs (A-3, A-5a, A-1a/b) — si salen según recomendación,
los slices 2/4/6 son PRs del tren v0.11/v0.12 ejecutables en sesiones
siguientes; (3) tras eso el gate solo tendrá abiertos A-2 (tren programado) y
el slice 9 (rehearsal + tag).

---

### Sesión 2026-07-07 (3ª) — slice 3 ejecutado (CircuitBreaker→stable) + brief de decisión A-3

- **[Nucleus] Slice 3 del §C implementado** (nucleus#178, docs/governance-only):
  `CircuitBreakerSpec`/`CircuitBreakerConfig` promovidos a `stable` — el shape
  de 4 campos es idéntico en las tres capas y el layering es deliberado (la
  superficie de config queda desacoplada de `circuit.Config` y su campo
  test-only `Now`). 5 marcadores del inventario fuera, 8 claves
  `*_circuit_breaker.*` del registro a `stable`, la afirmación "marked
  transitional" de MAIL_GUIDE corregida (habría mentido tras la promoción),
  A-1d y slice 3 marcados en el gate. Freeze verde (los símbolos ya estaban
  en el baseline). **Fusión cruzada verificada**: merge local limpio con la
  rama de #177 (ambos tocan V1_GATE §C y MAIL_GUIDE) — pueden aterrizar en
  cualquier orden.
- **[Nucleus] Brief de decisión A-3 entregado a Carlos** (fichero; el
  clasificador bloqueó crear el issue): `CookieSessionStore.CommitCtx` cifra
  y DESCARTA (`_ = encoded`, session_store_cookie.go:126) — fallo
  arquitectural (el contrato `SessionStore` no ve la respuesta HTTP);
  `session_store=cookie` ni existe como valor de config (error del switch);
  `ErrSessionStoreNotIterable` existe por este store (rompe la pantalla de
  sesiones que Orbit consume). **Recomendación: remove vía el tren de
  deprecación** (v0.11 WARN → v0.12 borrado, el tren de DEP-2026-004).
- **Cola de merges de Carlos (creciendo)**: nucleus#177 (slice 1, 9/9 verde),
  nucleus#178 (slice 3), quantum#33 (cierres de sesión ×3), quantum#34 (lane
  lockstep, 2/2 verde). Tras nucleus#177+#178: release-PR v0.10.1 → tag →
  bump de pines.

**Foco siguiente sugerido:** (1) los 4 merges + release-PR v0.10.1 → tag →
certificar pines; (2) decisión A-3 con el brief (si `remove`: el slice 2 son
dos PRs del tren v0.11/v0.12); (3) sin decisiones pendientes quedan slice 7
(fixtures/SLO, A-6) y el cierre de A-7 en el gate cuando quantum#34 fusione;
slice 4 (openapi/outbox) sí requiere decisión A-1a/b.

---

### Sesión 2026-07-07 (2ª) — lane de lockstep en el CI de la suite (slice 8, A-7)

- **[Paraguas] Job `orbit-lockstep` en `integration.yml`** (quantum#34): el
  plano de integración compilaba orbit pero no corría sus tests — el hueco que
  el gate señala en A-7. El job nuevo ejecuta `go test` de los seis módulos de
  orbit (core, agent, proto, server, quarkbridge, quarkdatasource) resolviendo
  nucleus/quark por el go.work. Procedimiento de RC documentado en el
  comentario del workflow: para validar un release candidate de nucleus antes
  del tag, un PR en quantum bumpea el submódulo nucleus al RC y este lane corre
  los tests de orbit contra él. Verificado en local (los seis módulos pasan,
  además contra el tip de nucleus#177).
- **Pendientes que siguen siendo de Carlos**: fusionar nucleus#177 (9/9 verde
  desde la 1ª sesión), quantum#33 (cierre de la 1ª sesión) y quantum#34 (este
  lane); tras nucleus#177, el release-PR v0.10.1 de release-please → tag →
  bump de pines del paraguas. Decisiones de mantenedor abiertas:
  CookieSessionStore (slice 2), CORS default (A-5a), openapi/outbox (A-1).
- **Fleco anotado**: marcar A-7 cerrado en `V1_GATE.md` (repo nucleus) cuando
  quantum#34 esté fusionado — PR pequeño en nucleus.

**Foco siguiente sugerido:** con los merges hechos, (1) release-PR v0.10.1 →
tag → certificar pines (primer pin limpio de nucleus) + cerrar A-7 en el gate;
(2) slice 2 del §C con la decisión de CookieSessionStore; (3) slice 3
(CircuitBreaker spec) no requiere decisión previa y es el siguiente sin
bloqueo.

---

### Sesión 2026-07-07 — Fase 5 slice 1 ejecutado: PR nucleus#177 listo (CI verde, SIN fusionar)

- **[Nucleus] Slice 1 del §C del gate implementado** (nucleus#177, rama
  `fix/v1-gate-slice1-doc-residuals-mail-headers`, 3 commits, **9/9 checks
  verdes incl. Required Gate — PENDIENTE DE MERGE**, la política de la sesión
  bloqueó la auto-fusión de un PR propio; lo fusiona el responsable):
  - **A-4 cerrado**: `README.md.tmpl` del scaffold ya no promete `/admin` ni
    las claves retiradas `admin_bootstrap_*` (apunta a Orbit y
    `modules.orbit.*`); comentario de `mvc/rbac_policy.csv` sin gate admin
    in-core; `AUTH_GUIDE.md:531` usa el campo real `cfg.RBACPolicyFile` (el
    fantasma `AuthzPolicyPath` era N-4). Los dos greps del "closed when"
    devuelven vacío.
  - **A-5b cerrado (rama sanitize, como rechazo)**: `validateMessage` rechaza
    CR/LF en claves/valores de `mail.Message.Headers` y claves en blanco
    (misma disciplina que From/Subject; antes un valor con `\r\nBcc:` interior
    inyectaba cabeceras — TrimSpace solo limpia extremos). El emisor además
    trimea claves. Godoc + MAIL_GUIDE documentan el contrato, con el matiz
    honesto de que un `Sender` custom de `RegisterProvider` no pasa por la
    validación (emite él mismo). Test de mesa (7 casos). `go test ./...` y
    freeze de contrato verdes en local y en CI.
  - `V1_GATE.md` actualizado en el mismo PR: A-4 ✅, ítem mail de A-5 ✅,
    slice 1 marcado en §C. **CORS (A-5a) sigue abierto** — decisión de
    mantenedor.
- **[Paraguas] Sin cambios de pines**: nucleus#177 no está fusionado; cuando
  lo esté, el `fix(mail)` hará que release-please abra el release-PR de
  **v0.10.1** en nucleus. Decidir entonces: fusionar ese release-PR (tag) y
  subir `workspace_pins.nucleus` (idealmente al tag v0.10.1 — primer pin
  limpio de nucleus), o bump a pseudo-version si se deja el tag para después.
- Matiz de auditoría de arranque: el checkout local del submódulo nucleus
  quedó un commit por delante del pin (el merge de #176) — deliberado en el
  cierre anterior; el pin registrado sigue siendo `1d2adac8`.

**Foco siguiente sugerido:** (1) fusionar nucleus#177 (verde) y, con el
release-PR v0.10.1 de release-please, decidir tag + bump de pin del paraguas;
(2) slice 2 del §C — decisión de mantenedor sobre `CookieSessionStore`
(wire/deprecate/remove) e implementación (M); (3) en cola: slice 3
(CircuitBreaker spec), decisión CORS (A-5a), disposición openapi/outbox (A-1).

---

### Sesión 2026-07-06 (noche) — Fase 5 ABIERTA: gate v1.0 de Nucleus redactado

- **[Nucleus] `docs/V1_GATE.md` ✅** (nucleus#176): el checklist cualitativo
  verificable del v1.0, con la disciplina del precedente de Quark. Base: barrido
  de inventario/baseline (17 pkgs estables, 1.492 símbolos congelados),
  follow-ups ADR-001..020, governance, el audit de junio RE-VERIFICADO contra
  el árbol de hoy (D-WEB cerrado por #164–#167; S-1/N-4 reducidos a restos), y
  la superficie exacta que consume Orbit (14 paquetes; Tier-1 explícito).
- **§A, 7 bloqueantes**: disposición de los 4 pkgs no-stable (el duro: builder
  estable acoplado a `openapi.DocumentProvider` experimental); deuda de
  deprecación (DEP-2026-004 fija el tren **v0.11 → v0.12 → v1.0**);
  `CookieSessionStore` (P1 vivo: wire/deprecate/remove — decisión de
  mantenedor); restos de docs (scaffold README.tmpl, AUTH_GUIDE:531); defaults
  de seguridad en el major (CORS — v1.0 ES el major de ADR-013 R4; mail
  headers); SLO de fixtures inmedible (perfiles retirados 2026-05-16, nunca
  repuestos); arnés lockstep (el CI de la suite COMPILA orbit pero no corre sus
  TESTS contra el RC — falta ese lane).
- **§B** waivers candidatos (observability→v1.2, ADR-018 driver instr.,
  campos reservados ADR-010, unificación de generadores, Oracle quoting).
  **§C** plan de 9 slices ordenado. Anclado desde RELEASE_CHECKLIST.md.
- Sin bump de pines (docs-only en nucleus).

**Foco siguiente sugerido:** ejecutar §C en orden — slice 1 (restos de docs +
mail headers, S) y slice 2 (decisión CookieSessionStore, M) son el arranque
natural; las decisiones de mantenedor requeridas: CookieSessionStore
(wire/deprecate/remove), CORS default en v1.0 (in/waiver), y disposición de
openapi/outbox.

---

### Sesión 2026-07-06 (tarde) — rediseño de orbit/ui + métricas + Quantum 0.2.0

- **[Orbit] Rediseño completo de la UI del admin server ✅** (orbit#15, 3
  commits): sistema de tokens de dos temas del handoff de diseño
  (`design_handoff_orbit_redesign`), shell 212px con nav agrupada, 11 pantallas
  (Node detail/Health/Metrics/Access control/Audit log nuevas), política de
  datos honestos (nada simulado; huecos declarados). Verificado en vivo con la
  pila completa (admin-server + showcase como agente + tráfico real).
- **[Orbit] Métricas de host end-to-end ✅** (mismo PR): `HostMetrics` en el
  Heartbeat (proto), sampler stdlib en el agente (CPU getrusage, heap/
  goroutines/GC, RSS Linux-only, pool BD vía extensión), server → `ListNodes`,
  UI con ventana rodante de 60 muestras. Cierra el hueco nº1 del PR. Quedan:
  RPCs RBAC/audit, row count SQL.
- **[Orbit] v0.3.0 publicado** (release-PR #11; #13 obsoleto cerrado).
- **[Nucleus] Pata fleet opcional del showcase ✅** (nucleus#175): tras build
  tag `fleet` + `ORBIT_ADMIN_ENDPOINT` — el build por defecto sigue resolviendo
  standalone (orbit/agent y orbit/proto siguen sin tags: pendiente añadirlos a
  release-please si la pata fleet debe salir del workspace).
- **[Paraguas] Quantum 0.2.0 certificado** (este PR): modules.orbit → v0.3.0,
  pin de orbit = TAG (primer pin limpio), nucleus pin = v0.10.0 + housekeeping
  de examples/ci, quark restaurado a su pin v1.1.5 (su main lleva +37 commits
  propios sin tag — drift normal de producto).

**Foco siguiente sugerido:** Fase 5 (inventario del gate v1.0 de Nucleus);
opcionales: tags de orbit/agent+proto en release-please, RPCs RBAC/audit para
las pantallas Manage, row count en SqlStatementEvent.

---

### Sesión 2026-07-06 — Pages standalone retirados: Fase 2 COMPLETA

- **Runbook `docs/RETIRE_PRODUCT_PAGES.md` ejecutado** (orbit#14, quark#234,
  nucleus#174): los tres Pages standalone publican ahora un redirector al sitio
  unificado — raíz con meta-refresh + canonical, rutas profundas mapeadas por
  `404.html` (`/quark/docs/<rest>` → `/quantum/quark/<rest>`, etc.). La fuente
  Docusaurus sigue en cada repo y construible en local (QADR-0003); en nucleus
  el build de Docusaurus se conserva como validación de PRs. Verificado en vivo
  (raíz + ruta profunda + destino 200) en los tres.
- **Lección Pages** (anotada en el runbook): el deploy de orbit falló 3× con
  `deployment_failed` genérico — el site estaba corrupto en el lado de GitHub
  (`status: null`); recrearlo (`DELETE /pages` + `POST /pages
  {build_type: workflow}`) lo resolvió.
- **Fleco de release-please cerrado**: `workflow_dispatch` añadido a los
  release-please.yml de quark, nucleus y orbit (mismos PRs).
- Con esto, **Fases 0–4 completas**. Único arco abierto: **Fase 5**
  (convergencia v1.0, QADR-0005).

**Foco siguiente sugerido:** arrancar la Fase 5 con una sesión de producto en
nucleus: inventario del gate de v1.0 (superficies sin congelar, deuda de
contrato, plan de slices), con Orbit en lockstep como arnés (el freeze del
contrato `datasource` cae en el v1.0 de Orbit).

---

### Sesión 2026-07-03 (tarde) — Fase 3 completa: tags reales + Quantum 0.1.0 certificado

- **release-please instalado** en Nucleus (#171) y Orbit (#5, multi-módulo con
  tags por componente `quarkbridge/vX`, `quarkdatasource/vX`; `release-as:
  0.1.0` para el primer corte de los puentes — el default 1.0.0 falsearía
  madurez, #9). Hizo falta habilitar "Actions can create PRs" en ambos repos.
- **Tags publicados**: nucleus **v0.10.0** (#172; el minor lo exige el clean
  break del admin), orbit **v0.2.0** (#8), **quarkbridge/v0.1.0** (#6),
  **quarkdatasource/v0.1.0** (#12; la rama del bot se rebasó a mano tras un
  conflicto de manifest con #6 — GitHub no reabre PRs con branch force-pushed,
  se recreó como #12 con la label `autorelease: pending`).
- **Deps a tags reales** (orbit#10): quarkbridge→nucleus v0.10.0;
  quarkdatasource suelta el `replace` intra-repo→orbit v0.2.0. **Ambos puentes
  y el showcase resuelven standalone por proxy** (GOWORK=off verificado).
- **Quantum 0.1.0 certificado** (PR del paraguas de esta sesión): `modules.*` a
  v0.10.0/v0.2.0, `quantum: 0.1.0`, `status: certified`; pines con dos matices
  housekeeping documentados en versions.yaml (nucleus = v0.10.0 + repin del
  ejemplo; orbit = commit de quarkdatasource/v0.1.0). El release-PR rodante
  orbit#11 (root 0.2.1 por el quirk de exclude-paths en root, 17.3.0) queda
  abierto a propósito.
- Lecciones release-please anotadas: los PRs del bot no disparan CI
  (GITHUB_TOKEN) → close/reopen o merge tras rebase manual; sin
  `workflow_dispatch` en el workflow copiado de Quark.

**Foco siguiente sugerido:** (1) retirar Pages standalone de Quark/Nucleus
(`docs/RETIRE_PRODUCT_PAGES.md`) — último fleco de Fase 2; (2) Fase 5, el arco
largo: Nucleus→v1.0 primero, Orbit en lockstep (QADR-0005); (3) considerar
`workflow_dispatch` en los release-please.yml de los tres repos.

---

### Sesión 2026-07-03 — showcase de Fase 4 ✅ (QADR-0006 demostrado en vivo)

- **[Nucleus] `examples/showcase_demo` ✅ MERGEADO** (nucleus#170): repuesto el
  showcase de la suite (ROADMAP Fase 4, "reponer"; el original se borró en
  `2aa216dc`), reconstruido sobre el stack actual — app Nucleus (builder fluent
  + módulos) con dominio en Quark y Orbit montado, **ambos puentes cableados**:
  el módulo `shop` deriva en `OnStart` un cliente con `quarkbridge` (Caso 1) y
  Data Studio corre sobre `quarkdatasource` vía `orbit.Config.DataSource`
  (Caso 2). `go.mod` propio (Quark/Orbit fuera del graph del framework); dos
  modelos (`Author`, `Article` belongs_to); sqlite compartido; `WithOpenAuthz()`
  para la API pública del demo. **Validado EN VIVO**: el snapshot del feed live
  muestra el SQL de Quark con `request_id` y args redactados; Data Studio
  cataloga con counts reales, sirve el envelope correcto, y un registro creado
  en `/admin` aparece por la API pública. Nucleus main = `d9656cb8`.
- **[Paraguas] Coordinación** (este PR): submódulo nucleus → `d9656cb8`,
  `workspace_pins.nucleus` actualizado, `./nucleus/examples/showcase_demo`
  añadido al `go.work` y al CI de integración (9 módulos) → **el CI ejerce los
  tres productos juntos: los dos criterios de Fase 4 quedan cumplidos**.
- Matiz documentado (go.mod/README del showcase): el ejemplo se construye desde
  el workspace de la suite; la resolución standalone por proxy se desbloquea
  cuando Orbit corte su primer tag (el `replace` intra-repo de quarkdatasource
  no propaga a consumidores).

**Foco siguiente sugerido:**
1. **Fase 3 (3)-(4)** — el único bloque grande abierto: release-please en
   Nucleus/Orbit; primer tag de Nucleus (línea EmitSQL+showcase) y de Orbit
   (datasource+puentes) → limpiar `workspace_pins` a tags, repin de
   `quarkbridge/quarkdatasource/showcase` a tags, certificar **Quantum 0.1.0**
   (`status` de `versions.yaml`).
2. Pendiente menor de Fase 2: retirar Pages standalone de Quark/Nucleus
   (`docs/RETIRE_PRODUCT_PAGES.md`).
3. Con 0.1.0 certificado, la Fase 5 (convergencia v1.0) queda como el arco
   largo (QADR-0005: Nucleus primero, Orbit en lockstep; freeze de `datasource`
   en el v1.0 de Orbit).

---

### Sesión 2026-07-02/03 — Caso 2 cerrado (quarkdatasource) + coordinación

**QADR-0006 queda implementado al completo** (ambos casos en el main de orbit);
el paraguas se puso al día en esta sesión:

- **[Orbit] `orbit/quarkdatasource` ✅ MERGEADO** (orbit#4) — módulo opt-in con
  `go.mod` propio que implementa el contrato `datasource` sobre un cliente Quark:
  **Data Studio navega/edita modelos Quark** (Caso 2). Catálogo desde los tags
  Quark de los structs (`GetModelMetaByType`, la fuente de sus migraciones), no
  introspección de tablas. Registro **genérico por modelo**
  (`quarkdatasource.Register[T]`) porque la API de Quark es tipada
  (`quark.For[T]`, sin binding en runtime). Search multi-columna como un grupo
  OR vía el AST (`WhereExpr`); counts reales; `UpdateMap` (escribe zero values);
  soft/hard delete de Quark; PK compuesta → catalogado read-only. Tenancy vía
  `*quark.TenantRouter` como provider + `WithTenantColumn`. Cableado:
  `orbit.Config.DataSource` (Go-only) — nil = adaptador Nucleus por defecto.
- **[Orbit] Contrato validado con 2ª implementación** (mismo PR, ADR-001
  actualizado): **una corrección** — el contrato salió de `internal/` a
  **`orbit/datasource`** (público; la app debe nombrarlo para inyectar el
  adaptador; se congela en v1.0 de Orbit) — y tres encajes sin forzar (D1
  composite-PK→read-only; D2 absorbe `quark.Nullable`; D3 alias ignorado,
  documentado). El contrato NO quedó con forma de Nucleus. Orbit main = `728c79e`.
- **[Paraguas] Coordinación** (esta sesión, PR en quantum): submódulo orbit →
  `728c79e`, `workspace_pins.orbit` actualizado, `./orbit/quarkdatasource` añadido
  al `go.work` y al CI de integración (8 módulos).

**Foco siguiente sugerido:**
1. **Demo/showcase de Fase 4**: app Nucleus+Quark+Orbit exhibiendo AMBOS casos
   (quarkbridge alimentando el feed live + Data Studio sobre modelos Quark vía
   `Config.DataSource`). Ya no hay prerrequisitos técnicos; valida QADR-0006
   end-to-end y es el "hecho cuando" de la Fase 4 junto al CI que lo ejerza.
2. **Fase 3 (3)-(4)**: release-please en Nucleus/Orbit; primer tag de Nucleus
   (la línea con EmitSQL) → limpiar `workspace_pins` a tags, repin de
   `quarkbridge/go.mod` y `quarkdatasource/go.mod`, certificar **Quantum 0.1.0**.
3. Pendiente menor de Fase 2: retirar Pages standalone de Quark/Nucleus
   (`docs/RETIRE_PRODUCT_PAGES.md`; toca repos de producto).

---

### Sesión 2026-07-02 — QADR-0006 completo en los productos + coordinación del paraguas

Las TRES piezas de la integración Quark↔Orbit quedaron **fusionadas en los mains
de producto**, y el paraguas se puso al día:

- **[Nucleus] `EventBus.EmitSQL` ✅ MERGEADO** (nucleus#168, ADR-020) — el ingest
  SQL público en la superficie del `Runtime`. De camino, **nucleus#169**: bump de
  seguridad `jackc/pgx/v5 v5.5.5→v5.9.2` (GO-2026-5004, el Required Gate de su CI
  estaba en rojo por la advisory; era preexistente, se aisló en PR propio).
  Nucleus main = `a46fad0e`.
- **[Orbit] `orbit/quarkbridge` ✅ MERGEADO** (orbit#2) — módulo opt-in con
  `go.mod` propio: `quark.Middleware` ctx-aware que cronometra cada sentencia,
  mapea a `nucleus.SQLEvent` (correlación RequestID/TraceID/UserID desde el ctx
  vía `pkg/observe`) y publica con `EmitSQL`. Redacción por defecto espejo de la
  de Nucleus; `WithRedaction(IncludeArgs)` opt-in. **Caso 1 de QADR-0006 cerrado**
  (falta solo la demo viva de Fase 4). OTel sigue siendo complementario.
- **[Orbit] Data Studio agnóstico ✅ MERGEADO** (orbit#3, su ADR-001 → accepted) —
  contrato `internal/datasource` (`ModelSource`/`RecordStore`/`DataSource` +
  `ModelInfo`/`FieldInfo`/`Query`/`Page`/`Record`) + adaptador Nucleus;
  `NewPanel(src datasource.DataSource, …)`; O1–O3 confirmados (O3: el envelope
  `Page` serializa idéntico al `PaginatedResult` nativo, SPA intacta, con test).
  Sin doble registro. Excepciones documentadas: field-meta editor
  (`cfg.SchemaRegistry`) y el sink del feed live. **Prerrequisito del Caso 2
  listo**: el adaptador Quark implementará el mismo contrato. Orbit main = `782b388`.
- **[Paraguas] Coordinación** (esta sesión, PR en quantum): submódulos bumpeados a
  esos mains, `workspace_pins` actualizados (pseudo-versions nuevas; `modules.*`
  sin cambio — nada taggeado aún), `./orbit/quarkbridge` añadido al `go.work` y al
  patrón del CI de integración (7 módulos).

**Foco siguiente sugerido:**
1. **Adaptador Quark del Caso 2** (repo orbit; módulo aparte tipo quarkbridge que
   implemente `datasource.DataSource` sobre `*quark.Client` + introspección) — el
   contrato ya está congelable y probado con la implementación Nucleus.
2. **Fase 3 (3)-(4)**: release-please en Nucleus/Orbit y el primer tag de la línea
   nueva de Nucleus → limpiar `workspace_pins` a tags, repin de
   `quarkbridge/go.mod` a tag, certificar **Quantum 0.1.0** (`status` de
   `versions.yaml`).
3. La **demo Fase 4** (app Nucleus+Quark+Orbit con el puente cableado) valida el
   Caso 1 end-to-end en cuanto exista el ejemplo.

---

### Sesión 2026-07-01 (código) — ingest SQL público en Nucleus ✅ (PR abierto, sin fusionar)

Se implementó el work-item **desbloqueante** de §5 (el que habilita el Caso 1 de
[QADR-0006](../../docs/adr/QADR-0006-integracion-quark-orbit.md)). Trabajo en el
repo de PRODUCTO **Nucleus** (no en el paraguas):

- **`EventBus.EmitSQL(SQLEvent)`** — lado emisor que faltaba en la superficie del
  `Runtime`. La `EventBus` que devuelve `Runtime.Observability()` era solo
  suscripción; ahora un productor externo (p. ej. `orbit/quarkbridge`) puede
  publicar una sentencia SQL en el mismo bus que Orbit ya drena vía
  `SubscribeSQL()`. Helper `fromSQLEvent` (inverso de `toSQLEvent`); método
  **aditivo** (nadie implementa la interfaz, solo la recibe) → sin ruptura.
  Registrado en Nucleus como **ADR-020**; baseline de contrato regenerado.
- **PR: `jcsvwinston/nucleus` #168** (rama `feat/eventbus-emitsql-ingest`), **sin
  fusionar**. Pasó `/code-review` (un hallazgo menor —fuga en bus nil— corregido).
- **Superficie del `Runtime` → gate de v1.0 de Nucleus** ([QADR-0005]). Secuenciación:
  no arranca `orbit/quarkbridge` hasta que #168 se fusione y Nucleus taggee la línea
  que lo habilita (hoy Orbit fija Nucleus por pseudo-version, ver `versions.yaml`).

**Foco siguiente sugerido:** fusionar #168 y decidir la ruta de tag/pin
(QADR-0004/0005); en paralelo, el desacople `datasource` de Orbit (orbit/ADR-001),
independiente del ingest. `orbit/quarkbridge` queda bloqueado hasta el tag.

Aparte, esta sesión **fijó a `main` del paraguas** las QADR-0005/0006 y las
referencias del roadmap/índice que la sesión de planificación había dejado sin
commitear.

### Sesión 2026-07-01 — decisiones de secuenciación e integración (planificación, sin código)

Sesión de análisis/planificación (Cowork). NO se tocó código de productos; se
redactaron decisiones y se dejó el foco listo para la siguiente sesión de código.
Registrado en:

- **[QADR-0005](../../docs/adr/QADR-0005-secuenciacion-convergencia.md)** —
  Secuenciación: **Nucleus a v1.0 primero**, Orbit en lockstep como arnés de
  dogfooding; Quark converge por el paraguas (no entra en el grafo de
  dependencias). Es el orden de trabajo hacia Quantum 1.0 (Fase 5).
- **[QADR-0006](../../docs/adr/QADR-0006-integracion-quark-orbit.md)** —
  Integración Quark↔Orbit: feed SQL en tiempo real (puente `quark.Middleware` →
  bus de Nucleus; OTel en paralelo) y Data Studio sobre Quark. Encaja en Fase 4.
- **[orbit/ADR-001](../../orbit/docs/adrs/ADR-001-datastudio-agnostic-datasource.md)**
  — Data Studio agnóstico del origen (contrato `datasource`); decisión interna de
  Orbit, se congela en su v1.0.

**Foco propuesto para la próxima sesión de código** (tres work-items en §5, todos
en repos de PRODUCTO, no aquí): el desbloqueante es el **ingest SQL público en
Nucleus** (habilita el Caso 1); el desacople `datasource` de Orbit (ADR-001) puede
ir en paralelo. Nada de esto bloquea la Fase 2/3 en curso.

---

**Contexto previo (cierre 2026-06-27):**

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
  - **Hueco de CI ✅** (PR #23): `.github/workflows/website-ci.yml` construye
    `website/` (mismos pasos que deploy.yml: checkout con submódulos, Node 20,
    `npm ci`, `npm run build`; sin publicar) en PRs que toquen `website/` o
    `versions.yaml`; verde en CI. Antes solo `deploy.yml` (en push a main) lo
    construía → un sitio roto solo se veía al desplegar tras merge.

## 4. Las fases (resumen; el detalle y el "hecho cuando" están en docs/ROADMAP.md)

| Fase | Objetivo | Hecho cuando |
|---|---|---|
| 1 | **Identidad/marca Quantum**, portada de la suite | Front page que nombra y enlaza los tres pilares y aclara el uso standalone de Quark |
| 2 | **Docs unificadas**: Docusaurus multi-instancia en `website/`, product switcher, doble selector de versión, un solo deploy en `/quantum/` | Un sitio sirve las tres docs bajo una marca, sin sacar la fuente de cada repo |
| 3 | **Convenciones + primera release**: `release-please` a Nucleus/Orbit, instancia de docs de Orbit, **Quantum 0.1.0** con CI de integración | Set Quantum reproducible y verificado por CI |
| 4 | **Integración demostrada**: ejemplo Nucleus+Quark+Orbit + CI que ejerce los tres | Hay un ejemplo ejecutable y CI del set |
| 5 | **Convergencia Quantum 1.0**: Nucleus y Orbit a v1.0, régimen de majors en lockstep | Los tres en major 1 bajo un manifiesto Quantum 1.0 |

## 5. Pendientes técnicos anotados (revísalos cuando apliquen)

**Integración Quark↔Orbit y convergencia (QADR-0005/0006, orbit/ADR-001; toca repos de PRODUCTO):**

- **[Nucleus] Ingest SQL público ✅ HECHO** (2026-07-01, nucleus#168, ADR-020):
  `EventBus.EmitSQL(SQLEvent)` en la superficie del `Runtime`. [QADR-0006]
- **[Orbit] `orbit/quarkbridge` ✅ HECHO** (2026-07-02, orbit#2): módulo opt-in,
  `quark.Middleware` ctx-aware → `EmitSQL`. Redacción por defecto. Queda su
  validación end-to-end en la demo de Fase 4. [QADR-0006, Caso 1]
- **[Orbit] Desacople `datasource` de Data Studio ✅ HECHO** (2026-07-02, orbit#3,
  ADR-001 accepted): contrato neutral + adaptador Nucleus; O1–O3 confirmados, SPA
  intacta. [QADR-0006, Caso 2]
- **[Orbit] `orbit/quarkdatasource` ✅ HECHO** (2026-07-02, orbit#4): 2ª
  implementación del contrato — Data Studio sobre modelos Quark, inyectado vía
  `orbit.Config.DataSource`. Contrato movido de `internal/` a `orbit/datasource`
  (público) como corrección de la validación; se congela en el v1.0 de Orbit.
  Queda su validación end-to-end en la demo de Fase 4. [QADR-0006, Caso 2]
- **[Suite] Secuenciación** (sigue vigente): no arrancar el freeze de Orbit sobre
  la pseudo-version de Nucleus; Nucleus→v1.0 primero, Orbit en lockstep. Las
  interfaces `datasource` se congelan en el v1.0 de Orbit. [QADR-0005]

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
  reescritos en el ensamblaje (PR #20). CI de PR: `website-ci.yml` (PR #23) construye
  el sitio en PRs que lo toquen. Pendiente: retirar los Pages standalone de
  Quark/Nucleus + redirects (plan en `docs/RETIRE_PRODUCT_PAGES.md`; toca repos de
  producto). `cd website && npm install && npm run build`.

## 6. Cómo cerrar la sesión

Actualiza el §3 de este archivo (estado al cierre) con lo que avanzaste y el
próximo foco, para no romper el contexto a la siguiente sesión. Si cambia una
decisión de coordinación, abre un QADR sucesor (no reabras uno aceptado).
