# Cierre — Arco de endurecimiento #1 (Quantum 1.10.0)

**Naturaleza:** micro-arco de *hardening*, NO una ronda. Cierra a CERO el backlog completo de `REVISION_DIRIGIDA_SEG_1.md` — la primera revisión dirigida de seguridad que produjo el régimen de auditoría continua. Quantum 1.9.0 seguía certificada; esto es endurecimiento, ejecutado con el rigor de siempre (cada fix con test o guard, negativos probados, verificación por ejecución).

**Set certificado:** **Quantum 1.10.0** — quark v1.4.0 (`36a1ab72`), nucleus v1.6.0 (`26c5b60a`), orbit v1.5.1 (`bf5e0d7e`) + agent/v0.5.6, server/v0.9.1, quarkbridge/v0.3.6, quarkdatasource/v0.2.7, proto/v0.4.1; quantum-app v0.1.2. `declared_lags` vacío.

**Numeración:** 1.10.0 (minor) y no «1.9.1» porque el minor de nucleus (v1.5.0→v1.6.0) obliga al número de suite a reflejar el vX.Y.Z real (QADR-0002). Anticipado por el plan; no es desviación.

**Hallazgo del régimen respetado:** el framework (quark/nucleus/orbit) quedó LIMPIO en la revisión. NO se inventó trabajo de seguridad en el framework. Lo accionable estaba en la app de referencia (que enseñaba el anti-patrón credencial-por-defecto) y en la maquinaria; SEC-3/SEC-4 entran en nucleus como defensa en profundidad, tal como el plan los nombra.

---

## Definición de hecho — casilla a casilla

### ✅ A.1 · SEC-1 · quantum-app: `WAREHOUSE_OUTBOX_SECRET` fail-closed
`main.go` incorpora `mustEnv` + `validateDeploymentSecret`: el arranque **muere** (`log.Fatalf`) si un secreto de despliegue va sin fijar, vacío, o con un valor-ejemplo público del repo (`dev-outbox-secret`, `dev-outbox-token`, `warehouse-ops`). Aplicado a `WAREHOUSE_OUTBOX_SECRET` **y** `WAREHOUSE_OPS_PASSWORD` (frontera secreto/no-secreto documentada en README y `docs/TUTORIAL.md`; los DSN de localhost siguen siendo `envOr` por no ser secretos de producción).
- **PR:** jcsvwinston/quantum-app#7 (`fix(warehouse): secretos de despliegue fail-closed y firma HMAC obligatoria en /hooks/outbox (SEC-1, SEC-2)`), MERGED.
- **Gate:** unit `validateDeploymentSecret` (unset/empty/valor-`dev-` → error; valor propio → nil); E2E exporta valores CLARAMENTE-CI (`ci-e2e-outbox-secret`, `ci-e2e-ops-password`) y arranca 7/7.

### ✅ A.2 · SEC-2 · quantum-app: sin downgrade al token estático
`authenticateOutboxDelivery` exige SIEMPRE la firma HMAC del cuerpo (`X-Nucleus-Signature`, comparada con `hmac.Equal`); sin cabecera de firma → 401. `OutboxToken` y su default eliminados. Comentario del handler actualizado (ya no describe un estado futuro).
- **PR:** jcsvwinston/quantum-app#7, MERGED.
- **Gate (rojo-sin-fix demostrado):** `TestOutboxHookRequiresSignature` — firma válida → 200; **sin cabecera de firma pero con un would-be `X-Outbox-Token` → 401** (antes del fix ese caso iba a 200); firma basura / bajo secreto equivocado / cuerpo +1 byte → 401. `go test ./internal/warehouse/ -run TestOutboxHookRequiresSignature` → PASS (6/6 subtests).

### ✅ B.1 · MAQ-1 · guard del tag: el tag debe CAPTURAR el set de HEAD
`scripts/check_suite_tag.sh` gana el **assert 5** (`assert_tag_captures_head`): gitlinks del tag `==` gitlinks de HEAD `==` `workspace_pins` del `versions.yaml` de HEAD. Un tag rancio-pero-autoconsistente (gitlink viejo + su propio manifiesto viejo, coherentes entre sí) pasaba los asserts 2-4 y sólo muere aquí — la variante de la clase QM7-3 que el guard decía cazar y sólo cubría a medias.
- **PR:** jcsvwinston/quantum#84 (`fix(ci): cierra las dos costuras del guard del tag y endurece el notificador (MAQ-1, MAQ-2, MAQ-4)`), MERGED (ya en `main`).
- **Gate:** fixture `umbrella-suite-tag` en `guard-of-guards.sh` → **muerde (EXIT=1)** sobre la variante rancia-autoconsistente; positivo al pin → EXIT=0.

