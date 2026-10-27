# A12 — Rendimiento, re-auditoría y cierre a 5

> Lee antes [`README.md`](README.md): el contrato de sesión, qué fichero manda
> para cada pregunta y qué no decide una sesión sola.

> **El troceado salió de la MEDICIÓN.** `S0` midió el 2026-10-04 lo que el
> arco promete con números —quark contra pgx sobre PostgreSQL 16 real, el
> grafo de nucleus en cinco variantes, la cola SQL con 1 a 16 workers, el
> bundle del panel, el inventario de lo que va al major y cómo se repitió la
> auditoría del 2026-09-03— y reescribió el arco. Corrigió tres suposiciones
> del enunciado: la caché de sentencias no rinde en PostgreSQL (pgx ya
> cachea) y sí en MySQL; el RETURNING multifila de los lotes ya existe; y el
> peso del binario con driver es casi todo un solo paquete, `dbclassify`.

**Qué entrega.** Que las cifras que la suite publica sobre sí misma sean
ciertas y estén vigiladas, y que el 2.0 salga una sola vez: quark a una
distancia medida de pgx en las operaciones de una fila y en listas, la cola
SQL que escala con los workers, un binario con driver que no arrastra los
otros cuatro motores, un panel que viaja comprimido y dentro de presupuesto,
una re-auditoría que se puede repetir, y el major que retira todo lo
deprecado y voltea los defaults en un único corte (QADR-0010).

**Precondición del arco**: A10 cerrado para empezar; **A11 cerrado para `M0`
en adelante** (el major retira lo que A11 deprecie).

**Gate del arco**: los bancos de rendimiento (quark sobre PostgreSQL, cola
SQL, tamaño del binario, presupuesto del panel) en lanes con su veredicto
registrado; la re-auditoría con 5 en todas las dimensiones salvo comunidad,
o un A13 abierto con lo que falte; y el set 2.0.0 certificado sin ninguna
marca viva que prometa 2.0.0.

## Decisiones del arco (APROBADAS por Carlos el 2026-10-06)

`S0` las dejó escritas con la recomendación; Carlos las aprobó tal cual el
2026-10-06, junto con que **el 2.0 respeta la ventana de 90 días de
`POLITICA_DEPRECACION.md` y no sale antes de 2027-01-04** (varios avisos
vencen ese día).

1. **«A un 15 % de pgx», ¿frente a qué?** Pasando por `database/sql`, una
   lista de 100 filas ya cuesta un 10–23 % más que pgx nativo antes de que
   quark haga nada. **Recomendación**: frente a `database/sql` + pgx en
   todas las operaciones, y frente a pgx nativo sólo en las de una fila.
   **Y la decisión tiene que nombrar la máquina** (lo midió `Q1`): el
   trabajo propio de quark en un InsertOne cuesta unos 6 µs en un M4 Pro y
   unos 35 µs en la vCPU de un runner de GitHub, mientras el viaje de ida y
   vuelta sólo se multiplica por 2,4; las operaciones de una fila están en
   el umbral en el portátil (1,11–1,16×) y ausentes en el runner
   (1,24–1,31×). El banco registra el runner como referencia.
2. **«Panel ≤ 400 KB comprimido», ¿qué carga?** **Recomendación**: la carga
   inicial MÁS la navegación más pesada (el deep-link a Data Studio), por
   entrada y en gzip; el total con todo lo lazy no lo ve ningún usuario.
3. **La re-auditoría va ANTES del major**, con una confirmación ligera
   después: si encuentra algo rompiente, todavía entra en el 2.0 en vez de
   forzar un 3.0 (QADR-0010).
4. **El proveedor asynq sale a módulo propio en el major**, no en una minor:
   es una ruptura de empaquetado, y QADR-0010 las acumula.

## Lo que midió `S0`

### Quark frente a pgx, sobre PostgreSQL 16

Binario dentro del namespace de red del contenedor (loopback: domina la
CPU, el caso más estricto), medianas de 10, en un M4 Pro.

| Operación | `database/sql` | pgx nativo | quark | quark frente a `database/sql` | quark frente a pgx |
|---|---:|---:|---:|---:|---:|
| InsertOne (RETURNING id) | 50,4 µs | 48,7 µs | 57,4 µs | +14 % | +18 % |
| FindByPK | 48,9 µs | 50,5 µs | 57,5 µs | +17 % | +14 % |
| List100 | 103,3 µs | 84,1 µs | 127,4 µs | +23 % | **+52 %** |
| Preload100 (100 + 500 filas) | 268,2 µs | 246,2 µs | 608,6 µs | **+127 %** | **+147 %** |
| InsertBatch1000 (con ids) | 1,93 ms | 1,78 ms | 2,55 ms | +33 % | +44 % |

Por qué, según el perfil:

- **`List` serializa a JSON todo el resultado aunque no haya caché**
  (QK-34): el 13,6 % de la CPU de List100 y 11 KB por llamada que se tiran;
  `Find` lo paga porque pasa por `List`. Quitándolo, List100 baja de +52 % a
  +30 % frente a pgx.
- **El preload usa `IN ($1..$N)`** y PostgreSQL replanifica cada ejecución
  (QK-35): unos 200 µs del hueco son la forma de la consulta (`= ANY($1)`) y
  unos 180 µs el mapeo por reflexión.
- **Los lotes**: un `fmt.Sprintf` por parámetro en `Placeholder` (13 % de la
  CPU), `reflect.Value.Interface` (10 %) y `Validate` (6,5 %); y en MySQL y
  MSSQL con PK autogenerada el backfill hace un INSERT por fila (QK-36).
  COPY sólo gana a partir de unas 10 000 filas (la mitad de tiempo); con 100
  y 1000 empata o pierde.
- **Sentencias preparadas**: en PostgreSQL pgx ya las cachea; en MySQL cada
  consulta de quark hace prepare + exec + close, y reutilizarlas (o
  `interpolateParams=true`) recorta un 38–48 % (QK-37).
- La página pública de benchmarks sólo mide SQLite en memoria con versiones
  viejas (QK-38).

### El grafo de nucleus

| Variante | hello sin driver | hello + `drivers/sqlite` | starter `api` |
|---|---|---|---|
| hoy | 92 módulos · 366 paquetes · 21,1 MB | 134 · 479 · 45,6 MB | 137 · 536 · 49,6 MB |
| el predicado de SQLite dentro de su driver (NU-8, A11 `N3`) | igual | **105 · 402 · 25,0 MB** | 108 · 460 · 29,0 MB |
| + tests y CLI fuera del módulo raíz | 79 | 92 | 95 |
| + asynq fuera del core | — | **88** | 88 |

Binarios con `-s -w`. Mover sólo el predicado quita 29 módulos y 20,6 MB
(un 45 %): `dbclassify` importa los tipos de error de los cuatro motores y
`link.go` los cinco drivers, y todo driver importa `dbclassify`. **Ese
arreglo es de A11** (`N3`, NU-8), porque el banco del catálogo lo mide en la
aplicación; A12 hereda el binario adelgazado. Lo que queda aquí: el
`go.mod` raíz lleva dependencias que sólo usan los tests (miniredis,
goleak) y la CLI (los cuatro motores vía `RegisterAll`), `nucleustest`
importa SQLite en código de producción, y el hello sin driver creció de 87
a 92 módulos desde ADR-031 sin que nada lo vigilara (NU-106). `go list -m
all` es mala métrica: de 79 módulos, 40 se enlazan; el gate vigila paquetes,
módulos enlazados y binario.

### La cola SQL (NU-87)

| Modo | 1 worker | 4 | 16 |
|---|---:|---:|---:|
| `Manager` real, poll de 1 s | 1217 jobs/s | 1202 | 1667 |
| claim sin dormir | 1055 | 1169 (75 % de claims perdidos) | **795** (90 % perdidos) |
| prototipo con `FOR UPDATE SKIP LOCKED` | 1689 | 4442 | **7447** |

El techo actual son unos 1100–1200 jobs/s por muchos workers que se añadan,
y con 16 rinde menos que con 4: `Manager` reclama de uno en uno y el que
pierde la carrera duerme el `PollInterval` entero. Con SKIP LOCKED escala
4,4× hasta 16 workers.

