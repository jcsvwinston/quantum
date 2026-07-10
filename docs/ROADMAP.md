# Quantum — Roadmap de convergencia

> Cómo seguir desarrollando Quark, Nucleus y Orbit por separado y que converjan en una suite llamada **Quantum**, sin romper la cadencia independiente de cada uno ni el uso aislado de Quark.
>
> Documento de planificación. Sin lenguaje de marketing (se hereda la regla anti-hype de Quark): describe lo que se hace, no lo vende.

**Fecha:** 2026-06-22 · **Estado:** propuesta para ejecutar · **Decisiones base confirmadas por el responsable.**

> **Cierre (2026-07-11):** la convergencia de versiones se alcanzó — **Quantum
> 1.0.0 certificado** con los tres pilares en major 1 (quark v1.1.5, nucleus
> v1.0.0, orbit v1.0.0; ver `versions.yaml`). Las fases de versionado (0–5)
> están cerradas y rige el régimen de majors en lockstep (QADR-0002). Queda
> abierto, como trabajo posterior al hito: el sitio de docs unificado (§5) y
> el versionado de la instancia de docs de nucleus. Las tablas de estado de
> este documento reflejan el punto de partida de 2026-06-22, no el estado
> actual.

---

## 1. Punto de partida (estado real, no el declarado)

| Componente | Rol | Repo / módulo | Versión real | Docs | Release tooling |
|---|---|---|---|---|---|
| **Quark** | ORM | `github.com/jcsvwinston/quark` | **v1.1.5** (línea estable v1.x) | Docusaurus en `/quark/`, 13 snapshots versionados | `release-please` + `release-please-config.json` |
| **Nucleus** | Framework web MVC/REST | `github.com/jcsvwinston/nucleus` (carpeta aún `GoFrame/`) | **v0.9.0** (pre-1.0) | Docusaurus en `/nucleus/`, sin versionar | `release.yml` + `rehearsal.yml` (custom) |
| **Orbit** | Admin del framework | `github.com/jcsvwinston/orbit` (+ `/proto`, `/agent`, `/server`) | **v0.1.0** (recién taggeado) | Solo `site/index.html` estático + READMEs | ninguno (solo `pages.yml`) |

Observaciones que condicionan el plan:

- **La marca "Quantum" no existe** en ningún repo (ni código, ni docs, ni configs). Es puramente conceptual hoy.
- **Tres sitios Docusaurus independientes**, tres `baseUrl` distintos, tres workflows de GitHub Pages separados. Orbit ni siquiera tiene sitio de docs real.
- **Las versiones no comparten major**: Quark major 1, Nucleus major 0, Orbit major 0 (v0.1.0). La regla "los majors se mueven juntos" todavía no es aplicable porque aún no hay un punto de partida común.
- **La integración entre módulos es fina y unidireccional**: Orbit depende de Nucleus por *pseudo-version* (no por tag); Nucleus **eliminó** su integración de ejemplo con Quark (`examples/showcase_demo` y `docs/quark/` borrados en el rename). Quark es completamente autónomo.
- **El rename de Nucleus está a medias**: la carpeta sigue siendo `GoFrame/`, y `NUCLEUS_RENAME_BRIEF.md` (que debía borrarse al terminar) sigue presente.
- **Patrón ya probado a reutilizar**: Orbit es multi-módulo y usa un `go.work` para "desarrollar por separado, construir junto". Es exactamente el modelo que se eleva a nivel suite.

---

## 2. Decisiones base (confirmadas)

| # | Decisión | Elegido | Implicación |
|---|---|---|---|
| D1 | Estrategia de código | **Multi-repo + paraguas** | Los tres repos siguen separados con releases propias; se añade un repo `quantum` ligero de coordinación. Mínima disrupción. |
| D2 | Documentación | **Sitio único** con selector de versión Quantum + versión real de cada módulo visible debajo | Una marca y un deploy; el versionado independiente por módulo se conserva. |
| D3 | Significado de "fusión" | **Presentación primero → suite** | Unificar marca, docs y convenciones ya; la release coordinada (Quantum 1.0) es un hito posterior, no el primer paso. Quark se mantiene usable en cualquier app Go. |

Estas decisiones se documentan como ADRs en el repo `quantum` (ver §9) para que no se reabran sin un sucesor.

---

## 3. El modelo "paraguas" en detalle

El repo `quantum` **coordina, no contiene**. Analogía: una distro de Linux no incluye el código de cada paquete; publica un manifiesto que fija qué versiones, probadas juntas, forman una release. Quantum es esa distro; Quark/Nucleus/Orbit son los paquetes.

