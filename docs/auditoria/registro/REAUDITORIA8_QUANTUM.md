# Re-auditoría Quantum (8ª pasada — LA ÚLTIMA MANUAL) — verificación del cierre definitivo y dictamen sobre la auditoría continua

**Fecha:** 2026-07-21 · **Auditor:** Fable 5 (5 auditores Fable 5 en paralelo — quark, nucleus, orbit, paraguas/maquinaria, quantum-app — + verificación de lo crítico por mí).
**Estado auditado (set Quantum 1.8.0, certificado 2026-07-20):** quark v1.3.3 (`e4a07017`), nucleus v1.4.0 (`cdf175ac`), orbit v1.4.4 (`5a4d75ff`) con agent/v0.5.4, server/v0.8.4, quarkbridge/v0.3.4, quarkdatasource/v0.2.6, proto/v0.4.1; quantum-app v0.1.0 (`c2c44a1`); **declared_lags VACÍO por primera vez**.
**Encargos (los dos que pidió el propio CIERRE_7A_RONDA §5):** (1) pasada clásica sobre 1.8.0 incluida la banda §3 y el juicio humano (docs de superficie nueva, seguridad de webhooks, honestidad del suite-manifest); (2) el meta-encargo: validar la maquinaria de auditoría continua, intentar romperla, y dictaminar si la 9ª+ puede prescindir de la pasada manual completa.
**Limitaciones:** sin daemon Docker (el E2E 7/7 de quantum-app y las lanes de motor no re-ejecutables aquí; un auditor levantó PostgreSQL 16 local sin Docker y corrió la suite RLS completa contra PG real); API GitHub 403 (compensado ejecutando localmente).

---

## 1. Veredicto

**El cierre de la 7ª ronda es VERAZ, Quantum 1.8.0 queda CONFIRMADO, y — tercera pasada consecutiva — no hay ningún P0 ni P1.** Todo lo grande se verificó con reproducción independiente: Jobs y Webhooks de nucleus están **realmente ejecutándose** (E2E propio por la superficie pública: job ≥2 ejecuciones, webhook firmado→200 / mal firmado→401 / método→405 / body manipulado→401, cron inválido→boot falla; `NOT EXECUTED` → 0); quark#252 está cerrado de verdad (el rojo de 5 idle-in-transaction re-provocado contra PG real revirtiendo el fix, y el guard anti-fuga de QK7-1 re-provocado 3×"pool exhausted"); el E2E fleet de orbit repite boot-fail con token malo y eventos reales con token bueno; quantum-app es un consumidor externo genuino (requires exactos del set, resolución por proxy, MVS sin elevaciones) y su suite-manifest de 789 ítems se GENERA de verdad desde los inventarios a los tags, con muestreo de honestidad casi limpio (una sola evidencia inflada de 10+15+8 muestreadas — y varias clasificaciones pecan de conservadoras, la dirección segura).

**Y el meta-encargo tiene respuesta: la maquinaria funciona y resistió el sabotaje.** `suite-integral.sh` 14/14 en verde sobre el árbol pinado y `guard-of-guards.sh` 14/14 mordiendo; los cinco intentos de rotura dirigidos (fixture castrada, guard sin fixture, fixture huérfana, tríada de fallos reales inyectados, submódulo fuera de pin) fueron cazados con la causa exacta, y la "tabla veraz" no infla conteos. El gap-analysis contra las checklists reales de las pasadas 4ª-8ª da: ~40% cubierto por la lane, ~27% por los CI de cada repo, ~33% de juicio humano — y ese 33% es íntegramente **evento-dirigido** (superficie nueva, ronda nueva), no calendario.

**DICTAMEN: SÍ — a partir de la 9ª, la certificación puede descansar en la lane semanal + juicio humano puntual, sin pasada manual completa, con las condiciones del §5.** Esta 8ª cierra la era de las pasadas manuales como rito.

