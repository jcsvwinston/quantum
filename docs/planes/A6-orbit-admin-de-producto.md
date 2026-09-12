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

**Hallazgos que descuenta.** Ocho: **OR-4** (P1, heredado) y los siete que
abrió la medición de `S0` — **NU-73** (P1, en nucleus), **OR-45** y **OR-46**
(P2), **OR-47**, **OR-48**, **OR-49** y **OR-50** (P3).

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

## S3 · El rastro deja de ser un buffer

**Precondición.** Ninguna.

**Qué produce.** La auditoría en la base, con retención declarable y export, y
con ella el historial de un registro (que es la misma tabla leída por fila).
Controles AUD-05, AUD-06, AUD-07 y DS-16.

**Criterio de hecho**

```bash
cd orbit && go test ./internal/adminbench/ -run 'TestAdminBench/(AUD-0[567]|DS-16)' -v
```

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
