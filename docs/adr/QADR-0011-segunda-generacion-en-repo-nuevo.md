---
id: QADR-0011
title: El 2.0 es una segunda generación en un monorepo nuevo; la generación 1 se congela
status: accepted
date: 2026-11-17
deciders: jcsvwinston
related: [QADR-0001, QADR-0002, QADR-0003, QADR-0004, QADR-0008, QADR-0010]
supersedes: null
tags: [release, versionado, repos, segunda-generacion]
---

# QADR-0011 — El 2.0 es una segunda generación en un monorepo nuevo; la generación 1 se congela

## Contexto

QADR-0010 acumuló todo lo rompiente en un único major al cierre de A12, y
desde el 2026-10-16 ese major se preparó como se prepara para quien ya usa el
producto: 34 avisos de deprecación publicados con ventana de 90 días, una guía
de migración generada, la ruta de módulo `/v2` sobre los repos actuales, un
ensayo en ramas `dry-run/2.0` y, tras `M1-S0` (2026-11-16), un troceado de 23
sesiones más el tren, con 18 sesiones de tramo 1.x como precondición y trece
decisiones (D26…D38) sobre cómo aterrizarlo.

El 2026-11-16 el propietario dejó escrito lo que ese plan no sabía: Quantum es
un proyecto experimental **que nadie ha usado**. Casi todo ese aparato protege
a usuarios que no existen. El coste es real —la mayor parte de las sesiones
de `M1` son maquinaria de transición, no producto— y el beneficio es nulo.

A la vez, la re-auditoría `R1` dejó 32 dimensiones por debajo del 5, y varias
de ellas (dos capas de datos que se contradicen, adaptadores, puertas sin
tipo, tres sitios de documentación ensamblados, un tren de cuatro repos) no
son defectos de una pieza sino de la forma en que la generación 1 creció.
Corregirlas una a una sobre los repos actuales es más caro que heredar lo que
vale en una estructura pensada para ello.

## Decisión

**El 2.0 no es un major de los repos actuales. Es la segunda generación de
Quantum, construida en un repositorio nuevo y sin histórico, y la generación 1
se congela en su último set certificado (Quantum 1.45.0).**

Las cinco decisiones que le dan forma, tomadas por el propietario el
2026-11-17, una a una:

1. **Dónde vive.** En la organización de GitHub `the-quantum-platform`, en un
   único repositorio `quantum`.
2. **Monorepo.** Un `go.work` y un `go.mod` por pieza instalable. Las
   dependencias sólo bajan: quark no depende de ningún otro módulo del
   repositorio, nucleus depende de quark, orbit depende de ambos. Todos los
   módulos comparten **un solo número de versión**.
3. **Quark conserva nombre y vida propia.** Es instalable y usable sin el
   resto, tiene entrada propia en la documentación, y una lane de CI lo
   compila y prueba aislado y falla si aparece una dependencia hacia nucleus u
   orbit. Nucleus y Orbit conservan su nombre como piezas del producto, sin
   vida independiente.
4. **Ruta de importación y número.** La ruta es la de GitHub y «2» es semver
   real, así que los módulos llevan el sufijo de major que Go exige:
   `github.com/the-quantum-platform/quantum/quark/v2`, y lo mismo para
   `nucleus` y `orbit`. Mientras se construye se etiquetan prelanzamientos
   (`quark/v2.0.0-alpha.N`, después `-beta` y `-rc`); la publicación es
   `v2.0.0`. No hay dominio propio.
5. **Identidad.** El repositorio lo opera la cuenta del propietario, como
   hasta ahora; lo que se quería fuera de la cuenta personal era la URL.

### Qué se hereda y qué no

Se hereda **por copia, con criterio y sin histórico**: quark como única capa
de datos, el runtime de nucleus con composición explícita, el panel de orbit
sobre quark con opciones tipadas, el starter único, el kit de test, el
documento OpenAPI tipado, la CLI (`dev`, `doctor`, generadores), la cadena de
suministro firmada, los bancos y los guards que miden código, y el método de
auditoría de `R0`/`R1`.

**Los 34 avisos del §3.0 del contrato anterior dejan de ser un contrato con
ventana y pasan a ser decisiones de diseño ya tomadas**: en la segunda
generación el comportamiento que anunciaban es el único que existe desde el
primer commit.

No se hereda lo transicional: `pkg/model` y sus adaptadores, las variantes
que avisan, los módulos de reenvío, las ventanas de 90 días, la guía de
migración, `Release-As`, el lag declarado, `versions.yaml` como manifiesto de
tríos, el ensamblaje de tres sitios y el tren de alineación.

### Cómo se trabaja

Sin fechas. Siete fases, cada una con criterio de salida, y ninguna se abre
sin cumplir el de la anterior:

