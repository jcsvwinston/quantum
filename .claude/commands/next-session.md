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

## 3. Estado al cierre (2026-09-18, QUANTUM 1.33.0 — A6 CERRADO; A7 arrancado, TROCEADO y con `S0` y `S1` hechas)

### Estado vigente (léelo entero; es lo único que hace falta para arrancar)

- **Set certificado: Quantum 1.33.0** (2026-09-18) — quark v1.14.0 (sin
  cambio), nucleus v1.29.0, orbit v1.10.1 y sus módulos, tal como los lista
  `versions.yaml` (la fuente; no copies números de aquí). `declared_lags`
  vacío. Publica el arco **A6**.
- **ANTES DE NADA, abre [`docs/planes/`](../../docs/planes/README.md).** Es el
  contrato de sesión —los cinco comandos que dicen dónde estamos, qué fichero
  manda para cada pregunta, qué NO decide una sesión sola y las tres
  escrituras que deja al terminar— y lleva el troceado del arco en curso. Con
  él, una sesión no necesita reconstruir contexto con criterio propio.
- **Trabajo por arcos del plan 5/5**: A1, A2, A3, A4, A5 y **A6 CERRADOS**
  (1.28.0, 1.29.0, 1.30.0, 1.31.0, 1.32.0, 1.33.0) → **A7 EN CURSO** (jobs,
  eventos y tiempo real): su `S0` de medición está hecha y el arco **ya tiene
  troceado** en
  [`docs/planes/A7-jobs-eventos-tiempo-real.md`](../../docs/planes/A7-jobs-eventos-tiempo-real.md)
  —doce sesiones—; `S0` (medición) y **`S1` (la cola deja de perder trabajo)
  HECHAS**; **siguiente: `S2`**, el proveedor SQL durable, cuya precondición es
  que **nucleus#550 esté fusionada**. A7 lleva **nueve hallazgos abiertos**:
  los dos heredados de A6 —**NU-77** (P2, arranque con outbox sobre SQLite) y
  **NU-76** (P3, contar un topic)—, los **cinco que abrió la medición**
  (NU-78, NU-79, NU-80 —arreglado en nucleus#550, pendiente de fusión—, NU-81,
  NU-82) y los **dos que verificó `S1`**: **NU-83** (P2) y **OR-53** (P2), las
  dos mitades de que la vista de colas que A6 entregó sea **inalcanzable** en
  una aplicación real — `orbit.Config` no tiene por dónde recibir un
  `tasks.Inspector` y `nucleus.Runtime` no expone ninguno, así que el panel
  contesta `enabled:false` con «task inspector not configured (check
  redis_url)» y 400 en las acciones. Van a `S3`. Lo que fue A6, sesión a sesión y con lo que cada una midió, está en
  [`docs/planes/A6-orbit-admin-de-producto.md`](../../docs/planes/A6-orbit-admin-de-producto.md);
  A4 y A5, en sus ficheros.
  `bash scripts/estado.sh --breve` deriva el arco y la sesión siguientes; no
  los copies de aquí.
  El gate de cada arco sigue siendo el registro
  `docs/auditoria/madurez-2026-09-03/registro.csv` con su guard
  `umbrella-audit-backlog` (cero abiertos en un arco cerrado).
- **50 guards en el registro**: los 49 de 1.32.0 más
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

### Sesión 2026-09-18 (noche) — **A7 `S1`**: la cola deja de tirar trabajo, y una revisión adversarial caza nueve defectos del primer borrador

