# Suite Quantum — madurez como plataforma

Auditoría del repo paraguas `/Users/jcsv/GolandProjects/quantum` sobre el set certificado **Quantum 1.26.0** (quark v1.10.0 · nucleus v1.23.0 · orbit v1.8.17), 2026-09-03. Foco: la suite como producto (embudo, sitio, tren, gobernanza, coherencia, ecosistema), no el código de los pilares. Todo lo afirmado se leyó en ficheros reales o se ejecutó (§6).

## 1. Veredicto

Quantum es hoy un **proyecto de una persona con disciplina de release de nivel industrial y superficie de plataforma de nivel hobby**: el set certificado, los 28 guards que muerden, el tren scriptado y el sitio unificado con búsqueda y versionado están por encima de lo que ofrecen Buffalo/Beego/Goa; lo que falta es todo lo que convierte un framework en plataforma (starter de suite, ecosistema, comunidad, cadena de suministro firmada, políticas de soporte públicas) y, más urgente, **el arco D3 dejó el propio paraguas contándose dos historias**: el README, `RUMBO.md`, la página de instalación, `print-requires.sh`, el `go.work` y el `train.sh` siguen pensando en 9 módulos y build tags mientras `versions.yaml` certifica 25 módulos y sin build tags. El quickstart de 15 minutos **funciona de punta a punta tal cual** (verificado: API, login, feed en vivo con INSERTs de Quark, Data Studio con `Author`/`Article`), pero su receta de driver es la de antes de D3 y degrada en silencio el clasificador de unicidad. El consumidor de referencia externo (`quantum-app`) **no recibió el set 1.26.0**: el dispatch D6 falló al abrir el PR.

| Dimensión | Nota (1-5) | Una línea |
|---|---|---|
| Embudo de entrada | **3** | Quickstart real y verificado; sin starter de suite; instalación post-D3 incompleta; ~14 comandos, 4 ficheros, ~12 conceptos. |
| Sitio / docs | **3** | Construye en 25 s, 0 enlaces rotos, búsqueda local, 3 selectores de versión; sirve páginas con claims retirados (build tags) y no hay tutoriales por caso de uso ni comparativa de suite. |
| Tren / releases | **3** | Mecanizado y vigilado como pocos proyectos Go; sigue costando ~2 h/set, `train.sh` no clasifica los 17 módulos nuevos y el anuncio a `quantum-app` está roto. |
| Gobernanza / seguridad de cadena | **2** | govulncheck en los 3 CI y SECURITY.md en los 3 productos; sin Dependabot/Renovate, sin SBOM/firma/provenance, paraguas sin SECURITY/CONTRIBUTING, bus factor = 1. |
| Coherencia entre pilares | **2** | Seis contradicciones vivas sobre D3 entre README, RUMBO, docs servidas de nucleus, install page y scripts. |
| Ecosistema / comunidad | **1** | 0 stars, 0 forks, 0 integraciones de terceros, Discussions desactivadas en los 4 repos, sin blog. |
| Posicionamiento | **3** | «Cuándo NO usar la suite» y la topología son honestos y claros; falta el «por qué Quantum y no Django/Encore» a nivel suite, casos de uso y guías de migración. |

## 2. Tabla comparativa

Leyenda: ✅ existe y se verificó · partial · ❌ no existe. La celda Quantum cita el fichero que lo prueba.