### ✅ B.2 · MAQ-2 · modo `--cierre` (el AVISO mid-tren pasa a NO-PASA)
`check_suite_tag.sh` y `suite-integral.sh` aceptan `--cierre` / `QUANTUM_CERTIFYING=1`: en certificación, «versión nueva en `main` sin tag» deja de ser AVISO y es FAIL, y el assert 5 se exige aunque el tag no sea HEAD. Así «15/15 EXIT=0 en `--cierre`» ya no puede significar «tren a medias sin su tag». La lane semanal normal sigue tolerando HEAD>tag entre arcos (documentado en `docs/AUDITORIA_CONTINUA.md`).
- **PR:** jcsvwinston/quantum#84, MERGED.
- **Estreno:** esta certificación es la primera aplicación del modo `--cierre` (evidencia abajo).

### ✅ C · SEC-3 · nucleus: cabecera de encoding informativa + helper de consumidor
Decisión **Opción 2** (documentada): la cabecera `X-Outbox-Payload-Encoding` se queda INFORMATIVA/sin firmar — firmarla habría bifurcado el esquema de firma body-only (un solo verificador para webhooks de módulo y de outbox, pineado por un test). En su lugar, `pkg/outbox/bridge_webhook.go` añade `CheckPayloadEncoding(expected, delivered string) error` + el centinela `ErrPayloadEncodingMismatch`; el wire NO cambia.
- **PR:** jcsvwinston/nucleus#238 (`feat(nucleus,outbox): harden webhook registration and keep the outbox encoding header informational (SEC-4, SEC-3)`), MERGED → nucleus v1.6.0.
- **Consumidor alineado:** quantum-app decodifica por el encoding CONFIGURADO (`WAREHOUSE_OUTBOX_ENCODING`), nunca por la cabecera, y rechaza el mismatch (400) — `TestOutboxHookChecksPayloadEncoding` (jcsvwinston/quantum-app#8).

### ✅ C · SEC-4 · nucleus: `/` y nombres de módulo
El boot rechaza `path==""`/`path=="/"` no canónico y nombres de módulo con `..`/`/` (defensa en profundidad; `pkg/nucleus/module.go`).
- **PR:** jcsvwinston/nucleus#238, MERGED → nucleus v1.6.0.

### ✅ C · MAQ-3 · orbit: excepción root-edge estrechada
La tolerancia de ≤1 minor de lag del guard de pins internos se ciñe al ÚNICO borde topológicamente forzado (`root↔quarkdatasource`, por directorio consumidor) y verifica que el contrato de datasource congelado (ADR-001) es idéntico en el tag que va por detrás. Cualquier otro borde rancio vuelve a ser FAIL.
- **PR:** jcsvwinston/orbit#132 (`fix(ci): estrecha la excepción root-edge a la arista root↔quarkdatasource (MAQ-3)`), MERGED → orbit v1.5.1.
- **Evidencia al pin:** guard `orbit-internal-pins` → `ok quarkdatasource/go.mod: … v1.4.3 (root↔quarkdatasource edge: lags v1.5.1 by ≤1 minor, topologically forced; datasource contract frozen ADR-001, verified identical at both tags)`.

### ✅ C · MAQ-4 · quantum: notificador robusto
`scripts/notify_schedule_failure.sh` + `integration.yml`: (a) fallback `if: always()` para que un fallo del propio job de aviso no degrade al email default; (b) búsqueda de issues filtrada server-side (evita duplicados con >100 issues); (c) cubre `cancelled()` además de `failure()`.
- **PR:** jcsvwinston/quantum#84, MERGED.

### ✅ C · MAQ-5 · nucleus: healthcheck MSSQL + false-green de `-run` (AMBAS mitades)
Ambas mitades quedaron hechas — **nada viaja al siguiente arco**:
1. **MSSQL healthcheck:** la lane `db-matrix-live-mssql` de `ci.yml` gatea sobre un healthcheck real del contenedor (una query que sale != 0 si falla), generalizando el patrón de #235; ya no es un port-probe crudo.
2. **`-run` false-green:** `scripts/ci/assert_run_selects.sh` aserta vía `go test -list` que cada rama de un filtro `-run` sigue seleccionando su test (un test renombrado hace que su rama seleccione 0 tests → FAIL, nombrándolo, antes de los pasos live).
- **PR:** jcsvwinston/nucleus#239 (`ci(nucleus): gate the MSSQL lane on a real container healthcheck and guard -run filters against the false-green (MAQ-5)`), MERGED → nucleus v1.6.0.

### ✅ Cada guard nuevo/modificado con su fixture en guard-of-guards
- `umbrella-suite-tag` (assert 5, B.1) → fixture actualizada, muerde sobre la variante rancia-autoconsistente.
- `assert_run_selects.sh` (nucleus, MAQ-5) es un helper PARAMETRIZADO del CI de nucleus (`<pkg> <run-regex>`), no un guard de certificación del set que el paraguas repita → **clasificado como exclusión** en `scripts/lib/guard-registry.sh` con razón (misma familia que los `run_*.sh` de nucleus ya excluidos). El check anti-fósil de `suite-integral` lo forzó y quedó resuelto (ver Decisiones).
- `guard-of-guards.sh` completo: **15/15 muerden**.

### ✅ Set re-certificado por `suite-integral.sh --cierre` (tablas abajo); `declared_lags` vacío; etiquetas humanas de quantum-app al día
- Etiquetas humanas de quantum-app al set 1.10.0 (README «Current set», `docs/TUTORIAL.md` go-get, comentario de `go.mod`, `suite-manifest.yaml` `suite:`/`pins:`); gate `check_human_labels.sh` → EXIT=0.
- `declared_lags: {}` en `versions.yaml`.
- Certificación mecánica: tablas en §«Certificación».

### ✅ `CIERRE_ENDURECIMIENTO_1.md` — este documento
DoD casilla a casilla con comando/PR+EXIT, tags/PRs, desviaciones, Pendiente VACÍA, y la solicitud de verificación dirigida.

---

## Tren de releases (orden de dependencia)

| Repo | PR(s) clave del arco | Release | Tag | Gitlink |
|---|---|---|---|---|
| nucleus | #238 (SEC-3, SEC-4), #239 (MAQ-5) | #240 | **v1.6.0** | `26c5b60a` |
| orbit | #132 (MAQ-3), #134 (deps→nucleus v1.6.0) | #133 (root), server #137, quarkbridge #136, agent #135 | **v1.5.1** (+ server/v0.9.1, quarkbridge/v0.3.6, agent/v0.5.6) | `bf5e0d7e` |
| quark | — (no se tocó en el arco) | — | **v1.4.0** (sin cambios) | `36a1ab72` |
| quantum-app | #7 (SEC-1, SEC-2), #8 (bump al set + alineación SEC-3 + etiquetas) | — | **v0.1.2** | — |
| quantum | #84 (MAQ-1/2/4, ya en `main`), **#85** (re-pin + certificación) | — | **v1.10.0** | — |

---

## Certificación

### Pre-tag (modo lane, local — el AVISO mid-tren del guard del tag es legítimo sin tag)

```
$ ./scripts/suite-integral.sh
guards registrados: 15 · ejecutados: 15 · con fallo: 0
suite-integral: OK — los 15 guards pasan sobre el árbol pinado.        # EXIT=0

$ ./scripts/guard-of-guards.sh
guards registrados: 15 · fixtures ejecutadas: 15 · muerden: 15
guard-of-guards: OK — los 15 guards muerden sobre sus fixtures.         # EXIT=0
```

CI de la PR #85 (`main` gate): manifest-guard, guard-of-guards, go-install-tag, suite-integral, build+vet, orbit-lockstep, Docusaurus → todos verdes.

### E2E de quantum-app (Docker real, arranque fail-closed + sin downgrade + SEC-3)

```
$ ./scripts/e2e_local.sh
--- PASS: TestOrbitPanelDataStudio / TestOrbitLiveFeed / TestOrdersReadRequireSession /
          TestOrderOutboxAndMail / TestOutboxHookSignatureVerification /
          TestOutboxBridgeSignsDeliveries / TestProductCRUDAcrossEngines /
          TestReadReplica / TestSessionsInRedis / TestStorageS3MinIO
ok  github.com/jcsvwinston/quantum-app/e2e   # 7 suites / 10 funciones — EXIT=0
```
`WAREHOUSE_OUTBOX_ENCODING=json` exportado (== `payload_encoding` del bridge) para ejercer el decode configurado; el shape base64 sigue ejercitado por el bridge `e2e-probe` contra el listener `/probe` del propio test.

### Post-tag (modo `--cierre`, estreno de B.2 — tag==HEAD)

Tag de suite **v1.10.0** cortado sobre el merge de #85 (`15e32e51`); `tag==HEAD`.

```
$ git rev-list -n1 v1.10.0   # = HEAD = 15e32e51f9a8cd8868f898161060951a6ad9db0b
$ ./scripts/suite-integral.sh --cierre
guards registrados: 15 · ejecutados: 15 · con fallo: 0
suite-integral: OK — los 15 guards pasan sobre el árbol pinado.        # EXIT=0

$ bash scripts/check_suite_tag.sh --cierre
== tag de suite v1.10.0 (la versión que versions.yaml declara) ==
OK: v1.10.0 — su versions.yaml declara quantum "1.10.0"
OK: v1.10.0 — gitlink de quark (36a1ab72) == workspace_pin (36a1ab72)
OK: v1.10.0 — gitlink de nucleus (26c5b60a) == workspace_pin (26c5b60a)
OK: v1.10.0 — gitlink de orbit (bf5e0d7e) == workspace_pin (bf5e0d7e)
OK: v1.10.0 — ancestro de HEAD
-- assert de captura (certificación): el tag v1.10.0 debe apuntar al MISMO set que HEAD certifica
OK: v1.10.0 — captura el set de quark de HEAD  (36a1ab72 == pin 36a1ab72)
OK: v1.10.0 — captura el set de nucleus de HEAD (26c5b60a == pin 26c5b60a)
OK: v1.10.0 — captura el set de orbit de HEAD  (bf5e0d7e == pin bf5e0d7e)
check_suite_tag: OK                                                    # EXIT=0
```

En `--cierre`, el AVISO mid-tren «versión sin tag» habría sido FAIL y el assert 5
(captura de HEAD) es OBLIGATORIO: «15/15 EXIT=0 en `--cierre`» significa aquí
«tag cortado que captura el set de HEAD», no «tren a medias». Primera aplicación
real del modo de certificación (B.2).

---

## Desviaciones y decisiones

1. **Clasificación anti-fósil de `assert_run_selects.sh` (nucleus, MAQ-5).** El re-pin trajo un guard nuevo en nucleus v1.6.0. El check anti-fósil de `suite-integral` exige registrarlo (con fixture) o excluirlo (con razón). **Decisión: exclusión**, porque es un helper parametrizado (`<pkg> <run-regex>`) de las lanes de test de nucleus — sin argumentos es un error de uso, no un check con veredicto propio; sus regex viven en el workflow de nucleus, no en el paraguas (registrarlo obligaría a fosilizar aquí la lista de nombres de test de nucleus); y protege la integridad de las lanes de nucleus, que su CI ejerce en cada corrida con los args reales. Es la misma familia que los `run_*.sh` de nucleus ya excluidos. Documentado en `scripts/lib/guard-registry.sh` con su porqué.
2. **Numeración 1.10.0** (no 1.9.1): forzada por el minor de nucleus (QADR-0002). Anticipada por el plan.
3. **Ningún fix se movió al framework unilateralmente.** SEC-3 se resolvió con la Opción 2 (helper de consumidor, no firmar la cabecera) — dentro de nucleus por diseño del plan, no un movimiento nuevo. No surgió ningún helper de arranque que hubiera que decidir mover.

---

## Pendiente

**VACÍA.** El backlog de `REVISION_DIRIGIDA_SEG_1.md` (SEC-1..4, MAQ-1..5) queda a cero. Las dos mitades de MAQ-5 (healthcheck MSSQL **y** false-green de `-run`) se hicieron ambas; nada viaja al siguiente arco.

---

## Solicitud: verificación dirigida de cierre (ACOTADA — media hora de un revisor)

Conforme a los disparadores §6.1/§6.3 del runbook (este arco tocó superficie de seguridad y la propia maquinaria de certificación), el cierre SOLICITA una verificación humana dirigida, **acotada** a:

**(a) SEC-1/SEC-2 no dejan vivo ningún camino de auth débil.** Confirmar que, reintroducidos el default de secreto y el downgrade al token estático, los negativos se ponen rojos: (a1) arranque sin `WAREHOUSE_OUTBOX_SECRET` o con un valor `dev-` → el proceso muere; (a2) reintroducido el fallback al token, «sin cabecera de firma + token bueno» pasa a 200 (hoy 401). Es decir: que la única puerta viva de `/hooks/outbox` es la firma HMAC del cuerpo, y que no hay secreto de despliegue con default funcional.

**(b) B.1/B.2 no rompen un flujo de certificación legítimo.** Confirmar que el assert de captura de HEAD y el modo `--cierre` no generan falsos positivos en la lane semanal normal: un `main` con el set drifteado por delante del último tag (estado legítimo entre arcos) debe seguir pasando la lane semanal (AVISO mid-tren, EXIT=0) y sólo el modo `--cierre` debe exigir el tag que captura HEAD.

No es una ronda; es la comprobación puntual que el régimen prescribe cuando un arco toca seguridad y maquinaria.
