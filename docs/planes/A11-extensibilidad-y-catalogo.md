# A11 — Extensibilidad y catálogo

> Lee antes [`README.md`](README.md): el contrato de sesión, qué fichero manda
> para cada pregunta y qué no decide una sesión sola.

> **El troceado salió de la MEDICIÓN, no del enunciado.** `S0` midió los
> cuatro repos el 2026-10-04 con un banco por producto —tres bancos Go con
> veredicto registrado y uno del sitio en el paraguas— y reescribió el
> arco. Es la séptima vez que la medición corrige el plan: el panel ya había
> entregado en A6 casi todo lo que el plan le pedía, y el contrato de driver
> de quark tenía un problema que el plan no sabía nombrar (el esquema decide
> por el nombre del dialecto, no por la interfaz).

**Qué entrega.** Que una aplicación de la suite se extienda sin bifurcarla: un
catálogo de módulos oficiales que `nucleus add` instala fijados a la versión
certificada y cableados, con los cuatro módulos que el catálogo nombra y no
existían; un panel que la aplicación amplía con sus acciones (con formulario,
por registro, con descarga o redirección), sus widgets, sus páginas, su
código de cliente y su tema; un contrato de plugin de quark publicado y
congelado, con un kit de conformidad que un driver de fuera puede pasar sin
importar la raíz, e integraciones probadas; y un sitio que explica por qué
elegir la suite con cifras que un guard comprueba, con tutoriales y guías de
migración que se ejecutan en CI.

**Precondición del arco**: A10 cerrado (`nucleustest.CheckModule` es el test
de la plantilla de módulo comunitario).

**Decisiones de Carlos (2026-10-04)**:

1. **Ejemplos como fixtures probados.** El plugin de ejemplo de nucleus y las
   integraciones de quark (chi, Echo, Gin, gRPC, Nucleus) viven como código
   de test que el CI compila y ejecuta; no se reabre `examples/` (la decisión
   del 2026-09-12 se mantiene).
2. **Los cuatro módulos que faltan se construyen**: SAML, redis-cache, Stripe
   y Sentry.
3. **El catálogo va embebido en el CLI y fijado a la versión de la
   release.** Sin índice remoto ni claves: el CLI vive en el módulo raíz
   (NU-8), y cada dependencia que añada la hereda toda aplicación.

**Gate del arco**: los tres bancos de producto y el del sitio sin ausentes sin
razón escrita; `nucleus add <cualquier entrada del catálogo>` sobre un
proyecto recién generado compila, arranca y deja la capacidad cableada, en
CI, con la versión de la release; el contrato de plugin de quark congelado
con firmas y su kit pasado por un driver de fuera; los tres tutoriales y las
dos guías de migración ejecutados en CI; y un guard que ata cada cifra de
«Why Quantum» a su fuente. Un guard de postura por producto, clonado de los
de A6–A9.

## Los bancos

| Banco | Dónde | Controles | Línea de base (2026-10-04) | PR de `S0` |
|---|---|---|---|---|
| catálogo y plugins | `nucleus/internal/catalogbench` | 38 (11 del comando, 15 entradas, 12 de plugins) | **6 present · 15 partial · 17 absent** (catalog 1/6/4, entries 3/8/4, plugins 2/1/9) | nucleus#587 |
| familia `extension` del panel | `orbit/internal/adminbench` | 13 (+2 de navegador) | **1 present · 3 partial · 9 absent**; el banco pasa de 59/59 a 60/72 y la mitad de navegador de 6/6 a 6/8 | orbit#531 |
| extensión de quark | `quark/internal/extbench` | 22 | **5 present · 7 partial · 10 absent** (contract 4/3/1, drivers 1/3/4, integrations 0/1/5) | quark#422 |
| sitio de la suite | `tests/sitebench/sitebench.sh` (paraguas) | 12 | **0 present · 1 partial · 11 absent** | este PR |

Los bancos de producto siguen el patrón de A4–A10: cada control con su
sonda, el test asserta el veredicto REGISTRADO y la página de cada producto
publica la tabla generada. El del sitio es el mismo contrato en bash, porque
lo que mide son páginas, sidebars y lanes del paraguas.

## Lo que la medición encontró y el plan no sabía

