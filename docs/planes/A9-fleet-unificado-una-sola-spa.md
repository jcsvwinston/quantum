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
| `S4` | El agente sirve Data Studio a través de `datasource.DataSource` con la identidad recibida | S3 | **HECHA** — orbit#509 (el módulo `orbit/datasource`) + orbit#511 (el agente sobre el contrato bajo el operador que el servidor envía): `FDS-05`, `FDS-06`, `FDS-07`, `FDS-10` a `present`; banco 26/50 |
| `S5` | El servidor rellena la identidad desde la cadena de auth de la UI; audit con antes/después; ADR-002 cerrado | S4 | **HECHA** — orbit#512 (el cable declara el antes y el después del audit) + corte `v1.13.0`/`proto/v0.6.0` + orbit#513 + corte de convergencia `v1.14.0` (el agente devuelve el registro previo, el servidor escribe los dos lados, `quarkdatasource` probado en el fleet, ADR-002 implementado): `FDS-11`, `FDS-12` a `present`; banco 28/50, familia `datasource` completa |
| `S6` | Retención local: un almacén para eventos, métricas y audit con ventana y export (ADR sucesor de «no persiste») | S0 | **HECHA** — orbit#515 (ADR-013: store SQLite opt-in con ventana, replay calentado, audit y descarga, muestras de métricas; el agente aparca eventos sin stream): `RET-01/02/04/05/06` a `present`; banco 33/50; `RET-03` espera el RPC de historial en el lote de proto |
| `S7` | Alertas por umbral con canales, y colectores propios del servidor | S6 | **HECHA** — orbit#520 (reglas por umbral sobre métricas de host, canales webhook y correo, `AlertService`, colectores `admin_server_*`, `MetricsService` sirve el historial retenido, pines a proto v0.7.0): familias `alerts` 6/0/0 y `retention` 7/0/0 completas; banco 38/50 |
| `S8` | Multi-servidor: estado compartido, relay de eventos y asignación de agentes | S6 | **HECHA** — orbit#522 (ADR-014: malla de un salto sobre el listener de agentes, nodos remotos en el registro, relay de eventos con demanda total, asignación por rendezvous hashing y `Command.redirect`; el stream reemplazado termina, OR-56 cerrado): familia `ha` 5/0/0; banco 42/50 |
| `S9` | Una sola SPA: la decisión con datos (ADR-015), tokens compartidos, tests, frescura del dist y presupuesto | S5 | **HECHA** — orbit#524 (ADR-015: el proyecto del panel como base, el fleet como segunda entrada, un dist embebido por el módulo `orbit/ui` que raíz y servidor requieren por tag; tokens, tests, lint, lane de frescura y presupuesto por entrada compartidos): `UI-01`–`UI-05` a `present`; banco 47/50 |
| `S10` | connect-es 2 desde `proto/`, el instrumento de navegador sobre el fleet, tenant en la UI | S9 | **HECHA** — orbit#526 (stubs de segunda generación desde `proto/`, proyecto `fleet` del instrumento de navegador con seis controles `UIF`, el tenant del operador y del modelo en la SPA sobre dos campos aditivos): `UI-06`, `UI-07` a `present`; `UI-09` `partial` hasta que servidor y agente rellenen los campos tras el corte (parte 2, en `S11`); banco 49/50; OR-58 cerrado, OR-59 abierto |
| `S11` | Gate, guard y set: clúster de tres agentes en CI, `umbrella-fleet-posture`, set certificado | todas | **EN CURSO** — orbit#527 (el clúster de tres agentes detrás de dos servidores, `TestFleetParityThreeAgents`; el servidor rellena `node_id` en las respuestas de Data Studio, OR-60) y el guard `umbrella-fleet-posture` con fixture en la rama `feat/a9-s11-fleet-posture` del paraguas, verificado sobre el árbol de orbit; la deuda de doc de v1.17.0 en la rama del bot. Falta: el primer corte (`ui/v1.0.0`, `proto/v0.8.0`), la parte 2 de `S10` en orbit#527, el corte de convergencia y el tren con el guard (`--incluye`) |

