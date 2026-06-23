---
id: QADR-0003
title: Docs — sitio único que ensambla, la fuente se queda en cada repo
status: accepted
date: 2026-06-23
deciders: jcsvwinston
related: [QADR-0001, QADR-0002]
supersedes: null
tags: [docs, docusaurus, governance]
---

# QADR-0003 — Docs: sitio único que ensambla, fuente en cada repo

## Contexto

Hoy hay tres situaciones de documentación distintas: Quark tiene un Docusaurus
maduro con 13 snapshots versionados; Nucleus un Docusaurus sin versionar; Orbit
apenas READMEs dispersos y una landing estática. Tres `baseUrl`, tres deploys de
GitHub Pages separados.

Se quiere una sola marca y un solo sitio de docs (decisión base D2). El riesgo es
introducir una **segunda fuente de verdad**: si las docs se copian al repo
paraguas y se editan allí, se desincronizan del código que documentan.

Quark tiene una regla dura al respecto (su ADR-0008): **la documentación se
modifica en el mismo PR que la API**. Esa regla existe porque, históricamente,
tener las docs en un repo aparte (`quark-docs`) las desincronizó del código de
forma previsible. No se puede romper.

## Decisión

**Un solo sitio Docusaurus en el repo `quantum` (`website/`, Fase 2) que
*ensambla* las docs de cada producto; la fuente de las docs NO sale de cada
repo.**

- El sitio usa varias instancias de `plugin-content-docs` (una por producto)
  bajo una sola navbar con *product switcher* y doble selector de versión
  (versión Quantum arriba, versión real de cada módulo en su sección, tomada de
  [`versions.yaml`](../../versions.yaml)).
- La fuente de cada doc sigue viviendo en su repo de producto. El paraguas la
  trae en build-time (vía submódulo git o un paso de sync en CI), **no la posee**.
- Un único deploy en `/quantum/`; los tres Pages actuales se retiran y redirigen
  a la sección correspondiente.

Esto preserva literalmente la regla de Quark: como la fuente no se mueve, "API y
docs en el mismo PR" se sigue cumpliendo dentro de cada repo. El sitio unificado
es una vista *ensamblada*, no un repositorio de contenido editable.

## Consecuencias

**Positivas:**
- Preserva la regla dura de Quark (su ADR-0008) sin excepciones: no hay segunda
  fuente de verdad.
- Una marca, un deploy, un selector de versión; el versionado independiente por
  módulo se conserva.
- El histórico de versiones de Quark (sus snapshots) entra tal cual como instancia.

**Negativas:**
- El build del sitio es más complejo: tiene que ensamblar contenido de tres repos
  (submódulo o sync), no servir un solo árbol.
- Hay latencia entre un merge de docs en un repo de producto y su aparición en el
  sitio unificado (depende del paso de sync/rebuild). Aceptable.
- Orbit es el mayor hueco de contenido: su instancia hay que **escribirla** desde
  los READMEs (trabajo de Fase 3), no solo migrarla.

## Alternativas consideradas

- **Mover las docs al repo paraguas.** Rechazado de plano: crea la segunda fuente
  de verdad que la regla de Quark existe para evitar.
- **Mantener tres sitios separados con una landing que enlaza.** Rechazado: no
  cumple D2 (una sola marca, un selector de versión unificado) y deja a Orbit sin
  sitio real.

## Cuándo reabrir

Si el coste de ensamblar en build-time se vuelve inmanejable, considerar
alternativas de sync (p. ej. publicar las docs de cada repo como artefacto
versionado que el paraguas consume) — pero **nunca** moviendo la fuente fuera del
repo de producto. Esa parte no se reabre sin sustituir antes el ADR-0008 de Quark.
