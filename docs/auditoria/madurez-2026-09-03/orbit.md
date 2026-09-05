# Orbit — madurez

Auditoría sobre `github.com/jcsvwinston/orbit` @ `ba23abd` (set certificado v1.8.17 = `a192117c` + 1 commit de docs), 2026-09-03. Código leído, no descrito; nada editado en el repo. Fuentes: auditoría propia del panel in-process, del montaje DX y de la ejecución; sub-auditorías de la SPA in-process (`D1–D22`), del plano fleet (`F1–F18`) y de la deriva documental, verificadas en sus hallazgos graves. No se repite la deuda ya anotada en `quantum/docs/RUMBO.md` (PR-ORB-02 audit ring, AO-4 postura sin-auth, D2 fleet→datasource) salvo para situarla.

## 1. Veredicto

Orbit es un **panel de observabilidad in-process sólido con un CRUD genérico encima**, no todavía un admin framework: el núcleo Go (auth, hardening, contrato `datasource`, tests con `-race` limpios, guards de release) está por encima de la media, pero la capa de producto que un operador toca (formularios, relaciones, validación, permisos por operador, audit persistente, personalización) está uno o dos escalones por debajo de Django Admin/Filament, y el plano fleet promete TLS/mTLS que hoy **no existe** (P0). La deuda más cara no es de código sino de alcance: dos SPAs con stacks distintos, dos Data Studios que no comparten contrato (D2), y una doc que describe el producto que se quiere ser.

| Dimensión | Nota (1-5) | Por qué |
|---|---|---|
| Data Studio | 2,5 | CRUD/export/import/fixtures reales en API; sin validación de modelo, sin FK lookup/M2M/inlines, filtros solo igualdad, IDs uint, la SPA rompe import/paginación |
| RBAC/permisos | 2 | Casbin por modelo+acción y superusuario funcionan; sin gestión de usuarios admin, sin permisos por campo/fila, `deny` invisible en UI, políticas no auditadas |
| Telemetría/live feed | 3,5 | Feed HTTP/SQL por bus + WS + relay Redis + fleet con sampling/backpressure; se autocontamina con el tráfico del panel; sin retención |
| Audit | 1,5 | Ring en memoria (conocido) que además solo cubre `/api/models/*`: RBAC, flags, migraciones, imports, cache y `clear` no dejan rastro; `new_value` siempre null |
| Fleet | 2,5 | Plano real (registro, stream bidi, Data Studio remoto, RBAC viewer/rw, allowlist), pero TLS no se aplica al listener, sin mTLS, sin persistencia ni alertas |
| Personalización/extensibilidad | 1,5 | Título y `DataSource` custom; sin logo/tema/colores, sin dashboards/widgets, sin acciones custom, sin hooks, sin i18n |
| UI/UX/a11y | 2 | Grid AG Grid competente; 0 `aria-*`, contrastes 1,9–2,3:1, toasts que no se cierran, 3 flujos que dicen «éxito» sin hacerlo |
| Seguridad | 3 | Panel: bcrypt+timing, lockout, CSRF, CSP estricta, redacción de audit; pero fuga de DSN por System Pulse (P1) y fleet P0 |
| Testing | 3,5 | 18 paquetes Go verdes, `-race` limpio en panel y fleet, gate por motor en CI; 0 tests en ambas SPAs, 0 lint en la SPA in-process |
| Docs/DX | 2,5 | README/config honestos y guards de versión; pero el ejemplo mínimo no arranca, tags anunciados que no existen, mTLS/https documentados y falsos, `/api/models` marcado DEPRECATED |

## 2. Tabla comparativa

Leyenda: ✅ comparable · ◐ parcial · ❌ ausente. La columna Orbit lleva fichero de evidencia.

