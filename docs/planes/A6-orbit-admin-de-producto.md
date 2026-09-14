# A6 — Orbit como admin de producto

> Lee antes [`README.md`](README.md): el contrato de sesión, qué fichero manda
> para cada pregunta y qué no decide una sesión sola.

**Qué entrega.** Orbit deja de ser *un panel de observabilidad con un CRUD
genérico encima* y pasa a ser el admin del producto: hoy un operador puede
mirarlo todo y administrar a nadie —no hay ruta que cree un operador, le
cambie la contraseña o lo desactive—, los permisos se paran en el borde del
modelo, y el rastro de auditoría se va con el proceso. Es el arco que lleva el
**único P1 heredado del registro** (OR-4) y el que hereda de A5 la pantalla de
sesiones por dispositivo, cuya capacidad ya existe en el framework
(`ActiveSessions`, `Revoke`, `RevokeWhere`, metadatos con agente de usuario).

**Gate del arco** (se registrará como guard `umbrella-admin-posture` con su
fixture; sería el 50º):

- el banco de admin —`orbit/internal/adminbench`— sin ningún control ausente
  **sin razón escrita**;
- OR-4 cerrado: un operador se crea, se gradúa y se revoca desde el panel;
- un instrumento que corra en un navegador para lo que el banco en Go no puede
  medir, en el CI de orbit;
- lo publicado y lo medido, comprobados el uno contra el otro (la página
  `orbit/docs/admin-bench.md` contra lo que cuentan los casos).

**Hallazgos que descuenta.** Ocho: **OR-4** (P1, heredado — **cerrado en
`S1`**, orbit#471) y los siete que abrió la medición de `S0`: **NU-73** (P1,
en nucleus; arreglado y esperando a que el pin de orbit lo traiga), **OR-45**
y **OR-46** (P2), **OR-47**, **OR-48**, **OR-49** y **OR-50** (P3).

**La regla que lo condiciona.**
[QADR-0010](../adr/QADR-0010-rupturas-agrupadas-en-un-major.md): lo rompiente
se acumula en un único major al cierre de A12. Aquí muerde en un sitio
concreto y conocido: **`datasource.Query` y `orbit.Config` son superficies
congeladas** (`contracts/freeze_test.go`). Un operador de filtro no puede
cambiar `Filters map[string]string`; se entrega **junto** a él, como campo
nuevo (`Where []Filter`), y el adaptador acepta los dos. Una sesión que no
pueda avanzar por adición **para y lo dice**.

**La trampa de este arco, dicha por adelantado.** NU-73 se arregla en
**nucleus**, y un arreglo de nucleus **no llega a orbit hasta que sube el pin**
(`require` en el `go.mod` de orbit). Si el PR de nucleus entra tarde, su
release no lo contiene y la mitad de orbit de `S6` no se puede verificar en el
mismo set. El PR de nucleus va **primero**, y la mitad de orbit **después de
que el tren corte nucleus**.

---

## S0 · Medir antes de trocear

**Precondición**

```bash
bash scripts/check_audit_backlog.sh | tail -1   # ha de decir: arcos cerrados: A1 A2 A3 A4 A5
```

**Qué produce.** El numerador del gate: un banco de controles del panel
ejecutable, con el veredicto de cada uno medido, no leído.

**Criterio de hecho**

```bash
cd orbit && go test ./internal/adminbench/ -run TestAdminBench -v
```

