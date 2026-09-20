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
| `S2` | `LIKE … ESCAPE` de punta a punta, por dialecto | S0 | Los 7 `absent` de `qk25` cerrados; ejercido en los cinco motores |
| `S3` | El plan lleva índices, FK y CHECK, y el ejecutor los emite | S0 | `MIG-01`, `MIG-03` y `MIG-06` a `present` |
| `S4` | `ALTER COLUMN` completo y reversibilidad más allá de CREATE/DROP | S3 | `MIG-07` y `MIG-09` a `present` |
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
