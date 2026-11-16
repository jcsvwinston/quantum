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
   **Retitulado el 2026-11-16 (D38 g, contra la recomendación)**: el
   criterio del 5 pasa a lo medido en `R1` sobre el runner
   (`docs/auditoria/reauditoria/2026-10-23/rendimiento.md:44-51`, corrida
   del 2026-10-16 en EPYC 9V45): InsertOne 1,20 · 1,22, FindByPK 1,14 ·
   1,15, List100 1,18, Preload100 1,30 frente a `database/sql` · pgx; MY-01
   (FindByPK en MySQL por defecto) 1,42 · 2,91 por llamada · con sentencia
   reutilizada. El 15 % queda como lo que esta decisión pedía, no como el
   criterio; `criterios-5.csv` (quark · rendimiento) lleva las cifras.
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
| `M0-F` | Los `fix` de 1.x que `M0-E` listó y `R1` amplió, antes del major: el registro de proveedores de `pkg/tasks` (prerrequisito de DEP-2026-020), las coerciones del importador y los inlines (OR-144), la clave lógica de la subida (OR-141), OR-89 y QK-70 | `M0-R` | fusionados en un set 1.x; el módulo `providers/tasks-asynq` nace después, con su tag |
| `M1-S0` | **hecha el 2026-11-16** (este PR; el número, en el registro de sesiones): la medición que trocea `M1` (D16): la ruta `/v2` (41 `go.mod`, 2 156 líneas de import, 33 módulos publicables de los que 24 están en v0.x), las 34 filas del §3.0 (30 ensayadas en `dry-run/2.0`, 4 sin commit; 31/83/37 ficheros a rehacer sobre `main`), `pkg/model` y el adaptador `datasource/nucleus`, asynq fuera del root (4 módulos se van; go-redis se queda), D11 en el paraguas y en orbit, la guía (vacía con avisos `completed` si el generador no cambia) y el tren (24 módulos v0.x sin número, `verify` de nucleus y ldflags que dejarían la release sin activos o con binarios «devel»); la lista de lo aditivo de las 32 (64 elementos cortos en 42 sesiones `V-*`, D17); el rediseño como carril `RD-0 → RD-1o-ui → RD-1o-root ∥ RD-1q → RD-2`; 13 preguntas al propietario como D26…D38 del §3.3 del contrato. Sección «`M1-S0` — el major, medido y troceado» | 1.45.0 certificado | PR fusionado; `bash scripts/check_audit_backlog.sh`, `bash scripts/check_handoff_size.sh` y `bash scripts/check_rumbo_estado.sh` en verde |
| `M1` | El 2.0 tal como lo troceó `M1-S0` (sección «`M1-S0` — el major, medido y troceado», 23 sesiones más el tren; el tramo 1.x de 18 sesiones que va delante NO es `M1` sino su precondición): el primer commit del major de cada repo es la ruta `/v2` (`M1-V2-Q` → `M1-V2-N` → `M1-V2-O`, en ese orden, con pseudo-versiones entre repos y un footer `Release-As: 2.0.0` por repo si el propietario lo admite), después las retiradas y los volteos por grupo de ficheros compartidos (`M1-R-Q1…Q4`, `M1-R-N1…N6`, `M1-AS-N`, `M1-PM-N`, `M1-AD-O` con el `go.mod` de D11, `M1-D11-O`, `M1-R-O1`, `M1-R-O2`), la deuda de doc del major (`M1-D-Q/N/O`, dos PRs cada una) y el tren (`M1-G-S` → `M1-TREN`); arranca en enero de 2027 (D17) | `M1-S0` (hecha); las diez sesiones cortas del §2.2 del contrato (D15); el tramo 1.x del troceado (18 sesiones: `M1-V2-P`, `M1-T-P`, `M1-T-O`, `M1-T-N`, `M1-T-Q`, `M1-G-P`, `M1-G-Q/N/O`, `M1-G-F1…F5`; `M1-T-LINT-Q/N/O/P` según D28; `M1` empieza con `M1-V2-Q`(1), el primer `feat!:`); D26…D38 (bloque `M1-S0` del §3.3 del contrato) decididas el 2026-11-16, con `V-N-AM` (DEP-2026-027, D30) antes del set del 2026-11-23; `R1` y `M0-R` (hechas) | set 2.0.0 certificado (`suite-integral --cierre`, 61 guards); ninguna marca viva que prometa 2.0.0; la guía con 34 entradas y la sección de la ruta; `GOWORK=off go install github.com/jcsvwinston/nucleus/cmd/nucleus/v2@v2.0.0` con caché virgen imprime `v2.0.0` |
| `R2` | Re-auditoría completa como `R1` (D18, 2026-11-16: 36 dimensiones, mismo método e instrumentos; esta fila decía «re-puntuar sólo lo que `M1` tocó»); A12 cerrado | `M1` | todas las dimensiones a 5 salvo comunidad, o A13 abierto con lo que falte |

`Q1→(Q2 ∥ Q3)`, `N1`, `N2`, `O1` y `R0` van en paralelo y pueden solaparse con
A11 si no tocan los mismos paquetes. `M0 → R1 → M0-R → M1-S0 → M1 → R2` va al
final y en serie.

`M0` tiene su propio troceado en seis sesiones, medido el 2026-10-16: está
en la sección siguiente.

`M1` tiene el suyo —23 sesiones más el tren, con un tramo 1.x de 18 sesiones
delante y 42 sesiones `V-*` de la ventana—, medido el 2026-11-16: está en la
sección «`M1-S0` — el major, medido y troceado», con la precondición y el
criterio de hecho de cada una como comando.

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
| `M0-N` | nucleus: avisos DEP-2026-019… para NU-121, asynq a módulo propio (`Scope: packaging`), NU-72 (D1), problem+json por defecto (D3), `NewWrapResponseWriter` (D4, con marca), la puerta no tipada de `signals` (D6, con marcas), la retirada de `pkg/model` como capa pública (D5, con marcas en lo que se retira), NU-110 (D8) y la fecha de DEP-2026-003 (D2); y las salidas en 1.x: `WithErrorEnvelope()`, `router.Wrap(w)`, topics tipados para las señales de ciclo de vida (no se construyeron: las ocho señales las emite `pkg/model`, que D5 retira; lo midió `M0-N` y lo fijó D20); baselines regenerados sólo con adiciones | D1…D8 | `make check` verde; `check_deprecations.sh` verde al pin; cada aviso nombra el test que pina v1 y el que ejercita la salida |
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
así que el 2.0 no tiene fecha final todavía), y lo de arriba —la DX al 5,
los `fix` de 1.x, el registro de proveedores, D9…D11— tiene que estar en
sets 1.x antes de que `M1` empiece; la ruta `/v2` no es trabajo de 1.x: es
el primer commit del major en cada repo (§3.5 del contrato).

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
  decisión 2) y los 92 módulos. **Decidido el 2026-11-16**: el criterio
  del 15 % se retitula a lo medido (D38 g; decisión 1, nota de arriba) y el
  de `N1` pasa a ≤ 27 MB (D38 j; `V-N6` lo escribe en la fila `N1`, en
  `criterios-5.csv` y en `ceilings.tsv`). El auditor de rendimiento también
  encontró que la página pública y Why Quantum siguen diciendo que el 15 %
  «no está adoptado» (QK-82, QM-44).
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

## `M0-R` — lo que `R1` dejó para antes del major (2026-11-03)

> Cinco tramos en paralelo, uno por agente y cada uno en su worktree, con
> sus PRs fusionados en serie tras integrar los seis de orbit en local
> (build, vet y tests de todos los módulos con el workspace). Antes hubo
> que pagar una vulnerabilidad de Go publicada esa semana: GO-2026-6809
> (`crypto/x509`, en go1.26.9, arreglada en go1.26.10) ponía rojo
> `govulncheck` en todo PR de los tres productos; el `toolchain` subió a
> go1.26.10 en quark#477, nucleus#635 (con la imagen del builder por
> digest y la constante del scaffold) y orbit#580, sin mover la directiva
> `go`. El `go.work` del paraguas sube en el PR de set.

| Tramo | PR | Qué deja |
|---|---|---|
| QK-76 (fila 31) | quark#476 | DEP-2026-011 con el test que pina v1; la salida en 1.x es un token NUEVO, `quark:"literal_column"` (la forma `db:"column:pk"` que se suponía es la gramática de `pkg/model` y ya daba `ErrInvalidTag`); el WARN nombra el aviso y la salida; y los siete avisos de `M0-Q` re-fechados al 2027-02-07 |
| OR-80 (P1, fila 32) | orbit#578 | `tenant_id` en la cuenta de operador (columna nullable, API de operadores); un operador atado, sin superusuario ni `tenant_switch`, recibe 403 si la petición resuelve otro tenant (cabecera, subdominio o `?tenant=`) en lectura, export y escritura; el que no tiene tenant sigue al resolver con un WARN y en el 2.0 se rechaza (DEP-2026-003 de orbit); CUST-07 mide confinamiento de verdad (OR-87) |
| OR-78 (P1) y OR-83 | orbit#579 | el panel valida contra `FieldInfo` antes del store, y `quarkdatasource` valida y clasifica como el adaptador de Nucleus (422 por campo, 409 sin texto del motor, 404, 400); sin auditoría de escrituras que no ocurrieron |
| OR-79 (P1) | orbit#581 | claves lógicas en import, fixtures y export bajo un tenant; DS-13/14/15 corren también bajo uno |
| OR-93 (fila 33) | orbit#576 | el permiso `system_env`; `system_pulse` sólo sigue viendo el entorno con un WARN por operador (DEP-2026-004 de orbit) |
| OR-99 (P1) | orbit#577 | `--peer-ca/--peer-cert/--peer-key` y, bajo `--agent-client-ca`, la CA y el par del listener de agentes por defecto; la malla registra la causa de un enlace caído; control `HA-06` (el banco del fleet, 51 de 51) |
| OR-103 (fila 34) | orbit#582 | `--peer-allowlist` opt-in: `Sync` sólo acepta el `server_id` que contestó en un enlace propio a un `--peers` y, con certificado verificado, su CN; sin él, un WARN por peer que el 2.0 rechazaría (DEP-2026-005 de orbit) |

**Lo que la sesión encontró y el contrato no decía**:

- **OR-80 no se cierra en 1.x por defecto.** La fila 32 decidió que el
  tenant de la cuenta sea opcional en 1.x (rechazar al operador sin tenant
  rompería despliegues en una minor), así que el hueco sigue abierto para
  el operador que no tenga tenant hasta `M1`. Hay salida en 1.x (atarlo, o
  no darle `tenant_switch`) y aviso, y el hallazgo queda `abierto` hasta el
  volteo, como QK-45. El criterio de `M0-R` («los cuatro P1 `hecho`») se
  cumple en tres; el cuarto lo cierra `M1`.
- **El tenant se compara exacto y nucleus resuelve en minúsculas**: un
  operador atado a `Acme` no coincide nunca (falla cerrado, 403). OR-143.
- **«Configurado en `--peers`» no existía**: `--peers` lista endpoints,
  no `server_id`. La regla es «el `server_id` que contestó cuando este
  servidor marcó uno de sus `--peers`», y por eso una malla en una sola
  dirección tendrá que listarse en los dos lados en el 2.0. Con sólo el
  token, la lista compara nombres y no autentica; autentica bajo mTLS. El
  aviso lo dice.
- **Quark se avisaba a sí mismo**: el modelo de su log de auditoría tiene
  una columna `pk` de verdad, y `EnableAuditLog` emitía el WARN desde
  v1.14.0 (y en el 2.0 habría fallado). Lleva el token nuevo.
- **La sonda DS-03 sobre Quark no cabe en 1.x**: el banco vive en el
  módulo raíz de orbit y ADR-012 deja quark fuera de su grafo hasta D11
  (OR-88 sigue abierto con esa razón).
- **`nucleus/pkg/db.IsUniqueViolation` no ve un error de unicidad de Quark
  sobre SQLite** si la aplicación no enlaza los módulos de driver de
  nucleus; `quarkdatasource` usa `quark.IsUniqueViolation`.
- **Hallazgos nuevos** (registro, A12): OR-141 a OR-144, NU-152, NU-153 y
  QK-86 a QK-88.

## `M0-F` — los `fix` de 1.x antes de `M1` (2026-11-07)

> Lo que `M0-E` listó como «va a 1.x ANTES del major» y `R1` amplió, hecho
> en tres tramos paralelos (uno por producto, cada agente en su worktree)
> dos días antes del set del 2026-11-09, para que suban en él. La fuente
> fue la rama `dry-run/2.0` de cada hermano: se portó sólo lo válido en
> 1.x (nada que asuma un volteo del 2.0). Del listado de `M0-E` quedó
> fuera **el nacimiento del módulo `providers/tasks-asynq`** (nace con su
> tag en una sesión propia: `nucleus add tasks-asynq` apuntaría a un
> módulo que no existe) y lo que ya estaba en `main` por `M0-R`
> (`quarkdatasource` ya contestaba 404/400 desde orbit#579; el WARN por
> directivas `db:` desconocidas ya corre al arrancar, `pkg/app/app.go`).

| Tramo | PR | Qué deja |
|---|---|---|
| QK-70 (P2) | quark#479 | `CreateBatch` y `UpsertBatch` deciden la columna clave **por tramo** de entidades consecutivas que coinciden en llevar clave (`batchKeyRuns`), no por la primera: un lote mixto emite un juego de sentencias por tramo y ninguna clave se pierde ni se inserta `id=0`; sin cambio de firma; las guías de lotes corregidas |
| Registro de proveedores de `pkg/tasks` (prerrequisito de DEP-2026-020) | nucleus#638 | `tasks.Provider`, `ProviderOptions`, `ProviderRuntime`, `RegisterProvider`, `MustRegisterProvider`, `LookupProvider`, `RegisteredProviders`; el proveedor asynq del árbol se registra en su `init` y `jobs.go` y `doctor --check tasks` resuelven por el registro (comportamiento idéntico en 1.x, con el import en blanco); `knownproviders.RequireDBDriver` compartido por `pkg/db` y `nucleustest.Transactional`; `hooks.SQLQueryEvent`, `hooks.SQLQueryObserver` y `hooks.NewSQLQueryObserver` sin tocar la firma de `NewSQLObserver`; la prosa de `pkg/tasks` en README, SPEC y el manual |
| OR-89 (P3) | orbit#584 | DEP-2026-002 remite al README del adaptador y al paso 4 del quick-start, que enseña el camino de Quark junto al del registro (el texto anterior citaba opciones del adaptador que no existen) |
| OR-141 (P2) | orbit#585 | la subida de un widget de fichero contesta y audita la clave lógica bajo un tenant, como import/export/fixtures desde orbit#581 |
| OR-144 (P3) y las coerciones | orbit#586 | `(IsReadOnly && !IsPK)` en la validación de importación con el invariante del fuzz al día; las celdas CSV llegan al store en el tipo declarado; el padre de un inline se escribe en el tipo de su campo (`int64` también para `uint`: el adaptador de Nucleus no acepta `uint64`, OR-145); los pines de `internal/fleettest/go.mod` al set vigente; las sondas de identidad del fleet con el CN igual al `node_id` donde no miden el enlace |

**Lo que la sesión encontró y el plan no decía**:

- **Otra vulnerabilidad el día antes del corte, y esta sin arreglo en la
  base de datos**: GO-2026-6909 (`crewjam/saml` ≤ v0.5.1, publicada el
  2026-11-05) pone en rojo la lane SAML de nucleus y con ella el gate
  obligatorio de todo PR. Upstream la arregla en v0.5.2 (nucleus#639 la
  pina; los tests del proveedor pasan), pero la base de datos de Go la
  lista sin versión arreglada, así que `govulncheck` sigue avisando
  contra v0.5.2. Qué hace la lane mientras tanto era decisión del
  propietario (NU-155), y la tomó el mismo día: la opción 1, una
  excepción explícita, acotada y que se retira sola. La lane SAML corre
  ahora `scripts/ci/govulncheck_gate.sh` (nucleus#639): el mismo veredicto
  que el binario —falla toda vulnerabilidad que el código del módulo
  LLAMA— más las líneas de `scripts/ci/govulncheck_exceptions.txt`, cada
  una para UN id en UN módulo a UNA versión, con fecha de caducidad
  (2026-12-31 para esta) y válida sólo mientras la base no registre
  versión arreglada: el día que la registre, o el hallazgo desaparece y
  la línea queda rancia (la lane avisa de borrarla), o sigue y falla
  porque el pin se quedó corto. Seis comprobaciones en local contra un
  escaneo grabado (positivo, fichero vacío, fecha pasada, línea sin
  hallazgo, base con fix y hallazgo vivo, base con fix y hallazgo ido).
  Con la lane verde se fusionaron #639 y #638 en serie, y las notas de
  v1.34.0 con el snapshot van en nucleus#640, antes del tren.
- **La DX al 5 no empezó**: NU-137 (los generadores sobre `pkg/model`)
  es trabajo de diseño (Quark como capa de datos del starter y los
  generadores) que no cabe en un tramo de porte; sigue como precondición
  de `M1`.
- **Hallazgos nuevos** (registro, A12): QK-89 a QK-91, NU-154 a NU-158 y
  OR-145 a OR-148.

## La DX al 5 — medida y troceada (2026-11-08)

> El §2.1 del contrato del 2.0 lista lo que el 5 pide en docs/DX, CLI y
> datos de quark y nucleus (decisión de Carlos del 2026-10-06). `M0-E`
> midió que UNA PARTE es prerrequisito de DEP-2026-024 (retirar
> `pkg/model`) y el resto es trabajo de dimensión que `R2` mide. Esta
> sesión (`DX-0`) contó qué queda de cada punto al pin de 1.43.0 y lo
> troceó. Regla: todo aditivo y en sets 1.x; nada espera al major; `M1`
> sólo necesita el **bloque A** (`DX-N1`, `DX-N2`, `DX-S1`): lo demás
> sube la nota de `R2`, no desbloquea nada.

### Lo que hay, contado (al pin de 1.43.0; `main` de los tres el 2026-11-08)

| Punto del §2.1 | Medido | Qué falta | Sesión |
|---|---|---|---|
| Quark · una guía por caso de uso | 14 guías + 7 avanzadas en el sitio y los tutoriales del paraguas (A11 `W2`/`W3`) | caché, réplicas y sharding en producción no tienen guía más allá de la referencia | `DX-Q3` |
| Quark · playground de consultas en el sitio | no existe nada en `website/` | el playground entero; la forma es decisión del propietario (**D13**) | `DX-Q4` |
| Quark · receta en el 100 % de los `Err*` | 12 de 25 centinelas; ~17 % de los sitios que los envuelven (QK-78) | 13 centinelas, los wraps, y un test de convención que cuente | `DX-Q1` |
| Quark · cero deriva | los cuatro guards de doc verdes | deriva fuera de su mirada: `docs/deprecations/` (QK-73), `acceptance/README.md` (QK-74), `acceptance/COVERAGE.md` (QK-77), `benchmarks.mdx` (QK-82) | `DX-Q1` |
| Quark · las 60 consultas del banco tipadas | **58 de 60** (`docs/query-bench.md`); las dos restantes son `GROUP BY` sin proyección, que SQLite acepta y PostgreSQL no | nada en 1.x: cambian de veredicto con DEP-2026-008 en el 2.0 (`M1`) | — |
| Nucleus · generadores que montan, prueban y documentan (NU-127) | `generate module --mount` monta y su test prueba la composición (A11); el módulo generado entra en `/openapi.json` sólo con `responses: default` (NU-145) y contesta errores fuera del sobre (NU-136) | endpoints tipados y `c.Error(...)` en lo generado | `DX-N3` |
| Nucleus · `dev` con recarga, completions, `routes`/`migrate` que ven el binario | hechos y medidos en `R1` (4,5) | nada | — |
| Nucleus · ≤ 5 conceptos hasta el primer endpoint | 5 de 5 (`check_quickstart_cost.sh`) | que siga en 5 al reescribir el quickstart sobre quark | `DX-N2` |
| Nucleus · tutoriales en CI, referencia generada, sin deriva | hechos (A11 `W2`…`W4`) | la deriva de `R1`: NU-133 (README «40 commands»), NU-135 (FED-03 `absent`), NU-144 (39 avisos permanentes de `bodycheck`) | `DX-N2` |
| Nucleus · Quark como capa de datos por defecto | el starter `suite` y `generate module --data quark` sí | `generate model`, `generate resource` y `startapp` escriben `model.BaseModel` (NU-137); `nucleustest.Make` sólo persiste por `pkg/model` | `DX-N1` |
| Nucleus · migraciones autogeneradas desde modelos, con lock y deriva | lock (NU-13) y deriva (`migrate drift`) sí | derivar el SQL de los modelos quark del proyecto: `nucleus makemigrations` es `migrate create` con un par vacío | `DX-N3` |
| Nucleus · `pkg/model` fuera del camino | — | (a) los generadores (`DX-N1`); (b) **nueve páginas del sitio enseñan `pkg/model`** (`quickstart.md`, `models-and-database.md`, `intro.md`, `application.md`, `principles.md`, `compatibility.md`, `events.md`, README y las notas) (`DX-N2`); (c) **`nucleus new --with orbit` en `mvc`/`api` monta `orbit.Module` sin `DataSource`**, que en el 2.0 rehúsa arrancar (`TestModule_DataSourceIsRequired` en orbit `dry-run/2.0`; NU-159); el starter `suite` y el showcase ya pasan `quarkdatasource` (`DX-S1`) | `DX-N1`, `DX-N2`, `DX-S1` |

### Tres cosas que el §2.1 no decía

- **nucleus no depende de quark** (`go.mod` raíz sin `github.com/jcsvwinston/quark`; el arco D3 adelgazó el grafo a propósito). «`nucleustest` sobre quark» no puede importar quark sin cambiar ese grafo. La rama `dry-run/2.0` ya resolvió `Make` sin registro (`internal/model.ExtractMeta` de las etiquetas del struct); `DX-N1` hizo lo propuesto (**D12**: doble gramática sin dependencia) y **Carlos lo cambió el mismo día a la opción 2**: al releer nucleus#644, la doble gramática persistía por el CRUD de `pkg/model` —la capa que `M1` retira— y duplicaba la gramática de quark en nucleus, donde deriva en silencio. `DX-N1b` la sustituye ANTES del set del 2026-11-16 por una costura en `nucleustest` (sin importar quark) y el módulo `pkg/nucleustest/quarkmake`, que escribe por `quark.For[T]` y rompe en compilación si quark cambia. Coste: el 18.º `go.mod` de nucleus y el primero que pina quark (entra en la alineación del tren; `umbrella-why-quantum` aprende la clase «kit de pruebas» que `nucleus add` no instala).
- **El punto «60 consultas tipadas» es del 2.0, no de 1.x**: las dos que quedan tienen aviso (DEP-2026-008) y voltean en `M1`. Ninguna sesión de 1.x lo mueve.
- **El `--with orbit` de `mvc`/`api` no estaba en la lista de `M0-E`** (que miraba el starter de la suite y el showcase, ya corregidos en nucleus#483): NU-159.

### Las sesiones

| Sesión | Qué deja | Precondición | Hecho cuando |
|---|---|---|---|
| `DX-0` | este inventario, el troceado, D12 y D13 escritas en el contrato, NU-159 en el registro | 1.43.0 certificado | PR fusionado; `check_audit_backlog.sh` y `check_handoff_size.sh` en verde |
| `DX-N1` | nucleus: `generate model`, `generate resource` y `startapp` escriben modelos quark (la forma de `generate module --data quark`: `Record` con `db:`/`pk:`, `TableName()`, soft delete), repositorio sobre `quark.For[T]` y `--data quark\|sql` también en `resource` y `startapp`; `nucleustest.Make` con doble gramática (D12); la CLI sigue rendiendo la migración desde sus metadatos internos; docs de la CLI y `testing.md` en el mismo PR | — | PR verde fusionado; `grep pkg/model` sobre lo que los generadores escriben = 0; `make check` verde; `go.mod` de nucleus sin quark |
| `DX-N1b` | nucleus (D12, opción 2): costura en `pkg/nucleustest` para persistir lo que no está en el registro sin que el root importe quark; módulo publicado `pkg/nucleustest/quarkmake` que la implementa con el cliente quark de la aplicación (defaults y escritura por quark, tests sobre SQLite); fuera del root la gramática duplicada de nucleus#644; alta del módulo en release-please, README y lane de CI propia; aserción de que el `go.mod` raíz sigue sin quark | `DX-N1`; antes del set del 2026-11-16 | PR verde fusionado; `go.mod` raíz sin quark; `Make` sobre un struct no registrado sin la costura falla con la receta que nombra el módulo |
| `DX-N2` | nucleus docs: el quickstart enseña lo que el CLI escribe (quark), `models-and-database.md` pasa a «Quark como capa de datos» con `pkg/model` como sustrato deprecado, las otras siete páginas y el README dejan de presentar `pkg/model` como la capa; NU-133, NU-135, NU-144 | `DX-N1` fusionado (la prosa cita código fusionado) | `check_quickstart_cost.sh` 5/5; `check-coverage.sh --strict` y `bodycheck -strict` sin avisos permanentes; `tutorials_smoke.sh` verde; snapshot con la minor |
| `DX-N3` | **Medida el 2026-11-08 y partida en tres**, porque el CLI de quark escribe la migración derivada de modelos como fichero Go (`migrate create --from-models` → `<ts>_<nombre>.go` con el `Exec` dentro) y nucleus la quiere como par `.up.sql`/`.down.sql`: **`DX-N3q`** (quark): `quark migrate create <n> --from-models <dir> --dialect <d> --emit json` imprime en stdout `{schema:1, tool, version, dialect, models[], up[], down[]}` sin escribir fichero (contrato versionado por `schema`; acepta `postgresql`, que es como nucleus nombra su motor, NU-164). **`DX-N3n1`** (nucleus, sin esperar a nadie): `generate module\|resource` sobre `nucleus.Handle[In, Out]` tipado con estados de éxito y errores por el sobre del framework (problem+json negociado) —NU-145, NU-136—, y `doctor`/`health`/`config print` que leen los imports `providers/*` de `main.go` del proyecto (go/parser) y los cruzan con el catálogo embebido para aceptar el bloque que `nucleus add` escribió —NU-132. **`DX-N3n2`** (nucleus): `nucleus makemigrations <n>` deriva el par desde `internal/models` llamando al CLI de quark (`quark` en el PATH, si no `go run github.com/jcsvwinston/quark/cmd/quark@latest`, con `NUCLEUS_QUARK_CLI` para fijarlo) con `--emit json` para el dialecto configurado (`database.default.driver`), y escribe el par con la cabecera que diga la versión de quark que lo rindió; sin el flag en el CLI encontrado, la receta que nombra la versión mínima; sin modelos quark, el par vacío de hoy | `DX-N3q` y `DX-N3n1`: `DX-N1`. `DX-N3n2`: **el `cmd/quark` con `--emit json` publicado** (la lane `suite-starter` monta los hermanos a su ÚLTIMA release, así que un test que lo use antes del corte de quark no puede estar verde): después del set del 2026-11-16 | `DX-N3q`: el JSON de los cinco dialectos igual a `buildDDLStatements`. `DX-N3n1`: el módulo generado entra en `/openapi.json` con parámetros, cuerpo y esquemas; un 404 con `Accept: application/problem+json` contesta problem+json; `doctor` pasa sobre un proyecto con `nucleus add sentry`; NU-132/136/145 `hecho`. `DX-N3n2`: `makemigrations` produce el par desde un modelo quark en los cinco dialectos (test con el CLI de quark construido del hermano a su release) |
| `DX-Q1` | quark: receta en los 25 centinelas y en los wraps, contada por un test de convención (QK-78); la deriva QK-73/74/77/82 corregida y leída por el guard | — | el test de convención verde y la cifra publicada = la contada; los cuatro ids `hecho` |
| `DX-Q3` | quark: guías por caso de uso (caché, réplicas, sharding en producción) con fixture ejecutada; y, si `DX-N3` lo pide, un paquete público que derive DDL desde modelos sin base de datos | — | guías con su fixture en CI |
| `DX-Q4` | quark: el playground de consultas en el sitio —D13 (a), decidida el 2026-11-08—: `internal/playground` (quark compilado a `js/wasm` con un driver `database/sql` que no ejecuta nada y graba el SQL; exporta `quarkRender`), la página `website/docs/playground.mdx` con el constructor inline (sin `@site/src`, porque el sitio que la sirve es el paraguas), un ejemplo estático visible sin JavaScript que CI compara con lo que el `.wasm` renderiza, y el `.wasm` cargado sólo a petición con su peso escrito en el botón; `scripts/ci/check_playground_weight.sh` (gzip ≤ 3,5 MB y el peso escrito a ±10 % del medido) en la lane `static-build`; `scripts/ci/build_playground.sh <dir>` para que el paraguas lo compile al pin | D13 | PR verde fusionado; el peso medido en la página; el paraguas lo compila en `deploy`/`website-ci` (`scripts/build_quark_playground.sh`) |
| `DX-S1` | nucleus: `nucleus new --with orbit` (`mvc`/`api`) monta el panel con un `DataSource` (`quarkdatasource` sobre un cliente quark del pool; `--with orbit` implica quark y `quarkdatasource`); el proyecto generado arranca contra orbit `dry-run/2.0` en un ensayo local | `DX-N1` | NU-159 `hecho`; `quickstart_smoke` verde; `check_quickstart_cost.sh` 5/5 |

Orden: `DX-N1` ∥ `DX-Q1` → `DX-N2` ∥ `DX-S1` ∥ `DX-Q3` → `DX-N1b` ∥ `DX-Q4` → `DX-N3q` ∥ `DX-N3n1` → (release de `cmd/quark`) → `DX-N3n2`
(D12 y D13 decididas el 2026-11-08). `M1` espera al bloque A —con `DX-N1b`,
que cambia la forma de `Make`— publicado en un set; `DX-N3`, `DX-Q3` y
`DX-Q4` suben la nota en `R2` y pueden seguir en 1.x en paralelo a `M1`.

## `tasks-asynq` — el módulo nace en 1.x (2026-11-10)

> La sesión propia que `M0-E` pidió y `M0-F` dejó fuera a propósito: con
> DEP-2026-020 publicado, `nucleus add tasks-asynq` apuntaba a un módulo que
> no existía. La decisión 4 sigue en pie (asynq SALE del módulo raíz en el
> major): lo que cabe en 1.x es que el módulo exista, con su tag, y que el
> import que una aplicación escriba hoy sea el definitivo.

- **La forma**: `providers/tasks-asynq` (nucleus#651) es un módulo de
  **reenvío**: `package asynqprovider` importa en blanco
  `pkg/tasks/providers/asynq` (que es quien se registra en `pkg/tasks`) y
  expone su superficie entera por aliases de tipo y funciones envoltorio.
  Pina nucleus v1.34.0 —el registro de proveedores ya está ahí
  (nucleus#638)— y pasa `check_modules_standalone.sh` sin esperar a ningún
  suelo. El root no cambia: `go.mod` conserva asynq y go-redis,
  `pkg/nucleus/jobs.go` conserva su import en blanco.
- **Lo que vigila que no derive**: `contracts/tasks_asynq_module_test.go`
  compara con `go/parser` los identificadores exportados del paquete del
  árbol y del módulo, y falla nombrando el que falte o sobre.
- **Lo que `M1` hace con él**: mover el código al módulo (ya ensayado en
  `dry-run/2.0`), borrar `pkg/tasks/providers/asynq`, sacar asynq y lo que
  sólo él arrastra (`spf13/cast`, `golang.org/x/time`,
  `google.golang.org/protobuf`: 93 → 89 módulos; medido por `M1-S0`, sesión
  `M1-AS-N`) del `go.mod` raíz —go-redis se queda: seis paquetes del raíz lo
  usan— y hacer obligatorio el import (el error guiado de boot que
  DEP-2026-020 describe). Para una aplicación que ya escribió el import, el
  2.0 es un cambio de versión. Tres cosas que `M1` tiene que tocar a la vez, o
  el `main` del 2.0 se pone rojo al mover el código:
  `contracts/tasks_asynq_module_test.go` pasa de «superficies iguales» a «el
  paquete del árbol ya no existe»; el relleno de `GroupJobs` en
  `internal/cli/add_recipe_test.go` (hoy se apoya en que el framework enlaza
  asynq) pasa a un `tasks.RegisterProvider` de relleno; y
  `TestEveryModuleEntryIsAReleasedModule` lee `providers/tasks-asynq/go.mod`
  por ruta, así que la entrada del catálogo y el directorio del módulo van
  siempre en el mismo PR.
- **Catálogo y listas fijas**: entrada `tasks-asynq` (grupo nuevo «jobs
  providers»; `Key: asynq`; receta con `jobs_provider: asynq` y
  `jobs_redis_url`), `modules.json` y manifest con `0.0.0` (la primera
  release corta el tag), release-please, dependabot, codeql, SECURITY,
  README, SPEC, CLAUDE.md, la lane de providers de `ci.yml`, CI_MATRIX e
  inventario de contratos. Para el paraguas: `nucleus_modules.tasks-asynq`
  en `versions.yaml` y su `use` en el `go.work` en el PR de re-pin, y la
  frase del catálogo de `why-quantum.md` (15 módulos, «a Redis jobs
  provider»), que `umbrella-why-quantum` exige desde este PR.

## `M1-S0` — el major, medido y troceado (2026-11-16)

> `M1` toca los cuatro repos, lleva el primer `!` de la suite y el tren que
> lo certifica, y su fila del plan sólo decía el alcance: igual que `M0`,
> empieza por una sesión de medición (`M1-S0`, ésta) cuyo producto es el
> troceado de abajo. Se midió en sólo lectura sobre `main` de los tres
> hermanos el 2026-11-16 (quark `e5b439d4` = v1.19.1, nucleus `3d64c8ad` =
> v1.36.0, orbit `9ba49df` = v1.22.0 tras la release; el pin de Quantum
> 1.45.0) y sobre las ramas del ensayo `dry-run/2.0` (quark `a2b4558d`,
> nucleus `2dd5b82f`, orbit `f584a53`), con una medición por área (nueve) y
> dos refutaciones por medición (dieciocho: una reprodujo cada comando; otra
> buscó lo que no se había medido). Donde el refutador demostró otra cifra,
> vale la
> suya; cada cifra lleva su comando o su `fichero:línea`. Lo que exige
> publicar para medirse está en «Lo que `M1-S0` no pudo medir sin
> publicar». Regla del plan: las sesiones se miden en ficheros, líneas,
> símbolos, comandos y dependencias; nada aquí se mide en tiempo.

### Lo que hay, contado (al pin de 1.45.0; `main` de los tres el 2026-11-16)

| Área | Medido | Cómo se contó |
|---|---|---|
| La ruta `/v2` (§3.5) | **41 `go.mod`** (quark 13, nucleus 19, orbit 9; el §3.5 decía 39: nucleus ganó `pkg/nucleustest/quarkmake` y `providers/tasks-asynq`), **1 067 ficheros `.go`** y **2 156 líneas de import** propias (800 / 1 073 / 283); de ellas 559 / 989 / 14 apuntan a paquetes del módulo raíz y el resto a módulos anidados (que también cambian de ruta: §3.5 dice «TODOS sus módulos»). Cruzadas: orbit → nucleus/quark en 164 ficheros y 363 líneas (162 a nucleus, 10 a quark) con **20 `require`** en 7 `go.mod` (10 a las raíces, 10 a drivers); nucleus → quark en 13 ficheros, 27 líneas y 2 `require` (`pkg/nucleustest/quarkmake/go.mod:13-14`). 33 módulos publicables: 9 en v1.x y **24 en v0.x** (los 5 drivers de quark, 16 de nucleus, `proto`/`agent`/`server` de orbit). Tabla completa más abajo | `find . -name go.mod -not -path '*/node_modules/*' \| sort` en cada hermano; `git ls-files '*.go' \| xargs grep -h '"github.com/jcsvwinston/<repo>[/"]' \| wc -l` (y `-l` para ficheros); `grep -nE 'github.com/jcsvwinston/(nucleus\|quark)' go.mod */go.mod internal/*/go.mod` en orbit; `.release-please-manifest.json` de los tres |
| Las 34 filas del §3.0 | **34 avisos `active`, 34 filas `publicado`** (ventanas: quark 2026-12-08 ×2, 2027-01-04 ×1, 2027-02-07 ×8; nucleus 2027-01-02 ×8, 2027-01-04 ×1, 2027-01-17 ×9; orbit 2027-01-17 ×2, 2027-02-07 ×3). El ensayo aplicó **30 de 34** (quark 10, nucleus 18, orbit 2) en 13 + 23 + 7 commits sin merge; **las filas 31–34 no tienen commit** (nacieron en `M0-R`, después del ensayo). Coste de rehacer = ficheros que la rama cambia ∩ ficheros que `main` cambió desde la base: **quark 31 de 111, nucleus 83 de 358, orbit 37 de 204** (bases `5c4bceefd`, `dff6f4db7`, `520dcc803`). Las cinco discrepancias que `M0-E` listó siguen en el texto publicado. 29 marcas `// Deprecated:` que el guard ve (quark 5, nucleus 20, orbit 4). **18 hallazgos `A12,abierto`** del registro los cierran estas filas y ninguna sesión los nombraba | `git rev-list --count origin/main..origin/dry-run/2.0` (y al revés); `git diff --name-only origin/main...origin/dry-run/2.0 \| sort` ∩ `git diff --name-only origin/dry-run/2.0...origin/main \| sort` con `comm -12`; `grep -m1 '^- Status:'` y `grep -oE 'no earlier than ...'` sobre los 41 `DEP-*.md`; `bash scripts/check_deprecations.sh` (marcas por aviso); `grep ',A12,abierto,' registro.csv` |
| `pkg/model` y el adaptador | `pkg/model`: **36 declaraciones + 13 constantes + 14 métodos** (el aviso dice «48 símbolos»), 168 líneas del baseline, 4 051 líneas no-test en 12 ficheros + 3 761 de test en 21; lo importan 14 ficheros de nucleus (8 no-test; `cmd/nucleus` 0) y **4 tests más usan la API que se retira** sin importarlo (18 en total). El commit `15504c99` de la rama: 94 ficheros (+201 −589; 38 renombrados, `base.go` y `meta.go` reescritos), **22 cambiados en `main` después**; `0c2c9106` restaura el WARN y su test. El adaptador `datasource/nucleus`: 877 + 669 líneas sin `go.mod` propio; **9 importadores** (`orbit.go:29`, `agent/agent.go:30`, 7 tests de `internal/admin` = 4 899 líneas); 33 de 74 tests del panel montan sobre él; `nucleus/pkg/model` lo importan **24 ficheros** de orbit (6 no-test). `0dada8e`: 184 ficheros (+1 205 −3 867; **96 son `ui/dist`**, 5 de `ui/src`), unión de 5 commits 189, **27 cambiados en `main` después**. `NewWithDB` = **0** en `main` de orbit: el segundo pool SQLite del banco admin (el rojo de `M0-E`) sigue sin arreglar. El starter y el showcase ya montan `DataSource` | `go doc -all ./pkg/model \| grep -E '^(func\|type\|var) [A-Z]' \| wc -l`; `grep -c pkg/model contracts/baseline/api_exported_symbols.txt`; `grep -rln 'nucleus/pkg/model"' --include='*.go'`; `git show --name-status -M 15504c99`; `comm -12` con `git diff --name-only origin/dry-run/2.0...origin/main`; `grep -rn NewWithDB --include='*.go' orbit` |
| asynq fuera del root (fila 22) | Grafo del raíz **93 módulos / 291 aristas**; con asynq se van **4** (`hibiken/asynq`, `spf13/cast`, `golang.org/x/time`, `google.golang.org/protobuf`); **`go-redis` se queda** (sesiones, cache, health, realtime, signals, testredis lo usan: el plan decía sacarlo y no sale). La hello-world **no enlaza asynq** (0 paquetes); `pkg/nucleus` arrastra 9 por el import en blanco de `jobs.go:36`. El paquete: 14 ficheros, 2 947 líneas, 42 identificadores. El módulo `providers/tasks-asynq` ya existe (6 ficheros, 18 indirectos, `v0.1.1`). Delta a portar: **20 ficheros Go del raíz/CLI (+221 −597 frente a la rama; la rama retrocede #638/#651, así que se porta a mano)**, 11 renames sin diff + 3 reescritos, la fila 22 en `ci.yml` son cinco hunks (lane jobs-redis `:385`, lane CLI/providers + «The core links no asynq» `:435`, listas de providers `:531`/`:544`, `cli_workspace.sh` `:670`): 39+/15− del diff de tres puntos (45+/21− en los 11 hunks del fichero: los otros seis, 1+/1− cada uno, son `./pkg/model` → `./internal/model`, de la fila 26, no ruido; `git diff origin/main...origin/dry-run/2.0 -- .github/workflows/ci.yml`), y `release.yml` 6+/2−, `generate_dependency_impact_report.sh:96,227`, `SECURITY.md:90,94-95`. Techos de `hello-size` 79/92 → 75/88 (el guard es `≤`, no igualdad: se bajan por la regla del tsv) | `GOWORK=off GOFLAGS=-mod=readonly go list -m all \| wc -l`; `go mod why -m <m>`; `GOWORK=off go list -deps ./pkg/app \| grep -c hibiken/asynq`; `git diff --stat origin/main origin/dry-run/2.0 -- <20 ficheros>`; `git diff --stat=200 -M … -- pkg/tasks providers/tasks-asynq \| grep -c '=> .*\| *0$'`; `scripts/ci/check_hello_size.sh:139` |
| D11 (quark en la raíz de orbit) | La raíz de orbit no importa quark (0 ficheros del módulo raíz: los 10 que casan el grep viven en `quarkbridge/`, `quarkdatasource/` e `internal/fleettest/`, con `go.mod` propio); 4 aristas internas por tag en verde. Tags desde `datasource/v1.0.0` (2026-09-22): raíz 18, `quarkdatasource` 13, y **6 de esos 13 coincidieron con tags de `ui`/`datasource`/`proto`** que ya obligan a converger: la arista nueva cuesta **7 cortes de convergencia más**, no 13. `datasource/go.mod:8` pina nucleus **v1.30.1** (seis minors detrás, nadie lo ve: QM-22) y `internal/fleettest/go.mod` lleva **11 pines rancios** (7 de la suite: nucleus v1.33.0, quark v1.17.0, server v0.21.1, ui v1.2.0, quarkdatasource v1.13.1, agent v0.16.1, proto v0.8.1; y 4 de drivers: `nucleus/drivers/mysql` y `postgres` v0.1.0 con v0.1.13 certificado, `nucleus/drivers/sqlite` v0.1.7 con v0.2.3, `quark/drivers/sqlite` v0.3.0 con v0.3.3; `grep -cE '^[[:space:]]+github.com/jcsvwinston/[^ ]+ v[^ ]+$' internal/fleettest/go.mod` → 11 `require` directos, los 11 por detrás del set; la `:50`, `orbit/datasource v1.1.0 // indirect`, la refresca `go mod tidy`). `check_internal_pins.sh` (109 l.) ya lee el tercer pin por el glob `orbit/*`; `align_set.sh` (248 l.) lleva `MODULES` de 6 (sin `datasource` ni `ui`, l.66) y la excepción muerta `DATASOURCE_EDGE_MODULE` (l.68, 174-181); `bump-set.sh` sólo descubre módulos por la presencia de `go.mod` (`:143`) y no lee su contenido ni compara pines. **ADR-006 de orbit (l.84-85, l.97, l.100-101) descarta como alternativa lo que D11 hace** | `grep -rl --include='*.go' '"github.com/jcsvwinston/quark' .` + `go.mod` más cercano; `git tag -l '<prefijo>v*' --format='%(creatordate:iso-strict) %(refname:short)'` y `git tag --points-at`; `grep -nE 'jcsvwinston' internal/fleettest/go.mod datasource/go.mod`; `cat -n scripts/release/align_set.sh scripts/ci/check_internal_pins.sh`; `grep -nE 'go\.mod\|require' quantum/scripts/bump-set.sh` |
| La guía y los docs del 2.0 | `scripts/lib/migration-guide.py` 159 líneas; `guia-migracion-2.0.md` 2 703 líneas / 34 entradas; el generador **filtra `status == active` (l.143)**: sobre las ramas del ensayo (quark 8 `completed` + 2 `removed`, nucleus 12 + 13, orbit 1 + 1) da **0 entradas**, y el guard seguiría verde porque `bump-set` la regenera. **28 de 34 avisos llevan código** (13 con `// before … // after`; quark 9/11 y orbit 5/5 con viñetas `Now (v1)`/`At 2.0`; nucleus con **25 asistentes `MA-*` con `## Rewrite`**, todos con código); «What breaks if ignored» en 16 de 34 (nucleus 0/18: su plantilla no tiene la sección); 15 menciones `ADR-` (14 en avisos + **1 que escribe el propio generador**, `migration-guide.py:103`); los 44 ids de hallazgo no los rechaza ningún guard. **Ningún aviso nombra `/v2`**. Deuda de doc del major que las ramas ya enseñan: quark 30 ficheros de `website/docs` (+385 −2 040), nucleus 27 (+767 −1 460), orbit 11 (+298 −657); **46 líneas «v1.x» en 19 páginas servidas** (quark 13 en 6, nucleus 28 en 10, orbit 5 en 3: `git grep -n 'v1\.x' -- website/docs \| wc -l` en cada hermano) sin guard que las vea; `go install` en docs: 13 / 10 / 9 líneas. El sitio sirve 4 instancias; el hueco es «Migration guides» en `website/sidebarsStart.ts` | `wc -l`; `python3 scripts/lib/migration-guide.py --root . --out … --check`; `git show origin/dry-run/2.0:<DEP> \| grep -m1 '^- Status'`; `grep -qE '^[[:space:]]*\`\`\`'` y `grep -c '// before'` por aviso; `grep -oE '<regex de check_served_jargon.sh:33>'`; `grep -rn '/v2' */docs/deprecations` → 0; `git diff --shortstat origin/main origin/dry-run/2.0 -- website/docs`; `grep -rn 'v1\.x' <repo>/website/docs` |
| El tren del 2.0.0 | **61 guards** registrados (62 entradas en `tests/guard-fixtures` = 61 + `lib.sh`); release-please con 7 / 17 / 8 paquetes, sin plugins, `bump-minor-pre-major: true` y `separate-pull-requests: false` en los tres (comprobado con `python3 -I` sobre los tres `release-please-config.json`), **29 `package-name`** (la raíz no lo lleva). **El lint del `!` que ADR-032 regla 2 promete no existe** en ningún repo. Con una raíz `/v2` hoy: `align-module-floors.sh` dice «OK … los 0 módulos» (falso verde), `manifest-guard` §5/§5b hacen `continue` (callan), `align_set.sh` «nothing to do», `check_cli` NOTICE vacío; `check_internal_pins.sh` FAIL ruidoso, `align-orbit-pins.sh` exit 1, `site-pages.py:175-177` `SourceError` (paso 6 de `bump-set`), `check_exit0` rechaza la sonda; `release.yml:97-100` de nucleus deja a `cmd/nucleus` sin tag y su job `verify` (`generate_compatibility_report.sh --enforce-threshold`: `go test ./pkg/model`, baseline con 2 525 rutas v1, harness con literales) **deja la release sin activos**; los ldflags `-X` sobre la ruta literal (quark `.goreleaser.yaml:41` + `version.go:16`; nucleus `.goreleaser.yaml:22`) publicarían binarios que dicen «(devel)»/«dev». `pull_request: branches: [main]` en quark y nucleus (sin CI en PRs a otra rama). `go install …/cmd/nucleus@v1.36.0` con caché virgen: 31 s, OK aunque `cmd/nucleus/go.sum` no lleve la raíz. `sum.golang.org` con una ruta `/v2` hoy: 404 (la v1: 200). El anuncio a quantum-app muere por diseño (su receptor exige las rutas v1 exactas). Los sets 1.x salen de `main` hasta el primer merge de un `!` (release-please sólo mira `main`; 0 ramas `release/*`) | `source scripts/lib/guard-registry.sh; guard_names \| wc -l`; `grep -c '"package-name"' */release-please-config.json`; `grep -rnE 'BREAKING\|\\!:' */.github/workflows */scripts/ci`; lectura de cada script (`fichero:línea` en la sección siguiente); `GOMODCACHE=<tmp> GOBIN=<tmp> GOWORK=off go install …@v1.36.0`; `curl -s -o /dev/null -w '%{http_code}' https://sum.golang.org/lookup/github.com/jcsvwinston/nucleus/v2@v2.0.0`; `gh api repos/jcsvwinston/quantum-app/contents/scripts/bump_set.sh` |
| Lo aditivo de las 32 (D17) | Las 32 líneas del gate nombran **91 elementos (68 con 76 ids distintos y 23 sin id)**; con los 8 de D15 que el gate no lista, 99 filas: 65 con fila en el registro, 16 `hecho`, 49 `abierto`, 11 sin fila (controles de banco `absent`/`partial`); **las diez de D15, `abierto`**. Clasificadas por la tabla completa de abajo: **64 aditivo-corto** (56 del gate + 8 de D15), 16 ya hecho (lo mide `R2`), 6 rompiente (todas en el §3.0: van en `M1`), 12 aditivo-largo y 1 del propietario (QM-37). Ningún commit de `main` desde el pin de `R1` toca los ficheros de los abiertos fuera de los PRs ya registrados | `sed -n 133,221p docs/auditoria/reauditoria/2026-10-23/README.md \| grep -oE '(QK\|NU\|OR\|QM\|MIG\|TYP\|PG\|MY\|RLS\|OPS\|MFA)-[0-9]+' \| sort -u`; `grep "^<id>," registro.csv`; `git log --oneline <pin R1>..origin/main -- <ficheros>` en cada hermano |
| El rediseño (§3.4) | Tokens semánticos del panel 22 / 20 (`ui/src/shared/tokens.css`, 60 l.), paleta numerada del fleet 56 × 2 (`ui/src/fleet/index.css`, 88 l.), **318 usos de clases `-tN` y 271 tamaños a mano** en `ui/src/fleet` (el 213 anterior era un subconjunto); 10 claves `branding.*` (A11), ninguna elige el «look»; banco 19 UIX + 8 UIF (`required` en `ci.yml:424,430`); contraste medido en 7 tests del panel (UIX-01/02/08/09/12/13/17; sólo UIX-13 en los dos temas) y en 4 rutas del fleet en claro y en oscuro; presupuesto 400 KiB gzip, medido 373,4. `dry-run/2.0` **sí toca `ui/`: 5 ficheros de `ui/src` (−359 líneas: el `FieldConfigPanel` que el 2.0 borra) y 96 de `ui/dist`**, ninguno de tema. Sitio: `custom.css` 164 l. / 23 propiedades distintas, marca «el estado fijado» (`docs/brand/`, 2026-06-25); **0 axe/pa11y/lighthouse en el paraguas**; `appearance.go:79-84` duplica los HSL de `tokens.css` en Go; el fleet no tiene superficie de configuración de look (el `server` sirve el SPA sin inyección) | `sed -n '/:root/,/^  }/p' tokens.css \| grep -c '^\s*--'`; `grep -rEo '\b(text\|bg\|border\|ring\|fill\|stroke)-t[0-9]+' ui/src/fleet --include='*.tsx' \| wc -l`; `grep -n 'color-contrast' panel.spec.ts`; `ui/embed_test.go:31`; `docs/admin-bench.md:1385`; `git diff --stat origin/main...origin/dry-run/2.0 -- ui/`; `grep -rn 'axe\|pa11y\|lighthouse\|playwright' scripts .github/workflows tests/sitebench website/package.json` |
| Discussions (D24) | `has_discussions` = **true en `jcsvwinston/quantum`** y false en quark, nucleus y orbit (comprobado por esta síntesis el 2026-11-16, no sólo por el medidor): D24 comprobado activo (la fecha del clic no sale de ningún comando); QM-42 se cierra y la fila 2 de «Lo del propietario» (pendiente del clic) está rancia | `for r in quantum quark nucleus orbit; do gh api repos/jcsvwinston/$r --jq .has_discussions; done` |

#### La ruta `/v2`, frente al §3.5 (medido el 2026-10-18)

| Repo | `go.mod` | ficheros `.go` con la ruta propia | líneas de import | de ellas a la raíz | otros ficheros rastreados que la nombran (sin `versioned_docs`/`node_modules`) | lo que decía el §3.5 |
|---|---:|---:|---:|---:|---|---|
| quark | **13** | **408** | **800** | 559 | **122** (2 577 líneas; 1 537 se regeneran: `acceptance/apisurface.json` 956 + `allowlist.json` 581; 361 son `CHANGELOG`) | 13 / 397 / 808 / 764 (el 764 salía de un `grep -r` sobre ignorados: no es reproducible; `/usr/bin/grep -rl` da 2 209, de los que 1 991 son `website/build` + `website/.docusaurus`) |
| nucleus | **19** | **495** | **1 073** | 989 | **161** (3 705 líneas; 2 525 son `contracts/baseline/api_exported_symbols.txt`) | 17 / 479 / 1 020 / 115 |
| orbit | **9** | **164** | **283** | 14 (`datasource` 71, `proto` 96, `server` 62, `agent` 33, otros) | **54** (1 256 líneas; 931 son `CHANGELOG`s, 174 del baseline se regeneran) | 9 / 152 / 267 / 37 |
| orbit → nucleus/quark | **20 `require`** en 7 `go.mod` (10 raíces + 10 drivers; `internal/fleettest/go.mod` incluido) | **164** (162 a nucleus, 10 a quark) | **363** | — | 28 | 151 ficheros |
| nucleus → quark | 2 `require` (`pkg/nucleustest/quarkmake/go.mod:13-14`) | 13 | 27 | — | 17 | — |
| paraguas | `go.work` con 38 `use` y 0 `replace` (el workspace compila contra `/v2` **sin replace**: laboratorio) | — | — | — | **16 scripts/workflows/fixtures (10 + 6) + 32 docs y páginas = 48**, más 2 que componen la ruta sin nombrarla (`manifest-modules.sh:75`, `align-module-floors.sh:66`) | «21 scripts y páginas» |

Comandos: `find . -name go.mod -not -path '*/node_modules/*' -not -path
'*/.git/*' | sort`; `git ls-files '*.go' | xargs grep -l
'"github.com/jcsvwinston/<repo>[/"]' | wc -l` (y `-h … | wc -l` para líneas;
restando las que casan los directorios de los `go.mod` anidados para «a la
raíz»); `git ls-files | grep -v '\.go$' | grep -v versioned_docs | grep -v
node_modules | xargs grep -l 'github.com/jcsvwinston/<repo>' | wc -l`; `grep
-rlE 'github\.com/jcsvwinston/(quark|nucleus|orbit)' scripts .github/workflows
tests | wc -l` y lo mismo sobre `website/docs website/src docs | grep -v
versioned`. Las cifras del plan se definen sobre `git ls-files` (rastreados),
y así hay que escribirlo en el §3.5 corregido: en este Mac `grep` es una
función de shell sobre ugrep que respeta `.gitignore` (`type grep`), y un
`grep -r` a pelo da otra cosa en otra máquina.

Lo que el `sed` de imports no toca y cambia de comportamiento (ruta literal
fuera de un bloque `import`; comando: `git ls-files '*.go' | xargs grep -n
'github.com/jcsvwinston/<r>' | grep -vE
'^[^:]+:[0-9]+:\s*([A-Za-z_][A-Za-z0-9_]* )?"github.com/jcsvwinston/<r>[/"]' |
grep -vE '^[^:]+:[0-9]+:\s*//'`): **quark 77 líneas en 32 ficheros**
(`internal/migrate/migrate.go:412,425,435` compara `t.PkgPath()` con la ruta
v1 y con `/v2` devuelve `false` en silencio; `otel/otel.go:37-38` es el nombre
de scope OpenTelemetry que ve el usuario —decisión—;
`quarkdriver/known.go:33-37`, `events.go:180-182`,
`cmd/quark/internal/codegen/emit.go:197`, `init.go:352,357`, `migrate.go:49`,
`acceptance/cmd/gen-apisurface/main.go:161` + test,
`gen-allowlist/main.go:94-150` con 7 claves, `acceptance/exercise` ×4;
`cmd/quark/commands/version.go:16` `libraryModule`); **nucleus 154 líneas en
54 ficheros** (`internal/testredis/testredis.go:256,261` busca un `go.mod`
cuyo `module` sea exactamente la ruta v1;
`internal/knownproviders/catalog.go:168` `RepoModule` sirve a la vez a la raíz
y a los hermanos: 15 entradas hermanas (`:183-277`, `:338`, `:407`), 6 de raíz
(`:306`, `:379`, `:430`, `:442`, `:459`, `:494`) y `:578`
`TrimPrefix(e.Module, RepoModule+"/")`; `catalog.go:436,501`;
`pkg/nucleustest/factory.go:73`; 11 `.tmpl` con 29 líneas (26 de código:
`go.mod.tmpl` ×2, `main.go.tmpl` ×3, `module.go.tmpl` ×2,
`module_test.go.tmpl` ×2; 3 de prosa); 36 ficheros no-test de `internal/cli`
con 86 líneas (89 con tests y plantillas, 304 líneas):
`generatemodule.go:48,346,806`, `generate.go:1490,1652`, `routes.go:355`,
`mountedit.go:44`, `makemigrations.go:38`, `new.go:521,649`, `doctor.go:31`; 5
tests de `internal/cli` escriben `replace github.com/jcsvwinston/nucleus =>
repoRoot`; `modules.json` con `Target() = Module@Version` → con la raíz en
`/v2` escribiría `…/v2/providers/tasks-asynq@v0.1.1`, que Go rechaza); **orbit
9 líneas en 6 ficheros** (`internal/admin/management.go:129,158,164`: el
endpoint de salud reportaría «devel»; `proto/nucleus/admin/v1/admin.proto:18`
`go_package` + `admin.pb.go` generado: se regenera con buf/protoc, no con sed;
en quark, `notes.proto:10`). Dependabot: el patrón `dependency-name:
github.com/jcsvwinston/<repo>` a secas deja de casar `<repo>/v2` (quark 10
líneas, nucleus 3 (`:44,:57,:58`; la `:58` ya tolera el comodín `nucleus/*`),
orbit 29; `check_dependabot_floors.sh:117` tomaría `orbit/v2` por un módulo
hermano).

#### Las 34 filas: ensayada, ficheros, solapamiento con `main`, aviso a corregir

Los commits son de `origin/dry-run/2.0` (`git show --format= --name-only
<hash>`); «solapan» es la intersección de esos ficheros con los que `main`
cambió desde la base (`comm -12`); cuando el ensayo aplicó varias filas en un
grupo de commits, la cifra es del grupo y se dice. «Prosa 1.x» son los
ficheros de `main` fuera de `docs/deprecations/`, `versioned_docs`,
`CHANGELOG` y tests que citan el aviso (`grep -rl DEP-2026-NNN`) y quedan
rancios tras el volteo.

| # | Aviso | Ensayada | Ficheros del ensayo | Solapan con `main` | Prosa 1.x | Aviso a corregir (docs, antes de `M1`) | Sesión |
|---|---|---|---|---|---|---|---|
| 1 | quark DEP-2026-001 | sí (`82cd1b77`) | grupo Q1 (filas 1-2): 17 (7 `.go`) | 3 (`CLAUDE.md`, `quarkdriver/listener.go`, `tenant_router.go`) | 1 | el `Summary` cuenta la crónica («is on v1.12.0 with the alias still in place»): la guía la publica como vigente | `M1-R-Q1` |
| 2 | quark DEP-2026-002 | sí (`eca76132`) | grupo Q1 | (grupo) | 1 | — | `M1-R-Q1` |
| 3 | quark DEP-2026-003 | sí (`8bbdef77`) | 11; grupo Q2 (filas 3-6): 40 (31 `.go`) | **8 de 11** (`query_builder.go`, `query_crud.go`, `errors.go` + 5 docs) | 4 | — | `M1-R-Q2` |
| 4 | quark DEP-2026-004 | sí (grupo Q2) | grupo Q2 | 13 (grupo) | 4 | l.74-75 proponen `ErrInvalidQuery` para un mapa que nombre la columna de versión: la rama no lo aplicó (el mapa se escribe tal cual) y rompería la salida v1 que el propio aviso enseña | `M1-R-Q2` |
| 5 | quark DEP-2026-005 | sí (grupo Q2) | grupo Q2 | (grupo) | 3 | — | `M1-R-Q2` |
| 6 | quark DEP-2026-006 | sí (grupo Q2) | grupo Q2 | (grupo) | 4 | la sección se titula «What changes at 2.0 — proposed for `M1`»: el generador no la lee (regex exacto) y «propuesto» ya no es verdad | `M1-R-Q2` |
| 7 | quark DEP-2026-007 | sí (`7b5e27ac`/`87cfbcda`) | grupo Q4 (filas 7, 10, 31): 29 (20 `.go`) | 3 (`migrate_execute.go`, `migrator.go`, `modeling.mdx`) | 4 | — | `M1-R-Q4` |
| 8 | quark DEP-2026-008 | sí (`64a7a6ee`) | grupo Q3 (filas 8-9): 23 (14 `.go`) | 3 (`expr.go`, `query_builder.go`, `query_exec.go`) | 4 | — | `M1-R-Q3` |
| 9 | quark DEP-2026-009 | sí (`3f9a0fff`) | grupo Q3 | (grupo) | 6 | el aviso dice «and the other builder doors that take an operator», sin cifra (la «13 puertas» de una medición no sale de ningún comando) | `M1-R-Q3` |
| 10 | quark DEP-2026-010 | sí (grupo Q4) | grupo Q4 | (grupo) | 3 | — | `M1-R-Q4` |
| 11 | nucleus DEP-2026-009 | sí (`991042e2`) | grupo N1 (filas 11, 12, 13, 25): 58 (44 `.go`) | 6 (`api_exported_symbols.txt`, `pkg/auth/jwt.go`, `pkg/db/migrate.go`, bodycheck test, 2 docs) | 3 | l.47 nombra el método retirado con la ruta v1 (`…/nucleus/pkg/nucleus.Context.HTML`); en el 2.0 la ruta es `/v2`: lo cubre la sección fija de la guía | `M1-R-N1` |
| 12 | nucleus DEP-2026-011 | sí (grupo N1) | grupo N1 | (grupo) | 4 | l.42 no dice que, retirado `nucleus.Context.Set`, un `c.Set(k, v)` **sigue compilando** por la promoción de `router.Context.Set` con otro significado (la rama lo pina a propósito) ni cómo detectarlo | `M1-R-N1` |
| 13 | nucleus DEP-2026-012 | sí (grupo N1) | grupo N1 | (grupo) | 12 | — | `M1-R-N1` |
| 14 | nucleus DEP-2026-013 | sí (`24fdd503`/`8f649ee5`) | grupo N2 (filas 14-19): 64 (46 `.go`); los 33 de `eeb586df` (D9) ya están en `main` por nucleus#662; `15f55a8f` quedó superado | 10 | 12 | — | `M1-R-N2` |
| 15 | nucleus DEP-2026-014 | sí (grupo N2) | grupo N2 | (grupo) | 14 | l.38 («not even asked for its capabilities») y l.120: `DiscoverExternal` (`pkg/plugins/plugins.go:68`) y `Host.CollectInventory` (`:153`) siguen sondeando cada `nucleus-plugin-*` del `PATH`; orbit no los usa (0): o un parámetro de política aditivo en 1.x o rebajar la promesa a «denegado, aunque sondeado» (decisión) | `M1-R-N2` |
| 16 | nucleus DEP-2026-015 | sí (grupo N2) | grupo N2 | (grupo) | 8 | — | `M1-R-N2` |
| 17 | nucleus DEP-2026-016 | sí (grupo N2) | grupo N2 | (grupo) | 9 | — | `M1-R-N2` |
| 18 | nucleus DEP-2026-017 | sí (grupo N2) | grupo N2 | (grupo) | 19 | — | `M1-R-N2` |
| 19 | nucleus DEP-2026-018 | sí (grupo N2) | grupo N2 | (grupo) | 13 | — (la guarda aditiva de `pprof` en 1.x es una pregunta de la ventana, no del aviso) | `M1-R-N2` |
| 20 | nucleus DEP-2026-003 | sí (`f3fe8413`, sin código: godoc de `pkg/authz/enforcer.go`) | grupo N6 (filas 20, 27): 36 (26 `.go`); 12 de los 32 de `b101b88d` bajo `internal/model` | 6 | 4 | — | `M1-R-N6` |
| 21 | nucleus DEP-2026-019 | sí (`cc2c49a6`, `0709555c`, `20a4b03d`) | 18 (el grupo N4 sin los 66 de `815b5256`) | 6 | 4 | l.39-53: el import que el usuario añade es `_ "github.com/jcsvwinston/nucleus/drivers/sqlite"`; con §3.5 (todos los módulos a `/v2`) es `…/nucleus/v2/drivers/sqlite` | `M1-R-N4` |
| 22 | nucleus DEP-2026-020 | sí (`815b5256`: 66 ficheros, +1 349 −340; anterior a #638/#651) | 20 Go del raíz/CLI + 14 movidos + CI (ver área asynq) | 32 de 66 | 19 | 5 rutas literales `github.com/jcsvwinston/nucleus/providers/tasks-asynq` en el aviso y en MA-2026-020 (el `sed` del asistente reescribe a esa ruta): en el 2.0 es `…/nucleus/v2/providers/tasks-asynq` | `M1-AS-N` |
| 23 | nucleus DEP-2026-021 | sí (`6ab180e8`) | grupo N3 (filas 23-24): 30 (16 `.go`) | 5 (`auth-bench.md`, `CONFIG_KEY_REGISTRY`, `authbench_cases_test.go`, `security.md`, `configuration.md`) | 4 | — | `M1-R-N3` |
| 24 | nucleus DEP-2026-022 | sí (`21396c98`) | grupo N3 | (grupo) | 6 | — | `M1-R-N3` |
| 25 | nucleus DEP-2026-023 | sí (grupo N1) | grupo N1 | (grupo) | 3 | l.27 nombra `router.NewWrapResponseWriter` con la ruta v1; ídem fila 11 | `M1-R-N1` |
| 26 | nucleus DEP-2026-024 | sí (`15504c99` + `0c2c9106` + `f3fe8413`) | 94 (+201 −589) + 6 (`0c2c9106`: el WARN restaurado) + 3 (`f3fe8413`: dos baselines y `check_internal_docs_drift.sh`) | **22** | 21 (+ 12 páginas con `pkg/model`) | no nombra `nucleus.Module[C].Models`, `ModuleSpec.Models()`, `App.RegisterModel`, `ErrModelsRegistryNotInitialized` ni que `hooks.NewSQLObserver` cambia de firma (`sql.go:69`); no dice que `App.AutoMigrate` sigue leyendo la gramática `db:` desde `internal/` ni que el WARN se conserva; «48 símbolos» frente a 36 + 13 medidos (la cifra está repetida en la fila 26, en el plan `:258,759` y en la guía `:2017`) | `M1-PM-N` |
| 27 | nucleus DEP-2026-025 | sí (`b101b88d`, `fa9cf935`) | grupo N6 | (grupo) | 5 | l.54 «Not affected: … NewRedisRelay and RedisRelay»: el major lo retipa entero (`Channel(topic string)`, `ForwardToBus(ctx, topic, bus)`) | `M1-R-N6` |
| 28 | nucleus DEP-2026-026 | sí (`66ef09a7`) | 12 (5 `.go`) | 5 | 2 | — (`_time_format=sqlite` es parámetro de modernc; en nucleus sólo lo pina `drivers/sqlite/time_format_v1_test.go`) | `M1-R-N5` |
| 29 | orbit DEP-2026-001 | sí (`e99b7e5`) | 15 (10 `.go`) | 9 | 5 | — | `M1-R-O1` |
| 30 | orbit DEP-2026-002 | sí (`0dada8e` + 4 commits: unión 189) | 184 (+1 205 −3 867; 96 `ui/dist`, 28 de `internal/admin` (29 en la unión de los 5 commits: 18 tests + 11 de producción), 8 de `adminbench`, 9 de `fleettest`, 5 de `ui/src`) | **27** | 6 (+ `website/docs/cluster/agent.md:118`) | no nombra la retirada de `agent.Config.Registry`/`Databases` ni del cableado `ExtensionConfig → a.Models/a.DBs` (`agent/extension.go:105-106`); «the one place in Orbit that imports nucleus/pkg/model» (l.17-18) es falso: 24 ficheros; no dice que el módulo `datasource` deja de requerir nucleus | `M1-AD-O` |
| 31 | quark DEP-2026-011 | **no** (quark#476 `c998941e`, 18 ficheros, nació en `M0-R`) | 5 `.go` de `main` nombran el aviso (`internal/schema/schema.go`, `errors.go`, `migrator.go`, `audit.go`, `client_registry.go`) | — | 7 | — | `M1-R-Q4` |
| 32 | orbit DEP-2026-003 | **no** (orbit#578 `438eb83`, 14 ficheros) | 5 `.go` de `main` (`panel.go` también en la 33: 6 únicos) | — | 10 | — | `M1-R-O2` |
| 33 | orbit DEP-2026-004 | **no** (orbit#576 `fb7356e`, 6 ficheros) | 2 `.go` de `main` | — | 4 | — | `M1-R-O2` |
| 34 | orbit DEP-2026-005 | **no** (orbit#582 `5f0f59f`, 12 ficheros) | 3 `.go` de `main` (`cmd/admin-server/main.go`, `config.go`, `services/peer_service.go`) | — | 6 | — | `M1-R-O1` |

Y una fila que falta en los 34 y que todo consumidor necesita primero: **la
ruta de módulo `/v2`** (`go get …/v2@v2.0.0` y el `sed` de imports). Es
empaquetado sin aviso ni ventana (`POLITICA_DEPRECACION.md:109-113`: no mueve
el 2027-02-07), así que no es un DEP nuevo sino una sección fija del generador
de la guía (`M1-G-P`), que también tiene que decir que `go get
github.com/jcsvwinston/quark@latest` seguirá resolviendo v1.19.x para siempre
sin aviso de `go` (no habrá marca `// Deprecated:` de módulo:
`POLITICA_SOPORTE.md:62,240` prohíbe el tag v1 posterior que la haría
visible).

### Lo que el contrato no decía

Lo nuevo que salió de medir, en el orden en que muerde: primero lo que
decide si un PR de `M1` puede estar verde, después lo que decide si el
corte sale con activos, y al final lo que es prosa.

**La ruta `/v2` y el workspace**

- **El §3.5 presupone el lockstep y lo que falta es el mecanismo.** «Renombra
  la ruta de TODOS sus módulos» y «en v2.0.0, en lockstep (QADR-0002,
  QADR-0010)» (`quantum-2.0.md:384-387,416-417`) ya es decisión: no se reabre.
  Lo que ningún documento dice es cómo release-please pone 2.0.0 en los 24
  módulos v0.x: con `bump-minor-pre-major: true` un `feat!:` deja a cada
  v0.x en v0.(x+1).0, y un tag `v0.*` sobre una ruta `/v2` es inválido para
  Go («should be v2, not v0», reproducido en laboratorio). Con
  `separate-pull-requests: false` hay UN release PR por repo y «`Release-As:`
  se aplica a TODOS los paquetes» (`scripts/train/README.md:616-627`,
  verificado en vivo con `quarkbridge` 0.4.10 → 1.8.17): basta un footer
  `Release-As: 2.0.0` en el cuerpo del squash del commit `!` de cada repo (que
  toca los 13/19/9 `go.mod`), y revisar el manifiesto del release PR antes de
  fusionarlo. ADR-032 de nucleus (l.49-54) y el README del tren vetan
  `Release-As` para SUPLIR un `!`, no para fijar el número junto a él; que lo
  decida el propietario (pregunta 1). Las alternativas (`release-as` por
  paquete en los tres `release-please-config.json` y un `chore` que lo quite
  tras el corte; o el plugin `linked-versions`, que deja los 33 módulos en
  lockstep para siempre) no son inertes en 1.x: actúan en el siguiente
  release PR aunque no haya `!`. Majors mezclados (raíces en `/v2`, módulos
  0.x sin sufijo) son legales en Go pero no caben en «una unidad = un PR»:
  release-please atribuye el squash a cada componente cuyos ficheros toca
  (`orbit/quarkbridge/CHANGELOG.md:8,15,23`), así que el `feat!:` que toca
  `cmd/quark/go.mod` le propone 2.0.0 a `cmd/quark` (v1.3.1) sobre un
  `go.mod` sin `/v2` y Go rechaza el tag.
- **Los tags no cambian de forma, pero `cmd/nucleus` sí cambia de ruta de
  instalación**: `cmd/nucleus` es módulo propio desde v1.32.0 (ADR-038) y va
  en lockstep por `release.yml:86-113`, no por release-please: su ruta pasa a
  `github.com/jcsvwinston/nucleus/cmd/nucleus/v2` y el `go install` también;
  el §3.5 la escribe mal (`…/nucleus/v2/cmd/nucleus`). `cmd/quark` sí es
  paquete de release-please (v1.3.1) y hoy **no va en lockstep**: requiere
  quark v1.19.0 con el set en v1.19.1 porque no lleva `x-release-please-version`
  (nucleus sí: `cmd/nucleus/go.mod:8`). Bajo `/v2`, `cmd/quark/v2` tiene que
  requerir `quark/v2 v2.0.0` desde su primer tag: la anotación y la entrada en
  `extra-files` del paquete raíz son un `chore` de 1.x en quark (`M1-T-Q`),
  prerrequisito del major, no trabajo del tren.
- **El workspace compila contra `/v2` sin `replace` y sin tags.** En modo
  workspace un módulo en `use` satisface el `require` a cualquier versión,
  incluida una inexistente, para `go build`/`vet`/`test`/`list ./...`; sólo
  `go list -m all`, `go work sync`, `go mod verify` y `GOWORK=off go mod tidy`
  van al proxy (laboratorio en `scratchpad/m1s0/rv2-lab`, go1.26: `module
  example.com/a/v2` + `require example.com/a/v2 v2.0.0` inexistente → `go
  build` OK). Ni el `go.work` del paraguas (38 `use`, 0 `replace`) ni el
  rastreado de orbit necesitan un `replace` versionado, y
  `check_gowork_covers_manifest` no tiene nada que tolerar. Lo que sí espera
  al tag o a una pseudo-versión son **las lanes `GOWORK=off`** (quark
  `ci.yml:352-364` «Driver modules (standalone, no workspace)»; nucleus
  `check_modules_standalone.sh:35-46`, que hace `go mod tidy` por módulo y
  FALLA; orbit `ci.yml:29-60,96-111,289-319`) y `go mod tidy`. Con D23 (gate
  requerido en `main`) un PR con esas lanes rojas no se fusiona: o la lane
  aprende la salida NOTICE que `check_cli` ya tiene (`:70-72`) cuando el
  proxy no sirve el suelo (`M1-T-N`, `M1-T-Q`), o cada repo publica una
  pseudo-versión `v2.0.0-<yyyymmddhhmmss>-<sha>` (la forma 1 de Go para una
  ruta sin tags v2) en un segundo PR después del primero, y los `go.mod`
  anidados y los consumidores la requieren hasta el corte. Es la trampa de
  «Orbit pina nucleus v1.1.0»: entre el primer commit y el tag, cada avance
  de quark/nucleus no llega a nucleus/orbit hasta que alguien sube la
  pseudo-versión a mano; `align-module-floors.sh:37` exige «el target tiene
  que estar publicado» y nunca se ha probado con un target pseudo (QADR-0005
  tiene el precedente pre-1.0).
- **Diez lectores de ruta del paraguas y cuatro de orbit/nucleus se
  comportan distinto con `/v2`, y cinco callan.** Callan: `manifest-guard.sh`
  §5 (`:247-264`, `continue` en `:252` si no encuentra la ruta literal) y §5b
  (`:292-324`, `continue` en `:302`), `align-module-floors.sh` (`ROOT_MOD`
  literal `:66`, awk `:89`
  → «OK … los 0 módulos hermanos», exit 0), `align_set.sh` de orbit (`want_for`
  `:165-183` devuelve vacío y `:202` hace `continue` → «nothing to do»),
  `check_cli` de nucleus (`check_modules_standalone.sh:70-72`: floor vacío →
  NOTICE y `return 0` sin comprobar). Mueren o fallan en voz alta:
  `check_internal_pins.sh` de orbit (`:89-94`: el glob `$MODULE_ROOT/*` casa
  `…/orbit/agent/v2`, `want` vacío → FAIL por cada `require` interno),
  `align-orbit-pins.sh` (`:27` lookup a `sum.golang.org` con la ruta v1; `:49`
  lee `quark/v2` como módulo «v2»), `site-pages.py:175-177` (`SourceError` si
  el `module` del `go.mod` no es `{OWNER}/{repo}`: `bump-set` muere en el paso
  6, sin `api-*.md`, `catalog.md` ni post del set),
  `check_exit0_regressions.sh:114-128`
  (la sonda necesita el sufijo Y `v2.0.0-00010101000000-000000000000`:
  `require …/v2 v0.0.0` es inválido aunque haya `replace`),
  `print-requires.sh:50-61`
  y `manifest-modules.sh:75` (emiten `github.com/jcsvwinston/<repo> v2.0.0`,
  inválido, que viaja a quantum-app por `dispatch-app-bump.sh:75`), nucleus
  `release.yml:97-100` (awk literal → floor vacío → sin `cmd/nucleus/v2.0.0`),
  `cli_workspace.sh:27,42`, `check_hello_size.sh:55-65`,
  `run_compatibility_harness.sh:135,145`, `test_with_engines.sh:78`,
  `link_unpublished_siblings.sh:37-60` (derivaría el directorio
  `v2/quarkdatasource`, inexistente), `integration.yml:120,133` (dos `go
  install` con la ruta v1). Y **`versions.yaml` no colisiona**: `manifest-guard`
  §3b, `manifest-modules.sh:52-63` y `bump-set.sh:132-142` derivan la clave de
  cada módulo del DIRECTORIO, no de la ruta.
- **Las fixtures de `guard-of-guards` doctoran con la ruta v1 y dejarían de
  morder**: `umbrella-manifest-guard/fixture.sh:52-58` (awk sobre
  `github.com/jcsvwinston/quark` → «la rotura 2 no aplica», exit 1) y
  `orbit-internal-pins/fixture.sh:29-32` (el `sed` no casa `…/proto/v2
  v2.0.0`). `guard-of-guards` es `needs` del cierre
  (`suite-integral.yml:102-137`).
- **El primer commit del major necesita una regla transitoria en orbit**: en
  ese commit la raíz pina `…/orbit/v2/quarkdatasource v2.0.0` antes de que
  exista el tag; el caso `initial_version` de `check_internal_pins.sh:48-55`
  sólo dispara cuando el módulo no tiene NINGÚN tag (quarkdatasource tiene
  13+), así que FAIL; `link_unpublished_siblings.sh` sólo cubre hermanos de
  orbit sin tag. Hace falta «pin == v<N+1>.0.0 mientras el último tag sea
  v<N>.x y el `go.mod` raíz lleve `/v<N+1>`» en los dos (`M1-T-O`).

**El corte: lo que dejaría una release sin activos**

- **El job `verify` de `release.yml` de nucleus (`:40-48`) bloquea el major
  antes que el awk del CLI**: corre `generate_compatibility_report.sh
  --enforce-threshold`, que ejecuta `go test ./pkg/model` (`:101`; el paquete
  que D5 retira), `check_contract_freeze.sh` contra un baseline con 2 525
  rutas v1 (`:105`) y el harness con `awk`/`replace` literales
  (`run_compatibility_harness.sh:135,145`); cualquiera en rojo → NOT READY →
  exit 2 → `tag-cli-module` y `publish` no corren (`needs: verify`,
  `:66-67,125-126`): **nucleus v2.0.0 saldría sin activos y sin
  `cmd/nucleus/v2.0.0`**, y `check_release_assets.sh` pondría rojo el
  cierre. Se ensaya sin publicar con `nucleus/.github/workflows/rehearsal.yml`
  → `scripts/release/rehearse_rc.sh:30-35` (goreleaser `--snapshot
  --skip=publish` + el informe).
- **Los binarios publicados se identificarían como «devel»/«dev»**: los
  ldflags estampan la versión sobre la ruta de importación literal
  (`quark/.goreleaser.yaml:41` → `cmd/quark/commands.version`;
  `nucleus/.goreleaser.yaml:22` → `internal/cli.Version`); con `/v2` el
  enlazador ignora un `-X` sobre un símbolo que no existe, `quark version`
  cae a `debug.ReadBuildInfo` («(devel)», `version.go:37-60`; y
  `libraryModule`, `version.go:16`, deja de casar `dep.Path`), `nucleus
  version` imprime `dev` (`internal/cli/root.go:33`), y
  `release_asset_smoke.yml` (quark `:157,189,218`; nucleus `:148,180`) se pone
  rojo DESPUÉS de publicar, y además es `workflow_dispatch` (el tren no la
  corre). Orbit usa `-X main.version` (`.goreleaser.yaml:62`) y no lo sufre.
- **La trampa de 1.38.0 es de seis módulos, no de uno**:
  `cmd/nucleus/go.mod:9-13`
  requiere los cinco drivers (v0.1.8) y, tras `M1-AS-N`,
  `providers/tasks-asynq`;
  con `/v2` todos nacen `v2.0.0` en el mismo corte; el `release.yml` de la
  rama (`:305-310`) enlaza desde el checkout sólo `providers/tasks-asynq`. Y
  **nadie escribe ni vigila esos pines**: release-please sólo reescribe
  `cmd/nucleus/go.mod:8`; `align-module-floors.sh:89` sólo alinea el
  `require` de `$ROOT_MOD`; `check_internal_pins --check` no mira los
  internos (trampa de 1.42.0); `tag-cli-module` sólo comprueba el suelo del
  raíz. Lo mismo en `cmd/quark/go.mod` (drivers v0.2.0 con el set en v0.3.3:
  QK-72/NU-147).
- **Un `go install` al tag no necesita que `go.sum` del CLI lleve la raíz**
  (medido: `cmd/nucleus@v1.36.0` con caché virgen, 31 s, `cmd/nucleus/go.sum`
  sin ninguna línea de la raíz): nacer juntos no bloquea el install.
- **Sin CI en los PRs contra la rama del major**: quark `ci.yml:6-7` y nucleus
  `ci.yml:7-9` sólo disparan `pull_request` contra `main`; orbit no filtra. Y
  **cómo aterriza el major en `main` no está decidido**: los cuatro repos
  permiten squash, merge commit y rebase (`gh api … --jq .allow_squash_merge
  …` → `true` ×3 en los cuatro; squash-only es convención), ninguna rama
  `major/2.0` existe ni está definida (sólo `dry-run/2.0`), y desde el
  primer merge de un `!` en `main` no puede salir ningún set 1.x
  (`release-please.yml` `branches: [main]` en los tres; 0 ramas `release/*`;
  D21/D22 sin LTS). La rama `major/*` como excepción del lint del `!` y el
  orden «tres `!` seguidos tras el último set 1.x» dependen de esa decisión
  (pregunta 2).
- **La lane `suite-starter` de nucleus cierra un ciclo entre repos**:
  `ci.yml:759-791` clona quark y orbit en su ÚLTIMO tag de raíz (`git
  ls-remote --tags --sort=-v:refname … | head -1`) y exige los checkouts
  (`NUCLEUS_REQUIRE_SIBLING_CHECKOUTS=1`, `:835-867`); con nucleus `main` en
  `/v2` y orbit v1.22.x (que requiere nucleus v1) la lane no puede estar
  verde hasta que exista orbit v2, y orbit v2 requiere un nucleus v2
  resoluble. Un ref de hermano por entrada (variable o `workflow_dispatch`
  input, con «tag más alto» como defecto) es aditivo y cabe en 1.x
  (`M1-T-N`); en local sólo con `NUCLEUS_SIBLING_CHECKOUTS` apuntando a un
  orbit en su rama del 2.0 (`new_with_orbit_boot_test.go:36-49`).
- **El anuncio a quantum-app muere por diseño**
  (`quantum-app/scripts/bump_set.sh:82-83,147-151`
  exige las cinco rutas v1 exactas) y `train.sh:1419-1421` termina en `die`
  tras certificar; no hay `--sin-dispatch`. Decisión ya tomada (§4.7:
  quantum-app se rehace entero sobre el 2.0; «quantum-app no frena nada»):
  el runbook lo salta (`M1-T-P` añade el flag).
- **`ui` es un módulo con tag propio requerido por tag** desde la raíz
  (`go.mod:39`), `server` (`server/go.mod:10`) y `internal/fleettest`, y el
  paraguas lo pina (`versions.yaml:83`): cualquier cambio en `ui/src` (la
  fila 30 borra el `FieldConfigPanel`; cinco sesiones de la ventana tocan la
  SPA; el rediseño entero) reconstruye y commitea `ui/dist` (`ci.yml:393-401`
  «dist matches source»; 70 ficheros rastreados) y cuesta un corte de `ui` +
  re-pin + segundo corte de la raíz y `server`
  (`scripts/train/README.md:927-933`).
  Las sesiones de SPA se agrupan en un mismo set para pagar un segundo corte,
  no cinco.
- **Nadie alinea los pines de orbit sobre los MÓDULOS de nucleus**:
  `go.mod:10` y `datasource/go.mod:9` pinan `nucleus/drivers/sqlite v0.1.7`
  (certificado v0.2.3), `server/go.mod:14-16` `mysql`/`postgres` v0.1.0
  (certificado v0.1.13); `align-orbit-pins.sh:49` sólo descubre `quark/…`,
  `align_set.sh` sólo tiene `--quark-module`, `manifest-guard` §5 sólo
  compara raíces, dependabot ignora `nucleus/*`. D11 añade a la raíz un pin
  de módulo de quark y deja huérfanos los de nucleus. `declared_lags` no es
  expresable por `go.mod` (se indexa por dependencia, `manifest-guard.sh:254`):
  sólo cabe subir el suelo de `datasource/go.mod`, que corta
  `datasource/v1.1.3` y obliga a re-pinar raíz, agent y quarkdatasource (lo
  hace `align_set.sh` solo en cuanto `datasource` esté en `MODULES`).
- **Los scripts del tren llevan la arista vieja**: `orbit-align-notes.sh:46`
  escribe «`quarkdatasource` pins the root at {prev}» (retirada por ADR-012;
  con D11 es al revés) y `orbit-converge.sh` sólo alinea `agent`/`server`.
  `manifest-guard` §3 (`:138`) es lista fija de 5 (QM-24), no sólo §5 (QM-22).
- **`release-please` oculta `docs:`** en los tres productos
  (`changelog-sections`): una sesión de sólo docs (notas, avisos corregidos,
  páginas) llega al pin sólo montada en un `feat`/`fix` del mismo producto, y
  el snapshot de docs se corta por minor. Cada fila de docs dice con qué
  corte viaja.

**La guía y los avisos**

- **Con la forma de cierre del ensayo (`Status: completed`/`removed`) la guía
  del 2.0 queda vacía y el guard verde**: `migration-guide.py:143` sólo
  rinde `active`; `check_deprecations.sh:48,346` ignora `removed`/`completed`
  y una fila `publicado` sólo exige que el fichero exista; `bump-set` la
  regenera en cada re-pin (`:242,260,269`); el §4.3 pide una entrada por
  cambio. Y muerde antes del major: **la regla D2 de
  `POLITICA_DEPRECACION.md` §4 (volteo a `completed` al vencer la fecha;
  APROBADA el 2026-09-09, l.139: «La deprecación pasa a `completed` en su
  aviso y espera al major en esa lista») voltea un aviso en 1.x cuando vence
  su fecha**: quark 001/002 el 2026-12-08, ocho de nucleus el 2027-01-02,
  quark 003 y nucleus 009 el 2027-01-04, nueve de nucleus + dos de orbit el
  2027-01-17 (y quark 004…011 + orbit 003…005 el 2027-02-07 si el major no
  está cortado ese día). `check_deprecations.sh:346`
  ya ignora `completed`: la única pieza que falta es el generador, no la
  política. El generador tiene que seleccionar por versión de ventana
  (v2.0.0) sea cual sea el `Status`, y rendir el estado por entrada
  («removed/changed at v2.0.0» tras el major; antes, «not before»): es el
  primer PR del paraguas con fecha (`M1-G-P`(a), incondicional, antes del
  set posterior al 2026-12-08). La alternativa («`active` hasta el commit
  del major») exigiría enmendar esa fila aprobada de la política —decisión
  del propietario, README de planes §2— y no se recomienda (nota tras la
  pregunta 8: no es pregunta). No
  es la D2 del §3.3 del contrato (DEP-2026-003 de nucleus, las filas de
  política de 3 columnas, fechada al 2.0). El volteo por vencimiento
  (`Status: completed` a secas) y la aplicación en el major (`Status:
  completed (applied on <rama del major>, fecha; the v2.0.0 tag publishes
  it)`, la forma que nucleus ya usa en `dry-run/2.0` en sus 18 avisos)
  llevan forma distinta, para que ninguna precondición confunda vencer con
  aplicar; los volteos por fecha son `M1-G-F1…F5` (tramo 1.x). El §3.0 tampoco
  tiene estado para «aplicado» (el guard
  sólo conoce `publicado|en main|por escribir|decisión|descartado`): §4.2
  no tiene mecanismo tras el major.
- **El «antes/después» y la «salida en 1.x» ya existen en la mayoría**: no
  hay que reescribir 30 avisos sino hacer que el generador los lea (viñetas
  `Now (v1)`/`At 2.0` de quark y orbit; `## Rewrite` del `MA-*` que cada
  aviso de nucleus cita en `Assistant spec:`). Lo que falta de verdad: 2
  avisos de quark sin viñetas, la sección «What breaks if this is ignored»
  en la plantilla de nucleus y sus 18 avisos, el retitulado de DEP-006, la
  crónica de DEP-001, las 14 menciones `ADR-` en avisos (la servida pasa por
  `umbrella-served-jargon`, `check_served_jargon.sh:33`; los ids `QK-5`
  no los rechaza ningún guard), y las correcciones de la tabla de arriba.
- **Tres correcciones de la tabla de las 34 filas amplían lo que un aviso
  publicado dice que rompe** (DEP-2026-025 l.54 «Not affected: …
  NewRedisRelay and RedisRelay»; DEP-2026-024 sin `hooks.NewSQLObserver`;
  orbit DEP-2026-002 sin `agent.Config.Registry`/`Databases`), y si abren
  ventana nueva no lo decide esta sesión. Medido: los cuatro métodos de
  `RedisRelay` toman `Signal`/`Event`/`Handler` (`git -C nucleus diff
  origin/main origin/dry-run/2.0 -- pkg/signals/`: `Channel(signal Signal)`,
  `Publish(ctx, event Event)`, `Subscribe(ctx, signal Signal, handler
  Handler)`, `ForwardToBus(ctx, signal Signal, bus)`), `NewSQLObserver`
  devuelve `model.SQLQueryObserver` y `agent.Config.Registry` es
  `*model.Registry`: las firmas cambian porque sus tipos son los que retiran
  DEP-025/024 y orbit DEP-002. Pero `POLITICA_DEPRECACION.md` §3 (l.109-113)
  sólo exime de ventana el empaquetado y lo experimental —ninguna línea
  cubre una firma pública que cambia—, un usuario que leyó «Not affected»
  tendría menos de 90 días desde la corrección, y el §5 del contrato (l.439:
  «entra moviendo la fecha del 2.0, por decisión de Carlos») y el README de
  planes §2 ponen la ventana del lado del propietario. Es la pregunta 4
  (D29): (a) comparten la ventana del aviso que retira sus tipos
  (recomendación, con la regla escrita como enmienda del §3 de la política)
  o (b) abren aviso propio (mueve el 2.0 ≥ 90 días desde el set que lo
  publique, o los tres símbolos quedan en el 2.0 sobre una capa de
  adaptación hasta el 3.0). Las tres van en `M1-G-N`/`M1-G-O` con la fecha de
  la corrección, y `M1-R-N6`/`M1-PM-N`/`M1-AD-O` llevan D29 rellena como
  precondición.
- **La tabla §6 de `POLITICA_DEPRECACION.md` (23 filas) va 11 avisos por
  detrás y ningún guard la lee**: no sirve como fuente de «salida en 1.x».
- **Un último tag v1 con `// Deprecated: use …/v2` en el `go.mod`** es lo
  único que avisaría a un `go get @latest` sobre la ruta v1, y contradice
  D21/D22 (`POLITICA_SOPORTE.md:62,240`): decisión por escrito (pregunta 8).

**`pkg/model`, el adaptador y D11**

- **`App.AutoMigrate(models ...any)` se queda público leyendo la gramática
  `db:` de `pkg/model` desde `internal/model`** (rama `app.go:147-151`;
  `AutoMigrate` no toca el registro ni en `main` ni en la rama): retirarlo o
  retiparlo sobre quark necesita un aviso que no existe y que no cabe antes
  del 2027-02-07. Recomendación: queda como la rama y se anota como deuda del
  3.0 (pregunta 5).
- **La fila 30 y el `go.mod` de D11 son el MISMO PR**: los 7 tests del panel
  que importan el adaptador no compilan sobre `quarkdatasource` sin los
  `require` de quark, `quark/drivers/sqlite` y `quarkdatasource` en la raíz
  (la rama los trae en el mismo ensayo: `git show origin/dry-run/2.0:go.mod`
  → 4 `require` que CAMBIAN, no 3 que se añaden, porque la raíz sigue
  requiriendo nucleus/v2 y `nucleus/drivers/sqlite`). Lo que queda de D11
  (ADR-006 y ADR-012, scripts, prosa, `module-matrix`, OR-88) es un segundo PR.
- **ADR-006 de orbit contradice en sus alternativas descartadas lo que D11
  hace**: l.97 «Relajar `check_internal_pins.sh` para tolerar un patch de
  desfase. Rompe exactamente lo que el guard protege» (responde NO a la
  tolerancia raíz → quarkdatasource) y l.100-101 «Mover los tests a la raíz …
  heredaría la misma cascada». La tolerancia se decide contra ADR-006, no en
  blanco; la alternativa no medida es `extra-files` de release-please
  (`orbit/release-please-config.json:75-86` ya usa el updater `generic`) sobre
  la línea `require …/quarkdatasource vX // x-release-please-version` de la
  raíz, ensayable en 1.x sobre la arista raíz → `ui` (pregunta 7).
- **El segundo pool SQLite del banco admin sigue sin arreglar** (`NewWithDB`
  = 0 en `main`; la rama abre `quark.New("sqlite", dsn)` en
  `adminbench/env_test.go:158`): copiar la rama reproduce el rojo de `M0-E`;
  hay que abrir con `quark.NewWithDB(driver, srv.DB())` sobre el handle. Sin
  Playwright instalado el banco se salta y registra lo grabado:
  `ORBIT_BENCH_BROWSER=required` (`browserbench_test.go:190`) lo convierte
  en fallo.
- **El paraguas tiene 20 ficheros que nombran `pkg/model` o el adaptador** y
  ninguna sesión los tenía: `website/docs/choosing-a-data-layer.md:16,44`
  («Data Studio browses the models in the app's pkg/model registry out of
  the box»: contradice D5), `what-is-quantum.md:74`, `README.md:87`,
  `docs/RUMBO.md:187-188`, `check_tag_grammar.sh:66` (texto), `api-nucleus.md`
  (generada por `site-pages.py`; `bump-set` la reescribe) y tres fixtures
  que doctoran con `pkg/model.InventedByGuardOfGuards…`
  (`nucleus-docs-coverage`, `nucleus-contract-freeze`, `nucleus-bodycheck`):
  siguen fallando como deben, pero el escaneo anti-fósil debe correrlas al
  pin nuevo.
- **Los guards de postura del paraguas leen al pin los bancos que `M1`
  regenera** con suelos y cabeceras fijas (`check_quark_posture.sh:40`
  EXPECTED_CONTROLS=69; `check_api_posture.sh:47-49` 46 +
  `starter_openapi.json`;
  `check_admin_posture.sh:50-52` 73/73/13; `check_fleet_posture.sh:52` 50, con
  51 casos ya en `fleetbench` y «50 of 50» en la tabla publicada;
  `check_catalog_posture.sh:41-46` 38/36) y el espejo de sidebars
  (`check_sidebar_sync.sh`; `website/sidebars*.ts` no están en `RUTAS_REPIN`):
  todo eso va en el PR de set con `--incluye`, como en 1.45.0.

**asynq**

- **`go-redis` no sale del raíz** (lo usan `pkg/auth/session_store_redis.go`,
  `pkg/cache/rediscache`, `pkg/health/redis.go`, `pkg/signals/redis.go`,
  `pkg/realtime/redisrelay.go`): el plan (`A12-…:718`) y el aviso (l.22)
  dicen lo contrario; se corrige aquí.
- **`internal/cli` es del módulo raíz y no puede importar el módulo** (ciclo):
  `doctor` resuelve por el registro y `cmd/nucleus` enlaza el módulo con un
  import en blanco (`cmd/nucleus/providers.go`, +19), lo que hace que
  `cmd/nucleus/go.mod` requiera un tag que nace en el mismo corte (ver la
  trampa de seis módulos). Tres tests más de `pkg/nucleus` dependen de que
  el raíz enlace asynq y nadie los contaba (`jobs_test.go:242,305` —el
  texto «jobs_redis_url» lo pone hoy `register.go:45` del proveedor—,
  `runtime_tasks_outbox_test.go:84-96`). Los hallazgos NU-156, NU-168 y
  NU-157 viven en el código que se mueve: NU-156 y NU-168 son fixes de 1.x
  (`V-N8`; el movimiento los arrastra ya arreglados: §5 del contrato, lo que
  no rompe se publica en 1.x) y NU-157 se re-apunta en `M1-AS-N`; NU-154
  (abrir el enum de `jobs_provider` al registro) es aditivo y entra en la
  ventana (`V-N9`).
- **Orden fijo con rebase**: `M1-V2-N` y `M1-AS-N` editan los mismos
  ficheros (`cli_workspace.sh:27`, `check_modules_standalone.sh:70`,
  `release.yml:94` y el paso «Link The CLI Module», `check_hello_size.sh`,
  `Makefile`): la segunda rebasa tras fusionar la primera (regla de
  «fusionar en serie»).

**El rediseño**

- **La rama del major toca `ui/src` y `ui/dist`** (5 y 96 ficheros): el
  carril del rediseño reconstruye el MISMO `ui/dist` (conflicto en cada
  rebase) y una maqueta de «Data Studio con modelo abierto» sobre 1.x dibuja
  el panel de metadatos por campo que el 2.0 borra (−290 líneas de
  `FieldConfigPanel.tsx`). Independiente del major sólo en `tokens.css`,
  `appearance.go`, `branding.go` y `first_frame_theme.js`.
- **Si un defecto visual que cambia es un «volteo»**, el precedente que el
  §3.4 cita («como `CheckVersions()`») LLEVA aviso (DEP-2026-003,
  `POLITICA_DEPRECACION.md:259`) y la segunda pasada del guard existe para
  avisos sin marca (`:184-191`); un DEP publicado después del 2026-11-16
  abre ≥ 2027-02-2x y mueve el 2.0, o `RD-2` pasa al 2.1 (pregunta 12a;
  decidida el 2026-11-16, D37 a: sin aviso).
- **El §4 del contrato no se cumple sin maquetas**: los puntos 4 («AA con el
  tema nuevo») y 5 («documentación 2.0 publicada con el rediseño») exigen el
  rediseño, y el §3.4 dice «se planifica después de lo pendiente (§2)»: las
  diez cortas de D15 están `abierto`. Sin elección del propietario el carril
  no bloquea `M1` pero sí el criterio de terminado tal como está escrito.

**Lo que aún falta en 1.x y ninguna fila nombraba**

Las diez de D15 (todas `abierto`); `datasource/go.mod` → nucleus v1.36.0
(QM-22, corta `datasource` y converge raíz/agent/quarkdatasource); los 11
pines de `internal/fleettest/go.mod` (7 de la suite + 4 de drivers); la prosa
de la arista en orbit
(`README.md:213,219`, `CONTRIBUTING.md:65`, `docs/V1_GATE.md:30`,
`ci.yml:314`, `go.work:20`, `website/docs/quick-start.md:129-131` «Quark never
enters the panel's dependency graph», `quarkdatasource/README.md:68`; con
OR-137); `knownproviders.RepoModule` partido; los patrones de dependabot;
`site-pages.py`; la sección fija de la guía; el `§3.5` y `A12-…:756,718`
corregidos; OR-121/OR-116/OR-129 antes del re-skin del fleet; la lane
`suite-starter` con refs; un job agregador en el paraguas (D23: `A12-…:815`,
sin sesión); el refresco de la matriz de orbit por PR (D23, V-O12; con
`allow_auto_merge` false en los cuatro y `GITHUB_TOKEN` sin disparar CI, el
criterio observable es «la release abre el PR», y hace falta un secreto
`RELEASE_PR_TOKEN` del propietario: ajuste de repo, 0 secretos hoy en orbit);
Discussions ya está
(QM-42 se cierra en el PR de `M1-S0`).

### Las sesiones de `M1`

Una fila por PR (donde una sesión es dos o tres PRs por construcción, cada
letra lleva su precondición y su criterio). `M1` son 23 sesiones más el
tren; delante va un tramo 1.x de 18 sesiones (`M1-V2-P`, `M1-T-O/N/Q/P`,
`M1-T-LINT-Q/N/O/P`, `M1-G-P`, `M1-G-Q/N/O`, `M1-G-F1…F5`), que NO son `M1`
sino su precondición —`M1` empieza con `M1-V2-Q`(1), el primer `feat!:`—. Los
ids son estables: `M1-V2-*` la ruta `/v2`, `M1-R-*` las
retiradas y los volteos por grupo de ficheros compartidos, `M1-PM-N` y
`M1-AD-O` las dos retiradas de paquete, `M1-AS-N` asynq, `M1-D11-O` lo que
queda de D11 en orbit, `M1-G-*` la guía y los avisos, `M1-D-*` la deuda de
doc del major, `M1-T-*` lo que el tren y los guards aprenden, y `M1-TREN`
el tren. Tres ids del esquema se fundieron: `M1-V2-P` absorbe `M1-T-P1` y la
mitad del paraguas de `M1-D11-P` (los mismos cinco scripts); `M1-D11-P` se
reparte entre `M1-V2-P` (lectores y fixtures) y `M1-T-P` (lane
`orbit-lockstep`, `align-orbit-pins`, notas y convergencia); `M1-T-RP` (la
configuración de release-please del major: `release-as`/`linked-versions`)
no es inerte en 1.x y va dentro del PR de la ruta de cada repo; `extra-files`
y la anotación de `cmd/quark/go.mod` sí son inertes y van en `M1-T-Q`. Las
rutas de los comandos son relativas al
repo de la fila; `cd quantum` es `/Users/jcsv/GolandProjects/quantum`.
«Prosa 1.x» de la tabla anterior entra en el tamaño de cada `M1-R-*`.

| Sesión | Qué entrega | Precondición (comando) | Criterio de hecho (comando en verde) | Tamaño medido |
|---|---|---|---|---|
| `M1-V2-P` (quantum, **1.x**; tres PRs) | **(a)** los lectores de ruta leen el `module` de cada `go.mod` (o toleran `(/v[0-9]+)?`) en vez de componer la literal: `manifest-guard.sh` §5/§5b (`:247-264,:292-324`; FAIL cuando el sufijo de un `require` no es el del set), `manifest-modules.sh:75`, `print-requires.sh:50-65` + su self-check, `align-module-floors.sh:66,89` (y `--target <pseudo>` probado), `align-orbit-pins.sh:27,49` (lookup por `module`; descubre módulos de quark Y nucleus con `/vN`), `check_exit0_regressions.sh:114-128` (sufijo + `v2.0.0-00010101000000-000000000000`), `train.sh:617-620`, `merge-bot-pr.sh:131-139`, `untag-recipe.sh:9,34`, `site-pages.py:62,175-177,353,972,1004-1012`; fixtures: `umbrella-manifest-guard` (doctorado agnóstico `:52-58` + roturas «`go.mod` sufijado» y «tercer pin en la raíz de orbit»), `umbrella-generated-pages` (`go.mod` `/v2`), `orbit-internal-pins` (`:29-32` agnóstico). La sección fija de la guía «la ruta de módulo `/v2`» y su rotura en `umbrella-migration-guide` son de `M1-G-P`(a), que es quien reescribe el generador (y la única que depende de D33). Cumple la cláusula `bump-set` de D11: el tercer pin lo leen `align-orbit-pins.sh` (lookup por `module`, módulos de quark Y nucleus) y `manifest-guard` §5; `bump-set.sh` sólo descubre módulos por la presencia de `go.mod` (`:143`) y no compara pines. **(b)** §3 (`:138`) y §5 descubiertos desde `mm_keys orbit_modules` (QM-22 mitad quantum, QM-24; muerde hoy sobre `datasource` v1.30.1: va tras `V-S2b` → `M1-T-O`). **(c)** la lane `orbit-lockstep` (`integration.yml:262`) desde `gowork-patterns.sh` filtrado a `./orbit` sin `internal/`, y `go-install-tag` (`:120,133`) con la ruta leída del `go.mod` del submódulo. Compatible: al pin de 1.45.0 el bloque `require` no cambia | (a) `cd quantum && bash scripts/guard-of-guards.sh && bash scripts/manifest-guard.sh` (hace `git fetch --tags` en los submódulos: no es sólo lectura) y `bash scripts/print-requires.sh > $SCRATCH/requires-antes.txt` capturado antes. (b) (a) y `M1-T-O` fusionadas y `V-S2b` al pin: `cd quantum && grep -q -- '--nucleus-module' ../orbit/scripts/release/align_set.sh && test "$(grep -c 'github.com/jcsvwinston/quark ' scripts/print-requires.sh)" = 0 && test "$(awk '$1=="github.com/jcsvwinston/nucleus"{print $2}' orbit/datasource/go.mod)" = "$(awk '/^modules:/{f=1} f && /^  nucleus:/{gsub(/"/,"",$2); print $2; exit}' versions.yaml)"`. (c) (a) fusionada: el mismo `test … = 0` | (a) `cd quantum && bash scripts/guard-of-guards.sh && bash scripts/manifest-guard.sh && bash scripts/check_gowork_covers_manifest.sh && bash scripts/check_migration_guide.sh && bash scripts/check_generated_pages.sh && diff <(bash scripts/print-requires.sh) $SCRATCH/requires-antes.txt && test "$(grep -c 'github.com/jcsvwinston/quark ' scripts/print-requires.sh)" = 0`. (b) `cd quantum && bash scripts/manifest-guard.sh && test "$(grep -c 'for mod in proto agent server quarkbridge quarkdatasource' scripts/manifest-guard.sh)" = 0` (hoy la lista fija está en `:138`); QM-24 `hecho`. (c) `cd quantum && sed -n '/^  orbit-lockstep:/,/^  [a-z-]*:$/p' .github/workflows/integration.yml \| grep -q 'gowork-patterns.sh' && gh run list -R jcsvwinston/quantum --workflow integration.yml --branch <rama> --json conclusion --jq '.[0].conclusion' \| grep -x success` (hoy el job `orbit-lockstep`, `:254`, no usa `gowork-patterns.sh`: 0 líneas) | 10 scripts/workflows con 37 líneas literales + 2 que componen (`$OWNER/%s`) + 3 awk/printf de lógica; 1 generador (`site-pages.py` 1 380 l., 5 sitios); 3 fixtures; `integration.yml` 3 líneas |
| `M1-T-O` (orbit, **1.x; tras `V-S2b`**) | `align_set.sh`: `MODULE_ROOT` del `go.mod`, `MODULES` desde `.release-please-manifest.json` (entran `datasource` y `ui`; `internal/fleettest` por decisión), `want_for` con `(/v[0-9]+)?` y `--nucleus-module <path>=<ver>` (o `--module` genérico), fuera `DATASOURCE_EDGE_MODULE` (`:68,174-181`) y la cabecera «six modules»; `check_internal_pins.sh:24-25` desde el manifiesto y la **regla transitoria del major** (pin == `v<N+1>.0.0` mientras el último tag sea `v<N>.x` y el `go.mod` raíz lleve `/v<N+1>`); `link_unpublished_siblings.sh:37-60` con `/vN` y los `require` cruzados; `check_dependabot_floors.sh:117`; `.github/dependabot.yml` con `nucleus/*` y `orbit/v*`; un test de shell con `go.mod` de pega (raíz `/v2` + módulo 0.x sin sufijo). Cierra la mitad orbit de QM-22; prepara D11 (el tercer pin cabe en `want_for`) | `cd orbit && bash scripts/ci/check_internal_pins.sh && test "$(awk '$1=="github.com/jcsvwinston/nucleus"{print $2}' datasource/go.mod)" = v1.36.0` (`V-S2b` al pin: al meter `datasource` en `MODULES`, `--check` sólo es verde si su suelo ya está al set; hoy `datasource/go.mod:8` lleva v1.30.1) | `cd orbit && bash scripts/ci/check_internal_pins.sh && bash scripts/release/align_set.sh --manifest ../quantum/versions.yaml --check && bash scripts/ci/check_dependabot_floors.sh && bash scripts/ci/test_align_set.sh` (el test nuevo, con los dos `go.mod` de pega; `--check` ya verde, sin mirar al futuro) | 3 scripts (`align_set.sh` 248 l. ×4 sitios, `check_internal_pins.sh` 109 ×1, `link_unpublished_siblings.sh` ×1) + 1 (`check_dependabot_floors.sh`) + `dependabot.yml` (29 líneas) + 1 test nuevo; `datasource` entra en `MODULES` con su suelo ya al set (`V-S2b` → el tren de hoy corta `datasource/v1.1.3` y re-pina raíz, agent y quarkdatasource), así que `--check` es verde en `main` desde el primer día |
| `M1-T-N` (nucleus, **1.x**) | `release.yml:97-100` (awk con `(/v[0-9]+)?`) y `scripts/ci/test_release_awk.sh` (nuevo: ese awk sobre un `go.mod` de pega con `module …/cmd/nucleus/v2` y `require …/nucleus/v2 v2.0.0`); en el mismo job `tag-cli-module` (`release.yml:75-112`, que hoy sólo comprueba el suelo de la raíz), por cada `require github.com/jcsvwinston/nucleus/<dir> <ver>` de `cmd/nucleus/go.mod` (hoy los cinco drivers, `:9-13`; tras `M1-AS-N`, también `providers/tasks-asynq`) comprobar que el tag `<dir>/<ver>` existe en el commit —el vigilante de la trampa de seis módulos, que nadie escribe ni vigila—, con ese caso en `test_release_awk.sh`; `cli_workspace.sh:27,42`, `check_modules_standalone.sh:70` (y la salida NOTICE en el bucle de `providers/*` cuando `go mod download <raíz>@<suelo>` falla; FAIL si el floor sale vacío), `check_hello_size.sh:55-65`, `run_compatibility_harness.sh:135,145`, `test_with_engines.sh:78`, `scripts/website/check-coverage.sh`; `knownproviders.RepoModule` partido en `RootModule`/`SiblingModule` con un test que recorra el catálogo (`:306,:379,:430,:442,:459,:494,:578`); `routes.go:355` y `mountedit.go:44` aceptan `/vN`; `.goreleaser.yaml:22` estampa sobre un símbolo sin ruta (`-X main.version`, como orbit); `ci.yml:7-9` `pull_request: branches: [main, '<rama del major>/**']` (si D27 da una rama); la lane `suite-starter` (`ci.yml:759-791`) acepta un ref por hermano (variable; defecto «tag más alto»); `dependabot.yml:44` con `nucleus/*`; `ADR-032:53-54` sin tocar hasta la pregunta 3 | `gh run list -R jcsvwinston/nucleus --branch main --workflow ci.yml --limit 1 --json conclusion --jq '.[0].conclusion' \| grep -x success` | `cd nucleus && make check && go test ./internal/knownproviders/ -count=1 && bash scripts/ci/test_release_awk.sh` (el test del awk con un `go.mod` `/v2` de pega y el caso «cada `require` interno de `cmd/nucleus/go.mod` tiene su tag en el commit») `&& bash scripts/release/rehearse_rc.sh` con `dist/*/nucleus version` imprimiendo la versión del tag de ensayo | 9 ficheros / 23 menciones (+ `check-coverage.sh`); `release.yml` 1 paso más en `tag-cli-module`; `.goreleaser.yaml` 1 línea; `catalog.go` 22 sitios; `ci.yml` 2 bloques; `dependabot.yml` 1 |
| `M1-T-Q` (quark, **1.x**) | `release_asset_smoke.yml:157,189,218` («built against» sin la ruta literal, o leída del `go.mod`), `.goreleaser.yaml:41` → símbolo sin ruta, `cmd/quark/commands/version.go:16` (`libraryModule` casa `…/quark` y `…/quark/v2`), `ci.yml:6-7` `branches: [main, '<rama>/**']`, `ci.yml:338` y `link_workspace.sh:17` (comentarios), `dependabot.yml` ×10 con `quark/*`; **la anotación `// x-release-please-version` en `cmd/quark/go.mod` y `cmd/quark/go.mod` en `extra-files` del paquete raíz** de `release-please-config.json` (QK-72, mitad raíz: hoy requiere v1.19.0 con el set en v1.19.1; sin ella `cmd/quark/v2` no requeriría `quark/v2 v2.0.0` en su primer tag) | `gh workflow view 'Release Asset Smoke' -R jcsvwinston/quark` activo; `grep -c 'x-release-please-version' cmd/quark/go.mod` = 0 | `cd quark && goreleaser build --snapshot --single-target --clean && dist/*/quark version` imprime la versión y «built against … v1.19.1»; `gh workflow run release_asset_smoke.yml -R jcsvwinston/quark --ref main -f tag=v1.19.1` verde (lo lanza el propietario: escritura en GitHub); en el siguiente corte de quark `cmd/quark/go.mod` requiere la raíz del mismo tag | 1 workflow (3 sitios) + 2 comentarios + `.goreleaser.yaml` 1 + `version.go` 1 + `ci.yml` 1 + `dependabot.yml` 10 + `release-please-config.json` 1 + `cmd/quark/go.mod` 1 |
| `M1-T-P` (quantum, **1.x**) | El tren entiende `/vN` y lo ensaya: `tests/train-v2/selftest.sh` nuevo (tres hermanos de mentira con `go.mod` `/v2` y tags locales `v2.0.0` y `drivers/x/v2.0.0`; corre `align-module-floors --check`/`--dry-run`, `manifest-guard`, `print-requires`, `bump-set --sin-notas`, `site-pages`) registrado en `integration.yml` junto a `train-rutas` (`:81`) y `train-dry-run` (`:89`); `train.sh --sin-dispatch` (el anuncio a quantum-app muere por diseño en el 2.0.0); `orbit-align-notes.sh:46` con la arista invertida; `orbit-converge.sh` con la raíz convergiendo tras cada tag de `quarkdatasource`; QM-23 (`align-orbit-pins --check` mira los pines internos), QM-40 (`fase_repo` comprueba releasables); paso del runbook «`release_asset_smoke` por `workflow_dispatch` tras cada corte»; **sin segunda pasada de suelos ni segundo tag del CLI** (D35, 2026-11-16, contra la recomendación): el lag de los drivers en `cmd/quark`/`cmd/nucleus` se declara en `declared_lags` de `versions.yaml` (hoy sólo conoce lags cross-repo de orbit y está vacío: `manifest-guard` §5 y `suite-integral` tienen que aprender la forma intra-repo y la lane certificar con ellos declarados) y la guía de migración lo dice | `cd quantum && test "$(grep -c 'github.com/jcsvwinston/quark ' scripts/print-requires.sh)" = 0` (`M1-V2-P` fusionada) `&& grep -q -- '--nucleus-module' ../orbit/scripts/release/align_set.sh && grep -qE '^[\|] \*\*D35\*\* [\|][^\|]*[\|][^\|]*[\|] \*\*[^\|]*202[67]-[0-9]{2}-[0-9]{2}' docs/planes/quantum-2.0.md` (`M1-T-O` fusionada; D35 decidida el 2026-11-16: el lag declarado) | `cd quantum && bash tests/train-v2/selftest.sh && bash tests/train-rutas/selftest.sh && bash tests/train-dry-run/selftest.sh && bash scripts/train/train.sh --dry-run` (exige `../orbit` en `main` limpio y `gh` con red: `align-orbit-pins.sh:53-57`) | 3 scripts del tren (`align-module-floors.sh` 185 l., `align-orbit-pins.sh` 63, `train.sh` 1 477: 5 sitios + el flag), 2 scripts de notas/convergencia, 1 workflow (2 líneas), 1 selftest nuevo (a imagen de `train-rutas`, 232 l.) |
| `M1-T-LINT-Q` (quark, **1.x; D28 primero**) | El lint del `!` que ADR-032 regla 2 promete, en quark: `scripts/ci/check_pr_title_english.sh` (o un guard `quark-pr-title-major`) rechaza `!` y `BREAKING CHANGE` en título Y cuerpo salvo rama base `<rama del major>/*` (`GITHUB_BASE_REF`, la variable que Actions da a los `pull_request`) o etiqueta `major`. Alternativa: corregir ADR-032:53-54 (nucleus) y no construirlo | D28 (pregunta 3) rellena: `grep -qE '^[\|] \*\*D28\*\* [\|][^\|]*[\|][^\|]*[\|] \*\*[^\|]*202[67]-[0-9]{2}-[0-9]{2}' ../quantum/docs/planes/quantum-2.0.md`; `cd quark && bash scripts/ci/check_pr_title_english.sh 'feat(x): y'` → exit 0 (hoy el script sólo mira el idioma: `:9-14`) | `cd quark && ! bash scripts/ci/check_pr_title_english.sh 'feat(x)!: y' && GITHUB_BASE_REF='<rama del major>' bash scripts/ci/check_pr_title_english.sh 'feat(x)!: y' && bash scripts/ci/check_pr_title_english.sh 'feat(x): y'` | 1 script |
| `M1-T-LINT-N` (nucleus, **1.x**) | lo mismo sobre `nucleus/scripts/ci/check_pr_title_english.sh`, y ADR-032:53-54 pasa de «promete» a «existe» | D28 rellena: `grep -qE '^[\|] \*\*D28\*\* [\|][^\|]*[\|][^\|]*[\|] \*\*[^\|]*202[67]-[0-9]{2}-[0-9]{2}' ../quantum/docs/planes/quantum-2.0.md`; `cd nucleus && bash scripts/ci/check_pr_title_english.sh 'feat(x): y'` → exit 0 | `cd nucleus && ! bash scripts/ci/check_pr_title_english.sh 'feat(x)!: y' && GITHUB_BASE_REF='<rama del major>' bash scripts/ci/check_pr_title_english.sh 'feat(x)!: y' && make guards` | 1 script + ADR-032 (2 líneas) |
| `M1-T-LINT-O` (orbit, **1.x**) | lo mismo sobre `orbit/scripts/ci/check_pr_title_english.sh` | D28 rellena: `grep -qE '^[\|] \*\*D28\*\* [\|][^\|]*[\|][^\|]*[\|] \*\*[^\|]*202[67]-[0-9]{2}-[0-9]{2}' ../quantum/docs/planes/quantum-2.0.md`; `cd orbit && bash scripts/ci/check_pr_title_english.sh 'feat(x): y'` → exit 0 | `cd orbit && ! bash scripts/ci/check_pr_title_english.sh 'feat(x)!: y' && GITHUB_BASE_REF='<rama del major>' bash scripts/ci/check_pr_title_english.sh 'feat(x)!: y'` | 1 script |
| `M1-T-LINT-P` (quantum, **1.x; tras las tres**) | tres fixtures `<repo>-pr-title-major` en `tests/guard-fixtures` (rotura doctorada: un `feat(x)!: …` contra `main` que el script deja pasar) registradas en `guard-registry.sh` | las tres fusionadas: `cd quantum && for r in quark nucleus orbit; do grep -q 'BREAKING' ../$r/scripts/ci/check_pr_title_english.sh \|\| exit 1; done` | `cd quantum && bash scripts/guard-of-guards.sh && (source scripts/lib/guard-registry.sh; for g in quark-pr-title-major nucleus-pr-title-major orbit-pr-title-major; do guard_names \| grep -qx $g \|\| exit 1; done)` | 3 fixtures + 3 entradas en `guard-registry.sh` |
| `M1-G-P` (quantum, **1.x, antes del set posterior al 2026-12-08**; dos PRs) | **(a)** `migration-guide.py`: selecciona los avisos cuya versión de ventana es `v2.0.0` sea cual sea su `Status`; rinde el estado por entrada: «removed/changed at v2.0.0» sólo cuando la línea `- Status:` lleva la marca de aplicación `(applied on <rama del major>, YYYY-MM-DD; the v2.0.0 tag publishes it)` —la forma que nucleus ya usa en `dry-run/2.0` en sus 18 avisos con ventana—, y «not before …» con `active` o con `completed` a secas (el volteo por vencimiento de la regla D2 de `POLITICA_DEPRECACION.md` §4, l.139); esa forma queda declarada en el generador y en `POLITICA_DEPRECACION.md` §4; `check_deprecations.sh:339` ya la lee (toma la palabra entre acentos: nucleus DEP-007 lleva paréntesis al pin) y la fixture `umbrella-deprecations` la pina; la sección fija «la ruta de módulo `/v2`» (`go get …/v2@v2.0.0`, el `sed` de imports, «`go get …@latest` sigue en v1.19.x» y lo que D33 decida del último tag v1) con su rotura en `umbrella-migration-guide`; «Before / after» del bloque del aviso, de las viñetas `Now (v1)`/`At 2.0` (quark, orbit) o del `## Rewrite` del `MA-*` citado en `Assistant spec:` (nucleus); «Exit in 1.x»; sin `QADR-0002` en su texto propio (`:103`); `--check` con recuento por campo (entradas sin antes/después o sin salida = 0); fixture del guard con un aviso `completed` que la guía debe seguir listando; `docs/planes/guia-migracion-2.0.md` regenerada. **(b)** la salida publicable `website/docs/migrating-to-2.0.md` (instancia `start`, front-matter; o una por producto: D34, pregunta 9), `sidebarsStart.ts` («Migration guides»), el enlace en `src/pages/index.tsx:105-123`, control `ST-13` en `tests/sitebench/sitebench.sh` y `check_site_posture.sh:46,49` 12 → 13; `check_migration_guide.sh` lee las dos salidas | (a) `cd quantum && python3 scripts/lib/migration-guide.py --root . --out docs/planes/guia-migracion-2.0.md --check` EXIT 0 `&& test "$(grep -c '^### DEP' docs/planes/guia-migracion-2.0.md)" = 34` y D33 (pregunta 8: el último tag v1, lo que la sección fija dice) rellena: `grep -qE '^[\|] \*\*D33\*\* [\|][^\|]*[\|][^\|]*[\|] \*\*[^\|]*202[67]-[0-9]{2}-[0-9]{2}' docs/planes/quantum-2.0.md`. (b) (a) fusionada y D34 (pregunta 9: dónde se publica) rellena: `cd quantum && grep -qE '^[\|] \*\*D34\*\* [\|][^\|]*[\|][^\|]*[\|] \*\*[^\|]*202[67]-[0-9]{2}-[0-9]{2}' docs/planes/quantum-2.0.md && grep -q 'completed' tests/guard-fixtures/umbrella-migration-guide/fixture.sh` (hoy 0: la fixture del aviso `completed` la trae (a)) | (a) `cd quantum && bash scripts/check_migration_guide.sh && bash scripts/guard-of-guards.sh && test "$(grep -c '^### DEP' docs/planes/guia-migracion-2.0.md)" = 34 && test "$(grep -oE 'QADR-[0-9]+' docs/planes/guia-migracion-2.0.md \| wc -l)" = 0 && grep -q 'github.com/jcsvwinston/quark/v2' docs/planes/guia-migracion-2.0.md` (la sección fija de la ruta: hoy `grep -c '/v2' docs/planes/guia-migracion-2.0.md` → 0; las 14 `ADR-` de los avisos las quitan `M1-G-Q/N/O`). (b) `cd quantum && bash scripts/check_sidebar_sync.sh && bash scripts/check_site_posture.sh && test -f website/docs/migrating-to-2.0.md && bash scripts/check_migration_guide.sh`; la lane `website-ci` verde en el PR (`npm run build` no corre en el sandbox) | generador 159 l. (+2 campos, +1 selector, +1 sección fija, +1 salida); guía 2 703 l.; 1 página nueva; `sidebarsStart.ts` 1 entrada; `index.tsx` 1 enlace; `check_migration_guide.sh` 57 l. + fixture; `sitebench.sh` 1 control; `check_site_posture.sh` 2 literales |
| `M1-G-Q` / `M1-G-N` / `M1-G-O` (docs de avisos, **1.x**, uno por producto) | Las correcciones de la columna «Aviso a corregir» de la tabla de las 34 filas; las 14 menciones `ADR-`/`QADR-` fuera de los avisos; quark: viñetas `Now (v1)`/`At 2.0` en los 2 que no las llevan, DEP-006 retitulada, DEP-001 sin crónica; nucleus: «## What breaks if this is ignored» en `docs/governance/DEPRECATION_TEMPLATE.md` (la plantilla no vive en `docs/deprecations/`, que sólo tiene `README.md` y los `DEP-*.md`; `docs/deprecations/README.md:11` la apunta ahí) y en los 18 activos de `docs/deprecations/`, DEP-024/025/011/014 (la 014 según D31, pregunta 6), DEP-019/020/023/009 con la ruta `/v2` (o remitiendo a la sección fija); orbit: DEP-002 (`agent.Config.Registry`/`Databases`, «the one place» → 24 ficheros, `datasource` sin nucleus) y `docs/deprecations/README.md`; quark DEP-004 l.74-75. Las tres correcciones que amplían lo que un aviso publicado dice que rompe (DEP-025 l.54, DEP-024 `hooks.NewSQLObserver`, orbit DEP-002 `agent.Config.Registry`/`Databases`) se escriben como D29 (pregunta 4) decida: con la fecha de la corrección y «comparte la ventana del aviso que retira sus tipos» (a), o como aviso propio con ventana nueva (b). Sólo docs: viaja con el siguiente `feat`/`fix` de cada producto | `cd quantum && bash scripts/check_deprecations.sh` sin FAIL; `M1-G-N` y `M1-G-O`: D29 rellena, `cd quantum && grep -qE '^[\|] \*\*D29\*\* [\|][^\|]*[\|][^\|]*[\|] \*\*[^\|]*202[67]-[0-9]{2}-[0-9]{2}' docs/planes/quantum-2.0.md`; `M1-G-N`: también D31 (DEP-014), `grep -qE '^[\|] \*\*D31\*\* [\|][^\|]*[\|][^\|]*[\|] \*\*[^\|]*202[67]-[0-9]{2}-[0-9]{2}' docs/planes/quantum-2.0.md` | `test "$(grep -lE '(Q?ADR)-[0-9]+' docs/deprecations/DEP-*.md \| wc -l)" = 0` en cada repo; nucleus: `test "$(grep -L '^## What breaks if this is ignored' docs/deprecations/DEP-2026-0{03,09,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26}-*.md \| wc -l)" = 0`; `cd quantum && bash scripts/check_deprecations.sh` sin FAIL al pin que los traiga y `python3 scripts/lib/migration-guide.py … --check` con 0 huecos por campo (tras `M1-G-P`) | quark 11 avisos (2 sin viñetas, 1 título, 1 crónica, l.74-75); nucleus 18 avisos + plantilla (+ `MA-2026-020`); orbit 5 avisos + README; 14 líneas `ADR-` |
| `M1-G-F1` (quark, **1.x, docs; el 2026-12-08 o después**) | DEP-2026-001/002 → `Status: completed` a secas (vencidas: regla D2 de `POLITICA_DEPRECACION.md` §4, l.139; sin la marca `(applied on`, que es de `M1-R-Q1`); viaja con el siguiente `feat`/`fix` de quark (`docs:` oculto en release-please); el guard avisa con los días vencidos y no rompe, y la guía los sigue listando desde `M1-G-P`(a) | `test "$(date +%F \| tr -d -)" -ge 20261208` `&& cd quark && test "$(grep -l '^- Status: .active.' docs/deprecations/DEP-2026-00{1,2}-*.md \| wc -l)" = 2` | `cd quark && test "$(grep -lE '^- Status: .completed.$' docs/deprecations/DEP-2026-00{1,2}-*.md \| wc -l)" = 2 && cd ../quantum && bash scripts/check_deprecations.sh` sin FAIL (al pin que lo traiga) | 2 avisos, 1 línea cada uno |
| `M1-G-F2` (nucleus, **1.x, docs; el 2027-01-04 o después**) | DEP-2026-011…018 (vencen el 2027-01-02) y DEP-2026-009 (2027-01-04) → `Status: completed` a secas, un PR para las nueve; viaja con el siguiente `feat`/`fix` de nucleus | `test "$(date +%F \| tr -d -)" -ge 20270104` `&& cd nucleus && test "$(grep -l '^- Status: .active.' docs/deprecations/DEP-2026-0{09,11,12,13,14,15,16,17,18}-*.md \| wc -l)" = 9` | `cd nucleus && test "$(grep -lE '^- Status: .completed.$' docs/deprecations/DEP-2026-0{09,11,12,13,14,15,16,17,18}-*.md \| wc -l)" = 9 && cd ../quantum && bash scripts/check_deprecations.sh` sin FAIL | 9 avisos, 1 línea cada uno |
| `M1-G-F3` (quark, **1.x, docs; el 2027-01-04 o después**) | DEP-2026-003 → `Status: completed` a secas (`no earlier than 2027-01-04`, la tercera fecha de quark); viaja con el siguiente `feat`/`fix` de quark | `test "$(date +%F \| tr -d -)" -ge 20270104` `&& cd quark && grep -q '^- Status: .active.' docs/deprecations/DEP-2026-003-*.md` | `cd quark && grep -qE '^- Status: .completed.$' docs/deprecations/DEP-2026-003-*.md && cd ../quantum && bash scripts/check_deprecations.sh` sin FAIL | 1 aviso, 1 línea |
| `M1-G-F4` (nucleus, **1.x, docs; el 2027-01-17 o después**) | DEP-2026-003 y DEP-2026-019…026 → `Status: completed` a secas (nueve); viaja con el siguiente `feat`/`fix` de nucleus | `test "$(date +%F \| tr -d -)" -ge 20270117` `&& cd nucleus && test "$(grep -l '^- Status: .active.' docs/deprecations/DEP-2026-0{03,19,20,21,22,23,24,25,26}-*.md \| wc -l)" = 9` | `cd nucleus && test "$(grep -lE '^- Status: .completed.$' docs/deprecations/DEP-2026-0{03,19,20,21,22,23,24,25,26}-*.md \| wc -l)" = 9 && cd ../quantum && bash scripts/check_deprecations.sh` sin FAIL | 9 avisos, 1 línea cada uno |
| `M1-G-F5` (orbit, **1.x, docs; el 2027-01-17 o después**) | DEP-2026-001/002 → `Status: completed` a secas; viaja con el siguiente `feat`/`fix` de orbit. Quark 004…011 y orbit 003…005 vencen el 2027-02-07, el suelo del 2.0.0: si ese día el major no está cortado, dos PRs más con la misma forma (sin fila: hoy no se sabe si existirán) | `test "$(date +%F \| tr -d -)" -ge 20270117` `&& cd orbit && test "$(grep -l '^- Status: .active.' docs/deprecations/DEP-2026-00{1,2}-*.md \| wc -l)" = 2` | `cd orbit && test "$(grep -lE '^- Status: .completed.$' docs/deprecations/DEP-2026-00{1,2}-*.md \| wc -l)" = 2 && cd ../quantum && bash scripts/check_deprecations.sh` sin FAIL | 2 avisos, 1 línea cada uno |
| `M1-V2-Q` (quark; **primer commit del major**; dos PRs: el renombrado y la pseudo-versión) | **(1)** `go mod edit -module github.com/jcsvwinston/quark/v2` en la raíz y `…/quark/<dir>/v2` en los 12 anidados (§3.5: todos); `require` y los 17 `replace` reescritos; `sed` de las 800 líneas de import + revisión de los 32 ficheros con literales fuera de `import` (`migrate.go:412,425,435`, `otel.go:37-38` —decisión del nombre de scope—, `known.go:33-37`, `events.go:180-182`, `emit.go:197`, `init.go:352,357`, `migrate.go:49`, `gen-apisurface`, `gen-allowlist` ×7 claves, `acceptance/exercise` ×4, `version.go:16`); `cmd/quark/go.mod` requiere `…/quark/v2 v2.0.0` por la anotación (`M1-T-Q`); `notes.proto:10` + `.pb.go` regenerado; `make regen` (`apisurface.json` 956, `allowlist.json` 581); 13 `.tmpl` de `quark init --with`; 79 páginas (47 md + 32 mdx) y 13 `go install`; `dependabot.yml` con `quark/v2` ×10; título del squash `feat!:` + footer `Release-As: 2.0.0` (pregunta 1) + 6 `package-name` con `/v2`. **(2)** los `go.mod` anidados requieren la pseudo-versión `v2.0.0-<ts>-<sha>` del primero (lo que las lanes `GOWORK=off` necesitan hasta el tag) | último set 1.x certificado con quark al pin y sin filas pendientes: `cd quantum && bash scripts/check_deprecations.sh` sin FAIL `&& test "$(git -C ../quark describe --tags --abbrev=0 --match 'v[0-9]*')" = "$(awk '/^modules:/{f=1} f && /^  quark:/{gsub(/"/,"",$2); print $2; exit}' versions.yaml)"` (`versions.yaml:20-21`; `yaml_value` sólo existe dentro de `manifest-guard.sh:72` y `check_release_assets.sh:67`, no en una lib); `M1-T-Q` y `M1-V2-P` fusionadas: `test "$(grep -c 'x-release-please-version' ../quark/cmd/quark/go.mod)" = 1 && test "$(grep -c 'github.com/jcsvwinston/quark ' scripts/print-requires.sh)" = 0`; D26 (pregunta 1) y D27 (pregunta 2) rellenas, desde `cd quantum`: `grep -qE '^[\|] \*\*D26\*\* [\|][^\|]*[\|][^\|]*[\|] \*\*[^\|]*202[67]-[0-9]{2}-[0-9]{2}' docs/planes/quantum-2.0.md && grep -qE '^[\|] \*\*D27\*\* [\|][^\|]*[\|][^\|]*[\|] \*\*[^\|]*202[67]-[0-9]{2}-[0-9]{2}' docs/planes/quantum-2.0.md` | (1) `cd quark && make workspace && for m in . cmd/quark drivers/mssql drivers/mysql drivers/oracle drivers/postgres drivers/sqlite internal/enginesuite acceptance; do (cd $m && go build ./... && go vet ./... && go test ./...) \|\| exit 1; done && for m in benchmarks bugbash internal/integrations internal/drivertemplate; do (cd $m && GOWORK=off go build ./... && go vet ./...) \|\| exit 1; done && test "$(grep -c '^module github.com/jcsvwinston/quark/v2$' go.mod)" = 1 && test "$(git ls-files '*.go' \| xargs grep -hoE '"github.com/jcsvwinston/quark[^"]*"' \| grep -vc '/v2')" = 0 && make regen && git diff --quiet acceptance/ && goreleaser build --snapshot --single-target --clean && dist/*/quark version` sin «(devel)». (2) `for m in <12 anidados>; do (cd $m && GOWORK=off go build ./... && go test ./...) \|\| exit 1; done` contra el proxy | 13 `go.mod` (1 `module` + 46 `require`/`replace`); 408 ficheros `.go` / 800 líneas + 32 ficheros / 77 literales; 122 no-Go (1 537 regeneradas; 361 de `CHANGELOG` no se tocan); 13 `.tmpl`; 79 páginas; 13 `go install`; `dependabot.yml` 10 |
| `M1-V2-N` (nucleus; **primer commit del major**; dos PRs) | **(1)** `module …/nucleus/v2` en la raíz, `…/nucleus/cmd/nucleus/v2` en la CLI (lockstep por `release.yml`) y `…/nucleus/<dir>/v2` en los otros 17 (`internal/testdeps` incluido; 1 `require` en una línea en `providers/tasks-asynq/go.mod`: la forma de quantum#318); `sed` de 1 073 líneas + 54 ficheros con 154 literales (`testredis.go:256,261`, `catalog.go:436,501`, `factory.go:73`, 5 tests de `internal/cli` con `replace`); 11 `.tmpl` / 29 líneas; 36 ficheros no-test de `internal/cli` (86 líneas) + 53 tests; `modules.json` sin `Target()` con versión hasta el corte (o 2.0.0 a mano); `.golden`; baseline regenerado (`NUCLEUS_UPDATE_CONTRACT_BASELINE=1 go test ./contracts/`, 2 525 líneas); `quarkmake/go.mod` requiere `quark/v2` (pseudo-versión de `M1-V2-Q`); 10 `go install`; DEP-019/020/023/009 y MA-020 con la ruta si `M1-G-N` no lo hizo; `dependabot.yml` ×3 (`:44,:57,:58`; la `:58` ya tolera el comodín); `feat!:` + footer `Release-As: 2.0.0` + 16 `package-name`. **(2)** pseudo-versión en los 17 `go.mod` anidados | `M1-V2-Q` (1) y (2) fusionadas: `git -C ../quark show origin/<rama del major>:go.mod \| grep -q '^module github.com/jcsvwinston/quark/v2$' && git -C ../quark show origin/<rama del major>:drivers/sqlite/go.mod \| grep -qE 'jcsvwinston/quark/v2 v2\.0\.0-'` (`<rama del major>` = la que fije D27, pregunta 2; `main` si la respuesta es (b): con la rama `major/2.0` la ruta `/v2` de quark no llega a `main` hasta el merge final del tren); `M1-T-N` fusionada: `grep -q 'v\[0-9\]' .github/workflows/release.yml` (el awk tolerante); D9/D10 publicados (lo están en 1.45.0); D27 rellena: `grep -qE '^[\|] \*\*D27\*\* [\|][^\|]*[\|][^\|]*[\|] \*\*[^\|]*202[67]-[0-9]{2}-[0-9]{2}' ../quantum/docs/planes/quantum-2.0.md` | (1) `cd nucleus && make workspace && go build ./... && go vet ./... && go test ./... && (cd cmd/nucleus && go build ./... && go test ./...) && (cd pkg/nucleustest/quarkmake && go test ./...) && test "$(grep -c '^module github.com/jcsvwinston/nucleus/v2$' go.mod)" = 1 && test "$(grep -c '^module github.com/jcsvwinston/nucleus/cmd/nucleus/v2$' cmd/nucleus/go.mod)" = 1 && t=$(mktemp -d) && go run ./cmd/nucleus new --template api $t/app && grep -q 'github.com/jcsvwinston/nucleus/v2' $t/app/go.mod && go test ./internal/cli/ -run 'TestRunNewAPIWithGeneratedModuleBoots\|TestNewSuite' -count=1 && go test ./contracts/ && bash scripts/release/generate_compatibility_report.sh --enforce-threshold && bash scripts/release/rehearse_rc.sh` (el binario de ensayo imprime la versión). (2) `bash scripts/ci/check_modules_standalone.sh` con las lanes de `providers/*` en verde (no NOTICE) | 19 `go.mod` (2 `module` + 24 `require`/`replace`); 495 ficheros `.go` / 1 073 líneas + 54 / 154 literales; 11 `.tmpl` / 29; 89 ficheros de `internal/cli` / 304 líneas; 161 no-Go (2 525 regeneradas; 323+ de `CHANGELOG`s no se tocan); 10 `go install`; `dependabot.yml` 3 |
| `M1-V2-O` (orbit; **primer commit del major**; dos PRs) | **(1)** `module …/orbit/v2` en la raíz y `…/orbit/<dir>/v2` en los 8 anidados (`internal/fleettest` incluido); `sed` de 283 líneas propias + 363 cruzadas en 164 ficheros; 13 `require` propios + 20 cruzados (nucleus/v2, quark/v2 y sus drivers, con las pseudo-versiones de `M1-V2-N`/`M1-V2-Q`); `management.go:129,158,164`; `admin.proto:18` `go_package` + `admin.pb.go` regenerado (buf/protoc); el `go.work` rastreado no necesita `replace`; baseline (174 líneas, `ORBIT_UPDATE_CONTRACT_BASELINE=1`); 9 `go install`; `dependabot.yml` ×29; `feat!:` + footer `Release-As: 2.0.0` + 7 `package-name`. `ui/src` no cambia (el `module` de `ui/go.mod` sí). **(2)** pseudo-versiones en los 8 anidados | `M1-V2-N` (1) y (2): `git -C ../nucleus show origin/<rama del major>:go.mod \| grep -q '^module github.com/jcsvwinston/nucleus/v2$' && git -C ../nucleus show origin/<rama del major>:drivers/sqlite/go.mod \| grep -qE 'nucleus/v2 v2\.0\.0-'` (`<rama del major>` como en `M1-V2-N`); `M1-T-O` fusionada: `grep -q -- '--nucleus-module' scripts/release/align_set.sh`; D27 rellena: `grep -qE '^[\|] \*\*D27\*\* [\|][^\|]*[\|][^\|]*[\|] \*\*[^\|]*202[67]-[0-9]{2}-[0-9]{2}' ../quantum/docs/planes/quantum-2.0.md` | (1) `cd orbit && go build ./... && go vet ./... && go test ./... && bash scripts/ci/check_internal_pins.sh && test "$(grep -c '^module github.com/jcsvwinston/orbit/v2$' go.mod)" = 1 && test "$(git ls-files '*.go' \| xargs grep -hoE '"github.com/jcsvwinston/(nucleus\|quark\|orbit)[^"]*"' \| grep -vc '/v2')" = 0 && git diff --quiet -- go.work.sum` (OR-138: `go test` lo ensucia; `GOWORK=off` donde sea posible). (2) `for m in . agent server proto datasource quarkbridge quarkdatasource ui internal/fleettest; do (cd $m && GOWORK=off go build ./... && go vet ./...) \|\| exit 1; done`; `GOWORK=off go list -m all \| grep -c jcsvwinston/quark` registrado en el PR | 9 `go.mod` (1 `module` + 13 propios + 20 cruzados); 164 ficheros / 283 + 363 líneas + 6 / 9 literales; 54 no-Go (931 de `CHANGELOG`s no se tocan; 174 regeneradas); 9 `go install`; `dependabot.yml` 29; 1 `.proto` |
| `M1-R-Q1` (quark; filas 1, 2) | Retira el alias `RowLevelSecurity` (`tenant_router.go`) y el contrato viejo de listeners (`quarkdriver/listener.go`); regenera `acceptance/apisurface.json` y `allowlist.json` (`gen-allowlist` cambia de forma); DEP-2026-001/002 → `Status: removed (applied on <rama del major>, YYYY-MM-DD; the v2.0.0 tag publishes it)` (la forma de nucleus en la rama; parten de `completed` a secas desde `M1-G-F1`, 2026-12-08, no de `active`) y `CHANGELOG` | `cd quark && grep -q '^module github.com/jcsvwinston/quark/v2$' go.mod && go build ./... && cd ../quantum && bash scripts/check_deprecations.sh` sin FAIL | `cd quark && make lint && make docs-guards && make regen && git diff --exit-code acceptance/ && go test ./... && test "$(grep -rn 'RowLevelSecurity\|NewListenerFunc' --include='*.go' . \| grep -vc _test.go)" = 0 && test "$(grep -lE '^- Status: .removed.*\(applied on' docs/deprecations/DEP-2026-00{1,2}-*.md \| wc -l)" = 2` | 17 ficheros (7 `.go`) de la rama; 3 a rehacer; 5 marcas; prosa 1.x: 2 ficheros |
| `M1-R-Q2` (quark; filas 3, 4, 5, 6) | `UpdateBatch` comprueba versiones por defecto, todas las escrituras versionadas entran en el bloqueo optimista, una escritura de 0 filas no dispara hooks/auditoría/eventos, `Upsert` igual en los seis motores (sin `updateCols`; duplicado en otra clave única; `UpsertBatch` fila a fila con modelo versionado); `query-bench.md` a mano y `enterprise-bench.md` regenerado; DEP-2026-003…006 → `completed` | `cd quark && grep -qE '^- Status: .completed.* \(applied on' docs/deprecations/DEP-2026-007-*.md` (la marca de aplicación, no el volteo por vencimiento; `M1-R-Q4` fusionada, y con ella `M1-R-Q1`: Q4 ∩ Q2 = `docs/enterprise-bench.md`, `internal/enginesuite/suite_test.go`, `website/docs/guides/modeling.mdx` por `comm -12` de los grupos; `query_builder.go` no está en el grupo Q1) `&& go test ./...` | `cd quark && go test ./... && (cd internal/enginesuite && go vet -tags=integration ./...) && make test-all` (con `QUARK_TEST_{POSTGRES,MYSQL,MARIADB,MSSQL,ORACLE}_DSN` exportados; Oracle con `make oracle-up`) `&& make superapp && QUARK_BENCH_TABLE=1 go test ./internal/enterprisebench/ -run TestEnterpriseBenchTable && git diff --exit-code docs/enterprise-bench.md && go test ./internal/enginesuite/ -run TestQueryBench` | 40 ficheros (31 `.go`) de la rama; **13 a rehacer** (`query_builder.go`, `query_crud.go`, `errors.go`, `dialect.go`, `quarkdriver/dialect.go`, `soft_delete.go`, `upsert_tenant.go`, `query-builder.md`, 5 mdx); prosa 1.x: 15 ficheros; cierra QK-45, QK-58, QK-46, QK-59, QK-65 |
| `M1-R-Q3` (quark; filas 8, 9) | `GroupBy` sin `Select` es `ErrInvalidQuery` (valida identificadores antes; `Paginate` manda su `COUNT` antes de rehusar) y el `LIKE` plano declara `ESCAPE '\'` en todos los motores en las puertas que toman operador (`Where`, `Or`, `WhereNot`, `Having`, `HavingAggregate`, `TypedStringColumn.Like/NotLike`, `Cmp`, `WhereLike`/`WhereNotLike`/`LikeEscaped`/`NotLikeEscaped`); las dos consultas del banco pasan a tipadas (60 de 60); DEP-2026-008/009 → `completed` | `cd quark && grep -qE '^- Status: .completed.* \(applied on' docs/deprecations/DEP-2026-003-*.md` (vencida desde el 2027-01-04 por `M1-G-F3`: sólo la marca distingue; `M1-R-Q2` fusionada: comparte `query_builder.go`) | `cd quark && go test ./... && make test-all && make superapp && QUARK_BENCH_TABLE=1 go test ./internal/enterprisebench/ -run TestEnterpriseBenchTable && git diff --exit-code docs/enterprise-bench.md && go test ./internal/enginesuite/ -run TestQueryBench` (60 typed · 0 wrong-sql; las sondas LIKE-01/02/05 reverdictan, no abortan) | 23 ficheros (14 `.go`); 3 a rehacer; prosa 1.x: 10 ficheros; cierra QK-24, QK-32 |
| `M1-R-Q4` (quark; filas 7, 10, 31) | `SET DEFAULT` rehusado en MySQL/MariaDB antes de enviar (`dialect_schema.go`, `migrate_execute.go`, `migrator.go`, `quarkdriver/schema.go`), `VARCHAR2(n CHAR)` en Oracle (`migrate_diff.go`, `dialect_introspection.go` lee `CHAR_USED`, `internal/migrate`), y una directiva de `pkg/model` en un tag `db` pasa de WARN a `ErrInvalidTag` (`internal/schema/schema.go`, `errors.go`, `migrator.go`, `audit.go`, `client_registry.go`; `literal_column` ya en `main`; `TestDirectiveShapedColumnNameWarnsAndMigratesInV1` renombrado y volteado); DEP-2026-007/010/011 → `completed` | `cd quark && grep -qE '^- Status: .removed.* \(applied on' docs/deprecations/DEP-2026-001-*.md && go test ./internal/migrate/...` (`M1-R-Q1` fusionada: Q1 ∩ Q4 = `acceptance/apisurface.json`, `acceptance/allowlist.json`, `docs/playbooks/dialects.md` por `comm -12` de los grupos; los dos regeneran `acceptance/`) | `cd quark && go test ./... && go test -run 'TestDirectiveShapedColumnName\|TestLiteralColumn' . && make test-all` (MySQL, MariaDB, Oracle: `on_delete_set_default_test.go` en `internal/enginesuite`, `oracle_varchar2_char_test.go` en `internal/migrate`) `&& make regen && git diff --exit-code acceptance/` | 29 ficheros (20 `.go`) + 5 `.go` de `main` para la fila 31 (18 ficheros en quark#476); 3 a rehacer; prosa 1.x: 14 ficheros; cierra QK-60, QK-50, QK-76 |
| `M1-R-N1` (nucleus; filas 11, 12, 13, 25) | Retira `Context.HTML(code, html)`, `Context.Get/Set` sin tipo (test que pina que `c.Set` compila por la promoción de `router.Context.Set`), los cuatro constructores que paniquean y `NewWrapResponseWriter`; baseline regenerado; patrones nuevos en `scripts/ci/check_retired_claims.sh` para lo retirado; DEP-2026-009/011/012/023 → `removed` con la marca `(applied on <rama del major>, YYYY-MM-DD; the v2.0.0 tag publishes it)`, la forma de nucleus en la rama: todas las `M1-R-*` la escriben y el volteo por vencimiento (`M1-G-F*`) no la lleva, así que `grep '(applied on'` distingue aplicar de vencer. Orbit no usa ninguno (0: ya comprobado) | `cd nucleus && grep -q '^module github.com/jcsvwinston/nucleus/v2$' go.mod && make vet && cd ../quantum && bash scripts/check_deprecations.sh` sin FAIL | `cd nucleus && NUCLEUS_UPDATE_CONTRACT_BASELINE=1 go test ./contracts/ -run APIExportedSymbols && go test ./contracts/ && make vet && make guards && go test ./... && test "$(grep -rn 'NewWrapResponseWriter\|func (c \*Context) HTML(' --include='*.go' pkg \| grep -vc _test.go)" = 0` (68 paquetes: `go list ./... \| wc -l`) | 58 ficheros (44 `.go`); 6 a rehacer; 8 marcas; prosa 1.x: 22 ficheros |
| `M1-R-N2` (nucleus; filas 14…19) | Una aplicación `WithoutDefaults()` rehúsa arrancar con `storage`/`mail_driver`/`rate_limit_*`/authz/`profiling_enabled` sin su opción (`pkg/app` `config.go`, `extensions.go`, `pkg/nucleus/nucleus.go`, `doctor`), y los plugins externos fuera de `plugins.allowed` se deniegan (`pkg/plugins/policy.go`, `pkg/app/plugins_config.go`, `internal/cli` `external.go`/`plugincommands.go`; con o sin sondeo según D31, pregunta 6); DEP-2026-013…018 → `completed` | `cd nucleus && grep -qE '^- Status: .removed.* \(applied on' docs/deprecations/DEP-2026-009-*.md` (`M1-R-N1`) `&& test "$(grep -c WithoutDefaults internal/cli/generatemodule.go)" -ge 1 && grep -qE '^[\|] \*\*D31\*\* [\|][^\|]*[\|][^\|]*[\|] \*\*[^\|]*202[67]-[0-9]{2}-[0-9]{2}' ../quantum/docs/planes/quantum-2.0.md` (D9-N en `main`; D31 rellena: con o sin sondeo) | `cd nucleus && go test ./pkg/app/... ./pkg/nucleus/... ./pkg/plugins/... ./internal/cli/... && make guards && go test ./internal/cli/ -run TestRunNewAPIWithGeneratedModuleBoots -count=1 && bash scripts/ci/check_hello_size.sh` | 64 ficheros (46 `.go`); 10 a rehacer (los 33 de `eeb586df` ya están en `main`); prosa 1.x: 75 ficheros (013:12, 014:14, 015:8, 016:9, 017:19, 018:13) |
| `M1-R-N3` (nucleus; filas 23, 24) | `session_idle_timeout` 30m de fábrica (un 0 explícito lo apaga) y problem+json por defecto con `WithErrorEnvelope()` para quedarse (los handlers de `generate resource\|module` escriben dentro del marco); regenera `asvs_l2.txt`, `security_posture.txt` y `starter_openapi.json` (baseline de `umbrella-api-posture`: su suelo va en el PR de set); DEP-2026-021/022 → `completed` | `cd nucleus && grep -qE '^- Status: .completed.* \(applied on' docs/deprecations/DEP-2026-013-*.md` (vencida desde el 2027-01-02 por `M1-G-F2`: sólo la marca distingue; `M1-R-N2`: comparte `pkg/app/extensions.go` y `app.go`) | `cd nucleus && go test ./contracts -run ASVS -update-asvs && NUCLEUS_UPDATE_CONTRACT_BASELINE=1 go test ./contracts/ && go test ./contracts/ && go test ./internal/authbench/... ./internal/apibench/... && go test ./internal/cli/ -run TypeScriptClient && make guards` | 30 ficheros (16 `.go`); 5 a rehacer; prosa 1.x: 10 ficheros; cierra NU-72 |
| `M1-R-N4` (nucleus; fila 21) | `nucleustest` deja de enlazar SQLite (`txdb.go`, `require.go`, los tres consumidores internos); el usuario importa `_ "github.com/jcsvwinston/nucleus/v2/drivers/sqlite"`; DEP-2026-019 → `completed` | `cd nucleus && grep -qE '^- Status: .removed.* \(applied on' docs/deprecations/DEP-2026-009-*.md` (`M1-R-N1`) | `cd nucleus && make workspace && test "$(GOWORK=off go list -deps ./pkg/nucleustest \| grep -c modernc.org/sqlite)" = 0 && go test ./pkg/nucleustest/... ./internal/apibench/... ./internal/jobsbench/... && bash scripts/ci/check_hello_size.sh` | 18 ficheros (`cc2c49a6`, `0709555c`, `20a4b03d`); 6 a rehacer; prosa 1.x: 4; cierra NU-121 |
| `M1-AS-N` (nucleus; fila 22; **tras `M1-V2-N`, con rebase**) | `pkg/tasks/providers/asynq` desaparece y su código vive en `providers/tasks-asynq` (`package asynqprovider`, los 42 identificadores con su nombre; 11 renames sin diff + `register.go`, `register_test.go`, `framework_test.go` reescritos; el `go.mod` del módulo usa `internal/testsqlite`, no `drivers/sqlite`); el raíz sin `hibiken/asynq`, `spf13/cast`, `x/time` ni `protobuf` (93 → 89); `jobs.go` sin el import en blanco y `unknownJobsProvider` con el texto del 2.0; `doctor.go` resuelve por el registro; `cmd/nucleus/providers.go` (+19) y `cmd/nucleus/go.mod` con el módulo y los cinco drivers a `v2.0.0` a mano; tests movidos (run_stop, tasks, scheduler, leader, runtime, framework, `TestProvider_AgainstRealRedis`, `TestModuleJobsAsynqSchedulerLockWiring`) o reescritos sobre un proveedor de relleno (`jobs_provider_registry_test.go` ×3, `doctor_test.go` ×2, `add_recipe_test.go`, `jobs_test.go:242,305` + helper, `runtime_tasks_outbox_test.go`); `contracts/tasks_asynq_module_test.go` → «el paquete del árbol ya no existe», `packages_test.go:122`, `firewall_test.go`; `ceilings.tsv` 75/88; `ci.yml` (lane jobs-redis enlaza el módulo con `go work`; «The core links no asynq»; lane CLI), `release.yml` (`Link The CLI Module To This Checkout` con los **seis** módulos), `cli_workspace.sh` (replace versionado por módulo), `Makefile`, `codeql.yml`, `SECURITY.md:90,94-95`, `dependabot-auto-merge.yml`, `generate_dependency_impact_report.sh:96,227`; `catalog.go:409`; 14 docs vivas; DEP-2026-020 → `completed` y MA-2026-020 con la ruta `/v2`; NU-156 y NU-168 ya cerrados en 1.x por `V-N8` (el movimiento los arrastra arreglados: §5 del contrato, nada aditivo en el major); NU-157 re-apuntado | `cd nucleus && head -1 go.mod \| grep -q '/v2$' && head -1 providers/tasks-asynq/go.mod \| grep -q 'nucleus/v2/providers/tasks-asynq$' && test "$(grep -c 'nucleus/v2/pkg/tasks/providers/asynq' providers/tasks-asynq/asynq.go)" = 1 && GOWORK=off go test ./contracts -run TestTasksAsynqModuleForwardsTheWholeInTreeSurface -count=1 && grep -qE '^- Status: .removed.* \(applied on' docs/deprecations/DEP-2026-009-*.md` (`M1-R-N1`: baselines en serie) | `cd nucleus && test "$(GOWORK=off go list -deps ./pkg/app ./pkg/nucleus ./internal/cli \| grep -c hibiken/asynq)" = 0 && test "$(grep -c hibiken/asynq go.mod)" = 0 && test ! -d pkg/tasks/providers/asynq && make check && bash scripts/ci/check_hello_size.sh && go work init . providers/tasks-asynq && (cd providers/tasks-asynq && go build ./... && go vet ./... && go test ./... -count=1)` y, con Redis en Docker, `(cd providers/tasks-asynq && go test . -run '^TestProvider_AgainstRealRedis$' -count=1)`; `gh pr checks <PR> --required` con las lanes standalone en NOTICE (la lane standalone del módulo y `check_cli` sólo tras el tag: del tren) | 14 movidos (2 947 líneas, 42 símbolos); 20 ficheros Go del raíz/CLI (+221 −597); 6 de CI/build (`ci.yml` 39+/15− en cinco hunks + `release.yml` 6+/2− + `Makefile` + `cli_workspace.sh` + `codeql.yml` + `dependabot-auto-merge.yml`); 1 tsv; 2 json de release-please; 14 docs; `SECURITY.md`; DEP + MA |
| `M1-R-N5` (nucleus; fila 28) | `pkg/db` añade `_time_format=sqlite` por defecto a toda URL SQLite (también desnudas y `:memory:`) junto a `busy_timeout`; el driver lee las dos formas; MA-2026-026 con la migración de datos opcional, documentada antes del tag; DEP-2026-026 → `completed` | `cd nucleus && grep -qE '^- Status: .removed.* \(applied on' docs/deprecations/DEP-2026-009-*.md && make workspace && (cd drivers/sqlite && go test -run TimeFormat ./...)` | `cd nucleus && make workspace && go test ./pkg/db/... && (cd drivers/sqlite && go test ./...) && make guards` | 12 ficheros (5 `.go`); 5 a rehacer; prosa 1.x: 2; cierra NU-110 |
| `M1-PM-N` (nucleus; fila 26) | `git mv pkg/model → internal/model` (38 renombrados; `base.go`/`meta.go` reescritos; re-aplica `15504c99` + `0c2c9106` sobre 22 ficheros que `main` cambió); retira `Runtime.Models()`, `App.Models/RegisterModel/ErrModelsRegistryNotInitialized`, `nucleus.Module[C].Models`, `ModuleSpec.Models()`, `registerModuleModels`; `nucleustest.Make` sólo por `Factory` (`quarkmake`); `hooks.NewSQLObserver` sobre tipos propios (0 consumidores fuera); los 3 generadores y `bodycheck` a `internal/model`; 4 tests sobre la API retirada reescritos (`factory_seam_test.go` nació después de la rama); `App.AutoMigrate` como la rama (D30, pregunta 5); `ci.yml` (6 líneas) y 4 scripts a `./internal/model`; `generate_compatibility_report.sh:101` sin `./pkg/model`; baseline −168 y `contracts/packages_test.go` sin la fila (NU-163 cierra); `docs/reference/api/pkg_model.md` retirado, `pkg_app.md`/`pkg_nucleus.md`/`pkg_observability_hooks.md`, `DETAILED_TUTORIAL.md`, `DEVELOPER_MANUAL.md`, README/SPEC/`API_CONTRACT_INVENTORY`, 24 menciones en 11 páginas (+12 con `pkg/model`; `covers:` colgantes del check 2 de `check-coverage.sh`); DEP-2026-024 → `removed` y MA-024 | `cd nucleus && test "$(grep -c '^module github.com/jcsvwinston/nucleus/v2' go.mod)" = 1 && grep -qE '^- Status: .removed.* \(applied on' docs/deprecations/DEP-2026-009-*.md` (`M1-R-N1`: baselines en serie) `&& test "$(grep -rln 'nucleus/v2/pkg/model"' --include='*.go' internal/cli cmd/nucleus \| grep -vcE 'generate(module)?\.go\|startapp\.go')" = 0 && grep -qE '^[\|] \*\*D29\*\* [\|][^\|]*[\|][^\|]*[\|] \*\*[^\|]*202[67]-[0-9]{2}-[0-9]{2}' ../quantum/docs/planes/quantum-2.0.md && grep -qE '^[\|] \*\*D30\*\* [\|][^\|]*[\|][^\|]*[\|] \*\*[^\|]*202[67]-[0-9]{2}-[0-9]{2}' ../quantum/docs/planes/quantum-2.0.md` (D29: `hooks.NewSQLObserver`; D30: `AutoMigrate`); la lane `suite-starter` con el ref de orbit en su rama del major (`M1-T-N`) o `NUCLEUS_SIBLING_CHECKOUTS` en local | `cd nucleus && go build ./... && go vet ./... && NUCLEUS_UPDATE_CONTRACT_BASELINE=1 go test ./contracts/ && go test ./contracts/ && go test ./... && (cd cmd/nucleus && go test ./...) && (cd pkg/nucleustest/quarkmake && go test ./...) && make guards && bash scripts/website/check-coverage.sh --strict && go run ./scripts/website/bodycheck -strict && bash scripts/release/generate_compatibility_report.sh --enforce-threshold && test "$(grep -rln 'pkg/model"' --include='*.go' . \| wc -l)" = 0 && test ! -d pkg/model` | 94 ficheros de `15504c99` (+201 −589) + 6 de `0c2c9106` + 3 de `f3fe8413`; 22 a rehacer; 18 ficheros Go importadores/usuarios; 4 051 + 3 761 líneas movidas; 168 líneas de baseline; 6 líneas de `ci.yml` + 4 scripts; 5 páginas de contrato/guías + 11 páginas del sitio (+12); prosa 1.x: 21 ficheros |
| `M1-R-N6` (nucleus; filas 27, 20) | Retira la puerta sin tipo de `pkg/signals` (`Signal`, `Event`, `Handler`, `Bus.On/Emit/EmitAsync`; `Bus.Clear` a `string`; `RedisRelay` retipado sobre nombres y `Topic[T]`; el bridge del outbox con `Define[[]byte]`); DEP-2026-003 cierra como `removed` sin código (godoc de `pkg/authz/enforcer.go`); `extension_surface.txt` y baseline regenerados; DEP-2026-025 → `removed`. Orbit: 0 usos fuera del adaptador (se va con `M1-AD-O`) | `cd nucleus && test ! -d pkg/model && go build ./... && test "$(grep -rn 'signals\.\(Pre\|Post\)' --include='*.go' . \| grep -v _test.go \| grep -vc 'pkg/signals/')" = 0 && grep -qE '^[\|] \*\*D29\*\* [\|][^\|]*[\|][^\|]*[\|] \*\*[^\|]*202[67]-[0-9]{2}-[0-9]{2}' ../quantum/docs/planes/quantum-2.0.md` (`M1-PM-N`: `pkg/model/crud.go` era el único emisor; D29: `RedisRelay` retipado) | `cd nucleus && go test ./pkg/signals/... ./pkg/outbox/... ./internal/jobsbench/... ./internal/model/... && NUCLEUS_UPDATE_CONTRACT_BASELINE=1 go test ./contracts/ && go test ./contracts/ && make guards` | 36 ficheros (26 `.go`; 12 bajo `internal/model`); 6 a rehacer; 8 marcas; prosa 1.x: 9 ficheros |
| `M1-AD-O` (orbit; fila 30 **+ el `go.mod` de D11**; dos PRs: el código y el `ui/dist` regenerado + ADR) | Borra `datasource/nucleus` (7 ficheros) y sus 9 importadores; `orbit.Config.DataSource` obligatorio (`TestModule_DataSourceIsRequired`, de la rama); `agent.Config` sin `Registry`/`Databases` y sin el cableado `a.Models/a.DBs` (`extension.go:105-106`); retira `PanelConfig.SchemaRegistry`, `SetSignalBus`, `PUT /api/models/{name}/schema/fields` y el `FieldConfigPanel` (5 ficheros de `ui/src`, −359; `npm ci && npm run build`; `ui/dist` commiteado → corte de `ui/v2.0.0` y re-pin en raíz y `server` en el tren); la raíz requiere `quark/v2`, `quark/drivers/sqlite/v2` y `orbit/quarkdatasource/v2` además de `nucleus/v2` (4 `require` que cambian; `go.sum`, `go.work.sum`); `datasource/go.mod` a cero dependencias (−48); los 33 tests del panel, los 5 importadores de los bancos (adminbench 2, fleettest 3; la rama tocó 8 + 9) y los 29 ficheros de `internal/admin` (18 tests + 11 de producción) sobre `quarkdatasource` con `quark.NewWithDB(driver, srv.DB())` (un solo pool: el rojo de `M0-E` en `adminbench/env_test.go:158`); `quarkdatasource/options_parity_test.go` retirado; `website/docs/cluster/agent.md:118` + 6 páginas + `docs/deprecations/README.md`; DEP-2026-002 → `removed`; OR-88 (D11), OR-119 y OR-145 cierran | `cd orbit && test "$(grep -c '^module github.com/jcsvwinston/orbit/v2$' go.mod)" = 1 && git -C ../nucleus show origin/<rama del major>:go.mod \| grep -q 'nucleus/v2$' && ! git -C ../nucleus ls-tree origin/<rama del major> pkg/model \| grep -q .` (`<rama del major>` como en `M1-V2-N`) (`M1-PM-N` publicado con pseudo-versión) `&& test -f quarkdatasource/options_parity_test.go` (D10-O en `main`) `&& test -d internal/adminbench/browser/node_modules && grep -qE '^[\|] \*\*D27\*\* [\|][^\|]*[\|][^\|]*[\|] \*\*[^\|]*202[67]-[0-9]{2}-[0-9]{2}' ../quantum/docs/planes/quantum-2.0.md && grep -qE '^[\|] \*\*D29\*\* [\|][^\|]*[\|][^\|]*[\|] \*\*[^\|]*202[67]-[0-9]{2}-[0-9]{2}' ../quantum/docs/planes/quantum-2.0.md` (D27: `<rama del major>`; D29: `agent.Config.Registry`/`Databases`) | `cd orbit && go build ./... && go vet ./... && go test ./... && go test -count=1 -run TestModule_DataSourceIsRequired . && (cd internal/adminbench/browser && npm ci && npx playwright install --with-deps chromium) && ORBIT_BENCH_BROWSER=required go test ./internal/adminbench/ -run TestBrowserBench -count=1 && (cd internal/fleettest/fleetbench && ORBIT_BENCH_BROWSER=required go test . -run TestFleetBrowserBench -count=1) && (cd ui && npm ci && npm run typecheck && npm run lint && npm test && npm run build && git diff --quiet -- dist) && test "$(grep -rln 'orbit/datasource/nucleus"\|nucleus/v2/pkg/model"' --include='*.go' . \| wc -l)" = 0 && ORBIT_ADMIN_BENCH_TABLE=1 go test ./internal/adminbench -run TestAdminBenchTable && diff internal/adminbench/bench-table.md docs/admin-bench.md`; `GOWORK=off go list -m all \| wc -l` antes/después en el cuerpo del PR | 189 ficheros de la rama (96 `ui/dist`), 27 a rehacer; 9 importadores + 24 de `pkg/model`; 33 de 74 tests del panel; 5 de `ui/src`; 3 `go.mod`; 7 páginas + README; prosa 1.x: 6 ficheros |
| `M1-D11-O` (orbit; **tras `M1-AD-O`**) | ADR-006 (l.84-85, l.97, l.100-101) y ADR-012 enmendados (la nota de 10 l. de la rama + «el módulo requiere Nucleus» deja de ser cierta); `module-matrix.md:108-116` y `gen_module_matrix.sh:73-81` sin la arista `quarkdatasource → raíz`; `go.work:20`, `README.md:213,219`, `CONTRIBUTING.md:65`, `docs/V1_GATE.md:30`, `ci.yml:314`, cabeceras de `check_internal_pins.sh:5` y `align_set.sh:4-9` (8 módulos, arista raíz → quarkdatasource); `website/docs/quick-start.md:129-131` si no lo hizo la ventana; la tolerancia decidida (D32, pregunta 7) escrita en los dos scripts; `DS-03` del banco admin medida sobre quark; OR-137 si sigue abierto | `cd orbit && test ! -d datasource/nucleus && grep -q 'jcsvwinston/quark/v2 ' go.mod && grep -qE '^[\|] \*\*D32\*\* [\|][^\|]*[\|][^\|]*[\|] \*\*[^\|]*202[67]-[0-9]{2}-[0-9]{2}' ../quantum/docs/planes/quantum-2.0.md` (D32: tolerancia, convergencia o `extra-files`) | `cd orbit && bash scripts/ci/check_adr_index.sh && bash scripts/ci/gen_module_matrix.sh && git diff --quiet website/docs/reference/module-matrix.md && bash scripts/ci/check_internal_pins.sh && bash scripts/release/align_set.sh --manifest ../quantum/versions.yaml --check && test "$(grep -rn -iE 'six modules\|keeping quark out' README.md CONTRIBUTING.md go.work scripts docs/V1_GATE.md .github \| wc -l)" = 0` | 2 ADR (+~14 l.), 2 scripts (cabeceras + tolerancia), `module-matrix` + generador (~10 l.), 6 líneas de prosa, 1 sonda |
| `M1-R-O1` (orbit; filas 29, 34; módulo `server` + `agent`) | La identidad del nodo atada al CN del certificado por defecto (`AllowSharedAgentCertificate` para quedarse) y `PeerService.Sync` sólo acepta peers de `--peers` (bajo mTLS el CN ha de ser el `server_id`); `docs/deprecations/README.md`; DEP-2026-001/005 → `completed`; `docs/fleet-bench.md` regenerado | `cd orbit && grep -q '^module github.com/jcsvwinston/orbit/server/v2$' server/go.mod && (cd server && go build ./...) && (cd agent && go build ./...)` | `cd orbit && (cd server && go test ./...) && (cd agent && go test ./...) && (cd internal/fleettest && go test -race ./...) && (cd internal/fleettest/fleetbench && ORBIT_BENCH_BROWSER=required go test . -run TestFleetBrowserBench -count=1 && ORBIT_FLEET_BENCH_TABLE=1 go test . -run TestFleetBenchTable) && diff internal/fleettest/fleetbench/bench-table.md docs/fleet-bench.md` | 15 ficheros (10 `.go`) de `e99b7e5` + 3 `.go` de `main` que nombran DEP-005; 9 a rehacer; prosa 1.x: 11 ficheros; cierra OR-57, OR-103 (y los cuatro tests IDENT que registraban un `node_id` distinto del CN, ya independientes del régimen) |
| `M1-R-O2` (orbit; filas 32, 33; raíz, `internal/admin`) | El operador queda atado a su tenant (columna obligatoria; sin `tenant_switch` ni superusuario no lee ni escribe otro: `orbit.go`, `tenant.go`, `bootstrap_admin.go`, `panel.go`, `operators.go`) y el entorno sale de `system_pulse` (sólo `system_env`: `system.go`, `panel.go`; la lista vacía conserva la forma del snapshot, sin tocar `ui/`); MA con cómo asignar tenant a un operador existente antes de subir; `docs/deprecations/README.md`; DEP-2026-003/004 → `completed`; `docs/admin-bench.md` regenerado | `cd orbit && test ! -d datasource/nucleus && go build ./...` (`M1-AD-O`: comparten `panel.go` y `tenant.go`) | `cd orbit && go test ./internal/admin/... && go test ./internal/adminbench/... -count=1 && ORBIT_BENCH_BROWSER=required go test ./internal/adminbench/ -run TestBrowserBench -count=1 && ORBIT_ADMIN_BENCH_TABLE=1 go test ./internal/adminbench -run TestAdminBenchTable && diff internal/adminbench/bench-table.md docs/admin-bench.md && bash scripts/ci/check_internal_pins.sh`; la lane `datastudio-engines`: `gh run list -R jcsvwinston/orbit --workflow ci.yml --branch <rama> --json conclusion --jq '.[0].conclusion' \| grep -x success` | 6 `.go` de `main` (`panel.go` en los dos avisos); orbit#578/#576 tocaron 14 + 6 en 1.x; prosa 1.x: 14 ficheros; cierra OR-80, OR-93 |
| `M1-D-Q` (quark; dos PRs por construcción) | **(1) a `main`, antes del tren**: la sección `## v2.0.0` de `website/docs/reference/release-notes.mdx` y `docs/RELEASE_NOTES_v2.0.0.md` (esqueleto por `gen_release_notes_skeleton.sh` + prosa), `docs/MIGRATION_v2.0.0.md` (la promesa literal de `README.md:24`; pregunta 9), `README.md:23-24` sin «v1.x», las 13 líneas «v1.x» de 6 páginas servidas, los 30 ficheros de `website/docs` que la rama ya reescribió (`crud`, `query-builder`, `batch-operations`, `upgrade`…), `roadmap.mdx` sin versiones, la entrada de `release-notes.mdx` que cita DEP como «removed/changed at v2.0.0». **(2) en la rama del bot, tras el commit de suelos** (release-please la regenera: trampa de 1.35.0/1.45.0): marcador, la tabla de `SECURITY.md` `v2.0.x` (+ `v1.19.x` a mano: `--supported-minors 2.0.0` escribe sólo `v2.0`; en `main` con el manifiesto en 1.19.x la tabla FALLA el self-test), `CLAUDE.md`, snapshot `website/versioned_docs/version-2.0.0` (copia literal si Docusaurus no arranca) + `versions.json` + sidebar | (1) `cd quark && test "$(grep -LE '^- Status: .*\(applied on' $(grep -l 'no earlier than' docs/deprecations/DEP-*.md) \| wc -l)" = 0` (las 11 filas aplicadas, no sólo vencidas: `grep -l 'no earlier than'` selecciona los 11 con ventana) `&& bash scripts/check-version-coherence.sh && grep -qE '^[\|] \*\*D34\*\* [\|][^\|]*[\|][^\|]*[\|] \*\*[^\|]*202[67]-[0-9]{2}-[0-9]{2}' ../quantum/docs/planes/quantum-2.0.md` (D34: `MIGRATION_v2.0.0.md`). (2) `git -C quark show origin/release-please--branches--main:.release-please-manifest.json \| python3 -c "import json,sys;print(json.load(sys.stdin)['.'])"` = `2.0.0` | `cd quark && bash scripts/check-version-coherence.sh && bash scripts/ci/check_docs_archive_freshness.sh && bash scripts/ci/check_versioned_docs_markers.sh && bash scripts/lint-docs.sh && bash scripts/ci/check_docs_product_voice.sh && test "$(grep -rn 'v1\.x' website/docs README.md \| wc -l)" = 0` (o una allowlist por línea) | 4 ficheros con marcador + 1 `RELEASE_NOTES` + 1 `MIGRATION` + 1 sección (hoy 47) + 30 ficheros de la rama + 13 líneas v1.x + snapshot (`website/docs` entero) + `versions.json` + 1 sidebar; 13 `go install` ya cambiados por `M1-V2-Q` |
| `M1-D-N` (nucleus; dos PRs por construcción) | **(1) a `main`, antes del tren**: `## v2.0.0` en `website/docs/reference/release-notes.md` (18 entradas), `README.md:8-16` y `SECURITY.md:6,16` sin «v1.x», las 28 líneas «v1.x» de 10 páginas, los 27 ficheros de `website/docs` que la rama tocó (las notas de la rama van 3 minors atrás: no se copian), las 12 páginas con `pkg/model` y sus `covers:` colgantes (check 2 de `check-coverage.sh --strict`), la tabla de paquetes del README sin `pkg/model` (== inventario), reglas nuevas en `scripts/ci/check_retired_claims.sh` (`pkg/model` como capa, `NewWrapResponseWriter`, el sobre `{"error":…}` por defecto, asynq en el root); **(2) en la rama del bot**: marcador (8 ficheros; `cmd/nucleus/go.mod` y `new.go` ya con `/v2` por `M1-V2-N`), snapshot con `cut_docs_snapshot.sh` (marcador a mano si Docusaurus no arranca), `versions.json` 28 → 29 | (1) `cd nucleus && test "$(grep -LE '^- Status: .*\(applied on' $(grep -l 'no earlier than' docs/deprecations/DEP-*.md) \| wc -l)" = 0` (las 18 aplicadas, no sólo vencidas; los 7 históricos sin ventana no cuentan). (2) `git -C nucleus show origin/release-please--branches--main:.release-please-manifest.json \| python3 -c "import json,sys;print(json.load(sys.stdin)['.'])"` = `2.0.0` | `cd nucleus && bash scripts/ci/check_version_claims.sh && bash scripts/ci/check_docs_archive_freshness.sh && bash scripts/ci/check_versioned_docs_markers.sh && bash scripts/ci/check_retired_claims.sh && bash scripts/ci/check_docs_product_voice.sh && bash scripts/website/check-coverage.sh --strict && go run ./scripts/website/bodycheck -strict && test "$(grep -rn 'v1\.x' website/docs README.md SECURITY.md \| wc -l)" = 0` | 8 ficheros con marcador; 1 sección (hoy 55); 27 ficheros de la rama; 12 páginas con `pkg/model`; 28 líneas v1.x; `RULES` de `check_retired_claims.sh`; snapshot + `versions.json` + sidebar |
| `M1-D-O` (orbit; dos PRs por construcción) | **(1) a `main`**: `## v2.0.0` en `website/docs/reference/release-notes.md` para los 5 avisos (el borrador «## v2.0.0 — unreleased» de la rama cubre 2 y su marcador dice v1.20.1: se reescribe; `product-voice` rechaza `ADR-` en las notas), `README.md:51` sin «frozen for the life of v1.x», las 5 líneas «v1.x» de 3 páginas, `website/docs/operations/upgrade.md` con el salto 1.x → 2.0 (quarkdatasource en vez del adaptador, identidad ligada al certificado, operadores con tenant, `system_pulse` sin entorno, mesh sólo con peers configurados), los 11 ficheros de `website/docs` de la rama, `module-matrix.md` (refresco por PR, V-O12); **(2) en la rama del bot** (la del root, no la de un módulo): 5 marcadores, snapshot con `scripts/release/cut_docs_snapshot.sh` (`cp -R`, sin Docusaurus), `versions.json` 17 → 18 | (1) `cd orbit && test "$(grep -LE '^- Status: .*\(applied on' $(grep -l 'no earlier than' docs/deprecations/DEP-*.md) \| wc -l)" = 0` (las 5 aplicadas, no sólo vencidas). (2) `git -C orbit show origin/release-please--branches--main:.release-please-manifest.json \| python3 -c "import json,sys;print(json.load(sys.stdin)['.'])"` = `2.0.0` | `cd orbit && bash scripts/ci/check_docs_version_claims.sh && bash scripts/ci/check_docs_archive_freshness.sh && bash scripts/ci/check_versioned_docs_markers.sh && bash scripts/ci/check_docs_product_voice.sh && bash scripts/ci/check_adr_index.sh && test "$(grep -rn 'v1\.x' website/docs README.md \| wc -l)" = 0` | 5 ficheros con marcador; 1 sección (hoy 85); `upgrade.md`; 11 ficheros de la rama; 5 líneas v1.x; snapshot + sidebar autogenerada + `versions.json`; 9 `go install` ya por `M1-V2-O` |
| `M1-G-S` (quantum; **un PR propio antes del PR de set 2.0.0, y lo que sólo es verde al pin va en el PR de set con `--incluye`**) | PR propio: `check_retired_claims.sh:48` con las frases que el 2.0 retira + fixture; `website/docs/choosing-a-data-layer.md:16,44`, `what-is-quantum.md:74`, `README.md:87`, `docs/RUMBO.md:187-188` sin `pkg/model` como capa; `check_tag_grammar.sh:66` (texto); la página «qué cambia en 2.0» (`website/docs/what-changes-in-2.0.md`: el §3.0 en prosa de producto, enlazando la guía y las notas v2.0.0 de los tres) enlazada desde `what-is-quantum.md` y la portada; el estado «cumplido» de las filas del §3.0 en `check_deprecations.sh` (o: una fila `publicado` cuyo pin ≥ versión de ventana exige `removed`/`completed`) con fixture; `requireBlock` de `docusaurus.config.ts:74-90` con `/v2` (si `M1-V2-P` no lo hizo). PR de set (`--incluye`): `why-quantum.md` (cifras al pin), `website/sidebarsNucleus.ts`/`sidebarsQuark.ts` (espejo), los suelos de los guards de postura (`check_quark_posture.sh:40`, `check_api_posture.sh:47-49`, `check_admin_posture.sh:50-52`, `check_fleet_posture.sh:52`, `check_catalog_posture.sh:41-46`), `api-*.md` regeneradas por `bump-set`, las tres fixtures con `pkg/model.InventedByGuardOfGuards…` verificadas al pin; `registro.csv`: los 18 ids `A12,abierto` que cierran las `M1-R-*`, `M1-PM-N` y `M1-AD-O` (QK-45, QK-58, QK-46, QK-59, QK-65, QK-24, QK-32, QK-60, QK-50, QK-76, NU-72, NU-121, NU-110, OR-57, OR-103, OR-80, OR-93, OR-88; más OR-119, OR-145 y NU-163) a `hecho` con su PR | PR propio: `cd quantum && bash scripts/guard-of-guards.sh` verde. PR de set: `for r in quark nucleus orbit; do gh api repos/jcsvwinston/$r/git/ref/tags/v2.0.0 --jq .ref; done` (los tres tags) `&& git submodule status` en los pines 2.0.0 | PR propio: `cd quantum && bash scripts/guard-of-guards.sh && test "$(grep -rn 'pkg/model' website/docs README.md docs/RUMBO.md \| grep -v reference/api \| wc -l)" = 0 && bash scripts/check_sidebar_sync.sh && bash scripts/check_site_posture.sh` y la lane `website-ci` verde (`gh run list -R jcsvwinston/quantum --workflow website-ci.yml --branch <rama> --json conclusion --jq '.[0].conclusion' \| grep -x success`). PR de set: `bash scripts/suite-integral.sh --cierre` (61 guards) `&& test "$(grep -cE '^(QK-45\|QK-58\|QK-46\|QK-59\|QK-65\|QK-24\|QK-32\|QK-60\|QK-50\|QK-76\|NU-72\|NU-121\|NU-110\|OR-57\|OR-103\|OR-80\|OR-93\|OR-88),.*,A12,abierto,' docs/auditoria/madurez-2026-09-03/registro.csv)" = 0` (hoy 18) | 1 regex + fixture; 4 páginas/prosa; 1 página nueva; 1 guard (`check_deprecations.sh` + fixture); 2 sidebars; 5 guards de postura (6 literales); 20 ficheros del paraguas nombran el área |
| `M1-TREN` (quantum conduce quark → nucleus → orbit → paraguas → cierre; **es el tren, no una sesión: 3 PRs `!` + 3 release PRs + 1 PR de set, excepción explícita a «una unidad = un PR»**) | Runbook: preflight (`govulncheck` limpio con la toolchain declarada; fecha ≥ 2027-02-07; `release-please release-pr --dry-run` proponiendo 2.0.0 en los 33 paquetes; `tests/train-v2/selftest.sh` verde; los 34 avisos `removed`/`completed` con la marca `(applied on …)` en las ramas y `check_deprecations.sh` verde en el laboratorio al 2.0.0; `rehearsal.yml` de nucleus verde sobre la rama del major) → merge del PR `!` de quark (el título del squash + el footer son la decisión; revisar el manifiesto del release PR: 7 componentes en 2.0.0) → `train.sh --desde quark --hasta quark` (7 tags; `release_asset_smoke` por `workflow_dispatch` sobre `v2.0.0`) → merge `!` de nucleus → fase nucleus (18 tags; `cmd/nucleus/v2.0.0` por `release.yml`; `release_asset_smoke`) → merge `!` de orbit (pines `/v2` + pseudo-versiones ya en la rama) → fase orbit (8 tags; corte de `ui` + re-pin + segundo corte de raíz y `server` si `M1-AD-O` no se publicó antes en una minor) → paraguas (`bump-set`: `versions.yaml` 2.0.0, guía con 34 entradas + la sección `/v2`, páginas, `--incluye` de `M1-G-S`, notas con la razón de cadencia QADR-0008) → `--desde paraguas --hasta cierre --sin-dispatch` (tag `v2.0.0`, `suite-integral --cierre`). Los tres merges `!` van seguidos tras el último set 1.x certificado: desde el primer merge de un `!` en `main` no sale ningún set 1.x (con la rama `major/2.0` de D27, los sets 1.x siguen saliendo mientras viva la rama) | todas las `M1-*` fusionadas (`git -C <repo> show origin/<rama del major>:go.mod \| head -1` lleva `/v2` en los tres; `test "$(grep -LE '^- Status: .*\(applied on' $(grep -l 'no earlier than' <repo>/docs/deprecations/DEP-*.md) \| wc -l)" = 0` en los tres: las 34 aplicadas, no sólo vencidas); último set 1.x certificado: `git -C quantum tag -l 'v1.*' \| sort -V \| tail -1` == `quantum:` de `versions.yaml`; `npx release-please@17 release-pr --repo-url jcsvwinston/<repo> --target-branch <rama> --dry-run` propone 2.0.0 en 7/17/8 (token y red); `bash tests/train-v2/selftest.sh`; `gh workflow run rehearsal.yml -R jcsvwinston/nucleus --ref <rama>` verde; por repo, el CI del PR `!` en verde antes de fusionarlo: `gh run list -R jcsvwinston/<repo> --branch <rama del major> --workflow ci.yml --limit 1 --json conclusion --jq '.[0].conclusion' \| grep -x success` (exige `M1-T-Q`/`M1-T-N` fusionadas: hoy quark y nucleus no tienen CI en PRs contra otra rama); `date +%F` ≥ 2027-02-07 | `cd quantum && grep -q '^quantum: "2.0.0"' versions.yaml && bash scripts/suite-integral.sh --cierre && bash scripts/check_release_assets.sh && test "$(grep -c '^### DEP' docs/planes/guia-migracion-2.0.md)" = 34 && grep -q 'github.com/jcsvwinston/quark/v2' docs/planes/guia-migracion-2.0.md && GOMODCACHE=$(mktemp -d) GOBIN=$(mktemp -d) GOWORK=off go install github.com/jcsvwinston/nucleus/cmd/nucleus/v2@v2.0.0 && $GOBIN/nucleus version` imprime `v2.0.0`; los puntos 4 y 5 del §4 (AA con el tema nuevo; docs con el rediseño) sólo si el carril `RD-*` llegó: si no, D37 (12b) | 33 tags de producto + `v2.0.0` del paraguas; 4 repos; 6 fases; 7 PRs |

**El orden.** Lo de arriba cabe en tres tramos:

1. **Ahora, en 1.x, en paralelo por repo** (compatible hacia atrás; cada PR
   deja el pin de 1.45.0 igual): quantum `M1-V2-P`(a) ∥ `M1-G-P`(a) →
   `M1-G-P`(b); `V-S2b` (orbit, de la ventana: sube el suelo de
   `datasource/go.mod` y de `fleettest`, y el tren lo publica) → orbit
   `M1-T-O` → quantum `M1-V2-P`(b) → `M1-V2-P`(c) → `M1-T-P`; orbit `M1-G-O`;
   nucleus `M1-T-N` ∥ `M1-G-N`; quark `M1-T-Q` ∥ `M1-G-Q`; `M1-T-LINT-Q/N/O` →
   `M1-T-LINT-P` cuando D28 esté rellena; `M1-G-F1…F5`, cada una al vencer
   su fecha. Van entremezcladas con las diez cortas de D15 y las `V-*`
   (sección siguiente); `M1-G-P` tiene la primera fecha de este tramo (antes
   del set posterior al 2026-12-08: la regla D2 de `POLITICA_DEPRECACION.md`
   §4) y `M1-G-F1…F5` las demás (2026-12-08; 2027-01-04, dos repos;
   2027-01-17, dos repos).
2. **El major, por repo y en este orden, porque orbit sólo compila contra
   nucleus/v2 y nucleus contra quark/v2 por pseudo-versiones fusionadas**
   (enero de 2027, D17): quark `M1-V2-Q`(1)(2) → `M1-R-Q1` → `M1-R-Q4` →
   `M1-R-Q2` → `M1-R-Q3` → `M1-D-Q`(1) (en serie: Q1 ∩ Q4 =
   `acceptance/apisurface.json`, `acceptance/allowlist.json`,
   `docs/playbooks/dialects.md`; Q4 ∩ Q2 = `docs/enterprise-bench.md`,
   `internal/enginesuite/suite_test.go`, `website/docs/guides/modeling.mdx`;
   Q2 ∩ Q3 = `query_builder.go` más los dos primeros de Q4 ∩ Q2; `comm -12`
   sobre los ficheros de cada grupo); nucleus `M1-V2-N`(1)(2) → `M1-R-N1` →
   {`M1-R-N2` → `M1-R-N3`} ∥ `M1-AS-N` ∥ `M1-R-N4` ∥ `M1-R-N5` → `M1-PM-N` →
   `M1-R-N6` → `M1-D-N`(1) (los baselines de `contracts/` obligan a fusionar
   en serie o rebasar tras cada merge); orbit `M1-V2-O`(1)(2) → `M1-AD-O` →
   `M1-D11-O` ∥ `M1-R-O1` ∥ `M1-R-O2` → `M1-D-O`(1). El primer commit del
   major de cada repo es `M1-V2-{Q,N,O}`(1): título `feat!:`.
3. **El tren**: `M1-G-S` (PR propio) → `M1-TREN` con `M1-D-{Q,N,O}`(2) en
   la rama del bot de cada repo y el PR de set con `--incluye`.

**Lo que puede hacerse EN 1.x antes de `M1`** (todo compatible hacia atrás):
el tramo 1 entero (`M1-V2-P`, `M1-T-P`, `M1-T-O`, `M1-T-N`, `M1-T-Q`,
`M1-T-LINT-Q/N/O/P`, `M1-G-P`, `M1-G-Q/N/O`, `M1-G-F1…F5`); de release-please,
`release-as`/`linked-versions` NO (actúan en el siguiente release PR aunque
no haya `!`: van en los PRs `!`) y `extra-files` con la anotación
`x-release-please-version` de `cmd/quark/go.mod` SÍ (`M1-T-Q`: hoy
`cmd/quark/go.mod:23` requiere v1.19.0 con el set en v1.19.1,
`versions.yaml:21`); el §3.5 y el plan corregidos (este
PR); `datasource/go.mod` y los 11 pines de `fleettest` (`V-S2b`, antes de
`M1-T-O`); la prosa
de la arista y OR-137 (`V-O11`); OR-121/OR-116/OR-129 y el fleet sobre
tokens semánticos (`V-O7`, `V-O16`); la anotación de `cmd/quark/go.mod`
(`M1-T-Q`); el job agregador del paraguas y el refresco de la matriz por PR
(D23: `V-S6`, `V-O12`); la política de soporte (`V-S3a…d`); Discussions (hecho).

### Lo aditivo que entra en la ventana (D17)

Las 32 líneas del gate de `R1`
(`docs/auditoria/reauditoria/2026-10-23/README.md:133-215`)
nombran 91 elementos (68 con 76 ids distintos y 23 sin id); con los 8 de
D15 que el gate no lista, 99 filas. Clases: **AC** aditivo-corto (entra en la
ventana), **AL**
aditivo-largo (A13 salvo que el propietario lo quiera), **R** rompiente
(ya en el §3.0: `M1`), **P** del propietario, **H** ya hecho (lo mide `R2`).
Estado = la columna `estado` del registro (`grep "^<id>," registro.csv`);
«sin fila» son controles de banco `absent`/`partial` sin hallazgo.

| # | Elemento | Dimensión | Id | Estado | Clase | Sesión |
|---|---|---|---|---|---|---|
| 1 | `GroupBy` sin `Select` (Q22/Q23) | quark·API/query | QK-24 | abierto | R | `M1-R-Q3` |
| 2 | `Raw[T]` tipado (`client.go:695` devuelve `*sql.Rows`) | quark·API/query | — | sin id | AC | `V-Q1` |
| 3 | un caso LATERAL en el banco y en el builder | quark·API/query | QK-79 | abierto | AC (interfaz opcional en 6 módulos: ADR 0029) | `V-Q1` |
| 4 | `.sql` embebidos desde un `Plan` (`--emit sql`) | quark·migraciones | MIG-13 | sin fila | AC | `V-Q2` |
| 5 | hash del plan comprobado al aplicar | quark·migraciones | MIG-05 | sin fila | AC (sólo opt-in: D38 b, 2026-11-16) | `V-Q2` |
| 6 | tipo decimal exacto | quark·tipos | QK-71 | abierto P2 | AL: A13 (D38 a, 2026-11-16) | A13 |
| 7 | JSONB con operadores | quark·tipos | TYP-08 | sin fila | AC (interfaz opcional en 6 módulos) | `V-Q3` |
| 8 | InsertOne/FindByPK/List100/Preload100 dentro del 15 % | quark·rendimiento | PG-01…04, MY-01 | sin fila | criterio retitulado a lo medido (D38 g, 2026-11-16, contra la recomendación: `criterios-5.csv` y la decisión 1 del arco) | hecho el 2026-11-16 (el PR de D26…D38) |
| 9 | COPY en PostgreSQL | quark·rendimiento | QK-54 | abierto (D15) | AL: a A13 (D38 i, 2026-11-16, contra la recomendación) | A13 |
| 10 | brazo «quark, generated» en PG-01/02/03 y MY-01 | quark·rendimiento | QK-84 | abierto | AC (mide, no sube) | `V-Q4` |
| 11 | control UpdateByPK (PG-07/MY-04) | quark·rendimiento | QK-85 | abierto | AC | `V-Q4` |
| 12 | RLS nativa + verificador en SQL Server y Oracle | quark·multi-tenant | — | sin id | AL | A13 |
| 13 | sharding que componga con tenant | quark·multi-tenant | RLS-12 | sin fila | AL | A13 |
| 14 | tenant en réplicas, sin medir | quark·multi-tenant | — | sin id | AL (sin instrumento) | A13 |
| 15 | EXPLAIN opcional en el slow log | quark·observabilidad | OPS-10 | sin fila | AC | `V-Q5` |
| 16 | muestreo del detector de N+1 | quark·observabilidad | OPS-10 | sin fila | AC | `V-Q5` |
| 17 | exemplars (el SDK pinado los lleva: `sdk/metric v1.46.0`, `go.mod:13`) | quark·observabilidad | OPS-10 | sin fila | AC | `V-Q5` |
| 18 | `quarktest` para los seis motores | quark·testing | — | sin id | AC (DSN del entorno con `Skip`, sin dependencia nueva: decidido aquí, no se pregunta) | `V-Q6` |
| 19 | fixtures/factories (`quarktest.Make[T]`) | quark·testing | — | sin id | AC | `V-Q6` |
| 20 | snapshot de esquema | quark·testing | — | sin id | AC | `V-Q6` |
| 21 | playground de consultas | quark·docs/DX | — | — | H (quark#485) | `R2` |
| 22 | receta en el 100 % de los `Err*` | quark·docs/DX | QK-78 | hecho | H | `R2` |
| 23 | deriva fuera de los guards | quark·docs/DX | QK-73, QK-74, QK-77 | hecho | H | `R2` |
| 24 | política de estabilidad del contrato aprobada | quark·ecosistema | — | — | H (ADR 0029 `accepted`) | `R2` |
| 25 | suelo del CLI en el mismo corte | quark·ecosistema | QK-72, NU-147 | abierto | AC: la mitad «raíz» de quark es la anotación de release-please (`M1-T-Q`); los suelos de los drivers (quark v0.2.0 → v0.3.3, nucleus v0.1.8 → v0.1.13/v0.2.3) se declaran en `declared_lags` de `versions.yaml` (D35, 2026-11-16) | `M1-T-Q` + `M1-T-P` |
| 26 | migraciones generadas desde modelos | nucleus·Datos | — | — | H (nucleus#656) | `R2` |
| 27 | generadores y `nucleustest.Make` sobre quark | nucleus·Datos | NU-137 | hecho | H | `R2` |
| 28 | `pkg/model` fuera | nucleus·Datos | — | — | R (fila 26) | `M1-PM-N` |
| 29 | WebAuthn | nucleus·Auth/Authz | MFA-02 | sin fila | AL: A13 (D38 f, 2026-11-16: todo lo largo que la ventana no cubre) | A13 |
| 30 | timeout de inactividad de fábrica | nucleus·Auth/Authz | NU-72 | abierto | R (fila 23) | `M1-R-N3` |
| 31 | pprof protegido en toda composición | nucleus·Observabilidad | — | — | R (fila 19); la guarda de 1.x ya existe y no lleva fila: la línea ERROR de DEP-018 (`:45`, desde v1.32.0) y el comentario del starter `api` (`nucleus.yml.tmpl:33-35`) | `M1-R-N2` |
| 32 | firma de cookies con keyring | nucleus·Seguridad | — | sin id | AL | A13 |
| 33 | rotación de secretos de base y storage | nucleus·Seguridad | NU-67 | hecho (anterior a `R1`, nucleus#473) | H | `R2` |
| 34 | factories sobre la capa de datos por defecto | nucleus·Testing | — | — | H (nucleus#648) | `R2` |
| 35 | cero deriva | nucleus·Docs/DX | NU-133, NU-135, NU-144 | hecho | H | `R2` |
| 36 | endpoints tipados y errores en el marco | nucleus·CLI | NU-136, NU-145 | hecho | H | `R2` |
| 37 | `doctor`/`health`/`config print` con los providers de `main.go` | nucleus·CLI/Ecosistema | NU-132 | hecho | H | `R2` |
| 38 | catálogo fijado al set para los productos de la suite (`add.go:208,318`) | nucleus·Ecosistema | NU-143 | abierto | AC (el CLI se taggea antes que orbit: D36, 2026-11-16, `versions.yaml` por red con caída a la tabla) | `V-N1` |
| 39 | validación por campo sobre `quarkdatasource` | orbit·Data Studio | OR-78 | hecho | H | `R2` |
| 40 | FK comprobada al escribir y al borrar | orbit·Data Studio | OR-82 | abierto P2 | AC (criterio en `quarkdatasource`, no en adminbench) | `V-O1` |
| 41 | M2M | orbit·Data Studio | — | sin id | AL | A13 |
| 42 | vocabulario de 25 tipos de campo | orbit·Data Studio | — | sin id | AL | A13 |
| 43 | `deny` creable desde el panel (`rbac.go:221-233`) | orbit·RBAC | OR-81 | abierto P2 | AC (toca `ui/src`: cascada `ui`) | `V-O2` |
| 44 | impersonación auditada | orbit·RBAC | — | sin id | AL | A13 |
| 45 | operador atado a un tenant | orbit·RBAC | OR-80 | abierto P1 | R (fila 32) | `M1-R-O2` |
| 46 | retención configurable del anillo del feed (hoy 256 fijo, `live.go:26-27,191`; 50 es el límite de lista) | orbit·Telemetría | — | sin id | AC | `V-O3` |
| 47 | EXPLAIN desde el feed | orbit·Telemetría | — | sin id | AL: a A13 (D38 d, 2026-11-16, contra la recomendación; el contrato `datasource` congelado no expone conexión) | A13 |
| 48 | feed confinado por tenant (`live.go`: 0 menciones de tenant) | orbit·Telemetría | OR-94 | abierto | AL: a A13 (D38 d, 2026-11-16, contra la recomendación; la enmienda a ADR-007:118 va con él) | A13 |
| 49 | el tenant en cada entrada de auditoría | orbit·Audit | OR-74 | abierto (D15) | AC | `V-O4` |
| 50 | ninguna entrada por una mutación que no ocurrió | orbit·Audit | OR-83 | hecho | H | `R2` |
| 51 | la flota bajo mTLS desde el binario | orbit·Fleet | OR-99 | hecho | H | `R2` |
| 52 | fallo de la malla visible + gauge de peers | orbit·Fleet | OR-100 | abierto P2 | AC | `V-O5` |
| 53 | alertas que se resuelven cuando el nodo se va | orbit·Fleet | OR-101 | abierto P2 | AC | `V-O5` |
| 54 | alertas e historial retenido visibles en la SPA | orbit·Fleet | OR-102 | abierto P2 | AC (cascada `ui`) | `V-O6` |
| 55 | retención sin UI suscrita | orbit·Fleet | OR-108 | abierto | AC | `V-O5` |
| 56 | lo relayado retenido en el peer | orbit·Fleet | OR-113 | abierto | AC | `V-O5` |
| 57 | ruleset WCAG 2.1 AA entero en CI, todas las rutas, dos temas (`withTags` 0 hoy; 6 llamadas con reglas elegidas) | orbit·UI/UX | OR-129 | abierto | AC (+ viewport móvil, OR-120) | `V-O7` |
| 58 | diálogo modal: foco retenido y `aria-modal` | orbit·UI/UX | OR-115 | abierto P2 | AC (cascada `ui`) | `V-O7` |
| 59 | `Card role="table"` con `<a>` dentro | orbit·UI/UX | OR-116 | abierto P2 | AC | `V-O7` |
| 60 | feed desplazable sin `tabIndex` | orbit·UI/UX | OR-117 | abierto P2 | AC | `V-O7` |
| 61 | contraste de los botones destructivos en claro (3,60:1, `tokens.css:23-24`) | orbit·UI/UX | OR-121 | abierto P2 | AC | `V-O7` |
| 62 | estado de lista en la URL | orbit·UI/UX | OR-122 | abierto | AC (cascada `ui`) | `V-O8` |
| 63 | atajos de teclado | orbit·UI/UX | — | sin id | AC | `V-O8` |
| 64 | un solo sistema de tokens (318 clases `-tN` + 271 tamaños + `tailwind.fleet.config.js`) | orbit·UI/UX | OR-126 | abierto | AL mecánico: entra en la ventana sólo como prerrequisito del carril del rediseño (`RD-1o-ui`), no por D17 (decidido: en `V-O16`, no con el rediseño) | `V-O16` |
| 65 | lockout compartido entre réplicas | orbit·Seguridad | — | sin id | AC (migración aditiva) | `V-O9` |
| 66 | 2FA de operadores | orbit·Seguridad | — | sin id | AL | A13 |
| 67 | entorno fuera de `system_pulse` | orbit·Seguridad | OR-93 | abierto | R (fila 33) | `M1-R-O2` |
| 68 | sesiones revocadas al cambiar la contraseña | orbit·Seguridad | OR-85 | abierto P2 | AC | `V-O9` |
| 69 | lane de motor para `internal/admin` y `quarkdatasource` | orbit·Testing | OR-84 | abierto P2 | AC (la de `internal/admin` exige `nucleus/drivers/{postgres,mysql}` en la raíz) | `V-O10` |
| 70 | cobertura de la SPA publicada | orbit·Testing | — | sin id | AC | `V-O10` |
| 71 | guía por feature (`features.md` 1 719 líneas al pin) | orbit·Docs/DX | — | sin id | AC (grande, docs) | `V-O11` |
| 72 | DEP-2026-002 sin puntero roto | orbit·Docs/DX | OR-89 | hecho | H | `R2` |
| 73 | orbit/README lista tres de siete hermanos | suite·Coherencia | OR-137 | abierto | AC | `V-O11` |
| 74 | el camino frío medido en CI | suite·Embudo | QM-36 | abierto | AC | `V-S5` |
| 75 | «Ten files» (`quickstart.md:111`) | suite·Embudo/Sitio | QM-30 | abierto | AC | `V-S1` |
| 76 | «Go 1.26 or newer», puerto sin `NUCLEUS_PORT` | suite·Embudo/Sitio | QM-31 | abierto | AC | `V-S1` |
| 77 | «fleet trio and two bridges»; tabla sin 4 módulos | suite·Sitio/Coherencia | QM-29 | abierto | AC | `V-S1` |
| 78 | siete enlaces de snapshots archivados a `examples/` | suite·Sitio | QM-37 | hecho | retirado el punto (D38 c, 2026-11-16): los snapshots no se reescriben; QM-37 hecho | — |
| 79 | un set en < 30 min; `--check` que mire los pines internos | suite·Tren | QM-23 | abierto P2 | AC (el `--check`) + AL (los 30 min: 68–88 conducidos) | `M1-T-P` |
| 80 | `align_set`/§5 con listas derivadas del árbol | suite·Tren | QM-22 | abierto P2 | AC | `V-S2b` (orbit) + `M1-V2-P`(b) (quantum) |
| 81 | `fase_repo` sin comprobar releasables; `orbit-align-notes.sh` anterior a ADR-012 | suite·Tren | QM-40 | abierto | AC | `M1-T-P` |
| 82 | Scorecard ≥ 8; el paraguas publica su nota | suite·Gobernanza | QM-33 | abierto | H (publicación, D25) + P (≥ 8 = D23) | `V-O12`, `V-S6` + propietario |
| 83 | SLSA 3 o decir el nivel | suite·Gobernanza | QM-34 | abierto | AL: L3 en A13 (D38 e, 2026-11-16, contra la recomendación) | A13 |
| 84 | política de soporte publicada | suite·Gobernanza | QM-25 | abierto | AC (D21/D22) | `V-S3a` |
| 85 | SECURITY con un canal que funcione | suite·Gobernanza | NU-149 | abierto | AC | `V-S3c` |
| 86 | README «doce módulos opcionales» | suite·Coherencia | QM-26 | abierto | AC | `V-S1` |
| 87 | README «seis módulos hermanos» | suite·Coherencia | QM-27 | abierto | AC | `V-S1` |
| 88 | AUDITORIA_CONTINUA «41 guards» (61 registrados) | suite·Coherencia | QM-28 | abierto | AC | `V-S1` |
| 89 | benchmarks públicos de nucleus y orbit | suite·Posicionamiento | QM-39 | abierto | AC ×2 | `V-N2`, `V-O13` |
| 90 | Encore y Supabase en la comparativa | suite·Posicionamiento | QM-38 | abierto | AC (amplía la tabla de `check_why_quantum.sh:14-20`) | `V-S4` |
| 91 | la frase rancia del 15 % (`why-quantum.md:139`) | suite·Posicionamiento | QM-44 | abierto | AC | `V-S4` |
| 92 | WARN imposible con `WithOpenAuthz()` + `profiling_enabled` | nucleus (D15) | NU-129 | abierto | AC | `V-N3` |
| 93 | fila de autorización en la tabla de middleware | nucleus (D15) | NU-131 | abierto | AC (docs: viaja con `V-N3`/`V-N5`) | `V-N4` |
| 94 | pool por defecto que churnea con 16 workers | nucleus (D15) | NU-108 | abierto | AC | `V-N5` |
| 95 | búsqueda rechazada entera si un campo buscable está oculto | orbit (D15) | OR-71 | abierto | AC (sin tocar `datasource.Query`: D38 h, 2026-11-16) | `V-O14` |
| 96 | editor de hijos: filtro 400 sin `admin:"filter"` | orbit (D15) | OR-75 | abierto | AC (cascada `ui`) | `V-O15` |
| 97 | editor de hijos manda cadena vacía (`InlineEditor.tsx:137`) | orbit (D15) | OR-76 | abierto | AC (cascada `ui`) | `V-O15` |
| 98 | `ForTx(...).Cache(...)` guarda lo no confirmado | quark (D15) | QK-68 | abierto | AC | `V-Q8` |
| 99 | `CreateBatch` por RETURNING bajo RLS nativo invalida antes del commit | quark (D15) | QK-69 | abierto | AC | `V-Q9` |

Y doce hallazgos abiertos del mismo instrumento que quedaron fuera de las 32
líneas y tienen dueño aquí: NU-150 (hello+sqlite 26,2 MB; el criterio pasa
a ≤ 27 MB por D38 j: `V-N6`),
QK-81 y QK-83 (el banco de motores: `V-Q4`), QM-24 (`M1-V2-P`(b)), QM-32
(`CADENA_DE_SUMINISTRO.md` congelado en 1.29.0: `V-S3a`), QM-35 (shellcheck:
`M1-T-P` o A13), NU-154 (abrir el enum de `jobs_provider` al registro:
`V-N9`), NU-156 y NU-168 (el proveedor asynq del árbol, en 1.x: `V-N8`),
OR-124 (enlace «skip to content») y OR-135 (`document.title` por ruta), los
dos aditivos y de la misma SPA que `V-O7`, OR-103 (fila 34: `M1`). Y tres
del mismo instrumento que no son UI y quedan donde están, fuera de la
ventana: OR-118 (validación del formulario de registro) y OR-131 (toolchain:
`npm audit` de la cadena de build), en A13 o en un `fix` de orbit; OR-119
(validación en el adaptador de nucleus) la cierra `M1-AD-O` al borrarlo.

Por los números de la tabla (`R` = 0 y `AL/P` = 0), **17 de las 32
dimensiones quedan sin ningún elemento pendiente fuera de la ventana**
(quark·migraciones, observabilidad, testing, docs/DX, ecosistema;
nucleus·Testing, Docs/DX, CLI, Ecosistema; orbit·Telemetría, Audit, Fleet,
Testing, Docs/DX; suite·Embudo, Coherencia, Posicionamiento); **3 sólo a
falta de `M1`** (quark·API/query, nucleus·Datos, nucleus·Observabilidad);
**3 a falta de `M1` y de un elemento largo** (nucleus·Auth, orbit·RBAC,
orbit·Seguridad); **9 con algo largo o del propietario** (quark·tipos,
rendimiento, multi-tenant; nucleus·Seguridad; orbit·Data Studio, UI/UX;
suite·Sitio/docs, Tren, Gobernanza). La nota que `R2` dará depende del
instrumento de cada dimensión, no de esta tabla.

#### Las sesiones de la ventana (una sesión = un PR; precondición y criterio como comando)

Cuatro reglas que salieron de refutar las sesiones y valen para todas:
**(i)** las que tocan `ui/src` (`V-O2`, `V-O6`, `V-O7`, `V-O8`, `V-O15`, y
`V-O3` si toca la SPA) se agrupan en un mismo set para pagar UN segundo
corte de orbit (`ui` es módulo con tag requerido por tag); **(ii)** las que
tocan al dialecto de quark (`V-Q1`, `V-Q3`, `V-Q7`) no pueden añadir métodos a
`quarkdriver.Dialect` (ADR 0029,
`internal/extbench/testdata/extension-points.txt`):
son una interfaz opcional nueva implementada en los cinco módulos de driver
(seis módulos en el PR) con veredicto por motor; **(iii)** las de sólo docs
(`V-N2`, `V-N4`, `V-O11`, `V-O13`) no cortan (`docs:` oculto en
release-please): su fila dice con qué corte viajan; **(iv)** cada sesión de
producto —de la ventana o de `M1`— arrastra escrituras en el paraguas en el
PR de set (suelos de postura, espejo de sidebars, `hecho` en `registro.csv`
con su PR, la marca en el plan); los 18 ids `A12,abierto` que cierran las
`M1-R-*`, `M1-PM-N` y `M1-AD-O` los escribe `M1-G-S` en el PR de set 2.0.0,
con su comando.

Lo que la ventana no repite porque ya es del tramo 1.x de `M1`: QK-72 mitad
raíz → `M1-T-Q`; la lane `suite-starter` con refs de hermanos → `M1-T-N`;
QM-22 mitad quantum, QM-24, QM-23 `--check` y QM-40 del paraguas →
`M1-V2-P`(b) y `M1-T-P`. Las filas de la tabla son las 42 sesiones `V-*` que
se publican.

| Sesión | Qué entrega | Precondición (comando) | Criterio de hecho (comando) | Tamaño medido |
|---|---|---|---|---|
| `V-Q1` (quark) | `Raw[T]` tipado (escaneo a `[]T` con el mapeo existente) y `JoinLateral` por interfaz opcional de dialecto (LATERAL en PG/MySQL ≥ 8.0.14, `CROSS APPLY` en MSSQL; SQLite sin él) + caso Q61 en el banco con veredicto por motor | `cd quark && go test ./internal/enginesuite -run TestQueryBench` verde al pin | el mismo con 59 typed en los motores que lo soportan; `grep -c LATERAL internal/enginesuite/querybench_cases_test.go` ≥ 1; `make check`; `docs/query-bench.md` al día | `client.go:695` (+1 función), `query_builder.go` (+1 método), 5 drivers (+1 método estructural), banco 558 l. (+1 caso) |
| `V-Q2` (quark) | `quark migrate create --emit sql` (par `.up.sql`/`.down.sql`, MIG-13) y `WithPlanHashCheck()` sólo opt-in (MIG-05; D38 b, 2026-11-16) | `cd quark && go run ./cmd/quark migrate create x --from-models ./m --emit json` imprime `up[]`/`down[]` | `QUARK_BENCH_TABLE=1 go test ./internal/enterprisebench/ -run TestEnterpriseBenchTable` con MIG-13 y MIG-05 `present` y `git diff --exit-code docs/enterprise-bench.md`; `make check`; **dos PRs** (el CLI es módulo propio: el `--emit sql` sin tocar la raíz; `WithPlanHashCheck` en la raíz) | `cmd/quark/commands` (molde: `--emit json`, quark#486), `migrate_state.go:39`, `internal/migrate/migrate.go` 562 l. |
| `V-Q3` (quark) | `WhereJSONContains`/`WhereJSONHasKey`/`WhereJSONPath` por interfaz opcional de dialecto, casos en `SharedSuite` | `cd quark && go test ./internal/enginesuite -run SharedSuite` verde en SQLite | TYP-08 `present` en `TestEnterpriseBenchTable`; `make test-all` con `QUARK_TEST_POSTGRES_DSN` (JSONB) | `query_builder.go:1000` (+3), 5 drivers, `SharedSuite` |
| `V-Q4` (quark) | brazo «quark, generated» en PG-01/02/03 y MY-01 (QK-84), control UpdateByPK PG-07/MY-04 (QK-85), la aserción de asignaciones que salta en local (QK-81) y el artefacto de 10 días del banco (QK-83); fila en `benchmarks.mdx` | `cd quark && bash benchmarks/engines/run.sh <dir>` PASS al pin (3 corridas, Docker) | `bash benchmarks/engines/run.sh <dir>` con los brazos nuevos; la corrida de `engine-bench.yml` enlazada en el PR y la página con la cifra | `benchmarks/engines/{postgres,mysql,cases}_test.go` |
| `V-Q5` (quark) | `WithSlowQueryExplain()` opt-in, muestreo del detector de N+1 y exemplars (OPS-10) | `cd quark && go test -run 'SlowQuery\|NPlusOne' .` verde | OPS-10 `present` en `TestEnterpriseBenchTable`; `make check` | `slow_query_log.go` 47 l., `observe.go` 346 l., `option.go` |
| `V-Q6` (quark) | `quarktest.Engine(tb)` por DSN del entorno (`Skip` si falta), `quarktest.Make[T]` (defaults desde los metadatos, como `nucleustest/quarkmake`), `quarktest.SnapshotSchema` (golden por dialecto) | `cd quark && go test ./quarktest` verde | `go test ./quarktest` en la lane PG con `QUARK_TEST_POSTGRES_DSN`; un test de convención que cuente las tres entradas | `quarktest/quarktest.go` 103 l. (3 → 6 funciones) |
| `V-Q7` → **A13** (quark; D15 · QK-54; D38 i, 2026-11-16, contra la recomendación: no se publica en la ventana) | COPY opcional en PostgreSQL (`CreateBatchCopy` o `WithCopy()`) con capacidad declarada por el driver; API aparte (COPY no devuelve claves, no aplica reglas ni RLS: `benchmarks/engines/cases_test.go:126-127`) | lane PG verde al pin: `make test-all` con `QUARK_TEST_POSTGRES_DSN` | el brazo COPY del banco (`postgres_test.go:550`) comparado con `CreateBatchCopy` en el lote de 10 000 (cifra en el PR; el «≤ 1,15× COPY» del plan se retitula a lo medido); `make check`; QK-54 `hecho` | `drivers/postgres` (0 `CopyFrom` hoy), `batch*.go`, banco |
| `V-Q8` (quark; D15 · QK-68) | `ForTx(...).Cache(...)` no escribe en la caché compartida filas sin confirmar (salta la caché en tx o difiere al commit; la elección en el godoc) | `cd quark && go test -run Cache .` verde | `go test -run 'Cache\|ForTx' .` con el test nuevo verde y `make test-all`; QK-68 `hecho` | `cache_invalidation.go:171-173`, `tx.go:705`, `query_builder.go:730` |
| `V-Q9` (quark; D15 · QK-69) | invalidación de caché tras el commit en `CreateBatch` por RETURNING bajo RLS nativo | `make test-all` con `QUARK_TEST_POSTGRES_DSN`: `TestRowLevelSecurityNativePostgresIsolation` verde | el test nuevo de la ventana invalidación → commit verde en PG; QK-69 `hecho` | `rls_native.go:30-50,456-470` |
| `V-N1` (nucleus) | NU-143: `nucleus add\|new` instala la versión del set certificado para orbit/quark/quarkbridge/quarkdatasource (tabla embebida que el tren regenera, o `versions.yaml` por red con caída a la tabla: D36, pregunta 11) | `cd nucleus && go run ./cmd/nucleus add orbit --dry-run` imprime «latest» `&& grep -qE '^[\|] \*\*D36\*\* [\|][^\|]*[\|][^\|]*[\|] \*\*[^\|]*202[67]-[0-9]{2}-[0-9]{2}' ../quantum/docs/planes/quantum-2.0.md` (D36 rellena) | `go run ./cmd/nucleus add orbit --dry-run` imprime la versión de `versions.yaml` (o la del set anterior, según la decisión); control `CAT-xx` nuevo para `add` (`CAT-04` mide `new`) y el suelo de `check_catalog_posture.sh:41-46` en el PR de set | `internal/cli/add.go:208,318`; `scripts/bump-set.sh` del paraguas |
| `V-N2` (nucleus; docs) | QM-39 mitad nucleus: página de benchmarks (hello-size, cola SQL, router) con fuente y fecha; espejo `website/sidebarsNucleus.ts` en el PR de set; viaja con el siguiente `feat`/`fix` | `cd nucleus && bash scripts/website/check-coverage.sh --strict` verde | `check-coverage.sh --strict` y `go run ./scripts/website/bodycheck -strict` verdes; `cd quantum && bash scripts/check_sidebar_sync.sh` en el PR de set | `website/docs/` (0 páginas de benchmarks hoy) |
| `V-N3` (nucleus; D15 · NU-129) | sin WARN imposible con `WithOpenAuthz()` + `profiling_enabled`; las filas de módulo no se cargan en un enforcer que nadie consulta | `cd nucleus && go test ./pkg/app -run OpenAuthz` verde | test nuevo: arranque `WithOpenAuthz()` + `profiling_enabled` con 0 WARN; NU-129 `hecho` | `pkg/app/app.go:1029-1044,1263,2048` |
| `V-N4` (nucleus; D15 · NU-131; docs) | fila «Authorization» en la tabla de middleware de `routing.md:449-462` y la frase «every auto-mounted middleware can be turned off» corregida; viaja con `V-N3`/`V-N5` | `check-coverage.sh --strict` verde | `check-coverage.sh --strict` y `bodycheck -strict` verdes; NU-131 `hecho` | 1 página |
| `V-N5` (nucleus; D15 · NU-108) | pool por defecto (`MaxIdle` 5) que no churnea con 16 workers de la cola SQL | `bash scripts/ci/test_with_engines.sh ./pkg/tasks/providers/sql -run '^TestSQLMatrix_JobsClaimsDoNotCollide$\|^TestSQLMatrix_JobsQueueScalesWithWorkers$\|^TestSQLMatrix_JobsClaimCostDoesNotGrowWithTheBacklog$'` con `NUCLEUS_SQL_MATRIX_URL` (el gate de `N2`, `ci.yml:343-349`) verde al pin | el mismo gate con el `MaxIdle` nuevo y la cifra de conexiones abiertas/cerradas en el PR; notas de la minor lo dicen; NU-108 `hecho` | `pkg/app/config.go:692-693`; `pkg/db/db.go:126-130` |
| `V-N6` (nucleus + quantum) | NU-150: el criterio de `N1` pasa a **≤ 27 MB** (D38 j, 2026-11-16, contra la recomendación): la sesión reescribe el criterio en este plan (la fila `N1` del troceado y la nota «Los criterios de rendimiento del arco») y en `criterios-5.csv` (nucleus · rendimiento), y alinea `ceilings.tsv` a 27 MB (27 000 000 B; hoy 26 730 000) | `cd nucleus && bash scripts/ci/check_hello_size.sh` verde | `bash scripts/ci/check_hello_size.sh` con el techo de hello+sqlite en `ceilings.tsv` = 27 000 000 B y la columna `bytes` por debajo; `grep -q '27 MB' docs/auditoria/criterios-5.csv` en el paraguas; NU-150 `hecho` | `scripts/ci/hello-size/ceilings.tsv:23-24`; en el paraguas, este plan y `criterios-5.csv` |
| `V-N8` (nucleus; en 1.x, sobre el paquete del árbol) | NU-168: `NewLeaderScheduler` devuelve `ErrRedisURLRequired` con `RedisURL` vacía, como `NewManager` y `NewScheduler` (`pkg/tasks/providers/asynq/leader.go:105`); NU-156: `TestNormalizeQueueAction_SeenFromTheAsynqProvider` y `TestSupportedQueueActions_SeenFromTheAsynqProvider` (`runtime_test.go:46,66`) se retiran (duplican `pkg/tasks/runtime_test.go`). `M1-AS-N` mueve el paquete ya arreglado (§5 del contrato: nada aditivo en el major) | `cd nucleus && go test ./pkg/tasks/providers/asynq/ -count=1` verde al pin | `cd nucleus && go test ./pkg/tasks/... -count=1 && test "$(grep -c 'SeenFromTheAsynqProvider' pkg/tasks/providers/asynq/runtime_test.go)" = 0 && grep -q 'ErrRedisURLRequired' pkg/tasks/providers/asynq/leader.go`; NU-156 y NU-168 `hecho` | `leader.go` (1 línea + 1 test), `runtime_test.go` (−2 tests) |
| `V-N-AM` (nucleus; **D30, antes del set del 2026-11-23**) | el aviso DEP-2026-027 (fila 35 del §3.0 del contrato): `App.AutoMigrate` acepta modelos quark y migra por la ruta de `makemigrations` en el 2.0 y deja de leer la gramática `db:` de `pkg/model`; con la forma de `M0-N` (asistente, test que pina v1, marca que el guard lee) y la salida en 1.x que ya existe (`nucleus makemigrations`, `DX-N3n2`); la fila 35 pasa a `en main` en el mismo PR del paraguas que lo cite y a `publicado` con el set | `cd quantum && grep -qE '^[\|] \*\*D30\*\* [\|][^\|]*[\|][^\|]*[\|] \*\*[^\|]*202[67]-[0-9]{2}-[0-9]{2}' docs/planes/quantum-2.0.md` (D30 decidida el 2026-11-16) | `cd nucleus && test -f docs/deprecations/DEP-2026-027.md && go test ./pkg/app/... -run AutoMigrate` verde; en el paraguas `bash scripts/check_deprecations.sh` sin el AVISO de la fila 35 tras el set | `pkg/app` (`AutoMigrate`), `docs/deprecations/`, `internal/model` |
| `V-N9` (nucleus) | NU-154: `validateConfigEnum("jobs_provider", …, "memory", "asynq", "sql")` (`pkg/app/config_validate_layers.go:115`) acepta además cualquier proveedor registrado con `tasks.RegisterProvider` (`pkg/tasks/provider.go`), y la fila de `jobs_provider` en `docs/reference/CONFIG_KEY_REGISTRY.md:263` lo dice | `cd nucleus && go test ./pkg/app -count=1` verde al pin | `cd nucleus && go test ./pkg/app -count=1 && make guards` con un test nuevo (proveedor registrado con nombre propio: la configuración carga; nombre no registrado: el error de hoy); NU-154 `hecho` | `config_validate_layers.go:115` (+1 consulta al registro), `CONFIG_KEY_REGISTRY.md:263`, 1 test |
| `V-O1` (orbit) | OR-82: FK comprobada al crear/actualizar/importar (422) y al borrar el padre con hijos (409) en `quarkdatasource` | `cd orbit && (cd quarkdatasource && go test ./...)` verde | `(cd quarkdatasource && go test -run FK ./...)` con los tests nuevos; OR-82 `hecho` (sin sonda nueva en adminbench ni suelo del paraguas: el banco vive en la raíz sin quark hasta D11, OR-88) | `quarkdatasource/store.go` 760 l. (`fieldKeys` :550; :406) |
| `V-O2` (orbit; SPA) | OR-81: `eft` en `POST /api/rbac/policies` y selector allow/deny en el formulario | `cd orbit && go test ./internal/admin -run RBAC` verde | control `permissions` nuevo (deny creado desde el panel y aplicado); `(cd ui && npm test && npm run build && git diff --quiet -- dist)`; OR-81 `hecho` | `internal/admin/rbac.go:221-233` (430 l.) + formulario en `ui/src` |
| `V-O3` (orbit) | retención configurable del anillo del feed (hoy 256 fijo). OR-94 (feed confinado por tenant, con la enmienda a `ADR-007-permisos-por-campo-y-por-fila.md:118`) y EXPLAIN desde el feed pasan a A13 (D38 d, 2026-11-16, contra la recomendación): fuera de esta sesión | `cd orbit && go test ./internal/admin -run Live` verde | control OPS nuevo en adminbench (`ORBIT_ADMIN_BENCH_TABLE=1 go test ./internal/adminbench -run TestAdminBenchTable`) | `internal/admin/live.go` 1 229 l. |
| `V-O4` (orbit; D15 · OR-74) | `tenant_id` en cada entrada de auditoría (migración aditiva en los cinco motores) y filtro por el alcance del operador | `cd orbit && go test ./internal/admin -run Audit` verde | control `audit` nuevo (operador confinado no ve entradas de otro tenant); la lane `datastudio-engines` (job `name: Data Studio (<motor>)`, `ci.yml:225-226`, dos entradas de la matriz) verde en el PR: `gh run view "$(gh run list -R jcsvwinston/orbit --workflow ci.yml --branch <rama> --limit 1 --json databaseId --jq '.[0].databaseId')" -R jcsvwinston/orbit --json jobs --jq '[.jobs[] \| select(.name \| startswith("Data Studio ("))] \| length == 2 and all(.conclusion == "success")' \| grep -x true` (`gh run list --json name` da el nombre del workflow, «CI», no el del job: por eso `gh run view --json jobs`); OR-74 `hecho` | `internal/admin/audit.go` 1 031 l. |
| `V-O5` (orbit; `server` + `agent`) | OR-100 (WARN + gauge `peers_connected`), OR-101 (alerta resuelta cuando el nodo se va), OR-108 (retención sin suscriptor), OR-113 (lo relayado retenido en el peer); `bench-table.md` regenerado → `docs/fleet-bench.md` (hoy «50 of 50» con 51 casos) | `cd orbit && (cd internal/fleettest && go test -race ./...)` verde | `(cd internal/fleettest/fleetbench && ORBIT_FLEET_BENCH_TABLE=1 go test . -run TestFleetBenchTable) && diff internal/fleettest/fleetbench/bench-table.md docs/fleet-bench.md` con 55 `present`; `cd quantum && bash scripts/check_fleet_posture.sh` tras subir `EXPECTED_CONTROLS` (`:52`) en el PR de set | `server/peers/mesh.go` 447 l., `server/services/agent_service.go` 356, `peer_service.go` 170, `agent/stream` 890 |
| `V-O6` (orbit; SPA) | OR-102: alertas e historial retenido visibles en la SPA del fleet (desde `ListHostMetrics`) | `V-O5` fusionada; `(cd internal/fleettest/fleetbench && ORBIT_BENCH_BROWSER=required go test . -run TestFleetBrowserBench -count=1)` verde con Playwright | el mismo con el control de alertas nuevo; `(cd ui && npm test && npm run build && git diff --quiet -- dist)`; OR-102 `hecho` | `ui/src/fleet/` |
| `V-O7` (orbit; SPA + banco) | OR-115 (foco y `aria-modal`), OR-116 (`Card role=table` ×3 en `OverviewPage.tsx:152,230,261`), OR-117 (`tabIndex`), OR-121 (destructivo a AA en claro), OR-129 (`withTags(['wcag2a','wcag2aa','wcag21a','wcag21aa'])` sobre todas las rutas, dos temas, con diálogo abierto) y un proyecto móvil en `playwright.config.ts` (OR-120), más OR-124 (enlace «skip to content» en `DashboardLayout.tsx:124-282`) y OR-135 (`document.title` por ruta, `main.tsx:20`), fuera de las 32 líneas pero de la misma SPA y del mismo ruleset (WCAG 2.4.1/2.4.2); arreglar las seis conocidas antes de encender el ruleset | `(cd internal/adminbench/browser && npm ci && npx playwright install --with-deps chromium) && ORBIT_BENCH_BROWSER=required go test ./internal/adminbench/ -run TestBrowserBench -count=1` verde | el mismo comando con el ruleset entero y 0 violaciones; `(cd ui && npm test && npm run build && git diff --quiet -- dist)`; los siete ids `hecho` | `dialog.tsx` 116, `DashboardLayout.tsx`, `main.tsx`, `OverviewPage.tsx` 401, `NetworkInspectorPage.tsx` 322, `tokens.css` 60, `panel.spec.ts` 1 546, `playwright.config.ts` |
| `V-O8` (orbit; SPA) | OR-122 (búsqueda, filtros, orden, tamaño y página en la URL) y atajos de teclado con hoja `?` | `(cd ui && npm ci && npm test)` verde (la cifra de tests se mide al abrir) | control UIF nuevo (recargar conserva el estado; `?` abre la hoja); `(cd ui && npm test && npm run build && git diff --quiet -- dist)`; OR-122 `hecho` | `AGGridTable.tsx` 1 033 l.; un hook de atajos |
| `V-O9` (orbit) | OR-85 (cambiar la contraseña revoca las sesiones vivas) y lockout compartido entre réplicas (tabla en vez del anillo en memoria, `hardening.go:142`) | `cd orbit && go test ./internal/admin -run 'Operator\|Lockout'` verde | control `operations` nuevo (sesión vieja → 401; 11.º intento → 429 desde otro proceso); OR-85 `hecho` | `internal/admin/operators.go` 865 l. (`:305`, `:507-543`); `hardening.go:142` + migración |
| `V-O10` (orbit) | OR-84: lane PG/MySQL para `quarkdatasource` (en su módulo) e `internal/admin` (exige `nucleus/drivers/{postgres,mysql}` en el `go.mod` de la raíz y alinear `drivers/sqlite` v0.1.7 → v0.2.3); cobertura de Vitest como artefacto en una lane no requerida | `cd orbit && (cd quarkdatasource && go test ./...)` verde | las dos lanes nuevas verdes en el PR, por el `name:` que el PR deje escrito: `gh run view "$(gh run list -R jcsvwinston/orbit --workflow ci.yml --branch <rama> --limit 1 --json databaseId --jq '.[0].databaseId')" -R jcsvwinston/orbit --json jobs --jq '[.jobs[] \| select(.name == "<lane quarkdatasource>" or .name == "<lane internal/admin>")] \| length == 2 and all(.conclusion == "success")' \| grep -x true`; artefacto `ui-coverage` presente; OR-84 `hecho` | `.github/workflows/ci.yml:225-268`; `ui/package.json:15`; `go.mod` (+2 `require`) |
| `V-O11` (orbit; docs) | guía por feature (`website/docs/features.md` 1 719 l. partida) y OR-137 (los siete hermanos en `README.md:186-192`), más la prosa de la arista (`README.md:213,219`, `CONTRIBUTING.md:65`, `docs/V1_GATE.md:30`, `ci.yml:314`, `go.work:20`, `quick-start.md:129-131` como «until 2.0», `quarkdatasource/README.md:68`); viaja con cualquier `fix` de orbit (snapshot con la minor) | `cd orbit && bash scripts/ci/check_docs_version_claims.sh && bash scripts/ci/check_docs_product_voice.sh && bash scripts/ci/check_docs_archive_freshness.sh && bash scripts/ci/check_versioned_docs_markers.sh` verde en `main` | `bash scripts/ci/check_docs_version_claims.sh && bash scripts/ci/check_docs_product_voice.sh && bash scripts/ci/check_docs_archive_freshness.sh && bash scripts/ci/check_versioned_docs_markers.sh`; `grep -rn -iE 'six modules\|keeping quark out\|never enters' README.md CONTRIBUTING.md go.work docs .github website/docs \| wc -l` = 0; OR-137 `hecho` | `website/docs/` + `README.md` (224 l.) + 7 líneas |
| `V-O12` (orbit; D23) | el refresco de la matriz de módulos por PR en vez del `git push` del bot (`release-please.yml:108-122`); el PR lo abre un token que dispare CI (`RELEASE_PR_TOKEN`, PAT o GitHub App: ajuste de repo del propietario, «El tren» de «Lo que espera al propietario»; con `GITHUB_TOKEN` el PR del bot no dispara CI y D23 lo deja sin fusionar); el merge lo hace `merge-bot-pr.sh` o el auto-merge cuando D23 lo active (`allow_auto_merge` false hoy en los cuatro) | `cd orbit && bash scripts/ci/gen_module_matrix.sh && git diff --quiet website/docs/reference/module-matrix.md && gh api repos/jcsvwinston/orbit/actions/secrets --jq '.secrets[].name' \| grep -qx RELEASE_PR_TOKEN` (hoy `total_count: 0`: sin el secreto, `V-O12` sólo abre el PR; respondido el 2026-11-16: el secreto lo crea el propietario antes de `V-O12`, con el comando y los permisos del §5 del handoff) | la siguiente release abre el PR `chore(docs): refresh the module matrix` (`gh pr list -R jcsvwinston/orbit --search 'refresh the module matrix'`) | 1 workflow |
| `V-O13` (orbit; docs) | QM-39 mitad orbit: página de benchmarks del panel (presupuesto gzip) y del fleet, con fuente; viaja con un corte | `cd quantum && bash scripts/check_fleet_posture.sh` y el presupuesto del panel (`go test ./ui/ -run TestEmbeddedDist`) verdes | `cd orbit && bash scripts/ci/check_docs_version_claims.sh && bash scripts/ci/check_docs_product_voice.sh && bash scripts/ci/check_docs_archive_freshness.sh && bash scripts/ci/check_versioned_docs_markers.sh && test "$(git ls-files website/docs \| grep -c benchmarks)" -ge 1`; en el PR de set, `cd quantum && grep -q benchmarks website/sidebarsOrbit.ts && bash scripts/check_sidebar_sync.sh` (el sidebar de orbit vive en el paraguas: hoy 0 `benchmark` en `sidebarsOrbit.ts`); QM-39 mitad orbit `hecho` | `website/docs/` (0 hoy) |
| `V-O14` (orbit; D15 · OR-71) | la búsqueda se estrecha a los campos legibles por el operador en vez de rechazarse entera; **sin tocar `datasource.Query`** (congelado: `datasource.go:108-125`, QADR-0010, `contracts/freeze_test.go`): el recorte en `quarkdatasource/store.go:559` + `internal/admin`; D38 h (2026-11-16): sin tocar el contrato `datasource.Query`; si el recorte exigiera un campo nuevo en `Query`, no se hace en 1.x | `cd orbit && go test ./internal/admin -run Search` verde | control nuevo (operador con un campo oculto busca y recibe 200 sin ese campo); `(cd quarkdatasource && go test ./...)`; OR-71 `hecho` | `quarkdatasource/store.go:559`, `internal/admin` |
| `V-O15` (orbit; D15 · OR-75, OR-76; SPA) | el editor de hijos filtra por el padre sin exigir `admin:"filter"` y no manda cadenas vacías (`InlineEditor.tsx:84,137`) | `(cd ui && npm test -- InlineEditor)` verde | los mismos tests + dos casos nuevos; `(cd ui && npm run build && git diff --quiet -- dist)`; OR-75 y OR-76 `hecho` | `InlineEditor.tsx` 204 l. |
| `V-O16` (orbit; prerrequisito de `RD-1o-ui`, no de D17) | OR-126: el fleet sobre los tokens semánticos de `tokens.css` y el `tailwind.config.js` del panel (318 clases `-tN` + 271 tamaños → 0); `fleet-palette.test.ts` reescrito sobre los pares de `tokens.css` para las dos entradas (texto/superficie, acento/superficie, destructivo/su texto) | `(cd internal/fleettest/fleetbench && ORBIT_BENCH_BROWSER=required go test . -run TestFleetBrowserBench -count=1)` verde (UIF-02/06) | `grep -rEo '\b(text\|bg\|border\|ring\|fill\|stroke)-t[0-9]+' ui/src/fleet --include='*.tsx' \| wc -l` = 0; `(cd ui && npm test && npm run build && git diff --quiet -- dist)`; UIF-02/06 verdes; OR-126 `hecho` | 12 páginas + 7 componentes de `ui/src/fleet`; `tailwind.fleet.config.js` 32 l.; `fleet-palette.test.ts` |
| `V-S1` (quantum) | QM-26, QM-27 (`README.md:35,74`), QM-28 (`AUDITORIA_CONTINUA.md:37` → 61), QM-29 (`install.md:45,71`, `certified-sets.md:53`), QM-30 (`quickstart.md:111`), QM-31 (`quickstart.md:40` + `NUCLEUS_PORT`): cifras generadas de una fuente con guard (62.º o `check_why_quantum.sh` ampliado) | `cd quantum && bash scripts/suite-integral.sh` 61/61 al pin | `cd quantum && bash scripts/guard-of-guards.sh && (source scripts/lib/guard-registry.sh; guard_names \| grep -qx umbrella-<nombre>) && test -d tests/guard-fixtures/umbrella-<nombre>` (`<nombre>`, el que el PR deje escrito; `guard_names` está en `guard-registry.sh:390`); los seis ids `hecho` | 6 ficheros; 1 guard |
| `V-S2b` (orbit; **antes de `M1-T-O`**) | `datasource/go.mod` → nucleus v1.36.0 (QM-22) y los 11 pines de `internal/fleettest/go.mod` (7 de la suite: nucleus, quark, server, ui, quarkdatasource, agent, proto; 4 de drivers: `nucleus/drivers/{mysql,postgres,sqlite}`, `quark/drivers/sqlite`; los 11 por detrás del set); `GOWORK=off go mod tidy` en los dos. El corte de `datasource/v1.1.3` y el re-pin de raíz, agent y quarkdatasource los hace el tren de hoy (`align_set.sh --quark-module` o a mano, como en 1.42.0): ni esta sesión ni `M1-T-O` | `cd orbit && bash scripts/ci/check_internal_pins.sh` verde | `cd orbit && (cd datasource && GOWORK=off go build ./... && go vet ./...) && (cd internal/fleettest && GOWORK=off go build ./... && go vet ./...) && bash scripts/ci/check_internal_pins.sh && test "$(awk '$1=="github.com/jcsvwinston/nucleus"{print $2}' datasource/go.mod)" = v1.36.0 && test "$(awk '$1=="github.com/jcsvwinston/nucleus"{print $2}' internal/fleettest/go.mod)" = v1.36.0 && test "$(awk '$1=="github.com/jcsvwinston/quark"{print $2}' internal/fleettest/go.mod)" = v1.19.1 && (cd internal/fleettest && GOWORK=off go mod tidy && git diff --quiet -- go.mod go.sum)` (sin mirar a `manifest-guard` §5 descubierto: eso es `M1-V2-P`(b), después de `M1-T-O`) | 2 `go.mod` (1 + 11 líneas) |
| `V-S3a` (quantum; docs + 1 guard) | D21/D22: QADR nuevo, `website/docs/support.md`, calendario YAML con guard `umbrella-release-calendar` y campos del manifiesto (QM-25); `CADENA_DE_SUMINISTRO.md` al pin (QM-32; QM-34 va a A13 para subir a SLSA L3, D38 e: esta sesión no lo cierra); el `SECURITY.md` del paraguas con la ventana de suite. Primera de las cuatro | `cd quantum && bash scripts/check_deprecations.sh && bash scripts/check_supply_chain.sh` verdes, y D38 rellena (13e decidido el 2026-11-16: L3 en A13): `cd quantum && grep -qE '^[\|] \*\*D38\*\* [\|][^\|]*[\|][^\|]*[\|] \*\*[^\|]*202[67]-[0-9]{2}-[0-9]{2}' docs/planes/quantum-2.0.md` (la 9, dónde se publica la guía, no toca la política ni `support.md`) | `cd quantum && bash scripts/guard-of-guards.sh && (source scripts/lib/guard-registry.sh; guard_names \| grep -qx umbrella-release-calendar) && test -d tests/guard-fixtures/umbrella-release-calendar && bash scripts/check_supply_chain.sh && test -f website/docs/support.md && bash scripts/check_sidebar_sync.sh`; QM-25 y QM-32 `hecho` | `POLITICA_SOPORTE.md` §8 (`:318`), 1 `SECURITY.md`, 1 QADR, 1 guard + fixture, 1 página, 1 YAML |
| `V-S3b` (quark; docs) | `SECURITY.md` con la ventana de suite y el comparador de la tabla de `scripts/check-version-coherence.sh` (`:216,338`) para que la ventana de suite mande (D22) antes de que `M1-D-Q` escriba `v2.0.x`; viaja con el siguiente `fix`/`feat` de quark | `test -f ../quantum/website/docs/support.md` (`V-S3a` fusionada) `&& cd quark && bash scripts/check-version-coherence.sh` verde | `cd quark && bash scripts/check-version-coherence.sh && bash scripts/ci/check_docs_product_voice.sh` | `SECURITY.md` + 1 comparador (2 sitios) |
| `V-S3c` (nucleus; docs) | `SECURITY.md` con la ventana de suite y el canal de respaldo (`SECURITY.md:118-124`, NU-149); viaja con el siguiente `fix`/`feat` de nucleus | `test -f ../quantum/website/docs/support.md` (`V-S3a` fusionada) `&& cd nucleus && make guards` verde | `cd nucleus && make guards`; NU-149 `hecho` | `SECURITY.md` (7 líneas) |
| `V-S3d` (orbit; docs) | `SECURITY.md` con la ventana de suite; viaja con el siguiente `fix`/`feat` de orbit | `test -f ../quantum/website/docs/support.md` (`V-S3a` fusionada) `&& cd orbit && bash scripts/ci/check_docs_product_voice.sh` verde | `cd orbit && bash scripts/ci/check_docs_product_voice.sh && bash scripts/ci/check_docs_version_claims.sh` | `SECURITY.md` |
| `V-S4` (quantum) | Encore y Supabase en la comparativa (QM-38; amplía la tabla de fuentes de `check_why_quantum.sh:14-20`) y la frase del 15 % (QM-44, `why-quantum.md:139`) | `cd quantum && bash scripts/check_why_quantum.sh` verde | `bash scripts/check_why_quantum.sh` verde con las filas nuevas con fuente | `why-quantum.md:9-16,36-49,137-139`; `check_why_quantum.sh` |
| `V-S5` (quantum) | QM-36: el job «Coste frío del quickstart» mide el proxy (`GOWORK=off`, `GOMODCACHE` virgen, como el paso de `go install` de `integration.yml:132`) y publica la cifra | `gh run list -R jcsvwinston/quantum --workflow integration.yml --branch main --limit 1 --json conclusion --jq '.[0].conclusion' \| grep -x success` (el paso «Coste frío del quickstart (sólo informa)», `integration.yml:143-148`, corre hoy `scripts/ci/quickstart_smoke.sh` sin `GOWORK=off` ni `GOMODCACHE` virgen: 0 líneas) | `cd quantum && test "$(grep -cE 'GOWORK=off\|GOMODCACHE=\$\(mktemp' scripts/ci/quickstart_smoke.sh)" -ge 2 && gh run view <run> --log 2>/dev/null \| grep -E '<nombre del step>.*[0-9]+ ?s'` (el nombre del step, el que el PR deje escrito; la cifra con `GOPROXY` por defecto); QM-36 `hecho` | `integration.yml:130-150`; `scripts/ci/quickstart_smoke.sh` |
| `V-S6` (quantum; D23) | el job agregador en las lanes del paraguas (un único check requerido) y los comandos `gh api` de protección que el propietario ejecuta en los cuatro repos (`A12-…:815`) | `gh api repos/jcsvwinston/quantum/branches/main/protection` → 404 (hoy) | `cd quantum && grep -q 'CI Required Gate' .github/workflows/integration.yml && gh run view "$(gh run list -R jcsvwinston/quantum --workflow integration.yml --branch <rama> --limit 1 --json databaseId --jq '.[0].databaseId')" -R jcsvwinston/quantum --json jobs --jq '[.jobs[] \| select(.name == "CI Required Gate")] \| length == 1 and all(.conclusion == "success")' \| grep -x true` (el nombre que `next-session.md:435` ya da al agregador; hoy 0 en los workflows del paraguas; `gh run list --json name` daría el nombre del workflow, no el del job); los comandos `gh api … branches/main/protection` ya están escritos en `next-session.md:436-443` (§5): nada que añadir | 1 workflow |

Orden dentro de la ventana: por repo, cualquier orden salvo `V-O5` →
`V-O6`, `V-S2b` → `M1-T-O` → `M1-V2-P`(b), `V-O16` → `RD-1o-ui`, y las de SPA
en un mismo set; `V-S3a` con D38 (13e) rellena, y `V-S3b…d` tras ella; los
diez hallazgos de D15 en nueve sesiones (`V-Q7`, `V-Q8`, `V-Q9`, `V-N3`,
`V-N4`, `V-N5`, `V-O4`, `V-O14`, `V-O15`; `V-O15` lleva OR-75 y OR-76: 204
líneas del mismo fichero) **antes de `M1`** (D15) y sin orden entre sí.

### El rediseño, carril paralelo (§3.4)

Independiente del major sólo en lo que importa para no bloquearlo: la rama
`dry-run/2.0` no toca `tokens.css`, `appearance.go`, `branding.go` ni
`first_frame_theme.js`. Pero sí toca `ui/src` (5 ficheros, −359) y
reconstruye `ui/dist` (96): el carril y la rama del major reconstruyen el
mismo `dist` y una maqueta de Data Studio sobre 1.x dibuja un panel que el
2.0 borra. Sin maquetas elegidas, el carril no bloquea `M1`; sí deja sin
cumplir los puntos 4 y 5 del §4 tal como están escritos, y el §3.4 dice
«después de lo pendiente (§2)» con las diez cortas de D15 abiertas: las dos
cosas son del propietario (pregunta 12; decidida el 2026-11-16: D37 b, el
2.0.0 se certifica sin tema nuevo si no hay maquetas antes del corte, y
D37 d, `RD-0` arranca ya).

| Sesión | Qué entrega | Lo que espera del propietario | Precondición (comando) | Criterio de hecho (comando) |
|---|---|---|---|---|
| `RD-0` (quantum) | 3 direcciones en HTML autocontenido claro/oscuro (el formato se decide aquí, no se pregunta: como `docs/brand/quantum-brandboard.html`, 459 l., no capturas), cada una con 9 pantallas (login, overview, Data Studio con modelo abierto **sin el `FieldConfigPanel`**, formulario con errores, audit, fleet overview, fleet nodes, portada del sitio, una página de docs con código/admonition/tabla, y el playground); el inventario de tokens (22 + 20 panel, 56 × 2 fleet, 23 sitio, 15 brand board, las 7 + 2 series de gráficos de `widgets.ts:70-78`/`SystemPulsePage.tsx:182-183`, los 5 estados del fleet de `fleet/lib/colors.ts:5-9`, los params del tema de AG Grid `grid.ts:46-50`) con la columna «equivalente en el sistema común»; la medición de contraste de cada maqueta con un instrumento que hoy no existe en el paraguas (traer `@axe-core/cli` desde `orbit/internal/adminbench/browser`, que ya pina `@axe-core/playwright 4.13.0`, o reutilizar el test de paleta de `V-O16`). No decide nada visual. **Puede arrancar ya**, en paralelo a las diez cortas (D37 d, 2026-11-16), y **puede reabrir la marca** (D37 c, contra la recomendación): el brand board deja de ser el límite y una dirección puede proponer una marca nueva | la elección entre maquetas («elegida: <nombre>», anotada en el plan: es la precondición de `RD-1*`) | `test -f docs/brand/quantum-brandboard.html && grep -q '3.4 Rediseño estético' docs/planes/quantum-2.0.md && grep -qE '^[\|] \*\*D37\*\* [\|][^\|]*[\|][^\|]*[\|] \*\*[^\|]*202[67]-[0-9]{2}-[0-9]{2}' docs/planes/quantum-2.0.md` (D37: la 12d, si arranca con las diez cortas abiertas) | PR fusionado; `npx @axe-core/cli docs/brand/<maqueta>.html --rules color-contrast` (el comando que el PR deje escrito) en verde para cada maqueta en claro y oscuro |
| `RD-1o-ui` (orbit; **un PR, un corte de `ui/v1.x`**; requiere `V-O16` y `V-O7` fusionadas) | la clave `branding.look` (defecto `classic`) pintada antes del primer frame por `first_frame_theme.js` como `branding.theme`; segundo conjunto de tokens en `tokens.css` bajo `[data-look]`; `panelTokens[look][theme]` en `appearance.go:79-84` (hoy un espejo a mano de `tokens.css`; un test de paridad Go ↔ CSS antes del segundo conjunto); `themeQuartz.withParams(...)` desde los tokens; tercera app en el driver del banco (como `themed`, `browserbench_test.go:178-233`) y UIX-02/08/09/12/13/17 y UIF-02/06 en ambos looks y temas (sin renumerar: `check_admin_posture` compara el titular); las 10 claves de A11 no cambian. El look del fleet NO está aquí: pregunta 12f, sin medir | maquetas elegidas | `grep -q 'elegida:' docs/planes/A12-rendimiento-reauditoria-cierre.md` (en quantum) `&& cd orbit && test "$(grep -rEo '\b(text\|bg\|border\|ring\|fill\|stroke)-t[0-9]+' ui/src/fleet --include='*.tsx' \| wc -l)" = 0` (`V-O16`) `&& grep -q 'withTags' internal/adminbench/browser/specs/panel.spec.ts` (`V-O7`; hoy 0) `&& (cd internal/adminbench/browser && npm ci && npx playwright install --with-deps chromium) && ORBIT_BENCH_BROWSER=required go test ./internal/adminbench/ -run TestBrowserBench -count=1` | `cd orbit/ui && npm ci && npm run typecheck && npm run lint && npm test && npm run build && git diff --quiet -- dist && cd .. && go test ./ui/ -run TestEmbeddedDist -count=1 && go test ./internal/admin/ -run 'Appearance\|Branding' -count=1 && ORBIT_BENCH_BROWSER=required go test ./internal/adminbench/ -run TestBrowserBench -count=1` (las tres apps del driver: los dos looks) `&& ORBIT_ADMIN_BENCH_TABLE=1 go test ./internal/adminbench -run TestAdminBenchTable && diff internal/adminbench/bench-table.md docs/admin-bench.md`; el presupuesto (400 KiB gzip; 373,4 medido: 26,6 de margen; sin webfonts salvo decisión) |
| `RD-1o-root` (orbit; **el re-pin: segundo corte, raíz y `server`**) | la raíz y `server` requieren el tag de `ui` que contiene el sha de `RD-1o-ui` (`go.mod:39`, `server/go.mod:10`; hoy v1.2.2, sea el nuevo minor o patch) y `website/docs/configuration.md:63-72` documenta `branding.look`; el paraguas re-pina `ui` en `versions.yaml:83` en el PR de set, con `check_admin_posture.sh`/`check_fleet_posture.sh` y `why-quantum.md:105` | — | `t=$(git -C orbit tag --contains <sha de RD-1o-ui> \| grep '^ui/v1\.' \| sort -V \| head -1 \| sed 's#^ui/##') && test -n "$t"` (`RD-1o-ui` publicada en un tag de `ui`) | `cd orbit && t=$(git tag --contains <sha de RD-1o-ui> \| grep '^ui/v1\.' \| sort -V \| head -1 \| sed 's#^ui/##') && grep -q "orbit/ui $t" go.mod && grep -q "orbit/ui $t" server/go.mod && grep -q 'branding.look' website/docs/configuration.md && bash scripts/ci/check_internal_pins.sh`; en el paraguas, al re-pinar: `grep -qE "^[[:space:]]*ui:[[:space:]]+\"$t\"" ../quantum/versions.yaml` |
| `RD-1q` (quantum) | el tema nuevo del sitio: `custom.css` (164 l., 23 propiedades), portada (`index.tsx` 156, `index.module.css` 171), swizzles de Navbar (94), assets de marca en `docs/brand/` y `static/img`; el sitio no es API: sin fase de opción; AA en el sitio = un control nuevo sobre `website/build` (D37 e, 2026-11-16; hoy 0 instrumentos) | maquetas elegidas | `grep -q 'elegida:' docs/planes/A12-rendimiento-reauditoria-cierre.md` y la lane `website-ci` verde en `main` | la secuencia exacta de `website-ci.yml:72-138` en CI (`check_sidebar_sync`, `check_quickstart_cost`, `check_generated_pages`, `build_quark_playground.sh`, `npm run build`, `check_served_jargon`, `check_retired_claims`, `check_built_codeblocks`, `check_built_links`): `gh run list -R jcsvwinston/quantum --workflow website-ci.yml --branch <rama> --json conclusion --jq '.[0].conclusion' \| grep -x success` (Docusaurus no arranca en el sandbox); `bash scripts/check_site_posture.sh && bash scripts/check_why_quantum.sh` en local |
| `RD-2` (orbit; dentro de `M1`, contra la rama del major con `ui/v2`) | el look nuevo pasa a ser el defecto de `branding.look`; `classic` queda como opción; el driver del banco invierte las apps; `configuration.md` y la página «qué cambia en 2.0» lo dicen. **Sin aviso** (D37 a, 2026-11-16: `classic` sigue existiendo y nada se retira, así que no necesita un DEP); y por D37 b, si no hay maquetas elegidas antes del corte, el 2.0.0 se certifica sin tema nuevo y el volteo del defecto pasa al 2.1 (el look nuevo entra como opción en una 2.x) | — (D37 decidida) | `cd quantum && grep -qE '^[\|] \*\*D37\*\* [\|][^\|]*[\|][^\|]*[\|] \*\*[^\|]*202[67]-[0-9]{2}-[0-9]{2}' docs/planes/quantum-2.0.md && t=$(git -C orbit tag --contains <sha de RD-1o-ui> \| grep '^ui/v1\.' \| sort -V \| head -1 \| sed 's#^ui/##') && grep -q "orbit/ui $t" orbit/go.mod && grep -q "orbit/ui $t" orbit/server/go.mod && grep -qE "^[[:space:]]*ui:[[:space:]]+\"$t\"" versions.yaml` (`RD-1o-root` al pin: el tag de `ui` que contiene el sha de `RD-1o-ui`, sea minor o patch; hoy `versions.yaml:83` lleva catorce espacios tras `ui:` y `go.mod:39` v1.2.2, así que ninguna cifra va fija) | el mismo comando que `RD-1o-ui`; `test "$(git -C orbit diff --stat <base>..HEAD -- docs/deprecations \| wc -l)" = 0` (ningún DEP nuevo) si 12a dice «sin aviso»; el conflicto del `dist` reconstruido con la rama del major rebasado |

Dos cosas que ninguna sesión del carril entrega y alguien tiene que
poseer: la página «qué cambia en 2.0», el snapshot 2.0 de los docs y el
enlace a la guía desde la portada (§3.4, §4.5) van en `M1-G-S`/`M1-G-P`(b);
y el criterio «AA en los dos temas con el tema nuevo» (§4.4) se mediría con
el instrumento parcial que `R1` puntuó con 4 (reglas elegidas, 7 tests, un
viewport): `V-O7` lo completa antes de `RD-1o-ui`.

### Lo que `M1-S0` no pudo medir sin publicar

- Lo que release-please propone de verdad para los 24 paquetes v0.x con un
  `!` (`release-please release-pr --dry-run` exige token y una rama con el
  `!`); y si `Release-As: 2.0.0` en el footer los fija a todos (se infiere
  de `scripts/train/README.md:616-627` y del precedente de `quarkbridge`).
- Cuánto tarda `sum.golang.org` en servir una ruta `/v2` recién publicada
  (hoy 404; la espera de 30 min de `align-orbit-pins.sh` es una suposición
  de v1) y si una pseudo-versión `/v2` resuelve en el proxy desde una rama
  que no es `main` (depende de que ese commit ya lleve `/v2` en el `go.mod`).
- Las lanes `GOWORK=off` y `go mod tidy` por módulo antes del tag; el
  comportamiento de `{{ .ModulePath }}` de goreleaser con `dir: ./cmd/quark`;
  el efecto real del corte con seis módulos nacidos en el mismo tag
  (GoReleaser + `release.yml`); el experimento de `extra-files` de
  release-please escribiendo el `require` de `quarkdatasource` en la raíz.
- Lo que exige Docker, Playwright, npm o Docusaurus en local: `make
  test-all`, `make superapp`, los bancos de motor, el banco de navegador
  (sin Playwright se salta y registra lo grabado), Vitest (la cifra
  «221/221» es de `R1`, no del pin), `npm run build` (Docusaurus no arranca
  en el sandbox), `check_hello_size.sh` (`mktemp` + `-mod=mod`: 75/88 se
  deduce del grafo y coincide con `M0-E`).
- Si las tres fixtures que doctoran con `pkg/model.InventedByGuardOfGuards…`
  muerden al pin 2.0 (sólo corren contra el árbol pinado); cuántas páginas
  de nucleus llevan `covers:` sobre símbolos retirados (necesita el
  baseline del 2.0); si `go test ./...` ensucia `go.work.sum` en orbit hoy
  (OR-138).
- Cuántos módulos añade D11 al grafo de una aplicación que requiere la raíz
  de orbit (`GOWORK=off go list -m all` falló sin red por
  `golang.org/x/xerrors`); si `align-orbit-pins`/`orbit-converge` mueven el
  pin de `ui` (no lo nombran); el peso gzip de un segundo conjunto de
  tokens; la superficie de configuración de un look en el módulo `server`.
- El «764» del §3.5 (ficheros no-Go de quark): no se reproduce con ningún
  comando; se sustituye por «122 rastreados».
- Tiempos: el plan lo prohíbe y no se estiman.

### Lo que espera al propietario

**Respondidas el 2026-11-16, una a una** (la misma tarde; la columna
«Decisión de Carlos» del bloque `M1-S0` del §3.3 del contrato lleva el
texto literal con su fecha; ★ = contra la recomendación): 1 → D26
Release-As en el commit `!`; 2 → D27 rama `major/2.0` por repo con merge
commit; 3 → D28 construir el lint; 4 → D29 las tres correcciones comparten
la ventana del aviso que retira sus tipos; 5 → D30 ★ `App.AutoMigrate` NO
se queda: migra a quark en el 2.0, con un aviso nuevo DEP-2026-027 de
nucleus (fila 35 del §3.0, `por escribir`, sesión `V-N-AM`), y si lo publica
el set del 2026-11-23 el suelo del 2.0 pasa al 2027-02-21; 6 → D31 rebajar
la promesa de DEP-2026-014; 7 → D32 el experimento con `extra-files`
primero; 8 → D33 descartar por escrito el último tag v1; 9 → D34 una
página en `/start/migrating-to-2.0` + `docs/MIGRATION_v2.0.0.md` como
puntero; 10 → D35 ★ declarar el lag de los drivers en `cmd/quark` y
`cmd/nucleus` (`declared_lags` de `versions.yaml`; sin segunda pasada ni
segundo tag); 11 → D36 `versions.yaml` por red con caída a la tabla; 12 →
D37 (a) sin aviso, (b) sin maquetas antes del corte el 2.0.0 se certifica
con la página «qué cambia» y la guía, y el rediseño es opción en una 2.x
y defecto en el 2.1, (c) ★ reabrir la marca, (d) `RD-0` arranca ya, (e) AA en
el sitio sí, (f) medir primero la superficie del `server`; 13 → D38 (a)
QK-71 a A13, (b) MIG-05 sólo opt-in, (c) QM-37 retirar el punto, (d) ★
OR-94 y EXPLAIN desde el feed a A13, (e) ★ QM-34 subir a L3 en A13, (f) lo
largo a A13, (g) ★ PG-01…04/MY-01 retitular el criterio a lo medido, (h)
OR-71 sin tocar `datasource.Query`, (i) ★ QK-54 COPY a A13, (j) ★ NU-150
retitular el criterio de `N1` a ≤ 27 MB. Y el ajuste de repo: el secreto
`RELEASE_PR_TOKEN` de orbit lo crea el propietario antes de `V-O12` (el
comando y los permisos, en el §5 del handoff). Las consecuencias están
escritas en las tablas de esta sección y en «La ventana hasta el 2.0».

Sólo lo que salió de medir y no decide una sesión (README de planes §2).
Cada una con recomendación; ninguna reabre D1…D25. Cada pregunta tiene su
fila en el bloque `M1-S0` del §3.3 del contrato (delta (c): 1 → D26, 2 →
D27, 3 → D28, 4 → D29, 5 → D30, 6 → D31, 7 → D32, 8 → D33, 9 → D34, 10 →
D35, 11 → D36, 12 → D37, 13 → D38), con la columna «Decisión de Carlos»
vacía; la respuesta se escribe ahí con su fecha, como D1…D25, y la
precondición que depende de ella la comprueba con
`grep -qE '^[|] \*\*D<n>\*\* [|][^|]*[|][^|]*[|]
\*\*[^|]*202[67]-[0-9]{2}-[0-9]{2}' docs/planes/quantum-2.0.md`
(la forma de las 25 filas decididas: 25 de 25 casan hoy con ese regex).

**Las que condicionan `M1`** (D26 y D27 sin respuesta: el primer commit del
major, `M1-V2-Q`(1), no se escribe; D28 delante de `M1-T-LINT-*`; D29…D33
delante de la sesión que cada una cita):

1. **El número 2.0.0 en los 24 módulos v0.x.** §3.5 ya decide que todos pasan
   a `/v2` en lockstep; falta el mecanismo. (a) Footer `Release-As: 2.0.0` en
   el cuerpo del squash del commit `!` de cada repo: uno por repo, sin tocar
   la configuración, nada que retirar después; ADR-032 y el README del tren
   vetan `Release-As` para SUPLIR un `!`, no para fijar el número junto a él.
   (b) `release-as: "2.0.0"` en los 24 paquetes de los tres
   `release-please-config.json` dentro del PR `!` + un `chore` que lo quite
   tras el corte (si se olvida, el siguiente corte de cada módulo vuelve a
   publicar 2.0.0). (c) Plugin `linked-versions` por repo: los 33 módulos en
   lockstep para siempre (cambio de política fuera de QADR-0002).
   **Recomendación: (a)**,
   con el manifiesto del release PR revisado antes de fusionarlo (criterio de
   `M1-TREN`). Es D26.
2. **Cómo aterriza el major en `main` y cómo se llama la rama.** (a) Una rama
   `major/2.0` por repo donde se fusionan los PRs de `M1` (CI en PRs contra
   ella: `M1-T-Q`/`M1-T-N`) y un merge final a `main` (squash = un commit y
   un CHANGELOG de una línea; merge commit = todos los commits; los cuatro
   repos permiten ambos); (b) sin rama: `main` se vuelve 2.0 el día del
   primer `!` y las demás sesiones de `M1` aterrizan bajo un release PR
   abierto. Desde el primer MERGE de un `!` en `main` no sale ningún set
   1.x (`release-please.yml` `branches: [main]` en los tres): con (a) los
   sets 1.x siguen saliendo mientras viva la rama —es precisamente lo que
   la recomendación compra—; con (b), desde el primer `!`. D21/D22 (sin
   LTS) dicen que no hay rama `release/1.x`. Las precondiciones entre repos
   (`M1-V2-N`, `M1-V2-O`, `M1-AD-O`, `M1-TREN`) miran
   `origin/<rama del major>` del hermano: `main` si la respuesta es (b).
   **Recomendación: (a) con merge commit**, los tres `!` seguidos tras el
   último set 1.x certificado, y sin rama `release/1.x`. Es D27.
3. **El lint del `!` de ADR-032 regla 2**: construirlo (`M1-T-LINT-Q/N/O/P`,
   cuatro PRs, excepción por rama del major) o corregir el ADR (l.53-54).
   **Recomendación: construirlo**, porque QADR-0002 hace que un `!` colado
   en 1.x adelante el major de la suite y hoy la única señal es el título
   del release PR, que llega tarde. Es D28.
4. **Tres correcciones de avisos ya publicados amplían lo que el aviso dice
   que rompe**: DEP-2026-025 l.54 («Not affected: … NewRedisRelay and
   RedisRelay»; el major retipa los cuatro métodos), DEP-2026-024
   (`hooks.NewSQLObserver` cambia de firma, `sql.go:69`) y orbit DEP-2026-002
   (`agent.Config.Registry`/`Databases` se retiran). Las firmas cambian
   porque sus tipos son los que esos avisos retiran, pero
   `POLITICA_DEPRECACION.md` §3 (l.109-113) sólo exime de ventana el
   empaquetado y lo experimental —no hay línea que cubra una firma pública
   que cambia—, un usuario que leyó «Not affected» tendría menos de 90 días
   desde la corrección, y el §5 del contrato (l.439) deja mover la fecha del
   2.0 a Carlos. (a) Comparten la ventana del aviso que retira sus tipos: la
   corrección se publica en `M1-G-N`/`M1-G-O` con su fecha y la regla se
   escribe como enmienda del §3 de la política; nada se mueve. (b) Abren
   aviso propio: ventana ≥ 90 días desde el set que lo publique (≥
   2027-02-2x si sale en el set siguiente), y con ella se mueven `RD-2` y
   esas tres retiradas (`M1-R-N6`, `M1-PM-N`, `M1-AD-O`); o los tres símbolos
   quedan en el 2.0 sobre una capa de adaptación hasta el 3.0.
   **Recomendación: (a)**, con la razón medida: los tipos retirados son los
   de DEP-024/025 y orbit DEP-002, no rupturas nuevas. Es D29.
5. **`App.AutoMigrate` en el 2.0**: queda público leyendo la gramática `db:`
   de `pkg/model` desde `internal/model` (así lo deja la rama; no toca el
   registro). Retirarlo o retiparlo necesita un aviso que no cabe antes del
   2027-02-07. **Recomendación: queda como está, anotado como deuda del 3.0.**
   Es D30.
6. **DEP-2026-014 («ni siquiera se le preguntan sus capacidades»)**: un
   parámetro de política aditivo en `DiscoverExternal`/`Host.CollectInventory`
   en 1.x, o rebajar la promesa a «denegado, aunque sondeado». Orbit no los
   usa (0). **Recomendación: rebajar la promesa** (`M1-G-N`); el parámetro, si
   alguien lo pide, es aditivo en cualquier 1.x o 2.x. Es D31.
7. **La arista nueva raíz → `quarkdatasource` (D11)**: tolerancia en
   `check_internal_pins.sh` (ADR-006 l.97 dice que no), corte de convergencia
   de la raíz tras cada tag de `quarkdatasource` (7 extra desde el
   2026-09-22, medido sobre los tags), o el
   experimento con `extra-files` de release-please sobre la arista raíz → `ui`
   en 1.x. **Recomendación: el experimento primero**; si funciona, ADR-006
   l.97 se mantiene y no hay tolerancia; si no, converger (el tren ya lo hace
   con `ui`/`datasource`/`proto`). Es D32.
8. **Un último tag v1 con `// Deprecated: use …/v2`** en el `go.mod` de cada
   pilar (lo único que avisa a `go get @latest` sobre la ruta v1; contradice
   `POLITICA_SOPORTE.md:62,240`). **Recomendación: descartarlo por escrito**; la
   sección fija de la guía lo dice (`M1-G-P`(a)). Es D33.

Nota (no es pregunta): la regla D2 de `POLITICA_DEPRECACION.md` §4 (volteo
a `completed` al vencer la fecha; APROBADA el 2026-09-09, l.139: «La
deprecación pasa a `completed` en su aviso y espera al major en esa lista»)
se aplica tal como está: quark 001/002 el 2026-12-08, nucleus 011…018 el
2027-01-02, quark 003 y nucleus 009 el 2027-01-04, nucleus 003/019…026 y
orbit 001/002 el 2027-01-17 (`M1-G-F1…F5`, una fila por repo y fecha, en el
tramo 1.x), y quark 004…011 y orbit 003…005 el 2027-02-07 si el 2.0.0 no se
ha cortado ese día. `check_deprecations.sh:339` ya lee `completed` (toma la
palabra entre acentos y tolera el paréntesis), la pieza que faltaba es el
generador por versión de ventana (`M1-G-P`(a), antes del set posterior al
2026-12-08), y el volteo por vencimiento (`Status: completed` a secas) lleva
forma distinta de la aplicación en el major (`… (applied on <rama>, fecha;
the v2.0.0 tag publishes it)`, la forma de nucleus en la rama), para que
ninguna precondición de `M1-R-*`/`M1-D-*`/`M1-TREN` confunda vencer con
aplicar. No es la D2 del §3.3 del contrato (DEP-2026-003 de nucleus, las
filas de política de 3 columnas, fechada al 2.0). Si Carlos quisiera
enmendar la regla aprobada («`active` hasta el commit del major»), es suya
(README de planes §2); no se recomienda.

**La guía y los docs:**

9. **Dónde se publica la guía**: una página en `/start/migrating-to-2.0`
   (categoría «Migration guides» de `sidebarsStart.ts`, ~2 700 líneas) o una
   por producto bajo `/quark`, `/nucleus`, `/orbit` (cambia el `--check` y el
   snapshot de cada producto); y si `quark/README.md:24` cumple su promesa
   literal con `docs/MIGRATION_v2.0.0.md` (puntero a la guía) o se reescribe.
   **Recomendación: una página en `start` + `MIGRATION_v2.0.0.md` como
   puntero.** Es D34.

**El tren:**

10. **Los suelos de los drivers en `cmd/quark` y `cmd/nucleus`** (QK-72/NU-147:
    v0.2.0 frente a v0.3.3; v0.1.8 frente a v0.1.13 y v0.2.3): una segunda
    pasada de suelos y un segundo tag del CLI por tren, o declarar el lag.
    La mitad «raíz» no es decisión (anotación de release-please, `M1-T-Q`).
    **Recomendación: la segunda pasada** (`M1-T-P`), porque bajo `/v2` un CLI
    que requiera un driver `v2.0.0-…` rancio es un `go install` roto. Es D35.
11. **`nucleus add|new` y la versión de orbit del set** (NU-143): el CLI de
    nucleus se taggea antes que orbit, así que una tabla embebida nunca lleva
    la versión del MISMO set; o lee `versions.yaml` del paraguas por red (con
    caída a la tabla) o acepta «el set anterior». **Recomendación: red con
    caída a la tabla.** Es D36.

Ajuste de repo, no decisión (README de planes §2: los secretos son del
propietario): un secreto `RELEASE_PR_TOKEN` (PAT o GitHub App) en orbit para
que el PR de refresco de la matriz de módulos (`V-O12`) dispare CI; con
`GITHUB_TOKEN` el PR del bot no dispara CI y D23 (gate requerido) lo deja
sin fusionar; sin el secreto, `V-O12` sólo puede abrir el PR y
`merge-bot-pr.sh` lo fusiona a mano. Comprobable: `gh api
repos/jcsvwinston/orbit/actions/secrets --jq '.secrets[].name' | grep -qx
RELEASE_PR_TOKEN` (hoy `{"total_count":0,"secrets":[]}`).

**El rediseño (§3.4):**

12. (a) ¿Un defecto visual que cambia es un volteo con aviso, como
    `CheckVersions()`? Si sí, `RD-2` pasa al 2.1. **Recomendación: sin aviso
    (`classic` sigue existiendo y nada se retira), escrito en el contrato.**
    (b) Sin maquetas antes del corte: ¿el §4.4/§4.5 se cumple con la página
    «qué cambia en 2.0» sin tema nuevo, o se pospone el criterio al 2.1?
    (c) ¿Las direcciones parten de «el estado fijado» o reabren la marca?
    (d) ¿`RD-0` arranca con las diez cortas de D15 abiertas (§3.4 lo pone
    «después del §2»)? (e) ¿AA en el sitio del paraguas (hoy 0 instrumentos;
    un control nuevo sobre `website/build`)? (f) ¿El look del fleet se
    configura en el `server` o es el del build? Hoy el `server` sirve el SPA
    sin inyección (`server.go:589`) y el tema sale de
    `localStorage['orbit.theme']` (`fleet/App.tsx:64-68`): hace falta una
    superficie de configuración nueva (flag del server o defecto de build)
    que nadie ha medido; **sin medir: no es sesión hasta que se mida la
    superficie del `server`**, y por eso no está en la tabla del carril.
    (Decidido en la propuesta y
    fuera de la lista: tres direcciones en HTML autocontenido, como
    `docs/brand/quantum-brandboard.html`, no capturas.) Es D37 (una fila con
    las letras (a)…(f)).

**La ventana (D17):**

13. (a) QK-71 decimal: dependencia (`shopspring/decimal`) o tipo propio; ¿A13?
    (b) MIG-05: sólo opt-in en 1.x (por defecto sería un volteo sin aviso) o
    retitular el punto del 5. (c) QM-37: retirar el punto (los snapshots no
    se reescriben por política) o reescribir los siete enlaces. (d) OR-94
    frente a ADR-007:118 (enmienda en el mismo PR) y EXPLAIN desde el feed
    (seam en el contrato `datasource` congelado: tag + segundo corte, o
    fuera de 1.x). (e) QM-34: decir «SLSA Build L2» o subir a L3 (otro
    builder, A13). (f) Lo largo que la ventana no cubre (WebAuthn, 2FA de
    operadores, impersonación, M2M y 25 tipos, keyring, RLS nativa
    MSSQL/Oracle, sharding + tenant): A13 o alguno en la ventana. (g)
    PG-01…04/MY-01 dentro del 15 %: A13 o retitular a lo medido. (h) OR-71
    sin tocar `datasource.Query` (congelado) o con campo nuevo + tag +
    segundo corte. (i) QK-54: alcance de COPY (API aparte, sin RLS ni
    reglas; el banco dice que no es la misma operación). (j) NU-150: techo
    de la lane al criterio (≤ 25 MB) o criterio retitulado. Decididas en la
    propuesta y fuera de esta lista (README de planes §2: son de sesión):
    `quarktest` por DSN del entorno con `Skip`, sin testcontainers (`V-Q6`);
    la guarda de pprof en 1.x ya existe (la línea ERROR de DEP-018 y el
    comentario del starter `api`: sin fila); OR-126 en `V-O16` como
    prerrequisito de `RD-1o-ui`, no con el rediseño; NU-154 en la ventana
    (`V-N9`); `V-S3` como cuatro sesiones `V-S3a…d`, una por PR. Es D38 (una
    fila con
    las letras (a)…(j)).

**Y una que ya no es decisión**: Discussions en quantum está activo
(comprobado el 2026-11-16: `gh api repos/jcsvwinston/quantum --jq
.has_discussions` → true; la fecha del clic no sale de ningún comando);
QM-42 pasó a `hecho` en quantum#324
(el mismo día, antes de este PR) y la fila 2 de «Lo del propietario» pasa
a «hecho» aquí. El «clic» de D24 era
exactamente eso: GitHub → `jcsvwinston/quantum` → Settings → General →
Features → Discussions; sólo en el paraguas, no en los productos
(`false` en los tres), y no mueve ninguna nota (comunidad está fuera del
gate).

## La ventana hasta el 2.0 — decidida el 2026-11-16

> Quantum 1.45.0 (2026-11-16) publica `D9-N` y `D10-O`, lo último que la
> precondición de `M1` esperaba. Ese día la sesión midió dónde está el arco
> y qué falta para el 5 de 5 y para empezar el 2.0, y Carlos tomó una a una
> las doce decisiones que salieron de esa medición: el bloque D14…D25 del
> §3.3 del [contrato del 2.0](quantum-2.0.md). Lo que cambian en este plan:

- **La secuencia** (actualizada el 2026-11-16 al cerrar `M1-S0`): `M1-S0`
  (hecha) → en paralelo y por repo, en sets 1.x: las diez «sesiones cortas»
  del §2.2 del contrato (D15), lo aditivo de las 32 dimensiones que `M1-S0`
  marcó como corto (42 sesiones `V-*`, D17; QADR-0010: nada rompiente) y el
  tramo 1.x del troceado de `M1` —lo que el paraguas, los guards y el tren
  aprenden de la ruta `/v2` y del tercer pin (`M1-V2-P`, `M1-T-P`, `M1-T-O`,
  `M1-T-N`, `M1-T-Q`; `M1-T-LINT-Q/N/O/P` según D28), el generador de la guía
  por versión de ventana (`M1-G-P`, antes del set posterior al 2026-12-08),
  las correcciones de los avisos (`M1-G-Q/N/O`) y los volteos a `completed` al
  vencer cada fecha (`M1-G-F1…F5`)—; D26 y D27 (bloque `M1-S0` del §3.3 del
  contrato) → `M1` en enero de 2027, lo más tarde posible para no rebasar el
  major: el primer commit del major de cada repo es la ruta `/v2` (`M1-V2-Q` →
  `M1-V2-N` → `M1-V2-O`) y lo demás va por grupo de ficheros → `M1-TREN` →
  2.0.0 no antes del 2027-02-07 (desde el primer merge de un `!` en `main` no
  sale ningún set 1.x) → `R2` completa, como `R1` (D18) → A13 con lo que `R2`
  deje por debajo del 5. Con eso A12 se cierra con el 2.0 certificado y con la
  lista exacta de A13, no con el 5 de 5. El rediseño (§3.4) es un carril
  aparte (`RD-0 → RD-1o-ui → RD-1o-root ∥ RD-1q → RD-2`) que espera las
  maquetas y no bloquea `M1`, pero sin él los puntos 4 y 5 del §4 no se
  cumplen tal como están escritos.
- **2026-11-16, D26…D38** (las trece, una a una, la misma tarde; «Lo que
  espera al propietario» lleva la lista): la secuencia resultante es, antes
  del set del 2026-11-23, el aviso DEP-2026-027 de nucleus (sesión `V-N-AM`,
  nueva en la tabla de la ventana: escribe el aviso de D30 —`App.AutoMigrate`
  migra a quark en el 2.0— con su salida en 1.x, que ya existe:
  `makemigrations`); si ese set lo publica, su ventana abre el 2027-02-21 y
  **el suelo del 2.0 pasa al 2027-02-21** (una semana más por cada set que se
  retrase). Lo demás no mueve fechas: Release-As en el commit `!` (D26) y
  rama `major/2.0` con merge commit (D27) delante de `M1-V2-Q`(1); el lint
  se construye (D28); las tres correcciones comparten ventana (D29); el lag
  de los CLIs se declara en `versions.yaml` sin segunda pasada (D35, `M1-T-P`
  recortada); `RD-0` arranca ya y puede reabrir la marca (D37 c/d), sin aviso
  para el defecto visual (D37 a) y con el 2.0.0 certificable sin tema nuevo
  (D37 b); y la ventana se recorta hacia A13: QK-71, OR-94 y EXPLAIN desde el
  feed, QM-34 (L3), QK-54 (COPY, `V-Q7` fuera) y lo largo (D38 a/d/e/f/i),
  con QM-37 retirado (D38 c), MIG-05 sólo opt-in (D38 b), OR-71 sin tocar
  `datasource.Query` (D38 h) y dos criterios retitulados a lo medido: el
  15 % (D38 g, hecho en el mismo PR) y el ≤ 25 MB de `N1`, que pasa a ≤ 27
  MB (D38 j, `V-N6`).
- **Lo que `M1-S0` midió y dejó escrito** (2026-11-16; sección «`M1-S0` — el
  major, medido y troceado»; esta viñeta decía 39 `go.mod`, unas 2 100 líneas
  y 48 símbolos, las cifras de `M0-E` y `S0`): la ruta `/v2` (§3.5 del
  contrato, corregido: 41 `go.mod` y 2 156 líneas de import; las plantillas
  del starter, el catálogo de `nucleus add` y los lectores de ruta del
  paraguas, de los que cinco callan con `/v2` y nueve mueren), las retiradas y
  los volteos de las 34 filas del §3.0 (30 ensayadas en `dry-run/2.0`, 4 sin
  commit) y los 36 + 13 símbolos de `pkg/model` con el adaptador
  `datasource/nucleus` de orbit, asynq fuera del root (4 módulos se van;
  go-redis se queda), D11 en el paraguas (`check_internal_pins`, `align_set`,
  `bump-set`; 7 cortes de convergencia, no 13), la guía de migración (vacía
  con avisos `completed` si el generador no cambia) y el tren de cuatro repos
  que certifique 2.0.0; el troceado de `M1` (23 sesiones más el tren, con un
  tramo 1.x de 18 delante); la lista de lo aditivo de las 32 que entra en la
  ventana (64 elementos en 42 sesiones `V-*`, D17); y el rediseño estético
  (§3.4 del contrato) como carril paralelo (`RD-0 → RD-1o-ui → RD-1o-root ∥
  RD-1q → RD-2`) que espera las maquetas de Carlos.
- **Dos trampas de calendario**: la excepción de govulncheck para GO-2026-6909
  en la lane SAML de nucleus caduca el 2026-12-31, antes del suelo del 2.0
  (D19: esperar al registro de la base de datos de Go, que golang/vulndb#6909
  dejó pendiente de publicar el 2026-11-15; si el 2026-12-15 no está, un chore
  PR en nucleus la mueve al 2027-03-31); y la lane semanal corre sobre 1.45.0
  desde la corrida que dispare después de la fusión de quantum#319 (05:58 UTC
  del 2026-11-16): el cron del lunes 2026-11-16 no había disparado a las 08:30
  UTC, y los cuatro lunes anteriores disparó entre las 11:51 y las 14:55 UTC.
- **Lo que no es código y también entra en la ventana**: la política de
  soporte publicada sin LTS y con la ventana de suite mandando sobre las
  cuatro `SECURITY.md` (D21, D22: una sesión de docs con calendario YAML,
  guard y campos del manifiesto); la protección de `main` en los cuatro repos
  como la de nucleus, con auto-merge (D23; antes, el PR de orbit que lleva el
  refresco de la matriz de módulos a un PR); Discussions sólo en quantum (D24:
  comprobado activo el 2026-11-16 con `gh api repos/jcsvwinston/quantum --jq
  .has_discussions` → true; QM-42 hecho, quantum#324); la nota de Scorecard
  publicada (D25); y el guard `umbrella-migration-guide` sobre la guía
  regenerada en 1.45.0 (D14, quantum#321).
- **Lo que se corrigió en la prosa ese mismo día** (un verificador cruzó la
  respuesta contra los ficheros): la fila 27 y D6 del contrato decían «topics
  tipados de ciclo de vida» cuando `M0-N` midió que no se construyen y
  DEP-2026-025 dice que se van con `pkg/model` (D20); la ruta `/v2` figuraba a
  la vez «en sets 1.x antes de `M1`» y como «primer commit del major» (vale lo
  segundo, §3.5); la fila de `M0` decía que `pkg/model` «no se retira en el
  2.0» (era la medición de `M0-S0`; D5 lo retira); la de `D10-O` preveía un
  `fix` de la raíz de orbit y cortó MINOR (v1.22.0: release-please atribuye a
  la raíz el `feat` de orbit#597 por sus ficheros fuera de `quarkdatasource/`,
  `go.work.sum` y `website/docs/features.md`); y la política de estabilidad
  del contrato de extensión de quark no estaba «pendiente de aprobación»:
  Carlos la adoptó el 2026-10-06 (ADR 0029 de quark).

## Lo del propietario — en paralelo a `M0-R` (2026-10-27)

> Decisión de Carlos del 2026-10-27, al fusionar `R1`: lo que la
> re-auditoría nombra como «ajuste del propietario» no frena el arco. Se
> anota aquí, en paralelo a `M0-R`, para que ninguna sesión lo vuelva a
> descubrir ni lo confunda con un defecto del código. Ninguno es
> precondición de `M0-R` ni de `M1`; todos van **antes de `R2`**, que es
> cuando se re-puntúan. Las tres respuestas pendientes (ítems 2, 3 y 4)
> las da Carlos en una línea cada una; la sesión que las reciba rellena la
> columna «Decisión», pasa el estado y ejecuta lo que toque. Respondidas el
> 2026-11-16 (ítem 2: D24; ítem 4: D21 y D22); el ítem 3 ya estaba adoptado
> desde el 2026-10-06 (ADR 0029 de quark).

| # | Ítem | Hallazgo | Qué es y quién lo hace | Decisión de Carlos | Estado |
|---|---|---|---|---|---|
| 1 | «Private vulnerability reporting» en quantum, nucleus y orbit | NU-149 (P3) | Ajuste en GitHub (Settings → Code security → Private vulnerability reporting): tres clics de Carlos; no mueve ninguna nota por sí solo. La parte de código —que `nucleus/SECURITY.md` nombre un canal de respaldo— la hace cualquier sesión (`M0-R` o la de docs del ítem 4) | no requiere | **hecho** (activo en los cuatro repos; comprobado el 2026-11-16 con `gh api`); la parte de código —el canal de respaldo en `nucleus/SECURITY.md`— va con el ítem 4 |
| 2 | Discussions en los cuatro repos | QM-42 (P3); QM-13 | Ajuste en GitHub. Comunidad está fuera del gate por decisión del propietario, así que no cambia el veredicto. Si es «sí», cuatro clics; si es «no», QM-42 pasa a `decisión` y QM-13 (que decía hecho) se corrige en el registro | **sólo en quantum** (D24, 2026-11-16) | **hecho** (activado en `jcsvwinston/quantum`; comprobado el 2026-11-16 con `gh api repos/jcsvwinston/quantum --jq .has_discussions` → true; false en los tres productos, como dice D24); QM-42 pasó a `hecho` (quantum#324) y QM-13 lleva el clic como evidencia |
| 3 | La política de estabilidad del contrato de extensión de quark | quark · ecosistema 4,5 (A11 `Q6`, quark#443; con QK-72 y NU-147) | Aprobar la política de compatibilidad que quark#443 dejó como «propuesta pendiente de la decisión del propietario» en tres sitios: la nota de la página del contrato (`quark/website/docs/reference/extension-contract.mdx`), `docs/playbooks/dialects.md` y `CONTRIBUTING.md`. Con el visto bueno es un PR pequeño en quark (las tres notas pasan de propuesta a adoptada) que cabe en el set 1.x de `M0-R`. **Es el único de la lista que mueve el gate**: el medio punto de quark · ecosistema | **adoptada el 2026-10-06** (ADR 0029 de quark, `accepted`; la fila de `Q6` del plan de A11 seguía diciendo «propuesta» y se corrigió el 2026-11-16) | hecho |
| 4 | La política de soporte: los números del §3 y el plan de adopción del §8 | QM-25 (P3) | `docs/gobernanza/POLITICA_SOPORTE.md` lleva trece sets como borrador. Carlos decide los números del §3; después, ejecutar el §8 es una **sesión de docs propia** (un QADR nuevo —QADR-0010 está ocupado, D21—; `quantum/SECURITY.md`; los tres `SECURITY.md` de producto alineados a la ventana de suite; `website/docs/support.md` con el calendario del §7.2) que cabe entre `M0-R` y `M1` sin tocar el tren: sólo documentación, ningún pilar corta por ella | **publicar ya, sin LTS, con la ventana de suite mandando sobre los tres** (D21 y D22, 2026-11-16) | sesión de docs pendiente, en la ventana |
| 5 | Protección de rama en `main` de los cuatro repos | QM-33 (P3; es lo que más pesa en el Scorecard) | Ajuste en GitHub de Carlos. Los scripts del tren no empujan a `main` (sólo `--force-with-lease` sobre la rama del bot de release-please), así que no lo rompe. **Trampa**: exigir revisiones aprobadas bloquearía todos los merges (un solo humano, y GitHub no deja aprobar el propio PR); «rama al día» rompe la pila de PRs con squash. Checks obligatorios sí; revisiones obligatorias y «rama al día», no | **los cuatro como nucleus, con auto-merge** (D23, 2026-11-16): la forma de nucleus incluye «rama al día»; la trampa de la pila con squash de esta fila se conduce rebasando cada PR apilado antes de fusionarlo | pendiente: el PR de orbit (el refresco de la matriz por PR), un job agregador en las lanes del paraguas y los ajustes del propietario con los comandos que la sesión prepare (D23) |

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
| M0 | **hecha** 2026-10-23, publicada entera en Quantum 1.43.0 (2026-11-07: 34 de 34 filas del §3.0 `publicado`) — `M0-S0`, `M0-G`, `M0-N` y `M0-Q` 2026-10-16, `M0-O` 2026-10-18 (en 1.42.0), `M0-E` 2026-10-23; dos salvedades que `M1` hereda (las siete filas de quark `en main`; la DX al 5, los `fix` de 1.x y D9…D11 antes de `M1`, y la ruta `/v2` como primer commit del major) | quantum#284 (`M0-S0`), quantum#285 (`M0-G`), nucleus#630 (`M0-N`), quark#470 y quark#471 (`M0-Q`) | el inventario del major contado al pin de 1.41.0 (12 marcas que el guard ve, 7 avisos de volteo que no ve, 9 volteos decididos sin aviso, 1 aviso sin fecha, orbit sin `docs/deprecations/`); los «~14 sitios» de orbit son 2 llamadas a `NewWrapResponseWriter` más una decisión sobre `authz.New`; el bus único ya es `signals.Bus` y lo que sobra es su puerta sin tipo; `pkg/model` sostiene el adaptador de orbit (6 ficheros, 3 módulos) —lo que midió `M0-S0`; D5 decidió retirarlo en el 2.0 y D5b retira el adaptador con él—; el sobre no tiene opción de quedarse. `M0` troceado en `M0-Q` ∥ `M0-N` ∥ `M0-G` → `M0-O` → `M0-E`; ocho decisiones D1…D8 escritas como propuesta en `quantum-2.0.md` §3.3 |
| M0-Q | **hecha** 2026-10-16 | quark#470, quark#471 | DEP-2026-004…009 (QK-58, QK-46, QK-59+65, QK-60, QK-24, QK-32) con godoc en cada método afectado y cinco tests que pinan v1 (verdes en seis motores), y DEP-2026-010 (QK-50, D7): en Oracle la longitud de un texto cuenta bytes hoy (`VARCHAR2(n)`) y caracteres en el 2.0 (`VARCHAR2(n CHAR)`); quark no tiene interruptor para la semántica, la salida en 1.x es `NLS_LENGTH_SEMANTICS=CHAR` de Oracle, y la introspección tendrá que leer `CHAR_USED`. Las siete filas de quark del §3.0 están `en main` hasta el set del 2026-10-19 |
| M0-N | **hecha** 2026-10-16 | nucleus#630 | nueve avisos con asistente y test que pina v1: DEP-2026-003 fechado al 2.0 (D2) y 019…026 (NU-121, asynq, NU-72, problem+json, `NewWrapResponseWriter`, `pkg/model`, puerta sin tipo de `signals`, NU-110); trece marcas `Deprecated` que el guard lee; las salidas en 1.x `WithErrorEnvelope()` (app, nucleus, builder), `router.Wrap`, `Topic.String` y la pista al migrador en `authz.New`; seis adiciones al baseline de símbolos. Dos cosas que el enunciado daba por hechas y no eran: los topics tipados de ciclo de vida NO se construyen (las ocho señales las emite `pkg/model`, que D5 retira: se van con él y la salida es quark), y casbin v2.135.0 ya rechaza al cargar una fila de política de 3 columnas (la fase «inerte» de DEP-003 terminó con la dependencia; el aviso dice lo medido y `authz.New` nombra el migrador). Los avisos llegan al pin con el set del 2026-10-19; hasta entonces las filas 20…28 del §3.0 están `en main` |
| M0-G | **hecha** 2026-10-16 | quantum#285 | `umbrella-deprecations` lee los 13 avisos `active` al pin (5 de retirada, 7 de volteo; `DEP-2026-003` de nucleus, `active` sin fecha, tolerado con AVISO sólo mientras su fila 20 esté en `decisión`) y las 29 filas del §3.0 (12 `publicado` con fichero al pin, 9 `por escribir`, 8 `decisión` → 17 pendientes antes de `M1`); un aviso al pin que nombre el major y falte en la tabla, o cuya fila no diga `publicado`, FALLA. Los doce avisos publicados se leen con su formato real —tres grafías de la viñeta de ventana: «Earliest removal», «Behaviour flip», «Earliest change»— sin tocar ningún producto, y ninguno está mal escrito. Fixture con cinco roturas (las dos de antes más el aviso `active` sin fecha fuera de `decisión`, la fila `publicado` sin fichero y el aviso del major que falta en la tabla); política §1/§5/§6, nota del §3.0 y registro de guards al día; **QM-20 hecho**. Trampa para el tren: el PR de set que re-pine quark o nucleus con los avisos de `M0-Q`/`M0-N` sale rojo hasta pasar sus filas del §3.0 a `publicado` |
| M0-O | **hecha** 2026-10-18 — (a) orbit#568 y (b) orbit#570, publicadas en Quantum 1.42.0 (orbit v1.20.0/v1.20.1) | orbit#568 (a), orbit#570 (b) | La precondición no se cumplía (nucleus#631, la release con `M0-N`, sigue abierto hasta el tren del 19) y sólo `router.Wrap` la necesita, así que se troceó. (a): `docs/deprecations/` de orbit (README calcado del de quark: sin asistentes ni CHANGELOG), DEP-2026-001 (OR-57, volteo) con la salida `server.Config.AllowSharedAgentCertificate` (`--allow-shared-agent-certificate`, contradice `AgentIdentityFromCertificate` y `Run` rehúsa las dos; con mTLS y ninguna de las dos, un WARN al arrancar que nombra las dos) y DEP-2026-002 (D5b: 4 marcas en `datasource/nucleus`, WARN al montar el panel y al arrancar el agente sobre el camino por defecto; al 2.0 `orbit.Config.DataSource` nil es error de configuración y el editor de metadatos de campo y el `*signals.Bus` del adaptador se van con él); `quarkdatasource` pasa del `LIKE` plano con escape propio a `quark.Contains/StartsWith/EndsWith` —SQLite y Oracle contestan un `%` en vez de rechazarlo, QK-25 cerrado por este lado, `escapeLike` y `FuzzEscapeLike` fuera—; `api.ts` lee problem+json (detail > title) junto al sobre y `ApiError.code` en las dos formas; dist reconstruido. **Medido y distinto del enunciado**: orbit NO llama a la puerta sin tipo de `signals` (0 sitios: guarda el bus sólo para `model.NewCRUD`, que se va con el adaptador; `Panel.SetSignalBus` no lo lee nadie), así que no hay topics que migrar; `ExtensionConfig.DataSource` del agente cae al mismo adaptador por defecto; y el banco del fleet con `GOWORK=off` da dos fallos falsos (su go.mod resuelve server/agent publicados): se corre con el workspace de orbit, como CI. Criterio en (a): banco admin 72/72, IDENT-06 present, CI verde; `grep NewWrapResponseWriter` = 2 hasta (b). El squash es `feat:` → orbit cortó **minor** (v1.20.0) en el tren del 18. **(b)** entró en orbit#570, el PR de alineación a nucleus v1.33.0 del propio tren: las dos llamadas a `router.Wrap(w)`, `grep NewWrapResponseWriter` = 0 en orbit; nada de la lista de retiradas del 2.0 queda referenciado |
| M0-E | **hecha** 2026-10-23 (arrancada el 2026-10-18) | ramas `dry-run/2.0` en origin: quark `a2b4558d`, nucleus `2dd5b82f`, orbit `f584a53`; quantum (este PR) | el ensayo del major: treinta avisos aplicados por doce grupos en worktrees con un refutador cada uno, un integrador y un auditor por producto (workflows de agentes); orbit `dry-run/2.0` compila y pasa sus tests contra quark y nucleus `dry-run/2.0` por el `go.work` del paraguas (el criterio); el §3.0 sin filas `por escribir`. Lo que el §3 no preveía: la ruta `/v2` (§3.5 del contrato), el §2.1 como prerrequisito de DEP-024, quark en el grafo de la raíz de orbit (D11), y las decisiones D9 (starter `api` contra `generate module`) y D10 (metadatos por campo en `quarkdatasource`); los rojos y los `fix` de 1.x en la sección «`M0-E` — el ensayo del major, medido». Borrador del generador de la guía: `scripts/lib/migration-guide.py` + `docs/planes/guia-migracion-2.0.md` (23 entradas al pin) |
| R1 | **hecha** 2026-10-27 (auditores el 2026-10-23, revisión adversarial el 2026-10-27) | quantum#294 | la re-auditoría completa sobre el pin de 1.42.0 con el método de `R0`: siete auditores en paralelo, siete revisores adversariales (ninguna nota movida; tres severidades cambiadas, seis duplicados fundidos, dieciséis hallazgos nuevos de los revisores), consolidación en `docs/auditoria/reauditoria/2026-10-23/` (informes, `adversarial.md`, `notas.csv`, README) y en el registro (122 filas: 0 P0, 4 P1, 24 P2, 94 P3). Media 2,79 → 4,12; tres dimensiones en 5; **el gate de A12 no se cumple** (32 dimensiones por debajo, lista en el README). Cuatro volteos al §3.0 del 2.0 (filas 31–34, `por escribir` → `M0-R`). La escala con los cuatro instrumentos que estaban «en main» movidos a `instrumento` (35 con instrumento, 1 juicio). Los criterios de rendimiento del arco: 15 % no cumplido en 5 de 9, COPY no, `N1` 26,2 MB > 25 MB. Sección «`R1` — la re-auditoría, medida» |
| M0-R | **hecha** 2026-11-03, publicada en Quantum 1.43.0 (2026-11-07) — tres de los cuatro P1 `hecho` (OR-78, OR-79, OR-99); OR-80 tiene la salida en 1.x y se cierra con el volteo de `M1` | quark#476, orbit#576…#579, orbit#581, orbit#582 (y el toolchain go1.26.10: quark#477, nucleus#635, orbit#580) | las cuatro filas 31–34 `en main` con su salida en 1.x; los siete avisos de quark re-fechados al 2027-02-07; la salida de QK-76 era un token nuevo; «configurado en `--peers`» definido por el `server_id` que contesta; nueve hallazgos nuevos (sección «`M0-R`») |
| M0-F | **hecha** 2026-11-07 en los tres y publicada en Quantum 1.43.0 el mismo día (nucleus el mismo día, tras la decisión de NU-155) | quark#479, orbit#584, orbit#585, orbit#586; nucleus#639 (el bump de `crewjam/saml` y el gate de `govulncheck` con excepciones) y nucleus#638; nucleus#640 (notas y snapshot de v1.34.0) | tres tramos paralelos sobre las ramas `dry-run/2.0`, sólo lo válido en 1.x; el módulo `providers/tasks-asynq` nació en su sesión propia el 2026-11-10 (fila `tasks-asynq`); la DX al 5 (NU-137) sigue como precondición de `M1`; doce hallazgos nuevos |
| DX-0 | **hecha** 2026-11-08 | este PR | la DX al 5 (§2.1) contada punto a punto al pin de 1.43.0 y troceada en `DX-N1`/`N2`/`N3`, `DX-Q1`/`Q3`/`Q4` y `DX-S1`; sólo el bloque A (`DX-N1`, `DX-N2`, `DX-S1`) desbloquea `M1`; nucleus no depende de quark (D12: `Make` con doble gramática); las dos consultas del banco que faltan son del 2.0 (DEP-2026-008); `nucleus new --with orbit` monta el panel sin `DataSource` (NU-159); D13 (el playground) al propietario |
| DX-N1 | **hecha** 2026-11-08 | nucleus#644 | `generate model`, `generate resource` y `startapp` escriben un modelo quark (`db:"id" pk:"true"`, `quark:"not_null"`, `TableName()`, soft delete) y un repositorio sobre `quark.For[T]` con `--data quark\|sql` (el `sql` conserva `database/sql` sobre el mismo struct: el fichero del modelo del `resource` era código muerto); ningún fichero escrito importa `pkg/model`; la migración la sigue rendiendo la CLI desde sus metadatos internos; `nucleustest.Make` con la doble gramática de D12 (registro si el tipo está registrado; si no, las etiquetas de quark leídas por el kit —columna, `pk`, `TableName()` o plural en snake— y escritura por el CRUD interno: la clave vuelve en SQLite, PostgreSQL, MySQL y SQL Server; en Oracle no, como siempre); `go.mod` de nucleus sin quark; `bodycheck` del sitio aprende la gramática de quark (antes el sitio no podía mostrar un modelo quark sin fallar el chequeo estricto); el quickstart y `minimal-api.md` siguen enseñando `model.BaseModel` (`DX-N2`); un hallazgo de paso, NU-160 |
| DX-Q1 | **hecha** 2026-11-08 | quark#481, quark#482 | receta en **30 de 30** centinelas `Err*` (la auditoría había contado 25: el conteo mecánico encontró cinco más y el denominador del registro queda corregido aquí) con la convención «una frase del godoc empieza por `What to do:`», contada por `TestEveryExportedSentinelNamesWhatToDo`, que además exige que `errors.mdx` nombre cada centinela y publique la cifra; los sitios que envuelven un centinela con un paso a seguir pasan de 48 de 181 a 165 de 185 (los ~20 restantes son los `ErrStaleEntity` por fila, cuya receta vive en el centinela); `ErrNotFound`, `ErrTimeout` y `ErrConstraintViolation` crecen su texto tras el prefijo (un test aguas arriba que compare `err.Error()` exacto se rompería al subir el pin: en quark no había ninguno); la deriva QK-73/74/77/82 corregida y el guard `check_internal_docs_drift.sh` estricto bajo `docs/deprecations/` y leyendo `acceptance/*.md`, con `TestReadmeFiguresMatchManifest` derivando las cifras del arnés de sus JSON; dos hallazgos de paso, QK-92 y QK-93 |
| DX-S1 | **hecha** 2026-11-08 | nucleus#646 | `--with orbit` implica `quark` y `quarkdatasource`; el `main.go` de `mvc`/`api` deriva el cliente quark del pool del framework en un `OnStart` (`quarkPool`, el patrón de `generate module --data quark`, no la segunda conexión con DSN duplicado del starter `suite`) y pasa `quarkdatasource.New(pool)` como `DataSource`; el scaffold arranca y `/admin/api/models` contesta contra orbit 1.x y contra `dry-run/2.0` (test `TestWithOrbitScaffoldBootsWithSiblingCheckouts`, también en la lane suite-starter); el quickstart sin tocar; hallazgos de paso NU-161 y NU-162 |
| DX-Q3 | **hecha** 2026-11-08 | quark#484 | tres guías de producción —caché, réplicas de lectura, sharding— escritas para quien lo opera, cada una copia byte a byte de una fixture que corre en la lane de integración (`internal/integrations/{caching,readreplicas,sharding}`) y atada por el mismo guard que la guía de frameworks (`guide.CheckPage`); cada guía dice lo que quark NO hace con el fichero que lo prueba (sin métrica de hit/miss, el SQL crudo no invalida, sin medida de lag ni auto-pin, failover sólo por error transitorio, el router de shards no migra ni se anida con `TenantRouter`); dos afirmaciones falsas de la doc existente corregidas (cachear bajo la etiqueta de tabla «para no vaciar la tabla» —toda escritura la vacía—, y «un shard puede estar detrás de un TenantRouter» —el confinamiento sólo se aplica al proveedor `*TenantRouter`); hallazgos de paso QK-94…QK-97; el paquete público de DDL no hace falta (`DX-N3` delega en el CLI de quark) |
| DX-N2 | **hecha** 2026-11-08 | nucleus#647 | el quickstart enseña la forma que el CLI escribe (modelo quark con `db:`/`pk:`/`TableName()` y `Storage` sobre `quark.NewWithDB(driver, rt.DB())` en `OnStart`, sin `Models` ni `noteRow`) y sigue pegándose a un scaffold limpio, construyendo y arrancando (`TestQuickstartSliceServesOnTheScaffold`, 0 WARN); `concepts/models-and-database.md` pasa a «Models and the database» con Quark como capa y `pkg/model` como sustrato que se va (registro, gramáticas de etiquetas, WARN, AutoMigrate, caja de deprecación); intro, application, principles, compatibility, events, using-quark, minimal-api y la fila del README dicen `pkg/model` deprecado y Quark la capa; **NU-133** (README 43 comandos, `apikey` congelado en el baseline, test que falla si README≠baseline), **NU-135** (FED-03 `present` midiendo el módulo `providers/auth-saml` que el repo publica: `docs/auth-bench.md` **41 de 43**), **NU-144** (`bodycheck` entiende las filas de patrón del registro de claves: `-strict` y `check-coverage.sh --strict` sin avisos); tres afirmaciones falsas de la doc corregidas de paso (`generate migration --from-model` no existe, `migrate drift` no compara esquemas, «there is no ORM»); **trampa para el próximo tren**: `website/docs/why-quantum.md` cita «40 of 43» y `umbrella-why-quantum` lo cruzará con 41 al re-pinar nucleus — se corrige en el PR de set; la casilla de ciclo de vida de `pkg/model` sigue `stable` porque el enum de `contracts/packages_test.go` no tiene `deprecated` (NU-163) |
| DX-N1b | **hecha** 2026-11-08 | nucleus#648 | D12 cambiada por Carlos a la opción 2 el mismo día: costura `nucleustest.Factory` (`Fill`/`Persist`) y `Server.UseFactory`; `Make` sobre un struct no registrado delega en la costura (fill → overrides → persist) o falla con la receta que nombra el módulo; módulo publicado `pkg/nucleustest/quarkmake` (`New(provider, Model[T]()...)`, defaults desde `quark.GetModelMetaByType`, escritura por `quark.For[T].Create`: timestamps, soft delete, hooks y clave son de quark; no importa el kit, para construir solo contra el pin v1.34.0); fuera del root `factory_quark.go` y su gramática duplicada; alta en release-please/manifest/modules.json (ADR-034 obliga, con lista `notInstalledByAdd` en `catalog_test.go`), README, SPEC, SECURITY, inventario de contratos, lane de CI propia y `contracts/quark_out_of_root_test.go`; el banco de API cazó un pánico con `nil` en el primer borrador (DI-07); hallazgo de paso NU-164 |
| DX-Q4 | **hecha** 2026-11-08 | quark#485 | D13 (a): `internal/playground` (quark a `js/wasm`, driver `database/sql` que graba y no ejecuta, `quarkRender(spec) → {go, dialects[6]{sql,args}, catalog}`), `website/docs/playground.mdx` con el constructor inline (sólo `@docusaurus/BrowserOnly`, `useBaseUrl` y react), ejemplo estático entre marcadores que `TestStaticExampleMatchesTheDocs` compara con el render, el `.wasm` cargado a petición con «≈3.3 MB compressed» en el botón; siete presets (join, group con proyección, count, exists, window, union, cte); `check_playground_weight.sh` en `static-build` (gzip ≤ 3,5 MB y la cifra escrita a ±10 %): 14,0 MB crudo / 3,26 MB gzip; cada `Query[T]` instanciado cuesta ~130 KB gzip (con los cinco modelos reales, 3,66 MB: fuera de presupuesto), así que cuatro modelos renderizan por una forma común con `FromTable` y dos tests prueban SQL idéntico byte a byte; verificado en navegador en claro y oscuro; hallazgos de paso QK-98 y QK-99 |
| DX-N3q | **hecha** 2026-11-08 | quark#486 | `quark migrate create <n> --from-models <dir> --dialect <d> --emit json` imprime en stdout un único documento `{schema:1, tool:"quark", version, dialect (normalizado: `postgresql`→`postgres`, `sqlserver`→`mssql`), models[{name,table}], up[], down[]}` y no escribe nada (ni crea `migrations/`; de paso, el modo `go` ya no deja un directorio vacío cuando falla el render); `--emit go` es el defecto, byte a byte lo de antes; tipo del contrato `commands.DDLDocument` con la regla de bump en el godoc; tests por dialecto (postgresql, mysql, sqlite, mssql, oracle) iguales a `buildDDLStatements`; `sqlserver` se aceptaba sin documentarse; hallazgo de paso QK-100 (`--from-models` se resuelve contra el cwd, no contra el fichero de config: nucleus debe lanzar el CLI desde la raíz del módulo o con ruta absoluta) |
| DX-N3n1 | **hecha** 2026-11-08 | nucleus#650 | `generate module` escribe endpoints `nucleus.Handle[In, Out]` (`NoteID{ID path}`, `NoteInput`, `NoteList`…; 201 al crear, 204 al borrar; `operationId` con la entidad para no chocar entre módulos) y errores del framework (`errors.NotFound`/`BadRequest`/`ValidationFailed`): `/openapi.json` pasa de `responses: default` sin esquemas a parámetros, cuerpo y esquemas con `$ref`, y un 404 con `Accept: application/problem+json` contesta problem+json (probado sobre un scaffold arrancado); `generate resource` devuelve errores del framework (su contrato a mano ya prometía el sobre que el controlador no escribía) pero sigue sobre `Resource` (NU-166, decisión); `doctor`/`health`/`config print` leen los imports `providers/*` de `main.go` y los cruzan con el catálogo embebido: `storage.s3.*`, `auth.ldap.*`, `interceptors.sentry.*` pasan sólo si el proyecto los importa, y el mensaje nombra el import que falta; el guard del hello-world (374 paquetes) cazó el primer borrador, que metía go/parser en todo binario por `providerns`: la lectura vive en `internal/cli`; NU-132/136/145 `hecho`; hallazgos de paso NU-165…167 |
| tasks-asynq | **hecha** 2026-11-10 | nucleus#651 | el módulo `providers/tasks-asynq` nace en 1.x reenviando al paquete del árbol (aliases + envoltorios + import en blanco), pina v1.34.0 y pasa standalone el primer día; test anti-deriva en `contracts/`; entrada en el catálogo de `nucleus add` (grupo «jobs providers»); DEP-2026-020/MA-2026-020 dicen que el import ya puede escribirse; `unknownJobsProvider` nombra la línea de instalación de un proveedor que el proyecto publica (el error guiado del 2.0, probado llamando al helper); el root no cambia (asynq sale en `M1`); hallazgos de paso NU-168 y NU-169 |
| set 1.44.0 | **certificado** 2026-11-12 (tren del 2026-11-11, adelanto del set del 16) | quantum#307, quantum#308 | publica el bloque A, `DX-N1b` (D12), `DX-Q1`, `DX-Q3`, `DX-Q4` (D13), `DX-N3q`, `DX-N3n1`, QK-100 y `providers/tasks-asynq`: quark v1.19.0 (`cmd/quark` v1.3.0), nucleus v1.35.0 (con `pkg/nucleustest/quarkmake` v0.1.0 y `providers/tasks-asynq` v0.1.0) y orbit v1.21.3; Go 1.26.11 en los tres; 60 de 60; trampas en la sección 1.44.0 de `scripts/train/README.md` |
| DX-N3n2 | **hecha** 2026-11-12, publicada en Quantum 1.45.0 (nucleus v1.36.0) | nucleus#656 | `nucleus makemigrations <n>` deriva el par de los modelos quark: cuando el proyecto tiene `internal/models` (donde escriben los generadores) el alias reescribe a `migrate create --from-models internal/models`, que lanza el CLI de quark (`quark` en el PATH; si no, `go run github.com/jcsvwinston/quark/cmd/quark@latest`, anunciado porque descarga; `NUCLEUS_QUARK_CLI` lo fija) con `--emit json`, ruta absoluta (QK-100) y el motor configurado (`--database` elige el alias; `--dialect` lo fuerza), y escribe el par con cabecera (modelos, versión de quark, dialecto) y cada sentencia terminada como la parte `pkg/db.ExecScript` (`;`, o una línea `/` en Oracle); un CLI sin `--emit json` (anterior a `cmd/quark` v1.3.0) se reporta con la receta de instalación, un documento con otro `schema` se rechaza, un directorio sin struct con `db:` da el par vacío y lo dice (decidido con go/parser, sin lanzar el CLI), y un proyecto sin el paquete es el alias de siempre; `--from-models <dir>` vale en `migrate create` con cualquier directorio; `pkg/db` gana `Migrator.CreateWithSQL`; `TestMakeMigrationsRendersThroughTheSiblingQuarkCLI` construye `cmd/quark` del hermano por un workspace versionado (como `link_workspace.sh`) y rinde un modelo generado en los cinco dialectos, y la lane `suite-starter` lo corre contra la última release de quark; doc en `models-and-database.md`, matriz de contratos y ayuda; hallazgos de paso QK-101 (el CLI escribe `IF NOT EXISTS` literal para mssql/oracle/índices de MySQL) y NU-170 (foto completa, sin diff) |
| D9-N | **hecha** el 2026-11-13 (nucleus#662, `feat(cli)`: nucleus cortó MINOR v1.36.0 en Quantum 1.45.0; D9 = A, decidida el mismo día) | nucleus, en 1.x | `generate module` lee el root de composición del proyecto (el paquete main de `--out`, TODOS sus ficheros, con el lector de `doctor`, que ahora también mira bajo `cmd/<app>/`) y, sobre un root `WithoutDefaults()` sin `WithAuthz()`, escribe las filas de `Module.Policies` comentadas con la pista (con `--with-policy`, las abiertas, con su aviso), lo dice en su salida (`policy: NONE`, DEP-2026-017) y el test generado arranca `WithoutDefaults()` como `main.go` y afirma el 201 anónimo con lectura; sobre un root con enforcer, o uno que no puede leer, lo de hoy; `generate resource` y `startapp` dicen sobre ese root que nada carga `rbac_policy.csv`; el starter `api` conserva «sin authz». Medido: tests del generador en los dos roots y las dos políticas, del lector (ficheros auxiliares, `cmd/`, excluidos) y el starter `api` arrancado de tres maneras (nada descartado; con `WithAuthz()` aplica; con filas y sin él arranca en 1.x con una línea `DISCARDED`). NU-127 hecho. DEP-2026-017 y MA-2026-017 dicen que el generador ya no produce la combinación en un root que puede leer |
| D10-O | **hecha** 2026-11-13 | orbit#596, orbit#597, nucleus#661 | `quarkdatasource.Register[T](a, opts...)` con las once opciones (`ListFields`, `SearchFields`, `Filters`, `Exclude`, `ReadOnly`, `ReadOnlyFields`, `Label`, `Choices`, `Icon`, `OrderBy`, `PageSize`) y `ShowSensitive`, sobre los defaults de hoy; exclusión por defecto, con aviso en el log del adaptador (`WithLogger`), de las columnas cuyo nombre parece credencial (`IsSensitiveColumnName`, la misma regla con la que el panel redacta la auditoría); una opción que no nombra campo, nombra uno del tipo equivocado, contradice a otra o anularía un default en silencio es error de `Register`; el store aplica página y orden del modelo cuando la consulta no trae, deja las columnas ocultas fuera de cada registro y rechaza una escritura que las nombre; test de paridad contra el registro de `pkg/model` (los flags que el adaptador de nucleus copia campo a campo); control nuevo del banco admin **`DS-18`** (72 → **73 de 73**), que al nacer midió `partial`: el panel sólo enmascaraba las filas bajo políticas por campo y el valor de una columna excluida viajaba en cada fila del API → OR-150 (P2, reparado en orbit#596: `mask`/`maskAll`/`maskValues` lo quitan para todo operador); OR-147 cerrado de paso; tabla `ModelConfig` → opciones en MA-2026-024 (nucleus#661). Salió en orbit v1.22.0 con Quantum 1.45.0 (la raíz cortó MINOR, no `fix`: release-please le atribuye el `feat` de orbit#597 por sus ficheros fuera de `quarkdatasource/`, `go.work.sum` y `website/docs/features.md`; `quarkdatasource` v1.14.0); el PR de set subió el suelo de `umbrella-admin-posture` a 73 |
| set 1.45.0 | **certificado** 2026-11-16 (tren del 2026-11-13/16, fuera de cadencia: adelanta el set del 2026-11-23; conducido por el propietario desde su terminal) | quantum#319 | publica `D9-N` y `D10-O`: quark v1.19.1 (`cmd/quark` v1.3.1, los cinco drivers v0.3.3; QK-101), nucleus v1.36.0 (`cmd/nucleus` v1.36.0 en lockstep y los dieciséis módulos en patch; NU-127, NU-170, NU-171, `DX-N3n2`) y orbit v1.22.0 (`quarkdatasource` v1.14.0, `agent` v0.16.6, `server` v0.22.4, `quarkbridge` v1.9.9; OR-150, `DS-18` 73 de 73); el PR de set sube `umbrella-admin-posture` a 73, pone «73 of 73» en why-quantum y regenera la guía de migración (34 avisos); `suite-integral --cierre` 60 de 60; trampas en la sección 1.45.0 de `scripts/train/README.md` |
| M1-S0 | **hecha** 2026-11-16 | quantum#326 | el major medido en sólo lectura sobre el pin de 1.45.0 (`main` de los tres) y las ramas `dry-run/2.0`, con nueve mediciones y dieciocho refutaciones (reproducir y lo que falta): la ruta `/v2` son 41 `go.mod` y 2 156 líneas de import, no 39 y ~2 100 (`cmd/nucleus` pasa a `…/nucleus/cmd/nucleus/v2`; el workspace compila contra `/v2` sin `replace`; cinco lectores de ruta callan y nueve mueren; el job `verify` de `release.yml` de nucleus dejaría v2.0.0 sin activos y los ldflags de quark y nucleus binarios que dicen «devel»/«dev»; `cmd/quark` no va en lockstep: le falta la anotación de release-please); las 34 filas están `publicado`, 30 ensayadas y 4 sin commit, con 31/83/37 ficheros a rehacer sobre `main` y las cinco discrepancias de `M0-E` sin corregir; `pkg/model` son 36 + 13 símbolos (no 48), el segundo pool SQLite del banco admin sigue sin arreglar y la fila 30 y el `go.mod` de D11 son el mismo PR; asynq deja 4 módulos y go-redis se queda; D11 cuesta 7 cortes de convergencia (no 13) y ADR-006 lo contradice; la guía queda vacía con avisos `completed` (`migration-guide.py:143`) y la regla D2 de `POLITICA_DEPRECACION.md` §4 lo adelanta al 2026-12-08; el tren no conoce un major (24 módulos v0.x sin número, lint del `!` inexistente, sin CI en PRs a otra rama); 99 elementos de las 32 dimensiones clasificados (64 cortos, 16 hechos, 6 rompientes, 13 largos o del propietario) en 42 sesiones `V-*`; Discussions comprobado activo en quantum (QM-42 hecho, quantum#324). `M1` troceada en 23 sesiones más el tren, con un tramo 1.x de 18 sesiones como precondición, todas con precondición y criterio como comando; 13 preguntas al propietario (D26…D38 del §3.3), 2 antes del primer commit del major; D26…D38 decididas el 2026-11-16 (quantum#__PR__) |
| M1 | pendiente — **troceada el 2026-11-16 por `M1-S0`** en 23 sesiones más el tren (sección «`M1-S0` — el major, medido y troceado»); precondición: las diez cortas de D15 en sets 1.x, el tramo 1.x del troceado (18 sesiones: `M1-V2-P`, `M1-T-P/O/N/Q`, `M1-T-LINT-Q/N/O/P`, `M1-G-P/Q/N/O`, `M1-G-F1…F5`; no es `M1`: `M1` empieza con `M1-V2-Q`(1)) y D26…D38 decididas el 2026-11-16 (D30 abre DEP-2026-027, `V-N-AM`, antes del set del 2026-11-23: el suelo del 2.0 pasa al 2027-02-21 si ese set lo publica); arranca en enero de 2027 (D17); el primer commit del major de cada repo es `M1-V2-{Q,N,O}`, en ese orden | — | |
| R2 | pendiente — alcance decidido el 2026-11-16 (D18): re-auditoría completa como `R1`, no sólo lo que `M1` toque | — | |
