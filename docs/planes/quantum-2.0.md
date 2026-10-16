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
  ninguna fila `por escribir` en el §3.0.
- **El orden lo decidió Carlos: primero se termina lo pendiente**, después el
  2.0. Nada de este documento se empieza antes de que se cumpla el §2.

## 2. Lo que tiene que estar hecho ANTES de empezar el 2.0

1. **A11 cerrado**: set 1.41.0 (cadencia del 2026-10-12) con `S-fin` (b).
2. **Lo pendiente de A12 cerrado**: el arreglo de seguridad del panel anotado
   en la memoria de la sesión del 2026-10-06; los hallazgos abiertos que no
   son del 2.0 (los «sesiones cortas» del registro: NU-127, NU-129, NU-131,
   OR-70, OR-71, OR-74, OR-75, OR-76, NU-108, QK-54, QK-68, QK-69); N1
   publicado (NU-106).
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
   quark.
5. **`R1` hecha**: la re-auditoría completa sobre el último set 1.x. Lo
   rompiente que encuentre entra en el §3 (con su aviso); lo demás, en sets
   semanales.
6. **La DX al 5** (§2.1), en 1.x: es aditiva, así que no espera al major.

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
> cierre del 2026-10-16: 12 filas `publicado`, **15 `en main`** (las seis de
> quark#470 y las nueve de nucleus#630, que el set del 2026-10-19 lleva al
> pin y su PR de set pasa a `publicado`), 3 `por escribir` (la 10, que
> espera a `M0-Q`, y la 29 y la 30, de `M0-O`) y 0 `decisión`.

| # | Producto | Qué cambia en el 2.0 | Tipo | Hallazgo | Aviso | Estado | Ventana abre | Sesión |
|---|---|---|---|---|---|---|---|---|
| 1 | quark | se retira el alias `RowLevelSecurity` | retirada (1 marca) | — | DEP-2026-001 | `publicado` | 2026-12-08 | — |
| 2 | quark | se retira el contrato viejo de listeners (`NewListenerFunc` y 3 más) | retirada (4 marcas) | QK-8 | DEP-2026-002 | `publicado` | 2026-12-08 | — |
| 3 | quark | `UpdateBatch` comprueba la versión por defecto | volteo | QK-45 | DEP-2026-003 | `publicado` | 2027-01-04 | — |
| 4 | quark | las demás escrituras de un modelo versionado entran en el bloqueo optimista | volteo | QK-58 | DEP-2026-004 | `en main` | — | `M0-Q` |
| 5 | quark | una escritura que no toca filas no dispara hooks, auditoría ni eventos | volteo | QK-46 | DEP-2026-005 | `en main` | — | `M0-Q` |
| 6 | quark | `Upsert` hace lo mismo en los seis motores (sin `updateCols`; con el duplicado en otra clave única) | volteo | QK-59, QK-65 | DEP-2026-006 | `en main` | — | `M0-Q` |
| 7 | quark | `ON DELETE SET DEFAULT` igual en los seis motores | volteo | QK-60 | DEP-2026-007 | `en main` | — | `M0-Q` |
| 8 | quark | `GroupBy` sin `Select` es un error | volteo | QK-24 | DEP-2026-008 | `en main` | — | `M0-Q` |
| 9 | quark | el `LIKE` plano declara `ESCAPE '\'` en todos los motores | volteo | QK-32 | DEP-2026-009 | `en main` | — | `M0-Q` |
| 10 | quark | Oracle cuenta `VARCHAR2` en caracteres | volteo (esquema) | QK-50 | DEP-2026-010 | `por escribir` | — | `M0-Q` |
| 11 | nucleus | se retira `Context.HTML` con cadena cruda | retirada (1 marca) | NU-41 | DEP-2026-009 | `publicado` | 2027-01-04 | — |
| 12 | nucleus | se retiran `Context.Get`/`Set` sin tipo (`router.Context.Set` se promociona con la misma firma: hay que mirar las dos) | retirada (2 marcas) | — | DEP-2026-011 | `publicado` | 2027-01-02 | — |
| 13 | nucleus | se retiran los constructores que paniquean (`NewJWTManager`, `NewModuleMigrator`, `NewModuleFSMigrator`, `CSRFMiddleware`) | retirada (4 marcas) | NU-41 | DEP-2026-012 | `publicado` | 2027-01-02 | — |
| 14 | nucleus | storage declarado sin `WithStorage()` en `WithoutDefaults()` deja de arrancar | negativa | NU-99 | DEP-2026-013 | `publicado` | 2027-01-02 | — |
| 15 | nucleus | plugins externos fuera de la allowlist, denegados | negativa | — | DEP-2026-014 | `publicado` | 2027-01-02 | — |
| 16 | nucleus | `mail_driver` sin `WithMail()`, deja de arrancar | negativa | — | DEP-2026-015 | `publicado` | 2027-01-02 | — |
| 17 | nucleus | `rate_limit_*` sin `WithRateLimit()`, deja de arrancar | negativa | — | DEP-2026-016 | `publicado` | 2027-01-02 | — |
| 18 | nucleus | claves de authz y `Module.Policies` sin `WithAuthz()`, deja de arrancar | negativa | — | DEP-2026-017 | `publicado` | 2027-01-02 | — |
| 19 | nucleus | `profiling_enabled` sin guarda, deja de arrancar | negativa | — | DEP-2026-018 | `publicado` | 2027-01-02 | — |
| 20 | nucleus | las filas de política de 3 columnas dejan de leerse (hoy `active` SIN fecha, contra la política §2) | retirada | — | DEP-2026-003 | `en main` | — | `M0-N` |
| 21 | nucleus | `nucleustest` deja de enlazar SQLite siempre | volteo (empaquetado de test) | NU-121 | DEP-2026-019 | `en main` | — | `M0-N` |
| 22 | nucleus | el proveedor asynq sale a `providers/tasks-asynq` (decisión 4 de A12) | empaquetado | — | DEP-2026-020 | `en main` | — | `M0-N` |
| 23 | nucleus | `session_idle_timeout` con valor de fábrica | volteo (config) | NU-72 | DEP-2026-021 | `en main` | — | `M0-N` |
| 24 | nucleus | los errores salen en problem+json por defecto; `WithErrorEnvelope()` para quedarse | volteo | — | DEP-2026-022 | `en main` | — | `M0-N` |
| 25 | nucleus | se retira `NewWrapResponseWriter(w, _ int)`; `router.Wrap(w)` desde 1.x | retirada (1 marca) | NU-41 | DEP-2026-023 | `en main` | — | `M0-N` |
| 26 | nucleus | se retira `pkg/model` como capa de datos pública (48 símbolos); los generadores, el starter, `nucleustest` y la doc pasan a quark en 1.x (la DX al 5) y `pkg/app`/`pkg/nucleus` dejan de exponerlo | retirada (paquete) | — | DEP-2026-024 | `en main` | — | `M0-N` |
| 27 | nucleus | se retira la puerta sin tipo de `signals` (`Signal`, `Event`, `Handler`, `Bus.On/Emit/EmitAsync`); las señales de ciclo de vida como topics tipados desde 1.x | retirada (marcas) | — | DEP-2026-025 | `en main` | — | `M0-N` |
| 28 | nucleus | SQLite guarda las fechas en un formato que `date()` entiende | volteo (datos) | NU-110 | DEP-2026-026 | `en main` | — | `M0-N` |
| 29 | orbit | la identidad del nodo del fleet atada al certificado cuando hay mTLS; `AllowSharedAgentCertificate` para quedarse | volteo (config) | OR-57 | DEP-2026-001 (orbit) | `por escribir` | — | `M0-O` |
| 30 | orbit | se retira el adaptador `datasource/nucleus` (el panel sobre modelos de `pkg/model`): el panel se monta sólo sobre `quarkdatasource` (D5b) | retirada (paquete) | — | DEP-2026-002 (orbit) | `por escribir` | — | `M0-O` |

