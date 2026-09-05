# Nucleus — madurez

Auditoría sobre `github.com/jcsvwinston/nucleus` en el tag `v1.23.0` (commit `253ec05c`, checkout `/Users/jcsv/GolandProjects/nucleus`), Go 1.26.6 darwin/arm64, 2026-09-03. Todo lo afirmado se ha leído en código o ejecutado; las cifras de la sección 6 son medidas propias. No se ha editado el repositorio.

## 1. Veredicto

Nucleus es un **runtime operativo serio con un producto de aplicación a medias**: la mitad "plataforma" (config con veredicto único, migraciones con ledger y drift, outbox, tasks, storage con contratos hoja, observabilidad OTel, seguridad por defecto, contratos congelados, CI con cinco motores reales) está al nivel o por encima de Buffalo/Beego y de la mayoría de frameworks Go; la mitad "producto" (ORM con relaciones, auth completa con OAuth/MFA/reset, vistas, tiempo real, DI, OpenAPI derivado del código, cliente de test de alto nivel) sigue siendo un conjunto de primitivas y está muy por debajo del listón Django/Rails/Laravel/Spring/Nest/Phoenix. El arco D3 (ADR-030/031) ha cumplido en el binario de la app pero ha dejado cuatro cabos que hoy rompen la experiencia de quien clona, evalúa o mantiene el repo: el ejemplo canónico `examples/mvc_api` no arranca (falta el import del driver), los módulos hermanos no compilan solos, el runtime recomienda un comando (`nucleus add prometheus`) que no existe, y el `go.mod` raíz sigue arrastrando los cinco drivers. La documentación pública (README, SPEC, website) describe todavía el mundo pre-D3 (build tags, módulo único, 38 comandos) en las tres primeras pantallas que ve un usuario nuevo. Veredicto: **3/5 global — "framework de plataforma maduro, framework de aplicación en construcción"**; no compite hoy con Django/Rails y sí puede competir con Buffalo/Beego/Encore en el nicho "Go stdlib-first con operaciones de verdad", si cierra los defectos P1 y la deriva documental antes de seguir añadiendo superficie.

| Dimensión | Nota (1-5) | Motivo en una línea |
|---|---|---|
| Routing/HTTP | 3 | ServeMux 1.22 con params, grupos, `Resource`, `Mount`; sin versionado, negociación, binding tipado de query, ni SSE viable con la pila por defecto |
| Datos | 3 | `database/sql` + migraciones con ledger/checksum/drift excelentes; `pkg/model` es CRUD por reflexión sin relaciones ni query builder; sin lock de migraciones |
| Auth/Authz | 2 | bcrypt+JWT+sesiones scs+cadena de backends+Casbin default-deny sólidos; sin OIDC in-tree, API keys, MFA, reset, lockout; `iss/aud` sin verificar |
| Jobs/Eventos | 3 | asynq completo (DLQ, líder, métricas) pero exige Redis; proveedor memory degrada en silencio; tres buses de eventos sin puente |
| Observabilidad | 4 | slog con redacción, OTel trazas+métricas, exportadores como módulos, `/healthz` agregado; falta `/readyz`, `http.route` con cardinalidad |
| Seguridad | 4 | CSRF doble capa, cabeceras, CORS deny-by-default, proxies de confianza, topes de body, default-deny; XFF sin validar en sesiones, fuga de `err.Error()` |
| Testing | 3 | `nucleustest` in-process con puerto libre, `TempSQLite`, `MintToken`, suites de conformidad; sin factories, cliente de test ni transacción por test; un flaky |
| Docs/DX | 3 | Website versionado y quickstart honesto; README/SPEC/installation describen build tags y módulo único que ya no existen; ~10 conceptos hasta el primer endpoint |
| CLI/generadores | 3 | 40 comandos, `generate module` ADR-022 impecable, `add` escribe el import; `routes`/`serve`/`migrate status` ciegos a los módulos del binario; `--help` sin subcomandos |
| Ecosistema/plugins | 2 | Registros in-process bien diseñados y 12 módulos hermanos; cero plugins ejecutables de ejemplo, cero proveedores OIDC, comunidad de un autor |

## 2. Tabla comparativa

Leyenda: ✅ completo · ◐ parcial · ❌ ausente. La celda de Nucleus lleva la evidencia (fichero).

