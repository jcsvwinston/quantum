# /next-session — arranque de sesión para Quantum (paraguas)

> Comando de arranque para Claude Code en el repo **`quantum`** (el paraguas).
> Audita el estado real de la suite y ancla la sesión al foco correcto.
> No es el `/next-session` de Quark ni el `/resume` de Nucleus: aquí coordinas
> la suite, no tocas el código de los productos.

## 0. Qué es Quantum (recordatorio de una frase)

Suite de tres productos Go que se desarrollan por separado y se coordinan bajo un
paraguas: **Nucleus** (framework web, el host), **Quark** (ORM, usable en solitario)
y **Orbit** (admin que monta in-process en Nucleus). El repo `quantum`
**coordina, no contiene**: fija el trío compatible (`versions.yaml`) y da un
`go.work`. Detalle en [`README.md`](../../README.md) y [`docs/ROADMAP.md`](../../docs/ROADMAP.md).

## 1. Protocolo de arranque (hazlo SIEMPRE antes de tocar nada)

1. **Lee** [`versions.yaml`](../../versions.yaml) (el set certificado vigente) y
   el §3 de abajo (estado vigente + las DOS últimas sesiones; lo anterior
   está archivado en `docs/handoff/` y NO se carga: se busca con grep). [`docs/ROADMAP.md`](../../docs/ROADMAP.md)
   guarda las cinco fases, **todas cerradas** desde Quantum 1.0.0: hoy el
   trabajo entra por **arcos**, no por fases.
2. **Audita el estado real.** Lo de abajo lo resume en un comando, que no
   escribe nada:

   ```
   bash scripts/estado.sh          # set, arcos, próxima sesión, checkout, PRs
   bash scripts/estado.sh --breve  # sólo el titular
   ```

   Lo que hace por dentro, por si hay que mirar una pieza suelta:
   - `git submodule status` — ¿siguen los submódulos en el trío de `versions.yaml`?
   - `git -C quark describe --tags`, idem `nucleus`, `orbit` — ¿coinciden con `workspace_pins`?
   - `go build $(bash scripts/gowork-patterns.sh)` (el root del workspace no es un
     módulo; los patrones explícitos salen del go.work, que cubre los 26 módulos).
   - `gh pr list` y `gh issue list` en los cinco repos (quantum, quark, nucleus,
     orbit, quantum-app) — qué quedó abierto.
   - `scripts/suite-integral.sh` si vas a certificar o sospechas deriva; la lane
     semanal (§5) ya la corre los lunes.
3. **Reconcilia** con el §3: ¿qué arco quedó a medias y cuál es el siguiente?
   Los pendientes con destinatario están en el §5.
4. **Abre el plan del arco**: [`docs/planes/`](../../docs/planes/README.md) lleva
   el contrato de sesión —qué comando responde a cada pregunta, qué NO decide
   una sesión sola, qué deja escrita al terminar— y, por arco, el troceado en
   sesiones con su precondición y su criterio de hecho. **Es lo que hace que
   una sesión pueda trabajar sin recordar la anterior.** El arco siguiente
   tiene su fichero; los demás se trocean al empezarlos, y siempre por una
   sesión de medición: las tres veces que se planificó sin medir, la medición
   corrigió el plan.
5. **Propón el foco** de la sesión (una sesión concreta del arco, no «el
   arco») antes de trabajar, y deja que el responsable lo confirme.

## 2. Reglas duras que NO se rompen (mismas que el brief de Fase 0 y los QADR)

1. **Cada producto en su repo; `quantum` solo coordina** (no contiene código). [QADR-0001]
2. **Versionado en dos niveles**: el número Quantum nunca falsea el `vX.Y.Z` real
   que la gente instala. [QADR-0002]
3. **Docs**: la fuente vive en cada repo; el sitio unificado *ensambla*, no posee. [QADR-0003]
4. **Anti-hype**: sin superlativos de marketing —afirmaciones exageradas de
   madurez o de rendimiento— en commits, README, ADRs ni roadmap. La cultura
   anti-hype se hereda de Quark; el grep de esos términos debe seguir vacío (por
   eso este propio fichero no los nombra en literal).
5. **`go.work` es solo dev local**; sin `replace` en los `go.mod` de los productos.
6. **Quark sigue usable en solitario**; nada lo obliga a depender de Nucleus/Orbit.
7. **Conventional Commits**; trabaja en rama y abre PR (no commitees directo a `main`).

## 3. Estado al cierre (2026-09-26, QUANTUM 1.38.0 — A9 CERRADO; A10 EN CURSO: `S0`–`S2` hechas, el banco del API en 18 de 46; nucleus#578 sin fusionar; siguiente `S3`, los dobles que capturan)

### Estado vigente (léelo entero; es lo único que hace falta para arrancar)

- **Set certificado: Quantum 1.38.0** (2026-09-25, FUERA de cadencia por
  tercera vez seguida, por la misma razón: los cortes de orbit a mitad y al
  cierre de A9 dejan tags de módulo por delante del pin) — quark v1.15.0 y
  nucleus v1.30.1 sin cambio, orbit v1.18.0 con sus SIETE módulos (`ui` es
  el nuevo), tal como los lista `versions.yaml` (la fuente; no copies
  números de aquí). `declared_lags` vacío. **Cierra A9**. El tren enseñó
  tres cosas (sección 1.38.0 de `scripts/train/README.md`): un módulo que
  nace y un consumidor que lo requiere en el mismo corte dejan esa release
  SIN activos si el build exige el go.sum completo (v1.17.0 de orbit; el
  workflow de release resuelve ya como un consumidor, y se comprueban los
  activos de cada corte); la fila nueva del README de un módulo nuevo se
  escribe a mano ANTES de bump-set; y una fixture que doctora «el primer
  `required`» de una lane con dos drivers muerde por la causa equivocada.
- **ANTES DE NADA, abre [`docs/planes/`](../../docs/planes/README.md).** Es el
  contrato de sesión —los cinco comandos que dicen dónde estamos, qué fichero
  manda para cada pregunta, qué NO decide una sesión sola y las tres
  escrituras que deja al terminar— y lleva el troceado del arco en curso. Con
  él, una sesión no necesita reconstruir contexto con criterio propio.
