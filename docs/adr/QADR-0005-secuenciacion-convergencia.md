---
id: QADR-0005
title: Secuenciación de convergencia — Nucleus a v1.0 primero, Orbit en lockstep
status: accepted
date: 2026-07-01
deciders: jcsvwinston
related: [QADR-0002, QADR-0006]
supersedes: null
tags: [convergencia, versionado, secuenciacion]
---

# QADR-0005 — Secuenciación de convergencia (Nucleus a v1.0 primero, Orbit en lockstep)

## Contexto

Quantum 1.0 requiere que Nucleus y Orbit alcancen major 1 para igualar a Quark
(ver [QADR-0002](QADR-0002-versionado-dos-niveles.md)). Hoy: Quark v1.1.x
(estable), Nucleus v0.9.0 (pre-1.0), Orbit v0.1.0 (pre-1.0). La pregunta es el
orden de trabajo: ¿madurar Orbit primero (parece lo más verde) o Nucleus primero?

Hechos que condicionan la respuesta (verificados sobre el trío al día):

- **Orbit está estructuralmente aguas abajo de Nucleus.** Consume 15 paquetes
  públicos de Nucleus (`pkg/db`, `router`, `model`, `auth`, `authz`,
  `observability`, `observe`, `storage`, `tasks`, `outbox`, `errors`, `mail`,
  `signals`, `app`, `nucleus`) y se ata a `nucleus.Runtime` por sus accessors
  (`Models()`, `Session()`, `Authorizer()`, `Storage()`, `Observability()`,
  `DatabaseHandle(s)`) en `orbit/orbit.go`.
- **Orbit fija Nucleus por pseudo-version, no por tag.** El propio
  [`versions.yaml`](../../versions.yaml) lo documenta: *"Orbit v0.1.0 consume API
  de Nucleus (`nucleus.EventBus`, `nucleus.SQLEvent`) introducida DESPUÉS de
  v0.9.0, y Nucleus aún no ha taggeado esa línea."* Un v1.0 no puede depender de
  una dependencia sin tag para su núcleo.
- **La superficie que Orbit consume aún se mueve** (p. ej. `pkg/observability`
  vs `pkg/observe` coexisten; Orbit importa ambos). El camino de Nucleus a v1.0
  está en marcha — hay ADRs abiertos que cierran sus bloqueadores conocidos:
  `nucleus/docs/adrs/ADR-014` (CORS seguro por defecto), `ADR-015` (firewall
  `/vN` y fugas de tipo), `ADR-018` (migración del bus de observabilidad).
- **Quark NO está en el grafo de dependencias.** Ni Nucleus ni Orbit lo importan
  (Nucleus tiene su propio `pkg/db`+`pkg/model`). Quark ya es major 1 y autónomo.

## Decisión

**Nucleus se lleva a v1.0 (congelación de API pública) ANTES que Orbit; Orbit se
desarrolla en paralelo como arnés de *dogfooding* que valida esa congelación —
no en serie.** Quark converge por el paraguas (docs, versionado, un ejemplo
showcase), sin entrar en el grafo de dependencias.

Concretamente, en este orden:

1. Estabilizar en Nucleus **la superficie que Orbit consume**: decidir
   `observability` vs `observe`, cablear el default-deny de `authz`, cerrar los
   bloqueadores ADR-014/015/018, y fijar los accessors del `Runtime`. Orbit monta
   contra cada RC y reporta qué no es congelable (ese es el valor del arnés).
2. Taggear **Nucleus v1.0** y **repinear Orbit a ese tag** (fin de la
   pseudo-version).
3. Congelar la API pública de Orbit — incluido el contrato de origen de datos de
   Data Studio (ver ADR de Orbit sobre `datasource`) — y taggear **Orbit v1.0**.
4. Cortar **Quantum 1.0** (Fase 5) y activar el régimen de majors en lockstep.

## Consecuencias

**Positivas:**
- Es el camino más rápido *y* de-riesgado: el arnés prueba que el freeze de
  Nucleus es real antes de comprometerlo.
- Versiones honestas: Orbit no reclama v1.0 sobre una dependencia sin tag.
- Quark sigue usable en solitario; no se toca su autonomía.

**Negativas:**
- Orbit permanece en v0.x pineado a un pre-release de Nucleus hasta el tag de
  Nucleus 1.0. Se asume: es la consecuencia de estar aguas abajo.
- Habrá algo de retrabajo en Orbit según se asiente la superficie de Nucleus;
  el modelo lockstep lo minimiza (se detecta pronto, no al final).

## Alternativas consideradas

- **Orbit primero.** Rechazado: congelar Orbit mientras sus 15 dependencias se
  mueven es construir el tejado antes de que paren los muros; además no se puede
  taggear v1.0 sobre una pseudo-version.
- **Serial estricto (terminar Nucleus, luego empezar Orbit).** Rechazado: pierde
  el dogfooding que de-riesga el freeze. Orbit montado es la mejor prueba de que
  el `Runtime` de Nucleus es congelable.

## Cuándo reabrir

Si Nucleus se estanca de forma indefinida (bloquearía Orbit y Quantum 1.0), o si
el acoplamiento Orbit→Nucleus se rompe (haría a Orbit independiente). No antes.
