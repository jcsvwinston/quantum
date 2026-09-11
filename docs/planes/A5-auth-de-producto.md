# A5 — Auth de producto

> Lee antes [`README.md`](README.md): el contrato de sesión, qué fichero manda
> para cada pregunta y qué no decide una sesión sola.

**Qué entrega.** Nucleus deja de tener sólo el *sustrato* de autenticación y
pasa a tener el *producto*: hoy hay sesiones, tokens, hash de contraseñas,
motor de políticas y dos costuras de extensión, y no hay una sola ruta que
inicie sesión a nadie. La dimensión más baja del pilar (auth/authz, 2 de 5)
sube copiando lo que Laravel Fortify/Sanctum, Django allauth, Spring Security
y el generador de Rails 8 ya resolvieron.

**Gate del arco** (se registra como guard cuando el pin lo contenga, igual que
los demás):

- el banco de conformidad de auth —`nucleus/internal/authbench`— con **cero
  controles ausentes** en las familias que el arco toca;
- la suite de conformidad corriendo contra un IdP real en CI (OIDC) y contra
  los cinco motores para lo que toca base de datos;
- baseline ASVS L2 congelado, con cada control atado a su requisito;
- Orbit muestra las sesiones por dispositivo.

**Hallazgos que descuenta.** Seis: NU-43 (P3, heredado: la costura federada
sin proveedores) y los cinco que abrió la medición de `S0` — **NU-68** y
**NU-69** (P2), **NU-70**, **NU-71** y **NU-72** (P3).

**La regla que lo condiciona.** [QADR-0010](../adr/QADR-0010-rupturas-agrupadas-en-un-major.md):
lo rompiente se acumula en un único major al cierre de A12. Aquí muerde en un
sitio concreto y conocido: `backend.User.Role` es un `string` y los proveedores
federados entregan listas. Se entrega `Roles []string` **junto** al campo
viejo, no en su lugar. Una sesión que no pueda avanzar por adición **para y lo
dice**.

---

## S0 · Medir antes de trocear

**Precondición**

```bash
bash scripts/check_audit_backlog.sh | tail -1   # ha de decir: arcos cerrados: A1 A2 A3 A4
```

**Qué produce.** El numerador del gate: un banco de controles de auth
ejecutable, con el veredicto de cada uno medido, no leído.

**Criterio de hecho**

```bash
cd nucleus && go test ./internal/authbench/ -run TestAuthBench -v
```

