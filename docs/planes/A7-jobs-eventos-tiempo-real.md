# A7 — Jobs, eventos y tiempo real

> Lee antes [`README.md`](README.md): el contrato de sesión, qué fichero manda
> para cada pregunta y qué no decide una sesión sola.

**Qué entrega.** Que una aplicación pueda confiarle trabajo en segundo plano
al framework sin operar un Redis, que tenga **un** bus de eventos en vez de
tres caminos, y que pueda empujar algo a un navegador abierto. Es el arco que
lleva lo que Rails (Solid Queue, Action Cable), Phoenix (Channels) y Django
(Channels) traen de serie.

**Gate del arco** — CUMPLIDO el 2026-09-19, registrado como guard
`umbrella-jobs-posture` con su fixture (el 51º):

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

**HECHA el 2026-09-18** (nucleus#550, CI verde). El banco pasa de **12 a 15 de
40** y la familia de cola de 4 a 7 presentes. **NU-80 cerrado.**

### Lo que S1 entregó, y las decisiones que conviene no reabrir

- **Dos almacenes con presupuesto SEPARADO**, no uno: un tipo mal escrito no
  puede desalojar los jobs que murieron de verdad, y `purge-archived` vacía
  **sólo** la dead letter —un job que espera a su consumidor no está muerto—.
  Los dos acotados (asynq acota el suyo en 10 000 y 90 días; éste muere con el
  proceso, así que guarda menos).
- **Dos acciones implementadas y cuatro rechazadas POR SU NOMBRE**, con la
  palabra `unsupported` en el texto: Orbit clasifica el error por subcadena, y
  sin esa palabra un nombre de cola equivocado le llega al operador como 500 en
  vez de 400. **La pausa se queda fuera a propósito**: con el canal lleno, o
  destruye trabajo aceptado o cuelga el cierre.
- **Cero símbolos nuevos en `pkg/tasks`**. El paquete del proveedor no está
  congelado y los campos del snapshot que esto necesita ya existían, así que no
  hay baseline que regenerar ni superficie que crecer (QADR-0010).
- **`TotalFailed` sigue contando lo mismo que antes** — es un campo publicado y
  alguien puede tener una alerta colgada de él—, y reencolar un job retenido no
  cuenta su fallo dos veces.
- **El contexto retenido conserva sus VALORES** (`WithoutCancel`), porque en
  este framework el tenant viaja ahí; el reencolado se ata al ciclo de vida del
  manager para que el job siga siendo parable.
- **Lo que S1 NO compra es durabilidad ante un reinicio.** Eso es `S2`. La doc
  pública lo dice donde antes afirmaba que el manager hacía dead-letter y
  métricas, que era verdad sólo de asynq.

### Lo que encontró la revisión adversarial, y no hay que redescubrir

Seis lentes sobre el diff y tres escépticos por hallazgo: **37 en bruto, 20
confirmados**, y **nueve defectos reales en el primer borrador**. Los tres que
más caro habrían salido:

1. **`putBack` recortaba por el extremo equivocado**: una sola pulsación de
   `retry-archived` con la cola llena destruía hasta 1 000 jobs retenidos
   **mientras el mensaje decía que seguían retenidos**. Reproducido con
   capacidad real por el verificador.
2. **Los dos almacenes se fundían al reencolar**: un job que sólo esperaba
   handler volvía clasificado como muerto, y el `purge-archived` siguiente lo
   borraba — justo la invariante que el cambio dice proteger.
3. **La sonda JOB-08 era flaky**: un token viejo en el canal cortocircuitaba la
   espera, así que habría dado por bueno un reencolado sin comprobar la segunda
   ejecución.

Y uno que **no era de este cambio**: `Run` hace `wg.Add` mientras `Close` hace
`wg.Wait`, que es una carrera de libro reproducible con `go Run(ctx)` +
`Close()`. Arreglada aquí, con test de regresión bajo `-race`.

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

**HECHA el 2026-09-18** (nucleus#553, más nucleus#552 con los dos P1 del outbox
que la medición destapó). El banco pasa de **15 a 19 de 40** y la familia de
cola de 7 a **11 de 13**.

### La decisión que el plan pedía, y su porqué

**El proveedor vive DENTRO del módulo raíz**, en `pkg/tasks/providers/sql`. El
criterio de ADR-030/031 para sacar algo a módulo hermano es el **peso** de lo
que arrastra —los SDK cloud eran 42 MB de un hola-mundo de 75—; éste habla
`database/sql` y no importa ningún driver, igual que `pkg/outbox`, así que no
añade nada a la build de nadie y no cuesta ni tag ni suelo en cada corte. La
excepción del suelo de 1.30.0 no aplica: no sale nada del raíz.

### Lo que garantiza, dicho en la doc pública

**At-least-once.** El worker reclama bajo lease y lo renueva mientras el
handler corre; si el proceso muere con el job, el lease vence y otro lo
recupera — y ese rescate está **acotado**, para que un job que tumba a su
proceso acabe retirado en vez de girar. Las colas son un **orden**, no pesos, y
una cola que nadie sirve no se toca. La curva de reintento viaja **con el job**.
**El cron no está soportado**: necesita que una sola réplica dispare, eso es
`S4`, y el arranque **rechaza** la combinación en vez de disparar cada entrada
en cada réplica.

### Lo que la revisión adversarial encontró, y no hay que redescubrir

Siete lentes y tres escépticos por hallazgo: **43 en bruto, 41 confirmados**, y
**el primer borrador era incorrecto de cuatro formas**, todas con test de
regresión ahora:

1. **No arrancaba.** La rama del proveedor dejaba el scheduler nil y `start()`
   lo desreferenciaba: cualquier aplicación que eligiera `jobs_provider: sql`
   moría en el arranque. **El banco no lo vio porque sus sondas conducen el
   paquete directamente y no pasan por el cableado** — la lección de método de
   esta sesión, y por eso `pkg/nucleus` tiene ahora el test de arranque.
2. **Un tipo sin handler quemaba los intentos**: el claim cobra uno por
   adelantado y `Release` no lo devolvía, así que un worker que sondea cada
   segundo agotaba un presupuesto de tres en tres segundos y el job moría **sin
   haberse ejecutado nunca**, en una réplica que no iba a ejecutarlo.
3. **Las escrituras de resultado no estaban valladas por el dueño del lease**:
   un rezagado podía cerrar un job que otro worker ya había tomado.
4. **El apagado ordenado ejecutaba el mismo job DOS VECES A LA VEZ**: `Close`
   cancelaba todo junto, el heartbeat moría mientras los handlers seguían, los
   leases vencían debajo y otra réplica reclamaba lo que aquí seguía corriendo.
   No es el duplicado que perdona at-least-once: nadie se había muerto.

Más el reaper corriendo en cada reclamo de cada worker, y el snapshot contando
los jobs terminados como tamaño de cola.

### Lo que S2 deja abierto, con destinatario

Tres hallazgos que son decisiones de diseño, no defectos del cambio, y que por
eso se registran en vez de parchearse con prisa: **NU-86** (sin retención: la
tabla crece sin límite y `Retention` se ignora), **NU-87** (el claim serializa
en la cabeza de la cola; `SKIP LOCKED` donde exista, midiendo antes) y **NU-88**
(ninguna escritura tolera `SQLITE_BUSY`, y depende de NU-77).

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

Se rellena al terminar cada una: el PR que la cierra y lo que se midió. El
estado se escribe **hecha** en minúsculas y entre asteriscos, que es lo que
`scripts/estado.sh` lee para derivar cuál es la próxima.

| Sesión | Estado | PR | Lo que midió |
|---|---|---|---|
| S0 | **hecha** 2026-09-18 | nucleus#549 · quantum#206 | 12 de 40 controles; cinco correcciones al plan y cinco hallazgos nuevos |
| S1 | **hecha** 2026-09-18 | nucleus#550 · quantum#207 | 15 de 40; NU-80 cerrado, y nueve defectos del primer borrador que cazó la revisión adversarial |
| S2 | **hecha** 2026-09-18 | nucleus#553 (+ nucleus#552) | 19 de 40; el proveedor durable, dos P1 del outbox y cuatro defectos del primer borrador — uno impedía arrancar |
| S3 | **hecha** 2026-09-19 | nucleus#554 | 21 de 40; NU-81, NU-82 y NU-83, más un defecto que el banco cazó por ORDEN: los instrumentos se quedaban atados al meter provider anterior |
| S4 | **hecha** 2026-09-19 | nucleus#555 | 22 de 40 y la familia de cola COMPLETA; cron con líder por lock de base de datos, y unicidad de job |
| S5 | **hecha** 2026-09-19 | nucleus#556 | 24 de 40; NU-78 y NU-79 — el bus dejó de hacerle daño a quien emite |
| S6 | **hecha** 2026-09-19 | nucleus#557 | 26 de 40; bus tipado junto al que hay, y el outbox como su transporte |
| S7 | **hecha** 2026-09-19 | nucleus#558 | 28 de 40 y la familia de eventos COMPLETA; NU-76 |
| S8 | **hecha** 2026-09-19 | nucleus#559 | 32 de 40 sin parciales; canales WS y SSE con el protocolo en el framework |
| S9 | **hecha** 2026-09-19 | nucleus#560 | 39 de 40; NU-77 cerrado por sus dos causas, /livez y /readyz separados, pprof protegido, relay entre réplicas |
| S10 | **hecha** 2026-09-19 | nucleus#561 | 40 de 40; `Server.Stream`, y `Quiet` para asertar silencio |
| S11 | **hecha** 2026-09-19 | nucleus#562 · quantum#(este) | el gate medido (10 000 jobs, worker muerto a mitad, cero pérdidas), el guard 51º con su fixture, y la retención |

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


---

## Cómo quedó el arco

**El banco: 40 de 40, todas las familias completas.** De 12 de 40 a 40 de 40 en
once sesiones, y el camino está en la tabla de arriba.

**El gate, medido y exigido por el CI:**

- el banco sin ningún control ausente sin razón escrita — no queda ninguno
  ausente;
- **10 000 jobs con el worker muerto a mitad y cero pérdidas**: medido con
  SIGKILL sobre un proceso hijo, asertando que la muerte ocurrió CON TRABAJO EN
  VUELO (matar un proceso ocioso también pasa, y mide nada), con el resultado
  10 000 hechos, 0 muertos, 0 perdidos, 0 duplicados;
- un canal con clientes concurrentes en el CI — los nueve tests de protocolo de
  `pkg/realtime` conducen sockets crudos contra el servidor;
- lo publicado y lo medido comprobados el uno contra el otro, por
  `scripts/check_jobs_posture.sh`, el guard 51º, con su fixture de tres
  roturas.

**Lo que sustituyó al showcase.** El gate escrito pedía «dashboard con datos
reales en el showcase» y el showcase salió del árbol el 2026-09-12. Lo
sustituyen las dos patas medibles de arriba, y la vista de colas del panel la
cierra OR-53 con el tren.

**Lo que queda abierto, y por qué no lo cierra una sesión:**

- ~~**OR-53**~~ — **cerrado en el tren**, y era más hondo que «falta una
  línea»: ver abajo.
- **NU-87** — el claim 1+N serializa en la cabeza de la cola. **Reasignado a
  A12** por escrito: es rendimiento, que es el arco de A12, y la cola cumple su
  contrato sin ello — el claim es correcto y portable a los cinco motores, sólo
  no escala.

**Lo que este arco enseñó sobre medir**, y conviene no volver a aprender:

1. **Una sonda que no recorre el camino del usuario certifica algo que no
   existe.** El banco daba por presentes los cuatro controles del proveedor SQL
   mientras `jobs_provider: sql` **panicaba en el arranque**, porque las sondas
   conducían el paquete y no el cableado.
2. **Un veredicto correcto por la razón equivocada no lo caza ningún test.**
   Cuatro sondas de `S0` medían menos de lo que su título decía; dos más se
   debilitaron al cambiar el código en `S1`.
3. **El orden de los tests es un instrumento.** El defecto de los instrumentos
   de métricas —que se quedaban atados al meter provider anterior— sólo se vio
   porque una sonda corría después de otra.
4. **Un `replace` silencioso miente.** El paso de CI que `S2` decía haber
   añadido no se añadió, y el PR lo afirmaba. Los guards existen para eso, y
   por eso `umbrella-jobs-posture` comprueba que la lane corra la prueba.


## Lo que encontró el TREN, que ninguna sesión encontró

El tren de este arco no fue mecánico. Redactar la doc pública que las sesiones
debían y las notas de la versión —ambas verificadas contra el código por
escépticos, no por lectura— destapó **nueve defectos**, dos de ellos paradas de
release, y **ninguno lo tenía el banco**. Están en el registro como NU-89…NU-95,
OR-54 y OR-55, con su informe.

**Los dos que habrían salido publicados:**

1. **Una aplicación que ya sirve su propio `/livez` o `/readyz` dejaba de
   arrancar** (NU-89). El framework sirvió sólo `/healthz` durante todo `v1.x`,
   así que quien quería las sondas de Kubernetes se las escribía; registrar las
   nuestras en `New` las pone en el mux antes que las suyas y `ServeMux` panica
   ante un patrón duplicado. Es **una ruptura en una minor**, que es justo lo
   único que QADR-0010 prohíbe hasta el major del cierre de A12. Se montan al
   arrancar el servidor y sólo para la ruta que la aplicación no reclamó.
2. **Todo stream SSE moría al minuto** (NU-90). `WriteTimeout` es un plazo de la
   conexión, no por escritura, y el keep-alive no salva: demuestra que el
   stream vive, y al plazo eso le da igual. La función estrella del arco, rota
   con la configuración de fábrica.

**La lección de método, que es la quinta de la lista de abajo y la más cara:**
*escribir la documentación ES una medición, y más severa que el banco.* El
banco conduce el código; la doc obliga a afirmar QUÉ HACE, y una afirmación se
puede contrastar. Las dos paradas de release salieron de redactar la página de
canales y la sección de notas, no de las cuarenta sondas.

**Y el corolario, en el propio banco de A6:** `OPS-14` («job queues listed and
acted on») medía que el endpoint devolviera 200 — leía una clave `queues` de
nivel superior que la respuesta nunca ha tenido, y la aplicación del banco ni
siquiera declaraba un job. Reportó `present` durante todo A6 sobre un panel
ciego (OR-55). Es AUD-05 otra vez: **un control cuyo título afirma más de lo
que su sonda comprueba**.

**Cuatro tests medían la máquina y no la cola** (NU-95), y los cuatro pusieron
el CI en rojo durante el tren: una ventana fija leída justo entre el claim y el
release —el ciclo funcionando, leído como job perdido—, 120 s fijos para drenar
10 000 jobs en un gate que no va de rendimiento, el gate corriendo además en la
lane de `-race` y en la de asynq, y tests que arrancaban un scheduler con
`Start()` —que no escucha al contexto— sin cerrarlo. La regla que queda:
**esperar al hecho, no al reloj**.
