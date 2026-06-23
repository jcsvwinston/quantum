---
id: QADR-0004
title: versions.yaml como manifiesto de releases Quantum
status: accepted
date: 2026-06-23
deciders: jcsvwinston
related: [QADR-0001, QADR-0002]
supersedes: null
tags: [versionado, manifiesto, ci, governance]
---

# QADR-0004 — `versions.yaml` como manifiesto de releases Quantum

## Contexto

El modelo paraguas ([QADR-0001](QADR-0001-multirepo-paraguas.md)) necesita una
definición operativa y reproducible de "qué es una release Quantum". Sin ella, la
suite es solo un nombre: no hay forma de decir qué trío de versiones forma un
conjunto, ni de verificarlo.

Hace falta un artefacto declarativo, versionado y legible que:

1. Fije el trío compatible (Quark, Nucleus, Orbit) de cada release Quantum.
2. Sea la fuente que el `go.work` y (en Fase 3) el CI de integración consumen.
3. No falsee las versiones reales publicadas de cada módulo
   ([QADR-0002](QADR-0002-versionado-dos-niveles.md)).

## Decisión

**Un fichero [`versions.yaml`](../../versions.yaml) en la raíz del paraguas es el
manifiesto de la suite.** Cada release Quantum es un commit/tag sobre este fichero
que certifica un trío. Entre releases, cada módulo saca subversiones libremente;
el manifiesto solo se actualiza cuando se quiere certificar un nuevo conjunto.

Estructura:

- `quantum` — versión de la suite (SemVer propio).
- `status` — `pre-fusion` hasta que el CI de integración (Fase 3) verifique sets.
- `modules` — las versiones **reales publicadas** de cada módulo (lo que la gente
  instala con `go get`).
- `workspace_pins` — los commits exactos a los que se fijan los submódulos para que
  el `go.work` compile. Coinciden con `modules`, **salvo** cuando un módulo
  depende de código aún sin taggear de otro (hoy: Orbit v0.1.0 consume API de
  Nucleus posterior a v0.9.0, así que el submódulo de Nucleus se fija a esa
  pseudo-version; `modules.nucleus` sigue siendo `v0.9.0`, su última versión
  publicada). Distinguir ambos campos mantiene el manifiesto honesto sin romper
  el build.

El primer set realmente **verificado por CI** será Quantum 0.1.0 en la Fase 3.
Hasta entonces, el manifiesto declara el trío (`status: pre-fusion`) pero no lo
certifica automáticamente.

## Consecuencias

**Positivas:**
- "Qué es una release Quantum" queda definido, declarativo y reproducible.
- El `go.work` y el futuro CI de integración tienen una única fuente que consultar.
- La separación `modules` (publicado) vs `workspace_pins` (lo que compila) hace
  explícita —no oculta— la realidad de que Orbit consume Nucleus pre-release.

**Negativas:**
- El manifiesto se mantiene a mano hasta la Fase 3 (sin CI que lo valide), así que
  un trío declarado puede no compilar si nadie lo prueba. Mitigación parcial: en
  Fase 0 se ha verificado a mano que el trío compila vía `go.work`.
- Dos campos de versión (`modules` y `workspace_pins`) son más que uno; es el
  precio de no falsear ni la versión publicada ni la que realmente se construye.

## Alternativas consideradas

- **Un solo campo de versión por módulo (solo tags).** Rechazado: hoy no existe un
  tag de Nucleus que satisfaga a Orbit v0.1.0, así que un único campo o bien
  miente (declara v0.9.0 y no compila) o bien expone una pseudo-version como si
  fuera una release. Los dos campos resuelven el conflicto sin perder honestidad.
- **Codificar el trío solo en los punteros de submódulo git.** Rechazado: los
  punteros no son legibles ni llevan la versión de suite, el status ni notas; el
  manifiesto declarativo es además consumible por CI.

## Cuándo reabrir

Cuando llegue el CI de integración (Fase 3) y Nucleus taggee la línea que Orbit
consume: en ese punto `workspace_pins.nucleus` pasará a ser un tag y conviene
revisar si `modules` y `workspace_pins` pueden volver a colapsar en un solo campo
para los casos sin pre-release. Con ADR sucesor si cambia el esquema.
