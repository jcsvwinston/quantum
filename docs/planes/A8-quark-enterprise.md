# A8 — Quark enterprise

> **El troceado salió de la MEDICIÓN, no del enunciado.** El plan a 5/5
> describía este arco como «migraciones v2 (diff declarativo, `migrate diff`,
> plan hash) y RLS en tres motores», escrito meses antes de que nadie mirara.
> `S0` midió y corrigió las dos mitades: dos de las tres cosas de migraciones
> ya existían y la tercera no significa lo que el plan suponía; y «RLS en tres
> motores» daba por supuesto que hay algo en más de uno, cuando el RLS nativo
> es PostgreSQL y nada más. Es la cuarta vez que la medición corrige el plan.

**Precondición del arco**: Quantum 1.34.0 certificado (A7 cerrado).
**Gate del arco**: el registro `docs/auditoria/madurez-2026-09-03/registro.csv`
sin hallazgos abiertos de A8, y el banco publicando su cifra.

## El banco

`quark/internal/enterprisebench` — **69 controles, uno por sonda ejecutable**,
publicados en `quark/docs/enterprise-bench.md`. El test asserta el veredicto
REGISTRADO, no el éxito: cerrar un hueco pone la suite en rojo y pide
actualizar la cifra, de modo que el numerador no puede quedarse rancio.

**Línea de base medida el 2026-09-20 sobre quark v1.14.0:**

| familia | present | partial | absent | de |
|---|---|---|---|---|
| migraciones | 5 | 5 | 6 | 16 |
| tipos | 3 | 3 | 5 | 11 |
| rls | 3 | 8 | 2 | 13 |
| operacion | 6 | 11 | 1 | 18 |
| qk25 | 3 | 1 | 7 | 11 |
| **TOTAL** | **20** | **28** | **21** | **69** |

Corre en SQLite, en el módulo raíz, así que `go test ./...` lo ejerce en cada
cambio. Eso basta para medir una superficie, un contrato y una negativa; no
basta para certificar comportamiento contra los otros cuatro motores, y donde
un control necesita un motor vivo su nota lo dice — esa prueba vive en
`internal/enginesuite`.

## Lo que la medición encontró y el plan no sabía

1. **`quark.ForTx` no lleva confinamiento por tenant.** `For[T]` aplica el
   schema o el `WHERE` del tenant cuando el proveedor es un `TenantRouter`;
   `ForTx[T]` construye su `BaseQuery` sin schema, sin tenantID y sin ese
   WHERE, y `TenantRouter.Tx` entrega un `*Tx` desnudo para cualquier
   estrategia que no sea `RowLevelSecurityNative`. Dentro de una transacción,
   una consulta ve y escribe fuera de su tenant. **Es el P1 del arco.**
2. **`ApplyPlan` descarta índices, claves ajenas y CHECK** al crear una tabla,
   y devuelve `nil`. El godoc del op dice que el ejecutor los emite; el godoc
   del ejecutor dice que vienen en ops posteriores; ninguna de las dos es
   cierta. El mismo patrón que `Plan.Down` trata como defecto de primera en la
   dirección inversa.
3. **El builder no puede emitir `LIKE … ESCAPE` por ningún camino** (QK-25), y
   el remedio que el registro proponía —escapar también en SQLite y Oracle—
   **rompe SQLite si se aplica solo**: sin cláusula `ESCAPE`, el motor trata la
   barra como un carácter más.
4. **El camino documentado para UUID produce tablas sin clave primaria**, y
   `precision/scale` **secuestra el tipo base**: un `string` con esa pista sale
   `DECIMAL(10,2)`.
5. **La paginación por cursor no existe**: `page.go` es OFFSET puro con dos
   consultas, y `cursor.go` es un iterador de filas.

## El troceado

