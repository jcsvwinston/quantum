# Re-auditoría de madurez del 2026-10-23 sobre Quantum 1.42.0 (A12 `R1`)

Siete auditores en paralelo (quark, nucleus, orbit, orbit-fleet, orbit-ui,
suite y rendimiento), con el método de [`../README.md`](../README.md) y sus
prompts, sobre el paraguas con los submódulos al pin del set certificado
**Quantum 1.42.0** (2026-10-18): quark v1.17.0 `cda611bbb9845c238246b46f97987a1b6f3fc571`,
nucleus v1.33.0 `dff6f4db7e9f9bdd0115455e2f8efd943a49d90b`, orbit v1.20.1
`b2a3e040f4bff98631e4d758be9302f9eb2b1884`; paraguas en `339d4fe` (rama de
esta sesión). Los auditores corrieron el 2026-10-23; la revisión adversarial
—un revisor por informe, que no es su autor— el 2026-10-27 (§Método). Todo
lo que la revisión cambió está aplicado en los informes (§7 de cada uno) y
en el registro.

## Veredicto

Quantum 1.42.0 es, medido con los mismos instrumentos y la misma escala
que el 2026-09-03, otra suite: la media de las 36 dimensiones pasa de
**2,79 a 4,12** (de 2,84 a 4,21 sin la comunidad, que el propietario deja
fuera del objetivo), ninguna dimensión baja, veintinueve suben, y tres
alcanzan el 5 (Routing/HTTP y Jobs/Eventos de nucleus, Personalización del
panel de orbit). Los once arcos cerrados están en el pin y hacen lo que sus
planes dicen: los auditores lo comprobaron sesión a sesión ejecutando, no
leyendo (los cuatro bancos de quark, los cuatro de nucleus, el de admin con
sus 72 controles y su mitad de navegador, el del fleet con el clúster, el
del sitio, el de motores de quark frente a `database/sql` y pgx, las lanes
de PostgreSQL y MySQL con Docker, y el starter generado, arrancado y
recorrido como lo haría un usuario). Ningún hallazgo `hecho` de los 313 del
registro ha vuelto a abrirse (veintidós verificados al azar entre auditor y
revisor), y ninguno de los P0 del 2026-09-03 resiste a sus primos. Lo que la
re-auditoría encontró son **122 hallazgos nuevos: 0 P0, 4 P1, 24 P2 y
94 P3**, concentrados donde el 2.0 deja un solo camino (el panel de orbit
sobre `quarkdatasource`, que no valida ni clasifica, y que en una
aplicación multi-tenant pierde el confinamiento por el resolver y las
claves de import/export), en el fleet bajo mTLS (la flota de servidores no
se puede formar desde el binario), y en la deriva de cifras escritas a mano
que los guards no leen. Cuatro de ellos son volteos de comportamiento y
entran en la lista cerrada del major (§3.0 del contrato del 2.0, filas
31–34). El gate de A12 —5 en todo salvo comunidad— no se cumple: treinta
y dos dimensiones no llegan, y lo que les falta está en una línea cada una
más abajo.

## Notas

| Pilar | Dimensión | 2026-09-03 | 2026-10-23 | Dueño |
|---|---|---|---|---|
| quark | API/query | 4 | 4,5 | quark |
| quark | migraciones | 3 | 4 | quark |
| quark | tipos | 3 | 4 | quark |
| quark | rendimiento | 3 | 4 | rendimiento |
| quark | multi-tenant | 4 | 4 | quark |
| quark | observabilidad | 4 | 4 | quark |
| quark | testing | 4 | 4 | quark |
| quark | docs/DX | 2 | 3,5 | quark |
| quark | ecosistema | 2 | 4,5 | quark |
| nucleus | Routing/HTTP | 3 | 5 | nucleus |
| nucleus | Datos | 3 | 4 | nucleus |
| nucleus | Auth/Authz | 2 | 4,5 | nucleus |
| nucleus | Jobs/Eventos | 3 | 5 | nucleus |
| nucleus | Observabilidad | 4 | 4,5 | nucleus |
| nucleus | Seguridad | 4 | 4,5 | nucleus |
| nucleus | Testing | 3 | 4,5 | nucleus |
| nucleus | Docs/DX | 3 | 4,5 | nucleus |
| nucleus | CLI/generadores | 3 | 4,5 | nucleus |
| nucleus | Ecosistema/plugins | 2 | 4,5 | nucleus |
| orbit | Data Studio | 2,5 | 3,5 | orbit |
| orbit | RBAC/permisos | 2 | 4 | orbit |
| orbit | Telemetría/live feed | 3,5 | 4 | orbit |
| orbit | Audit | 1,5 | 4,5 | orbit |
| orbit | Fleet | 2,5 | 4,5 | orbit-fleet |
| orbit | Personalización/extensibilidad | 1,5 | 5 | orbit |
| orbit | UI/UX/a11y | 2 | 4 | orbit-ui |
| orbit | Seguridad | 3 | 4 | orbit |
| orbit | Testing | 3,5 | 4 | orbit |
| orbit | Docs/DX | 2,5 | 4 | orbit |
| suite | Embudo de entrada | 3 | 4,5 | suite |
| suite | Sitio / docs | 3 | 4,5 | suite |
| suite | Tren / releases | 3 | 3,5 | suite |
| suite | Gobernanza / seguridad de cadena | 2 | 4 | suite |
| suite | Coherencia entre pilares | 2 | 3,5 | suite |
| suite | Ecosistema / comunidad | 1 | 1 | suite |
| suite | Posicionamiento | 3 | 4 | suite |