**El orden no es negociable en tres sitios**: `S3` va antes que `S4` porque
sin la decisión de módulos el agente no puede importar el contrato; `S6` va
antes que `S7` y `S8` porque alertas y estado compartido necesitan un
almacén; y `S9` va después de `S5` porque la SPA única debe hablar con un
fleet que ya tiene identidad y permisos, no con el de hoy. `S1`–`S2` y
`S3`–`S5` pueden ir en paralelo (ficheros distintos); `S6`–`S8` tras ellos.

## Registro de sesiones

### `S11` — el gate, el guard y el set (2026-09-25) · **en curso**

- **PR de orbit**: [orbit#527](https://github.com/jcsvwinston/orbit/pull/527)
  (`test(fleet)`), abierto; crece con la parte 2 de `S10` tras el primer
  corte y se fusiona ANTES del corte de convergencia, no antes del primero
  (la deuda de doc de v1.17.0 ya está en la rama del bot y release-please
  la regenera con cada push a main).
- **El clúster de tres agentes**: `TestFleetParityThreeAgents` en
  `internal/fleettest/fleetbench/cluster_test.go` — dos servidores en malla,
  tres agentes con base de datos propia (dos detrás de A, uno detrás de B) —
  pregunta a los DOS servidores lo que el panel de A6 responde para una
  aplicación: inventario (tres nodos, cada remoto nombrando su servidor),
  eventos (un suscriptor en cualquiera oye a los tres), Data Studio (cada
  nodo por su servidor; en el otro, rechazo nombrando al propietario), audit
  (la mutación atribuida a su nodo) y vida (el agente que para no está
  conectado en ninguno). 0,6 s; corre con `internal/fleettest` en la lane
  `test`. Verificado por mutación (sin el fix del servidor, seis respuestas
  vacías; sin el `stop` del agente, el nodo sigue conectado).
- **Lo que encontró**: `ListModelsResponse.node_id` y
  `PaginatedRecords.node_id` («qué agente respondió») declarados en el cable
  y VACÍOS: el servidor descartaba el nodo que `dispatch` devuelve. Con
  varios nodos una UI no sabía de quién era la página que leía. Ninguna de
  las cincuenta sondas pone dos nodos detrás de un servidor. **OR-60**,
  hecho en el mismo PR.
- **La página del banco tenía la tabla por familias tres sesiones rancia**
  (26/3/21 bajo un titular de 49 de 50): se retipaba a mano. El generador
  (`TestFleetBenchTable`) emite ahora también el resumen por familias, la
  página lleva el generado, y el guard compara los dos con el catálogo.
- **El guard `umbrella-fleet-posture`** (`scripts/check_fleet_posture.sh`,
  fixture con cuatro roturas): 50 controles con nota en cada hueco; la cifra
  publicada y la tabla por familias iguales al catálogo, familia a familia;
  la mitad de navegador en el pin con su violación plantada (`UIF-00`) y el
  CI de orbit corriendo `TestFleetBrowserBench` con
  `ORBIT_BENCH_BROWSER=required`; el test del clúster presente, sin `t.Skip`,
  y la lane corriendo `internal/fleettest`. Al pin actual (v1.16.0) FALLA por
  construcción —no hay proyecto fleet del navegador ni clúster, y la tabla
  ya estaba rancia— así que entra con el set (`train.sh --incluye`), no en
  un PR propio. Verificado en OK sobre el árbol de orbit#527 y en las cuatro
  causas sobre su fixture, en una copia con `orbit` apuntando al hermano.
- **La deuda de doc de v1.17.0** está pagada en la rama
  `release-please--branches--main` de orbit (notas: la flota de servidores,
  un proyecto de frontend, la UI sobre la segunda generación del protocolo,
  `proto/v0.8.0`; snapshot 1.17.0; los cinco guards de docs en verde;
  `check-anchored-release-branch.sh orbit 523` OK). El corte publica
  **v1.17.0, proto/v0.8.0, agent/v0.14.0, server/v0.19.0, ui/v1.0.0**.
- **Falta, en este orden**: `merge-bot-pr.sh orbit 523` (corte 1) → parte 2
  de `S10` en orbit#527 (`GetSelf` rellena `tenant` desde
  `auth.Identity.Tenant`; `modelToProto` del agente rellena `tenant_field`;
  pines de raíz/agent/server/fleettest a proto v0.8.0 y ui v1.0.0; fuera el
  `replace` de `ui` del go.work; `UI-09` a `present`, banco 50/50 y página)
  → fusionar orbit#527 → deuda de doc de v1.18.0 y corte de convergencia
  (v1.18.0, agent/v0.15.0, server/v0.20.0) → `train.sh --desde paraguas
  --hasta cierre --incluye scripts/check_fleet_posture.sh --incluye
  tests/guard-fixtures/umbrella-fleet-posture --incluye
  scripts/lib/guard-registry.sh` con `./orbit/ui` en el go.work del
  paraguas (la fila `orbit/ui` del README la escribe `bump-set`) → A9
  cerrado.

