# Cierre de la 7ª ronda — «cierre definitivo» (Quantum 1.8.0)

Fecha: 2026-07-20. Ejecutor: sesión de Claude Code (19ª sesión de la suite), con
4 agentes paralelos en worktrees dedicados (F1-nucleus, F1-quark, F1-orbit +
F3, F4, F5) y el tren de releases, la certificación y este cierre en la sesión
principal. Plan de referencia: `PLAN_EJECUCION_7_FINAL.md`; auditoría:
`REAUDITORIA7_QUANTUM.md` (19-jul).

**Set certificado Quantum 1.8.0** — quark `v1.3.3` (e4a07017) · nucleus
`v1.4.0` (cdf175ac) · orbit `v1.4.4` (5a4d75ff; agent/v0.5.4, server/v0.8.4,
quarkbridge/v0.3.4, quarkdatasource/v0.2.6, proto/v0.4.1) · quantum-app
`v0.1.0`. `declared_lags` **vacío** por primera vez desde que existe la
sección.

---

## 1. DoD del plan, punto por punto

### 1.1 Backlog de la 7ª a CERO

| Hallazgo | Cierre | PR (fusionado) | Evidencia (comando + EXIT) |
|---|---|---|---|
| NU7-1 (release notes sin sección de la versión actual) | Guard de contenido `check_version_claims.sh` ampliado: exige `## v<actual>`; negativo probado | nucleus#222 | positivo EXIT=0; sin `## v1.3.3` → «claims v1.3.3 … but has no section» EXIT=1. **Mordió 3 veces en producción durante el tren** (quark#260, nucleus#224, orbit#115: las tres secciones se redactaron porque los guards las exigieron) |
| NU7-2 (mass-assignment de PK, secuela de NU6-1) | `RejectClientPK` opt-in por modelo + `model.ErrClientAssignedPK`; el check corre ANTES de hooks (BeforeCreate sigue asignando en servidor) | nucleus#222 | tests unit + live EXIT=0 |
| NU7-3 (rama TOP 1 jamás ejecutada contra MSSQL real) | Fixture de schema admin en la lane MSSQL; rojo-sin-fix demostrado | nucleus#222 | restaurando `LIMIT 1` pre-fix → `mssql: Incorrect syntax near 'LIMIT'`; con fix PASS contra mssql/server:2022 real |
| NU7-4 (TestInstrumentLive fuera de toda lane) | Filtro de la lane DB Matrix Required ampliado | nucleus#222 | `=== RUN` visible en la lane, no skip, PASS contra postgres:16 |
| QM7-1 (showcase_demo pinaba un set prehistórico) | Re-pin al set certificado + `check_example_pins.sh` (pins == último tag publicado, consultado EN VIVO con ls-remote — sin fichero local fosilizable) + smoke por HTTP en el gate requerido | nucleus#222 | guard positivo EXIT=0 (6 pins); doctorado con quark v1.1.5 → EXIT=1; smoke 2 casos asertados por HTTP |
| QK7-1 (fuga de conexión en pánico del driver, rls_native) | Guard de ownership en los 3 caminos; cleanup en goroutine aparte (los RLocks internos de database/sql convertían el cleanup in-situ en deadlock); ExecContext también era vulnerable y se corrigió | quark#259 | rojo-sin-fix: 3 subtests FAIL «pool exhausted» → verde; `-race` EXIT=0 |
| QK7-2 (-race ausente + 2 tests de batch fuera de presupuesto) | Lane `Race (-short)` con `-timeout 15m`; límites propios de los 2 tests medidos con `-json` (33.9s y 16.5s bajo race) | quark#259 | lane verde en CI |
| QK7-3 (errores enmascarados como ErrNoRows) | Driver interno `quark-internal-row-error` que acuña `*sql.Rows` cuyo Scan devuelve el error real con prefijo de etapa; `errors.Is/As` intactos | quark#259 | rojo-sin-fix: Scan devolvía nil con el driver fake → verde con fix |
| OR7-1 (release notes v1.4.3 ausentes) | Sección redactada + guard de contenido `check_docs_version_claims.sh` | orbit#113 | positivo EXIT=0; sin sección → EXIT=1 |
| OR7-2 (WARN de sospecha global pero por-endpoint en el mensaje) | Reset SOLO del endpoint activo (`delete(noFrameCycles, endpoint)`): un frame aceptado en A no invalida la evidencia de B | orbit#113 | test determinista ciclo-a-ciclo (0.03s); rojo-sin-fix nombra a B con evidencia de A; verde también con `-race` |
| OR7-3 (linter no vetaba IDs de hallazgo) | Regla `\b(OR|QK|NU|QM)[0-9]+-[0-9]+\b` en el linter de voz; barrido previo: 0 apariciones reales | orbit#113 | positivo EXIT=0; probe `OR6-1` → EXIT=1 |
| QM7-2 (conteo 17-OK+resumen) | Conteos de este cierre copiados de las tablas de las lanes; regla en runbook §3.6 y en `suite-integral.sh` (cuenta solo guards ejecutados) | quantum#78 | tabla «guards registrados: 14 · ejecutados: 14» impresa por la lane |
| QM7-3 (tag v1.7.2 no contenía quantum#75) | Procedimiento nuevo aplicado: **el tag de suite se corta tras el ÚLTIMO PR de la ronda** (runbook §3.5) | quantum#78 (runbook) + este cierre | v1.8.0 tageado sobre el merge del PR de certificación, último de la ronda |
| QM7-4 (sidebars espejadas sin guard de sincronía) | `check_sidebar_sync.sh`: sets de ids espejo↔producto pinado, misma heurística en ambos lados; website-ci dispara también en los gitlinks (el re-pin es cuando aparece la deriva) | quantum#77 | positivo EXIT=0; id inyectado en el sidebar del producto → «página servida pero invisible» EXIT=1 |
| QM7-5 (comentario fósil 'warn' en website-ci.yml:8) | Comentario alineado con la realidad (onBrokenLinks: 'throw' desde la 6ª) | quantum#77 | — |
| QM7-6 (quarkdatasource pinaba root v1.4.1, invisible por la excepción root-edge) | Bump a v1.4.3 en el PR de alineación del tren | orbit#116 | `check_internal_pins.sh` EXIT=0 |

Además, regla espejo de OR7-3 en el linter del paraguas sobre el HTML SERVIDO
(quantum#77): positivo 0 fugas EXIT=0; probe con `QK5-2`/`NU7-1` → EXIT=1.

### 1.2 Fase 2 — Jobs y Webhooks de nucleus EJECUTÁNDOSE (v1.4.0)

nucleus#223 (feat, minor). `JobRegistry`/`WebhookRegistry` ganan `Register`
real — aditivo puro sobre la forma congelada (waiver W3 de ADR-013,
parcialmente resuelto; Migrations queda WARN-por-diseño ADR-006):

- Jobs sobre `pkg/tasks` (memory default / asynq con `jobs_redis_url`), CERO
  schedulers nuevos. `Every`/`Cron` validado en el registro (5-field o
  descriptor, traducido por provider — misma semántica en ambos), `Timeout`,
  `Singleton`. Registro inválido = **boot falla**.
- Webhooks como rutas reales en `<webhooks_prefix>/<módulo><path>`: allow-list
  de métodos (405), tope de body (413), HMAC-SHA256 en tiempo constante sobre
  `X-Nucleus-Signature` (401 ANTES del handler; helper `SignWebhookBody`),
  exención CSRF automática del prefijo, WARN de arranque si no hay Secret.
- `grep -rn "NOT EXECUTED" pkg/nucleus/` → **0**; los WARN de readiness de
  Jobs/Webhooks eliminados porque dejaron de ser verdad.
- **Bug real de la suite destapado por el estreno** (lección NU5-4 aplicada):
  el `Manager.Run` del provider asynq usaba `asynq.Server.Run`, que bloquea en
  una espera de señales del SO que un Shutdown externo no desbloquea — el
  worker embebido era IMPARABLE por API. Commit `fix(tasks)` separado
  (Start/Shutdown dirigidos por ctx o Close). Rojo-sin-fix: 2 pins cuelgan 15s
  y fallan EXIT=1; verde con fix `ok … 2.412s`.
- Gates: build/vet/tests completos EXIT=0; freeze 6/6 PASS (23 adiciones, 0
  bajas); bodycheck/coverage/version-claims EXIT=0; E2E por la superficie
  pública `Run` (boot real con `csrf_enabled`, job ejecutándose ≥2 veces,
  webhook firmado 200 / mal firmado 401 / método 405 con handler intacto,
  SIGTERM → `Run()==nil`); lane requerida nueva `jobs-redis` (redis:7 real).

### 1.3 Fase 3 — quark#252 CERRADO (por implementación, con fix raíz)

quark#261 (`Closes #252`, fusionado; issue CLOSED). El spike contra PG 16 real
desmontó la premisa del issue: solo `Create`/`Update` (vía saveAny) pasaban el
ctx del caller sin acotar — sonda de 72 ops: **11 sesiones idle-in-transaction
= exactamente los 11 Create**; DDL posterior bloqueado; y de propina
**read-your-writes roto** (la fila del Create invisible a lecturas del mismo
ctx), que desmentía la guía publicada. Fix: mismo patrón per-op que sus ~15
hermanos. Opción 1 del issue (commit-on-Close vía driver) prototipada y
VIABLE, aparcada con criterio; opción 2 (timeout+commit forzado) descartada
con evidencia (mata el cursor a mitad de lectura). Mínimo del issue cumplido:
troubleshooting «A migration or DDL statement hangs» en la guía, en voz de
producto. Rojo-sin-fix: `5 implicit transaction(s) still idle-in-transaction`
(10s) → verde 0.02s. Suite RLS completa contra PG real EXIT=0, también bajo
`-race`.

### 1.4 Fase 4 — quantum-app (consumidor externo real) + suite-manifest

Repo nuevo `github.com/jcsvwinston/quantum-app` (decisión de Carlos; sin
nombre de marketing). quantum-app#1 (bootstrap + app + E2E + manifest +
tutorial) y #2 (bump al set 1.8.0), ambos verdes y fusionados; tag `v0.1.0`.

- **OR-1 imposible por construcción**: requires explícitos del set certificado
  resueltos por el module proxy; `GOWORK=off` + `check_no_workspace.sh` en CI
  (negativo probado: go.work creado → EXIT=1).
- **E2E Docker 7/7** (mismo compose local y CI), la banda nunca-ejecutada del
  §4 de la auditoría ejecutada POR PRIMERA VEZ — tabla de estrenos:
  sesiones Redis ✅ · S3/MinIO ⚠️ (bug de la suite, abajo) · SMTP real ✅ ·
  outbox-PG transaccional con bridge webhook ✅ · cadena
  quark→quarkbridge→panel orbit + feed vivo ✅ (con observación) · multi-base
  PG+MySQL por alias + **réplica física PG** (streaming, `WithReplicas` de
  quark; nucleus no tiene superficie de réplica — verificado y clasificado) ✅
  · CRUD quark contra PG y MySQL reales ✅.
- **suite-manifest.yaml**: denominador GENERADO desde los inventarios
  existentes a los tags pinados (quark apisurface.json 670 símbolos, nucleus
  API_CONTRACT_INVENTORY 21 paquetes, orbit api_exported_symbols 98) — **789
  ítems: 67 covered con evidencia puntual, 552 not-covered con razón, 170
  out-of-scope**. Gate con negativo probado (437 sin clasificar → EXIT=1) que
  además caza huérfanos y pin drift — **el drift real del bump al set 1.8.0 lo
  cazó en producción**.
- Tutorial del integrador (`docs/TUTORIAL.md`), voz de producto, 0 jerga.
- Transporte real del feed vivo verificado por inspección + ejecución: bus
  in-process → `panel.ConsumeEventBus` → ring → REST/WS. Sin Redis en
  single-node (el relay Redis es fan-out multi-nodo; clasificado).

### 1.5 Fase 5 — certificación MECÁNICA

quantum#78 (fusionado): `scripts/lib/guard-registry.sh` (registro explícito +
aserción anti-fósil), `scripts/suite-integral.sh` (14 guards de los 4 repos AL
PIN + gate declared_lags vacío + tabla veraz), `scripts/guard-of-guards.sh` +
`tests/guard-fixtures/` (14 fixtures overlay con `expect=` de causa de muerte;
cobertura guard↔fixture en ambas direcciones), workflow con schedule semanal,
y runbook `docs/AUDITORIA_CONTINUA.md`.

