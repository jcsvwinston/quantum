---
id: QADR-0010
title: Lo rompiente se acumula en un único major al cierre de A12
status: accepted
date: 2026-09-10
deciders: jcsvwinston
related: [QADR-0002, QADR-0008]
supersedes: null
tags: [release, versionado, arcos, deprecacion]
---

# QADR-0010 — Lo rompiente se acumula en un único major al cierre de A12

## Contexto

QADR-0002 fija que la suite se versiona en lockstep: un major de cualquiera
de los tres pilares arrastra a los otros dos. Eso hace que la pregunta «¿esto
rompe?» no sea del repo donde ocurre, sino de la suite entera.

El plan a 5/5 tiene al menos tres arcos que pueden pedirlo:

- **A4** — la semántica de valores cero en `Update` de quark es hoy implícita,
  y hacerla explícita cambia lo que hace una llamada existente; y `pkg/model`
  de nucleus tendría que dejar de ser capa de usuario para pasar a sustrato.
- **A10** — la inyección de dependencias ligera sustituye al service locator.
- **A6** — lo que no quepa por adición sobre el contrato datasource congelado.

Sin una regla, cada uno de ellos decide por su cuenta y cada decisión cuesta
un 2.0, un 3.0, un 4.0 de los tres pilares a la vez. Con 24 sets cortados en
siete semanas ya medidos como problema (QADR-0008), multiplicar majors es la
misma enfermedad con otro nombre: coste de tren que no es producto.

## Decisión

**Todo cambio rompiente se acumula y sale en un único major al cierre de
A12**, con guía de migración generada.

Hasta entonces, un arco que necesite romper algo entrega **la forma nueva
junto a la vieja**:

1. La API nueva se añade; la vieja sigue funcionando.
2. La vieja se marca según `docs/gobernanza/POLITICA_DEPRECACION.md`: nombra
   su recambio, su aviso `DEP-YYYY-NNN` y una versión de retirada que todavía
   no ha salido. El guard `umbrella-deprecations` lo comprueba en cada
   certificación, así que una marca sin fecha o con una versión ya publicada
   no llega a un set.
3. La versión de retirada que se escribe es **la del major**, no una minor.

Un arco que no pueda entregar su cambio por adición —ni con una API paralela
ni con una marca de deprecación— **para y lo dice**, en vez de cortar un
major por su cuenta.

## Consecuencias

**Lo que desbloquea.** Las sesiones de A4 que dependían de esta decisión
(`S2`, semántica de valores cero; `S6`, `pkg/model` a sustrato) pueden
empezar: entregan la forma nueva y deprecan la vieja con retirada en el
major.

**Lo que cuesta.** La superficie de API crece antes de encoger: durante todo
el plan conviven las dos formas de cada cosa que se rompe. Es deliberado —
el coste lo paga el mantenedor en superficie, no el consumidor en migraciones
repetidas.

**Lo que hay que vigilar.** Que el registro de deprecaciones no se convierta
en un cajón: cada marca lleva su fecha desde el día que se escribe, y el
guard falla si la versión prometida ya salió. Si al llegar a A12 el registro
tiene marcas que nadie pensaba retirar, el problema no es el major — es que
se deprecó lo que no se iba a quitar.

**Cuándo reabrir.** Si un arco encuentra una ruptura que no se puede entregar
por adición de ninguna forma razonable, o si el número de formas paralelas
vivas hace la API difícil de explicar antes de A12. Las dos son señales de
que el major llega tarde, no de que la regla esté mal.
