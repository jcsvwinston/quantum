# A8 — Quark enterprise

> **El troceado salió de la MEDICIÓN, no del enunciado.** El plan a 5/5
> describía este arco como «migraciones v2 (diff declarativo, `migrate diff`,
> plan hash) y RLS en tres motores», escrito meses antes de que nadie mirara.
> `S0` midió y corrigió las dos mitades: dos de las tres cosas de migraciones
> ya existían y la tercera no significa lo que el plan suponía; y «RLS en tres
> motores» daba por supuesto que hay algo en más de uno, cuando el RLS nativo
> es PostgreSQL y nada más. Es la cuarta vez que la medición corrige el plan.

**Precondición del arco**: Quantum 1.34.0 certificado (A7 cerrado).
**Gate del arco** — CUMPLIDO el 2026-09-20, registrado como guard
`umbrella-quark-posture` y publicado en Quantum 1.35.0: el registro
`docs/auditoria/madurez-2026-09-03/registro.csv` sin hallazgos abiertos de A8
(QK-25 a QK-31 hechos; QK-24 y QK-32, rompientes, en A12), y el banco
publicando su cifra: **47 de 69** controles presentes, desde 20.

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
| `S5` | uuid nativo y enum con CHECK desde el modelo | S0 | **HECHA** — quark#409: `TYP-01`, `TYP-02` y `TYP-03` a `present`; banco 38 de 69 |
| `S6` | Arrays de PostgreSQL, rangos e inet | S5 | **HECHA** — quark#411: `TYP-04`, `TYP-06` y `TYP-07` a `present`; banco 42 de 69 |
| `S7` | `precision/scale` deja de secuestrar, y la matriz de tipos deja de mentir | S5 | **HECHA** — quark#410: `TYP-11` a `present`, QK-28 y QK-30 cerrados; banco 39 de 69 |
| `S8` | RLS fuera de PostgreSQL: qué recibe cada motor, y la verificación | S1 | **HECHA** — quark#412: `RLS-02` y `RLS-04` a `present`, `RLS-01` `partial` medido y decidido; banco 44 de 69 con `S6` |
| `S9` | Paginación por cursor / keyset | S0 | **HECHA** — quark#413: `OPS-15` a `present`; banco 45 de 69 |
| `S10` | El CLI: `migrate diff/plan/verify` y las políticas de tenant | S3, S8 | **HECHA** — quark#414: `MIG-11` y `RLS-06` a `present`; banco 47 de 69 |
| `S11` | Gate, guard y set | todas | **HECHA** — quantum#(set 1.35.0): `umbrella-quark-posture` registrado con su fixture; quark v1.15.0 y el set certificado |

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

### `S5` — uuid nativo y enum con CHECK desde el modelo (2026-09-20) · **hecha**

**PR**: quark#409 (`feat(model)`). **Medido**: `tipos` de 3 a **6 present**;
el banco de 35 a **38 de 69**. Cierra **QK-29**.

**Lo que entrega.** (1) **La forma UUID**: un array de 16 bytes —la forma de
`google/uuid.UUID` y de todo UUID del ecosistema— recibe `UUID` en PostgreSQL
y en SQLite (nombre de tipo declarado; el texto se guarda como texto bajo su
afinidad NUMERIC porque un UUID nunca es un número bien formado), `CHAR(36)`
en MySQL/MariaDB, `VARCHAR2(36)` en Oracle y `NCHAR(36)` en SQL Server. El
`UNIQUEIDENTIFIER` de SQL Server se descarta a propósito: su driver lo lee
como dieciséis bytes en el orden mixto del motor, que un `Scanner` que espera
el orden RFC lee como OTRO UUID. El valor viaja en texto por el
`Valuer`/`Scanner` del propio tipo; como clave, `UUID PRIMARY KEY` sin
autoincremento inferido. (2) **La clave mapeada conserva su clave (QK-29)**:
`SQLTypeWithOpts` devolvía el tipo del mapper ANTES del sufijo y el ejemplo
documentado para claves UUID creaba tablas sin clave. Ahora el tipo del
mapper va tal cual y `PRIMARY KEY` se añade salvo que el mapper lo escriba.
(3) **El modelo declara CHECK**: `quark:"check=<expr>"` literal o
`db:"col,enum=a|b|c"` como lista `IN`; `Migrate` los emite como
`CONSTRAINT ck_<tabla>_<columna> CHECK (…)` —la forma que la reconstrucción
de SQLite sabe leer— y `PlanMigration` los lleva en el esquema deseado. Un
`check=` o `enum=` vacío es error de etiqueta. El divisor de tokens de la
etiqueta `quark` deja de partir por las comas de dentro de paréntesis y
comillas.

