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

## 3. Estado al cierre (2026-09-12, QUANTUM 1.32.0 — A5 cerrado, A6 arrancado por su medición)

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
  **Siguiente sesión: `S1`** (operadores desde el panel), que es la que cierra
  el P1 heredado OR-4. A6 lleva ahora **dos P1**: OR-4 y **NU-73**, que abrió
  su propia medición.
  Lo que fue A4 y A5, sesión a sesión y con lo que cada una midió, está en
  [`docs/planes/A4-capa-de-datos.md`](../../docs/planes/A4-capa-de-datos.md) y
  [`docs/planes/A5-auth-de-producto.md`](../../docs/planes/A5-auth-de-producto.md).
  `bash scripts/estado.sh --breve` deriva el arco y la sesión siguientes; no
  los copies de aquí.
  El gate de cada arco sigue siendo el registro
  `docs/auditoria/madurez-2026-09-03/registro.csv` con su guard
  `umbrella-audit-backlog` (cero abiertos en un arco cerrado).
- **49 guards en el registro**: los 48 de 1.31.0 más `umbrella-auth-posture`,
  que A5 registró para vigilar la frontera entre lo que el banco de auth MIDE
  y lo que la página PUBLICA — los dos documentos de A5 siguen siendo ficheros
  de texto, y editar una cifra no pone roja ninguna suite.
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
- **Deuda viva, con fecha de vencimiento**: los guards de cadena de suministro
  leen el ÁRBOL, así que un release que falla al firmar sale VERDE. Le pasó a
  nucleus v1.26.0, que recupera activos en su release siguiente (decisión del
  propietario). `scripts/check_release_assets.sh` ya lo comprueba mirando los
  ACTIVOS de la release y hoy caza ese fallo, así que espera fuera del registro
  hasta que el pin de nucleus traiga una release con activos: la entrada y la
  fixture están en `docs/handoff/deuda-registro-release-assets.md`.
- **Dónde está cada cosa**: contrato de sesión y troceado → `docs/planes/`;
  trampas del tren → `scripts/train/README.md` (índice «Trampas
  transversales» + una sección por tren); decisiones → `docs/adr/` y los ADR
  de cada pilar; historia de sesiones anteriores al 2026-09-03 →
  `docs/handoff/sesiones-2026-07-12_a_2026-09-02.md` (grep, no cargar);
  memoria de la sesión de Claude → `~/.claude/projects/.../memory/`.
- **Pendientes con destinatario**: §5.

### Sesión 2026-09-12 (noche) — A6 arranca: 32 de 59 controles, y un defecto que ninguna suite veía

