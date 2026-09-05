# Quark — madurez

> Auditoría sobre `github.com/jcsvwinston/quark` **v1.10.0** (commit `7bb5a6e3`, checkout `/Users/jcsv/GolandProjects/quark`; el submódulo de `quantum/quark` está al mismo commit). Fecha: 2026-09-03. Método: lectura de código (no de la doc), ejecución local con SQLite, quickstart reproducido en un módulo aparte, instalación real de los módulos de driver publicados desde el proxy. Todo lo afirmado remite a fichero:línea. No se ha editado el repo.

## 1. Veredicto

Quark ya no es lo que describía `docs/ANALISIS_MADUREZ.md` (2026-05-10): de las 18 brechas de aquel análisis, 16 están cerradas en código (AST de expresiones, CTE/window/set-ops/locking, diff de esquema real con tipo/nullable/default/índices/FK/checks, lock distribuido, RLS nativa de PostgreSQL, stampede, métricas OTel, réplicas, sharding, hooks post-commit, event bus, audit, testcontainers en CI, tipos ricos). Hoy es un ORM reflect-based de la clase GORM/bun con **más superficie que GORM en multi-tenant, caché, migraciones-como-plan y observabilidad**, y con Oracle/MSSQL reales; por debajo de ent en codegen/grafo y de sqlc en tipado de consultas arbitrarias; y todavía lejos del listón enterprise (SQLAlchemy 2/EF Core/Hibernate) en Unit of Work, identity map, lazy loading y ecosistema.
Lo que hoy le pesa no son features sino **la costura recién abierta en v1.9/v1.10 (drivers como módulos)**: un bug P0 que impide abrir conexión con `lib/pq` y `mattn/go-sqlite3` (los drivers que la propia guía de instalación recomienda), una degradación silenciosa cuando se importa el driver "a la antigua" (que es exactamente lo que el README, la guía y los ejemplos siguen enseñando), y módulos de driver publicados con `go.mod` no tidy que apuntan a un Quark sin `quarkdriver`. Más un binario de 42 MB trackeado en git.
La calidad de base es buena: `go build`/`vet`/`test -count=1`/`-race -short`/`go mod tidy` limpios en el módulo raíz, 623 funciones de test, 6 motores en CI, gate de superficie (`superapp`) reconciliado contra la API real.
Notas de madurez (1-5): **API/query 4 · migraciones 3 · tipos 3 · rendimiento 3 · multi-tenant 4 · observabilidad 4 · testing 4 · docs/DX 2 (por la deriva post-1.9 y el P0) · ecosistema 2**.

## 2. Tabla comparativa

Leyenda: ✅ nativo · partial · ❌. Listón enterprise = SQLAlchemy 2 / EF Core / Hibernate / Prisma (lo mejor de cada uno).

