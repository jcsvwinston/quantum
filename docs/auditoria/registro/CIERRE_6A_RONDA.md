# Cierre de la 6ª ronda — Quantum (ejecutado por Claude Code, 2026-07-19)

**Entrada:** `PLAN_EJECUCION_6.md` + `REAUDITORIA6_QUANTUM.md` (misma carpeta).
**Estado base:** Quantum 1.7.1 (quark v1.3.1 `238af896`, nucleus v1.3.2 `e7f00d5c`, orbit v1.4.2 `ee2c84b5`), certificación CONFIRMADA por la 6ª auditoría.
**Estado final:** **Quantum 1.7.2 certificado** — quark v1.3.2 (`bfc08e14`), nucleus v1.3.3 (`3edc8a63`), orbit v1.4.3 (`eb8b98b4`) con agent/v0.5.3, server/v0.8.3, quarkbridge/v0.3.3, quarkdatasource/v0.2.5, proto/v0.4.1.
**Método:** verificación por ejecución; cada gate ejecutado de verdad (Docker incluido), salidas con EXIT pegadas en el PR correspondiente; todo guard nuevo probado en negativo. La lección del arco — **la rama que nunca se ejecutó** — aplicada: cada fix llega con el test o la lane que lo habría cazado.

---

## 1. Definición de Hecho, casilla a casilla

