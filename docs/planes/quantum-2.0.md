# Quantum 2.0 — lo que tiene que cumplir

> Fijado por Carlos el 2026-10-06. Es el **contrato del major**: lo que entra,
> lo que tiene que estar hecho antes de empezarlo y lo que lo da por terminado.
> `M0` (plan de A12) lo convierte en filas con aviso; `M1` lo ejecuta; `R2` lo
> confirma. Lo que no esté aquí no entra en el 2.0: se publica en 1.x si es
> aditivo, o espera a un 3.0 si rompe.

## 1. Cuándo

- **No antes del 2027-01-04.** Cada cambio que rompe lleva un aviso `DEP` con
  al menos 90 días naturales de ventana
  ([`POLITICA_DEPRECACION.md`](../gobernanza/POLITICA_DEPRECACION.md)), y
  varios vencen ese día. Los avisos que publique `M0` vencen 90 días después
  del set que los lleve (si es el del 2026-10-19, hacia el 2027-01-17; si
  es el del 10-26, el 2027-01-24). **La fecha del 2.0 la fija la última
  ventana que `M0` abra**, y `M0-E` la escribe aquí cuando no quede
  ninguna fila `por escribir` en el §3.0. Medido al cierre de 1.42.0
  (2026-10-18): las veintitrés filas `publicado` abren el 2027-01-17 como
  muy tarde; las siete de quark (`en main`) abrirán 90 días después del
  set que lleve la primera release de quark posterior a v1.17.0.
- **Medido el 2026-11-03 (`M0-R`)**: no queda ninguna fila `por escribir`.
  Las once que siguen `en main` (las siete de quark y las cuatro de
  `M0-R`) llevan `no earlier than 2027-02-07`, que es la ventana de un set
  del 2026-11-09: **si ese set las publica, el 2.0 no puede salir antes
  del 2027-02-07**, y cada semana que se retrase las mueve una semana.
  Lo que `M1` exige además antes de empezar (§2, §3.5, D9…D11) puede
  retrasarlo más; esa fecha es un suelo, no una estimación.
- **Medido el 2026-11-07 (Quantum 1.43.0, el set del 9 adelantado dos
  días)**: las once filas que seguían `en main` están `publicado` (quark
  v1.18.0 y orbit v1.21.1 las llevan al pin), ninguna queda `en main`, `por
  escribir` ni `decisión`: **34 de 34 `publicado`, y el 2.0 no antes del
  2027-02-07.**
- **Medido el 2026-11-16 (Quantum 1.45.0, fuera de cadencia)**: `D9-N` y
  `D10-O` publicadas; del §2 quedan las diez «sesiones cortas» del punto 2
  (D15: en sets 1.x antes de `M1`), y delante de `M1` va además la sesión
  de medición `M1-S0` del plan de A12 (D16). Las doce decisiones de ese
  día (D14…D25) están en el §3.3; la secuencia hasta el 2.0, en la sección
  «La ventana hasta el 2.0» del plan de A12.
- **Medido el 2026-11-16 (`M1-S0`)**: el major está troceado en 23 sesiones
  más el tren, con un tramo 1.x de 18 sesiones como precondición (plan de A12,
  sección «`M1-S0` — el major, medido y troceado»). Lo que mueve este
  documento: el §3.5 se corrige abajo (41 `go.mod`, 2 156 líneas de import,
  `cmd/nucleus` a `…/nucleus/cmd/nucleus/v2`, 122 ficheros rastreados de
  quark, 48 scripts y páginas del paraguas; el workspace compila contra `/v2`
  sin `replace`); el primer commit del major de cada repo es la ruta `/v2` en
  el orden quark → nucleus → orbit, con pseudo-versiones entre repos; y dos
  decisiones del propietario van antes de ese commit (D26, el número 2.0.0 en
  los 24 módulos v0.x; D27, cómo aterriza el major en `main`), con once más en
  el bloque `M1-S0` del §3.3 (D28…D38: el lint del `!` de ADR-032, las tres
  correcciones que amplían avisos publicados, `App.AutoMigrate`, DEP-2026-014,
  la arista raíz → `quarkdatasource`, el último tag v1, dónde se publica la
  guía, los suelos de los drivers del CLI, `nucleus add`, el rediseño y la
  ventana), cada una delante de la sesión que la cita; la regla D2 de
  `POLITICA_DEPRECACION.md` §4 se aplica tal como está aprobada (no es
  decisión). La fecha sigue siendo un suelo: no antes del 2027-02-07; desde el
  primer merge de un `!` en `main` no sale ningún set 1.x.
- **Decididas el 2026-11-16 (D26…D38)**: las trece, una a una, la misma
  tarde (§3.3, bloque `M1-S0`; ocho contra la recomendación). Sólo una mueve
  fechas: D30 (`App.AutoMigrate` migra a quark en el 2.0) abre un aviso
  nuevo de nucleus, DEP-2026-027, `por escribir` (fila 35 del §3.0; lo
  escribe `V-N-AM` antes del set del 2026-11-23). Si ese set lo publica, su
  ventana abre el 2027-02-21 y **el suelo del 2.0 pasa al 2027-02-21**; si
  se retrasa un set, una semana más. El resto (Release-As en el `!`, rama
  `major/2.0`, el lint, las correcciones que comparten ventana, el lag
  declarado de los CLIs, el rediseño con la marca reabierta y la ventana
  recortada hacia A13) no mueve ninguna fecha.
- **El orden lo decidió Carlos: primero se termina lo pendiente**, después el
  2.0. Nada de este documento se empieza antes de que se cumpla el §2.

## 2. Lo que tiene que estar hecho ANTES de empezar el 2.0

1. **A11 cerrado**: set 1.41.0 (cadencia del 2026-10-12) con `S-fin` (b).
2. **Lo pendiente de A12 cerrado**: el arreglo de seguridad del panel anotado
   en la memoria de la sesión del 2026-10-06; los hallazgos abiertos que no
   son del 2.0 (los «sesiones cortas» del registro: NU-127, NU-129, NU-131,
   OR-70, OR-71, OR-74, OR-75, OR-76, NU-108, QK-54, QK-68, QK-69); N1
   publicado (NU-106). **Estado el 2026-11-16**: el arreglo del panel
   (OR-67) y N1 (NU-106, en 1.41.0) hechos; de las doce sesiones cortas,
   NU-127 y OR-70 hechas y las diez restantes se cierran en sets 1.x antes
   de `M1` (D15; el plan de A12 las nombra ya en la precondición de `M1`).
3. **`M0` hecho**: la lista del §3 cerrada, **un aviso `DEP` publicado por
   cada cambio** con su ventana corriendo, y el guard de deprecaciones viendo
   también los cambios de comportamiento (QM-20).
4. **Orbit migrado en una minor 1.x** (`M0-O`): medido el 2026-10-16, lo
   que el major rompe son 2 llamadas a `NewWrapResponseWriter`
   (`internal/admin/audit.go`, `live.go`) si D4 lo retira, la lectura de
   errores sólo del sobre (`ui/src/services/api.ts`) si D3 voltea el
   default, el `LIKE` plano con escape propio de `quarkdatasource/store.go`
   (la forma portable `WhereLike`/`WhereContains` existe desde A8) y lo que
   llame a la puerta sin tipo de `signals` (D6 la retira). `authz.New` no
   rompe (D4). **Y lo que D5/D5b añaden**: el adaptador `datasource/nucleus`
   se deprecia en 1.x (`DEP-2026-002` de orbit, fila 30) y se retira en el
   2.0, así que el panel sobre `pkg/model` deja de existir con el major y
   la guía de migración lo dice. El 2.0 no puede romper el panel sobre
   quark. **HECHO el 2026-10-18** (orbit#568 y orbit#570, en Quantum
   1.42.0): los dos avisos, la salida `AllowSharedAgentCertificate`, las
   marcas y el aviso al montar, el `LIKE` escapado, `api.ts` leyendo
   problem+json y `router.Wrap` en las dos llamadas con el require de
   nucleus v1.33.0; medido al hacerlo, orbit no llama a la puerta sin tipo
   de `signals` (guarda el bus sólo para `model.NewCRUD`, que se va con el
   adaptador). `grep` de los símbolos del §3.1 sobre orbit = 0.
5. **`R1` hecha**: la re-auditoría completa sobre el último set 1.x. Lo
   rompiente que encuentre entra en el §3 (con su aviso); lo demás, en sets
   semanales.