| Capacidad | Orbit | Django Admin | Filament/Nova | Directus/Payload | React-Admin/Refine |
|---|---|---|---|---|---|
| CRUD auto-generado por modelo | ✅ `internal/admin/handlers.go:450-457`, adapter `internal/datasource/nucleus/` | ✅ | ✅ | ✅ | ✅ (con provider) |
| Validación de modelo en formularios | ❌ `validate:"required"` ignorado: POST sin `title` → 201 (`store.go:91`, probado) | ✅ | ✅ | ✅ | ◐ (cliente) |
| Filtros con operadores (rango, contains, in, null) | ◐ solo igualdad exacta y solo campos `admin:"filter"` (`datastudio.go:49-98`) | ✅ | ✅ | ✅ | ✅ |
| Búsqueda | ◐ `search` sobre campos `admin:"search"`; sin campos se ignora en silencio; `%`/`_` sin escapar en quark (`quarkdatasource/store.go:90`) | ✅ | ✅ | ✅ | ✅ |
| Ordenación servidor | ◐ API allow-list multi-col (`datastudio.go:107+`); la SPA ordena solo cliente (`AGGridTable.tsx:74`) | ✅ | ✅ | ✅ | ✅ |
| Paginación con total | ◐ `total:-1/is_estimated` en SQLite con 2 filas (probado); «Load More» reemplaza filas (`AGGridTable.tsx:154-158`) | ✅ | ✅ | ✅ | ✅ |
| Relaciones FK (select/lookup) | ◐ metadatos `is_fk`/`fk_model` (`handlers.go:392`) sin endpoint lookup ni widget | ✅ | ✅ | ✅ | ✅ |
| M2M / inlines / anidados | ❌ | ✅ | ✅ | ✅ | ◐ |
| Tipos de campo ricos (JSON, fichero, imagen, rich text, enum) | ◐ `html_type` text/number/bool/datetime/textarea/choices; JSON → `[object Object]` y se guarda corrupto (`RecordForm.tsx:55,163`) | ✅ | ✅ | ✅ | ✅ |
| Bulk actions | ◐ delete/export, IDs `[]uint` (`handlers.go:475`) | ✅ | ✅ | ✅ | ✅ |
| Acciones custom por modelo | ❌ | ✅ | ✅ | ◐ hooks | ✅ |
| Import/Export | ◐ API CSV/JSON/SQL + fixtures (`exporters.go`, `importers.go`, `fixtures.go`); la SPA de import es no-op (`AGGridTable.tsx:314-327`); export trunca a 10 000 (`actions.go:40`) | ◐ (3rd party) | ✅ | ✅ | ◐ |
| Permisos por modelo/acción | ✅ Casbin `admin:<Model>` + superuser (`panel.go:874-909`) | ✅ | ✅ | ✅ | ◐ |
| Permisos por campo / por fila | ❌ | ✅ / ◐ | ✅ | ✅ | ◐ |
| Gestión de usuarios/roles desde el panel | ◐ políticas y roles sí (`rbac.go`); usuarios admin **no** (solo `nucleus createuser`) | ✅ | ✅ | ✅ | ◐ |
| Multi-tenant | ◐ filtro de vista por `?tenant=`, desactivable con `all`; Get/Update/Delete/export por id sin comprobar tenant (`panel.go:672-686`, `handlers.go:515-680`) | ❌ | ◐ | ◐ | ◐ |
| Audit log | ◐ ring en memoria solo para `/api/models/*` (`audit.go:170-191`) | ✅ (LogEntry) | ◐ plugin | ✅ | ❌ |
| Historial/versionado de registros | ❌ | ◐ (history) | ◐ | ✅ | ❌ |
| Live feed HTTP/SQL | ✅ único en la categoría (`live.go`, WS, relay Redis) | ❌ | ❌ | ❌ | ❌ |
| Métricas de runtime / health | ✅ `system.go`, `management.go:35` | ❌ | ❌ | ◐ | ❌ |
| Sesiones activas (ver/revocar) | ✅ `sessions.go` (store iterable) | ◐ | ◐ | ✅ | ❌ |
| Plano fleet multi-nodo | ◐ `server/`, `agent/`, `proto/`; sin TLS efectivo (F1) ni persistencia | ❌ | ❌ | ❌ | ❌ |
| Branding (logo, colores, tema) | ◐ solo título (`ui_fallback.go` meta); tema claro/oscuro sin AG Grid dark | ◐ | ✅ | ✅ | ✅ |
| Dashboards/widgets custom | ❌ | ◐ | ✅ | ✅ | ✅ |
| Hooks/plugins/extensión UI | ❌ (solo `Config.DataSource` en Go) | ✅ | ✅ | ✅ | ✅ |
| i18n | ❌ in-process; ◐ catálogo inglés en fleet (`ui/src/lib/i18n.ts`) | ✅ | ✅ | ✅ | ✅ |
| Accesibilidad | ❌ 0 `aria-*`, contraste bajo, fuentes 9-10 px (SPA in-process) | ◐ | ✅ | ◐ | ✅ |
| Seguridad login (lockout, timing, CSRF, CSP) | ✅ `default_auth.go`, `hardening.go` | ✅ | ✅ | ✅ | n/a |
| Tests de UI | ❌ 0 en ambas SPAs; lint solo en `ui/` | ✅ | ✅ | ✅ | ✅ |
| API pública estable | ✅ `datasource` + `orbit.Config` congelados (`contracts/freeze_test.go`) | ✅ | ✅ | ✅ | ✅ |

