# /next-session — arranque de sesión para Quantum (paraguas)

> Comando de arranque para Claude Code en el repo **`quantum`** (el paraguas).
> Audita el estado real de la suite y ancla la sesión al foco correcto.
> No es el `/next-session` de Quark ni el `/resume` de Nucleus: aquí coordinas
> la suite, no tocas el código de los productos.

## 0. Qué es Quantum (recordatorio de una frase)

Suite de tres productos Go que se desarrollan por separado y se coordinan bajo un
paraguas: **Nucleus** (framework web, el host), **Quark** (ORM, usable en solitario)
y **Orbit** (admin que monta in-process en Nucleus). El repo `quantum`
**coordina, no contiene**: fija el trío compatible (`versions.yaml`) y da un
`go.work`. Detalle en [`README.md`](../../README.md) y [`docs/ROADMAP.md`](../../docs/ROADMAP.md).

## 1. Protocolo de arranque (hazlo SIEMPRE antes de tocar nada)

1. **Lee** [`versions.yaml`](../../versions.yaml) (el set certificado vigente) y
   el §3 de abajo (estado vigente + las DOS últimas sesiones; lo anterior
   está archivado en `docs/handoff/` y NO se carga: se busca con grep). [`docs/ROADMAP.md`](../../docs/ROADMAP.md)
   guarda las cinco fases, **todas cerradas** desde Quantum 1.0.0: hoy el
   trabajo entra por **arcos**, no por fases.
2. **Audita el estado real** con bash:
   - `git submodule status` — ¿siguen los submódulos en el trío de `versions.yaml`?
   - `git -C quark describe --tags`, idem `nucleus`, `orbit` — ¿coinciden con `workspace_pins`?
   - `go build $(bash scripts/gowork-patterns.sh)` (el root del workspace no es un
     módulo; los patrones explícitos salen del go.work, que cubre los 26 módulos).
   - `gh pr list` y `gh issue list` en los cinco repos (quantum, quark, nucleus,
     orbit, quantum-app) — qué quedó abierto.
   - `scripts/suite-integral.sh` si vas a certificar o sospechas deriva; la lane
     semanal (§5) ya la corre los lunes.
3. **Reconcilia** con el §3: ¿qué arco quedó a medias y cuál es el siguiente?
   Los pendientes con destinatario están en el §5.
4. **Propón el foco** de la sesión (un arco concreto) antes de trabajar, y deja
   que el responsable lo confirme.

## 2. Reglas duras que NO se rompen (mismas que el brief de Fase 0 y los QADR)

1. **Cada producto en su repo; `quantum` solo coordina** (no contiene código). [QADR-0001]
2. **Versionado en dos niveles**: el número Quantum nunca falsea el `vX.Y.Z` real
   que la gente instala. [QADR-0002]
3. **Docs**: la fuente vive en cada repo; el sitio unificado *ensambla*, no posee. [QADR-0003]
4. **Anti-hype**: sin superlativos de marketing —afirmaciones exageradas de
   madurez o de rendimiento— en commits, README, ADRs ni roadmap. La cultura
   anti-hype se hereda de Quark; el grep de esos términos debe seguir vacío (por
   eso este propio fichero no los nombra en literal).
5. **`go.work` es solo dev local**; sin `replace` en los `go.mod` de los productos.
6. **Quark sigue usable en solitario**; nada lo obliga a depender de Nucleus/Orbit.
7. **Conventional Commits**; trabaja en rama y abre PR (no commitees directo a `main`).

## 3. Estado al cierre (2026-09-05 noche, QUANTUM 1.28.0 — A1 cerrado, en la puerta de A2)

### Estado vigente (léelo entero; es lo único que hace falta para arrancar)

- **Set certificado: Quantum 1.28.0** (2026-09-05) — quark v1.11.0, nucleus
  v1.24.0, orbit v1.9.2 y sus módulos, tal como los lista `versions.yaml`
  (la fuente; no copies números de aquí). `declared_lags` vacío.
- **Trabajo por arcos del plan 5/5** (artefacto «Quantum a 5 de 5» y
  `docs/RUMBO.md`): **A1 CERRADO** en 1.28.0 → **A2 starter de suite es el
  SIGUIENTE** → A3 cadena de suministro (hereda QK-14) → A4 … → A12. El gate
  de cada arco es el registro `docs/auditoria/madurez-2026-09-03/registro.csv`
  con su guard `umbrella-audit-backlog` (cero abiertos en un arco cerrado).
