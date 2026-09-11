# A4 — Quark como capa de datos de Nucleus

> Lee antes [`README.md`](README.md): el contrato de sesión, qué fichero manda
> para cada pregunta y qué no decide una sesión sola.

**Qué entrega.** Nucleus deja de tener dos capas de datos. Hoy convive
`pkg/model` con Quark, y esa duplicidad es lo que lo separa de Django y de
Rails: en aquellos hay UNA capa, la que el generador escribe y la que las
migraciones leen.

**Gate del arco** (se registra como guard cuando esté, igual que los demás):

- el showcase y el starter se generan con `--data quark` y pasan el smoke;
- el banco de 60 consultas se expresa tipado, sin `RawQuery`;
- un guard de mapeo de tags corre en quark y en nucleus.

**Hallazgos que descuenta.** Cinco, todos abiertos por la medición de `S0`:
QK-21 (P1), QK-22, QK-23 y NU-50 (P2), QK-24 (P3). La versión anterior de esta
línea decía que A4 no heredaba filas; era verdad hasta que se midió.

**La decisión que lo condicionaba, ya tomada.** [QADR-0010](../adr/QADR-0010-rupturas-agrupadas-en-un-major.md)
(2026-09-10): lo rompiente se acumula en **un único major al cierre de A12**.
Hasta entonces, un arco que necesite romper algo entrega la forma nueva junto
a la vieja y deprecia la vieja con retirada **en ese major**. Con eso `S2` y
`S6` dejan de estar bloqueadas — y quedan con una condición: si su cambio no
se puede entregar por adición, la sesión **para y lo dice**, no corta un
major por su cuenta.

---

## S0 · Medir antes de trocear

**Precondición**

```bash
bash scripts/check_audit_backlog.sh | tail -1   # ha de decir: arcos cerrados: A1 A2 A3
```

**Qué produce.** Un documento en quark y otro en nucleus, con los comandos al
lado de cada cifra, que responden a lo que el troceado de abajo da por hecho:

1. **El banco de 60 consultas.** Escribirlo si no existe: 60 consultas reales
   (CTE recursiva, window, set ops, lateral, JSON path, locking) y, por cada
   una, si hoy se expresa tipada o exige `RawQuery`. Es el numerador del gate,
   y hasta que exista el gate no se puede medir.
2. **Qué hace `pkg/model` que Quark no.** Inventario símbolo a símbolo, no
   impresión. Lo que Quark ya cubre, lo que le falta y lo que no debería
   cubrir nunca.
3. **Qué gramáticas de tags hay en el árbol** (`db`, `quark`, `validate`,
   `admin`) y en qué se contradicen sobre un mismo campo.
4. **Qué tipos soporta cada motor hoy**, medido contra motores reales, no
   contra la documentación.

**Criterio de hecho**

```bash
ls quark/docs/query-bench.md nucleus/docs/pkg-model-vs-quark.md
```

**Al terminar: reescribe S1–S8 de este fichero con lo medido.** Si alguna
sesión de abajo resulta innecesaria o mal dimensionada, se dice y se cambia.
Las tres veces anteriores la medición corrigió el plan.


**HECHA el 2026-09-11.** Lo que midió y lo que cambió del plan, abajo.

### Lo que S0 midió

Cuatro cifras, cada una con el comando que la reproduce:

1. **El banco de 60 consultas: 44 tipadas, 4 que emiten SQL equivocado, 12 sin
   API.** Escrito y ejecutable en
   `quark/internal/enginesuite/querybench_cases_test.go`; documento en
   [`quark/docs/query-bench.md`](../../quark/docs/query-bench.md).
   `cd quark/internal/enginesuite && go test -run TestQueryBench -v .`
2. **`pkg/model` frente a quark, símbolo a símbolo**: siete capacidades están
   en `pkg/model` y no en quark, y sólo tres son trabajo de capa de datos.
   [`nucleus/docs/pkg-model-vs-quark.md`](../../nucleus/docs/pkg-model-vs-quark.md).
3. **Las gramáticas de tags se contradicen** sobre el mismo tag `db`, en
   silencio y en las dos direcciones (NU-50).
4. **Las dos capas generan esquemas distintos para el mismo modelo**, y quark
   colapsa toda anchura de entero en un `INTEGER` (QK-21).

