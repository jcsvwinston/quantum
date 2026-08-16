# CHANGELOG de la suite Quantum

Historial narrativo de los sets certificados. La entrada del set VIGENTE
vive en `versions.yaml` (`notes:`); al certificar un set nuevo, la entrada
anterior se mueve aquí (DX-25 — antes el manifiesto acumulaba ~4 300
palabras de historial interno en el fichero que la gente abre para saber
qué instalar).

## Quantum 1.11.0 (vigente — copia de la nota del manifiesto)

Quantum 1.11.0 — Arco QCD-FW (micro-arco de features dirigido por los
hallazgos de framework de quantum-coverage-demo; Quantum 1.10.1 seguía
certificada). Cierra los dos hallazgos que el arco QCD-CLI dejó
registrados con workaround declarado, más el cableado prometido en
v1.6.2. **nucleus v1.7.0 (minor):** QCD-FW-1 — el authz global
default-deny ve claims JWT: App.New monta el decoder opcional de bearer
por delante del enforcement y el middleware resuelve sujetos en orden
uid → rol → anonymous (primer permitido gana; el fallback anonymous
preserva el allowlist de bootstrap para autenticados — dirección
estrictamente no-restrictiva). El RBAC por roles del CSV de AUTH_GUIDE
es alcanzable en la capa global sin replicarlo por módulo. QCD-FW-2 —
bootstrap de buckets S3: CreateBucketIfMissing (opt-in, provisiona al
construir) y S3Store.EnsureBucket (programático, idempotente); cambio
declarado: sin opt-in, un bucket ausente falla ALTO en el constructor en
vez de bootear verde y reventar en el primer Put. Además,
ServiceRegistration.Health cableado a /healthz como service:<name> (503
si falla), con health.FuncProbe y app.RegisterHealthProbe como piezas
reutilizables. **orbit v1.5.4 (patch):** alineación pura de deps a
nucleus v1.7.0 (agent v0.5.10, server v0.9.5, quarkbridge v0.3.9; proto
y quarkdatasource sin cambios). **quark v1.4.1:** sin cambios, continúa
del set 1.10.1. La demo puede retirar sus dos workarounds declarados
(fila-puerta anonymous + RBAC por módulo, y el MakeBucket a mano en
OnStart). Nombre 1.11.0 (minor): el minor de nucleus arrastra el número
de suite (QADR-0002).

## Histórico

--- Quantum 1.10.1 (histórico) — Arco QCD-CLI (micro-arco de reparación, NO una ronda;
Quantum 1.10.0 seguía certificada). Primera vez que el detector es EXTERNO:
quantum-coverage-demo, un consumidor independiente que ejercita la suite
solo por module proxy, reportó 5 hallazgos de CLI con repro rojo ejecutado
(QCD-CLI-1..5) más papercuts de doc (QCD-FW-3); todos cerrados en producto
con disciplina rojo-sin-fix. **quark v1.4.1 (patch):** QCD-CLI-1 model
generate --fields compila y declara PK (imports derivados de los campos,
tag quark solo con vocabulario del ORM), QCD-CLI-2 receta de embebido con
commands.Main() que propaga errores (la impresa por el propio CLI salía 0
en silencio), QCD-CLI-3 tenant provision completa bajo schema_per_tenant
con gate de idempotencia en quark_tenants antes de cualquier DDL, más
papercuts (migrate status con pendientes y sin error en base fresca,
seeders en orden de registro, init lee go.mod, InstallRLSPolicies
re-ejecutable con DROP POLICY IF EXISTS — cambio de comportamiento
declarado). **nucleus v1.6.2 (2 patches):** QCD-CLI-4 generate
resource/startapp emiten DDL del dialecto de la base configurada (exports
nuevos db.SystemFromURL y model.BuildMigrationScaffoldForSystem) con
--dialect/--config/--database; QCD-CLI-5 loaddata carga en orden
topológico por FKs introspectadas y respeta --tables (round-trip
dump→load en una invocación); papercuts QCD-FW-3 (healthz honesto, import
path de storage, acciones CRUD en AUTH_GUIDE, Health sin cablear
declarado). **orbit v1.5.3 (2 patches):** alineación pura de deps (quark
v1.4.1, nucleus v1.6.2) en v1.5.2, y v1.5.3 recoge proto/v0.4.2 — la
directiva go del bump transversal tocó proto/go.mod y el guard §3 exige
que el pin no lleve código de módulo sin publicar; su onda re-pina agent
(v0.5.9) y server (v0.9.4). **Transversal a los tres pilares:**
toolchain/directiva go a 1.26.6 (CVEs stdlib GO-2026-6218/6091/6090/6089),
grpc v1.82.1 (GO-2026-6061) y otel v1.44.0 (GO-2026-5158) donde eran
alcanzables. Quedan REGISTRADOS para un arco propio (feats → minor):
QCD-FW-1 (la capa global de authz nunca ve claims JWT) y QCD-FW-2 (S3Store
sin bootstrap de bucket) — la demo opera con workarounds declarados.
Nombre 1.10.1 (patch): solo patches en los tres pilares (QADR-0002).

