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

## 3. Estado al cierre (2026-09-10, QUANTUM 1.30.0 — A3 cerrado, en la puerta de A4)

### Estado vigente (léelo entero; es lo único que hace falta para arrancar)

- **Set certificado: Quantum 1.30.0** (2026-09-10) — quark v1.13.0, nucleus
  v1.26.0, orbit v1.9.4 y sus módulos, tal como los lista `versions.yaml`
  (la fuente; no copies números de aquí). `declared_lags` vacío. El tag
  v1.30.0 publica el paquete del set firmado y atestado.
- **ANTES DE NADA, abre [`docs/planes/`](../../docs/planes/README.md).** Es el
  contrato de sesión —los cinco comandos que dicen dónde estamos, qué fichero
  manda para cada pregunta, qué NO decide una sesión sola y las tres
  escrituras que deja al terminar— y lleva el troceado del arco en curso. Con
  él, una sesión no necesita reconstruir contexto con criterio propio.
- **Trabajo por arcos del plan 5/5**: A1, A2 y **A3 CERRADOS** (1.28.0,
  1.29.0, 1.30.0) → **A4, quark como capa de datos de nucleus, EN CURSO y casi
  cerrado**. De sus diez sesiones hay **ocho hechas** (`S0`–`S7`) y `S8`
  parcial; el troceado, con lo que cada una midió, está en
  [`docs/planes/A4-capa-de-datos.md`](../../docs/planes/A4-capa-de-datos.md).
  `bash scripts/estado.sh --breve` deriva la siguiente; no la copies de aquí.
  **A4 ya no tiene hallazgos abiertos**: QK-21, QK-22, QK-23 y NU-50 cerrados,
  y QK-24 movido a A12 con su porqué.
  **Lo que queda son dos cosas, y una es tuya**: la decisión de S8 (¿`--data
  quark` por defecto?) y `S9`, el tren que publica el set.
  El gate de cada arco sigue siendo el registro
  `docs/auditoria/madurez-2026-09-03/registro.csv` con su guard
  `umbrella-audit-backlog` (cero abiertos en un arco cerrado).
- **48 guards en el registro** (el 48º es `umbrella-tag-grammar`, de A4/S6)
- Antes eran 47 (41 + los cinco que A3 dejó esperando al pin +
  el de suelos de Dependabot de orbit que ese pin destapó).
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

### Sesión 2026-09-11 (tarde) — A4 de S1 a S8: el banco de 44 a 58, QK-21 arreglado y el gate puesto

- **Ocho sesiones del arco en un día** (S0 por la mañana, S1–S8 después), con
  **doce PRs fusionados**: quark #388/#389/#391/#392/#393/#394/#395, nucleus
  #518/#520/#522/#523, paraguas #181/#182/#183. **El set sigue en 1.30.0**:
  falta `S9`, que es el tren.
- **El banco de consultas va de 44 a 58 de 60 tipadas, y de 16 huecos a 2.**
  Los dos que quedan son `GROUP BY` sin proyección, que ahora AVISA; hacerlo
  error rompe a quien depende de SQLite y MySQL permisivo, así que **QK-24 se
  movió a A12**, donde vive el major de QADR-0010. Con eso **A4 no tiene
  hallazgos abiertos**.
- **Dos de los hallazgos de S0 eran errores de la propia medición**, y conviene
  no olvidarlo: QK-22 (CTE recursiva) y QK-23 (top-N por grupo) ya funcionaban.
  Lo que S0 leyó fue el **comentario** de `WithRecursive`, que seguía diciendo
  que la superficie tipada no modelaba `UNION` — una nota que sobrevivió a lo
  que describía. **Una medición que se fía de un comentario mide el
  comentario.** Desde S2 cada caso del banco ejecuta contra una base real y
  comprueba su RESULTADO, no su SQL.
- **QK-21 (P1) confirmado y arreglado.** S0 lo dejó dicho sin confirmar por no
  tener contenedores; el CI lo confirmó en cinco de seis motores (MySQL: «Out
  of range value»). Los enteros mapean ya por anchura y las claves son de 64
  bits. Destapó un defecto latente: el diff comparaba el tipo desnudo de una
  PK sin pasar por el camino de la PK, y en SQLite sólo `INTEGER PRIMARY KEY`
  aliasa el rowid — sin `PKBareColumnType`, cada tabla de SQLite reportaba
  deriva contra sí misma al crearse. **Nota de migración**: `PlanMigration`
  propone el ensanchado como `ALTER COLUMN`; no pierde datos, pero en una
  tabla grande el motor puede reescribirla.
- **El gate del arco está puesto**: `umbrella-tag-grammar` (48 guards) y la
  sonda `--data quark` dentro de `quickstart-smoke`. La sonda **se enciende
  sola** cuando el pin traiga el arreglo del generador; verificado en las dos
  direcciones. Correr el gate es lo que encontró los dos defectos del código
  generado que nucleus#522 arregla.
- **S8 PARA a mitad, y es la decisión que espera a Carlos**: completarla
  exigiría afirmar que Quark es la capa de datos por defecto, y `--data` sigue
  por defecto en `sql`. **¿`nucleus generate module` debe pasar a `--data
  quark` por defecto, con `--data sql` como salida explícita?** Es un cambio
  en lo que el generador emite para todos: QADR-0010 lo pone en tu mesa.
