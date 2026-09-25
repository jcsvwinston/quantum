# A10 — Testing y OpenAPI de primera clase

> Lee antes [`README.md`](README.md): el contrato de sesión, qué fichero manda
> para cada pregunta y qué no decide una sesión sola.

> **El troceado salió de la MEDICIÓN, no del enunciado.** El plan a 5/5
> describía este arco en cuatro líneas —`nucleustest.Client` con JSON,
> cookies, CSRF y sesión, factories, transacción por test y dobles que
> capturan; OpenAPI 3.1 derivado de recursos y structs con validación y
> cliente TypeScript; binding tipado, negociación, versionado y
> `problem+json`; inyección de dependencias ligera y hooks ordenables— y un
> gate: «el showcase publica su OpenAPI y un cliente TypeScript generado lo
> consume en un test end-to-end». `S0` midió las cuatro y las confirmó, con
> dos hallazgos que el enunciado no sabía y una corrección al gate: **el
> showcase ya no existe** (los ejemplos salieron del árbol el 2026-09-12), así
> que el gate se mide sobre el starter que genera `nucleus new`. Es la sexta
> vez que la medición corrige el plan.

**Qué entrega.** Que quien escribe una aplicación Nucleus pueda PROBARLA sin
inventar su propio arnés —un cliente que habla JSON y lleva sesión, datos de
prueba con una llamada, dobles que capturan el correo, los ficheros, los jobs
y el HTTP que la aplicación emite— y DESCRIBIR su API sin escribirla dos
veces: un documento OpenAPI que sale del router y de los structs, se exige a
cada petición, se congela como contrato y genera el cliente. Y que sus módulos
se encuentren tipados y arranquen en el orden que declaran. Es lo que Rails
(integration tests, factories), Encore (cliente generado), FastAPI (contrato
desde el código) y Spring (inyección) traen de serie.

**Precondición del arco**: Quantum 1.38.0 certificado (A9 cerrado); A5 cerrado
(1.32.0), porque el cliente de test con sesión monta sobre las cuentas y
sesiones que A5 dejó.

**Gate del arco** (reescrito por `S0`): el registro
`docs/auditoria/madurez-2026-09-03/registro.csv` sin hallazgos abiertos de
A10; el banco `nucleus/internal/apibench` publicando su cifra sin ningún
ausente sin razón escrita; **el starter que genera `nucleus new` publica su
documento OpenAPI y un cliente TypeScript generado desde él consume su API en
un test que corre en el CI de nucleus**; el kit de test cubre el starter (su
test generado usa el cliente, no `*http.Client`); y el documento entra en
`contracts/baseline`, de modo que un cambio rompiente del contrato pone un
check en rojo.

**Hallazgos que descuenta.** Los dos que hereda del plan —**NU-41** (P3,
`HTML` con dos semánticas, constructores que hacen panic) y **NU-44** (P3,
un `OnStart` fallido no apaga los módulos ya arrancados)—, los dos que quedaron
sin medidor al salir los ejemplos —**NU-74** (el quickstart afirma que su
código se copia y compila) y **NU-75** (la página del API mínima promete
«veinte símbolos»)— y los que abrió la medición de `S0`: **NU-96**, **NU-97**
y **NU-98**.

**La regla que lo condiciona.**
[QADR-0010](../adr/QADR-0010-rupturas-agrupadas-en-un-major.md): lo rompiente
se acumula en un único major al cierre de A12. Aquí muerde en dos sitios
conocidos: el **service locator** (`Context.Get(key)`) y la **forma del
envelope de error** (`{error: {code, message, details}}`) son superficie
publicada. La inyección tipada y `problem+json` se entregan **junto** a lo que
hay, y lo viejo se depreca con retirada EN ese major. Una sesión que no pueda
avanzar por adición para y lo dice.

## El banco

`nucleus/internal/apibench` — **46 controles, uno por sonda ejecutable**,
publicados en `nucleus/docs/api-bench.md`. Cada sonda arranca una aplicación
real con un módulo mínimo y llama a una ruta real, o —para un helper que el
autor llamaría y que aún no existe— pregunta al conjunto de métodos del kit y
al fuente del módulo por él bajo los nombres que usan los demás kits, y deja
escrito qué buscó. `TestAPIBench` asserta el veredicto REGISTRADO; cerrar un
hueco pone la suite en rojo pidiendo mover la cifra.
`NUCLEUS_API_BENCH_TABLE=1 go test ./internal/apibench/ -run TestAPIBenchTable`
genera el resumen por familias y el catálogo que la página pega.