--- Quantum 1.10.0 (histórico) — Arco de endurecimiento #1 (micro-arco de hardening, NO una
ronda; Quantum 1.9.0 seguía certificada). Cierra a CERO el backlog de
REVISION_DIRIGIDA_SEG_1 — la primera revisión dirigida de seguridad del
régimen de auditoría continua: SEC-1..4 y MAQ-1..5. Nombre 1.10.0 (minor) y
no «1.9.1» porque el minor de nucleus (v1.5.0→v1.6.0) obliga al número de
suite a reflejar el vX.Y.Z real (QADR-0002). La revisión halló el FRAMEWORK
(quark/nucleus/orbit) LIMPIO: la seguridad accionable estaba en la app de
referencia (que enseñaba un anti-patrón que otros copian) y en la maquinaria
de guards; SEC-3/SEC-4 entran en nucleus como defensa en profundidad.
**quantum-app v0.1.2 (SEC-1, SEC-2 — lo más importante del arco):** mata el
anti-patrón credential-by-default. main es fail-closed — mustEnv rechaza
WAREHOUSE_OUTBOX_SECRET y WAREHOUSE_OPS_PASSWORD si van sin valor, vacíos, o
con uno de los valores-ejemplo públicos del repo (dev-outbox-secret,
warehouse-ops): el boot MUERE alto y claro en vez de arrancar sobre una
credencial que vive en el árbol. Y se eliminó el downgrade a token estático
del hook del outbox: /hooks/outbox exige la firma HMAC del cuerpo y nada más
(rojo-sin-fix demostrado: con el downgrade reintroducido, «sin cabecera de
firma + buen token» iba a 200; con el fix, 401). Alineado además a SEC-3: el
consumidor decodifica por el encoding CONFIGURADO
(WAREHOUSE_OUTBOX_ENCODING), nunca por la cabecera sin firmar, y rechaza el
mismatch (400). E2E Docker 7/7 real. **nucleus v1.6.0 (minor; SEC-3, SEC-4,
MAQ-5):** SEC-3 — decisión Opción 2: la cabecera X-Outbox-Payload-Encoding se
queda INFORMATIVA/sin firmar (firmarla habría bifurcado el esquema de firma
body-only, un verificador para webhooks de módulo y de outbox, pineado por un
test); el helper nuevo de consumidor outbox.CheckPayloadEncoding + el
centinela ErrPayloadEncodingMismatch cierran el hueco en el lado que decodea;
el wire NO cambia. SEC-4 — el boot rechaza path=="/" y nombres de módulo con
«..» o «/» (defensa en profundidad). MAQ-5. Este minor de nucleus es el que
arrastra el número de suite. **orbit v1.5.1 (+ agent/v0.5.6, server/v0.9.1,
quarkbridge/v0.3.6; quarkdatasource/v0.2.7 y proto/v0.4.1 sin cambios):**
MAQ-3 — la excepción root-edge del guard de pins internos se ciñe al ÚNICO
borde topológicamente forzado (root↔quarkdatasource, por directorio
consumidor) y verifica el contrato de datasource congelado contra la línea
base de ADR-001; alineación de deps a nucleus v1.6.0, sin cambios de
comportamiento de orbit. **Maquinaria del paraguas (MAQ-1, MAQ-2, MAQ-4):**
las dos costuras del guard del tag de suite — MAQ-1/B.1 assert 5 (el tag
CAPTURA HEAD: gitlinks del tag == gitlinks de HEAD == workspace_pins de HEAD;
un tag rancio-pero-autoconsistente pasaba los asserts 2-4 y moría solo aquí),
MAQ-2/B.2 modo certificación (--cierre / QUANTUM_CERTIFYING=1) que trata el
AVISO mid-tren «versión sin tag» como NO-PASA y exige la captura de HEAD, de
modo que «15/15 EXIT=0 en --cierre» solo puede significar «tag cortado que
captura HEAD»; MAQ-4 endurece el notificador de fallo del schedule. Esta
certificación ESTRENA el modo --cierre. **Seguridad transversal:**
GO-2026-5970 (bucle infinito en x/text) se mantiene en v0.39.0 (arrastrado
por MVS). Reglas del arco cumplidas: cada guard nuevo/modificado probado en
negativo y con fixture en guard-of-guards; cada fix de seguridad con
rojo-sin-fix demostrado; E2E de quantum-app 7/7 con Docker real; tren en
orden de dependencia; tag de suite tras el último PR. El cierre SOLICITA una
verificación humana dirigida ACOTADA a (a) SEC-1/SEC-2 no dejan vivo ningún
camino de auth débil y (b) B.1/B.2 no rompen un flujo de certificación
legítimo.

