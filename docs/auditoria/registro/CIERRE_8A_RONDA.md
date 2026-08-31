# Cierre de la 8ª ronda — consolidación final (Quantum 1.9.0)

Fecha: 2026-07-21. Ejecutor: sesión de Claude Code (22ª sesión de la suite), con
5 agentes en paralelo en clones dedicados (bloque A, nucleus B/C, quark,
quantum-app, maquinaria) y el tren + certificación + este cierre en la sesión
principal. Plan: prompt de arranque de la 8ª ronda. Auditoría fuente:
`REAUDITORIA8_QUANTUM.md` (§3 hallazgos, §4 drift/FRENO a #230, §5 dictamen del
régimen).

**Set certificado Quantum 1.9.0** — quark `v1.4.0` (36a1ab72) · nucleus `v1.5.0`
(2634d9b5) · orbit `v1.5.0` (2c151a03; agent/v0.5.5, server/v0.9.0,
quarkbridge/v0.3.5, quarkdatasource/v0.2.7, proto/v0.4.1) · quantum-app `v0.1.1`.
`declared_lags` **vacío**.

**Desviación de nombre (documentada, no silenciada):** el prompt nombró la ronda
«1.8.1» previendo patches; release-please dictó MINORS en los tres pilares
(StrictReads, contrato del outbox, feed HTTP+UI). QADR-0002 obliga a que el
número de suite refleje el vX.Y.Z real → **1.9.0**. Decisión consultada con
Carlos antes del tren y aprobada.

---

## 1. DoD, casilla por casilla (comando + EXIT)

### BLOQUE A — contrato del webhook del outbox (EL FRENO)

nucleus#233 (`feat(outbox)`) + quantum-app#3 (`fix(hooks)`), fusionados.

| DoD | Cierre | Evidencia |
|---|---|---|
| Firma HMAC del bridge | `X-Nucleus-Signature: sha256=<hex>` con `outbox.bridges.<n>.config.secret`, misma forma que webhooks de módulo; sin secret → WARN de arranque | test cruzado `outbox_bridge_signature_test.go`: la firma del bridge la acepta `verifyWebhookSignature` y es idéntica a `SignWebhookBody` |
| Cabecera de encoding | `X-Outbox-Payload-Encoding: json\|base64` SIEMPRE presente | — |
| Compat / default | **default `base64`** (wire de v1.4.0 byte a byte); `payload_encoding: json` opt-in ampara #230; fallbacks: no-JSON→base64 declarado, vacío→null | criterio de menor rotura, sin DECISIÓN REQUERIDA |
| Test de contrato del CUERPO | fixtures byte a byte por variante en `pkg/outbox/testdata/` | negativo: `"payload"`→`"paYload"` → «diverges … at byte offset 112» EXIT=1 |
| Consumidor verifica | quantum-app `/hooks/outbox` con `hmac.Equal` (fuera el `!=`) + lee la cabecera; QA8-6 comentario fósil corregido | E2E LOCAL con go.mod→commit de nucleus#233: `TestOutboxBridgeSignsDeliveries` PASS (sonda sin skip), firma válida→confirma, inválida→401 |
| Docs | página de Storage & background tasks con firma, cabecera, shapes, límites (sin anti-replay) | — |

### BLOQUE B — P2 de producto

| Hallazgo | Cierre | PR | Evidencia rojo/verde |
|---|---|---|---|
| NU8-1 (Oracle SQL inválido en pkg/model stable) | **Rama Oracle implementada** (no reclasificación): `OFFSET/FETCH` en FindAll, `FETCH FIRST 1 ROWS ONLY` en FindByID + `selectOneAdminUserIDSQL` §2.6 de la 7ª | nucleus#232 | rojo contra Oracle real: `ORA-03049 … 'LIMIT'`; verde: `TestCRUDLive_OracleCRUD` PASS en la lane `db-matrix-live-oracle` |
| OR8-1 (v1.4.4 sobre-promete el feed HTTP) | orbit v1.5.0 con nota que **corrige** explícitamente la de v1.4.4 (el feed HTTP no funcionó hasta v1.5.0) | orbit#125 | guard `check_docs_version_claims` EXIT=0 |
| QA8-1 (etiquetas humanas fósiles) | README/TUTORIAL/go.mod/manifest al set actual + **gate nuevo** `check_human_labels.sh` (asierta README+TUTORIAL contra go.mod, dinámico) | quantum-app#5 | rojo: 8 etiquetas fósiles EXIT=1; verde EXIT=0; fixture en `guard_fixtures.sh` |
| QA8-2 (GET orders sin auth expone PII) | `requireUser` en listOrders/getOrder + barrido de PII (resto de endpoints limpios) | quantum-app#4 | E2E `orders_auth_test.go`: 401 sin sesión / 200 con sesión; rojo pre-fix `status 200 (want 401)` |