## 3. Lo que falta para competir

**Bloqueante** (sin esto no se puede recomendar frente a un Django Admin):
1. **Validación de modelo en Data Studio.** Hoy el panel escribe lo que le mandan (`store.go:91`, `reflect.go:92` convierte 123 → `"123.0"`). Un admin que corrompe datos no es un admin.
2. **Gestión de usuarios admin y roles desde el panel.** `nucleus_admin_users` solo vive en `createuser`; RBAC por operador es inoperable sin CLI.
3. **Formularios de relaciones**: FK con lookup/autocomplete, M2M, inlines; tipos JSON/fichero.
4. **Filtros con operadores y ordenación servidor en la SPA**; paginación con total real.
5. **Audit persistente y completo** (PR-ORB-02 + cubrir RBAC/flags/migraciones/imports/`clear`/login, con `new_value`).
6. **Fleet: TLS que realmente se aplique** (F1) o retirar los flags/documentación hasta que exista.
7. **Cerrar las tres mentiras de la SPA** (import no-op, Load More, batch 500) y el `[object Object]`.

**Diferenciador** (lo que ningún competidor de la lista tiene y Orbit ya casi tiene):
- Live feed HTTP/SQL correlado con sesiones y trazas (`trace_url_template`), in-process y sin sidecar.
- Fleet con Data Studio remoto y sampling/backpressure, si se une al contrato `datasource` (D2) y gana persistencia mínima.
- System Pulse (pool, outbox, goroutines) al lado del CRUD: un «admin + APM ligero» en un binario.
- Contrato `datasource` congelado: Orbit puede ser el admin de Quark y de terceros sin tocar el core.

**Nice-to-have**: branding (logo/paleta), dashboards y widgets declarativos, acciones custom por modelo (`orbit.Action`), vistas guardadas, historial de registro, i18n (es/en), exportación streaming, soft-delete visible, tema oscuro en AG Grid, atajos de teclado, notificaciones.

## 4. Mejoras propuestas

| Horizonte | Mejora | Esfuerzo | Valor | Dependencia |
|---|---|---|---|---|
| **Corto (≤1 mes)** | Aplicar `tls.NewListener` en `server.Run` + test de handshake; el guard deja de contar `AgentTLS` como auth (OR-1) | S | crítico | ninguna |
| | Validar en `store.Create/Update` con el validador de nucleus (`validate:` tags) y devolver 422 con errores por campo (OR-2) | M | alto | nucleus expone `validate.Struct` |
| | Enmascarar env por defecto (allow-list o patrón `URL|DSN|CONN|PASS|AUTH|CREDENTIAL|PRIVATE`) y sacar `environment` del snapshot salvo `?env=1` con `system_env` (OR-3) | S | alto | ninguna |
| | Arreglar `examples/minimal` (import `drivers/sqlite`) y que CI lo **ejecute** con `-run`+curl (OR-5) | S | alto | ninguna |
| | Reconciliar tags: cortar `quarkbridge/v0.4.11`, `quarkdatasource/v0.2.20` reales o borrar los `v1.8.17` y re-pinar paraguas (OR-8) | S | alto | quantum `versions.yaml` |
| | SPA: import cableado a validate/execute, Load More acumulativo, batch ≤200, JSON stringify/parse, `eft` deny, toasts con cierre, `npm audit fix` react-router (OR-9…13, OR-20, OR-31) | M | alto | ninguna |
| | IDs como string de punta a punta (bulk, export, fixtures, SPA) según ADR-001 D1 (OR-14) | S | medio | ninguna |
| | Live excludes comparando contra la ruta sin prefijo (OR-15); audit para RBAC/flags/migraciones/imports/`clear`/login (OR-16) | S | medio | ninguna |
| | `go mod tidy` guard en CI y refrescar `go.work.sum` (OR-36) | S | bajo | ninguna |
| **Medio (1-3 meses)** | Usuarios admin como modelo gestionable (`AdminUser` en Data Studio + endpoints crear/reset/superuser) | M | alto | ADR-004 (frontera authn/authz) |
| | Audit persistente en BD (tabla `orbit_audit`) con retención y export (PR-ORB-02) | M | alto | pkg/db migraciones |
| | Filtros con operadores en contrato (`Query.Filters` → `[]Filter{Col,Op,Val}`) sin romper freeze: campo nuevo `Where` | M | alto | ADR-001 (adición compatible) |
| | FK lookup endpoint + widget select/autocomplete; JSON editor; fecha con TZ | M | alto | ninguna |
| | Tests de SPA (vitest + testing-library) y ESLint en `internal/admin/ui`; a11y básica (aria, htmlFor, contraste) | M | medio | ninguna |
| | Fleet: `WithReadMaxBytes`, cancelación de stream viejo en reconexión, cap de suscripciones (F4-F6); agente https + `--agent-client-ca` (mTLS real) o retirar la palabra mTLS | M | alto | F1 |
| | Fleet consume `datasource.DataSource` (D2) → RBAC por modelo y tenant también en fleet; `quarkbridge.ModelName` relleno | L | alto | ADR-002 aceptado |
| **Largo (3-12 meses)** | Unificar las dos SPAs en una sola base (o compartir design system) — hoy stacks distintos: ag-grid/zustand/react-router vs connect-web/tanstack | L | alto | decisión de producto |
| | Acciones custom por modelo (`orbit.Action{Name, Handler}`) y hooks de UI (widgets de dashboard declarados en Go) | L | diferenciador | freeze v1 → adición |
| | Permisos por campo/fila (política Casbin `admin:<Model>.<field>` + `row_filter`) | L | alto | RBAC usuarios |
| | Fleet: retención (SQLite/Parquet), alertas simples, métricas propias en `/metrics`, multi-cluster | L | diferenciador | D2 |
| | i18n (es/en) y branding (logo, paleta, favicon) desde `orbit.Config` | M | medio | ninguna |