- **Trabajo por arcos del plan 5/5**: A1…A9 CERRADOS (1.28.0 … 1.38.0).
  **A9 (Fleet unificado y una sola SPA) se cerró el 2026-09-25 en Quantum
  1.38.0**, en doce sesiones del 2026-09-20 al 25 (orbit#500 a #527), con el
  banco `orbit/internal/fleettest/fleetbench` de **16 a 50 de 50**, seis
  cortes de orbit (v1.11.0, v1.12.0, v1.13.0, v1.14.0, v1.15.0, v1.16.0,
  v1.17.0, v1.18.0: un cambio de proto son DOS cortes y el arco tocó el
  proto cuatro veces) y tres sets (1.36.0, 1.37.0, 1.38.0). Lo que dejó: la
  identidad del nodo es la del certificado y rota sin reinicio (`S1`–`S2`);
  el contrato `datasource` es un módulo (ADR-012) y el fleet lo habla bajo
  el operador con política y tenant (`S3`–`S4`); el audit dice qué cambió y
  ADR-002 está implementado (`S5`); el servidor retiene con ventana
  (ADR-013) y avisa por umbral (`S6`–`S7`); una flota de servidores comparte
  nodos y eventos y asigna agentes (ADR-014, `S8`); un solo proyecto de
  frontend y el módulo `orbit/ui` embeben el único dist (ADR-015: el PANEL
  es la base, no el fleet, como decía el plan; `S9`); la UI del fleet habla
  connect-es 2, la mide un banco de navegador y muestra el tenant relleno
  (`S10` en dos partes por el corte); y el clúster de tres agentes detrás
  de dos servidores corre en CI, el guard `umbrella-fleet-posture` vigila lo
  publicado y el servidor dice qué agente respondió (`S11`, OR-60). Lo que
  fue, sesión a sesión y con lo que cada una midió, está en
  [`docs/planes/A9-fleet-unificado-una-sola-spa.md`](../../docs/planes/A9-fleet-unificado-una-sola-spa.md);
  A4…A8, en sus ficheros. Cuatro lecciones que valen para el arco
  siguiente: la medición corrigió el enunciado por quinta vez (el mTLS ya
  existía y su identidad se tiraba; «el stack del fleet como base» era la
  SPA débil); **una fila del banco que se retipa a mano se queda rancia
  bajo un titular al día** (la tabla por familias, tres sesiones), así que
  se genera y el guard la compara; **un campo declarado en el cable y vacío
  no es una capacidad** (FDS-09, UI-09 y el `node_id` de Data Studio, los
  tres cazados por sondas que comprueban el relleno); y **un test que pone
  varios nodos donde las sondas ponen uno encuentra lo que ninguna sonda
  puede ver**. Hallazgos abiertos de orbit: **OR-57** (P3, A12: el enlace
  identidad↔certificado es opt-in hasta el major) y **OR-59** (P3, A12: el
  contraste del tema claro del fleet, re-skin sobre los tokens compartidos).
  **A10 (Testing y OpenAPI de primera clase) EN CURSO y TROCEADO** por su `S0`
  de medición (2026-09-25, nucleus#574, `test(apibench)`, sin fusionar): diez
  sesiones en
  [`docs/planes/A10-testing-y-openapi.md`](../../docs/planes/A10-testing-y-openapi.md),
  banco `nucleus/internal/apibench` en **12 de 46** (46 controles en cuatro
  familias: testkit, openapi, http, di; `TestAPIBench` asserta el veredicto
  registrado; `NUCLEUS_API_BENCH_TABLE=1` genera las tablas que
  `nucleus/docs/api-bench.md` pega). Lo que midió y el plan no sabía: el kit
  `nucleustest` arranca la aplicación y no ayuda con nada más (cliente sin
  JSON, sin cookies, sin CSRF, sin sesión, sin factories, sin transacción, sin
  dobles); **el 404 propio del router es el texto plano de Go** incluso con
  `Accept: application/json` (NU-96); el contrato que escribe `nucleus new`
  declara la API abierta y la aplicación generada no lo sirve (NU-97, NU-98);
  `Module.Requires` nombra bases de datos, no módulos, y el arranque es
  alfabético; NU-41 y NU-44 confirmados por sonda. **El gate cambia**: el
  showcase ya no existe, así que se mide sobre el starter de `nucleus new`
  (documento publicado, cliente TypeScript generado que lo consume en un test
  en CI, kit cubriendo el starter, documento en `contracts/baseline`).
  **`S1` hecha** (2026-09-26, nucleus#576, `feat(nucleustest)`, sin
  fusionar): el kit tiene cliente — `Request`/`Get`/`Post`… con
  `Response.JSON`, jarra que conserva las cookies `Secure` sobre loopback en
  HTTP plano, `CSRFToken`/`WithCSRF` (el middleware responde 419), y
  `SignIn`/`SignInAccount`/`SignOut` que abren la sesión en el store de la
  aplicación por scs — `TK-02`…`TK-05` present, banco **16 de 46**. **La
  lane de MinIO de nucleus pasó a RustFS** (nucleus#575): MinIO dejó de
  publicar imagen en Docker Hub, quay.io y GHCR, y la lane `storage-minio`
  estuvo roja del 20 al 26 en todo PR; RustFS fijado por digest, los seis
  `TestS3Live_*` pasan sin tocar el test, el id del job no cambia. Docker
  local está disponible en esta máquina para probar lanes de contenedor.
  **`S2` hecha** (2026-09-26, nucleus#578, `feat(nucleustest)`, sin
  fusionar): `Make[T]`/`MakeN` construyen registros de un modelo registrado
  con defaults desde su metadata y los escriben por `model.CRUD` con el
  dialecto de la app; `Transactional` corre el test entero —rutas incluidas—
  dentro de una transacción que se deshace al final, un nivel por debajo del
  pool (driver por test que entrega UNA conexión; las transacciones de la app
  son savepoints), medido en SQLite, PostgreSQL y MySQL con Docker local y en
  la lane de matriz. Plumbing aditivo: `db.Config.DriverName`,
  `app.DatabaseConfig.Driver`, `db.ResolveDriver`. `TK-06`, `TK-07` present,
  banco **18 de 46**. **Siguiente: `S3`**, los dobles que capturan (correo
  con proveedor `memory` legible desde el kit, almacenamiento, tasks
  encolados, HTTP saliente; `TK-08`…`TK-11`), precondición nucleus#578
  fusionado; `S5` (el documento desde el código), `S8` (binding y errores) y
  `S9` (cableado) pueden ir en paralelo porque tocan paquetes distintos. Trampa dicha por adelantado: casi todo es API pública de
  `pkg/nucleustest`, `pkg/nucleus` y `pkg/router`, que el baseline de
  símbolos y el gate de la allowlist vigilan; lo que no sea Go puro (un
  generador TS) se decide ANTES de escribirse.
  `bash scripts/estado.sh --breve` deriva el arco y la sesión siguientes; no
  los copies de aquí.
  El gate de cada arco sigue siendo el registro
  `docs/auditoria/madurez-2026-09-03/registro.csv` con su guard
  `umbrella-audit-backlog` (cero abiertos en un arco cerrado).
- **Lo que A7 enseñó, y vale para cualquier arco**: **escribir la
  documentación es una MEDICIÓN, y más severa que el banco.** El banco conduce
  el código; la doc obliga a afirmar qué hace, y una afirmación se contrasta.
  Redactar la doc pública que las sesiones debían y las notas de la versión
  destapó **nueve defectos que ninguna de las cuarenta sondas vio**, dos de
  ellos paradas de release (NU-89: una aplicación con su propio `/livez`
  dejaba de arrancar, ruptura en una minor; NU-90: todo stream SSE moría al
  minuto por `write_timeout`). Están en el registro como NU-89…NU-95, OR-54 y
  OR-55. Y el corolario: **OPS-14**, el control de A6 que debía cazar OR-53,
  medía que el endpoint devolviera 200 sobre un panel ciego. Un control cuyo
  título afirma más de lo que su sonda comprueba pasa para siempre.
- **53 guards en el registro**: los 52 de 1.37.0 más
  **`umbrella-fleet-posture`**, el gate de A9 (2026-09-25, en el PR de set
  de 1.38.0 porque sólo al pin nuevo hay qué vigilar): el banco del fleet
  tiene sus 50 controles y ningún hueco sin nota, la cifra que publica
  `orbit/docs/fleet-bench.md` Y su tabla por familias son las que cuenta el
  catálogo (la tabla se retipaba y estuvo tres sesiones rancia), la mitad de
  navegador está en el pin con su violación plantada y el CI de orbit corre
  su driver con `ORBIT_BENCH_BROWSER=required`, y el test del clúster de
  tres agentes está, no se salta, y la lane corre `internal/fleettest`. Los
  guards de postura anclan ahora su `required` al driver que vigilan
  (`admin-posture` al del panel), porque la lane corre dos. Los 52
  anteriores: los 51 de 1.34.0 más
  **`umbrella-quark-posture`**, el gate de A8 (2026-09-20): el banco de quark
  tiene sus 69 controles y ningún ausente sin razón escrita, la cifra que
  publica `quark/docs/enterprise-bench.md` es la que cuenta la tabla, y las
  seis pruebas que el arco añadió a `SharedSuite` siguen corriendo en la lane
  de cada motor — lo único del arco que se mide contra un motor real, porque
  las sondas del banco corren sobre SQLite. El 51º es
  **`umbrella-jobs-posture`**, el gate de A7 (2026-09-19): la cifra que
  publica `nucleus/docs/jobs-bench.md` es la que cuenta la tabla, ningún
  control ausente se queda sin razón escrita, y el CI de nucleus corre DE
  VERDAD la prueba de durabilidad (10 000 jobs, worker muerto a mitad) y la
  cola contra motores reales — un `replace` silencioso ya afirmó una vez haber
  añadido un paso de CI que no estaba. El 50º es
  **`umbrella-admin-posture`**, el gate de A6 (2026-09-18): la cifra que
  publica `orbit/docs/admin-bench.md` es la que cuenta la tabla del banco,
  ningún control ausente se queda sin razón escrita, el instrumento de
  navegador está EN EL PIN y el CI de orbit lo corre con
  `ORBIT_BENCH_BROWSER=required` — sin eso la lane se pone verde cuando el
  navegador falta, que es decir que se midió lo que nadie midió. Los 49
  anteriores eran los de 1.31.0 menos
  `umbrella-quickstart-embeds`, retirado al salir los ejemplos del árbol
  (2026-09-12): resolvía fences `file=` contra `nucleus/examples/showcase_demo`
  y ya no hay árbol contra el que resolver. Lo que comprueba ahora que los
  listados del quickstart sean lo que el scaffold escribe es
  `scripts/ci/check_quickstart_listings.sh`, dentro de la lane que genera el
  proyecto — comparación más fuerte que la anterior, pero en lane, no en el
  registro. Y más **`umbrella-release-assets`**, registrado el 2026-09-15 con
  su fixture: la release de cada tag que el set pina publica DE VERDAD su
  `checksums.txt` firmado (los otros 48 leen el árbol, y un release que falla
  al firmar salía verde — nucleus v1.26.0). Es el único guard que pregunta a
  la red, así que la lane le da `GH_TOKEN`; sin poder preguntar, FALLA.
  `umbrella-auth-posture` (A5) sigue.
- **Cadencia**: set semanal (QADR-0008); un corte fuera de cadencia lleva la
  razón escrita en `status:` de `versions.yaml`.
- **Reglas que ya se decidieron (no reabrir sin motivo nuevo)**:
  - Un `!`/BREAKING CHANGE decide el major de la suite entera (QADR-0002);
    un movimiento de empaquetado con error guiado es minor (ADR-032 de
    nucleus). Nunca se repara con Release-As.
  - **Lo rompiente se acumula en UN major al cierre de A12 (QADR-0010).**
    Hasta entonces se entrega la forma nueva junto a la vieja y se depreca la
    vieja con retirada EN ese major. Un arco que no pueda por adición PARA y
    lo dice, en vez de cortar.
  - El `require` de un hermano es un SUELO (MVS resuelve al máximo); el
    manifest-guard AVISA por los suelos y FALLA por los pines CRUZADOS de
    orbit → `align_set.sh` de orbit tras cortar quark/nucleus (el tren lo
    hace desde 1.28.0). Los suelos módulo→raíz suben como PRIMER commit de
    cada corte (`sube_suelos` en `train.sh`).
  - **Excepción del suelo, aprendida en 1.30.0**: un módulo que SALE del
    módulo raíz no puede llevarlo por detrás —cualquier tag de raíz que aún
    lo contenga deja su paquete provisto por dos módulos y Go se planta con
    `ambiguous import`—, así que nombra el tag que el corte crea. El CI lo
    resuelve con `replace` VERSIONADO en el go.work
    (`quark/scripts/ci/link_workspace.sh`), no con `go work init` a secas.
  - **cosign se queda en la línea v3 del instalador** (cosign v2.x) en los
    cuatro repos, con ignore de Dependabot por nombre y tipo. Su v4 trae
    cosign v3, que cambió `sign-blob`, y eso publicó nucleus v1.26.0 con cero
    activos sin que ningún guard se pusiera rojo.
  - Voz de producto en inglés — código, docs, commits y títulos de PR (guards
    `nucleus/quark/orbit-pr-title-english`): QADR-0009. El paraguas y los
    CLAUDE.md siguen en español.
  - Todo PR de docs de release, guards o baselines entra ANTES del tag.
  - Las deudas de doc por minor (RT-9) se pagan EN la rama del release PR;
    el tren corre el esqueleto de quark solo (`quark-doc-debt.sh`) y escribe
    la sección de una release de alineación de orbit
    (`orbit-align-notes.sh`); las de nucleus (sección + snapshot) siguen
    siendo un PR `docs(release)` antes del tren.
  - El squash de un PR lleva título y cuerpo controlados (`merge-group.sh`):
    un «Palabra: texto» en el cuerpo deja a release-please sin ver el feat, y
    **en squash-only el título del PR ES el commit que llega a main** — el
    tren lo aprendió perdiendo un `fix(deps)` y doce tags de módulo.
- **Dónde está cada cosa**: contrato de sesión y troceado → `docs/planes/`;
  trampas del tren → `scripts/train/README.md` (índice «Trampas
  transversales» + una sección por tren); decisiones → `docs/adr/` y los ADR
  de cada pilar; historia de sesiones anteriores al 2026-09-03 →
  `docs/handoff/sesiones-2026-07-12_a_2026-09-02.md` (grep, no cargar);
  memoria de la sesión de Claude → `~/.claude/projects/.../memory/`.
- **Pendientes con destinatario**: §5.

### Sesión 2026-09-26 — **A10 `S1` y `S2` HECHAS (nucleus#576 fusionado, nucleus#578 sin fusionar) y la lane de MinIO a RustFS (nucleus#575)**: el cliente y los datos del kit, banco 18/46

- **Fusionados por orden de Carlos**: nucleus#574 (`S0`) y quantum#247, tras
  desbloquear el gate de nucleus: MinIO ya no publica imagen en ningún
  registro público (quay.io 401 con token anónimo, Docker Hub sin tags, GHCR
  403) y la lane `storage-minio` llevaba roja desde el 20. **RustFS**
  (fork Apache-2.0 compatible) fijado por digest en `ci.yml`, credenciales en
  `RUSTFS_ACCESS_KEY/SECRET_KEY`, readiness `/health`; probado en local con
  Docker contra el mismo digest: los seis `TestS3Live_*` pasan sin cambios.
- **`S1`**: `pkg/nucleustest/client.go` (+ tests): `Request`/verbos con
  `Response.JSON`; `loopbackJar` (guarda las cookies quitando `Secure`, como
  hace un navegador con localhost — sin eso la cookie de sesión y la de CSRF,
  `Secure` por defecto, se perdían en HTTP plano); `CSRFToken`/`WithCSRF`;
  `SignIn`/`SignInAccount`/`SignOut` vía `Runtime().Session().SCS()`
  (Load/Put/Commit + cookie). Las sondas `TK-02`…`TK-05` ejercitan el cliente
  (sonda que crece cuando aparece la superficie), verificado por dos
  mutaciones. Guía `getting-started/testing.md` con dos secciones nuevas.
  **Trampas**: un módulo sin `Prefix` monta en la raíz; el rechazo CSRF es
  419; `git checkout <fichero>` para deshacer una mutación se llevó también
  la jarra (reaplicada); un PR apilado sobre otro squash-mergeado se rebasa
  con `--onto` soltando los commits ya fusionados; y **la jarra cambió lo que
  medía un contrato**: `TestSecurityPosture_MatchesBaseline` leía los
  `Set-Cookie` de una petición hecha con el cliente del kit, que ahora ya
  llevaba la cookie `_csrf` del sondeo de readiness, así que el middleware no
  ponía nada y la postura salía «(no cookies set)» sin haber cambiado — la
  sonda usa ahora un cliente sin jarra, porque mide el primer contacto.
- **`S2` en la misma sesión** (nucleus#578, tras fusionar #576 y quantum#248
  por orden de Carlos): `pkg/nucleustest/factory.go` (`Make[T]`, `MakeN`) y
  `txdb.go` (`Transactional` + el driver transaccional: `Open` comparte una
  conexión con la transacción abierta, `BeginTx` → `SAVEPOINT`, mutex por
  llamada, no durante la iteración de filas — la limitación de una conexión
  la dice la guía). Probado en local con Docker (PostgreSQL 16 y MySQL 8) y
  la lane `db-matrix` corre `TestTransactionalOnTheMatrixDatabase`. Dos
  mutaciones verificadas (commit en vez de rollback → TK-07 partial; `Make`
  sin insertar → TK-06 partial). **Trampas**: en SQLite cerrar la conexión ya
  deshace la transacción, así que «sin rollback» no es una mutación que
  muerda (usar commit); `git checkout <fichero>` no restaura un fichero
  NUEVO sin commitear (la mutación se quedó puesta hasta reaplicar el
  original); en MySQL el DDL hace commit implícito → el test de matriz crea
  la tabla FUERA del scope; los drivers pgx y mysql son deps de la raíz
  (clasificación de errores) y se registran en un `_test.go` del kit.
- **Siguiente**: fusionar nucleus#578 y arrancar `S3`.

### Sesión 2026-09-25 (segunda) — **A10 `S0` HECHA (nucleus#574, sin fusionar)**: el banco del API en 12 de 46, tres hallazgos (NU-96, NU-97, NU-98) y el troceado de diez sesiones

- **Fusionado** quantum#246 (cierre de A9) por orden de Carlos; `estado.sh`
  derivó A10 sin troceado.
- **El banco** `nucleus/internal/apibench`: 46 controles en cuatro familias,
  modelado sobre `jobsbench` (arnés, env con un módulo mínimo `bench`,
  sondas) y sobre `fleetbench` (generador de tabla con resumen por familias,
  gitignored). Las sondas de un helper que no existe preguntan al conjunto de
  métodos del kit y al fuente bajo los nombres de los demás kits, y dejan
  escrito qué buscaron. **Trampas del propio banco**: el runtime de jobs es
  nil hasta que un módulo registra un job (la sonda TK-10 monta uno);
  `Module.Requires` son alias de BD, no módulos; el paquete del proveedor de
  tasks en memoria se llama `memoryprovider`; una regex que casaba
  `ModuleSpec` daba un falso present en TK-15. Verificado por mutación
  (HT-01 baja a partial sin el tag `validate`). `make check` de nucleus en
  verde.
- **Lo que midió**: 12/46. El kit arranca y no ayuda; el 404 del router es
  texto plano de Go en todas partes (NU-96); el contrato del scaffold dice
  «abierta» y la app generada no lo sirve (NU-97, NU-98); NU-41 y NU-44
  confirmados. El gate pasa del showcase (borrado el 2026-09-12) al starter.
- **Escrituras**: plan `A10-testing-y-openapi.md` con el troceado en diez
  sesiones y el registro con tabla legible por `estado.sh`; fila de A10 en
  `docs/planes/README.md`; RUMBO; registro NU-96/97/98 (A10, abiertos) con
  sus filas en `nucleus.md`; memoria.
- **Siguiente**: fusionar nucleus#574 y arrancar `S1` (el cliente del kit).


## 4. Las fases (resumen; el detalle y el "hecho cuando" están en docs/ROADMAP.md)

> **Las cinco fases están CERRADAS** desde Quantum 1.0.0 (2026-07-11): los tres
> pilares en major 1 bajo un manifiesto de suite, con régimen de majors en
> lockstep (QADR-0002). La tabla queda como referencia histórica; el trabajo
> nuevo entra por arcos (§5) bajo el régimen de auditoría continua.

| Fase | Objetivo | Hecho cuando |
|---|---|---|
| 1 | **Identidad/marca Quantum**, portada de la suite | Front page que nombra y enlaza los tres pilares y aclara el uso standalone de Quark |
| 2 | **Docs unificadas**: Docusaurus multi-instancia en `website/`, product switcher, doble selector de versión, un solo deploy en `/quantum/` | Un sitio sirve las tres docs bajo una marca, sin sacar la fuente de cada repo |
| 3 | **Convenciones + primera release**: `release-please` a Nucleus/Orbit, instancia de docs de Orbit, **Quantum 0.1.0** con CI de integración | Set Quantum reproducible y verificado por CI |
| 4 | **Integración demostrada**: ejemplo Nucleus+Quark+Orbit + CI que ejerce los tres | Hay un ejemplo ejecutable y CI del set |
| 5 | **Convergencia Quantum 1.0**: Nucleus y Orbit a v1.0, régimen de majors en lockstep | Los tres en major 1 bajo un manifiesto Quantum 1.0 |

## 5. Pendientes técnicos anotados (revísalos cuando apliquen)

> Puesto al día el 2026-09-05. Lo que esta sección listaba antes (integración
> Quark↔Orbit de QADR-0005/0006, pin de nucleus en `8714882c`, `status:
> pre-fusion`, retirada de los Pages standalone de los productos, y el plan de
> extensibilidad A–H, cerrado en Quantum 1.22.0) está **todo hecho y publicado**: los tres pilares llevan desde Quantum 1.0.0 (2026-07-11)
> en major 1 con los pines EN TAG, `quarkbridge`/`quarkdatasource` van en el
> set (v0.4.0 / v0.2.14) y `jcsvwinston.github.io/{quark,nucleus,orbit}` ya
> sirven el redirector al sitio unificado. El histórico de cómo se llegó ahí
> vive en el §3 y en `docs/auditoria/`.

**`quantum-app` NO frena nada (decisión de Carlos, 2026-09-20).** Mientras el
plan 5 de 5 siga abierto, nada de lo que le ocurra a `jcsvwinston/quantum-app`
bloquea un arco, un corte ni una certificación: se **rehará entero** al
terminar el plan, así que arreglarlo set a set es trabajo que se tira. Sus
gates en rojo y sus PRs de bump sin fusionar —cuatro abiertos desde 1.30.0— se
anotan y se sigue. Lo único que hay que distinguir es «deuda suya» de «el set
recién cortado rompió al consumidor»: lo segundo SÍ es hallazgo del release.
No se abren sesiones ni arcos para ponerlo al día. El detalle está en
`scripts/train/README.md`, en la sección del anuncio.

**Trabajo con destinatario (por orden de arranque):**

- **El plan a 5 de 5** manda el orden: ~~A1~~ … ~~A8~~ CERRADOS (1.28.0 …
  1.35.0) → **A9 (Fleet unificado y una sola SPA), EN CURSO y TROCEADO** por
  su `S0` de medición (2026-09-20/21, orbit#500): doce sesiones en
  [`docs/planes/A9-fleet-unificado-una-sola-spa.md`](../../docs/planes/A9-fleet-unificado-una-sola-spa.md),
  `S0` hecha, siguiente `S1` → A10 … → A12. El registro de hallazgos y su
  guard (`umbrella-audit-backlog`) siguen siendo el gate de cada arco; A6, A7
  y A8 lo cerraron con el suyo propio (`umbrella-admin-posture`,
  `umbrella-jobs-posture`, `umbrella-quark-posture`) y A9 propone
  `umbrella-fleet-posture` para el suyo (`S11`). Hallazgos abiertos:
  **OR-56** (P2, A9, el stream superseded que no se termina) y **OR-57**
  (P3, A12, el enlace identidad↔certificado nace opt-in).
- **Los hallazgos que abrió A7, todos CERRADOS en 1.34.0** (queda como mapa de
  qué sesión cerró qué; todos en nucleus salvo uno): **NU-78** (P2,
  `EmitAsync` bloquea al emisor con el techo de concurrencia lleno), **NU-79**
  (P2, un pánico en un handler síncrono se lleva a quien emitió; el `recover`
  sólo cubre el asíncrono), **NU-80** (P2, el proveedor por defecto descartaba
  un job cuyo tipo nadie maneja — **arreglado en nucleus#550**, pendiente de
  fusión), **NU-81** (P3, cero métricas de jobs fuera de asynq, y ninguna del
  outbox) y **NU-82** (P3, el `Inspector` por defecto devuelve ceros). Más los
  dos que verificó `S1`: **NU-83** (P2) y **OR-53** (P2), que son las dos
  mitades de lo mismo — **la vista de colas que A6 entregó es inalcanzable**
  porque `orbit.Config` no tiene por dónde recibir un `tasks.Inspector` y
  `nucleus.Runtime` no expone ninguno. Cada uno tiene su sesión asignada en el
  troceado; NU-83 y OR-53 van a `S3`.
- **Lo que A4 dejó a deber, con su porqué escrito**: la segunda mitad de su
  `S4` —uuid nativo, enums con CHECK, arrays de PostgreSQL, rangos, inet,
  JSONB— no está en el gate del arco y encaja en A8, que ya lleva los tipos
  enterprise. Y **QK-24** (un `GROUP BY` sin proyección deja `SELECT *`,
  inválido fuera de SQLite y MySQL permisivo) avisa desde quark v1.14.0 pero
  no es error: convertirlo rompe a quien depende de esos motores, así que se
  movió a **A12**, donde QADR-0010 acumula lo rompiente.
- **Todo A6 está FUSIONADO y publicado**: del banco (orbit#467) al gate, con
  las once sesiones y sus dos releases de orbit (**v1.10.0**, que publica el
  arco, y **v1.10.1**, que publica OR-51 y existe porque un fix de módulo
  hermano no puede salir por delante de la raíz). Los PRs, por sesión, están
  en el plan del arco; los del paraguas van de **quantum#189** a
  **quantum#205**.
- **Lo que aprendió el tren de A6** está en el §3 y en
  `scripts/train/README.md`: el perfil `scaffold-mvc` del arnés de nucleus no
  podía pasar en NINGUNA rama de release-please hasta nucleus#546; la rama de
  un release PR no se regenera con un commit que release-please no considera
  publicable (y `gh pr update-branch` es además el disparador de su CI); y un
  fix de módulo hermano necesita un cambio del paquete raíz con `Release-As:`
  para no quedar por delante del set.
- **OR-51 CERRADO** (orbit#490, publicado en `quarkdatasource v1.9.1`):
  implementa `datasource.OperatorFilterSource`, así que el panel montado
  sobre Quark contesta los filtros con operador en vez de rechazarlos. Entró
  **tras** la release v1.10.0 de la raíz, que es la que publica
  `datasource.Filter` — la dependencia topológica que el hallazgo describía.
  Dos refusals que se quedan: un operador no expresable se rechaza por su
  nombre, y un comodín en `contains`/`startswith`/`endswith` se rechaza en
  SQLite y Oracle (QK-25) en vez de ensanchar la búsqueda.
- **OR-52, nacido y CERRADO en `S9`**: el id de un export es su clave de
  almacenamiento, que lleva barra, así que `GET /api/exports/{id}` —un solo
  segmento— nunca casó con los ids que el propio panel emite; caía al
  fallback de la SPA y volvía como `200 text/html`, y por eso **el banco
  daba OPS-15 por bueno desde `S0` leyendo una página web**. Sólo se ve al
  cerrar OR-48. La ruta toma `{id...}`. La lección quedó escrita en
  `orbit/docs/admin-bench.md`: en ese panel un 200 no es evidencia hasta que
  algo del cuerpo lo es.
- **NU-77, nacido el 2026-09-17 (P2, arco A7) — y tumbó `main` de orbit**:
  una aplicación que arranca un **outbox sobre SQLite puede fallar el
  arranque**. `app.New` lanza el dispatcher (primera pasada **inmediata**,
  poll de 1 s) ANTES del `OnStart` de los módulos, que es donde se hace
  `AutoMigrate`; y como el DSN de sqlite se pasa pelado, `busy_timeout` queda
  en **0**, así que la contención no espera: falla con `SQLITE_BUSY`. Lo
  destapó el banco de admin al fusionar `S9` (orbit#484), **no un test de
  nucleus — nada en nucleus cubre outbox + SQLite**. No reproduce en macOS
  (0/12 bajo carga, 0/6 con `GOWORK=off`); sí en el runner Linux. El arnés lo
  esquiva pidiendo `busy_timeout` en su DSN (orbit#485), que es el arnés
  haciendo usable SQLite con dos escritores — **el defecto de producto sigue
  abierto**.
- **NU-76, nacido en `S9` (P3, arco A7)**: `outbox.InspectRuntime` cuenta
  TODOS los topics a la vez y no hay forma pública de contar uno solo (ni de
  leer el último error de entrega), así que la vista de correo del panel
  **declara su alcance** en el payload en vez de fingir uno más estrecho.
  Replicarlo dentro de orbit duplicaría el quoting por dialecto del
  framework. Va a A7 (jobs, eventos y tiempo real), NO al gate de A6.
- **QK-25, nacido en `S5` de A6 (P2, A8 → su `S2`)**: el builder de quark no puede emitir
  `LIKE … ESCAPE`, y SQLite y Oracle no tienen escape por defecto, así que un
  `%` en el valor ensancha. `quarkdatasource` rechaza esa consulta en esos dos
  motores en vez de contestarla mal; **la caja de búsqueda arrastra el mismo
  defecto y no se tocó**, porque cambiarla altera el comportamiento de una
  función publicada. Por la ruta de nucleus el escape sí funciona.
- **Lo que `S2` deja dicho y ninguna sesión debe reabrir sin motivo nuevo**:
  los verbos globales `export_data` / `import_data` (sobre `admin:*`) **no**
  llevan alcance de fila ni de campo — conceder uno a un operador confinado
  es darle el rodeo, y quien lo concede lo decide—; el rastro de auditoría
  guarda los valores con sus propias reglas de redacción, así que un campo
  prohibido por política puede seguir siendo legible para quien tenga
  `audit_view`; y el feed en vivo no filtra por estas políticas. Está en el
  ADR-007 de orbit y en la doc pública, no sólo aquí.
- **La trampa que se coló hasta `main`**: la sonda AUD-05 preguntaba si el id
  del registro aparecía **en cualquier parte** del payload de auditoría. Un id
  es un número corto y casa con un timestamp: pasó en el PR y tumbó el CI de
  `main` al fusionar, con los ids ya distintos. En este banco, `Contains`
  sobre un payload no es una medición — se busca LA entrada (acción, modelo,
  record_id). Está escrito en `orbit/docs/admin-bench.md` con las otras
  cuatro.
- **`NU-50` nombra DOS hallazgos distintos en el registro** (visto el
  2026-09-17): uno P3 sin arco sobre `internal/cli/configcommands.go` y otro
  P2 de A4 sobre `pkg/model/meta.go` frente al esquema de quark. Los dos
  están `hecho`, así que hoy no falsea ningún recuento de abiertos, pero el
  registro es la fuente de verdad del gate de cada arco y un id que nombra
  dos cosas hace ambigua cualquier evidencia que lo cite. `umbrella-audit-backlog`
  no comprueba unicidad de id — añadirla es de una línea. Renumerar uno de
  los dos toca los informes que lo citan, así que la decisión (cuál se
  renumera, o si se deja con una nota) no la toma una sesión de arco sola.
- **`umbrella-built-links` se pondrá ROJO EN EL PRÓXIMO TREN, no antes**
  (medido el 2026-09-17, y conviene no confundirlo con un rojo de hoy). El
  guard resuelve los enlaces a repos propios **contra el checkout de los
  submódulos**, y en CI ese checkout es el PIN DEL SET: en `nucleus
  v1.28.0` el directorio `examples/` **todavía existe**, así que la lane
  pasa. En `v1.29.0` ya no está — se borró el 2026-09-12, después de cortar
  v1.28.0 —, de modo que **en cuanto un set pine v1.29.0 la lane se pone
  roja** por dos enlaces: `examples/mvc_api` desde
  `/nucleus/1.15.0/getting-started/project-structure/` y
  `examples/showcase_demo` desde el `intro` de `/orbit/1.9.0/`. En un
  checkout local con los submódulos por delante del set (como el de esta
  sesión) ya falla, y ese es el aviso.
  **Y los dos viven en doc ARCHIVADA** (`website/versioned_docs/version-…`),
  donde cuando se cortó cada snapshot la ruta existía: arreglarlos sería
  reescribir un archivo que existe precisamente para no reescribirse (regla
  en el `CLAUDE.md` de orbit y en el hueco declarado de 1.6.7), y silenciar
  el guard perdería los enlaces rotos de la doc VIVA, que es lo que sí hay
  que cazar. **La decisión es del guard**: excluir los enlaces que nacen
  bajo `versioned_docs/`, o resolverlos contra el tag del snapshot en vez de
  contra el pin. Cualquiera de las dos es un cambio pequeño, pero elegir
  cuál no lo decide una sesión de arco sola — y hacerlo ANTES del tren
  ahorra un rojo a mitad de corte.
- **Lo que sigue esperando al propietario, y ninguna sesión puede cerrar**:
  proteger `main` en quark, orbit y quantum exigiendo `CI Required Gate`
  (sólo nucleus la tiene); activar `allow_auto_merge` en los cuatro (medido
  en `false` el 2026-09-10, y sin él la auto-fusión de Dependabot no se arma);
  hacer pública la imagen del CLI en Packages de nucleus; aprobar la corrida
  de quantum-app#21 (queda en `action_required`); y decidir quark#369, que
  sube el `go` mínimo a todos los consumidores de quark.
- **Deuda con fecha de vencimiento, ya vencida y pagada**: los cinco guards
  que A3 dejó escritos esperando a que el pin los contuviera
  (`quark-action-pins`, `nucleus-action-pins`, `orbit-action-pins`,
  `umbrella-deprecations` y `umbrella-supply-chain`) entraron en el set 1.30.0
  con sus fixtures, y con ellos entró el guard de suelos de Dependabot que
  orbit trae en ese mismo pin: el registro pasó de 41 a 47. Sus playbooks de
  `docs/handoff/` se borraron con ellos: eran instrucciones pendientes, y
  dejarlas leería como si aún lo estuvieran.
- **Pendiente de Carlos**: fusionar quantum-app#14 (bump a 1.28.0; sus gates
  ya pasan con los imports de módulos y los doce paquetes clasificados) y
  cerrar quantum-app#13. El paso 2 de QK-8 (quark#352) y la mitad nucleus de
  OR-43 (nucleus#476) salen con la siguiente release de cada pilar. La
  deuda del tren de 1.28.0 (`align_set.sh` de orbit antes de su fase) quedó
  pagada el mismo día: `alinea_pines_orbit` en `train.sh`.
- **QADR-0009 firmado** (2026-09-08): el idioma va por SUPERFICIE. Producto
  (código, comentarios, docs, commits, títulos y cuerpos de PR) en inglés;
  paraguas (commits, PRs, QADRs, informes, runbooks, notas del manifiesto) en
  español; el sitio publicado sigue en inglés por QADR-0007, que queda
  enmendado en su alcance. Los ADRs de los productos quedan FUERA: cada repo
  mantiene su idioma (nucleus inglés; quark y orbit español).
- **Lo que deja a deber el arreglo del auto-bloqueo**: la prueba en vivo. El
  próximo release PR de raíz sola en cualquiera de los tres repos debe
  etiquetar sin receta; si vuelve a fallar, el diagnóstico está en la
  cabecera de `scripts/train/untag-recipe.sh` y el driver aplica la receta.
- **Backlog DX abierto** (del diagnóstico de los arcos DX y DX-2): `quark
  migrate diff`, clasificación de errores exportada de quark
  (`IsUniqueViolation` — hoy degrada a `lib/pq`), ayuda del CLI de nucleus,
  `doctor` unificado, `profile: dev` visible, snapshots de quark congelados,
  índice de ADRs, y la **capa 3 de automatización de docs**: la que REDACTA la
  narrativa, no solo la que mueve versiones (capas 1 y 2 hechas —
  `scripts/bump-set.sh` con `set-notes.py`, `cut_docs_snapshot.sh` + guard de
  frescura; el esqueleto de notes con `REDACTAR` es estructura, no redacción).
- **Roadmap enterprise de nucleus**: Tracks **F** (cloud — Secrets Manager/KMS/
  Lambda, Pub/Sub, Service Bus) y **G** (tooling — doctor unificado, wizard,
  asistentes de migración) siguen abiertos. El **Track E** (seguridad) se cerró
  con evidencia en Quantum 1.16.0.
- **quark**: cierres **S8/S9** pendientes.

**Deuda DECLARADA por escrito (no es olvido; no reabrir sin motivo nuevo):**

- **quark#265** — binder generado de codegen (F6-3b), aplazado por disposición
  escrita. Reabrir solo por type-safety o corrección, no por estética.
- **Rate limiting apagado por defecto** (nucleus): voltear
  `rate_limit_requests: 0` haría que cada despliegue existente empezara a
  rechazar tráfico al actualizar → pertenece a una **major con ventana de
  deprecación**. Escrito así en el roadmap de nucleus (Track E).
- **Huecos del archivo de documentación**: el de orbit empieza en 1.6.7. No se
  fabrican snapshots retroactivos — uno afirmaría que la doc de hoy fue la de
  entonces, justo lo que el mecanismo existe para impedir.

**Vigilancias abiertas (nada que hacer hoy; qué mirar si rebrota):**

- **Flake NO cerrado**: pánico `-race` en el teardown de `pkg/outbox` de nucleus
  (`database/sql.(*Rows).close→awaitDone`), visto UNA vez en CI y no
  reproducible en local. El `Stop` grácil de v1.11.0 elimina el disparador más
  plausible y arregla un abandono real de entregas a medio pase, pero **no se
  declara arreglado**; hay canario de 50 ciclos Start/Stop en la suite. Si
  rebrota: `GOTRACEBACK=all` en linux/amd64, y para recuperar el trace de un
  intento anterior `gh api repos/<r>/actions/runs/<id>/attempts/1/jobs` — un
  rerun verde ESCONDE el pánico (`gh run view` solo enseña el último intento).
- **Prosa que FUE verdad**: la clase de hallazgo que ningún guard caza (la web
  anunciando como «en despliegue» algo que llevaba meses corriendo). Al tocar
  una feature, mirar la página que la describe.

**Régimen operativo vigente (desde Quantum 1.9.0):**

- Certificar = lane semanal verde + CI por repo verde + juicio humano por
  disparadores. **Ya no hay rondas completas de auditoría**; el trabajo entra
  por arcos. Runbook: [`docs/AUDITORIA_CONTINUA.md`](../../docs/AUDITORIA_CONTINUA.md).
- `suite-integral.yml` corre los **lunes 06:00 UTC** e `integration.yml` a las
  **06:30**; una lane roja abre issue automático —y `umbrella-schedule-notify`
  exige ese aviso en toda lane con `schedule:`—. Hoy hay **41 guards**
  registrados y `guard-of-guards` prueba con fixture que cada uno muerde.
- Escribir el set: `scripts/bump-set.sh` (submódulos al tag, los bloques de
  módulos, pins y tablas del README, y desde 1.27.0 la versión de suite por
  QADR-0002, las notes anteriores al CHANGELOG y el esqueleto de las nuevas
  con `REDACTAR`, que `manifest-guard` §0 rechaza hasta redactarlo); el juicio
  lo pone `manifest-guard.sh` después. La
  corrida `suite-integral.sh --cierre` va **TRAS** el tag de suite (QM7-3), y el
  pre-check exige árbol limpio (`QUANTUM_ALLOW_DIRTY=1` solo para iterar en
  local).
- Al cerrar un arco, el snapshot de docs se corta **el último** de los cambios
  de la ronda. El re-pin del showcase ya no existe: los ejemplos salieron del
  árbol el 2026-09-12 y con ellos el paso del tren que los re-pinaba.

## 6. Cómo cerrar la sesión

Actualiza el §3 de este archivo (estado al cierre) con lo que avanzaste y el
próximo foco, para no romper el contexto a la siguiente sesión — entrada nueva
ARRIBA, no al final. El §3 lleva el bloque «Estado vigente» (actualízalo) y
como mucho DOS sesiones: al añadir la nueva arriba, mueve la más vieja, tal
cual, al final de `docs/handoff/sesiones-…md` (o abre un archivo nuevo por
rango de fechas) — `bash scripts/check_handoff_size.sh` lo exige y la lane
lo corre. Si un pendiente del §5 se cierra o nace uno nuevo, tócalo
allí en el mismo cambio: un §5 rancio contradice al §3 y desorienta más que la
ausencia de nota.

Si cambia una decisión de coordinación, abre un QADR sucesor (no reabras uno
aceptado).