```
quantum/                      ← repo nuevo, ligero
├── versions.yaml             ← manifiesto: qué trío compatible = qué release Quantum
├── go.work                   ← desarrollo local cruzado de los 3 a la vez
├── README.md                 ← front page de la suite
├── docs/                     ← ADRs y guías a nivel suite (no las de cada producto)
├── website/                  ← sitio Docusaurus unificado (ensambla las docs de cada repo)
├── .github/workflows/        ← deploy del sitio + CI de integración del set fijado
└── scripts/                  ← bump coordinado, sync de docs, validación del manifiesto

quark/      (repo aparte, intacto)   ── release propia, usable solo
nucleus/    (repo aparte, intacto)   ── release propia
orbit/      (repo aparte, intacto)   ── release propia
```

Lo que el paraguas **sí** hace: fija conjuntos compatibles, da un `go.work` para trabajar a la vez, aloja el sitio de docs unificado, y centraliza convenciones (commits, plantillas de CI, tema de docs).

Lo que el paraguas **no** hace: no absorbe el código, no tiene el `go.mod` de los productos, no decide sus subversiones, y no condiciona que `go get github.com/jcsvwinston/quark` siga funcionando para cualquiera.

### 3.1 `versions.yaml` (el corazón del modelo)

```yaml
# quantum/versions.yaml
quantum: "0.1.0"            # versión de la SUITE (semver propio, ver §4)
released: 2026-06-22
modules:
  quark:   "v1.1.5"        # versiones reales que la gente instala
  nucleus: "v0.9.0"
  orbit:   "v0.1.0"        # ya publicado
compat:
  notes: "Set verificado por el CI de integración del repo quantum."
```

Cada release Quantum es un commit/tag sobre este fichero. Entre releases Quantum, cada módulo saca subversiones libremente; el manifiesto solo se actualiza cuando se quiere certificar un nuevo trío.

### 3.2 `go.work` compartido

```go
// quantum/go.work — para desarrollo cruzado en local
go 1.26

use (
    ./quark      // checkout local (submódulo o clon hermano)
    ./nucleus
    ./orbit
    ./orbit/agent
    ./orbit/proto
    ./orbit/server
)
```

El `go.work` **no se publica** como dependencia: es una conveniencia de desarrollo. En release, cada módulo resuelve sus dependencias por tag real (no por `replace`). Es el mismo principio que ya usa Orbit internamente.

---

## 4. Modelo de versionado

Dos niveles, y ninguno pisa al otro:

**Nivel módulo (independiente).** Cada repo mantiene su propio SemVer y su propia cadencia. `Quark v1.1.6`, `Nucleus v0.9.1`, `Orbit v0.1.1` salen cuando cada uno esté listo, sin coordinación. Esto es lo que protege que Quark siga siendo un ORM usable en solitario.

**Nivel suite (paraguas).** Quantum tiene su propio SemVer, que **no** es el de ningún módulo: es la versión del *manifiesto*.

- **Hoy → Quantum 1.0**: fase de pre-fusión. El paraguas vive en `0.x`, pinta conjuntos compatibles y unifica la presentación. No reclama "major compartido" todavía, porque Nucleus y Orbit aún no son 1.0.
- **Quantum 1.0.0** = hito de convergencia: requiere `Nucleus ≥ 1.0` y `Orbit ≥ 1.0`. Como Quark ya está en major 1, converger significa **subir Nucleus y Orbit hasta alcanzar a Quark** y, a partir de ahí, bloquear el paso.
- **Desde Quantum 1.0**: se aplica tu regla en sentido estricto — un major de Quantum (→ v2) implica que los tres cruzan a major 2 a la vez, con su guía de migración. Los minors/patches de cada módulo siguen flotando entre releases Quantum.

Resumen de la regla: **las subversiones avanzan por separado; los majors solo se cruzan en una release Quantum coordinada.**

---

## 5. Modelo de documentación unificada

Objetivo (D2): un solo sitio, una sola marca, selector de versión Quantum arriba y versión real de cada módulo visible en su sección.

### 5.1 Arquitectura

- **Un Docusaurus multi-instancia** en el repo `quantum` (`website/`), usando varias instancias de `plugin-content-docs` (una por producto: quark, nucleus, orbit) bajo una sola navbar con *product switcher*.
- **La fuente de las docs sigue viviendo en cada repo de producto.** Esto es innegociable: respeta la regla dura de Quark ("API y docs se modifican en el mismo PR", ADR-0008). El sitio del paraguas **ensambla** esas docs (vía submódulo git o un paso de sync en CI que las copia en build-time), no las posee.
- **Selector de versión doble**: el dropdown principal elige versión *Quantum*; cada sección de producto muestra además su tag real (`quark v1.1.5`, …) tomado de `versions.yaml`.
- **Un único deploy**: GitHub Pages desde `quantum` en `/quantum/` (o dominio propio). Los tres Pages actuales se retiran y se redirigen a la sección correspondiente del sitio unificado.

