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

## Estado real (2026-09-05)

- **Set certificado: Quantum 1.28.0** (2026-09-05) — quark v1.11.0
  (drivers/{postgres,mysql,sqlite,mssql,oracle} v0.1.2) · nucleus v1.24.0
  (doce módulos hermanos: cinco drivers, dos exportadores y cuatro providers
  en v0.1.2, providers/ldap v0.2.6) · orbit v1.9.2 (proto v0.4.4, agent
  v0.6.16, server v0.11.2, quarkbridge v1.8.20, quarkdatasource v1.8.21).
  1.28.0 publica el arco A1 (la deuda de la auditoría de madurez del
  2026-09-03 en los tres pilares); minor de suite por las minors de quark y
  nucleus. Siguiente arco: A2 (starter de suite).
  La fuente de verdad es [`versions.yaml`](../versions.yaml), siempre — y
  desde esta cabecera lo vigila `check_rumbo_estado.sh`.
- **Auditoría de madurez 2026-09-03 sobre 1.26.0: ejecutada, corregida y
  PUBLICADA en 1.26.1.** Cuatro auditores midieron cada pilar contra el
  mercado (147 defectos, 4 P0, todos en la primera hora del evaluador). Los
  cinco PRs de corrección (quark#338, nucleus#455, orbit#380, orbit#379,
  quantum#136) están fusionados. Informe:
  <https://claude.ai/code/artifact/2ffd4e81-ae29-413c-ba01-555cef7ecedd>.
  Plan de trabajo a 5/5 (doce arcos, cada uno con gate mecánico):
  <https://claude.ai/code/artifact/cbd9d082-7404-4989-bd79-7408f9dbaf38>.
  El orden de los frentes de abajo se subordina a ese plan desde este set.
- **Certificación mecánica:** 32 guards en el registro, lane semanal + modo
  `--cierre` ([`AUDITORIA_CONTINUA.md`](AUDITORIA_CONTINUA.md)). La 8ª pasada
  fue la última auditoría manual completa; rige el régimen del §6.
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
