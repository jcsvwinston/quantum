# Auditoría continua — certificación mecánica de la suite

Runbook interno del paraguas (7ª ronda; §6 y robustez QM8-* desde la 8ª).
Describe qué comprueba la certificación mecánica, cómo se demuestra que los
checks siguen vivos, el procedimiento de cierre de una ronda, qué queda
deliberadamente fuera para el juicio humano — y, desde la 8ª, el régimen
operativo de la auditoría continua (§6): la 8ª pasada fue LA ÚLTIMA manual
completa. El §7 fija las dos reglas con las que nace cada workflow
del paraguas: permisos mínimos del token, y aviso activo si el cron se pone
rojo.

Piezas:

| Pieza | Ruta | Qué hace |
|---|---|---|
| Registro de guards | `scripts/lib/guard-registry.sh` | Única fuente de verdad: nombre → cwd → comando de cada guard, más la aserción anti-fósil. |
| Lane de certificación | `scripts/suite-integral.sh` | Ejecuta TODOS los guards del registro contra el árbol pinado; tabla `guard → EXIT`. Con `--cierre`/`QUANTUM_CERTIFYING=1` exige además que el tag de suite exista y capture HEAD (MAQ-2/B.2). |
| Guard-of-guards | `scripts/guard-of-guards.sh` + `tests/guard-fixtures/` | Ejecuta cada guard contra una fixture de fallo y exige que muera por la causa esperada. |
| CI | `.github/workflows/suite-integral.yml` | Ambos, en PR (paths relevantes — entre ellos todo `.github/workflows/**` y `.github/dependabot.yml`, que es lo que `umbrella-actions-pinned` vigila), a demanda y cada lunes 06:00 UTC. |
| CI de integración | `.github/workflows/integration.yml` | Build + vet del set, lockstep de orbit, `go install @tag` con caché virgen y la lane **quickstart-smoke** (gate del arco A2, abajo) — en PR, push a main y cada lunes 06:30 UTC (QM8-1, escalonado tras suite-integral). |
| Lane quickstart-smoke | `scripts/ci/quickstart_smoke.sh` (job `quickstart-smoke` de integration.yml) | El quickstart de la suite EJECUTADO al set pinado: CLI de nucleus compilado del submódulo, `nucleus new --template suite --with orbit,quark,quarkbridge,quarkdatasource --db sqlite --offline`, build con los hermanos por copia del `go.work` (sin red), arranque, los `curl` EXTRAÍDOS de `website/docs/quickstart.md` con el parser del guard `umbrella-quickstart-cost`, sondas propias (/nope → 404, login admin, INSERT en el feed en vivo, modelos en Data Studio), 0 `level=WARN` en app.log, presupuesto de 60 s (scaffold + build + arranque + curls) sobre la caché de módulos restaurada, `go test ./...` del proyecto y el guard de coste al final. **Salvaguarda:** si el nucleus pinado no conoce `--with` sale 0 con `::notice` — se fusiona antes del tren y se enciende sola al re-pinar; el criterio es el mismo predicado del guard de coste (`qs_nucleus_knows_with`, fuente pinada) y la lane exige además que `nucleus new --help` coincida con él (si discrepan, rojo: el predicado no puede quedarse ciego en silencio). El job `go-install-tag` (caché virgen) corre el mismo script con `QUICKSTART_BUDGET_SECONDS=0` (sólo informa la cifra fría). Arnés, no guard: en `GUARD_SCAN_EXCLUDE` con su porqué. Esta lane arranca su app con `scripts/lib/background-app.sh` (`bg_start`: el subshell hace `exec`, así que el PID que el trap mata es el del servidor — con `(cd … && ./app) &` a secas, bash 3.2 dejaba la app huérfana ESCUCHANDO tras cada corrida local, con su temporal ya borrado); `bg_stop`: TERM, 5 s, KILL — con cota real también para un hijo de la shell, donde `wait` a secas bloquea sin límite: el KILL lo dispara un vigilante, así una app que ignora TERM o se atasca en su parada limpia no cuelga el trap EXIT hasta el timeout del job); autotest `tests/background-app/selftest.sh` (12 aserciones, con un servidor que ignora SIGTERM) como paso 0 de la lane. Desde el 2026-09-12 es además la ÚNICA lane que ejerce los tres productos juntos —la app que lo hacía era `nucleus/examples/showcase_demo`, y el árbol ya no lleva ejemplos— y comprueba, con `scripts/ci/check_quickstart_listings.sh`, que los listados de la página sean lo que el scaffold acaba de escribir. |
| Lane de medida (Scorecard) | `.github/workflows/scorecard.yml` | OpenSSF Scorecard sobre este repositorio, lunes 07:00 UTC y a demanda; sube el SARIF a code scanning y lo guarda como artefacto `scorecard-results`. Es MEDIDA, no guard: no está en el registro y no impone umbral (§8). Su rojo avisa por el mismo canal que las otras dos lanes. |
| Aviso activo del schedule rojo | `scripts/notify_schedule_failure.sh` | En corridas programadas fallidas **o canceladas** (MAQ-4/(c)), las **tres** lanes programadas —`integration.yml`, `suite-integral.yml` y `scorecard.yml`— abren o actualizan un issue `[lane] fallo del schedule <workflow> <fecha>` con el enlace al run. Dedupe **server-side** por etiqueta `lane-schedule-failure` + término de título (MAQ-4/(b): con >100 issues abiertos un `--limit 100` sin filtro duplicaba). Si el propio job de aviso falla, un step de **último recurso** (MAQ-4/(a)) emite `::error::` + resumen del job + issue de título fijo, para que el fallo del notificador no degrade al email default (QM8-1, insuficiente). Que toda lane con `schedule:` lleve el job —y que su `needs` cubra a todos los demás (RT-8)— lo exige el guard `umbrella-schedule-notify`; hasta el arco A3 era costumbre copiada de lane a lane, y la tercera nació sin él. |

## 1. Qué cubre la certificación mecánica

`bash scripts/suite-integral.sh` desde la raíz del paraguas. Precondiciones
(anti-fósil, `declared_lags` vacío, submódulos con historia y tags, build del
sitio) y después los guards del registro, todos, capturando el EXIT de cada
uno sin abortar al primero. EXIT global ≠ 0 si cualquier cosa falló.

Los guards de producto corren **al pin** — el submódulo tal y como lo fija
`versions.yaml`. Un fallo ahí no significa «el CI de otro repo está roto»:
significa que el set que el manifiesto certifica no pasa sus propios guards,
que es exactamente lo que reportaría un auditor.

Registro actual (41 guards — la cifra canónica NO es esta prosa, es el
registro: `source scripts/lib/guard-registry.sh && guard_names | wc -l`. Esta
tabla es descriptiva y ya fue por detrás del registro real dos veces
(DI-14/RT-10: decía «25» y omitía `orbit-versioned-markers`; QM-11: decía
«27» y omitía `orbit-adr-index`); al registrar un guard, añadir aquí su fila
en el mismo PR, y comprobar la cifra con el comando de arriba):

