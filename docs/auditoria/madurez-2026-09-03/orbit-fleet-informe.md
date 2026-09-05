# Auditoría del plano fleet de Orbit (proto/agent/server + quarkbridge/quarkdatasource) — informe del sub-auditor

Repo `/Users/jcsv/GolandProjects/orbit` @ ba23abd. Nada editado.

## Ejecución
- `go test -race ./... -count=1 -short` en server/: OK. Sin tests: services, ui, cmd/admin-server.
- agent/: OK. Sin tests: datastudio, hostmetrics, rbac, stream.
- SPA fleet `ui/`: lint 0 warnings, typecheck OK, build OK; bundle 430 KB (121 gzip); `server/ui/dist` == build (sin diff).

## Defectos
| # | Sev | Dónde | Evidencia | Corrección |
|---|---|---|---|---|
| F1 | **P0** | `server/server.go:490` vs `:256,:263`; `:421` | `newH2CServer` asigna `srv.TLSConfig` pero `Run` llama `Serve(ln)` (nunca `ServeTLS`/`tls.NewListener`) → `--agent-cert/--agent-key` y `--ui-cert/--ui-key` NO aplican TLS. Además `agentListenerGuard` acepta `c.AgentTLS != nil` como autenticación → `admin-server --agent-addr=:9090 --agent-cert=… --agent-key=…` arranca h2c en claro, sin token, en todas las interfaces, logueando `agent_tls=true`. Reproducido: GET http en claro → 200; `tls.Dial` → "first record does not look like a TLS handshake". | `ln = tls.NewListener(ln, cfg)` con `NextProtos: ["h2","http/1.1"]`; test de handshake; el guard no debe contar AgentTLS como auth hasta que exista. |
| F2 | **P1** | `agent/agent.go:238-242`, `agent/connection/connection.go:289-306` | Dialer sin `TLSConfig`; `DialTLSContext` devuelve TCP plano para `https://` → el stream no puede hablar con un endpoint https (la sonda /healthz sí). Reproducido contra httptest TLS. Sin knobs CA/cert cliente en `ExtensionConfig`. | Decidir por esquema; exponer `TLS`/`CAFile`; test e2e https. |
| F3 | **P1** | `server/cmd/admin-server/main.go:176-188`, `config.go:24`, `README:55` | `loadTLS` solo `Certificates`+`MinVersion`; no hay `ClientCAs`/`ClientAuth` → no existe mTLS aunque se anuncie. | `--agent-client-ca` + `RequireAndVerifyClientCert`; corregir docs. |
| F4 | P2 | `server/server.go:93,109-111` | Sin `connect.WithReadMaxBytes`: payloads de cientos de MB retenidos en Replay. | `WithReadMaxBytes(4<<20)` + cap de payload. |
| F5 | P2 | `server/nodes/registry.go:125-129` | Reconexión con mismo NodeID no cancela stream viejo (`closeOnce.Do(func(){})` no-op; comentario falso) → duplicados. | Guardar cancel en Entry o rechazar con AlreadyExists. |
| F6 | P2 | `server/services/control_service.go:105-142` | Sin límite de suscripciones StreamEvents por operador; cada apertura empuja aggregate a todos los agentes y reenvía ring completo. | Cap por identidad, limit en replay, debounce. |
| F7 | P3 | `datastudio_service.go:328-336` vs `agent/datastudio/datastudio.go:538` | `recordID` lee `values_json["id"]` pero el agente serializa `"ID"` → audit de create sin id. | Usar `meta.PrimaryKey`. |
| F8 | P3 | `server/auth/auth.go:224-240` | `IdentityFromRequest` código muerto que confía en X-Auth-User sin CIDR. | Borrar. |
| F9 | P3 | `server/auth/auth.go:245-268` | `parseCIDRs` ignora entradas malformadas; `ErrTrustedProxyMisconfigured` nunca se devuelve. | Fail-fast. |
| F10 | P3 | `agent_service.go:81` | `started_at` ausente → epoch 1970. | nil-check. |
| F11 | P3 | `agent/connection/connection.go:320` | Sonda /healthz (exenta de auth) envía el bearer en claro a cada endpoint. | No enviar token. |
| F12 | P3 | `routing/replay.go:119-123` vs `eventbus.go:328-340` | Matchers de NodeIds distintos (exacto vs EqualFold). | Compartir matcher. |
| F13 | P3 | `agent/datastudio/datastudio.go:223-230`; `quarkdatasource/store.go:90` | Search LIKE sin escapar %/_. | ESCAPE. |
| F14 | P3 | `agent/metrics/metrics.go:47-50`, `agent/agent.go:332` | `reconnects_total` cuenta ciclos fallidos. | Incrementar en OnAccepted. |
| F15 | P3 | `agent/hostmetrics/hostmetrics.go:52-56` | cpu_percent sin /NumCPU (>100 %); RSS=0 fuera de Linux. | Normalizar/documentar. |
| F16 | P3 | `agent_service.go:192`, `control_service.go:262`, `main.go:223`, `buffer.go:207` | `var _ = sync.Mutex{}`… imports muertos. | Eliminar. |
| F17 | P3 | `agent/stream/stream.go:424-435,456-467`, `snapshot.go:24` | Goroutine por comando sin límite en el agente. | Semáforo. |
| F18 | P3 | `agent/stream/stream.go:207-211` + buffer | El ring solo captura por backpressure con stream vivo; durante desconexión no bufferiza nada, contra lo que dice `buffer.go:4-9`. | Mantener suscripción o documentar. |