| Capacidad de plataforma | Quantum | Django | Rails / Laravel | Spring Boot | Encore / Supabase |
|---|---|---|---|---|---|
| CLI de scaffolding (`new`) | ✅ `nucleus new --template mvc\|api` (`nucleus/internal/cli/new.go:23`) | ✅ | ✅ / ✅ | ✅ Initializr | ✅ / ✅ |
| Starter que cablea la suite entera | ❌ ninguno; el quickstart cablea a mano (`website/docs/quickstart.md`, 14 comandos) | n/a | ✅ Breeze/Jetstream | ✅ starters | ✅ templates |
| Generadores (módulo/modelo/migración) | ✅ `nucleus generate module` (RUMBO §3, `nucleus/website/docs/cli/overview.md`) | ✅ | ✅ / ✅ | ❌ | ✅ / partial |
| Migraciones | ✅ SQL versionadas (nucleus) + schema-as-code (quark) | ✅ | ✅ / ✅ | partial (Flyway) | ✅ / ✅ |
| Capa de datos tipada | ✅ Quark, 6 motores (`README.md:110-127`) | ✅ | ✅ / ✅ | ✅ JPA | n/a / ✅ |
| Panel de administración | ✅ Orbit in-process (`orbit/README.md`) | ✅ | ❌ (3rd) / partial (Nova pago) | ❌ | ❌ / ✅ Studio |
| Auth completo (registro, reset, verificación) | partial — sesiones/JWT/LDAP sí; módulo `accounts` pendiente (RUMBO D4) | ✅ | ✅ / ✅ | partial | ✅ / ✅ |
| Autorización (RBAC) | ✅ Casbin default-deny (`nucleus.yml` del scaffold) | ✅ | partial / ✅ | ✅ | ✅ / ✅ RLS |
| Multi-tenancy nativa | ✅ nucleus + quark (DB/schema/RLS) | ❌ (3rd) | ❌ / ❌ | ❌ | ❌ / partial |
| Jobs y scheduler | ✅ Asynq+Redis, outbox (`README.md:97-101`) | partial (Celery) | ✅ / ✅ | partial | ✅ / partial |
| Mail, i18n, storage | ✅ `pkg/mail`, `makemessages`, providers S3/GCS/Azure | ✅ | ✅ / ✅ | partial | partial / ✅ |
| Observabilidad (OTel, /metrics) | ✅ exporters como módulos (`versions.yaml` nucleus_modules) | partial | partial / partial | ✅ Actuator | ✅ / partial |
| Realtime (websockets/SSE/canales) | ❌ 0 menciones en `nucleus/website/docs` | ❌ (Channels aparte) | ✅ / partial | partial | ✅ / ✅ |
| OpenAPI / cliente generado | partial — 4 páginas lo mencionan, sin generador verificado | partial (DRF) | partial / partial | ✅ | ✅ / ✅ |
| Helpers de testing | ✅ `nucleustest`/`quarktest` (`nucleus/website/docs/getting-started/testing.md`) | ✅ | ✅ / ✅ | ✅ | ✅ / partial |
| Sitio de docs versionado + búsqueda | ✅ Docusaurus, 3 instancias versionadas, `@easyops-cn/docusaurus-search-local` (`website/docusaurus.config.ts:121`) | ✅ | ✅ / ✅ | ✅ | ✅ / ✅ |
| Tutoriales por caso de uso (SaaS, API-only, MVC) | partial — 1 quickstart integrador + `showcase_demo`; nada por caso de uso | ✅ | ✅ / ✅ | ✅ guides | ✅ / ✅ |
| Página «por qué X» / comparativa | partial — solo Quark vs GORM/sqlx/Ent (`quark/website/docs/reference/comparison.mdx`) | ✅ | ✅ / ✅ | partial | ✅ / ✅ |
| Benchmarks públicos | partial — solo Quark (`quark/website/docs/reference/benchmarks.mdx`) | ❌ | ❌ / ❌ | ❌ | ✅ / partial |
| Guías de migración desde otros frameworks | ❌ | partial | ✅ / ✅ | ✅ | ✅ / ✅ |
| Ecosistema de paquetes/plugins de terceros | partial — SDK de plugins v1 (`nucleus-plugin-<provider>`), 0 terceros | ✅ | ✅ / ✅ | ✅ | partial / ✅ |
| Hosting / PaaS propio | ❌ | ❌ | ❌ / ✅ Forge | ❌ | ✅ / ✅ |
| Artefactos de despliegue (imagen, Helm) | partial — binarios CLI con goreleaser (`nucleus/.goreleaser.yaml`), sin imagen oficial | ❌ | partial / partial | ✅ buildpacks | ✅ / ✅ |
| Set de compatibilidad certificado (estilo distro/BOM) | ✅ `versions.yaml` + manifest-guard + tag de suite — **diferenciador** | ❌ | ❌ / ❌ | ✅ BOM | partial / n/a |
| Automatización de releases | ✅ release-please + `scripts/train/` | ✅ | ✅ / ✅ | ✅ | ✅ / ✅ |
| SBOM / firma / provenance | ❌ solo `checksums.txt` sha256 (`nucleus/.goreleaser.yaml:29-31`) | partial | partial / partial | ✅ | ✅ / partial |
| Bots de dependencias | ❌ ningún `dependabot.yml`/`renovate.json` en los 4 repos | ✅ | ✅ / ✅ | ✅ | ✅ / ✅ |
| Escaneo de vulnerabilidades en CI | ✅ govulncheck en quark/nucleus/orbit (`*/.github/workflows/ci.yml`) | partial | partial / partial | ✅ | ✅ / ✅ |
| Política de seguridad y canal privado | ✅ 3 productos; ❌ paraguas (health 42 %) | ✅ | ✅ / ✅ | ✅ | ✅ / ✅ |
| Política de soporte / LTS | partial — «últimos dos minors» (`*/SECURITY.md`), sin LTS, sin política de suite | ✅ LTS | ✅ / ✅ | ✅ | partial / ✅ |
| Política de deprecación / compat | partial — nucleus `COMPATIBILITY_SLO.md` + `DEPRECATION_TEMPLATE.md`; nada a nivel suite | ✅ | ✅ / ✅ | ✅ | ✅ / ✅ |
| Roadmap público | partial — `docs/RUMBO.md` en español dentro del repo; quark tiene página | ✅ | ✅ / ✅ | ✅ | ✅ / ✅ |
| Comunidad (Discussions/Discord/foro) | ❌ `has_discussions:false` en los 4 repos | ✅ | ✅ / ✅ | ✅ | ✅ / ✅ |
| Blog / anuncios de release humanos | partial — releases de suite narrativas; `blog:false` en el sitio; releases de producto = changelog crudo | ✅ | ✅ / ✅ | ✅ | ✅ / ✅ |
| Bus factor | **1** (100 % de commits humanos en los 4 repos: `git shortlog`) | >50 | >50 | >100 | equipo |

