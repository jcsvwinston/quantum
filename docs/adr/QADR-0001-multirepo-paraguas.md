---
id: QADR-0001
title: Multi-repo + repo paraguas de coordinación (no monorepo)
status: accepted
date: 2026-06-23
deciders: jcsvwinston
related: [QADR-0002, QADR-0003, QADR-0004]
supersedes: null
tags: [estructura, repos, governance]
---

# QADR-0001 — Multi-repo + repo paraguas de coordinación (no monorepo)

## Contexto

Quantum nace de unir tres productos Go que ya existen y se desarrollan por
separado, cada uno con su propia historia, su release y su cadencia:

- **Quark** — ORM maduro (v1.1.5, línea estable v1.x), autónomo, usable en
  cualquier app Go.
- **Nucleus** — framework web MVC/REST pre-1.0 (v0.9.0).
- **Orbit** — admin in-process sobre Nucleus, recién taggeado (v0.1.0),
  multi-módulo (`/`, `/agent`, `/proto`, `/server`).

Se quiere converger en una suite **sin** congelar las cadencias independientes,
sin reescribir las historias de cada repo y sin obligar a Quark a depender de los
otros dos. La integración real entre módulos hoy es fina y unidireccional (Orbit
depende de Nucleus; Quark es autónomo).

La pregunta es la estrategia de código: ¿monorepo (absorber los tres en un único
repositorio) o multi-repo coordinado?

## Decisión

**Multi-repo + un repo `quantum` ligero de coordinación.** Los tres productos
siguen en sus repositorios actuales, intactos, con sus releases propias. Se añade
un repositorio `quantum` que **coordina, no contiene**: no aloja el código de los
productos ni sus `go.mod`; los referencia como **submódulos git** y publica el
manifiesto del trío compatible ([`versions.yaml`](../../versions.yaml), ver
[QADR-0004](QADR-0004-versions-yaml-manifiesto.md)) y un `go.work` para el
desarrollo cruzado en local.

La analogía es una distro de Linux: no incluye el código de cada paquete, publica
un manifiesto de qué versiones, probadas juntas, forman una release. Es además el
patrón que Orbit ya usa internamente entre sus cuatro módulos (`go.work`),
elevado a nivel suite.

Los productos se enganchan como **submódulos** (no clones hermanos) para que el
paraguas sea autocontenido y reproducible: `git clone --recurse-submodules` deja
el trío exacto que el `go.work` resuelve, sin pasos manuales.

## Consecuencias

**Positivas:**
- Disrupción mínima: ningún repo de producto cambia de sitio ni de historia.
- Cada producto conserva su release, su CI y su cadencia.
- Quark sigue siendo `go get`-able en solitario; el paraguas no le añade
  dependencias (regla dura, ver [QADR-0002](QADR-0002-versionado-dos-niveles.md)).
- La coordinación vive en dos artefactos explícitos y revisables: el manifiesto y
  el `go.work`.

**Negativas:**
- La sincronía entre productos es **explícita, no automática**: actualizar el trío
  es un commit consciente sobre los punteros de submódulo y `versions.yaml`, no un
  efecto colateral.
- Trabajar cruzando módulos exige clonar el paraguas con submódulos y entender el
  `go.work` (coste de onboarding pequeño, documentado en el README).
- Los submódulos git tienen ergonomía conocida-incómoda (punteros desincronizados
  si no se hace `submodule update`); se asume como coste menor frente a un
  monorepo.

## Alternativas consideradas

- **Monorepo (absorber los tres).** Rechazado: reescribiría historias, forzaría
  una cadencia común, rompería el `go get` standalone de Quark y mezclaría tres
  matrices de CI muy distintas. Es justo lo que se quiere evitar.
- **Clones hermanos en vez de submódulos.** Viable (el `go.work` solo necesita las
  rutas relativas), pero el paraguas dejaría de ser autocontenido: el trío exacto
  no quedaría fijado en el repo. Se prefieren submódulos por reproducibilidad. Si
  en el futuro la fricción de submódulos supera su beneficio, este es el primer
  candidato a reabrir.

## Cuándo reabrir

Si la coordinación explícita se vuelve insostenible (muchos cambios cruzados
simultáneos, punteros de submódulo en conflicto constante) o si el `go get`
standalone de Quark deja de ser un requisito, reconsiderar la estrategia con un
ADR sucesor. No antes.