**HECHA el 2026-09-12** (nucleus#528). Lo que midió y lo que cambió del plan,
abajo.

### Lo que S0 midió

**14 de 43 controles presentes, 3 parciales, 26 ausentes.** El banco vive en
`nucleus/internal/authbench/` y su página es
[`nucleus/docs/auth-bench.md`](../../nucleus/docs/auth-bench.md). Cada probe
arranca una aplicación por defecto y pregunta a la ruta, llama a la API y
comprueba la respuesta, o lee el struct de configuración por su tag koanf.
`TestAuthBench` asserta el **veredicto registrado**, no el éxito: cerrar un
hueco pone la suite roja pidiendo que se actualice la cifra.

| familia | presentes | parciales | ausentes |
|---|---|---|---|
| sesiones | 3 | 2 | 1 |
| credenciales | 2 | 0 | 6 |
| segundo factor | 0 | 0 | 4 |
| claves de API | 1 | 0 | 5 |
| identidad federada | 1 | 0 | 3 |
| autorización | 3 | 0 | 2 |
| correo | 1 | 1 | 3 |
| tokens | 2 | 0 | 1 |
| postura | 1 | 0 | 1 |

**La forma del resultado es el hallazgo**: está el sustrato y no el producto.
Nada de lo que toca una persona existe — ninguna ruta inicia sesión, no hay
cuenta que verificar ni recuperar, no hay segundo factor, no hay clave con la
que llamar a una API.

Y una corrección a la propia hipótesis de partida, que conviene no olvidar:
**KEY-05 se escribió primero como «el limitador va por dirección»**, leído del
nombre de una clave de configuración. El probe que agota el presupuesto de una
identidad y luego pregunta como otra —mismo rol, misma dirección— sale servido:
el limitador va por **usuario autenticado**, con el tenant de prefijo. A4
aprendió que un comentario no es una medición; esto es la misma lección en su
otra forma. Lo que A5 se lleva de ahí: el middleware de clave de API tiene que
poner la identidad de la clave donde el limitador ya mira.

### Lo que cambió del plan

El entregable del artefacto («apikeys, oidc, accounts, permisos por objeto,
mail, ASVS») lista **productos**; los 26 huecos salen de **siete causas**, y
las sesiones van por causa:

1. **No hay superficie de cuentas.** Ocho controles (CRED-03…08, MFA-01…04)
   son el mismo agujero: el framework nunca sirvió una ruta de auth.
2. **Nada revoca** (SES-04, TOK-03) — y `ActiveSessions` ya enumera y el store
   ya borra, así que es API, no mecanismo.
3. **La identidad no tiene dónde poner los claims** (FED-04, NU-70).
4. **La costura federada no tiene implementación** (FED-02/03, NU-43).
5. **No hay credencial de máquina** (KEY-01…04, 06).
6. **El correo no sabe hacer un correo de producto** (MAIL-02…05, NU-71), y
   eso **precede** a verificación y reset, que sin él se pierden en el hueco
   entre el commit y el SMTP.
7. **El modelo de política es `sub, obj, act`** (AZ-03) y el `Context` del
   handler no ofrece nada (AZ-04), así que la propiedad de una fila se
   reimplementa en cada aplicación, donde nada la audita.

Dos consecuencias sobre el orden: el correo (6) sube a la primera sesión
porque bloquea a las cuentas, y el sustrato de identidad y revocación (2 y 3)
va antes que todo lo que lo consume. El segundo factor se parte en dos —TOTP y
WebAuthn son dos trabajos, no uno— y la postura ASVS cierra, porque mide lo
que las demás dejaron.

---

## S1 · Correo de producto

**Precondición**

```bash
cd nucleus && go test ./internal/authbench/ -run 'TestAuthBench/MAIL' -v
```

**Qué hace.** Cuerpo alternativo HTML/multipart, adjuntos, render por
plantilla, y envío por el outbox que ya existe, para que un correo encolado
sobreviva a una caída entre la base y el SMTP. Por adición: `Body` sigue
significando lo que significa.

**Criterio de hecho.** MAIL-02, MAIL-03, MAIL-04 y MAIL-05 en `present`.
Cierra NU-71.

## S2 · Identidad y revocación

**Precondición.** S1 no la bloquea; son ficheros distintos.

**Qué hace.** `Roles []string` junto a `Role` (QADR-0010, por adición);
`SessionManager.Revoke(token)` sobre el store, que ya sabe borrar; denylist de
`jti` con TTL para los tokens emitidos; y el agente de usuario en los metadatos
de sesión, que hoy guardan dirección y primera/última vez pero no desde qué.

**Criterio de hecho.** SES-04, SES-05 y TOK-03 en `present`. Cierra NU-69 y
NU-70.

## S3 · `accounts`: el módulo que sirve las rutas

**Precondición**

```bash
cd nucleus && go test ./internal/authbench/ -run 'TestAuthBench/(MAIL|SES-04)' -v
```

**Qué hace.** Módulo opt-in con el patrón ADR-022/023: registro con
verificación, login y logout sobre la cadena de backends, reset por token de
un solo uso, cambio de contraseña con reautenticación, enlace mágico y
**lockout progresivo**.

**Criterio de hecho.** CRED-03…08 en `present`. Cierra NU-68.

## S4 · Segundo factor: TOTP y recuperación

**Precondición.** S3 hecha (un segundo factor se enrola desde una cuenta).

**Qué hace.** TOTP con enrolamiento y verificación, códigos de recuperación de
un solo uso, y reautenticación (step-up) antes de una operación sensible.

**Criterio de hecho.** MFA-01, MFA-03 y MFA-04 en `present`.

## S5 · WebAuthn / passkeys

**Precondición.** S4 hecha (comparte el registro de factores).

**Criterio de hecho.** MFA-02 en `present`.

## S6 · `auth/apikeys`: la credencial de máquina

**Precondición.** S2 hecha: la clave autentica a una identidad, y esa
identidad es la que el limitador ya usa.

**Qué hace.** Emisión con hash y prefijo mostrable, mostrada una sola vez;
scopes proyectados sobre la política; middleware que reconoce `X-API-Key` y el
bearer no-JWT; rotación y revocación; `nucleus apikey create|list|revoke`.

**Criterio de hecho.** KEY-01…04 y KEY-06 en `present`.

## S7 · `providers/oidc`

**Precondición.** S2 hecha (los claims necesitan dónde aterrizar).

**Qué hace.** Proveedor federado propio sobre la costura que ya existe: code
flow con PKCE, discovery, JWKS, y mapeo de claims a roles. SAML va detrás, con
el mismo contrato.

**Criterio de hecho.** FED-02 en `present` y la conformidad corriendo contra un
IdP en CI. Cierra NU-43.

## S8 · Permisos por objeto

**Precondición.** Ninguna de las anteriores.

**Qué hace.** Modelo de política con atributos del recurso (el dueño de la
fila, el tenant) y los ayudantes de autorización en el `Context` del handler,
que hoy no expone ni la identidad.

**Criterio de hecho.** AZ-03 y AZ-04 en `present`.

## S9 · Postura ASVS L2

**Precondición.** S1…S8 hechas: mide lo que dejaron.

**Qué hace.** Ata cada línea del baseline congelado a su requisito ASVS L2,
con un test de conformidad por control, y decide los valores por defecto que
hoy salen apagados —empezando por `session_idle_timeout`—. Cambiar uno mueve
el baseline, que es donde se revisa.

**Criterio de hecho.** POS-02 y SES-06 en `present`. Cierra NU-72.

## S10 · Gate, guard y set

**Qué hace.** Registra el gate del arco como guard con su fixture, corre
`suite-integral.sh --cierre` y corta el set que lo publica, con
`scripts/train/README.md` delante.

**Criterio de hecho.** `bash scripts/check_audit_backlog.sh` con A5 en la
primera línea del registro.

---

## Registro de sesiones

Se rellena al terminar cada una: el PR que la cierra y lo que se midió.

| Sesión | Estado | PR | Qué midió o cambió del plan |
|---|---|---|---|
| S0 | **hecha** 2026-09-12 | nucleus#528, quantum#187 | 14/43 controles presentes, 3 parciales, 26 ausentes. Está el sustrato y no el producto. Los 26 huecos salen de SIETE causas, así que las sesiones van por causa: el correo sube a la primera porque bloquea a las cuentas, el segundo factor se parte en dos y la postura cierra. Y una hipótesis propia corregida: el limitador va por identidad, no por dirección |
| S1 | pendiente | — | — |
| S2 | pendiente | — | — |
| S3 | pendiente | — | — |
| S4 | pendiente | — | — |
| S5 | pendiente | — | — |
| S6 | pendiente | — | — |
| S7 | pendiente | — | — |
| S8 | pendiente | — | — |
| S9 | pendiente | — | — |
| S10 | pendiente | — | — |

### Lo que estas sesiones dejaron dicho, y no hay que redescubrir

- **Un nombre tampoco es una medición.** A4 aprendió que un comentario fósil
  engaña; `S0` de A5 estuvo a punto de publicar «el limitador va por
  dirección» leyendo el nombre de una clave de configuración. Un control que
  no se puede sondear no entra en el banco.
- **Medir la ausencia también se ejecuta.** Los 26 huecos no son greps vacíos:
  son 404 de una aplicación arrancada, un registro de proveedores vacío y un
  struct de configuración sin la clave. Un grep vacío dice que no encontró;
  un 404 dice lo que recibe quien lo usa.