**Línea de base medida el 2026-09-25 sobre nucleus v1.30.1:**

| familia | present | partial | absent | de |
|---|---|---|---|---|
| testkit | 4 | 3 | 8 | 15 |
| openapi | 2 | 2 | 6 | 10 |
| http | 2 | 2 | 8 | 12 |
| di | 4 | 1 | 4 | 9 |
| **TOTAL** | **12** | **8** | **26** | **46** |

## Lo que la medición encontró y el plan no sabía

1. **El kit arranca; no ayuda.** Cuatro de los presentes del testkit son el
   mismo hecho —una aplicación sube en proceso con su runtime, su base y su
   stream alcanzables— y todo lo que el autor hace después es a mano:
   codificar, pedir, decodificar, sin cookie, sin token CSRF, insertando cada
   fila, sin leer ningún correo. `nucleustest` es un lanzador, y la guía lo
   llama «experimental».
2. **El 404 propio del router es el texto plano de Go, en todas partes.** Bajo
   el prefijo de un módulo y fuera de cualquier módulo, una ruta desconocida
   responde `404 page not found` como `text/plain`, con `Accept:
   application/json`. El envelope de error cubre lo que devuelven los handlers
   y no lo que el router dice por su cuenta (`HT-10`, `HT-12`) → **NU-96**.
3. **El contrato que escribe el scaffold dice que la API es abierta**, y la
   aplicación generada no lo sirve. Los `internal/contracts` de `nucleus new`
   declaran rutas y esquemas y ningún esquema de seguridad mientras la
   aplicación exige bearer; `WithOpenAPIHandler` existe en `pkg/nucleus` y
   ninguna plantilla lo llama: el documento sólo sale con `nucleus openapi
   --out` (`OA-08`, `OA-10`) → **NU-97**, **NU-98**.
4. **Dos de las cuatro líneas del plan son una.** «Binding tipado de query,
   path y cabeceras» y «problem+json» son la misma sesión que el 404 JSON y el
   envelope (`HT-02`…`HT-12`): una forma para la entrada y una para los
   errores, o ninguna está hecha.
5. **El runtime de jobs no existe hasta que un módulo registra uno**
   (`Runtime().Tasks()` es nil en una aplicación por defecto, NF-13). No es un
   defecto; es un hecho que el diseño del doble de tasks tiene que saber.
6. **`Module.Requires` nombra bases de datos, no módulos**, y los módulos
   arrancan en orden alfabético (`sortedModuleSpecs`): la «inyección ligera»
   del plan empieza por que un módulo pueda decir de quién depende.

## El troceado

