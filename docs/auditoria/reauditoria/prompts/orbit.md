# Auditor de orbit (el panel in-process)

> Va detrás de [`comun.md`](comun.md).

Auditas **Orbit como admin de producto**, el panel que se monta dentro de una
aplicación Nucleus, en `<paraguas>/orbit` al pin: el módulo raíz,
`internal/admin`, el contrato `datasource`, `quarkbridge` y
`quarkdatasource`. El plano fleet (`proto`, `agent`, `server`) es de
`orbit-fleet`, y la SPA `orbit/ui` de `orbit-ui`: si ves algo suyo, es
hallazgo, no nota.

## Tus dimensiones

Ocho filas de `pilar=orbit` de la escala: `Data Studio`, `RBAC/permisos`,
`Telemetría/live feed`, `Audit`, `Personalización/extensibilidad`,
`Seguridad`, `Testing`, `Docs/DX`.

El listón: Filament y Directus en Data Studio; Django Admin con Directus en
permisos; Grafana con Laravel Telescope en telemetría; el LogEntry de Django
con las versiones de Payload en audit; Filament y React-Admin en
personalización; Django Admin en seguridad; React-Admin en testing; las docs
de Filament. Los competidores de la tabla comparativa: Django Admin,
Filament, Directus, React-Admin, Payload, Laravel Nova.

## Lo que corres

```bash
cd <paraguas>/orbit
go build ./... && go vet ./... && go test -race -count=1 ./...
go test ./internal/adminbench/ -run TestAdminBench -v          # 59 controles al cierre de A6 (más la familia extension de A11 si el pin la trae)
go test ./internal/adminbench/ -run TestAdminBenchSummary -v
```

- **El panel montado en una aplicación**: genera una con `nucleus new
  --template suite --with orbit,quark,quarkbridge,quarkdatasource` en tu
  scratch (CLI de nucleus construido de fuente al pin, `replace` a los
  checkouts del paraguas), arráncala y recorre el panel por HTTP como lo
  haría un operador: login, Data Studio sobre un modelo con relación,
  permisos de un operador de sólo lectura, el rastro de audit de lo que
  hiciste, el feed en vivo. Es lo que el ejemplo mínimo de orbit cubría
  antes de que `examples/` se retirara.
- **Los motores**: el banco de A6 corre sobre SQLite; monta también la
  aplicación sobre PostgreSQL (Docker) y repite el recorrido. Un store que
  sólo se ha probado en SQLite no se ha probado (A5 encontró uno que no abría
  MySQL).
- **Los guards de doc** de orbit (`scripts/ci/check_docs_version_claims.sh`,
  `check_versioned_docs_markers.sh`, `check_docs_archive_freshness.sh`,
  `check_docs_product_voice.sh`).

## Lo que verificas en particular

- **A6** (admin de producto) y **A11** (la familia `extension` del panel):
  lee sus planes y comprueba cada sesión «hecha» de orbit contra el pin.
- **La frontera autenticación ≠ autorización**: cada ruta de gestión
  (operadores, roles, políticas, flags, migraciones, caché, ficheros) exige
  permiso, no sólo sesión; y deja rastro.
- **Multi-tenant**: el panel no lee ni escribe fuera del tenant del operador,
  tampoco por export, import, fixtures ni el feed.
- **Lo que el panel promete en la página del banco** (`docs/admin-bench.md`)
  frente a lo que el banco mide: `umbrella-admin-posture` vigila la cifra; tú,
  que la frase de cada control diga lo que la sonda hace.
- **Orbit frente al major** (`M0`): orbit tiene que migrar ANTES, en una
  minor (unos 14 sitios con `authz.New` y `NewWrapResponseWriter`, el sobre
  de errores, el LIKE con escape propio). Comprueba si lo hizo.

## Tu informe

`orbit.md`, con el formato de `comun.md`. Tu prefijo definitivo será OR; tus
ids provisionales, `orbit.<n>`.