1. **El panel ya hizo casi todo en A6.** `ModelAction`, `Widgets`, `Pages` y
   `Branding` existen (adminbench 59/59). Lo que falta es lo que el plan no
   distinguía: acciones con formulario, sobre un registro y con descarga o
   redirección; widgets de serie y más de un dashboard; código de cliente de
   la aplicación bajo la CSP; renderers de campo; tema por configuración.
   Y cuatro defectos de lo que A6 dio por hecho: `field_widgets` es la única
   declaración que no se valida al arrancar; el branding acepta un logo
   `https://` que la CSP (`img-src 'self' data:`) bloquea; el login no dibuja
   el logo aunque la página de A6 decía que sí; y cinco claves faltan en la
   referencia de configuración.
2. **En quark, el esquema decide por el NOMBRE del dialecto, no por la
   interfaz.** Con el dialecto de SQLite tal cual pero llamado `extlite`, las
   once consultas coinciden y los ocho pasos de esquema divergen: `Migrate`
   escribe una PK que queda NULL y `ApplyPlan` rechaza hasta un ADD COLUMN
   porque decide el DDL transaccional por nombre sin llamar a
   `SupportsTransactionalDDL()`. Una plantilla de driver no sirve mientras
   eso siga así. Además `RegisterDialect` tiene una carrera con
   `DetectDialect`, `drivertest` no acepta un dialecto, el driver de postgres
   no corre el kit y `internal/enginesuite` no se puede importar desde fuera.
3. **El middleware y el observer de quark no ven todo.** De 23 sentencias que
   llegaron al motor, el middleware vio 10 y el observer 11: ni el DDL, ni la
   introspección, ni los savepoints, y `CreateBatch`/`Exec`/`RawQuery` se
   saltan uno u otro. otel y `orbit/quarkbridge` heredan esos huecos.
4. **Un panic con una entrada normal: `Where(col, "IN", []string{...})`**
   (QK-33, P2, abierto aquí y reproducido sobre SQLite). Y buscándolo, algo
   peor: **las escrituras con condiciones ignoraban `WhereNot`** —`WhereNot(…).DeleteBy()`
   borraba las filas que excluía— (QK-39, P0, arreglado en quark v1.15.2 dentro
   del set que cierra A10), y dos huecos más del mismo `Where` (QK-40, QK-41)
   que van a `Q11`.
5. **El sitio no tiene nada de lo que el arco pide**, y su página de entrada
   dice que la suite no compite en «breadth of plugins»: el catálogo la pone
   en duda y nada la reconcilia.

6. **En nucleus, la mitad de lo que el catálogo instala no hace nada en el
   starter que el arco nombra.** El starter `api` arranca con
   `WithoutDefaults()` y nunca construye storage: `nucleus add s3|gcs|azure`
   compila, arranca y `storage.provider` se ignora sin aviso (NU-99). Las
   cinco entradas del core no tienen nada que `add` conozca: funcionan a mano
   (import, `Mount`, configuración), y `accounts` exige además un `*sql.DB` y
   un mailer propios. Y `add` instala `@latest`, `aws-sm` no sale en la
   ayuda, y `add` y `new --with` son dos catálogos que no se aceptan entre sí.
7. **Cada módulo de driver enlaza los cinco motores.** Es NU-8 medido en la
   aplicación: `internal/dbclassify/link.go` importa en blanco todos los
   drivers y todos los drivers importan `dbclassify`, así que el starter (sólo
   SQLite, 66 MB) lleva pgx, mysql, mssql y go-ora, y una URL de postgres
   conecta en vez de pedir `nucleus add postgres`. **NU-8 pasa de A12 a este
   arco (`N3`)**: el banco del catálogo lo mide (`CAT-11`) y A12 hereda el
   binario ya adelgazado.
8. **Las pistas de instalación no siempre llegan.** La validación estricta
   rechaza `auth.ldap.*` como clave desconocida antes de que la cadena de auth
   diga «falta `providers/ldap`» (NU-100); sólo otlp y prometheus nombran el
   `nucleus add` que las arregla (2 de 8).
9. **El lado plugin es el más corto**: `nucleus plugin test --execute` no
   manda ningún envelope, así que un plugin roto pasa como «ok» (NU-101); los
   plugins externos corren sin allowlist y las claves `plugins.*` que la
   referencia propone se rechazan (NU-102); el bridge `plugin` del outbox
   arranca con un WARN y se descarta; y `PLUGIN_SDK.md` dice que no hay
   plugin de ejemplo. Lo que sí funciona de punta a punta: `mail.send` hacia
   un plugin externo y el despacho de `nucleus-<name>`.
