# Sesión 2026-09-20 — A8 cerrado en Quantum 1.35.0

> Archivado desde el §3 de `.claude/commands/next-session.md` el 2026-09-22,
> al entrar la sesión de A9 `S5`. Historia para buscar con grep, no para cargar.

### Sesión 2026-09-20 — **A8 `S1`–`S11` HECHAS, ARCO CERRADO en Quantum 1.35.0**: tenancy en transacción, `LIKE … ESCAPE`, el plan emite lo que lleva, `ALTER COLUMN` completo, uuid/enum, `precision/scale`, tipos nativos de PostgreSQL, el router Native que verifica, keyset, el CLI, y el guard del arco

**`S11` (el PR del set)** — guard `umbrella-quark-posture` con su fixture
(52º): 69 controles con nota en los ausentes, la cifra publicada es la que
cuenta la tabla, y las seis pruebas del arco siguen en `SharedSuite`. El tren:
quark v1.15.0 + `cmd/quark` v1.1.0 de un release PR; la deuda de doc pagada
EN la rama del release (prosa → menciones → snapshot a mano); orbit alineado;
set certificado. `registro.csv` cierra A8. Las trampas del tren, en
`scripts/train/README.md` (sección 1.35.0).


**`S10` (quark#414, `feat(cli)`)** — `PlanMigration` sin modelos rehúsa con
`ErrInvalidQuery` (antes: el plan de borrar todas las tablas vivas, que es
lo que recibía un binario sin los modelos del usuario). `quark migrate
diff|plan|verify --from-models <dir>` lee los structs con `go/packages`,
mapea con la función de tipos del runtime, arrastra lo no declarado del
esquema vivo y diffea; `verify` es un gate de CI. `quark tenant
install-rls-policies|verify-rls-policies --from-models` imprime/aplica el
DDL del runner y verifica en `pg_class`/`pg_policy`; sólo PostgreSQL. El
lector estático aprende `default`, `index`, `check`, `enum`; `quark model`
acepta `index`. MIG-11 y RLS-06 a `present`; banco **47 de 69**. Trampas:
`GOWORK=off` + `Chdir` para cargar un módulo fixture desde el `go.work`; el
test de `Example:` cazó cinco subcomandos.


**`S9` (quark#413, `feat(query)`)** — `PaginateAfter(pageSize, token)`: una
sentencia por página que busca la última fila leída por el `ORDER BY` (la
comparación de tuplas desarrollada, porque SQL Server y Oracle no la
tienen), PK añadida al orden, token opaco que se rehúsa bajo otro orden.
`Paginate` conserva su contrato con total. Banco **45 de 69**.
`acceptance/REPORTS/` al `.gitignore`.


**`S8` (quark#412, `feat(tenancy)`)** — `GetClient` falla cerrado bajo Native
fuera de PostgreSQL (RLS-02); el router verifica al primer uso por tabla que
el motor aplica RLS (`pg_class`, `pg_policy`) y rehúsa con
`ErrRLSNotEnforced` si no puede confirmarlo (RLS-04), con
`SkipPolicyVerification` como salida; `List`/`First`/`Find` dicen `q.err`
antes que «client not initialized». RLS-01 se queda en PostgreSQL con la
razón escrita: los contextos de sesión de SQL Server y Oracle sobreviven al
commit en el pool. Banco **44 de 69** con `S6`. Trampa de esta tanda: un
`git add -A` tras correr el arnés de aceptación se lleva `acceptance/REPORTS/`
al commit; quedó en `.gitignore` en `S9`.


**`S6` (quark#411, `feat(types)`)** — slices y maps crudos almacenados
(array nativo en PostgreSQL con literal de array en el cable, JSON en el
resto), `quark.Range[T]` (rangos nativos en PG, JSON en el resto), `net.IP`
como `INET`/texto en su forma textual, y los operadores `@>`, `<@`, `&&`,
`<<`, `>>`, `<<=`, `>>=` conocidos por el guard y rehusados POR MOTOR fuera
de PG con `ErrUnsupportedFeature` antes de emitir SQL; el introspector de PG
lee arrays y rangos por `udt_name`. Banco **42 de 69** (`tipos` 10/1/0).
Retitulados TYP-04/06/07 a lo que SQLite mide; PG lo prueba `NativeTypes`.


**`S7` (quark#410, `fix(migrate)`)** — la pista `precision/scale` refina sólo
flotantes (`DECIMAL(p,s)`, `NUMBER(p,s)` en Oracle) y en el resto se ignora
con AVISO de etiqueta (QK-28); `numeric`/`NUMBER(p,s)` son `decimal` para el
diff, así que el plan converge en PG y Oracle; la matriz de tipos y el
roadmap dejan de afirmar lo que el banco mide ausente (QK-30). Banco **39 de
69**. Trampa: el bool de Oracle es `NUMBER(1)` de nacimiento.


**`S5` (quark#409, `feat(model)`)** — forma UUID (`[16]byte`) con tipo por
motor (PG `UUID`, SQLite `UUID` declarado, MySQL `CHAR(36)`, Oracle
`VARCHAR2(36)`, SQL Server `NCHAR(36)` porque su `UNIQUEIDENTIFIER` se lee
en orden de bytes mixto); **la clave mapeada conserva `PRIMARY KEY`**
(QK-29); `quark:"check=<expr>"` y `db:"col,enum=a|b"` emitidos por `Migrate`
como `ck_<tabla>_<col>` y llevados por `PlanMigration`; el divisor de la
etiqueta respeta paréntesis y comillas. Banco **38 de 69**. Trampa: la
matriz de tipos se GENERA con `-write-type-matrix`; la fila va al generador.


**`S4` (quark#408, `feat(migrate)`)** — `OpAlterColumn` cubre tipo, nullable,
default y PK en los seis motores (PG por faceta; MySQL/MariaDB un `MODIFY`;
SQL Server por nombre de sus restricciones; Oracle un `MODIFY` de lo que
cambia), y **SQLite reconstruye la tabla** dentro de la transacción del
plan llevando índices, triggers, CHECK y nombres de FK leídos de
`sqlite_master` — con lo que FK y CHECK en SQLite dejan de rehusarse. Un
CHECK ilegible rehúsa la reconstrucción en vez de perderse. Banco **35 de
69**. La sonda MIG-07 medía nullable sobre una columna recién convertida en
PK: artefacto de orden, corregido. Detalle en el plan.


**`S3` (quark#407, `feat(migrate)`)** — QK-27: `applyCreateTable` emite la
tabla ENTERA (FK y CHECK inline, índices como `CREATE INDEX`); `Diff` crea
las tablas referenciadas primero, casa las FK por composición y no por
nombre (SQLite no lo guarda), lee la acción vacía como `NO ACTION` y casa un
índice por forma (el de respaldo de un `unique`); el modelo declara índices
con `quark:"index"` / `index=<nombre>` y `Migrate`/`PlanMigration` los leen;
los índices no declarados siguen sin tocarse a propósito. `migraciones` de
5 a 9 present, banco **33 de 69**. MIG-03 retitulado (borrar lo no declarado
se rehúsa por diseño) y su sonda vieja no tenía camino a `present`. Cinco
mutaciones, `PlanConstraints` en `SharedSuite` para los seis motores, que
cazó que **MySQL/MariaDB crean un índice de respaldo por cada FK** con el
nombre de la restricción: el introspector lo filtra ahora como el de la PK.
Queda para `S10`: el CLI no conoce `index`.


**`S2` (quark#406, `feat(query)`)** — la familia `qk25` del banco de 3/1/7 a
**11 present**; banco **29 de 69**. Por adición: `WhereLike`/`WhereNotLike`,
`WhereContains`/`WhereStartsWith`/`WhereEndsWith` con `EscapeLike`, los
tipados `Contains`/`StartsWith`/`EndsWith`/`LikeEscaped` y el AST
`Like`/`Contains`; la cola `ESCAPE` se escribe POR MOTOR (doblada en
MySQL/MariaDB, y SQLite rechaza la doblada) desde un helper que los cinco
renderizadores añaden; el guard rechaza el escape colgante; `SharedSuite`
lo prueba en los cinco motores. **La forma plana `Where(col,"LIKE",p)` no
cambia**: unificar su escape es rompiente → **QK-32** (A12). Cuatro controles
retitulados con su porqué escrito (su `present` sólo era alcanzable rompiendo
la forma publicada). QK-31 de paso: la lane de MariaDB falla en vez de saltar.
Trampas: buscar la palabra `ESCAPE` la encuentra en `like_escape_rows` (se
busca la cláusula); y **Oracle rechaza `\[` con `ORA-01424`** — el corchete
se escapa SOLO en SQL Server, donde es comodín, y lo vio la lane de Oracle,
no una sonda sobre SQLite. Detalle en el plan del arco.

**`S1` (quark#404)**:

- **PR quark#404** (`fix(tenancy)`), sobre la rama del primer corte. Los seis
  defectos que la revisión adversarial dejó abiertos se cierran así: (1) toda
  escritura mira `q.err` a la entrada, las copias internas de `BaseQuery` lo
  arrastran y `queryRowOn` lo acuña en el `*sql.Row` — el comentario que decía
  que «aflora solo en `Scan`» describía un mecanismo inexistente, y un
  `Create` bajo Native sobre SQLite ejecutaba su INSERT sin aislamiento
  alguno; (2) `NewTenantRouter` estampa el `BaseClient` y `Client.BeginTx`
  confina la transacción si el contexto lleva inquilino, así que
  `GetClient`+`client.Tx` es la misma puerta que `router.Tx`; (3) `Preload`
  cualifica la tabla de la relación (`qualifiedTable`, por donde pasa ya toda
  tabla que una consulta toca); (4) `DatabasePerTenant` no re-resuelve del
  contexto de la consulta: hereda; (5) `RLS-13` exige evidencia POSITIVA —un
  schema `ATTACH`ado en SQLite con una fila que sólo vive ahí, y el predicado
  ligado a ESE inquilino con sólo sus filas de vuelta—, y revertir el
  confinamiento de `ForTx` la pone en `partial`; (6) **decisión escrita en el
  ADR-0025 de quark: la transacción fija el inquilino** — un contexto sin
  inquilino lo hereda, uno que nombre a otro falla con `ErrTenantMismatch`
  (API nueva, aditiva).
- **Banco: 21 de 69** (27 parciales, 21 ausentes). Se movió un solo control;
  era el P1.
- **Método**: cada test de regresión se verificó **revirtiendo su arreglo**
  (cuatro mutaciones; cada una puso rojo el test que debía y ninguno más). La
  lección del primer corte —un parámetro declarado, documentado y no leído—
  se pagó así: el booleano `inTx` pasó a ser el propio `*Tx`, que además
  decide QUÉ inquilino, de modo que no leerlo ya no compila.
- **Lo que enseñó, y vale para el arco**: `For[T]` sin inquilino ya se
  rechazaba, pero **por la razón equivocada** («client not initialized»,
  porque `GetClient` falló antes de llegar al confinamiento); la fuga real
  era la consulta que SÍ tenía cliente y falló al construirse (Native sobre
  un motor que no es PostgreSQL). El primer test que escribí para el defecto
  pasaba con el arreglo revertido — lo destapó la mutación, no la lectura.
- **Siguiente: `S2`.** Precondición: quark#404 fusionado. La deuda de doc de
  la release (RT-9) la paga el tren; el snapshot, si la release es minor, va
  ANTES del release PR.
