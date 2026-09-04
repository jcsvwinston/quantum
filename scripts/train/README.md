# El tren de releases — runbook y driver (RT-1)

Cortar un set certificado eran ~12 fases manuales y 15-25 PRs con el
procedimiento repartido entre `docs/AUDITORIA_CONTINUA.md` §3 y la memoria de
quien conducía: ~2 horas de conducción experta por set. Este directorio
contiene el driver de la parte MECÁNICA y este runbook con el paso a paso
completo, trampas incluidas.

Los tres scripts son **escritores/conductores, no verificadores**: no están
(ni deben estar) en el registro de guards. Los jueces siguen siendo
`manifest-guard.sh`, `suite-integral.sh` y los CI de cada repo. `scripts/train/`
queda fuera del escaneo anti-fósil a propósito (solo cubre `scripts/`,
`scripts/ci/` y `scripts/website/`).

| Script | Qué hace |
|---|---|
| `train.sh` | Driver por fases: `preflight → quark → nucleus → orbit → paraguas → cierre`. Imprime SIEMPRE qué va a hacer antes de hacerlo, para EN SECO al primer rojo, y donde hace falta juicio humano se detiene con la instrucción exacta (EXIT=2). `--dry-run` para ensayar; `--desde <fase>` para retomar. |
| `merge-bot-pr.sh <repo> <pr>` | Fusiona UN release PR del bot: push humano de commit vacío (dispara el CI que el token del bot no puede), espera de checks con `gh pr checks --watch --fail-fast`, `update-branch` si queda BEHIND, merge con el método del repo, y espera del tag con receta de recuperación si release-please se atasca. |
| `check-anchored-release-branch.sh <repo> [pr]` | Detecta la rama de release del ROOT anclada al main viejo: `git merge-base --is-ancestor` de cada último tag de módulo contra el head del PR. Si falla, imprime la receta cerrar + borrar rama + re-dispatch. Se ejecuta JUSTO ANTES de fusionar el root. |
| `dispatch-app-bump.sh` | Anuncia el set YA certificado al consumidor externo `quantum-app` (`repository_dispatch` con el número de suite y la salida de `print-requires.sh`), **espera el run** que provoca y **exige que termine en PR** (QM-2). Allí un workflow reescribe el pin, corre sus gates y abre el PR. Exige `status: certified` y que el tag de suite exista; no fusiona ni escribe nada en el otro repo. |

## El tren, paso a paso

Orden de dependencias, de `docs/AUDITORIA_CONTINUA.md` §3 más lo aprendido en
los cierres 1.19.0–1.24.0. La lección de 1.24.0 manda: **quark → nucleus ANTES
que orbit**, y todos los módulos de orbit (root incluido) re-pinados en el
mismo tren — cortar nucleus después de orbit obligó a DOS roots extra
(v1.8.12 y v1.8.13).

### 0. Preflight (`train.sh --hasta preflight`)

- `gh` autenticado; árbol del paraguas limpio (lo exigirá la certificación,
  QM8-5); `declared_lags` vacío o con plan de vaciarse en este tren.
- Las **deudas de doc por minor (RT-9)** se saldan EN la rama de cada release
  PR, no después (cada olvido cuesta 2 vueltas de CI):
  - **quark**: sección `## vX.Y.0` en las release notes del sitio +
    `docs/RELEASE_NOTES_vX.Y.0.md` + menciones en README/SECURITY/CLAUDE.md
    (CLAUDE.md no está en extra-files a propósito — release-please hacía
    reemplazo global y falsificaba el historial).
  - **nucleus**: sección `## vX.Y.Z` en `website/docs/reference/release-notes.md`
    + snapshot de docs versionadas (`scripts/release/cut_docs_snapshot.sh`) EN
    la rama del release — ahí el marcador ya declara la versión nueva, así que
    el snapshot sale correcto por construcción.
  - **orbit** (root): sección `## vX.Y.Z` en sus release notes.

### 1. quark (`train.sh --desde quark --hasta quark`)

Un solo módulo: fusionar su release PR con `merge-bot-pr.sh quark <n>` y
esperar el tag.

### 2. nucleus