| Capacidad | Nucleus | Gin/Echo/Chi | Buffalo/Beego | Encore/Goa | Listón Django/Rails/Spring |
|---|---|---|---|---|---|
| Router: params, wildcard, grupos, middleware por grupo | ✅ `pkg/router/mux.go:162-266` (ServeMux 1.22, `{id}`, `{path...}`, `Group/With`) | ✅ | ✅ | ✅ (generado) | ✅ |
| Versionado de API / negociación de contenido | ❌ sólo `Route("/v1")` manual; `c.JSON/HTML` explícitos, no lee `Accept` (`pkg/router/context.go`) | ◐ | ◐ | ✅ Goa | ✅ (DRF versioning, Rails `respond_to`) |
| REST resources / controladores | ✅ `Router.Resource` + interfaces `Indexer/Shower/...` (`pkg/nucleus/router.go:253`) | ❌ | ✅ | ✅ | ✅ |
| Binding JSON/form + validación | ◐ `Bind/BindForm` con topes y guard mass-assignment (`pkg/router/render.go:64`, `bind_form.go:53`); sin binding de query/path a struct; `BindXML` sin tope | ✅ (Gin/Echo `ShouldBind` query/uri/header) | ✅ | ✅ (tipado desde DSL) | ✅ |
| Templates/vistas | ◐ `html/template` recursivo + `fs.FS` por módulo (`pkg/app/templates_loader.go`); sin layouts, helpers, hot reload | ◐ | ✅ Buffalo (plush, hot reload) | n/a | ✅ |
| Sesiones | ✅ scs memory/sql/redis, cookies seguras, `__Host-` (`pkg/auth/session.go`, `pkg/app/app.go:1515`); flash roto (NU-9) | ◐ (middleware externo) | ✅ | ❌ | ✅ |
| Auth password + JWT | ✅ bcrypt 12, HS/RS/ES256, keyset, JWKS (`pkg/auth/jwt.go:168-451`) | ❌ (externo) | ◐ | ◐ Encore auth handler | ✅ |
| Cadena de backends / LDAP | ✅ `pkg/auth/backend_registry.go:172` + `providers/ldap` (rechazo ≠ indisponible) | ❌ | ❌ | ❌ | ✅ (Django backends, Spring Security) |
| OAuth2/OIDC/SAML | ◐ seam ADR-028 (`pkg/auth/federated`) **sin ningún proveedor** ni rutas montadas (`pkg/app/app.go:1730`) | ❌ | ◐ Buffalo goth | ❌ | ✅ |
| API keys, MFA/TOTP, magic link, reset de contraseña, lockout | ❌ ninguno (grep en `pkg/auth`); D4 (API keys) sigue pendiente | ❌ | ❌ | ❌ | ✅ (Laravel Sanctum/Fortify, Rails Devise, Spring) |
| Authz | ✅ Casbin deny-override, default-deny, políticas por módulo (`pkg/authz/enforcer.go:24`, `pkg/nucleus/module_policies.go`); sin adaptador BD ni permisos por objeto | ❌ | ◐ | ✅ Encore (auth data) | ✅ |
| ORM: relaciones, eager loading, query builder | ❌ `pkg/model/crud.go` es CRUD por reflexión sobre `*sql.DB`; lo cubre Quark fuera del framework | ❌ (externo) | ✅ Pop / Beego ORM | ❌ | ✅ |
| Migraciones SQL con ledger, checksum, drift, down | ✅ `pkg/db/migrate.go:64-136`, `schema_drift.go:120`; embebidas por módulo; **sin lock** (NU-13) | ❌ | ✅ | ✅ Encore | ✅ |
| Migraciones autogeneradas desde modelos | ◐ `AutoMigrate` sólo `CREATE TABLE IF NOT EXISTS` (`pkg/app/app.go:117`); `makemigrations` crea un par vacío | ❌ | ◐ | ❌ | ✅ |
| Multi-BD, motores | ✅ alias por config, 5 motores como módulos (`drivers/*`), CI con Postgres/MySQL/MSSQL/Oracle reales | ❌ | ◐ | ◐ | ✅ |
| Jobs en cola con retry/DLQ | ✅ asynq (`pkg/tasks/providers/asynq/runtime.go:220`); **Redis obligatorio**; memory ignora retry (NU-12) | ❌ | ◐ Buffalo workers | ✅ Encore pub/sub | ✅ (Sidekiq, Celery, Solid Queue sin Redis) |
| Cron/scheduler | ✅ robfig cron + líder Redis (`pkg/tasks/providers/asynq/leader.go:105`) | ❌ | ◐ | ✅ Encore cron | ✅ |
| Outbox transaccional | ✅ `pkg/outbox` claim atómico, lease, backoff, webhook HMAC (`dispatcher.go:430`); Kafka preview | ❌ | ❌ | ◐ | ◐ (gems/paquetes) |
| Signals/eventos de dominio | ◐ `pkg/signals` bus + relay Redis; sin handlers tipados; 3 buses solapados | ❌ | ◐ Beego | ✅ | ✅ |
| WebSockets / SSE / canales | ❌ nada; `TimeoutHandler` sin `Flusher` (`pkg/router/httputil.go:241`) | ◐ (externo) | ◐ | ◐ | ✅ (Channels, ActionCable, Phoenix) |
| i18n | ◐ catálogos compilados + `Accept-Language` + `c.T` (`pkg/i18n`); sin plurales, fechas, validación traducida | ❌ | ◐ | ❌ | ✅ |
| Mail | ◐ `Sender` noop/smtp + plugins ejecutables (`pkg/mail/mail.go:143`); **sólo text/plain**, sin adjuntos ni plantillas | ❌ | ✅ | ❌ | ✅ |
| Storage (local, S3, GCS, Azure) | ✅ contrato hoja + registro, prefijo tenant, URLs firmadas, breaker (`pkg/storage/provider/store.go:99`, `providers/storage-*`) | ❌ | ◐ | ◐ Encore buckets | ✅ |
| Cache | ◐ memory + SQL, experimental (`pkg/cache/cache.go:36`); sin Redis pese a la dep, sin tags/stampede | ❌ | ✅ Beego | ✅ Encore | ✅ |
| OpenAPI | ◐ modelo 3.1 escrito a mano + CLI `openapi` (`pkg/openapi`); sin generación desde rutas/structs ni UI | ◐ (swag) | ◐ Beego | ✅ (contract-first) | ✅ (DRF spectacular, springdoc, Nest) |
| Observabilidad (slog, OTel, request id) | ✅ `pkg/observe`, `pkg/router/otel.go`, `pkg/db/telemetry.go`; exportadores como módulos | ◐ | ◐ | ✅ Encore | ✅ |
| Health / readiness | ◐ `/healthz` agregado (`pkg/app/healthz.go:41`), `health --deploy` exit 1; sin `/livez` `/readyz` separados | ❌ | ❌ | ✅ | ✅ (actuator) |
| Circuit breaker | ✅ `pkg/circuit` en mail y storage; no en BD/HTTP clientes | ❌ | ❌ | ❌ | ◐ (Resilience4j) |
| Kit de testing | ◐ `nucleustest.Start/StartApp/TempSQLite/MintToken` (`pkg/nucleustest/nucleustest.go:57-232`); sin factories, cliente de test, tx-por-test | ◐ | ✅ | ✅ Encore | ✅ |
| Plugins / extensiones | ◐ registros `init()` por contrato hoja (ADR-023/025/026) + plugins ejecutables JSON (`pkg/plugins`); **ningún ejemplo ejecutable en el repo** | ◐ | ✅ Buffalo plugins | ❌ | ✅ |
| Multi-tenant | ◐ resolución subdominio/header, BD por tenant, prefijo storage (`pkg/app/requestscope.go:199`); sin filtrado de filas ni rate limit por tenant efectivo (NU-4) | ❌ | ❌ | ❌ | ◐ (paquetes) |
| Config y secretos | ✅ koanf, env `NUCLEUS_`, multi-fichero, 5 capas de validación con did-you-mean (`pkg/app/config_validate_layers.go`); `secrets-aws`; sin `${VAR}` en claves | ❌ | ◐ | ✅ Encore | ✅ |
| Seguridad por defecto (CSRF, cabeceras, CORS, rate limit) | ✅ `pkg/router/csrf.go`, `middleware.go:106`, `corsmw.go`, `ratelimit.go`; posture congelada en `contracts/baseline/security_posture.txt` | ❌ (middlewares opcionales) | ◐ | ◐ | ✅ |
| Admin | ◐ vía módulo externo orbit (ADR-019); no en el core | ❌ | ✅ Beego admin | ✅ Encore dashboard | ✅ (Django admin) |
| CLI de proyecto | ✅ 40 comandos + 7 alias Django (`internal/cli/root.go:44-84`); `doctor`, `health --deploy`, `add` | ❌ | ✅ | ✅ | ✅ |
| Generadores | ◐ `new`, `generate module` (ADR-022), `resource`, `startapp`; no montan en `main.go`, no generan tests (module) ni Dockerfile/CI | ❌ | ✅ | ✅ | ✅ |
| Hot reload / dev server | ❌ ninguno (grep `fsnotify` en `pkg`/`internal` vacío) | ❌ (air externo) | ✅ Buffalo dev | ✅ Encore run | ✅ |
| DI / contenedor | ❌ `Runtime` es un service locator (`pkg/nucleus/runtime.go:41`) | ❌ | ❌ | ✅ (implícito) | ✅ (Spring, Nest) |
| Deploy (Dockerfile, compose, health) | ◐ Dockerfile sólo de la CLI (`Dockerfile:8-15` fósil), compose heredado de Quark, sin `.dockerignore` | ❌ | ◐ | ✅ Encore cloud | ✅ |
| Contratos de compatibilidad congelados | ✅ 6 baselines en `contracts/` (símbolos, CLI, JSON, claves, extensión, posture medida) — único en Go | ❌ | ❌ | ◐ | ◐ |
| Tamaño hello-world | ◐ 60 MB (45 MB strip) con sqlite; 31/21 MB sin driver — vs ~10 MB Gin | ✅ | ◐ | ◐ | n/a |

## 3. Lo que falta para competir