--- Quantum 1.9.0 (histórico) — 8ª ronda (consolidación final; nombre 1.9.0 y no «1.8.1»
porque release-please dictó MINORS en los tres pilares — QADR-0002 obliga
al número de suite a reflejar el vX.Y.Z real): backlog de la 8ª auditoría a
CERO y ACTIVACIÓN del régimen de auditoría continua — a partir de la 9ª la
certificación descansa en la lane semanal + juicio humano puntual, sin
pasada manual completa (dictamen de la 8ª). Esta ronda ES la primera
certificación por el régimen nuevo: Quantum 1.9.0 se certifica con
suite-integral 15/15 EXIT=0 + guard-of-guards 15/15 + CI por-repo verde +
E2E de quantum-app, SIN pasada manual. **quark v1.4.0 (minor):** modo
estricto de lecturas opt-in (WithStrictReads — WARN/reject de Iter/Cursor
sin límite + detección N+1 por contexto con TrackReads y escape
AllowUnbounded, coste cero apagado), contador BlockedPanicCleanups (hace
observable un cleanup de pánico del RLS bloqueado), WithLimits normaliza
los campos numéricos a cero desde DefaultLimits con WARN si un literal
parcial deja SafeMigrations=false. **nucleus v1.5.0 (minor):** EL FRENO —
el contrato del webhook del bridge del outbox versionado y firmado en UN
cambio (firma HMAC-SHA256 en X-Nucleus-Signature con secret por bridge,
cabecera X-Outbox-Payload-Encoding json|base64, default base64 = wire de
v1.4.0 byte a byte con #230 como opt-in, y test de contrato del CUERPO byte
a byte — el hueco que el freeze de símbolos no ve); Oracle pagina con
OFFSET/FETCH en pkg/model (era SQL inválido en un paquete stable — NU8-1) +
§2.6 de la 7ª; webhooks con path canónico obligatorio (boot falla) y
anti-replay opt-in por timestamp firmado; regla de IDs de hallazgo en el
linter de voz; lane Oracle endurecida con el healthcheck del contenedor
(gateaba solo el puerto → flake ORA-12514). **orbit v1.5.0 (+ agent/v0.5.5,
server/v0.9.0, quarkbridge/v0.3.5, quarkdatasource/v0.2.7):** el feed vivo
HTTP in-process POR FIN funciona (v1.4.4 lo sobre-prometía — nota corregida
en las release notes, OR8-1); alineación de deps al set; la excepción
root-edge del guard de pins se amplió a ≤1 minor de lag (topológicamente
forzado cuando el root cruza un minor). **quantum-app v0.1.1:** requireUser
en lecturas de pedidos (PII), datasheets con nosniff+attachment, unit tests
reales, imágenes minio/mailpit pinadas, el consumidor del outbox verifica
la firma con hmac.Equal, y un gate nuevo (check_human_labels) que asierta
README+TUTORIAL contra go.mod (QA8-1). **Gobernanza (paraguas):**
integration.yml con schedule semanal + issue automático en fallo (QM8-1);
runbook AUDITORIA_CONTINUA.md §6 con los disparadores de mini-pasada, el
decisor y la plantilla de CIERRE (regla nueva: un ✅ con asimetría conocida
se escribe ⚠️); guard del tag de suite (QM8-6); robustez QM8-3..8 (el
15º guard, umbrella-suite-tag, entra al registry y al guard-of-guards).
**Seguridad transversal:** GO-2026-5970 (bucle infinito en x/text) elevado
a v0.39.0 en los cuatro repos. **Este arco toca superficie de seguridad
(firma del bridge, auth de orders, paths de webhooks, anti-replay) y la
propia maquinaria (root-edge, lane Oracle, schedule) → el cierre SOLICITA
una revisión humana dirigida SOLO a esa superficie, primera aplicación del
régimen nuevo (disparadores §6.1 y §6.3).** Tren en orden de dependencia,
tag de suite tras el último PR.

