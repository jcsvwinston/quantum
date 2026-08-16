# Architecture Decision Records — Quantum (QADR)

> Decisiones arquitectónicas a **nivel suite**, una por archivo, formato MADR
> (mismo criterio que los ADRs de Quark). No las cuestiones sin abrir un nuevo
> QADR que las supersede.
>
> Estos QADR cubren la coordinación de la suite (paraguas, versionado, docs,
> manifiesto). Las decisiones internas de cada producto viven en los ADRs de su
> propio repo (p. ej. `quark/docs/adr/`).

## Índice

| ID | Título | Estado | Fase relacionada |
|---|---|---|---|
| [QADR-0001](QADR-0001-multirepo-paraguas.md) | Multi-repo + repo paraguas de coordinación (no monorepo) | Accepted | Fase 0 |
| [QADR-0002](QADR-0002-versionado-dos-niveles.md) | Versionado en dos niveles — módulos independientes, suite coordina majors | Accepted | Fase 0 / Fase 5 |
| [QADR-0003](QADR-0003-docs-sitio-unico-fuente-en-repos.md) | Docs: sitio único que ensambla, fuente en cada repo | Accepted | Fase 2 |
| [QADR-0004](QADR-0004-versions-yaml-manifiesto.md) | `versions.yaml` como manifiesto de releases Quantum | Accepted | Fase 0 / Fase 3 |
| [QADR-0005](QADR-0005-secuenciacion-convergencia.md) | Secuenciación de convergencia — Nucleus a v1.0 primero, Orbit en lockstep | Accepted | Fase 5 |
| [QADR-0006](QADR-0006-integracion-quark-orbit.md) | Integración Quark↔Orbit — feed SQL en tiempo real y Data Studio sobre Quark | Accepted | Fase 4 |
| [QADR-0007](QADR-0007-idioma-del-paraguas.md) | Idioma único del sitio del paraguas — inglés | Accepted | Fase 3 |

## Cómo añadir un QADR nuevo

1. Copia la plantilla de uno existente (frontmatter + secciones
   Contexto / Decisión / Consecuencias / Alternativas / Cuándo reabrir).
2. Numera secuencialmente (`QADR-NNNN-titulo-corto-en-kebab.md`).
3. Estado inicial: `proposed`. Tras discusión: `accepted` o `rejected`.
4. Si supersede una decisión previa, márcalo en `supersedes:` y actualiza el QADR
   antiguo con `status: superseded`.
5. Añade fila a este índice.

## Para Code

Lee el QADR específico cuando justifiques o cuestiones una decisión de
coordinación de la suite. **No reabras decisiones aceptadas sin abrir un nuevo
QADR**. Si encuentras configuración o estructura que viola un QADR, eso es un bug,
no una alternativa de diseño.

Las decisiones base de Quantum (multi-repo, versionado en dos niveles, docs con
fuente en cada repo) están confirmadas por el responsable y registradas aquí
precisamente para no reabrirlas sin sucesor.