### Bloqueante (sin esto un equipo nuevo no lo adopta o se rompe al primer paso)
0. **El ejemplo canónico no arranca** (NU-55): `examples/mvc_api` — el que el README llama "canonical starting point" y el quickstart del sitio incrusta como "slice completo" — sale con exit 1 por falta del import `drivers/sqlite` desde ADR-031.
1. **Repositorio multi-módulo que no compila solo**: `cd drivers/sqlite && go build ./...` falla en un clon limpio; `drivers/postgres` ni siquiera requiere el core aunque su test lo importa (NU-1). Sólo CI con `go work init` lo esconde.
2. **Documentación de entrada falsa**: README:24/37/67/297, `website/docs/getting-started/installation.md:12-68` y `SPEC.md:328` hablan de build tags `-tags mssql/oracle`, "single Go module" y "38 commands" (NU-24..27). Es lo primero que lee un evaluador y contradice ADR-031.
3. **El runtime recomienda un comando inexistente** (`nucleus add prometheus`, NU-3) y todo proyecto recién creado arranca con dos WARN (metrics no servidas, jwt sin secreto). Primera impresión: "esto está roto".
4. **Auth incompleta para producto**: sin OIDC real (el seam ADR-028 no tiene proveedor), sin API keys (D4 sin decidir), sin reset de contraseña, MFA ni lockout. Cualquier SaaS lo necesita en la semana 1; Django/Rails/Laravel lo traen.
5. **Sin ORM con relaciones en el framework**: `pkg/model` no hace joins ni eager loading; la respuesta oficial es Quark, pero Quark vive en otro módulo con su propio ciclo y el quickstart enseña SQL a mano.
6. **Jobs durables exigen Redis**: no hay cola SQL (Solid Queue/Oban/Django-Q); el proveedor memory pierde trabajos y no reintenta.

### Diferenciador (lo que ya hace mejor que el mercado y debe protegerse/exhibir)
- Contratos congelados y medidos (`contracts/`), incluida la postura de seguridad tomada de una respuesta HTTP real — ningún framework Go lo hace.
- Config con "un solo veredicto" (CLI, builder y struct validan igual) y did-you-mean.
- `requireDriver` (`pkg/db/db.go:224-244`): el mejor mensaje de "driver olvidado" de un framework Go.
- Migraciones con ledger + checksum + drift de esquema, con matriz real de 5 motores en CI.
- Módulos vertical-slice (ADR-022): políticas, CSRF, migraciones y plantillas viajan con el paquete; `generate module` lo produce en 20 ms.
- Cadena de autenticación con semántica rechazo/indisponible (break-glass) y registros por contrato hoja (2 paquetes de deuda para implementar un backend).
- Outbox transaccional con dispatcher de leasing en el core.

### Nice-to-have
- Binding de query/path a struct; negociación por `Accept`; versionado de API declarativo.
- Hot reload (`nucleus dev`), autocompletado de shell, `nucleus routes` que vea los módulos del binario.
- SSE/WebSockets con timeout excluible por ruta; cache Redis con tags; mail HTML/adjuntos/plantillas.
- Factories y cliente de test sobre `Context`; `/livez` y `/readyz`.
- DI ligera (constructores con dependencias declaradas) para sustituir el service locator `Runtime`.

## 4. Mejoras propuestas

| Horizonte | Mejora | Esfuerzo | Valor | Dependencia |
|---|---|---|---|---|
| Corto (≤1 mes) | Cerrar NU-1: subir `require nucleus` de los 11 módulos a v1.23.0, añadir require en `drivers/postgres`, guard CI `GOWORK=off go build` por módulo (ya existe para ldap: `ci.yml:454`) | S | Alto | Tren de release (memoria: los hermanos no ven fixes hasta subir el `require`) |
| Corto | Cerrar NU-2: quitar `release-as`/`last-release-sha` de `release-please-config.json` | XS | Alto (desbloquea el próximo release de cualquier driver) | — |
| Corto | Cerrar NU-3: `nucleus add otlp\|prometheus` + scaffold que importa `exporters/prometheus` o `metrics_path` vacío por defecto; silenciar el WARN de JWT cuando `auth_backends` está vacío | S | Alto (primera impresión) | — |
| Corto | Cerrar NU-55: import de `drivers/sqlite` en `examples/mvc_api/main.go` + smoke test en CI que arranque el ejemplo (`showcase-smoke` ya hace lo equivalente para el showcase) | XS | Muy alto (primera impresión) | — |
| Corto | Barrido documental (NU-24..28, NU-56..67): QUICKSTART/installation (P0), README, SPEC §3.3/§3.10/§4, `MountOpenAPI` → `MountOpenAPIHandler`, `metrics_path` requiere el exporter, cifras reales ("40 comandos", tamaños medidos), baseline `add`, CHANGELOG sin "BREAKING" en minor o ADR que lo justifique; guard CI `grep -- '-tags mssql'` sobre docs y website | S | Alto | snapshot 1.24.0 del sitio |
| Corto | Seguridad rápida: mover rate limit tras identidad (NU-4), enmascarar `err.Error()` (NU-5), `ClientIPFromRequest` sin XFF (NU-7), `BindXML` con tope (NU-10), `WithIssuer/WithAudience` (NU-33), subir `golang.org/x/crypto` a ≥0.56.0 | S | Alto | ninguna; actualizar `security_posture.txt` si cambia |
| Corto | Lock de migraciones por dialecto (NU-13) y timestamps UTC uniformes (NU-15) | S | Medio | — |
| Corto | `generate module --with-policy` por defecto deny (NU-14); `--help` con subcomandos (NU-18); `routes --from-binary` o `nucleus.RunContext` que vuelque la tabla con `NUCLEUS_PRINT_ROUTES=1` (NU-16) | M | Medio | — |
| Medio (1-3 meses) | Decidir D4 y entregar API keys (`pkg/auth/apikey`: hash, scopes, rotación, middleware) + lockout/rate limit de login | M | Alto | Decisión D4 de Carlos |
| Medio | Proveedor OIDC in-tree (`providers/oidc`, code flow + PKCE, discovery) sobre el seam ADR-028, con rutas start/callback montadas por la app | M | Alto | ADR-028 ya cableado |
| Medio | Cola de jobs SQL durable (`tasks/providers/sql`, tabla + `SKIP LOCKED`) y proveedor memory honrando `MaxRetry/Timeout` (NU-12) | M | Alto | `pkg/db` |
| Medio | Flash con ciclo de vida (NU-9), SSE viable (timeout 0 = sin timeout, exclusión por ruta, `Flusher` propagado) (NU-6), `/livez` `/readyz` | S-M | Medio | — |
| Medio | Binding de query/path a struct + negociación `Accept` + versionado `r.Version("v1")` | M | Medio | `pkg/router` |
| Medio | Kit de test: factories, `nucleustest.Client` con helpers JSON/cookies/CSRF, transacción por test, fakes capturadores de mail/storage/tasks | M | Alto (adopción) | — |
| Medio | Mail HTML/multipart/adjuntos/plantillas + cola vía outbox | M | Medio | `pkg/outbox` |
| Medio | Cache Redis (la dep ya está) con `GetOrSet`, tags y singleflight | S | Medio | — |
| Largo (3-12 meses) | Integración oficial Quark-en-Nucleus como "capa de datos por defecto" (quickstart con Quark, `generate module --orm quark`, migraciones autogeneradas desde modelos Quark) | L | Muy alto | Quark, orbit, tren de tres repos |
| Largo | OpenAPI derivado de `Resource`/structs (anotaciones en tags) + Swagger UI en dev; validación de requests contra el spec | L | Alto | `pkg/openapi` experimental |
| Largo | Tiempo real: canales WS/SSE con broadcast in-process y relay Redis (reusar `pkg/signals`) | L | Medio | NU-6 |
| Largo | DI ligera y hooks ordenables por dependencia; rollback de `OnShutdown` en arranque parcial (NU-45) | M | Medio | ADR nuevo |
| Largo | Reducir el grafo: sacar `internal/dbclassify` del core (predicados al lado de cada driver), quitar deps de test del `go.mod` raíz (miniredis, goleak) vía módulo `internal/testdeps` o `tools.go`; objetivo real 87 módulos (NU-8) | M | Medio | ADR-031 |
| Largo | Ecosistema: un plugin ejecutable de ejemplo en el repo, `nucleus completion`, `nucleus dev` con recarga, plantilla de módulo comunitario | M | Alto (adopción) | — |