## 5. Defectos encontrados

Severidad: P0 seguridad/pérdida de datos en producción · P1 grave (seguridad, integridad, promesa rota) · P2 bug funcional o riesgo · P3 deuda/incoherencia. Origen entre paréntesis cuando viene de una sub-auditoría (verificado en los P0/P1).

| id | Sev | Fichero:línea | Evidencia | Corrección propuesta |
|---|---|---|---|---|
| OR-1 | **P0** | `server/server.go:256,263,490`; `:421` (F1) | `newH2CServer` asigna `srv.TLSConfig` pero `Run` llama `Serve(ln)` (no `ServeTLS`/`tls.NewListener`): `--agent-cert/--ui-cert` no cifran nada. `agentListenerGuard` acepta `AgentTLS != nil` como autenticación → `--agent-addr=:9090 --agent-cert…` arranca h2c **en claro, sin token, en todas las interfaces** y loguea `agent_tls=true`. Verificado en código. | `ln = tls.NewListener(ln, cfg)` (NextProtos h2/http1.1) + test de handshake; el guard no cuenta TLS como auth hasta que haya `ClientAuth`. |
| OR-2 | P1 | `internal/datasource/nucleus/store.go:91-102`, `reflect.go:38-140` | `POST /api/models/Note {"body":"b"}` con `Title validate:"required" db:"required"` → **201** con título vacío (probado). `PUT {"title":123}` → guarda `"123.0"`; campos desconocidos ignorados. Ningún validador en la ruta. | Validar entidad tras `payloadToEntity` (validator de nucleus) y devolver 422 por campo; rechazar tipos incompatibles y claves desconocidas. |
| OR-3 | P1 | `internal/admin/system.go:99-165,414-452` | `/api/system/snapshot` devuelve `os.Environ()` completo (53-58 filas); máscara solo `KEY|SECRET|PASSWORD|TOKEN`. Probado: `DATABASE_URL=postgres://app:S3cretPw@…`, `REDIS_URL`, `SENTRY_DSN` en claro. `NUCLEUS_DATABASES_DEFAULT_URL` (vía oficial, `nucleus/pkg/app/config.go:762`) tampoco se enmascara. Accesible a cualquier operador con `system_pulse`. | Allow-list o ampliar patrón (`URL`,`DSN`,`PASS`,`AUTH`,`CRED`,`PRIVATE`) y redactar `user:pass@` en URLs; env solo bajo permiso propio. |
| OR-4 | P1 | `internal/admin/panel.go:441-517` (rutas), `default_auth.go` | No existe endpoint ni UI para `nucleus_admin_users`: crear/desactivar/reset/superuser solo por `nucleus createuser`. `AdminUser` no aparece en Data Studio (probado: solo `Note`). RBAC por operador inoperable desde el panel. | Registrar `AdminUser` como modelo gestionable con hash en escritura, o endpoints `/api/users`. |
| OR-5 | P1 | `examples/minimal/main.go:19-27`, `README.md:96-104`, `.github/workflows/ci.yml` | El ejemplo «runnable, built by CI» **no arranca**: `db: the sqlite driver ships as its own module and is not imported yet` (probado). CI solo lo compila. | `import _ "github.com/jcsvwinston/nucleus/drivers/sqlite"`; CI arranca y hace curl a `/admin/login`. |
| OR-6 | P1 | `agent/agent.go:238-242`, `agent/connection/connection.go:289-306` (F2) | Dialer sin `TLSConfig`; `DialTLSContext` devuelve TCP plano para `https://` → el stream no funciona contra https aunque la doc lo ejemplifique (`cluster/agent.md:38`). | TLS por esquema; knobs `CAFile`/cert cliente en `ExtensionConfig`; test e2e https. |
| OR-7 | P1 | `server/cmd/admin-server/main.go:176-188`, `server/config.go:24`, `server/README.md:55`, `auth/auth.go:3` (F3) | «mTLS at the listener» en 8 sitios; `loadTLS` solo carga `Certificates` — sin `ClientCAs`/`ClientAuth`. | `--agent-client-ca` + `RequireAndVerifyClientCert`, o borrar «mTLS» de la doc. |
| OR-8 | P1 | `.release-please-manifest.json`, `website/docs/reference/module-matrix.md:20`, commit `3c4e78d` (`Release-As: 1.8.17`) | Manifest y matriz anuncian `quarkbridge v0.4.11` y `quarkdatasource v0.2.20`; en el remoto **no existen**: los tags reales son `quarkbridge/v1.8.17` y `quarkdatasource/v1.8.17` (`git ls-remote`), y el paraguas ya los pina. `go get …/quarkbridge@v0.4.11` falla; el próximo release (0.4.12) será menor que 1.8.17 → `@latest` apuntará al fantasma. | Decidir una serie: retag 0.4.11/0.2.20 y borrar los 1.8.17 (o al revés) y alinear manifest, matriz y `versions.yaml`. |
| OR-9 | P1 | `internal/admin/ui/src/features/data-studio/components/AGGridTable.tsx:314-327`, `services/api.ts:434-448` (D1) | Import en la SPA sube el fichero y muestra «éxito» sin llamar nunca a `/api/import/validate` ni `/execute`: no importa nada. | Cablear upload → validate → execute; quitar `.sql` del accept. |
| OR-10 | P1 | `AGGridTable.tsx:154-158` vs `:506` (D2) | «Load More» reemplaza las filas en vez de anexar: no se puede ver más allá de la primera página. | Acumular `rowData` en estado. |
| OR-11 | P1 | `AGGridTable.tsx:559` vs `handlers.go:478-480` (D3) | Selector de batch ofrece 500 → API responde 400 `page_size must be <= 200`. | Opciones ≤200 o subir el cap. |
| OR-12 | P1 | `RecordForm.tsx:55,163`, `AGGridTable.tsx:94-95` (D4) | Campos JSON/struct se muestran como `[object Object]` y al guardar se persiste esa cadena (corrupción). | `JSON.stringify` en display, `JSON.parse` al guardar o readonly para no primitivos. |
| OR-13 | P1 | `services/api.ts:251-262` vs `rbac.go:150-161` (D5) | La SPA descarta `eft`: una política `deny` se pinta igual que `allow`. | Propagar `eft` y badge. |
| OR-14 | P2 | `handlers.go:475`, `actions.go:94-140`, `fixtures.go:460-491`, `quarkdatasource/store.go:258-283`, `AGGridTable.tsx:46,263,291` | IDs `uint` en bulk/export/fixtures/SPA; contradice ADR-001 D1 (string). `{"ids":["abc"]}` → 400 «invalid JSON» (probado). quarkdatasource rechaza `uuid.UUID`. | `[]json.RawMessage`/string de punta a punta. |
| OR-15 | P2 | `live.go:500-524,751-776` | Excludes por defecto `["/admin"]` pero el middleware ve rutas ya sin prefijo (`Mount` lo quita): snapshot muestra `/api/audit`, `/api/live/snapshot`… — el feed se llena con el propio panel (probado: 53/53 requests). | Comparar contra ruta con prefijo o normalizar excludes sin prefijo. |
| OR-16 | P2 | `audit.go:170-191`, `rbac.go`, `management_migrations.go:37`, `p2_features.go:113`, `audit.go:388` | Solo se auditan escrituras con `{name}` en ruta: añadir política RBAC no deja entrada (probado); tampoco flags, migraciones, cache flush, imports/exports, `audit/clear`, login. `new_value` siempre `null`. `PUT schema/fields` se registra como «update» de `Note` con `record_id ""`. | `recordAuditEntry` explícito en cada handler mutador; capturar body de create/update; acción `schema.update`. |
| OR-17 | P2 | `actions.go:16-92` | Export CSV: `PageSize: 10000` fijo → trunca en silencio; ignora filtro tenant y `mi.DatabaseAlias` (List sí los aplica); errores de `writer.Write` ignorados. | Paginar hasta agotar; aplicar tenant/alias; comprobar errores. |
| OR-18 | P2 | `management.go:233-258` | `GET /api/exports/download?key=…` pasa la clave cruda a `store.Get`: cualquier objeto del store es descargable con `export_data` (ADR-005 confinó solo el browse). `../../etc/passwd` → **500** (rechazado por LocalStore, pero no 403). | Confinar a `_tmp/export_*`; mapear error de clave a 403/404. |
| OR-19 | P2 | `handlers.go:411-414`, `orbit.go:239` | Con `Config.DataSource` custom `SchemaRegistry` es nil y `p.registry.Get` desreferencia nil (`Registry.Get` hace `r.mu.RLock()`): panic → 500 vía `router.Recoverer`, **antes** de `authorizeAction`. | Guard `if p.registry == nil → 501/404`. |
| OR-20 | P2 | `internal/admin/ui/package-lock.json` (D17) | react-router 7.17.0 con GHSA-wrjc-x8rr-h8h6 (open redirect) y GHSA-chx6-hx7r-mcp5; `npm audit --omit=dev`: 5 (3 high). | `npm audit fix` → 7.18.3; job de audit en CI. |
| OR-21 | P2 | `management.go:335-370` | `ParseMultipartForm(50<<20)` es umbral de memoria, no límite; sin `http.MaxBytesReader` → subida ilimitada. Clave `_tmp/import_ts_<Filename>` sin sanear. | `MaxBytesReader` + `filepath.Base` + whitelist de extensión. |
| OR-22 | P2 | `store.go:123-131`, `handlers.go:523,634,668` | `GET /api/models/Note/abc` → **500** `{"error":"datasource/nucleus: invalid id \"abc\""}` (probado); igual en PUT/DELETE. | Envolver en `gferrors.BadRequest`/`NotFound`. |
| OR-23 | P2 | `panel.go:672-686`, `handlers.go:515-680`, README «Filter records by the request's resolved tenant» | El tenant es un filtro de vista: `?tenant=all` lo apaga; Get/Update/Delete/bulk por id no comprueban tenant. La doc sugiere aislamiento. | Documentar como «scope de vista» o derivar tenant de la identidad y aplicarlo en todas las operaciones. |
| OR-24 | P2 | `server/server.go:93,109-111` (F4) | Sin `connect.WithReadMaxBytes`: frames de cientos de MB retenidos en replay. | `WithReadMaxBytes(4<<20)` + cap de payload. |
| OR-25 | P2 | `server/nodes/registry.go:125-129` (F5) | Reconexión con el mismo NodeID no cancela el stream viejo (`closeOnce.Do(func(){})` no-op; comentario falso) → eventos duplicados. | Guardar `cancel` en `Entry` o rechazar `AlreadyExists`. |
| OR-26 | P2 | `server/services/control_service.go:105-142` (F6) | Sin límite de `StreamEvents` por operador; cada apertura reenvía el ring completo y re-agrega filtros a todos los agentes. | Cap por identidad, límite de replay, debounce. |
| OR-27 | P2 | `AGGridTable.tsx:136-209,329-332` (D8, D9) | Ordenación solo cliente (ignora `order_by`); dos loaders sin `AbortController` y fetch por tecla → carreras de estado. | `onSortChanged` → `order_by`; un loader + abort + debounce. |
| OR-28 | P2 | `AuditLogPage.tsx:28-31` vs `audit.go:345-349` (D10) | Búsqueda del audit no hace nada (`search` no existe en API); sin paginación en UI. | Filtros `user_id/model/action` + paginación. |
| OR-29 | P2 | `NetworkInspectorPage.tsx:52-92`; `api.ts:83-100,213-221` (D11, D13) | WS sin `onclose`/reconexión; identidad fabricada (`admin`, `is_superuser:true`) sin consultar al servidor. | Reconexión con backoff; `GET /api/me`. |
| OR-30 | P2 | SPA in-process §a11y (D16); `RBACPage.tsx:113-118` (D15) | 0 `aria-*`, contraste 1,9–2,3:1, fuentes 9-10 px, `<button>` anidado, AG Grid sin tema dark. | aria/htmlFor/contraste; `render={<Button/>}`; `ag-theme-quartz-auto-dark`. |
| OR-31 | P2 | `toaster.tsx:15-26`, `use-toast.ts:6` (D6); `RecordForm.tsx:52-54,163` (D14) | Toasts sin cierre (`TOAST_REMOVE_DELAY = 1_000_000`); `datetime-local` pierde zona horaria. | Cierre + 5 s; ISO con offset. |
| OR-32 | P2 | `quarkbridge/quarkbridge.go:156`; `quarkdatasource/store.go:130,211,520-522` (fleet) | `ModelName` siempre vacío → filtro `sql_models` del fleet descarta todo SQL de quark; `Store()` ignora `dbAlias`; `ForeignColumn` «id» hardcodeado; filtros no validados contra `ModelInfo`. | Rellenar `ModelName`; honrar alias; validar columnas. |
| OR-33 | P3 | `panel.go:442-447` | Comentario «DEPRECATED (Phase 7)… removed in Phase 8» sobre `/api/models/*` — contradice CLAUDE.md («el panel in-process es el producto real») y D2. | Borrar; documentar la API como estable. |
| OR-34 | P3 | `rbac.go:17-124`; `server/auth/auth.go:224-268` (F8, F9) | `newRBACAuth`/`combinedAdminAuth` sin usos fuera de tests; `IdentityFromRequest` confía en `X-Auth-User` sin CIDR; `parseCIDRs` traga entradas malformadas. | Eliminar; fail-fast. |
| OR-35 | P3 | `default_auth.go:311-345`, `audit.go:72-134` | `SELECT * FROM nucleus_admin_users` en **cada** request autenticada y búsqueda lineal; el audit copia y ordena 10 000 entradas por petición. | `WHERE id = ?`; índice/orden estable. |
| OR-36 | P3 | `go.mod` raíz, `go.work.sum`, `.github/workflows/ci.yml` | `go mod tidy` no es limpio: `drivers/sqlite` pasa de `// indirect` a directo, `go.sum` +16, `go.work.sum` +43; cualquier `go build` con workspace lo ensucia. No hay guard de tidy en CI. | Commit tidy + job `go mod tidy && git diff --exit-code`. |
| OR-37 | P3 | `.gitignore:1-4`, `internal/admin/ui/README.md:1-160`, `internal/admin/ui/package.json` (D22) | `.gitignore` habla de una sola SPA y de `ui_fallback.go`; hay **dos** SPAs (1,9 MB y 444 KB de dist) con stacks distintos; README de la in-process cita `pkg/admin/ui`, `build-ui.sh`, shadcn. | Actualizar; decidir convergencia (§4 largo). |
| OR-38 | P3 | `docs/adrs/ADR-002-*.md:4,14`, `docs/adrs/README.md:13`, `CLAUDE.md` | ADR-002 sigue «draft — sin decidir» cuando `quantum/docs/RUMBO.md` registra D2 como TOMADA (2026-08-31) en dirección «fleet consume datasource». | Aceptar el ADR con la decisión y fecha. |
| OR-39 | P3 | `proto/EVOLUTION.md:26-27,103,111`; `agent/buffer/buffer.go:4-9`; `server/config.go:26` (fleet docs) | «buf breaking en cada PR» y «CI falla si `make proto` diverge»: `ci.yml` no ejecuta buf; `SCHEMAS.md` referenciado no existe; el ring «bridges brief disconnects» solo actúa por backpressure con stream vivo (F18); «Production MUST configure AgentTLS» desactiva el guard sin cifrar (OR-1). | Corregir doc o añadir el job. |
| OR-40 | P3 | `management.go:35-115` | `/api/health` devuelve `"version":"Orbit"` (nombre en el campo versión) y `uptime:""`. | Inyectar versión del módulo y uptime real. |
| OR-41 | P3 | `datastudio_service.go:328-336` vs `agent/datastudio/datastudio.go:538` (F7); `agent_service.go:81` (F10); `connection.go:320` (F11) | Audit de create sin id (`"id"` vs `"ID"`); `started_at` nil → 1970; sonda `/healthz` envía el bearer aunque esté exenta de auth. | `meta.PrimaryKey`; nil-check; no enviar token. |
| OR-42 | P3 | `hardening.go:34-36`; `default_auth.go` limiter | CSP `connect-src 'self' ws: wss:` sin host; lockout en memoria por proceso (no global en multi-nodo). | `ws://host`/`wss://host`; limiter opcional en Redis. |
| OR-43 | P3 | `nucleus/pkg/model/fields.go:100-125`; `handlers.go:530-538` | Por defecto ningún campo es `search`/`filter` (requiere tag `admin:"search,filter"`); `?search=` sin campos responde 200 con todo, sin aviso. | Search por defecto en campos string; 400 o `warning` cuando no aplica. |
| OR-44 | P3 | `internal/admin/ui/dist/assets/*` (SPA) | Bundle 1 279 KB JS (348 gzip) + 254 KB CSS (205 KB de temas AG Grid no usados); sin lazy routes; 16 `any`; código muerto en `api.ts`. | Tree-shake temas; lazy por feature. |