### El panel de orbit

| Entrada | JS inicial | CSS inicial | lazy | total (gzip) |
|---|---:|---:|---:|---:|
| panel | 101,7 KB | 7,5 KB | 407,4 KB | **516,5 KB** |
| fleet | 131,0 KB | 5,1 KB | 0 | 136,1 KB |

La carga inicial cumple; el deep-link a Data Studio suma 402 KB, justo en
el umbral (ag-grid es el 89 % de ese chunk). **El servidor no comprime
nada**: lo que viaja es el tamaño sin comprimir (el fleet, 477 KB). El
presupuesto de CI mide raw e inicial; y admin-server embebe el dist entero,
1,98 MB del panel incluidos, aunque sólo sirve el fleet (OR-61).

### El major 2.0

> **El contrato completo del 2.0** —qué entra, qué tiene que estar hecho antes
> y cuándo está terminado, rediseño estético incluido— está en
> [`quantum-2.0.md`](quantum-2.0.md). Lo de abajo es la medición de `S0` y
> las decisiones que lo alimentaron.

Doce símbolos deprecados con aviso y fecha (quark 5: DEP-2026-001/002;
nucleus 7: DEP-2026-009/011/012; orbit ninguno). Lo que el guard NO ve
(QM-20): los **volteos de comportamiento** no tienen aviso DEP —NU-72
(`session_idle_timeout`), OR-57 (identidad del agente por certificado),
QK-24 (`GroupBy` sin `Select` a error), QK-32 (`ESCAPE` en el LIKE plano), y
problem+json como formato por defecto, que ni siquiera tiene fila—; quitar
`Context.Set` no hace nada porque `router.Context.Set` se promociona con la
misma firma; y la política dice que no hay avisos vivos en nucleus cuando
DEP-2026-003 lo está (sin fecha de retirada). Orbit rompe con el major en
unos 14 sitios (`authz.New`, `NewWrapResponseWriter`), lee los errores sólo
del sobre (`ui/src/services/api.ts`) y construye su LIKE con escape propio:
tiene que migrar ANTES, en una minor.

**Decisiones de Carlos del 2026-10-06 para el major** (`M0` las convierte en
filas con su aviso):

- **Al 2.0 por decisión**: QK-45 (`UpdateBatch` comprueba la versión por
  defecto; la opción explícita llega antes, en una minor), y las
  divergencias entre motores QK-59 (`Upsert` con `updateCols` vacío), QK-60
  (`ON DELETE SET DEFAULT` en MySQL/MariaDB) y QK-65 (`Upsert` con el
  duplicado en otra clave única).