## 5. Defectos encontrados

Severidad: P0 = pérdida de datos/seguridad explotable/bloquea a todos; P1 = rompe un flujo principal o el tren; P2 = defecto real con workaround; P3 = calidad/deuda.

| Id | Sev | Fichero:línea | Evidencia | Corrección propuesta |
|---|---|---|---|---|
| NU-1 | P1 | `drivers/sqlite/go.mod:5` (y mssql, mysql, oracle, exporters/*, providers/secrets-aws, storage-*) ; `drivers/postgres/go.mod` ; `drivers/postgres/postgres_test.go:11` | Pinan `nucleus v1.22.0` (ldap v1.21.0) pero importan `pkg/db/driver` e `internal/dbclassify`, que sólo existen en v1.23.0: `cd drivers/sqlite && go build ./...` → "missing go.sum entry"; con `-mod=mod` go reescribe go.mod (+24) y go.sum (+41). `drivers/postgres` no requiere el core y su test importa `pkg/db` → `go vet` falla. CI lo tapa con `go work init` (`.github/workflows/ci.yml:386`) | Subir `require github.com/jcsvwinston/nucleus v1.23.0` en los 11 módulos, añadir el require a `drivers/postgres`, y un guard `GOWORK=off go build ./... && go vet ./...` por módulo (como `providers-ldap` en `ci.yml:454`) |
| NU-2 | P1 | `release-please-config.json:106-195` | 11 módulos ya publicados en `v0.1.0` (tags sobre #453) conservan `release-as: "0.1.0"` y `last-release-sha`; release-please los reutiliza en cada manifest-PR | Borrar `release-as`, `last-release-sha` y `bootstrap-sha` de esos paquetes en un `chore(release)` antes del siguiente cambio en un módulo |
| NU-3 | P1 | `pkg/observe/otel.go:136` ; `internal/cli/add.go:166-187` ; `pkg/app/app.go:253` ; `internal/knownproviders/knownproviders.go:117-125` | WARN en cada arranque: `fix="run nucleus add prometheus"`; `nucleus add prometheus` → `error: unknown module "prometheus"`. `PrometheusEnabled` deriva de `metrics_path != ""` (default no vacío) así que todo scaffold nace con el WARN | Añadir `TelemetryExporter` a `lookupAddable`/`addableList`; en el scaffold importar `exporters/prometheus` o dejar `metrics_path` vacío; degradar el WARN a INFO cuando el exporter no está enlazado por diseño |
| NU-4 | P2 | `pkg/router/middleware.go:12-24` ; `pkg/router/ratelimit.go:190-212` ; `pkg/app/app.go:373,948` | `rateLimitMiddleware` está en `DefaultStack` (capa externa, `rebuildHandler` envuelve el primero como más externo); `OptionalJWTMiddleware` y `scopeResolver` se `Use` después. `UserIDFromCtx`/`ClaimsFromContext` siempre vacíos → `rate_limit_by_role` y "per-tenant rate limiting" (README:77) son inertes | Montar el limitador después de identidad/scope, o resolver claims/tenant dentro del limitador; test que compruebe la clave `user:`/`tenant:` |
| NU-5 | P2 | `pkg/router/context.go:163-165` | `handleError` responde 500 con `{"error": err.Error()}` para cualquier error no `DomainError`/`HTTPError` (mensajes de driver, rutas) | Enmascarar ("internal error") y registrar con `ErrorHandler.Report`; mantener el detalle sólo con `env: development` |
| NU-6 | P2 | `pkg/router/httputil.go:241` ; `pkg/app/app.go:1226-1234` | `http.TimeoutHandler` no expone `Flusher`; `toTimeoutSeconds(0)` devuelve 30 → no hay forma de desactivar el timeout por config; SSE/streaming imposibles con la pila por defecto | `0`/negativo = sin timeout; exclusión por ruta o timeout propio que propague `Flush`/`Hijack` |
| NU-7 | P2 | `pkg/auth/session_runtime.go:150-176` ; `pkg/observability/hooks/http.go:110` | `ClientIPFromRequest` toma el primer `X-Forwarded-For`/`X-Real-IP` sin trusted proxies; contradice `pkg/router/httputil.go:112-127` (QCD-FW-18). Afecta a metadata de sesión y a la IP de auditoría | Usar sólo `r.RemoteAddr` (ya reescrito por `RealIP` cuando el proxy es de confianza) |
| NU-8 | P2 | `go.mod:22-46` ; `internal/dbclassify/link.go:17-18` ; `cmd/nucleus/drivers.go:19` | El core requiere go-mssqldb, go-ora, pgx, mysql, modernc, go-redis, gomemcache, asynq; `go list -m all` en un scaffold = 138 módulos (ADR-031:121 promete 87); la CLI enlaza los 5 motores (60,8 MB). `go.mod` raíz aparece como `// indirect` en cada app generada | Mover los predicados de `dbclassify` a cada `drivers/*`; deps de test a un módulo `internal/testdeps`; publicar cifras medidas en ADR-031 |
| NU-9 | P2 | `pkg/auth/session.go:32,172-226` | `Flash` escribe `_flash:k`, nada lo borra tras la petición siguiente; `_flash_old:` sólo se escribe, nadie lo lee (grep vacío) | Middleware de envejecimiento: borrar `_flash:*` leídos al final de la request, promover `_flash_old:*` |
| NU-10 | P2 | `pkg/nucleus/context.go:24-31` | `BindXML` decodifica `r.Body` sin `MaxBytesReader` ni `validate.Validate`, a diferencia de `Bind/BindForm` (`pkg/router/render.go:84`) | Tope 1 MiB + validación + `errors.As(MaxBytesError)` → 413 |
| NU-11 | P2 | `pkg/errors/handler.go:126,141-174` | `throttleMap` con clave `err.Error()` (mensajes dinámicos) sin poda; `SampleRate` devuelve `false` "for now" | Podar entradas vencidas, clave por tipo, implementar muestreo |
| NU-12 | P2 | `pkg/tasks/providers/memory/memory.go:113-120,159-196` ; `scheduler.go:57` | Handler que falla sólo se loguea (sin retry); `MaxRetry/Queue/Timeout/Retention` ignorados; tareas diferidas descartadas con cola llena; error de encolado ignorado (`_, _ =`) | Honrar `MaxRetry` con backoff y `Timeout`; error explícito en opciones no soportadas; contador de ticks perdidos |
| NU-13 | P2 | `pkg/db/migrate.go:221-296` | Dos réplicas ejecutando `migrate up` aplican el mismo pendiente; en MySQL/Oracle (DDL autocommit) la segunda deja DDL aplicado y falla en el ledger | `pg_advisory_lock`/`GET_LOCK`/fila de lock por dialecto alrededor del plan |
| NU-14 | P2 | `internal/cli/generatemodule.go:432-433` | `generate module` emite `{anonymous, /x, *}` y `{anonymous, /x/*, *}` + `CSRFExempt` sin flag: todo CRUD generado nace público y escribible por anónimos | Por defecto sólo `read` anónimo (o nada) y `--with-policy open` explícito, con aviso en la salida |
| NU-15 | P2 | `pkg/db/migrate.go:471` ; `internal/cli/migrationmaintenance.go:136` vs `internal/cli/generate.go:464` | `migrate create` y `squashmigrations` usan hora local; `generate`/`startapp` usan UTC → ficheros creados en orden se ordenan al revés (`20260903203150_add_widgets` antes que `20260903183150_create_billings`, reproducido) | UTC en todos (`time.Now().UTC()`); test de orden |
| NU-16 | P2 | `internal/cli/routes.go:92` ; `internal/cli/serve.go:20-25` ; `internal/cli/migrate.go` | `routes` lista sólo `/healthz`, `serve` arranca sin los módulos del binario, `migrate status` dice "No migration files found" tras aplicar la migración embebida del módulo; los tres comandos son ciegos al binario real y `routes` además abre la BD y loguea WARNs para listar una ruta | `NUCLEUS_PRINT_ROUTES=1`/flag en `RunContext` que vuelque la tabla y salga; `migrate status` que lea el ledger por namespace de módulo; `routes` sin abrir BD |
| NU-17 | P2 | `internal/cli/openapi.go:46-75` | En un proyecto de `nucleus new` sin `internal/contracts`, el error es el stderr crudo de `go run` ("go get example.com/myapp/internal/contracts"), instrucción imposible | Comprobar `internal/contracts/contracts.go` antes y fallar con receta (`generate resource` / `startapp`) |
| NU-18 | P2 | `internal/cli/migrate.go:18-30` (+ 34 comandos con `flag.PrintDefaults`) | `--help` no lista subcomandos ni posicionales (`up/down/steps/status/drift/reset/refresh/create`); `migrate --config x` sin acción → `up` implícito | `fs.Usage` propio por comando con la gramática; aplicar a `shell`, `seed`, `loaddata`, `testserver`, `findstatic` |
| NU-19 | P2 | `internal/cli/plugincommands_test.go:76` ; `pkg/plugins/plugins.go:19` | `TestRunPluginTestDiscovery` falló en la primera pasada de `go test ./... -short` (4,01 s, "plugin test failed (stderr=)") y pasa aislado (0,31 s) y en la segunda pasada: flaky por el probe de 2 s bajo carga | `--timeout` mayor en el test o `t.Setenv` de un probe timeout de test; reintento explícito |
| NU-20 | P2 | `pkg/model/registry.go:63-85` | Registrar dos modelos con el mismo nombre sobreescribe en silencio (dos módulos con `User`) | Error en duplicado (o namespace por módulo) |
| NU-21 | P2 | `CHANGELOG.md:10-17` ; `docs/governance/COMPATIBILITY_SLO.md` | 1.23.0 (minor) publica "⚠ BREAKING CHANGES: los backends de nube salen a módulos propios": una app con S3 deja de compilar/arrancar sin añadir un import, bajo un SLO que promete "no rewrites within v1.x" | ADR/deprecation record que lo justifique y lo documente en el CHANGELOG, o `Release-As` mayor la próxima vez; cambiar el guard de commits `!` |
| NU-22 | P2 | `contracts/baseline/cli_primary_commands.txt` (39 líneas) ; `website/docs/cli/overview.md` | Falta `add` en el baseline (el freeze sólo bloquea borrados, no lo detecta) y `add`/`wizard` no aparecen en el overview; `contracts/cli_doc_parity_test.go` sólo valida doc→código | `make regen-baselines`; filas `add`/`wizard`; test de paridad inverso |
| NU-23 | P2 | `internal/cli/add_test.go` | Ningún test ejecuta `runAdd` (sólo helpers); el comando toca `go.mod` y ficheros fuente | Test con `--dry-run` sobre scaffold temporal y con `--into` inexistente |
| NU-24 | P2 | `README.md:67-68,297` ; `website/docs/getting-started/installation.md:12,63-68` ; `SPEC.md:328` | "MSSQL and Oracle … behind build tags (`-tags mssql`, `-tags oracle`)" / `go install -tags mssql …`: los build tags desaparecieron en ADR-031; hoy son `drivers/mssql` y `drivers/oracle` (`nucleus add sqlserver\|oracle`) | Reescribir las tres fuentes con `nucleus add`; test de deriva que grepee `-tags mssql` en docs |
| NU-25 | P2 | `README.md:24` | "ships as a single Go module" — hay 14 `go.mod` (12 módulos hermanos + showcase) | "un core más doce módulos opcionales" |
| NU-26 | P2 | `README.md:37` ; `internal/cli/root.go:44-84` | "38 lifecycle commands" — son 40 (+7 alias) | Actualizar y generar la cifra desde `commandSpecs` |
| NU-27 | P2 | `website/docs/getting-started/installation.md:22` ; `docs/adrs/ADR-031-drivers-and-exporters-as-modules.md:121` | "~350 modules, 3 GB" (pre-D3) vs ADR-031 "19 MB / 349 paquetes / 87 módulos": medido hoy en el scaffold real: 60,2 MB (45,5 strip), 516 paquetes, 138 módulos; 19-21 MB sólo sin driver | Publicar las cifras medidas del scaffold con sqlite y explicar la diferencia |
| NU-28 | P2 | `README.md:75-78` | "per-tenant rate limiting" — inerte por NU-4 | Corregir tras arreglar NU-4 |
| NU-29 | P3 | `pkg/auth/jwt.go:354` | `ParseWithClaims` sin `WithIssuer`/`WithAudience`/`WithLeeway`; el `iss` se emite pero no se comprueba | Añadir las opciones y test negativo |
| NU-30 | P3 | `pkg/router/otel.go:31,38` | Span y `http.route` usan `r.URL.Path` crudo (cardinalidad ilimitada en métricas) | `r.Pattern` (Go ≥1.23) |
| NU-31 | P3 | `pkg/router/mux.go:308-316` ; `resource.go:26` | `Mount("/users")` registra `/users` como 307 a `/users/`; `Resource` hereda que la colección viva con barra | Registrar el patrón exacto contra el mismo handler |
| NU-32 | P3 | `pkg/router/mux.go:174,360-375` | `Handle` hace panic en patrones duplicados (`mountModule` no puede devolver error); `Walk` pasa `handler=nil` y cuenta middlewares capturados en registro | `recover` → `error`; guardar handler real |
| NU-33 | P3 | `pkg/router/csrf.go:432` ; `mux.go:141` | `UseSessionToken` sólo funciona desde `Group` (la sesión se inyecta por ruta); en `Use` top-level cae a cookie sin aviso | Inyectar en `ServeHTTP` o loguear la degradación |
| NU-34 | P3 | `pkg/validate/validate.go:61,68` | `customMessages` sin mutex en `RegisterRule` | `sync.RWMutex` |
| NU-35 | P3 | `pkg/signals/signals.go:81-96` | `EmitAsync` lanza una goroutine por handler sin `recover` ni límite | `recover` + pool opcional |
| NU-36 | P3 | `pkg/router/httputil.go:180,281-286` | `Recoverer` usa `slog.Error` global (salta redacción); `Compress` fija `Content-Encoding: gzip` antes de conocer status/tipo (comprime imágenes, 204/304) | `RecovererWithLogger` en `DefaultStack`; decidir en el primer `Write` |
| NU-37 | P3 | `pkg/authz/policies.go:70` ; `pkg/auth/session_store_memcached.go:20` ; `pkg/app/config.go:337-338` | `SetupAdminPolicies` codifica `/api/models/` del admin extraído (ADR-019); store memcached no registrado y rechazado por `validateSessionStoreName` pero `gomemcache` sigue en go.mod; `static_prefix/static_root` no montan nada (`Mux.Static` nunca se llama) | Deprecar/eliminar; registrar `memcached` o borrar; montar `Static` o retirar las claves del registro |
| NU-38 | P3 | `pkg/router/middleware.go:17-21` ; `corsmw.go:50` | CORS va tras rate limit y timeout: los 429/timeout salen sin cabeceras CORS; sólo orígenes exactos | CORS justo tras `RequestID`; comodín de subdominio |
| NU-39 | P3 | `pkg/model/meta.go:278-292` | Único TODO del árbol (ADR-011): palabras reservadas Oracle y `.` en nombres pasan el allowlist | Cerrar el follow-up |
| NU-40 | P3 | `contracts/security_posture_test.go:207` ; `internal/cli/common.go:42,82` ; `pkg/app/config.go:594` | Tests que arrancan con `DefaultConfig()` (`sqlite://nucleus.db` relativo al cwd) crean `contracts/nucleus.db` (reproducido, 0 B) e `internal/cli/nucleus.db`; `nucleus.db` raíz (17-jun) es un resto. Ignorados por `*.db`, no trackeados | `TempSQLite(t)` / `NUCLEUS_DATABASES__DEFAULT__URL` en esos tests; `make clean` |
| NU-41 | P3 | `pkg/nucleus/context.go:76` vs `pkg/router/context.go:398` ; `pkg/authz/enforcer.go`, `pkg/router/router.go`, `pkg/db/db.go` | `nucleus.Context.HTML(code, html)` escribe HTML crudo; `router.Context.HTML(status, tpl, data)` renderiza plantilla — mismo nombre, semántica distinta. Constructores con el logger en posiciones distintas; `NewJWTManager` panic vs `NewJWTManagerFromKeys` error; `NewWrapResponseWriter(w, _ int)` parámetro muerto | Guía de estilo (cfg-struct + logger último, nunca panic) y renombrar a `RawHTML` |
| NU-42 | P3 | `pkg/auth/session_cache.go:30-37` | `Get` confunde `""` con miss (`value != ""`) | Usar `Exists` como `GetInt` |
| NU-43 | P3 | `pkg/app/app.go:1708-1740` ; `providers/` | Seam federado ADR-028 cableado pero sin ningún proveedor OIDC/SAML ni rutas start/callback; `auth_federated` aparece en el registro de claves como si funcionara | Marcar "experimental, sin proveedor" en el registro o entregar `providers/oidc` |
| NU-44 | P3 | `pkg/nucleus/nucleus.go:826-836` ; `pkg/db/migrate.go:687-692` | Si `OnStart` del módulo N falla, no se ejecutan los `OnShutdown` de 1..N-1 (documentado); Oracle DDL autocommit rompe la atomicidad (documentado como follow-up) | Ejecutar hooks ya registrados antes de retornar; documentar la no-atomicidad por dialecto en `migrate --help` |
| NU-45 | P3 | `internal/cli/generatemodule.go:368-371` | `bindPayload` colapsa todo error de `BindJSON` (incluido el 413 `PAYLOAD_TOO_LARGE` que sí emite `render.go:88`) en "request body must be valid JSON" 400: body de 3 MB → 400 (reproducido) | Propagar el `DomainError` (`return c.Error(err)`) |
| NU-46 | P3 | `internal/cli/add.go:43-54` ; `root.go:141-152,47,200` | `add --help` imprime el usage dos veces; `version` ignora `--json`; resumen de `generate` omite service/repository/resource/module; `%-10s` desalinea la tabla | `fs.SetOutput(io.Discard)`; JSON en `version`; texto y `%-26s` |
| NU-47 | P3 | `internal/cli/startapp.go` (`startAppHTMLTemplate`) | Única salida generada en español ("app scaffold listo", "Punto de entrada sugerido") en una CLI en inglés; `startapp` no tiene `--with-policy` (sus rutas nacen 403) | Traducir; reutilizar `seedResourcePolicy` |
| NU-48 | P3 | `internal/cli/generate.go:80` ; `contracts_scaffold.go` ; `generatemodule.go` | Todo `generate <kind>` crea `internal/contracts/contracts.go` aunque no lo necesite; `generate module` no emite test (resource sí) y no monta en `main.go` | `ensureContractsAggregator` sólo en `resource`; test `nucleustest` por módulo; `--mount` que edite `main.go` como hace `add` |
| NU-49 | P3 | `internal/cli/scaffold/templates/mvc/rbac_policy.csv:13-19` ; `nucleus.yml.tmpl:26-28` | El esqueleto "vacío" lleva filas `/notes` y exención CSRF `/notes` para un módulo que no genera (acoplado al quickstart) | Mover al quickstart o a `generate module notes --with-policy` |
| NU-50 | P3 | `internal/cli/configcommands.go:82,95` | `--effective` bool aceptado e ignorado (la doc lo muestra obligatorio); `config print` exige `--config` aunque `nucleus.yml` esté en cwd, mientras `doctor`/`health` lo descubren | Descubrimiento uniforme de `nucleus.yml`; documentar `--effective` como opcional o quitarlo |
| NU-51 | P3 | `Dockerfile:8-15` ; `docker-compose.yml`, `docker-compose.test.yml` ; `CONTRIBUTING.md:53` | Comentario fósil "v0.9.X", `CGO_ENABLED=1`+`apk add gcc` innecesarios (todo Go puro), `alpine:latest`, sin `.dockerignore` (copia `website/node_modules`, `.git`); compose heredado de Quark (`quark_user`, `version: '3.8'`) con credenciales distintas de CI (`ci.yml:139-160`) | `CGO_ENABLED=0`, pin de alpine, `.dockerignore`; alinear compose con CI |
| NU-52 | P3 | `nucleus-test.yml` ; `scripts/dev/stop_admin_cluster_lab.sh`, `scripts/dev/local_lb.go` ; `Makefile:64` | Residuos del lab de admin extraído (ADR-019) y un YAML en español sin referencias; `make check` requiere red (`check_example_pins.sh` hace `git ls-remote`) | Eliminar; `SKIP_PINS=1` o target `guards-net` |
| NU-53 | P3 | `go.mod:47` (`golang.org/x/crypto v0.55.0`) | govulncheck: GO-2026-6355 y GO-2026-6354 (x/crypto/ssh, corregidas en 0.56.0) y GO-2026-5932 (openpgp) en módulos requeridos, no alcanzables | `go get golang.org/x/crypto@v0.56.0` en el próximo tren |
| NU-54 | P3 | `website/docs/getting-started/minimal-api.md:3` | "freezes over 1 600 symbols" — el baseline tiene 1 923 líneas | Generar la cifra desde el baseline |

### Deriva documental (afirmaciones que el código ya no cumple)

| Id | Sev | Fichero:línea | Evidencia | Corrección propuesta |
|---|---|---|---|---|
| NU-55 | **P0** | `examples/mvc_api/main.go:22-26` ; `README.md:107-109` ; `website/docs/getting-started/quickstart.md:80-83,114` | La "canonical starting point" no importa `drivers/sqlite`: `go run ./examples/mvc_api` desde la raíz → `db: the sqlite driver ships as its own module and is not imported yet … (linked right now: none)`, **exit 1** (reproducido). El quickstart del sitio incrusta ese `main.go` literalmente y afirma "Those five files are the complete slice": quien lo copie sobre el scaffold pierde el import | Añadir `_ "github.com/jcsvwinston/nucleus/drivers/sqlite"` (y decidir `exporters/prometheus`) al ejemplo y una frase en quickstart §3 y en `examples/mvc_api/README.md`; smoke test en CI que arranque el ejemplo |
| NU-56 | **P0** | `docs/QUICKSTART.md:95-102` ; `website/docs/getting-started/installation.md:11-12,60-73` | "SQLite, PostgreSQL, and MySQL are included by default … MSSQL and Oracle opt-in via build tags", `go install -tags mssql …`: ningún driver viene de serie en una app (el scaffold escribe el import), los tags no existen (ADR-031) y el CLI ya enlaza los cinco motores | Reescribir ambas secciones como "drivers as modules" con `nucleus add <motor>`; L73 → `drivers/` o `nucleus add --help` |
| NU-57 | P1 | `website/docs/concepts/routing.md:379-381` ; `docs/reference/DEVELOPER_MANUAL.md:241,252,272` ; `docs/reference/PROJECT_LAYOUT.md:120` ; `docs/reference/CLI_CONTRACT_MATRIX.md:31` ; `SPEC.md:104,318,415` | Snippets con `a.MountOpenAPI(...)`, eliminado en v0.12.0 (DEP-2026-008); sólo existe `App.MountOpenAPIHandler(pattern, http.Handler)` (`pkg/app/app.go:1025`) + `openapi.Handler` (`pkg/openapi/http.go:11`) | `a.MountOpenAPIHandler("/api/openapi.json", openapi.Handler(func() *openapi.Document { return doc }))` |
| NU-58 | P1 | `docs/reference/CONFIG_KEY_REGISTRY.md:264` ; `website/docs/reference/configuration.md:212` ; `website/docs/operations/deployment.md:213-217,266` ; `docs/guides/DEPLOYMENT_GUIDE.md:765` | "When non-empty, App.New attaches a Prometheus reader and serves it": sin `exporters/prometheus` sólo hay WARN y `/metrics` responde 404 (comprobado) | Añadir "requires `exporters/prometheus`; the default path only warns" |
| NU-59 | P1 | `SPEC.md:138-142,297-305,327-328,331` | §3.3 no menciona el registro de drivers (`pkg/db/driver`, `requireDriver`, `nucleus add`) ni el clasificador de errores; §3.10 no dice que los exportadores son módulos; §4 sigue con "behind build tags" y "OpenTelemetry SDK/exporters". "Reference date 2026-08-31" con contrato de revisión (L9-13) que ADR-030/031, del mismo día, contradicen | Reescribir §3.3/§3.10/§4 y listar los 12 módulos; explicar por qué el raíz conserva `internal/dbclassify` |
| NU-60 | P1 | `README.md:148,151` ; `website/docs/intro.md:75-77` ; `SPEC.md:194,219-223,364` ; `docs/reference/CONFIG_KEY_REGISTRY.md:308` | Mail "noop/smtp/sendgrid" (sendgrid eliminado, DEP-2026-002; `pkg/mail` sólo `noop.go`, `smtp.go`, `external.go`) y storage "S3/GCS/Azure built in" (`pkg/storage/builtins.go` sólo registra `local`; ADR-030); claves `sendgrid_*` sin fila en el registro | "noop, smtp + plugins externos"; "local built in; cloud via `nucleus add s3\|gcs\|azure`" |
| NU-61 | P1 | `website/versioned_docs/version-1.23.0/**` | Copia byte a byte de `website/docs` (`diff -rq` vacío): hereda NU-24, NU-56, NU-57, NU-58 en el snapshot inmutable de 1.23.0 | Corregir en `website/docs` y que el snapshot 1.24.0 lo recoja; nota de errata en 1.23.0 |
| NU-62 | P2 | `website/docs/concepts/models-and-database.md:40-44,264-265` ; `website/docs/operations/deployment.md:41-42` ; `website/docs/architecture/principles.md:117-119` ; `architecture/compatibility.md:144-145` ; `docs/governance/CI_MATRIX.md:105-106,118-127,151-153` ; `docs/reference/DEPENDENCY_IMPACT_REPORT.md:4,17,39-40` ; `docs/reference/api/pkg_db.md:15` ; `docs/MODULARIZATION.md:5-6` | Ocho fuentes más con "build tags mssql/oracle"; `MODULARIZATION.md` se contradice a sí mismo (banner "Completed" vs Fase 2 "Superseded by ADR-031") y su tracker L207-214 declara "actualizados" documentos hoy erróneos; `DEPENDENCY_IMPACT_REPORT` con versiones de abril (pgx 5.5.5 vs 5.9.2) | Barrido con un guard `grep -rn -- '-tags mssql' docs website/docs` en CI; `MODULARIZATION.md` y `V1_GATE.md` ("Current version v0.12.0") a `docs/audits/` con banner |
| NU-63 | P2 | `docs/reference/API_CONTRACT_INVENTORY.md` ; `README.md:140-163` ; `scripts/ci/check_version_claims.sh` | Faltan 12 paquetes que `contracts/packages_test.go` congela (`pkg/auth/{backend,backend/backendtest,federated,secrets,sessionstore}`, `pkg/db/driver{,/drivertest}`, `pkg/observe/exporter`, `pkg/router/interceptor`, `pkg/storage/provider`, `pkg/tasks/providers/{asynq,memory}`); el guard sólo comprueba README ⊆ inventario | Filas nuevas; guard en ambos sentidos |
| NU-64 | P2 | `CLAUDE.md:51` ; `SPEC.md:130,181-183,311,387-397,417-430` ; `README.md:171-185,256,299` | CLAUDE.md lista sólo `providers/ldap` como módulo (son 12); SPEC cita el paquete hoja `pkg/plugins/schema` (no existe), pone OTel en signals, omite `add/outbox/doctor/config` en §7 y no nombra los seis baselines; README omite `add`/`outbox` en los grupos, dice "3 ADRs" (hay 31) y que compose levanta "Postgres, MySQL, MariaDB, Redis" (también mssql, oracle, jaeger) | Corregir texto; generar la lista de módulos y comandos desde el árbol |
| NU-65 | P2 | `docs/guides/STORAGE_GUIDE.md:79-165` ; `docs/guides/OBSERVABILITY_BASELINE.md` ; `docs/reports/*` ; `docs/governance/RELEASE_CHECKLIST.md:162` | Guías con `provider: s3\|gcs\|azure` y dashboards de `/metrics` sin mencionar el módulo necesario (0 coincidencias de `providers/`, `exporters/`, `nucleus add`); `RELEASE_CHECKLIST` manda regenerar `docs/reports/compatibility_harness_latest.md`, no regenerado en 4 releases; `mssql_oracle_stability_report.md` (build tags) citado como evidencia viva | Cuadro "necesitas el módulo" al inicio; archivar `docs/reports/` con banner o regenerarlo |
| NU-66 | P3 | `docs/adrs/ADR-021…:8`, `ADR-022:5,8`, `ADR-023:6,8`, `ADR-024:7`, `ADR-025:7`, `ADR-026:7`, `ADR-020:10,12` | Enlaces rotos a `ADR-007-log-redaction.md`, `ADR-010-module-contract.md`, `ADR-015-authz-hardening.md` (nombres reales distintos) y a `../../../docs/adr/QADR-000{5,6}` (sólo resuelve dentro de `quantum/`); `check_internal_docs_drift.sh` no escanea `docs/adrs/` | Corregir nombres; URL absoluta al repo quantum; incluir `docs/adrs/` en el guard |
| NU-67 | P3 | `SPEC.md:234` ; `pkg/app/jwt_setup.go:46-105` ; `pkg/storage` | `secret_manager` "(planned)": ya funciona para `jwt_keys` vía `aws-sm:` (`providers/secrets-aws`) pero sigue sin implementarse para credenciales de storage | Precisar el alcance por subsistema |

Estado de D4 (API keys): no existe en nucleus (ni `pkg/auth/apikeys`, ni comando `apikey`, ni backend) y la doc del repo no lo promete; sólo aparece en `quantum/docs/RUMBO.md:71-75`. Lo único relacionado es el modelo de documento `APIKeyScheme` (`pkg/openapi/openapi.go:170-173`) y `x-api-key` en la lista de redacción (`pkg/observe/redact.go:31`).

## 6. Resultados de ejecución

### Build / vet / test / tidy / vuln (raíz)
- `go build ./...`: OK. `go vet ./...`: OK, sin avisos.
- `go test ./... -count=1 -short` (SQLite; ningún paquete exigió motor externo en `-short`): pasada 1 → **FAIL** `internal/cli` `TestRunPluginTestDiscovery` (4,01 s), 34 paquetes ok, 15 sin tests, 23,7 s. Pasada 2 → todo ok (7,7 s en `internal/cli`). Aislado → PASS 0,31 s. Diagnóstico: flaky por probe de plugin de 2 s bajo carga (NU-19).
- `go test -race -short -count=1 ./...`: **sin carreras ni fallos**.
- `go mod tidy` en raíz: **sin cambios** en `go.mod`/`go.sum` (verificado con `git diff` y restaurado).
- `govulncheck ./...` (v1.3.0 instalado): 0 vulnerabilidades alcanzables desde el código; 3 en módulos requeridos no llamadas (x/crypto 0.55.0, NU-53).
- `git status`: limpio antes y después (los `.db` están ignorados).

### Módulos hermanos (`cd <mod> && go build ./... && go vet ./...`, sin go.work)
| Módulo | Resultado |
|---|---|
| drivers/mssql, mysql, oracle, sqlite; exporters/otlp, prometheus; providers/secrets-aws, storage-azure, storage-gcs, storage-s3 | **FALLA**: "missing go.sum entry … github.com/jcsvwinston/nucleus" (pin v1.22.0 sin `pkg/db/driver`) — NU-1 |
| drivers/postgres | **FALLA vet**: `postgres_test.go:11: no required module provides package …/pkg/db` — NU-1 |
| providers/ldap | OK |
| examples/showcase_demo | OK (descarga `orbit/quarkbridge v0.4.9`, `orbit/quarkdatasource v0.2.18`); sin tests propios (validación vía `scripts/ci/run_showcase_smoke.sh`, no ejecutada) |
| examples/mvc_api (módulo raíz) | build y vet OK; **`go run ./examples/mvc_api` desde la raíz aborta con exit 1**: "the sqlite driver ships as its own module and is not imported yet … (linked right now: none)" (NU-55) |

Con `go work init` (lo que hace CI) todos compilan.

### DX quickstart (`scratchpad/auditoria/nucleus-dx/`, `replace` al checkout, sin docker)
| Paso | Medida |
|---|---|
| `nucleus new myapp --module github.com/acme/myapp` | 0,2 s; 7 ficheros; `go.mod` requiere `nucleus v1.23.0` pero no `drivers/sqlite` aunque `main.go` lo importa (lo resuelve `go mod tidy` → `drivers/sqlite v0.1.0`, que pina `nucleus v1.22.0`; MVS lo salva) |
| `go mod tidy` + `go build` | 0,1 s + 0,9 s (caché caliente); `go list -m all` = **138 módulos**; `go list -deps` = **516 paquetes** |
| Tamaño del binario hello-world | **60.225.618 B** (45.501.666 B con `-s -w`); plantilla `api` idéntica; sin driver sqlite: 31,0 / 21,3 MB (407 paquetes); modernc sqlite solo: 8,4 MB; CLI `nucleus`: 60,8 MB |
| `go run .` | Arranca en <1 s; `/healthz` 200 `{"status":"ok"}` con CSP, HSTS, COOP/CORP, `X-Request-Id`, cookie `_csrf`; `/` y rutas desconocidas → **403** (default-deny, no 404); `/metrics` 404 + WARN "Prometheus exporter is not linked" + WARN "jwt: no signing material" en cada arranque |
| `nucleus generate module notes` | 0,02 s; 7 ficheros + `internal/contracts/contracts.go`; no monta en `main.go` (edición manual); política anonymous `*` (NU-14) |
| Endpoints del módulo | GET /notes 200 · POST 201 · POST `name` vacío 400 "name is required" · JSON roto 400 · GET /notes/999 404 · /notes/abc 400 · PATCH 405 · DELETE 204 · /notes/page 200 HTML · body 3 MB → **400** (debería ser 413, NU-45) · OPTIONS preflight 405 (CORS deny por defecto) |
| `nucleus add postgres` | 2,5 s: `go get` + blank import en `main.go`; compila. `nucleus add prometheus` → `unknown module` (NU-3) |
| `nucleus doctor` | HEALTHY 4/8 (4 "not configured"), exit 0; `--json` válido |
| `nucleus health --deploy` | `degraded` (jwt_secret error + 4 warnings), **exit 1** correcto; `--json` correcto |
| `nucleus routes` / `serve` / `migrate status` / `config print` | Sólo `/healthz` (ciego a módulos) / arranca sin módulos (aviso) / "No migration files found" pese a la migración embebida aplicada / exige `--config` aunque `nucleus.yml` esté en cwd (NU-16, NU-50) |
| Plantilla `api` + `migrate create` + `generate model/handler` + `startapp billing` | 20 ficheros en layout por capas; `go build`/`go vet` limpios; timestamps mezclan local/UTC (NU-15); `startapp` en español y sin `--with-policy` (NU-47) |
| Conceptos hasta el primer endpoint propio | ≈10: builder fluente, `Module[C]`/`ModuleSpec`, `Runtime`, `Router.Resource` + interfaces `Indexer/...`, `Context`, `PolicyRule` (verbos CRUD, no HTTP), `CSRFExempt`, migraciones `fs.FS`, templates `fs.FS`, `rbac_policy.csv` del host. Gin: 3; Buffalo: ~6; Django: ~6 (urls, views, models, migrations, settings, admin) |
| Mensajes confusos | WARN de exporter no enlazado con receta inexistente; 403 (no 404) en rutas inexistentes; `routes` que arranca la app y abre la BD para listar una ruta; `openapi` con stderr crudo de `go run` |
| Pasos que sobran | Editar `main.go` a mano tras `generate module`; `go mod tidy` obligatorio porque el scaffold no requiere `drivers/sqlite`; borrar las filas `/notes` del scaffold si no se sigue el quickstart |
