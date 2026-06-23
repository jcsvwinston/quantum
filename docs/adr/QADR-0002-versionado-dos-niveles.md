---
id: QADR-0002
title: Versionado en dos niveles — módulos independientes, suite coordina majors
status: accepted
date: 2026-06-23
deciders: jcsvwinston
related: [QADR-0001, QADR-0004]
supersedes: null
tags: [versionado, semver, governance]
---

# QADR-0002 — Versionado en dos niveles

## Contexto

Los tres productos no comparten major: Quark está en major 1 (v1.1.5), Nucleus en
major 0 (v0.9.0) y Orbit en major 0 (v0.1.0). La regla deseada —"las subversiones
avanzan por separado; los majors se cruzan juntos"— todavía no es aplicable
porque no hay un punto de partida común en major.

Hace falta un esquema de versiones que:

1. No falsee la versión real que la gente instala (`go get` devuelve `vX.Y.Z` de
   cada módulo, no un número de marketing).
2. No obligue a coordinar subversiones entre productos.
3. Permita, llegado el momento, mover los majors en lockstep bajo una release
   coordinada.

## Decisión

**Dos niveles de SemVer, y ninguno pisa al otro:**

- **Nivel módulo (independiente).** Cada repo mantiene su propio SemVer y su
  propia cadencia. `Quark v1.1.6`, `Nucleus v0.9.1`, `Orbit v0.1.1` salen cuando
  cada uno está listo, sin coordinación. Esto es lo que protege que Quark siga
  siendo un ORM usable en solitario.
- **Nivel suite (paraguas).** Quantum tiene su propio SemVer, que **no** es el de
  ningún módulo: es la versión del *manifiesto* ([`versions.yaml`](../../versions.yaml)).

La regla de majors se aplica **a partir de Quantum 1.0**:

- **Hoy → Quantum 1.0**: fase de pre-fusión. El paraguas vive en `0.x`, pinta
  conjuntos compatibles y unifica la presentación. No reclama "major compartido"
  todavía, porque Nucleus y Orbit aún no son 1.0.
- **Quantum 1.0.0** = hito de convergencia: requiere `Nucleus ≥ 1.0` y
  `Orbit ≥ 1.0` (subirlos hasta alcanzar a Quark, que ya está en major 1).
- **Desde Quantum 1.0**: un major de Quantum (→ v2) implica que los tres cruzan a
  major 2 a la vez, con su guía de migración. Los minors/patches de cada módulo
  siguen flotando entre releases Quantum.

Resumen: **las subversiones avanzan por separado; los majors solo se cruzan en una
release Quantum coordinada.**

## Consecuencias

**Positivas:**
- Honra "subversiones por separado, majors juntos" sin inventar coordinación donde
  no la hay.
- El número Quantum nunca falsea las versiones reales que la gente instala
  (versiones honestas, regla dura).
- Quark conserva intacta su línea v1.x y su uso standalone.

**Negativas:**
- Hay dos números que explicar (versión Quantum vs versión de cada módulo). Se
  mitiga mostrando siempre el `vX.Y.Z` real de cada producto junto al número
  Quantum (en docs y en el manifiesto).
- El régimen de "majors en lockstep" introduce, a partir de Quantum 1.0, una
  restricción real de coordinación para los breaking changes. Es deliberado: es el
  punto donde la suite pasa a comportarse como un todo.

## Alternativas consideradas

- **Un único SemVer compartido desde ya.** Rechazado: obligaría a alinear majors
  hoy (Nucleus/Orbit no están maduros para 1.0) y falsearía las versiones reales.
- **Sin versión de suite (solo el trío en el manifiesto).** Rechazado: se pierde
  un identificador estable de "qué es una release Quantum" y un ancla para el
  régimen de majors futuro.

## Cuándo reabrir

Cuando se corte Quantum 1.0 (Fase 5 del roadmap), revisar si el régimen de majors
en lockstep se confirma tal cual o necesita matices (p. ej. ventanas de gracia
por módulo). Cualquier cambio, con ADR sucesor.