Multi-módulo desde v1.15.0 y con **doce hermanos** desde D3 (cinco drivers,
dos exportadores, cinco providers). Con `separate-pull-requests: false` el bot
abre UN PR («chore: release main») que corta el root y todos los módulos del
mismo commit, y el driver lo trata como root. Si alguna vez vuelven los PRs
por módulo, el driver los clasifica por título de forma **genérica** —
cualquier `chore(main): release <ruta> X.Y.Z` es un módulo, sin lista escrita
(QM-8) — y los ordena hojas → dependientes leyendo los `require` entre
hermanos del `go.mod` de cada uno, root el último: manifest-guard §3b exige
que el tag del módulo sea ancestro del pin raíz, y un tag de módulo cortado
DESPUÉS del de la raíz no es certificable. Tras fusionar un módulo, el PR del
root puede quedar **anclado al main viejo**: `check-anchored-release-branch.sh
nucleus` antes de fusionarlo (pasó en #391→#395).

### 3. orbit

Seis módulos con manifest compartido; desde D3 con
`separate-pull-requests: false` (un solo PR «chore: release main», que el
driver trata como root). Si vuelven los PRs por módulo, el orden lo calcula
el driver desde los `require` entre hermanos: hojas → dependientes → **ROOT EL
ÚLTIMO** (`proto` → `agent` → bump del pin de agent en server → `server` →
`quarkbridge`/`quarkdatasource` → root). Trampas:

- **Cascada DIRTY**: cada merge puede dejar los demás release PRs en conflicto
  por el `.release-please-manifest.json` compartido. A veces release-please
  los regenera solo (verificar `gh pr view <n> --json mergeable`); si no,
  reconciliar a mano: manifest = main + el bump propio del PR, push normal.
- **Rama del root anclada**: mismo check que en nucleus, antes de fusionar el
  root (pasó en #338→#339).
- **Root sin commits releasables**: el footer `Release-As: X.Y.Z` en un commit
  chore CON contenido real lo fuerza (release-please filtra los commits
  vacíos; `"release-as"` en el config NO abre PR por sí solo).
- **La arista quarkdatasource→root** tolera ≤1 minor de lag: no es permiso, es
  deuda con plazo — el segundo minor la saca de rango en plena certificación.

### 4. Re-pin del paraguas (`train.sh --desde paraguas`)

`bump-set.sh` (mueve submódulos al tag y reescribe versions.yaml/README) +
`manifest-guard.sh`, y después lo humano: versión de SUITE según QADR-0002,
`notes`, CHANGELOG, quitar `QUANTUM_ALLOW_DECLARED_LAGS` del workflow si
estaba, y el PR de re-pin — cuya lane suite-integral debe salir verde **sin
escapes** (corre en modo normal: tolera el mid-tren sin tag). Ojo al re-pin
que trae un guard nuevo de producto: la aserción anti-fósil pone la lane roja
hasta registrarlo (con fixture) o excluirlo con porqué.

### 5. Cierre (`train.sh --desde cierre --hasta cierre`)

Tras fusionar el PR de re-pin (quantum usa MERGE COMMIT):

1. `git checkout main && git pull` — el tag se corta EN HEAD, **después del
   último PR de la ronda**, nunca antes.
2. `git tag -a vX.Y.Z` + push.
3. `bash scripts/suite-integral.sh --cierre` → EXIT=0 (el tag existe, captura
   HEAD — assert 5 — y sin escapes). Correrlo ANTES de taggear es FAIL por
   diseño (MAQ-2/B.2).
4. `dispatch-app-bump.sh` — el consumidor EXTERNO de referencia se entera del
   set (D6/RT-5). Va aquí y no antes: `quantum-app` sigue al set **certificado**,
   nunca al mid-tren, y el script se niega si `versions.yaml` no dice
   `status: certified` o si el tag `vX.Y.Z` no existe todavía. El script
   **espera el run** de `set-bump.yml` y **exige el PR** `chore/set-X.Y.Z`
   (ver «El anuncio a quantum-app exige un permiso del repo», abajo). Si
   falla no se pierde nada: el set ya está certificado y la pieza se relanza
   sola (`bash scripts/train/dispatch-app-bump.sh`) o se dispara a mano desde
   la pestaña Actions de quantum-app.
5. El CIERRE de ronda se escribe con la plantilla de `AUDITORIA_CONTINUA.md`
   §6 (conteos COPIADOS de las tablas de las lanes) y se actualiza
   `docs/RUMBO.md`.

### El anuncio a quantum-app exige un permiso del repo (REQUISITO)

El workflow `set-bump.yml` de quantum-app abre el PR con el `GITHUB_TOKEN` de
Actions, y GitHub se lo prohíbe por defecto: el dispatch de 1.26.0 se aceptó
(HTTP 204), el run murió con **«GitHub Actions is not permitted to create or
approve pull requests»**, la rama `chore/set-1.26.0` quedó sin PR y el tren
dio el cierre por bueno porque el anuncio era fire-and-forget (QM-2).

Requisito, una sola vez, **lo activa Carlos** en `jcsvwinston/quantum-app`:

> Settings → Actions → General → Workflow permissions →
> ☑ **Allow GitHub Actions to create and approve pull requests**

(o, alternativamente, el secreto `QUANTUM_APP_PR_TOKEN` con un PAT: entonces
el PR además dispara su propio CI — ver la trampa del PR sin checks, abajo).
Se comprueba sin abrir el navegador:

```bash
gh api repos/jcsvwinston/quantum-app/actions/permissions/workflow
# {"default_workflow_permissions":"read","can_approve_pull_request_reviews":true}  ← lo que hace falta
```

Desde QM-2 `dispatch-app-bump.sh` no confía en el 204: localiza el run creado
tras el dispatch, lo espera (`gh run watch`) y decide por el PR — PR abierto
es OK (en borrador si los gates salieron rojos: deuda de quantum-app); run
verde sin PR es bump idempotente; run rojo sin PR es FAIL con la receta del
permiso. `--sin-esperar` recupera el comportamiento antiguo para ensayos.

## Trampas transversales (por qué el driver hace lo que hace)

- **Los PRs de release-please no disparan CI** (token del bot + guardia
  anti-recursión): quedan BLOCKED con «no checks reported». El disparador
  determinista es el **push humano de commit vacío** (release-please los
  filtra: no ensucian el changelog); close/reopen a veces no dispara y hay
  sospecha de que dejó a release-please sin poder etiquetar una vez.
- **Merges estrictamente seriales** donde main exige ramas al día (nucleus):
  cada merge deja al resto en BEHIND → `update-branch` + otra vuelta de
  checks. El driver lo hace; no intentes paralelizar.
- **release-please puede auto-bloquearse** («untagged, merged release PRs
  outstanding»): PR merged con `autorelease: pending` y sin tag. Receta en
  `merge-bot-pr.sh` (tag manual + `gh release create` + relabel a
  `autorelease: tagged` — sin el relabel el siguiente corte vuelve a abortar).
- **Los tags del token del bot no disparan `push:tags`**: los assets salen
  porque «Release Please» encadena `release.yml` por `workflow_dispatch`
  (arreglado en 1.24.0) — si una release sale sin binarios, mirar ahí.
- **El PR del bump de quantum-app puede salir sin checks**: lo abre el
  `GITHUB_TOKEN` de Actions, y GitHub no dispara workflows `pull_request` para
  PRs creados con ese token — la misma familia de trampa que los release PRs
  del bot. La evidencia entonces son los gates de la corrida que abrió el PR
  (van en su cuerpo); para que corra además el CI del PR, un commit vacío en
  la rama o el secreto `QUANTUM_APP_PR_TOKEN` en quantum-app.
- **PRs zombi** al cambiar la configuración de ramas de release-please (rama
  vieja sin componente + rama nueva): cerrar el de la rama vieja y borrar la
  rama.

### El orden dentro del tren: qué va ANTES del corte

Tres cosas tienen que estar DENTRO del tag y las tres parecen posteriores. La
certificación las caza, pero entonces cuestan una ronda entera por repo — en
el tren de 1.26.0 costaron tres.

**1. El snapshot de documentación y las notas de la versión.** El sitio sirve
la doc del TAG PINADO, así que un snapshot añadido después del corte no llega
al lector hasta la release siguiente. release-please bumpa el marcador de
versión; la narrativa la escribe una persona. Ambos van **en la rama del
release**, y en este orden: primero las notas, después el snapshot — al revés
se archiva una versión anunciando otra, que es lo que rechaza
`check_versioned_docs_markers.sh`. Mordió con quark: el snapshot de v1.9.0 se
cortó en un PR fusionado DESPUÉS del release y hubo que gastar una minor
entera (v1.10.0) para meterlo.

**2. El pin del módulo hermano dentro del mismo repo.** `align_set.sh` corre
ANTES del corte, así que fija el hermano al tag entonces vigente — y el corte
publica el siguiente acto seguido. En orbit eso deja `server` pinando un
`agent` viejo, y ahí el desfase SÍ importa: `go install
.../admin-server@server/vX` resuelve el agent que server pina y no hay ningún
otro consumidor que suba el suelo, así que el binario se lleva el agent viejo.
(Distinto del suelo de un módulo hacia su PROPIA raíz, que es un aviso: allí
MVS sube la versión porque el consumidor requiere también la raíz.)

**3. Y el más sutil: arreglar SÓLO un módulo no corta el root.** Un
`fix(server):` que toca únicamente `server/` hace que release-please proponga
`server/vX` a secas — un tag que saldría DESPUÉS del root pinado, y §3b lo
rechaza por definición. El módulo queda colgando por delante del set, sin
forma de certificarlo. Se arregla con un cambio que pertenezca al paquete
RAÍZ en el mismo tren (las notas de la versión valen, el sitio es del root) y
un `Release-As:` en el footer, para que los dos tags salgan del mismo commit.

### El tag de un módulo Go lleva BARRA, no guion

`tag-separator` decide si el tag sale `drivers/mysql/v0.1.0` o
`drivers/mysql-v0.1.0`. Con guion **Go no lo resuelve**:

    go: github.com/jcsvwinston/quark/drivers/mysql@v0.1.0:
        invalid version: unknown revision drivers/mysql/v0.1.0

Un tag así no es una versión, es un nombre que nadie puede pedir — y es
justo lo que el error guiado promete que funcione.

Mordió en el tren de D3 porque quark tenía `tag-separator: "-"` en la RAÍZ.
Ahí da igual (el tag del root no lleva componente, es `v1.9.0`), pero los
módulos nuevos lo heredaron y se publicaron dos tags inservibles. La
comprobación es una línea y va DESPUÉS de cortar, no antes:

```bash
GOPROXY=https://proxy.golang.org go list -m <módulo>@<versión>
```

Si sale `404` o `unknown revision`, el tag está mal formado: se retira (con
`gh release delete --cleanup-tag`), se pone `tag-separator: "/"` **por
paquete** —no en la raíz, para no tocar el formato del tag del root— y se
vuelve a cortar.

### Un módulo nuevo replaya el historial entero

Registrarlo no basta. Sin tag previo, release-please recorre TODO el
historial del repo para ese componente: propone un número sacado de commits
ajenos (v1.9.2 para módulos que no existían entonces) y les escribe un
CHANGELOG con cambios de otros — un arreglo de `pkg/storage` listado como
cambio de `drivers/sqlite`. Eso queda **congelado dentro del tag**.

`release-as` fija el número; `bootstrap-sha` y `last-release-sha` NO
acotaron el changelog en la práctica. Lo que sí funciona: **un solo PR de
release** (ver abajo) y editar los CHANGELOG en su rama antes de fusionar.

### Con muchos módulos, un SOLO PR de release

`separate-pull-requests` abre uno por módulo, y todos escriben el mismo
`.release-please-manifest.json`: fusionar uno deja al resto en conflicto, y
en un repo cuyo `main` exige un gate requerido **ninguno se puede fusionar**
porque los release PR no disparan CI. Con doce módulos eso es un bucle que
no avanza.

Con `separate-pull-requests: false`: el manifiesto se escribe una vez, hay
UNA corrida de CI, y **todos los tags salen del mismo commit** — con lo que
la regla de ancestría de `manifest-guard §3b` se cumple por construcción en
vez de por verificación manual. Es donde el tren de quark tropezó con una
rama rancia en este mismo ciclo.

**La contrapartida, y muerde fuerte**: con un PR único, `Release-As:` se aplica
a **TODOS los paquetes**, no sólo al root. Un footer puesto para forzar el
corte de la raíz publicó `quarkbridge` como `1.8.17` viniendo de `0.4.10` — un
major inventado para un módulo que sólo cambiaba un pin.

Para forzar el corte del root sin efectos laterales: un commit `fix:` que
toque un fichero del paquete RAÍZ (las notas de la versión valen: el sitio es
del root) y **sin** footer — eso ya bumpea la raíz sola. El `Release-As` queda
para cuando hay que fijar un NÚMERO concreto, y entonces hay que revisar el
manifiesto del release PR antes de fusionarlo.

### Al enlazar un driver en un test, importa el MÓDULO

Desde que los drivers viajan en módulos propios, un test que abre una base
de datos necesita enlazar uno. Importar el paquete del driver a secas
(`_ "modernc.org/sqlite"`) **compila y pasa**, pero no registra el
clasificador de errores: `IsUniqueViolation` y el reintento de deadlocks no
fallan sin él — contestan `false`. Un test que dependa de eso pasa en verde
midiendo otra cosa.

Importar el módulo (`_ ".../drivers/sqlite"`) registra las dos mitades, y es
además lo que escribe una aplicación real. La excepción es el repo que
PUBLICA el módulo: ahí el requisito sería circular, y se usa el paquete
interno de predicados compartidos.

Corolario que costó una ronda: una suite que sólo corre con motor real
(las lanes de matriz, Data Studio contra PostgreSQL) **no se ve en local**,
porque se salta sin DSN. Al tocar drivers, mirar qué lanes necesitan uno.

### Un módulo nuevo no sale publicado por existir

Crear un módulo hermano y fusionarlo **no** le da tag. Hay que registrarlo en
`release-please-config.json` **y** en `.release-please-manifest.json`, y si no
está, release-please lo ignora en silencio: el árbol tiene el módulo, el
release PR no lo menciona, y nadie se entera hasta que alguien hace `go get`.

Mordió al arrancar el tren de D3, con **diez módulos en nucleus y sólo dos
registrados**: los cuatro backends de nube de ADR-030 llevaban un tramo entero
fusionados sin haber salido nunca. En quark, cinco de seis.

Lo que lo vuelve caro no es el tag que falta, es la promesa que rompe: el error
guiado dice literalmente

    go get github.com/jcsvwinston/nucleus/drivers/postgres

y sin tag esa línea **falla**. La regla que sale:

> Un mensaje de error que nombra un `go get` es un contrato. Antes de cortar el
> set, comprobar que **cada módulo del árbol está en el manifiesto**.

La comprobación cabe en una línea, por repo:

```bash
diff <(find . -name go.mod -not -path './examples/*' | sed 's|/go.mod||;s|^\./||' | sort) \
     <(python3 -c "import json;print('\n'.join(sorted(json.load(open('.release-please-manifest.json')))))" | sed 's|^\.$|.|')
```

Los módulos nuevos entran al manifiesto con `0.0.0`, para que el primer corte
les dé `v0.1.0`.

### El `!` de un commit decide el número del set entero

Un commit `feat(algo)!:` hace que release-please proponga un **major**, y en
esta suite un major **no es una decisión local**: QADR-0002 mantiene los majors
de los tres pilares en lockstep, así que un `!` de más en nucleus arrastra a
quark y a orbit a la 2.0.

Mordió en el arco D3 (nucleus#407 → #408 proponiendo `2.0.0` por un cambio de
empaquetado). La regla que sale:

> El `!` es para rupturas de lo que el framework **hace**, no de dónde se
> compila algo. Si el compilador nombra lo que falta y la receta cabe en el
> error, es una minor.

Y si ya está fusionado, no se arregla reescribiendo el commit: se **fuerza el
número** con un `Release-As:` en el footer de otro PR. Dos condiciones que
cuestan una ronda cada una si se olvidan:

- el `Release-As` tiene que ir en un commit que **toque un fichero real del
  módulo** — en un `chore` suelto se ignora;
- al fusionar hay que **controlar el mensaje del squash** (`--subject` /
  `--body`): si el footer queda anidado dentro de un bullet, release-please no
  lo lee.

Comprobación barata antes de fusionar cualquier release PR: que el título diga
el número que esperabas. Es la única señal que da el bot, y llega tarde.

### Lo que aprendió el tren de 1.26.1 (el de la auditoría de madurez)

- **El push de la fusión de un release PR puede NO disparar «Release Please».**
  Pasó en nucleus#456: `gh pr merge --merge` por token humano, main avanzó, y
  ni CI ni Release Please corrieron por `push` — cero runs, ni en cola.
  Remedio: `gh workflow run 'Release Please' -R jcsvwinston/<repo> --ref
  main` (y `CI` si se quiere el verde en main). `merge-bot-pr.sh` lo hace solo
  a los dos minutos sin corrida por push del commit de merge.
- **`chore: release main` es un release PR aunque no lleve número.** El
  driver lo trataba como «no es de release-please» y daba el merge por bueno
  sin esperar tag. Ahora lee `.release-please-manifest.json` del commit de
  merge y espera TODOS los tags que declara (root `vX.Y.Z` y `<ruta>/vX.Y.Z`).
- **quark tenía el mismo `release-as` pegajoso que nucleus antes de D3** y
  `separate-pull-requests: true`: seis PRs de release proponiendo `0.1.0` para
  módulos ya publicados en `v0.1.0`. Se arregló en la config (quark#345) y
  release-please regeneró un PR único; los seis viejos son zombis que hay que
  cerrar a mano (`gh pr close --delete-branch`) — no se cierran solos.
- **Las release notes no pueden citar un ADR.** `check_docs_product_voice.sh`
  de orbit rechaza «ADR-002» en `release-notes.md` (el lector no puede abrirlo):
  se explica la decisión en prosa. Costó una vuelta de CI del release PR.
- **`merge-bot-pr.sh` se lanza desde la raíz del paraguas.** Con `cd` a otro
  repo la ruta relativa no existe y el driver muere antes de hacer nada.
- **Los patches también llevan sección `## vX.Y.Z` en las release notes** de
  los tres productos (`check_version_claims.sh` en nucleus,
  `check-version-coherence.sh` en quark, `check_docs_version_claims.sh` en
  orbit); solo el snapshot de docs es por minor.

### Lo que aprendió el tren de 1.25.0 (el primero conducido con estos scripts)

- **Fusionar el release de un módulo REGENERA la rama del root, y se lleva por
  delante lo que hubieras escrito a mano en ella.** Pasó con nucleus: las notas
  de la versión, el snapshot de docs versionadas y el arreglo de la sidebar
  desaparecieron al fusionar `providers/ldap`. Se recuperaron porque el
  worktree seguía montado; a la segunda hubo que reescribirlas.
  **Regla: las deudas de doc del root se escriben CUANDO LA CASCADA DE MÓDULOS
  YA ESTÁ CERRADA**, no antes. Y mientras haya trabajo humano en una rama de
  release, no la borres — `git log --oneline origin/main..<rama>` antes de
  cualquier receta destructiva (por eso `check-anchored-release-branch.sh`
  ofrece ahora primero la vía no destructiva).
- **Reconciliar el manifest compartido: valida el JSON ANTES de commitear.**
  El resolutor automático de un conflicto falló a mitad y el commit se empujó
  igual, dejando el manifest sin una coma —JSON inválido— en la rama del
  release. No encadenes `resolver && commit && push`: resuelve, **parsea el
  fichero** (`python3 -c "import json;json.load(open(...))"`), y solo entonces
  commitea. Un manifest roto no lo caza ningún guard: lo consume
  release-please.
- **El proxy de Go falla en tandas.** `sum.golang.org` / `proxy.golang.org`
  devolviendo `INTERNAL_ERROR` (o dejando la caché corrupta en `setup-go`)
  tumbó **tres** lanes distintas en un mismo tren, en tres repos. Firma
  reconocible: el fallo es de descarga/verificación de un módulo, no de un
  test. Remedio: `gh run rerun <id> --failed`, **sin tocar código**. Es el
  rojo que más induce a "arreglar" algo que está sano.
- **Un submódulo del paraguas no inicializado hace que los scripts operen
  sobre el repo equivocado.** En un worktree nuevo, `git submodule update
  --init --recursive` ANTES de `bump-set.sh`: sin él, un `git -C orbit fetch`
  cae al repo padre y los tags que ves son los del paraguas.
- **El árbol tiene que estar limpio de verdad para `--cierre`.** Un
  `showcase_demo.db` sin trackear —artefacto de haber corrido la demo— basta
  para que la certificación se niegue (QM8-5). El escape `QUANTUM_ALLOW_DIRTY`
  no existe en modo cierre, y hace bien.
- **Un guard nuevo en un producto bloquea la certificación hasta registrarlo.**
  Al re-pinar orbit entró `check_adr_index.sh` y la aserción anti-fósil se negó
  a certificar: hay que añadirlo a `scripts/lib/guard-registry.sh` **y** darle
  fixture en `tests/guard-fixtures/<nombre>/`. Cuéntalo en el PR de
  certificación; no es ruido, es el inventario haciendo su trabajo.