Lo que esta tabla deja fuera a propósito: la migración de orbit (§2.4, es
trabajo de 1.x, no un cambio del 2.0), la DX al 5 (§2.1, aditiva) y el
rediseño (§3.4, que llega como opción en una minor y se vuelve el defecto
en el 2.0 sin retirar nada). Los ids `DEP-2026-010` y `019…026` de arriba
y el `DEP-2026-002` de orbit son los siguientes libres de cada repo al 2026-10-16; si una decisión se
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
| **D6** | los buses que se solapan | **Retirar la puerta sin tipo de `signals`** (`Signal`, `Event{Payload any}`, `Handler`, `Bus.On/Emit/EmitAsync`) y quedarse con `signals.Bus` y la API tipada que A7 entregó; las señales de ciclo de vida (`PostSave`…) se publican como topics tipados en 1.x. `observability.Bus` no se toca: es el fan-out de observabilidad, no un bus de dominio. Orbit guarda un `*signals.Bus` en el adaptador y en el panel; `M0-O` migra lo que use la puerta vieja | **La puerta sin tipo** (2026-10-16): se retiran `Signal`, `Event`, `Handler`, `Bus.On/Emit/EmitAsync`; `observability.Bus` no se toca. |
| **D7** | QK-50: Oracle cuenta `VARCHAR2` en caracteres | **Entra** (ya estaba propuesto): cambia el DDL que genera el plan en Oracle, no los datos; una tabla existente conserva su semántica de bytes hasta que una migración la toque, y el aviso lo dice | **Entra** (2026-10-16). |
| **D8** | NU-110: SQLite guarda las fechas en un formato que sus funciones de fecha entienden | **Entra** (ya estaba propuesto), con la lectura de las dos formas en el 2.0 y una migración de datos opcional documentada: cambia lo que hay escrito en bases existentes, y es el único de la lista que lo hace | **Entra, leyendo las dos formas** (2026-10-16), con la migración de datos opcional documentada. |

<!-- FIN BLOQUE DE DECISIÓN M0 -->

**Decididos ya, sin aviso todavía** (los escribe `M0-Q`/`M0-N`, sin
esperar al bloque): QK-58, QK-46, QK-59+QK-65, QK-60, QK-24 y QK-32 en
quark; NU-121 y asynq a módulo propio en nucleus; OR-57 en orbit (que
además estrena `docs/deprecations/`).

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

## 4. Cuándo está terminado el 2.0

1. **Set Quantum 2.0.0 certificado** con quark, nucleus y orbit en v2.0.0, en
   lockstep (QADR-0002, QADR-0010), con `suite-integral --cierre` en verde.
2. **Todo el §3 ejecutado**, y ninguna marca viva que prometa algo para 2.0.0
   (el guard de deprecaciones los ve cumplidos).
3. **Guía de migración generada**, una entrada por cambio con su antes y
   después y la salida que ya existía en 1.x.
4. **Bancos y guards en verde** sobre el 2.0: ningún control ausente sin razón
   escrita, el banco de navegador en AA con el tema nuevo, el presupuesto del
   panel cumplido.
5. **Documentación 2.0 publicada** con el rediseño, la página «qué cambia en
   2.0» y la guía de migración enlazada desde la portada.
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
