# Handoff archivado — sesión 2026-11-08 (A12: la DX al 5 arranca)

> Movido tal cual desde el §3 de `.claude/commands/next-session.md` el
> 2026-11-12, al entrar la sesión del tren de Quantum 1.44.0 (el §3 lleva
> como mucho dos sesiones; `scripts/check_handoff_size.sh`). Historia para
> buscar con grep, no para cargar.

### Sesión 2026-11-08 — **La DX al 5 arranca: `DX-0` la cuenta y la trocea, y el bloque A entero más `DX-Q1` y `DX-Q3` entran en `main` el mismo día (seis PRs en dos productos, cinco agentes en paralelo)**

- **Arranque**: Carlos dijo «adelante con la DX al 5» sobre el set 1.43.0
  recién certificado. El §2.1 del contrato lista trece puntos; antes de
  tocar nada, `DX-0` midió cada uno al pin (tabla «Lo que hay, contado» en
  la sección «La DX al 5 — medida y troceada» del plan de A12) y troceó:
  sólo el **bloque A** (`DX-N1`, `DX-N2`, `DX-S1`) desbloquea `M1`; lo
  demás sube la nota de `R2`.
- **Tres cosas que el §2.1 no decía**: nucleus NO depende de quark, así
  que `nucleustest.Make` «sobre quark» no podía importarlo (D12: doble
  gramática sin dependencia, hecha como propuesta); las dos consultas del
  banco que faltan (58 de 60) son `GROUP BY` sin proyección con aviso
  DEP-2026-008, del 2.0 y no de 1.x; y `nucleus new --with orbit` en
  `mvc`/`api` montaba el panel sin `DataSource`, que el 2.0 rehúsa
  (NU-159, fuera de la lista de `M0-E`).
- **Lo que deja en `main`** (todo fusionado en serie con `merge-group.sh`
  y el CI de `main` verde detrás de cada uno): nucleus#644 (`DX-N1`:
  `generate model|resource` y `startapp` escriben modelos quark con
  `--data quark|sql`, `Make` con doble gramática, `bodycheck` entiende la
  gramática de quark), nucleus#646 (`DX-S1`: `--with orbit` implica quark
  y `quarkdatasource`, el panel monta con `DataSource` sobre el pool del
  framework y el scaffold arranca contra orbit 1.x y `dry-run/2.0`),
  nucleus#647 (`DX-N2`: el quickstart y ocho páginas más enseñan Quark,
  `pkg/model` como sustrato que se va; NU-133/135/144 cerrados: README 43
  comandos con test, FED-03 `present` → `auth-bench.md` **41 de 43**,
  `bodycheck -strict` sin avisos), quark#481 (`DX-Q1`: receta «What to
  do:» en **30 de 30** centinelas —la auditoría contó 25— y en 165 de 185
  wraps, contada por `TestEveryExportedSentinelNamesWhatToDo`), quark#482
  (la deriva QK-73/74/77/82 y el drift guard estricto bajo
  `docs/deprecations/`) y quark#484 (`DX-Q3`: guías de producción de
  caché, réplicas y sharding, copia byte a byte de fixtures que corren en
  CI, y dos afirmaciones falsas de la doc existente corregidas).
