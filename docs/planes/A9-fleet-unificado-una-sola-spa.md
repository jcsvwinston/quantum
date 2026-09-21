# A9 — Fleet unificado y una sola SPA

> Lee antes [`README.md`](README.md): el contrato de sesión, qué fichero manda
> para cada pregunta y qué no decide una sesión sola.

> **El troceado salió de la MEDICIÓN, no del enunciado.** El plan a 5/5
> describía este arco en cinco líneas —el agente habla el contrato
> `datasource`; mTLS real de extremo a extremo con rotación; retención local
> de eventos, métricas y audit con alertas; multi-servidor con estado
> compartido; una sola SPA sobre el stack del fleet— y un gate: la checklist
> de paridad de A6 sobre un clúster de tres agentes. `S0` midió las cinco y
> corrigió tres: el mTLS **ya existe** en el servidor (exige y verifica el
> certificado del cliente) y lo que falta es lo que viene después —atar la
> identidad del nodo al certificado, cargar el certificado del agente por
> configuración y rotar—; el agente **no puede** hablar el contrato sin una
> decisión de módulos, porque `agent/go.mod` no requiere la raíz donde vive
> `datasource` y el ADR-006 prohíbe pines cruzados salvo el proto; y «el stack
> del fleet como base común» nombra la SPA **menos** mantenida de las dos
> (cero tests, sin router, sin división de código, último cambio dos meses
> atrás). Es la quinta vez que la medición corrige el plan.

**Precondición del arco**: Quantum 1.35.0 certificado (A8 cerrado); A6 cerrado
(1.33.0), porque el fleet debe alcanzar la paridad que A6 midió en el panel.
**Gate del arco**: el registro `docs/auditoria/madurez-2026-09-03/registro.csv`
sin hallazgos abiertos de A9, el banco del fleet publicando su cifra, y el
ADR-002 de orbit cerrado como implementado.

## El banco

`orbit/internal/fleettest/fleetbench` — **50 controles, uno por sonda
ejecutable**, publicados en `orbit/docs/fleet-bench.md`. Vive dentro del
módulo `internal/fleettest`, el único que puede arrancar un `agent.Agent` real
contra un `server.Server` real, así que cada sonda mide el plano fleet de
punta a punta: un servidor que escucha, un agente que se registra, y la API
que la SPA consume. El test asserta el veredicto REGISTRADO, no el éxito:
cerrar un hueco pone la suite en rojo y pide actualizar la cifra.

**Línea de base medida el 2026-09-20 sobre orbit v1.10.3 (tras la ronda
adversarial; la primera pasada daba 17/4/29):**

| familia | present | partial | absent | de |
|---|---|---|---|---|
| identity | 6 | 2 | 2 | 10 |
| datasource | 4 | 2 | 6 | 12 |
| retention | 1 | 0 | 6 | 7 |
| alerts | 2 | 0 | 4 | 6 |
| ha | 1 | 1 | 3 | 5 |
| ui | 2 | 0 | 8 | 10 |
| **TOTAL** | **16** | **5** | **29** | **50** |

Corre en SQLite y en la lane `test` del CI de orbit (`go test ./...` en
`internal/fleettest`). Lo que sólo existe en un navegador —contraste, foco,
teclado de la SPA del fleet— no lo mide este banco: lo medirá el instrumento
de A6 cuando `S10` lo apunte al fleet, y hasta entonces el control `UI-07`
dice que no lo hace nadie.

## Lo que la medición encontró y el plan no sabía

1. **El mTLS del servidor ya existe, y la identidad que produce se tira.**
   `--agent-client-ca` exige y verifica el certificado del cliente, el guard
   fail-closed lo cuenta como autenticación, y hay test. Pero
   `server/services/agent_service.go` registra el nodo con el `node_id` que el
   agente **declara**, y nunca lee la identidad que el handshake acaba de
   poner en el contexto: un agente con certificado `node-a` puede registrarse
   como `node-b`. Y el agente sólo acepta un `*tls.Config` construido en Go
   (`koanf:"-"`): no hay forma de darle un certificado por configuración. Sin
   rotación en ninguno de los dos lados.