--- Quantum 1.8.0 (histórico) — cierre de la 7ª ronda («cierre definitivo»): backlog de la
auditoría a CERO (los 3 restos de la 7ª pasada + P3 completo), lags
cross-repo a CERO (declared_lags vacío por primera vez desde que existe la
sección), y la certificación convertida en MECÁNICA: lane suite-integral
(los 14 guards de los 4 repos ejecutados AL PIN + gate de declared_lags
vacío) y guard-of-guards (14 fixtures de fallo que prueban en CI que cada
guard sigue mordiendo, con aserción anti-fósil de guards sin registrar y
cobertura fixture↔guard en ambas direcciones) + runbook
AUDITORIA_CONTINUA.md. **nucleus v1.4.0 (minor):** Jobs y Webhooks de
módulo EJECUTÁNDOSE — JobRegistry/WebhookRegistry ganan Register real
(aditivo sobre la forma congelada, como preveía el waiver W3 de ADR-013):
jobs sobre los providers existentes de pkg/tasks (memory/asynq vía
jobs_provider) con Every/Cron validado, Timeout y Singleton; webhooks como
rutas reales bajo webhooks_prefix con verificación HMAC-SHA256 en tiempo
constante (401 antes del handler), allow-list de métodos, tope de body y
exención CSRF automática del prefijo; registro inválido = boot falla; los
WARN «not executed» eliminados porque ya no son verdad. El estreno destapó
y corrigió un bug real de pkg/tasks: el Manager.Run de asynq esperaba
señales del SO y era imparable por API (ctx cancelado no lo desbloqueaba).
E2E por la superficie pública (boot real con CSRF, job ejecutándose,
webhook firmado 200 / mal firmado 401, SIGTERM limpio) + lane requerida
jobs-redis con Redis 7 real. NU7-1..4 y QM7-1 (showcase re-pinado con
guard de pins contra el último tag publicado EN VIVO + smoke por HTTP en
el gate requerido). **quark v1.3.3:** quark#252 cerrado por implementación
de raíz — la tx implícita de Create/Update bajo RLS nativo se acota a la
operación (la sonda contra PG real mostró 11 sesiones idle-in-transaction
= exactamente los 11 Create; DDL posterior bloqueado; read-your-writes
roto): sin retención hasta el fin del ctx, DDL en ms con ctx vivo, write
visible en el propio ctx; el executor devuelve la conexión al pool incluso
en pánico del driver (QK7-1, con detalle fino de los RLocks internos de
database/sql); errores ya no enmascarados como ErrNoRows en QueryRow
(QK7-3, driver interno que acuña rows-con-error); lane -race en CI con los
2 tests de batch acotados (QK7-2). **orbit v1.4.4 (+ agent/v0.5.4,
server/v0.8.4, quarkbridge/v0.3.4, quarkdatasource/v0.2.6):** sospecha de
auth POR ENDPOINT — un frame aceptado en A ya no resetea la evidencia de B
(OR7-2, test determinista ciclo a ciclo); guard de contenido de release
notes (OR7-1) y linter que veta IDs de hallazgo en el sitio (OR7-3);
requires de nucleus v1.4.0 y quark v1.3.3 en TODOS los módulos y el pin
del root de quarkdatasource actualizado (QM7-6). **Paraguas:** guard de
sincronía de sidebars espejadas disparando también en re-pins vía gitlinks
(QM7-4), comentario veraz en website-ci (QM7-5), regla de IDs de hallazgo
en el linter de lo servido. **quantum-app v0.1.0:** repo nuevo como consumidor
externo REAL de la suite (app warehouse; requires explícitos del set
certificado vía module proxy, JAMÁS workspace — guard GOWORK probado en
negativo en CI), con E2E Docker 7/7 de la banda nunca-ejecutada del §4:
sesiones Redis reales, S3 contra MinIO, SMTP real (Mailpit), outbox
transaccional sobre PG con bridge webhook, cadena
quark→quarkbridge→panel orbit con feed vivo por el bus, multi-base
PG+MySQL por alias y RÉPLICA física de PG (streaming) vía WithReplicas de
quark. El estreno de S3 cazó un bug real de nucleus (isS3NotFound compara
por texto y nunca mapea ErrNotFound contra un endpoint real — issue
abierto), más una observación del carril HTTP del live feed de orbit y un
papercut del payload base64 del bridge webhook (issues abiertos, 8ª
pasada). suite-manifest.yaml con denominador GENERADO desde los
inventarios de los 3 productos a los tags pinados: 789 ítems — 67
covered con evidencia puntual, 552 not-covered con razón, 170
out-of-scope — y gate que falla ante ítems sin clasificar, huérfanos y
pin drift (probado en negativo; el drift real del bump al set 1.8.0 lo
cazó en producción). Tren de
releases en orden de dependencias con el procedimiento nuevo QM7-3: el
tag de suite se corta DESPUÉS del último PR de la ronda. Las 3 secciones
de release notes de producto se redactaron sobre los release PRs (el
guard de contenido las exigió — funcionando como diseñado).