Media por pilar (2026-09-03 → 2026-10-23): quark 3,22 → 4,06 · nucleus
3,00 → 4,55 · orbit 2,45 → 4,15 · suite 2,43 → 3,57 (4,00 sin comunidad).
Las 36 notas las confirmó la revisión adversarial re-corriendo el
instrumento de cada fila; ninguna se movió. `notas.csv` lleva las 36 con su
evidencia (el instrumento corrido y el porqué del informe del dueño), en el
formato que `umbrella-audit-criteria` valida. Dos reglas de la consolidación
se comprobaron y no cambiaron nada: ningún 5 tiene un P0 o P1 dentro
(Personalización, Routing y Jobs no tienen ninguno), y los criterios que el
auditor de rendimiento declara `no cumple` sólo tocan dimensiones que ya
estaban por debajo del 5 (Posicionamiento por los benchmarks de nucleus y
orbit; la parte de bundle del 5 de UI/UX/a11y `cumple`).

## Los P1, en una línea cada uno

- **OR-78** (orbit, Data Studio): sobre `quarkdatasource` —el adaptador del
  starter y el único que queda tras DEP-2026-002— el panel no valida ni
  clasifica: un requerido vacío entra con 201 (también desde la SPA, cuyo
  formulario envía `{}`), tipo y UNIQUE contestan 500 con el texto del
  motor, y la API del mismo starter contesta 422/409 para el mismo modelo.
- **OR-79** (orbit, Data Studio): en una aplicación multi-tenant el panel
  devuelve la clave física ya prefijada con el tenant y la vuelve a
  prefijar al leerla: import, `loaddata` y la descarga de exports no
  funcionan desde la SPA.
- **OR-80** (orbit, RBAC/permisos; va al major): el operador no está atado
  a un tenant: con `resolver: header`, un operador sin `tenant_switch` lee y
  escribe en otro tenant cambiando la cabecera (la revisión lo elevó de P2
  a P1 al demostrar la escritura).
- **OR-99** (orbit, Fleet): el binario `admin-server` no puede formar la
  flota de servidores bajo mTLS, la postura que su doc recomienda: ningún
  flag rellena `PeerTLS` y la malla sobre `https://` muere en el handshake
  (la revisión midió que con `PeerTLS` relleno in-process sí abre: es el
  cableado de `main.go`).

Los cuatro son `fix` de 1.x y no esperan a `R2`: van en el set siguiente,
antes del major (sesión `M0-R` del plan de A12).

## Lo que va al major (§3.0 del contrato del 2.0, filas 31–34)

Cuatro hallazgos piden cambiar un comportamiento por defecto: se escriben
como aviso `DEP` con su salida en 1.x y se voltean en el 2.0, como los
treinta anteriores. **QK-76**: las directivas desnudas de la gramática de
`pkg/model` en un tag `db` (`db:"pk"`, `db:"readonly"`) pasan de aviso a
`ErrInvalidTag` (hoy quark migra una columna llamada `pk`; es endurecer lo
que NU-50 dejó en aviso). **OR-80**: el operador queda atado a su tenant
(columna en la cuenta; sin `tenant_switch` no cruza, venga de `?tenant=` o
del resolver). **OR-93**: el entorno del proceso sale del snapshot bajo
`system_pulse` y pasa a un permiso propio. **OR-103**: `PeerService.Sync`
sólo acepta peers configurados en `--peers` (y bajo mTLS, el CN del
certificado ha de ser el `server_id` anunciado).

## El gate de A12: lo que falta para un 5, por dimensión

