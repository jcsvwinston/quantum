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
orbit v1.9.3). Se cuentan sólo las marcas escritas a mano: las del código
generado —55 en `orbit/proto/gen/…/admin.pb.go`, 1 en `quark/benchmarks/ent`—
las escribe protoc o ent y se reescriben solas en la siguiente generación.

| Producto | Marcas `// Deprecated:` a mano | Ciclo escrito | Registro de avisos |
|---|---|---|---|
| nucleus | **0** | sí (`docs/governance/DEPRECATION_TEMPLATE.md`) | sí: 8 avisos `DEP-2026-NNN` + 9 especificaciones `MA-2026-NNN` |
| quark | **5** | no | no |
| orbit | **0** | no | no |

Los tres números de la primera columna dicen lo mismo desde tres sitios: el
único producto con ciclo es el único sin deprecaciones vivas, porque las
llevó todas hasta `removed` antes de su v1.0. Los otros dos no tienen ciclo,
y uno de ellos tiene cinco marcas sueltas.

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

El guard tiene fixture en `tests/guard-fixtures/umbrella-deprecations/`, con
las dos roturas que importan: la nota sin cláusula y la nota que promete una
versión ya publicada.

**No está registrado todavía en `scripts/lib/guard-registry.sh`.** Hoy
fallaría al pin, porque las cinco marcas de quark aún son las viejas. Se
registra en el PR de set que re-pine quark por encima del arreglo; la deuda
está escrita en `docs/handoff/deuda-registro-umbrella-deprecations.md`, junto
a la del guard `quark-action-pins`.

## 6. Índice de deprecaciones vivas de la suite

Al 2026-09-09, sobre el pin de 1.29.0. Se actualiza en el PR de set que
publica un aviso nuevo o una retirada.

| Aviso | Producto | Qué se deprecia | Recambio | Estado | Retirada no antes de |
|---|---|---|---|---|---|
| — | nucleus | — | — | — | ninguna viva: los 8 avisos de nucleus están en `removed` |
| `DEP-2026-001` | quark | `RowLevelSecurity` (alias de constante) | `RowLevelSecurityClient` | `active` | 2026-12-08, retirada en v2.0.0 |
| `DEP-2026-002` | quark | forma anterior del registro de listeners (4 símbolos) | `ListenerFactory` + `RegisterListenerFactory` | `active` | 2026-12-08, retirada en v2.0.0 |
| — | orbit | — | — | — | ninguna |

Los dos avisos de quark los abre quark#373, que trae el registro y reescribe
las cinco marcas. El agrupamiento es por DECISIÓN y no por símbolo: los
cuatro símbolos del registro de listeners migran y se retiran juntos, así que
llevan un aviso y no cuatro.

Un detalle que el aviso `DEP-2026-002` deja escrito y conviene no perder: los
registradores deprecados nombran `internal/guard.SQLGuard` en su firma, y la
regla `internal` de Go impide que nadie de fuera del repo los llame. O sea que
esa mitad deprecada **no tiene consumidor externo posible**, y su retirada en
v2.0.0 es más barata de lo que la nota deja entender.

## 7. Qué NO decide esta política

- **Cuándo hay un major de suite.** La retirada cabe en el próximo major;
  este documento no lo convoca ni lo fecha. QADR-0002 dice lo que cuesta.
- **La ventana**, que es S4 de la política de soporte (≥ 90 días) y se decide
  allí, no aquí.
- **El ciclo interno de nucleus**, que ya existe y no se toca: esta política
  lo eleva a estándar de suite y no lo reescribe.
- **Las deprecaciones de terceros** que aparecen en el grafo de dependencias.
  Eso es `govulncheck` y Dependabot, no esto.

## 8. Plan de adopción

1. **Este PR** deja el documento, el guard y su fixture; el guard todavía no
   se registra.
2. **PR en quark** (quark#373, hecho): `docs/deprecations/` con su README,
   los avisos `DEP-2026-001` y `DEP-2026-002` y las cinco marcas reescritas a
   la forma del §5. Sin retirar nada. Con esa rama, el guard sale **EXIT=0**;
   contra `main` sigue saliendo «5 de 5», que es lo que prueba que el verde es
   el cambio y no un pase vacío.
3. **PR de set** que re-pina quark por encima de (2): registra
   `umbrella-deprecations` en `scripts/lib/guard-registry.sh` y rellena las
   dos filas del §6.
4. **Orbit y nucleus** no necesitan PR: no tienen marcas a mano. Adoptan la
   forma cuando escriban la primera, y el guard la exigirá desde ese momento.
5. **Publicación**: este documento sale del borrador cuando el propietario
   apruebe el §4, a la vez que S4 de la política de soporte. Antes de eso no
   está en `website/` ni enlazado desde ningún `SECURITY.md`.