- **Negativas ya programadas con aviso** (DEP-2026-013…018, de la tanda del
  2026-10-06): una aplicación `WithoutDefaults()` que declara storage, mail,
  rate limit, claves de authz, filas de política de módulo o el profiler sin
  la opción que los monta deja de arrancar en v2.0.0. **`WithAuthz()` se
  ofrece como opción** (decisión de Carlos) y es la salida de las de authz y
  del profiler (nucleus#620).
- **También al 2.0 (decididos la misma tarde)**: QK-58 (las demás escrituras
  fuera del bloqueo optimista; sigue a QK-45), QK-46 (efectos laterales de
  una escritura que no tocó filas) y NU-121 (`nucleustest` sin SQLite).
- **OR-67** no espera al major: import y `loaddata` exigen ya el permiso de
  cada modelo (orbit#551).

### La re-auditoría

La del 2026-09-03 no se puede repetir tal cual (QM-21): los prompts de los
auditores no se guardaron, **la tabla «qué significa 5» sólo existe en un
artefacto**, el «rendimiento 3» salió de leer código (sin Docker ni un
benchmark), lo auditado entonces (`examples/`) ya no existe, y
`check_audit_backlog.sh` rechaza un A13 y no detecta ids duplicados (había
dos NU-50; el segundo es ahora NU-105). **Lo cerró `R0`**: la escala está en
[`../auditoria/criterios-5.csv`](../auditoria/criterios-5.csv) y el método,
con los prompts de cada auditor, en
[`../auditoria/reauditoria/`](../auditoria/reauditoria/README.md).

## El troceado

Cinco hilos en paralelo (repos o ficheros distintos) y un cierre en serie.

| Sesión | Qué entrega | Precondición | Criterio de hecho |
|---|---|---|---|
| `Q1` | Banco de rendimiento de quark sobre PostgreSQL real (el arnés de `S0` en `quark/benchmarks`, lane con Docker, veredicto por operación como los demás bancos) y `benchmarks.mdx` con cifras de PostgreSQL (QK-38) | `S0` | lane verde con las 5 operaciones × `database/sql`/pgx/quark; página publicada |
| `Q2` | CPU: sin JSON cuando no hay caché (QK-34), preload con `ANY($1)` en PostgreSQL (QK-35), `Placeholder` sin `Sprintf`, `Validate` sólo con tags, menos asignaciones en el mapeo | `Q1` | las cifras que fije `Q1` con la decisión 1 |
| `Q3` | Lotes y sentencias: COPY por encima de un umbral en PostgreSQL, backfill de MySQL/MSSQL sin un INSERT por fila (QK-36), sentencias reutilizadas en MySQL/MSSQL/Oracle o `interpolateParams` documentado y medido (QK-37) | `Q1`; en paralelo con `Q2` | lote de 10 000 en PG cerca de COPY; FindByPK en MySQL −40 % |
| `N1` | El grafo: tests a un módulo interno, CLI a módulo propio (patrón de quark A3, con sus trampas de `go install`), `nucleustest` sin SQLite; lane «hello-world stays small» midiendo hello + driver por paquetes, módulos enlazados y binario (NU-106) | A11 `N3` | hello + SQLite ≤ 92 módulos y ≤ 25 MB con `-s -w`; la lane muerde al crecer |
| `N2` | La cola: claim con SKIP LOCKED en PostgreSQL y MySQL 8 (SQLite se queda como está), el worker que pierde reintenta sin dormir (NU-87), y el apagado que para el scheduler antes de cerrar la base (NU-103) | `S0` | ≤ 5 % de claims vacíos con 16 workers y W=16 ≥ 2× W=1 en la lane de cada motor (el ≥ 4× sólo en local: en el runner mide la máquina); la puerta de 10 000 jobs en verde; parada < 1 s |
| `O1` | El panel: compresión en el servidor (precomprimido en el embed), ag-grid y recharts troceados, presupuesto en gzip por entrada y por ruta, admin-server sin el dist del panel (OR-61); el contraste del tema claro del fleet (OR-59) y los errores del panel como texto legible (OR-62) | `S0`; decisión 2 | el presupuesto falla al pasarse; respuestas con `Content-Encoding`; `UIF-02` present; un control de navegador de formulario con errores en los dos temas |
| `R0` | Preparar la re-auditoría: la tabla «qué significa 5» y los prompts de los auditores al repo, `check_audit_backlog.sh` acepta A13+ y detecta ids duplicados (QM-21) | `S0`; en cualquier momento | guards con su fixture; la tabla en el repo |
| `M0` | Preparar el major: decidir cada volteo (NU-72, OR-57 sólo con mTLS, el sobre con opción de quedarse, las firmas de constructores, `pkg/model`, signals), un aviso DEP y una fila por volteo, `umbrella-deprecations` ampliado a volteos, la política corregida (QM-20); y **orbit migra antes, en una minor** | A11 cerrado | el guard ve el 100 % de lo que va al major; orbit compila contra la rama del major |
| `R1` | La re-auditoría completa con el método del 2026-09-03 más un auditor de rendimiento, sobre el último set 1.x y la lista cerrada del major; pasada adversarial y consolidación con las notas en CSV y guard | `Q*`, `N*`, `O1`, `R0`, `M0` | informe, registro y notas con guard; lo rompiente que encuentre entra en `M1` |
| `M0-R` | Lo que `R1` dejó para antes del major: los cuatro avisos `por escribir` del §3.0 (filas 31–34: QK-76, OR-80, OR-93, OR-103) con su salida en 1.x, y los cuatro P1 de la re-auditoría (OR-78, OR-79, OR-80, OR-99) como `fix` de 1.x | `R1` | las cuatro filas `publicado` al pin; los cuatro P1 `hecho` en un set 1.x; `umbrella-deprecations` sin `por escribir` |
| `M1` | El 2.0: retirar los doce símbolos, voltear los defaults, asynq a módulo propio (decisión 4), guía de migración generada; tren de cuatro repos | `R1`, `M0-R` | set 2.0.0 certificado; ninguna marca viva que prometa 2.0.0 |
| `R2` | Confirmación ligera sobre el 2.0: bancos, guards y re-puntuar sólo lo que `M1` tocó; A12 cerrado | `M1` | todas las dimensiones a 5 salvo comunidad, o A13 abierto con lo que falte |

`Q1→(Q2 ∥ Q3)`, `N1`, `N2`, `O1` y `R0` van en paralelo y pueden solaparse
con A11 si no tocan los mismos paquetes. `M0 → R1 → M0-R → M1 → R2` va al final y
en serie.

`M0` tiene su propio troceado en seis sesiones, medido el 2026-10-16: está
en la sección siguiente.

## `M0` — inventario medido y troceado (2026-10-16)

> `M0` toca los cuatro repos y lleva ocho decisiones que no toma una sesión
> sola, así que no cabe en un PR: igual que el arco, empieza por una sesión
> de medición (`M0-S0`, esta) cuyo producto es el troceado de abajo y la
> lista cerrada del major en [`quantum-2.0.md`](quantum-2.0.md) §3.0. Lo que
> sigue se midió sobre el pin de 1.41.0 con los comandos que se citan;
> nada es copia de `S0`.

### Lo que hay, contado

| Qué | quark | nucleus | orbit | Cómo se contó |
|---|---:|---:|---:|---|
| Marcas `// Deprecated:` a mano (el guard las ve) | 5 (2 avisos: 001, 002) | 7 (3 avisos: 009, 011, 012) | 0 | `bash scripts/check_deprecations.sh` → 12 marcas, 0 vencidas |
| Avisos de VOLTEO escritos, sin marca (el guard NO los ve) | 1 (003: `UpdateBatch`, 2027-01-04) | 6 (013…018: negativas de `WithoutDefaults()`, 2027-01-02) | 0 | `grep -l 'Behaviour flip\|Earliest change' */docs/deprecations/*.md` |
| Avisos `active` sin fecha (contra la política §2) | 0 | 1 (003: filas de política de 3 columnas) | 0 | `grep -A3 'Status: .active' nucleus/docs/deprecations/DEP-2026-003*` |
| Volteos decididos SIN aviso todavía | 6 (QK-58, QK-46, QK-59+65, QK-60, QK-24, QK-32) | 2 (NU-121, asynq a módulo) | 1 (OR-57: lo promete el comentario de `server/config.go`, no un aviso) | registro.csv × `docs/deprecations/` |
| `docs/deprecations/` existe | sí | sí | **no** | `ls */docs/deprecations` |
| Siguiente id libre | `DEP-2026-004` | `DEP-2026-019` | `DEP-2026-001` | idem |

Lo que cambia respecto a lo que decía el enunciado de `M0`:

- **Los «~14 sitios» de orbit son dos y una decisión.** `authz.New(logger,
  policyPath...)` no tiene parámetro muerto ni está deprecado: aparece en 1
  fichero de producción (`agent/datastudio/datastudio.go:214`) y en 17 de
  test, y romperlo sería sólo por estilo (NU-41 pide el logger al final).
  `NewWrapResponseWriter(w, _ int)` sí lleva un parámetro muerto y orbit lo
  llama en 2 sitios (`internal/admin/audit.go:397`, `live.go:540`). La
  propuesta (D4 en `quantum-2.0.md`) es deprecar sólo el segundo.
- **El bus único ya existe: es `signals.Bus` con dos puertas.** A7 `S6`
  entregó la tipada (`Define`/`Subscribe`/`Publish`, `pkg/signals/typed.go`)
  junto a la no tipada (`Signal`, `Event{Payload any}`, `Handler`,
  `Bus.On/Emit/EmitAsync`), y una publicación llega a las dos. Lo que se
  solapa no es otro paquete —`observability.Bus` es el fan-out de
  observabilidad, no eventos de dominio—, sino la puerta sin tipo. Orbit
  guarda un `*signals.Bus` en el adaptador y en el panel; qué le llama lo
  mide `M0-O`.
- **`pkg/model` no se puede retirar en el 2.0 sin matar el adaptador de
  orbit**: 48 símbolos exportados; en nucleus lo importan `pkg/app`,
  `pkg/nucleus`, `pkg/nucleustest`, `pkg/observability/hooks` y los tres
  generadores de la CLI; en orbit, 6 ficheros de 3 módulos (`agent`,
  `datasource/nucleus` entero —`ModelMeta`, `FieldMeta`, `Registry`,
  `Filter`, `NewCRUD`—, `internal/admin`); 7 páginas del sitio lo
  enseñan. La propuesta (D5) era bajarlo a sustrato en el 2.0 y retirarlo
  en el 3.0; **Carlos decidió el 2026-10-16 retirarlo en el 2.0** y, con
  él, el adaptador `datasource/nucleus` de orbit (D5b): el panel queda
  sólo sobre `quarkdatasource`. Es lo que más trabajo añade a `M0-O` y a
  `M1`.
- **El sobre no tiene opción de quedarse**: existe `WithProblemDetails()`
  (opt-in a problem+json) y ningún `WithErrorEnvelope()`. Voltear el default
  exige la salida primero (D3), y orbit lee los errores sólo del sobre
  (`ui/src/services/api.ts:43-47`).
- **El `LIKE` propio de orbit** está en `quarkdatasource/store.go`
  (`Cmp(col, "LIKE", Lit(pattern))` + `escapeLike` + `dialectEscapesLike`):
  cuando QK-32 declare `ESCAPE '\'` en la forma plana, ese escape cambia de
  significado en tres motores. La forma portable ya existe desde A8
  (`WhereLike`/`WhereContains`…), así que la migración es cambiar la llamada.
- **La ventana la fija el último aviso que se publique**: los que salgan en
  el set del 2026-10-19 abren el 2027-01-17; en el del 10-26, el 2027-01-24.
  El 2.0 no sale antes de la última.

### Las sesiones de `M0`

`M0-S0` → **decisiones D1…D8 de Carlos** (bloque en `quantum-2.0.md` §3.3,
**decididas el 2026-10-16**; D5 contra la recomendación) → `M0-Q` ∥
`M0-N` ∥ `M0-G` → `M0-O` → `M0-E`. Las tres del medio van en
paralelo porque tocan repos distintos; `M0-O` espera a que una release de
nucleus publique las salidas que orbit necesita; `M0-E` es el ensayo que
cumple el criterio de `M0`.

| Sesión | Qué entrega | Precondición | Criterio de hecho |
|---|---|---|---|
| `M0-S0` | Este inventario, el troceado, la lista cerrada del major (§3.0 del contrato) con las ocho decisiones escritas como propuesta, y la política §1/§6 puesta al día con lo medido | A11 cerrado | PR fusionado; `bash scripts/check_deprecations.sh` y `bash scripts/check_handoff_size.sh` en verde |
| `M0-Q` | quark: un aviso por decisión —DEP-2026-004 (QK-58), 005 (QK-46), 006 (QK-59+QK-65: `Upsert` igual en los seis), 007 (QK-60), 008 (QK-24), 009 (QK-32), y 010 (QK-50) si D7 lo confirma—, cada uno con `Scope: behaviour`, la salida que ya existe en 1.x y el test que pina el comportamiento v1 nombrado; godoc de cada método afectado; CHANGELOG; README de `docs/deprecations/` | `M0-S0`; D7 sólo para el 010 | cada test que un aviso cita, en verde (`go test -run` del aviso); `check_deprecations.sh` verde al pin que los traiga |
| `M0-N` | nucleus: avisos DEP-2026-019… para NU-121, asynq a módulo propio (`Scope: packaging`), NU-72 (D1), problem+json por defecto (D3), `NewWrapResponseWriter` (D4, con marca), la puerta no tipada de `signals` (D6, con marcas), la retirada de `pkg/model` como capa pública (D5, con marcas en lo que se retira), NU-110 (D8) y la fecha de DEP-2026-003 (D2); y las salidas en 1.x: `WithErrorEnvelope()`, `router.Wrap(w)`, topics tipados para las señales de ciclo de vida; baselines regenerados sólo con adiciones | D1…D8 | `make check` verde; `check_deprecations.sh` verde al pin; cada aviso nombra el test que pina v1 y el que ejercita la salida |
| `M0-G` | paraguas: `check_deprecations.sh` lee también `<repo>/docs/deprecations/DEP-*.md` con `Status: active` —exige `v2.0.0` + «no earlier than», FALLA por versión ≤ pin, AVISA por fecha vencida— y cruza la tabla de `quantum-2.0.md` §3.0: una fila `publicado` sin fichero al pin FALLA, una `por escribir` AVISA, y un aviso `active` al pin que nombre `v2.0.0` y no esté en la tabla FALLA; fixture con las dos roturas; política §5/§6; **QM-20 hecho** | `M0-S0` (el pin de 1.41.0 ya trae siete avisos de volteo que leer) | `guard-of-guards` verde; `check_deprecations.sh` enumera el 100 % de las filas de §3.0 |
| `M0-O` | orbit: `docs/deprecations/` con README, DEP-2026-001 (OR-57, con la salida `AllowSharedAgentCertificate` en 1.x) y DEP-2026-002 (el adaptador `datasource/nucleus` se retira en el 2.0, D5b: marca en su API y el panel sobre `quarkdatasource` como salida); la migración en una minor: `api.ts` lee problem+json y el sobre, `router.Wrap`, `WhereLike`/`WhereContains` en `quarkdatasource`, topics tipados donde use la puerta sin tipo; nada de la lista de retiradas queda referenciado. **Troceada el 2026-10-18** como `M0-Q`: **(a)** todo lo que sólo necesita lo que el set ya pina (los dos avisos y el README, la salida, las marcas y el aviso al montar, el `LIKE` escapado, `api.ts`) y **(b)** las dos llamadas a `NewWrapResponseWriter` → `router.Wrap` con el require de nucleus v1.33.0 | (a) `M0-S0` y D1…D8; (b) `M0-N` publicado en una release de nucleus (orbit requiere esa minor) | `grep` de los símbolos de §3.1 y de la puerta sin tipo sobre orbit = 0 fuera de tests de compatibilidad; banco admin 72/72 e IDENT-06 present; CI verde |
| `M0-E` | el ensayo del major: ramas `dry-run/2.0` en quark y nucleus (sin fusionar, sin tag) con todo §3 aplicado; orbit `main` compila y pasa `go test ./...` contra ellas por `go.work`; borrador del generador de la guía de migración (una entrada por aviso) | `M0-Q`, `M0-N`, `M0-O`, `M0-G` | `go build ./... && go test ./...` de orbit contra las ramas en verde; la tabla de §3.0 sin ninguna fila `por escribir`; **`M0` hecha** |

**Lo que `M0` NO hace**: retirar nada ni voltear nada (eso es `M1`), ni
decidir la dirección visual del rediseño (§3.4 del contrato, Carlos entre
maquetas), ni la DX al 5 (§2.1, aditiva, en sets 1.x por su lado).

## `M0-E` — el ensayo del major, medido (2026-10-18 / 2026-10-23)

> Ramas `dry-run/2.0` en los tres hermanos (quark, nucleus y orbit; sin
> fusionar, sin tag, empujadas como ramas de trabajo) con los treinta
> avisos aplicados: doce grupos en paralelo (uno por conjunto de avisos que
> comparten ficheros), cada grupo refutado por un revisor, un integrador
> por producto que fusionó, regeneró y corrió la verificación completa, y
> un auditor por producto que la repitió. Lo de abajo es lo que el §3 del
> contrato NO decía y el 2.0 necesita; los números son del `main` del
> 2026-10-18. Las ramas de grupo (`dry-run/2.0-A…F`) quedan como historia
> en cada hermano.

### Tres dependencias estructurales que ningún aviso nombraba

1. **La ruta de módulo `/v2`** (§3.5 del contrato): Go no resuelve un tag
   `v2.0.0` sobre un módulo cuyo `go.mod` no lleve el sufijo. Es el primer
   commit del major de cada repo (13+17+9 `go.mod`, 397+479+152 ficheros
   Go, 151 más en orbit por nucleus/quark), y lo que el paraguas compara
   por ruta literal (manifest-guard §5, `align_set.sh`, `print-requires.sh`,
   el catálogo de `nucleus add`, `go install …/cmd/nucleus@v2.0.0`). El
   ensayo NO lo aplicó, para que orbit compile contra las ramas por
   `go.work`; va presupuestado en `M1`.
2. **El §2.1 (la DX al 5) es prerrequisito de DEP-2026-024, no trabajo
   paralelo**: `nucleus generate model` y `generate resource` escriben
   `import "github.com/jcsvwinston/nucleus/pkg/model"` y `model.BaseModel`
   en el código del usuario, `nucleustest.Make` escribe por el CRUD de
   `pkg/model`, y el sitio enseña `pkg/model` en `quickstart.md` y
   `models-and-database.md`. En la rama `pkg/model` se movió a
   `internal/model` y el framework compila; lo que queda rojo son los
   tests de `internal/cli` que construyen lo que los generadores escriben.
   Sin la DX al 5 en 1.x, `M1` no puede retirar `pkg/model`.
3. **El panel de orbit sin el adaptador necesita quark en el grafo de la
   raíz**: 31+7 ficheros de test del panel y el banco admin montaban sobre
   `datasource/nucleus`; la rama los mueve a `quarkdatasource` sobre SQLite
   y la raíz de orbit pasa a requerir quark y `quarkdatasource`. El ADR-012
   de orbit (quark fuera del grafo de la raíz) deja de tener razón de ser
   con D5b (D11). Y el starter de la suite y el showcase del paraguas, que
   montan `orbit.Module` sin `DataSource`, rehúsan arrancar en el 2.0
   (`TestModule_DataSourceIsRequired` lo pina): la DX al 5 también los
   alcanza.

### Lo que cada aviso no decía (y la rama tuvo que decidir o medir)

- **quark**. DEP-003 y DEP-004 se cruzan: los tests de salida de 003
  siembran con `UpdateMap` sobre una fila versionada y voltean bajo 004.
  `Dialect.UpsertSQL` NO necesitó parámetro nuevo (la guarda de versión no
  liga nada), así que el punto de extensión congelado no se toca. La
  propuesta de DEP-004 de rechazar con `ErrInvalidQuery` un mapa que nombre
  la columna de versión NO se aplicó: rompería la salida v1 que el propio
  aviso enseña (`Where("version","=",v).UpdateMap(…"version": v+1)`); el
  mapa se escribe tal cual, sin bump, y los pines lo dicen (`M1`
  confirma). `UpsertBatch` pasa a fila a fila también en los demás motores
  cuando el modelo es versionado y hay `updateCols`; en MSSQL/Oracle una
  entidad con clave entera cuesta uno o dos viajes más antes del `MERGE`.
  **Defecto de 1.x destapado**: en `UpsertBatch` la columna clave entra en
  el INSERT multifila sólo si la PRIMERA entidad lleva clave; las claves de
  las siguientes se descartan en silencio. DEP-007: el catálogo de MySQL
  devuelve `SET DEFAULT` para claves creadas antes, así que un `Diff` de un
  esquema que aún lo declara no planifica nada ni rehúsa. DEP-010: un
  `VARCHAR2(n)` a secas en `normalizeType` es la columna BYTE (el default
  de Oracle) y la introspección devuelve la unidad que encuentra. DEP-009
  alcanza también `Having`/`HavingAggregate` con LIKE, `WhereJSON` y
  `PreloadWhere` (trece puertas validan el patrón); las sondas
  LIKE-01/02/05 del banco enterprise abortaban en vez de reverdictar.
  DEP-008 valida los identificadores agrupados ANTES de exigir la
  proyección (el kit de drivers lo espera así) y `Paginate` envía su COUNT
  antes de rehusar. Las páginas `docs/enterprise-bench.md` (49 de 69),
  `docs/extension-bench.md` (22 de 22) y `docs/query-bench.md` (60/0/0) se
  regeneran y coinciden con lo que fusionó git. Los pines por motor sólo
  se ejercitan en la matriz de integración de CI (Docker): la rama no se
  certifica desde los tests del módulo raíz. Los drivers en `GOWORK=off`
  ya estaban rojos en el `main` base (pinan quark v1.16.0 y su kit de test
  usa símbolos posteriores): el efecto «módulo nacido tras el pin», no de
  la rama.
- **nucleus**. DEP-017 choca con la decisión del propietario del
  2026-10-06 (el starter `api` sin `WithAuthz()`): un starter recién
  generado con un módulo generado (`generate module` escribe filas de
  política) rehúsa arrancar en el 2.0 → D9. DEP-020 necesita un registro
  de proveedores en `pkg/tasks` que no existe (hoy `pkg/nucleus/jobs.go`
  elige asynq por import directo): es trabajo de 1.x ANTES del major, y el
  módulo nuevo nace con el tag (las lanes `standalone` están rojas hasta
  entonces; las listas de módulos de ci.yml, dependabot, release-please,
  `knownproviders`, SECURITY.md y codeql.yml son a mano). DEP-025 se
  contradice: `RedisRelay` (`Channel/Publish/Subscribe/ForwardToBus`) está
  tipado sobre `Signal/Event/Handler` aunque diga «not affected» → se
  retipa sobre nombres y `Topic[T]`; el bridge del outbox publica por la
  puerta tipada con `Define[[]byte]`. DEP-024 arrastra más que
  `Runtime.Models()`/`App.Models`: `App.RegisterModel`,
  `ErrModelsRegistered…`, `hooks.NewSQLObserver` (ahora con tipos propios
  en `pkg/observability/hooks`), y `App.AutoMigrate` sigue leyendo la
  gramática `db:` de `pkg/model`; el WARN de arranque por directivas `db:`
  desconocidas no lo retira ningún aviso y se conserva. DEP-022:
  `App.ProblemDetails()` pasa a significar «la forma efectiva»; las tres
  plantillas del starter no pasan opción y contestan problem+json; los
  handlers que escribe `generate resource|module` escriben su propio
  `{"error": "<texto>"}` fuera del marco. DEP-021 cambia dos baselines
  congelados (postura de seguridad y ASVS). DEP-026: el default
  `_time_format=sqlite` vive en `pkg/db` (junto a `busy_timeout`), así que
  el test del driver sólo es verde con el workspace hasta el re-pin; se
  aplica también a rutas desnudas y `:memory:`. DEP-019: tres consumidores
  internos del driver implícito (`internal/jobsbench`, `internal/apibench`,
  `internal/catalogbench`), no uno.
- **orbit**. `quarkdatasource` necesitó tres arreglos para que el panel
  fuera correcto sobre él (un `Get` de un id inexistente contestaba 500 en
  vez de 404, un `Delete` de cero filas no decía NotFound, y la respuesta a
  un alias que ningún adaptador sirve): son `fix` de 1.x y van ANTES del
  major, con los tests que la rama añade. El panel se apoyaba en
  coerciones del adaptador de Nucleus que el contrato nunca prometió
  (celdas CSV como cadenas…). El adaptador de Quark no tiene opciones de
  metadatos por campo (lo que las etiquetas `admin:` daban al de Nucleus)
  → D10. Quark no aplana structs embebidos y sólo corre `BeforeUpdate` en
  guardados de entidad (el adaptador actualiza con `UpdateMap`): una
  validación escrita como hook de Quark guarda sólo las creaciones.
  DEP-001: cuatro tests fuera de la lista del aviso registraban un
  `node_id` distinto del CN bajo mTLS (IDENT-02/04/08 y
  `with_client_cert_connects`) y el test del WARN de arranque, listado como
  «salida», pinaba el WARN de 1.x. El agente deja de recibir `Databases`;
  el arnés del fleet envuelve su pool con `quark.NewWithDB`. El
  `internal/fleettest/go.mod` pina `server` v0.19.0 y `ui` v1.1.0 (fuera
  del guard de pines, que sólo mira los módulos publicados).

### Resultado del ensayo (2026-10-23)

| Repo | Rama `dry-run/2.0` (en origin) | Verde | Rojo que queda, y por qué |
|---|---|---|---|
| quark | `a2b4558d` (10 avisos `removed`/`completed`) | `make lint`, `make docs-guards`, `make regen` sin diff, `go build && go vet`, `go test ./...` del módulo raíz, `go vet -tags=integration` en enginesuite y los cinco drivers, `make superapp` en SQLite (gate estricto) | los pines por motor (PG, MySQL, MariaDB, MSSQL, Oracle) sólo corren en la matriz de integración de CI; los drivers en `GOWORK=off` ya estaban rojos en el `main` base (pinan quark v1.16.0 y su kit usa símbolos posteriores) |
| nucleus | `2dd5b82f` (18 avisos `removed`/`completed`, 25 filas en el registro) | `make vet`, `make guards`, `go test ./contracts/` (seis baselines regenerados: cada línea que desaparece es un símbolo que un aviso retira), 52 paquetes del raíz, `check_hello_size` (75/88 enlazados, bajo techo), el starter de la suite con los hermanos en `dry-run/2.0` | **§2.1**: `internal/cli` (4 tests) y `cmd/nucleus` (3) porque `generate model/resource` y el quickstart escriben `pkg/model` en el código del usuario; `providers/tasks-asynq` y `cmd/nucleus` en `GOWORK=off` hasta que exista el tag (el registro de proveedores nace en la rama); `catalogbench` EX-01 sólo por el toolchain local (go1.26.6 con `GOTOOLCHAIN=auto` no puede bajar 1.26.9 en el HOME temporal; en CI pasa) |
| orbit | `f584a53` (2 avisos) | build, vet y tests de raíz, agent, server, quarkdatasource y fleetbench con el workspace; **contra quark y nucleus en `dry-run/2.0` por el `go.work` del paraguas: build, vet y tests de todos sus módulos en verde** (el criterio de `M0-E`) | **rojo real**: la mitad de navegador del banco admin (UIX-08/12/16/17/18) mide `absent` sobre la fixture Quark, que abre un segundo pool SQLite sobre el mismo fichero que el handle de la app y bajo las peticiones concurrentes del navegador el `count` espera el lock hasta agotar los 10 s de Playwright (`main` pasa en el mismo entorno; el banco HTTP, secuencial, no lo ve; la rama sigue registrando `present` porque el arnés se salta sin `node_modules`): `M1` lo arregla compartiendo el pool (`quark.NewWithDB` sobre el handle, como hace el arnés del fleet). La lane `standalone` de la raíz necesita una release de `quarkdatasource` con los arreglos de la rama; las lanes de motores reales no se corrieron |

**Lo que va a 1.x ANTES del major** (no rompe nada; sale de las ramas con
el test que lo pina): en nucleus, el registro de proveedores de `pkg/tasks`
(`Provider`, `RegisterProvider`, `LookupProvider`, `RegisteredProviders`;
prerrequisito de DEP-2026-020), la entrada `tasks-asynq` en
`knownproviders` y en `nucleus add`, `doctor --check tasks` por el registro,
`knownproviders.RequireDBDriver` compartido por `pkg/db` y
`nucleustest.Transactional`, los tipos públicos `hooks.SQLQueryEvent/
SQLQueryObserver`, el WARN por directivas `db:` desconocidas enganchado en
`AutoMigrate`, `nucleustest.Make` rehusando un modelo que no puede leer,
nombres únicos en los tests de proveedores, los patrones nuevos de
`check_retired_claims.sh` y las correcciones de doc (README/SPEC/
DEVELOPER_MANUAL sobre `pkg/tasks`, AUTH_GUIDE y `jwt.go` sin
`NewJWTManager`, la forma de error en las guías); en orbit,
`fix(quarkdatasource)` (un `Get` de id inexistente → 404, un `Delete` de
cero filas → NotFound, la respuesta a un alias que ningún adaptador
sirve), `fix(admin)` con las coerciones que el adaptador de Nucleus hacía
y Quark no (celdas CSV al tipo declarado; `IsReadOnly && !IsPK` en la
importación; el stamp del padre en los inlines), las fixtures de identidad
del fleet independientes del régimen, los pines de
`internal/fleettest/go.mod` (nucleus v1.30.1→v1.33.0, quark v1.15.0→
v1.17.0, sqlite, quarkdatasource, server, ui) y el README de
`quarkdatasource`, que aún dice que nil deja al agente sobre el adaptador
de Nucleus. En quark nada: sus diez avisos son volteos o retiradas puras.

**Lo que los avisos deben corregir** (lo aplicado es más ancho o distinto
de lo escrito): DEP-2026-025 sigue diciendo que `RedisRelay` «no se ve
afectado» cuando se retipa entero; DEP-2026-002 no nombra la retirada de
`agent.Config.Registry` y `agent.Config.Databases`; DEP-2026-014 promete
«ni siquiera se le preguntan sus capacidades» pero `pkg/plugins.
DiscoverExternal` y `Host.CollectInventory` siguen sondeando cada
`nucleus-plugin-*` del PATH (en el repo nadie los llama con un plugin no
listado; un consumidor externo —orbit tiene un `Host`— sí): falta un
parámetro de política; DEP-2026-011 retira `nucleus.Context.Set` pero
`c.Set` sigue compilando por la promoción de `router.Context.Set`
(decisión deliberada, pinada); DEP-2026-004 propone rechazar un mapa que
nombre la columna de versión y la rama no lo hace (rompería la salida v1
del propio aviso); varias citas de rutas y tests renombrados (ya
corregidas en las ramas al cerrar cada aviso). El generador de la guía de
migración (`scripts/lib/migration-guide.py`, borrador) lee la rama que cada
checkout tenga: al pin da 23 entradas, en las ramas cero (allí los avisos
ya están cerrados).

**`M0` queda hecha** con dos salvedades que `M1` hereda como precondición:
las siete filas de quark del §3.0 siguen `en main` (su ventana se cuenta
desde el set que lleve la primera release de quark posterior a v1.17.0,
así que el 2.0 no tiene fecha final todavía), y lo de arriba —`/v2`, la DX
al 5, los `fix` de 1.x, el registro de proveedores, D9…D11— tiene que
estar en sets 1.x antes de que `M1` empiece.

## `R1` — la re-auditoría, medida (2026-10-23 / 2026-10-27)

> Informes, revisiones, notas y veredicto en
> [`../auditoria/reauditoria/2026-10-23/`](../auditoria/reauditoria/2026-10-23/README.md);
> los hallazgos en el registro con `informe = reauditoria/2026-10-23/…` y
> `arco = A12`. Lo que sigue es lo que el gate de A12 y el 2.0 necesitan de
> ella.

- **Las notas**: media de las 36 dimensiones 2,79 → **4,12** (2,84 → 4,21
  sin comunidad); por pilar quark 3,22 → 4,06, nucleus 3,00 → 4,55, orbit
  2,45 → 4,15, suite 2,43 → 3,57. Ninguna baja; tres en 5 (nucleus
  Routing/HTTP y Jobs/Eventos, orbit Personalización/extensibilidad). Las
  36 las confirmó la revisión adversarial re-corriendo el instrumento de
  cada fila.
- **El gate (5 en todo salvo comunidad) NO se cumple**: 32 dimensiones no
  llegan. Lo que le falta a cada una, en una línea, está en el README del
  directorio («El gate de A12»); es la lista que `R2` convierte en A13 si
  sigue en pie. Las más lejanas: quark docs/DX (3,5: playground, receta en
  el 100 % de los `Err*`, deriva fuera de los guards), orbit Data Studio
  (3,5: validación y clasificación sobre `quarkdatasource`, FK, M2M, 25
  tipos), suite Tren (3,5: 68–88 min conducidos frente a 30, el segundo
  corte de orbit a mano) y suite Coherencia (3,5: cifras a mano que ya no
  son verdad).
- **Hallazgos**: 122 nuevos, 0 P0, 4 P1, 24 P2, 94 P3 (QK-70…85, NU-132…151,
  OR-78…140, QM-22…44), todos `abierto` en A12. Los P1: OR-78 (Data Studio
  sobre `quarkdatasource` no valida ni clasifica), OR-79 (import/export
  rotos en multi-tenant por la clave prefijada dos veces), OR-80 (el
  operador no está atado a un tenant: lee y escribe en otro por la
  cabecera), OR-99 (la flota de servidores no se forma bajo mTLS desde el
  binario). No esperan a `R2`: `M0-R`.
- **Lo rompiente**: cuatro volteos entran en el §3.0 del contrato del 2.0
  como filas 31–34 `por escribir` (QK-76 la gramática de `db` a error, OR-80
  el operador atado al tenant, OR-93 el entorno fuera de `system_pulse`,
  OR-103 la malla sólo con peers configurados); `M0-R` escribe los avisos
  con su salida en 1.x antes de `M1`.
- **Los criterios de rendimiento del arco**: la decisión 1 (15 %) no se
  cumple en 5 de 9 controles (InsertOne, FindByPK, List100, Preload100,
  FindByPK en MySQL por defecto) ni el lote de 10 000 «cerca de COPY»; el
  «≤ 25 MB» de `N1` tampoco (26,2 MB = 25,02 MiB en el runner; la lane
  vigila 26 730 000 B y la fila `N1` de abajo decía «0,2 MB sobre», que no
  sale en ninguna unidad: NU-150). Cumplen la cola (`N2`), el panel (`O1`,
  decisión 2) y los 92 módulos. El auditor de rendimiento también encontró
  que la página pública y Why Quantum siguen diciendo que el 15 % «no está
  adoptado» (QK-82, QM-44).
- **Lo que `M0-E` llamó «fix de 1.x» y la re-auditoría amplió**: en
  `quarkdatasource` no sólo `Get`/`Delete` (OR-83: `Update` de cero filas,
  el bulk que cuenta `deleted:1`, las entradas de auditoría falsas); en
  `UpsertBatch` también `CreateBatch` (QK-70, con la mezcla inversa que
  inserta `id=0`); y la DX al 5 (§2.1) con nombre: NU-137 (los generadores
  sobre `pkg/model`), OR-89 (DEP-2026-002 apunta a una sección que no
  existe).
- **El método, probado**: los siete auditores y los siete revisores corrieron
  como workflows de agentes (53 min y 3,8 M de tokens los auditores; 20 min
  y 1,9 M los revisores). Dos trampas para `R2`: el límite de uso del modelo
  mató la primera pasada adversarial entera, y el scratch (y el `mktemp` de
  cada auditor) desaparece entre días —los informes se recuperaron de las
  transcripciones—; desde este PR `prompts/lanzamiento.md` manda copiar
  cada entregable a un sitio persistente. `orbit/go.work.sum` lo ensucia
  cualquier `go` bajo el `go.work` de orbit (OR-138): se restaura antes de
  `suite-integral`.

## Registro de sesiones

| Sesión | Estado | PR | Qué midió o cambió del plan |
|---|---|---|---|
| S0 | **hecha** 2026-10-04 | este PR | las cinco mediciones, nueve hallazgos (QK-34…38, NU-106, OR-61, QM-20, QM-21), NU-87 ampliado y NU-50 duplicado renumerado (NU-105); NU-8 a A11 `N3` |
| Q1 | **hecha** 2026-10-05 | quark#431 | el banco de PG y MySQL (`benchmarks/engines`, workflow propio no requerido): las seis operaciones ausentes en el runner (PG 1,24–1,98× sobre `database/sql`; MySQL 1,42× por llamada). En Preload100 la forma de la consulta pesa más que el mapeo (≈240 µs de ≈325 en el portátil). `interpolateParams=true` ya da −41 % en MySQL. Trampa: `align-module-floors.sh` no hace tidy de `benchmarks/`, así que el banco importa los drivers de `database/sql` directamente |
| Q2 | **hecha** 2026-10-05 | quark#444 | List sin copia JSON sin caché (QK-34), preload con `= ANY` en PostgreSQL (QK-35), placeholders sin fmt y `Validate` sólo con tags (mitad CPU de QK-36); en el runner: List100 1,35→1,17, Preload100 1,98→1,25, lote de 1000 1,33→1,09; el banco afirma tiempos sólo en modelos de CPU registrados (QK-47); pista para Q3: `context.WithTimeout` por consulta añade asignaciones |
| Q3 | **hecha** 2026-10-06 | quark#452 | `WithStatementCache` opt-in (QK-37, ADR-0027): un LRU por pool con recuento de referencias, sentencias preparadas una vez por transacción, sólo las del builder con argumentos; ignorada en PostgreSQL (pgx cachea) y en Oracle (go-ora v2.9.0 devuelve un resultado rancio a una sentencia preparada re-ejecutada, reproducido sin quark). FindByPK en MySQL −46…48 % frente a sin caché en el runner (5 corridas, 3 CPUs; −41…42 % en portátil), 1,65× la sentencia reutilizada a mano; `interpolateParams` documentado y medido (≈ igual). `CreateBatch` sin RETURNING (mitad de lotes de QK-36, ADR-0028): SQL Server un `MERGE … OUTPUT` con la posición de la fila por chunk (OUTPUT INSERTED no garantiza orden); MySQL INSERT multifila con claves calculadas SÓLO con `innodb_autoinc_lock_mode` 0/1 (el 2 por defecto de MySQL 8 sigue fila a fila: el manual no garantiza claves consecutivas); un chunk que falla se deshace y va fila a fila. Lote MySQL de 1000: 9,6 ms frente a 241 ms fila a fila (EPYC 7763). COPY en PG no se construyó (no devuelve claves): PG-06 a 1,09× database/sql, COPY 2,6× más rápido. Controles nuevos PG-06, MY-02, MY-03. Hallazgo previo: el per-row de MSSQL tapaba la violación de unicidad con un escaneo de NULL (QK-53, arreglado en quark#453). El criterio «lote de 10 000 en PG cerca de COPY» no se cumple devolviendo claves: queda medido y explicado, y COPY opcional pasa a QK-54 |
| N1 | **hecha** 2026-10-12 (publicada en 1.41.0) | nucleus#607 | la CLI a módulo propio `cmd/nucleus` (lockstep: un tag `cmd/nucleus/vX.Y.Z` por cada release del raíz, ADR-038), los tests del raíz sólo con SQLite (`internal/testsqlite`; las lanes de motor enlazan los otros cuatro con un workspace), dependencias de test a `internal/testdeps`, goleak→`internal/leakcheck`; lanes requeridas nuevas `hello-world-size` (techos exactos de módulos y paquetes, binario +2 %) y `cli`. Grafo en linux/amd64: hello 92→**79** módulos (39 enlazados, 373 paquetes, 22,4 MB), hello+sqlite 105→**92** (46, 384, 26,2 MB: 0,2 MB sobre los 25 MB del criterio, código enlazado y no grafo), starter api 108→**95**; la predicción de S0 salió exacta. **Se fusiona en el tren del 2026-10-12 justo antes del corte de nucleus**: entre el merge y el primer tag `cmd/nucleus/v*`, `go install …/cmd/nucleus@latest` daría «ambiguous import». `nucleustest` sin SQLite no se hizo (no es aditivo → NU-121, lista del major) |
| N2 | **hecha** 2026-10-05 | nucleus#592 | claim con `SKIP LOCKED` en PostgreSQL y MySQL 8/MariaDB 10.6+ (en READ COMMITTED: en REPEATABLE READ los gap locks vuelven a serializar), SQLite y motores sin `SKIP LOCKED` con el claim de antes; el perdedor reintenta con jitter. 16 contra 1 worker: 4,4× PG y 5,1× MySQL en local, 2,9× y 2,6× en el runner (4 vCPU, se satura) — **el criterio cambió**: el ≥ 4× mide la máquina (la lección de NU-95), así que el gate exige ≤ 5 % de claims vacíos con 16 workers (0 % con SKIP LOCKED, 91 % con el claim viejo) y ≥ 2× por el `Manager` real. Parada con `sql`: 9 s → 0,7 ms (NU-103). El prototipo de `S0` era O(backlog): partido en dos rangos del índice. NU-108 nuevo (el pool por defecto churnea) |
| O1 | **hecha** 2026-10-05 | orbit#544 | dist precomprimido y servido por negociación, admin-server sin el panel (25,6→23,8 MB), presupuesto en gzip de carga inicial + navegación más pesada (424,6→373,4 KB, `main` ya se pasaba), AG Grid 36 sin fuente de iconos; OR-59/61/62/63 |
| R0 | **hecha** 2026-10-05 | quantum#258 | la escala en `docs/auditoria/criterios-5.csv`: las 36 dimensiones del 2026-09-03 con su nota de entonces, el listón y el 5 copiados del artefacto del plan a 5/5 (los dos artefactos, el plan y el informe de la auditoría, se pudieron leer), el 1 y el 3 escritos desde los informes, y el instrumento al pin —34 con banco, guard o lane, 2 sólo juicio (quark·ecosistema y suite·comunidad)—; guard `umbrella-audit-criteria` (56º) que saca la lista de dimensiones de los propios informes y valida también el `notas.csv` de cada re-auditoría. El brief en `docs/auditoria/reauditoria/` con sus prompts (el común, uno por auditor, el de la revisión adversarial y el de la consolidación): siete auditores en paralelo (quark, nucleus, orbit, orbit-fleet, orbit-ui, suite y uno de rendimiento nuevo), cada dimensión con un solo dueño, ids provisionales, revisión adversarial por informe y consolidación al mismo registro. `check_audit_backlog.sh` acepta A13+, falla ante un id repetido (registro o informes) y ante una fila de defecto sin id, lee los informes de `reauditoria/<fecha>/` y enseña los P0 abiertos (QK-42 no salía); `estado.sh` deriva el arco siguiente más allá de A12; `suite-integral` corre en los PRs que tocan `docs/auditoria/`. Para `R1`: cuatro instrumentos están en `main` de su producto y no al pin de 1.39.0 (`quark/benchmarks/engines`, `quark/internal/extbench`, `nucleus/internal/catalogbench`, la familia `extension` de adminbench): se mueven a la escala con el pin que los traiga |
| M0 | **hecha** 2026-10-23 — `M0-S0`, `M0-G`, `M0-N` y `M0-Q` 2026-10-16, `M0-O` 2026-10-18 (en 1.42.0), `M0-E` 2026-10-23; dos salvedades que `M1` hereda (las siete filas de quark `en main`; `/v2`, la DX al 5, los `fix` de 1.x y D9…D11 antes de `M1`) | quantum#284 (`M0-S0`), quantum#285 (`M0-G`), nucleus#630 (`M0-N`), quark#470 y quark#471 (`M0-Q`) | el inventario del major contado al pin de 1.41.0 (12 marcas que el guard ve, 7 avisos de volteo que no ve, 9 volteos decididos sin aviso, 1 aviso sin fecha, orbit sin `docs/deprecations/`); los «~14 sitios» de orbit son 2 llamadas a `NewWrapResponseWriter` más una decisión sobre `authz.New`; el bus único ya es `signals.Bus` y lo que sobra es su puerta sin tipo; `pkg/model` sostiene el adaptador de orbit (6 ficheros, 3 módulos) y no se retira en el 2.0; el sobre no tiene opción de quedarse. `M0` troceado en `M0-Q` ∥ `M0-N` ∥ `M0-G` → `M0-O` → `M0-E`; ocho decisiones D1…D8 escritas como propuesta en `quantum-2.0.md` §3.3 |
| M0-Q | **hecha** 2026-10-16 | quark#470, quark#471 | DEP-2026-004…009 (QK-58, QK-46, QK-59+65, QK-60, QK-24, QK-32) con godoc en cada método afectado y cinco tests que pinan v1 (verdes en seis motores), y DEP-2026-010 (QK-50, D7): en Oracle la longitud de un texto cuenta bytes hoy (`VARCHAR2(n)`) y caracteres en el 2.0 (`VARCHAR2(n CHAR)`); quark no tiene interruptor para la semántica, la salida en 1.x es `NLS_LENGTH_SEMANTICS=CHAR` de Oracle, y la introspección tendrá que leer `CHAR_USED`. Las siete filas de quark del §3.0 están `en main` hasta el set del 2026-10-19 |
| M0-N | **hecha** 2026-10-16 | nucleus#630 | nueve avisos con asistente y test que pina v1: DEP-2026-003 fechado al 2.0 (D2) y 019…026 (NU-121, asynq, NU-72, problem+json, `NewWrapResponseWriter`, `pkg/model`, puerta sin tipo de `signals`, NU-110); trece marcas `Deprecated` que el guard lee; las salidas en 1.x `WithErrorEnvelope()` (app, nucleus, builder), `router.Wrap`, `Topic.String` y la pista al migrador en `authz.New`; seis adiciones al baseline de símbolos. Dos cosas que el enunciado daba por hechas y no eran: los topics tipados de ciclo de vida NO se construyen (las ocho señales las emite `pkg/model`, que D5 retira: se van con él y la salida es quark), y casbin v2.135.0 ya rechaza al cargar una fila de política de 3 columnas (la fase «inerte» de DEP-003 terminó con la dependencia; el aviso dice lo medido y `authz.New` nombra el migrador). Los avisos llegan al pin con el set del 2026-10-19; hasta entonces las filas 20…28 del §3.0 están `en main` |
| M0-G | **hecha** 2026-10-16 | quantum#285 | `umbrella-deprecations` lee los 13 avisos `active` al pin (5 de retirada, 7 de volteo; `DEP-2026-003` de nucleus, `active` sin fecha, tolerado con AVISO sólo mientras su fila 20 esté en `decisión`) y las 29 filas del §3.0 (12 `publicado` con fichero al pin, 9 `por escribir`, 8 `decisión` → 17 pendientes antes de `M1`); un aviso al pin que nombre el major y falte en la tabla, o cuya fila no diga `publicado`, FALLA. Los doce avisos publicados se leen con su formato real —tres grafías de la viñeta de ventana: «Earliest removal», «Behaviour flip», «Earliest change»— sin tocar ningún producto, y ninguno está mal escrito. Fixture con cinco roturas (las dos de antes más el aviso `active` sin fecha fuera de `decisión`, la fila `publicado` sin fichero y el aviso del major que falta en la tabla); política §1/§5/§6, nota del §3.0 y registro de guards al día; **QM-20 hecho**. Trampa para el tren: el PR de set que re-pine quark o nucleus con los avisos de `M0-Q`/`M0-N` sale rojo hasta pasar sus filas del §3.0 a `publicado` |
| M0-O | **hecha** 2026-10-18 — (a) orbit#568 y (b) orbit#570, publicadas en Quantum 1.42.0 (orbit v1.20.0/v1.20.1) | orbit#568 (a), orbit#570 (b) | La precondición no se cumplía (nucleus#631, la release con `M0-N`, sigue abierto hasta el tren del 19) y sólo `router.Wrap` la necesita, así que se troceó. (a): `docs/deprecations/` de orbit (README calcado del de quark: sin asistentes ni CHANGELOG), DEP-2026-001 (OR-57, volteo) con la salida `server.Config.AllowSharedAgentCertificate` (`--allow-shared-agent-certificate`, contradice `AgentIdentityFromCertificate` y `Run` rehúsa las dos; con mTLS y ninguna de las dos, un WARN al arrancar que nombra las dos) y DEP-2026-002 (D5b: 4 marcas en `datasource/nucleus`, WARN al montar el panel y al arrancar el agente sobre el camino por defecto; al 2.0 `orbit.Config.DataSource` nil es error de configuración y el editor de metadatos de campo y el `*signals.Bus` del adaptador se van con él); `quarkdatasource` pasa del `LIKE` plano con escape propio a `quark.Contains/StartsWith/EndsWith` —SQLite y Oracle contestan un `%` en vez de rechazarlo, QK-25 cerrado por este lado, `escapeLike` y `FuzzEscapeLike` fuera—; `api.ts` lee problem+json (detail > title) junto al sobre y `ApiError.code` en las dos formas; dist reconstruido. **Medido y distinto del enunciado**: orbit NO llama a la puerta sin tipo de `signals` (0 sitios: guarda el bus sólo para `model.NewCRUD`, que se va con el adaptador; `Panel.SetSignalBus` no lo lee nadie), así que no hay topics que migrar; `ExtensionConfig.DataSource` del agente cae al mismo adaptador por defecto; y el banco del fleet con `GOWORK=off` da dos fallos falsos (su go.mod resuelve server/agent publicados): se corre con el workspace de orbit, como CI. Criterio en (a): banco admin 72/72, IDENT-06 present, CI verde; `grep NewWrapResponseWriter` = 2 hasta (b). El squash es `feat:` → orbit cortó **minor** (v1.20.0) en el tren del 18. **(b)** entró en orbit#570, el PR de alineación a nucleus v1.33.0 del propio tren: las dos llamadas a `router.Wrap(w)`, `grep NewWrapResponseWriter` = 0 en orbit; nada de la lista de retiradas del 2.0 queda referenciado |
| M0-E | **hecha** 2026-10-23 (arrancada el 2026-10-18) | ramas `dry-run/2.0` en origin: quark `a2b4558d`, nucleus `2dd5b82f`, orbit `f584a53`; quantum (este PR) | el ensayo del major: treinta avisos aplicados por doce grupos en worktrees con un refutador cada uno, un integrador y un auditor por producto (workflows de agentes); orbit `dry-run/2.0` compila y pasa sus tests contra quark y nucleus `dry-run/2.0` por el `go.work` del paraguas (el criterio); el §3.0 sin filas `por escribir`. Lo que el §3 no preveía: la ruta `/v2` (§3.5 del contrato), el §2.1 como prerrequisito de DEP-024, quark en el grafo de la raíz de orbit (D11), y las decisiones D9 (starter `api` contra `generate module`) y D10 (metadatos por campo en `quarkdatasource`); los rojos y los `fix` de 1.x en la sección «`M0-E` — el ensayo del major, medido». Borrador del generador de la guía: `scripts/lib/migration-guide.py` + `docs/planes/guia-migracion-2.0.md` (23 entradas al pin) |
| R1 | **hecha** 2026-10-27 (auditores el 2026-10-23, revisión adversarial el 2026-10-27) | quantum#294 | la re-auditoría completa sobre el pin de 1.42.0 con el método de `R0`: siete auditores en paralelo, siete revisores adversariales (ninguna nota movida; tres severidades cambiadas, seis duplicados fundidos, dieciséis hallazgos nuevos de los revisores), consolidación en `docs/auditoria/reauditoria/2026-10-23/` (informes, `adversarial.md`, `notas.csv`, README) y en el registro (122 filas: 0 P0, 4 P1, 24 P2, 94 P3). Media 2,79 → 4,12; tres dimensiones en 5; **el gate de A12 no se cumple** (32 dimensiones por debajo, lista en el README). Cuatro volteos al §3.0 del 2.0 (filas 31–34, `por escribir` → `M0-R`). La escala con los cuatro instrumentos que estaban «en main» movidos a `instrumento` (35 con instrumento, 1 juicio). Los criterios de rendimiento del arco: 15 % no cumplido en 5 de 9, COPY no, `N1` 26,2 MB > 25 MB. Sección «`R1` — la re-auditoría, medida» |
| M0-R | pendiente — siguiente: los cuatro avisos `por escribir` (QK-76, OR-80, OR-93, OR-103) con su salida en 1.x y los cuatro P1 de `R1` como `fix` de 1.x | — | |
| M1 | pendiente — precondición ampliada por `M0-E` y `R1`: `R1` hecha (lo está), `M0-R` hecha, D9…D11 decididas, la DX al 5 (§2.1) y los `fix` de 1.x publicados, el registro de proveedores de `pkg/tasks` en una minor, y las siete filas de quark `publicado` | — | |
| R2 | pendiente | — | |
