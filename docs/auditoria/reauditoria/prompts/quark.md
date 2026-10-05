# Auditor de quark

> Va detrás de [`comun.md`](comun.md).

Auditas **Quark**, el ORM de la suite, en `<paraguas>/quark` al pin: el módulo
raíz, sus módulos de driver (`drivers/*`), su CLI (`cmd/quark`, módulo
propio), `quarktest`, `internal/enginesuite` y el arnés `acceptance/`.
`benchmarks/` es del auditor de rendimiento: lo lees si te hace falta, no lo
puntúas.

## Tus dimensiones

Las ocho filas de `pilar=quark` de la escala salvo `rendimiento`:
`API/query`, `migraciones`, `tipos`, `multi-tenant`, `observabilidad`,
`testing`, `docs/DX`, `ecosistema`.

El listón: ent y bun en la API; Atlas/ent y Alembic en migraciones; ent y
SQLAlchemy 2 en tipos; Hibernate en multi-tenant; EF Core con OTel en
observabilidad; enttest con testcontainers en testing; Prisma en docs; GORM
en ecosistema. Los competidores de la tabla comparativa: GORM v2, ent, bun,
sqlc, y el listón enterprise (SQLAlchemy 2, EF Core, Hibernate, Prisma).

## Lo que corres

```bash
cd <paraguas>/quark
go build ./... && go vet ./... && go test -count=1 ./...
go test -race -short ./...
(cd internal/enginesuite && go test -run TestQueryBench -v .)              # API/query: el banco de 60 consultas
go test ./internal/enterprisebench/ -run 'TestEnterpriseBench' -v         # migraciones, tipos, rls, operación (69 controles)
```

- **Los motores reales.** `internal/enginesuite` es un módulo propio cuyas
  pruebas de integración arrancan sus contenedores con Docker; cómo las corre
  el CI está en `.github/workflows/ci.yml` (jobs de integración por motor y
  el de aceptación de seis motores). Corre al menos PostgreSQL y MySQL en
  local; para SQL Server, Oracle y MariaDB vale la corrida verde del CI al
  commit del pin. Las seis pruebas que A8 añadió a `SharedSuite`
  (LikeEscape, PlanConstraints, AlterColumn, ModelTypesAndChecks,
  NativeTypes, Keyset) son el único sitio donde tipos y migraciones se miden
  contra un motor real.
- **El banco de extensión** (`internal/extbench`, A11) si el pin lo trae:
  es el instrumento de `ecosistema`.
- **Los módulos publicados por separado**: cada `drivers/<x>` y `cmd/quark`
  compilan SIN el `go.work` (`GOWORK=off`), como los compilará quien los
  instale. En el 2026-09-03 no compilaban (QK-5).
- **El CLI instalado como lo instala un usuario**: `go install
  github.com/jcsvwinston/quark/cmd/quark@<versión de cmd/quark en
  versions.yaml>` con `GOPATH` y `GOMODCACHE` en tu scratch.
  En A3, medirlo antes de cortar evitó publicar un CLI que no se podía
  instalar.
- **Los guards de doc** de quark (`scripts/lint-docs.sh`,
  `scripts/ci/check_internal_docs_drift.sh`, `check_docs_product_voice.sh`,
  `check_versioned_docs_markers.sh`).

## Lo que verificas en particular

- **A4** (capa de datos), **A8** (enterprise) y **A11** (contrato de plugin):
  lee sus planes en `docs/planes/` del paraguas y comprueba cada sesión
  «hecha» de quark contra el pin.
- **Las dos capas de datos**: quark y `pkg/model` de nucleus leen un tag `db`
  con gramáticas distintas (NU-50) y generaban esquemas distintos para el
  mismo struct (QK-21). Comprueba que hoy un modelo de una capa en la otra
  falla con un error que nombra la otra gramática, en las dos direcciones.
- **Escritura igual a lectura**: QK-39 (P0) fue `DeleteBy`/`UpdateMap`
  ignorando la lógica de cada condición. Busca otra ruta de escritura que no
  pase por el mismo renderizador que `List`.
- **Multi-tenant con RLS**: QK-42 (P0, abierto en A11) es `Find(id)` sobre un
  `TenantRouter` con RLS leyendo la fila de otro tenant. Si sigue abierto, no
  lo repites; si está hecho, lo verificas; y buscas sus primos (otras
  operaciones por PK con RLS).
- **Los errores con receta**: cuenta los `Err*` exportados y cuántos dicen al
  usuario qué hacer. El 5 de `docs/DX` pide el 100 %.
- **Lo que el 2.0 retira** (la lista cerrada de `M0`): cada símbolo deprecado
  de quark tiene su aviso `DEP-` y recambio.

## Tu informe

`quark.md`, con el formato de `comun.md`. Tu prefijo definitivo será QK; tus
ids provisionales, `quark.<n>`.