### Lo que eso cambió del troceado

El plan escrito de S1 apuntaba a `Raw[T]`, `Select[T]` a DTO, `Exists`,
`Pluck`, `FirstOrCreate` y preload con condiciones. La medición dice que de
esos, sólo dos aparecen entre las dieciséis consultas que hoy no se pueden
escribir: la proyección a DTO y el preload filtrado. `Exists`, `Pluck` y
`FirstOrCreate` son azúcar —ninguna consulta del banco los necesita para
dejar de usar `RawQuery`— y la causa mayor, la whitelist de funciones del
AST, **no estaba en el plan**.

Las dieciséis consultas salen de **siete causas**, así que las sesiones van
por causa y no por consulta. Cinco hallazgos nuevos entraron en el registro:
QK-21 (P1), QK-22, QK-23, NU-50 (P2) y QK-24 (P3). **A4 sí hereda filas
ahora**, al contrario de lo que decía la cabecera de este fichero.

| antes | ahora | por qué |
|---|---|---|
| S1 huecos de consulta | S1, S2, S3 | una sesión no cubre siete causas; se reparten por causa, de mayor a menor rendimiento |
| S2 valores cero en `Update` | **retirada** | no aparece en el banco: ninguna de las 60 la necesita. Vuelve al backlog hasta que algo la pida |
| S3 tipos por motor | S4 | primero el rango de los enteros que ya existen (QK-21), y sólo después decimal/uuid/arrays |
| S4 migraciones | S5 | sin cambio de alcance |
| S5 `--data quark` | S7 | depende del linter de tags, que sube |
| S6 `pkg/model` a sustrato | S8 | con la corrección de que el CRUD sin tipos es un requisito, no legado |
| S7 linter de tags | S6 | sube: NU-50 bloquea a `--data quark`, así que va antes |
| S8 gate y set | S9 | sin cambio |

---

## S1 · quark — la whitelist de funciones del AST

**Precondición**

```bash
cd quark/internal/enginesuite && go test -run TestQueryBench .   # verde con los veredictos de hoy
```

**Por qué primero.** Es la causa mayor: cuatro de las dieciséis (Q24
`COUNT(DISTINCT)`, Q25 agregado condicional, Q45 `NTILE`, Q52 proyección
JSON). `Func` sólo acepta diez nombres —`COUNT, SUM, AVG, MIN, MAX, LOWER,
UPPER, LENGTH, COALESCE, ABS`— y renderiza el nombre directo al SQL.

**Cuidado.** La whitelist **es una barrera de seguridad**, no un descuido.
Ampliarla es una decisión sobre esa barrera: o una lista mayor, o un
constructor tipado por función que no pueda llevar una cadena arbitraria. La
segunda forma no cabe en la primera; elegir es parte de la sesión, y la
elección se escribe. Y `CASE` no es una función: necesita forma propia.

**Criterio de hecho**: Q24, Q25, Q45 y Q52 cambian de veredicto y
`TestQueryBench` lo exige.

---

## S2 · quark — seleccionar de algo que no sea la tabla del modelo

**Precondición**: S1 hecha (comparten el constructor de expresiones).

**Alcance**: `quark`. QK-23 y QK-22 tienen la misma raíz: el `FROM` siempre es
la tabla de `T`. De ahí salen cuatro consultas —Q33 (tabla derivada), Q44
(top-N por grupo), Q36 y Q37 (CTE recursiva de verdad)—.

**Cuidado.** Q36 es el caso más engañoso del banco: `WithRecursive` emite la
palabra clave y el cuerpo no recurre, así que la API afirma hoy una capacidad
que no tiene. Lo que se entregue tiene que poder ligar término ancla y
término recursivo en un cuerpo, y referenciar la CTE desde dentro de sí misma.

**Criterio de hecho**: Q33, Q36, Q37 y Q44 cambian de veredicto; QK-22 y QK-23
pasan a hechos.

---

## S3 · quark — las seis restantes

**Precondición**: S2 hecha.

**Alcance**: `quark`. Lo que queda del banco, que ya no comparte causa:

- **Q17, proyección a DTO** — `For[T]` deriva el `FROM` de `T`, así que un DTO
  se traduce en `FROM order_emails`. Es lo que obliga a `RawQuery` a toda
  consulta cuya forma de resultado no sea exactamente un modelo registrado.
- **Q16, preload filtrado** — y con él la trampa: `Preload` es variádico sobre
  NOMBRES, así que `Preload("Orders", "status = ?")` compila, y sólo falla
  cuando la consulta padre devuelve filas.
- **Q43, frame de ventana** — omitirlo no es una versión menor de la consulta:
  una media móvil se convierte en acumulada, sin avisar.
- **Q60, expresión en el `SET`** — `stock = stock - 1`. Leer-modificar-escribir
  no es equivalente: pierde la atomicidad que es la razón de escribirlo en SQL.
- **Q14 y Q18** — literal en la cláusula `ON`, y `FULL OUTER`/`CROSS JOIN`.
- **QK-24** — `GroupBy` sin `Select()` deja `SELECT *`.

**Cuidado**: la superficie pública de quark está congelada por contract tests.
Añadir es seguro; cambiar una firma existente cae en QADR-0010. `Preload` es
el caso a vigilar: darle condiciones sin romper la firma variádica actual.

**Criterio de hecho**: `TestQueryBench` dice 60 tipadas, 0 wrong-sql, 0 no-api.

---

## S4 · quark — la anchura de los tipos, y luego la matriz

**Precondición**: un motor real disponible. **S0 no pudo medir contra motores
reales** (sin runtime de contenedores), y esta sesión no empieza sin ellos.

**Alcance**: `quark`. En dos mitades, y la primera manda:

1. **QK-21, el defecto.** Todo entero Go colapsa en `INTEGER` y todo flotante
   en `REAL` (PostgreSQL, SQLite); la PK autoincremental sale `SERIAL`. Antes
   de nada, **confirmar el comportamiento por motor** — PostgreSQL, MySQL en
   sus dos modos, MSSQL — que S0 dejó sin confirmar a propósito.
2. **Los tipos nuevos**: decimal, uuid nativo, enums con CHECK, arrays de
   PostgreSQL, rangos, inet, JSONB con operadores.

**Cuidado.** Cambiar el DDL generado **toca esquemas ya creados**: una tabla
existente tiene hoy `INTEGER` donde la versión nueva pondría `BIGINT`. Si eso
no cabe por adición, QADR-0010 dice lo que hay que hacer: **PARAR y decirlo**,
no cortar un major por cuenta propia.

**Criterio de hecho**: la matriz publicada y **generada**, no escrita, con una
lane que la comprueba contra motores reales.

---

## S5 · quark — migraciones generadas desde el modelo

**Precondición**: S3 y S4 hechas (el generador necesita conocer los tipos).

**Alcance**: `quark`. Generar la migración desde el modelo, reversible, con
`down` generado. `pkg/model` ya sabe hacerlo para cinco dialectos
(`BuildXMigrationScaffold`): es una de las tres capacidades que el inventario
marcó como trabajo de capa de datos que quark hace de otra forma —planifica y
aplica contra la base viva en vez de emitir ficheros—.

**Cuidado**: NO es el arco de migraciones v2 (diff declarativo, `migrate
diff`, plan hash), que es **A8**.

**Criterio de hecho**: generar, aplicar y revertir sobre los seis motores en
CI, con el esquema volviendo byte a byte al de partida.

---

## S6 · el linter de tags común

**Precondición**: S0 hecha. Sube de la posición 7 a la 6 porque NU-50 bloquea
a `--data quark`: generar modelos antes de arreglar esto es generar modelos
que una de las dos capas lee mal.

**Alcance**: quark y nucleus. Las dos gramáticas del tag `db` se contradicen
—coma contra punto y coma, nombre de columna contra directiva— y **ninguna de
las dos avisa**. La tabla de la contradicción, medida, está en
`nucleus/docs/pkg-model-vs-quark.md` §2.

**Cuidado**: es un **guard del gate**, así que necesita fixture y entrada en
`scripts/lib/guard-registry.sh`. Y como comprueba algo de los productos, no se
puede registrar hasta que el pin lo contenga: se escribe con su fixture, entra
en `GUARD_SCAN_EXCLUDE` con su porqué, y se registra en el commit del set que
mueve los gitlinks.