2. **El agente no habla el contrato, y el grafo de módulos lo impide.**
   `datasource` vive en el módulo raíz; `agent/go.mod` y `server/go.mod` no
   lo requieren, y el ADR-006 dice que el único pin cruzado permitido es el
   proto. Antes de que el agente construya un `datasource.DataSource` hay una
   decisión: mover el contrato a módulo propio o enmendar el ADR-006. Además
   el cable no lleva ni la identidad del operador ni los doce operadores de
   filtro: `ListRecordsRequest` tiene `map<string,string> filters`. El ADR-002
   enumera cuatro pasos y este quinto no.
3. **El servidor declara por escrito que no persiste** (`server/doc.go`:
   «The server is NOT persistence»). Eventos en anillos, métricas sólo la
   última muestra por nodo, audit del fleet en un anillo de 2048 sin
   antes/después ni retención ni export. Retención local no es una función
   que falta: es un invariante que hay que superar con un ADR sucesor.
4. **Alertas: cero código, cero mensajes en el proto.** Y el servidor no tiene
   colectores Prometheus propios (sólo el registro por defecto de Go); el
   agente sí, ocho.
5. **Multi-servidor: `server/doc.go` dice «single-instance by default»**, con
   failover del agente por lista de endpoints y nada más: sin estado
   compartido, sin relay entre servidores, sin sharding.
6. **Dos SPAs con cero código compartido y dos sistemas de tokens
   incompatibles**, y la del fleet es la débil: sin tests, sin router, un
   único chunk de 430 KB, Vite 6, sin AG Grid/Recharts/base-ui. El panel
   tiene 21 ficheros de test, división por rutas y presupuesto de carga
   inicial. La decisión «el stack del fleet como base» se toma en `S9` con
   estos datos delante, no antes.
7. **connect-es 2 no está bloqueado sólo por Dependabot**: `proto/buf.gen.yaml`
   pina los generadores v1 con un comentario que afirma que no hay v2
   publicada, y la hay. La migración es de `proto/`.
8. **El presupuesto de tamaño existente es raw y sólo de carga inicial**;
   todos los assets del panel comprimidos suman ≈504 KB y nada sirve
   comprimido. El «<400 KB comprimido» de A12 hoy no tiene ni medida ni
   contraparte en el servidor.

## El troceado

| Sesión | Qué entrega | Precondición | Criterio de hecho |
|---|---|---|---|
| `S0` | La medición: el banco, su página y los hallazgos | A8 cerrado | **HECHA** — orbit#500: 16/50, 8 hallazgos que reescriben el plan y OR-56 |
| `S1` | La identidad del nodo es la del certificado, y el agente lo carga por configuración | S0 | **HECHA** — orbit#501: `IDENT-05`, `IDENT-06` a `present` (18/50); e2e mTLS con agente real a través de la extensión, en la lane `test` |
| `S2` | Rotación de certificados en servidor y agente sin reinicio | S1 | **HECHA** — orbit#505: `IDENT-07`, `IDENT-08` a `present` (20/50, identity 10/0/0) |
| `S3` | La decisión de módulos (ADR-012) y el proto aditivo: identidad, operadores y total exacto en el cable | S0 | **HECHA** — orbit#506 (ADR-012, proto aditivo, `FDS-09`) + corte `v1.11.0`/`proto/v0.5.0` + orbit#507 (el agente lee `where`, `FDS-08`); `buf breaking` limpio; banco 22/50 |
| `S4` | El agente sirve Data Studio a través de `datasource.DataSource` con la identidad recibida | S3 | **PARTE 1 HECHA** — orbit#509: el contrato y su adaptador Nucleus son el módulo `orbit/datasource` (ADR-012 ejecutado). **Parte 2**: `agent.Config.DataSource`, el agente bajo la identidad recibida y el servidor rellenándola → `FDS-05`, `FDS-06`, `FDS-07`, `FDS-10` a `present` |
| `S5` | El servidor rellena la identidad desde la cadena de auth de la UI; audit con antes/después; ADR-002 cerrado | S4 | `FDS-11`, `FDS-12` a `present`; `quarkdatasource` registrado en el fleet |
| `S6` | Retención local: un almacén para eventos, métricas y audit con ventana y export (ADR sucesor de «no persiste») | S0 | familia `retention` completa |
| `S7` | Alertas por umbral con canales, y colectores propios del servidor | S6 | familia `alerts` completa |
| `S8` | Multi-servidor: estado compartido, relay de eventos y asignación de agentes | S6 | familia `ha` completa |
| `S9` | Una sola SPA: la decisión con datos (ADR-013), tokens compartidos, tests, frescura del dist y presupuesto | S5 | `UI-01` a `UI-05` a `present` |
| `S10` | connect-es 2 desde `proto/`, el instrumento de navegador sobre el fleet, tenant en la UI | S9 | `UI-06`, `UI-07`, `UI-09` a `present` |
| `S11` | Gate, guard y set: clúster de tres agentes en CI, `umbrella-fleet-posture`, set certificado | todas | guard registrado con fixture; set certificado; ADR-002 implementado |

