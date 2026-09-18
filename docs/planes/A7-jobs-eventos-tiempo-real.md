# A7 — Jobs, eventos y tiempo real

> Lee antes [`README.md`](README.md): el contrato de sesión, qué fichero manda
> para cada pregunta y qué no decide una sesión sola.

**Qué entrega.** Que una aplicación pueda confiarle trabajo en segundo plano
al framework sin operar un Redis, que tenga **un** bus de eventos en vez de
tres caminos, y que pueda empujar algo a un navegador abierto. Es el arco que
lleva lo que Rails (Solid Queue, Action Cable), Phoenix (Channels) y Django
(Channels) traen de serie.

**Gate del arco** — PROPUESTO por `S0`, pendiente de cerrarse con su guard:

- el banco de jobs —`nucleus/internal/jobsbench`— sin ningún control ausente
  **sin razón escrita**;
- durabilidad medida: 10 000 jobs con el proceso caído a mitad y **cero
  pérdidas**, en los motores que la matriz de CI de nucleus ya arranca;
- un canal con clientes concurrentes en el CI;
- lo publicado y lo medido, comprobados el uno contra el otro
  (`nucleus/docs/jobs-bench.md` contra lo que cuentan los casos).

> **El gate escrito en el plan 5/5 pedía además «dashboard con datos reales en
> el showcase», y eso ya no se puede cumplir tal cual**: los ejemplos salieron
> del árbol el 2026-09-12 (decisión de producto: sin ejemplos hasta 5/5), y con
> ellos el showcase. Lo sustituye la tercera línea de arriba. El dashboard, por
> su parte, **ya existe**: lo entregó A6. Lo que le falta no es panel, es que
> el proveedor por defecto le dé números — ver `S3`.

**Hallazgos que descuenta.** Los dos que hereda de A6 —**NU-76** (P3, el
outbox no sabe contar un topic) y **NU-77** (P2, una aplicación con outbox
sobre SQLite puede fallar el arranque)— y los cinco que abrió la medición de
`S0`: **NU-78**, **NU-79**, **NU-80**, **NU-81** y **NU-82**.

**La regla que lo condiciona.**
[QADR-0010](../adr/QADR-0010-rupturas-agrupadas-en-un-major.md): lo rompiente
se acumula en un único major al cierre de A12. Aquí muerde en tres sitios
conocidos: **`signals.Event`, `signals.Handler` y `tasks.EnqueuePolicy` son
superficie publicada**. Un bus tipado no puede cambiar `Payload any`; se
entrega **junto** al que hay, como API nueva, y el viejo se depreca con
retirada EN ese major. Una sesión que no pueda avanzar por adición **para y lo
dice**.

**La trampa de este arco, dicha por adelantado.** Media capacidad de jobs vive
**fuera** del módulo raíz: el proveedor asynq está en `pkg/tasks/providers/`
pero los instrumentos, los exportadores y los drivers son módulos hermanos con
tag propio. Un proveedor SQL nuevo tiene que decidir dónde vive ANTES de
escribirse — dentro del raíz cuesta dependencias a todo consumidor, fuera
cuesta un tag y un suelo en cada corte (ADR-030/031 de nucleus). Y la
excepción del suelo de 1.30.0 aplica: un paquete que SALE del raíz no puede
llevarlo por detrás.

---

## S0 · Medir antes de trocear

**Precondición**

```bash
bash scripts/check_audit_backlog.sh | tail -1   # ha de decir: arcos cerrados: A1 A2 A3 A4 A5 A6
```

**Qué produce.** El numerador del gate: un banco de controles de jobs, eventos
y tiempo real ejecutable, con el veredicto de cada uno medido, no leído.

**Criterio de hecho**

```bash
cd nucleus && go test ./internal/jobsbench/ -run TestJobsBench -v
```