**Criterio de hecho**: la fixture muerde con la causa que declara,
`guard-of-guards` pasa, y NU-50 pasa a hecho.

---

## Deuda con destinatario: el espejo del sidebar

`S4` publicó `website/docs/reference/type-matrix.mdx` en quark, y el paraguas
sirve la navegación desde un espejo (`website/sidebarsQuark.ts`) que se
compara contra el sidebar **del pin**. Añadir la entrada ahora deja
`umbrella-sidebar-sync` en rojo: apunta a una página que el pin todavía no
tiene.

Es la misma mecánica que la de los guards que esperan al pin, y la entrada va
en el commit del set, junto a los gitlinks. `S9` la incluye.

---

## S7 · nucleus — `generate module --data quark`

**Precondición**: S3, S5 y S6 hechas y publicadas en un tag de quark que el
paraguas pueda pinar. **Ojo al borde**: nucleus no puede requerir una versión
de quark que no exista; si no han salido en release, esta sesión espera o el
tren corta antes.

**Alcance**: `nucleus`. `generate module --data quark` escribe modelo,
repositorio tipado, registro en `quarkdatasource`, migración y test.

**Cuidado**: el generador es el embudo de entrada, y su recorrido está medido
por el quickstart de suite (guards `quickstart-cost` y `quickstart-embeds`,
lane `quickstart-smoke`). Si el número de conceptos o de comandos sube, esos
guards lo dicen: es una regresión del arco A2, no un efecto colateral
aceptable.

**Criterio de hecho**: `nucleus new` + `generate module --data quark` arranca y
sirve un endpoint, en el smoke, sin pasos manuales.

---

## S8 · nucleus — `pkg/model` a sustrato

**Precondición**: S7 hecha.

**Alcance**: `nucleus`. `pkg/model` deja de aparecer en la documentación de
usuario y pasa a ser sustrato interno del framework.

**Lo que el inventario corrigió.** El plan daba por hecho que `pkg/model` se
retira en favor de `Query[T]`. **No se puede tal cual**: el panel sirve
modelos que no puede nombrar en tiempo de compilación, y el CRUD sobre
`interface{}` es un requisito, no legado. De las siete capacidades exclusivas,
dos —metadatos de presentación y mutación de metadatos en caliente— deberían
salir de la capa de datos pase lo que pase con el arco: son vocabulario del
panel viviendo en el registro de modelos, y son la razón de que las dos capas
se parezcan más de lo que son.

**Cuidado**: `pkg/model` está en el freeze de contratos
(`nucleus/scripts/ci/check_contract_freeze.sh`). Sacarlo de la documentación
no es sacarlo del contrato: lo segundo es la ruptura, y va al major de A12
(QADR-0010).

**Criterio de hecho**: el guard de cobertura de docs no encuentra `pkg/model`
en las páginas de usuario, y el freeze sigue en verde.

---

## S9 · el gate, y el set que publica el arco

**Precondición**: S1–S8 hechas.

**Qué hace**

1. Registra el guard del gate (S6) y el del banco de consultas.
2. Añade `A4` a la primera línea de
   `docs/auditoria/madurez-2026-09-03/registro.csv`.
3. Corta el set con el tren, con `scripts/train/README.md` delante.

**Criterio de hecho**

```bash
bash scripts/check_audit_backlog.sh    # ha de decir: arcos cerrados: A1 A2 A3 A4
bash scripts/suite-integral.sh --cierre
```

**Y una comprobación que este arco NO puede dar por hecha**, porque el corte
de 1.30.0 enseñó que no se ve desde el árbol: que la release del set y las de
los tres productos hayan publicado **activos firmados de verdad**. Los guards
de cadena de suministro leen el árbol —que declara `sboms:` y `signs:`— y un
release que falla al firmar sale verde. Se mira a mano, o se le pone guard.

---

## Registro de sesiones

Se rellena al terminar cada una: el PR que la cierra y lo que se midió.

