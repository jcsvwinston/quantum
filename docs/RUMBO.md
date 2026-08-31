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

- **Set certificado: Quantum 1.24.0** (2026-08-30) — quark v1.7.1 · nucleus
  v1.21.0 (providers/ldap v0.2.3) · orbit v1.8.13 (proto v0.4.2, agent v0.6.8,
  server v0.10.8, quarkbridge v0.4.8, quarkdatasource v0.2.17). La fuente de
  verdad es [`versions.yaml`](../versions.yaml), siempre.
- **Certificación mecánica:** 26 guards en el registro, lane semanal + modo
  `--cierre` ([`AUDITORIA_CONTINUA.md`](AUDITORIA_CONTINUA.md)). La 8ª pasada
  fue la última auditoría manual completa; rige el régimen del §6.
- **Auditoría integral 2026-08-30 sobre 1.24.0:** 147 hallazgos, 52 graves,
  3 P0 — los tres en el embudo de entrada, no en el runtime. **Ejecutada: 20
  PRs fusionados** en los cuatro repos (los 3 P0 cerrados y verificados).
- **Las seis decisiones de rumbo D1–D6 están TOMADAS** (2026-08-31), y fijan
  el orden de trabajo de los frentes de abajo. D1 tiene ADR propio:
  [QADR-0008](adr/QADR-0008-cadencia-de-certificacion.md).

## Frentes abiertos, en orden de trabajo

Las decisiones D1–D6 de la auditoría quedaron tomadas el 2026-08-31; lo que
sigue es su traducción a trabajo. El orden importa: cada frente supone hecho
el anterior.

0. **Cadencia del tren (D1) — DECIDIDO, en vigor.** Arcos y sets se
   desacoplan: el set se certifica **semanalmente**, pegado a la corrida del
   lunes, o antes por hito con razón escrita.
   [QADR-0008](adr/QADR-0008-cadencia-de-certificacion.md). La conducción va
   por [`scripts/train/`](../scripts/train/) (RT-1), no de memoria.
1. **Adelgazado del grafo (D3) — el arco SIGUIENTE.** Providers cloud
   (S3/GCS/Azure/minio) y el runtime asynq de nucleus salen a módulos propios
   con el patrón ya probado de `providers/ldap`; los drivers de quark pasan a
   registro por subpaquete con clasificación de errores enchufable. Es
   empaquetado, no API. **Objetivo medible: hello-world < 30 MB y < 150
   módulos** (hoy 79 MB / 347). Es la primera impresión de todo evaluador y
   hoy contradice el «stdlib-first» (AN-01, PR-DX-01, AQ-05).
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
5. **quantum-app revive con bump automatizado (D6).** El consumidor de
   referencia externo se re-pina en cada corte de set mediante
   `workflow_dispatch` alimentado por `scripts/print-requires.sh`, y sus gates
   corren contra el set nuevo. Con la cadencia de D1 es sostenible; archivarlo
   queda descartado (RT-5). *Mecanizado*: la fase `cierre` del tren llama a
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