Treinta y dos dimensiones no están en 5 (comunidad queda fuera del gate).
Es la lista que `R2` convierte en A13 si sigue en pie.

- **quark · API/query (4,5)**: 60 de 60 tipadas (Q22/Q23, `GroupBy` sin
  `Select`, decidido al 2.0: QK-24); `Raw[T]` tipado; un caso LATERAL en el
  banco y en el builder (QK-79).
- **quark · migraciones (4)**: ficheros `.sql` embebidos desde un `Plan`
  (MIG-13) y un plan cuyo hash detecte el esquema cambiado al aplicar
  (MIG-05).
- **quark · tipos (4)**: un tipo decimal exacto (QK-71) y JSONB con
  operadores (TYP-08).
- **quark · rendimiento (4)**: InsertOne, FindByPK, List100 y Preload100
  dentro del 15 % de `database/sql` y pgx (PG-01…04, MY-01); COPY (QK-54);
  binders generados para UPDATE y batch (QK-84, QK-85 miden el hueco).
- **quark · multi-tenant (4)**: RLS nativa y su verificador en SQL Server y
  Oracle; sharding que componga con tenant (RLS-12); tenant en réplicas,
  sin medir.
- **quark · observabilidad (4)**: EXPLAIN opcional en el slow log, muestreo
  del detector de N+1, exemplars; OPS-10 partial.
- **quark · testing (4)**: `quarktest` para los seis motores (testcontainers
  opt-in), fixtures/factories y snapshot de esquema.
- **quark · docs/DX (3,5)**: playground de consultas; receta en el 100 % de
  los `Err*` (QK-78: 12 de 25 centinelas, ~17 % de los sitios); la deriva
  fuera de los guards (QK-73, QK-74, QK-77).
- **quark · ecosistema (4,5)**: la política de estabilidad del contrato
  aprobada por el propietario (publicada, pendiente de aprobación); drivers
  publicados que compilen su kit en `GOWORK=off` (suelo en el mismo corte:
  QK-72, NU-147).
- **nucleus · Datos (4)**: migraciones generadas desde modelos; `generate
  model|resource` y `nucleustest.Make` sobre quark en vez de `pkg/model`
  (NU-137; la DX al 5, prerrequisito de DEP-2026-024).
- **nucleus · Auth/Authz (4,5)**: WebAuthn (MFA-02) y el timeout de
  inactividad con valor de fábrica (NU-72, DEP-2026-021 en el 2.0).
- **nucleus · Observabilidad (4,5)**: pprof protegido en toda composición
  (en la plantilla `api` sirve `/debug/pprof` con una línea ERROR;
  DEP-2026-018 en el 2.0 o una guarda en 1.x).
- **nucleus · Seguridad (4,5)**: firma de cookies con keyring; rotación de
  secretos de base y storage (NU-67).
- **nucleus · Testing (4,5)**: factories sobre la capa de datos por defecto
  (`Make` sólo persiste por `pkg/model`).
- **nucleus · Docs/DX (4,5)**: cero deriva (NU-133, NU-135, NU-144).
- **nucleus · CLI/generadores (4,5)**: generadores con endpoints tipados y
  errores dentro del marco (NU-136, NU-145); `doctor`/`health`/`config
  print` que conozcan los providers que `main.go` importa (NU-132).
- **nucleus · Ecosistema/plugins (4,5)**: el catálogo fijado al set también
  para los productos de la suite (NU-143); NU-132.
- **orbit · Data Studio (3,5)**: el 3 entero sobre el camino que queda:
  validación por campo y clasificación de errores sobre `quarkdatasource`
  (OR-78), FK comprobada al escribir y al borrar (OR-82); después M2M y el
  vocabulario de 25 tipos de campo.
- **orbit · RBAC/permisos (4)**: `deny` creable desde el panel (OR-81),
  impersonación auditada, el operador atado a un tenant (OR-80).
- **orbit · Telemetría/live feed (4)**: retención configurable del anillo,
  EXPLAIN desde el feed, el feed confinado por tenant (OR-94).
- **orbit · Audit (4,5)**: el tenant en cada entrada (OR-74) y ninguna
  entrada por una mutación que no ocurrió (OR-83).
- **orbit · Fleet (4,5)**: la flota bajo mTLS desde el binario (OR-99) y su
  fallo visible (OR-100); alertas que se resuelven cuando el nodo se va
  (OR-101) y visibles en la SPA (OR-102); retención que no dependa de una UI
  suscrita (OR-108); lo relayado retenido en el peer (OR-113).