6. **La DX al 5** (§2.1), en 1.x: es aditiva, así que no espera al major —
   y **es prerrequisito de DEP-2026-024** (medido por `M0-E` el 2026-10-18):
   `nucleus generate model` y `generate resource` escriben
   `import "github.com/jcsvwinston/nucleus/pkg/model"` y `model.BaseModel`
   en el código del usuario, `nucleustest.Make` escribe por el CRUD de
   `pkg/model`, y el sitio enseña `pkg/model` en el quickstart y en
   `models-and-database.md`; sin ella, `M1` no puede retirar `pkg/model`
   (en el ensayo quedan rojos los seis tests de `internal/cli` que
   construyen lo que los generadores escriben). Alcanza también al
   paraguas: el starter de la suite y el showcase montan `orbit.Module`
   sin `DataSource`, que en el 2.0 rehúsa arrancar.

### 2.1 La DX al 5 (decisión de Carlos, 2026-10-06)

El §4 exige que `R2` dé 5 en todas las dimensiones salvo comunidad, así que el
2.0 ya obliga a cerrar la DX; aquí queda explícito qué falta. Cada punto sale
del listón de [`criterios-5.csv`](../auditoria/criterios-5.csv) y lo mide `R1`.

**Quark — docs/DX (2 el 2026-09-03)**
- Una guía por caso de uso.
- Un playground de consultas en el sitio.
- Mensajes de error con receta (qué pasó y qué hacer) en el 100 % de los
  `Err*`, contado por un guard y no a juicio.
- Cero deriva entre documentación y código (los guards de doc ya existen).

**Quark — API de consultas (58 de 60 tipadas al pin de 1.39.0)**
- Las 60 consultas del banco expresadas tipadas, sin `RawQuery`.

**Nucleus — CLI y generadores (3)**
- Generadores que montan, prueban y documentan lo que generan, y cuyo test
  prueba la composición real de la aplicación (NU-127).
- `nucleus dev` con recarga.
- Completions de la CLI.
- `routes` y `migrate` que ven lo que monta el binario real.

**Nucleus — Docs/DX (3)**
- Como mucho cinco conceptos hasta el primer endpoint, medido sobre el
  quickstart.
- Tutoriales por caso de uso ejecutados en CI y referencia generada (hechos
  en A11: W2, W3, W4); que sigan sin deriva.

**Nucleus — Datos (3)**
- Quark como capa de datos por defecto (starter y generadores).
- Migraciones autogeneradas desde modelos con lock y detección de deriva.
- `pkg/model` fuera del camino: generadores, starter y `nucleustest` sobre
  quark en 1.x, porque en el 2.0 se retira como capa pública (D5, fila 26).

**Medido el 2026-11-08** (sesión `DX-0`; el detalle, la tabla punto a punto
y el troceado están en la sección «La DX al 5 — medida y troceada» del
[plan de A12](A12-rendimiento-reauditoria-cierre.md)). De los trece puntos
de arriba, cuatro están hechos y medidos en `R1` (`nucleus dev`,
completions, `routes`/`migrate` sobre el binario, tutoriales y referencia
en CI); uno es del 2.0 y no de 1.x (las 60 consultas tipadas: 58 de 60, y
las dos que quedan voltean con DEP-2026-008); y lo que de verdad
desbloquea `M1` es el **bloque A**: los generadores y `nucleustest.Make`
sobre quark (`DX-N1`, NU-137), el sitio de nucleus enseñando quark
(`DX-N2`, nueve páginas) y el panel montado con `DataSource` desde
`nucleus new --with orbit` (`DX-S1`, NU-159). El resto —receta en los
`Err*` y la deriva de quark (`DX-Q1`), migraciones desde modelos y
generadores tipados (`DX-N3`), guías por caso de uso (`DX-Q3`) y el
playground (`DX-Q4`)— sube la nota de `R2` sin bloquear nada. Dos
decisiones que el §2.1 no preveía:

<!-- INICIO BLOQUE DE DECISIÓN DX -->

