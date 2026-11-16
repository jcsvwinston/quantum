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

## 3. Estado al cierre (2026-11-16, QUANTUM 1.45.0 CERTIFICADO — A11 CERRADO; A12 en curso: `M0`, `R1`, `M0-R`, `M0-F`, la DX al 5, `D9-N` y `D10-O` HECHAS Y PUBLICADAS; las DOCE decisiones de Carlos del 2026-11-16 (D14…D25) fijan la ventana hasta el 2.0; siguiente: **`M1-S0`**, la sesión de medición que trocea `M1`)

### Estado vigente (léelo entero; es lo único que hace falta para arrancar)

- **Set certificado: Quantum 1.45.0** (2026-11-13/16, fuera de cadencia:
  el propietario pidió seguir avanzando el viernes 13 y el set adelanta la
  cadencia del lunes 2026-11-23; razón escrita en `status:`) — quark
  v1.19.1 (CLI v1.3.1, los cinco drivers v0.3.3), nucleus v1.36.0
  (`cmd/nucleus` v1.36.0 en lockstep y los dieciséis módulos en patch,
  `providers/tasks-asynq` v0.1.1 incluido) y orbit v1.22.0 (UN solo corte
  por primera vez en cinco trenes: `datasource`, `ui` y `proto` no se
  movieron), tal como los lista `versions.yaml` (la fuente; no copies
  números de aquí). `declared_lags` vacío. `suite-integral --cierre`
  **60 de 60**. Publica **`D9-N` y `D10-O` de A12, lo último que la
  precondición de `M1` esperaba**: `generate module` escribe las filas de
  política comentadas sobre un root sin enforcer (D9, NU-127), el lector
  de `doctor` lee todo el paquete `main` y `cmd/`, `makemigrations` deriva
  el par de los modelos Quark a través de la CLI de quark (`DX-N3n2`,
  NU-170); `quarkdatasource.Register` toma opciones tipadas (D10) y un
  campo excluido sale de todas las filas (OR-150, `DS-18` 73 de 73);
  `migrate create --from-models` rinde el DDL idempotente de cada motor
  (QK-101). El PR de set subió `umbrella-admin-posture` a 73, puso «73 of
  73» en why-quantum y regeneró la guía de migración (34 avisos). **Es el
  primer tren conducido por el propietario desde su terminal** (el
  clasificador de permisos de la sesión deniega las fases que publican).
  Sus trampas, en la sección 1.45.0 de `scripts/train/README.md`.
- **ANTES DE NADA, abre [`docs/planes/`](../../docs/planes/README.md).** Es el
  contrato de sesión —los cinco comandos que dicen dónde estamos, qué fichero
  manda para cada pregunta, qué NO decide una sesión sola y las tres
  escrituras que deja al terminar— y lleva el troceado del arco en curso. Con
  él, una sesión no necesita reconstruir contexto con criterio propio.