### 5.2 Qué hay que migrar

- **Quark**: 41 docs + 13 snapshots versionados → entran como instancia `quark` conservando su histórico de versiones.
- **Nucleus**: 15 docs sin versionar → instancia `nucleus`; se versiona por primera vez al cortar su release de alineación.
- **Orbit**: hoy solo READMEs dispersos (`proto/`, `server/`, `agent/`) + una landing → hay que **escribir** la instancia `orbit` desde esos READMEs (es el mayor hueco de contenido).

---

## 6. Cómo se trabaja el día a día (sin fricción)

**Trabajo en un solo producto (el caso normal):** nada cambia. Se clona el repo, se trabaja, se saca su subversión. La regla de Quark (tests en los 6 motores, conventional commits, docs en el mismo PR) sigue intacta dentro de su repo.

**Trabajo que cruza módulos:** se clona el meta-repo `quantum` (que trae los tres como submódulos/hermanos), el `go.work` los enlaza, y se desarrolla contra versiones aún sin publicar. Al terminar, cada cambio se hace PR en *su* repo; el `replace`/`go.work` nunca se commitea en los `go.mod` de release.

**CI en dos planos:**

- *Por repo* (existente): cada uno valida lo suyo (Quark, su matriz de 6 motores bloqueante; etc.).
- *De integración* (nuevo, en `quantum`): construye el trío fijado en `versions.yaml`, corre un *smoke* que monta Nucleus + Quark + Orbit juntos, y falla si el set no compila o no pasa. Aquí encaja de forma natural la *superapp* de aceptación cross-engine que Quark ya está construyendo.

---

## 7. Plan por fases

Cada fase es **entregable de forma independiente** y **compatible con el desarrollo normal de cada producto** (no congela ninguna cadencia). El orden es de menor a mayor riesgo.

### Fase 0 — Cimientos sin riesgo
No toca el código de ningún producto.
- Crear el repo `quantum` con `README`, `versions.yaml` (documentando el estado actual tal cual), `go.work`, y los tres como submódulos.
- Terminar el rename de Nucleus pendiente: carpeta `GoFrame/` → `nucleus/`, borrar `NUCLEUS_RENAME_BRIEF.md`, renombrar el repo en GitHub.
- **Hecho cuando:** `go build ./...` desde `quantum` compila los tres juntos vía `go.work`.

### Fase 1 — Identidad Quantum
- Decidir y aplicar marca: nombre, relación visual entre los tres pilares, README-portada de la suite.
- Sin tocar las APIs; solo presentación y narrativa "suite".
- **Hecho cuando:** existe una front page de Quantum que nombra y enlaza los tres pilares y explica que Quark también es usable en solitario.

### Fase 2 — Docs unificadas (el núcleo de D2)
- Montar el Docusaurus multi-instancia en `quantum/website/` con product switcher y doble selector de versión.
- Ensamblar las docs de cada repo (submódulo o sync en CI); migrar contenido de Quark (con su histórico) y Nucleus.
- Un solo deploy en `/quantum/`; redirects desde `/quark/` y `/nucleus/`.
- **Hecho cuando:** un solo sitio sirve las tres docs bajo una marca, sin que la fuente salga de cada repo.

### Fase 3 — Convenciones compartidas y primer tag de Orbit
- Homogeneizar el tooling de release: llevar `release-please` (el patrón de Quark) a Nucleus y Orbit; unificar conventional commits y plantillas de CI.
- Escribir la instancia de docs de Orbit desde sus READMEs (`proto/`, `server/`, `agent/`). Orbit ya tiene su primer tag `v0.1.0`.
- Primera **release Quantum 0.1.0**: primer trío certificado en `versions.yaml` + CI de integración en verde.
- **Hecho cuando:** los tres comparten convenciones y existe un set Quantum reproducible y verificado.

### Fase 4 — Integración demostrada
- Reponer un ejemplo real Nucleus + Quark + Orbit (el `showcase_demo` se había eliminado) como prueba viva de la suite.
- Extender la superapp cross-engine para cubrir el montaje conjunto en el CI de integración.
- **Hecho cuando:** hay un ejemplo ejecutable y un CI que ejerce los tres juntos.

### Fase 5 — Convergencia de versión (Quantum 1.0)
- Cuando Nucleus y Orbit maduren: llevarlos a `v1.0` para alcanzar a Quark.
- Cortar **Quantum 1.0.0**: inaugura el régimen de major compartido. Desde aquí, los majors se mueven en lockstep.
- **Hecho cuando:** los tres están en major 1 bajo un manifiesto Quantum 1.0 y la regla de majors-juntos queda activa.

