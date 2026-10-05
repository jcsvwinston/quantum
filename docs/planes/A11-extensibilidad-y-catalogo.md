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
| N5 | pendiente | — | |
| N6 | pendiente | — | |
| N7 | pendiente | — | |
| N8 | pendiente | — | |
| N9 | pendiente | — | |
| N10 | pendiente | — | |
| N11 | pendiente | — | |
| O1 | PR verde | orbit#532 | 63/72, navegador 7/8; el logo del propio banco daba 404 y `EXT-08` contaba cualquier fallo de arranque |
| O2 | PR verde | orbit#534 | 65/72; tema aplicado antes del primer frame con un script clásico de `'self'`; su `UIX-09` se renumera a `UIX-10` al integrar |
| O3 | PR verde | orbit#533 | 61/72; sin `delete` no había selección en la rejilla; OR-62 (contraste de los errores) |
| O4 | PR verde | orbit#535 | 63/72 en su rama; ruta `/actions/{action}/{id}` (la otra chocaba con el catch-all); Data Studio con estado en la URL |
| O5 | PR verde | orbit#538 | 67/72, navegador 9/10; un operador sólo con permiso de dashboard no podía entrar; los assets relativos rompían el deep-link |
| O6 | pendiente | — | |
| Q1 | **hecha** 2026-10-05 | quark#425 | registro con `RWMutex`, QK-33 (`listOperand`), ADR-0026 aceptado; al buscar QK-33 apareció **QK-39 (P0)**, arreglado en quark#428 dentro de 1.39.0 |
| Q2 | **hecha** 2026-10-05 | quark#432 → quark#433 | seis interfaces opcionales nuevas en `quarkdriver`; Oracle declaraba DDL transaccional y no lo tiene; `DRV-04` present (7/22) (fusionados como `feat(schema)`: añaden API) |
| Q3 | pendiente | — | |
| Q4 | pendiente | — | |
| Q5 | pendiente | — | |
| Q6 | pendiente | — | |
| Q7 | pendiente | — | |
| Q8 | **hecha** 2026-10-05 | quark#426 | `internal/integrations` (módulo propio no publicado); la guía de frameworks comprobada línea a línea contra las fixtures; banco 8/22 |
| Q9 | **hecha** 2026-10-05 | quark#427 | gRPC y Nucleus; NU-107 (`BindJSON` con arrays, ya arreglado en nucleus#591); banco 10/22 |
| Q10 | pendiente | — | |
| Q11 | en curso | — | ampliada con **QK-42 (P0)**: `Find(id)` bajo `RowLevelSecurityClient` lee la fila de otro tenant (lo encontró el tutorial multi-tenant de `W2`); primero QK-42, luego QK-40 y QK-41 |
| W1 | pendiente | — | |
| W2 | **hecha** 2026-10-05 | quantum#255 | tres tutoriales en `website/docs/` (SaaS multi-tenant con las tres piezas, API-only con documento, `--check` y cliente TypeScript ejecutado con node, monolito MVC con formulario, CSRF, sesión y flash) y la lane `tutorials-smoke` que los ejecuta paso a paso: `qs_steps` en el parser del quickstart (comandos, ficheros por `title=` y salidas pegadas a su comando, comparadas), sondas de lo que la página sólo cuenta y 0 WARN; ~8 s, ~8 s y ~2,5 s en local (presupuesto 60 s por tutorial). Banco del sitio 0→**3/12**; la sonda de tutorial ya no se conforma con un script que lo nombre: tiene que llamarlo un workflow. Encontró QK-42 (P0) y NU-111 (punto 11) |
| W3 | pendiente | — | |
| W4 | pendiente | — | |
| S-fin | pendiente | — | |