- **La ventana hasta el 2.0, decidida el 2026-11-16 (D14…D25, §3.3 del
  contrato; sección «La ventana hasta el 2.0» del plan de A12)**: la
  secuencia es **`M1-S0`** (la sesión de medición que trocea `M1`: ruta
  `/v2`, las retiradas y los volteos de las 34 filas, `pkg/model` y el
  adaptador, asynq fuera del root, D11 en el paraguas, la guía, el tren
  del 2.0.0; lista lo aditivo que entra en la ventana; rediseño como carril
  paralelo a la espera de las maquetas de Carlos) → (o en paralelo, por
  producto) las diez «sesiones cortas» del §2.2 del contrato en sets 1.x
  (NU-129, NU-131, NU-108; OR-71, OR-74, OR-75, OR-76; QK-54, QK-68,
  QK-69) → lo aditivo de las 32 dimensiones por debajo del 5 que `M1-S0`
  marque como corto y seguro, en sets 1.x (QADR-0010: nada rompiente) →
  `M1` en enero de 2027 → 2.0.0 no antes del 2027-02-07 → `R2` COMPLETA
  como `R1` → A13. **Lo que no es código y también entra**: la política
  de soporte publicada sin LTS y con la ventana de suite mandando sobre
  las cuatro `SECURITY.md` (D21, D22: sesión de docs con calendario YAML,
  guard `umbrella-release-calendar`, campos del manifiesto y un QADR
  nuevo; cierra QM-25); la protección de `main` en los cuatro repos como
  la de nucleus, con «Allow auto-merge» (D23; antes, el PR de orbit que
  lleve el refresco de la matriz de módulos a un PR y un job agregador en
  el paraguas; los ajustes los ejecuta Carlos con los comandos del §5);
  Discussions sólo en quantum (D24, clic de Carlos); la nota de Scorecard
  publicada (D25, quantum#320); y el guard `umbrella-migration-guide`
  (D14, quantum#321). **Trampa de calendario**: la excepción de
  govulncheck para GO-2026-6909 caduca el 2026-12-31; si el 2026-12-15 la
  base de datos de Go sigue sin registrar v0.5.2 como arreglada
  (golang/vulndb#6909, cerrada el 2026-11-15 con el cambio pendiente), un
  chore PR en nucleus la mueve al 2027-03-31 (D19).
- **Trabajo por arcos del plan 5/5**: A1…A10 CERRADOS (1.28.0 … 1.39.0).
  **A10 (Testing y OpenAPI de primera clase) se cerró el 2026-10-05 en
  Quantum 1.39.0** (nucleus v1.31.0), en once sesiones del 2026-09-25 al
  2026-10-05 (nucleus#574…#586): banco `nucleus/internal/apibench` de **12 a
  46 de 46**. Lo que dejó: el kit de test completo (cliente con sesión,
  datos, dobles, `CheckModule`); el documento OpenAPI derivado de las rutas,
  los structs y la seguridad (`WithOpenAPIDocument`), exigido
  (`WithOpenAPIValidation`, `AssertConforms`, `nucleus openapi --check`) y
  con cliente TypeScript generado por un generador propio en Go; endpoints
  tipados (`nucleus.Handle`); problem+json junto al sobre;
  `Provide`/`Resolve` y `DependsOn`. El gate corre en la lane
  `suite-starter` de nucleus (obligatoria) y lo vigila
  `umbrella-api-posture`. Detalle en
  [`docs/planes/A10-testing-y-openapi.md`](../../docs/planes/A10-testing-y-openapi.md).
  **A11 (Extensibilidad y catálogo) y A12 (Rendimiento, re-auditoría y
  cierre a 5) EN CURSO** desde el 2026-10-04, con sus `S0` hechas y sus
  troceados en
  [`docs/planes/A11-extensibilidad-y-catalogo.md`](../../docs/planes/A11-extensibilidad-y-catalogo.md)
  (33 sesiones en carriles N/O/Q/W) y
  [`docs/planes/A12-rendimiento-reauditoria-cierre.md`](../../docs/planes/A12-rendimiento-reauditoria-cierre.md)
  (12 sesiones; sus cuatro decisiones APROBADAS por Carlos el 2026-10-06, y
  **`M0` en marcha desde el 2026-10-16**: `M0-S0` contó el major al pin y
  lo troceó en `M0-Q` ∥ `M0-N` ∥ `M0-G` → `M0-O` → `M0-E`; la lista cerrada
  del major, con el estado de cada aviso, es el §3.0 de
  [`docs/planes/quantum-2.0.md`](../../docs/planes/quantum-2.0.md), que
  desde `M0-G` (quantum#285, fusionado) lee `umbrella-deprecations`
  junto con los avisos `active` sin marca; y sus **ocho decisiones D1…D8
  las tomó Carlos el 2026-10-16** (§3.3; D5 contra la recomendación:
  `pkg/model` se retira en el 2.0 y con él el adaptador `datasource/nucleus`
  de orbit), así que ninguna fila queda en `decisión`; **`M0-N` está hecha
  (nucleus#630, fusionado el 2026-10-16: nueve avisos, trece marcas,
  `WithErrorEnvelope()`, `router.Wrap`)**, **`M0-Q` también** (quark#470 y
  quark#471: DEP-2026-004…010), **y `M0-O` completa** (orbit#568 (a) y
  orbit#570 (b), publicadas en 1.42.0: orbit estrena `docs/deprecations/`
  con DEP-2026-001 y 002, la salida `AllowSharedAgentCertificate`, las
  marcas del adaptador y el aviso al montar, el `LIKE` escapado de
  `quarkdatasource`, `api.ts` leyendo problem+json y `router.Wrap` en sus
  dos llamadas); del §3.0, 23 filas `publicado` al pin de 1.42.0 y las 7
  de quark `en main` hasta la primera release de quark posterior a
  v1.17.0. **Y `M0-E` hecha el 2026-10-23**: el ensayo del major en
  ramas `dry-run/2.0` de los tres hermanos (en origin, sin PR), con orbit
  compilando y pasando sus tests contra quark y nucleus `dry-run/2.0`;
  **`M0` queda hecha**. Lo que el ensayo midió y el §3 no decía está en la
  sección «`M0-E` — el ensayo del major, medido» del plan y en el §3.5 y
  las decisiones D9…D11 del contrato: la ruta `/v2`, la DX al 5 (§2.1)
  como prerrequisito de retirar `pkg/model`, quark en el grafo de la raíz
  de orbit, y una lista de `fix` de 1.x que van ANTES del major. **Y `R1`
  hecha el 2026-10-27** (quantum#294): la re-auditoría completa sobre el pin de
  1.42.0 con el método de `R0` —siete auditores y siete revisores
  adversariales como workflows de agentes—, en
  [`docs/auditoria/reauditoria/2026-10-23/`](../../docs/auditoria/reauditoria/2026-10-23/README.md):
  media de las 36 dimensiones 2,79 → 4,12 (ninguna baja, tres en 5), 122
  hallazgos nuevos en el registro (0 P0, 4 P1: OR-78, OR-79, OR-80, OR-99;
  24 P2; 94 P3), cuatro volteos al §3.0 del 2.0 (filas 31–34 `por
  escribir`), y el veredicto del gate: **32 dimensiones por debajo del 5**
  (lista en el README, una línea cada una; `R2` la convierte en A13).
  **Y `M0-R` hecha el 2026-11-03** (sección «`M0-R`» del plan): los
  cuatro avisos de `R1` `en main` con su salida en 1.x (quark#476 con el
  token nuevo `quark:"literal_column"`, orbit#576, #578, #582) y los P1 de
  orbit arreglados en 1.x (OR-78 orbit#579, OR-79 #581, OR-99 #577;
  OR-80 tiene salida en 1.x en #578 pero sigue `abierto` hasta el volteo
  de `M1`, como QK-45). Del §3.0, 23 `publicado` y **11 `en main`** (las
  siete de quark, re-fechadas al 2027-02-07 en quark#476, y las cuatro de
  `M0-R`): ninguna `por escribir`; **las once las publicó Quantum 1.43.0
  el 2026-11-07**. En 1.x antes de `M1`: la DX al 5, los `fix` de 1.x de `M0-E` (OR-144 entre
  ellos), el registro de proveedores de `pkg/tasks` y las sesiones de 1.x
  de D9 y D10 —`D9-N` y `D10-O`, hechas el 2026-11-13 y por publicar—). **Y
  `M0-F` hecha el 2026-11-07** (sección «`M0-F`» del plan): los `fix` de
  1.x portados desde `dry-run/2.0` — quark#479 (QK-70), orbit#584 (OR-89),
  #585 (OR-141), #586 (OR-144 y las coerciones), nucleus#639 (el bump de
  `crewjam/saml` a v0.5.2 por **GO-2026-6909** y, decidido por Carlos el
  mismo día (NU-155, opción 1), el gate `scripts/ci/govulncheck_gate.sh`
  en la lane SAML: excepciones acotadas a un id, módulo y versión, con
  fecha, que se retiran solas cuando la base de Go registre la versión
  arreglada) y nucleus#638 (el registro de proveedores de `pkg/tasks`,
  que hace a nucleus MINOR) en `main`; las notas de v1.34.0 y el snapshot
  en nucleus#640 (publicado en 1.43.0). **Y la DX al 5 (§2.1) EN CURSO
  desde el 2026-11-08**: `DX-0` la contó punto a punto al pin de 1.43.0 y
  la troceó (sección «La DX al 5 — medida y troceada» del plan): sólo el
  **bloque A** desbloquea `M1` —`DX-N1` (los generadores y
  `nucleustest.Make` sobre quark, NU-137), `DX-N2` (las nueve páginas del
  sitio de nucleus que enseñan `pkg/model`) y `DX-S1` (`nucleus new --with
  orbit` monta el panel sin `DataSource`, NU-159)—; `DX-Q1` (receta en los
  `Err*` de quark y su deriva), `DX-N3`, `DX-Q3` y `DX-Q4` suben la nota de
  `R2` sin bloquear nada; las dos consultas del banco que faltan (58 de
  60) son del 2.0 (DEP-2026-008). Dos decisiones nuevas al propietario en
  el contrato: D12 (`Make` con doble gramática, hecha como propuesta
  porque nucleus no depende de quark) y D13 (la forma del playground).
  **El bloque A entero, `DX-Q1` y `DX-Q3` entraron en `main` el mismo
  2026-11-08** (nucleus#644, #646, #647; quark#481, #482, #484; sesión del
  2026-11-08, archivada) y **Quantum 1.44.0 los publicó el 2026-11-11**
  con `tasks-asynq` v0.1.0 y D12/D13. **Quantum 1.45.0 publicó `D9-N` y `D10-O` el 2026-11-16**; D11 es del 2.0 y la ejecuta `M1`. Delante de `M1` quedan `M1-S0`, las diez cortas del §2.2 y lo aditivo de la ventana (D14…D25, el bullet de la ventana).
  Decisiones de Carlos para A11: ejemplos como fixtures probados,
  construir saml/redis-cache/sentry (Stripe se construyó y se
  retiró el 2026-10-06: los pagos quedan en la aplicación), catálogo de `nucleus add`
  embebido y fijado a la release. El estado de cada sesión (hecha, PR
  abierto, fusionada) está en el registro de sesiones de cada plan; la cola
  de integración de esta noche, en la sesión de abajo.
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
- **61 guards en el registro**: los 60 de antes más **`umbrella-migration-guide`** (D14, 2026-11-16; quantum#321): la guía de migración al 2.0 (`docs/planes/guia-migracion-2.0.md`) es lo que `scripts/lib/migration-guide.py` genera de los avisos activos de los tres productos AL PIN; nació porque la guía llevó 23 entradas con 34 avisos desde el 2026-10-23 sin que nada la mirara; `bump-set` la regenera en cada re-pin y `train.sh` la cuenta en `RUTAS_REPIN`. Los 60: los 59 de antes más **`umbrella-catalog-posture`**, la segunda mitad de A11 `S-fin` (con el pin de 1.41.0): la cifra y la tabla por familias de `nucleus/docs/catalog-bench.md` contra `internal/catalogbench`, nota en todo lo no present y un suelo de 36 de 38; y, en el PR de set, `umbrella-quark-extension-posture` sube su suelo de 14 a 22 de 22 (con 14 su fixture dejaba de morder al pin nuevo). Los 59: los 57 más **`umbrella-site-posture`** y **`umbrella-quark-extension-posture`**, la primera mitad (2026-10-06): el banco del sitio corre en la certificación (lo medido = lo registrado, suelo 12 de 12), y la cifra y las cabeceras de `quark/docs/extension-bench.md` contra `internal/extbench`; `umbrella-admin-posture` sube su suelo a 72. Los 57: los 55 más `umbrella-audit-criteria` (A12 `R0`) y `umbrella-generated-pages` (A11 W4). Los 55: los 54 de 1.39.0 más **`umbrella-why-quantum`**, el gate W1 de A11 (2026-10-05, registrado sin esperar al set porque sus fuentes ya están en el pin): cada cifra de `website/docs/why-quantum.md` contra su fuente al pin y citada en su párrafo, ningún otro número en su prosa (tampoco en palabras), y la frase de `what-is-quantum.md` que sustituyó a «not breadth of plugins». **Trampa anunciada para el próximo tren**: al re-pinar nucleus con el catálogo de N1/N4, la tabla de `nucleus add` cablea capacidades del core que no son módulos (3 en el main de hoy) y el guard pone rojo el PR de set hasta reescribir las dos frases del catálogo con lo que publica. Los 54: los 53 de 1.38.0 más **`umbrella-api-posture`**, el gate de A10 (2026-10-05, en el PR de set de 1.39.0): la cifra de `nucleus/docs/api-bench.md` y su tabla por familias contra el catálogo, el starter con `WithOpenAPIDocument` y endpoints tipados, el test del gate y la lane que lo corre con node y `tsc`, y la línea base del documento del starter. Los 53: los 52 de 1.37.0 más
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

### Sesión 2026-11-13/16 — **el tren de Quantum 1.45.0 conducido por el propietario, y las doce decisiones de la ventana hasta el 2.0 (quantum#319, D14…D25)**

- **Arranque**: Carlos, el viernes 2026-11-13 con `D9-N` y `D10-O` en
  `main`: «vamos a ir avanzando». El set del lunes 2026-11-23 se adelanta
  para publicar lo que `M1` espera.
- **El tren (2026-11-13/16, pausado el 14 y retomado el 15)**: quark
  v1.19.1 (quark#494 suelos → quark#493; prosa repuesta en la rama del
  bot; siete tags), nucleus v1.36.0 (nucleus#665 suelos → nucleus#663/#664
  notas y snapshot → nucleus#667 el test rancio de la lane suite-starter
  → nucleus#668 el suelo de `tasks-asynq` → nucleus#669 notas re-fechadas
  → nucleus#657; dieciocho tags con `cmd/nucleus`, 15 activos firmados),
  orbit v1.22.0 (orbit#599 alineación —hecha a mano por la sesión calcando
  `alinea_pines_orbit`, con las notas y el snapshot en la rama del bot por
  `orbit-notes-apply.sh`— → orbit#598; cinco tags nuevos, 15 activos; sin
  segundo corte), quantum#319 (set) y el cierre (60 de 60; reloj
  1h33m39s conducido en once invocaciones y 62h54m18s de espera del
  propietario, 64h27m57s de punta a punta; anuncio a quantum-app:
  quantum-app#39, en borrador y con sus gates en rojo, deuda suya). **El clasificador de
  permisos denegó a la sesión la fase de quark** («Create Public
  Surface»), así que el propietario lanzó las cuatro fases que publican
  desde su terminal y la sesión preparó suelos, notas, snapshots,
  alineación, cifras de guards y prosa, y paró antes de cada una diciendo
  el comando exacto. Los tres `fix(train)` que el tren obligó:
  quantum#316 (govulncheck en el preflight con la toolchain declarada),
  quantum#317 (`${var}` ante bytes no ASCII: bash 3.2 con locale UTF-8 dio
  por anclada una rama que no lo estaba) y quantum#318 (el `require` de
  UNA línea, invisible para los suelos y manifest-guard: `tasks-asynq`
  llevaba dos minors de retraso sin aviso; fusionado tras el set). La lane
  de integración de `main` cayó por el flake OR-149 (`EXT-10`) tras
  fusionar el set y pasó al relanzar.
- **La medición del arco** («¿qué nos queda para el 5 de 5 y para empezar
  el 2.0?»): respondida desde el plan de A12, el contrato, el informe de
  `R1` y el registro, con un verificador cruzándola contra los ficheros.
  Lo que afloró: `M1` sin troceado (su fila decía «retirar los doce
  símbolos»), el alcance de `R2` sin cerrar, la guía de migración rancia
  (23 de 34), diez «sesiones cortas» del §2.2 abiertas que el plan no
  nombraba, la excepción de GO-2026-6909 caducando antes del suelo del
  2.0, y prosa que se contradecía (topics tipados de ciclo de vida frente
  a DEP-2026-025; `/v2` «en 1.x» frente a «primer commit del major»;
  `pkg/model` «no se retira» frente a D5; «raíz: fix» frente al MINOR de
  orbit; la política de estabilidad de quark «pendiente» cuando ADR 0029
  la adoptó el 2026-10-06; el reporte privado de vulnerabilidades ya
  activo en los cuatro repos).
- **Las doce decisiones, una a una (D14…D25)**: guía regenerada en el set
  y guard aparte (D14); las diez cortas en 1.x antes de `M1` (D15); `M1-S0`
  primero (D16); lo aditivo de las 32 en la ventana (D17); `R2` completa
  (D18); GO-2026-6909 esperar hasta el 2026-12-15 (D19); señales según el
  aviso publicado (D20); soporte publicada sin LTS (D21); la ventana de
  suite manda (D22); `main` protegida en los cuatro con auto-merge (D23);
  Discussions sólo en quantum (D24); Scorecard publicada (D25).
  Registradas en el contrato (§3.3) y en el plan (quantum#322, con las
  correcciones de prosa verificadas por tres lentes y una confirmación);
  quantum#320 publica la nota de Scorecard; quantum#321 registra
  `umbrella-migration-guide` (61 guards).
- **Lo siguiente**: **`M1-S0`** (ver el bullet de la ventana); en
  paralelo, lo del propietario del §5 (protección de rama, Discussions) y
  la sesión de docs de la política de soporte.

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

- **El próximo tren** (el set del lunes 2026-11-23, o el siguiente que
  tenga algo que publicar): quark, nucleus y orbit no se han movido desde
  1.45.0 salvo lo que las sesiones de la ventana fusionen; los suelos
  módulo→raíz de nucleus (dieciséis a v1.36.0) y de quark (seis a v1.19.1)
  suben como primer commit de cada corte, como siempre; `bump-set`
  regenera ya la guía de migración (D14, quantum#321) sin `--incluye`.
- **Lo del propietario, con los comandos preparados** (D23, D24; tabla
  «Lo del propietario» del plan de A12): (1) Discussions sólo en quantum:
  Settings → General → Features → Discussions. (2) Protección de `main` en
  quantum, quark y orbit como la de nucleus, y «Allow auto-merge» en los
  cuatro — DESPUÉS del PR de orbit que lleve el refresco de la matriz de
  módulos a un PR (hoy `release-please.yml` hace `git push` directo a
  `main` tras cada tag y la protección lo rechazaría) y de un job agregador
  «CI Required Gate» en las lanes del paraguas (hoy sus checks son nueve
  nombres distintos). La forma de nucleus, leída el 2026-11-16 con
  `gh api repos/jcsvwinston/nucleus/branches/main/protection`: checks
  requeridos `["CI Required Gate"]` con `strict: true`, `enforce_admins`,
  `required_approving_review_count: 0` con `dismiss_stale_reviews`, sin
  force-push ni borrado, `required_conversation_resolution`. Se replica
  con `gh api -X PUT repos/jcsvwinston/<repo>/branches/main/protection
  --input protection.json` por repo y `gh api -X PATCH
  repos/jcsvwinston/<repo> -f allow_auto_merge=true` en los cuatro. Trampa
  conocida: exigir revisiones aprobadas bloquearía todos los merges (un
  solo humano); «rama al día» se conduce rebasando cada PR apilado antes
  de fusionarlo.
- **GO-2026-6909 (D19)**: el 2026-12-15, `curl -s
  https://vuln.go.dev/ID/GO-2026-6909.json` debe traer `fixed: 0.5.2`; si
  no, chore PR en nucleus moviendo la fecha de
  `scripts/ci/govulncheck_exceptions.txt` al 2027-03-31; si sí, el gate
  marcará la línea como rancia en la siguiente corrida: borrarla.
- **OR-149 (P3, orbit)**: el banco admin flakea en CI (EXT-04 con 405 al
  iniciar sesión, EXT-10 «partial») por el puerto que `tryStart` reserva
  y suelta; tres relanzamientos en el tren de 1.44.0 y uno en el de 1.45.0
  (la lane de integración del paraguas tras fusionar el set). Arreglo
  propuesto en `docs/auditoria/madurez-2026-09-03/orbit.md`.
- **El deploy del sitio unificado**: el run de `deploy.yml` tras
  quantum#319 salió verde; comprobar que la portada sirve 1.45.0; si el
  sitio sigue creciendo, el siguiente tope es la memoria del runner (16
  GB), no el heap.
- **Las 34 filas del §3.0 están `publicado`** desde Quantum 1.43.0
  (2026-11-07): la ventana más tardía abre el 2027-02-07 y el 2.0 no sale
  antes. Lo que queda con fecha: la excepción de `nucleus/scripts/ci/govulncheck_exceptions.txt` (GO-2026-6909 sobre `crewjam/saml` v0.5.2) **caduca el 2026-12-31**; decidido el 2026-11-16 (D19): comprobar el 2026-12-15 (bullet de arriba).
- **Lo que el tren de 1.42.0 dejó al driver** (nace el 2026-10-18; sección
  1.42.0 de `scripts/train/README.md`): `fase_repo` sube los suelos sin
  mirar si hay commits releasables desde el tag (con quark en `docs:` habría
  cortado módulos por delante de la raíz: se saltó la fase a mano);
  `align_set.sh` y manifest-guard §5 no conocen `datasource` ni `ui` (lista
  fija de seis); `align-orbit-pins.sh --check` no mira los pines internos,
  así que el segundo corte de orbit es a mano entero; y la plantilla de
  `orbit-align-notes.sh` es de antes de ADR-012. Ninguno frena un set;
  cada uno cuesta una vuelta a mano. **1.43.0 añade**: el segundo corte
  de orbit sigue a mano (tercer tren seguido); `suite-integral --cierre`
  necesita `NODE_OPTIONS=--max-old-space-size=8192` en el Mac para
  construir el sitio; y correr `guard-of-guards` en local ANTES de
  `--desde paraguas` (regla de 1.37.0) ahorra la vuelta de CI que esta vez
  se pagó.

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
- **Decisiones D9…D11 de `M0-E`** (nacidas el 2026-10-23, **decididas el
  2026-11-13, las tres en A**; bloque en `docs/planes/quantum-2.0.md`
  §3.3): D9 hecha en 1.x por `D9-N` (nucleus#662: `generate module`
  escribe las filas comentadas en un root `WithoutDefaults()` sin
  `WithAuthz()`), D10 por `D10-O` (orbit#596/#597), D11 la ejecuta `M1` (en 1.x nada cambia). Ninguna fila del §3.0 depende de ellas; **`D9-N` y `D10-O` publicadas en Quantum 1.45.0 (2026-11-16)**.
- **Lo que sigue esperando al propietario, y ninguna sesión puede cerrar**:
  cerrar el issue automático quantum#263 (lane de integración; quantum#262 lo cerró la sesión el 2026-11-16 con tres lunes en verde; la corrida programada del 2026-11-09 de integration.yml salió roja y la del 2026-11-23 decide); proteger `main` en quark, orbit y quantum y activar `allow_auto_merge` en los cuatro: **decidido el 2026-11-16 (D23), comandos en el bullet «Lo del propietario» de arriba**;
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
