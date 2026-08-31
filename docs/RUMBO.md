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
  3 P0 — los tres en el embudo de entrada, no en el runtime. Dos olas de PRs
  en implementación; 6 decisiones de rumbo (D1–D6) pendientes de Carlos.

## Frentes abiertos

1. **El embudo de entrada** — donde se pierde al desarrollador que evalúa la
   suite. Los 3 P0: quickstart de nucleus publicado con los bloques de código
   vacíos (SD-01/GF-01), `nucleus generate module` genera una app que panica
   con nombres plurales (NC-01/GF-02), Data Studio sobre quark muestra «—» en
   todas las celdas del propio showcase certificado (PR-DS-01). Más la
   ausencia de historia de suite en el sitio (GF-05). En curso en las olas 1–2.
2. **Cohesión de producto** — dos Data Studio y dos modelos de auth entre el
   panel in-process y el fleet (AO-2, decisión D2), y dos capas de datos con
   gramáticas de tags incompatibles sin una «bendecida» (PR-COH-01, D5).
3. **Adelgazado del grafo** — providers cloud + asynq de nucleus a módulos
   propios (patrón providers/ldap ya probado), drivers de quark por registro.
   Objetivo medible: hello-world < 30 MB y < 150 módulos (AN-01, PR-DX-01,
   AQ-05; decisión D3).
4. **API keys y accounts** — el gap nº1 del caso API-first: API keys con
   scopes (PR-GAP-01) y módulo accounts opt-in (PR-GAP-02); decisión D4
   (recomendado: keys primero).
5. **Cadencia del tren** — el coste fijo del tren se paga casi por arco
   (RT-3/PR-REL-01, decisión D1: desacoplar arcos de sets), la conducción se
   está mecanizando en [`scripts/train/`](../scripts/train/) (RT-1), y
   quantum-app lleva 14 sets congelado: revivirlo o archivarlo (RT-5, D6).

## Qué NO está en duda

El diseño del paraguas se mantiene: go.work + submódulos + versions.yaml
(veredicto RT-12 de la auditoría — la simplificación está en el tren, no en el
workspace). «Coordina, no contiene» sigue vigente (QADR-0001).