**Trampa del propio repo**: la matriz de tipos publicada la GENERA un test
(`-write-type-matrix`); una fila a mano la deja rancia y el test lo dice. La
fila UUID se añade al generador, no al `.mdx`.

**Método**: tests de raíz (tipo por dialecto y como clave; ida y vuelta del
UUID; el id duplicado rechazado; ambas gramáticas, la coma dentro de la
expresión, la aplicación del CHECK, plan vacío tras migrar y CHECK que
sobrevive a la reconstrucción; etiquetas vacías como error), dos
mutaciones, y `ModelTypesAndChecks` en `SharedSuite` para los seis motores.

**Siguiente: `S7`** (`precision/scale` deja de secuestrar el tipo base y la
matriz deja de mentir: TYP-11, QK-28, QK-30), y después `S6`.

### `S7` — `precision/scale` deja de secuestrar, y la matriz deja de mentir (2026-09-20) · **hecha**

**PR**: quark#410 (`fix(migrate)`). **Medido**: `tipos` de 6 a **7 present**;
el banco de 38 a **39 de 69**. Cierra **QK-28** y **QK-30**.

**Lo que entrega.** `applyPrecisionScale` sustituía el tipo base de CUALQUIER
campo con la pista sin mirar el tipo Go —un `string` salía `DECIMAL(10,2)`,
un `bool` `DECIMAL(3)`— y su godoc describía lo contrario. Ahora refina sólo
`float32`, `float64` y `Nullable` de ellos a `DECIMAL(p,s)` —`NUMBER(p,s)` en
Oracle, la grafía del motor— y en cualquier otro tipo la pista se ignora con
un **aviso de etiqueta** que nombra el campo: un no-op silencioso no se
confunde con una etiqueta que funciona. `normalizeType` lee `numeric(p,s)`
(PostgreSQL) y `NUMBER(p,s)` (Oracle) como `decimal(p,s)`, así que un plan con
un decimal dimensionado converge en los dos; el `NUMBER` desnudo de Oracle
sigue casando con sus formas dimensionadas y `NUMBER(19)` sigue siendo el
entero. **QK-30**: la fila de slices y maps de la matriz decía «se serializan
como texto» —`database/sql` los rechaza en la primera escritura— y ahora lo
dice y apunta a `Array[T]`/`JSON[T]`; el roadmap deja de llamar «nativo en
PostgreSQL» a `Array[T]`, que es JSON en los seis (el array nativo para slices
es `S6`).

**Trampa pequeña**: el bool de Oracle es `NUMBER(1)` de nacimiento; un test
que buscaba «ningún NUMBER» en el bool con pista medía el motor, no la pista.

**Siguiente: `S6`** (arrays de PostgreSQL, rangos e inet: TYP-04, TYP-06,
TYP-07).

### `S6` — arrays de PostgreSQL, rangos e inet (2026-09-20) · **hecha**

**PR**: quark#411 (`feat(types)`). **Medido**: `tipos` de 7 a **10 present**
(la familia queda en 10 present · 1 partial · 0 absent); el banco de 39 a
**42 de 69**.

**Lo que entrega, por adición.** (1) **Los slices y maps crudos se
almacenan**: `[]string`, `[]int64` o `map[string]any` recibían columna y
fallaban en la primera escritura en el conversor de `database/sql`; ahora
Quark los liga y los lee — en PostgreSQL un slice de tipo escalar es un array
nativo (`TEXT[]`, `BIGINT[]`, `DOUBLE PRECISION[]`, `BOOLEAN[]`) y el valor
viaja como literal de array; en el resto, y para maps y slices de structs en
todos, la columna es el tipo JSON del dialecto. `Array[T]` sigue siendo el
envoltorio JSON en los seis. (2) **`quark.Range[T]`** (`Lower`, `Upper`,
`Bounds` con `"[)"` por defecto, `Empty`): `TSTZRANGE`/`INT8RANGE`/
`INT4RANGE`/`NUMRANGE` en PostgreSQL con el literal de rango en el cable, JSON
en el resto; `Scan` lee ambas formas. (3) **`net.IP` es una dirección, no
cuatro bytes**: `INET` en PostgreSQL, texto en el resto, ligada y leída en su
forma textual (y desde los bytes crudos de una fila anterior). (4) **Los
operadores de PostgreSQL son conocidos y se rehúsan por motor**: `@>`, `<@`,
`&&`, `<<`, `>>`, `<<=`, `>>=` entran en la lista del guard, y fuera de
PostgreSQL el builder los rehúsa con `ErrUnsupportedFeature` nombrando el
motor antes de emitir SQL — en SELECT, UPDATE, DELETE y el AST. Nada se
reescribe a una aproximación, y MySQL no llega a leer `<<` como
desplazamiento. (5) El introspector de PostgreSQL lee arrays (el
`information_schema` sólo dice `ARRAY`; el elemento va en `udt_name`) y
tipos de usuario como los rangos por `udt_name`, así que el plan converge.

