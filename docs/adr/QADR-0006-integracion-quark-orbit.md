---
id: QADR-0006
title: Integración Quark↔Orbit — feed SQL en tiempo real y Data Studio sobre Quark
status: accepted
date: 2026-07-01
deciders: jcsvwinston
related: [QADR-0005]
supersedes: null
tags: [integracion, observabilidad, quark, orbit]
---

# QADR-0006 — Integración Quark↔Orbit (feed SQL en tiempo real y Data Studio)

## Contexto

Quark es autónomo: ni Nucleus ni Orbit lo importan ([QADR-0001](QADR-0001-multirepo-paraguas.md),
[QADR-0005](QADR-0005-secuenciacion-convergencia.md)). Para que la suite "funcione
como una", sin convertir a Quark en dependencia del framework, se acota una
integración mínima con dos objetivos:

1. **Indicar** que una app Nucleus usa Quark como ORM.
2. **Cablear** el Data Studio y la visualización en tiempo real de las sentencias
   SQL que ejecuta Quark, vía suscripción u OTel.

Hechos verificados (trío al día):

- **Quark ya emite por sentencia.** `WithQueryObserver(QueryObserver)` con
  `ObserveQuery(QueryEvent)`; `notifyObservers` dispara en **cada** operación
  (incluidos SELECT/List/Row). `QueryEvent{SQL, Args, Duration, Rows, Error,
  Table, Operation}` (`quark/option.go:310-325`). Quark tiene además una interfaz
  `Middleware` (`WrapExec/WrapQuery/WrapQueryRow`) que **sí recibe `ctx`**, y un
  paquete `quark/otel/` (span por query con `db.statement`, redacción de args por
  defecto).
- **Orbit consume el bus de Nucleus en modo suscripción.** El feed live drena
  `nucleus.EventBus.SubscribeSQL()` → `nucleus.SQLEvent{NodeID, EmittedAt,
  ModelName, Operation, Query, Args, Duration, Err, RequestID, TraceID, UserID}`
  (`orbit/internal/admin/live_eventbus.go`).
- **El bus de Nucleus tiene emisión, pero no expuesta.** `observability.Bus.Emit(Event)`
  existe (`nucleus/pkg/observability/bus.go:65`), pero lo que Orbit recibe por
  `rt.Observability()` es la interfaz `nucleus.EventBus`, **solo suscripción**
  (`SubscribeSQL`/`SubscribeHTTP`, `nucleus/pkg/nucleus`). No hay ingest público.

## Decisión

**No enseñar a Orbit sobre Quark; enseñar al bus.** Orbit ya drena el bus;
cualquier productor que publique un evento SQL en él aparece en el feed sin tocar
Orbit.

**Caso 1 — feed SQL en tiempo real:**
- Un **`quark.Middleware` ctx-aware** mapea cada sentencia ejecutada a un evento
  SQL de observabilidad y lo **emite en el bus de Nucleus**, rellenando
  `RequestID/TraceID/UserID` desde el `ctx`. (El `QueryObserver` es la variante
  simple sin `ctx`; se descarta para el feed porque perdería la correlación con
  la request.)
- **Prerrequisito en Nucleus (bloqueante):** exponer un *ingest* SQL público en
  la superficie del `Runtime`/`EventBus` — `EmitSQL(SQLEvent)` o un accessor del
  `*observability.Bus`. La capacidad (`Bus.Emit`) ya existe; falta destaparla.
  Es superficie del `Runtime` → entra en el gate de v1.0 de Nucleus (QADR-0005).
- **OTel en paralelo, no como transporte del feed.** Con un tracer compartido,
  los spans de Quark (`quark/otel/`) cuelgan del span de la request y encienden
  el `TraceURLTemplate` de Orbit. El feed *live* va por el bus (menos fontanería,
  y los spans se exportan en batch → no serían tiempo real).
- **Dónde vive el puente:** módulo opt-in `orbit/quarkbridge` (depende de Quark +
  Nucleus). **No** en el core de Quark (lo ataría a Nucleus) ni en el de Nucleus
  (lo ataría a un ORM). Respeta la `RedactionMode` de Quark para los args.

**Caso 2 — Data Studio sobre modelos Quark:**
- El panel de Orbit se desacopla de los tipos de Nucleus mediante un contrato
  neutral de origen de datos (decisión interna de Orbit; ver `orbit/docs/adrs/`
  ADR sobre `datasource`). Un adaptador respaldado por Quark (su `Client` +
  introspección) implementa ese contrato → Data Studio opera sobre modelos Quark.
- Proyecto embrionario → **sin doble registro**: se va directo al contrato limpio.

**Indicar el uso de Quark:** el ejemplo *showcase* de la Fase 4 (app Nucleus +
Quark + Orbit con el puente cableado) es la prueba viva; y la doc de Nucleus lo
señala. No es un cambio de código en Nucleus.

## Consecuencias

- **Orbit no cambia para el Caso 1**: sigue drenando el bus; el puente es externo.
- **Quark sigue standalone**: el `Middleware`/observer ya existen; el puente vive
  fuera de su core.
- **Nucleus gana un ingest público pequeño** (superficie de `Runtime`, v1.0).
- **El contrato de Data Studio queda validado por dos implementaciones** (Nucleus
  y Quark): si ambas lo satisfacen sin forzar, no quedó con forma de Nucleus.

## Alternativas consideradas

- **OTel como transporte del feed live.** Rechazado: obligaría a Orbit a consumir
  spans y estos se exportan en batch (no tiempo real). OTel se usa para el
  trazado durable, complementario.
- **Puente en el core de Quark o de Nucleus.** Rechazado: acoplaría un core al
  otro producto. El puente es opt-in y externo.

## Cuándo reabrir

Si se decide que **Nucleus adopte Quark como su ORM interno** (hoy tiene el suyo):
eso cambiaría todo el modelo de integración y es una decisión mayor, deliberadamente
**fuera del alcance** de este QADR. Requeriría su propio ADR.