--- Quantum 1.7.2 (histórico) --- cierre de la 6ª ronda: un arco normal de subversiones (la
6ª auditoría CONFIRMÓ la certificación 1.7.1 sin P0/P1 nuevos) que cierra
su banda de P2/P3 y ejecuta de una vez la documentación de producto
pendiente desde la 4ª. La lección aplicada: la rama que nunca se ejecutó —
cada fix llegó con el test o la lane que lo habría cazado. **nucleus
v1.3.3:** NU6-1 — CRUD.Create descartaba en silencio toda PK asignada por
la aplicación (SQLite insertaba fila con PK NULL SIN error; UUIDs de
cliente imposibles): la PK no-cero viaja en el INSERT sin read-back ni
backfill, pineado rojo/verde contra SQLite, PG y MSSQL reales. NU6-2 —
ErrNoPrimaryKey explícito en las ops por id y ORDER BY sobre columna real.
NU6-3 — TOP 1 en createuser/changepassword, fail-fast del session store
SQL y el outbox en mssql/oracle (incluidos dos puentes que lo anulaban), y
compatibilidad acotada por subsistema con tabla honesta. NU6-4 — «not
null» estricto: db:"not null unique" ya no pierde el unique en silencio.
**quark v1.3.2:** QK6-2 — la adquisición de conexión del RLS nativo era
incancelable (pool saturado = goroutine colgado más allá del deadline):
db.Conn(ctx) + tx desacoplada, con pin de no-fuga del pool. QK6-3 — el
commit diferido fallido deja log a nivel Error y contador
(Client.DeferredCommitFailures); semántica de escritura documentada donde
el lector la ve. QK6-1 — segundo anillo de tests de motor en lanes
(MariaDB Otel/Stress, patas all-engines con skip visible, locks de Redis
contra Redis REAL por primera vez) e inventario con cero huérfanos sin
clasificar. **orbit v1.4.3 (+ agent/v0.5.3, server/v0.8.3,
quarkbridge/v0.3.3, quarkdatasource/v0.2.5):** OR6-1 — require_connection
se daba por bueno con token inválido (la sonda /healthz exenta de auth
cerraba Connected()): la señal es ahora el primer frame aceptado bajo
auth, E2E con binarios reales (token malo = boot FALLA). OR6-2 — WARN de
sospecha de auth tras 3 ciclos sin frame aceptado (el 401 que la carrera
de transporte se tragaba). QM6-1 — requires cross-repo alineados y regla
de DISCLOSURE en el manifest-guard §5: un require rancio no declarado en
declared_lags rompe el CI. **Docs (Fase 3, los tres productos):**
Deployment, Security, Upgrade guide, FAQ y release notes publicadas en el
sitio; la Configuration reference de nucleus se GENERA por script desde su
registry con gate de frescura en CI (el drift es imposible); sidebars
curadas estilo Django/Laravel; sitio íntegro en inglés (QADR-0007,
reversible); CLAUDE.md de los 4 repos sin fósiles y bajo guard. El corte
del root de orbit se forzó con el footer Release-As (sus commits eran
docs/ci): desviación documentada en el informe de cierre. Verificación del
set: manifest-guard completo (§1-§5), build de los 9 patrones, sitio
construido y linteado sobre lo SERVIDO sin exclusiones, nucleus new pina
v1.3.3, go install @v0.8.3 con caché virgen.