| Guard | Repo | Comando | Qué caza |
|---|---|---|---|
| umbrella-manifest-guard | paraguas | `bash scripts/manifest-guard.sh` | Manifiesto afirmando lo que git no respalda: pin ↔ tag ↔ gitlink (§1–§2), tags de los módulos hermanos de los tres repos —DESCUBIERTOS del árbol— contra el root pinado (§3/§3b), tablas del README (§4/§4b), lags cross-repo no declarados (§5). |
| umbrella-served-jargon | paraguas | `bash scripts/check_served_jargon.sh website/build` | Jerga interna (ADR-nnn, P0…, IDs de hallazgo QK/NU/OR/QMn-n) en el HTML **servido**, tras el build. |
| umbrella-sidebar-sync | paraguas | `bash scripts/check_sidebar_sync.sh` | Sidebars espejadas (nucleus/quark) desincronizadas del sidebar del submódulo pinado; parser sin ids = FAIL, no verde-vacío (QM8-3). |
| umbrella-suite-tag | paraguas | `bash scripts/check_suite_tag.sh` | Tag de suite que no respalda lo que afirma. **Autoconsistencia (asserts 2-4):** `v<quantum>` inexistente sin estar mid-tren, versions.yaml del tag declarando otra versión, o gitlinks del tag ≠ workspace_pins del tag (QM8-6). **Captura (assert 5, MAQ-1/B.1):** gitlinks del tag ≠ gitlinks/workspace_pins de HEAD — un tag rancio pero autoconsistente (cortado antes del re-pin) que los asserts 2-4 no cazan. El assert 5 solo se exige al certificar (`--cierre`/`QUANTUM_CERTIFYING=1`) o con tag==HEAD; la lane semanal tolera HEAD>tag entre arcos. En certificación, además, el mid-tren sin tag es NO-PASA (MAQ-2/B.2). |
| umbrella-built-links | paraguas | `bash scripts/check_built_links.sh website/build` | Enlaces del sitio **construido** que no resuelven: los `href` a nuestros repos se comprueban contra el checkout local (sin red, sin 429) y los internos contra el HTML generado. Docusaurus no mira los externos — así vivieron meses los «Edit this page» rotos de las tres instancias. |
| umbrella-built-codeblocks | paraguas | `bash scripts/check_built_codeblocks.sh website/build` | Bloques de código VACÍOS en el HTML **servido**: una fence ```` ```lang file=… ```` sin resolver (remark-code-import descableado en el ensamblaje) se publica como `<code></code>` y el build sale verde — así salió el quickstart de nucleus con sus 3 bloques vacíos en todas las versiones (SD-01). |
| umbrella-exit0-regressions | paraguas | `bash scripts/check_exit0_regressions.sh` | Los repros «exit 0 sin efecto» del informe DX (§4.A): comandos que fracasaban con éxito aparente, ejercidos contra el árbol al pin. |
| umbrella-rumbo-estado | paraguas | `bash scripts/check_rumbo_estado.sh` | La cabecera «Estado real» de `docs/RUMBO.md` nombra el set que `versions.yaml` certifica (versión de suite y los tres pilares). En 1.26.0 se quedó un set atrás mientras su propio §1 decía 1.26.0 (QM-6). |
| umbrella-gowork-covers-manifest | paraguas | `bash scripts/check_gowork_covers_manifest.sh` | El `go.work` cubre TODO módulo publicable: raíz de cada repo, todo `go.mod` del árbol (salvo `examples/`, `benchmarks/`, `bugbash/`) y toda clave de `*_modules` del manifiesto. Iba diez módulos por detrás del set y `go build` con módulos de menos sale con EXIT=0 (QM-7). |
| umbrella-retired-claims | paraguas | `bash scripts/check_retired_claims.sh website/build` | Afirmaciones RETIRADAS («-tags mssql», «build tags», «single Go module», «Nine modules») en el HTML **servido** como vigente — hermano de served-jargon (C8). Snapshots versionados y release notes fuera del gate con porqué; excepción auto-expirante ligada al pin de nucleus ≤ v1.23.0 (mismo mecanismo que el token ADR-010 de served-jargon). |
| umbrella-quickstart-cost | paraguas | `bash scripts/check_quickstart_cost.sh website/docs/quickstart.md` | El quickstart de la suite que crece: más de 5 comandos en sus fences (continuaciones unidas, comentarios fuera, `<GoInstallCLI />` cuenta) o más de 5 conceptos — identificadores `pkg.Ident` de la suite agrupados por reglas fijas e impresas (builder = su constructor, `Config` con el constructor, `Register[T]` con su `New`) y cruzados en las dos direcciones con el `concepts:` del front matter (contrabando y declaración colgante; sin `concepts:` es EXIT 2, no verde-vacío). Cuenta sobre la FUENTE con el parser que la lane quickstart-smoke usa para ejecutar los curl de la misma página (`scripts/lib/quickstart-fences.sh`, autotest en `tests/quickstart-fences/`). Gate del arco A2; transición auto-expirante ligada a la CAPACIDAD del nucleus pinado, con el mismo predicado que enciende la lane (`qs_nucleus_knows_with`: ¿`nucleus/internal/cli/new.go` registra el flag `with`?): mientras no, mide e informa; en cuanto el pin lo traiga, exige. Sin el submódulo es EXIT 2. |
| nucleus-version-claims | nucleus | `bash scripts/ci/check_version_claims.sh` | Marcadores `x-release-please-version` desalineados, directivas Go del scaffold, estados README↔inventario. |
| nucleus-product-voice | nucleus | `bash scripts/ci/check_docs_product_voice.sh` | Vocabulario interno en `website/docs/**`. |
| nucleus-contract-freeze | nucleus | `bash scripts/ci/check_contract_freeze.sh` | Removals en los contratos congelados (CLI, config, símbolos estables) + firewall de tipos. |
| nucleus-docs-coverage | nucleus | `bash scripts/website/check-coverage.sh --strict` | Tokens legacy, referencias `covers:` colgantes y (vía bodycheck) falsedades de cuerpo en la web pública. |
| nucleus-bodycheck | nucleus | `go run ./scripts/website/bodycheck -strict` | Falsedades duras en el cuerpo de las páginas: versión de Go, símbolos Go inexistentes, tags `db:` que el parser real no reconoce. |
| nucleus-docs-drift | nucleus | `bash scripts/ci/check_internal_docs_drift.sh` | Documentación **interna** (`docs/**`) citando ficheros ausentes: enlaces relativos y rutas entre comillas invertidas que no resuelven en el árbol. Los registros históricos (`adrs/`, `audits/`, `iterations/`…) quedan fuera — son actas, no manuales vivos. |
| nucleus-docs-archive | nucleus | `bash scripts/ci/check_docs_archive_freshness.sh` | Archivo versionado del sitio por detrás de lo publicado: el snapshot más reciente no puede quedar bajo la MINOR publicada (un patch no exige corte). |
| nucleus-adr-index | nucleus | `bash scripts/ci/check_adr_index.sh` | ADRs del directorio ausentes del índice, y enlaces del índice que no resuelven. El índice se quedó en ADR-022 con veintinueve records: diecisiete decisiones sólo alcanzables listando la carpeta. |
| nucleus-action-pins | nucleus | `bash scripts/ci/check_action_pins.sh` | Ídem para el CI de nucleus. |
| nucleus-retired-claims | nucleus | `bash scripts/ci/check_retired_claims.sh` | Afirmaciones retiradas en la documentación VIVA de nucleus (README, SPEC, docs/ salvo actas, website/docs salvo snapshots): build tags, «single Go module», `MountOpenAPI`, sendgrid built-in. Hermano en la FUENTE del `umbrella-retired-claims`, que mira el HTML servido. |
| nucleus-versioned-markers | nucleus | `bash scripts/ci/check_versioned_docs_markers.sh` | Un snapshot versionado que anuncia una versión ajena. El marcador lo sube release-please DESPUÉS de cortar el snapshot, así que cinco se publicaron afirmando la versión anterior — y en la página que el sitio sirve en la RAÍZ, porque el archivo más reciente es el que se sirve por defecto. Sólo se ve desde fuera: la copia es coherente consigo misma. |
| quark-version-coherence | quark | `bash scripts/check-version-coherence.sh` | Versión publicada ausente de README/SECURITY/CLAUDE/release-notes; roadmap con versiones hardcodeadas. |
| quark-versioned-markers | quark | `bash scripts/ci/check_versioned_docs_markers.sh` | Lo mismo que en nucleus, y por el mismo defecto real: el snapshot de 1.6.0 anunciaba «Quark is v1.5.2». |
| quark-product-voice | quark | `bash scripts/ci/check_docs_product_voice.sh` | Vocabulario interno en `website/docs/**`. |
| quark-lint-docs | quark | `bash scripts/lint-docs.sh` | Lenguaje de marketing, fugas `RELEASE_NOTES_V1`, enlaces relativos rotos. |
| quark-docs-drift | quark | `bash scripts/ci/check_internal_docs_drift.sh` | Igual que en nucleus, con la lista de directorios de primer nivel de este repo. |
| quark-docs-archive | quark | `bash scripts/ci/check_docs_archive_freshness.sh` | Igual que en nucleus: el archivo cubre la minor publicada. |
| orbit-product-voice | orbit | `bash scripts/ci/check_docs_product_voice.sh` | Vocabulario interno en `website/docs/**`. |
| orbit-docs-version-claims | orbit | `bash scripts/ci/check_docs_version_claims.sh` | Marcadores `x-release-please-version` desalineados con la versión publicada. |
| orbit-internal-pins | orbit | `bash scripts/ci/check_internal_pins.sh` | Pins entre módulos hermanos por detrás del último tag publicado. |
| orbit-docs-archive | orbit | `bash scripts/ci/check_docs_archive_freshness.sh` | Archivo versionado por detrás de lo publicado. Orbit versiona desde v1.6.7; antes servía siempre su doc actual. |
| orbit-versioned-markers | orbit | `bash scripts/ci/check_versioned_docs_markers.sh` | Un snapshot versionado que anuncia una versión ajena — mismo guard que en nucleus/quark, y por el mismo defecto real: los snapshots 1.7.0 y 1.8.0 de orbit anunciaban «current release v1.6.7» y «v1.7.4» en producción. Entra al set con orbit v1.8.11 (arco de deuda QCD). |
| orbit-adr-index | orbit | `bash scripts/ci/check_adr_index.sh` | ADRs del directorio ausentes del índice, y enlaces del índice que no resuelven — gemelo del guard de nucleus, portado cuando orbit ganó actas retroactivas. Entra al set con orbit v1.8.14. |
| orbit-action-pins | orbit | `bash scripts/ci/check_action_pins.sh` | Ídem para el CI de orbit. |
| orbit-dependabot-floors | orbit | `bash scripts/ci/check_dependabot_floors.sh` | Un require de la suite que la entrada de Dependabot de su directorio no ignora: un suelo del tren que un bot podría subir sin que nadie lo decida. |
| umbrella-audit-backlog | paraguas | bash scripts/check_audit_backlog.sh | Cada hallazgo de los informes de madurez tiene fila en registro.csv; ninguno abierto sin arco; ningún arco cerrado con filas abiertas |
| umbrella-handoff-size | paraguas | bash scripts/check_handoff_size.sh | El handoff del paraguas no supera 70 KB ni dos sesiones en el §3, y abre con «Estado vigente» |
| nucleus-pr-title-english | nucleus | bash scripts/ci/check_pr_title_english.sh | El título de un PR (= línea del changelog) está en inglés (QM-18) |
| quark-pr-title-english | quark | bash scripts/ci/check_pr_title_english.sh | Ídem en quark |
| quark-action-pins | quark | `bash scripts/ci/check_action_pins.sh` | Toda Action del CI de quark está fijada por SHA de commit, con su tag en el comentario. |
| orbit-pr-title-english | orbit | bash scripts/ci/check_pr_title_english.sh | Ídem en orbit |
| umbrella-actions-pinned | paraguas | `bash scripts/check_actions_pinned.sh` | Una referencia `uses:` de los workflows del paraguas sin fijar por SHA de commit, o fijada sin el comentario `# <tag>` que Dependabot necesita para mantenerla — y la otra mitad de la misma decisión: el bloque `github-actions` de `.github/dependabot.yml` borrado, que dejaría los pines sin quien los suba. Corre desde `suite-integral.yml`, cuyo filtro de rutas incluye `.github/workflows/**` y `.github/dependabot.yml` para que muerda en el PR que introduce la deriva y no en el cron siguiente. Ver §8. |
| umbrella-deprecations | . | `bash scripts/check_deprecations.sh` | Deprecaciones a mano sin recambio, sin aviso `DEP-YYYY-NNN` o con una versión de retirada ya publicada. |
| umbrella-supply-chain | . | `bash scripts/check_supply_chain.sh` | Un release que dejaría de publicar SBOM, firma o atestación de procedencia — o que perdería el permiso que las hace posibles. |
| umbrella-schedule-notify | paraguas | `bash scripts/check_schedule_notify.sh` | Una lane con disparador `schedule:` sin su job `notify-schedule-failure` —el cron rojo degradando al email por defecto de Actions, que QM8-1 declaró insuficiente—, o con el job puesto pero inservible: `if:` que no cubre `cancelled()` (MAQ-4/(c)) o que no acota a `schedule`, sin `issues: write`, sin el canal común (`scripts/notify_schedule_failure.sh`), o con un `needs` incompleto (RT-8: `failure()` sólo mira la cadena de dependencias, y así se perdió el rojo de `showcase-smoke`). Ver §7. |

Notas operativas:

- **Árbol limpio (QM8-5).** La lane exige `git status --porcelain` limpio,
  submódulos incluidos, ANTES de ejecutar nada: un fichero editado en un
  submódulo haría que los guards «al pin» certificaran algo que no es el pin.
- **Red y tags (QM8-8).** `manifest-guard` (§2–§3) y `check_internal_pins`
  comparan contra tags publicados: los submódulos necesitan historia completa
  y tags fetcheados. La lane completa la historia si el clone es shallow y
  fetchea tags antes de ejecutar. Un fetch de tags fallido es **FAIL** (tags
  rancios = veredicto con datos viejos), no un aviso; en local sin red,
  `QUANTUM_OFFLINE=1` lo degrada a AVISO visible — en CI siempre estricto.
- **Fallos legítimos al pin.** Si la ronda en curso ya cortó tags nuevos en un
  remoto (p. ej. un `agent/vX.Y.Z` de orbit), `manifest-guard §3` y/o
  `orbit-internal-pins` se ponen rojos **con razón**: el set pinado quedó por
  detrás de lo publicado. No se silencia — es información de certificación.
  La corrida del lunes existe para que esa deriva aflore sin esperar a un PR.
- **El tag de suite, mid-tren y captura (QM8-6 + MAQ-1/MAQ-2).** «Versión
  nueva en `versions.yaml` pero tag aún sin cortar» es un estado LEGÍTIMO EN LA
  LANE SEMANAL: el procedimiento (§3.5) corta el tag DESPUÉS del último PR de la
  ronda, así que el propio PR de re-pin corre la lane en ese estado. Decisión
  de diseño: en vez de «FAIL salvo escape» (que pondría roja estructuralmente la
  lane del PR de re-pin, la que debe salir verde **sin escapes**),
  `umbrella-suite-tag` verifica en ese caso el ÚLTIMO tag existente contra SU
  propio árbol (su versions.yaml declara su versión; sus gitlinks == sus
  workspace_pins; ancestro de HEAD) y deja un AVISO visible «vX.Y.Z pre-tag —
  tren en marcha» que la corrida semanal repite hasta que el tag se corte.
  - **Certificar es más estricto que la lane semanal (MAQ-2/B.2).** En modo
    `--cierre`/`QUANTUM_CERTIFYING=1` ese mismo mid-tren es **NO-PASA**:
    certificar exige que el tag EXISTA. Así el conteo «15/15 EXIT=0 en --cierre»
    no puede significar «tren a medias sin su tag». Un tag olvidado no llega a
    un cierre: la plantilla de CIERRE (§6) corre el guard en `--cierre`.
  - **El tag debe CAPTURAR HEAD, no solo ser autoconsistente (MAQ-1/B.1).** Los
    asserts 2-4 comparan el tag CONSIGO MISMO; un tag cortado antes del re-pin
    final puede ser rancio (gitlink viejo + su propio manifiesto viejo,
    coherentes) y pasarlos. El **assert 5** compara los gitlinks del tag contra
    los de HEAD y contra `workspace_pins` de HEAD: el tag tiene que apuntar al
    MISMO set que HEAD certifica. Se EXIGE al certificar o con tag==HEAD; entre
    arcos, la lane semanal ve HEAD por delante del último tag con el set
    posiblemente drifteado y eso es legítimo, así que fuera de esos casos NO se
    fuerza (romper ahí pondría roja la lane semanal en un estado válido).
- **Escapes documentados** (solo a mitad de ronda, nunca en el cierre):
  - `QUANTUM_ALLOW_DECLARED_LAGS=1` — tolera `declared_lags` no vacío. Solo
    a mitad de ronda, y solo mientras el tren no haya alineado los requires:
    el workflow NO lo lleva puesto (la lista está vacía desde Quantum 1.8.0)
    y un PR de re-pin lo quita si alguien lo puso.
  - `QUANTUM_SKIP_BUILD=1` — reutiliza `website/build` existente para iterar
    en local. En CI siempre se construye.
  - `QUANTUM_ALLOW_DIRTY=1` (QM8-5) — tolera árbol sucio SOLO en local, para
    iterar sobre un guard a medio escribir. En CI se ignora: falla igual.
  - `QUANTUM_OFFLINE=1` (QM8-8) — degrada el fetch de tags fallido a AVISO,
    SOLO en local sin red. En CI se ignora: siempre estricto.

## 2. Qué prueba el guard-of-guards

`bash scripts/guard-of-guards.sh`. Para cada guard del registro hay una
fixture (`tests/guard-fixtures/<guard>/fixture.sh`) que prepara en un
directorio temporal una copia doctorada del árbol mínimo que el guard valida
— ficheros reales del repo al pin, incluida la copia del propio script, con
**una** rotura concreta — y el harness ejecuta el comando real del registro
contra la copia:

- Si el guard sale `EXIT=0` sobre la copia rota, el guard **ha muerto** y el
  harness falla.
- Si sale `EXIT≠0` pero su salida no contiene la causa declarada por la
  fixture (`expect=`), también falla: morir por un error de setup no
  demuestra mordida.

Regla de cobertura, en las dos direcciones: guard registrado sin fixture →
fallo; fixture huérfana sin guard → fallo. Añadir un guard sin su fixture es
imposible sin poner la lane roja.

Cada fixture documenta en su cabecera qué rompe y por qué esa rotura demuestra
que el guard muerde (casi siempre es la regresión histórica que motivó el
guard: QM-P0-1 para manifest-guard, OR5-1 para internal-pins, H-Q6 para
version-coherence, etc.).

## 3. Procedimiento de ronda

1. **Auditoría / trabajo de la ronda.** Los hallazgos se cierran en los repos
   de producto con su test o guard. Mientras haya requires cross-repo por
   detrás del set, se declaran en `declared_lags` (disclosure, no excepción).
2. **Tren de releases, en orden de dependencias:**
   `quark` → `nucleus` → orbit por módulos (`agent` → bump del pin de agent en
   server → `server` → `quarkbridge`/`quarkdatasource` → **root de orbit al
   final**, para que su commit contenga todos los tags de módulo como
   ancestros — manifest-guard §3 exige exactamente eso). El tren alinea los
   requires cross-repo y **vacía `declared_lags`**.
3. **Re-pin del paraguas:** submódulos a los tags nuevos, `versions.yaml`
   (modules + workspace_pins + notes), README. Quitar
   `QUANTUM_ALLOW_DECLARED_LAGS` del workflow si estaba puesto. En ese PR la
   lane suite-integral debe salir verde **sin escapes**: eso es el set
   certificable.
4. **quantum-app se re-pina en CADA corte**, ya no «si la ronda lo toca»
   (D6/QADR-0008). Y no aquí: el consumidor externo sigue al set
   **certificado**, así que su bump va DESPUÉS del tag del punto 5 y lo
   dispara la fase `cierre` del tren (`scripts/train/dispatch-app-bump.sh`),
   que le pasa el bloque require de `scripts/print-requires.sh`. Allí un
   workflow reescribe el pin, corre sus gates y abre un PR — que se revisa
   como cualquier otro. Un rojo en ese PR es deuda de quantum-app contra el
   set nuevo, no un motivo para no certificar.
5. **El tag de suite se corta DESPUÉS del último PR de la ronda** —
   procedimiento nuevo de esta ronda: primero se fusiona todo lo que forma
   parte del set, después se tagea; nunca un tag que apunte a un estado que
   aún iba a cambiar. Desde la 8ª el procedimiento tiene guard
   (`umbrella-suite-tag`, QM8-6); desde MAQ-1/MAQ-2 el acto de certificar se
   corre en modo `--cierre`: tras cortar el tag **en HEAD**,
   `bash scripts/suite-integral.sh --cierre` (o `bash scripts/check_suite_tag.sh
   --cierre`) debe salir EXIT=0 — el tag existe, captura HEAD (assert 5) y no hay
   AVISO pre-tag. Corrida en `--cierre` ANTES de cortar el tag, o con un tag que
   no captura HEAD, es FAIL por diseño. Así lo exige la plantilla de CIERRE (§6).
6. **Cierre honesto:** los conteos del informe de cierre se copian de las
   tablas de las lanes (guards ejecutados, tests, fixtures), no se redactan de
   memoria — la lección QM7-2: nada de líneas-resumen infladas.

## 4. Cómo añadir un guard

1. Escribe el guard en el repo dueño (producto o paraguas) y cablealo en el CI
   de ese repo.
2. Regístralo en `scripts/lib/guard-registry.sh` (nombre, cwd, comando — el
   comando **exacto** del CI del repo dueño).
3. Escribe su fixture en `tests/guard-fixtures/<nombre>/fixture.sh`: copia
   mínima real + una rotura + `expect=` con la causa de muerte.

El orden lo fuerza la mecánica: si el guard llega al árbol (p. ej. por un
re-pin de un producto que añadió un check) sin registrar, la aserción
anti-fósil pone las dos lanes rojas; si se registra sin fixture, el
guard-of-guards falla por cobertura. Un script auxiliar que no es guard se
añade a `GUARD_SCAN_EXCLUDE` con su porqué — sin porqué, no.

**No todo check de un producto certifica el set.** Caso probado en la
certificación 1.8.0: `check_example_pins.sh` de nucleus compara los pins de
sus examples contra los tags remotos EN VIVO. Es un guard-recordatorio de
main de nucleus (su rojo fuerza el chore de re-pin tras cada release de un
hermano), pero al pin es rojo ESTRUCTURAL tras cada tren: nucleus taggea
antes que orbit por orden de dependencias, así que el ejemplo dentro del tag
siempre apunta al orbit del momento del corte. Registrarlo en la lane hacía
in-certificable un set correcto; quedó en `GUARD_SCAN_EXCLUDE` con ese
razonamiento. Criterio general: la lane registra guards cuyo veredicto
depende solo del árbol pinado (más los tags que ese árbol declara); un guard
que compara contra el estado vivo del mundo pertenece al CI del repo dueño.

## 5. Qué queda para el juicio humano

La lane mecaniza lo verificable por ejecución. No sustituye a la pasada
manual en:

- **Fidelidad de docs de superficie nueva.** bodycheck caza símbolos y
  versiones falsas, no una explicación engañosa de una feature nueva; leer la
  página sigue siendo trabajo del auditor.
- **Revisión de seguridad.** govulncheck vive en los CI de producto; el
  razonamiento sobre superficie de ataque, defaults y manejo de credenciales
  no lo hace un regex.
- **Decisiones de alcance.** Qué hallazgo es P-algo, qué se difiere, cuándo un
  lag declarado lleva demasiado tiempo declarado: criterio, no script.
- **Los guards que faltan.** El guard-of-guards prueba que los guards
  registrados muerden; no puede probar que no falte un guard por escribir.
  Detectar la clase de deriva sin check sigue siendo el trabajo de la
  auditoría.

## 6. Régimen de auditoría continua (desde la 9ª)

La 8ª pasada
([REAUDITORIA8](auditoria/registro/REAUDITORIA8_QUANTUM.md), dictamen del §5 —
copia en el repo, con los CIERREs de ronda, en
[`auditoria/registro/`](auditoria/registro/)) fue **la última pasada manual
completa**: desde la 9ª, la certificación descansa en la lane semanal verde +
CI por-repo verde + los disparadores de mini-pasada de abajo. **Decisor:
Carlos** — qué disparador ha saltado, cuánta superficie cubre la mini-pasada
y cuándo un hallazgo frena un tren lo decide él, no un script.

### Disparadores de mini-pasada dirigida (el «juicio humano puntual»)

Copiados del dictamen (REAUDITORIA8 §5); si se da cualquiera, hay mini-pasada
ANTES de certificar el set afectado:

- Superficie de **seguridad** nueva o cambiada → revisión humana de ESA
  superficie antes de certificar el set que la incluya.
- **Feature minor** en cualquier producto → lectura de fidelidad de sus docs
  + verificación de que su arco trajo rojo-sin-fix.
- **Cambio en la propia maquinaria** (registry, fixtures, orquestadores,
  workflows) → revisión humana del diff: la maquinaria no puede
  auto-vigilarse.
- Lane semanal **roja 2 corridas** sin PR que lo explique; **declared_lags
  poblado >1 ronda**; guard nuevo sin negativo revisado.
- **Cada 2 rondas, una pasada de «ojos frescos» ACOTADA** a la superficie más
  cambiada — es la única fuente histórica de los P0 (OR-1/OR-2, NU6-1, QK7-1
  nacieron así) y ningún guard la sustituye. No es la pasada completa de 5
  auditores: es una, dirigida.

### Lo estructuralmente sin red mecánica

Asumido y por eso ligado a los disparadores (no hay guard que lo cubra; si un
cambio toca una de estas clases, la mini-pasada correspondiente lo mira):

- **Re-provocar rojos quitando fixes** (tests tautológicos): solo un humano
  quita el fix y comprueba que el test muere.
- **Honestidad semántica** de evidencias y clasificaciones (manifiestos,
  informes de cierre): los gates cazan forma, no verdad.
- **Wire-formats**: el contract-freeze es symbol-only — nucleus#230 lo
  demuestra (cambió el wire del payload sin tocar un símbolo).
- **Drift de main entre rondas**: lo que main acumula por delante de los tags
  no está certificado hasta el siguiente tren.
- **Prosa que FUE verdad**: los guards de deriva cazan símbolos que
  desaparecen y rutas que no resuelven, no afirmaciones que envejecen. La
  página de configuración de nucleus declaró la capa 3 de validación
  «rolling out» durante los meses en que ya corría en cada carga, y ningún
  guard podía verlo. Solo lo ve alguien releyendo la página con el código
  delante — por eso el arco que TOCA un subsistema relee sus páginas.
- ~~**Documentación de orbit sin versionar**~~ — CERRADO. Orbit versiona
  desde v1.6.7 con su propio `cut_docs_snapshot.sh` (operaciones de fichero:
  no tiene instalación de Docusaurus, y su sidebar es autogenerada) y el
  guard `orbit-docs-archive`. No movió ninguna ruta: `lastVersion: 'current'`
  mantiene la doc actual en `/orbit/…` y añade los snapshots aparte. El hueco
  HISTÓRICO (minors 1.0–1.5 sin snapshot) queda declarado y sin rellenar: un
  snapshot retroactivo afirmaría que la doc de hoy fue la de entonces.

Con las condiciones del dictamen cumplidas, la «auditoría» de la 9ª+ es: lane
semanal verde + CI por-repo verde + los disparadores que toquen.

### Plantilla de CIERRE de ronda

Los cierres se escriben sobre esta plantilla. Reglas duras: cada casilla del
DoD lleva su **comando + EXIT** (no prosa); los conteos se **copian de las
tablas de las lanes**, no se redactan de memoria (lección QM7-2); y la regla
nueva de la 8ª (lección OR8-1: el CIERRE_7A marcó «✅ (con observación)» una
cadena que tenía un carril roto): **un ✅ con asimetría conocida se escribe
⚠️** — si un ítem pasa con un carril, caso o superficie conocidamente roto o
excluido, su casilla es ⚠️ con la asimetría nombrada, nunca ✅.

```markdown
# CIERRE de la Nª ronda — Quantum X.Y.Z

## DoD (casilla a casilla; comando + EXIT literal)

- [ ] certificación en modo CIERRE (tag cortado en HEAD, sin escapes): `bash scripts/suite-integral.sh --cierre` → EXIT=0
- [ ] guard-of-guards: `bash scripts/guard-of-guards.sh` → EXIT=0
- [ ] tag de suite cortado tras el último PR y captura HEAD: `bash scripts/check_suite_tag.sh --cierre` → EXIT=0 (tag existe, assert 5 verde, sin aviso pre-tag)
- [ ] declared_lags vacío en versions.yaml (lo exige suite-integral; se afirma aquí explícitamente)
- [ ] CI por-repo verde en los tags del set (enlaces a las corridas)
- [ ] disparadores del §6 evaluados: cuáles saltaron y qué mini-pasada se hizo (o «ninguno», con por qué)
<!-- ⚠️ donde haya asimetría conocida: nómbrala en la propia casilla -->

## Conteos (copiados de las tablas, no de memoria)

<línea literal de suite-integral: «guards registrados: N · ejecutados: N · con fallo: 0»>
<línea literal de guard-of-guards: «guards registrados: N · fixtures ejecutadas: N · muerden: N»>

## Tags / PRs / desviaciones

- Tags cortados (suite y módulos), en orden.
- PRs de la ronda (número → una línea).
- Desviaciones del procedimiento §3, cada una con su porqué. Sin desviaciones: «ninguna».

## Pendiente

(vacío) — o entradas «DECISIÓN REQUERIDA: …» con dueño (Carlos) y contexto.
Nada de pendientes implícitos: lo que no está aquí, no existe.
```

## 7. Permisos del token en los workflows del paraguas

Regla, para que el próximo workflow nazca bien: **cada workflow declara
`permissions:` arriba con lo mínimo que necesita para leer** (`contents:
read`) **y la escritura baja al job que de verdad la usa**. El motivo es
mínimo privilegio, y se sostiene solo: el token que no puede escribir no
escribe tampoco cuando un paso del job resulta comprometido. Ojo a la
mecánica: un bloque `permissions:` de job **sustituye** al del workflow, no se
suma, así que un job que declara escritura vuelve a nombrar la lectura que
necesite.

Lo que puntúa OpenSSF Scorecard es sólo una parte de esta regla, y conviene no
confundir las dos. Su comprobación Token-Permissions (riesgo alto, una de las
ocho de ese peso) puntúa 0 el workflow **sin bloque arriba** cuyos jobs
tampoco lo declaran: corre con el token por defecto del repo, que cuenta como
`write-all`. Pero una escritura **declarada** arriba sólo resta si cae en uno
de los siete ámbitos que Scorecard vigila —`contents`, `packages`, `actions`,
`statuses`, `checks`, `security-events`, `deployments`—; `pages`, `id-token`,
`issues` o `pull-requests` arriba no le restan nada: los clasifica como
escritura no peligrosa y ni siquiera avisa (queda en la traza de depuración).
Consecuencia práctica, derivada de las reglas de puntuación y no de una
corrida (aquí no se ha ejecutado Scorecard todavía — §8): bajar
`pages`/`id-token` de `deploy.yml` al job que los usa es mínimo privilegio
real y **no** mueve la puntuación, porque Token-Permissions sólo penaliza los
siete ámbitos de arriba y ninguno de esos dos está entre ellos. La regla vale
por sí misma; la puntuación no es su argumento.

Qué puede escribir hoy cada lane, tras el barrido de `gh`, `git push` y
`GITHUB_TOKEN`/`github.token` sobre los cinco ficheros y los scripts que
invocan:

| Workflow | Arriba | Jobs con escritura | Por qué |
|---|---|---|---|
| `deploy.yml` | `contents: read` | `deploy`: `pages: write` + `id-token: write` | Es lo que exige `actions/deploy-pages`: publicar en Pages y acuñar el OIDC del despliegue. El job `build` se queda en solo lectura — hace checkout con submódulos y sube el artefacto de Pages, y ninguna de las dos cosas escribe en el repo. |
| `integration.yml` | `contents: read` | `notify-schedule-failure`: `issues: write` | `scripts/notify_schedule_failure.sh` crea la etiqueta `lane-schedule-failure` (`gh label create`, bajo el ámbito de issues) y abre o comenta el issue del schedule rojo. Sin ese permiso, el aviso del cron falla en silencio y el schedule rojo degrada al email por defecto, que es justo lo que QM8-1 declaró insuficiente. |
| `suite-integral.yml` | `contents: read` | `notify-schedule-failure`: `issues: write` | El mismo script y el mismo motivo, para el cron del lunes 06:00 UTC. |
| `website-ci.yml` | `contents: read` | ninguno | Construye el sitio y corre los guards sobre lo servido; no toca la API. |
| `scorecard.yml` | `read-all` | `analysis`: `security-events: write` + `id-token: write`; `notify-schedule-failure`: `issues: write` | La escritura de `security-events` es lo que exige subir el SARIF al panel de code scanning; va en el job, no arriba. `id-token` hoy **no se ejerce** —con `publish_results: false` la acción no acuña OIDC—: queda declarado porque es lo que la acción documenta como requisito y porque publicar sería una línea, no un permiso nuevo. El job vuelve a nombrar `contents: read` y `actions: read` porque un bloque de job sustituye al del workflow. El `issues: write` del job de aviso es el mismo de las otras dos lanes y por el mismo motivo (abajo). |

El barrido es el paso que hace la regla comprobable, y hay que repetirlo
cuando un job gana un paso nuevo: el permiso se justifica por lo que el job
ejecuta, no por lo que el workflow parece. Los demás jobs de las tres lanes de
CI —los guards (`manifest-guard`, `guard-of-guards`, `suite-integral`), los
smoke (`quickstart-smoke`, `go-install-tag`, `orbit-lockstep`) y los builds— no usan el token más allá del checkout: leen
el árbol pinado y salen con un EXIT.

### El aviso del cron es parte de la lane, no un añadido

Segunda regla, hermana de la anterior y del mismo §7: **toda lane con
disparador `schedule:` lleva su job `notify-schedule-failure`**. El motivo es
QM8-1: para un cron rojo, Actions sólo ofrece por defecto un email a la cuenta
del propietario —señal que nadie mira—, y el remedio del paraguas es un job
que abre o actualiza un issue con el enlace al run
(`scripts/notify_schedule_failure.sh`, fila de la tabla de piezas). El job
tiene que servir, no sólo estar: cubre `failure()` **y** `cancelled()`
(MAQ-4/(c)), se acota a `github.event_name == 'schedule'` —en un PR el rojo ya
se ve—, declara `issues: write`, usa el canal común y su `needs` lista TODOS
los demás jobs del workflow (RT-8: `failure()` sólo mira la cadena de
dependencias; con la entonces `showcase-smoke` fuera de la lista, el lunes enrojecía sin
abrir issue).

Hasta el arco A3 esta regla vivía sólo aquí, y las dos lanes programadas la
cumplían porque se habían copiado la una de la otra. La tercera —`scorecard.yml`,
la lane de medida del §8— nació sin el job y la certificación salió verde con
la omisión dentro: 40 de 40 guards, ninguno mirando eso. El caso era además el
peor posible para esa lane en concreto, que existe para PRODUCIR una medida: un
lunes fallido en silencio no deja medida y nadie se entera. Desde el arco A3
la regla la sostiene el guard `umbrella-schedule-notify`, que la comprueba en
el PR que añade la lane.

## 8. Acciones fijadas por SHA, y la lane de OpenSSF Scorecard

### La regla

**Toda referencia `uses:` de los workflows de este repositorio se escribe
`owner/accion@<40 hex> # <tag>`.** Las dos mitades son obligatorias y el guard
`umbrella-actions-pinned` (`scripts/check_actions_pinned.sh`) exige las dos.

El SHA, porque un tag de Git es un puntero móvil en un repositorio ajeno:
quien controle esa cuenta puede reapuntar `v7` a otro commit, y ese commit
corre dentro de nuestro CI con el token del repo sin que aquí cambie una
línea. El SHA de 40 hex nombra un árbol concreto y no se reapunta. Lo que fija
es ese **árbol**, que para una acción JavaScript o compuesta es todo el código
que corre y para una acción **Docker** no: ver la excepción del paraguas más
abajo, que hay una y conviene decirla aquí para que la regla no suene
absoluta.

El comentario, porque es lo que hace el pin **mantenible**, y ahí está el
riesgo real de esta regla: un pin abandonado congela también los fallos de
seguridad de su versión, y eso es peor que el tag móvil que vino a sustituir.
El bloque `github-actions` de `.github/dependabot.yml` es la otra mitad de la
decisión: Dependabot lee el comentario para saber en qué versión está el pin
y, cuando sale una nueva, reescribe SHA y comentario **a la vez** en un PR.
Sin comentario no tiene de dónde partir y el pin queda opaco. Fijar sin bot,
o poner el bot sin comentario, deja el trabajo a medias en direcciones
opuestas.

Por eso el guard comprueba las dos mitades: los `uses:` de los cinco
workflows y que `.github/dependabot.yml` siga declarando el ecosistema
`github-actions`. De ese bloque comprueba que **existe**, no su contenido: la
deriva realista es que desaparezca en un PR que no rompe ninguna corrida, no
que se afine mal.

Estado tras el arco A3 (29 referencias: 24 en cuatro workflows + 5 en el
quinto, `scorecard.yml`, contando el checkout de su job de aviso):

| Acción | SHA | Tag |
|---|---|---|
| `actions/checkout` | `3d3c42e5aac5ba805825da76410c181273ba90b1` | `v7.0.1` |
| `actions/setup-go` | `b7ad1dad31e06c5925ef5d2fc7ad053ef454303e` | `v7.0.0` |
| `actions/setup-node` | `820762786026740c76f36085b0efc47a31fe5020` | `v7.0.0` |
| `actions/upload-pages-artifact` | `fc324d3547104276b827a68afc52ff2a11cc49c9` | `v5.0.0` |
| `actions/deploy-pages` | `368f82528645a54fb793d4d04e342629a3f51346` | `v5.0.1` |
| `actions/upload-artifact` | `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` | `v7.0.1` |
| `ossf/scorecard-action` | `2d1146689b8cda280b9bc96326124645441f03bc` | `v2.4.4` |
| `github/codeql-action/upload-sarif` | `cdf488f595d80d6e07e03d4674febd5ab45fa938` | `v4.37.9` |

Cada SHA se resolvió con `gh api repos/<owner>/<accion>/commits/<tag> --jq
.sha` y se verificó contra el tag **y contra el propietario**: un SHA correcto
del repositorio equivocado no rompe nada visible: ejecuta otro código.
Escribir el pin a mano sin esa verificación es lo único de esta regla que sale
mal en silencio.

Alcance: los workflows del paraguas. Los de nucleus, quark y orbit los fija
cada producto en su propio PR del arco; el paraguas no reescribe ficheros del
submódulo, y el guard no mira dentro de ellos.

### La excepción: el SHA de una acción Docker no fija el código que corre

Fijar el SHA fija el árbol de la acción. Para una acción **Docker** ese árbol
son sus metadatos: el `action.yaml` dice qué imagen ejecutar, y si la nombra
por tag, el tag se reapunta sin que el SHA cambie. El paraguas tiene hoy
exactamente un caso, `ossf/scorecard-action`, cuyo `action.yaml` **al SHA que
este repositorio fija** dice:

```yaml
runs:
  using: "docker"
  image: "docker://ghcr.io/ossf/scorecard-action:v2.4.4"
```

Es decir: el pin congela un fichero de metadatos, y el contenedor que de
verdad se ejecuta lo trae el runner de `ghcr.io` **por tag**. Quien controle
ese espacio de nombres puede reapuntar `v2.4.4` a otra imagen sin que aquí
cambie una línea — el mismo modelo de amenaza que la regla cierra para las
demás referencias. Lo que ese contenedor tiene delante es el job `analysis` de
`scorecard.yml`: el token del repo en lectura, más `security-events: write`
(subir el SARIF) e `id-token: write` declarado y hoy sin ejercer.

Las otras siete referencias no tienen esta grieta, y se comprobó una por una
leyendo su `action.yaml` al SHA fijado: seis son `using: node24` (`checkout`,
`setup-go`, `setup-node`, `deploy-pages`, `upload-artifact`,
`codeql-action/upload-sarif`) y `upload-pages-artifact` es compuesta, con su
único paso —`actions/upload-artifact`— fijado por SHA.

El guard no puede ver esto: leer el `action.yaml` de un repositorio ajeno
exige red, y un guard de esta suite no sale a la red. Sí exige `@sha256:` a
las imágenes que un paso nombra **directamente** (`docker://…`), que es la
parte que sí está a nuestro alcance. La excepción se sostiene, por tanto, por
escrito: aquí, en la cabecera del guard y en un comentario junto al `uses:` de
la lane.

Salidas examinadas, ninguna gratis:

- **Llamar a la imagen directamente**, con un paso
  `uses: docker://ghcr.io/ossf/scorecard-action@sha256:<digest>` (el digest de
  `v2.4.4` hoy es `sha256:ae5104dd3cc28466ebeb11144354be4cac4b7ff829654f9fab89021d71c46670`).
  El contenedor lee sus entradas de variables `INPUT_*`, así que habría que
  pasarlas a mano: ese contrato es interno de la acción, no su interfaz
  documentada, y el pin quedaría fuera del formato `owner/accion@sha # tag`
  con el que Dependabot lo mueve. Se cambiaría una exposición por otra:
  frescura a cambio de inmutabilidad.
- **Bifurcar la acción** y fijar la imagen por digest en el fork: pone a
  nuestro cargo el mantenimiento al día de una herramienta de seguridad ajena.
- **Aceptarlo y dejarlo escrito**, que es lo que se hace: la lane mide, no
  bloquea (no está en el registro de guards), y la subida de versión llega por
  Dependabot como la de cualquier otra acción. La exposición queda anotada, no
  cerrada. Si un día esta lane pasara a gating, la decisión se revisa.

### Dónde muerde el guard, y por qué eso obligó a tocar el filtro de rutas

`umbrella-actions-pinned` está en el registro, y el registro sólo lo ejecuta
`scripts/suite-integral.sh` — en CI, el workflow `suite-integral.yml`. Ese
workflow filtra por rutas en `pull_request`, así que **la lista de rutas es
parte del guard**: si no nombra los ficheros que el guard vigila, el PR que
puede deshacer la regla es justo el que no lo dispara.

No es hipotético: el primer borrador de esta regla nombraba en el filtro
`.github/workflows/suite-integral.yml` y nada más del directorio. Un workflow
nuevo escrito a mano que naciera con `@v7`, un revert del pin, un PR de
Dependabot del ecosistema `github-actions` (que por definición sólo toca
`.github/workflows/*.yml`) o el borrado del bloque del bot se fusionaban en
verde, y la deriva esperaba al cron del lunes 06:00 UTC. Por eso el filtro
dice hoy `.github/workflows/**` y `.github/dependabot.yml`.

La otra lane, `integration.yml`, sí corre en todo PR sin filtro de rutas,
pero no ejecuta el registro (manifest-guard, `gowork-covers-manifest`, los
smoke y el lockstep). Invocar ahí el guard a mano daría el mismo veredicto en
dos sitios y una segunda fuente de verdad fuera del registro; la regla del
paraguas es que un guard se ejecute desde el registro, así que lo que se
ajusta es el filtro. **Al mover un guard de lane o al añadir uno que valide
ficheros fuera de las rutas listadas, revisar ese filtro**: es la diferencia
entre morder en el PR que introduce la deriva y morder una semana después.

### La lane de Scorecard

`.github/workflows/scorecard.yml` corre OpenSSF Scorecard los lunes a las
07:00 UTC (una hora después del cron de `suite-integral`, para no solapar dos
lanes largas) y a mano con `workflow_dispatch`. Sube el SARIF a code scanning
y lo guarda como artefacto `scorecard-results`.

Sobre la corrida a mano: el README de la acción marca `pull_request` y
`workflow_dispatch` como **experimentales**. Leyendo `options.Validate()` al
SHA fijado, un dispatch sobre `main` cumple lo que exige —token no vacío y
evento de PR **o** rama por defecto—, así que debería funcionar; pero la vía
soportada es el `schedule`, y si el disparo a mano se porta mal, la primera
medida espera al lunes. Es una posibilidad conocida, no una sorpresa.

Como toda lane programada del paraguas, lleva su job
`notify-schedule-failure` (§7): si el lunes falla —cuota de la API, subida del
SARIF rechazada, bump de la acción—, el rojo abre issue en vez de morir en el
email por defecto. Sin ese aviso, una lane cuyo propósito es producir una
medida podría dejar de producirla sin que nadie lo notara.

**Es una lane de medida, no un guard.** No impone umbral y no está en el
registro: su rojo significa que la corrida falló, no que la nota bajó. El
guard que lea la nota llega en un PR posterior del arco, y hasta entonces no
tendría contra qué comparar — no existe ninguna medida previa, en ninguno de
los cinco repos.

`publish_results` está en **false**. Publicar la nota en el dataset público de
OpenSSF (y con ella el badge) es una decisión del propietario que no está
tomada; mientras no lo esté, la nota se lee de la propia corrida: el log del
paso la imprime por comprobación, y `gh run download <run-id> -n
scorecard-results` deja el SARIF. La elección tiene consecuencia de diseño
para el guard posterior: leyendo del dataset público bastaría un `curl` sin
token; leyendo del artefacto hay que descargarlo de la corrida.

### Qué se espera de la primera nota

Estimación del mapa de A3 (medida por inspección, sin ejecutar Scorecard):
**~5,8** para el paraguas antes del arco. La primera ola cerró
Token-Permissions (+0,86 en el promedio ponderado del mapa) y este PR cierra
Pinned-Dependencies (+0,57), lo que deja la estimación en **~7,2**. Es una
estimación, y sustituirla por una medida es justo el propósito de la lane.

Lo que **no** puede pasar todavía, y por qué:

- **Signed-Releases.** Scorecard lee las cinco releases más recientes y busca
  firmas en sus assets. Las del paraguas son tags de suite sin assets, así que
  no hay nada que leer: la comprobación queda no concluyente y fuera del
  promedio. En los tres productos ocurre lo mismo por la misma razón —tags de
  módulo sin assets—, y ahí sí lo cambia el PR de firma del arco.
- **Branch-Protection.** 0/10: `main` del paraguas no tiene protección. Es un
  ajuste de repositorio, no un fichero del árbol.
- **Code-Review.** 0/10: los últimos diez PRs fusionados aquí se fusionaron
  sin revisión. Es historia de revisión, tampoco un fichero, y con un solo
  mantenedor no se arregla declarándolo.
- **SAST.** 0/10 hasta el PR de CodeQL del arco.
- **Fuzzing.** 0/10, y aquí no hay nada que fuzzear: el paraguas no tiene
  módulo Go propio (`go.work` sobre los submódulos). Ese punto se gana en los
  productos.
- **Vulnerabilities.** Sin medir hasta esta corrida: la superficie del
  paraguas es el `package-lock.json` de `website/`, que ningún check actual
  cubre. La primera nota es también la primera lectura de ese dato.
