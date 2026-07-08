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

## 3. Estado al cierre (2026-07-07)

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