- **Registro**: `hecho` NU-137 (re-evidenciado con nucleus#648), NU-159,
  NU-133, NU-135, NU-144, QK-73, QK-74, QK-77, QK-78, QK-82; nuevos
  NU-160…NU-164 y QK-92…QK-99 (QK-98: doble espacio tras `IS NULL` en el
  SQL emitido; QK-99: enlace roto en `reference/api/index.mdx` que rompe
  el `npm run build` del sitio propio de quark; NU-164: nucleus dice
  `postgresql` y quark no lo acepta como nombre de motor).
- **Decisiones del propietario, el mismo día** (bloque DX del contrato):
  **D12 → opción 2** («lo más sensato es la 2, ¿no?», y lo era: al releer
  nucleus#644 la doble gramática persistía por el CRUD de `pkg/model`, la
  capa que `M1` retira, y duplicaba la gramática de quark en nucleus);
  `DX-N1b` la sustituye antes del set: costura en `nucleustest` y módulo
  `pkg/nucleustest/quarkmake` (nucleus#648, fusionado; el root sigue sin quark por `contracts/quark_out_of_root_test.go`; `nucleus add` no lo instala, por lista en `catalog_test.go`). **D13 → (a) adelante** con la
  medición hecha: quark raíz compila a `js/wasm` sin cambios y el `.wasm`
  pesa 13,1 MB crudo / 3,09 MB gzip / 2,19 MB brotli (suelo de Go 3,4 /
  0,95 / 0,71; el chunk más grande del sitio 0,75 / 0,18 / 0,14); el sitio
  no tenía presupuesto escrito, así que `DX-Q4` publica bajo tres
  condiciones —carga sólo a petición con el peso en el botón, ejemplo
  estático sin JavaScript que CI compara con el render, y
  `check_playground_weight.sh` con gzip ≤ 3,5 MB y el peso escrito a
  ±10 %— (quark#485, fusionado: 14,0 MB crudo / 3,26 MB gzip medidos por el script con los siete presets; cada instanciación genérica de `Query[T]` cuesta ~130 KB gzip, así que cuatro de los cinco modelos renderizan por una forma común con `FromTable` y dos tests prueban SQL idéntico byte a byte). El paraguas lo compila al pin en `deploy`/`website-ci`
  (setup-go + `scripts/build_quark_playground.sh`, que sale 0 mientras el
  pin no traiga el script de quark) y `umbrella-why-quantum` aprende la
  clase «kit de pruebas» (`pkg/nucleustest/*`: módulo del set que
  `nucleus add` no instala; la página tiene que decir «test kit»).
- **Trampas para el próximo tren**: `website/docs/why-quantum.md` cita
  «40 of 43» del banco de auth y `umbrella-why-quantum` lo cruza con la
  fuente al pin (41 de 43 con el nucleus nuevo): se corrige en el PR de
  set; los textos de `ErrNotFound`, `ErrTimeout` y `ErrConstraintViolation`
  de quark crecen tras el prefijo (un test de orbit que compare
  `err.Error()` exacto se rompería al subir el pin); el bloque A es la
  precondición de `M1` y tiene que salir en un set (quark y nucleus MINOR:
  notas y snapshot antes del tren, receta de 1.42.0). Y con `DX-N1b`, el
  set estrena un módulo de nucleus que NO instala `nucleus add`
  (`quarkmake`): fila en `versions.yaml` `nucleus_modules`, `use` en el
  `go.work` EN el PR de re-pin (1.26.2), la frase «test kit» en
  `why-quantum.md`, y es el primer módulo de nucleus que pina quark, así
  que la alineación tras cortar quark también le toca a nucleus.
  Dos más de `DX-N1b`: `quarkmake` nace con `0.0.0` en el manifiesto de
  release-please (receta de errors-sentry; si el tag sale con otro número,
  la trampa de 1.41.0: release-as y quitarlo), y queda FUERA de
  `scripts/ci/check_modules_standalone.sh` hasta que su suelo de nucleus
  sea la release que lleva la costura (sus tests llaman a `UseFactory`,
  que v1.34.0 no tiene): añadirlo a la lista del script en el PR de suelos.
- **`DX-N3` arranca el mismo día y queda medida y partida en tres** (fila
  `DX-N3` del plan): el CLI de quark escribía la migración derivada de
  modelos como fichero Go, y nucleus la quiere como par `.up.sql`/`.down.sql`.
  `DX-N3q` (quark#486): `migrate create --from-models --emit json` imprime
  `{schema:1, tool, version, dialect, models, up, down}` sin escribir nada
  (hallazgo de paso QK-100: `--from-models` se resuelve contra el cwd).
  `DX-N3n1` (nucleus#650): `generate module` sobre `nucleus.Handle` tipado
  con esquemas en `/openapi.json` y errores por el sobre (problem+json
  negociado); `doctor`/`health`/`config print` leen los imports
  `providers/*` de `main.go`; NU-132/136/145 `hecho`; nuevos NU-165…167
  (la doc a mano del quickstart enseña `{"error": …}` fuera del sobre y
  afirma que es «la misma forma» que el generador; `resource`/`startapp`
  siguen sin tipar; un test con interceptor de relleno). **`DX-N3n2`**
  (`nucleus makemigrations` llamando al CLI de quark con `--emit json`)
  espera a que el set del 2026-11-16 publique `cmd/quark`: la lane
  `suite-starter` monta los hermanos a su última release, así que antes
  no puede estar verde.
- **Lo siguiente**: el set del 2026-11-16 (publica el bloque A, `DX-Q1` y
  `DX-Q3`); `DX-N3` (`makemigrations` delegando en el CLI de quark,
  NU-145/136/132: sólo queda `DX-N3n2`, `makemigrations`, tras la release
  de `cmd/quark` del set) en 1.x en paralelo a `M1`; el nacimiento de
  `providers/tasks-asynq`; D9…D11 de Carlos (D12 y D13 ya decididas).

