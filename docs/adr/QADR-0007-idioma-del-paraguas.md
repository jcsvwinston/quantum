---
id: QADR-0007
title: Idioma único del sitio del paraguas — inglés
status: accepted
date: 2026-07-19
deciders: jcsvwinston
related: [QADR-0003]
supersedes: null
tags: [docs, website, idioma]
---

# QADR-0007 — Idioma único del sitio del paraguas: inglés

## Contexto

Desde la Fase 2 el sitio unificado servía un híbrido: las documentaciones de
los tres productos en inglés (así nacieron en sus repos) y el *chrome* del
paraguas — portada, navegación, tema — en español. Dos auditorías señalaron la
incoherencia (QM5-7 dejó honesto el comentario del buscador; la 6ª pidió
decidir). Un lector llega a una portada en español que abre docs en inglés: la
mezcla no sirve a ninguno de los dos públicos.

## Decisión

**Todo el sitio publicado en inglés.** Las docs ya lo estaban; el chrome se
alinea con ellas (portada, etiquetas de navegación, footer, `defaultLocale`
`en`, buscador solo `en`). El inglés es el idioma en el que un ecosistema Go
espera evaluar herramientas, y el único que no duplica trabajo: mantener el
chrome en español exigía traducir cada cadena nueva sin que ninguna doc lo
estuviera.

El español sigue siendo el idioma de trabajo interno del proyecto (ADRs,
commits, PRs, informes de auditoría): esta decisión cubre solo la superficie
publicada.

## Reversibilidad

Deliberadamente barata: el chrome son ~15 cadenas en
`website/docusaurus.config.ts`, `website/src/pages/index.tsx` y el swizzle del
logo, más el `defaultLocale`. Revertir (o añadir i18n real con `locales:
['en', 'es']` y traducciones de tema) es un cambio acotado que no toca las
docs de los productos. Si en el futuro se decide localizar las docs, el camino
es el i18n de Docusaurus por instancia, no volver al híbrido.