10. **Visto de paso**: con `jobs_provider: sql`, parar la aplicación tarda
    unos 9 s y el scheduler sigue disparando contra la base cerrada (NU-103,
    a A12, que mide la cola SQL); y `nucleus new` recomienda
    `examples/mvc_api`, que no existe desde el 2026-09-12 (NU-104).
11. **Lo que encontró el primer tutorial ejecutado (W2, no `S0`).** Escribir
    el SaaS multi-tenant contra el set pinado midió lo que ningún banco
    miraba: **`Find(id)` sobre un `TenantRouter` con `RowLevelSecurityClient`
    lee la fila de otro tenant** (QK-42, P0) —`Find` sustituye el `Where` por
    la PK y el predicado del tenant viaja en el `Where`—, y `Update(&row)` y
    `Delete(&row)` escriben en ella (la mitad de tenant de QK-40, medida aquí
    sobre el router). Y en nucleus, **`/healthz` dispara la política de
    tenant del storage** en toda aplicación multi-tenant (NU-111): WARN en el
    primer `/healthz`, 503 con `require_tenant_storage`. El tutorial usa
    `Where("id","=",id).First()` y avisa de `Find`; la lane exige ese aviso y
    tolera esa línea WARN mientras cada hallazgo siga abierto en el registro.

## El troceado

Cuatro carriles que tocan repos distintos y pueden ir en paralelo, y un
cierre. Dentro de cada carril, el orden de la tabla.

### Catálogo y plugins (nucleus)

| Sesión | Qué entrega | Precondición | Criterio de hecho |
|---|---|---|---|
| `N1` | La tabla del catálogo (ADR-034): una sola para `add`, `new --with`, la ayuda y las pistas del runtime; versiones embebidas que release-please mantiene y un test contra el manifiesto; sugerencia del nombre más cercano; la clave que selecciona la entrada; NU-104 | `S0` | `CAT-02`, `CAT-03`, `CAT-07`…`CAT-10` present; `CAT-04` en lo que es de nucleus |
| `N2` | Que el starter respete las entradas: storage construido cuando se configura o negativa en voz alta (NU-99), y negativas de configuración que nombran el `nucleus add` (NU-100) | `S0` | `EN-10`…`EN-12` present; `CAT-01` 7 de 8 |
| `N3` | NU-8 en la aplicación: los imports en blanco de `dbclassify` a un paquete que sólo enlazan la CLI y los tests; cada driver registra su clasificador | `S0` | `CAT-11` present y `CAT-01` completo; el starter sin los motores que no pidió |
| `N4` | Entradas que cablean: la receta (import, `Mount` con el editor de `generate module --mount`, bloque de configuración, rutas) y las tres del core sin requisitos (oidc con sus rutas federadas, apikeys, sql-queue) | `N1` | `CAT-05`, `EN-01`, `EN-03`, `EN-05` present |
| `N5` | accounts y websockets: el servicio de cuentas construido desde el runtime (base y mailer) y un hub de realtime en el runtime | `N4` | `EN-04`, `EN-07` present |
| `N6` | redis-cache: backend Redis de `pkg/cache` y su cableado por configuración; core o módulo según el grafo (go-redis ya está en el del core) | `N1` | `EN-06` present |
| `N7` | sentry: módulo que registra un interceptor de errores | `N1` | `EN-09` present |
| `N8` | saml: módulo sobre el registro federado, con revisión de seguridad propia | `N4` | `EN-02` present |
| `N9` | stripe: ADR del seam de facturación y el módulo | `N4` | `EN-08` present |
| `N10` | El lado plugin: plugin de ejemplo como fixture probado, helper `plugins.Serve`, `plugin test --execute` con envelope real (NU-101), `PLUGIN_SDK.md` apuntando al ejemplo, comandos externos en la ayuda, allowlist opcional (NU-102; denegar por defecto espera al major, QADR-0010) | `S0` | `EX-01`, `EX-08`…`EX-12` present |
| `N11` | Puentes, ejemplo y plantilla: bridge `plugin` del outbox para `queue.publish` y `webhook.deliver`, ejemplo in-process probado, `nucleus new --template module` con su test `CheckModule` | `N10` | `EX-03`…`EX-06` present; banco 38 de 38 |