### BLOQUE C — P3 (todos, cada uno con test/guard)

nucleus (#234, #232): NU8-2 (`path.Clean(p)!=p` → boot falla; `TestRun_NonCanonicalWebhookPathFailsBoot`) · NU8-3 (anti-replay documentado como límite + timestamp firmado opt-in `TimestampTolerance`/`SignWebhookBodyWithTimestamp`, compat body-only intacta) · regla de IDs `\b(QK|NU|OR|QM|QA)[0-9]+-[0-9]+\b` en el linter de voz de nucleus (0 hits reales, negativo probado).

quark (#267, #268): QK8-1 (`Client.BlockedPanicCleanups()` + watchdog con plazo = QueryTimeout; bloqueo simulado con driver fake `panicblockrollback`) · QK8-2 (WARN una vez cuando la normalización numérica de Limits actuó Y `SafeMigrations=false`, sin falsos positivos).

quantum-app (#4, #5): QA8-4 (assert `created_at` non-zero añadido, PG+MySQL) · QA8-5 (minio `RELEASE.2025-09-07T16-13-09Z`, mailpit `v1.30.5`) · QA8-7 (15 unit tests reales: isStorageNotFound/parseID/validaciones/cabeceras) · QA8-8 (`nosniff`+`Content-Disposition: attachment` en datasheets, test) · negativos de `check_no_workspace`/`check_suite_manifest` como fixtures en `guard_fixtures.sh` (6 gates muerden en CI).

quantum (#81): QM8-3 (sidebar-sync exige ≥1 id/lado) · QM8-4 (served-jargon exige >0 HTML) · QM8-5 (suite exige árbol limpio, escape `QUANTUM_ALLOW_DIRTY` solo local) · QM8-7 (anti-fósil escanea guards Go) · QM8-8 (`QUANTUM_OFFLINE=1` explícito). Cada uno con negativo comando+EXIT.

### BLOQUE D — gobernanza (condiciones del dictamen)

quantum#81: **QM8-1** schedule semanal en integration.yml + `notify-schedule-failure` (abre/actualiza issue automático en fallo, sin duplicar; negativo del script en dry-run) · **QM8-2** runbook §6 con disparadores copiados del §5 (verificado por diff), decisor Carlos, plantilla de CIERRE con la regla «un ✅ con asimetría conocida se escribe ⚠️» · **QM8-6** guard del tag de suite `check_suite_tag.sh` (existe ∧ declara la versión ∧ gitlinks==pins ∧ ancestro; decisión mid-tren: verifica el último tag existente contra su propio árbol + AVISO, no FAIL, para no romper el PR de re-pin). Registrado (15º guard) + fixture.

### BLOQUE E — tren y certificación

Tren en orden de dependencia: quark v1.4.0 → re-pin showcase (quark) → nucleus
v1.5.0 → orbit deps-align (#126) → agent v0.5.5 → pin en server (#130) → server
v0.9.0 → quarkbridge v0.3.5 → quarkdatasource v0.2.7 (manifest reconciliado) →
**fix del guard root-edge (#131)** → root v1.5.0 ÚLTIMO → re-pin showcase al set
completo → quantum-app v0.1.1 (etiquetas al final) → **tag de suite v1.9.0 tras
el último PR**.

Certificación POR EL RÉGIMEN NUEVO (estreno, sin pasada manual):
`suite-integral.sh` SIN escapes → **15/15 guards EXIT=0**; `guard-of-guards.sh`
→ **15/15 fixtures muerden**; `manifest-guard.sh` §1-§5 EXIT=0; sitio construido
sobre los pins nuevos; E2E de quantum-app 7/7 en CI (con la firma del outbox
verificada end-to-end tras el bump a nucleus firmante).

## 2. Desviaciones (documentadas)

1. **Nombre 1.9.0 vs «1.8.1»** — arriba; QADR-0002, aprobado por Carlos.
2. **GO-2026-5970 (x/text) transversal** — advisory publicada durante la ronda,
   alcanzable en los cuatro repos vía `database/sql`/proxy; bump mecánico a
   v0.39.0 (quark#269, nucleus en #233, orbit por MVS en #126, quantum-app por
   MVS). No previsto en §3; desbloqueo de CI heredado.
3. **Lane Oracle endurecida (fuera de §3)** — NU8-1 hizo el CRUD Oracle
   load-bearing y afloró un flake de readiness (`ORA-12514`: el healthcheck
   gateaba solo el puerto, no el registro de FREEPDB1). Fix nucleus#235
   (`ci(oracle)`: healthcheck del contenedor). Bajo el régimen que se instala,
   una lane requerida flakeando dispararía el issue automático — por eso se
   arregló en la ronda, no se dejó.
4. **Guard root-edge ampliado (maquinaria, orbit#131)** — la excepción
   same-minor-only fallaba cuando el root cruza un minor (v1.4.4→v1.5.0):
   quarkdatasource, contenido en el tag del root, no puede pinar v1.5.0. Se
   amplió a ≤1 minor de lag (mismo major); ≥2 minors sigue vetado (rot OR5-3).
   Negativos probados. **Es un cambio de la propia maquinaria → entra en la
   revisión dirigida del §4.**
5. **Cascada DIRTY del manifest** (quarkdatasource, root) reconciliada a mano —
   patrón conocido; el push humano a la rama del release dispara CI.

## 3. Pendiente

**VACÍA.** No hay pendiente silencioso. Los hallazgos de §3 están todos
cerrados con test/guard; las desviaciones están arriba; la revisión dirigida de
seguridad del §4 es un ACTO del régimen nuevo, no un pendiente.

## 4. Primer acto del régimen: solicitud de revisión humana DIRIGIDA

Conforme a los disparadores §6.1 (superficie de seguridad nueva/cambiada) y
§6.3 (cambio en la propia maquinaria) del runbook `AUDITORIA_CONTINUA.md` que
esta ronda instala, y **no** como una ronda completa: se solicita una mirada
humana ACOTADA a la superficie que este arco tocó —

**Seguridad (§6.1):**
- Bloque A: la firma HMAC del bridge del outbox (constant-time, material
  firmado = cuerpo; ¿el default base64 y el opt-in json son la elección de
  menor rotura correcta?; ¿el fallback no-JSON→base64 es honesto?).
- QA8-2: `requireUser` en lecturas de pedidos (¿el barrido de PII fue completo?).
- NU8-2 (paths canónicos de webhooks) y NU8-3 (anti-replay: el límite
  documentado + el timestamp firmado opt-in — ¿el material `ts + "." + body`
  y la tolerancia son correctos?).

**Maquinaria (§6.3):**
- orbit#131: el diff del guard root-edge (¿tolerar ≤1 minor de lag en la arista
  del root es la invariante correcta, o abre una puerta?).
- nucleus#235: el healthcheck de la lane Oracle.
- quantum#81: schedule + issue automático + el guard del tag de suite.

Si la revisión no encuentra nada, la 9ª «auditoría» es la lane semanal verde +
CI por-repo verde. Si encuentra algo, es el backlog de un arco nuevo, no de una
ronda.

## 5. Verificación final (comando + EXIT)

- `bash scripts/manifest-guard.sh` → EXIT=0 (pins nuevos, 5 tags de módulo
  ancestros, README==manifiesto).
- `bash scripts/suite-integral.sh` (SIN escapes, árbol limpio) → «guards
  registrados: 15 · ejecutados: 15 · con fallo: 0» EXIT=0.
- `bash scripts/guard-of-guards.sh` → «15 · muerden: 15» EXIT=0.
- `bash scripts/check_suite_tag.sh` → EXIT=0 (una vez cortado v1.9.0; mid-tren
  daba AVISO por diseño).
- quantum-app: `check_human_labels` EXIT=0, `check_suite_manifest` 797 ítems
  EXIT=0, E2E 7/7 en CI.
- serie de pasadas: 4ª→2 P0 · 5ª→3 P1 · 6ª→0 · 7ª→0 · 8ª→0 (última manual).
