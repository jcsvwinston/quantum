# Auditoría del panel in-process de Orbit (`internal/admin/ui`) — informe del sub-auditor de la SPA

(Reconstruido desde el resultado del sub-agente; rutas bajo `/Users/jcsv/GolandProjects/orbit/internal/admin/`.)

## Resumen ejecutivo
Panel de observabilidad con un CRUD genérico encima, no un "admin framework". Bueno: contrato tipado, CSP estricta (`script-src 'self'`), cookie de sesión sin tokens en localStorage, prefijo inyectado por meta, `dist` reproducible y verificado en CI (`.github/workflows/ci.yml:239-266`), FieldConfigPanel (edición de metadatos de campo en caliente). Malo: tres flujos que "funcionan" en la UI y no hacen lo que dicen (Import no-op con toast de éxito; Load More reemplaza en vez de anexar; batch 500 → 400), `deny` pintado igual que `allow` en RBAC, corrupción de campos JSON al editar, 0 tests, 0 lint, 0 `aria-*`, 0 i18n.

## Defectos (D1–D22)
| # | Sev | Defecto | Evidencia | Corrección |
|---|---|---|---|---|
| D1 | P1 | Import es un no-op con toast de éxito; nunca llama a validate/execute | `ui/src/features/data-studio/components/AGGridTable.tsx:314-327`, `ui/src/lib/api.ts:434-448`; backend `management.go:335-380` devuelve `key`; `:261-333` requieren `model`+`key` | Flujo upload → `POST /api/import/validate?key=` `{model}` → `POST /api/import/execute`. Quitar `.sql` del accept. |
| D2 | P1 | "Load More" reemplaza filas (applyTransaction + re-render con `rowData={result.items}`) | `AGGridTable.tsx:154-158` vs `:506` | Array acumulado en estado como `rowData`. |
| D3 | P1 | Batch size 500 → HTTP 400 (`page_size must be <= 200`) | `AGGridTable.tsx:559` vs `handlers.go:478-480` | Limitar opciones a ≤200. |
| D4 | P1 | JSON/struct/array → `[object Object]` y se guarda como ese string (corrupción en PUT) | `RecordForm.tsx:55,163`; `AGGridTable.tsx:94-95`; `handlers.go:650,669` | `JSON.stringify` display / `JSON.parse` al guardar; `html_type: 'json'`; mientras, readonly para no primitivos. |
| D5 | P1 | RBAC: `deny` se muestra como `allow` (`eft` descartado) | `api.ts:251-262`; `rbac.go:150-161` | Propagar `eft`, badge allow/deny. |
| D6 | P2 | Toasts sin cerrar ni auto-dismiss (`TOAST_REMOVE_DELAY = 1_000_000`) | `toaster.tsx:15-26`, `toast.tsx:38-50`, `use-toast.ts:6` | Cablear close + 5 s. |
| D7 | P2 | IDs asumidos numéricos en bulk (`[]uint`); PK string/UUID → 400 | `AGGridTable.tsx:46,263,291`; `api.ts:191`; `handlers.go:726` | ids como string; backend acepta RawMessage. |
| D8 | P2 | Ordenación solo cliente; `order_by` del backend no se usa | `AGGridTable.tsx:74`; `api.ts:154` | `onSortChanged` → `order_by`. |
| D9 | P2 | Race: dos loaders, sin AbortController, fetch por tecla | `AGGridTable.tsx:136-172,174-181,184-209,329-332` | Un loader + AbortController + debounce. |
| D10 | P2 | Búsqueda de Audit no hace nada (`search` no leído; backend lee user_id/model/action); sin paginación UI | `AuditLogPage.tsx:28-31`; `audit.go:345-349` | Tres filtros reales + paginación. |
| D11 | P2 | WebSocket sin onclose/reconexión | `NetworkInspectorPage.tsx:52-92` | onclose + backoff. |
| D12 | P2 | Errores tragados / genéricos; 403 indistinguible de 500 | `OverviewPage.tsx:38-40`; `HealthPage.tsx:31-36`; `RBACPage.tsx:42-48`… | `ApiError{status, body}`. |
| D13 | P2 | Identidad fabricada (`admin`/`is_superuser:true` sin consultar); Sessions `ID: 0`, UA vacío | `api.ts:83-100,213-221` | `GET /api/me`. |
| D14 | P2 | `datetime-local` pierde TZ (recorte a 16 chars) | `RecordForm.tsx:52-54,163` | ISO con offset. |
| D15 | P2 | `<button>` anidado (DialogTrigger + Button) | `RBACPage.tsx:113-118` | `render={<Button/>}`. |
| D16 | P2 | a11y: 0 aria, contraste 1,9–2,3:1, fuentes 9–10 px, AG Grid sin variante dark | §3; `AGGridTable.tsx:503` | aria-label, htmlFor, -700/-400, auto-dark. |
| D17 | P2 | Vulns runtime: react-router 7.17.0 (open redirect GHSA-wrjc-x8rr-h8h6, DoS GHSA-chx6-hx7r-mcp5); `npm audit --omit=dev`: 5 (3 high) | `package-lock.json` | `npm audit fix` → 7.18.3. |
| D18 | P3 | 16 usos de `any` | `types/index.ts:79,144`; … | `unknown` + guards. |
| D19 | P3 | Código muerto: `api.login`, `useAuth.login`, `getRecords`, `getFeatureFlags`… | `api.ts:53-76,102-113,164-171,299-318,399-411` | Borrar o cablear. |
| D20 | P3 | setTimeout sin clear; useToast re-suscribe | `AGGridTable.tsx:213-216,232-235`; `use-toast.ts:171-179` | Limpiar. |
| D21 | P3 | Borrado de política/sesión sin confirmación; `key={index}` | `RBACPage.tsx:88-103,210`; `InfraManagerPage.tsx:43-58` | Diálogo de confirmación. |
| D22 | P3 | README de ui obsoleto (`pkg/admin/ui`, `build-ui.sh`, shadcn); `package.json` name `nucleus-admin-ui` 1.0.0 | `ui/README.md:1-160` | Actualizar. |

## Otras observaciones
- Filtros: solo igualdad exacta (`datastudio.go:49-51,78-98`); AG Grid filtra cliente sobre la página cargada: dos sistemas incoherentes.
- Bulk: solo delete; backend soporta `export` con `export_url` (`handlers.go:760+`) sin UI. Export ignora filtros/selección.
- Sin FK lookup, M2M, inlines, historial, acciones custom, vistas guardadas, edición inline.
- Endpoints sin UI: feature flags, migraciones, cache, storage browse, email stats, fixtures, queue, live excludes, deployment info, sites (`panel.go:462-517`).
- i18n: ninguna; branding: solo título; sin logo/paleta.
- Build: `npm ci` 2,4 s; build 5,3 s; `index-*.js` 1 279 KB (gzip 348), CSS 254 KB (205 KB son `.ag-*` incl. temas dark no usados); sin lazy routes; AG Grid 32.3.9 (latest 36.1), deprecaciones `checkboxSelection`/`suppressMenu`.
- Tests: 0. Lint: no hay eslint/prettier/biome en `internal/admin/ui` (sí en `orbit/ui` fleet).
- Verificado NO defecto: XSS (0 innerHTML), tokens en localStorage (solo tema), 401 redirige, CSP sin inline.