**HECHA el 2026-09-18** (nucleus#549, quantum#206). Lo que midió y lo que
cambió del plan, abajo.

### Lo que S0 midió

**12 de 40 controles presentes, 4 parciales, 24 ausentes.** El banco vive en
`nucleus/internal/jobsbench/` y su página es
[`nucleus/docs/jobs-bench.md`](../../nucleus/docs/jobs-bench.md). Cada sonda
arranca una aplicación, conduce el API público de `pkg/tasks`, `pkg/signals` o
`pkg/outbox`, o le pide una clave a la capa de configuración y lee la negativa.

| familia | presentes | parciales | ausentes | de |
|---|---|---|---|---|
| queue | 4 | 2 | 7 | 13 |
| events | 6 | 0 | 6 | 12 |
| realtime | 1 | 2 | 5 | 8 |
| ops | 1 | 0 | 6 | 7 |
| **total** | **12** | **4** | **24** | **40** |

### Lo que cambió del plan

Cinco cosas, y ninguna se sabía leyendo el plan escrito:

1. **La cola no sólo es volátil: PIERDE trabajo con el proceso vivo.** Un job
   cuyo tipo ningún worker maneja se cuenta como fallido y **se descarta**
   (JOB-10), y un job que agota sus reintentos tampoco queda en ninguna parte
   (JOB-07). El plan hablaba de durabilidad frente al reinicio; esto es
   pérdida con el proceso en pie, y es **previo** a cualquier proveedor nuevo:
   un productor desplegado antes que su consumidor pierde todo lo que encoló
   entre medias. → `S1`.
2. **El panel que A6 acaba de publicar enseña ceros.** El `Inspector` del
   proveedor por defecto devuelve `TotalPending=0` y `TotalActive=0` con tres
   jobs en vuelo (JOB-09), y Orbit consume exactamente ese `Inspector`. No hay
   que escribir un dashboard de jobs: hay que darle datos al que ya existe.
   → `S3`.
3. **El bus ya tiene `recover` y límite, y los dos están en el sitio
   equivocado.** Un handler que entra en pánico en el camino **síncrono** se
   lleva por delante lo que emitió —el `recover` sólo cubre `EmitAsync`
   (EVT-03)—, y el límite de concurrencia se toma **en la goroutine del
   emisor**, así que con 64 handlers en vuelo `EmitAsync` **bloquea a quien
   emite** (EVT-12): una emisión asíncrona hereda la latencia de su suscriptor
   más lento, dentro del request que la disparó. El plan pedía «handlers con
   recover y límite» como si no existieran; existen y son defectos. → `S5`.
4. **Cero métricas.** Medido con un meter provider real y un lector manual
   mientras un job corría: **ninguna serie** (OPS-05). Los siete instrumentos
   `jobs.*` están dentro del proveedor asynq, de modo que quien no opera un
   Redis no tiene nada sobre lo que alertar — y el outbox no instrumenta nada
   en ningún caso. → `S3`.
5. **NU-77 es dos hechos deterministas, no un flake.** El `PRAGMA
   busy_timeout` de la conexión que el framework entrega es **0** (OPS-06), y
   medido desde dentro del `OnStart` del primer módulo, **la tabla del outbox
   ya existe** (OPS-07): el dispatcher llegó a la base de datos antes de que
   ningún módulo pudiera migrar. Las dos assertions se cumplen en macOS, donde
   la carrera no reproduce. → `S9`.

Y una corrección al gate: el tercio del showcase no se puede medir porque el
showcase no existe (ver arriba).

---

## S1 · La cola deja de perder trabajo

**Precondición**

```bash
cd nucleus && go test ./internal/jobsbench/ -run TestJobsBench   # el banco existe y pasa
```

**Qué produce.** Que ningún job desaparezca en silencio con el proceso vivo: un
tipo sin handler se retiene en vez de descartarse, un job que agota reintentos
queda donde se le pueda ver, y `OperateQueue` deja de ser un error en el
proveedor por defecto. Cierra **NU-80** y los controles JOB-07, JOB-08 y
JOB-10.

**Criterio de hecho**

```bash
cd nucleus && go test ./internal/jobsbench/ -run 'TestJobsBench/JOB-(07|08|10)' -v
```

## S2 · `providers/sql`: la cola durable sobre la base que ya hay

**Precondición**: `S1` fusionada.

**Qué produce.** El proveedor que el arco promete: cola durable sobre la base
de datos de la aplicación, con reclamación por lease (`SELECT … FOR UPDATE SKIP
LOCKED` donde el motor lo tiene y el equivalente donde no), colas con nombre y
prioridades, y reintentos con la curva que la aplicación elija. Cierra JOB-02,
JOB-03, JOB-04 y JOB-06.

Antes de escribir una línea, la sesión decide **dónde vive el módulo** (ver la
trampa del arco) y lo escribe.

**Criterio de hecho**

```bash
cd nucleus && go test ./internal/jobsbench/ -run 'TestJobsBench/JOB-0[2346]' -v
```

## S3 · Lo que la cola hace, visible

**Precondición**: `S2` fusionada.

**Qué produce.** Un `Inspector` que cuenta de verdad —pendientes, activos,
reintentos, muertos, por cola— en el proveedor por defecto y en el SQL, y los
instrumentos `jobs.*` fuera de asynq, más los del outbox. Cierra **NU-81** y
**NU-82**, los controles JOB-09 y OPS-05, y es lo que hace que la vista de
colas de Orbit deje de enseñar ceros.

**Criterio de hecho**

```bash
cd nucleus && go test ./internal/jobsbench/ -run 'TestJobsBench/(JOB-09|OPS-05)' -v
cd orbit && go test ./internal/adminbench/ -run 'TestAdminBench/OPS' -v
```

## S4 · Cron sin Redis, y una sola réplica disparando

**Precondición**: `S2` fusionada.

**Qué produce.** El planificador con elección de líder por lock de **base de
datos**, de modo que el cron deje de necesitar el lock de Redis que hoy lo
elige, y la unicidad de job encolado (JOB-13), que es la otra cara del mismo
problema.

**Criterio de hecho**

```bash
cd nucleus && go test ./internal/jobsbench/ -run 'TestJobsBench/JOB-13' -v
```

## S5 · El bus: un pánico no se lleva al emisor, y emitir no bloquea

**Precondición**: el banco pasa.

**Qué produce.** `recover` en el camino síncrono y la toma del slot de
concurrencia **dentro** de la goroutine, con la política de qué pasa cuando el
límite está lleno escrita (esperar, descartar con log, o crecer) en vez de
heredada. Cierra **NU-78**, **NU-79** y los controles EVT-03 y EVT-12.

**Criterio de hecho**

```bash
cd nucleus && go test ./internal/jobsbench/ -run 'TestJobsBench/EVT-(03|12)' -v
```

## S6 · Un bus, tipado, con el outbox como transporte

**Precondición**: `S5` fusionada.

**Qué produce.** Un API de eventos tipada (genéricos) **junto** a la que hay
—`signals.Event` está publicada y QADR-0010 manda—, con el outbox como
transporte transaccional del mismo bus: emitir dentro de una transacción y
recibirlo como handler, sin elegir transporte. Cierra EVT-02 y EVT-07.

**Criterio de hecho**

```bash
cd nucleus && go test ./internal/jobsbench/ -run 'TestJobsBench/EVT-0[27]' -v
```

## S7 · El outbox sabe de un topic

**Precondición**: ninguna más allá del banco.

**Qué produce.** Recuento por topic y último error de entrega en el snapshot,
que es lo que NU-76 pidió desde `S9` de A6 y lo que la vista de correo del
panel declaró no poder decir. Cierra **NU-76** y los controles EVT-10 y EVT-11.

**Criterio de hecho**

```bash
cd nucleus && go test ./internal/jobsbench/ -run 'TestJobsBench/EVT-1[01]' -v
```

## S8 · Canales: WS y SSE de primera clase

**Precondición**: `S6` fusionada (un canal publica sobre el bus).

**Qué produce.** El upgrade, el framing y el ping/pong dejan de ser cosa de la
aplicación; un canal con topics, autenticación del join por sesión o API key, y
un helper de SSE. Cierra RT-01, RT-02, RT-04 y RT-05.

**Criterio de hecho**

```bash
cd nucleus && go test ./internal/jobsbench/ -run 'TestJobsBench/RT-0[1245]' -v
```

## S9 · Presencia, relay y lo que ve el orquestador

**Precondición**: `S8` fusionada.

**Qué produce.** Presencia y relay de canal entre réplicas (RT-06, RT-07), y lo
que un orquestador necesita: `/livez` y `/readyz` separados (OPS-01, OPS-02) y
un profiler que exista y no sea público (OPS-04). Y **NU-77**, que es de esta
familia: el `busy_timeout` en el DSN que el framework construye y el arranque
del dispatcher después de los módulos (OPS-06, OPS-07).

**Criterio de hecho**

```bash
cd nucleus && go test ./internal/jobsbench/ -run 'TestJobsBench/(RT-0[67]|OPS-0[12467])' -v
```

## S10 · Que se pueda testear

**Precondición**: `S8` fusionada.

**Qué produce.** Lo que `nucleustest` no ofrece: correr los jobs en línea o
capturar los encolados, y abrir un stream, leer sus eventos y cerrarlo.
Cierra RT-08.

**Criterio de hecho**

```bash
cd nucleus && go test ./internal/jobsbench/ -run 'TestJobsBench/RT-08' -v
```

## S11 · Gate, guard y set

**Precondición**: las anteriores fusionadas.

**Qué produce.** La prueba de durabilidad del gate (10 000 jobs, proceso caído
a mitad, cero pérdidas) en la matriz de CI, el guard `umbrella-jobs-posture`
con su fixture —la cifra publicada es la que la tabla cuenta, ningún ausente
sin razón, la prueba de durabilidad EXIGIDA por el CI— y el set que lo publica.

**Criterio de hecho**

```bash
bash scripts/check_jobs_posture.sh
bash scripts/check_audit_backlog.sh | tail -1   # ha de decir: … A6 A7
```

---

## Registro de sesiones

| Sesión | Estado | PR | Lo que midió |
|---|---|---|---|
| S0 | HECHA 2026-09-18 | nucleus#549 · quantum#206 | 12 de 40 controles; cinco correcciones al plan y cinco hallazgos nuevos |

### Lo que S0 dejó dicho, y no hay que redescubrir

- **El banco se asserta contra el veredicto REGISTRADO, no contra el éxito.**
  Cerrar un hueco pone la suite roja pidiendo que se actualice el veredicto en
  el mismo cambio. Es lo que impide que la cifra publicada se separe de la
  verdad.
- **Cuatro sondas se reescribieron antes de publicar nada**, porque su primera
  versión medía menos de lo que su título afirmaba: preguntar `/metrics` a una
  aplicación arrancada mide que el exportador es un módulo opcional, no si los
  jobs están instrumentados; observar un mensaje `pending` no mide un reintento;
  construir un relay con configuración vacía y leer su error no es entrega; y
  comprobar que el runtime expone un outbox no mide ningún orden de arranque.
  Está escrito en `nucleus/docs/jobs-bench.md` — es la lección AUD-05 del banco
  de admin, repetida en cuatro formas nuevas.
- **`signals.RedisRelay.ForwardToBus` BLOQUEA**: es el bucle de recepción, no
  una suscripción que devuelve. Una sonda que lo llamó en línea colgó la suite
  cuatro minutos hasta el timeout del test.