**Los tres controles, retitulados a lo que SQLite puede medir**: la ida y
vuelta, el JSON en la columna, y el operador conocido y rehusado por motor
(un rechazo de la lista —`ErrInvalidQuery`— es el estado de `S0`: el
operador no existía). Los tipos nativos y las respuestas de los operadores
se prueban en `NativeTypes` de `SharedSuite` sobre PostgreSQL. TYP-08 acepta
el rechazo por motor como el mismo hecho que registraba.

**Método**: tests de raíz (literal de rango y JSON en ambos sentidos; el
literal de array con comas, comillas y barras en los elementos; el lector de
IP sobre texto, `inet` con máscara y bytes; ida y vuelta completa en SQLite
con tipos y plan; cada operador rehusado por motor y `@@` por la lista; bajo
un cliente de dialecto PostgreSQL el bind del WHERE es el literal y el DDL
los tipos nativos), `NativeTypes` en la suite, y el exerciser `NATIVETYPES`
en el arnés para que el gate estricto cubra los métodos de `Range`.

**Siguiente: `S8`** (RLS fuera de PostgreSQL: qué recibe cada motor, y la
verificación: RLS-01, RLS-02, RLS-04).
### `S8` — RLS fuera de PostgreSQL: qué recibe cada motor, y la verificación (2026-09-20) · **hecha**

**PR**: quark#412 (`feat(tenancy)`). **Medido**: `rls` de 4 a **6 present**
(RLS-02 y RLS-04); RLS-01 conserva su `partial` MEDIDO con la decisión en la
nota. Banco: 44 de 69 una vez fusionadas `S6` y `S8`.

**Lo que entrega.** (1) **La tercera puerta falla cerrada (RLS-02)**:
`GetClient` —el método de `ClientProvider`, exportado y documentado—
devolvía el `BaseClient` bajo `RowLevelSecurityNative` en un motor sin RLS
nativo, y una lectura a través suyo devolvía las filas de todos los
inquilinos; ahora rehúsa con `ErrUnsupportedFeature` como `For` y `Tx`.
(2) **El router verifica antes de servir (RLS-04)**: en PostgreSQL comprueba,
una vez por tabla al primer uso, que `pg_class.relrowsecurity` está activo y
existe al menos una `pg_policy`, y rehúsa con `ErrRLSNotEnforced` si no —
desactivado, sin política, o un catálogo que no puede leer—. Antes, un router
Native servía filas sobre una base cuyas políticas nunca se instalaron, sin
una palabra; `quarktenant.VerifyRLSPolicies` existía y nada lo llamaba. Esa
función sigue siendo el preflight detallado (nombre de la política, `FORCE`,
qué dice el predicado) y ahora informa con el sentinela de la raíz.
`TenantConfig.SkipPolicyVerification` lo apaga para políticas gestionadas
fuera de la vista de Quark; los tres tests de la suite que miden otra cosa
bajo Native (retención, durabilidad, aviso de SQL crudo) lo usan. (3) **Una
lectura sobre una consulta que falló al construirse dice por qué**: `List`,
`First` y `Find` miraban `q.client == nil` antes que `q.err`, así que un
proveedor rehusado salía como «client not initialized» — la lección de `S1`,
cerrada en su origen.