Queda una banda de hallazgos nuevos (4 P2 de producto + 2 P2 de gobernanza + cola P3) que cabe entera en el tren 1.8.1 — que además ya está medio hecho: main va por delante de los tags con los fixes de la banda §3 del cierre, todos verificados correctos, con una excepción que hay que frenar antes de taguear (#230, cambio de wire ROMPEDOR, §4).

---

## 2. Verificación del cierre (todo reproducido; selección)

**Quark v1.3.3** — QK7-1/2/3 y #252 verificados con rojos re-provocados (guard neutralizado → 3× pool exhausted; ctx crudo → 5 idle-in-tx contra PG 16 real; driver fake propio → el error de BeginTx llega al caller con etapa, no ErrNoRows). Suite RLS completa + `-race` contra PG real en verde. Guards de release con negativos. **Nota de mérito:** el contrato de ctx operation-scoped quedó documentado a nivel de tipo con referencia al pin — la clase de doc que evita reintroducciones.

**Nucleus v1.4.0** — Jobs/Webhooks reproducidos por E2E propio (con un caso extra que el test del repo no tiene: firma válida para un body DISTINTO → 401). Fix de asynq correcto (Start/Shutdown por ctx, dos pins). Freeze 6/6 con +25/−0 honesto (23 feature + 2 retro de §2.4). RejectClientPK, fixture MSSQL, TestInstrumentLive en lane, check_example_pins (verde en main, rojo estructural en tag — exclusión de la lane bien razonada): todo confirmado. **Seguridad del webhook: sólida en lo esencial** — hmac.Equal en tiempo constante, body con tope ANTES de la firma, 405 sin tocar handler, exención CSRF EXACTA del prefijo, secret jamás en logs.

**Orbit v1.4.4** — Tags/pins/ancestría al tag; declared_lags vacío es VERAZ (todos los requires cross-repo cruzados contra el certificado). OR7-1/2/3 confirmados (rojo de OR7-2 re-demostrado mutando el contador a global). E2E fleet al tag en verde. #123 (UI): las dos SPAs reconstruidas desde fuente son **byte-idénticas** a los dist commiteados.

**Paraguas + maquinaria** — Pines==tags en 3 coordenadas; tag v1.8.0 tras el último PR (procedimiento QM7-3 aplicado: #77/#78/#79 ancestros, #80 post-tag correctamente fuera); build 9/9; manifest-guard §1-§5 + negativos; `go install @v0.8.4` caché virgen; linter servido con regla de IDs mordiendo. Suite-integral y guard-of-guards: ver §1.

**quantum-app v0.1.0** — go.mod == set certificado exacto; `GOWORK=off` real con guard anti-workspace (negativo probado); gate del manifest con dos negativos; generador fresco (789 = 670+21+98 leídos del module cache a los pins); los 7 casos E2E assertan por HTTP/API + backend directo (cero "arrancó"); CI sin `|| true` ni continue-on-error. TUTORIAL fiel comando a comando (dos nits inocuos), sin hype, carril SQL del feed prometido == lo asertado.

---

## 3. Hallazgos NUEVOS

### P2 — para el tren 1.8.1 (ninguno invalida 1.8.0)

**NU8-1 · `nucleus/pkg/model/crud.go:307-308` (FindByID) y `:208-212` (FindAll) — Oracle emite SQL inválido en un paquete STABLE.** Verificado por mí en el tag: la rama es `if dialect == "mssql" {...} else {LIMIT...}` y Oracle cae en el else (ORA-00933). El inventario declara `oracle://` stable. Excede la nota §2.6 del cierre, que lo limitó al CLI admin. → Rama oracle (`OFFSET/FETCH`/`FETCH FIRST 1 ROWS ONLY`) o reclasificar oracle como exploratorio; decidir, no dejar el claim.

**OR8-1 · `orbit/website/docs/features.md:27-28` (al tag) — la doc publicada promete el feed vivo HTTP in-process que en v1.4.4 no existe** (orbit#121: solo el carril SQL funcionaba). El fix #122 en main es correcto y con test (`requests>0`). **Lección para los cierres:** el §1.4 del CIERRE_7A marcó esa cadena "✅ (con observación)" cuando era "carril SQL ✅ / carril HTTP roto" — un ✅ así debió ser ⚠️; la honestidad de los informes de cierre es tan parte del sistema como la de los manifiestos (va a la plantilla del runbook, §5). → Cortar v1.4.5 en el tren.

**QA8-1 · quantum-app `README.md:24`, `docs/TUTORIAL.md:30-34`, `go.mod:1-11`, `suite-manifest.yaml:22` — toda etiqueta humano-legible del set quedó fósil en "1.7.2" tras el bump** (verificado por mí: el README nombra el set viejo con números concretos y **el TUTORIAL enseña `go get` del set anterior completo**). El gate protege `pins:`↔go.mod pero no las superficies humanas. → Actualizar los 4 sitios + extender el gate (el equivalente del guard README==manifiesto que el paraguas ya tiene).

**QA8-2 · quantum-app `internal/warehouse/handlers_orders.go:93-112` + `module.go:127-128` — `GET /api/orders{,/{id}}` sin `requireUser`: expone `customer_email` de todos los pedidos, sin sesión y con IDs enumerables** (verificado por mí: las rutas se registran sin guard). En la app de referencia de la suite, PII en endpoint abierto enseña el patrón equivocado. → `requireUser` en lecturas de pedidos (o redactar el email).

**QM8-1 · `quantum/.github/workflows/integration.yml` — la señal semanal es incompleta:** solo suite-integral tiene schedule (verificado por mí: 0 menciones en integration.yml); entre rondas nada re-compila el set ni re-ejecuta `go install @tag`, y la lane roja solo notifica por el email default de Actions. → schedule/workflow_call + issue automático en fallo. **Condición del dictamen.**

**QM8-2 · `quantum/docs/AUDITORIA_CONTINUA.md` — faltan los disparadores de mini-pasada, el decisor y la plantilla de CIERRE** para operar el régimen sin pasada manual. → §6 nuevo (contenido propuesto en §5 de este informe). **Condición del dictamen.**

### P3 — cola (tren 1.8.1 o chore)

- **NU8-2** · el registro de webhook acepta `..` en el path → boot NO falla (contradice el claim) y el webhook queda montado-pero-inalcanzable (307 del ServeMux al path limpiado). → rechazar `path.Clean(p) != p`.
- **NU8-3** · sin protección anti-replay en webhooks y SIN documentar como límite. → documentar (dedup por ID de evento) ± timestamp firmado con tolerancia.
- **QA8-3** · el webhook consumidor de quantum-app compara token con `!=` (no constante) y NO puede usar la verificación HMAC de nucleus porque **el bridge del outbox no firma** (solo headers estáticos) — hueco de suite: `SignWebhookBody` existe pero el productor no lo usa. → fix app (hmac.Equal) + issue de nucleus (firma HMAC en el bridge; familia de #228/#230).
- **QK8-1** · cleanup de pánico del RLS puede quedar bloqueado si database/sql no libera locks (trade-off correcto y documentado; opcional: contador de operador). **QK8-2** · `SafeMigrations=false` sobrevive al literal parcial de Limits (documentado; candidato WARN).
- **QA8-4** (única evidencia inflada del manifest: `BeforeCreate` cita un assert inexistente), **QA8-5** (imágenes minio/mailpit `:latest` sin pinar), **QA8-6** (workaround cita "v1.3.3" fósil), **QA8-7** (paso "Unit tests" del CI vacío — no existe ni un test unitario; verde que no ejecuta nada), **QA8-8** (datasheets servidos inline sin nosniff → XSS almacenado para autenticados).
- **QM8-3..8** (robustez de la maquinaria): sidebar-sync con verde-vacío si el parser no extrae ids (demostrado; mitigado por su fixture), build dir vacío pasa el linter servido, la lane no exige árbol limpio en local, el procedimiento del tag de suite no tiene guard, la aserción anti-fósil solo escanea `*.sh`, y en local sin red los tags rancios solo avisan. Todos fixes <15 líneas.
- El linter de voz de **nucleus** no tiene la regla de IDs de hallazgo (vive en orbit y en el servido del paraguas — defensa aguas abajo cubierta; hueco local).

---

## 4. Drift de main (sin certificar — la entrada del tren 1.8.1, ya verificada)

Main va por delante de los tags en los tres repos con los fixes de la banda §3 del cierre, todos revisados: **quark #263** (WithLimits normaliza los 5 campos numéricos a cero — cotejados contra el struct; correcto, con tests) y **#264** (modo estricto de lecturas: sólido, opt-in, con matices de falsos positivos anotados — TrackReads en ctx de proceso acumula; polling del mismo id dispara); **nucleus #229** (not-found de S3/GCS clasificado por TIPO del SDK, con fakes y caso envuelto; limpio); **orbit #122** (feed vivo HTTP arreglado con test `requests>0`) y **#123** (UI verificada, dist byte-idéntico al fuente).

**EXCEPCIÓN a frenar: nucleus #230.** El bridge del outbox cambia el wire de `payload` (base64 → JSON anidado | base64-fallback | null): **ROMPE consumidores existentes**, no está versionado ni tiene opt-in, y el contract-freeze es ciego a formatos de wire (solo símbolos). → Antes de cortar 1.8.1: opt-in o cabecera `X-Outbox-Payload-Encoding` + test de contrato del cuerpo. Idealmente, resolverlo junto con QA8-3 (firma HMAC del bridge) en un solo cambio de contrato bien versionado.

---

## 5. DICTAMEN del meta-encargo: régimen de auditoría continua desde la 9ª

**SÍ, con condiciones.** Fundamento: todas las clases de comprobación mecánica de las pasadas 5ª-8ª están en la lane o en los CI por-repo, y su vitalidad se prueba semanalmente en tres capas (guard-of-guards con causa de muerte + aserción anti-fósil + cobertura bidireccional guard↔fixture) — el sabotaje de cualquiera pone la lane en rojo, demostrado por ejecución. Lo no-mecánico (~33%) es evento-dirigido y queda como procedimiento:

**Condiciones previas (una ronda-chore corta, junto al tren 1.8.1):**
1. QM8-1: schedule para integration.yml + notificación activa (issue automático) del schedule rojo.
2. QM8-2: runbook §6 con disparadores, decisor (Carlos) y plantilla de CIERRE (formato comando+EXIT; y la lección de OR8-1: un ✅ con asimetría conocida se escribe ⚠️).
3. QM8-6: guard del tag de suite (existe ∧ declara la versión ∧ gitlinks==pins).
4. Recomendado: QM8-3/4/5/7/8 (robustez, fixes triviales) y los negativos de los gates de quantum-app como fixtures.

**Disparadores de mini-pasada dirigida (el "juicio humano puntual"):**
- Superficie de **seguridad** nueva o cambiada → revisión humana de ESA superficie antes de certificar el set que la incluya.
- **Feature minor** en cualquier producto → lectura de fidelidad de sus docs + verificación de que su arco trajo rojo-sin-fix.
- **Cambio en la propia maquinaria** (registry, fixtures, orquestadores, workflows) → revisión humana del diff: la maquinaria no puede auto-vigilarse.
- Lane semanal **roja 2 corridas** sin PR que lo explique; **declared_lags poblado >1 ronda**; guard nuevo sin negativo revisado.
- **Cada 2 rondas, una pasada de "ojos frescos" ACOTADA** a la superficie más cambiada — es la única fuente histórica de los P0 (OR-1/OR-2, NU6-1, QK7-1 nacieron así) y ningún guard la sustituye. No es la pasada completa de 5 auditores: es una, dirigida.
- Lo que queda estructuralmente sin red mecánica, asumido y por eso ligado a los disparadores: re-provocar rojos quitando fixes (tests tautológicos), honestidad semántica de evidencias/clasificaciones, wire-formats (el freeze es symbol-only — #230 lo demuestra), y el drift de main entre rondas.

**Con las condiciones cumplidas, la 9ª "auditoría" es: lane semanal verde + CI por-repo verde + los disparadores que toquen. Este informe cierra la serie de pasadas manuales completas.**

## 6. No verificable en esta sesión

E2E Docker 7/7 de quantum-app y lanes de motor salvo PG (un auditor lo levantó localmente sin Docker); corridas reales de Actions y estados de PR/issue (API 403); comportamiento real del email de notificación del schedule (inferido de YAML — y es justamente QM8-1).

---

*Serie completa: 4ª→2 P0 · 5ª→3 P1 · 6ª→0 · 7ª→0 · 8ª→0. La suite corre "sin fisuras" demostrado por ejecución, lo publicado se lee como producto, el 100% ejecutable está medido por manifiesto (789 ítems), y la verificación ya no depende de que alguien se acuerde de hacerla.*