## Inconsistencias API agent/server
`resp.Error` del agente → siempre `CodeUnknown` (`datastudio_service.go:250`) vs `FailedPrecondition` en `manage_service.go:82`; `database_alias` de list_models ignorado en fast path (`datastudio_service.go:70-84`).

## Confirmación D2/ADR-002
`agent/datastudio/datastudio.go:53` importa `nucleus/pkg/model` directamente; `:426` `model.NewCRUD(sqlDB, meta, nil)`; no aparece `datasource.DataSource` en agent/ ni server/. `:13-15`: "NO per-model RBAC… NO multi-tenant". Modelos de `quarkdatasource` no existen para el fleet. Lecturas sin gate (`datastudio_service.go:286`).

## quarkdatasource / quarkbridge
- quarkdatasource implementa todo `datasource.DataSource`; `parseID` (`store.go:258-283`) rechaza `uuid.UUID` ([16]byte); composite/no-PK → ReadOnly; no valida columnas contra ModelInfo (`store.go:520-522`); `%`/`_` sin escapar; solo belongs_to, `ForeignColumn` "id" hardcodeado (`:211`); `Store()` ignora dbAlias (`:130`).
- quarkbridge: `ModelName` siempre vacío (`quarkbridge.go:156`) → filtro `sql_models` en fleet descarta todos los statements de quark.

## Docs falsas o exageradas
| Doc | Afirmación | Realidad |
|---|---|---|
| `server/README.md:55`, `cmd/admin-server/main.go:14`, `config.go:11,24,34,42`, `auth/auth.go:3,37`, `agent/agent.go:43`, `agent/extension_config.go:22` | "mTLS at the listener" | No hay ClientCAs/ClientAuth; TLS ni se aplica (F1). |
| `website/docs/operations/security.md:152-157`, `cluster/server.md`, `deployment.md:84,105,116` | "TLS 1.2+ when PEM supplied"; "Agents accept https:// endpoints" | Falso (F1, F2). |
| `cluster/agent.md:38`, `agent/README.md:37`, `deployment.md:202` | Ejemplo `Endpoints: ["https://admin.internal:9090"]` | No funciona. |
| `config.go:26` | "Production MUST configure AgentTLS" | No hace nada y desactiva el guard fail-closed. |
| `proto/EVOLUTION.md:26-27,111` | "buf breaking en cada PR", "CI falla si make proto produce diff" | ci.yml no ejecuta buf; `proto/README.md:30` dice lo contrario (correcto). |
| `proto/EVOLUTION.md:103` | Esquemas JSON en `admin/server/snapshot/SCHEMAS.md` | No existe. |
| `agent/buffer/buffer.go:4-9`, `cluster/agent.md` | "ring buffer bridges brief disconnects" | Solo backpressure (F18). |
| `server/nodes/registry.go:125` | "old handler will detect ctx done" | No se cancela nada (F5). |

## SPA fleet (`ui/`)
12 páginas, router hash a mano; 0 tests; i18n = catálogo centralizado inglés; a11y razonable (aria-live, aria-label, foco en diálogo) con faltas (`aria-current` en nav, skip-link); tema en localStorage sin try/catch (`App.tsx:66`).

## Frente a Grafana / K8s Dashboard
Tiene: binario único, feed live con sampling/backpressure, Data Studio, snapshot RBAC. Falta: retención/persistencia (0), alertas (0), dashboards configurables/lenguaje de consulta, métricas propias en /metrics (solo go_*/process_*), multi-cluster/HA, RBAC granular (viewer/rw + allowlist), multi-tenancy fleet, logs/trazas correlados, plugins, API pública estable, tests de SPA/services/stream.