## 3. Lo que falta para competir

**Bloqueante (sin esto el evaluador de la primera hora se va):**
- Un **starter de suite**: `nucleus new blog --with orbit,quark` (o `--template suite`) que escriba lo que el quickstart pide teclear en 14 comandos y 4 ficheros. Hoy es el único framework de la comparativa donde «la suite» se monta a mano.
- La **página de instalación y el bloque `require` alineados con D3**: sin driver module no arranca ninguna app y la página no lo menciona (QM-3).
- **Una sola historia sobre D3** en README, RUMBO, docs servidas de nucleus y scripts (QM-1, QM-4, QM-5, QM-6, QM-8). Un evaluador que lea «MSSQL tras build tags» y luego `nucleus add sqlserver` deja de fiarse de todo lo demás.
- **Cadena de suministro mínima**: Dependabot en los 4 repos y firma/SBOM/provenance de los binarios que goreleaser ya publica (QM-14). Es el punto que cualquier evaluación corporativa mira primero.

**Diferenciador (lo que Quantum puede contar que otros no):**
- El **set certificado** es un concepto que sólo Spring (BOM) tiene y ningún framework Go ofrece; falta contarlo como ventaja en la portada y no sólo como mecánica.
- **Multi-tenancy y RLS nativos en framework + ORM + admin**, coherentes de punta a punta. Un tutorial «SaaS multi-tenant en 30 minutos» lo haría visible.
- **28 guards que muerden + guard-of-guards**: publicar el régimen de certificación mecánica como garantía de calidad de doc (nadie más verifica que sus quickstarts se ejecuten contra el set publicado).
- **Grafo adelgazado medido** (19 MB / 87 módulos): cifras verificables que Gin+GORM+admin de terceros no pueden igualar.

**Nice-to-have:**
- Realtime (SSE/websockets) en nucleus con feed hacia Orbit.
- OpenAPI generado desde `nucleus.Module` y cliente TS.
- Imagen Docker oficial y Helm chart para la app generada; guía de despliegue por proveedor.
- Comparativa honesta a nivel suite (vs Django+DRF+admin, vs Encore, vs Gin+GORM+Casbin), guías de migración desde Gin/GORM.
- Blog de releases en inglés (hoy las notas de quark/orbit salen en español desde release-please) y Discussions como único punto de entrada.
- Política de soporte y LTS publicada a nivel suite (qué sets reciben parches y durante cuánto).