| Capacidad | Quark (nota → fichero) | GORM v2 | ent | bun | sqlc | Listón enterprise |
|---|---|:---:|:---:|:---:|:---:|:---:|
| API genérica sin `interface{}` | ✅ `For[T]`, `Query[T]` (`query_builder.go`) | ✅ (`gorm.G[T]` desde 1.30) | ✅ | partial | ✅ | ✅ |
| Query builder componible (AST) | ✅ `Expr`, `And/Or/Cmp/Func/In/Exists` (`expr.go`), `WhereExpr/HavingExpr/SelectExpr` | partial (strings) | ✅ predicates | ✅ | n/a (SQL) | ✅ |
| Subconsultas tipadas | ✅ `AsSubquery`, `InSub/Exists` (`subquery.go`) | partial | ✅ | ✅ | ✅ | ✅ |
| CTE / recursivas | ✅ `With/WithRecursive` (`cte.go`), Oracle/MSSQL cubiertos | ❌ raw | partial | ✅ | ✅ | ✅ |
| Window functions | ✅ `Over/Rank/RowNumber/Lag/Lead` (`window.go`) | ❌ raw | partial | ✅ | ✅ | ✅ |
| UNION/INTERSECT/EXCEPT (+ALL) | ✅ con gating por motor y `ErrUnsupportedFeature` (`setop.go`) | ❌ raw | ❌ | ✅ | ✅ | ✅ |
| Locking pesimista (`FOR UPDATE/SHARE/SKIP LOCKED/NOWAIT`) | ✅ (`locking.go`, `dialect_lock.go`) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Locking optimista (`version`) | ✅ tag `quark:"version"`, `ErrStaleEntity` (`optimistic_locking.go`) | plugin | ✅ | partial | ❌ | ✅ |
| Dirty tracking / UoW | partial `Track().Find().Save()` (`dirty_track.go`); `Update` sigue con *zero-value skip* (`query_crud.go:685-696`) | partial (`Select/Omit`) | ❌ | ❌ | n/a | ✅ UoW+identity map |
| Relaciones: has_many/belongs_to/m2m/polimórfica | ✅ (`preload_loaders.go`, `internal/schema`) | ✅ | ✅ grafo | ✅ | n/a | ✅ |
| Preload anidado / condicional / lazy | partial: anidado ✅ (`preload_tree.go`); **sin condiciones ni orden por relación, sin lazy** (`query_builder.go:179`) | ✅ condicional | ✅ | ✅ | n/a | ✅ |
| Raw SQL → struct tipado | ❌ `RawQuery` devuelve `*sql.Rows` (`client.go:583`); no hay `Raw[T]` | ✅ `Raw().Scan` | partial | ✅ | ✅ | ✅ |
| Batch: create/upsert/update/delete chunked | ✅ con techos de binds por dialecto (`batch_test.go`, `query_crud.go`) | partial | partial | ✅ | ❌ | ✅ |
| Upsert 6 dialectos (MERGE en MSSQL/Oracle) | ✅ (`dialect.go` `UpsertSQL`) | ✅ | partial | ✅ | n/a | ✅ |
| Auto-migrate + Sync (renames) | ✅ (`migrator.go`, `sync.go`) | ✅ | ✅ | partial | ❌ | ✅ |
| Diff de esquema real (tipo/null/default/índice/FK/check) → plan | ✅ `PlanMigration/ApplyPlan`, `Plan.Hash` (`migrate_diff.go:89-116`, `migrate_plan.go`) | ❌ | ✅ (Atlas) | ❌ | ❌ | ✅ |
| Migraciones versionadas (ficheros) | partial: registry **global** Go-only, sin `.sql`, sin tx por migración, `fmt.Printf` (`migrate/migrate.go:128-170`) | partial (gormigrate) | ✅ | ✅ | ❌ | ✅ |
| Lock distribuido de migración | partial: existe (`migration_lock.go`, `dialect_migration_lock.go`) pero **ni `Migrator.Up`, ni `ApplyPlan`, ni el CLI lo toman solos** | ❌ | ✅ | ❌ | n/a | ✅ |
| Backfill orquestado | ✅ `Client.Backfill` (`migrate_backfill.go`) | ❌ | ❌ | ❌ | ❌ | partial |
| Tipos: `Nullable[T]`, `JSON[T]`, `time.Duration`, `[]byte`, size/precision | ✅ (`nullable.go`, `json_field.go`, `type_mapper.go`) | ✅ | ✅ | ✅ | ✅ | ✅ |
| decimal / uuid / enum built-in | ❌ sólo vía `RegisterTypeMapper` (`type_mapper.go:29-34`); roadmap lo declara fuera | partial | ✅ | ✅ | ✅ | ✅ |
| Arrays PG nativos | ❌ `Array[T]` viaja como JSON en todos los motores (`array.go:13-33`) | partial | ✅ | ✅ | ✅ | ✅ |
| Timezone por columna | ✅ `quark:"tz=…"`, `WithDefaultTZ` (`timezone.go`) | ❌ | ❌ | ❌ | n/a | partial |
| Multi-tenant (DB/schema/RLS cliente) | ✅ `TenantRouter` con LRU de pools (`tenant_router.go`) | plugin | manual | manual | ❌ | ✅ Hibernate |
| RLS nativa del motor | ✅ PG `set_config` + `CREATE POLICY` + `verify-rls-policies` que lee predicados (`rls_native.go`, `quarktenant/`) — sólo PostgreSQL | ❌ | ❌ | ❌ | ❌ | partial |
| Caché L2 + stampede + cross-instance | ✅ singleflight+jitter+XFetch, tags y por-PK, locker Redis (`cache_stampede.go`, `cache_invalidation.go`) | plugin | ❌ | ❌ | ❌ | ✅ Hibernate |
| Réplicas de lectura + failover + sticky | ✅ (`replicas.go`) | plugin (dbresolver) | partial | ❌ | ❌ | ✅ |
| Sharding + scatter-gather | ✅ (`shard_router.go`, `shard_scatter.go`) | plugin | ❌ | ❌ | ❌ | partial |
| Hooks post-commit, `OnCommit/OnRollback`, `BeforeFind` | ✅ (`hooks.go`, `tx.go`) | partial | ✅ | ✅ | n/a | ✅ |
| Event bus / audit log atómico | ✅ (`events.go`, `audit.go`) | ❌ | partial | ❌ | ❌ | ✅ Envers |
| OTel traces + metrics + redacción | ✅ (`otel/`), slow-query log, `QueryObserver` | plugin | contrib | ✅ | ❌ | ✅ |
| Retry de deadlock por código de error | ✅ `WithDeadlockRetry` (`tx.go`, `db_errors.go`) | ❌ | ❌ | ❌ | ❌ | ✅ EF |
| Clasificación de errores (`IsUniqueViolation/IsDeadlock`) | ✅ pero **depende de importar `drivers/<x>`**; sin aviso si falta (`db_errors.go:66-157`) | ❌ (`ErrDuplicatedKey` parcial) | ✅ `ent.IsConstraintError` | ✅ | ❌ | ✅ |
| Codegen tipado | partial: scanners/binder INSERT + `<Model>Columns` + `WhereP` (`codegen_registry.go`, `typed_columns.go`); UPDATE/batch no | ✅ gen | ✅ | ❌ | ✅ | partial |
| CLI (init/model/migrate/inspect/seed/tenant) | ✅ 21 comandos (`cmd/quark/commands/`) | ✅ gen | ✅ | ❌ | ✅ | ✅ |
| Test kit | partial `quarktest` sólo SQLite (`quarktest/quarktest.go:20-27`) | ❌ | ✅ enttest | ❌ | n/a | ✅ |
| Dialectos con Oracle/MSSQL reales en CI | ✅ 6 (`suite_test.go`, `.github/workflows/ci.yml`) | partial | partial | ❌ | partial | ✅ |
| Prepared-statement cache / COPY bulk | ❌ ninguno (grep vacío) | ✅ `PrepareStmt` | ❌ | partial | n/a | ✅ |
| Ecosistema (plugins, comunidad, adoptantes) | ❌ un mantenedor, 0 plugins de terceros | ✅ | ✅ | ✅ | ✅ | ✅ |