**El orden no es negociable en tres sitios**: `S3` va antes que `S4` porque
sin la decisión de módulos el agente no puede importar el contrato; `S6` va
antes que `S7` y `S8` porque alertas y estado compartido necesitan un
almacén; y `S9` va después de `S5` porque la SPA única debe hablar con un
fleet que ya tiene identidad y permisos, no con el de hoy. `S1`–`S2` y
`S3`–`S5` pueden ir en paralelo (ficheros distintos); `S6`–`S8` tras ellos.

## Registro de sesiones

### `S4` — el módulo `datasource` (2026-09-21) · **parte 1 hecha**

- **PR**: [orbit#509](https://github.com/jcsvwinston/orbit/pull/509)
  (`feat(datasource)`). El contrato pasa a `github.com/jcsvwinston/orbit/datasource`
  con el adaptador Nucleus como subpaquete `datasource/nucleus` (era
  `internal/`); la raíz y `quarkdatasource` lo requieren en `v1.0.0`, el tag
  que el corte creará; `quarkdatasource` deja de requerir la raíz.
- **La decisión que ADR-012 dejaba a `S4`, tomada con la medición**: el
  adaptador viaja con el contrato (un módulo, no dos). Requerir Nucleus no
  añade nada a ningún consumidor —los tres lo requieren ya— y un contrato
  sin implementación por defecto obligaría a cada consumidor a traer la
  suya. Está escrito como enmienda en el ADR-012.
- **Hasta el tag**: `go.work` lleva un `replace` versionado (listar el
  directorio no basta: la versión requerida entra en el grafo y Go pide su
  `go.mod` al proxy), y `scripts/ci/link_unpublished_siblings.sh` añade un
  `replace` de directorio en el `go.mod` de cada lane `GOWORK=off` sólo
  mientras el tag del hermano no exista, y lo retira antes del diff de tidy.
  Medido: `go mod tidy` ignora el workspace y pide al proxy igual — por eso
  el `replace` va en el `go.mod` durante la lane y no en un `go.work`.
- **Guard de pines**: `datasource` en `MODULES`; un módulo sin tag se acepta
  pinado en su `initial-version` de release-please; la excepción del borde
  raíz se retira (no queda quien requiera la raíz). Trampa cazada de paso:
  `latest_tag` abortaba EN SILENCIO con un módulo sin tags (`grep` sin match
  bajo `pipefail`+`errexit`).
- **Registrado en**: release-please (`initial-version: 1.0.0`, `exclude-paths`
  de la raíz), Dependabot, CodeQL, la lane de tests del workspace, la matriz
  de módulos (columna nueva con `—` para las releases anteriores).
- **Lo que el corte debe**: commit de convergencia tras `datasource/v1.0.0`
  (quitar el `replace` del `go.work`, `go mod tidy` en raíz y
  `quarkdatasource` para que sus `go.sum` lleven las líneas del módulo). En
  el paraguas, cuando el set pine ese árbol: `orbit_modules.datasource` en
  `versions.yaml` y `./orbit/datasource` en el `go.work` (manifest-guard
  descubre los módulos del árbol y fallará hasta que estén).
- **Siguiente: parte 2** — `agent.Config.DataSource` (por defecto, el
  adaptador Nucleus sobre `Registry`/`Databases`), el agente ejecuta bajo la
  identidad recibida (RBAC por modelo con el `Authorizer` y confinamiento
  por tenant con un filtro sobre `ModelInfo.TenantField`, como el panel) y
  el servidor rellena `DataStudioRequest.operator`. Precondición: orbit#509
  fusionado.

### `S3` — ADR-012 y el proto aditivo (2026-09-21) · **hecha**

- **PR**: [orbit#506](https://github.com/jcsvwinston/orbit/pull/506)
  (`feat(fleet)`). Banco **21 de 50** (6 parciales).
- **ADR-012, aceptado**: el contrato `datasource` pasa a módulo hoja
  (`github.com/jcsvwinston/orbit/datasource`, misma ruta de import, cero
  dependencias), la segunda arista que ADR-006 permite. Medido: el fichero no
  importa nada; `quarkdatasource` sólo importa ese paquete de la raíz (así
  que la excepción `≤1 minor` de `check_internal_pins.sh` se retira con la
  extracción); el adaptador que convierte una aplicación en `DataSource` es
  `internal/` a la raíz, inalcanzable desde el agente en cualquier layout —
  ESA decisión es de `S4`. Primer tag `datasource/v1.0.0` (API congelada
  desde v1). **La extracción se ejecuta en `S4`**, con el agente como primer
  consumidor nuevo, y la mecánica escrita en el ADR: suelo que nombra el tag
  del corte, `replace` versionado en el go.work del CI hasta el corte
  (patrón de quark), paquete de release-please, `orbit_modules.datasource` en
  `versions.yaml`.
- **Proto por adición** (`buf lint` y `buf breaking --against main` limpios;
  stubs Go y TS regenerados; la SPA del fleet tipa y linta): `RecordFilter`
  + `ListRecordsRequest.where` (los doce operadores del contrato),
  `OperatorIdentity` + `DataStudioRequest.operator` (subject, email, role,
  read_only, tenant).
- **Agente**: cada `ListRecords` pide `ExactTotal` → `FDS-09` a `present`
  (mutación: sin `ExactTotal`, la sonda en rojo).
- **Lo que la lane standalone enseñó y partió la sesión en dos**: el agente
  pina `proto` por tag (ADR-006), así que un agente que lea `where` no
  compila con `GOWORK=off` hasta que exista `proto/v0.5.0`. El mapeo
  (`whereFromWire` sobre `model.ParseFilterOp`, que rehúsa en vez de tirar,
  con su test y con la sonda `FDS-08` ya escrita contra el campo tipado) está
  commiteado y empujado en la rama `wip/a9-s3-part2` de orbit y entra en la
  **parte 2**, tras el corte. ADR-006 ya lo decía: un cambio de proto son dos cortes.
- **Tres controles a `partial` por la misma razón**: `FDS-05`, `FDS-07` y
  `UI-09` — el cable DECLARA identidad, tenant y operadores, y declarar no es
  hacer. `UI-09` se endureció de paso: un campo del descriptor no es una
  noción de tenant en la UI, ni lo es la palabra dentro de una cadena
  traducida — y esa cadena (`ui/src/lib/i18n.ts`, «tenant filters apply»)
  afirma lo que no ocurre: **OR-58** (P3, `S10`).
- **El corte, y la parte 2.** Carlos decidió cortar orbit a mitad de arco:
  release PR orbit#504 → **orbit v1.11.0, proto/v0.5.0, agent/v0.8.0,
  server/v0.13.0** (2026-09-21), con la deuda de doc pagada EN la rama del
  bot (sección `## v1.11.0` en las notas y snapshot `1.11.0`, en ese orden),
  `check-anchored-release-branch.sh` en verde y `merge-bot-pr.sh` que
  disparó el CI, fusionó y esperó los seis tags; la release publica su
  `checksums.txt` firmado. **Parte 2 en
  [orbit#507](https://github.com/jcsvwinston/orbit/pull/507)**: `agent` y
  `server` a `proto v0.5.0`, `quarkdatasource` a la raíz `v1.11.0` (el pin
  que el guard avisaba a una minor), y `whereFromWire` sobre
  `model.ParseFilterOp`, que rehúsa con el filtro nombrado en vez de tirar.
  `FDS-08` a `present` (mutación: con el mapeo vacío, sonda y tests en
  rojo). Banco **22 de 50** (5 parciales). Y como el árbol de v1.11.0 no
  certifica (agent/server pinaban proto v0.4.4 con v0.5.0 publicado — un
  cambio de proto son DOS cortes, ADR-006), el release PR de convergencia
  orbit#508 cortó **v1.12.0** (agent/v0.9.0, server/v0.14.0,
  quarkdatasource/v1.10.0) y **Quantum 1.36.0** lo pina, certificado el
  mismo día fuera de cadencia.
- **Siguiente: `S4`** (el agente sirve Data Studio a través de
  `datasource.DataSource`), que empieza por la extracción del contrato a
  módulo con la mecánica del ADR-012. Precondición: orbit#507 fusionado.

### `S2` — rotación sin reinicio (2026-09-21) · **hecha**

- **PR**: [orbit#505](https://github.com/jcsvwinston/orbit/pull/505)
  (`feat(fleet)`). Banco **20 de 50**, familia `identity` completa (10/0/0).
- **La forma**: los dos lados sirven el certificado DESDE los ficheros en vez
  de copiarlo una vez. `server.TLSFromFiles` construye un `tls.Config` cuyo
  `GetCertificate` pregunta en cada handshake si los dos ficheros cambiaron
  (tamaño o mtime) y relee el par si es así; el binario lo usa para los dos
  listeners. El agente resuelve `tls_cert_file`/`tls_key_file` a un
  `GetClientCertificate` con el mismo origen, así que la SIGUIENTE conexión
  (bajo un stream vivo, la reconexión) presenta el certificado nuevo. Una
  rotación es escribir dos ficheros. Una rotación a medias (certificado
  nuevo, clave vieja) mantiene el par anterior con UN WARN por error distinto
  y reintenta en el siguiente handshake. Sin watcher ni dependencia nueva;
  los CA bundles se leen una vez (rotar la CA sigue siendo reinicio).
- **Duplicación deliberada**: el origen (~40 líneas) vive dos veces,
  `server/certfiles.go` y `agent/certfiles.go`, porque el ADR-006 no
  permite un módulo común. Si `S3` mueve el contrato `datasource` a módulo
  propio, ese módulo NO es el sitio de esto: es del contrato, no de TLS.
- **Sondas**: `IDENT-07` y `IDENT-08` conservan la medición genérica de Go y
  añaden la del producto —ficheros escritos, handshake, reescritos, handshake
  otra vez; la del agente a través de un failover a un segundo servidor—.
  El helper `writeKeyPair` fija el mtime con `Chtimes` para que dos
  escrituras en el mismo tick del reloj sean distintas para el sello.
- **Método**: dos mutaciones (cada origen sin releer nunca): la sonda y el
  test propio del módulo en rojo, nada más. El test del servidor cubre
  además la rotación rota (par anterior servido, exactamente un WARN en tres
  handshakes) y la clave que alcanza.
- **Siguiente: `S3`** (ADR-012, la decisión de módulos y el proto aditivo).
  Precondición: orbit#505 fusionado. OR-56 (`HA-05`) sigue abierto.

### `S1` — la identidad del nodo es la del certificado (2026-09-21) · **hecha**

- **PR**: [orbit#501](https://github.com/jcsvwinston/orbit/pull/501)
  (`feat(fleet)`: agent y server suben minor; la raíz también, porque la doc
  pública vive en ella). Banco **18 de 50** (identity 8/2/0).
- **Servidor, por adición**: `server.Config.AgentIdentityFromCertificate`
  (`--agent-identity-from-cert`) rehúsa con `PermissionDenied` la
  registración cuyo `node_id` no es el CN del certificado verificado, y `Run`
  rehúsa arrancar con el knob sobre un listener que no verifica certificados.
  **Apagado por defecto**: el servidor registra el `node_id` declarado y deja
  un WARN con las dos identidades y el flag — nunca en silencio. Encenderlo
  por defecto rompería a un fleet que comparte un certificado entre agentes:
  es **OR-57** (A12, QADR-0010).
- **Agente, por adición**: `ExtensionConfig` gana `tls_cert_file`,
  `tls_key_file`, `tls_ca_file`, `tls_server_name`; `TLSConfig()` los carga
  sobre un clon de `TLS`. Con certificado por fichero y sin `node_id`, el
  nodo se registra como el CN del certificado: la identidad escrita una vez,
  donde el servidor la autentica.
- **Lo que las sondas miden ahora**: `IDENT-05` boota un agente real A TRAVÉS
  de la extensión con tres rutas de fichero y sin `node_id`, y busca el nodo
  bajo el CN (antes: reflexión sobre nombres de campo — un campo es un
  nombre, no una superficie). `IDENT-06` lee el `PermissionDenied` de un
  stream crudo contra un servidor con el enlace, y deja registrado que el
  default sigue registrando lo declarado.
- **Método**: cinco mutaciones, cada una revirtiendo un arreglo (la negativa
  del servidor, el WARN degradado a Debug, el guard de `Run`, `Attach` sin
  leer el CN, `TLSConfig` ignorando los ficheros); cada una puso rojo el test
  que debía y la sonda que debía. Una trampa del arnés: el servidor envía un
  frame (el `Subscribe` agregado) nada más registrar, así que `Receive` con
  éxito es evidencia de aceptación, no un error del test.
- **Trampa de sesión**: `git checkout <fichero>` para deshacer una mutación
  devuelve el fichero AL ÍNDICE y se lleva las ediciones sin commitear. Las
  mutaciones se deshacen con el mismo reemplazo textual que las hizo.
- **Siguiente: `S2`** (rotación sin reinicio: `IDENT-07`, `IDENT-08`) o `S3`
  (ADR-012). Precondición de ambas: orbit#501 fusionado. OR-56 (`HA-05`)
  sigue abierto: `S1` tocó el handler pero no el bucle lector.

### `S0` — la medición (2026-09-20) · **hecha**

- **PR**: [orbit#500](https://github.com/jcsvwinston/orbit/pull/500)
  (`test(fleetbench)`, módulo `internal/fleettest`, que no se publica: no
  corta release). Dos commits: el banco y la ronda adversarial.
- **Banco**: `orbit/internal/fleettest/fleetbench`, 50 controles en seis
  familias, publicados en `orbit/docs/fleet-bench.md`. **16 presentes, 5
  parciales, 29 ausentes.** Corre en la lane `test` del CI de orbit (`go test
  ./...` en `internal/fleettest`), así que mide en cada PR.
- **Método**: reconocimiento por familias contra el código real, luego las
  sondas, luego una ronda adversarial preguntando a cada sonda qué OTRO
  reparto de hechos le daría el mismo veredicto. Movió un control y endureció
  seis (FDS-11 mira dentro de un `BeforeCreate`; FDS-12 deja la supervivencia
  al reinicio a RET-04; UI-02/UI-04/UI-05/UI-07 y ALR-06 miden lo que su
  título nombra y no una palabra).
- **Lo que la ronda encontró y el reconocimiento no**: `HA-05` (una
  reconexión con el mismo `node_id` supersede el stream anterior) daba
  `present` contando entradas de un `map`, que no puede tener dos. Medido
  sobre el stream —un par crudo registrado primero y un agente real que toma
  el relevo—, `Registry.Add` cancela el escritor viejo pero el lector de
  `AgentService.Stream` bloquea en `Receive` y sólo mira el contexto cancelado
  tras un error, así que el par superseded no ve error alguno y un frame que
  emite después llega al suscriptor de la UI como si fuera del nodo. Es
  **OR-56** (P2, A9) en el registro; `HA-05` queda `partial` hasta que el
  lector salga en `streamCtx.Done()`. Encaja en `S8` (familia `ha`), o antes
  si `S1` toca ese handler.
- **Dos hipótesis del reconocimiento que las sondas tumbaron** están escritas
  en la página del banco: leer es una hipótesis, y sólo la sonda dice si era
  verdad. `FDS-09` es `absent` aunque el proto declare `total`: el servidor
  nunca lo rellena. Una declaración no es una superficie.
- **Detalle del arnés que vale para otros bancos**: un `Run` de servidor o
  agente que no retorna a los 5 s de cancelarlo se REGISTRA, no se traga: un
  proceso que no para es un hallazgo, no un tiempo.
- **Siguiente: `S1`** (la identidad del nodo es la del certificado).
  Precondición: orbit#500 fusionado. `S3` puede ir en paralelo (ficheros
  distintos), pero su ADR-012 es una decisión de módulos que se escribe
  ANTES de tocar `agent/go.mod`.
