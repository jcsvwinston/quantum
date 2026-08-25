# Auditoría continua — certificación mecánica de la suite

Runbook interno del paraguas (7ª ronda; §6 y robustez QM8-* desde la 8ª).
Describe qué comprueba la certificación mecánica, cómo se demuestra que los
checks siguen vivos, el procedimiento de cierre de una ronda, qué queda
deliberadamente fuera para el juicio humano — y, desde la 8ª, el régimen
operativo de la auditoría continua (§6): la 8ª pasada fue LA ÚLTIMA manual
completa.

Piezas:

| Pieza | Ruta | Qué hace |
|---|---|---|
| Registro de guards | `scripts/lib/guard-registry.sh` | Única fuente de verdad: nombre → cwd → comando de cada guard, más la aserción anti-fósil. |
| Lane de certificación | `scripts/suite-integral.sh` | Ejecuta TODOS los guards del registro contra el árbol pinado; tabla `guard → EXIT`. Con `--cierre`/`QUANTUM_CERTIFYING=1` exige además que el tag de suite exista y capture HEAD (MAQ-2/B.2). |
| Guard-of-guards | `scripts/guard-of-guards.sh` + `tests/guard-fixtures/` | Ejecuta cada guard contra una fixture de fallo y exige que muera por la causa esperada. |
| CI | `.github/workflows/suite-integral.yml` | Ambos, en PR (paths relevantes), a demanda y cada lunes 06:00 UTC. |
| CI de integración | `.github/workflows/integration.yml` | Build + vet del set, lockstep de orbit y `go install @tag` con caché virgen — en PR, push a main y cada lunes 06:30 UTC (QM8-1, escalonado tras suite-integral). |
| Aviso activo del schedule rojo | `scripts/notify_schedule_failure.sh` | En corridas programadas fallidas **o canceladas** (MAQ-4/(c)), ambos workflows abren o actualizan un issue `[lane] fallo del schedule <workflow> <fecha>` con el enlace al run. Dedupe **server-side** por etiqueta `lane-schedule-failure` + término de título (MAQ-4/(b): con >100 issues abiertos un `--limit 100` sin filtro duplicaba). Si el propio job de aviso falla, un step de **último recurso** (MAQ-4/(a)) emite `::error::` + resumen del job + issue de título fijo, para que el fallo del notificador no degrade al email default (QM8-1, insuficiente). |

## 1. Qué cubre la certificación mecánica

`bash scripts/suite-integral.sh` desde la raíz del paraguas. Precondiciones
(anti-fósil, `declared_lags` vacío, submódulos con historia y tags, build del
sitio) y después los guards del registro, todos, capturando el EXIT de cada
uno sin abortar al primero. EXIT global ≠ 0 si cualquier cosa falló.

Los guards de producto corren **al pin** — el submódulo tal y como lo fija
`versions.yaml`. Un fallo ahí no significa «el CI de otro repo está roto»:
significa que el set que el manifiesto certifica no pasa sus propios guards,
que es exactamente lo que reportaría un auditor.

Registro actual (22 guards):