---

## 8. Qué se preserva (reglas que el plan NO rompe)

- **Quark usable en solitario**: su repo, su `go get`, su release y sus docs standalone siguen existiendo. Quantum solo lo presenta *además* como pilar.
- **Reglas duras de Quark intactas**: tests en los 6 motores bloqueantes, conventional commits, **docs en el mismo PR que la API** (por eso la fuente de docs no sale de cada repo), y la cultura anti-hype.
- **Cadencia independiente**: ninguna fase obliga a coordinar subversiones. La coordinación solo aparece en los puntos Quantum.
- **Versiones honestas**: el número que la gente instala (`vX.Y.Z` de cada módulo) nunca se falsea para encajar en la marca.

---

## 9. ADRs de la suite (`quantum/docs/adr/`)

Para no reabrir lo ya decidido sin un sucesor (mismo criterio que Quark).
Redactados en Fase 0 (QADR-0001…0004); ampliados el 2026-07-01 con 0005 y 0006:

- **QADR-0001** — Multi-repo + paraguas de coordinación (no monorepo).
- **QADR-0002** — Versionado en dos niveles: módulos independientes, suite coordina majors.
- **QADR-0003** — Docs: sitio único que ensambla, fuente en cada repo (preserva ADR-0008 de Quark).
- **QADR-0004** — `versions.yaml` como manifiesto de releases Quantum.
- **QADR-0005** — Secuenciación: Nucleus a v1.0 primero, Orbit en lockstep como arnés de dogfooding.
- **QADR-0006** — Integración Quark↔Orbit: feed SQL en tiempo real (bus + OTel) y Data Studio sobre Quark.

Decisiones internas de producto: en el repo de cada uno (p. ej.
`orbit/docs/adrs/ADR-001` — Data Studio agnóstico del origen de datos).

---

## 10. Próximos pasos inmediatos

1. Crear el repo `quantum` con `versions.yaml` (estado actual) y `go.work` de los tres — Fase 0.
2. Cerrar el rename de Nucleus (`GoFrame/` → `nucleus/`, borrar el brief, renombrar en GitHub).
3. Redactar QADR-0001…0004 con las decisiones de §2.
4. Decidir el nombre/dominio del sitio unificado (`/quantum/` en `jcsvwinston.github.io` o dominio propio) para arrancar Fase 2.

> Nota de alcance: este documento es el plan. La ejecución de la Fase 0 (crear el repo, el manifiesto y el `go.work`) puede empezar sin tocar una sola línea de Quark, Nucleus u Orbit.

---

## 11. Secuenciación e integración Quark↔Orbit (addendum 2026-07-01)

Con la Fase 0 hecha y el trío al día, se fija el **orden de trabajo** hacia Quantum 1.0 y la **integración de Quark** en la suite. Detalle en los QADR; resumen:

**Secuenciación ([QADR-0005](adr/QADR-0005-secuenciacion-convergencia.md)).** Nucleus se lleva a v1.0 (freeze de API) *antes* que Orbit, porque Orbit está aguas abajo: consume 15 paquetes de Nucleus y lo fija por *pseudo-version* (ver `versions.yaml`). Orbit se desarrolla **en lockstep** como arnés de dogfooding que valida el freeze, no en serie. Quark converge por el paraguas (ya es major 1, autónomo), no por el grafo de dependencias. El camino de Nucleus a v1.0 ya está en marcha (sus `docs/adrs/ADR-014/015/018` cierran bloqueadores conocidos).

**Integración Quark↔Orbit ([QADR-0006](adr/QADR-0006-integracion-quark-orbit.md)).** Dos casos:

- *Feed SQL en tiempo real* — un `quark.Middleware` ctx-aware publica las sentencias que ejecuta Quark en el bus de Nucleus (que Orbit ya drena). Prerrequisito: Nucleus expone un *ingest* SQL público (`observability.Bus.Emit` ya existe por dentro; falta destaparlo en la superficie del `Runtime`). OTel en paralelo para el trazado durable. Puente en módulo opt-in `orbit/quarkbridge`, fuera de los cores.
- *Data Studio sobre Quark* — el panel de Orbit se desacopla de los tipos de Nucleus con un contrato neutral (`datasource`, ver [`orbit/docs/adrs/ADR-001`](../orbit/docs/adrs/ADR-001-datastudio-agnostic-datasource.md)); un adaptador Quark lo implementa después. Se congela en el v1.0 de Orbit.

Esto no rompe §8: Quark sigue usable en solitario, las versiones siguen siendo honestas, y el puente vive fuera de los cores de Quark y de Nucleus.