| Sesión | Qué entrega | Precondición | Criterio de hecho |
|---|---|---|---|
| `S0` | La medición: el banco, su página y los hallazgos | A9 cerrado | **HECHA** — nucleus#574: 12/46, tres hallazgos, gate reescrito sobre el starter |
| `S1` | El cliente del kit: peticiones JSON con cuerpo y destino, jarra de cookies, token CSRF, actuar como un usuario con sesión (`TK-02`…`TK-05`) | S0 | `TK-02`, `TK-03`, `TK-04`, `TK-05` a `present`; la guía de testing deja de decir «experimental» para el cliente |
| `S2` | Los datos del test: factories sobre los modelos registrados, transacción por test con rollback sobre la base de la aplicación (`TK-06`, `TK-07`) | S1 | `TK-06`, `TK-07` a `present`; probado en SQLite y en la lane de PostgreSQL |
| `S3` | Los dobles que capturan: correo (proveedor `memory` y su lectura desde el kit), almacenamiento, tasks encolados, HTTP saliente (`TK-08`…`TK-11`) | S1 | `TK-08`…`TK-11` a `present`; cada doble con su test de que captura lo que la aplicación emitió |
| `S4` | El kit cubre el starter y los módulos: el test generado por `nucleus new` usa el cliente; kit de conformidad de `ModuleSpec` (`TK-14`, `TK-15`); NU-74 y NU-75 medidos sobre los listados de la página | S1 | `TK-15` a `present`; el test del starter compila y pasa en la lane que genera el proyecto; NU-74/NU-75 hechos |
| `S5` | El documento sale del código: rutas desde el router, esquemas desde los structs, esquema de seguridad desde la auth, y la aplicación generada lo sirve (`OA-03`, `OA-04`, `OA-08`, `OA-10`; NU-97, NU-98) | S0 | `OA-03`, `OA-04`, `OA-08`, `OA-10` a `present`; `nucleus openapi` y `/openapi.json` dicen lo mismo |
| `S6` | El contrato se exige: validación de peticiones contra el documento, conformidad de respuestas desde el kit, el documento en `contracts/baseline` con su guard (`OA-05`, `OA-06`, `OA-09`) | S5 | `OA-05`, `OA-06`, `OA-09` a `present`; un cambio rompiente del documento pone rojo el check de contratos |
| `S7` | El cliente: generador TypeScript desde el documento y el test end-to-end del starter que lo consume en CI (`OA-07`) — el gate | S6, S4 | `OA-07` a `present`; la lane del starter ejecuta el test con el cliente generado |
| `S8` | Una forma para la entrada y una para los errores: binding tipado de query, path y cabeceras; `problem+json` junto al envelope; el 404 del router en el envelope; `RawHTML`; negociación por `Accept`; versionado declarativo; timeout por ruta (`HT-02`…`HT-12`; NU-41 en parte, NU-96) | S0 | familia `http` completa; NU-96 hecho |
| `S9` | El cableado: un módulo provee y otro consume tipado, valores de petición tipados, orden de arranque declarado, apagado de lo arrancado cuando un `OnStart` falla, guía de estilo de constructores (`DI-02`…`DI-05`, `DI-07`; NU-41, NU-44) — la inyección ligera JUNTO al locator (QADR-0010) | S0 | familia `di` completa; NU-41 y NU-44 hechos |
| `S10` | Gate, guard y set: `umbrella-api-posture` con fixture, la lane del starter con el cliente generado en CI, set certificado | todas | guard registrado con fixture; set certificado; A10 cerrado |

**El orden no es negociable en tres sitios**: `S1` va antes que `S2`–`S4`
porque factories, dobles y el test del starter se escriben CON el cliente, no
con `*http.Client`; `S5` va antes que `S6` y `S7` porque no se valida ni se
genera un cliente de un documento escrito a mano que dice que la API es
abierta; y `S7` va después de `S4` porque el test end-to-end del starter es el
test del starter. `S1`–`S4`, `S5`–`S7`, `S8` y `S9` son cuatro hilos que
tocan paquetes distintos (`pkg/nucleustest`, `pkg/openapi` + `internal/cli`,
`pkg/router` + `pkg/nucleus/context.go`, `pkg/nucleus/nucleus.go`) y pueden
ir en paralelo.

**La trampa de este arco, dicha por adelantado.** Casi todo lo que el arco
añade es API pública de `pkg/nucleustest`, `pkg/nucleus` y `pkg/router`, y
nucleus congela sus símbolos exportados en `contracts/baseline`: cada sesión
pasa por el baseline (añadir es libre; cambiar una firma existente no) y por
el gate estricto de la allowlist de símbolos no ejercitados. Y el kit vive en
el módulo raíz: cada dependencia que traiga (un generador TS, un validador
OpenAPI) es una dependencia de todo consumidor — lo que no sea Go puro se
decide ANTES de escribirse, como en A7.

## Registro de sesiones

Se rellena al terminar cada una: el PR que la cierra y lo que se midió.

| Sesión | Estado | PR | Qué midió o cambió del plan |
|---|---|---|---|
| S0 | **hecha** 2026-09-25 | nucleus#574 | 12/46 (testkit 4/3/8, openapi 2/2/6, http 2/2/8, di 4/1/4). El kit arranca y no ayuda; el 404 del router es texto plano (NU-96); el contrato del scaffold dice «abierta» y la app no lo sirve (NU-97, NU-98); el gate pasa del showcase al starter; binding y errores son una sola sesión; `Requires` nombra bases, no módulos |
| S1 | pendiente | — | |
| S2 | pendiente | — | |
| S3 | pendiente | — | |
| S4 | pendiente | — | |
| S5 | pendiente | — | |
| S6 | pendiente | — | |
| S7 | pendiente | — | |
| S8 | pendiente | — | |
| S9 | pendiente | — | |
| S10 | pendiente | — | |