## 6. Resultados de ejecución

| Paso | Resultado |
|---|---|
| `go build ./... && go vet ./...` en `.`, `agent`, `proto`, `quarkbridge`, `quarkdatasource`, `server` | Limpio (0 salida) en los seis módulos. |
| `go test ./... -count=1 -short` | **18/18 paquetes ok**: root, contracts, internal/admin (7,4 s), datasource/nucleus, server ×4, agent ×8, quarkdatasource, quarkbridge. `proto` sin tests. Ningún FAIL/panic. |
| `go test -race` (panel: internal/admin, root, datasource/nucleus) | ok (38 s). |
| `go test -race` (server/, agent/) | ok en las dos ejecuciones (sub-auditor y propia: 12 paquetes, 0 data races). Sin tests en `server/services`, `server/ui`, `cmd/admin-server`, `agent/datastudio`, `agent/hostmetrics`, `agent/rbac`, `agent/stream`. |
| `go mod tidy` | **No limpio en raíz** (OR-36): `go.mod` 1 línea (sqlite indirect→directo), `go.sum` +16, `go.work.sum` +43. Limpio en los otros cinco. Repo restaurado con `git checkout`. |
| `npm ci && npm run build` en `internal/admin/ui` | ci 2,4 s, build 5,3 s; `dist` trackeado == build (reproducible, verificado por CI `ci.yml:239-266`). `npm test`: **no existe script**; lint: **no configurado**. `npm audit --omit=dev`: 5 vulns (3 high). |
| `npm run lint/typecheck/build` en `ui/` (fleet) | 0 warnings, typecheck ok, build ok; `server/ui/dist` == build; bundle 430 KB (121 gzip). Sin tests. |
| Tamaño embebido | in-process 1,9 MB (JS 1 279 KB + charts 393 KB + CSS 254 KB); fleet 444 KB. Binario de la app DX: **64 MB** (arrastra pgx/mysql/mssql/oracle/otel vía nucleus). |
| DX: montaje en `scratchpad/auditoria/orbit-dx/` (nucleus v1.23.0 y orbit por `replace`, SQLite) | `go mod tidy` 0,07 s, build 3,8 s. Arranca; `/admin` → 307 → login; login OK (303), `/api/models` lista `Note`, CRUD, export CSV, sesiones, RBAC, audit, health, live snapshot: funcionan. Lockout al 11.º intento (429). CSRF por content-type (415). Cabeceras CSP/XFO/nosniff/Referrer/COOP/CORP/Permissions-Policy presentes; sin HSTS (delegado a TLS). **Pasos reales**: 3 ficheros + saber que hay que importar el driver SQLite (el ejemplo oficial no lo hace, OR-5) + `session_cookie_secure: false` para HTTP local. Ruido al arrancar: 3 WARN (prometheus no enlazado, jwt sin clave, authz sin políticas) que un recién llegado no sabe si le afectan. |
| DX: `examples/minimal` tal cual | **No arranca** (OR-5). |
| Sondas de defectos (curl) | Confirmadas: validación ausente (OR-2), env en claro (OR-3), IDs uint (OR-14), live autocontaminado (OR-15), audit incompleto (OR-16), 500 por id no numérico (OR-22), export download sin confinar (OR-18), coerción `123 → "123.0"` (OR-2). |
| Estado del repo al terminar | Limpio (`go.work.sum` restaurado tras cada ejecución con workspace). |