--- Quantum 1.7.1 (histórico) --- cierre de la 5ª ronda de auditoría, verificado por ejecución
real (Docker) y con la lección de la ronda instalada como forcing functions:
cada versión hardcodeada queda gestionada por release-please o vigilada por
un check de CI. **orbit v1.4.2 (+ server v0.8.2, agent v0.5.2,
quarkdatasource v0.2.4):** OR5-1 — server/v0.8.1 pinaba agent v0.5.0 (sin el
fix OR-2) y su propio test de regresión fallaba standalone; barrido completo
de pins internos + CI que ahora EJECUTA tests con GOWORK=off en los 6
módulos + check_internal_pins.sh (pin de hermano == último tag; probado en
negativo). OR5-2 — un token de agente rechazado era un fallo 100% silencioso
(la sonda /healthz «conectaba», el 401 del stream solo salía en Debug, el
backoff se reseteaba): WARN rate-limited en agente y server (con IP), el
backoff solo se resetea tras el primer frame aceptado, y el INFO «connected»
solo se emite con la aceptación real; E2E con binarios reales: intervalos
crecientes ~1.4s→10.6s y cero «connected» falsos. **nucleus v1.3.2:** NU5-1
— la web enseñaba una sintaxis de tags db: que el parser ignoraba en
silencio; página reescrita, db:"-" implementado (exclusión real del campo),
WARN de arranque ante directivas desconocidas y regla en bodycheck que
valida los tags de los snippets contra el parser real. NU5-2 — el camino
RETURNING/OUTPUT asumía PK entera y existente (PK UUID rompía el Create en
PG; sin PK, 42703): solo se emite con PK declarada y entera. NU5-4 — la
rama MSSQL jamás se había ejecutado, y al ejecutarla afloró que el listado
CRUD emitía LIMIT (inválido en T-SQL): paginación OFFSET…FETCH/TOP 1 y lane
MSSQL corriendo TODO TestCRUDLive_ contra SQL Server real. NU5-3 — el
scaffold pinaba v1.3.0: la constante la gestiona release-please y la vigila
CI (nucleus new demo pina ahora el tag recién cortado). NU5-5 — el evento
insert reporta las filas reales también en el camino RETURNING. **quark
v1.3.1:** QK5-1 — cadenas mixtas de set-ops divergían en silencio por motor
(precedencia de INTERSECT): ErrUnsupportedFeature. QK5-4 — seis tests de
integración vivían fuera de toda lane; al entrar en la matriz, el de RLS
nativo destapó un cuelgue de locks y una PÉRDIDA SILENCIOSA de escrituras
(INSERT…RETURNING bajo RLS nativo se rollbackeaba al cancelarse el ctx):
ciclo de vida de la tx desacoplado con WithoutCancel, regresión pineada
rojo/verde contra PG real. **Paraguas:** QM5-1 — el sitio publicado servía
por defecto snapshots viejos con jerga: lastVersion current con el tag real,
cola de snapshots curada (último patch por minor de 1.x, limpiados en sus
repos fuente) y linter post-build sobre el HTML SERVIDO, sin exclusiones.
QM5-3 — las docs de orbit decían v1.2.1 (real v1.4.1): coherencia de versión
con marcador + check en CI (orbit era el único repo sin él). Fase 4:
manifest-guard ampliado (§3 los 5 tags de módulo de orbit contra el pin —
disparó en producción durante la propia ronda al cortarse agent/v0.5.2 —,
§4 tabla del README == manifiesto), job go-install-tag con caché virgen, e
inventario de versiones hardcodeadas en los 4 repos con 3 rancios extra
cerrados. Verificación del set: manifest-guard completo, build de los 9
patrones del workspace, tests standalone por módulo, sitio construido y
linteado sobre lo servido; release-please cortó quark v1.3.1, nucleus
v1.3.2, orbit v1.4.2 + agent/v0.5.2 + server/v0.8.2 + quarkdatasource/v0.2.4.