## 4. Mejoras propuestas

### Corto plazo (≤ 1 mes)

| # | Mejora | Esfuerzo | Valor | Dependencia |
|---|---|---|---|---|
| C1 | Cerrar los 6 defectos de coherencia D3 (QM-1, QM-3, QM-5, QM-6, QM-11, QM-12) en un solo PR del paraguas + un patch de docs en nucleus (QM-4) y corte de set fuera de cadencia (razón QADR-0008: contrato cross-producto incoherente). | 1-2 días | Alto | ninguna |
| C2 | Arreglar D6: habilitar «Allow GitHub Actions to create PRs» en `quantum-app` (o PAT/App), y que `train.sh cierre` haga `gh run watch` del dispatch en vez de fire-and-forget (QM-2). | ½ día | Alto | permisos del repo |
| C3 | `go.work` y `integration.yml` derivados del árbol (`find -name go.mod`), con guard «go.work ⊇ módulos publicables» (QM-7). | 1 día | Alto | ninguna |
| C4 | `train.sh` clasifica cualquier `release <ruta> X.Y.Z` como módulo y ordena hojas→root por dependencias (QM-8); `align_set.sh` para nucleus y quark (deuda de RUMBO, quita los 16 AVISOs de manifest-guard). | 2 días | Alto | C3 |
| C5 | Quickstart y `showcase_demo` con `quark/drivers/sqlite` + `nucleus/drivers/sqlite`, y smoke que exija el clasificador registrado (QM-9); scaffold sin WARN de Prometheus (QM-10). | 1 día | Medio | ninguna |
| C6 | Dependabot (gomod + github-actions) en los 4 repos; `govulncheck` pinado en quark/orbit. | ½ día | Medio | ninguna |
| C7 | Paraguas: SECURITY.md (apunta a los tres advisories), CONTRIBUTING.md (tren + guards), CODE_OF_CONDUCT, plantillas de issue/PR en los 3 repos que faltan; activar Discussions sólo en `quantum`. | 1 día | Medio | ninguna |
| C8 | Guard «claims retirados» sobre el HTML servido (`-tags mssql`, `build tags`, `single Go module`, `Nine modules`), hermano de `check_served_jargon.sh`, con fixture. | ½ día | Medio | ninguna |

### Medio plazo (1-3 meses)

| # | Mejora | Esfuerzo | Valor | Dependencia |
|---|---|---|---|---|
| M1 | **Starter de suite**: `nucleus new --with orbit,quark[,quarkbridge,quarkdatasource]` que genere exactamente la app del quickstart; el quickstart pasa a «lee lo que se generó». | 1-2 semanas | Muy alto | C5 |
| M2 | Firma y provenance: goreleaser `sboms:` + `signs:` (cosign keyless) + `actions/attest-build-provenance`; tags de suite firmados. | 3 días | Alto | C6 |
| M3 | Tutorial «SaaS multi-tenant» (nucleus + quark RLS + Orbit por tenant) y «API-only con `--template api`»; ambos como ejemplos ejecutados por `showcase_smoke`-like en `integration.yml`. | 2 semanas | Alto | M1 |
| M4 | Página «Why Quantum» a nivel suite con comparativa honesta (Django+DRF, Encore, Gin+GORM+Casbin) y las cifras del grafo; portada que venda el set certificado como ventaja. | 1 semana | Alto | ninguna |
| M5 | Política pública de soporte de suite: qué sets reciben parches, ventana, cómo se anuncia un EOL; deprecation policy a nivel suite (hoy sólo nucleus). | 3 días | Medio | ninguna |
| M6 | Release notes de producto en inglés (convención de commits en inglés o post-proceso) y un canal de anuncios (blog Docusaurus `blog:true` con una entrada por set). | 1 semana | Medio | ninguna |
| M7 | Coste del tren: `train.sh` sin paradas manuales para las deudas de doc (generar la sección `## vX.Y.Z` y el snapshot desde el release PR), objetivo < 30 min/set. | 2 semanas | Alto | C4 |