- **orbit · UI/UX/a11y (4)**: el ruleset WCAG 2.1 AA entero en CI sobre
  todas las rutas y los dos temas (OR-129), con OR-115/116/117/121
  arreglados; el estado de lista en la URL (OR-122); atajos; un solo sistema
  de tokens (OR-126).
- **orbit · Seguridad (4)**: lockout compartido entre réplicas, 2FA de
  operadores, el entorno fuera de `system_pulse` (OR-93), sesiones revocadas
  al cambiar la contraseña (OR-85).
- **orbit · Testing (4)**: una lane de motor para `internal/admin` y
  `quarkdatasource` (OR-84); la cobertura de la SPA publicada.
- **orbit · Docs/DX (4)**: guía por feature; DEP-2026-002 sin puntero roto
  y el quick-start enseñando el camino que queda (OR-89).
- **suite · Embudo de entrada (4,5)**: el camino frío medido en CI (QM-36)
  y las tres imprecisiones de la página (QM-30, QM-31).
- **suite · Sitio / docs (4,5)**: cero deriva (QM-29, QM-30, QM-31, QM-37).
- **suite · Tren / releases (3,5)**: un set en menos de 30 minutos sin
  paradas fuera del reloj (QM-23; 68–88 min conducidos hoy), `align_set` en
  los tres repos con las listas derivadas del árbol (QM-22, QM-40).
- **suite · Gobernanza / seguridad de cadena (4)**: Scorecard ≥ 8 (QM-33; el
  paraguas no publica su nota; Branch-Protection es del propietario); SLSA 3
  o decir el nivel (QM-34); la política de soporte publicada (QM-25);
  SECURITY con un canal que funcione (NU-149).
- **suite · Coherencia entre pilares (3,5)**: las cifras generadas de una
  fuente (QM-26, QM-27, QM-28, QM-29, OR-137).
- **suite · Posicionamiento (4)**: benchmarks públicos de nucleus y orbit
  (QM-39), Encore y Supabase en la comparativa (QM-38), la frase rancia
  sobre el objetivo del 15 % (QM-44).

## Lo que los criterios de rendimiento de A12 no cumplen

De la tabla de veredictos de `rendimiento.md`: InsertOne, FindByPK, List100,
Preload100 y FindByPK en MySQL por defecto quedan fuera del 15 % de la
decisión 1 (5 de 9 controles); el lote de 10 000 en PostgreSQL no está
«cerca de COPY» (1,09× `database/sql`, COPY 2,5–2,7× más rápido; QK-54); y
hello + `drivers/sqlite` pesa 26,2 MB (25,02 MiB) en el runner, por encima
del «≤ 25 MB» del criterio de `N1` en las dos unidades (NU-150: la lane
vigila un techo más laxo que el criterio y el plan decía «0,2 MB sobre»).
Cumplen: los lotes de 1000 (PG-05, MY-03), la caché de sentencias (MY-02:
−46…50 %), la cola SQL (0 % de claims vacíos y 3,2×/2,5× en el runner), la
parada en menos de 1 ms, los 92 módulos del hello, y el panel comprimido
dentro de presupuesto (374 de 400 KiB; `Content-Encoding` negociado).

## Lo que espera al propietario (se nombra, no es defecto del código)

Activar «private vulnerability reporting» en quantum, nucleus y orbit (está
apagado; NU-149 nombra el texto sin canal de respaldo); Discussions sigue
apagado en los cuatro (QM-42, decisión conocida); aprobar la política de
estabilidad del contrato de extensión de quark (A11 Q6) y el §8 de la
política de soporte (QM-25); la protección de rama, que es lo que más pesa
en el Scorecard (QM-33).

## Método

- El brief: [`../README.md`](../README.md) y `../prompts/`. Los siete
  auditores recibieron `comun.md` + su prompt + una nota de lanzamiento con
  lo operativo (set, commits, rutas, scratch, Docker con puertos aleatorios,
  `go.work`, qué está al pin y qué no), y corrieron en paralelo en un
  workflow de agentes; después, siete revisores adversariales
  (`adversarial.md`, uno por informe), y una sola consolidación (esta).
- **Prompts cambiados en este PR**: `orbit-ui.md` construye la SPA en una
  copia en el scratch y compara el `dist` con `diff -r` (siete auditores
  sobre el mismo árbol y `suite-integral` exige el árbol limpio); y
  `lanzamiento.md`, nuevo, la plantilla de la nota operativa, con la lección
  de esta corrida: **los entregables se copian a un sitio persistente**,
  porque el scratch y el `mktemp` de cada auditor se borran entre días.
