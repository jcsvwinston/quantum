# Cierre de la 5ª ronda — Quantum (ejecutado por Claude Code, 2026-07-19)

**Entrada:** `PLAN_EJECUCION_5.md` + `REAUDITORIA5_QUANTUM.md` (misma carpeta).
**Estado base:** Quantum 1.7.0 (quark v1.3.0 `5282ce5b`, nucleus v1.3.1 `78d7d349`, orbit v1.4.1 `b48247eb`).
**Estado final:** **Quantum 1.7.1 certificado** — quark v1.3.1 (`238af896`), nucleus v1.3.2 (`e7f00d5c`), orbit v1.4.2 (`ee2c84b5`) con server/v0.8.2, agent/v0.5.2, proto/v0.4.1, quarkbridge/v0.3.2, quarkdatasource/v0.2.4.
**Método:** verificación por ejecución. Cada gate de abajo se ejecutó de verdad (Docker incluido); las salidas con EXIT están pegadas en el PR correspondiente y aquí se citan las líneas clave. Todo guard nuevo se probó también en negativo (provocando el fallo y verificando EXIT≠0) antes de darse por instalado.

---

## 1. Definición de Hecho, casilla a casilla

### ☑ OR5-1 — server pinaba agent v0.5.0; test de regresión rojo standalone
- **Reproducido primero** (main, pre-fix): `cd server && GOWORK=off go test -run AgentToken -count=1 .` → `FAIL TestServer_AgentToken_StreamAuthenticates ("the bearer is not reaching the bidi stream")`.
- **Fix** ([orbit#93](https://github.com/jcsvwinston/orbit/pull/93), fusionado): barrido completo de pins internos — server: agent v0.5.0→v0.5.1 y proto v0.4.0→v0.4.1; agent: proto→v0.4.1; quarkdatasource: orbit v0.3.0→v1.4.1 (OR5-3 adelantado, lo exigía el guard nuevo).
- **Gates:** `GOWORK=off go test ./...` EXIT=0 en los 6 módulos; `AgentToken` 3/3 PASS standalone; tras el tren de release, re-ejecutado contra el pin v0.5.2 (EXIT=0).
- **Guards instalados:** el job `standalone` del CI de orbit ejecuta ahora `GOWORK=off go test ./...` en los 6 módulos (no solo build+vet); `scripts/ci/check_internal_pins.sh` + job `internal-pins` (cada require de hermano == último tag publicado). Negativo: pin degradado a v0.5.0 → EXIT=1.
- **`go install @v0.8.2` (tras el corte):** `GOMODCACHE=$(mktemp -d) GOWORK=off go install github.com/jcsvwinston/orbit/server/cmd/admin-server@v0.8.2` → binario `nucleus-admin-server v0.8.2`, EXIT=0. Casilla completa.

### ☑ QM5-1 — el sitio publicado servía snapshots viejos con jerga
- **Fix** ([quantum#68](https://github.com/jcsvwinston/quantum/pull/68), fusionado): `lastVersion: 'current'` con label = tag real de versions.yaml en las instancias quark/nucleus; verificado en el build: `build/quark/intro/` muestra `v1.3.0` ×4 y 0 hits de «Next».
- **Decisión de cola de snapshots** (documentada en `sync-versions.mjs`): solo el último patch por minor de la línea 1.x — quark 1.0.0/1.1.0/1.2.2, nucleus 1.0.0/1.2.0. La historia 0.x queda en el repo de quark.
- **Limpieza única de los snapshots servidos, en sus repos fuente:** [quark#250](https://github.com/jcsvwinston/quark/pull/250) (44/47/30 fugas → 0, build Docusaurus verde) y [nucleus#214](https://github.com/jcsvwinston/nucleus/pull/214) (13/13 → 0, más la tabla de tags `db:` corregida en ambos snapshots contra el parser real de cada versión, sin mencionar `db:"-"` que no existía).
- **Linter sobre lo SERVIDO:** `scripts/check_served_jargon.sh` post-build sobre `build/**/*.html`, cableado en `website-ci.yml` y `deploy.yml`. Negativo probado (sin exclusiones, contra los snapshots pinados sucios): caza 62 páginas → EXIT=1. **Estado final tras el re-pin: lista de exclusiones VACÍA y `OK: 0 fugas … (0 rutas de snapshot excluidas)` EXIT=0 sobre el build completo** — todo lo que el lector ve queda bajo el gate.
- **Sitio vivo verificado:** `https://…/quantum/quark/intro/` sirve la doc actual con el tag real (0 hits de «Next»); el snapshot 1.2.2 responde 200 en su ruta de archivo.
- Cierra también la mitad de QM5-6 (el paraguas era el único repo sin linter de docs en CI).

### ☑ NU5-1 — la web enseñaba sintaxis de tags `db:` que el parser ignora
- **Fix** ([nucleus#215](https://github.com/jcsvwinston/nucleus/pull/215)): página reescrita con la sintaxis real (`;`, `column:`, `pk`, `fk:`, `index`/`unique`, `not null`, `readonly`, `tenant`); `db:"-"` implementado (convención encoding/json/sqlx: campo fuera de columnas/CRUD/DDL/admin) con test; WARN de arranque ante directivas no reconocidas (`FieldMeta.UnknownDBTokens` + sweep en `App.Run`, mismo canal que los WARN de readiness) — reproducido en test con `model=Post field=AuthorID "author_id,fk=users.id"`; bodycheck regla 4 (hard): cada `db:"…"` de un bloque go de las docs se valida contra `model.ExtractMeta` real vía `reflect.StructOf`.
- **Negativo del verifier:** snippet con `fk=users.id` inyectado → `FAIL (--strict): 1 body-content falsehood(s)` EXIT=1.
- Barrido adicional: 0 restos de sintaxis fantasma en internal/, examples/, README y plantillas del scaffold.

### ☑ NU5-2 — RETURNING/OUTPUT asumía PK entera y existente
- **Reproducido primero** contra PG 16 real (Docker): PK UUID → `scan returned id: converting driver.Value type string … to a int64`; sin PK → `ERROR: column "id" does not exist (SQLSTATE 42703)`.
- **Fix** ([nucleus#216](https://github.com/jcsvwinston/nucleus/pull/216)): el clause solo se emite con PK declarada (sin fallback adivinado, `pkFieldMeta`) y de kind entero (`isIntegerGoType`); resto → camino exec.
- **Gate:** `NUCLEUS_SQL_MATRIX_URL=postgres://… go test ./pkg/model/ -run 'CRUDLive' -count=1` EXIT=0 con los casos nuevos (uuid_pk, no_pk) — rojo-sin-fix/verde-con-fix demostrado. Unit tests del SQL por forma (PK int/string/sin PK × postgres/mssql/sqlite) + pin de que ExtractMeta rechaza PK compuesta.

### ☑ NU5-3 — `nucleus new` pinaba v1.3.0
- **Fix** (nucleus#216): constante con marcador `x-release-please-version` + extra-file; `check_version_claims.sh` la vigila (== versión del manifest). Cinturón extra descubierto y añadido: `scaffoldGoVersion`/`scaffoldToolchain` deben igualar las directivas de go.mod.
- **Negativos:** constante degradada a v1.2.0 → EXIT=1; scaffoldGoVersion falseado → EXIT=1.
- **Gate del scaffold, re-ejecutado tras cortar v1.3.2** (CLI compilada del pin nuevo): `nucleus new demo132 && grep nucleus demo132/go.mod` → `require github.com/jcsvwinston/nucleus v1.3.2` — release-please reescribió la constante en el release PR, exactamente el mecanismo instalado.

### ☑ NU5-4 — la rama MSSQL (OUTPUT INSERTED) jamás ejecutada — **hallazgo nuevo al ejecutarla**
- **Reproducido primero** contra SQL Server 2022 real (Docker): el Create con OUTPUT funcionó… y `FindAll` cayó con `mssql: Incorrect syntax near 'LIMIT'` — **todo el listado de CRUD era T-SQL inválido** y nadie lo había visto porque la rama jamás se ejecutó. No se silenció: se arregló (`OFFSET…FETCH` / `TOP 1` para mssql).
- **Fix** (nucleus#216): `liveMatrixProfile` acepta `sqlserver://`; la lane MSSQL del CI corre `^TestCRUDLive_` completo (y las lanes PG/MySQL dejan de filtrar a un único test); limitación OUTPUT+triggers (error 334) declarada en código y docs.
- **Gate (Docker):** `TestCRUDLive_*` completo contra MSSQL real EXIT=0 (create+backfill, list, get, update, soft-delete, uuid NEWID(), sin PK, evento insert). En el CI real del PR, la lane `DB Matrix Live (mssql)` pasó en 2m17s ejecutando el CRUD.

### ☑ QK5-1/QK5-2/QK5-4 — guard de mezcla, roadmap, tests huérfanos
- **Fix** ([quark#251](https://github.com/jcsvwinston/quark/pull/251)): `attachSetOp` rechaza mezcla de kinds con `ErrUnsupportedFeature` (Union+UnionAll = mismo kind, misma precedencia; decisión documentada en el guard); tests List/Count/no-regresión en SQLite verdes. Roadmap sin versión hardcodeada (grep → 0 hits). Patrones `-run` de la matriz ampliados con los 5 huérfanos + `TestRowLevelSecurityNativePostgresIsolation` (6º huérfano, detectado al verificar).
- **Gate Docker (matriz ejecutada en local por la sesión):** lane mysql — `TestDeadlockRetryMySQL` PASS (6.64s, ejecutado, no skip); lane mariadb — `TestDeadlockRetryMariaDB` PASS (3.24s); lane postgres (v3) — EXIT=0 con los 7 tests EJECUTADOS: `TestSuitePostgres`, `TestPostgresReplicaRouting`, `TestDeadlockRetryPostgres` (2.07s), `TestPgListener_RoundTrip`, `TestInstallRLSPolicies_Postgres{,_NoTenantColumn}`, `TestRowLevelSecurityNativePostgresIsolation`.
- **La primera ejecución real destapó DOS fallos serios** (ver Desviaciones §8): el test de RLS nativo colgaba 25m (locks del implicit-tx contra el DROP TABLE del cleanup) y, al arreglarlo, afloró que **el camino de escritura del RLS nativo perdía INSERTs en silencio** (la tx implícita ligada al ctx de la petición; database/sql rollbackea al cancelarse el ctx y el commit diferido perdía la carrera). Fix contenido con `context.WithoutCancel` + test de regresión rojo-sin-fix (`ta Count after insert = 3, want 4`)/verde-con-fix; arista de fondo en [quark#252](https://github.com/jcsvwinston/quark/issues/252).
- QK5-3/QK5-5 (P3) en el mismo PR: tabla de set-ops con IntersectAll/ExceptAll y soporte por motor real; claim falso sobre Oracle reformulado («Quark no lo asume sin probe», también en release notes).

### ☑ QM5-3 — docs de orbit decían v1.2.1 (real v1.4.1)
- **Fix** ([orbit#95](https://github.com/jcsvwinston/orbit/pull/95), fusionado): claims a v1.4.1 con marcador + extra-files del root; `check_docs_version_claims.sh` en el job docs. El inventario de F4 descubrió que el **README** llevaba la misma deriva → incluido.
- **Negativos:** versión falseada → EXIT=1; marcador eliminado → EXIT=1.

### ☑ OR5-2 — token rechazado = fallo totalmente silencioso
- **Fix** ([orbit#94](https://github.com/jcsvwinston/orbit/pull/94), fusionado): WARN rate-limited en el agente ante CodeUnauthenticated (1/min por endpoint); backoff que NO se resetea en Dial (solo tras el primer frame aceptado del server, hook `OnAccepted`); WARN rate-limited con IP en el server al devolver 401; el INFO «connected» se emite solo tras la aceptación real; propagación del `*connect.Error` arreglada (doble %w). Tests con -race verdes.
- **Gate E2E en vivo (binarios reales, ejecutado por la sesión):** token malo → WARN visible a nivel INFO en agente (`admin agent token rejected by admin server; check --agent-token`) y server (`… invalid or missing bearer token … remote_ip=127.0.0.1 token_presented=true`), 0 «connected» falsos, intervalos crecientes ~1.4s→2.4s→4.5s→10.6s (antes ~1/s constante); token bueno → registra e INFO «connected». Evidencia pegada en el PR.
- Nota del PR (fuera de alcance, señalado): `Agent.Connected()`/`--require-admin` sigue dándose por bueno al pasar la sonda de Dial con token malo; endurecerlo es un cambio de semántica aparte.

### ☑ Fase 3 — barrido P3
- **NU5-5** (nucleus#216): `insertReturningScan` emite el evento insert con las filas realmente consumidas; pin live `TestCRUDLive_InsertEventRowsAffected` PASS contra PG y MSSQL reales, corriendo en ambas lanes.
- **NU5-6** (nucleus#216): lagunas declaradas donde el lector las ve — Oracle sin backfill de PK y MSSQL OUTPUT-vs-triggers en `compatibility.md#databases` + nota en la página de modelos.
- **QK5-3/QK5-5**: en quark#251 (arriba).
- **OR5-3**: en orbit#93 (arriba), cubierto a futuro por `check_internal_pins.sh`.
- **QM5-4** (quantum#68): meta/og description de la portada replica el hero.
- **QM5-5**: el job `go-install-tag` ejecuta el claim en cada corrida de CI, y el comando literal de versions.yaml quedó en la forma válida con el re-pin (`go install github.com/jcsvwinston/orbit/server/cmd/admin-server@v0.8.2`), verificada con caché virgen.
- **QM5-7** (quantum#68): comentario del go.work sin número fósil; comentario del buscador corregido (las docs de los tres productos están en inglés).

### ☑ Fase 4 — forcing functions
- **4.1 Inventario** (documentado en [quantum#69](https://github.com/jcsvwinston/quantum/pull/69), fusionado): cada hit clasificado en (a) release-please, (b) check de CI, (c) no-reincidible. Descubrió y cerró 3 rancios más: README de orbit («v1.2.1»), claim cross-repo en nucleus admin.md («orbit v1.2.0» → eliminado: un repo no debe afirmar la versión de otro), y la tabla de pilares del README del paraguas (sin guard → manifest-guard §4).
- **4.2 `go install @tag` en CI** (quantum#69): job `go-install-tag` — GOMODCACHE virgen + GOWORK=off + install del último tag de server del submódulo + `--version`. Ejecutado en local (v0.8.1 → `nucleus-admin-server v0.8.1` EXIT=0) y en el CI de main (success).
- **4.3 manifest-guard ampliado** (quantum#69): §3 los 5 tags de módulo de orbit (ancestría + diff del directorio vacío contra el pin del root — era verificación manual de cada auditoría); §4 tabla del README == manifest; arreglado el cosmético que suprimía los OK tras el primer FAIL. Negativos: tag no-ancestro → EXIT=1; tag viejo con diff → EXIT=1; versión falseada en la tabla → EXIT=1. **El guard §3 disparó en producción durante esta misma sesión**: al cortarse agent/v0.5.2, el CI de main del paraguas se puso rojo con `FAIL: orbit/agent — latest tag agent/v0.5.2 is not an ancestor of the pinned root` — la presión de re-pin funcionando tal cual se diseñó.
- **4.4 Tests standalone por tag**: cubierto en orbit#93 (matriz `GOWORK=off go test` en los 6 módulos).
- **4.5 Linter sobre lo servido en los 4 repos**: quark/nucleus/orbit conservan su linter de fuente; el paraguas (la única superficie publicada — los otros redirigen a él) lin­ta el HTML servido de los tres productos + sus propias páginas.

### ☑ Fase 6 — re-pinar y certificar
- **Tren de releases ejecutado en orden de dependencia** (los guards nuevos lo imponen): fixes fusionados → agent/v0.5.2 → bump del pin de server ([orbit#100](https://github.com/jcsvwinston/orbit/pull/100)) → server/v0.8.2 → quarkdatasource/v0.2.4 → **root v1.4.2 el último** (su commit contiene todos los tags de módulo como ancestros, que es lo que el manifest-guard §3 exige). quark v1.3.1 con su checklist de coherencia H-Q6 completado a mano en el release PR (README/SECURITY/CLAUDE/release-notes); nucleus v1.3.2 con extra-files automáticos (close/reopen para disparar el CI del PR del bot).
- **El forcing function §3 disparó en producción durante la propia ronda**: al cortarse agent/v0.5.2, el CI de main del paraguas se puso rojo (`latest tag agent/v0.5.2 is not an ancestor of the pinned root`) y solo el re-pin lo devolvió a verde — la presión funciona tal cual se diseñó.
- **Re-pin y certificación** ([quantum#70](https://github.com/jcsvwinston/quantum/pull/70)): versions.yaml al set nuevo con pines EXACTOS y notas honestas (incluida la nota del require nucleus v1.3.1 de orbit, un patch por detrás — decisión deliberada, ver Desviaciones §10), tabla del README (guard §4), lista de exclusiones del linter servido VACIADA.
- **Gates del set** (local, y re-ejecutados por el CI del PR): manifest-guard completo EXIT=0 (3 pins + 5 tags de módulo + 3 filas de README); build de los 9 patrones del workspace EXIT=0; sitio construido con raíces v1.3.1/v1.3.2 y linter servido EXIT=0 sin exclusiones; `nucleus new` pina v1.3.2; `go install …/admin-server@v0.8.2` (caché virgen) → `nucleus-admin-server v0.8.2` EXIT=0.

---

## 2. Desviaciones respecto al plan

1. **Regla de mismo-minor para la arista `quarkdatasource → root`** en `check_internal_pins.sh` ([orbit#100](https://github.com/jcsvwinston/orbit/pull/100)). El plan pedía igualdad estricta con el último tag para todos los hermanos; es **topológicamente imposible** en esa arista: el patch de certificación del root se corta el ÚLTIMO (su commit debe contener todos los tags de módulo como ancestros — lo exige el manifest-guard §3 del paraguas), así que un módulo que requiere el root nunca puede pinar un tag que solo existirá después del suyo. La regla instalada: mismo minor pasa, un minor de retraso (el caso OR5-3, v0.3.0 contra v1.4.x) falla. Probada en negativo.
2. **OR5-3 adelantado de Fase 3 a Fase 1** (orbit#93): el guard de pins internos lo exigía para estar en verde.
3. **NU5-4 destapó un fallo mayor** al ejecutar la rama por primera vez: `FindAll`/`FindByID` emitían `LIMIT`, inválido en T-SQL — todo el listado CRUD roto en MSSQL. Arreglado y cubierto por la lane (no estaba en el enunciado del hallazgo; es su consecuencia directa).
4. **El inventario de F4.1 amplió el alcance** con 3 rancios nuevos (README de orbit, claim cross-repo de nucleus, tabla del README del paraguas) — cerrados en la misma ronda.
5. **QK5-4 ganó un 6º test huérfano** (`TestRowLevelSecurityNativePostgresIsolation`), detectado al verificar los patrones.
6. **Los P2/P3 de cada repo van en un PR por repo** (no un PR por hallazgo): mantiene un tren de release por módulo y evita la cascada de conflictos de release-please.
7. **Fase 5 (documentación pendiente del plan anterior): no ejecutada.** El plan la marca como opcional y no bloqueante; queda como entrada para la siguiente sesión (Deployment/Security/Upgrade guide/Release notes de nucleus-orbit en el sitio, Configuration reference, sidebars, FAQ, tutoriales, decisión de idioma único).
8. **QK5-4 destapó dos fallos al ejecutar por primera vez el test de RLS nativo** (el 6º huérfano): (a) cuelgue de 25m — el patrón implicit-tx retiene transacciones y locks hasta el fin del ctx, y el ctx del test no moría, así que el `DROP TABLE` del cleanup se bloqueaba (reproducido también en la lane del CI de GitHub, 20m40s de timeout); (b) al arreglar el ctx, **pérdida silenciosa de escrituras**: `INSERT … RETURNING` bajo `RowLevelSecurityNative` se rollbackeaba al cancelarse el ctx de la petición porque database/sql aborta una tx cuyo ctx de BeginTx se cancela, y el commit del AfterFunc corría esa carrera. Ambos arreglados en quark#251 (ctx request-scoped en el test; `context.WithoutCancel` en el ciclo de vida de la tx) con regresión pineada; la evaluación de fondo del patrón (commit en Rows.Close / timeout de tx) queda en quark#252.
9. **Un dato para la 6ª auditoría sobre el flujo de release:** al contrario que lo observado el 2026-07-15, esta vez release-please SÍ regeneró sus PRs tras cada merge (los conflictos de manifest se resolvieron por merge de 3 vías en líneas distintas); no hizo falta reconciliación manual. El root de orbit cortó v1.4.2 sin `Release-As`: los merge commits de los PRs con título `fix:` cuentan para el componente raíz.

---

## 3. Tags cortados y PRs

**Tags:** quark **v1.3.1** (`238af896`) · nucleus **v1.3.2** (`e7f00d5c`) · orbit **v1.4.2** (`ee2c84b5`) + **agent/v0.5.2** + **server/v0.8.2** + **quarkdatasource/v0.2.4** (proto/v0.4.1 y quarkbridge/v0.3.2 sin cambios, correctamente sin re-tag) · suite **quantum v1.7.1**.

| PR | Contenido | Estado |
|---|---|---|
| orbit#93 | OR5-1 + OR5-3: pins internos + tests standalone + check_internal_pins | MERGED |
| orbit#94 | OR5-2: auth silenciosa (WARNs, backoff, 401 con IP) | MERGED |
| orbit#95 | QM5-3: coherencia de versión en docs + README | MERGED |
| orbit#100 | bump agent v0.5.2 en server + regla mismo-minor arista root | MERGED |
| orbit#96/#97/#98/#99 | release PRs (quarkdatasource/root/agent/server) | MERGED |
| nucleus#214 | snapshots 1.0.0/1.2.0 sin jerga + tabla db: real | MERGED |
| nucleus#215 | NU5-1: página db:, db:"-", WARN, bodycheck regla 4 | MERGED |
| nucleus#216 | NU5-2/3/4/5/6 + claim cross-repo de admin.md | MERGED |
| nucleus#217 | release v1.3.2 | MERGED |
| quark#250 | snapshots 1.0.0/1.1.0/1.2.2 sin jerga | MERGED |
| quark#251 | QK5-1/2/3/4/5 + fix RLS nativo (cuelgue + pérdida de escrituras) | MERGED |
| quark#253 | release v1.3.1 (checklist H-Q6 incluido) | MERGED |
| quantum#68 | QM5-1 (raíz servida + linter servido) + QM5-4/7 | MERGED |
| quantum#69 | Fase 4: manifest-guard §3/§4 + go-install-tag + inventario | MERGED |
| quantum#70 | certificación 1.7.1 (re-pin + exclusiones vaciadas) | MERGED |

Issue abierto a propósito: [quark#252](https://github.com/jcsvwinston/quark/issues/252) — evaluación de fondo del patrón implicit-tx del RLS nativo.

## 4. Pendiente y por qué

1. **Fase 5 del plan (documentación)** — el propio plan la marca «no bloquea la certificación, sí la siguiente»: páginas Deployment/Security/Upgrade guide por producto, release notes de nucleus y orbit en el sitio, Configuration reference de nucleus publicada (hoy enlaza al blob de GitHub), sidebars curadas de nucleus/orbit, FAQ/troubleshooting, tutoriales, y la decisión de idioma único del paraguas (chrome en español + docs en inglés; el comentario del buscador ya lo dice honesto).
2. **Require nucleus de los módulos de orbit** (v1.3.1, un patch por detrás del certificado): decisión deliberada de no re-cascadear los 6 módulos por un patch de nucleus — MVS eleva a v1.3.2 en cualquier app que también lo requiera (el scaffold ya lo hace) y el lane lockstep A-7 prueba orbit contra el nucleus pinado. Alinear en el próximo arco de orbit.
3. **quark#252** — el commit diferido del implicit-tx sigue siendo asíncrono respecto al fin de la petición (una lectura inmediatamente posterior desde OTRA conexión puede no ver aún la escritura); las opciones de fondo (commit en Rows.Close, timeout de tx) son un cambio de diseño para un arco propio.
4. **`Agent.Connected()`/`--require-admin` de orbit** se sigue dando por bueno al pasar la sonda de Dial aunque el token sea inválido (señalado en orbit#94; endurecerlo es un cambio de semántica aparte).

---

*Escrito para ser reproducido: cada EXIT citado salió de una ejecución real de esta sesión (2026-07-19), con las salidas completas pegadas en el PR correspondiente. La 6ª auditoría puede re-ejecutar cada gate tal cual está descrito.*