| id | Qué decide | Propuesto | Decisión de Carlos |
|---|---|---|---|
| **D12** | `nucleustest.Make` «sobre quark» cuando nucleus no depende de quark (`go.mod` raíz sin él, a propósito desde el arco D3) | **Doble gramática sin dependencia nueva**: un struct que embebe `model.BaseModel` sigue su camino de hoy; cualquier otro struct lo lee el propio kit por sus etiquetas con la gramática de quark (`db:"columna"`, `pk:"true"`, `TableName()`) y lo escribe por el CRUD interno del framework. Es lo que la rama `dry-run/2.0` ya hace (`internal/model.ExtractMeta` sin registro) más la gramática de quark. La alternativa —un módulo hermano `nucleus/quarktest` que requiera quark— es un 16.º módulo en el tren y otro `go get` para el lector. `DX-N1` hace lo propuesto | **Opción 2, módulo aparte** (2026-11-08). Al releer nucleus#644 la doble gramática persistía por el CRUD de `pkg/model` —la capa que `M1` retira— y duplicaba la gramática de quark en nucleus, donde deriva en silencio; el módulo que escribe por `quark.For[T]` rompe en compilación si quark cambia. `DX-N1b` lo hace ANTES del set del 2026-11-16 para que la forma de #644 no se publique: costura en `nucleustest` sin importar quark y módulo `pkg/nucleustest/quarkmake` que la implementa (18.º `go.mod` de nucleus, primero que pina quark: entra en la alineación del tren). **Hecha**: `DX-N1b` (nucleus#648, `pkg/nucleustest/quarkmake`), publicada en Quantum 1.44.0. |
| **D13** | El playground de consultas de quark (criterio del 5 de docs/DX) | **Un constructor por formulario con quark compilado a WebAssembly**: el lector elige un modelo de ejemplo, filtros, orden, límite y motor, y la página enseña el SQL que quark emite en los seis dialectos; no ejecuta nada contra una base. Primero una sesión mide el peso del `.wasm` en la página y si pasa el presupuesto del sitio. Alternativas: **(b)** una galería estática «consulta tipada → SQL por motor» generada en CI desde las 60 del banco (sin interactividad: no es un playground, pero no miente), o **(c)** retirar el punto del criterio (`criterios-5.csv` es del propietario). Recomendación: (a) con la medición delante; si el peso no pasa, (b) | **(a) adelante** (2026-11-08), con la medición hecha el mismo día: quark raíz compila a `js/wasm` sin cambios; el `.wasm` que renderiza una consulta en los seis dialectos por un driver `database/sql` que no ejecuta nada pesa **13,1 MB en crudo, 3,09 MB gzip, 2,19 MB brotli** (suelo de Go sin quark: 3,4 / 0,95 / 0,71; el chunk JS más grande del sitio: 0,75 / 0,18 / 0,14). El sitio no tenía presupuesto escrito; `DX-Q4` publica bajo tres condiciones: el `.wasm` no viaja con la página, lo carga un botón que dice su peso; la página enseña sin JavaScript un ejemplo estático que CI compara con lo que el `.wasm` renderiza (cero deriva); y `quark/scripts/ci/check_playground_weight.sh` falla si el gzip supera **3,5 MB** o si el peso escrito en la página se aleja más del 10 % del medido. El paraguas lo compila al pin en `deploy`/`website-ci` (setup-go + `scripts/build_quark_playground.sh`). **Hecha**: `DX-Q4` (quark#485), publicada en Quantum 1.44.0. |

<!-- FIN BLOQUE DE DECISIÓN DX -->

**HECHA el 2026-11-12 y publicada**: el bloque A, `DX-N1b` (D12),
`DX-Q1`, `DX-Q3`, `DX-Q4` (D13), `DX-N3q` y `DX-N3n1` en Quantum 1.44.0, y
`DX-N3n2` (`nucleus makemigrations` desde los modelos quark, nucleus#656) en
Quantum 1.45.0.

## 3. Lo que entra en el 2.0

### 3.0 La lista cerrada, con el estado de cada aviso (medida el 2026-10-16)

> Es la tabla que lee el guard de deprecaciones
> (`scripts/check_deprecations.sh`, desde `M0-G`, quantum#285): una fila por
> decisión, con el aviso `DEP` que la anuncia y en qué estado está. Los
> estados son tres — **`publicado`** (el fichero está en el pin del set
> vigente), **`en main`** (fusionado en el producto, aún sin set) y **`por
> escribir`** (la sesión de `M0` que lo escribe)— y una fila **`decisión`**
> espera a Carlos (§3.3). El guard FALLA por una fila `publicado` sin
> fichero al pin, por un aviso `active` al pin que nombre el major y no esté
> aquí, y por un aviso ya al pin con su fecha cuya fila no diga `publicado`
> (se corrige en el PR de set que lo trae); AVISA por cada `por escribir` y
> cada `decisión`, y cuenta las que quedan. Un aviso `active` sin fecha
> sólo se tolera mientras su fila esté en `decisión`, `por escribir` o `en
> main` (`DEP-2026-003` de nucleus: D2 lo fechó al 2.0, nucleus#630 escribió
> la fecha y el set del 2026-10-19 la lleva al pin; con la fila en
> `publicado` FALLA). El id se lee de la columna «Aviso» y el producto de la
> columna «Producto», porque los tres repos numeran por su cuenta. `M1` no
> empieza con una fila que no diga `publicado`. Contado al pin de 1.41.0 al
> cierre del 2026-10-16: 12 filas `publicado`, 16 `en main` y 2 `por
> escribir`. **Al pin de 1.42.0 (2026-10-18)**: **23 `publicado`** (las
> nueve de nucleus#630 con nucleus v1.33.0 y las dos de orbit#568 con orbit
> v1.20.0, ventana abierta el 2027-01-17), **7 `en main`** (las de quark,
> quark#470 y quark#471: quark no cortó en 1.42.0 porque desde v1.17.0 sólo
> lleva documentación, y release-please no abre release por `docs:`; llegan
> al pin con la primera release de quark que las contenga, y su ventana se
> cuenta desde ese set), 0 `por escribir` y 0 `decisión`. **`R1` (2026-10-27)**
> añade las filas 31–34, `por escribir`: los cuatro volteos de comportamiento
> que la re-auditoría encontró (QK-76, OR-80, OR-93, OR-103;
> `docs/auditoria/reauditoria/2026-10-23/README.md`); los escribe `M0-R` con
> su salida en 1.x antes de `M1`. **`M0-R` (2026-11-03)** los deja `en
> main`: quark#476 (fila 31, con la salida nueva `quark:"literal_column"`),
> orbit#578 (32), orbit#576 (33) y orbit#582 (34). Quark#476 fecha además
> de nuevo las siete de quark al 2027-02-07: llevaban el 2027-01-17,
> contado desde un set que no las publicó. El set que lleve las releases
> de quark y orbit pasa las once a `publicado`. **Quantum 1.43.0
> (2026-11-07)** las pasó: 34 `publicado`, 0 `en main`. **2026-11-16
> (D30)**: fila 35 `por escribir` (DEP-2026-027 de nucleus:
> `App.AutoMigrate` migra a quark en el 2.0); la escribe `V-N-AM` antes del
> set del 2026-11-23, que es el que la lleva al pin con su ventana al
> 2027-02-21: 34 `publicado`, 1 `por escribir`.

| # | Producto | Qué cambia en el 2.0 | Tipo | Hallazgo | Aviso | Estado | Ventana abre | Sesión |
|---|---|---|---|---|---|---|---|---|
| 1 | quark | se retira el alias `RowLevelSecurity` | retirada (1 marca) | — | DEP-2026-001 | `publicado` | 2026-12-08 | — |
| 2 | quark | se retira el contrato viejo de listeners (`NewListenerFunc` y 3 más) | retirada (4 marcas) | QK-8 | DEP-2026-002 | `publicado` | 2026-12-08 | — |
| 3 | quark | `UpdateBatch` comprueba la versión por defecto | volteo | QK-45 | DEP-2026-003 | `publicado` | 2027-01-04 | — |
| 4 | quark | las demás escrituras de un modelo versionado entran en el bloqueo optimista | volteo | QK-58 | DEP-2026-004 | `publicado` | 2027-02-07 | `M0-Q` |
| 5 | quark | una escritura que no toca filas no dispara hooks, auditoría ni eventos | volteo | QK-46 | DEP-2026-005 | `publicado` | 2027-02-07 | `M0-Q` |
| 6 | quark | `Upsert` hace lo mismo en los seis motores (sin `updateCols`; con el duplicado en otra clave única) | volteo | QK-59, QK-65 | DEP-2026-006 | `publicado` | 2027-02-07 | `M0-Q` |
| 7 | quark | `ON DELETE SET DEFAULT` igual en los seis motores | volteo | QK-60 | DEP-2026-007 | `publicado` | 2027-02-07 | `M0-Q` |
| 8 | quark | `GroupBy` sin `Select` es un error | volteo | QK-24 | DEP-2026-008 | `publicado` | 2027-02-07 | `M0-Q` |
| 9 | quark | el `LIKE` plano declara `ESCAPE '\'` en todos los motores | volteo | QK-32 | DEP-2026-009 | `publicado` | 2027-02-07 | `M0-Q` |
| 10 | quark | Oracle cuenta `VARCHAR2` en caracteres | volteo (esquema) | QK-50 | DEP-2026-010 | `publicado` | 2027-02-07 | `M0-Q` |
| 11 | nucleus | se retira `Context.HTML` con cadena cruda | retirada (1 marca) | NU-41 | DEP-2026-009 | `publicado` | 2027-01-04 | — |
| 12 | nucleus | se retiran `Context.Get`/`Set` sin tipo (`router.Context.Set` se promociona con la misma firma: hay que mirar las dos) | retirada (2 marcas) | — | DEP-2026-011 | `publicado` | 2027-01-02 | — |
| 13 | nucleus | se retiran los constructores que paniquean (`NewJWTManager`, `NewModuleMigrator`, `NewModuleFSMigrator`, `CSRFMiddleware`) | retirada (4 marcas) | NU-41 | DEP-2026-012 | `publicado` | 2027-01-02 | — |
| 14 | nucleus | storage declarado sin `WithStorage()` en `WithoutDefaults()` deja de arrancar | negativa | NU-99 | DEP-2026-013 | `publicado` | 2027-01-02 | — |
| 15 | nucleus | plugins externos fuera de la allowlist, denegados | negativa | — | DEP-2026-014 | `publicado` | 2027-01-02 | — |
| 16 | nucleus | `mail_driver` sin `WithMail()`, deja de arrancar | negativa | — | DEP-2026-015 | `publicado` | 2027-01-02 | — |
| 17 | nucleus | `rate_limit_*` sin `WithRateLimit()`, deja de arrancar | negativa | — | DEP-2026-016 | `publicado` | 2027-01-02 | — |
| 18 | nucleus | claves de authz y `Module.Policies` sin `WithAuthz()`, deja de arrancar | negativa | — | DEP-2026-017 | `publicado` | 2027-01-02 | — |
| 19 | nucleus | `profiling_enabled` sin guarda, deja de arrancar | negativa | — | DEP-2026-018 | `publicado` | 2027-01-02 | — |
| 20 | nucleus | las filas de política de 3 columnas dejan de leerse (hoy `active` SIN fecha, contra la política §2) | retirada | — | DEP-2026-003 | `publicado` | 2027-01-17 | `M0-N` |
| 21 | nucleus | `nucleustest` deja de enlazar SQLite siempre | volteo (empaquetado de test) | NU-121 | DEP-2026-019 | `publicado` | 2027-01-17 | `M0-N` |
| 22 | nucleus | el proveedor asynq sale a `providers/tasks-asynq` (decisión 4 de A12) | empaquetado | — | DEP-2026-020 | `publicado` | 2027-01-17 | `M0-N` |
| 23 | nucleus | `session_idle_timeout` con valor de fábrica | volteo (config) | NU-72 | DEP-2026-021 | `publicado` | 2027-01-17 | `M0-N` |
| 24 | nucleus | los errores salen en problem+json por defecto; `WithErrorEnvelope()` para quedarse | volteo | — | DEP-2026-022 | `publicado` | 2027-01-17 | `M0-N` |
| 25 | nucleus | se retira `NewWrapResponseWriter(w, _ int)`; `router.Wrap(w)` desde 1.x | retirada (1 marca) | NU-41 | DEP-2026-023 | `publicado` | 2027-01-17 | `M0-N` |
| 26 | nucleus | se retira `pkg/model` como capa de datos pública (48 símbolos); los generadores, el starter, `nucleustest` y la doc pasan a quark en 1.x (la DX al 5) y `pkg/app`/`pkg/nucleus` dejan de exponerlo | retirada (paquete) | — | DEP-2026-024 | `publicado` | 2027-01-17 | `M0-N` |
| 27 | nucleus | se retira la puerta sin tipo de `signals` (`Signal`, `Event`, `Handler`, `Bus.On/Emit/EmitAsync`); las constantes de ciclo de vida se van con `pkg/model` (fila 26) y no se sustituyen por topics tipados (D20) | retirada (marcas) | — | DEP-2026-025 | `publicado` | 2027-01-17 | `M0-N` |
| 28 | nucleus | SQLite guarda las fechas en un formato que `date()` entiende | volteo (datos) | NU-110 | DEP-2026-026 | `publicado` | 2027-01-17 | `M0-N` |
| 29 | orbit | la identidad del nodo del fleet atada al certificado cuando hay mTLS; `AllowSharedAgentCertificate` para quedarse | volteo (config) | OR-57 | DEP-2026-001 (orbit) | `publicado` | 2027-01-17 | `M0-O` |
| 30 | orbit | se retira el adaptador `datasource/nucleus` (el panel sobre modelos de `pkg/model`): el panel se monta sólo sobre `quarkdatasource` (D5b) | retirada (paquete) | — | DEP-2026-002 (orbit) | `publicado` | 2027-01-17 | `M0-O` |
| 31 | quark | las directivas desnudas de la gramática de `pkg/model` en un tag `db` (`db:"pk"`, `db:"readonly"`…) pasan de aviso a `ErrInvalidTag`; opt-out explícito para una columna que de verdad se llame así | volteo | QK-76 | DEP-2026-011 | `publicado` | 2027-02-07 | `M0-R` |
| 32 | orbit | el operador queda atado a su tenant (columna en la cuenta de operador): sin `tenant_switch` ni superusuario no lee ni escribe otro, venga de `?tenant=` o del resolver; en 1.x la columna es opcional y un operador sin tenant en una aplicación multi-tenant avisa | volteo (config) | OR-80 | DEP-2026-003 (orbit) | `publicado` | 2027-02-07 | `M0-R` |
| 33 | orbit | el entorno del proceso sale del snapshot de `system_pulse` y pasa a un permiso propio (`system_env`); en 1.x el permiso existe y `system_pulse` sigue viéndolo con aviso | volteo (permisos) | OR-93 | DEP-2026-004 (orbit) | `publicado` | 2027-02-07 | `M0-R` |
| 34 | orbit | `PeerService.Sync` sólo acepta peers configurados en `--peers` (y bajo mTLS, el CN del certificado ha de ser el `server_id` anunciado); en 1.x `--peer-allowlist` opt-in y un WARN por cada peer no configurado | volteo (fleet) | OR-103 | DEP-2026-005 (orbit) | `publicado` | 2027-02-07 | `M0-R` |
| 35 | nucleus | `App.AutoMigrate` acepta modelos quark y migra por la ruta de `makemigrations`; deja de leer la gramática `db:` de `pkg/model` (D30) | volteo | — | DEP-2026-027 | `por escribir` | — | tramo 1.x (`V-N-AM`, antes del set del 2026-11-23) |

Lo que esta tabla deja fuera a propósito: la migración de orbit (§2.4, es
trabajo de 1.x, no un cambio del 2.0), la DX al 5 (§2.1, aditiva) y el
rediseño (§3.4, que llega como opción en una minor y se vuelve el defecto
en el 2.0 sin retirar nada). Los ids `DEP-2026-010` y `019…026` de arriba
y el `DEP-2026-002` de orbit son los siguientes libres de cada repo al 2026-10-16, y
`DEP-2026-011` de quark y `DEP-2026-003…005` de orbit (filas 31–34) los
siguientes libres al 2026-10-27, y `DEP-2026-027` de nucleus (fila 35) el
siguiente libre al 2026-11-16; si una decisión se
cae, su número no se reutiliza (queda la fila como `descartado` con la
fecha).

### 3.1 Retiradas de API (12 símbolos, con aviso y fecha)

| Producto | Aviso | Qué se retira |
|---|---|---|
| quark | DEP-2026-001 | el alias `RowLevelSecurity` |
| quark | DEP-2026-002 | el contrato viejo de registro de listeners (`NewListenerFunc`) |
| nucleus | DEP-2026-009 | `Context.HTML` con cadena cruda |
| nucleus | DEP-2026-011 | `Context.Get` / `Context.Set` sin tipo (ojo: `router.Context.Set` se promociona con la misma firma, quitarlo exige más que borrar) |
| nucleus | DEP-2026-012 | los constructores que paniquean |

Y **asynq sale a su propio módulo** (decisión 4 de A12: ruptura de
empaquetado, va en el major).

### 3.2 Negativas de configuración (aplicaciones core-only y plugins)

Una aplicación `WithoutDefaults()` que declara un subsistema sin la opción que
lo monta **deja de arrancar** (hoy lo avisa con una línea ERROR). La salida ya
existe en 1.x.

| Aviso | Configuración ignorada | Salida |
|---|---|---|
| DEP-2026-013 | storage | `WithStorage()` |
| DEP-2026-015 | `mail_driver` | `WithMail()` |
| DEP-2026-016 | `rate_limit_*` | `WithRateLimit()` |
| DEP-2026-017 | claves de authz y filas de `Module.Policies` | `WithAuthz()` |
| DEP-2026-018 | `profiling_enabled` sin guarda | `WithAuthz()` |
| DEP-2026-014 | plugins externos fuera de la allowlist | denegados por defecto |

### 3.3 Cambios de comportamiento

| Hallazgo | Qué cambia | Hoy en 1.x |
|---|---|---|
| QK-45 | `UpdateBatch` comprueba la versión por defecto (todo o nada, `ErrStaleEntity` por fila) | opción `CheckVersions()` (DEP-2026-003 de quark) |
| QK-58 | `UpdateMap`, la rama de actualización de `Upsert`, `Delete`/`HardDelete` de una entidad, el borrado lógico y `Restore` entran en el bloqueo optimista | sin predicado de versión |
| QK-46 | una escritura que no toca filas no dispara hooks, auditoría ni eventos | los dispara |
| QK-59 · QK-65 | `Upsert` hace lo mismo en los seis motores (sin `updateCols`; con el duplicado en otra clave única) | documentado por motor |
| QK-60 | `ON DELETE SET DEFAULT` igual en los seis motores (MySQL/MariaDB lo aceptan sin ejecutarlo) | documentado |
| QK-24 | `GroupBy` sin `Select` es un error | aviso |
| QK-32 | el `LIKE` escapa igual en todos los motores | escape por defecto de cada motor |
| NU-72 | la sesión caduca por inactividad de fábrica | `session_idle_timeout: 0` |
| — | los errores salen en problem+json por defecto | el sobre por defecto |
| OR-57 | la identidad del nodo del fleet atada al certificado (con mTLS) | opcional |
| NU-121 | `nucleustest` deja de enlazar SQLite siempre | lo enlaza |
| QK-76 | las directivas desnudas de `pkg/model` en un tag `db` son `ErrInvalidTag` (R1) | WARN y migra una columna `pk` |
| OR-80 | el operador del panel queda atado a su tenant (R1) | el panel confina lo que el host resuelve por petición |
| OR-93 | el entorno del proceso sólo bajo un permiso propio (R1) | 58 de 70 variables en claro bajo `system_pulse` |
| OR-103 | la malla sólo acepta peers configurados (R1) | cualquier llamante con credencial de agente es peer |

**Las ocho decisiones de `M0` — DECIDIDAS por Carlos el 2026-10-16**, una
a una, sobre lo que `M0-S0` midió esa misma mañana (plan de A12, sección
«`M0` — inventario medido»). Siete siguen la recomendación; **D5 no**:
`pkg/model` se retira en el 2.0, y con él el adaptador `datasource/nucleus`
de orbit (D5b). Ninguna fila del §3.0 queda en `decisión`: `M0-N` y
`M0-O` pueden escribir todos sus avisos.

<!-- INICIO BLOQUE DE DECISIÓN M0 -->

| id | Qué decide | Propuesto | Decisión de Carlos |
|---|---|---|---|
| **D1** | NU-72: el valor de fábrica de `session_idle_timeout` | **30m**: es lo que ya muestra `docs/guides/AUTH_GUIDE.md`, lo que `doctor security` pide al avisar del `0` y lo que satisface ASVS V3.3.2. Un `0` explícito en la configuración sigue apagándolo; `M0-N` comprueba que el cargador distingue «sin clave» de «clave a 0» | **30m** (2026-10-16). Un `0` explícito sigue apagándolo. |
| **D2** | DEP-2026-003 de nucleus (filas de política de 3 columnas), `active` sin fecha | **Fecharlo al 2.0**: la lectura de filas de 3 columnas se retira en v2.0.0 con ventana desde el set que lo publique. La política §2 no admite un aviso sin fecha, y hoy es el único. La alternativa es cerrarlo como `completed` sin retirar nada, que es dejar el código de compatibilidad para siempre | **Fecharlo al 2.0** (2026-10-16): la lectura de filas de 3 columnas se retira en v2.0.0. |
| **D3** | el sobre de errores: problem+json por defecto en el 2.0 | **Sí, con la salida primero**: `WithErrorEnvelope()` en 1.x (hoy sólo existe `WithProblemDetails()`, el opt-in), y orbit leyendo los dos formatos en su minor de migración (`api.ts` hoy lee sólo el sobre). Sin la salida, voltear rompe a todo cliente que parsee `{"error":…}` | **Sí, con la salida primero** (2026-10-16): `WithErrorEnvelope()` en 1.x; orbit lee los dos formatos. |
| **D4** | las firmas de constructores que NU-41 señaló | **Sólo `NewWrapResponseWriter`**: tiene un parámetro muerto (`_ int`), orbit lo llama en 2 sitios, y la salida es `router.Wrap(w)` en 1.x con la marca en el viejo. **`authz.New` se queda**: su variádico no rompe a nadie, y moverle el logger al final por estilo tocaría 18 ficheros de orbit a cambio de nada. La guía de estilo (cfg-struct, logger último, nunca panic) rige para constructores NUEVOS | **Sólo `NewWrapResponseWriter`** (2026-10-16): `router.Wrap(w)` en 1.x; `authz.New` se queda. |
| **D5** | `pkg/model` como capa de datos pública | **Bajarlo a sustrato en el 2.0 y retirarlo en el 3.0**: pasa a `transitional`, los generadores, el starter y la doc enseñan quark (es la DX al 5, aditiva, en 1.x), y el registro sigue publicado porque el adaptador `datasource/nucleus` de orbit entero se apoya en él (6 ficheros, 3 módulos) y no hay sustituto en la ventana. Retirarlo en el 2.0 es decidir que el panel sobre `pkg/model` desaparece con el major | **RETIRARLO EN EL 2.0** (2026-10-16, contra la recomendación): desaparece como capa pública con el major; generadores, starter, `nucleustest` y doc pasan a quark en 1.x. **D5b** (misma tarde): el adaptador `datasource/nucleus` de orbit **se retira** con él y el panel queda sólo sobre `quarkdatasource` (fila 30; orbit lo deprecia en 1.x con su `DEP-2026-002`). |
| **D6** | los buses que se solapan | **Retirar la puerta sin tipo de `signals`** (`Signal`, `Event{Payload any}`, `Handler`, `Bus.On/Emit/EmitAsync`) y quedarse con `signals.Bus` y la API tipada que A7 entregó; las señales de ciclo de vida (`PostSave`…) se publican como topics tipados en 1.x. `observability.Bus` no se toca: es el fan-out de observabilidad, no un bus de dominio. Orbit guarda un `*signals.Bus` en el adaptador y en el panel; `M0-O` migra lo que use la puerta vieja | **La puerta sin tipo** (2026-10-16): se retiran `Signal`, `Event`, `Handler`, `Bus.On/Emit/EmitAsync`; `observability.Bus` no se toca. **Y el 2026-11-16 (D20)**: sin topics tipados de ciclo de vida: `M0-N` midió que no se construyen (las ocho señales las emite `pkg/model`, que D5 retira) y DEP-2026-025 lo dice; la salida son los hooks de quark. |
| **D7** | QK-50: Oracle cuenta `VARCHAR2` en caracteres | **Entra** (ya estaba propuesto): cambia el DDL que genera el plan en Oracle, no los datos; una tabla existente conserva su semántica de bytes hasta que una migración la toque, y el aviso lo dice | **Entra** (2026-10-16). |
| **D8** | NU-110: SQLite guarda las fechas en un formato que sus funciones de fecha entienden | **Entra** (ya estaba propuesto), con la lectura de las dos formas en el 2.0 y una migración de datos opcional documentada: cambia lo que hay escrito en bases existentes, y es el único de la lista que lo hace | **Entra, leyendo las dos formas** (2026-10-16), con la migración de datos opcional documentada. |

<!-- FIN BLOQUE DE DECISIÓN M0 -->

**Decididos ya, sin aviso todavía** (los escribe `M0-Q`/`M0-N`, sin
esperar al bloque): QK-58, QK-46, QK-59+QK-65, QK-60, QK-24 y QK-32 en
quark; NU-121 y asynq a módulo propio en nucleus; OR-57 en orbit (que
además estrena `docs/deprecations/`).

**Las decisiones que deja `M0-E`** (el ensayo del major, 2026-10-18; lo
medido está en el plan de A12, sección «`M0-E` — el ensayo del major,
medido»). Tres cosas que ningún aviso decidía y que la rama `dry-run/2.0`
tuvo que resolver de la forma menos sorprendente; Carlos confirma o cambia.

<!-- INICIO BLOQUE DE DECISIÓN M0-E -->

| id | Qué decide | Propuesto | Decisión de Carlos |
|---|---|---|---|
| **D9** | DEP-2026-017 contra el starter `api`: en el 2.0 un `nucleus new --template api` (sin `WithAuthz()`, por la decisión del 2026-10-06 escrita en el aviso) con un `nucleus generate module` (que escribe filas de política) rehúsa arrancar | **`generate module` deja de escribir filas de política en un proyecto `WithoutDefaults()` sin `WithAuthz()`** (las escribe comentadas, con la pista de `WithAuthz()`), y el starter `api` conserva su contrato «sin authz». La alternativa —que el starter pase `WithAuthz()`— contradice la decisión escrita y cambia qué protege un starter recién generado. La rama hace lo propuesto | **A, el 2026-11-13**: `generate module` detecta en `main.go` un root `WithoutDefaults()` sin `WithAuthz()` y escribe las filas de política COMENTADAS con la pista de `WithAuthz()`; lo dice en su salida (las escrituras del módulo responden a cualquiera hasta añadir la opción) y el test generado afirma ese 201 con la misma frase, en vez de un 403 que allí no existe. El starter `api` conserva «sin authz». Aditivo, en 1.x: sesión `D9-N` del plan de A12, **hecha el 2026-11-13 (nucleus#662)**: el lector mira todos los ficheros del paquete main de `--out` (y bajo `cmd/<app>/`), `--with-policy` conserva su aviso, y `generate resource`/`startapp` dicen sobre ese root que nada carga `rbac_policy.csv`. DEP-2026-017 anota que el generador ya no produce la combinación en un root que puede leer. **Hecha**: `D9-N` (nucleus#662), publicada en Quantum 1.45.0. |
| **D10** | El adaptador de Quark no tiene metadatos por campo (lista, búsqueda, filtro, sólo lectura); el de Nucleus los leía de las etiquetas `admin:`, y con D5b el panel sólo tiene el de Quark | **Añadir a `quarkdatasource` opciones por modelo y por campo en una minor 1.x, ANTES del major** (leídas de una etiqueta `admin:` en el struct de quark o pasadas en `Register`): es lo que hace que «el panel sobre quarkdatasource» sea el mismo panel. Sin ello el 2.0 lista y busca todas las columnas de cada modelo | **A, el 2026-11-13**: opciones Go tipadas en `quarkdatasource.Register[T](a, opts...)` paralelas a `ModelConfig` —`ListFields`, `SearchFields`, `Filters`, `Exclude`, `ReadOnly` (modelo y campo), `Label`, `Choices`, `Icon`, `OrderBy`, `PageSize`— sobre los defaults de hoy (`ListFields` vacío sigue siendo «todas»), más exclusión por defecto, con aviso en el log, de columnas con nombre sensible (`password`, `*_hash`, `*_token`, `secret`). Sin etiqueta `admin:` en el struct de quark: el ORM no interpreta metadatos de UI. Minor de orbit en 1.x, antes del major: sesión `D10-O` del plan de A12; tabla `ModelConfig` → opciones en MA-2026-024. **Hecha**: `D10-O` (orbit#596, orbit#597, nucleus#661), publicada en Quantum 1.45.0. |
| **D11** | ADR-012 de orbit (quark fuera del grafo de la raíz) frente a D5b | **Sucederlo en el 2.0**: la raíz de orbit requiere quark y `quarkdatasource` (el panel sólo se monta sobre ellos; sus tests y el banco los necesitan). En 1.x nada cambia | **A, el 2026-11-13**: en el 2.0 la raíz de orbit requiere quark, su driver SQLite (tests) y `quarkdatasource`, como ya hace `dry-run/2.0`; enmienda a ADR-012 (siguen vigentes `datasource` hoja y el agente sobre el contrato; cae la consecuencia «quark fuera de la raíz»); `check_internal_pins.sh`, `align_set` y `bump-set` aprenden el tercer pin interno; OR-88 (sonda DS-03 sobre quark) se cierra en `M1`. En 1.x nada cambia. C (devolver `quarkdatasource` a la raíz) queda anotada para un 2.x si el segundo corte sigue costando |
<!-- FIN BLOQUE DE DECISIÓN M0-E -->

Medido por `M1-S0` (2026-11-16): `bump-set.sh` sólo descubre módulos por la
presencia de `go.mod` (`:143`) y no compara pines; la cláusula de D11
«`check_internal_pins.sh`, `align_set` y `bump-set` aprenden el tercer pin
interno» la cumplen `M1-T-O` (`check_internal_pins.sh`, `align_set.sh`),
`M1-V2-P`(a) (`align-orbit-pins.sh` con lookup por `module`, `manifest-guard`
§5) y `M1-T-P` (`train.sh`, `orbit-converge.sh`); la columna «Decisión de
Carlos» de D11 queda para su «**Hecha**», como en D10.

**Decisiones del 2026-11-16**, al certificar Quantum 1.45.0: lo que la
sesión midió al preguntarse qué falta para el 5 de 5 y para empezar el 2.0,
planteado a Carlos una decisión cada vez. Las ejecuta lo que dice la columna
«Decisión»; la secuencia resultante está en la sección «La ventana hasta el
2.0» del [plan de A12](A12-rendimiento-reauditoria-cierre.md).

<!-- INICIO BLOQUE DE DECISIÓN 2026-11-16 -->

| id | Qué decide | Propuesto | Decisión de Carlos |
|---|---|---|---|
| **D14** | La guía de migración (`docs/planes/guia-migracion-2.0.md`) estaba rancia: 23 entradas con 34 avisos activos al pin y ningún guard corriendo su `--check` | Regenerarla en el PR de set de 1.45.0 y registrar un guard que corra su `--check` | **Regenerar en el set y guard después** (2026-11-16): la guía fue en quantum#319; el guard, `umbrella-migration-guide`, en un PR propio del paraguas (quantum#321: registro, fixture, `bump-set` lo regenera y `train.sh` lo cuenta en `RUTAS_REPIN`). |
| **D15** | Las diez «sesiones cortas» del §2.2 que siguen abiertas (NU-129, NU-131, OR-71, OR-74, OR-75, OR-76, NU-108, QK-54, QK-68, QK-69; todas P3); el plan de A12 no las nombraba en la precondición de `M1` | Cerrarlas en sets 1.x antes de `M1`, por producto, y que el plan las nombre | **Cerrarlas en 1.x antes de `M1`** (2026-11-16). |
| **D16** | Qué sesión sigue a 1.45.0: `M1` no tiene troceado (su fila decía «retirar los doce símbolos», la cifra de `S0`) y el contrato de sesión exige medir antes de trocear | Una sesión de medición `M1-S0` que trocee `M1` (ruta `/v2`, retiradas, `pkg/model` y el adaptador, asynq, D11, guía, tren del 2.0.0), fije el alcance de `R2` y deje el rediseño como carril paralelo a la espera de las maquetas (el alcance de `R2` lo fijó D18 el mismo día; lo que entra en la ventana, D17) | **La medición primero** (2026-11-16); las diez cortas, después o en paralelo. |
| **D17** | Las doce semanas hasta el suelo del 2.0 (2027-02-07): el plan cerraba A12 con el 2.0 certificado y dejaba las 32 dimensiones por debajo del 5 para A13 | Adelantar en sets 1.x lo aditivo de las 32 que `M1-S0` marque como corto y seguro (QADR-0010: nada rompiente); `M1` arranca en enero de 2027, lo más tarde posible para no rebasar el major | **Adelantar en 1.x lo aditivo** (2026-11-16). |
| **D18** | El alcance de `R2`: el plan decía «re-puntuar sólo lo que `M1` tocó», pero con D17 casi todas las dimensiones se mueven desde `R1` | Re-auditoría completa como `R1` (36 dimensiones, mismo método e instrumentos): notas comparables y la lista exacta para A13 | **Re-auditoría completa** (2026-11-16). |
| **D19** | La excepción de govulncheck para GO-2026-6909 (lane SAML de nucleus) caduca el 2026-12-31, antes del suelo del 2.0; golang/vulndb#6909 se cerró el 2026-11-15 con el registro de v0.5.2 pendiente de publicar | Esperar al registro (al publicarse, el gate marca la línea como rancia y se borra); si el 2026-12-15 la base de datos sigue sin versión arreglada, un chore PR en nucleus mueve la caducidad al 2027-03-31 con la misma forma acotada y auto-retirable | **Esperar; extender sólo si el 2026-12-15 no está** (2026-11-16). |
| **D20** | Las señales de ciclo de vida en el 2.0: la fila 27 y la recomendación de D6 hablaban de topics tipados en 1.x; `M0-N` midió que no se construyen y DEP-2026-025, publicado y con ventana, dice que se van con `pkg/model` | Vale el aviso publicado: sin topics tipados; la salida son los hooks de quark (`BeforeCreate`, `AfterUpdate`…); corregir la fila 27 y D6 | **Lo que dice el aviso publicado** (2026-11-16). |
| **D21** | La política de soporte (`docs/gobernanza/POLITICA_SOPORTE.md`): S1, S2 y S4–S8 aprobadas el 2026-09-09, S3 (LTS) sin aprobar, y sin publicar trece sets después (QM-25) | Ejecutar su §8 ya, declarando expresamente que no hay LTS (S3 sigue sin aprobar), en una sesión de docs de la ventana: un QADR nuevo (el §8.2 de la política cita QADR-0010, ya ocupado por las rupturas agrupadas), las cuatro `SECURITY.md`, `website/docs/support.md`, calendario YAML con el guard `umbrella-release-calendar` y los campos de soporte del manifiesto; cierra QM-25 y mueve la dimensión de gobernanza | **Publicar ya, sin LTS** (2026-11-16). |
| **D22** | La ventana que prometen las cuatro `SECURITY.md` (§7.4 de la política): orbit «el último minor de cada módulo», nucleus y quark «los dos últimos minors», la suite S2 | La ventana de suite (S2: 60 días naturales desde la certificación y, en todo caso, los 3 últimos sets, lo que sea más amplio) manda sobre los tres productos; las `SECURITY.md` de producto dejan de contar minors | **La de suite manda sobre los tres** (2026-11-16). |
| **D23** | La protección de `main`: sólo nucleus la tiene (gate requerido, rama al día, sin force-push ni borrado, admins incluidos); es lo que más pesa en el Scorecard (QM-33) y el auto-merge de Dependabot la exige junto a «Allow auto-merge» | Proteger quantum, quark y orbit como nucleus y permitir auto-merge en los cuatro; antes, el PR de orbit que lleva el refresco de la matriz de módulos (hoy un push directo a `main` del bot tras cada tag) a un PR | **Los cuatro como nucleus, con auto-merge** (2026-11-16); los ajustes del repositorio los ejecuta el propietario con los comandos que la sesión prepare. |
| **D24** | Discussions: QM-13 proponía sólo quantum y figura hecho; apagadas en los cuatro (QM-42); la dimensión de comunidad está fuera del gate | Activarlas sólo en quantum | **Sólo en quantum** (2026-11-16); clic del propietario; QM-42 se cierra con él. |
| **D25** | La nota de Scorecard del paraguas: `publish_results` en false, la nota agregada no existe en ningún sitio (QM-33); los cuatro repos son públicos | Publicarla (`publish_results: true` en el workflow) y el badge cuando la primera corrida la registre | **Publicar la nota** (2026-11-16). |

<!-- FIN BLOQUE DE DECISIÓN 2026-11-16 -->

**Las trece preguntas de `M1-S0`** (2026-11-16; plan de A12, sección «`M1-S0`
— el major, medido y troceado», «Lo que espera al propietario», con la
recomendación y la razón medida de cada una). D26 y D27 van antes del primer
commit del major (`M1-V2-Q`(1)); las demás, delante de la sesión que las cita.
La columna «Decisión de Carlos» la rellena Carlos con su fecha; las
precondiciones de las sesiones la comprueban con `grep` sobre este fichero (la
forma de D1…D25).

<!-- INICIO BLOQUE DE DECISIÓN M1-S0 -->

| id | Qué decide | Propuesto | Decisión de Carlos |
|---|---|---|---|
| **D26** | El número 2.0.0 en los 24 módulos v0.x (con `bump-minor-pre-major` un `!` los deja en v0.(x+1).0, y un tag `v0.*` sobre `/v2` es inválido para Go) | (a) footer `Release-As: 2.0.0` en el squash del commit `!` de cada repo (ADR-032 veta `Release-As` para suplir un `!`, no para fijar el número junto a él); (b) `release-as` en los 24 paquetes + un `chore` que lo quite; (c) plugin `linked-versions`. **(a)**, con el manifiesto del release PR revisado antes de fusionarlo | **Release-As en el commit `!`** (2026-11-16): la opción (a), con el manifiesto del release PR revisado antes de fusionarlo. |
| **D27** | Cómo aterriza el major en `main` y cómo se llama la rama (desde el primer merge de un `!` en `main` no sale ningún set 1.x) | (a) rama `major/2.0` por repo con merge final; (b) sin rama. **(a) con merge commit**, los tres `!` seguidos tras el último set 1.x certificado, sin rama `release/1.x` | **Rama `major/2.0` por repo con merge commit** (2026-11-16): los tres `!` seguidos tras el último set 1.x certificado, sin rama `release/1.x`. |
| **D28** | El lint del `!` que ADR-032 regla 2 promete y no existe en ningún repo | construirlo (`M1-T-LINT-Q/N/O/P`, con excepción por rama del major) o corregir ADR-032:53-54. **Construirlo** | **Construirlo** (2026-11-16): `M1-T-LINT-Q/N/O/P`, con excepción por rama del major. |
| **D29** | Tres correcciones de avisos publicados amplían lo que dicen que rompe (DEP-2026-025 l.54, DEP-2026-024 `hooks.NewSQLObserver`, orbit DEP-2026-002 `agent.Config.Registry`/`Databases`); `POLITICA_DEPRECACION.md` §3 no las exime de ventana | (a) comparten la ventana del aviso que retira sus tipos (la regla, como enmienda del §3 de la política); (b) aviso propio con ventana nueva (mueve el 2.0 ≥ 90 días desde el set que lo publique, o capa de adaptación hasta el 3.0). **(a)** | **Comparten la ventana del aviso que retira sus tipos** (2026-11-16): la regla se escribe como enmienda del §3 de `POLITICA_DEPRECACION.md` (`M1-G-N`/`M1-G-O`); nada se mueve. |
| **D30** | `App.AutoMigrate(models ...any)` en el 2.0 (sigue leyendo la gramática `db:` desde `internal/model`) | queda como la rama, anotado como deuda del 3.0. **Queda** | **No se queda: migrarlo a quark** (2026-11-16, contra la recomendación): en el 2.0 `App.AutoMigrate` acepta modelos quark y migra por la ruta de `makemigrations`; la gramática `db:` de `pkg/model` deja de leerse. Exige un aviso DEP nuevo en nucleus (DEP-2026-027, fila 35 del §3.0, `por escribir`; lo escribe `V-N-AM` con su salida en 1.x, que ya existe: `makemigrations`). Si lo publica el set del 2026-11-23, su ventana abre el 2027-02-21 y el suelo del 2.0 pasa del 2027-02-07 al 2027-02-21; cada set que se retrase lo mueve una semana. |
| **D31** | DEP-2026-014 promete «ni siquiera se le preguntan sus capacidades» y `DiscoverExternal`/`Host.CollectInventory` siguen sondeando | parámetro de política aditivo en 1.x, o rebajar la promesa a «denegado, aunque sondeado». **Rebajar la promesa** (`M1-G-N`) | **Rebajar la promesa** (2026-11-16): «denegado, aunque sondeado» (`M1-G-N`). |
| **D32** | La arista nueva raíz → `quarkdatasource` (D11) frente a ADR-006 l.97 | tolerancia en `check_internal_pins.sh`, corte de convergencia (7 extra medidos), o el experimento con `extra-files` de release-please sobre raíz → `ui` en 1.x. **El experimento primero** | **El experimento con `extra-files` primero** (2026-11-16): si funciona, ADR-006 l.97 se mantiene y no hay tolerancia; si no, converger. |
| **D33** | Un último tag v1 con `// Deprecated: use …/v2` en el `go.mod` (lo único que avisa a `go get @latest`; contradice `POLITICA_SOPORTE.md:62,240`) | **descartarlo por escrito**; la sección fija de la guía lo dice | **Descartarlo por escrito** (2026-11-16): la sección fija de la guía lo dice (`M1-G-P`(a)). |
| **D34** | Dónde se publica la guía de migración y si `quark/README.md:24` cumple su promesa literal | una página en `/start/migrating-to-2.0` + `docs/MIGRATION_v2.0.0.md` como puntero, o una por producto. **Una página en `start` + el puntero** | **Una página en `/start/migrating-to-2.0` + `docs/MIGRATION_v2.0.0.md` en quark como puntero** (2026-11-16). |
| **D35** | Los suelos de los drivers en `cmd/quark` y `cmd/nucleus` (QK-72/NU-147) | segunda pasada de suelos y segundo tag del CLI por tren (`M1-T-P`), o declarar el lag. **La segunda pasada** | **Declarar el lag** (2026-11-16, contra la recomendación): `declared_lags` de `versions.yaml` para `cmd/quark` y `cmd/nucleus`; sin segunda pasada de suelos ni segundo tag del CLI por tren; la guía de migración lo dice. |
| **D36** | `nucleus add` y `nucleus new` y la versión de orbit del set (NU-143; el CLI se taggea antes que orbit) | `versions.yaml` por red con caída a la tabla embebida, o «el set anterior». **Red con caída a la tabla** | **`versions.yaml` por red con caída a la tabla embebida** (2026-11-16). |
| **D37** | El rediseño (§3.4): (a) si un defecto visual que cambia es un volteo con aviso (`RD-2` al 2.1 si sí); (b) §4.4/§4.5 sin maquetas antes del corte; (c) partir de «el estado fijado» o reabrir la marca; (d) `RD-0` con las diez cortas abiertas; (e) AA en el sitio; (f) el look del fleet en el `server` o en el build (sin medir) | (a) sin aviso; (b)…(f) como «Lo que espera al propietario» 12 | **(a) sin aviso** (2026-11-16): `classic` sigue existiendo y nada se retira; **(b)** sin maquetas antes del corte, el 2.0.0 se certifica con la página «qué cambia en 2.0» y la guía, sin tema nuevo: el rediseño llega como opción en una 2.x y es el defecto en el 2.1 (§4.4/§4.5 enmendados); **(c) reabrir la marca** (contra la recomendación): `RD-0` puede proponer una marca nueva; **(d)** `RD-0` arranca ya, en paralelo a las diez cortas (§3.4 enmendado); **(e)** sí: un control AA nuevo sobre `website/build`; **(f)** medir primero la superficie del `server`, fuera del carril. |
| **D38** | La ventana (D17): (a) QK-71 decimal; (b) MIG-05 sólo opt-in; (c) QM-37; (d) OR-94/ADR-007 y EXPLAIN desde el feed; (e) QM-34 «decir L2» o L3; (f) lo largo que la ventana no cubre; (g) PG-01…04/MY-01; (h) OR-71 sin tocar `datasource.Query`; (i) alcance de COPY; (j) NU-150 | como «Lo que espera al propietario» 13 | **(a) QK-71 → A13** (2026-11-16); **(b)** MIG-05 sólo opt-in en 1.x; **(c)** QM-37: retirar el punto (los snapshots no se reescriben; el guard avisa); **(d)** OR-94 y EXPLAIN desde el feed → ambos a A13 (contra la recomendación); **(e)** QM-34: subir a SLSA L3, en A13 (contra la recomendación); **(f)** lo largo: todo a A13; **(g)** PG-01…04/MY-01: retitular el criterio a lo medido (contra la recomendación; `criterios-5.csv` y la decisión 1 del arco); **(h)** OR-71: sin tocar el contrato `datasource.Query`; **(i)** QK-54 COPY → A13 (contra la recomendación); **(j)** NU-150: retitular el criterio de `N1` a ≤ 27 MB (contra la recomendación). |

<!-- FIN BLOQUE DE DECISIÓN M1-S0 -->

### 3.4 Rediseño estético (decisión de Carlos, 2026-10-06)

Que el salto de versión **se note**:

- **Orbit**: un tema nuevo por defecto del panel (Data Studio, fleet,
  formularios, navegación). Si cambian los tokens o las claves del tema que A11
  hizo configurables, la guía de migración lo dice.
- **Documentación**: tema nuevo del sitio Docusaurus, portada, la versión 2.0
  de los docs y una página «qué cambia en 2.0».
- **Un sistema de diseño común** (color en claro y oscuro, tipografía,
  espaciado, componentes) para que panel y documentación se vean del mismo
  producto.
- **La dirección visual la elige Carlos** entre maquetas; ninguna sesión la
  decide sola.
- **Se planifica después de lo pendiente** (§2), no antes. Puede llegar como
  opción en una minor y pasar a ser el defecto en el 2.0, como `CheckVersions()`.
- Tiene que respetar lo que ya vigilan los guards y bancos: contraste AA en los
  dos temas (banco de navegador), el presupuesto del panel de 400 KB en gzip
  (`O1`), la personalización por configuración (el tema nuevo es el de por
  defecto, no uno impuesto), y los guards del sitio (páginas generadas, «Why
  Quantum», jerga, enlaces). Los specs del banco de navegador se rehacen a la
  vez.

**Decidido el 2026-11-16 (D37)**: (a) un defecto visual que cambia NO es un
volteo con aviso: `classic` sigue existiendo y nada se retira, así que
`RD-2` no necesita un DEP; (b) sin maquetas elegidas antes del corte, el
2.0.0 se certifica con la página «qué cambia en 2.0» y la guía, sin tema
nuevo, y el rediseño llega como opción en una 2.x y es el defecto en el 2.1
(los puntos 4 y 5 del §4 quedan enmendados así); (c) las direcciones pueden
reabrir la marca (contra la recomendación): `RD-0` puede proponer una marca
nueva, y el brand board (`docs/brand/`) deja de ser el límite; (d) `RD-0`
arranca ya, en paralelo a las diez «sesiones cortas» del §2.2 («después de
lo pendiente» deja de aplicarse al carril); (e) AA también en el sitio del
paraguas: un control nuevo sobre `website/build` (hoy 0 instrumentos); (f)
el look del fleet en el `server` o en el build se mide primero (la
superficie de configuración del `server`), fuera del carril: no es sesión
hasta que esté medido.

### 3.5 La ruta de módulo `/v2` (medido por `M0-E` el 2026-10-18 y vuelto a medir por `M1-S0` el 2026-11-16)

Ningún aviso ni fila del §3.0 lo dice, y Go lo exige: **un tag `v2.0.0`
sobre un módulo con `go.mod` sólo se resuelve si la ruta del módulo lleva
el sufijo `/v2`** (semantic import versioning; sin él, el proxy y `go get`
lo rechazan, y `+incompatible` sólo vale para módulos sin `go.mod`). Así
que el primer commit del major de cada pilar renombra la ruta de TODOS sus
módulos (`github.com/jcsvwinston/quark/v2`, `…/quark/drivers/postgres/v2`…)
y reescribe cada import, y los consumidores (orbit de nucleus y quark; el
paraguas de los tres) cambian con ellos. Medido sobre el `main` del 2026-11-16
(pin de 1.45.0) por `M1-S0`, sobre `git ls-files`: las cifras son de ficheros
rastreados (la tabla de `M0-E` del 2026-10-18 decía 13/397/808/764,
17/479/1 020/115, 9/152/267/37, 151 y «21 scripts y páginas»; el 764 salía de
un `grep -r` sobre ficheros ignorados y no es reproducible):

| Repo | `go.mod` | ficheros `.go` que importan la ruta propia | líneas de import | otros ficheros rastreados que la nombran (sin `versioned_docs`/`node_modules`) |
|---|---:|---:|---:|---|
| quark | 13 | 408 | 800 (559 a la raíz) | 122 (2 577 líneas; 1 537 se regeneran: `acceptance/apisurface.json` y `allowlist.json`) |
| nucleus | 19 (`pkg/nucleustest/quarkmake` y `providers/tasks-asynq` nacieron después del 2026-10-18) | 495 | 1 073 (989 a la raíz) | 161 (3 705 líneas; 2 525 son el baseline de contratos; las 9 plantillas del starter que nombran la ruta de nucleus (11 contando las que sólo nombran quark/orbit) y los generadores incluidos) |
| orbit | 9 | 164 | 283 (14 a la raíz) | 54 (1 256 líneas; 931 son `CHANGELOG`s) |
| orbit → nucleus/quark | 20 `require` en 7 `go.mod` (10 raíces + 10 drivers) | 164 | 363 | 28 |
| nucleus → quark | 2 `require` (`pkg/nucleustest/quarkmake`) | 13 | 27 | 17 |
| paraguas | `go.work` con rutas relativas y 0 `replace`: no cambia (el workspace compila contra `/v2` sin `replace`) | — | — | 16 scripts, workflows y fixtures + 32 docs y páginas; 2 scripts más componen la ruta sin nombrarla |

Lo que implica, además del `sed`: los tags no cambian de forma (`v2.0.0`,
`drivers/postgres/v2.0.0`…: release-please usa el directorio, no la ruta de
módulo); `go install github.com/jcsvwinston/nucleus/cmd/nucleus/v2@v2.0.0`
(`cmd/nucleus` es módulo propio en lockstep por `release.yml`, ADR-038) y
`…/quark/cmd/quark/v2` (`cmd/quark` es paquete de release-please y necesita la
anotación `x-release-please-version` para requerir `quark/v2 v2.0.0` desde su
primer tag) cambian de ruta en toda la documentación y en el catálogo de
`nucleus add`; los `go.work` de cada repo (`make workspace`) y
`link_workspace.sh` de quark leen la ruta del `go.mod` y no se tocan;
`manifest-guard` §5, `align_set.sh` de orbit y `print-requires.sh` del
paraguas comparan rutas literales y necesitan el sufijo; los 24 módulos v0.x
de los 33 publicables (los cinco drivers de quark, 16 de nucleus, `proto`,
`agent` y `server` de orbit) no llegan a 2.0.0 con un `!`
(`bump-minor-pre-major`): el número lo pone el mecanismo que decida el
propietario (`M1-S0`, pregunta 1 = D26); las lanes `GOWORK=off` de cada repo
no están verdes hasta el tag o una pseudo-versión `v2.0.0-<ts>-<sha>`
fusionada, que es también lo que une los tres repos entre el primer commit y
el corte. Es trabajo mecánico de `M1`, pero de un tamaño que no cabe «dentro»
del PR que retira símbolos: va como el primer commit del major de cada repo,
con el workspace de cada uno probando que compila antes de cambiar nada más.
En el ensayo de `M0-E` NO se aplicó (las ramas `dry-run/2.0` conservan la ruta
v1 para que orbit compile contra ellas por `go.work`); queda medido aquí para
que `M1` lo presupueste.

## 4. Cuándo está terminado el 2.0

1. **Set Quantum 2.0.0 certificado** con quark, nucleus y orbit en v2.0.0, en
   lockstep (QADR-0002, QADR-0010), con `suite-integral --cierre` en verde.
2. **Todo el §3 ejecutado**, y ninguna marca viva que prometa algo para 2.0.0
   (el guard de deprecaciones los ve cumplidos).
3. **Guía de migración generada**, una entrada por cambio con su antes y
   después y la salida que ya existía en 1.x.
4. **Bancos y guards en verde** sobre el 2.0: ningún control ausente sin razón
   escrita, el banco de navegador en AA con el tema nuevo, el presupuesto del
   panel cumplido (enmendado por D37 b: sin maquetas antes del corte, el
   2.0.0 se certifica con la página «qué cambia en 2.0» y la guía; el tema
   nuevo llega como opción en una 2.x y es el defecto en el 2.1, y el AA
   «con el tema nuevo» se mide entonces).
5. **Documentación 2.0 publicada** con el rediseño, la página «qué cambia en
   2.0» y la guía de migración enlazada desde la portada (enmendado por D37
   b: sin maquetas antes del corte, el 2.0.0 se certifica con la página «qué
   cambia en 2.0» y la guía; el tema nuevo llega como opción en una 2.x y es
   el defecto en el 2.1).
6. **`R2` hecha**: el informe de madurez con todas las dimensiones a 5 salvo
   comunidad, o un A13 abierto con lo que falte. Con eso se cierran A12 y el
   plan 5 de 5.
7. Después, **quantum-app se rehace entero** sobre el 2.0 (decisión del
   2026-09-20).

## 5. Lo que NO entra

- **Nada aditivo**: lo que no rompe se publica en 1.x en cuanto está listo
  (OR-67, `WithAuthz()`, `CheckVersions()` y los arreglos de seguridad ya
  salieron así).
- **Nada sin aviso de 90 días**: un cambio que rompe y llega tarde a `M0` espera
  al 3.0 o entra moviendo la fecha del 2.0, por decisión de Carlos.
- **Ninguna funcionalidad nueva de producto** que no esté en este documento.