| Guard | Repo | Comando | Qué caza |
|---|---|---|---|
| umbrella-manifest-guard | paraguas | `bash scripts/manifest-guard.sh` | Manifiesto afirmando lo que git no respalda: pin ↔ tag ↔ gitlink (§1–§2), tags de módulo de orbit contra el root pinado (§3), tabla del README (§4), lags cross-repo no declarados (§5). |
| umbrella-served-jargon | paraguas | `bash scripts/check_served_jargon.sh website/build` | Jerga interna (ADR-nnn, P0…, IDs de hallazgo QK/NU/OR/QMn-n) en el HTML **servido**, tras el build. |
| umbrella-sidebar-sync | paraguas | `bash scripts/check_sidebar_sync.sh` | Sidebars espejadas (nucleus/quark) desincronizadas del sidebar del submódulo pinado; parser sin ids = FAIL, no verde-vacío (QM8-3). |
| umbrella-suite-tag | paraguas | `bash scripts/check_suite_tag.sh` | Tag de suite que no respalda lo que afirma. **Autoconsistencia (asserts 2-4):** `v<quantum>` inexistente sin estar mid-tren, versions.yaml del tag declarando otra versión, o gitlinks del tag ≠ workspace_pins del tag (QM8-6). **Captura (assert 5, MAQ-1/B.1):** gitlinks del tag ≠ gitlinks/workspace_pins de HEAD — un tag rancio pero autoconsistente (cortado antes del re-pin) que los asserts 2-4 no cazan. El assert 5 solo se exige al certificar (`--cierre`/`QUANTUM_CERTIFYING=1`) o con tag==HEAD; la lane semanal tolera HEAD>tag entre arcos. En certificación, además, el mid-tren sin tag es NO-PASA (MAQ-2/B.2). |
| umbrella-built-links | paraguas | `bash scripts/check_built_links.sh website/build` | Enlaces del sitio **construido** que no resuelven: los `href` a nuestros repos se comprueban contra el checkout local (sin red, sin 429) y los internos contra el HTML generado. Docusaurus no mira los externos — así vivieron meses los «Edit this page» rotos de las tres instancias. |
| umbrella-exit0-regressions | paraguas | `bash scripts/check_exit0_regressions.sh` | Los repros «exit 0 sin efecto» del informe DX (§4.A): comandos que fracasaban con éxito aparente, ejercidos contra el árbol al pin. |
| nucleus-version-claims | nucleus | `bash scripts/ci/check_version_claims.sh` | Marcadores `x-release-please-version` desalineados, directivas Go del scaffold, estados README↔inventario. |
| nucleus-product-voice | nucleus | `bash scripts/ci/check_docs_product_voice.sh` | Vocabulario interno en `website/docs/**`. |
| nucleus-contract-freeze | nucleus | `bash scripts/ci/check_contract_freeze.sh` | Removals en los contratos congelados (CLI, config, símbolos estables) + firewall de tipos. |
| nucleus-docs-coverage | nucleus | `bash scripts/website/check-coverage.sh --strict` | Tokens legacy, referencias `covers:` colgantes y (vía bodycheck) falsedades de cuerpo en la web pública. |
| nucleus-bodycheck | nucleus | `go run ./scripts/website/bodycheck -strict` | Falsedades duras en el cuerpo de las páginas: versión de Go, símbolos Go inexistentes, tags `db:` que el parser real no reconoce. |
| nucleus-docs-drift | nucleus | `bash scripts/ci/check_internal_docs_drift.sh` | Documentación **interna** (`docs/**`) citando ficheros ausentes: enlaces relativos y rutas entre comillas invertidas que no resuelven en el árbol. Los registros históricos (`adrs/`, `audits/`, `iterations/`…) quedan fuera — son actas, no manuales vivos. |
| nucleus-docs-archive | nucleus | `bash scripts/ci/check_docs_archive_freshness.sh` | Archivo versionado del sitio por detrás de lo publicado: el snapshot más reciente no puede quedar bajo la MINOR publicada (un patch no exige corte). |
| quark-version-coherence | quark | `bash scripts/check-version-coherence.sh` | Versión publicada ausente de README/SECURITY/CLAUDE/release-notes; roadmap con versiones hardcodeadas. |
| quark-product-voice | quark | `bash scripts/ci/check_docs_product_voice.sh` | Vocabulario interno en `website/docs/**`. |
| quark-lint-docs | quark | `bash scripts/lint-docs.sh` | Lenguaje de marketing, fugas `RELEASE_NOTES_V1`, enlaces relativos rotos. |
| quark-docs-drift | quark | `bash scripts/ci/check_internal_docs_drift.sh` | Igual que en nucleus, con la lista de directorios de primer nivel de este repo. |
| quark-docs-archive | quark | `bash scripts/ci/check_docs_archive_freshness.sh` | Igual que en nucleus: el archivo cubre la minor publicada. |
| orbit-product-voice | orbit | `bash scripts/ci/check_docs_product_voice.sh` | Vocabulario interno en `website/docs/**`. |
| orbit-docs-version-claims | orbit | `bash scripts/ci/check_docs_version_claims.sh` | Marcadores `x-release-please-version` desalineados con la versión publicada. |
| orbit-internal-pins | orbit | `bash scripts/ci/check_internal_pins.sh` | Pins entre módulos hermanos por detrás del último tag publicado. |
| orbit-docs-archive | orbit | `bash scripts/ci/check_docs_archive_freshness.sh` | Archivo versionado por detrás de lo publicado. Orbit versiona desde v1.6.7; antes servía siempre su doc actual. |

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
  - `QUANTUM_ALLOW_DECLARED_LAGS=1` — tolera `declared_lags` no vacío. El CI
    lo lleva puesto **hasta el tren de la 7ª** (el tren alinea los requires y
    vacía la lista); al re-pinar hay que quitarlo del workflow.
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
4. **quantum-app** (si la ronda la toca) contra el set re-pinado.
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

La 8ª pasada (REAUDITORIA8, dictamen del §5) fue **la última pasada manual
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