- Certificación 1.8.0 ejecutada en local sin escapes: **suite-integral 14/14
  EXIT=0** y **guard-of-guards 14/14 muerden EXIT=0**.
- La aserción anti-fósil mordió DOS veces en producción: durante su propia
  fase (cazó a los 2 orquestadores recién escritos) y en el re-pin 1.8.0
  (cazó los 2 scripts nuevos de nucleus v1.4.0).
- Sin el escape, el gate de lags demostró morder: con declared_lags poblado →
  «el set pinado NO certifica» EXIT=1.

### 1.6 Fase 6 — tren, re-pin y tag

Orden de dependencias ejecutado: quark v1.3.3 → re-pin showcase (nucleus#225)
→ nucleus v1.4.0 (#224) → orbit: alineación de lags (#116: nucleus v1.4.0 y
quark v1.3.3 en TODOS los módulos + QM7-6) → agent v0.5.4 (#114) → pin en
server (#120) → server v0.8.4 (#119) → quarkbridge v0.3.4 (#118) →
quarkdatasource v0.2.6 (#117, manifest reconciliado a mano — cascada conocida)
→ root v1.4.4 ÚLTIMO (#115; contiene los 5 tags de módulo como ancestros, §3
verificado) → re-pin final del showcase (nucleus#226) → quantum-app v0.1.0
(#2) → certificación del paraguas → **tag de suite v1.8.0 tras el último PR**
(procedimiento QM7-3, estreno).

## 2. Desviaciones (documentadas, no silenciadas)

1. **quark sin extra-files de release-please**: el release PR llegó sin las
   menciones de versión y el guard nuevo lo DETUVO (Lint rojo) — se
   redactaron a mano en la rama del release, como en nucleus/orbit. El guard
   es la forcing function y funcionó; pasar quark a extra-files queda como
   mejora opcional, no deuda (el guard cubre el riesgo).
2. **`check_example_pins.sh` registrado y luego excluido de la lane**: la
   certificación demostró que su rojo al pin es ESTRUCTURAL tras cada tren
   (compara contra tags remotos EN VIVO; nucleus taggea antes que orbit).
   Pertenece al CI de main de nucleus — donde hoy mismo forzó los 2 chores de
   re-pin (#225, #226). Criterio general instalado en runbook §4: la lane
   registra guards cuyo veredicto depende solo del árbol pinado.
3. **El reopen de orbit#119 no disparó CI** («no checks reported»): se
   resolvió con push humano de commit vacío a la rama del release —
   procedimiento más determinista que el close/reopen para los PRs del bot.
4. **Baseline de símbolos de nucleus**: al regenerar aparecieron 2 símbolos
   de rondas anteriores nunca baselinados (`model.ErrNoPrimaryKey`,
   `FieldMeta.UnknownDBTokens`) — el freeze solo vigila eliminaciones, así
   que eran invisibles. Capturados; solo adiciones.
5. **Flake preexistente** (reportado por el agente F1, no tocado):
   `TestRunPluginTestDiscovery` de nucleus falla esporádicamente en local
   bajo carga; pasó en aislamiento y en CI; ya fallaba en la línea base.
6. **Hallazgo lateral sin reclamar**: la rama no-mssql de
   `selectOneAdminUserIDSQL` (nucleus) emite `LIMIT 1`, inválido en Oracle;
   los comandos no declaran soporte Oracle — bug latente si algún día se
   reclama.
7. **quantum-app**: puertos no estándar en local por colisiones (indiferente
   en CI); WS del feed vivo no asertado directamente (el snapshot REST cubre
   el mismo ring; clasificado, no inflado); 2 fixes propios de scripts
   durante el desarrollo (único rojo de CI, corregido).
8. **Sin colisiones de worktree esta ronda**: la regla «worktrees para todo,
   incluido el ejecutor principal» se aplicó y funcionó.

## 3. Pendiente con razón (banda de entrada de la 8ª)

| Issue | Qué | Por qué no en esta ronda |
|---|---|---|
| quark#262 | `WithLimits` no normaliza campos a cero — `Limits` parcial deja `QueryTimeout=0` y TODA query falla al instante (verificado en código) | Hallazgo lateral del spike F3; quark v1.3.3 ya cortado; fix pequeño post-tren |
| nucleus#227 | **BUG**: `isS3NotFound` compara por TEXTO y nunca mapea `ErrNotFound` contra un endpoint S3 real (repro contra MinIO: Code=NoSuchKey, texto distinto) — Get/Exists de clave inexistente → 500 | Cazado por el estreno E2E de quantum-app; nucleus v1.4.0 ya cortado; candidato P2 |
| nucleus#228 | Papercut: el bridge webhook del outbox serializa `Payload []byte` como base64 (doble decodificación para el consumidor) | DX, no correctness; evaluar shape congelado |
| orbit#121 | El carril HTTP del feed vivo no llega al panel in-process (`ConsumeEventBus` solo consume SQL; `LiveTrafficMiddleware` no montable desde `orbit.Module`) — `requests: 0` con tráfico real | Observación del estreno de la cadena; orbit v1.4.4 ya cortado |

## 4. Verificación final del set (comando + EXIT)

- `bash scripts/manifest-guard.sh` (§1–§5) → EXIT=0 (pins nuevos, 5 tags de
  módulo ancestros, README==manifiesto, disclosure sin lags).
- `bash scripts/suite-integral.sh` (SIN escapes) → 14/14 guards EXIT=0,
  «guards registrados: 14 · ejecutados: 14 · con fallo: 0» → EXIT=0.
- `bash scripts/guard-of-guards.sh` → 14/14 «muerde(1)» → EXIT=0.
- quantum-app: `check_suite_manifest.sh` → «OK: 789 denominator items —
  covered 67 · not-covered 552 · out-of-scope 170 (quark v1.3.3 · nucleus
  v1.4.0 · orbit v1.4.4)» EXIT=0; E2E Docker 7/7 PASS contra el set 1.8.0
  (local y CI).
- Sitio del paraguas construido sobre los pins nuevos; linter de lo servido
  (con la regla de IDs) 0 fugas EXIT=0; sidebars sincronizadas EXIT=0.

## 5. Solicitud de la 8ª pasada — la última manual

Se solicita la **8ª auditoría**, con dos encargos:

1. **La pasada clásica** sobre el set 1.8.0 (con fecha y file:línea, como
   siempre), incluyendo la banda de entrada del §3 y el juicio humano que el
   runbook §5 declara fuera del alcance mecánico: fidelidad de las docs de la
   superficie nueva (Jobs/Webhooks, quantum-app/TUTORIAL), revisión de
   seguridad (HMAC del webhook, exención CSRF, superficie del panel), y
   decisiones de alcance (clasificaciones del suite-manifest: ¿los 67 covered
   tienen la evidencia que dicen? ¿las 552 razones de not-covered son
   honestas?).
2. **El meta-encargo que motiva que sea la última**: validar que
   `scripts/suite-integral.sh` + `scripts/guard-of-guards.sh` +
   `docs/AUDITORIA_CONTINUA.md` reproducen lo que el auditor hace
   mecánicamente — ejecutarlos, intentar romperlos (¿hay algún check de tus
   pasadas anteriores que la lane NO cubra?, ¿alguna fixture que no pruebe lo
   que dice?), y dictaminar si a partir de la 9ª la certificación puede
   descansar en la lane semanal + el juicio humano puntual, sin pasada manual
   completa. Si el dictamen es «aún no», el gap concreto es el backlog de la
   siguiente ronda.
