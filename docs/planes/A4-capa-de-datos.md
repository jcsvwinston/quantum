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

**Hallazgos que descuenta.** Ninguno del registro: A4 no hereda filas. Su
cierre depende sólo de su gate.

**Decisión que necesita antes de empezar.** La **ruptura controlada**: A4
puede exigir un major (semántica de valores cero en `Update`, `pkg/model`
degradado a sustrato) y en lockstep eso arrastra a los tres pilares
(QADR-0002). Hay que saber si lo rompiente se agrupa en un único 2.0 al
cierre de A12 —con guía de migración generada— o si sale cuando toque. **Sin
esa decisión, S2 y S6 no pueden empezar**; el resto sí.

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

---

## S1 · quark — los huecos de consulta

**Precondición**: S0 hecha; el banco de 60 nombra las consultas que hoy
exigen `RawQuery`.

**Alcance**: `quark` (repo), API pública. `Raw[T]` y `Select[T]` a DTO,
`Exists`, `Pluck`, `FirstOrCreate`, preload con condiciones.

**Cuidado**: la superficie de API de quark está congelada por contract tests.
Añadir es seguro; cambiar una firma existente no lo es y cae en la decisión
de ruptura.

**Criterio de hecho**: las consultas del banco que S0 marcó como
«`RawQuery` por falta de API» pasan a tipadas, y el banco lo dice.

---

## S2 · quark — semántica de valores cero en `Update`

**Precondición**: la decisión de ruptura controlada, tomada y escrita.
**Sin ella esta sesión no empieza.**

**Alcance**: `quark`. Hoy la semántica es implícita; el objetivo es que sea
explícita y elegible por llamada.

**Cuidado**: es el candidato más claro a major de todo el arco. Si la
decisión fue «todo lo rompiente al 2.0 del cierre de A12», esta sesión
entrega la API nueva **junto a** la vieja, con la vieja marcada según la
política de deprecación (`docs/gobernanza/POLITICA_DEPRECACION.md`: recambio,
aviso `DEP-YYYY-NNN` y versión de retirada que aún no ha salido — lo vigila
`umbrella-deprecations`).

**Criterio de hecho**: un test por cada combinación de la tabla de semántica,
en los seis motores.

---

## S3 · quark — tipos por motor, con matriz publicada

**Precondición**: S0 hecha; la matriz medida existe.

**Alcance**: `quark`. decimal, uuid nativo, enums con CHECK, arrays de
PostgreSQL, rangos, inet, JSONB con operadores.

**Cuidado**: cada tipo nuevo toca los seis dialectos y las lanes de motor
real. Un tipo que sólo existe en un motor se declara así en la matriz; no se
emula en silencio.

**Criterio de hecho**: la matriz publicada en el sitio y una lane que la
comprueba contra motores reales — que la matriz sea generada, no escrita.

---

## S4 · quark — migraciones generadas desde el modelo

**Precondición**: S1 y S3 hechas (el generador necesita conocer los tipos).

**Alcance**: `quark`. Generar la migración desde el modelo, reversible, con
`down` generado.

**Cuidado**: NO es el arco de migraciones v2 —diff declarativo, `migrate
diff` con dry-run, plan hash— que es **A8**. Aquí sólo lo que `generate
module` necesita para escribir su primera migración.

**Criterio de hecho**: generar, aplicar y revertir sobre los seis motores en
CI, con el esquema volviendo byte a byte al de partida.

---

## S5 · nucleus — `generate module --data quark`

**Precondición**: S1 y S4 hechas y publicadas en un tag de quark que el
paraguas pueda pinar. **Ojo al borde**: nucleus no puede requerir una versión
de quark que no exista; si S1–S4 no han salido en release, esta sesión
espera o el tren corta antes.

**Alcance**: `nucleus`. `generate module --data quark` escribe modelo,
repositorio tipado, registro en `quarkdatasource`, migración y test.

**Cuidado**: el generador es el embudo de entrada, y su recorrido está
medido por el quickstart de suite (guards `quickstart-cost` y
`quickstart-embeds`, lane `quickstart-smoke`). Si el número de conceptos o de
comandos sube, esos guards lo dicen: es una regresión del arco A2, no un
efecto colateral aceptable.

**Criterio de hecho**: `nucleus new` + `generate module --data quark` arranca
y sirve un endpoint, en el smoke, sin pasos manuales.

---

## S6 · nucleus — `pkg/model` a sustrato

**Precondición**: la decisión de ruptura controlada, y S5 hecha.
**Sin la decisión no empieza.**

**Alcance**: `nucleus`. `pkg/model` deja de aparecer en la documentación de
usuario y pasa a ser sustrato interno del framework.

**Cuidado**: `pkg/model` está en el freeze de contratos
(`nucleus/scripts/ci/check_contract_freeze.sh`). Sacarlo de la documentación
no es sacarlo del contrato: lo segundo es la ruptura, y va donde la decisión
diga.

**Criterio de hecho**: el guard de cobertura de docs no encuentra `pkg/model`
en las páginas de usuario, y el freeze sigue en verde.

---

## S7 · el linter de tags común

**Precondición**: S0 hecha (las gramáticas y sus contradicciones, medidas).

**Alcance**: quark y nucleus. Un linter que lee las cuatro gramáticas de tags
sobre un mismo campo y falla cuando dicen cosas distintas.

**Cuidado**: es un **guard del gate**, así que necesita fixture y entrada en
`scripts/lib/guard-registry.sh`. Y como comprueba algo de los productos, no
se puede registrar hasta que el pin lo contenga: se escribe con su fixture,
entra en `GUARD_SCAN_EXCLUDE` con su porqué, y se registra en el commit del
set que mueve los gitlinks.

**Criterio de hecho**: la fixture muerde con la causa que declara, y
`guard-of-guards` pasa.

---

## S8 · el gate, y el set que publica el arco

**Precondición**: S1–S7 hechas.

**Qué hace**

1. Registra el guard del gate (S7) y el del banco de consultas.
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
Mientras esté vacío, el arco no ha empezado.

| Sesión | Estado | PR | Qué midió o cambió del plan |
|---|---|---|---|
| S0 | pendiente | — | — |
| S1 | pendiente | — | — |
| S2 | bloqueada por la decisión de ruptura | — | — |
| S3 | pendiente | — | — |
| S4 | pendiente | — | — |
| S5 | pendiente | — | — |
| S6 | bloqueada por la decisión de ruptura | — | — |
| S7 | pendiente | — | — |
| S8 | pendiente | — | — |