| Sesión | Estado | PR | Qué midió o cambió del plan |
|---|---|---|---|
| S0 | **hecha** 2026-09-11 | quark#388, nucleus#518, quantum#181 | 44/60 tipadas; 16 huecos de 7 causas; las dos gramáticas de `db` se contradicen en silencio; las dos capas emiten esquemas distintos. Retiró la sesión de valores cero, partió S1 en tres y subió el linter de tags |
| S1 | **hecha** 2026-09-11 | quark#389 | 44 → **48**. La whitelist NO se amplió: ninguno de los cuatro casos pedía más nombres, sino formas propias (`CountDistinct`, `Case`, `JSONExtract`, seis leaves de ventana). Los motores reales destaparon tres límites que SQLite no ve |
| S2 | **hecha** 2026-09-11 | quark#391 | 48 → **52**, y sólo uno de los cuatro casos necesitaba código: `FromCTE`. **QK-22 y QK-23 eran errores de medición** — la CTE recursiva ya funcionaba, y lo que S0 leyó fue un comentario fósil. Una medición que se fía de un comentario mide el comentario |
| S3 | **hecha** 2026-09-11 | quark#392 | 52 → **58**, y cero casos sin API. Los seis one-offs: `FromTable`, `PreloadWhere`, frames de ventana, aritmética en el `SET`, `OnExpr`, `FullJoin`/`CrossJoin` |
| S4 | **hecha** 2026-09-11 | quark#393 | QK-21 **confirmado** contra motores reales (MySQL: «Out of range value») y arreglado. Destapó que el diff comparaba el tipo de una PK sin pasar por el camino de la PK. Matriz de tipos **generada** y publicada |
| S5 | **hecha** 2026-09-11 | quark#394 | `Plan.Down`, y el ida y vuelta verificado comparando el **catálogo** en los seis motores. Lo irreversible da error nombrando qué falta, en vez de un rollback que dice que fue bien |
| S6 | **hecha** 2026-09-11 | quark#395, nucleus#520, quantum#182 | NU-50 cerrado por los dos lados y el guard `umbrella-tag-grammar` con fixture: **48 guards** |
| S7 | **hecha** 2026-09-11 | nucleus#522, quantum#183 | La capacidad ya estaba (A2 la adelantó): el generador emite el modelo con la gramática de quark y sirve el endpoint. Lo que faltaba era el gate, y al correrlo cazó dos defectos del código generado — `List()` sin `Limit` (WARN en la primera petición) y un filtro aplicado DESPUÉS de la página |
| S8 | **parcial** 2026-09-11 | nucleus#523 | La doc de usuario deja de llamar «capa de datos» a `pkg/model` y dice para qué es. **PARA ahí**: completarla exigiría afirmar que Quark es la capa por defecto, y `--data` sigue por defecto en `sql`. Cambiar ese defecto es del propietario (QADR-0010) |
| S9 | pendiente | — | el gate del arco está puesto (`quickstart-smoke` con la sonda `--data quark`, `umbrella-tag-grammar`); falta el set que lo publica |

### Lo que estas sesiones dejaron dicho, y no hay que redescubrir

- **Una medición que se fía de un comentario mide el comentario.** Dos de los
  hallazgos de `S0` (QK-22, QK-23) no eran defectos: la capacidad existía y lo
  que estaba desfasado era la nota que decía que no. Desde `S2` cada caso del
  banco ejecuta contra una base real y comprueba su RESULTADO, no su SQL.
- **Compilar no basta, y no fallar tampoco.** Cuatro consultas pasaban
  emitiendo SQL que hacía otra cosa. Se cazaron leyendo lo que recibió el
  driver.
- **El banco corre sobre SQLite para ser barato como gate, y eso tiene precio.**
  Los tres límites de portabilidad de `S1` y el defecto de anchura de `S4` sólo
  aparecen con motores reales. El arnés del superapp es donde se ejercen los
  seis; todo símbolo nuevo pasa por ahí.
- **QK-24 se movió a A12**: `GroupBy` sin `Select()` deja `SELECT *`, y
  convertirlo en error rompe a quien depende de los motores permisivos. Avisa
  desde `S3`; su arreglo pertenece al major que QADR-0010 acumula.
- **La segunda mitad de `S4` —tipos nuevos: uuid nativo, enums con CHECK,
  arrays de PostgreSQL, rangos, inet, JSONB— NO se hizo.** No está en el gate
  del arco, y lo urgente era el defecto. Queda para A8, que ya lleva los tipos
  enterprise.