- **Sesión `S0` del arco A6, HECHA** (orbit#467, quantum#189). El set
  sigue en 1.32.0: `S0` no corta, mide. Precondición comprobada antes de
  empezar (`arcos cerrados: A1 A2 A3 A4 A5`).
- **El banco de admin existe y es ejecutable**: **32 de 59 controles
  presentes, 9 parciales, 18 ausentes**. Vive en
  `orbit/internal/adminbench/` —cada sonda arranca una aplicación Nucleus con
  `orbit.Module(...)` montado, inicia sesión como el admin de arranque y le
  pregunta al panel por su propia API— y `TestAdminBench` asserta el
  **veredicto registrado**, no el éxito. Página en `orbit/docs/admin-bench.md`.
- **La forma del resultado es el hallazgo**: el panel **navega y opera bien, y
  administra mal**. Los datos (CRUD con validación, búsqueda, orden servidor,
  lotes, import/export, fixtures, multi-tenant, datasource ajeno) y la
  aplicación (feed en vivo, pulso, flags, migraciones, storage, exports
  asíncronos) están; **lo que un operador le hace a otros operadores falta
  entero** — ninguna ruta crea un admin, le cambia la contraseña ni lo
  desactiva. Tres para retener: la política es `(sujeto, modelo, acción)`, así
  que ni campo ni fila caben; lo que una pantalla carga no lleva pistas de
  capacidad, así que la UI descubre los permisos **siendo rechazada**; y el
  rastro de auditoría cubre todo y **no sobrevive al proceso**.
- **NU-73 (P1), el hallazgo caro**: el middleware de sesión de nucleus envuelve
  el `ResponseWriter` en `auth.flashSweepWriter`, que implementa `Flush` y
  `Unwrap` pero **no `Hijack`** → **cualquier websocket de cualquier
  aplicación** revienta al hacer el upgrade y responde 500. El feed en vivo del
  panel —su capacidad diferencial— **nunca conecta** en un despliegue real; su
  snapshot sí. Los tests del panel lo cablean sin esa pila, por eso pasaban.
  El router ya implementa `Hijack` en sus otros dos envoltorios: falta en ése.
- **Seis hallazgos más en el registro** (207 filas, 13 abiertos, A6 con 8):
  **OR-45** (P2) ninguna lista tiene total (`total:-1`, `is_estimated:true`,
  con cinco filas); **OR-46** (P2) la fila de sesión nunca dice de quién es;
  **OR-47**, **OR-48** (el fallback de la SPA tapa los 404 de `/api/*`),
  **OR-49** y **OR-50** (P3).
- **Cuatro lecturas del primer pase medían el banco, no el producto**, y las
  cuatro se leían como defectos: el fallback de la SPA, un helper de logs que
  **truncaba** el cuerpo que la sonda examinaba, un operador compartido cuyos
  permisos se **acumulaban** entre sondas, y un modelo del banco con una clave
  foránea sin declarar. A4 aprendió que un comentario no es una medición y A5
  que un nombre tampoco; **una sonda tampoco, hasta que se comprueba contra qué
  mide**. Está escrito en la página del banco, no sólo aquí.
- **El troceado salió de la medición**: los 27 huecos vienen de **nueve
  causas**, así que las once sesiones van por causa. `S1` (operadores desde el
  panel) cierra OR-4 y va primero; la mitad **nucleus** de `S6` (el `Hijack`)
  va temprano por una razón mecánica: **un arreglo de nucleus no llega a orbit
  hasta que sube el pin**, así que si entra tarde su release no lo contiene y
  la mitad de orbit no se puede verificar en el mismo set.
- **Esa mitad ya está hecha, en la misma sesión** (nucleus#540): `Hijack` por
  `http.ResponseController`, con dos tests que fallan sin el arreglo — el
  unitario y uno de contrato **por la pila por defecto**, que es lo que no
  existía. Verificado en el workspace: con él, la sonda OPS-06 del banco abre
  el stream. **El veredicto del banco sigue en `absent`** hasta que el
  `require` de orbit traiga la release que lo contiene; cambiarlo antes sería
  publicar como cierto algo que el pin no respalda. NU-73 se marca hecho en el
  registro cuando esa release exista.

### Sesión 2026-09-12 (tarde) — A5 entregado: nueve sesiones y 40 de 43 controles

- **El arco A5 en un día**: `S0`–`S9` hechas, **diez PRs en nucleus**
  (#528…#537) y el paraguas (#187). **El banco de conformidad de auth pasa
  de 14 a 40 de 43 controles presentes**; `S10` (gate, guard y set) es lo que
  queda, y su guard —`umbrella-auth-posture`, el 49º— ya está escrito con su
  fixture, esperando a que el pin lo contenga.
- **Lo que ahora existe y no existía**: correo de producto (HTML/multipart,
  adjuntos, plantillas y `EnqueueTx` dentro de la transacción del llamante);
  `Roles []string` por adición y revocación de sesiones y de tokens;
  **`pkg/accounts`** con registro, verificación, login, reset, cambio, enlace
  mágico y lockout; TOTP con códigos de recuperación y step-up;
  **`pkg/auth/apikeys`** con scopes, rotación y CLI; permisos por OBJETO con
  helpers en el `Context`; **proveedor OIDC** con PKCE, discovery y JWKS; y
  la postura mapeada a **ASVS 4.0.3 L2**, 25 requisitos medidos (22 met, 2 de
  la aplicación, 1 not-met con su razón).
- **Cinco defectos los encontró el arnés, no la lectura**, y conviene
  retenerlo: un 500 al iniciar sesión porque el servicio llevaba un gestor de
  sesiones distinto del montado (el módulo toma ya el de la aplicación); un
  **pánico** al pedir la sesión fuera de su middleware (`HasSession`); un
  formato de clave de API que fallaba **una de cada diez** porque base64url
  contiene el separador `_`; y dos mediciones equivocadas — KEY-05 leyó el
  NOMBRE de una clave de configuración y ASVS V3.2.1 preguntó el token dentro
  de una petición anónima, donde está vacío en los dos lados.
- **Lo que NO se entrega, con su razón escrita en tres sitios** (banco, plan y
  registro): **WebAuthn** —su empaquetado correcto es un módulo hermano, y un
  módulo hermano pina la ÚLTIMA release publicada, que no contiene
  `accounts.MFAStore` hasta que salga este set; a mano en el core sería donde
  un fallo de seguridad es silencioso—; **SAML** —otro cuerpo de trabajo sobre
  la misma costura—; y el **timeout de inactividad por defecto**, que caduca
  sesiones en todo despliegue que actualice (QADR-0010): NU-72 se movió a A12
  y desde este arco `doctor security` lo nombra.
- **El gate se ajustó con su porqué**: «Orbit muestra las sesiones por
  dispositivo» pasa a **A6**. A5 entrega la capacidad (`ActiveSessions`,
  `Revoke`, `RevokeWhere`, metadatos con agente de usuario); dibujarla es del
  repo que tiene el panel.
- **Una trampa de CI, ajena al arco, que bloqueaba todo**: la imagen
  `minio/minio` dejó de servirse en Docker Hub («pull access denied … does not
  exist»), así que la lane de storage y con ella el gate obligatorio salían
  rojos en **cualquier** PR. Arreglado apuntando a `quay.io/minio/minio`.
- **Y una del flujo de PRs apilados**: fusionar el primero con `--delete-branch`
  **cierra automáticamente** los PRs cuya base era esa rama, y un PR cerrado no
  se puede reabrir ni reapuntar. Reapunta la pila entera a `main` ANTES de
  fusionar el primero.

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
  producto, EN CURSO** (`S0` hecha el 2026-09-12; troceado de once sesiones en
  [`docs/planes/A6-orbit-admin-de-producto.md`](../../docs/planes/A6-orbit-admin-de-producto.md),
  siguiente `S1`) → A7 … → A12. El registro de hallazgos y su guard
  (`umbrella-audit-backlog`) siguen siendo el gate de cada arco.
- **Lo que A4 dejó a deber, con su porqué escrito**: la segunda mitad de su
  `S4` —uuid nativo, enums con CHECK, arrays de PostgreSQL, rangos, inet,
  JSONB— no está en el gate del arco y encaja en A8, que ya lleva los tipos
  enterprise. Y **QK-24** (un `GROUP BY` sin proyección deja `SELECT *`,
  inválido fuera de SQLite y MySQL permisivo) avisa desde quark v1.14.0 pero
  no es error: convertirlo rompe a quien depende de esos motores, así que se
  movió a **A12**, donde QADR-0010 acumula lo rompiente.
- **URGENTE, y desatasca a todo el mundo**: **el `main` de nucleus está rojo**
  desde la release de v1.28.0 — los dos ejemplos (`examples/mvc_api`,
  `examples/showcase_demo`) siguen pinando v1.26.0 y el guard del showcase
  falla, lo que tumba el `CI Required Gate` de **cualquier PR abierto** del
  repo, incluidos los que no lo tocan. El arreglo existe y está verde:
  **nucleus#527** (re-pin a v1.28.0), MERGEABLE. Fusionarlo primero.
- **Los tres PRs de la sesión S0 de A6, abiertos y a la espera**: orbit#467
  (el banco), quantum#189 (plan, registro y handoff) y **nucleus#540** (el
  arreglo de NU-73, bloqueado sólo por el rojo de arriba). Orden de fusión:
  nucleus#527 → nucleus#540 → orbit#467 → quantum#189.
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
  de la ronda, y el re-pin de `examples/showcase_demo` (nucleus) va **después**
  de todos los tags del set.

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