--- Quantum 1.7.0 (histórico) --- cierre de la 4ª reauditoría, verificado por EJECUCIÓN real
con Docker (no por lectura de código): la matriz de motores que las cuatro
auditorías marcaron como «no verificable sin Docker» se corrió de verdad.
**orbit v1.4.1 (+ server v0.8.1, agent v0.5.1, proto v0.4.1):** **OR-1** —
server no compilaba standalone (`server/go.mod` pinaba proto v0.3.0 mientras
el código usaba `adminv1.GetSelfRequest`/`SelfInfo` de v0.4.0; el go.work lo
enmascaraba y `go install .../admin-server@server/v0.8.0` estaba roto).
Alineado el require a proto v0.4.0/agent v0.5.0; los seis módulos pasan
build+vet con GOWORK=off. **OR-2** — el `--agent-token` no viajaba en el
stream bidi (el interceptor era `UnaryInterceptorFunc`, que connect-go no
invoca en streaming → 401 en bucle, telemetría muerta fuera de loopback);
sustituido por un `connect.Interceptor` completo con WrapStreamingClient.
Test de regresión con agente real: rojo sin el fix, verde con él. **Orbit no
tenía CI de build ni test** (solo pages/release-please) — esa es la causa de
que OR-1/OR-2 llegaran a tag; añadido CI de cinco jobs (standalone GOWORK=off
por módulo — habría atrapado OR-1 —, tests, Data Studio contra PG+MySQL
reales, govulncheck, linter de docs). **nucleus v1.3.1:** **bug real de
producción que SQLite ocultaba** — `CRUD.Create` obtenía la PK con
`LastInsertId()`, que pgx/mssql no implementan, así que TODO Create en
Postgres devolvía id 0 y el flujo crear→usar-id operaba sobre 0. Afloró al
correr Data Studio de orbit contra un Postgres real. Corregido con
RETURNING (PG) / OUTPUT INSERTED (MSSQL); Oracle queda como laguna declarada.
Verificado contra PG 16 y MySQL 8 reales. También NU-1 (README decía
pkg/observability «experimental» cuando v1.3.0 lo hizo «stable»; check de
coherencia README↔inventory en CI) y NU-2 (W2 `sql_driver_instrumentation`
documentada). **quark v1.3.0:** matriz de 6 motores en verde por ejecución
(SQLite/PG/MySQL/MariaDB/MSSQL/Oracle) — MERGE upsert + back-fill de PK en
MSSQL, locks de migración (sp_getapplock/DBMS_LOCK/GET_LOCK), introspección,
RLS. Al ejercitar set-ops afloró que `INTERSECT ALL`/`EXCEPT ALL` eran código
inalcanzable (sin métodos públicos): expuestos `IntersectAll`/`ExceptAll`, y
el test cazó que MSSQL no las soporta (emitía SQL inválido en vez de
ErrUnsupportedFeature) y que el godoc negaba INTERSECT/EXCEPT en MariaDB
siendo falso. **Seguridad:** los seis módulos de orbit suben a go1.26.5 y
cierran GO-2026-5856 (fuga de ECH en crypto/tls, alcanzable desde los dials
TLS del agente y del relay Redis); govulncheck limpio en los tres repos.
**Docs de producto:** barrido de jerga interna (ADR/P0/SPEC.md/CLAUDE.md) en
los sitios de los tres repos + linter `check_docs_product_voice.sh` en CI que
lo impide reincidir. Verificación del set: los ocho patrones del workspace
compilan con el pin nuevo (go.work a 1.26.5); CI verde y mergeado en los tres
repos; release-please cortó quark v1.3.0, nucleus v1.3.1 y orbit v1.4.1 (+ los
cinco submódulos). Los tres pines EN TAG exacto.