- **Cadencia**: set semanal (QADR-0008); un corte fuera de cadencia lleva la
  razón escrita en `status:` de `versions.yaml`.
- **Reglas que ya se decidieron (no reabrir sin motivo nuevo)**:
  - Un `!`/BREAKING CHANGE decide el major de la suite entera (QADR-0002);
    un movimiento de empaquetado con error guiado es minor (ADR-032 de
    nucleus). Nunca se repara con Release-As.
  - El `require` de un hermano es un SUELO (MVS resuelve al máximo); el
    manifest-guard AVISA por los suelos y FALLA por los pines CRUZADOS de
    orbit → `align_set.sh` de orbit tras cortar quark/nucleus (el tren lo
    hace desde 1.28.0). Los suelos módulo→raíz suben como PRIMER commit de
    cada corte (`sube_suelos` en `train.sh`).
  - Voz de producto en inglés (QADR-0007): commits, títulos de PR (guard en
    los tres repos), código y docs. El paraguas y los CLAUDE.md, en español.
  - Todo PR de docs de release, guards o baselines entra ANTES del tag.
  - Las deudas de doc por minor (RT-9) se pagan EN la rama del release PR;
    el tren corre el esqueleto de quark solo (`quark-doc-debt.sh`).
- **Dónde está cada cosa**: trampas del tren → `scripts/train/README.md`
  (índice «Trampas transversales» + una sección por tren); decisiones →
  `docs/adr/` y los ADR de cada pilar; historia de sesiones anteriores al
  2026-09-03 → `docs/handoff/sesiones-2026-07-12_a_2026-09-02.md` (grep, no
  cargar); memoria de la sesión de Claude → `~/.claude/projects/.../memory/`.
- **Pendientes con destinatario**: §5.

### Sesión 2026-09-05 (b) — A1 cerrado: la deuda de auditoría publicada en QUANTUM 1.28.0

- **SET**: quark **v1.11.0** (+ `drivers/*` v0.1.2) · nucleus **v1.24.0**
  (+ once módulos v0.1.2, `providers/ldap` v0.2.6) · orbit **v1.9.2**
  (agent v0.6.16, server v0.11.2, quarkbridge v1.8.20, quarkdatasource
  v1.8.21, proto v0.4.4): v1.9.1 publica A1 y v1.9.2 alinea los pines
  cruzados. Certificado con `suite-integral --cierre` (ver el CHANGELOG del paraguas para el recuento de guards).