- **`S1` hecha** (nucleus#550, CI verde, **pendiente de fusión**). El banco pasa
  de **12 a 15 de 40** y la familia de cola de 4 a 7. **NU-80 cerrado.** Los
  tres caminos por los que el proveedor por defecto perdía trabajo **con el
  proceso vivo** —tipo sin handler, reintentos agotados, cancelación entre dos
  reintentos— ahora retienen; el apagado drena lo que quedaba y un job diferido
  se retiene a sí mismo.
- **Dos almacenes con presupuesto separado** (un tipo mal escrito no puede
  desalojar a los muertos; `purge-archived` vacía sólo la dead letter), **dos
  acciones implementadas y cuatro rechazadas por su nombre** con la palabra
  `unsupported` que Orbit necesita para contestar 400, y **cero símbolos nuevos
  en `pkg/tasks`** — el paquete del proveedor no está congelado, así que no hubo
  baseline que regenerar. La pausa queda fuera a propósito.
- **El método que hay que repetir**: diseño por panel (tres diseños
  independientes, nueve jueces) y luego **revisión adversarial del diff** (seis
  lentes, tres escépticos por hallazgo: 37 en bruto, 20 confirmados). Encontró
  **nueve defectos reales en mi primer borrador**, tres de ellos graves: que
  `putBack` recortaba por el extremo equivocado y **una pulsación de
  `retry-archived` podía destruir 1 000 jobs retenidos diciendo que seguían
  retenidos**; que los dos almacenes se fundían al reencolar, de modo que el
  `purge` siguiente borraba lo que sólo esperaba handler; y que **mi propia
  sonda JOB-08 era flaky** y habría dado por bueno un reencolado sin verlo
  correr. Nada de eso lo habrían cazado los tests que yo había escrito.
- **Y un defecto preexistente que salió a la luz**: `Run` hace `wg.Add`
  mientras `Close` hace `wg.Wait` — carrera reproducible con `go Run(ctx)` +
  `Close()`, confirmada bajo `-race`. Arranque y cierre quedan serializados,
  con test de regresión.
- **Corrección a lo que `S0` publicó**: escribí que el panel de A6 «enseña
  ceros porque el `Inspector` por defecto los devuelve». Verificado en el
  código, es inexacto y **peor**: `orbit.Module` nunca asigna `TaskInspector` y
  `orbit.Config` no tiene campo para recibirlo, así que la vista de colas es
  **inalcanzable**. Registrado como **OR-53** y **NU-83** (sus dos mitades), y
  la nota de NU-82 corregida.
- **Siguiente: `S2`** — el proveedor SQL durable. Su primera decisión, escrita
  en el plan, es **dónde vive el módulo** (dentro del raíz cuesta dependencias a
  todo consumidor; fuera cuesta tag y suelo en cada corte, ADR-030/031).

### Sesión 2026-09-18 (tarde) — **A7 arranca**: la medición dice 12 de 40, y reescribe el plan en cinco sitios

- **`S0` de A7, hecha** (nucleus#549 + el PR del paraguas de esta sesión). El
  banco vive en `nucleus/internal/jobsbench` y su página es
  `nucleus/docs/jobs-bench.md`: **40 controles, 12 presentes, 4 parciales, 24
  ausentes** (queue 4/2/7, events 6/0/6, realtime 1/2/5, ops 1/0/6). Mismo
  método que `authbench` y `adminbench`: el test asserta el **veredicto
  registrado**, no el éxito. **El set NO se mueve**: `S0` mide, no corta.
- **Cinco correcciones al plan escrito, y ninguna se sabía leyéndolo**: (1) la
  cola **pierde trabajo con el proceso vivo** —un job cuyo tipo nadie maneja se
  descarta (NU-80)—, así que hay una sesión ANTES del proveedor durable; (2) el
  **panel que A6 acaba de publicar enseña ceros**, porque el `Inspector` del
  proveedor por defecto los devuelve (NU-82) y Orbit consume ese mismo
  inspector — no hay que escribir dashboard, hay que darle datos; (3) el bus
  **ya tiene `recover` y límite, y los dos están mal puestos**: el recover sólo
  cubre el camino asíncrono (NU-79) y el límite se toma en la goroutine del
  emisor, así que `EmitAsync` **bloquea a quien emite** (NU-78); (4) **cero
  series de métricas** medidas con un lector manual mientras un job corría
  (NU-81); (5) **NU-77 deja de ser un flake**: `PRAGMA busy_timeout` da 0 y la
  tabla del outbox ya existe cuando corre el primer `OnStart` — dos assertions
  deterministas en macOS, donde la carrera no reproduce.
- **El gate escrito de A7 no se podía cumplir tal cual**: pedía «dashboard con
  datos reales en el showcase», y el showcase salió del árbol el 2026-09-12.
  El troceado lo sustituye por un canal con clientes concurrentes en CI, y deja
  las otras dos patas (banco sin ausentes sin razón; 10 000 jobs con caída a
  mitad y cero pérdidas).
- **Cuatro sondas se reescribieron antes de publicar nada**, porque medían menos
  de lo que su título decía —la lección AUD-05 de A6, en cuatro formas nuevas—:
  preguntar `/metrics` mide que el exportador es un módulo opcional, no si los
  jobs están instrumentados; ver un mensaje `pending` no mide un reintento;
  construir un relay con config vacía y leer su error no es entrega; y
  comprobar que el runtime expone un outbox no mide ningún orden de arranque.
  Quedan escritas en `nucleus/docs/jobs-bench.md`.
- **Y una trampa de API que costó cuatro minutos de suite colgada**:
  `signals.RedisRelay.ForwardToBus` **bloquea** —es el bucle de recepción, no
  una suscripción que devuelve—, así que una sonda que lo llamó en línea colgó
  el test hasta el timeout.
- **Siguiente: `S1` de A7** — que la cola deje de perder trabajo (JOB-07,
  JOB-08, JOB-10; cierra NU-80). Su precondición es que el banco pase, o sea
  que **nucleus#549 fusionado**.

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

**Trabajo con destinatario (por orden de arranque):**

- **El plan a 5 de 5** manda el orden: ~~A1~~, ~~A2~~, ~~A3~~, ~~A4~~, ~~A5~~ y
  ~~A6~~ CERRADOS (1.28.0, 1.29.0, 1.30.0, 1.31.0, 1.32.0, 1.33.0) → **A7
  (jobs, eventos y tiempo real), EN CURSO y TROCEADO** por su `S0` de medición
  (2026-09-18): doce sesiones en
  [`docs/planes/A7-jobs-eventos-tiempo-real.md`](../../docs/planes/A7-jobs-eventos-tiempo-real.md),
  siguiente `S1` → A8 … → A12. El registro de hallazgos y su guard
  (`umbrella-audit-backlog`) siguen siendo el gate de cada arco; A6 lo cerró
  con el suyo propio, `umbrella-admin-posture`, y A7 propone
  `umbrella-jobs-posture` para el suyo.
- **Los hallazgos que abrió A7** (todos en nucleus salvo uno): **NU-78** (P2,
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
- **QK-25, nacido en `S5` (P2, A8)**: el builder de quark no puede emitir
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
