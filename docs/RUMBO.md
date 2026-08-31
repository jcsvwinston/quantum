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

## Estado real (2026-08-31)

- **Set certificado: Quantum 1.25.0** (2026-08-31) — quark v1.8.0 · nucleus
  v1.22.0 (providers/ldap v0.2.4) · orbit v1.8.14 (proto v0.4.2, agent v0.6.9,
  server v0.10.9, quarkbridge v0.4.9, quarkdatasource v0.2.18). La fuente de
  verdad es [`versions.yaml`](../versions.yaml), siempre.
- **Certificación mecánica:** 28 guards en el registro, lane semanal + modo
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
1. **Adelgazado del grafo (D3) — EN MARCHA.** Primer tramo hecho y fusionado
   (nucleus#407, ADR-030): S3, GCS, Azure y AWS Secrets Manager salen a
   módulos hermanos. **Medido: 75,6 → 42,0 MB · 346 → 176 módulos**, con una
   lane que asserta que el core no vuelve a enlazar un SDK de nube.
   Dos premisas del plan cayeron al medir: `asynq` ya no estaba en el grafo, y
   los 57 paquetes de AWS entraban por el gestor de secretos, no por storage.
   **Lo que falta para < 30 MB / < 150, medido y sin decidir:** el exportador
   OTLP arrastra gRPC+protobuf (**106 paquetes**) por `pkg/observe`, y los
   drivers de BD de `pkg/db` suman **42**. Ninguno estaba en el alcance.
   Aparte y sí aprobados: los **drivers de quark** por registro — frente
   distinto, reducen una app quark standalone, no el hola-mundo de nucleus.
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