## 3. Lo que falta para competir

### Bloqueante (hoy impide adoptar o rompe al que adopta)

1. **La costura de drivers (v1.9/v1.10) está a medio cerrar.** `quark.New("postgres", dsn)` con `lib/pq` y `quark.New("sqlite3", dsn)` con `mattn/go-sqlite3` **fallan** en v1.10.0 con un error que pide importar un módulo (QK-1). El README, la guía de instalación, la guía de inicio, `deployment.mdx` y los 8 ejemplos siguen enseñando la importación directa del driver, que abre pero pierde silenciosamente `IsUniqueViolation`, retry de deadlock y failover de réplicas (QK-3/QK-4/QK-16). Los módulos `drivers/*@v0.1.0` publicados no son reproducibles por sí mismos (QK-5). Hasta que esto no cuadre, cualquier usuario nuevo tropieza en la primera hora.
2. **Higiene de repo:** un ejecutable de 42 MB trackeado (QK-2) es lo primero que ve quien clona; descalifica en una revisión de adopción.
3. **`Update(entity)` con *zero-value skip*** (`query_crud.go:685-696`): no puede escribir `false`/`0`/`""`; el propio godoc lo llama "P0-4 pending dirty tracking in Phase 1" cuando la fase 1 se entregó hace meses. GORM tiene el mismo defecto de diseño, pero ent/bun/sqlc/EF/SQLAlchemy no. Es la trampa que más incidentes produce en un ORM Active Record.

### Diferenciador (lo que le separa del listón enterprise y de ent)

4. **Consultas arbitrarias tipadas**: `Raw[T]`/`Select[T]` que escaneen a un struct/DTO cualquiera (hoy `RawQuery` → `*sql.Rows`). Sin esto, el "escape hatch" pierde el tipado que es la razón de ser del producto.
5. **Preload con condiciones/orden/limit por relación y carga diferida opcional** (`Preload("Orders", where...)`). Hoy `Preload(relations ...string)`.
6. **Migraciones versionadas de verdad**: registry por cliente (no global), ficheros `.sql` embebibles (`embed.FS`), transacción por migración donde `SupportsTransactionalDDL`, lock distribuido tomado por defecto en `Up`/`ApplyPlan`/CLI, `down` autogenerado desde el `Plan` (el diff ya lo permite), `quark migrate diff` que escriba el fichero.
7. **Tipos built-in**: `decimal` (shopspring ya está en el grafo vía mssql), `uuid.UUID` con `UUID` nativo en PG/`CHAR(36)` en el resto, enums con `CHECK`, arrays nativos PG detrás de `Array[T]` cuando el dialecto lo soporte.
8. **RLS nativa más allá de PostgreSQL** (SQL Server tiene RLS con predicados; Oracle VPD). Hoy `RowLevelSecurityNative` rechaza no-PG.
9. **Codegen que cubra UPDATE/batch** — el roadmap lo descarta por rendimiento (ADR-0017), pero el argumento de **seguridad de tipos** (que el propio ADR admite) sigue abierto: hoy `WhereP` cubre `Where` y nada más.

### Nice-to-have