--- Quantum 1.6.0 (histórico) --- orbit sube a v1.4.0 (+ server v0.8.0, proto v0.4.0): el
backlog de UI del plano fleet ejecutado al completo (orbit#70–#74, decisión
de Carlos «todas»). **#71** barra de filtros en las páginas de stream
(method/path-glob/status-class/sql-model/node) + knob de sampling (el proto
ya lo soportaba y #66 hizo real el sampler); estado debounced/persistido.
**#73** herramientas del audit log: filtro por actor/acción/nodo + rango
temporal, paginación y export CSV, todo client-side sobre el ring completo.
**#72** Data Studio expone lo que el backend ya sabe: multi-select +
BulkAction delete, selector de nodo (threading de node_id), choices→select,
editor de fecha (datetime-local↔RFC3339), FK→link al modelo referenciado.
**#70** (proto+server+UI, ADR aditivo): RPC `ControlService.GetSelf`
(identidad del operador + read_only + versión del server vía
debug.ReadBuildInfo) → el footer muestra «orbit <version> · <subject>
[(viewer)]» y Data Studio esconde las mutaciones en modo read-only. **#74**
(parcial): NodeDetail «Recent activity» ahora es un feed en vivo HTTP+SQL
por nodo (la correlación de node_id se arregló en #66; «Components»
eliminado por honestidad), búsqueda de modelos en el sidebar, y umbral de
sentencia lenta configurable; diferidos i18n, barrido completo de a11y de
tablas, y consolidar las tablas del panel in-process (#74 sigue abierta).
nucleus v1.3.0 y quark v1.2.2 continúan del set 1.5.0. Verificación: los
seis patrones del workspace compilan con el pin nuevo; go test verde en los
tres módulos de orbit; tsc + eslint --max-warnings 0 + vite build verdes;
GetSelf verificado end-to-end por TestServer_GetSelf (server real sobre el
cable). release-please cortó orbit v1.4.0 + server/v0.8.0 + proto/v0.4.0.

--- Quantum 1.5.0 (histórico) --- nucleus sube a v1.3.0: los dos compromisos con fecha del
gate v1.0 de nucleus, vencidos, resueltos (decisiones de Carlos). **W1
(nucleus#207/#208):** pkg/observability + pkg/observability/hooks promovidos
de experimental a stable y congelados — superficie pure-stdlib coherente,
frozen-but-not-firewalled; el freeze fija solo las formas de los símbolos
(los internos pooled/ring-buffer siguen optimizables). **W2
(nucleus#206/#210, ADR-021):** instrumentación SQL a nivel de driver opt-in
(`sql_driver_instrumentation`): un wrapper de database/sql/driver lleva al
feed en vivo las sentencias directas db.QueryContext/ExecContext que esquivan
model.CRUD (outbox, session stores SQL, migraciones, SQL crudo),
de-duplicadas contra CRUD por un marcador de contexto; off por defecto → coste
cero en el hot path. Los dos observers coexisten porque el wrapper no conoce
el ModelName. El gate v1.0 de nucleus queda con W1 y W2 cerrados. quark
v1.2.2 y orbit v1.3.0 continúan del set 1.4.0. Verificación: los seis
patrones del workspace compilan con el pin nuevo; CI de nucleus verde en
ambos PRs (freeze rebaselinado, firewall, matriz de 5 motores incl. el test
live del wrapper contra postgres/mysql, compat, smoke); release-please cortó
v1.3.0 con ambos feats en el CHANGELOG.

--- Quantum 1.4.0 (histórico) --- orbit sube a v1.3.0 (+ server v0.7.0, agent
v0.5.0): la ejecución del backlog de la auditoría de orbit
(orbit#66/#67/#68/#69). El reconocimiento del brief: el plano fleet es REAL de
punta a punta; los problemas eran dos botones fake, un audit roto bajo auth,
dos bugs
de telemetría fleet y UX incipiente. **Plano fleet (server v0.7.0 +
agent v0.5.0, orbit#66)**: el filtro agregado se reanuda al reconectar
un agente (State.OnAgentSubMode estaba sin cablear → pérdida silenciosa
de telemetría); los eventos viajan con el NodeID registrado del agente
(antes el del bus in-process → tarjetas por nodo a 0 con tráfico real);
el sampling_rate por suscripción SE APLICA en el fanout (residual
rate/aggRate) y el Subscribe agregado propaga el máx por tipo;
GetSnapshot deja de ser stub (providers GO_RUNTIME/REGISTERED_MODELS);
operador read-only (X-Auth-Role: viewer / --ui-read-only → mutaciones
de Data Studio PermissionDenied); CSP+nosniff+X-Frame-Options; lockout
de credenciales por IP; IdleTimeout h2c; expiración de agentes
inactivos (janitor MarkStale + revive en Touch). **Panel in-process
(orbit v1.3.0, orbit#67)**: el auditMiddleware colgaba solo del branch
SPA GET-only → bajo auth las escrituras de Data Studio no se auditaban;
redacción del OldValue; lockout de login; gate CSRF de Content-Type;
headers de seguridad; DELETE /api/sessions/{token} real (el botón
«terminate» de la SPA fallaba en cada click) y export alineado a
/api/exports (la SPA llamaba rutas inexistentes → 404). **UX de la SPA
fleet (orbit#68)**: toasts aria-live, feedback de error en Data Studio,
pausa con buffer, pantalla de no-autorizado, a11y del modal, contraste
WCAG del token t26. **Docs (orbit#69)**: versiones, «esqueleto» falso
corregido, aviso de superusuario + knobs read-only + guía OIDC en el
sitio, identidad de nodo, rutas de la SPA. Diferidos → issues
orbit#70–#74. Nucleus v1.2.0 y quark v1.2.2 continúan del set anterior
sin cambios; proto queda v0.3.0 (el contrato no cambió). Verificación:
los seis patrones del workspace compilan con el pin nuevo;
`go install …/server/cmd/admin-server@v0.7.0` → --version v0.7.0
(buildinfo end-to-end, con los flags nuevos); `go test ./...` verde en
raíz/agent/server sobre el main fusionado; govulncheck 0/8 (12ª sesión,
mismo día).
