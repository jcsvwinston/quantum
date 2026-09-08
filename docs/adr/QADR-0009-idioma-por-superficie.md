---
id: QADR-0009
title: Idioma por superficie — los productos en inglés, el paraguas en español
status: accepted
date: 2026-09-08
deciders: jcsvwinston
related: [QADR-0001, QADR-0003, QADR-0007]
supersedes: null
tags: [idioma, docs, releases, gobernanza]
---

# QADR-0009 — Idioma por superficie: los productos en inglés, el paraguas en español

## Contexto

[QADR-0007](QADR-0007-idioma-del-paraguas.md) puso el sitio publicado en
inglés y cerró con una frase que era verdad entonces: «el español sigue
siendo el idioma de trabajo interno del proyecto (ADRs, commits, PRs,
informes de auditoría)».

La auditoría de madurez del 2026-09-03 encontró por qué esa frase no se
sostiene en un repo de producto (QM-18): **el título del squash de un PR ES
la línea del CHANGELOG**, y de ahí sale la viñeta de las notas de release que
el sitio publica en inglés. Un título en español publica una nota en español
en un producto cuyo README, cuyas docs y cuyo sitio están en inglés. Lo mismo
vale para el mensaje del commit, que es lo que lee quien hace `git log` sobre
una librería que se instala desde el proxy de Go.

Desde el set 1.28.0 los tres productos llevan `scripts/ci/check_pr_title_english.sh`
en su CI, registrado además como guard del paraguas
(`nucleus-pr-title-english`, `quark-pr-title-english`,
`orbit-pr-title-english`), y sus commits van en inglés. La práctica lleva dos
sets contradiciendo la frase de QADR-0007, que es exactamente el tipo de
deriva que estos documentos existen para impedir.

## Decisión

**La frontera del idioma es la SUPERFICIE, no el repositorio.**

En los tres repos de producto (`quark`, `nucleus`, `orbit`), **inglés**:

- código y comentarios;
- documentación, tanto la publicada en el sitio como la del repo;
- mensajes de commit;
- títulos y cuerpos de pull request.

En el paraguas (`quantum`), **español**:

- mensajes de commit, títulos y cuerpos de pull request;
- QADRs, informes de auditoría, runbooks del tren y comentarios de los
  scripts de certificación;
- el manifiesto `versions.yaml` y sus notas de set.

Su sitio publicado sigue **en inglés** por QADR-0007, que no se toca.

**Los ADRs de los repos de producto quedan fuera de esta decisión.** Son
documento interno de trabajo, como los QADRs del paraguas, y cada repo
mantiene el idioma que tiene: `nucleus` los escribió en inglés desde el
principio, `quark` y `orbit` en español. Un ADR nuevo sigue el idioma de su
repo. Unificarlos exigiría traducir 27 documentos técnicos ya escritos, un
trabajo que no compra nada hoy; si algún día se decide, sale con el arco que
reordena la documentación (A11) y necesita su propio QADR sucesor.

## Consecuencias

- La frase de QADR-0007 sobre el idioma de trabajo interno queda **enmendada
  en su alcance**: sigue valiendo para el paraguas y para los ADRs de todos
  los repos; deja de valer para los commits y los PRs de los productos.
  QADR-0007 no queda superado: su decisión (sitio publicado en inglés) sigue
  intacta.
- Lo mecánico ya está: el guard vive en los tres repos y muerde sobre su
  fixture en el registro del paraguas. Esta decisión no añade trabajo, pone
  por escrito lo que ya se exige.
- Un colaborador que escriba un PR en español en un producto verá el CI en
  rojo con el motivo, no una discusión de estilo.

## Alternativas descartadas

- **Todo en español, incluidos los productos.** Publica notas de release en
  español en un ecosistema donde la evaluación de una librería Go se hace en
  inglés, y obliga a traducir en el momento del corte, que es cuando menos
  margen hay.
- **Todo en inglés, paraguas incluido.** El paraguas no publica su prosa
  interna: es la mesa de trabajo del propietario, que trabaja en español.
  Traducirla es coste sin lector.
- **Dejarlo sin escribir.** Es el estado que esta decisión corrige: dos sets
  de práctica contra una frase de un QADR aceptado.

## Cuándo reabrir

Si el proyecto incorpora colaboradores que no trabajen en español, el
paraguas pasa a ser superficie compartida y esta decisión se revisa entera.
También si alguna vez se localiza el sitio (i18n real de Docusaurus), porque
entonces «publicado en inglés» deja de ser una frase única.