### Largo plazo (3-12 meses)

| # | Mejora | Esfuerzo | Valor | Dependencia |
|---|---|---|---|---|
| L1 | Ecosistema: registro de providers/plugins de terceros (`nucleus add` con catálogo remoto), 2-3 integraciones oficiales fuera del core (Stripe/webhooks, S3 ya está). | 1-2 meses | Alto | M1 |
| L2 | Realtime (SSE/websockets) en nucleus con feed en Orbit; OpenAPI + cliente TS generado desde módulos. | 2 meses | Alto | ninguna |
| L3 | Imagen Docker oficial, Helm chart y guía por proveedor para la app generada; `nucleus deploy` opcional. | 1 mes | Medio | M1 |
| L4 | Reducir el bus factor: un segundo mantenedor con permisos de merge y de release, runbook del tren probado por alguien que no lo escribió. | continuo | Muy alto | M7 |
| L5 | Programa de adopción: 3 usuarios externos reales (no `quantum-app`) con casos publicados; hasta entonces no hay señal de que la suite funcione fuera de su autor. | 6-12 meses | Muy alto | M1, M3, M4 |

## 5. Defectos encontrados

| id | Sev | Fichero:línea | Evidencia | Corrección propuesta |
|---|---|---|---|---|
| QM-1 | **P1** | `scripts/print-requires.sh:47-52` | Emite `nucleus/providers/<clave>` para TODA clave de `nucleus_modules`: `github.com/jcsvwinston/nucleus/providers/mssql v0.1.0`, `…/providers/otlp`, `…/providers/prometheus` (rutas inexistentes; son `drivers/` y `exporters/`). Omite `quark_modules`. El self-check cuenta líneas, no rutas. El run 33778338017 de `quantum-app` las recibió y las descartó («no consumido por este repo»). | Derivar clave→ruta del árbol al pin (como hace `manifest-guard`) o tabla explícita; incluir `quark_modules`; self-check que compruebe que cada ruta tiene `go.mod` en el submódulo. |
| QM-2 | **P1** | `scripts/train/dispatch-app-bump.sh:58-90`, `scripts/train/train.sh:238-247`; repo `quantum-app` | `gh run list -R jcsvwinston/quantum-app`: run `quantum-set-certified` de 2026-09-03 16:23 **failure**: «GitHub Actions is not permitted to create or approve pull requests». La rama `chore/set-1.26.0` existe, el PR no. RUMBO §0 y QADR-0008 afirman «el anuncio abre su PR». | Activar el ajuste del repo en `quantum-app` (o PAT/GitHub App); `train.sh cierre` espera el run (`gh run watch`) y falla si el dispatch no acaba en PR. |
| QM-3 | **P1** | `website/docusaurus.config.ts:22-40`; `website/docs/install.md:43-53,62-70`; servido en `build/start/install/index.html` | `requireBlock` sólo con 9 módulos (3 pilares + ldap + 5 de orbit); «Nine modules make up a certified set»; la tabla «Which module do I actually need?» no tiene fila para drivers/exporters/providers; 0 menciones de `drivers/sqlite` en la página. Tras D3 ninguna app arranca sin un módulo de driver. | Generar el bloque desde los cuatro bloques del manifiesto con mapa de rutas; filas «Base de datos → `nucleus/drivers/*`, `quark/drivers/*`», «Prometheus → `exporters/prometheus`»; mencionar `nucleus add`. |
| QM-4 | **P1** | `nucleus/website/docs/concepts/models-and-database.md:41-42`, `getting-started/installation.md:63`, `concepts/configuration.md:149`, `architecture/principles.md:119`, `architecture/compatibility.md:145`; `nucleus/README.md:24,67-68,297` | Al pin certificado (v1.23.0) y también en `origin/main`: «MSSQL and Oracle are opt-in via Go build tags (`-tags mssql`)», «ships as a single Go module». El sitio lo sirve en 7 páginas de la versión actual de nucleus. `versions.yaml notes` y la release v1.26.0 dicen «Desaparecen además los build tags». | Reescribir en nucleus (patch) y corte de set fuera de cadencia; en el paraguas, guard de claims retirados sobre el HTML servido (ver C8). |
| QM-5 | **P1** | `README.md:76` y `README.md:91` vs `README.md:137-152` | Mismo fichero: «Se distribuye como un único módulo Go» / «MSSQL y Oracle son exploratorios tras build tags» y 60 líneas después «Los tres productos son multi-módulo… Desaparecen los build tags». `manifest-guard §4` sólo verifica las tablas de versiones. | Reescribir §Nucleus; extender §4 (o C8) a frases retiradas en el README. |
| QM-6 | **P1** | `docs/RUMBO.md:14-16` vs `versions.yaml:7` y `docs/RUMBO.md:39` | «Estado real (2026-08-31) — Set certificado: Quantum 1.25.0 … quark v1.8.0 · nucleus v1.22.0 · orbit v1.8.14» mientras el manifiesto dice 1.26.0 y el propio RUMBO §1 dice «CERRADO Y PUBLICADO en Quantum 1.26.0». Incumple su regla de mantenimiento (línea 9-12). | Actualizar cabecera; assert en `check_suite_tag.sh` de que «Set certificado: Quantum X» == `quantum:`. |
| QM-7 | P2 | `go.work:11-22`; `.github/workflows/integration.yml:47`; `README.md:239-246` | `go.work` usa 10 módulos; el árbol tiene 28 (`find -name go.mod`): faltan los 12 hermanos de nucleus, los 5 drivers de quark, `quark/benchmarks`, `quark/bugbash`. `go build ./nucleus/drivers/postgres/...` desde la raíz: «does not contain modules listed in go.work». build/vet/lockstep del CI nunca compilan los 17 módulos publicados al pin. | `use` generado del árbol (excluyendo `examples/`, `benchmarks/`, `bugbash/` a propósito); `MODULES` derivado de `go.work`; guard go.work ⊇ módulos del manifiesto. |
| QM-8 | P2 | `scripts/train/train.sh:127,150-153`; `scripts/bump-set.sh:12,85,107` | La lista de orden sólo conoce `proto/agent/server/quarkbridge/quarkdatasource/providers/ldap`; un PR «chore(main): release drivers/postgres 0.1.0» queda sin clasificar y el driver `die`. `bump-set.sh` lee `m['providers/ldap']` y escribe el comentario del pin nombrando sólo ldap. El tren de D3 (17 módulos) se condujo a mano. | Clasificar `release <ruta> X.Y.Z` como módulo genérico; orden por dependencias del `go.mod`; regenerar comentarios desde el manifiesto completo. |
| QM-9 | P2 | `website/docs/quickstart.md:247-260,308`; `nucleus/examples/showcase_demo/main.go:32`, `go.mod:18-24` | El `main.go` «whole file» importa `_ "modernc.org/sqlite"` y omite `_ "github.com/jcsvwinston/nucleus/drivers/sqlite"` (que el scaffold sí traía); `go get … modernc.org/sqlite` en vez de `quark/drivers/sqlite`. Verificado: arranca igual (modernc registra `sqlite` en `database/sql`, ningún error guiado salta) pero sin los clasificadores de unicidad de quark ni de nucleus — la degradación silenciosa que `versions.yaml notes` describe. `showcase_demo` pina un set atrás (nucleus v1.22.0, quark v1.8.0, orbit v1.8.14, puentes 0.x). | Quickstart con `nucleus add sqlite` + `quark/drivers/sqlite`; re-pin del showcase al set; `showcase_smoke.sh` que exija clasificador (POST duplicado → 409). |
| QM-10 | P2 | `nucleus/internal/cli/scaffold/templates/mvc/nucleus.yml.tmpl:30-33` (efecto en `website/docs/quickstart.md:38-52`) | `nucleus new blog && go run .` arranca con `WARN "metrics are not being served: the Prometheus exporter is not linked into this binary"`. El quickstart muestra un log de arranque sin ese aviso. Primera impresión: la config «no cambia» pero avisa. | Scaffold con `exporters/prometheus` importado o `metrics_path: ""` comentado; quickstart con el log real. |
| QM-11 | P2 | `docs/AUDITORIA_CONTINUA.md:33` y tabla siguiente | «Registro actual (27 guards…)» y la tabla omite `orbit-adr-index`; `guard_names \| wc -l` = 28; `docs/RUMBO.md:20` dice 28. Es la misma deriva que la propia línea confiesa haber tenido (DI-14/RT-10). | Añadir la fila y el número; o generar la tabla desde `guard-registry.sh`. |
| QM-12 | P2 | `versions.yaml:14`; `scripts/print-requires.sh:49`; `docs/AUDITORIA_CONTINUA.md` §1 «Escapes» | «manifest-guard verifica las 9 contra los tags del pin» (son 25); «today the single one, ldap»; «El CI lo lleva puesto hasta el tren de la 7ª» (vacío desde 1.8.0). Son los ficheros que la gente abre para saber qué instalar. | Reescribir sin números que caducan («todos los bloques del manifiesto»). |
| QM-13 | P2 | raíz de `quantum/`; `orbit/`; `nucleus/.github`, `orbit/.github` | Paraguas sin `SECURITY.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, plantillas (community profile 42 %); orbit sin CODE_OF_CONDUCT (71 %); nucleus/orbit sin `ISSUE_TEMPLATE`/PR template; `has_discussions:false` en los 4 repos. | Ver C7. |
| QM-14 | P2 | `nucleus/.goreleaser.yaml:29-31`; `nucleus/.github/workflows/release.yml`; `quark/.github/workflows/ci.yml:199`; `orbit/.github/workflows/ci.yml:169`; los 4 `.github/` | Sólo `checksums.txt` sha256: sin `signs:`, `sboms:`, ni `attest-build-provenance`; ningún `dependabot.yml`/`renovate.json`; `govulncheck@latest` sin pin en quark/orbit (nucleus lo pina a v1.3.0 por una razón documentada); releases de `quantum` sin assets y tags sin firmar. | Ver C6, M2. |
| QM-15 | P3 | `README.md:64,180,214-221` | «los otros tres habilitan observabilidad de flota» y el mermaid «root · proto · agent · server»: orbit tiene 5 módulos hermanos; los dos puentes viven en otra tabla 150 líneas más arriba. | Una sola tabla de módulos de orbit. |
| QM-16 | P3 | `website/docs/certified-sets.md:19-38` | La «frozen illustration» del manifiesto (1.24.0) ya no tiene la forma del manifiesto real (sin `quark_modules`, 12 `nucleus_modules`, puentes en 1.8.x). | Generar el esqueleto desde `versions.yaml` o actualizar la ilustración con la forma post-D3. |
| QM-17 | P3 | `website/docs/install.md:31`, `website/docs/quickstart.md:31`; `.github/workflows/integration.yml:75-100` | `go install …/cmd/nucleus@latest` puede ir por delante del set; el job `go-install-tag` sólo prueba `admin-server`, nunca el CLI `nucleus` al tag certificado. | `@<SuiteVersion of="nucleus" />` en la página; añadir `go install nucleus/cmd/nucleus@<tag>` al job. |
| QM-18 | P3 | releases de `quark`, `orbit`, `nucleus` (release-please) | Cuerpos en español («el error guiado nombra el módulo…») para productos cuyo sitio y README son en inglés (QADR-0007); la release de suite sí es narrativa. | Commits/notas de producto en inglés o post-proceso de notas. |
| QM-19 | P3 | `scripts/manifest-guard.sh` (salida) | 16 AVISOs por corrida (requires de módulos hermanos una o varias releases atrás). Ruido estructural que oculta señal; la deuda «nucleus necesita su align_set.sh» sigue abierta en RUMBO. | `align_set.sh` en nucleus/quark dentro del tren (C4). |

## 6. Resultados de ejecución

Entorno: macOS, Go 1.26.6, Node 20, árbol limpio en `main` @ `2d0fb45`, submódulos al pin.

| Qué | Resultado |
|---|---|
| `bash scripts/manifest-guard.sh` | **OK** en 5,7 s: 3 pilares pin↔tag↔gitlink; 22 módulos hermanos descubiertos y verificados; tablas del README. **16 AVISOs** (requires de hermanos por detrás: 11 en nucleus a v1.22.0/v1.21.0, 4 drivers de quark a v1.8.0, `quarkdatasource` a orbit v1.8.13). |
| `bash scripts/guard-of-guards.sh` | **OK**: 28 guards registrados, 28 fixtures, 28 muerden. |
| `go build` de los 10 patrones de `integration.yml` | **EXIT 0** en 7,8 s (caché caliente). Los 17 módulos D3 y `quark/benchmarks`, `quark/bugbash` no están en `go.work` → no se compilan (QM-7). |
| `cd website && npm run build` | **OK en 25 s** (Docusaurus 3.10.1; sí arranca en este sandbox): 1034 páginas; snapshots servidos quark 8/21, nucleus 15/15, orbit 3/3. |
| `check_built_links.sh website/build` | OK: 883 enlaces a repos propios + 946 internos resuelven. |
| `check_built_codeblocks.sh` / `check_served_jargon.sh` | OK: 0 bloques vacíos de 6 136; 0 fugas de jerga. |
| `check_sidebar_sync.sh` / `check_suite_tag.sh` | OK; `v1.26.0` existe, es ancestro de HEAD y captura los 3 gitlinks. |
| `bash scripts/ci/showcase_smoke.sh` | **OK** en 5,5 s (workspace): POST 201, login, feed con SQL de Quark, Data Studio con Author/Article. Ojo: en workspace resuelve quark v1.10.0 desde fuente; standalone el ejemplo pina quark v1.8.0 (QM-9). |
| Quickstart paso 1 (`nucleus new blog`, CLI construido de fuente, `replace` a checkouts locales, GOWORK=off) | **OK**: scaffold de 6 ficheros, `go mod tidy`, arranca, `/healthz` = `{"status":"healthy",…}`, `/` → 403 (default-deny). Arranca con el WARN de Prometheus (QM-10). Nota: el puerto 8080 estaba ocupado por Docker en esta máquina; se usó `NUCLEUS_PORT`. |
| Quickstart pasos 2-5, variante A (snippets literales: `modernc.org/sqlite`) | **OK funcional**: `GET /api/articles` devuelve el artículo sembrado con la misma forma JSON que la página; `POST` → 201; `/admin/login` 200; POST login → **419 con curl plano** (CSRF: origin check por `Sec-Fetch-Site`), **303 con cabeceras de navegador**; `/admin/api/live/snapshot` contiene 2 `INSERT` sobre `articles` (quarkbridge); `/admin/api/models` lista `Author` y `Article` (quarkdatasource). |
| Variante A′ (el `main.go` «whole file» literal, sin `nucleus/drivers/sqlite`) | Arranca igual: `modernc` registra `sqlite` en `database/sql`, así que ni nucleus ni quark disparan el error guiado. Degradación silenciosa de clasificadores (QM-9). |
| Variante B (`quark/drivers/sqlite` en vez de `modernc`) | OK: compila, arranca, API responde. Es la receta que la página debería dar. |
| Coste del quickstart medido | 5 secciones, **14 comandos de shell, 4 ficheros escritos a mano (~200 líneas), ~12 conceptos** (set certificado, módulo, `Mount`, default-deny, `WithOpenAuthz`, tags `db/pk/quark/rel/join`, `RegisterModel/MigrateRegistered`, datasource, quarkbridge, `OnStart`, `Runtime.Observability`, dos capas de datos). ~15 min con Go en caché es realista; sin caché, la descarga de módulos domina. Sin `nucleus new` con opción de suite ni template de suite; sólo `--template mvc\|api`. |
| GitHub (`gh api`) | 4 repos: 0 stars, 0 forks, Discussions off; quantum health 42 %, quark 100 %, nucleus 85 %, orbit 71 %. `quantum-app`: último dispatch **failure** (QM-2). Commits humanos: 100 % `jcsvwinston` en los 4 repos (bus factor 1). |
| `shellcheck` | no instalado en el sandbox; no se pudo lintar `scripts/`. |