**HECHA el 2026-09-12** (orbit#467, quantum#189). Lo que midió y lo que cambió del plan,
abajo.

### Lo que S0 midió

**32 de 59 controles presentes, 9 parciales, 18 ausentes.** El banco vive en
`orbit/internal/adminbench/` y su página es
[`orbit/docs/admin-bench.md`](../../orbit/docs/admin-bench.md). Cada sonda
arranca una aplicación Nucleus con `orbit.Module(...)` montado, inicia sesión
como el admin de arranque y le pregunta al panel por su propia API HTTP.
`TestAdminBench` asserta el **veredicto registrado**, no el éxito.

| familia | presentes | parciales | ausentes |
|---|---|---|---|
| data studio | 9 | 4 | 4 |
| permisos | 4 | 1 | 4 |
| auditoría | 4 | 1 | 2 |
| operación | 10 | 3 | 4 |
| personalización | 3 | 0 | 4 |
| interfaz | 2 | 0 | 0 |

**La forma del resultado es el hallazgo**: el panel **navega y opera bien, y
administra mal**. Todo lo que un operador le hace a los *datos* está y se
ejerce (CRUD con validación de modelo, búsqueda, orden servidor, acciones en
lote, import, export, fixtures, confinamiento multi-tenant, y un panel montado
sobre un backend que no es el del framework). Todo lo que le hace a la
*aplicación* también, y eso es lo que ningún competidor de la comparación
tiene (feed en vivo, pulso de runtime, flags, migraciones, storage, exports
asíncronos). Todo lo que le hace a **otros operadores** falta entero.

Tres cosas que conviene retener: el vocabulario de política es
`(sujeto, modelo, acción)`, así que «este editor toca el título pero no el
precio» y «cada autor edita lo suyo» **no se pueden expresar**; lo que una
pantalla carga no lleva ninguna pista de capacidad, así que la UI sólo
descubre un permiso **siendo rechazada**; y el rastro de auditoría cubre todas
las superficies mutantes y **no sobrevive al proceso**.

**Cuatro defectos que la medición encontró y no son ausencias de plan** —
todos de arrancar la aplicación de verdad, ninguno visible desde un test
unitario del panel:

- **NU-73 (P1)**: el websocket del feed en vivo **revienta en cualquier panel
  montado**. El middleware de sesión del framework envuelve el
  `ResponseWriter` en `auth.flashSweepWriter`, que implementa `Flush` y
  `Unwrap` pero no `Hijack`: el upgrade no puede tomar la conexión y responde
  500. Los tests del panel lo cablean sin ese middleware, por eso pasan. El
  snapshot funciona; el stream no conecta nunca. **Y no es sólo de orbit**:
  ninguna aplicación de nucleus puede servir un websocket con el gestor de
  sesiones montado, que es el de por defecto.
- **OR-45 (P2)**: el paginador no tiene total. Toda lista responde
  `total: -1` con `is_estimated: true`, filtrada o no, con cinco filas en
  SQLite.
- **OR-46 (P2)**: la fila de sesión **nunca dice de quién es**. Lleva campo
  `user` y el panel no lo rellena, así que revocar desde el visor es a ciegas.
- **OR-47 (P3)**: la vista de migraciones responde 500 en una aplicación que
  no tiene directorio de migraciones.

Y uno de superficie, que además engañó a la propia medición: **OR-48 (P3)**,
el fallback de la SPA cubre `/api/*`, así que «no existe ese endpoint» llega
como `200 text/html` (y `405` en POST).

**Lo que la propia medición se equivocó, corregido en la misma sesión** (la
página del banco lo publica, porque el siguiente que añada una sonda tropieza
igual): cuatro lecturas del primer pase medían el banco y no el producto — el
fallback de la SPA, un helper de logs que **truncaba** el cuerpo que la sonda
examinaba, un operador compartido cuyos permisos se **acumulaban** entre
sondas, y un modelo del banco que declaraba una clave foránea **sin
declararla**. Tres de ellas se leían como defectos del panel y ninguna lo era.
A4 aprendió que un comentario no es una medición y A5 que un nombre tampoco;
A6 añade que **una sonda tampoco, hasta que se comprueba contra qué está
midiendo**.

**El troceado salió de la medición**: los 27 huecos (18 ausentes + 9
parciales) vienen de **nueve causas**, así que las sesiones van por causa. El
orden lo fija lo que bloquea a qué: los operadores primero, porque son el P1 y
porque los permisos por fila necesitan a alguien a quien pertenecer; el
arreglo de nucleus temprano, porque el pin manda.

---

## S1 · Operadores: personas, no políticas

**Precondición**

```bash
cd orbit && go test ./internal/adminbench/ -run TestAdminBench   # el banco existe y pasa
```

**Qué produce.** Las rutas que hoy no existen: crear un operador, listarlos,
darle y quitarle rol, cambiar su contraseña, desactivarlo. Con su modelo
gestionable en el panel y su auditoría. Cierra **OR-4** y los controles
PERM-02 y PERM-03.

**Criterio de hecho**

```bash
cd orbit && go test ./internal/adminbench/ -run 'TestAdminBench/PERM-0[23]' -v
```

**HECHA el 2026-09-13** (orbit#471). **OR-4 cerrado**; el banco pasa de 32 a
**34 de 59** y la familia de permisos de 4 presentes a 6.

### Lo que S1 entregó, y las dos decisiones que conviene no reabrir

- **Diez rutas bajo `/admin/api/admin-users`** —listar con roles, crear,
  editar, contraseña, desactivar/reactivar, rol, borrar— con **auditoría por
  ruta** (las ocho mutantes tienen su sonda en `audit_coverage_test.go`, que
  además asserta que la contraseña NO entra en el rastro) y una **pantalla
  Operators** en el panel que las gasta.
- **Desactivar ≠ borrar.** El proveedor re-lee la cuenta en CADA petición, así
  que un operador desactivado deja de serlo en su petición siguiente —sin
  perseguir su sesión— y la cuenta, con el nombre que llevan sus entradas de
  auditoría, se queda. Eso pidió columna: `is_active`, en el CREATE para
  bases nuevas y por un **ALTER idempotente** para las que ya existen, en los
  cinco dialectos, con test de que el operador existente no vuelve
  desactivado.
- **Dos negativas viven en el handler, no en la UI**, porque la UI no es el
  único cliente: no puedes desactivar, borrar ni degradar tu PROPIA cuenta, y
  nadie puede hacérselo al ÚLTIMO superusuario activo. Las dos contestan 409
  con la razón, y la pantalla enseña ese mensaje en vez de uno genérico.
- **Un panel cuya autenticación no es esta tabla contesta 501** (ADR-004): no
  se inventa un almacén de cuentas que la aplicación no pidió.
- **Las sondas miden por EFECTO**: la cuenta creada inicia sesión, la
  contraseña nueva funciona y la vieja no, la cuenta desactivada ya no entra.
  Un 200 del endpoint no habría probado ninguna de las tres.

## S2 · Permisos que llegan al campo y a la fila

**Precondición.** `S1` hecha (los permisos por fila necesitan un dueño que
exista).

**Qué produce.** El vocabulario de política crece **por adición**: permisos por
campo y un filtro por fila, y las pistas de capacidad en lo que una pantalla
carga, para que la UI pueda apagar lo que el operador no puede hacer en vez de
descubrirlo con un 403. Controles PERM-06, PERM-07 y PERM-09.

**Criterio de hecho**

```bash
cd orbit && go test ./internal/adminbench/ -run 'TestAdminBench/PERM-0[679]' -v
cd orbit && go test ./contracts/... -count=1     # las superficies congeladas siguen congeladas
```

**HECHA el 2026-09-13** (orbit#472). Los tres controles miden `present`: el
banco pasa de **34 a 37 de 59** y la familia de permisos queda **completa**
(9 presentes, 0 parciales, 0 ausentes) — la primera que lo está.

### Lo que S2 entregó, y las decisiones que conviene no reabrir

- **El objeto de una política admite dos formas más**, y el que no escribe
  ninguna se comporta igual que antes (dos tests lo fijan):
  `admin:Post` (el modelo, lo de siempre), `admin:Post#own` (el mismo verbo
  sobre las filas del operador) y `admin:Post.title` (un campo).
- **Por fila**: la lista se filtra, la fila ajena contesta **404** en los
  endpoints de registro —la misma respuesta que una que no existe, para no
  revelar el espacio de ids—, el create **estampa** al dueño y el update no
  puede entregar la fila a otro. Cubre list, retrieve, create, update,
  delete, export_csv y bulk_delete.
- **Qué columna dice de quién es una fila lo declara la aplicación**
  (`row_owner_fields`, con `"*"` como defecto; `row_owner_subject` elige
  entre username e id). Y **un `#own` que el panel no puede honrar se
  RECHAZA** con un 403 que dice por qué: una regla de propiedad que degrada
  en silencio a «todo» sería invisible, que es justo lo que este mecanismo
  existe para impedir.
- **Por campo, en las dos formas que un admin necesita**: `deny` nombra la
  excepción, y `read`/`create`/`update`/`write` nombran el conjunto permitido
  entero. La escritura prohibida es un **403 que NOMBRA el campo**, no un
  descarte silencioso —un formulario que cree haber guardado lo que no guardó
  es peor—, y el campo que no se puede leer sale del registro, de la lista,
  del CSV y del esquema.
- **Las pistas son ayuda de render, no la puerta**: `permissions`,
  `can_create/update/delete`, `row_scope` y `can_edit` por campo viajan en lo
  que la pantalla ya cargaba, la UI los gasta, y todo se vuelve a comprobar
  en la petición siguiente.
- **Adición al contrato congelado**: dos campos nuevos en `orbit.Config`
  (QADR-0010 lo permite: no se renombra ni se quita nada). La baseline se
  regeneró en el mismo PR y **ADR-007** de orbit registra la decisión, con lo
  que deliberadamente NO cubre: los verbos globales de export/import, los
  valores del propio rastro de auditoría y el feed en vivo.
- **El confinamiento por fila comparte mecanismo con el de tenant**
  (`columnScopeOwns`), incluida la parte difícil: un registro que no trae la
  columna se confirma contra el almacén.
- **Las sondas miden por efecto**, y en los dos sentidos: la de fila crea la
  propia **a través del panel** y la ajena como superusuario; la de campo
  **relee el valor** tras el 403 y comprueba que un campo permitido sigue
  siendo escribible; la de pistas contrasta cada pista con la respuesta que
  el panel da de verdad. Las dos familias de tests se verificaron **mutando
  el código que cubren**.

## S3 · El rastro deja de ser un buffer

**Precondición.** Ninguna.

**Qué produce.** La auditoría en la base, con retención declarable y export, y
con ella el historial de un registro (que es la misma tabla leída por fila).
Controles AUD-05, AUD-06, AUD-07 y DS-16.

**Criterio de hecho**

```bash
cd orbit && go test ./internal/adminbench/ -run 'TestAdminBench/(AUD-0[567]|DS-16)' -v
```

**HECHA el 2026-09-14** (orbit#473). Los cuatro controles miden `present`: el
banco pasa de **37 a 41 de 59** y la familia de auditoría queda **completa**
(7/7), la segunda que lo está.

### Lo que S3 entregó, y las decisiones que conviene no reabrir

- **El rastro vive en una tabla que el panel crea y posee**
  (`nucleus_admin_audit`), en la base contra la que ya autentica, y es el
  comportamiento **por defecto** cuando la aplicación tiene base. Un rastro
  que hay que encender es un rastro que nadie tiene el día que lo necesita, y
  el precedente ya existía: el panel crea `nucleus_admin_users` sin pedir
  permiso. `audit_store: memory` vuelve al anillo.
- **Degradar antes que no arrancar**: sin handle, o si la tabla no se puede
  crear, avisa y sigue con el anillo. Y **una escritura de auditoría nunca
  tumba la operación que documenta**: el INSERT que falla se registra y la
  entrada queda en un anillo pequeño, para que el rastro degradado se **vea**
  en vez de callar.
- **La retención es un PERÍODO** (`audit_retention_days`), que es lo que es
  una ventana de cumplimiento; `audit_max_size` es un recuento y acota sólo
  el anillo. Se aplica al montar y como mucho una vez por hora **en la ruta
  de escritura**: sin barredor en segundo plano que arrancar, parar o perder.
  Un operador puede cambiar la ventana en efecto desde el panel, y el payload
  dice a qué valor vuelve un reinicio (`configured_retention_days`), en vez
  de dejarle creer que el cambio es durable.
- **El export es un fichero** (`?format=csv`) con los filtros del listado, y
  **queda auditado** (`audit.export`): quién se llevó una copia del log es
  justo para lo que existe el log.
- **El historial de un registro es el mismo rastro leído por fila**, y lo
  gobierna el permiso del REGISTRO, no `audit_view` — así el alcance por fila
  y los permisos por campo de `S2` se aplican también ahí; si no, el
  historial sería el rodeo de los dos.
- **El panel dice lo que sirve** (`persistent`, `retention_days`), para que un
  hueco se lea como una ventana de retención y no como silencio.
- **La prosa que FUE verdad, corregida en el mismo PR**: la doc pública decía
  que el rastro «no se persiste». Era cierto cuando se escribió. Es la clase
  de hallazgo que ningún guard caza y que el §5 del handoff lleva anotada
  como vigilancia.
- **Adición al contrato congelado**: dos campos más en `orbit.Config`;
  baseline regenerada. **ADR-008** registra la decisión y su límite: la
  entrada se escribe DESPUÉS del cambio y en su propia transacción, así que
  un rastro transaccional sigue siendo cosa de la capa de datos (el
  `quark_audit` de Quark) — dicho en la doc, no supuesto.
- **Lo que encontró el propio arreglo**: CodeQL marcó dos asignaciones
  dimensionadas con un tamaño de página del cliente. Estaban acotadas tres
  funciones más allá, y al mirarlo apareció un defecto de verdad: **el export
  pedía páginas de 500 donde el listado capa a 200**, leía la página corta
  como la última y se paraba en el tope —en silencio, que es la peor forma de
  que un export de cumplimiento esté mal—. Tiene test que falla con la
  constante vieja.

## S4 · Formularios que sostienen una relación y un documento

**Precondición.** Ninguna.

**Qué produce.** El endpoint que resuelve a qué apunta una clave foránea (hoy
el esquema marca la clave y el formulario enseña un id crudo), edición anidada
e in-line, y los tipos que un formulario no puede hoy: documento JSON, fichero,
texto rico. Controles DS-10, DS-11 y DS-12.

**Criterio de hecho**

```bash
cd orbit && go test ./internal/adminbench/ -run 'TestAdminBench/DS-1[012]' -v
```

**HECHA el 2026-09-14** (orbit#474). Los tres controles miden `present`: el
banco pasa de **41 a 44 de 59**.

### Lo que S4 entregó, y las decisiones que conviene no reabrir

- **La relación se resuelve** con dos endpoints (`/options` de un modelo y de
  un campo), con `value` + `label` legible, por la misma maquinaria que una
  lista (búsqueda, tenant, alcance por fila). **El permiso es el del
  DESTINO**: quien puede editar el registro y no navegar el destino recibe
  403 y el formulario cae al id crudo — el panel no ensancha una concesión
  para dibujar un widget más bonito.
- **Los hijos viajan en el payload del padre.** Con id es edición, sin id es
  alta, y el que debe irse **lo dice**: la ausencia **nunca** borra (un
  formulario que cargó dos de cinco líneas borraría las tres que no enseñó).
  La clave al padre la estampa el panel, y los permisos del modelo HIJO se
  comprueban **antes** de escribir el padre — sin transacción, un rechazo
  descubierto después dejaría el padre guardado y un «prohibido» sobre el que
  nadie puede actuar.
- **No es transaccional y no se finge**: cada hijo se reporta por separado.
  Quien necesite todo-o-nada necesita antes un origen de datos transaccional,
  y la doc pública lo dice.
- **El vocabulario de widgets crece** (json, richtext, file, image): el
  documento se infiere del tipo; «esto es HTML» y «esto es una clave de
  storage» los declara la aplicación (`field_widgets`), como la columna de
  propiedad de A6 `S2`. Un campo de fichero guarda una CLAVE y hay ruta de
  subida que la produce (32 MB, sólo el nombre base, auditada).
- **Sin editor WYSIWYG**: el texto rico se edita como marcado — un editor que
  reescribe lo que no entiende es peor que un área de texto que no lo toca.
  Y la many-to-many pura sigue fuera (ADR-009).
- **Dos cosas que destapó el trabajo**: una sonda que casaba el substring
  «widget» en los NOMBRES de la config movió CUST-03 sin que nada cambiara
  (corregida, y escrita en la página del banco junto a las otras cuatro); y
  un update cuyo payload sólo trae hijos es un update legítimo — ahora
  escribe los hijos sin escribir, ni auditar, un cambio del padre que no
  ocurrió.

## S5 · Listas a las que se puede preguntar de verdad

**Precondición.** Ninguna, pero **lee QADR-0010 antes**: `datasource.Query`
está congelado y el operador de filtro entra como campo nuevo.

**Qué produce.** Filtros con operadores (rango, contiene, en, nulo), el total
que hoy no existe (**OR-45**) y las vistas guardadas. Controles DS-05, DS-04 y
DS-17.

**Criterio de hecho**

```bash
cd orbit && go test ./internal/adminbench/ -run 'TestAdminBench/DS-0[45]|TestAdminBench/DS-17' -v
cd orbit && go test ./contracts/... -count=1
```

**A MEDIAS el 2026-09-14, y la mitad que falta espera al pin.**

- **DS-17 HECHO** (orbit#475): las vistas guardadas existen — nombre, modelo y
  el query string que la rejilla enseñaba, en una tabla del panel. El banco
  pasa de **44 a 45 de 59**. Decisiones: la consulta se guarda como **texto**
  y no se valida contra el esquema de hoy (una vista es un atajo a una URL, y
  la que deja de tener sentido falla en el listado con el mensaje de ese
  endpoint); una vista es de quien la guarda y `is_shared` la hace visible;
  **no tiene permiso propio** — crearla exige el `list` del modelo al que
  apunta, y una vista de un modelo que el operador no puede listar **no se le
  enseña** (la fila revelaría el modelo y por qué filtra alguien).
- **DS-04 y DS-05 arreglados en NUCLEUS** (nucleus#545, fusionado):
  `QueryOpts` gana `Where []Filter` (doce operadores, con `ESCAPE` explícito
  en `LIKE` y un `IN` vacío que **no** casa nada) y `ExactTotal`, que cuenta
  las filas de la consulta — **OR-45 arreglado de raíz**. Las dos son
  adiciones y hay test de que quien no las usa se comporta igual.
- **Lo que falta, y por qué**: la mitad de orbit —traducir `campo__op=valor` a
  `Where`, pedir `ExactTotal` desde el listado y mover los veredictos de
  DS-04/DS-05— **no puede verificarse hasta que el `require` de orbit traiga
  una release de nucleus que lo contenga**. Es la misma dependencia de pin que
  **NU-73** lleva esperando. Quien suba ese pin cierra las dos cosas en el
  mismo PR.

## S6 · Sesiones, y el stream que no conecta

**Precondición.** La mitad de nucleus **primero**: NU-73 es un PR de nucleus y
no llega a orbit hasta que el tren corte nucleus y suba el pin. La mitad de
orbit empieza cuando `orbit/go.mod` requiere la versión que lo contiene.

**Qué produce.**

1. *(nucleus)* **HECHA el 2026-09-12** (nucleus#540): `flashSweepWriter`
   implementa `Hijack` delegando por `http.ResponseController` —que recorre la
   cadena de `Unwrap` y pasa por encima del envoltorio de scs, que tampoco lo
   implementa—, con dos tests que fallan sin el arreglo: el unitario por la
   aserción de tipo y el de contrato **a través de la pila por defecto**, que
   es lo que nadie cubría. Verificado de punta a punta en el workspace de la
   suite: con el arreglo, la sonda OPS-06 del banco abre el stream y recibe
   `stream.ready`. **El veredicto del banco sigue en `absent` a propósito**:
   no cambia hasta que el `require` de orbit traiga la release que lo
   contiene, que es la mitad de abajo.
2. *(orbit)* La fila de sesión dice de quién es (**OR-46**) y con qué
   dispositivo, y el panel gasta la revocación masiva que el framework ya
   tiene. Controles OPS-16, OPS-02, OPS-04 y OPS-06.

**Criterio de hecho**

```bash
cd nucleus && go test ./pkg/auth/ -run Hijack -v
cd orbit && go test ./internal/adminbench/ -run 'TestAdminBench/OPS-(02|04|06|16)' -v
```

## S7 · Acciones y puntos de extensión

**Precondición.** Ninguna.

**Qué produce.** Lo que una aplicación registra desde Go y el panel dibuja: una
acción por modelo («publicar estos tres») y un punto de extensión de UI.
Controles DS-09 y CUST-04.

**Criterio de hecho**

```bash
cd orbit && go test ./internal/adminbench/ -run 'TestAdminBench/(DS-09|CUST-04)' -v
```

## S8 · El panel con la ropa del producto

**Precondición.** `S7` hecha (los widgets de un panel se declaran por el mismo
sitio que las acciones).

**Qué produce.** Marca (logo, paleta, favicon), tablero con widgets
declarables, e idioma. Controles CUST-02, CUST-03 y CUST-05.

**Criterio de hecho**

```bash
cd orbit && go test ./internal/adminbench/ -run 'TestAdminBench/CUST-0[235]' -v
```

## S9 · Las vistas de operación que callan

**Precondición.** Ninguna.

**Qué produce.** Las tres vistas que hoy informan de su configuración en vez de
su estado, y el 404 que la SPA se come: la caché que se vacía es la que la
aplicación tiene (**OR-49**), el correo enseña entrega —cola, fallos, outbox—
y no driver (**OR-50**), las migraciones degradan a lista vacía (**OR-47**), y
`/api/*` responde 404 JSON cuando no hay ruta (**OR-48**). Controles OPS-11,
OPS-13 y OPS-17.

**Criterio de hecho**

```bash
cd orbit && go test ./internal/adminbench/ -run 'TestAdminBench/OPS-(11|13|17)' -v
```

## S10 · El instrumento del navegador

**Precondición.** Ninguna.

**Qué produce.** Lo que el banco en Go **no puede medir y por eso no mide**:
contraste, orden de foco, alcance de teclado, si un aviso se puede cerrar. Un
arnés que corre en un navegador en el CI de orbit, con su veredicto registrado
igual que el banco. La auditoría de 2026-09-03 midió 0 `aria-*` y contrastes
de 1,9–2,3:1 en la SPA in-process; esta sesión decide si eso sigue siendo
verdad **midiéndolo**, no leyéndolo.

**Criterio de hecho**: el arnés corre en el CI de orbit y su veredicto está
registrado.

## S11 · El gate, su guard y el set

**Precondición.** `S1`–`S10` hechas; el registro sin hallazgos abiertos de A6.

**Qué produce.** `scripts/check_admin_posture.sh` con su fixture registrado en
`guard-registry.sh` (el 50º), A6 en la primera línea de `registro.csv`, y el
set que lo publica.

**Criterio de hecho**

```bash
bash scripts/check_audit_backlog.sh | tail -1   # A6 entre los cerrados
bash scripts/guard-of-guards.sh
bash scripts/suite-integral.sh --cierre
```
