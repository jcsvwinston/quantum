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
  del set que los lleve (si es el del 2026-10-19, hacia el 2027-01-17).
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
4. **Orbit migrado en una minor 1.x**: los ~14 usos que el major rompe
   (`authz.New`, `NewWrapResponseWriter`…), la lectura de errores sólo del
   sobre y su escape propio de `LIKE`. El 2.0 no puede romper el panel.
5. **`R1` hecha**: la re-auditoría completa sobre el último set 1.x. Lo
   rompiente que encuentre entra en el §3 (con su aviso); lo demás, en sets
   semanales.

## 3. Lo que entra en el 2.0

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

**Propuestos, entran salvo decisión en contra en `M0`**: NU-110 (SQLite guarda
las fechas en un formato que sus funciones de fecha entienden) y QK-50 (Oracle
cuenta `VARCHAR2` en caracteres). Los dos cambian datos o esquemas ya creados.

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