| Sesión | Qué entrega | Precondición | Criterio de hecho |
|---|---|---|---|
| `S0` | La medición: el banco, su página y los hallazgos | A7 cerrado | **HECHA** — 20/69, 46 defectos registrados |
| `S1` | El confinamiento por tenant sobrevive a una transacción | S0 | **HECHA** — quark#404: `RLS-13` a `present` con evidencia positiva, 21 de 69; ADR-0025 |
| `S2` | `LIKE … ESCAPE` de punta a punta, por dialecto | S0 | **HECHA** — quark#406: `qk25` 11 de 11 (los 7 `absent` y el `partial`), probado en los cinco motores por `SharedSuite`; banco 29 de 69 |
| `S3` | El plan lleva índices, FK y CHECK, y el ejecutor los emite | S0 | **HECHA** — quark#407: `MIG-01`, `MIG-02`, `MIG-03` y `MIG-06` a `present`; banco 33 de 69 |
| `S4` | `ALTER COLUMN` completo y reversibilidad más allá de CREATE/DROP | S3 | **HECHA** — quark#408: `MIG-07` y `MIG-09` a `present`; banco 35 de 69 |
| `S5` | uuid nativo y enum con CHECK desde el modelo | S0 | `TYP-01` y `TYP-03` a `present`, con la PK intacta |
| `S6` | Arrays de PostgreSQL, rangos e inet | S5 | `TYP-04`, `TYP-06` y `TYP-07` a `present` |
| `S7` | `precision/scale` deja de secuestrar, y la matriz de tipos deja de mentir | S5 | `TYP-11` a `present`; la matriz publicada coincide con lo medido |
| `S8` | RLS fuera de PostgreSQL: qué recibe cada motor, y la verificación | S1 | `RLS-01`, `RLS-02` y `RLS-04` con su veredicto medido |
| `S9` | Paginación por cursor / keyset | S0 | `OPS-15` a `present` |
| `S10` | El CLI: `migrate diff/plan/verify` y las políticas de tenant | S3, S8 | `MIG-11` y `RLS-06` a `present` |
| `S11` | Gate, guard y set | todas | `umbrella-quark-posture` registrado con su fixture; set certificado |

**El orden no es negociable en dos sitios**: `S1` va primero porque es el P1, y
`S2` va segundo porque su remedio ingenuo rompe SQLite y conviene cerrarlo con
la medición fresca. El resto puede reordenarse si una sesión se atasca.

## Registro de sesiones

### `S0` — la medición (2026-09-20) · **hecha**

- **Banco**: `quark/internal/enterprisebench`, 69 controles en cinco familias,
  publicados en `quark/docs/enterprise-bench.md`. **20 presentes.**
- **Método**: reconocimiento por familias contra el código real, con un
  escéptico por familia comprobando cada veredicto `present`; luego las sondas,
  con **tres rondas adversariales** que acertaron 92 veces.
- **La enfermedad que encontraron las rondas**, y que hay que vigilar en
  cualquier banco: *una sonda que llega a su veredicto registrado por más de un
  reparto de hechos*. `MIG-06` afirmaba que `ApplyPlan` es todo-o-nada en
  SQLite **y** que miente sobre un CREATE TABLE parcial; si la garantía
  transaccional se rompiera, la sonda devolvía el mismo `partial` y el banco
  seguía verde. Los arreglos se verificaron **por mutación**: cambiar el código
  de producto y comprobar que la sonda se pone roja.
- **Y la inversa, que rompe el contrato del banco**: una sonda cuyos caminos
  devuelven todos el mismo veredicto no-`present` no puede ponerse verde nunca,
  así que cerrar el hueco no mueve nada. Le pasaba a `MIG-11` y a `LIKE-02`.

### `S1` — el confinamiento en una transacción (2026-09-20) · **hecha**

**PR**: quark#404 (`fix(tenancy)`), sobre la rama del primer corte
`quark:fix/a8-s1-tenant-in-tx`. **Medido**: `RLS-13` de `partial` a
`present`, el banco de **20 a 21 de 69**; un solo control, el P1.