- **A1 = la deuda de la auditoría de madurez asignada al arco** (las filas
  cerradas pierden el arco en el CSV: se cuentan por evidencia),
  cerrados con evidencia en `docs/auditoria/madurez-2026-09-03/registro.csv`
  (`# arcos_cerrados: A1`; el guard `umbrella-audit-backlog` exige cero
  abiertos en un arco cerrado). Nucleus 27 (nucleus#468–#474), quark QK-6 y
  QK-8 (quark#350), orbit fleet 8 (orbit#427) y panel 6 (PANEL_PRS),
  suite QM-18 (títulos de PR en inglés con guard en los tres repos) y QM-19
  (los suelos de los hermanos suben como PRIMER commit de cada corte:
  `align-module-floors.sh` dentro de `train.sh`).
- **Lo que se difiere a propósito**: QK-14 (el `go.mod` raíz de quark
  requiere los cinco drivers porque el CLI enlaza todos los motores) va a A3
  con nota en el README: sacarlos exige mover el CLI a módulo propio. QK-8
  paso 2 (`drivers/postgres` adoptando `ListenerFactory`) espera el tag
  v1.11.0 y entra en el próximo tren.
- **TRAMPA DEL TREN, esta vez prevista por RT-9 y aun así costó una vuelta**:
  el Lint del release PR de quark (#349) falló por la deuda de doc de la
  minor — la entrada v1.11.0 en CLAUDE.md y el puntero del README a
  `docs/RELEASE_NOTES_v1.11.0.md` se escriben A MANO en la rama del release
  (CLAUDE.md no está en extra-files a propósito). Y un detalle nuevo: un
  `docs(release):` fusionado DESPUÉS de que el bot generase la rama NO la
  regenera (los docs no cambian el changelog), así que la rama no trae las
  notas ni el snapshot; el tag sale bien porque el squash cae sobre `main`,
  pero para correr el guard en local sobre la rama hay que meterle `main`
  (`git merge origin/main`) — o los errores del guard mienten.
- **TRAMPA QUE EL TREN NO CUBRE — pines cruzados de orbit.** Si quark y
  nucleus se cortan en el mismo tren, la fase orbit corta con los
  `require` viejos y el manifest-guard §5 FALLA (no avisa: los pines
  cruzados no son suelos tolerados salvo `declared_lags`). Costó un
  segundo corte de orbit (v1.9.2). Regla: tras los tags de quark y nucleus
  y ANTES de la fase orbit, `orbit/scripts/release/align_set.sh --nucleus
  vX --quark vY` en rama + PR + merge. Deuda: meterlo en `train.sh`
  (fase orbit, antes de merge-bot-pr), igual que `sube_suelos`.
- **Lección de los workflows**: un `votes.filter(Boolean)` cuenta cero
  revisores como cero pegas; si los verificadores mueren (límite de
  sesión) el resultado sale «approved» vacío. Mirar `failures` y `notes`
  antes de fusionar; `resumeFromRunId` relanza sólo los que fallaron.
- **Siguiente arco: A2 (starter de suite)** — ver el plan 5/5 (artefacto).


### Sesión 2026-09-03/05 — auditoría de madurez, sets 1.26.1 → 1.27.0, ADR-006 de orbit y la semana 1 del plan 5/5

- **SET VIGENTE: QUANTUM 1.27.0** (2026-09-05, quantum#148, tag `v1.27.0`,
  `--cierre` 32/32, release GH publicada): quark **v1.10.1** (+5 drivers
  v0.1.1) · nucleus **v1.23.2** (+12 módulos v0.1.1, ldap v0.2.5) · orbit
  **v1.9.0** (server v0.11.0, proto v0.4.4, agent v0.6.14, puentes v1.8.19).
  `declared_lags: {}`. Antes, en la misma serie: **1.26.1** (2026-09-04: los
  cinco PRs de la auditoría fusionados —quark#338, nucleus#455, orbit#380 y
  #379, quantum#136—; orbit v1.8.20, nucleus v1.23.1) y **1.26.2** (corte
  fuera de cadencia: quantum-app en rojo contra 1.26.1 por OR-32; orbit
  v1.8.25, nucleus v1.23.2; `declared_lags` restaurada y `manifest-guard` §0).
- **Auditoría de madurez frente al mercado (2026-09-03)**: 147 defectos, 4 P0
  (QK-1 drivers rechazados por alias; OR-1 el `tls.Config` del server nunca se
  aplicaba; NU-55/56 ejemplo y docs de drivers). Informe en artefacto y copia
  en `~/Documents/Claude/Projects/Quantum/auditoria/madurez-2026-09-03/`.
  Veredicto: plataforma sólida; producto de aplicación a medias (sin starter
  de suite, sin OIDC ni API keys, admin sin validación ni usuarios,
  ecosistema cero).
- **Plan a 5 de 5 en doce arcos (A1–A12)**, artefacto
  https://claude.ai/code/artifact/cbd9d082-7404-4989-bd79-7408f9dbaf38, con el
  mapa «del hoy al 5» (35 dimensiones, media 2,8, ninguna en 5). Orden:
  semana 1 tren → A1 deuda de auditoría (semanas 2–4) → A2 starter de suite →
  A3 cadena de suministro → A4 Quark como capa de datos de Nucleus → …
- **ADR-006 de orbit** (2026-09-05, orbit#423 y #424 → v1.9.0): `server` deja
  de requerir `agent` (los tests que arrancan un agente viven en
  `orbit/internal/fleettest`, módulo de solo test; `internal/*` queda fuera
  del descubrimiento del paraguas); `proto` es hoja deliberada; Dependabot
  usa `fix(deps)` en los módulos publicados. De ocho cortes de raíz de orbit
  en dos días, cinco no publicaban producto: eso es lo que cierra.
- **Sesión `auto` del 2026-09-05 (tarde) — la semana 1 del plan, cerrada:**
  - **La causa del auto-bloqueo de release-please, encontrada y quitada.** El
    log de orbit#399 y nucleus#466 dice «PR component: undefined does not
    match configured component». Un release PR con UNA sola release —la de
    la raíz— se trata como standalone y su componente de rama (ninguno, con
    el merge plugin) se compara con el `package-name` de la raíz. Arreglo:
    sin `package-name` en la raíz de `release-please-config.json` —
    orbit#426, nucleus#467 y quark#347 FUSIONADOS (chore, sin release). La
    prueba en vivo es el próximo corte de raíz sola; mientras,
    `merge-bot-pr.sh` lee el log de la corrida del commit de merge y aplica
    `untag-recipe.sh` solo (que ya no hace checkout: etiqueta por SHA).
  - **`bump-set.sh` escribe la parte humana que se rompía a mano**
    (`scripts/lib/set-notes.py`): versión de suite por QADR-0002 desde el
    salto real de los pilares, `released`, `status`, las notes anteriores al
    CHANGELOG y un esqueleto de notes con marcadores `REDACTAR`;
    `manifest-guard` §0 rechaza el marcador (`QUANTUM_ALLOW_NOTES_SKELETON=1`
    solo en local; el driver lo pone). Idempotente: con esqueleto presente
    solo acepta `--set` para cambiar el número.
  - **QM-19**: `scripts/train/align-module-floors.sh <nucleus|quark>` sube los
    suelos módulo→raíz (hoy 12 de 12 en nucleus a v1.23.0 y 5 de 5 en quark a
    v1.10.0: los 18 AVISOs de §5b). El driver imprime `--check` antes de cada
    repo. **DECIDIDO (Carlos, 2026-09-05): al principio de cada corte**, como
    primer commit; el driver lo hace solo en la fase de cada repo (rama, PR,
    fusión, espera de Release Please). Es un `fix(deps)` que corta un patch
    por módulo tocado.
  - orbit#425 (Dependabot, dependencia de desarrollo del UI) fusionado. Cero
    PRs abiertos en los cuatro repos; **quantum-app#13** (bump al set 1.27.0,
    E2E verde) espera la fusión de Carlos.

**TRAMPAS NUEVAS** (todas en `scripts/train/README.md`, secciones «tren de
1.27.0», «1.26.2» y «1.26.1»): un módulo con cambios sin tag deja la raíz no
certificable (por eso Dependabot va con `fix(deps)`); el push de un merge
puede no disparar «Release Please» (el driver lo dispara a los dos minutos);
los patches también llevan sección `## vX.Y.Z` en las release notes; la doc
de producto no puede citar ADRs; `merge-bot-pr.sh` se lanza desde la raíz del
paraguas; un artefacto republicado por otra sesión exige leerlo entero antes
de publicar; y quantum-app bumpea desde `main` SIN los imports de módulos,
así que cada set exige el cherry-pick de los imports hasta que Carlos
fusione un PR del bump.

- **A1 en marcha (misma tarde, «Adelante con A1, los suelos al principio de
  cada corte»)**: suelos estrenados (nucleus#469, quark#348); registro
  machine-readable de los 190 hallazgos en
  `docs/auditoria/madurez-2026-09-03/registro.csv` con el guard
  `umbrella-audit-backlog` (33) como gate de A1; nucleus A1 FUSIONADO en
  tres PRs (#471 router, #472 auth/tasks/datos, #473 CLI/docs con ADR-032
  «packaging move» vs `!` y commits en inglés con lint del título); quark#350
  (migrador con lock por defecto y UpTx, contrato público del listener,
  QK-14 → A3) y orbit#427 (plano fleet: cap por operador, matcher, LIKE,
  reconexiones, CPU, semáforo, CSP) en fusión. **QUEDA de A1**: NU-61 (el
  snapshot del minor de nucleus, se cierra al cortar) y el panel in-process
  de orbit — OR-14 IDs string, OR-16 audit completo, OR-23 tenant en todas
  las operaciones, OR-35, OR-43, OR-44 — y después el corte del set con el
  tren (nucleus y quark salen minor).

**PRÓXIMO FOCO**: terminar A1 con el panel de orbit (OR-14, OR-16, OR-23,
OR-35, OR-43, OR-44), cortar el set con `train.sh` (el snapshot 1.24.0 de
nucleus cierra NU-61), declarar `A1` en `arcos_cerrados` del registro (el
guard exige cero P1/P2 abiertos) y seguir con A2 (starter de suite).

## 4. Las fases (resumen; el detalle y el "hecho cuando" están en docs/ROADMAP.md)

> **Las cinco fases están CERRADAS** desde Quantum 1.0.0 (2026-07-11): los tres
> pilares en major 1 bajo un manifiesto de suite, con régimen de majors en
> lockstep (QADR-0002). La tabla queda como referencia histórica; el trabajo
> nuevo entra por arcos (§5) bajo el régimen de auditoría continua.

| Fase | Objetivo | Hecho cuando |
|---|---|---|
| 1 | **Identidad/marca Quantum**, portada de la suite | Front page que nombra y enlaza los tres pilares y aclara el uso standalone de Quark |
| 2 | **Docs unificadas**: Docusaurus multi-instancia en `website/`, product switcher, doble selector de versión, un solo deploy en `/quantum/` | Un sitio sirve las tres docs bajo una marca, sin sacar la fuente de cada repo |
| 3 | **Convenciones + primera release**: `release-please` a Nucleus/Orbit, instancia de docs de Orbit, **Quantum 0.1.0** con CI de integración | Set Quantum reproducible y verificado por CI |
| 4 | **Integración demostrada**: ejemplo Nucleus+Quark+Orbit + CI que ejerce los tres | Hay un ejemplo ejecutable y CI del set |
| 5 | **Convergencia Quantum 1.0**: Nucleus y Orbit a v1.0, régimen de majors en lockstep | Los tres en major 1 bajo un manifiesto Quantum 1.0 |

## 5. Pendientes técnicos anotados (revísalos cuando apliquen)

> Puesto al día el 2026-09-05. Lo que esta sección listaba antes (integración
> Quark↔Orbit de QADR-0005/0006, pin de nucleus en `8714882c`, `status:
> pre-fusion`, retirada de los Pages standalone de los productos, y el plan de
> extensibilidad A–H, cerrado en Quantum 1.22.0) está **todo hecho y publicado**: los tres pilares llevan desde Quantum 1.0.0 (2026-07-11)
> en major 1 con los pines EN TAG, `quarkbridge`/`quarkdatasource` van en el
> set (v0.4.0 / v0.2.14) y `jcsvwinston.github.io/{quark,nucleus,orbit}` ya
> sirven el redirector al sitio unificado. El histórico de cómo se llegó ahí
> vive en el §3 y en `docs/auditoria/`.

**Trabajo con destinatario (por orden de arranque):**

- **El plan a 5 de 5** (artefacto en el §3, sesión 2026-09-03/05) manda el
  orden: ~~A1 deuda de auditoría~~ (CERRADO en 1.28.0) → **A2 starter de
  suite** (SIGUIENTE) → A3 cadena de suministro (hereda QK-14) → A4 Quark
  como capa de datos → … → A12. El registro de hallazgos y su guard
  (`umbrella-audit-backlog`) siguen siendo el gate de cada arco.
- **Pendiente de Carlos**: fusionar quantum-app#13 y el PR de bump que
  dispara el cierre de 1.28.0. Deuda del tren anotada arriba: `align_set.sh`
  de orbit dentro de `train.sh` antes de la fase orbit; y el paso 2 de QK-8
  (quark#352) + la mitad nucleus de OR-43 (nucleus#476) salen con la
  siguiente release de cada pilar.
- **Lo que deja a deber el arreglo del auto-bloqueo**: la prueba en vivo. El
  próximo release PR de raíz sola en cualquiera de los tres repos debe
  etiquetar sin receta; si vuelve a fallar, el diagnóstico está en la
  cabecera de `scripts/train/untag-recipe.sh` y el driver aplica la receta.
- **Backlog DX abierto** (del diagnóstico de los arcos DX y DX-2): `quark
  migrate diff`, clasificación de errores exportada de quark
  (`IsUniqueViolation` — hoy degrada a `lib/pq`), ayuda del CLI de nucleus,
  `doctor` unificado, `profile: dev` visible, snapshots de quark congelados,
  índice de ADRs, y la **capa 3 de automatización de docs**: la que REDACTA la
  narrativa, no solo la que mueve versiones (capas 1 y 2 hechas —
  `scripts/bump-set.sh` con `set-notes.py`, `cut_docs_snapshot.sh` + guard de
  frescura; el esqueleto de notes con `REDACTAR` es estructura, no redacción).
- **Roadmap enterprise de nucleus**: Tracks **F** (cloud — Secrets Manager/KMS/
  Lambda, Pub/Sub, Service Bus) y **G** (tooling — doctor unificado, wizard,
  asistentes de migración) siguen abiertos. El **Track E** (seguridad) se cerró
  con evidencia en Quantum 1.16.0.
- **quark**: cierres **S8/S9** pendientes.

**Deuda DECLARADA por escrito (no es olvido; no reabrir sin motivo nuevo):**

- **quark#265** — binder generado de codegen (F6-3b), aplazado por disposición
  escrita. Reabrir solo por type-safety o corrección, no por estética.
- **Rate limiting apagado por defecto** (nucleus): voltear
  `rate_limit_requests: 0` haría que cada despliegue existente empezara a
  rechazar tráfico al actualizar → pertenece a una **major con ventana de
  deprecación**. Escrito así en el roadmap de nucleus (Track E).
- **Huecos del archivo de documentación**: el de orbit empieza en 1.6.7. No se
  fabrican snapshots retroactivos — uno afirmaría que la doc de hoy fue la de
  entonces, justo lo que el mecanismo existe para impedir.

**Vigilancias abiertas (nada que hacer hoy; qué mirar si rebrota):**

- **Flake NO cerrado**: pánico `-race` en el teardown de `pkg/outbox` de nucleus
  (`database/sql.(*Rows).close→awaitDone`), visto UNA vez en CI y no
  reproducible en local. El `Stop` grácil de v1.11.0 elimina el disparador más
  plausible y arregla un abandono real de entregas a medio pase, pero **no se
  declara arreglado**; hay canario de 50 ciclos Start/Stop en la suite. Si
  rebrota: `GOTRACEBACK=all` en linux/amd64, y para recuperar el trace de un
  intento anterior `gh api repos/<r>/actions/runs/<id>/attempts/1/jobs` — un
  rerun verde ESCONDE el pánico (`gh run view` solo enseña el último intento).
- **Prosa que FUE verdad**: la clase de hallazgo que ningún guard caza (la web
  anunciando como «en despliegue» algo que llevaba meses corriendo). Al tocar
  una feature, mirar la página que la describe.

**Régimen operativo vigente (desde Quantum 1.9.0):**

- Certificar = lane semanal verde + CI por repo verde + juicio humano por
  disparadores. **Ya no hay rondas completas de auditoría**; el trabajo entra
  por arcos. Runbook: [`docs/AUDITORIA_CONTINUA.md`](../../docs/AUDITORIA_CONTINUA.md).
- `suite-integral.yml` corre los **lunes 06:00 UTC** e `integration.yml` a las
  **06:30**; una lane roja abre issue automático. Hoy hay **32 guards**
  registrados y `guard-of-guards` prueba con fixture que cada uno muerde.
- Escribir el set: `scripts/bump-set.sh` (submódulos al tag, los bloques de
  módulos, pins y tablas del README, y desde 1.27.0 la versión de suite por
  QADR-0002, las notes anteriores al CHANGELOG y el esqueleto de las nuevas
  con `REDACTAR`, que `manifest-guard` §0 rechaza hasta redactarlo); el juicio
  lo pone `manifest-guard.sh` después. La
  corrida `suite-integral.sh --cierre` va **TRAS** el tag de suite (QM7-3), y el
  pre-check exige árbol limpio (`QUANTUM_ALLOW_DIRTY=1` solo para iterar en
  local).
- Al cerrar un arco, el snapshot de docs se corta **el último** de los cambios
  de la ronda, y el re-pin de `examples/showcase_demo` (nucleus) va **después**
  de todos los tags del set.

## 6. Cómo cerrar la sesión

Actualiza el §3 de este archivo (estado al cierre) con lo que avanzaste y el
próximo foco, para no romper el contexto a la siguiente sesión — entrada nueva
ARRIBA, no al final. Si un pendiente del §5 se cierra o nace uno nuevo, tócalo
allí en el mismo cambio: un §5 rancio contradice al §3 y desorienta más que la
ausencia de nota.

Si cambia una decisión de coordinación, abre un QADR sucesor (no reabras uno
aceptado).
