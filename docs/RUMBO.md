# Rumbo — el roadmap VIVO del paraguas

Documento corto y honesto: qué es verdad hoy y qué frentes están abiertos.
No es un acta — las actas (ROADMAP de convergencia, cierres de ronda) viven en
[`ROADMAP.md`](ROADMAP.md) y [`auditoria/`](auditoria/). Los ids (SD-01,
RT-3, D1…) referencian los hallazgos y decisiones de la auditoría integral
del 2026-08-30 (dictámenes en [`auditoria/registro/`](auditoria/registro/)).

**Regla de mantenimiento:** este fichero se actualiza al cerrar cada arco (y
en el PR de re-pin de cada set, si el arco cambió lo que aquí se afirma). Un
frente cerrado se borra o se mueve a su acta; no se acumula prosa. Si la fecha
de abajo tiene más de un par de sets de antigüedad, desconfía y verifica.

## Estado real (2026-10-05)

- **Set certificado: Quantum 1.39.0** (2026-10-05) — quark v1.15.2 (con el
  CLI en v1.1.2 y los cinco drivers en v0.2.4) · nucleus v1.31.0 (doce
  módulos hermanos: drivers y exportadores v0.1.8, providers/ldap v0.2.12,
  los cuatro de nube v0.1.8) · orbit v1.18.1 (proto v0.8.0, datasource
  v1.0.0, ui v1.0.0, agent v0.15.1, server v0.20.1, quarkbridge v1.9.3,
  quarkdatasource v1.12.1). 1.39.0 CIERRA **A10** (Testing y OpenAPI de
  primera clase): once sesiones (nucleus#574…#586) llevaron el banco
  `nucleus/internal/apibench` de **12 a 46 de 46** — un kit de test que
  arranca la aplicación y la recorre por HTTP con sesión, datos y dobles; un
  documento OpenAPI derivado de las rutas, los structs y la seguridad, que
  la aplicación puede exigir y el test comprobar, con `nucleus openapi
  --check` contra una línea base; endpoints tipados; problem+json junto al
  sobre; `Provide`/`Resolve` y `DependsOn`; y un generador de cliente
  TypeScript propio. El gate corre en la lane `suite-starter` del CI de
  nucleus (obligatoria) y el guard `umbrella-api-posture` vigila lo
  publicado. El set publica además **QK-39 (P0)**, encontrado en A11 con el
  tren en marcha: desde la primera release, `DeleteBy`, `UpdateMap` y
  `UpdateFields` ignoraban la lógica de cada condición y
  `WhereNot(…).DeleteBy()` borraba las filas que excluía; quark v1.15.2 los
  pasa por el mismo renderizador que `List`, con una prueba de igualdad
  escritura=lectura en los seis motores. 1.38.0 cerró **A9** (Fleet
  unificado y una sola SPA, banco del fleet 50 de 50; OR-57 y OR-59 a A12).
  El detalle de cada arco cerrado, en su plan de [`planes/`](planes/README.md).
  **A11** (Extensibilidad y catálogo) y **A12** (Rendimiento, re-auditoría
  y cierre a 5) están EN CURSO desde el 2026-10-04, troceados por su `S0`
  de medición en
  [`planes/A11-extensibilidad-y-catalogo.md`](planes/A11-extensibilidad-y-catalogo.md)
  y [`planes/A12-rendimiento-reauditoria-cierre.md`](planes/A12-rendimiento-reauditoria-cierre.md);
  A12 tiene cuatro decisiones escritas como propuesta, pendientes de Carlos.
- 1.34.0 publicó el arco **A7** (jobs, eventos y tiempo real): una cola de
  trabajos DURABLE sobre la base de datos sin broker, un bus de eventos
  TIPADO con el outbox como transporte opcional, CANALES sobre WebSocket y
  SSE con relay entre réplicas, y `/livez` y `/readyz` separados. El banco
  `nucleus/internal/jobsbench` fue de **12 a 40 de 40**. El detalle en
  [`planes/A7-jobs-eventos-tiempo-real.md`](planes/A7-jobs-eventos-tiempo-real.md);
  lo que publicó cada set anterior —A6 y A5 incluidos— en
  [`../CHANGELOG.md`](../CHANGELOG.md).
  La fuente de verdad es [`versions.yaml`](../versions.yaml), siempre — y
  desde esta cabecera lo vigila `check_rumbo_estado.sh`. El troceado de cada
  arco en sesiones, y el contrato que permite trabajarlo sin recordar la
  anterior, están en [`planes/`](planes/README.md).
- **Certificación mecánica:** 55 guards en el registro — el 55º,
  `umbrella-why-quantum`, es el gate W1 de A11: cada cifra de la página «Why
  Quantum» contra su fuente al pin, ningún número sin fuente en su prosa, y
  la frase de `what-is-quantum.md` sobre lo que instala `nucleus add`
  (registrado sin esperar a un set: sus fuentes ya están en el pin de
  1.39.0); el 54º,
  `umbrella-api-posture`, es el gate de A10 (la cifra de
  `nucleus/docs/api-bench.md` y su tabla, el starter con el documento y los
  endpoints tipados, el test del gate y la lane que lo corre con node y
  `tsc`, y la línea base del documento del starter); el 53º,
  `umbrella-fleet-posture`, el de A9; y el 52º, `umbrella-quark-posture`, el
  de A8: comprueba en el árbol pinado que
  el banco de quark tiene sus 69 controles y ningún ausente sin nota, que la
  cifra que publica `quark/docs/enterprise-bench.md` es la que cuenta la
  tabla, y que las seis pruebas que el arco añadió a `SharedSuite` siguen
  corriendo en la lane de cada motor — lo único del arco que se mide contra
  un motor real. El 51º, `umbrella-jobs-posture`, es el gate de A7 (la cifra
  de `nucleus/docs/jobs-bench.md`, ningún ausente sin razón, y el CI de
  nucleus corriendo DE VERDAD la prueba de durabilidad). El set se certifica
  con `suite-integral --cierre` sobre el árbol pinado.
- **Auditoría de madurez 2026-09-03 sobre 1.26.0: ejecutada, corregida y
  PUBLICADA en 1.26.1.** Cuatro auditores midieron cada pilar contra el
  mercado (147 defectos, 4 P0, todos en la primera hora del evaluador). Los
  cinco PRs de corrección (quark#338, nucleus#455, orbit#380, orbit#379,
  quantum#136) están fusionados. Informe:
  <https://claude.ai/code/artifact/2ffd4e81-ae29-413c-ba01-555cef7ecedd>.
  Plan de trabajo a 5/5 (doce arcos, cada uno con gate mecánico):
  <https://claude.ai/code/artifact/cbd9d082-7404-4989-bd79-7408f9dbaf38>.
  El orden de los frentes de abajo se subordina a ese plan desde este set.
  La 8ª pasada fue la última auditoría manual completa; rige el régimen del §6.
- **Auditoría integral 2026-08-30 sobre 1.24.0: ejecutada y PUBLICADA.** 147
  hallazgos, 52 graves, 3 P0 — los tres en el embudo de entrada, no en el
  runtime. 20 PRs fusionados y el set 1.25.0 los lleva al público (verificado
  en el sitio construido al pin: 0 bloques de código vacíos donde había 56).
- **Las seis decisiones de rumbo D1–D6 están TOMADAS** (2026-08-31), y fijan
  el orden de trabajo de los frentes de abajo. D1 tiene ADR propio:
  [QADR-0008](adr/QADR-0008-cadencia-de-certificacion.md).

## Frentes abiertos, en orden de trabajo

Las decisiones D1–D6 de la auditoría quedaron tomadas el 2026-08-31; lo que
sigue es su traducción a trabajo. El orden importa: cada frente supone hecho
el anterior.

0. **Cadencia del tren (D1) — EN VIGOR y estrenada.** Arcos y sets se
   desacoplan: el set se certifica **semanalmente**, pegado a la corrida del
   lunes, o antes por hito con razón escrita
   ([QADR-0008](adr/QADR-0008-cadencia-de-certificacion.md)). El tren de
   1.25.0 fue el primero conducido con [`scripts/train/`](../scripts/train/) y
   `align_set.sh`; sus lecciones están en el runbook de esa carpeta. **El
   consumidor externo (quantum-app) se re-pina solo en cada corte** (D6): el
   anuncio abre su PR, que sigue necesitando revisión humana.
1. **Adelgazado del grafo (D3) — CERRADO Y PUBLICADO en Quantum 1.26.0.**

   | | Binario | Paquetes | Módulos |
   | --- | --- | --- | --- |
   | nucleus, antes | 75,6 MB | 1008 | 346 |
   | nucleus, publicado | **19 MB** | **349** | **87** |
   | quark, antes | 24 MB | 304 | 171 |
   | quark, publicado | **6 MB** | **159** | **129** |

   Objetivo: < 30 MB y < 150 módulos. Cumplido con margen en los dos. Salen a
   módulos propios los cuatro backends de nube (ADR-030), los cinco drivers de
   BD y los dos exportadores de telemetría (ADR-031), y en quark los cinco
   drivers más el listener de LISTEN/NOTIFY (ADR-0023). Desaparecen los build
   tags `mssql`/`oracle`. La configuración no cambia; `nucleus add <nombre>`
   escribe el import, y desde quark v1.10.0 el error guiado existe en los dos.

   **Deuda viva del arco, para no perderla:**
   - **Prometheus es el único cambio de comportamiento**: quien scrapea el
     `/metrics` por defecto lo pierde hasta añadir el módulo. Avisa al
     arrancar y sigue; si la clave estaba escrita a mano, para.
   - **nucleus y quark tienen ya escritor para los suelos de sus módulos**
     (`scripts/train/align-module-floors.sh`, QM-19, tren de 1.27.0), y corre
     al principio de cada corte como primer commit (decisión 2026-09-05): es
     un `fix(deps)` que corta un patch por módulo, así que va en un corte que
     sale igual, no en uno propio. Orbit sigue con `align_set.sh`.
   - `mattn/go-sqlite3` deja de clasificarse en el árbol de quark; quien lo use
     registra su clasificador con tres líneas (ADR-0023).

2. **API keys y luego accounts (D4).** `pkg/auth/apikeys`: emisión con
   hash+prefijo mostrable, scopes proyectados como sujeto/roles Casbin,
   middleware Bearer/X-API-Key, CLI (`apikey create/revoke/list`) y rate limit
   por clave — encaja con los registries de ADR-023 (PR-GAP-01). Después, el
   módulo opt-in `accounts` estilo ADR-022 (registro con verificación, reset
   por token de un solo uso, cambio de contraseña) sobre `pkg/mail` y las
   sesiones existentes (PR-GAP-02).
3. **Capa de datos bendecida (D5).** **Quark es la capa de datos de las apps
   de la suite**; `pkg/db`/`pkg/model` quedan como sustrato del framework. Los
   generadores se alinean: `nucleus generate module --data quark` emite modelo
   quark + registro en `quarkdatasource`, para que lo generado aparezca en el
   Data Studio de orbit sin pegamento (PR-COH-01). Incluye documentar el mapeo
   entre las dos gramáticas de tags.
4. **El fleet consume el contrato datasource (D2).** Orbit deja de ser
   bicéfalo: el Data Studio del plano fleet pasa a consumir el mismo
   `datasource.DataSource` que el in-process, de modo que RBAC por-modelo,
   filtrado de tenant y `quarkdatasource` valgan en ambos planos (AO-2, AO-3).
   El borrador está en orbit `docs/adrs/ADR-002`; esta decisión lo acepta en
   esa dirección — la alternativa (declarar el fleet «telemetría + lectura»)
   queda descartada.
5. ~~**quantum-app revive con bump automatizado (D6).**~~ **HECHO** y
   estrenado en el corte de 1.25.0. Queda abierta una pregunta que el bump
   destapó y que no decide un script: si el consumidor de referencia debe
   llevar además una suite in-process sobre `nucleustest`/`quarktest`, hoy
   clasificada como no cubierta. *Mecanizado*: la fase `cierre` del tren llama a
   [`scripts/train/dispatch-app-bump.sh`](../scripts/train/dispatch-app-bump.sh),
   que anuncia el set certificado a quantum-app; allí un workflow reescribe el
   pin, corre sus gates y abre un PR (nunca empuja a main).

## Deuda viva de la auditoría (no bloquea, no se olvida)

- **PR-ORB-02** — el audit log del panel in-process sigue siendo un ring en
  memoria: se evapora en cada deploy. La doc lo dice sin ambigüedad desde
  orbit#349; la persistencia en BD está sin hacer.
- **AO-4** — quedan tests del panel en postura sin-auth; orbit#353 movió los
  críticos (mutación/authz/tenant) a la postura con-auth.
- **95 hallazgos P2/P3** de la auditoría sin cerrar, priorizados en el informe.
  Los baratos van cayendo dentro de los arcos que tocan el mismo código.

## Qué NO está en duda

El diseño del paraguas se mantiene: go.work + submódulos + versions.yaml
(veredicto RT-12 de la auditoría — la simplificación está en el tren, no en el
workspace). «Coordina, no contiene» sigue vigente (QADR-0001).