- **Lo que pasó**: los auditores terminaron el 2026-10-23 (53 minutos, 3,8 M
  de tokens); los siete revisores de esa misma pasada cayeron por el límite
  de uso del modelo antes de escribir nada, y al reanudar el 2026-10-27 el
  scratch había desaparecido con los siete informes. Se recuperaron íntegros
  de las transcripciones (cuatro de las salidas persistidas de los `cat` de
  los revisores, tres de sus `Read`, cotejados byte a byte donde hubo las
  dos fuentes) y la revisión adversarial se relanzó sobre ellos con los
  resultados de los auditores cacheados. Los revisores re-ejecutaron los
  instrumentos sobre el mismo pin cuatro días después: nada se movió.
- **La escala**: antes de lanzar, R1 movió a `instrumento` los cuatro
  bancos que `R0` dejó en `notas` como «entra con el siguiente pin»
  (`quark/benchmarks/engines`, `quark/internal/extbench`,
  `nucleus/internal/catalogbench`, la familia `extension` de adminbench):
  35 dimensiones con instrumento en el árbol, 1 sólo con juicio.
- **Ids**: provisionales `<auditor>.<n>` → definitivos por el repo donde
  vive el defecto (QK-70…85, NU-132…151, OR-78…140, QM-22…44), en el orden
  de los informes y de P0 a P3; seis duplicados entre informes fundidos en
  el dueño de la dimensión (prosa en el otro); los dieciséis hallazgos de
  los revisores en la tabla del dueño, marcados «hallazgo de la revisión
  adversarial».
- **Efectos en el árbol**, restaurados por la consolidación: `orbit/go.work.sum`
  (lo toca cualquier `go` bajo el `go.work` de orbit: OR-138) y el binario
  `nucleus/cmd/nucleus/nucleus` que deja `check_modules_standalone.sh`
  (NU-140).

## Límites (los §6 de los siete informes, juntos)

- MariaDB, SQL Server, Oracle y el superapp de seis motores de quark; las
  lanes `storage-minio`, `providers-ldap`, `providers-saml`, `mssql`,
  `oracle`, `compatibility-harness`, `website-drift`, `suite-starter` y el
  fuzz de nucleus; MySQL/MariaDB, MSSQL y Oracle para el panel de orbit; las
  lanes de motor de Data Studio del fleet: no se corrieron en local. Valen
  por la corrida verde del CI al commit del pin, citada por id de run en
  cada informe (quark 38279269011, nucleus 39142538608, orbit 39146629723).
  PostgreSQL, MySQL y Redis sí se reprodujeron con Docker, paso a paso como
  `ci.yml`.
- Las cifras del runner del banco de motores del 2026-10-16 (EPYC 9V45)
  salen de un artefacto que caducó el 2026-10-26 (QK-83): la revisión no
  pudo recuperarlas; el registro de `cases_test.go` y la corrida verde al
  pin sí.
- Lo local no es la referencia de rendimiento: siete auditores y sus
  contenedores en la misma máquina; medianas de 3 (banco) y 5 (cola), con
  las corridas una a una en los informes.
- Docusaurus no arranca en este entorno: la doc de quark se midió en fuente
  y el snapshot por `diff`; el sitio del paraguas sí se construyó
  (`suite-integral`).
- Sin navegador para el panel desde nucleus (sólo `curl`); sin lector de
  pantalla (VoiceOver/NVDA) para la SPA; los `incomplete` de axe sólo en
  parte a mano.
- Las siete filas de quark del §3.0 (DEP-2026-004…010) están `en main` y
  no al pin: no se auditaron (estado registrado, no hallazgo).
- La comparación con el listón es con lo que cada auditor sabe de esos
  productos; ninguna documentación pública consultada, sin URLs.
- `timeout` no existe en macOS: envoltorios en perl en cada scratch; nada
  venció. `train.sh --dry-run` sólo hasta `preflight` (las fases de repo
  tocan los hermanos). El Scorecard del paraguas no produce JSON (QM-33).
- El canal de correo de alertas del fleet, el failover «< 2 s» y la quema de
  CPU los midió el auditor, no el revisor; la malla con `PeerTLS` relleno
  sólo in-process.

## Ficheros

`quark.md`, `nucleus.md`, `orbit.md`, `orbit-fleet.md`, `orbit-ui.md`,
`suite.md`, `rendimiento.md` (los informes, con ids definitivos y el §7 de
la consolidación), `adversarial.md` (las siete revisiones), `notas.csv`
(las 36 notas con evidencia) y este README. Los hallazgos están en
[`../madurez-2026-09-03/registro.csv`](../madurez-2026-09-03/registro.csv)
con `informe = reauditoria/2026-10-23/<auditor>.md` y `arco = A12`.
