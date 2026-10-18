# Handoff archivado — sesión 2026-10-16 (A12 `M0-S0`, las decisiones D1…D8 y `M0-N`)

> Movido tal cual desde el §3 de `.claude/commands/next-session.md` el
> 2026-10-18, al entrar la sesión de `M0-O` (a) (el §3 lleva como mucho dos
> sesiones; `scripts/check_handoff_size.sh`). Historia para buscar con
> grep, no para cargar.

### Sesión 2026-10-16 — **A12 `M0-S0`: el major contado al pin de 1.41.0, y `M0` troceado en seis sesiones**

- **Arranque limpio**: `estado.sh` con el checkout en el pin, la lane
  semanal del 2026-10-12 verde, `main` de nucleus y orbit con un `chore`
  cada uno sin publicar, y 26 hallazgos abiertos, todos de A12 (P2=2,
  P3=24). Lo único fuera de sitio: los issues automáticos quantum#262 y
  quantum#263 (lanes del 2026-10-05) siguen abiertos aunque la corrida
  programada del 12/10 pasó — cerrarlos es de Carlos (§5).
- **Lo que midió, sobre el pin** (detalle en el plan de A12, sección «`M0`
  — inventario medido»): 12 marcas `// Deprecated:` a mano que el guard ve
  (quark 5 en 2 avisos, nucleus 7 en 3); **7 avisos de volteo que el guard
  NO ve** (nucleus 013…018, quark 003) porque sólo recorre marcas; nucleus
  DEP-2026-003 `active` SIN fecha; 9 volteos ya decididos sin aviso (6 de
  quark, 2 de nucleus, OR-57); orbit sin `docs/deprecations/`. Y cuatro
  cosas que el enunciado de `M0` daba por supuestas y no eran así: los
  «~14 sitios» de orbit son **2 llamadas** a `NewWrapResponseWriter` (y
  `authz.New`, que no tiene nada roto); el bus único **ya existe**
  (`signals.Bus` con la puerta tipada de A7 y la no tipada: sobra la
  segunda, no un paquete); **`pkg/model` sostiene el adaptador
  `datasource/nucleus` de orbit entero** (6 ficheros, 3 módulos) y no se
  retira en el 2.0 sin matarlo; y el sobre de errores **no tiene opción de
  quedarse** (hay `WithProblemDetails()`, no `WithErrorEnvelope()`).
- **Lo que escribió** (este PR): el troceado de `M0` —`M0-S0` → D1…D8 →
  `M0-Q` ∥ `M0-N` ∥ `M0-G` → `M0-O` → `M0-E`, cada una con precondición y
  criterio— en el plan de A12; el **§3.0 del contrato del 2.0**, la lista
  cerrada de 29 filas con el aviso de cada una y su estado (`publicado` /
  `en main` / `por escribir` / `decisión`), que es lo que `M0-G` enseña a
  leer al guard; el **bloque de decisión D1…D8** con recomendación (idle
  timeout 30m; fechar DEP-003 de nucleus; problem+json con
  `WithErrorEnvelope()` primero; deprecar sólo `NewWrapResponseWriter`;
  `pkg/model` a sustrato en el 2.0 y fuera en el 3.0; retirar la puerta sin
  tipo de `signals`; QK-50 y NU-110 entran); y la política de deprecación
  §1/§5/§6 remedidas al pin de 1.41.0. **QM-20 sigue abierto**: la prosa
  está, el guard lo cierra `M0-G`.
- **Lo siguiente**: `M0-Q` (los seis avisos de quark ya decididos) y
  `M0-G` (el guard) pueden arrancar sin esperar a nadie; `M0-N` espera el
  bloque D1…D8; `M0-O`, a la release de nucleus que traiga `M0-N`. El set
  del 2026-10-19 sale por cadencia con lo que esté fusionado; cada aviso
  que entre en él abre su ventana el 2027-01-17, y **la fecha del 2.0 la
  fija la última ventana que `M0` abra** (`M0-E` la escribe en el §1 del
  contrato).
- **La misma tarde**: quantum#284 y quantum#285 fusionados con el squash
  controlado (la pila con squash dejó #285 en conflicto: la sesión `M0-G`
  rebasó y empujó); quark#470 (`M0-Q`, DEP-2026-004…009) fusionado.
  **Carlos decidió D1…D8 una a una**: 30m; DEP-003 de nucleus fechado al
  2.0; problem+json con `WithErrorEnvelope()` antes; sólo
  `NewWrapResponseWriter`; **`pkg/model` se retira en el 2.0 y el adaptador
  `datasource/nucleus` de orbit con él** (fila 30 del §3.0, `DEP-2026-002`
  de orbit); la puerta sin tipo de `signals` fuera; QK-50 y NU-110 entran.
  El §3.0 queda con 18 filas `por escribir` y 0 `decisión`.
- **Y `M0-N`, hecha en esta misma sesión** (nucleus#630, fusionado): los
  nueve avisos de nucleus (003 fechado al 2.0; 019…026) con asistente y el
  test que pina v1, trece marcas `Deprecated`, `WithErrorEnvelope()`,
  `router.Wrap`, `Topic.String` y la pista al migrador en `authz.New`.
  **Dos correcciones al enunciado**: los topics tipados de ciclo de vida
  no se construyen (las señales las emite `pkg/model`, que D5 retira), y
  **casbin v2.135.0 ya rechaza una fila de política de 3 columnas al
  cargar** (DEP-003 describía filas inertes; el aviso dice lo medido). El
  `make check` de nucleus hay que mirarlo en su log: el primer intento paró
  en los guards por `configuration.md`, que es GENERADA desde
  `CONFIG_KEY_REGISTRY.md`, y la fase `test` no corrió. Las filas 4…9 y
  20…28 del §3.0 pasan a `en main`, y la 10 esa misma noche con quark#471
  (`M0-Q` (b): DEP-2026-010, QK-50; quark no tiene interruptor para la
  semántica de longitud en Oracle, la salida es `NLS_LENGTH_SEMANTICS=CHAR`
  del motor); el guard tolera el aviso sin fecha al pin también con la fila
  `en main`, porque el fichero nuevo aún no está al pin. **El PR de set del
  2026-10-19 debe pasar esas dieciséis filas a `publicado`** (si no,
  `umbrella-deprecations` se pone rojo al re-pinar).