Cuando una sesión enseña a `nucleus add` un nombre del core, la sonda de esa
entrada se vuelve roja hasta que la misma sesión le da su comprobación de
cableado (lo dice la página del banco).

### Panel (orbit)

| Sesión | Qué entrega | Precondición | Criterio de hecho |
|---|---|---|---|
| `O1` | Higiene de branding y configuración: `field_widgets` validado al arrancar, los orígenes del branding en la CSP, el logo en el login, las cinco claves en la referencia | `S0` | `EXT-08`, `EXT-11`, `EXT-12` y `UIX-07` present (63/72; navegador 7/8) |
| `O2` | Tema por configuración (dark/light/system leído antes de React sin pisar el conmutador del operador) y paleta validada por tema | `O1` | `EXT-09`, `EXT-10` present, con un UIX de primer frame |
| `O3` | Formularios en las acciones: `ModelAction.Fields`, entrada validada en el servidor (4xx que nombra el campo) | `S0` | `EXT-01` present, con su UIX |
| `O4` | Colocación y resultado de las acciones: en la rejilla y en el registro; redirección dentro del panel y descarga confinada | `O3` | `EXT-02`, `EXT-03`, `UIX-08` present |
| `O5` | Widgets de serie y más de un dashboard bajo RBAC, dentro del presupuesto del bundle | `S0` | `EXT-04`, `EXT-05` present; `EXT-13` sigue present |
| `O6` | Extensión de cliente: scripts de la aplicación servidos bajo el prefijo (sin aflojar `script-src 'self'`) y un registro mínimo de renderers de campo | `O1` | `EXT-06`, `EXT-07` present |

### Quark