10. Prepared-statement cache opcional (GORM `PrepareStmt`), `COPY`/bulk load en PG, `INSERT … RETURNING` multi-fila donde exista.
11. `quarktest` para Postgres vía testcontainers (hoy sólo SQLite), fixtures mínimos.
12. `Exists()` en `Query[T]`, `Pluck[T]`, `FirstOrCreate`, `UpdateOrCreate` — azúcar que GORM/ActiveRecord dan y que la gente busca en el primer día.
13. Un puente `context`-first para `slog` con `db.query.text` redactado ya existe en OTel; faltaría `QueryObserver` con `explain` opcional para consultas lentas.
14. Ecosistema: ejemplos de integración (chi/echo/nucleus), un `awesome-quark`, plantilla de driver externo documentada sobre `quarkdriver.Classifier`.

## 4. Mejoras propuestas

### Corto (≤1 mes)

| # | Mejora | Esfuerzo | Valor | Depende de |
|---|---|---|---|---|
| C1 | Arreglar `quarkdriver.IsRegistered` (QK-1) + test con `sql.Register` de un driver ficticio "postgres"/"sqlite3"; patch v1.10.1 | 0,5 d | Alto: desbloquea lib/pq y mattn | — |
| C2 | Aviso (WARN por defecto, error bajo `WithStrictDriver()`) en `newClient` cuando `!quarkdriver.HasEngine(dialect.Name())` (QK-4) | 1 d | Alto: convierte la degradación silenciosa en visible | C1 |
| C3 | Reescribir README Quick Start, `installation.mdx`, `getting-started.mdx`, `deployment.mdx`, `events.mdx`, `examples/*/main.go` para `drivers/<x>`; volver a cortar el snapshot `version-1.10.0` (QK-3/15/16/21) | 1-2 d | Alto | C1 |
| C4 | `drivers/*/go.mod` → `quark v1.10.x`, `go mod tidy`; job de CI **sin go.work** que haga `go mod tidy && git diff --exit-code && go build` por driver; script de release que suba el `require` al taggear quark (QK-5) | 1 d | Alto: módulos publicados reproducibles | — |
| C5 | `git rm --cached superapp`, `/superapp` en `.gitignore`, reescritura de historia opcional (QK-2) | 0,5 d | Medio-alto (percepción, tamaño de clone) | — |
| C6 | Deriva documental: tabla del README/comparison (GORM generics, ent `*sql.DB`), "Project Structure", ADR-0027→0023, `ErrGeneratedStub`, CHANGELOG duplicados, `ROADMAP.md` como puntero, archivar `TASKS.md`/`ANALISIS_MADUREZ.md` con banner (QK-7/9/10/11/12/13/26) | 1 d | Medio: credibilidad "anti-hype" | — |
| C7 | `Migrator.Up`/`ApplyPlan`/`quark migrate up` toman `AcquireMigrationLock` por defecto (`--no-lock` para desactivar) y `logger` en vez de `fmt.Printf` (QK-6) | 2 d | Alto para despliegues multi-pod | — |

### Medio (1-3 meses)

| # | Mejora | Esfuerzo | Valor | Depende de |
|---|---|---|---|---|
| M1 | `quark.Raw[T](ctx, client, sql, args...).List()/First()` con scan por nombre de columna y `SQLGuard` sobre la query (reutiliza el scan plan de `query_exec.go`) | 1-2 sem | Alto: cierra el hueco vs sqlx/bun | — |
| M2 | Preload con opciones: `Preload("Orders", quark.PreloadWhere(...), quark.PreloadOrder(...), quark.PreloadLimit(n))` | 2 sem | Alto | — |
| M3 | Tipos built-in: `decimal.Decimal`, `uuid.UUID`, enums (`quark:"enum=a|b|c"` → CHECK), mapeo nativo por dialecto en `internal/migrate.SQLType` | 2-3 sem | Alto | — |
| M4 | Migraciones versionadas v2: registry por `*Migrator`, `.sql` vía `embed.FS`, tx por migración, `quark migrate diff` que emite up+down desde `Plan` | 3-4 sem | Alto | C7 |
| M5 | Semántica de `Update`: opción de cliente `WithUpdateWritesZeroValues()` (o tag `quark:"omitzero"`) y deprecación documentada del skip para v2 | 1 sem | Alto (correctness) | — |
| M6 | `quarktest.Postgres(t)` con testcontainers opcional (build tag) y `quarktest.Seed` | 1-2 sem | Medio | — |
| M7 | Mover `internal/driverclassify` + suites de motor a un módulo de test (`quark/internal/enginetest`) para que el `go.mod` raíz deje de requerir 5 drivers + testcontainers (QK-14) | 1 sem | Medio (SBOM, dependabot, "129 módulos" de verdad) | C4 |

### Largo (3-12 meses)

