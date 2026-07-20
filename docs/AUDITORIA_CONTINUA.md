# Auditoría continua — certificación mecánica de la suite

Runbook interno del paraguas (7ª ronda). Describe qué comprueba la
certificación mecánica, cómo se demuestra que los checks siguen vivos, el
procedimiento de cierre de una ronda y qué queda deliberadamente fuera, para
el juicio humano.

Piezas:

| Pieza | Ruta | Qué hace |
|---|---|---|
| Registro de guards | `scripts/lib/guard-registry.sh` | Única fuente de verdad: nombre → cwd → comando de cada guard, más la aserción anti-fósil. |
| Lane de certificación | `scripts/suite-integral.sh` | Ejecuta TODOS los guards del registro contra el árbol pinado; tabla `guard → EXIT`. |
| Guard-of-guards | `scripts/guard-of-guards.sh` + `tests/guard-fixtures/` | Ejecuta cada guard contra una fixture de fallo y exige que muera por la causa esperada. |
| CI | `.github/workflows/suite-integral.yml` | Ambos, en PR (paths relevantes), a demanda y cada lunes 06:00 UTC. |

## 1. Qué cubre la certificación mecánica

`bash scripts/suite-integral.sh` desde la raíz del paraguas. Precondiciones
(anti-fósil, `declared_lags` vacío, submódulos con historia y tags, build del
sitio) y después los guards del registro, todos, capturando el EXIT de cada
uno sin abortar al primero. EXIT global ≠ 0 si cualquier cosa falló.

Los guards de producto corren **al pin** — el submódulo tal y como lo fija
`versions.yaml`. Un fallo ahí no significa «el CI de otro repo está roto»:
significa que el set que el manifiesto certifica no pasa sus propios guards,
que es exactamente lo que reportaría un auditor.

Registro actual (14 guards):

| Guard | Repo | Comando | Qué caza |
|---|---|---|---|
| umbrella-manifest-guard | paraguas | `bash scripts/manifest-guard.sh` | Manifiesto afirmando lo que git no respalda: pin ↔ tag ↔ gitlink (§1–§2), tags de módulo de orbit contra el root pinado (§3), tabla del README (§4), lags cross-repo no declarados (§5). |
| umbrella-served-jargon | paraguas | `bash scripts/check_served_jargon.sh website/build` | Jerga interna (ADR-nnn, P0…, IDs de hallazgo QK/NU/OR/QMn-n) en el HTML **servido**, tras el build. |
| umbrella-sidebar-sync | paraguas | `bash scripts/check_sidebar_sync.sh` | Sidebars espejadas (nucleus/quark) desincronizadas del sidebar del submódulo pinado. |
| nucleus-version-claims | nucleus | `bash scripts/ci/check_version_claims.sh` | Marcadores `x-release-please-version` desalineados, directivas Go del scaffold, estados README↔inventario. |
| nucleus-product-voice | nucleus | `bash scripts/ci/check_docs_product_voice.sh` | Vocabulario interno en `website/docs/**`. |
| nucleus-contract-freeze | nucleus | `bash scripts/ci/check_contract_freeze.sh` | Removals en los contratos congelados (CLI, config, símbolos estables) + firewall de tipos. |
| nucleus-docs-coverage | nucleus | `bash scripts/website/check-coverage.sh --strict` | Tokens legacy, referencias `covers:` colgantes y (vía bodycheck) falsedades de cuerpo en la web pública. |
| nucleus-bodycheck | nucleus | `go run ./scripts/website/bodycheck -strict` | Falsedades duras en el cuerpo de las páginas: versión de Go, símbolos Go inexistentes, tags `db:` que el parser real no reconoce. |
| quark-version-coherence | quark | `bash scripts/check-version-coherence.sh` | Versión publicada ausente de README/SECURITY/CLAUDE/release-notes; roadmap con versiones hardcodeadas. |
| quark-product-voice | quark | `bash scripts/ci/check_docs_product_voice.sh` | Vocabulario interno en `website/docs/**`. |
| quark-lint-docs | quark | `bash scripts/lint-docs.sh` | Lenguaje de marketing, fugas `RELEASE_NOTES_V1`, enlaces relativos rotos. |
| orbit-product-voice | orbit | `bash scripts/ci/check_docs_product_voice.sh` | Vocabulario interno en `website/docs/**`. |
| orbit-docs-version-claims | orbit | `bash scripts/ci/check_docs_version_claims.sh` | Marcadores `x-release-please-version` desalineados con la versión publicada. |
| orbit-internal-pins | orbit | `bash scripts/ci/check_internal_pins.sh` | Pins entre módulos hermanos por detrás del último tag publicado. |

Notas operativas:

- **Red y tags.** `manifest-guard` (§2–§3) y `check_internal_pins` comparan
  contra tags publicados: los submódulos necesitan historia completa y tags
  fetcheados. La lane completa la historia si el clone es shallow y fetchea
  tags antes de ejecutar (con aviso si no hay red).
- **Fallos legítimos al pin.** Si la ronda en curso ya cortó tags nuevos en un
  remoto (p. ej. un `agent/vX.Y.Z` de orbit), `manifest-guard §3` y/o
  `orbit-internal-pins` se ponen rojos **con razón**: el set pinado quedó por
  detrás de lo publicado. No se silencia — es información de certificación.
  La corrida del lunes existe para que esa deriva aflore sin esperar a un PR.
- **Escapes documentados** (solo a mitad de ronda, nunca en el cierre):
  - `QUANTUM_ALLOW_DECLARED_LAGS=1` — tolera `declared_lags` no vacío. El CI
    lo lleva puesto **hasta el tren de la 7ª** (el tren alinea los requires y
    vacía la lista); al re-pinar hay que quitarlo del workflow.
  - `QUANTUM_SKIP_BUILD=1` — reutiliza `website/build` existente para iterar
    en local. En CI siempre se construye.

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
   aún iba a cambiar.
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