### `S10` — connect-es 2, el navegador sobre el fleet y el tenant en la UI (2026-09-24) · **hecha**

- **PR**: [orbit#526](https://github.com/jcsvwinston/orbit/pull/526)
  (`feat(ui)`). Banco **49 de 50**, 1 parcial (`UI-09`), 0 ausentes; el
  banco de navegador del fleet, 5 de 6 (`UIF-02` ausente con razón).
- **connect-es 2 / protobuf-es 2** (`UI-06`): `proto/buf.gen.yaml` genera
  los stubs TS del fleet con `bufbuild/es` v2 a solas (mensajes y
  descriptores de servicio de un generador; el de `connectrpc/es`
  desaparece); `@bufbuild/protobuf ^2.15`, `@connectrpc/connect ^2.2`,
  `connect-web ^2.2`. Código: `createClient`, `create(Schema, …)`,
  `timestampDate`, tipos `wkt`; cuatro ficheros del fleet y dos tests. El
  bundle pasa de 424 a 458 KB (presupuesto 512).
- **El instrumento de navegador sobre el fleet** (`UI-07`): proyecto
  `fleet` del mismo Playwright (`specs/fleet.spec.ts`, seis controles
  `UIF`), conducido desde `internal/fleettest` (`TestFleetBrowserBench`:
  servidor con operador loopback sin credencial + un agente;
  `--project=fleet`, informe propio). El driver del panel pasa
  `--project=panel`. La lane de CI corre los dos. **`UIF-02` (contraste)
  mide `absent`**: en el tema claro —el de arranque— el texto pequeño
  atenuado de la vista general queda por debajo de 4.5:1 sobre `--t1`; los
  rótulos del sidebar pasaron a un token que cumple y `--t27`/`--t32`
  claros se subieron como se hizo con `--t26`; el resto es el re-skin sobre
  los tokens compartidos → **OR-59** (P3, A12). Retitular, no forzar.
- **El tenant en la UI** (`UI-09`): dos campos aditivos, `SelfInfo.tenant`
  (el tenant del proxy de confianza, junto a quién queda auditado el
  operador: `alice · tenant acme`, `describeOperator` con test) y
  `ModelInfo.tenant_field` (Data Studio marca el modelo acotado y su
  columna). **Sigue `partial`** por la razón de `FDS-11` en `S5`: servidor y
  agente rellenan los campos cuando pinen el proto que los lleva (parte 2,
  con el corte de `S11`), y la sonda ahora COMPRUEBA que el servidor
  devuelve el tenant que el proxy envió — un campo declarado no la pasa. La
  descripción de Data Studio de **OR-58** dice lo que ocurre desde `S4`.
- **Lo que costó**: `clean: true` de buf borra el directorio de salida
  entero (bien para el cambio de generador); protobuf-es 2 quita `toDate`
  y los constructores `new Msg({})`; el Chromium headless del instrumento
  se instaló en local (`npx playwright install chromium-headless-shell`) y
  desde ahí el banco de navegador se puede correr antes del CI.
- **Parte 2 (con el corte de `S11`)**: `GetSelf` rellena `tenant` desde
  `auth.Identity.Tenant`; `ListModels` del agente rellena `tenant_field`
  desde `datasource.ModelInfo.TenantField`; `UI-09` a `present`.

### `S9` — un solo proyecto de frontend (2026-09-24) · **hecha**

- **PR**: [orbit#524](https://github.com/jcsvwinston/orbit/pull/524)
  (`feat(ui)`). Banco **47 de 50**: `ui` 7/1/2; quedan `UI-06` (connect-es
  2), `UI-07` (instrumento de navegador sobre el fleet) y `UI-09` (tenant en
  la UI), los tres de `S10`.
- **ADR-015, aceptado e implementado, con los datos delante**: el plan
  decía «el stack del fleet como base» y la tabla dice lo contrario (panel:
  10 318 líneas, 116 tests, chunks por ruta, presupuesto y lane de frescura;
  fleet: 5 306 líneas y nada de eso). El proyecto del panel se mueve a `ui/`
  como base; las fuentes del fleet pasan a `ui/src/fleet/` como segunda
  entrada con su Vite y su Tailwind (sus pantallas siguen leyendo la paleta
  numerada). Un `npm run build` construye `dist/panel` y `dist/fleet`.
- **Un `//go:embed` no puede salir de su módulo**, y raíz y servidor son
  módulos distintos por ADR-006: «el mismo dist» sólo es posible si lo embebe
  un tercer módulo hoja que los dos requieran. Nace
  `github.com/jcsvwinston/orbit/ui` (sin dependencias; `Panel()`, `Fleet()`,
  `Dist()`), la raíz sirve `Panel()` bajo su prefijo y el servidor `Fleet()`
  en su raíz; `server/ui` desaparece. Mecánica del nacimiento como la de
  `datasource`: pin a `ui v1.0.0` (initial-version), `replace` versionado en
  el go.work, `link_unpublished_siblings.sh` en las lanes (verificado en
  local para raíz, servidor y ui), release-please, CodeQL, matrices,
  Dependabot con un solo proyecto npm.
- **Compartido por construcción**: `src/shared/tokens.css` importado por las
  dos hojas de estilos; un tsconfig, un ESLint, un Vitest (el fleet estrena
  specs), una lane de CI que tipa, linta, prueba, construye y falla con el
  dist rancio (desaparece la lane `admin-ui`), y `embed_test.go` con
  presupuesto por entrada (el del fleet, 512 KB, es un techo para el
  re-skin; su bundle es un chunk de 424 KB).
- **Sondas adaptadas al layout nuevo** (`UI-01`, `UI-04`, `UI-05`, `UI-10`):
  el módulo que las dos vertientes importan y sus embeds propios ausentes; la
  única lane que diffea `ui/dist`; las constantes de presupuesto en
  `ui/embed_test.go`; el dist del panel en `ui/dist/panel`.
- **Lo que costó mover**: los imports de efecto (`import '@/index.css'`) no
  entran en un `from '@/…'` y la build del fleet compilaba la hoja del
  panel; un comentario de una regla de lint que ya no existe; y un `import`
  de un `.js` de config en un `.ts` (se carga por ruta).
- **Deberes del corte y del paraguas**: el corte crea `ui/v1.0.0` y su
  convergencia quita el `replace`; en el paraguas, `./orbit/ui` en el
  go.work y una fila `orbit/ui` en la tabla del README (una vez, con su
  rol; `bump-set` ya regenera `orbit_modules` solo).
- **Numeración**: la SPA era «ADR-013» en el plan; `S6` tomó el 013 y `S8`
  el 014, así que es el ADR-015.

### `S8` — una flota de servidores (2026-09-24) · **hecha**

- **PR**: [orbit#522](https://github.com/jcsvwinston/orbit/pull/522)
  (`feat(fleet)`). Banco **42 de 50**: `ha` 5/0/0; todas las familias
  completas salvo `ui` (2/1/7, `S9`–`S10`). **OR-56 cerrado.**
- **ADR-014, aceptado e implementado**: cada servidor conoce a los demás
  por configuración (`--peers`) y mantiene UN stream saliente a cada uno
  sobre el listener de agentes, autenticado como un agente; por él empuja
  en un solo sentido `PeerHello`, sus nodos, y después cada cambio de nodo,
  evento y muestra de métricas (`server/peers.Mesh`). El otro extremo
  (`services.PeerService`) recibe y no reenvía: malla de un salto, dos
  streams por par, nada que deduplicar. Nodos remotos en el registro
  (`NodeInfo.Via`; etiqueta `orbit.server` en `ListNodes`; nada se les
  encola; Data Studio los rechaza con `FailedPrecondition` nombrando al
  propietario; un anuncio nunca sustituye a un nodo conectado aquí; los
  nodos de un peer se van con él). Eventos relayados al bus y al replay del
  peer, no a su store. **Demanda total mientras hay un peer**: la malla
  lleva eventos, no filtros, así que los agentes envían todo y cada servidor
  filtra para sus suscriptores — el campo de demanda en `PeerFrame` es la
  adición natural del corte siguiente. **Asignación** (`--assign-nodes` +
  `--agent-advertise-addr`): rendezvous hashing sobre este servidor y los
  peers alcanzados; el agente que se registra donde no le toca recibe
  `Command.redirect`, y lo acepta SOLO hacia un endpoint que el operador le
  configuró (`Dialer.Prefer`); si no, avisa y se queda.
- **OR-56 (`HA-05`)**: el handler del stream lee por una goroutine y hace
  select sobre su contexto; al ser desalojado por un registro más nuevo
  devuelve `Aborted` al extremo viejo y descarta el frame que entre en la
  carrera.
- **Medido y decidido de paso**: con un peer conectado el agente tiene
  demanda desde el registro, así que `waitDemand` ya no prueba que la UI
  esté suscrita — `HA-03` espera a las suscripciones en los dos buses
  (`SubscriberCount`). Las sondas de dos servidores reservan los puertos
  antes de arrancar para que cada uno nombre al otro, y esperan a que los
  dos enlaces estén abiertos. Tres mutaciones: malla sin relay (`HA-03`),
  servidor sin redirigir (`HA-04`), registro que ignora anuncios (`HA-02`).
- **Lo que NO decide** (en el ADR): descubrimiento ni consenso (dos vistas
  distintas de la malla asignan distinto durante una partición); relay de
  Data Studio o snapshots a otro servidor; cifrado propio entre peers.

### `S7` — alertas por umbral, canales y los colectores propios del servidor (2026-09-24) · **hecha**

- **PR**: [orbit#520](https://github.com/jcsvwinston/orbit/pull/520)
  (`feat(fleet)`). Banco **38 de 50**: `alerts` 6/0/0 y `retention` 7/0/0,
  las dos familias completas. Es además la **convergencia** del lote de
  proto: agent, server y `internal/fleettest` pinan `proto v0.7.0`.
- **`server/alerts`**: reglas por umbral sobre un campo de `HostMetrics`
  (operador, umbral, `for`, severidad, nodos por glob, canales), leídas de
  un fichero JSON (`--alert-rules-file`) con defaults y validación; el
  motor evalúa cada heartbeat, dispara cuando la condición se mantiene
  `for`, resuelve cuando cesa, guarda los últimos 1024 resueltos, y un
  notificador único entrega a los canales con tope por entrega. Canales:
  webhook (POST JSON, `--alert-webhooks name=url`) y correo SMTP
  (`--alert-smtp-*`, credenciales por entorno). Una regla que nombra un
  canal no configurado rehúsa arrancar (test): la regla que no avisa a
  nadie por error es el fallo silencioso que las alertas existen para
  evitar. `AlertService` (`ListAlertRules`, `ListAlerts`, `StreamAlerts`)
  tras la cadena de auth de la UI.
- **Colectores propios** (`server/metrics`): registro por servidor servido
  junto al registro por defecto (`promhttp.HandlerFor(Gatherers{...})`), así
  varios servidores en un proceso no chocan por nombre: nodos conectados y
  conocidos, frames/eventos/heartbeats recibidos, peticiones de Data Studio
  por resultado, alertas activas/disparadas/resueltas, eventos en replay,
  publicados y descartados a suscripciones de la UI.
- **`MetricsService.ListHostMetrics`** sirve el historial retenido desde
  `S6` (oldest first, ventana y `since`); sin directorio de datos, vacío.
- **Sondas**: `ALR-01` configura una regla que todo nodo rompe
  (`goroutines > 0`) y lee la alerta atribuida a regla, nodo, valor y hora;
  `ALR-02` levanta un webhook y recibe el POST; `ALR-03` lee reglas y
  alertas y comprueba que un llamante sin credencial es rechazado; `ALR-04`
  encuentra los colectores propios por espacio negativo; `RET-03` lee tres
  muestras en orden y honra `since`. Tres mutaciones: motor que no evalúa
  (`ALR-01` rojo), webhook que no envía (`ALR-02` rojo), historial vacío
  (`RET-03` rojo).
- **Lo que no hace**: las alertas no se retienen entre reinicios (viven en
  memoria); no hay reintento de entrega; la UI del fleet no las muestra
  todavía (`S9`/`S10`).

### `S6` — retención local del plano fleet (2026-09-24) · **hecha**

- **PR**: [orbit#515](https://github.com/jcsvwinston/orbit/pull/515)
  (`feat(fleet)`). Banco **33 de 50** (retention 6/0/1).
- **ADR-013, aceptado e implementado**: el servidor retiene cuando se le
  da un directorio de datos (`server.Config.DataDir`, `--data-dir`), en un
  fichero SQLite (`server/store`, driver puro en Go que el binario ya
  arrastraba por el driver de Nucleus: sin dependencia nueva). Retiene los
  eventos que reenvía (el anillo de replay se calienta desde el fichero al
  arrancar), el rastro de auditoría (`ListAudit` y la descarga leen del
  fichero) y una muestra de métricas de host por heartbeat y nodo. La
  ventana (`Retention`, `--retention`, 7 días) acota toda lectura antes de
  que el purgador borre; un escritor por lotes detrás de un canal;
  `Flush` para leer lo propio. Descarga en
  `GET /api/audit/export?format=csv|json`. Sin directorio de datos, el
  servidor de siempre: la retención es opt-in porque escribir en disco es
  un cambio que el operador pide.
- **El agente aparca lo que ocurre sin stream** (`agent/catcher.go`): al
  terminar un stream recuerda los filtros a los que el servidor estaba
  suscrito (`Stream.ParkedFilters`), sigue escuchando el bus bajo ellos y
  empuja al buffer por tipo que ya existía; el siguiente stream lo vacía
  nada más registrarse. Acotado como el buffer; contador
  `admin_agent_events_parked_total`.
- **Medido y decidido de paso**: `Subscription.Cancel` del bus de nucleus
  NO cierra el canal (lo documenta), así que un drenaje por `range` cuelga;
  el receptor usa un canal de parada. Las sondas `RET-01`/`RET-04` ponen
  `DataDir` (el knob que pedían; `restartable` reinicia con el mismo
  Config); `RET-05` fija una ventana de un segundo y ve irse la entrada.
  Dos mutaciones: servidor sin calentar el replay (`RET-01` rojo), agente
  sin aparcar (`RET-02` rojo).
- **El lote de proto de `S6`–`S8`, [orbit#516](https://github.com/jcsvwinston/orbit/pull/516)
  (`feat(proto)`, apilado sobre #515, para decidir)**: `MetricsService.
  ListHostMetrics` (`RET-03`), `AlertRule`/`Alert` y `AlertService` con
  `ListAlertRules`/`ListAlerts`/`StreamAlerts` (`S7`), `Command.redirect` y
  `PeerService.Sync` con `PeerHello`/`NodeInfo`/`NodeGone`/`Event`/
  `PeerHostMetrics` (`S8`). Medido al escribirlo: un RPC nuevo en un
  servicio existente cambia la interfaz del handler generado y el servidor
  no puede implementarla hasta pinar el tag → servicios nuevos, que
  simplemente no se sirven hasta entonces. `RET-03`, `ALR-01` y `ALR-03`
  pasan a `partial` con la razón escrita; `HA-04` sigue ausente porque
  nombrar la asignación antes de que `S8` la decida sería un nombre, no un
  diseño. Con #515 y el lote: 33 present, 5 partial, 12 absent. #516 se cerró
  solo al borrarse la rama base tras fusionar #515 (la pila con squash);
  rebasado con `--onto` y fusionado como **orbit#518**. **Corte
  (decisión de Carlos, 2026-09-24)**: release PR orbit#517 → **orbit
  v1.15.0, proto/v0.7.0, agent/v0.12.0, server/v0.17.0**, deuda de doc en
  la rama del bot. El árbol de v1.15.0 pina proto v0.6.0 en agent/server:
  la convergencia (pines a v0.7.0 y su release) va con `S7`, y hasta
  entonces el paraguas no puede re-pinar.
- **Lo que NO decide** (escrito en el ADR): estado compartido entre
  servidores (`S8`), export de eventos o métricas, cifrado del fichero.

### `S5` — el audit dice qué cambió, ADR-002 se cierra y `quarkdatasource` entra en el fleet (2026-09-22) · **hecha**

- **Parte 1, [orbit#512](https://github.com/jcsvwinston/orbit/pull/512)
  (`feat(proto)`)**: proto por adición, `buf lint` y `buf breaking` limpios,
  stubs Go y TS regenerados, la SPA tipa y linta. `AuditEntry.before_json` y
  `AuditEntry.after_json` (los valores del registro antes y después, como
  JSON; un create no tiene antes, un delete no tiene después, un bulk lleva
  un array por lado) y `DataStudioResponse.previous` (`repeated Record`: el
  agente devuelve el registro tal como estaba antes de un update, un delete
  o cada registro de un bulk, para que el servidor escriba el lado «antes»
  sin un segundo viaje). El README de `quarkdatasource` muestra el cableado
  del fleet por `agent.ExtensionConfig.DataSource`, el paso 4 del plan del
  ADR-002. Banco sin cambio (**26 de 50**): `FDS-11` sigue `partial` con su
  razón nueva —el cable declara los campos y el servidor no escribe nada en
  ellos— como `FDS-05` y `FDS-07` tras `S3`.
- **Por qué dos partes, otra vez**: agent y server pinan `proto` por tag
  (ADR-006); el código que rellena o lee los campos nuevos no compila con
  `GOWORK=off` hasta que exista `proto/v0.6.0`. Y la prueba de
  `quarkdatasource` en el fleet (un test que corre el handler del agente
  sobre el adaptador Quark) necesita `agent/v0.10.0`, que tampoco existe:
  el test no puede vivir en la raíz (Quark no entra en su grafo) ni en el
  agente (mismo motivo), así que vive en `quarkdatasource` y requiere el
  agente publicado. Ambas cosas caen en la **parte 2, tras el corte**.
- **El corte, y la parte 2.** Carlos decidió cortar orbit otra vez a mitad
  de arco: release PR orbit#510 → **orbit v1.13.0, proto/v0.6.0,
  agent/v0.10.0, server/v0.15.0, datasource/v1.0.0 (primer tag),
  quarkdatasource/v1.11.0** (2026-09-22), con la deuda de doc pagada en la
  rama del bot (sección `## v1.13.0` en las notas y snapshot `1.13.0`, en
  ese orden), `check-anchored-release-branch.sh` en verde y `merge-bot-pr.sh`
  que disparó el CI, fusionó y esperó los siete tags. **Parte 2 en
  [orbit#513](https://github.com/jcsvwinston/orbit/pull/513)
  (`feat(fleet)`)**: el agente devuelve el registro tal como estaba
  (`DataStudioResponse.previous`: uno en update y delete, uno por fila en
  bulk, ninguno en create; renderizado ANTES de escribir, porque el primer
  test cazó un store que entrega el mismo mapa que muta); el servidor
  escribe los dos lados como objetos JSON con claves ordenadas (un array en
  bulk), cada lado con tope de 64 KiB y marcador, y `ListAudit` los expone;
  agent/server a `proto v0.6.0`, el `replace` de `datasource` fuera del
  `go.work`, raíz y quarkdatasource tidy contra el tag publicado. La PRUEBA
  de `quarkdatasource` en el fleet vive donde Quark puede vivir, el módulo
  test-only `internal/fleettest`: `TestQuarkDataSourceInTheFleet` arranca
  un agente cuya única fuente es el adaptador Quark (sin registro ni base de
  Nucleus) y lo conduce por el servidor como dos tenants. ADR-002 pasa a
  `implemented` con una sección «Ejecución» que nombra el PR y el control
  del banco de cada paso del plan; fila del índice al día.
- **Banco 28 de 50** (datasource 12/0/0, familia completa): `FDS-11`
  endurecida —mide un update: el título viejo a un lado y el nuevo al otro—
  y `FDS-12` a `present`. Dos mutaciones: servidor sin escribir los lados
  (rojo en el create), agente sin devolver el registro previo (rojo en el
  update). Quedan parciales `UI-09` (S10) y `HA-05` (OR-56, S8).
- **El corte de convergencia** (decisión de Carlos, el mismo día): orbit#513
  fusionado → release PR orbit#514 → **orbit v1.14.0, agent/v0.11.0,
  server/v0.16.0, quarkdatasource/v1.12.0** (proto/v0.6.0, datasource/v1.0.0
  y quarkbridge sin cambio), deuda de doc en la rama del bot (notas
  `## v1.14.0` y snapshot; el guard de voz de producto rechazó «ADR-002»
  en las notas y se dijo en prosa —el `tail` había tapado su aviso, regla:
  no encadenar un guard con `tail`—). El árbol de v1.14.0 pasa
  `check_internal_pins.sh` por sí solo: es el que puede pinar el set, con
  `orbit_modules.datasource` en `versions.yaml` y `./orbit/datasource` en
  el go.work del paraguas.
- **Lo que conviene decidir antes de `S6`**: `S6` (retención y export),
  `S7` (alertas) y `S8` (multi-servidor) tocarán el proto casi seguro. Cada
  cambio de proto son dos cortes y, a mitad de arco, un re-pin del set. La
  opción barata es diseñar el proto aditivo de las tres en un solo PR antes
  de `S6` y pagar UN corte, no tres.

### `S4` — el módulo `datasource` y el agente que lo habla (2026-09-21) · **hecha**

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
- **Parte 2, [orbit#511](https://github.com/jcsvwinston/orbit/pull/511)
  (`feat(agent)`)**: `agent/datastudio` reescrito sobre
  `datasource.DataSource` (el camino `model.CRUD` desaparece);
  `agent.Config.DataSource` y `ExtensionConfig.DataSource`, nil = el
  adaptador Nucleus sobre `Registry`/`Databases`. El servidor rellena
  `DataStudioRequest.operator` desde `auth.Identity` en cada petición, con el
  tenant nuevo de la cabecera `X-Auth-Tenant` del proxy de confianza
  (`--ui-tenant-header`, sólo en esa ruta). Bajo ese operador el agente pone
  las claims del framework en el contexto (un hook de modelo ve quién pide),
  aplica la política de la aplicación por modelo y verbo del panel (`list`,
  `retrieve`, `create`, `update`, `delete`, `bulk_delete`) con su
  `Authorizer` (un `*authz.Enforcer` decide; una fuente de sólo filas se
  compila en uno), y confina a un operador con tenant: filtro de igualdad
  sobre la columna de tenant en lecturas, tenant estampado al crear,
  propiedad confirmada antes de actualizar o borrar, y la fila de otro
  tenant es «not found», no «forbidden». Sin operador (servidor viejo), el
  comportamiento anterior. Dos prefijos de error son convención de cable
  que el servidor mapea a códigos: `permission denied:` y `not found:`. El
  cable conserva `values_json` por NOMBRE de campo (lo que indexa la SPA)
  aunque el adaptador emite claves JSON: el handler traduce por nombre y
  columna plegados.
- **Medido y decidido de paso**: nucleus no exporta un setter de tenant en
  el contexto, así que el agente confina por filtro como el panel; el
  modelo casbin de nucleus no trata `*` como sujeto comodín (la política de
  la aplicación decide con su propio enforcer, la compilada sólo cubre
  fuentes de filas). La propiedad fuzz de A3 sobre el estrechado de ids
  (`FuzzParseID`) vive ahora en `datasource/nucleus`, que es quien estrecha.
- **Banco 26 de 50** (datasource 10/1/1): `FDS-05`, `FDS-06`, `FDS-07`,
  `FDS-10` a `present`. Tres mutaciones: el servidor sin rellenar
  `operator` (FDS-05/06/07 en rojo), el agente sin confinar por tenant
  (FDS-07), el agente sin autorizar (FDS-06). Tests unitarios del handler
  con un `DataSource` en memoria con claves JSON, tests del servidor para la
  cabecera de tenant (sólo ruta de proxy de confianza) y el mapeo de códigos.
- **Siguiente: `S5`** (`FDS-11` audit con antes/después, `FDS-12` ADR-002
  cerrado como implementado, `quarkdatasource` registrado en el fleet — que
  ya es posible por `ExtensionConfig.DataSource`). Precondición: orbit#511
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