**Lo que entrega.** El confinamiento vive en UNA función,
`applyTenantConfinement`, llamada desde `For` y desde `ForTx` — el defecto era
que había dos caminos y divergían. El `*Tx` lleva el router que lo confina y
el inquilino para el que se abrió, puestos por UNA función,
`TenantRouter.confineTx`, desde `router.Tx` y desde `Client.BeginTx` cuando el
cliente es el `BaseClient` estampado. Bajo `RowLevelSecurityNative` dentro de
una transacción la consulta conserva el executor de la transacción, porque el
aislamiento ya lo puso `set_config` en esa conexión.

**La decisión que faltaba, tomada y escrita — ADR-0025 de quark: la
transacción fija el inquilino.** Un contexto de consulta que no resuelve
inquilino lo hereda (`ForTx[T](context.Background(), tx)` es válido); uno que
resuelve OTRO falla con `ErrTenantMismatch`, API nueva y aditiva. Bajo Native
el motor ya filtra por el que fijó la transacción; bajo `DatabasePerTenant`
el pool ya se eligió. Obedecer al contexto de la consulta —lo que hacía el
primer corte— era una mentira en el primero y una regresión en el segundo.

**Los seis defectos de la revisión, cerrados y cada uno con su test verificado
revirtiendo el arreglo** (`tenant_tx_confinement_test.go`):

1. **`Create` no consultaba `q.err`** — ni ningún mutador. Las copias
   internas de `BaseQuery` (`dq`, `sq`, `bq`) no arrastraban `err` y
   `queryRowOn` no lo miraba: el comentario que afirmaba que «aflora solo en
   `Scan`» describía un mecanismo inexistente. Un `Create` bajo Native sobre
   SQLite ejecutaba su INSERT sin aislamiento alguno. Ahora todo mutador
   abre con `if q.err != nil`, toda copia arrastra `err`, y `queryRowOn`
   acuña el error en el `*sql.Row` con `errorRow`.
2. **`GetClient`+`client.Tx` era la otra puerta.** `NewTenantRouter` estampa
   el `BaseClient` de las tres estrategias de pool compartido y `BeginTx`
   confina la transacción si el contexto lleva inquilino (`set_config`
   incluido bajo Native). Sin inquilino queda como siempre fue —sobre el pool
   compartido—, que es como corren migraciones y aprovisionamiento; un
   inquilino inválido es error, nunca una transacción desnuda.
3. **`Preload` leía las relaciones del schema por defecto.** Toda tabla que
   una consulta toca pasa ahora por `qualifiedTable`.
4. **Regresión bajo `DatabasePerTenant`** (un `ForTx` con contexto sin
   inquilino fallaba donde bastaba el pool): resuelta por la regla del ADR.
5. **`RLS-13` llegaba a `present` sin observar confinamiento positivo.** La
   sonda `ATTACH`a en SQLite una base bajo el nombre del inquilino, con una
   fila que sólo vive ahí: la evidencia son las filas leídas, no la forma del
   error; y el lado cliente exige el predicado ligado a ESE inquilino con
   sólo sus filas de vuelta. Revertir el confinamiento de `ForTx` la deja en
   `partial` y el banco en rojo.
6. **Quién manda sobre el inquilino dentro de la transacción**: arriba.

**Método, y dos lecciones.** (a) El booleano `inTx` del primer corte —declarado,
documentado y no leído— pasó a ser el propio `*Tx`, que además decide QUÉ
inquilino: no leerlo ya no compila. (b) El primer test que escribí para el
defecto 1 pasaba con el arreglo revertido: `For[T]` sin inquilino ya se
rechazaba, pero **por la razón equivocada** («client not initialized», porque
`GetClient` falló antes de llegar al confinamiento). La fuga real era la
consulta que SÍ tenía cliente y falló al construirse. Lo destapó la mutación,
no la lectura — un veredicto correcto por la razón equivocada no lo caza
ningún test hasta que se busca el caso en que la razón importa.

**Docs en el mismo PR**: `advanced/multi-tenant` (sección Transactions),
`reference/api/multi-tenant` (`TenantRouter.Tx`, `ErrTenantMismatch`),
`advanced/row-level-native`; `docs/adr/0025` y `docs/playbooks/tenant.md` con
los dos anti-patrones nuevos; `docs/enterprise-bench.md` regenerado.