| Fase | Qué | Criterio de salida |
|---|---|---|
| F0 | Decisiones y este QADR | QADR aceptado |
| F1 | `S0` de la segunda generación, sin código: inventario hereda/tira por paquete, la primera hora medida sobre 1.45.0 como línea base, API pública en papel, arquitectura de la información, tres direcciones visuales | contrato nuevo y troceado en sesiones, cada una con su comando de comprobación |
| F2 | Esqueleto del repositorio: workspace, CI, release de un solo número con firma, la lane «quark solo», guards mínimos | un commit sin producto pasa todo en verde |
| F3 | Construcción de abajo arriba: quark → nucleus → orbit → CLI y starter | los bancos de cada capa en verde antes de empezar la siguiente |
| F4 | Documentación y sitio, en paralelo con F3: cada capítulo al cerrar su capa | las tareas de lector se completan sobre el sitio |
| F5 | La primera hora medida y `R2` sobre el repositorio nuevo | objetivos cumplidos, o lista corta con dueño |
| F6 | Publicación de `v2.0.0` con el sitio nuevo | etiqueta, activos firmados y sitio servidos |

Tres reglas de la generación 1 siguen en pie: se mide antes de trocear;
escribir la documentación es una medición y por eso no va al final; y lo que
es del propietario lo decide el propietario.

## Consecuencias

**Lo que deja sin objeto.** El troceado de `M1` (las 23 sesiones, el tramo 1.x
y el carril del rediseño tal como estaban planteados) y las decisiones
D26…D38: quedan escritas en la rama `docs/a12-decisiones-m1-s0` como registro
y no se fusionan. La ventana D14…D25 pierde lo que dependía del major sobre
estos repos; lo que era producto (lo aditivo de las 32 dimensiones) pasa a ser
entrada del inventario de F1.

**Lo que sustituye, para la segunda generación.** QADR-0001 (multi-repo con
paraguas), QADR-0002 (versionado en dos niveles), QADR-0003 (sitio que
ensambla), QADR-0004 (`versions.yaml`), QADR-0008 (cadencia de certificación)
y QADR-0010 (rupturas agrupadas) describen la generación 1 y **siguen siendo
ciertos para estos repositorios**, por eso no se marcan `superseded`. En el
repositorio nuevo no rigen: sus decisiones equivalentes se escriben allí, en
su propia serie de ADR.

**Lo que cierra.** A12 se cierra con este QADR: `R2`, su última sesión, se
hace sobre el repositorio nuevo (F5), no sobre el pin de la generación 1. El
plan a 5 de 5 deja de medirse sobre estos repos.

**Lo que cuesta.** Se renuncia al histórico de commits como trayectoria
visible, y hay un tramo —F1 y F2— sin producto nuevo. Y heredar por copia
obliga a decidir paquete a paquete: lo que se copie sin mirar trae consigo la
forma antigua.

**Lo que hay que vigilar.** Que «heredar» no se convierta en trasladar el
árbol entero: el inventario de F1 nombra cada paquete con su veredicto antes
de que F3 copie nada. Y que la frontera de quark no se erosione: la lane
aislada es la que la sostiene, no la intención.

## Lo que el propietario cerró el mismo día

- **Quantum 1.45.0 es el último set de la generación 1.** No hay set de
  cierre ni más trenes.
- **Los repositorios de la generación 1 se quedan donde están**, en la cuenta
  del propietario, sin transferirse a la organización. De ellos se aprovecha
  todo el trabajo que se pueda, por copia.
- **El repositorio nuevo nace privado** y se hace público cuando sirva para
  desarrollar aplicaciones, no antes.
- **Licencia del repositorio nuevo: Apache-2.0**, la misma de la generación 1.
- Las decisiones de diseño posteriores (núcleo ligero con capacidades como
  módulos, permisos propios con denegar por defecto, `net/http`, la carpeta
  `modules/`, migraciones por módulo, nada oculto) viven en los ADR del
  repositorio nuevo, `docs/adr/`.

## Lo que queda abierto

- La excepción de govulncheck para GO-2026-6909 en nucleus caduca el
  2026-12-31: sin más sets, sólo importa mientras las lanes programadas de la
  generación 1 sigan corriendo; apagarlas es una acción del propietario.
- Si el sitio nuevo enlaza a la generación 1. Con «2» como semver real, quien
  llegue preguntará por la versión 1.
- quantum-app sigue pendiente de rehacerse entero, ahora sobre `v2.0.0`.

## Alternativas

- **Seguir con `M1` sobre los repos actuales.** Es el plan medido y troceado,
  y conserva el histórico. Se descarta porque su coste es mayoritariamente
  maquinaria de transición para usuarios que no existen.
- **Un repositorio por producto dentro de la organización.** Rutas más cortas
  y una portada por producto, pero reconstruye el versionado en dos niveles,
  el manifiesto y el tren.
- **Dominio propio como ruta de importación.** Desata el nombre de GitHub;
  descartado por no añadir una dependencia que mantener.
- **Empezar la numeración en el repositorio nuevo** (`v0.x` → `v1.0.0`, con
  «2» como nombre interno). Imports sin sufijo; descartado: el número cuenta
  la historia como fue.

## Cuándo reabrir

Si el inventario de F1 muestra que lo heredable sin cambios es tan grande que
la copia equivale a una migración de repositorio; o si aparece un usuario real
de la generación 1 antes de F6, lo que devolvería sentido a una guía de
migración (no a las ventanas).