**La decisión de RLS-01, escrita.** El RLS nativo sigue siendo sólo
PostgreSQL, y `S8` decide dejarlo así: el `SESSION_CONTEXT` de SQL Server y
el contexto de sesión de Oracle son de SESIÓN — fijados dentro de una
transacción sobreviven a su commit en la conexión del pool, y el siguiente
inquilino que tome esa conexión hereda la identidad del anterior salvo que
todos los caminos la limpien —, donde el `set_config(..., true)` de
PostgreSQL es de transacción. Quark no ofrece una estrategia que no pueda
hacer segura sobre un pool. La guía multi-tenant lleva ahora la tabla de qué
recibe cada motor: PostgreSQL Native o Client; los otros cinco Client, y
Native rehúsa por las tres puertas.

**Trampa del banco**: las sondas de MECANISMO (qué variable fija el router,
cómo escopa la caché) corren sobre un SQLite con forma de PostgreSQL que no
tiene `pg_class`; la verificación al primer uso las habría rehusado todas.
Sus routers la saltan y lo dicen; RLS-04 es el control que mide la
verificación y construye el suyo con ella activa.

**Siguiente: `S9`** (paginación por cursor / keyset: OPS-15) — ya escrita en
rama, pendiente de rebase y CI.

### `S9` — paginación por cursor / keyset (2026-09-20) · **hecha**

**PR**: quark#413 (`feat(query)`). **Medido**: OPS-15 a `present`; el banco de
44 a **45 de 69**.

**Lo que entrega.** `Paginate(pageSize, page)` es paginación por número de
página —un `COUNT` y un `OFFSET` por página, así que la página N hace al
servidor recorrer todas las anteriores— y conserva su contrato para quien
quiere un total. **`PaginateAfter(pageSize, token)`** es paginación por
keyset (seek): una sola sentencia por página que busca la última fila leída
a través del `ORDER BY` de la consulta —`a > ? OR (a = ? AND b < ?)`, la
comparación de tuplas desarrollada porque SQL Server y Oracle no la tienen—,
con la clave primaria añadida al orden para que sea total y un empate no
salte ni repita filas. Devuelve `KeysetPage` con `Items`, `HasMore` y
`Next`, un token opaco (el orden y los valores de la última fila) que se
rehúsa con `ErrInvalidQuery` si se le entrega a una consulta con otro
`ORDER BY`, en vez de buscar en el sitio equivocado. Toda columna del orden
debe ser columna del modelo, porque el token se construye con sus valores.

**Método**: tests de raíz (primera página plana, segunda con predicado y
sin OFFSET en una sentencia, última sin más; orden compuesto con empates y
un tramo DESC recorrido sin saltos ni repeticiones; token de otro orden,
basura, columna desconocida y orden sólo por PK), `Keyset` en `SharedSuite`
para los seis motores, y el exerciser `KEYSET` en el arnés.

**Trampa que casi llega dos veces a `main`**: `git add -A` tras correr el
arnés de aceptación se lleva `acceptance/REPORTS/` al commit —el
`.gitignore` ignoraba la ruta vieja de `examples/superapp`—. Entró en
`.gitignore` en este PR.

**Siguiente: `S10`** (el CLI: `migrate diff/plan/verify` y las políticas de
tenant; MIG-11, RLS-06; y el token `index` que `S3` dejó a deber).

### `S10` — el CLI: `migrate diff/plan/verify` y las políticas de tenant (2026-09-20) · **hecha**

**PR**: quark#414 (`feat(cli)`). **Medido**: MIG-11 y RLS-06 a `present`; el
banco de 45 a **47 de 69**.

**Lo que entrega.** Primero un rehúse en la raíz: `PlanMigration` sin
modelos devolvía el plan de borrar todas las tablas vivas —el esquema
deseado de «nada»—, y eso era lo que recibía un binario precompilado que no
lleva los modelos del usuario. Ahora falla con `ErrInvalidQuery` y nombra
los dos caminos honestos. Sobre eso, **`quark migrate diff | plan | verify
--from-models <dir>`**: el binario lee los structs con `go/packages` (el
lector que ya tenía `migrate create`), los mapea con la misma función de
tipos del runtime, arrastra del esquema vivo los índices, FK y CHECK que
las etiquetas no pueden nombrar (la regla de `PlanMigration`: lo no
declarado no se propone borrar) y diffea contra `IntrospectSchema`;
`verify` sale distinto de cero con deriva, así que es un gate de CI sin
compilar los modelos en nada. Y **`quark tenant install-rls-policies |
verify-rls-policies --from-models <dir>`**: los comandos que el ADR-0012 y
la guía imprimían, en el binario publicado —por cada tabla del modelo con
la columna de tenant, el DDL del runner (enable, force, drop-if-exists,
create policy sobre `current_setting(var, true)`), con `--dry-run`; verify
lee `pg_class`/`pg_policy` y sale con los huecos—, ambos limitados a
PostgreSQL. El `quarktenant.Run` embebible conserva sus acciones a pelo: es
otro programa, y el banco ya no lee su rehúse del prefijo `tenant` como
hueco. El lector estático aprende lo que el runtime aprendió en `S3` y `S5`
(`default`, `quark:"index"`/`index=<n>`, `check=<expr>` partido por comas
fuera de paréntesis y comillas, `db:"…,enum=a|b"`), `migrate create` los
emite y `quark model` acepta `index` — la deuda que `S3` dejó.