### `S2` — `LIKE … ESCAPE` de punta a punta, por dialecto (2026-09-20) · **hecha**

**PR**: quark#406 (`feat(query)`). **Medido**: la familia `qk25` de **3 present ·
1 partial · 7 absent** a **11 present**; el banco de 21 a **29 de 69**. Y la
prueba que la sesión debía —«ejercido en los cinco motores»— la hace
`testLikeEscape` dentro de `SharedSuite`: en cada motor de la matriz asserta
que la sentencia lleva la cola DE ESE motor (placeholder y grafía) y que
devuelve exactamente la fila que una búsqueda de comodín literal debe.

**Lo que entrega, todo por adición.** `WhereLike`/`WhereNotLike` (patrón con
el escape declarado), `WhereContains`/`WhereStartsWith`/`WhereEndsWith` (texto
del usuario, escapado con el nuevo `EscapeLike` —`%`, `_`, `[`, `\`— y
envuelto), los tipados `Contains`/`StartsWith`/`EndsWith`/`LikeEscaped` y el
AST `Like`/`Contains`/`StartsWith`/`EndsWith`. La cola se escribe POR MOTOR
—`ESCAPE '\\'` en MySQL y MariaDB, cuyo parser lee una barra sola dentro del
literal como escape; `ESCAPE '\'` en los demás, y SQLite RECHAZA la doblada—
desde un solo helper que los cinco renderizadores (SELECT, UPDATE, DELETE)
añaden. El guard lee el valor: un patrón que acaba en escape colgante se
rechaza con `ErrInvalidQuery` antes de llegar al motor.

**La decisión: la forma plana NO cambia.** `Where(col, "LIKE", p)` y el
tipado `Like` siguen entregando el patrón opaco bajo el escape por defecto
del motor. Declararles `ESCAPE` unificaría el significado, pero cambia lo
que significa una barra invertida en tres motores para toda consulta
publicada: es rompiente y va a A12 (**QK-32**, nacido aquí). El remedio
ingenuo que el plan avisaba —escapar el valor sin declarar el carácter— es
justo lo que rompe SQLite, y las sondas lo distinguen (0 filas = `partial`).

**Cuatro controles retitulados, y por qué es honesto.** El `present` que `S0`
escribió para LIKE-02, 03, 05 y 06 sólo era alcanzable cambiando la forma
plana publicada (una búsqueda de `%%%` contestando cero filas). La capacidad
que una aplicación necesita es una superficie que reciba el TEXTO del
usuario aparte de los comodines que la aplicación pone alrededor —la propia
sonda de `S0` lo dejó escrito: «1 fila sólo es alcanzable desde una superficie
que reciba el texto aparte del patrón»—, y eso es lo que miden ahora; cada
nota lo dice y asserta la forma plana como SUELO (si cambiara, la sonda
falla en vez de dar un veredicto). LIKE-03 pasa de medir la variación por
«escape por defecto» —que con el carácter declarado deja de importar— a
medirla por las reglas del literal del parser, que es la que existe.

**QK-31 de paso**: los tres `t.Skipf` tras un `Ping` fallido de la suite de
MariaDB pasan a `t.Fatalf`; la lane que declara un motor falla si el motor
no contesta (LIKE-11 a `present`).

**Método**: tests de raíz verificados revirtiendo su arreglo (cola del SELECT,
colas de UPDATE/DELETE, validación del patrón), y el banco por mutación
(sin la cola del SELECT caen LIKE-01/02/03/05/08). Y una trampa pequeña: un
test que buscaba la palabra `ESCAPE` la encontró en el nombre de la tabla
`like_escape_rows`; se busca la CLÁUSULA (` ESCAPE '`), no la palabra.

**Lo que sólo vio el motor real, y ninguna sonda sobre SQLite**: el primer
corte escapaba `[` en los seis motores («con el carácter declarado, `\[` es
un corchete literal en todas partes»); la lane de Oracle lo tumbó con
`ORA-01424` — Oracle sólo admite el escape delante de `%`, `_` o de sí mismo.
El corchete es comodín SOLO en SQL Server, así que se escapa sólo ahí, y eso
obliga a componer el patrón de las búsquedas de texto cuando ya se conoce el
dialecto (en `WhereP` para los tipados, en `ToSQL` para el AST). LIKE-03 lo
mide como segundo hecho por motor: para un texto con `[`, exactamente SQL
Server liga un valor distinto. La regla del arco se confirma: **una prueba
en los cinco motores no es un extra, es la única que ve esto.**

**Docs en el mismo PR**: `guides/querying` (búsqueda de texto del usuario),
`reference/api/query-builder`, `reference/sqlguard`, `guides/codegen`;
`docs/enterprise-bench.md` regenerado.

**Siguiente: `S3`** (el plan lleva índices, FK y CHECK, y el ejecutor los
emite: `MIG-01`, `MIG-03`, `MIG-06`). Nota para el tren: quark#404 (fix) y
quark#406 (feat) juntos hacen una MINOR de quark; el snapshot de doc va
ANTES del release PR (regla de quark), y `quark-doc-debt.sh` lo sabe.

### `S3` — el plan lleva índices, FK y CHECK, y el ejecutor los emite (2026-09-20) · **hecha**

**PR**: quark#407 (`feat(migrate)`). **Medido**: `migraciones` de 5 a **9
present**; el banco de 29 a **33 de 69**. MIG-01, MIG-02 y MIG-06 cambian de
veredicto sólo con el arreglo; MIG-03 se retitula y su sonda se reescribe.

**QK-27, las tres mitades.** (1) **El ejecutor emite la tabla entera**: FK y
CHECK inline en el `CREATE TABLE` —la única forma que tiene SQLite, y una que
aceptan los seis— y cada índice como su propio `CREATE INDEX` por el helper
que ya usa `CreateIndex`. (2) **`Diff` ordena y casa para que el bucle
converja**: las tablas nuevas se crean padres primero (orden topológico por
sus FK, nombre entre las libres, nombre si hay ciclo); una FK se casa por lo
que ES —columnas, tabla y columnas destino— y nunca por un nombre que SQLite
no guarda; la acción vacía es el default del motor, `NO ACTION`; y un índice
deseado lo satisface uno vivo de la misma forma con otro nombre, que es lo
que parece desde el catálogo el índice de respaldo de una columna
`quark:"unique"`. (3) **El modelo declara índices**: `quark:"index"`
(`idx_<tabla>_<columna>`) e `index=<nombre>` entran en el vocabulario cerrado
de la etiqueta; `Migrate` los crea tras la tabla y `PlanMigration` los
propone cuando faltan. Los índices vivos que el modelo no nombra siguen sin
tocarse, a propósito: un modelo que no puede describir todo el catálogo no
debe proponer destruir lo que calla.

**El retitulado de MIG-03 y su porqué.** El título de `S0` pedía «proponer
crear o borrar índices»; borrar uno que el modelo no nombra es justo lo que
el plan rehúsa por diseño. La sonda nueva mide las tres cosas que sí hay:
`Migrate` crea el declarado y el plan queda vacío; un índice manual no
provoca nada; el declarado que falta se propone, y sólo él. El estado de
`S0` sigue siendo un `absent` alcanzable. Y la sonda vieja NO tenía camino a
`present` (las dos ramas no vacías devolvían `partial`): la misma enfermedad
que `S0` corrigió en MIG-11 y LIKE-02, en un tercer control.

**Método**: cinco tests de raíz, cada uno verificado revirtiendo su arreglo;
la prueba `PlanConstraints` en `SharedSuite` aplica un esquema padre/hijo
con índice, FK y CHECK en cada motor de la matriz y exige residuo vacío —el
CHECK se prueba por la fila que rechaza, porque SQLite no lo introspecciona.
Una trampa de la propia suite: su base de datos comparte tablas de otros
tests, así que el plan de un solo modelo propone borrarlas; se mide sólo lo
que dice de su tabla.

**Lo que sólo vio la matriz real, otra vez**: MySQL y MariaDB crean solos
un índice de respaldo para cada `FOREIGN KEY`, con el nombre de la
restricción, y el introspector lo devolvía como un índice más — el plan
recién aplicado proponía `DROP INDEX` sobre él para siempre. Se filtra en la
introspección, como ya se filtraba el de la `PRIMARY KEY`: la restricción es
lo que el modelo del diff sigue, y su índice lo gestiona el motor. Tercera
vez en el arco (Oracle `ORA-01424`, el gate del arnés, y esto) que la lane
de un motor enseña lo que ninguna sonda sobre SQLite puede ver.

**Queda para `S10` (la sesión del CLI)**: `quark from-models` y `quark model`
parsean el vocabulario de la etiqueta en su propio módulo y no conocen
`index` todavía.

**Siguiente: `S4`** (`ALTER COLUMN` completo y reversibilidad más allá de
CREATE/DROP: `MIG-07`, `MIG-09`), que depende de `S3`.

### `S4` — `ALTER COLUMN` completo y reversibilidad (2026-09-20) · **hecha**

**PR**: quark#408 (`feat(migrate)`). **Medido**: `migraciones` de 9 a **11
present**; el banco de 33 a **35 de 69**.

**Lo que entrega.** `OpAlterColumn` cubre las cuatro facetas —tipo,
nullable, default y clave primaria— en los seis motores, con los deltas
calculados como los calcula `Diff` (un op sin cambio es un no-op).
PostgreSQL altera cada faceta por separado; MySQL/MariaDB reformulan la
columna con un `MODIFY`; SQL Server altera la columna y gestiona por nombre
—leído del catálogo— sus restricciones de default y de clave; Oracle emite
un `MODIFY (…)` con exactamente lo que cambia (repetir `NOT NULL` es
ORA-01442). Un rename por `OpAlterColumn` se rehúsa en voz alta: es cosa de
`Sync`.

**SQLite reconstruye la tabla**, el procedimiento que documenta su manual:
leer la tabla, crear la nueva con nombre temporal, copiar filas, borrar,
renombrar, recrear. Corre sobre el executor del plan —la transacción—, así
que un fallo (un `NOT NULL` sobre filas con `NULL`) deja la tabla como
estaba. Lleva lo que los PRAGMA no saben, leyéndolo de `sqlite_master`: el
DDL de los índices literal, el índice automático de una columna `UNIQUE`
como índice único con nombre y misma forma, los triggers, los CHECK en la
forma que escribe `applyCreateTable` y los NOMBRES de las FK — que es lo que
permite al `OpDropForeignKey` de `Plan.Down` encontrar su clave. Un CHECK
en otra forma rehúsa la reconstrucción en vez de perderse. Con
`PRAGMA foreign_keys` activo, la comprobación se difiere al `COMMIT`. Las FK
y los CHECK en SQLite (`OpAddForeignKey`/`OpDropForeignKey`/`OpAddCheck`/
`OpDropCheck`) pasan por la misma reconstrucción.

**La sonda MIG-07 y un artefacto de orden**: `S0` medía primero el delta de
PK dando por hecho que se rechazaría; al aterrizar, la columna es clave, y
una clave nunca es nullable, así que el delta de nullable medido después
leía del catálogo un hecho sobre claves. Los deltas van ahora en el orden
del título, la clave la última. MIG-09 retitulado: la FK también hace el
viaje de ida y vuelta.

**Método**: tests de raíz (los cuatro deltas y las filas sobreviven cuatro
reconstrucciones; índices, índice único manual, triggers, CHECK y nombres
de FK sobreviven y el rollback generado borra la clave por su nombre; un
CHECK ilegible se rehúsa sin tocar la columna; un `NOT NULL` sobre `NULL`
falla y deja la tabla; las sentencias por dialecto), tres mutaciones sobre
la reconstrucción, los cinco tests de la suite que pinaban las negativas
convertidos en afirmaciones, y `AlterColumn` en `SharedSuite` para los seis
motores.

**Siguiente: `S5`** (uuid nativo y enum con CHECK desde el modelo, con la PK
intacta: TYP-01, TYP-03 y QK-29).
