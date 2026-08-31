---
id: QADR-0008
title: La certificación de un set va por cadencia, no por arco
status: accepted
date: 2026-08-31
deciders: jcsvwinston
related: [QADR-0002, QADR-0004]
supersedes: null
tags: [release, cadencia, tren]
---

# QADR-0008 — La certificación de un set va por cadencia, no por arco

## Contexto

Entre el 2026-07-11 (Quantum 1.0.0) y el 2026-08-30 (1.24.0) se certificaron
**24 sets en siete semanas**: once en los últimos ocho días, con dos sets el
mismo día en tres ocasiones. Cada uno arrastra el tren completo —15-25 PRs
repartidos en tres o cuatro repos, con sus cascadas de release-please y sus
re-pines— que la auditoría integral midió en **~2 horas de conducción
experta** (RT-1, RT-2, RT-3, PR-REL-01).

Ese coste no lo pedía ninguna regla: el acoplamiento arco↔set era una
costumbre. `versions.yaml` certifica **conjuntos** (QADR-0004), no arcos;
`declared_lags` y la lane semanal ya soportan por diseño estados intermedios
en los que un módulo va por delante del último set certificado. Mientras
tanto, el tiempo que consumía el tren era tiempo que no se dedicaba al
producto — que es de lo que se quejaba el responsable al pedir la auditoría.

## Decisión

**Los arcos y los sets se desacoplan.** Un arco se fusiona a `main` cuando
termina, con las releases de módulo que necesite; el **set se certifica por
cadencia fija, semanal**, pegada a la corrida del lunes que la lane
`suite-integral` ya ejecuta — o antes, por hito, cuando algo lo justifique.

Un corte de set fuera de cadencia necesita una razón escrita en el PR de
re-pin. Estas cuentan: un arreglo de seguridad que deba llegar al público, un
P0 que hoy pisa un usuario del set certificado, o un contrato cross-producto
que deje incoherente el conjunto. «El arco terminó» no cuenta.

## Consecuencias

- **La doc pública se retrasa hasta el corte.** El sitio unificado sirve el
  **tag pinado**, así que ninguna corrección documental es visible hasta
  certificar. Es el coste real de esta decisión y se acepta a sabiendas: a
  cambio, entre cortes se trabaja sin el peaje del tren. Si un arreglo de doc
  es urgente, es una razón legítima para un corte fuera de cadencia.
- **Las versiones de módulo flotan entre sets.** Ya lo permitía QADR-0002
  (el número Quantum nunca falsea el `vX.Y.Z` real que la gente instala); esta
  decisión lo convierte en el caso ordinario en vez de la excepción.
- **El tren se conduce con `scripts/train/`**, no de memoria: driver por
  fases, `merge-bot-pr.sh` y detección de ramas ancladas (RT-1). El runbook
  vive en `scripts/train/README.md`.
- **quantum-app se re-pina en cada corte** (D6): con cadencia semanal, el
  bump automatizado del consumidor de referencia externo es sostenible.
- El régimen de auditoría continua no cambia: la lane semanal y el CI por repo
  siguen siendo los jueces (`docs/AUDITORIA_CONTINUA.md`).

## Alternativas descartadas

- **Seguir por arco.** Es el estado que motivó la queja; incluso con el tren
  automatizado se paga un coste fijo casi diario.
- **Certificar solo por hito.** Deja al público sin correcciones durante
  periodos indefinidos y hace que cada corte vuelva a ser grande y arriesgado
  — justo lo que la cadencia corta evita.
