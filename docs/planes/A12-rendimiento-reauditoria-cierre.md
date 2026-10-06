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

## Decisiones que el arco necesita (propuestas, pendientes de Carlos)

`S0` las deja escritas con la recomendación; el troceado asume la
recomendación hasta que Carlos diga otra cosa.

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
| `M1` | El 2.0: retirar los doce símbolos, voltear los defaults, asynq a módulo propio (decisión 4), guía de migración generada; tren de cuatro repos | `R1` | set 2.0.0 certificado; ninguna marca viva que prometa 2.0.0 |
| `R2` | Confirmación ligera sobre el 2.0: bancos, guards y re-puntuar sólo lo que `M1` tocó; A12 cerrado | `M1` | todas las dimensiones a 5 salvo comunidad, o A13 abierto con lo que falte |

`Q1→(Q2 ∥ Q3)`, `N1`, `N2`, `O1` y `R0` van en paralelo y pueden solaparse
con A11 si no tocan los mismos paquetes. `M0 → R1 → M1 → R2` va al final y
en serie.

## Registro de sesiones

| Sesión | Estado | PR | Qué midió o cambió del plan |
|---|---|---|---|
| S0 | **hecha** 2026-10-04 | este PR | las cinco mediciones, nueve hallazgos (QK-34…38, NU-106, OR-61, QM-20, QM-21), NU-87 ampliado y NU-50 duplicado renumerado (NU-105); NU-8 a A11 `N3` |
| Q1 | **hecha** 2026-10-05 | quark#431 | el banco de PG y MySQL (`benchmarks/engines`, workflow propio no requerido): las seis operaciones ausentes en el runner (PG 1,24–1,98× sobre `database/sql`; MySQL 1,42× por llamada). En Preload100 la forma de la consulta pesa más que el mapeo (≈240 µs de ≈325 en el portátil). `interpolateParams=true` ya da −41 % en MySQL. Trampa: `align-module-floors.sh` no hace tidy de `benchmarks/`, así que el banco importa los drivers de `database/sql` directamente |
| Q2 | **hecha** 2026-10-05 | quark#444 | List sin copia JSON sin caché (QK-34), preload con `= ANY` en PostgreSQL (QK-35), placeholders sin fmt y `Validate` sólo con tags (mitad CPU de QK-36); en el runner: List100 1,35→1,17, Preload100 1,98→1,25, lote de 1000 1,33→1,09; el banco afirma tiempos sólo en modelos de CPU registrados (QK-47); pista para Q3: `context.WithTimeout` por consulta añade asignaciones |
| Q3 | **hecha** 2026-10-06 | quark#452 | `WithStatementCache` opt-in (QK-37, ADR-0027): un LRU por pool con recuento de referencias, sentencias preparadas una vez por transacción, sólo las del builder con argumentos; ignorada en PostgreSQL (pgx cachea) y en Oracle (go-ora v2.9.0 devuelve un resultado rancio a una sentencia preparada re-ejecutada, reproducido sin quark). FindByPK en MySQL −46…48 % frente a sin caché en el runner (5 corridas, 3 CPUs; −41…42 % en portátil), 1,65× la sentencia reutilizada a mano; `interpolateParams` documentado y medido (≈ igual). `CreateBatch` sin RETURNING (mitad de lotes de QK-36, ADR-0028): SQL Server un `MERGE … OUTPUT` con la posición de la fila por chunk (OUTPUT INSERTED no garantiza orden); MySQL INSERT multifila con claves calculadas SÓLO con `innodb_autoinc_lock_mode` 0/1 (el 2 por defecto de MySQL 8 sigue fila a fila: el manual no garantiza claves consecutivas); un chunk que falla se deshace y va fila a fila. Lote MySQL de 1000: 9,6 ms frente a 241 ms fila a fila (EPYC 7763). COPY en PG no se construyó (no devuelve claves): PG-06 a 1,09× database/sql, COPY 2,6× más rápido. Controles nuevos PG-06, MY-02, MY-03. Hallazgo previo: el per-row de MSSQL tapaba la violación de unicidad con un escaneo de NULL (QK-53, arreglado en quark#453). El criterio «lote de 10 000 en PG cerca de COPY» no se cumple devolviendo claves: queda medido y explicado, y COPY opcional pasa a QK-54 |
| N1 | **PR listo** 2026-10-06 | nucleus#607 | la CLI a módulo propio `cmd/nucleus` (lockstep: un tag `cmd/nucleus/vX.Y.Z` por cada release del raíz, ADR-038), los tests del raíz sólo con SQLite (`internal/testsqlite`; las lanes de motor enlazan los otros cuatro con un workspace), dependencias de test a `internal/testdeps`, goleak→`internal/leakcheck`; lanes requeridas nuevas `hello-world-size` (techos exactos de módulos y paquetes, binario +2 %) y `cli`. Grafo en linux/amd64: hello 92→**79** módulos (39 enlazados, 373 paquetes, 22,4 MB), hello+sqlite 105→**92** (46, 384, 26,2 MB: 0,2 MB sobre los 25 MB del criterio, código enlazado y no grafo), starter api 108→**95**; la predicción de S0 salió exacta. **Se fusiona en el tren del 2026-10-12 justo antes del corte de nucleus**: entre el merge y el primer tag `cmd/nucleus/v*`, `go install …/cmd/nucleus@latest` daría «ambiguous import». `nucleustest` sin SQLite no se hizo (no es aditivo → NU-121, lista del major) |
| N2 | **hecha** 2026-10-05 | nucleus#592 | claim con `SKIP LOCKED` en PostgreSQL y MySQL 8/MariaDB 10.6+ (en READ COMMITTED: en REPEATABLE READ los gap locks vuelven a serializar), SQLite y motores sin `SKIP LOCKED` con el claim de antes; el perdedor reintenta con jitter. 16 contra 1 worker: 4,4× PG y 5,1× MySQL en local, 2,9× y 2,6× en el runner (4 vCPU, se satura) — **el criterio cambió**: el ≥ 4× mide la máquina (la lección de NU-95), así que el gate exige ≤ 5 % de claims vacíos con 16 workers (0 % con SKIP LOCKED, 91 % con el claim viejo) y ≥ 2× por el `Manager` real. Parada con `sql`: 9 s → 0,7 ms (NU-103). El prototipo de `S0` era O(backlog): partido en dos rangos del índice. NU-108 nuevo (el pool por defecto churnea) |
| O1 | **hecha** 2026-10-05 | orbit#544 | dist precomprimido y servido por negociación, admin-server sin el panel (25,6→23,8 MB), presupuesto en gzip de carga inicial + navegación más pesada (424,6→373,4 KB, `main` ya se pasaba), AG Grid 36 sin fuente de iconos; OR-59/61/62/63 |
| R0 | **hecha** 2026-10-05 | quantum#258 | la escala en `docs/auditoria/criterios-5.csv`: las 36 dimensiones del 2026-09-03 con su nota de entonces, el listón y el 5 copiados del artefacto del plan a 5/5 (los dos artefactos, el plan y el informe de la auditoría, se pudieron leer), el 1 y el 3 escritos desde los informes, y el instrumento al pin —34 con banco, guard o lane, 2 sólo juicio (quark·ecosistema y suite·comunidad)—; guard `umbrella-audit-criteria` (56º) que saca la lista de dimensiones de los propios informes y valida también el `notas.csv` de cada re-auditoría. El brief en `docs/auditoria/reauditoria/` con sus prompts (el común, uno por auditor, el de la revisión adversarial y el de la consolidación): siete auditores en paralelo (quark, nucleus, orbit, orbit-fleet, orbit-ui, suite y uno de rendimiento nuevo), cada dimensión con un solo dueño, ids provisionales, revisión adversarial por informe y consolidación al mismo registro. `check_audit_backlog.sh` acepta A13+, falla ante un id repetido (registro o informes) y ante una fila de defecto sin id, lee los informes de `reauditoria/<fecha>/` y enseña los P0 abiertos (QK-42 no salía); `estado.sh` deriva el arco siguiente más allá de A12; `suite-integral` corre en los PRs que tocan `docs/auditoria/`. Para `R1`: cuatro instrumentos están en `main` de su producto y no al pin de 1.39.0 (`quark/benchmarks/engines`, `quark/internal/extbench`, `nucleus/internal/catalogbench`, la familia `extension` de adminbench): se mueven a la escala con el pin que los traiga |
| M0 | pendiente | — | |
| R1 | pendiente | — | |
| M1 | pendiente | — | |
| R2 | pendiente | — | |