| Sesión | Qué entrega | Precondición | Criterio de hecho |
|---|---|---|---|
| `Q1` | El registro de dialectos con cerrojo, QK-33 arreglado (cualquier slice en `IN`), y un ADR sucesor de 0023 que decide cómo sacar el contrato del dialecto a un paquete hoja | `S0` | `DRV-01` present; QK-33 hecho; ADR aceptado |
| `Q2` | El camino de esquema pregunta al dialecto: tipos, PK autoincremental, IF NOT EXISTS por interfaces opcionales; `ApplyPlan` usa `SupportsTransactionalDDL()` (probablemente dos sesiones) | `Q1` | `DRV-04` present; matriz de seis motores verde |
| `Q3` | El contrato del dialecto en el paquete hoja | `Q1`, `Q2` | `DRV-02` present |
| `Q4` | Kit de dialecto en `drivertest` contra un `*sql.DB` vivo y una suite de motor pública; postgres corre el kit | `Q2` | `DRV-05`, `DRV-06`, `DRV-07` present |
| `Q5` | Plantilla de driver (módulo fixture con su go.mod, `GOWORK=off`) y la guía «Writing a driver» | `Q4` | `DRV-08` present |
| `Q6` | La página del contrato con la estabilidad de los 43 tipos extensibles, la superficie congelada con firmas, e interfaces exportadas para `TableName`/`Validate`/`SQLState` (aditivo) | `S0` | `CON-01`, `CON-02`, `CON-07` present |
| `Q7` | Observación completa: DDL, introspección, savepoints y raw pasan por middleware y observer; `CreateBatch` llega al observer | `S0` | `CON-04` present; otel y quarkbridge verdes |
| `Q8` | Fixtures probados de chi, Echo y Gin; la guía de frameworks reescrita sobre ellos | `S0` | `INT-01`…`INT-03` present |
| `Q9` | Fixtures de gRPC y de Nucleus | `Q8` | `INT-04`, `INT-05` present |
| `Q10` | `quark init --with chi\|echo\|gin\|grpc`, su salida compilada contra los fixtures (la sonda debe COMPILAR la salida, no contar módulos que requieren el framework) | `Q8`, `Q9` | `INT-06` present |
| `Q11` | Lo que ignora el `Where`: las escrituras por clave (`Update`, `UpdateBatch`, `Delete`, `HardDelete`) aplican el del llamador además de la PK (QK-40), `Find` también (QK-42: sobre un `TenantRouter` lee otro tenant), y el borrado lógico entra en los grupos `Or` (QK-41) | QK-39 (quark#428) | QK-40, QK-41 y QK-42 hechos; `RLS-03` del banco de A8 re-medido y retitulado; tras el re-pin, el tutorial multi-tenant vuelve a `Find` sin la nota (la lane de tutoriales lo pide en cuanto QK-42 se marca hecho) |
| `Q12` | Los upserts y las actualizaciones por mapa dentro del tenant (QK-43, QK-44), encontrados por `Q11` | `Q11` | QK-43 y QK-44 hechos en los seis motores |

### Sitio (paraguas)

| Sesión | Qué entrega | Precondición | Criterio de hecho |
|---|---|---|---|
| `W1` | «Why Quantum»: comparación con Gin+GORM, Echo, Django, Rails, Laravel y Spring, con cada cifra atada a su fuente por un guard; la frase de «breadth of plugins» reconciliada | catálogo `N1` | `ST-01`, `ST-02`, `ST-03`, `ST-12` present |
| `W2` | Los tres tutoriales (SaaS multi-tenant, API-only, monolito MVC) ejecutados en una lane, con el parser de fences del quickstart | `S0` | `ST-04`…`ST-06` present |
| `W3` | Las guías de migración desde Gin+GORM y desde Django, con sus fragmentos ejecutados | `W2` | `ST-07`, `ST-08` present |
| `W4` | Referencia API generada de las superficies congeladas (con comprobación de deriva), el catálogo en el sitio generado de la tabla del CLI, y un post por set | catálogo `N1` | `ST-09`, `ST-10`, `ST-11` present |

### Cierre

| Sesión | Qué entrega | Precondición | Criterio de hecho |
|---|---|---|---|
| `S-fin` | Guards de postura (catálogo, extensión de quark, sitio; el de admin sube su suelo de 59 a 72), sets, y A11 cerrado en el registro | todas | guards registrados con fixture; set certificado |

## Registro de sesiones

| Sesión | Estado | PR | Qué midió o cambió del plan |
|---|---|---|---|
| S0 | **hecha** 2026-10-04 | nucleus#587, orbit#531, quark#422, este PR | los cuatro bancos y este troceado; QK-33 abierto |
| N1 | **hecha** 2026-10-05 | nucleus#590 | una tabla (`internal/knownproviders/catalog.go`) para `add`, `new --with`, la ayuda, la referencia y las negativas; `modules.json` embebido que release-please reescribe (ruta con `/` inicial: sin ella apunta dentro del paquete y no falla nada); quark y orbit siguen sin fijar (`CAT-04`: el set se certifica después del tag de nucleus); ADR-034; banco 6→12 |
| N2 | **hecha** 2026-10-05 | nucleus#589 | `WithStorage()` para apps `WithoutDefaults()`; sin ella el bloque declarado se IGNORA con una línea ERROR (negarse a arrancar sería una ruptura: DEP-2026-013 lo programa para v2.0.0); negativas que nombran `nucleus add`; banco 15/38 con N1 |
| N3 | **hecha** 2026-10-05 | nucleus#593 | cada driver clasifica su motor; `dbclassify` sólo stdlib (con los nombres antiguos, para que los drivers ya publicados compilen contra la raíz nueva); starter api 137→108 módulos, 49,6→29,0 MB; banco **17/38** con N1+N2 (`CAT-01` 8/8, `CAT-11`) |
| N4 | **hecha** 2026-10-05 | nucleus#595 | recetas en el catálogo (ADR-035): `nucleus add` inserta la opción o el `Mount` en `main.go` y escribe el bloque de configuración; `WithAPIKeys()` y `FederatedSignIn()`; oidc, apikeys y sql-queue cableados con su comprobación (oidc contra un IdP simulado); accounts y websockets a `N5`; NU-112 (el RBAC no ve al dueño de una clave); banco **21/38** |
| N5 | **hecha** 2026-10-05 | nucleus#598 | `accounts.FromRuntime()` (base por defecto, mailer y sesiones de la app; sin mailer que entregue no arranca; `mail_driver: log` sólo en desarrollo) y `WithRealtime()` (WebSocket y SSE en `/realtime/{topic}`); NU-112: el sujeto del RBAC es el dueño de la API key y la cuenta de la sesión (ADR-036); banco 35/38 |
| N6 | **hecha** 2026-10-05 | nucleus#601 | caché de framework (no existía): `cache.provider` memory/sql/redis, `App.Cache`, `/healthz`; el backend Redis en el core (`pkg/cache/rediscache`) porque go-redis ya se enlaza en todo hello-world; banco 33/38 |
| N7 | **hecha** 2026-10-05 | nucleus#597 | `providers/errors-sentry`: errores 500 y panics con contexto de la petición y redacción; el core ganó `interceptor.ErrorReporter` (aditivo); primera entrada de tipo módulo con receta; NU-113 (`Mux.With`); banco **32/38** |
| N8 | **hecha** 2026-10-05 | nucleus#602 | `providers/auth-saml` sobre `crewjam/saml` v0.5.1: SP iniciado por la app, aserciones firmadas exigidas, audiencia, tiempo, replay y seis formas de signature wrapping probadas; fuera: SLO, aserciones cifradas, metadatos firmados, estado entre réplicas; banco 36/38 |
| N9 | **hecha** 2026-10-06 | nucleus#603, nucleus#604 | `pkg/billing` (seam neutral, ADR-037) y `providers/billing-stripe` con webhooks verificados y deduplicados en el outbox; claves sólo como referencias; banco **37/38** |
| N10 | **hecha** 2026-10-05 | nucleus#596 | `plugins.Serve`, plugin de ejemplo probado (`internal/fixtures/plugins`), `plugin test --execute` real (NU-101), comandos externos en la ayuda, allowlist opcional (NU-102, DEP-2026-014); no existe un «plugins dir»: sólo PATH; banco 27/38 |
| N11 | **hecha** 2026-10-05 | nucleus#599 | bridge `plugin` del outbox para `queue.publish` y `webhook.deliver`, `outbox.Permanent` (el outbox no distinguía fallos definitivos), ejemplo in-process y `nucleus new --template module` con `CheckModule`; banco 31/38 |
| O1 | **hecha** 2026-10-05 | orbit#532 | 63/72, navegador 7/8; el logo del propio banco daba 404 y `EXT-08` contaba cualquier fallo de arranque |
| O2 | **hecha** 2026-10-05 | orbit#534 | 65/72; tema aplicado antes del primer frame con un script clásico de `'self'`; su `UIX-09` se renumera a `UIX-10` al integrar |
| O3 | **hecha** 2026-10-05 | orbit#533 | 61/72; sin `delete` no había selección en la rejilla; OR-62 (contraste de los errores) |
| O4 | **hecha** 2026-10-05 | orbit#535 | 63/72 en su rama; ruta `/actions/{action}/{id}` (la otra chocaba con el catch-all); Data Studio con estado en la URL |
| O5 | **hecha** 2026-10-05 | orbit#538 | 67/72, navegador 9/10; un operador sólo con permiso de dashboard no podía entrar; los assets relativos rompían el deep-link |
| O6 | **hecha** 2026-10-05 | orbit#540 | código de cliente de la aplicación bajo la CSP (con SRI, sin aflojar `script-src`) y renderers de campo (`window.orbit` v1); banco **72/72**, navegador 12/12; OR-63 (iconos de AG Grid bloqueados por la CSP) |
| Q1 | **hecha** 2026-10-05 | quark#425 | registro con `RWMutex`, QK-33 (`listOperand`), ADR-0026 aceptado; al buscar QK-33 apareció **QK-39 (P0)**, arreglado en quark#428 dentro de 1.39.0 |
| Q2 | **hecha** 2026-10-05 | quark#432 → quark#433 | seis interfaces opcionales nuevas en `quarkdriver`; Oracle declaraba DDL transaccional y no lo tiene; `DRV-04` present (7/22) (fusionados como `feat(schema)`: añaden API) |
| Q3 | **hecha** 2026-10-05 | quark#436 | el contrato del dialecto en `quarkdriver` con alias en `quark` (ADR-0026); `DRV-02` present con una fixture que sólo importa `quarkdriver`; el generador de superficie registra `alias_of`; banco 13/22 |
| Q4 | **hecha** 2026-10-05 | quark#441 | `drivertest.VerifyDialect` contra el motor del driver y `quarkdriver/drivertest/suite` importable; los cinco drivers lo corren (postgres por primera vez); arregló `DROP CHECK` de MariaDB y `HOLDLOCK`+`READPAST` de SQL Server; banco 17/22 |
| Q5 | **hecha** 2026-10-06 | quark#446 | plantilla de driver en `internal/drivertemplate` (módulo propio, sólo `quarkdriver`) que pasa el kit, y la guía «Writing a driver» sostenida bloque a bloque; banco 21/22 |
| Q6 | **hecha** 2026-10-05 | quark#443 | página de contrato con los 52 tipos implementables y su estabilidad (la política queda como PROPUESTA pendiente de Carlos), firmas en la superficie congelada, `TableNamer`/`Validator`/`SQLStater`; banco 20/22 |
| Q7 | en curso | quark#447 | el middleware y el observer ven las 27 sentencias del motor (antes 10 y 11) |
| Q8 | **hecha** 2026-10-05 | quark#426 | `internal/integrations` (módulo propio no publicado); la guía de frameworks comprobada línea a línea contra las fixtures; banco 8/22 |
| Q9 | **hecha** 2026-10-05 | quark#427 | gRPC y Nucleus; NU-107 (`BindJSON` con arrays, ya arreglado en nucleus#591); banco 10/22 |
| Q10 | **hecha** 2026-10-05 | quark#438 | `quark init --with chi\|echo\|gin\|grpc\|nucleus`; el CLI embebe copias byte a byte de las fixtures y CI compila su salida; banco 14/22 |
| Q11 | **hecha** 2026-10-05 | quark#435 | QK-42 (P0), QK-40, QK-41: `Find` dentro del tenant, escrituras por clave con tenant y `Where`, ámbitos con paréntesis; `RLS-03` present (enterprise 48/69); encontró QK-43…QK-46 |
| Q12 | **hecha** 2026-10-05 | quark#437 | QK-43 (P0): el upsert no escribe en otro tenant (guarda por motor); QK-44: `UpdateMap` no mueve filas de tenant |
| W1 | **hecha** 2026-10-05 | quantum#257 | «Why Quantum» (`website/docs/why-quantum.md`, en el sidebar tras «What is Quantum?»): la suite frente a Gin+GORM, Echo, Django, Rails, Laravel y Spring Boot en diez ejes, con un «Where the others are ahead» en cada sección y una de ecosistema y madurez donde todos van por delante, sin matices. Quince cifras en la página (seis titulares de banco y una familia, dos filas de la tabla de ns/op de quark, módulos y MB del starter, los comandos del quickstart, los módulos de `nucleus add` por clase) y una en `what-is-quantum.md`, cada una citada en su párrafo. Guard `umbrella-why-quantum` (el 55º) con fixture de cuatro roturas: compara cada cifra con su fuente al pin, prohíbe cualquier otro número en la prosa —también en palabras— y ata la frase que sustituyó a «not breadth of plugins» a `versions.yaml` y a la tabla de `nucleus add` al pin. **Al re-pinar nucleus con el catálogo de N1/N4 pondrá rojo el PR de set**: esa tabla cablea capacidades del core (3 en el main de hoy) y las dos frases cuentan sólo módulos; se reescriben ahí. `ST-02` y `ST-12` endurecidas: exigen el guard registrado y en verde, así que una cifra cambiada las tumba (verificado por mutación). Banco del sitio 3→**7/12** |
| W2 | **hecha** 2026-10-05 | quantum#255 | tres tutoriales en `website/docs/` (SaaS multi-tenant con las tres piezas, API-only con documento, `--check` y cliente TypeScript ejecutado con node, monolito MVC con formulario, CSRF, sesión y flash) y la lane `tutorials-smoke` que los ejecuta paso a paso: `qs_steps` en el parser del quickstart (comandos, ficheros por `title=` y salidas pegadas a su comando, comparadas), sondas de lo que la página sólo cuenta y 0 WARN; ~8 s, ~8 s y ~2,5 s en local (presupuesto 60 s por tutorial). Banco del sitio 0→**3/12**; la sonda de tutorial ya no se conforma con un script que lo nombre: tiene que llamarlo un workflow. Encontró QK-42 (P0) y NU-111 (punto 11) |
| W3 | **hecha** 2026-10-05 | quantum#260 | dos guías en `website/docs/` (categoría «Migration guides» del sidebar, enlazadas desde «Why Quantum»): `coming-from-gin-gorm.md` y `coming-from-django.md`, cada una con su mapa de conceptos por área y una app portada —bookmarks sobre `--template api` (middleware de token, borrado suave, búsqueda) y polls sobre `mvc` con Orbit (dos modelos con relación, vistas JSON, admin con inline)— que acaba en los mismos curl que hacía el original. El código de origen va en fences sin título, que la lane no ejecuta; el de Gin+GORM se compiló y se llamó a mano con esos curl: mismos códigos y cuerpos de éxito, y cambian los cuerpos de error y el `%` de la búsqueda (la página lo dice). La lane `tutorials-smoke` las ejecuta con las mismas reglas (5,2 s y 8,0 s en local; las cinco páginas en 33 s), con sondas de lo que sólo cuentan (borrado suave en la base, `?q=%`, Data Studio con Choice inline, y la ausencia de FOREIGN KEY que la guía de Django declara: si Quark empieza a crearla, la lane pide corregir la página); y ahora traduce el `fichero.go:N` de un error de compilación o de un test rojo a la `página:línea` de su fence, y el FAIL de un comando lleva su línea. Huecos escritos en «What has no equivalent yet», ninguno es un defecto: la relación de Quark no crea FOREIGN KEY ni borra en cascada, no hay desvincular many-to-many, `DeleteBy` siempre es duro, no hay orden por defecto (y `Preload` no ordena), el middleware de Gin no tiene adaptador, ni cuerpos YAML/TOML/ProtoBuf/MsgPack, ni `ModelAdmin`, `ModelForm`, lenguaje de plantillas de Django o `manage.py shell`. Banco del sitio 7→**9/12**; por mutación, una salida cambiada, un fichero que no compila y un test rojo tumban la lane en su `página:línea`, quitar la guía de la lane deja `ST-07` en partial y retitularla deja `ST-08` en absent |
| W4 | **hecha** 2026-10-06 | quantum#266 | tres familias de páginas que nadie escribe a mano: las genera `scripts/lib/site-pages.py` del árbol al pin y `bump-set` lo corre. **API** (`website/docs/reference/api-{nucleus,quark,orbit}.md`, categoría «Reference» del sidebar): de los ficheros con los que el CI de cada producto compara su código —nucleus y orbit `contracts/baseline/api_exported_symbols.txt` (+ `extension_surface.txt` de nucleus), quark `acceptance/apisurface.json`—, por paquete con tipos, miembros, enlace a pkg.go.dev a la versión del set y firmas/alias cuando el pin los trae (quark v1.16.0 trae `alias_of` y todavía no `sig`; probado contra el de `main`): 2 380, 895 y 174 símbolos. **Catálogo** (`reference/catalog.md`): la tabla que lee el CLI, parseada como datos (literales de los tipos con `Name` y `Module`, constantes resueltas, en estricto: lo que no sabe evaluar falla con fichero y línea). **El nucleus del pin (v1.31.0) NO trae la tabla de `N1`**: trae los mapas por subsistema y la tabla de `new --with`, así que la página publica 16 entradas (12 módulos y 4 productos de la suite) sin clave de configuración ni cableado, que esa tabla no registra; el lector entiende ya la tabla de `N1`/`N4` (probado contra el `main` de nucleus: 25 entradas con recetas) y la página las ganará sola en el re-pin. **Posts**: blog de Docusaurus en «Releases» (`/releases`, con RSS y Atom), uno por set desde el primer tag (1.0.0…1.40.0, 49): lo que fija, qué se movió desde el anterior y cuánto, y los enlaces a las notas de cada producto; la narrativa del set (`notes:`, CHANGELOG) está en español y el sitio en inglés, así que el post no la traduce: enlaza el manifiesto del tag y, desde 1.30.0, su release firmada (v1.3.0 y v1.23.0 no tienen release en GitHub). Guard `umbrella-generated-pages` (el 57º) con fixture de tres roturas —un símbolo congelado más, una entrada más en la tabla del CLI y el set vigente sin post—, en la lane del sitio (checkout con `fetch-depth: 0` por los tags) y en `RUTAS_REPIN` y los guards locales del tren. **Lo que el tren hace ahora por set: nada a mano** —`bump-set` escribe el post y las páginas, y sin ellos el PR de set sale rojo—. Banco del sitio 9→**12/12** con W3 dentro; por mutación, una página editada, una fuente movida sin regenerar, un post borrado o editado, el catálogo fuera del sidebar o retitulado y el guard fuera del registro tumban `ST-09`…`ST-11`. (El banco numera `ST-10` el post por set y `ST-11` el catálogo.) |
| S-fin | pendiente | — | |