| # | Mejora | Esfuerzo | Valor | Depende de |
|---|---|---|---|---|
| L1 | Unit of Work ligero opcional: `Session` con identity map por PK y `Flush()` que emite sólo los UPDATE de campos cambiados (extiende `Tracked[T]`) | 2-3 meses | Alto: es lo que separa Active Record del listón enterprise; ADR-0001 tendría que revisarse | M5 |
| L2 | RLS nativa en SQL Server (security policies) y Oracle (VPD) detrás del mismo `RowLevelSecurityNative` | 1-2 meses | Medio-alto para el nicho enterprise que Quark ya elige (Oracle/MSSQL) | — |
| L3 | Codegen fase 2 orientado a tipos: binders UPDATE/batch y `Select` tipado a DTOs generados (no por velocidad; por compile-time) | 2 meses | Medio | M1 |
| L4 | Schema-first opcional (declarativo → plan reversible), como capa sobre `Diff` — sólo si hay demanda (el roadmap lo condiciona bien) | 3 meses | Medio | M4 |
| L5 | Ecosistema: plantilla de driver externo, `awesome-quark`, integración documentada con nucleus/chi/echo, canal de issues público con triage | continuo | Alto a largo plazo | — |

## 5. Defectos encontrados

| id | Sev. | fichero:línea | Evidencia | Corrección propuesta |
|---|---|---|---|---|
| QK-1 | **P0** | `quarkdriver/known.go:88-98` (`IsRegistered`), usado en `client.go:255-259` | Con un driver registrado como `"postgres"` (lib/pq) o `"sqlite3"` (mattn), `quark.New("postgres", …)` y `quark.New("sqlite3", …)` devuelven `ErrConnection: the postgres driver ships as its own module and is not imported yet … (linked right now: postgres, sqlite3)`. Reproducido con un driver ficticio (`scratchpad/auditoria/quark-dx/alias`). `IsRegistered` sustituye el nombre por su alias (`postgres→pgx`, `sqlite3→sqlite`) y sólo busca el alias en `sql.Drivers()`. La guía de instalación (`website/docs/guides/installation.mdx:35,44`) recomienda `lib/pq` como driver por defecto de PostgreSQL. Regresión de v1.10.0 (#336). | `return slices.Contains(sql.Drivers(), driverName) \|\| slices.Contains(sql.Drivers(), alias)`; test unitario que registre un `driver.Driver` ficticio bajo `postgres`/`sqlite3` y espere que `New` llegue a `sql.Open`. Patch v1.10.1. |
| QK-2 | **P1** | `superapp` (raíz, 42 232 786 B, Mach-O arm64), `.gitignore:5-9` | `git ls-files -s superapp` → `100755 f4137561…`; entró en #312 (`31a2052b`). `.gitignore` ignora `/quark` y `/gen-apisurface` pero no `/superapp`. | `git rm --cached superapp`; añadir `/superapp` a `.gitignore`; valorar `git filter-repo` para que el clone no cargue 42 MB para siempre. |
| QK-3 | **P1** | `README.md` (Quick Start, `_ "modernc.org/sqlite"`), `website/docs/guides/getting-started.mdx:308`, `website/docs/guides/installation.mdx:32-48`, `website/docs/operations/deployment.mdx:28-33`, `website/docs/advanced/events.mdx:130-133`, `website/versioned_docs/version-1.10.0/guides/installation.mdx` (6 menciones) | Toda la doc pública de v1.10.0 enseña el driver directo. Quickstart reproducido tal cual: abre y consulta, pero `IsUniqueViolation(err)` = **false** ante `UNIQUE constraint failed` (con `drivers/sqlite` = true). Ni el README ni la guía mencionan `drivers/*` salvo el párrafo de status del README:27-30 y las release notes. | Reescribir quickstart/guías/ejemplos con `import _ "github.com/jcsvwinston/quark/drivers/<x>"`; tabla de instalación con el módulo y el nombre de driver a pasar a `New`; volver a cortar el snapshot 1.10.0 o parchearlo. |
| QK-4 | **P1** | `client.go:255-259`, `quarkdriver/driver.go:132` (`HasEngine` no se usa fuera de `drivertest`) | Si el driver está registrado por otro import, `New` no comprueba que exista clasificador para el dialecto: los tres predicados responden `false` (unique/deadlock/transient) sin señal alguna. El propio paquete lo documenta como el fallo caro (`quarkdriver/driver.go:23-27`). | En `newClient`, tras detectar dialecto: `if !quarkdriver.HasEngine(d.Name()) { logger.Warn(…MissingDriverHint…) }`; opción `WithStrictDriver()` para convertirlo en error. Test: `sql.Register("x")` + dialecto forzado. |
| QK-5 | **P1** | `drivers/mysql/go.mod:6`, `drivers/sqlite/go.mod:6`, `drivers/mssql/go.mod:6`, `drivers/oracle/go.mod:6` (`quark v1.8.0`); `drivers/postgres/go.mod` (sin `require quark`); `drivers/mysql/go.sum` y `drivers/oracle/go.sum` (2 líneas) | `quark@v1.8.0` **no contiene `quarkdriver/`** (verificado en `$GOMODCACHE/github.com/jcsvwinston/quark@v1.8.0` y con `git ls-tree v1.8.0`). `go build ./...` dentro de cada driver, sin go.work: `missing go.sum entry` / `no required module provides package …/quarkdriver`. `go mod tidy` standalone cambia 145 líneas (mysql) y 200 (postgres). Los `.mod` publicados en el proxy para `v0.1.0` son idénticos. Sólo funciona porque CI usa `go work init` (`.github/workflows/ci.yml:145`) y porque `go get` resuelve al latest. | Subir `require quark` a `v1.10.x` y `tidy` en los cinco; job de CI **sin workspace** (`go mod tidy && git diff --exit-code && go build`); en el flujo de release, re-pinar los drivers al taggear quark y publicar `drivers/*` v0.1.1. |
| QK-6 | P2 | `migrate/migrate.go:128-170`, `cmd/quark/commands/migrate.go`, `migrate_execute.go:56` (sólo lo documenta) | `Migrator.Up` no adquiere `AcquireMigrationLock`, no envuelve cada migración en tx aunque `SupportsTransactionalDDL()` sea true, y escribe con `fmt.Printf` desde una librería. `grep AcquireMigrationLock(` fuera de tests: sólo `quarktenant/install.go:223`. | Lock por defecto en `Up/Down` y en `ApplyPlan` (nombre `quark:schema`, timeout configurable, `WithoutLock()`); tx por migración cuando el dialecto lo soporte; `*slog.Logger` del cliente. |
| QK-7 | P2 | `README.md` tabla "Why Quark" (fila "Native Generics", fila "`stdlib` `*sql.DB`"), `docs/comparison.md` §1, `website/docs/reference/comparison.mdx` | "GORM: partial¹ — generic wrappers … not part of the primary API": GORM ≥1.30 (2025) tiene API de generics oficial (`gorm.G[T](db)`). "ent: ❌ `stdlib *sql.DB`": ent corre sobre `database/sql` (`entsql.OpenDB(dialect, db)`) — la celda es falsa. | Actualizar ambas celdas y la nota ¹; fechar la tabla ("comparado contra GORM vX, ent vY"). |
| QK-8 | P2 | `drivers/postgres/listener.go:16-17`, `quarkdriver/listener.go` (`NewListenerFunc func(db *sql.DB, g *guard.SQLGuard)`) | Un módulo separado importa `github.com/jcsvwinston/quark/internal/guard`; el contrato público `quarkdriver` expone un tipo `internal/`. Compila por el prefijo de ruta, pero cualquier cambio en `internal/guard` rompe un módulo con su propio ciclo de versiones, y un tercero no puede implementar `NewListenerFunc` sin el tipo interno. | Exponer la firma con un tipo público (`quark.SQLGuard` ya es alias) o una interfaz mínima en `quarkdriver` (`type IdentifierValidator interface{ ValidateIdentifier(string) error }`). |
| QK-9 | P2 | `codegen_registry.go:169-184`, `cmd/quark/internal/codegen/emit.go:120-131` | `ErrGeneratedStub` = "generated code is an F6-1 stub; the typed fast path lands in F6-2/F6-3". F6-2/F6-3 se entregaron (v0.11/v0.12, ROADMAP). El stub sigue emitiéndose para `BindUpdate` y modelos sin PK entera, así que el mensaje llega al usuario y le habla de fases internas futuras que ya pasaron. | Reescribir: "quark: generated binder does not cover this operation (UPDATE/partial/batch or non-integer PK); the reflection path is used" y no devolverlo como error donde el fallback es transparente. |
| QK-10 | P3 | `zz_drivers_for_test.go:7`, `cmd/quark/internal/db/drivers.go:7`, `quarktenant/zz_drivers_for_test.go:6`, `quarktest/zz_drivers_for_test.go:6`, `examples/superapp/exercise/zz_drivers_for_test.go:6` | Citan "ADR-0027"; el ADR de módulos de driver es `docs/adr/0023-driver-modules.md` (no existe 0027). | `sed -i 's/ADR-0027/ADR-0023/'`. |
| QK-11 | P3 | `README.md` § "Project Structure" | Omite `drivers/`, `quarkdriver/`, `quarktenant/`, `quarktest/`, `quarkmigrate/`, `seed/`, `benchmarks/`, `website/`. | Regenerar el árbol. |
| QK-12 | P3 | `TASKS.md` (235 KB, congelado 2026-06-20 según su propio banner), `docs/ANALISIS_MADUREZ.md` (2026-05-10, sin banner), `docs/AUDITORIA_DOCS_v1.1.4.md`, `docs/ENGLISH_DOCS.md`, `docs/BUGBASH_PLAN.md`, `docs/ROADMAP.md:3` (se declara "aligned with ANALISIS_MADUREZ §4" y termina en v1.1/v1.2) | Documentos internos rancios en raíz y en `docs/`; el análisis de madurez sigue enlazado como vigente y describe 16 brechas ya cerradas. | Mover a `docs/archive/` con banner "histórico, superado por …"; `docs/ROADMAP.md` → puntero a `website/docs/reference/roadmap.mdx`. |
| QK-13 | P3 | `drivers/mysql/CHANGELOG.md`, `drivers/postgres/CHANGELOG.md` | Sección `## 0.1.0 (2026-09-01)` duplicada (la segunda vacía). | Borrar la duplicada; revisar la config de release-please de los paquetes hijos. |
| QK-14 | P3 | `go.mod:7-31` (raíz) | El módulo raíz requiere directamente 5 drivers, `mattn/go-sqlite3` (sólo 2 tests) y 4 módulos testcontainers: un consumidor que hace `go get quark` ve `pgx`, `go-ora`, `go-mssqldb`, `shopspring/decimal`… como `// indirect` (comprobado en `quark-dx/published/go.mod`). No se enlazan (CI lo verifica) pero sí aparecen en SBOM/dependabot. | Mover `internal/driverclassify` y las suites por motor a un módulo de test aparte, o documentar la diferencia entre "módulos en el grafo" y "paquetes enlazados". |
| QK-15 | P3 | `website/docs/guides/installation.mdx:44-48`, `website/docs/advanced/events.mdx:129-135` | "Either `lib/pq` or `pgx` works, both report errors the same way to Quark" — con QK-1 `lib/pq` ni abre; el listener ahora vive en `drivers/postgres` (registrado vía `quarkdriver.RegisterListener`), no en "`jackc/pgx/v5/stdlib`". | Corregir junto con QK-3. |
| QK-16 | P2 | `examples/sqlite/main.go:10`, `examples/postgres/main.go:10`, `examples/mysql/main.go:10`, `examples/mssql/main.go:11`, `examples/migrations/main.go:22`, `examples/sharding/main.go:28`, `examples/tenant-rls-native/main.go:30`, `examples/superapp/main.go:49-53` | Ningún ejemplo oficial importa `drivers/*`; el ejemplo de RLS nativa y el de réplicas/sharding corren sin clasificación (sin deadlock retry, sin failover). | Cambiar los imports; que `superapp` (gate de superficie) ejercite también los cinco módulos de driver. |
| QK-17 | P2 | `query_crud.go:685-696` (godoc de `Update`) | "P0-4 — pending dirty tracking in Phase 1": la fase 1 está entregada (`dirty_track.go`), pero la semántica de `Update` no cambió y el godoc sigue prometiendo. | Actualizar el godoc y decidir (M5): opción de cliente o `omitzero`; deprecación programada para v2. |
| QK-18 | P3 | `website/docs/guides/installation.mdx:19`, `README.md:11` | Badge/tabla dicen "Go 1.25+" y `go.mod` declara `go 1.25.7` + `toolchain go1.26.6`: correcto, pero conviene decir que el toolchain se descarga solo (GOTOOLCHAIN) para no asustar a quien tiene 1.25. | Una frase en la guía. |
| QK-20 | P3 | `examples/superapp/README.md:88`, `examples/superapp/allowlist.json` | El README del gate dice "655 símbolos"; el manifiesto actual tiene 720 y 392 están allowlisted (54 %): el gate "estricto" cubre menos de la mitad de la superficie y la cifra pública está rancia. | Regenerar la cifra desde `apisurface.json` en `make regen`; revisar la allowlist para que los símbolos de `drivers/*`/`quarkdriver` entren en el gate. |
| QK-19 | P3 | `quarkdriver/known.go:65` | `MissingDriverHint` imprime `(linked right now: none)` incluso cuando hay drivers registrados bajo otro nombre (ver QK-1 salida: "linked right now: postgres, sqlite3" y aun así pide importar). Tras QK-1 el mensaje debería explicar "registrado como X, Quark esperaba Y". | Mensaje que nombre el driver encontrado y el nombre que espera. |

Notas sobre lo que **no** es defecto: `example.db` en raíz está ignorado (`*.db`) y no trackeado; `quark`/`gen-apisurface` binarios en raíz también ignorados; los 47 `SKIP` locales son suites por DSN/Redis que CI sí ejecuta; `go mod tidy` en raíz no cambia nada; `gofmt -l .` vacío.

## 6. Resultados de ejecución

Entorno: `go1.26.6 darwin/arm64`, sin Docker, sin DSN externos, sin Redis.

| Comando | Resultado |
|---|---|
| `go build ./...` (raíz) | OK |
| `go vet ./...` (raíz) | OK, sin avisos |
| `gofmt -l .` | vacío |
| `go test ./... -count=1` (raíz, SQLite) | **OK** — 22 paquetes `ok`, 20 sin tests, 0 FAIL, ~12 s el más lento (`cmd/quark/commands` 11,4 s) |
| `go test -v` (raíz + quarktenant/quarktest/quarkmigrate/migrate/cache/otel/commands) | 47 `SKIP`: `TestSuitePostgres/MySQL/MariaDB/MSSQL/Oracle`, RLS nativa PG (5), deadlock retry MySQL/MariaDB, `TestOtelAllEngines/*`, `TestCacheAllEngines`, Redis (2), y sub-tests de locking gateados por dialecto. Ningún flake en dos ejecuciones. |
| `go test -race -short -count=1 ./...` | **OK** — 22 paquetes `ok`, 0 `DATA RACE`, exit 0 (~5 min) |
| `go mod tidy` (raíz) + `git diff --stat` | sin cambios; restaurado |
| `go build && go vet` en `drivers/*` **sin go.work** | **FALLA los 5** (`missing go.sum entry` / `no required module provides package …/quarkdriver`) — QK-5 |
| `go build/vet/test` en `drivers/*` **con go.work externo** | OK los 5 (`ok … 0.4-0.9 s`) |
| `go mod tidy` standalone en `drivers/mysql`, `drivers/postgres` | diff 145 / 200 líneas (sube quark a v1.10.0, postgres añade el `require`); restaurado |
| `cd bugbash && go build ./...` | OK (módulo aparte compila contra el checkout) |
| `cd benchmarks && go vet ./...` | OK |
| `go run ./examples/superapp -engines=sqlite -gate=strict` | **GATE estricto OK**: 328/720 símbolos cubiertos, 0 sin cubrir, **392 allowlisted** (54 % de la superficie queda fuera del gate por allowlist; `examples/superapp/README.md:88` aún dice "655 símbolos en 7 paquetes") |
| Instalación real del módulo publicado: módulo vacío + `go get github.com/jcsvwinston/quark/drivers/sqlite@v0.1.0` (con red) | `go get` resuelve quark a **v1.10.0** (porque v1.8.0 no tiene `quarkdriver`); arrastra pgx/go-ora/go-mssqldb/decimal como `// indirect`; `go build` de un `main` que también importa `quark` falla con `missing go.sum entry … validator/v10` hasta hacer `go get github.com/jcsvwinston/quark` (dos `go get`, no uno) |

### DX quickstart (`scratchpad/auditoria/quark-dx/`)

Programa mínimo del README con `replace` al checkout local, tres variantes:

| Variante | `go mod tidy` | `go run` | `IsUniqueViolation` ante duplicado |
|---|---|---|---|
| `readme` — literal, `_ "modernc.org/sqlite"` | OK (offline) | OK: crea tabla, inserta (`id: 1`), lista, actualiza, borra | **false** (el error llega como `constraint violation … UNIQUE constraint failed: users.email (2067)` pero no se clasifica) |
| `withdriver` — `_ "github.com/jcsvwinston/quark/drivers/sqlite"` (+ `replace` del driver) | OK | OK, idéntico | **true** |
| `nodriver` — sin ningún import de driver | OK | Falla con el error guiado: `the sqlite driver ships as its own module … go get github.com/jcsvwinston/quark/drivers/sqlite … import _ "…/drivers/sqlite" (linked right now: none)` — claro y accionable | n/a |
| `alias` — driver ficticio registrado como `postgres` y `sqlite3` | OK | `quark.New("postgres")`, `quark.New("sqlite3")` y `quark.New("pq")` **fallan** con el mismo error guiado aunque el driver está enlazado (QK-1) | n/a |

Conceptos hasta la primera consulta: 6 (`quark.New(driver, dsn)`, import del módulo de driver, tags `db`/`pk`/`quark`, `client.Migrate`, `quark.For[T](ctx, client)`, `List`). Comandos: 2 `go get` (quark + driver). Pasos que sobran: ninguno en código; sobra la contradicción entre lo que dice el README (import directo) y lo que hace el runtime (clasificación sólo con el módulo). El log `INFO quark client initialized dialect=sqlite max_results=10000` en cada arranque es ruido para un quickstart (debería ser DEBUG). `List()` sin `Limit` avisa con WARN y aplica 100 filas (`query_exec.go:330`), comportamiento documentado y controlable con `WithStrictReads`/`AllowUnbounded`.