**Método**: tests del CLI sobre un módulo fixture (diff en base vacía
propone las dos tablas y verify falla; tras aplicar el DDL del propio
lector el plan está «in sync» y verify pasa, que es decir que el mapeo de
fuente y el del runtime coinciden; las etiquetas nuevas llegan al DDL y al
esquema deseado; el DDL de políticas byte a byte con la forma del runner,
la selección de tablas y la puerta de PostgreSQL). Los dos tests de la suite
que fijaban «sin modelos se borra todo» fijan ahora el rehúse y el borrado
con un modelo. Las sondas leen las fuentes del CLI —módulo aparte— y corren
el rehúse de la raíz.

**Trampas**: cargar un módulo fixture desde dentro del `go.work` del repo
falla con «not in workspace / outside main module» — `GOWORK=off` y
`Chdir` al módulo; y el test que exige `Example:` a todo subcomando
ejecutable cazó los cinco nuevos sin ejemplo.

**Siguiente: `S11`** (gate, guard y set: `umbrella-quark-posture` con su
fixture, y el tren que corta la MINOR de quark y certifica el set).

### `S11` — gate, guard y set (2026-09-20) · **hecha**

**PR**: el del set, `chore(set): Quantum 1.35.0`. **Medido**: nada nuevo en el
banco (47 de 69); lo que esta sesión mide es la frontera entre lo medido y lo
publicado.

**Lo que entrega.** El guard **`umbrella-quark-posture`**
(`scripts/check_quark_posture.sh`) con su fixture, el 52º del registro. Sobre
el árbol PINADO comprueba tres cosas: que el banco tiene sus 69 controles y
cada uno que no está `present` lleva nota que diga qué falta; que la cifra que
publica `quark/docs/enterprise-bench.md` es la que cuenta la tabla del banco;
y que las seis pruebas que el arco añadió a `SharedSuite` —`LikeEscape`,
`PlanConstraints`, `AlterColumn`, `ModelTypesAndChecks`, `NativeTypes`,
`Keyset`— siguen ahí. La tercera es la que distingue este guard de sus dos
hermanos: las sondas del banco corren sobre SQLite, y lo único del arco que se
ejecuta contra un motor real son esas pruebas en la lane de cada motor. Tres
veces una lane enseñó lo que ninguna sonda podía ver (ORA-01424 con `\[`, el
índice de respaldo de la FK en MySQL, el literal de rango de PostgreSQL); sin
ellas el banco seguiría verde y los motores dejarían de medirse. La fixture
rompe las tres cosas a la vez sobre una copia del banco real: cifra
falsificada, `Keyset` retirado de la suite, RLS-01 sin nota.

**Lo que NO comprueba**: que las sondas pasen — eso es `go test` en el CI de
quark, que es donde se ejecuta lo que mide.

**El tren**: quark v1.15.0 (minor: nueve `feat`, dos `fix`) con `cmd/quark`
v1.1.0 del mismo release PR; la deuda de doc pagada EN la rama del release y
en este orden —prosa, menciones, snapshot 1.15.0 cortado a mano porque
Docusaurus no arranca en el sandbox—; orbit alineado a los pines nuevos; el
paraguas re-pinado y el set certificado. Las trampas nuevas del tren, en
`scripts/train/README.md`.

**Lo que A8 deja a A12**: QK-24 (aviso desde v1.14.0) y QK-32 (la forma plana
de `LIKE`), los dos rompientes por definición. Y lo que deja al siguiente arco
que toque Quark: los 22 controles no presentes, cada uno con su nota en el
banco.
