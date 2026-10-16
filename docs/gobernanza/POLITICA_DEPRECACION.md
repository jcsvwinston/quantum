# Política de deprecación de la suite

> **Estado: APROBADO el 2026-09-09, sin publicar todavía.** El propietario
> aprobó **D1, D2 y D3** tal como estaban propuestos. Es el documento que el
> §7.5 de [`POLITICA_SOPORTE.md`](POLITICA_SOPORTE.md) declara bloqueante para
> publicar S4, así que con esto S4 deja de estar bloqueado por su lado.
> Redactado el 2026-09-09 sobre el set vigente **Quantum 1.29.0**.
>
> Sin publicar quiere decir que todavía no está en el sitio (`website/`) ni
> enlazado desde ningún `SECURITY.md`; lo que ya está en vigor es el mecanismo,
> porque el guard del [§5](#5-la-forma-de-la-marca-y-qué-la-comprueba) entra en
> el registro con el próximo corte.
>
> Relacionados: [QADR-0002](../adr/QADR-0002-versionado-dos-niveles.md) (un
> major mueve los tres pilares a la vez),
> [QADR-0008](../adr/QADR-0008-cadencia-de-certificacion.md) (cadencia
> semanal), `nucleus/docs/governance/DEPRECATION_TEMPLATE.md` (el ciclo que
> esta política eleva a estándar de suite).

## 1. Qué hace hoy la suite, medido

Medido el 2026-09-09 sobre el pin de 1.29.0 (quark v1.12.0, nucleus v1.25.0,
orbit v1.9.3), y **vuelto a medir el 2026-10-16 sobre el pin de 1.41.0**
(quark v1.17.0, nucleus v1.32.0, orbit v1.19.3) por `M0-S0` de A12. Se
cuentan sólo las marcas escritas a mano: las del código generado —55 en
`orbit/proto/gen/…/admin.pb.go`, 1 en `quark/benchmarks/ent`— las escribe
protoc o ent y se reescriben solas en la siguiente generación.

| Producto | Marcas a mano (1.29.0 → 1.41.0) | Ciclo escrito | Registro de avisos (1.29.0 → 1.41.0) |
|---|---|---|---|
| nucleus | **0 → 7** (3 avisos: 009, 011, 012) | sí (`docs/governance/DEPRECATION_TEMPLATE.md`) | 8 → **17** avisos `DEP-2026-NNN` (9 `active`: 003 sin fecha, 009, 011…018; 013…018 son volteos sin marca) + especificaciones `MA-2026-NNN` |
| quark | **5 → 5** (2 avisos: 001, 002) | sí desde quark#373 (`docs/deprecations/README.md`) | 0 → **3** (001, 002 y 003, un volteo sin marca) |
| orbit | **0 → 0** | **no** (sin `docs/deprecations/`) | no |

Lo que decían los tres números en 1.29.0: el único producto con ciclo era el
único sin deprecaciones vivas, porque las llevó todas hasta `removed` antes
de su v1.0; los otros dos no tenían ciclo, y uno tenía cinco marcas sueltas.
Lo que dicen en 1.41.0: los dos productos con marcas tienen ciclo y aviso
por cada una (el guard del §5 lo exige), **siete avisos anuncian un cambio
de comportamiento sin marca que el guard no lee** (QM-20, lo cierra `M0-G`
de A12), uno de nucleus sigue `active` sin fecha (D2 del bloque de
`docs/planes/quantum-2.0.md`), y orbit sigue sin ciclo: su primer aviso
(OR-57) lo escribe `M0-O`.

### El defecto concreto que hay debajo

`quark/tenant_router.go:63` deprecia el alias `RowLevelSecurity` y dice que
«the alias is scheduled for removal in v1.0». **Quark va por v1.12.0.** La
promesa venció doce minors atrás, el símbolo sigue ahí, y nada en el CI de
ninguno de los cuatro repos lo miraba.

Las otras cuatro marcas —la forma anterior del registro de listeners, en
`quark/quarkdriver/listener.go`— no dicen cuándo se retiran. Eso no es un
descuido menor: una deprecación sin fecha no es una deprecación, es una
etiqueta. Nadie puede planificar contra ella y nadie tiene motivo para
quitarla, así que se queda.

### Y la práctica que sí existe, sin estar escrita

El arco D3 (2026-08-31) sacó del framework los backends de nube, los
exportadores y los drivers, y lo hizo **rompiendo en un minor con un error
guiado**, con la decisión tomada explícitamente y registrada en ADR-030 y
ADR-031 de nucleus. Ninguno de esos cambios pasó por una ventana de
deprecación.

Eso no contradice al §2 de abajo, pero sólo si se dice en qué se distinguen,
que es lo que hace el [§3](#3-qué-cuenta-como-superficie-estable).

## 2. La decisión

**El ciclo de nucleus es el ciclo de la suite.** Los tres productos usan la
misma forma, con el mismo vocabulario y los mismos artefactos:

1. un aviso `DEP-YYYY-NNN-<slug>.md` en `<repo>/docs/deprecations/`, con el
   estado (`proposed` → `active` → `completed` → `removed`), la fecha de
   anuncio, la versión más temprana de retirada y la guía de migración;
2. la marca `// Deprecated:` en el símbolo, con la forma del [§5](#5-la-forma-de-la-marca-y-qué-la-comprueba);
3. la entrada en el CHANGELOG del producto, que es lo que llega a las notas
   de release publicadas;
4. la fila en el índice de suite de este documento, que es lo único que se
   lee de un vistazo para saber qué queda vivo en los tres a la vez.

La numeración es **por repositorio**, no de suite: `DEP-2026-001` de quark y
`DEP-2026-001` de nucleus son avisos distintos. Es lo que ya hace nucleus y
lo que permite que quark siga siendo utilizable en solitario (regla dura 6
del arranque) sin heredar la contabilidad del paraguas.

## 3. Qué cuenta como superficie estable

S4 de la política de soporte dice que una superficie estable no se retira en
`v1.x`. Para que eso sea una regla y no un eslogan hace falta saber qué es
superficie estable, porque el arco D3 retiró cosas en minors a propósito.

**Es superficie estable, y va por deprecación con ventana:**

- un símbolo exportado de un paquete no experimental: función, tipo, método,
  campo, constante;
- una clave de configuración y sus valores aceptados;
- una bandera o un subcomando de un CLI;
- el nombre o el significado de una columna, una tabla o un evento del
  protocolo entre agente y servidor.

**No lo es, y puede moverse en un minor con error guiado:**

- **el empaquetado**: en qué módulo Go vive un símbolo, mientras el símbolo,
  su firma y su comportamiento no cambien. Es exactamente lo que hizo D3, y
  el compilador lo dice en el sitio y en el momento — con el error guiado que
  nombra el `go get` que falta;
- lo que un ADR del producto declare **experimental** por escrito antes de
  publicarse;
- lo que sólo se alcanza desde `internal/`.

La frontera está en quién se entera y cómo. Un cambio de empaquetado lo caza
el compilador en la primera compilación; retirar un símbolo o cambiar el
significado de una clave de configuración no lo caza nadie hasta producción.
Esa es la diferencia que la ventana paga.

**El caso que aún no está resuelto** es el de la clave de configuración con
default: el arco D3 lo tuvo con `metrics_path`, que dejó de servir métricas a
quien no añadiera el módulo del exportador, y el aviso al arrancar fue lo
único que lo dijo. Con el §2 escrito, ese cambio habría llevado aviso `DEP` y
ventana. Se anota aquí porque es el precedente que más cerca estuvo de
hacer daño en silencio.

## 4. Los tres números — BLOQUE QUE DECIDE EL PROPIETARIO

S4 ya fija la ventana (≥ 90 días naturales) y el sitio de la retirada (major).
Lo que queda son tres cifras operativas que S4 no toca.

<!-- INICIO BLOQUE DE DECISIÓN -->

| id | Qué fija | Propuesto | Decisión del propietario |
|---|---|---|---|
| **D1** | Versión que nombra la marca de godoc | La **v2.0.0** del producto: por S4 la retirada es de major, y por QADR-0002 el major de un producto es el major de la suite. La marca dice «la retirada cabe aquí», no «la retirada será tal semana» | **APROBADO** 2026-09-09 |
| **D2** | Qué pasa cuando la fecha se cumple y el major no llega | El guard **avisa** con los días vencidos y **no** rompe el CI. La deprecación pasa a `completed` en su aviso y espera al major en esa lista | **APROBADO** 2026-09-09 |
| **D3** | Retroactividad | Las cinco marcas vivas de quark se **re-fechan** al 2026-12-08 con aviso `DEP`, **sin retirar nada**. Ninguna se retira en `v1.x` | **APROBADO** 2026-09-09 |

<!-- FIN BLOQUE DE DECISIÓN -->

**Por qué D1 y no una minor concreta.** La cadencia medida es de un set por
semana y quark ha pasado de v1.4 a v1.12 en siete semanas. Nombrar «v1.15.0»
hoy es nombrar una versión que sale dentro de tres semanas: la nota vencería
antes que la ventana de 90 días que la justifica, y el guard se pondría rojo
por su propio diseño. La v2.0.0 es la única versión que no se mueve debajo de
la nota, y es además la que S4 exige.

**Por qué D2 avisa y no falla.** Es el mismo reparto que hace
`manifest-guard`: la contradicción con el mundo publicado —una nota que
promete una versión que ya salió— rompe, porque se arregla editando el
código; el trabajo pendiente —una ventana cumplida— avisa, porque no puede
secuestrar el CI de un cambio que no lo toca. El aviso lleva los días
vencidos, que es lo que hace que se note.

## 5. La forma de la marca, y qué la comprueba

Un párrafo de godoc, en inglés como todo lo de un repo de producto
(QADR-0009), con estas cuatro cosas:

```go
// Deprecated: use RowLevelSecurityClient. See DEP-2026-001. Scheduled for
// removal in v2.0.0, no earlier than 2026-12-08.
```

`scripts/check_deprecations.sh` recorre los tres submódulos **al pin** y exige,
para cada marca escrita a mano:

| Comprueba | Si falla |
|---|---|
| el párrafo abre con `Deprecated: ` | — (es la convención de Go: lo que leen `go doc`, los editores y staticcheck SA1019) |
| dice `Scheduled for removal in vX.Y.Z, no earlier than YYYY-MM-DD` | **FAIL** |
| esa `vX.Y.Z` es mayor que la versión que `versions.yaml` pina para ese repo | **FAIL** |
| cita un `DEP-YYYY-NNN` y el fichero existe en `<repo>/docs/deprecations/` | **FAIL** |
| la fecha no ha pasado | **AVISO**, con los días vencidos |

Queda fuera el código generado, detectado por la cabecera `Code generated …
DO NOT EDIT.` que la convención de Go pone antes de la cláusula `package`
— no en las tres primeras líneas, que es donde no está en la salida de
protoc-gen-go.

**Lo que el guard todavía no lee** (medido el 2026-10-16): un aviso que
anuncia un cambio de comportamiento, una negativa de configuración o un
movimiento de empaquetado no tiene marca de godoc —el símbolo se queda— y
el guard, que sólo recorre marcas, no lo ve: ni su fecha, ni su versión, ni
si está en la lista del major. `M0-G` de A12 le enseña a leer también
`<repo>/docs/deprecations/DEP-*.md` con `Status: active` y a cruzarlos con
la tabla del §3.0 de `docs/planes/quantum-2.0.md` (QM-20).

El guard tiene fixture en `tests/guard-fixtures/umbrella-deprecations/`, con
las dos roturas que importan: la nota sin cláusula y la nota que promete una
versión ya publicada.

**Registrado en `scripts/lib/guard-registry.sh` desde Quantum 1.30.0**, que es
el primer set cuyo pin de quark contiene las cinco marcas reescritas y su
`docs/deprecations/`. Antes de ese pin fallaba con razón, y por eso esperó
fuera del registro con su porqué escrito al lado.

## 6. Índice de deprecaciones vivas de la suite

Al 2026-10-16, sobre el pin de 1.41.0 (antes: 2026-09-09 sobre 1.29.0). Se
actualiza en el PR de set que publica un aviso nuevo o una retirada, y la
lista cerrada del major —con el estado de cada aviso, los que faltan por
escribir incluidos— vive en `docs/planes/quantum-2.0.md` §3.0.

| Aviso | Producto | Qué se deprecia o cambia | Recambio o salida | Estado | Retirada o cambio no antes de |
|---|---|---|---|---|---|
| `DEP-2026-003` | nucleus | la lectura de filas de política Casbin de 3 columnas | filas de 4 columnas | `active` **sin fecha** (contra el §2; D2 lo fecha o lo cierra) | — |
| `DEP-2026-009` | nucleus | `Context.HTML(code, html)`, que escribe una cadena cruda con el nombre del render de plantillas (NU-41) | `Context.RawHTML` (cadena) y `Context.Render` (plantilla) | `active` | 2027-01-04, retirada en v2.0.0 |
| `DEP-2026-011` | nucleus | `Context.Get` / `Context.Set`, el almacén por clave con aserción de tipo en cada lectura | `NewKey` + `SetValue` / `Value` (valores tipados); el mapa de `Render` o `BindData` para datos de plantilla | `active` | 2027-01-02, retirada en v2.0.0 |
| `DEP-2026-012` | nucleus | constructores que hacen panic con entrada mala: `auth.NewJWTManager`, `db.NewModuleMigrator`, `db.NewModuleFSMigrator`, `router.CSRFMiddleware` (NU-41) | `NewJWTManagerFromSecret`, `NewMigratorFromConfig`, `NewCSRFMiddleware`, que devuelven el error | `active` | 2027-01-02, retirada en v2.0.0 |
| `DEP-2026-013` | nucleus | **volteo**: storage declarado en una aplicación `WithoutDefaults()` sin `WithStorage()` deja de arrancar | `WithStorage()`, o quitar el bloque | `active` (sin marca) | 2027-01-02, en v2.0.0 |
| `DEP-2026-014` | nucleus | **volteo**: plugins externos fuera de la allowlist, denegados | la allowlist | `active` (sin marca) | 2027-01-02, en v2.0.0 |
| `DEP-2026-015` | nucleus | **volteo**: `mail_driver` sin `WithMail()`, deja de arrancar | `WithMail()` | `active` (sin marca) | 2027-01-02, en v2.0.0 |
| `DEP-2026-016` | nucleus | **volteo**: `rate_limit_*` sin `WithRateLimit()`, deja de arrancar | `WithRateLimit()` | `active` (sin marca) | 2027-01-02, en v2.0.0 |
| `DEP-2026-017` | nucleus | **volteo**: claves de authz y `Module.Policies` sin `WithAuthz()`, deja de arrancar | `WithAuthz()` | `active` (sin marca) | 2027-01-02, en v2.0.0 |
| `DEP-2026-018` | nucleus | **volteo**: `profiling_enabled` sin guarda, deja de arrancar | `WithAuthz()` | `active` (sin marca) | 2027-01-02, en v2.0.0 |
| `DEP-2026-001` | quark | `RowLevelSecurity` (alias de constante) | `RowLevelSecurityClient` | `active` | 2026-12-08, retirada en v2.0.0 |
| `DEP-2026-002` | quark | forma anterior del registro de listeners (4 símbolos) | `ListenerFactory` + `RegisterListenerFactory` | `active` | 2026-12-08, retirada en v2.0.0 |
| `DEP-2026-003` | quark | **volteo**: `UpdateBatch` comprueba la versión por defecto (QK-45) | `CheckVersions()` hoy; en el 2.0 es el defecto | `active` (sin marca) | 2027-01-04, en v2.0.0 |
| — | orbit | — | — | — | ninguna (OR-57 será su `DEP-2026-001`, en `M0-O`) |

Los dos avisos de retirada de quark los abrió quark#373, que trajo el
registro y reescribió las cinco marcas. El agrupamiento es por DECISIÓN y
no por símbolo: los cuatro símbolos del registro de listeners migran y se
retiran juntos, así que llevan un aviso y no cuatro. Los avisos de volteo
los lee hoy sólo quien abre el fichero: hasta `M0-G`, esta tabla y la del
§3.0 del contrato del 2.0 son lo único que los enumera.