### ☑ Fase 0 — CLAUDE.md de los 4 repos sin fósiles, con guard y negativo
- **orbit** ([orbit#101](https://github.com/jcsvwinston/orbit/pull/101)): los tres fósiles corregidos (decía v1.2.1 → v1.4.2 con marcador `x-release-please-version` + extra-file; «nucleus v1.1.0» → las versiones de otros productos ya no se escriben ahí, se apunta a versions.yaml; «orbit NO tiene CI» → descripción del CI real de 6 módulos). CLAUDE.md entra en `check_docs_version_claims.sh`. Negativo: v1.2.1 falseada → EXIT=1. `grep -cE 'v1\.2\.1|v1\.1\.0|NO tiene CI' CLAUDE.md` → 0.
- **quark** ([quark#254](https://github.com/jcsvwinston/quark/pull/254)): el paso 10 del checklist afirmaba que deploy.yml publica el build de Docusaurus en Pages de quark — es un redirector desde el traslado al sitio unificado; corregido. (La mención de versión de CLAUDE.md ya la vigilaba `check-version-coherence.sh` desde H-Q6.)
- **nucleus**: sin fósiles (no afirma versiones; las descripciones de lanes coinciden con el CI real).
- **quantum**: no tiene CLAUDE.md — nada que barrer (anotado).

### ☑ NU6-1 — la PK asignada por la app viaja en el INSERT
- **Rojo reproducido** (SQLite, API pública): `row inserted with NULL primary key — silent corruption` EXIT=1.
- **Fix** ([nucleus#218](https://github.com/jcsvwinston/nucleus/pull/218)): PK no-cero → incluida en el INSERT, sin read-back ni backfill; PK cero → camino generado intacto. Decisión IDENTITY documentada (pass-through: error claro DEL MOTOR en MSSQL — 544 —, nunca silencio; CRUD no puede saber si la columna es identity y no bloquea los casos legítimos de columna entera no-identity). Comentario engañoso de crud.go corregido; comportamiento documentado en models-and-database.md (§How Create treats the primary key) y compatibility.md.
- **Gates (Docker):** unit por formas EXIT=0; live `client_assigned_uuid_pk` (tabla SIN default) contra **PG real** EXIT=0 y **MSSQL real** EXIT=0; entidad conserva su clave; suite completa 29 paquetes ok.

### ☑ QK6-2 — la adquisición de conexión del RLS nativo era incancelable
- **Fix** ([quark#256](https://github.com/jcsvwinston/quark/pull/256)): `db.Conn(ctx)` (la espera de pool respeta cancel/deadline) + `conn.BeginTx(context.WithoutCancel(ctx))` (solo la tx queda desacoplada); `conn.Close()` devuelto al pool en el AfterFunc tras el Commit y en todos los caminos de error — con test que pina que el pool no se fuga (`MaxOpenConns=1` reutilizable).
- **Gates:** rojo-sin-fix (bloqueado >2s tras deadline de 100ms) / verde-con-fix (`DeadlineExceeded` en ~100ms); pin de pérdida de escrituras de v1.3.1 INTACTO; `-race ./...` completo EXIT=0.

### ☑ QK6-3/QK6-4 — semántica documentada, commit no tragado, batch
- **Docs** (quark#256): §Limitations de row-level-native.mdx con la semántica real de escritura desde v1.3.1 (la cancelación ya no revierte; el commit diferido ocurre tras devolver el control); release notes de v1.3.1 corregidas en el mismo sentido.
- **Error de commit no tragado:** log SIEMPRE (fallback a slog.Default; nivel Error) + contador `Client.DeferredCommitFailures()` (superficie regenerada en el gate S7 y ejercida). Rojo doble demostrado (superficie inexistente pre-fix + `counter = 0, want 1` con el comportamiento antiguo).
- **QK6-4:** subtest `CreateBatch` bajo RLS nativo (mismo patrón scoped-ctx + poll), rojo contra PG real (`Count = 3, want 5`) / verde con los 7 subtests.

### ☑ OR6-1/OR6-2 — require_connection veraz + sospecha de auth
- **Fix** ([orbit#103](https://github.com/jcsvwinston/orbit/pull/103)): `connectedOnce` y la gauge `Connected` al hook `OnAccepted` (la señal veraz de OR5-2); en el dial solo queda reachability (DEBUG); gauge duplicada del stream eliminada; comentario del campo y README del agent veraces. OR6-2: N=3 ciclos consecutivos sin frame aceptado → WARN de sospecha (mismo canal/limiter que OR5-2); los fallos de dial no cuentan; reset en OnAccepted.
- **Gates:** tests rojo-sin-fix/verde-con-fix; `-race` EXIT=0; **E2E en vivo (binarios reales)**: token malo → `BOOT_DEADLINE_FAILED` EXIT=1 (pre-fix: OK falso) + WARN de rechazo + WARN `consecutive_cycles=3`, 0 «connected» falsos; token bueno → `BOOT_OK` EXIT=0. Detalle: el testserver fake ahora imita el ack que el server real siempre envía tras registrar (PushAggregate) — el hook OnAccepted dispara enseguida en producción.

### ☑ QM6-1 — pins cross-repo alineados + guard de disclosure
- **Orbit** ([orbit#102](https://github.com/jcsvwinston/orbit/pull/102)): quarkbridge/quarkdatasource quark v1.2.1 → v1.3.1, tests standalone verdes.
- **Paraguas** ([quantum#72](https://github.com/jcsvwinston/quantum/pull/72)): manifest-guard **§5** — require directo de quark/nucleus en los 6 go.mod de orbit == certificado **o** entrada en la sección nueva `declared_lags` de versions.yaml (regla de disclosure: rancio NO declarado = FAIL, probado en negativo con la entrada des-declarada). `declared_lags` declara el estado REAL del set pinado (sin tocar pines/versiones/status) y se actualiza en cada re-pin. La nota queda sin omisiones.

### ☑ QK6-1 — segundo anillo de huérfanos + Redis + inventario cero
- **Fix** ([quark#255](https://github.com/jcsvwinston/quark/pull/255)): `TestMariaDBOtel`/`TestMariaDBStress` migrados a `resolveMariaDBDSN` y en el patrón de la lane; `TestCacheAllEngines`/`TestOtelAllEngines`/`TestBenchmarkEngines` con skip explícito visible y paso «all-engines legs» por lane; **Redis real** (service container + `QUARK_TEST_REDIS_ADDR`) con `TestAcquireLock_*` ejecutándose de verdad; anclajes `-run` corregidos a `^(A|B|C)$` con comparación de `-list` antes/después.
- **Inventario final en el PR**: TODOS los tests con dependencia de motor clasificados — (a) lane concreta o (b) manual-con-motivo explícito (collector OTLP externo, arneses superapp/bugbash con build tags propios). **Cero sin clasificar.** CI del PR en verde (las lanes ejecutan los tests nuevos).

### ☑ Fase 2 — P3 barrida
- **NU6-2** (nucleus#218): `ErrNoPrimaryKey` explícito en FindByID/Update/Delete; ORDER BY por defecto sobre columna real; live `no_pk` ampliado con FindAll (PG+MSSQL — pre-fix en mssql: `Invalid column name 'id'`).
- **NU6-3** ([nucleus#219](https://github.com/jcsvwinston/nucleus/pull/219), código; docs en #218): `TOP 1` en createuser/changepassword vía `database.System()` (misma forma que FindByID); **fail-fast** de session store SQL y outbox en mssql/oracle — incluidos dos puentes que lo anulaban (app.go y doctor.go mapeaban mssql→sqlite en silencio); claim de compatibility.md acotado por subsistema con tabla honesta.
- **NU6-4** (nucleus#219): igualdad estricta de `not null`; `db:"not null unique"` → WARN con el token completo, sin perder unique en silencio (rojo/verde demostrado).
- **QK6-5** (quark#254): guard de reincidencia del roadmap (negativo probado).
- **QM6-2/QM6-3** ([quantum#73](https://github.com/jcsvwinston/quantum/pull/73)): redirects de las 13 rutas retiradas (1.2.0/1.2.1 → misma página en 1.2.2 ruta a ruta; roots 0.x → intro) y `onBrokenLinks: 'throw'` con build verde.

### ☑ Fase 3 — documentación de producto (completa)
- **nucleus** ([nucleus#220](https://github.com/jcsvwinston/nucleus/pull/220)): Deployment, Security, Upgrade, FAQ, release notes en el sitio (marcador + extra-file + check con negativo), y la **Configuration reference GENERADA** por `scripts/website/gen-config-reference` desde CONFIG_KEY_REGISTRY.md con **gate de frescura en CI** (negativo probado: registry editado sin regenerar → EXIT=1). De paso alineó el registry con claves reales que faltaban (tls_cert_file/tls_key_file). Sidebar curada estilo Django/Laravel. Todos los gates EXIT=0 (bodycheck, voz, claims, build standalone).
- **orbit** ([orbit#104](https://github.com/jcsvwinston/orbit/pull/104)): Deployment (19 flags verificados 1:1 contra --help), Security (dos planos de auth, exención /healthz, checklist), Upgrade, FAQ, release notes (extra-file + check con negativo). Escritas primero con honestidad PRE-OR6-1 y actualizadas tras fusionar orbit#103 con la semántica nueva + la entrada del WARN de sospecha.
- **quark** ([quark#257](https://github.com/jcsvwinston/quark/pull/257)): Deployment, Security, Upgrade, FAQ (12 entradas verificadas por grep de símbolos contra el código); sidebar con categoría Operations.
- **Idioma del paraguas** ([quantum#74](https://github.com/jcsvwinston/quantum/pull/74)): TODO en inglés según la recomendación del plan, documentado en **QADR-0007** y reversible. **Sidebars espejadas** ([quantum#75](https://github.com/jcsvwinston/quantum/pull/75)) con build de integración contra las tres ramas de docs.
- **Gate de la fase (con el set re-pinado)**: build del paraguas SUCCESS con `onBrokenLinks:'throw'`; linter servido `0 fugas, 0 exclusiones`; páginas nuevas servidas en los tres productos; único anchor roto = el heredado conocido del snapshot congelado (permitido en warn, documentado).

### ☑ Fase 4 — re-pinar y certificar
- **Tren en orden de dependencia**: quark v1.3.2 (checklist H-Q6 a mano en el release PR); nucleus v1.3.3; orbit: agent/v0.5.3 → bump de pin en server ([orbit#108](https://github.com/jcsvwinston/orbit/pull/108)) → server/v0.8.3 → quarkbridge/v0.3.3 → quarkdatasource/v0.2.5 (manifest reconciliado a mano tras la cascada DIRTY) → **root v1.4.3 el último**.
- **Certificación** ([quantum#76](https://github.com/jcsvwinston/quantum/pull/76)): pins exactos, declared_lags al día, notas de la ronda; gates: manifest-guard §1-§5 (18 OK) EXIT=0; build 9 patrones EXIT=0; sitio + linter servido 0/0 EXIT=0 con las páginas F3 servidas y lang=en; `nucleus new` pina v1.3.3; `go install …/admin-server@v0.8.3` caché virgen → v0.8.3 EXIT=0.
- **Dos guards mordieron durante el propio tren**: el check de coherencia de nucleus cazó `release-notes.md` rancio (v1.3.2) EN el release PR de v1.3.3 — corregido a mano y causa anotada (el extra-file llegó a mitad del ciclo del release PR; el marcador JSX {/* */} es el correcto para el MDX del sitio y release-please lo actualiza, como demuestra intro.md en ese mismo PR); y la lane standalone de orbit cazó una dep de test sin tidy en orbit#103.

---

## 2. Desviaciones respecto al plan

1. **NU6-3 se partió en dos PRs** (código en #219, docs en #218) para evitar conflictos en compatibility.md; el PR de código amplió el alcance justificadamente: `pkg/app` y `doctor.go` convertían mssql/oracle en `FlavorSQLite` antes de construir el outbox — sin cerrarlos, el fail-fast era inalcanzable.
2. **Decisión IDENTITY de NU6-1**: pass-through con error claro del motor, no `ErrExplicitPKOnIdentity` preventivo — CRUD no puede distinguir una columna identity de una entera normal, y un error propio bloquearía los casos legítimos. Cumple el «nunca silencio» del plan por la vía del error del motor, documentado user-facing.
3. **El contador de QK6-3** vive en `Client` (`DeferredCommitFailures()`) y no en una superficie de métricas global: quark no tiene pkg de métricas ni expvar, y el patrón atomic-en-Client ya existía. Exigió regenerar la superficie del gate S7.
4. **Colisión de checkout** durante la Fase 1: la sesión principal creó una rama en el checkout de orbit mientras un subagente trabajaba en él; el subagente lo gestionó (commits con paths explícitos) y no hubo daño, pero es un error operativo de la sesión — anotado para no repetir (worktrees para TODO trabajo paralelo, también el propio).
5. **Un `go mod tidy` de seguimiento en orbit#103**: el subagente obedeció el «no toques go.mod» literal y su test nuevo dejó una dep indirecta sin declarar — la lane standalone (instalada en la 5ª ronda) lo cazó exactamente como fue diseñada; la sesión principal añadió el tidy.

## 3. Tags cortados y PRs

**Tags:** quark **v1.3.2** (`bfc08e14`) · nucleus **v1.3.3** (`3edc8a63`) · orbit **v1.4.3** (`eb8b98b4`) + **agent/v0.5.3** + **server/v0.8.3** + **quarkbridge/v0.3.3** + **quarkdatasource/v0.2.5** (proto/v0.4.1 sin cambios, correctamente sin re-tag) · suite **quantum v1.7.2**.

| PR | Contenido | Estado |
|---|---|---|
| orbit#101 | Fase 0: CLAUDE.md veraz + guard | MERGED |
| orbit#102 | QM6-1: requires de quark → v1.3.1 en puentes | MERGED |
| orbit#103 | OR6-1/2: Connected veraz + sospecha de auth (+tidy) | MERGED |
| orbit#104 | F3 docs (+actualización post-OR6-1 + release-notes al check) | MERGED |
| orbit#108/#110/#111 | bump pin server / release-as (inoperante) / Release-As footer | MERGED |
| orbit#105/#106/#107/#109/#112 | release PRs (qds/qb/agent/server/root) | MERGED |
| nucleus#218 | NU6-1/NU6-2 (+docs NU6-3) | MERGED |
| nucleus#219 | NU6-3/NU6-4 código (con cierre de 2 puentes del fail-fast) | MERGED |
| nucleus#220 | F3 docs + generador Config reference + gate frescura | MERGED |
| nucleus#221 | release v1.3.3 (guard cazó release-notes rancio; corregido) | MERGED |
| quark#254 | Fase 0 CLAUDE.md + guard roadmap (QK6-5) | MERGED |
| quark#255 | QK6-1: lanes + Redis + inventario | MERGED |
| quark#256 | QK6-2/3/4: RLS nativo | MERGED |
| quark#257 | F3 docs | MERGED |
| quark#258 | release v1.3.2 (checklist H-Q6 incluido) | MERGED |
| quantum#72 | manifest-guard §5 + declared_lags | MERGED |
| quantum#73 | QM6-2/3: redirects + onBrokenLinks throw | MERGED |
| quantum#74 | chrome en inglés + QADR-0007 | MERGED |
| quantum#75 | sidebars espejadas (fusionado tras el re-pin) | MERGED |
| quantum#76 | certificación 1.7.2 + next-session §3 | MERGED |

## 4. Pendiente y por qué

1. **Drift del CONFIG_KEY_REGISTRY.md**: `templates_dir`, `state_dir` y `outbox.*` existen en el código y no están en el registry (lo señaló el agente del generador; el generador publica lo que el registry contiene, así que el drift está ACOTADO al registry, no a la página). Alinear registry↔código es trabajo de inventario de nucleus para el próximo arco.
2. **quark#252** — rediseño del ciclo de vida del implicit-tx del RLS nativo (commit en Rows.Close / timeout de tx): fuera de alcance deliberado de esta ronda; las aristas acotadas (adquisición cancelable, error de commit con rastro) quedaron cerradas.
3. **Require nucleus de los módulos de orbit** (v1.3.1 vs certificado v1.3.3, mismo minor, declarado en declared_lags y vigilado por el guard §5): alinear en el próximo arco de orbit.
4. **P-baja de la Fase 3** (declarada sin drama, como pedía el plan): tutorial largo de nucleus, tutorial integrador de la suite, tour con capturas de orbit.

---

*Escrito para ser reproducido: cada EXIT citado salió de una ejecución real de esta sesión (2026-07-19), con salidas completas en los PRs. La 7ª auditoría puede re-ejecutar cada gate tal cual está descrito.*