- **Lo que NO se hizo, dicho a propósito**: la segunda mitad de S4 —uuid
  nativo, enums con CHECK, arrays de PostgreSQL, rangos, inet, JSONB— no está
  en el gate de A4 y lo urgente era el defecto. Encaja en A8, que ya lleva los
  tipos enterprise.
- **Lo que espera al pin**: la entrada del sidebar espejo para
  `reference/type-matrix`, que se compara contra el sidebar DEL PIN. Va en el
  commit del set, como los guards que esperan.

### Sesión 2026-09-11 — A4 arranca: la medición de S0, y lo que le cambió al plan

- **Sesión `S0` del arco A4, HECHA** (quark#388, nucleus#518, quantum#181).
  El set sigue siendo 1.30.0: S0 no corta nada, mide. Precondición
  comprobada antes de empezar (`arcos cerrados: A1 A2 A3`).
- **El banco de 60 consultas existe y es ejecutable**: 44 tipadas, 4 que
  emiten SQL equivocado, 12 sin API. Vive en
  `quark/internal/enginesuite/querybench_cases_test.go` —módulo que ya enlaza
  los cinco motores y no se publica— y `TestQueryBench` asserta el VEREDICTO
  registrado, no el éxito: cerrar un hueco pone la suite roja pidiendo que se
  actualice el veredicto, en vez de mejorar en silencio. Documento en
  `quark/docs/query-bench.md`.
- **El veredicto `wrong-sql` es el hallazgo del método**: cuatro consultas
  compilan, corren, no devuelven error y emiten SQL que hace otra cosa. Las
  cuatro salieron de leer el SQL que recibió el driver, no de mirar el error.
  `GroupBy` sin `Select()` deja `SELECT *` (inválido fuera de SQLite);
  `With()` declara la CTE y no cambia el `FROM`; `WithRecursive` emite la
  palabra clave sobre un cuerpo que no puede recurrir. Contarlas como
  aprobadas es como una matriz de capacidades acaba afirmando lo que no tiene.
- **Cinco hallazgos nuevos en el registro** (195 filas, 10 abiertos):
  **QK-21 (P1)** todo entero Go colapsa en `INTEGER` y todo flotante en `REAL`
  —la PK sale `SERIAL`, no `BIGSERIAL`—, mientras `pkg/model` emite
  `BIGINT`/`DOUBLE PRECISION`/`BIGSERIAL` para el MISMO modelo; **NU-50 (P2)**
  las dos gramáticas del tag `db` se contradicen **en silencio y en las dos
  direcciones** (un modelo estilo nucleus deja a quark creyendo que hay una
  columna llamada `column:email;unique;not null`, sin PK, sin avisar);
  **QK-22, QK-23 (P2)** y **QK-24 (P3)**.
- **El plan cambió, que es el producto de S0.** Las dieciséis consultas que
  fallan salen de SIETE causas, así que las sesiones van por causa. S1 se
  partió en tres; la sesión de valores cero en `Update` se **retiró** (ninguna
  de las 60 la necesita); el linter de tags SUBIÓ a S6 porque NU-50 bloquea a
  `--data quark`; y los tipos por motor empiezan por arreglar el rango de los
  enteros que ya existen. La causa mayor —la whitelist de diez funciones del
  AST, que cuesta cuatro consultas— **no estaba en el plan escrito**.
- **Lo que S0 NO pudo medir, y lo dice en los documentos**: el comportamiento
  por motor de QK-21. No había runtime de contenedores en la máquina, así que
  la matriz se midió llamando al mapeador de tipos, no contra motores vivos.
  `S4` no empieza sin ellos; es su precondición escrita.
- **Dos bugs de `scripts/estado.sh`, arreglados de paso**: `read` sin `IFS=`
  se comía el espacio de la primera columna de `git submodule status`, así que
  el caso BUENO se imprimía como `?` (se lee como alarma) y sólo la deriva
  salía bien; y la próxima sesión se derivaba de la primera tabla del fichero
  del arco cuya celda empezara por `Sn`, que con la tabla nueva de A4 devolvía
  basura. Ahora lee sólo bajo «## Registro de sesiones».

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

- **El plan a 5 de 5** manda el orden: ~~A1~~, ~~A2~~ y ~~A3~~ CERRADOS
  (1.28.0, 1.29.0, 1.30.0) → **A4 Quark como capa de datos** (EN CURSO: `S0`
  hecha el 2026-09-11, siguiente `S1`; troceado en
  [`docs/planes/A4-capa-de-datos.md`](../../docs/planes/A4-capa-de-datos.md))
  → A5 … → A12. El registro de hallazgos y su guard
  (`umbrella-audit-backlog`) siguen siendo el gate de cada arco.
- **Lo que A4/S0 dejó pendiente de máquina, no de decisión**: confirmar QK-21
  contra motores reales. La máquina de la sesión no tenía runtime de
  contenedores, así que la matriz de tipos se midió llamando al mapeador y no
  contra PostgreSQL/MySQL/MSSQL vivos. Es la precondición escrita de `S4`, y
  la primera tarea de esa sesión.
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
