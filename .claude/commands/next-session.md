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

## 3. Estado al cierre (2026-09-15, QUANTUM 1.32.0 — A6: S1–S6 hechas, banco 51/59)

### Estado vigente (léelo entero; es lo único que hace falta para arrancar)

- **Set certificado: Quantum 1.32.0** (2026-09-12) — quark v1.14.0 (sin
  cambio), nucleus v1.28.0, orbit v1.9.6 y sus módulos, tal como los lista
  `versions.yaml` (la fuente; no copies números de aquí). `declared_lags`
  vacío. Publica el arco **A5**.
- **ANTES DE NADA, abre [`docs/planes/`](../../docs/planes/README.md).** Es el
  contrato de sesión —los cinco comandos que dicen dónde estamos, qué fichero
  manda para cada pregunta, qué NO decide una sesión sola y las tres
  escrituras que deja al terminar— y lleva el troceado del arco en curso. Con
  él, una sesión no necesita reconstruir contexto con criterio propio.
- **Trabajo por arcos del plan 5/5**: A1, A2, A3, A4 y **A5 CERRADOS**
  (1.28.0, 1.29.0, 1.30.0, 1.31.0, 1.32.0) → **A6, Orbit como admin de
  producto, EN CURSO**: su `S0` (medición) está hecha y el troceado en once
  sesiones vive en
  [`docs/planes/A6-orbit-admin-de-producto.md`](../../docs/planes/A6-orbit-admin-de-producto.md).
  **`S1`–`S6` hechas y FUSIONADAS** (orbit#471, #472, #473, #474, #475,
  #482 y #483): el banco está en **51/59**, con las familias de **permisos y
  auditoría completas**, la de **data studio a un solo control** de estarlo
  y la de **operación a los tres de `S9`** (OPS-11, OPS-13 parciales y
  OPS-17 ausente).
  **El pin de nucleus, que era el cuello de botella del arco, está subido**:
  nucleus **v1.29.0** cortado y el `require` de orbit con él, lo que cerró de
  una vez **NU-73** (OPS-06 verificado: el stream abre y contesta
  `stream.ready`), **OR-45** y los veredictos de **DS-04 + DS-05**. El set de
  suite sigue en 1.32.0 — esto fue un corte de pilar, no de suite.
  **Siguiente sesión: `S9`** (las vistas de operación que callan: OR-47,
  OR-48, OR-49 y OR-50) o **`S7`** (acciones y puntos de extensión), las dos
  sin precondición; `S8` espera a `S7` y `S10` (el instrumento del
  navegador) no espera a nadie.
  Lo que fue A4 y A5, sesión a sesión y con lo que cada una midió, está en
  [`docs/planes/A4-capa-de-datos.md`](../../docs/planes/A4-capa-de-datos.md) y
  [`docs/planes/A5-auth-de-producto.md`](../../docs/planes/A5-auth-de-producto.md).
  `bash scripts/estado.sh --breve` deriva el arco y la sesión siguientes; no
  los copies de aquí.
  El gate de cada arco sigue siendo el registro
  `docs/auditoria/madurez-2026-09-03/registro.csv` con su guard
  `umbrella-audit-backlog` (cero abiertos en un arco cerrado).
- **48 guards en el registro**: los 49 de 1.32.0 menos
  `umbrella-quickstart-embeds`, retirado al salir los ejemplos del árbol
  (2026-09-12): resolvía fences `file=` contra `nucleus/examples/showcase_demo`
  y ya no hay árbol contra el que resolver. Lo que comprueba ahora que los
  listados del quickstart sean lo que el scaffold escribe es
  `scripts/ci/check_quickstart_listings.sh`, dentro de la lane que genera el
  proyecto — comparación más fuerte que la anterior, pero en lane, no en el
  registro. `umbrella-auth-posture` (A5) sigue.
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
- **Deuda viva que YA VENCIÓ y nadie lo notó**: los guards de cadena de
  suministro leen el ÁRBOL, así que un release que falla al firmar sale VERDE.
  Le pasó a nucleus v1.26.0, y `scripts/check_release_assets.sh` —escrito,
  verificado y **fuera** del registro— esperaba a que el pin de nucleus trajera
  una release con activos. **Ya la trae**: corrido contra el set 1.32.0 sale
  **EXIT=0** con los cuatro (nucleus v1.28.0 lleva 15 activos), así que la
  condición se cumplió el 2026-09-12 y la entrada sigue sin registrarse. Lo que
  falta es registrarla con su fixture, que es lo único que `guard-of-guards`
  exige; la receta está en `docs/handoff/deuda-registro-release-assets.md` y
  hay que quitarla de `GUARD_SCAN_EXCLUDE` al hacerlo. **Tarea corta y
  discreta, buen arranque para la próxima sesión antes de S6 o S9.** (Y nucleus
  v1.29.0, cortada hoy, publica sus 15 activos: la regresión de cosign no ha
  vuelto.)
- **Dónde está cada cosa**: contrato de sesión y troceado → `docs/planes/`;
  trampas del tren → `scripts/train/README.md` (índice «Trampas
  transversales» + una sección por tren); decisiones → `docs/adr/` y los ADR
  de cada pilar; historia de sesiones anteriores al 2026-09-03 →
  `docs/handoff/sesiones-2026-07-12_a_2026-09-02.md` (grep, no cargar);
  memoria de la sesión de Claude → `~/.claude/projects/.../memory/`.
- **Pendientes con destinatario**: §5.

### Sesión 2026-09-15 — A6 `S6` hecha: la fila de sesión dice de quién es y desde qué dispositivo, y una llamada revoca todas las de una cuenta

- **OPS-02, OPS-04 y OPS-16 en `present`** (orbit#483): el banco pasa de
  **48 a 51 de 59** y **OR-46 queda cerrado**. La familia de operación queda
  en 14 presentes, 2 parciales (OPS-11, OPS-13) y 1 ausente (OPS-17), los
  tres de `S9`.
- **OR-46 era una clave, no una ausencia**: el visor leía las claves
  genéricas que una aplicación PODRÍA guardar (`user_id`, `email`…) y nunca
  las que escribe el proveedor de auth del PROPIO panel
  (`__nucleus_admin_username`), así que cada operador que el panel firmaba
  salía como nadie. Ahora las propias van primero y las genéricas quedan de
  reserva, con test de que una clave de aplicación no tapa al operador.
- **El dispositivo lo estampa el panel, bajo la clave del framework**: el
  middleware de runtime de nucleus escribe el user agent como mucho cada
  30 s y el `touchAdminSession` de orbit refresca `last_seen` en CADA
  petición, así que el de nucleus casi nunca volvía a escribir — un visor
  alimentado sólo por él nombraría el dispositivo de la sesión recién firmada
  y nada de la que lleva abierta toda la mañana. Misma sanitización
  (caracteres de control fuera, 256 bytes) y un clasificador pequeño
  (`Firefox on Linux`, `Safari on iOS`, `Go-http-client`) con el agente crudo
  al lado.
- **Tres decisiones que no conviene reabrir**: (1) la revocación masiva casa
  con LA MISMA cadena que la fila muestra (`user`), no con un id de cuenta —
  vale también para sesiones de aplicación, y lo que se lee es exactamente
  lo que se revoca; (2) **la petición que revoca nunca se revoca a sí
  misma**: revocar tu propia cuenta cierra los OTROS dispositivos
  (`kept_current: true`), porque «cerrar en todas partes menos aquí» es lo
  que se quiere y una llamada que se cerrara a sí misma dejaría una pantalla
  sin nadie detrás; (3) cero revocadas es un 200 honesto, no un 404 — el
  resultado pedido, que no quede otra sesión abierta, ya se cumple. Auditado
  como `session.revoke_all` con el usuario de record y el recuento, complete
  o no la llamada.
- **La fila marca `current`** (ésta es la tuya) y la SPA lo dibuja («you»),
  con el botón de revocar todas por fila y un diálogo que dice que la propia
  se conserva. Dist reconstruido.
- **Lección nueva del banco, la sexta de «la sonda mide el banco»**: OPS-02
  contaba filas de la lista COMPARTIDA y su veredicto dependía del filtro
  `-run`: `partial` en la corrida completa (sondas anteriores habían paseado
  la sesión del superusuario por el panel) y `absent` a solas. Y el panel
  estampa una sesión en las peticiones que pasan POR él, y el store lo ve al
  comprometer la respuesta: un login solo no deja nada que leer. Las tres
  sondas de sesión leen ahora SU fila, tras una petición propia por el panel.
  Escrito en `orbit/docs/admin-bench.md` con las otras.
- **Siguiente: `S9`** (las vistas de operación que callan —OR-47, OR-48,
  OR-49, OR-50— y con ellas OPS-11, OPS-13 y OPS-17) o **`S7`** (acciones y
  puntos de extensión), las dos sin precondición. La deuda corta del guard
  `check_release_assets.sh` (§Estado vigente) sigue sin registrar.

### Sesión 2026-09-15 — A6 `S5` cerrada: el pin de nucleus, y un arnés que no podía pasar en una rama de release

- **nucleus v1.29.0 CORTADO** (nucleus#543) y **el `require` de orbit subido**
  (orbit#482): con eso se cierran de golpe **NU-73** (OPS-06 abre el stream
  y recibe `stream.ready`, verificado, no leído), **OR-45** y la mitad de
  panel de **DS-04/DS-05**. El banco pasa de **45 a 48 de 59**, y `S5` queda
  HECHA. El set sigue en 1.32.0: esto es un corte de pilar, no de suite.
- **La trampa del corte, nueva y cara de encontrar**: el perfil
  `scaffold-mvc` del arnés de compatibilidad de nucleus **no puede pasar en
  NINGUNA rama de release-please**. El scaffold pina el framework a la
  versión que declara el CLI, y en esa rama release-please ya la subió a un
  tag que todavía no existe: el build se la pide al proxy y muere con
  `unknown revision`. Un `use` del workspace dice dónde está el CÓDIGO, no
  qué versión resuelve el grafo, así que listar la raíz nunca iba a
  arreglarlo. Lo arregla un `replace` **VERSIONADO** (uno sin versión lo
  rechaza Go para un módulo del workspace) — nucleus#546. Ese perfil
  sustituyó a los de ejemplos el 2026-09-12, así que v1.29.0 fue el primer
  release que lo corrió.
- **nucleus#542 cerrado** por huérfano: re-pinaba `examples/showcase_demo`,
  que #541 borró del árbol. Un PR de Dependabot sobre un directorio que ya no
  existe no se fusiona, se cierra.
- **La gramática del filtro es `?campo__op=valor`**, y la clave ENTERA gana si
  nombra una columna real: un campo llamado `views__gt` sigue resolviéndose.
  Un operador que nadie conoce **se rechaza**; caer a igualdad listaría todas
  las filas pareciendo un filtro.
- **Lo más expuesto del cambio, y cómo quedó cerrado**: un origen de datos
  escrito ANTES de que `Where` existiera compila igual e **ignora el campo**,
  así que contestaría todas las filas pareciendo filtrado. El contrato gana
  `OperatorFilterSource` (opcional): el panel **pregunta antes de mandar** y
  **rechaza** la consulta contra quien no declare que los aplica.
  `ExactTotal` no necesita esa promesa — quien lo ignora ya lo dice en el
  sobre (`total: -1`, `is_estimated: true`).
- **`quarkdatasource` los declina hoy, y es OR-51 (P3, A6)**: pina la RAÍZ de
  orbit y el CI lo construye con `GOWORK=off`, así que **no puede nombrar un
  símbolo que el tag que pina no publica**. Su parche está escrito y medido
  (doce operadores, `in` vacío, comodín) y entra en cuanto la raíz tenga
  release — antes de cerrar A6, que su gate lo exige. **Es la trampa de
  secuenciación a recordar**: en orbit, un módulo hermano no puede usar una
  adición de la raíz en el MISMO PR que la añade.
- **QK-25, hallazgo nuevo (P2, arco A8)**: el builder de quark **no puede
  emitir `LIKE … ESCAPE`** —no está en su whitelist de operadores ni hay
  `Expr` que lo produzca— y SQLite y Oracle no tienen escape por defecto, así
  que un `%` en el valor ensancha la coincidencia. Lo cazó el test del
  arnés (`contains "%"` devolvía las tres filas). En vez de publicar un filtro
  que miente, `quarkdatasource` **RECHAZA** esa consulta en esos dos motores
  nombrando el motivo; los valores sin comodín no cambian. **La caja de
  búsqueda arrastra el mismo defecto desde antes y NO se tocó**: cambiarla
  altera el comportamiento de una función publicada. Por la ruta de nucleus
  el escape sí funciona y el banco lo comprueba.
- **Dos cosas que el banco aprendió sobre sí mismo**, ambas escritas en su
  página: un modelo con UNA sola columna filtrable mide el lenguaje de
  filtros por una mirilla —cada operador volvía rechazado por el CAMPO, no
  por el operador—, y **el banco comparte UNA aplicación entre todas las
  sondas**, así que una aserción sobre un listado tiene que acotarse a las
  filas que esa sonda creó (la primera versión de DS-05 leyó los restos de la
  sonda de paginación como un filtro roto).
- **Lo que NO entra y hay que saberlo**: la fila de filtros de la rejilla
  sigue mandando igualdad. Los operadores se escriben en la URL y **una vista
  guardada los conserva**, que es lo que suele ser una consulta a la que un
  operador vuelve cada mañana. Cablear AG Grid a la gramática nueva es
  trabajo de SPA y pertenece a una sesión de interfaz.
- **Siguiente: `S6`** (la mitad de orbit: la fila de sesión que dice de quién
  es y con qué dispositivo —OR-46— y la revocación masiva; su mitad de
  nucleus está hecha y AHORA PUBLICADA, así que su precondición se cumple) o
  **`S9`** (las vistas de operación que callan), las dos sin precondición.

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

- **El plan a 5 de 5** manda el orden: ~~A1~~, ~~A2~~, ~~A3~~, ~~A4~~ y ~~A5~~
  CERRADOS (1.28.0, 1.29.0, 1.30.0, 1.31.0, 1.32.0) → **A6 Orbit como admin de
  producto, EN CURSO** (`S0`–`S6` hechas; troceado de once sesiones en
  [`docs/planes/A6-orbit-admin-de-producto.md`](../../docs/planes/A6-orbit-admin-de-producto.md),
  siguiente `S9` o `S7`) → A7 … → A12. El registro de hallazgos y su guard
  (`umbrella-audit-backlog`) siguen siendo el gate de cada arco.
- **Lo que A4 dejó a deber, con su porqué escrito**: la segunda mitad de su
  `S4` —uuid nativo, enums con CHECK, arrays de PostgreSQL, rangos, inet,
  JSONB— no está en el gate del arco y encaja en A8, que ya lleva los tipos
  enterprise. Y **QK-24** (un `GROUP BY` sin proyección deja `SELECT *`,
  inválido fuera de SQLite y MySQL permisivo) avisa desde quark v1.14.0 pero
  no es error: convertirlo rompe a quien depende de esos motores, así que se
  movió a **A12**, donde QADR-0010 acumula lo rompiente.
- **Todo lo del arco está FUSIONADO y `main` verde**: **orbit#467** (el
  banco), **orbit#471** (`S1`, OR-4), **orbit#472** (`S2`), **orbit#473**
  (`S3`), **orbit#474** (`S4`), **orbit#475** (vistas guardadas de `S5`),
  **nucleus#540** (NU-73) y **nucleus#545** (operadores y total de `S5`),
  **nucleus#546** (el arnés que no pasaba en una rama de release),
  **orbit#482** (el pin y la mitad de panel de `S5`), **orbit#483** (`S6`:
  dueño, dispositivo y revocación masiva), **orbit#469** (AUD-05) y los
  cuatro del borrado de ejemplos; en el paraguas,
  **quantum#189/#192/#193/#196/#197/#198/#199** y el de esta sesión.
- **El pin, que era el cuello de botella del arco, ESTÁ SUBIDO**: nucleus
  **v1.29.0** cortado y el `require` de orbit con él (orbit#482), lo que
  cerró **NU-73**, **OR-45** y los veredictos de **DS-04** y **DS-05** en un
  solo paso. Lo que aprendió el corte está en el §3 y en
  `scripts/train/README.md`: el perfil `scaffold-mvc` del arnés de nucleus no
  podía pasar en NINGUNA rama de release-please hasta nucleus#546.
- **OR-51, nacido esta sesión (P3, A6)**: `quarkdatasource` no implementa
  todavía `datasource.OperatorFilterSource`, así que el panel montado sobre
  Quark **rechaza** los filtros con operador en vez de contestarlos sin
  filtrar. No es descuido sino dependencia topológica: el CI construye cada
  módulo con `GOWORK=off` contra el tag de raíz que pina, y ese tag no publica
  aún `datasource.Filter`. Entra tras la release de la raíz y **antes de
  cerrar A6**, cuyo gate exige cero abiertos.
- **QK-25, nacido esta sesión (P2, A8)**: el builder de quark no puede emitir
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
