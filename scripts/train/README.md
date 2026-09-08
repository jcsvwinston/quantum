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
| `train.sh` | Driver por fases: `preflight → quark → nucleus → orbit → paraguas → cierre`. Imprime SIEMPRE qué va a hacer antes de hacerlo, para EN SECO al primer rojo, y donde hace falta juicio humano se detiene con la instrucción exacta (EXIT=2). `--dry-run` para ensayar (alcance justo debajo de la tabla); `--desde <fase>` para retomar. Se **cronometra por fase** («El reloj del tren», abajo: `--reloj`, `--reloj-cero`) y la fase paraguas **abre y fusiona ella misma** el PR de re-pin cuando las notes ya están redactadas — desde main al día, con solo las rutas del re-pin (`--incluye <ruta>` para añadir una a propósito) y preguntando a origin, no al árbol, si ya está fusionado. |
| `merge-bot-pr.sh <repo> <pr>` | Fusiona UN release PR del bot: push humano de commit vacío (dispara el CI que el token del bot no puede), espera de checks con `gh pr checks --watch --fail-fast`, `update-branch` si queda BEHIND, merge con el método del repo, y espera de los tags; si «Release Please» no corre la dispara, y si corre y termina SIN etiquetar (el auto-bloqueo) aplica `untag-recipe.sh` sola (`--sin-receta` para que solo lo imprima). |
| `check-anchored-release-branch.sh <repo> [pr]` | Detecta la rama de release del ROOT anclada al main viejo: `git merge-base --is-ancestor` de cada último tag de módulo contra el head del PR. Si falla, imprime la receta cerrar + borrar rama + re-dispatch. Se ejecuta JUSTO ANTES de fusionar el root. |
| `dispatch-app-bump.sh` | Anuncia el set YA certificado al consumidor externo `quantum-app` (`repository_dispatch` con el número de suite y la salida de `print-requires.sh`), **espera el run** que provoca y **exige que termine en PR** (QM-2). Allí un workflow reescribe el pin, corre sus gates y abre el PR. Exige `status: certified` y que el tag de suite exista; no fusiona ni escribe nada en el otro repo. |
| `merge-group.sh <repo> <--squash\|--merge> <pr>...` | Fusiona PRs humanos o de Dependabot en serie: `update-branch` si BEHIND (nucleus exige ramas al día), espera de checks, merge; para en rojo. No es para release PRs (para eso, `merge-bot-pr.sh`). |
| `orbit-converge.sh <root> <tags> <rama>` | Un corte de convergencia de pines internos de orbit (ADR-006): `align_set.sh` con el manifiesto del paraguas, notas del root en el mismo commit `fix(deps)`, PR, fusión, release PR y tags. Tras ADR-006 solo hace falta cuando cambia `proto`. |
| `untag-recipe.sh <repo\|repo-dir> <pr>` | La receta del auto-bloqueo de release-please, mecanizada: por cada tag del manifest del commit de merge que falte, tag anotado + release de GitHub con la sección del CHANGELOG + relabel `autorelease: tagged`. No hace checkout (lee con `git show <sha>:` y etiqueta por SHA): vale sobre `../<repo>`, sobre el submódulo pinado o sobre un clon temporal. `--dry-run` para ver qué cortaría. La CAUSA del auto-bloqueo está en su cabecera. |
| `align-module-floors.sh <nucleus\|quark>` | Sube el suelo `require github.com/jcsvwinston/<repo>` de los módulos hermanos al último tag de raíz publicado (QM-19). `--check` lista los que van por detrás; sin flag reescribe, `tidy` y commit `fix(deps)`. **Corre al principio de cada corte** (decisión 2026-09-05): el driver lo hace solo en la fase de cada repo (rama, PR, fusión, espera de Release Please), así que el `fix(deps)` entra en el mismo release PR que el trabajo. Orbit sigue con su `align_set.sh`. |
| `align-orbit-pins.sh [--check]` | Los pines CRUZADOS de orbit (nucleus y quark en sus seis go.mod, más los hermanos) hacia los ÚLTIMOS tags de `../quark` y `../nucleus`, llamando al `align_set.sh` de orbit. `--check` solo verifica (pone `main` al día antes). El driver lo corre al principio de la fase orbit (`alinea_pines_orbit`: rama, PR, fusión, espera de Release Please) — sin esto, cortar quark/nucleus y orbit el mismo día deja el manifest-guard §5 en FAIL (1.28.0 costó un corte de más). |
| `quark-doc-debt.sh [--dry-run]` | La deuda de doc de una release de quark (RT-9), pagada EN la rama del bot: worktree de `release-please--branches--main`, merge de `main` si la rama no lo trae, `gen_release_notes_skeleton.sh` de quark (sección del sitio, `RELEASE_NOTES`, línea marcada de CLAUDE.md, puntero del README) y push. Para (EXIT=2) sólo si el esqueleto dejó `TODO`: la prosa no se delega. El driver lo corre en la fase quark antes de `merge-bot-pr.sh`. |
| `orbit-align-notes.sh [--dry-run]` | La deuda RT-9 de una release de ALINEACIÓN de orbit, en la rama del bot: la sección `## vX.Y.Z — fecha` («alignment release with no product change», con los pines y los tags que salen a la vez, leídos del manifest y los go.mod de la rama). `alinea_pines_orbit` la llama tras la espera de Release Please; no-op si la sección ya existe. |

**Qué ensaya `--dry-run` y qué no.** No toca los remotos ni el set: no empuja,
no abre ni fusiona PRs, no etiqueta y no certifica. En las fases de repo sí toca
los checkouts HERMANOS en local, porque dos comprobaciones corren a propósito
fuera del ensayo —si no, el ensayo mentiría sobre lo que van a decir—:
`align-orbit-pins.sh --check` pone `../orbit` al día con un `git pull --ff-only`
(solo si está en `main` y limpio), y `quark-doc-debt.sh --dry-run` trae refs a
`../quark` y abre allí un worktree temporal donde mergea `origin/main` y
commitea el esqueleto de notas; no lo empuja, y el worktree se retira al salir.
Las dos fases que A3 cambia —paraguas y cierre— no dejan rastro:
`--dry-run --desde paraguas --hasta cierre` sale con el árbol igual, en la misma
rama y en el mismo commit, sin directorio de reloj y con el reloj temporal
borrado. Y el propio ensayo lo dice al terminar: su última línea nombra los
checkouts hermanos que el recorrido ha tocado —y solo esos— en vez de rematar
con un «nada se ha ejecutado con efectos» que en las fases de repo sería falso.

## El tren, paso a paso

Orden de dependencias, de `docs/AUDITORIA_CONTINUA.md` §3 más lo aprendido en
los cierres 1.19.0–1.24.0. La lección de 1.24.0 manda: **quark → nucleus ANTES
que orbit**, y todos los módulos de orbit (root incluido) re-pinados en el
mismo tren — cortar nucleus después de orbit obligó a DOS roots extra
(v1.8.12 y v1.8.13).

### 0. Preflight (`train.sh --hasta preflight`)

- `gh` autenticado; el paraguas **en `main`** y árbol limpio (lo exigirá la
  certificación, QM8-5, y de `main` sale el PR de re-pin, que se fusiona sin
  que nadie mire su diff); `declared_lags` vacío o con plan de vaciarse en
  este tren. El preflight avisa de la rama y del árbol sucio; la fase paraguas
  es la que para en seco.
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

`bump-set.sh` mueve los submódulos al tag, reescribe versions.yaml/README y,
desde 1.27.0, también lo que antes era humano y se rompía a mano: la versión
de SUITE por QADR-0002 (calculada del salto real de los pilares), `released`,
el comentario de `status`, las notes anteriores a `CHANGELOG.md` (DX-25) y un
esqueleto de notes con los movimientos del set y marcadores `REDACTAR`
(`scripts/lib/set-notes.py`). `manifest-guard` §0 rechaza el marcador — el
driver lo tolera en local con `QUANTUM_ALLOW_NOTES_SKELETON=1` mientras se
redacta; el CI nunca.

Desde A3 esta fase para en UN solo sitio, y por una sola razón: **la prosa**.
Con marcadores `REDACTAR` en `versions.yaml` el driver sale con EXIT=2 y pide
lo que no se delega — redactar las notes, revisar el título que `bump-set`
puso a la entrada anterior del `CHANGELOG.md`, actualizar la cabecera «Estado
real» de `docs/RUMBO.md` con el set nuevo y quitar
`QUANTUM_ALLOW_DECLARED_LAGS` del workflow si estaba. Sin marcadores ya no
queda ninguna decisión que tomar, así que **el driver hace el resto solo**:
corre en local los guards que la lane va a exigir (`manifest-guard` sin
escapes, `check_rumbo_estado`, `check_gowork_covers_manifest` — abrir un PR
que ya se sabe rojo cuesta una vuelta de CI), crea la rama `chore/set-X.Y.Z`,
commitea con las notes por cuerpo, abre el PR y lo fusiona con
`merge-group.sh quantum --merge`. La lane suite-integral del PR debe salir
verde **sin escapes** (corre en modo normal: tolera el mid-tren sin tag).

Se retoma con `--desde paraguas` (la propia fase, no la siguiente): al volver,
`bump-set` NO se repite —los tres pines ya están en el último tag, y repetirlo
mandaría las notes recién redactadas al CHANGELOG y escribiría otro esqueleto
encima— y el driver va directo a abrir y fusionar. Con
`--desde paraguas --hasta cierre` el re-pin y el cierre encadenan en una sola
invocación.

**De dónde sale la rama y qué entra en el commit.** Hasta A3, el diff del
re-pin lo veía la persona que abría el PR. Ahora se fusiona sin que nadie lo
mire, así que las dos cosas que esa persona comprobaba de un vistazo son
condiciones del driver:

- **De main y de un main al día.** La rama se creaba desde el HEAD que hubiera:
  conducir el tren desde una rama de trabajo metía los commits de esa rama en
  `chore/set-X.Y.Z` y de ahí a main. Ahora, si `HEAD` no es `main` o `main` no
  coincide con `origin/main`, la fase para en seco — **nada más entrar**, antes
  de que `bump-set` escriba el re-pin y el propietario redacte la prosa en la
  rama equivocada; comprobarlo justo antes de crear la rama dejaba todo ese
  trabajo hecho en el sitio que no era. La única otra procedencia legítima es
  la rama `chore/set-*` del camino de recuperación, y ahí lo que se exige es lo
  mismo dicho de otra forma: que **descienda de un `origin/main` al día**
  (`git merge-base --is-ancestor`). Si main se movió por debajo —la ola de PRs
  de la ronda se sigue fusionando mientras el tren corre—, se rebasa y se
  relanza. El preflight avisa de la RAMA (y del árbol sucio); que main esté al
  día y que la rama del set descienda de `origin/main` lo comprueba la propia
  fase paraguas al entrar.
- **Solo las rutas del re-pin.** El commit era un `git add -A`: cualquier
  fichero suelto del árbol —una nota de trabajo, un `.orig` de un conflicto, un
  backup del editor, la salida de un script— entraba en el PR y se fusionaba.
  Ahora entran solo `versions.yaml`, `README.md`, `CHANGELOG.md`,
  `docs/RUMBO.md`, `go.work`/`go.work.sum` y los gitlinks `quark`, `nucleus` y
  `orbit` (`RUTAS_REPIN`), y lo que quede fuera **para el tren** (EXIT=2) con
  los ficheros por delante. Si alguno va de verdad en el set, se nombra:
  `--desde paraguas --incluye docs/handoff/<fichero>.md`. Nombrarlo es la
  revisión que el paso automático quitó, y la parada imprime la orden de
  relanzamiento ya escrita, **con un fichero por ruta y uno por línea**: el
  árbol se lista con `-uall` porque `git status` colapsa un directorio nuevo
  entero en una sola línea (`docs/handoff/`), y entonces lo que viajaba a
  `--incluye` era el resumen y no el fichero. `--incluye` acepta
  indistintamente el fichero o el directorio que lo contiene, con barra final o
  sin ella. La orden se siembra con **los `--incluye` que ya se habían
  aceptado**: sin eso, aceptar dos rutas ajenas de una en una perdía la
  primera, y ejecutar literalmente la orden impresa entraba en ping-pong (la
  vuelta 2 pedía A, la 3 volvía a pedir B).
- **Y la ruta que la parada nombra es la ruta de verdad.** El árbol se lee con
  `git status --porcelain -z` y las ramas con `git diff -z`, que ni
  entrecomillan ni escapan, y las rutas se guardan en arrays. Sin eso,
  `docs/handoff/año.md` llegaba a la parada como el literal
  `"docs/handoff/a\303\261o.md"` —ilegible justo cuando hay que leerlo— y
  viajaba así a la orden de relanzamiento, donde `--incluye` ya no lo reconocía:
  el operador copiaba la orden que el propio driver le había dado, el tren
  volvía a parar por la misma ruta y no convergía nunca. Una ruta con espacios
  se partía además en varias, y la orden salía mutilada
  (`--incluye nota --incluye de --incluye trabajo.md`). Ahora la orden se
  imprime lista para pegar: lo que el shell miraría va entrecomillado
  (`--incluye 'docs/handoff/nota de trabajo.md'`). Lo prueba
  `tests/train-rutas/selftest.sh`, que monta un paraguas de mentira, ensucia el
  árbol (o la rama) con rutas acentuadas, con espacios y con comillas, y exige
  que la orden que imprime la parada, **ejecutada literalmente**, termine en
  EXIT=0 con esas rutas en main.
- **Lo mismo, sobre lo ya commiteado, en los otros dos caminos.** El filtro
  mira el árbol sin commitear, así que no veía nada en los dos caminos que
  fusionan una rama que ya existe: la rama `chore/set-*` que se retoma y el PR
  de set que sigue abierto. Los dos empujaban/fusionaban la rama ENTERA sin
  mirar su diff: bastaba con que el propietario, arreglando la causa de una
  fusión roja, dejara un fichero suelto commiteado en esa rama para que main se
  llevara el re-pin y el `wip:` de un tirón. Ahora los dos pasan por la misma
  revisión (`git diff --name-only origin/main...<rama>` contra `RUTAS_REPIN`),
  con el mismo escape `--incluye` y la misma parada EXIT=2. En el PR abierto se
  revisa la rama recién traída de `origin`, que es la que puede haber crecido.
- **El índice se mira antes de crear la rama.** `git add -- <rutas>` no
  desapunta lo que el índice ya llevara y `git commit` commitea el índice
  entero, así que lo que se comprueba es lo que va a ENTRAR. Comprobarlo
  después del `git checkout -b` dejaba, al rechazar, media rama
  `chore/set-X.Y.Z` con el índice apuntado detrás: un estado que había que
  deshacer a mano. Ahora la parada es en `main` y sin rama creada, así que la
  orden de relanzamiento vale tal cual.

**Dónde está el re-pin no se lee del árbol.** Un árbol limpio no distingue
«fusionado» de «parado en el merge sobre su rama», y las dos cosas se ven
igual — que es justo el estado en que deja el camino de recuperación que esta
fase crea: si la fusión muere (check rojo, protección de rama), `HEAD` queda en
`chore/set-X.Y.Z`, el árbol limpio y el PR abierto. La fase pregunta a `origin`
y a GitHub, y actúa según la respuesta:

| Lo que dicen origin y GitHub | Lo que hace la fase |
| --- | --- |
| `origin/main` ya declara el set y no hay PR `chore/set-*` abierto | nada que abrir |
| hay un PR `chore/set-*` abierto (y es el de este set) | revisa lo que su rama lleva sobre `origin/main` y retoma **su** fusión; no abre otro |
| `HEAD` en una rama `chore/set-*` con el re-pin commiteado | exige que descienda de `origin/main`, revisa lo que lleva, y retoma esa rama: push, PR y fusión |
| nada de lo anterior, desde `main` al día | rama, commit, PR y fusión |

Y al terminar no se da el merge por hecho: exige que `origin/main` **declare**
la versión del manifiesto. Si no, para en seco antes del cierre — un cierre
sobre el set anterior lo certifica y lo anuncia a `quantum-app` como si fuera
el nuevo.

**Si GitHub no contesta, tampoco se sigue.** Un `gh pr list` que falla —503,
token caducado a mitad de tren, rate limit, corte de red— no es «no hay ningún
PR de set abierto»: las dos fases que preguntan (esta y la de cierre) paran en
seco con el error de `gh` delante. Leído como «ninguno», el guard del cierre
contestaba «todo en orden» sin haber podido preguntar y certificaba —y
anunciaba a `quantum-app`— el set ANTERIOR con el re-pin nuevo sin fusionar; y
aquí, esta fase abriría un SEGUNDO PR de set sobre el mismo re-pin. En
`--dry-run`, que no certifica nada, lo avisa y sigue.

Un corte deliberado con otro número: `bump-set.sh --set X.Y.Z`. Ojo al re-pin
que trae un guard nuevo de producto: la aserción anti-fósil pone la lane roja
hasta registrarlo (con fixture) o excluirlo con porqué.

### 5. Cierre (`train.sh --desde cierre --hasta cierre`)

Tras fusionar el PR de re-pin (lo fusiona la propia fase paraguas, con MERGE
COMMIT, que es el método del paraguas).

Antes de nada, **que el set que se certifica sea el del tren**: el
`git checkout main` del paso 1 abandona en silencio un re-pin que no llegó a
main, y a partir de ahí la fase leería del manifiesto de main el set ANTERIOR,
encontraría su tag ya cortado («voy directo a la certificación») y lo
re-certificaría y re-anunciaría a `quantum-app`. Así que antes de tocar la
rama: ningún PR `chore/set-*` abierto —preguntado a GitHub, y si GitHub no
contesta se para en vez de dar por buena la respuesta que no llegó—, y si el
manifiesto del que arranca la invocación declara otro set, su commit tiene que
estar en main (si no, para en seco) — y si ese manifiesto no se puede leer, la
respuesta que falta no desactiva el gate en silencio: se dice y se para (en
`--dry-run`, que no certifica nada, se avisa y se sigue). Encadenado desde la fase paraguas, además, la versión que lee en main
tiene que ser la que esa fase acaba de dejar fusionada. Y después:

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
5. El driver imprime el **reloj del tren** (desglose por fase, conducido y
   espera del propietario) y lo archiva como `reloj-vX.Y.Z.tsv`.
6. El CIERRE de ronda se escribe con la plantilla de `AUDITORIA_CONTINUA.md`
   §6 (conteos COPIADOS de las tablas de las lanes). (`docs/RUMBO.md` ya va
   actualizado en el PR de re-pin: sin eso, ese PR sale rojo.)

### El reloj del tren (cuánto cuesta conducir un set)

Hasta A3 nadie lo medía: «el tren tarda demasiado» era una impresión, y sin
número no hay recorte que se pueda defender. El driver se cronometra por fase
y guarda las marcas en `<git-common-dir>/quantum-train/reloj.tsv` — dentro de
`.git`, así que ni ensucia el árbol ni lo ve el guard de árbol limpio de la
certificación (QM8-5). `QUANTUM_TREN_RELOJ=<fichero>` lo mueve; `--dry-run`
usa un temporal y no deja rastro.

Como el tren se lanza varias veces (`--desde quark`, `--desde nucleus`…), el
reloj vive ENTRE invocaciones: TSV sin cabecera, una línea por fase ejecutada,
seis columnas separadas por tabulador.

```
1757370216	quark	1757370216	1757371160	944	manual
1757372100	quark	1757372100	1757372740	640	ok
```

| columna | qué es |
|---|---|
| `corrida` | epoch en que arrancó la invocación: agrupa las fases de una misma llamada y las cuenta. |
| `fase` | `preflight`, `quark`, `nucleus`, `orbit`, `paraguas`, `cierre`. |
| `inicio`, `fin` | epoch UNIX de entrada y de salida de la fase. |
| `segundos` | `fin - inicio`. |
| `resultado` | `ok` (la fase terminó), `manual` (parada de prosa, EXIT=2), `rojo` (parada en seco, EXIT=1), `interrumpido` (Ctrl-C u otra salida). |

La fase de cierre imprime el desglose y archiva el reloj como
`reloj-vX.Y.Z.tsv` (el tren siguiente empieza en cero y el anterior queda para
comparar). `train.sh --reloj` lo imprime en cualquier momento sin efectos;
`train.sh --reloj-cero` archiva el que hubiera en vuelo — y con `--dry-run`
imprime qué archivaría sin moverlo, porque el reloj de `--reloj-cero` es el
real y archivarlo es un efecto.

**Qué cuenta como CONDUCIDO**: la suma de las fases. Lo que el propietario
tarda ENTRE invocaciones —redactar las notes, revisar, dormir— es el hueco
entre el `fin` de una fase y el `inicio` de la siguiente: queda fuera por
construcción y se imprime aparte, para que el descuento sea explícito y no un
recorte silencioso. La espera de CI **sí** cuenta: el driver está bloqueado en
`gh pr checks --watch`, y descontarla daría un número bonito que no paga
nadie. El objetivo se compara con `QUANTUM_TREN_OBJETIVO_MIN` (30 por
defecto), y por encima el driver imprime un AVISO **y sigue**: el reloj mide,
no manda — en la fase de cierre el set ya está certificado y un cronómetro no
puede descertificarlo por haber tardado.

**El tren de 1.29.0, reconstruido — y lo que la reconstrucción NO es.** El
reloj no existía entonces, y lo que mide (tiempo conducido, invocación a
invocación) no lo registra nadie más: GitHub no sabe cuándo estaba corriendo
el driver. Lo que sí se reconstruye de los PRs y los tags es el ENVOLVENTE de
reloj de pared, del primer PR que abrió el driver al anuncio del set:

| momento | UTC | desde el anterior |
|---|---|---|
| quark#358 abierto (suelos: primer PR del driver) | 2026-09-07 22:43:36 | — |
| quark#358 fusionado | 22:49:52 | +6m16s |
| **quark v1.12.0** | 22:59:19 | +9m27s |
| nucleus#486 abierto (re-pin de los ejemplos) | 23:08:47 | +9m28s |
| nucleus#486 fusionado | 23:14:20 | +5m33s |
| nucleus#487 abierto (suelos) | 23:14:29 | +9s |
| nucleus#487 fusionado | 23:20:15 | +5m46s |
| nucleus#488 fusionado (el arreglo para que la rama del release siguiera verde) | 23:37:39 | +17m24s |
| **nucleus v1.25.0** | 23:47:51 | +10m12s |
| orbit#437 abierto (pines cruzados) | 23:54:00 | +6m09s |
| orbit#437 fusionado | 23:56:41 | +2m41s |
| **orbit v1.9.3** (orbit#438 fusionado) | 2026-09-08 00:02:41 | +6m00s |
| quantum#156 abierto (re-pin del paraguas) | 00:06:13 | +3m32s |
| quantum#156 fusionado | 00:11:51 | +5m38s |
| **quantum v1.29.0** (tag de suite) | 00:11:54 | +3s |
| quantum-app#15 (el anuncio del cierre) | 00:15:46 | +3m52s |

**1h32m10s** de punta a punta. Los huecos entre fases son de minutos —el mayor
es 9m28s, entre el tag de quark y el primer PR de nucleus—, así que aquel tren
fue conducción casi continua, y el reparto se ve a simple vista: lo que se
lleva el tiempo son las vueltas de CI de PRs que el driver abre y espera, no
la escritura humana. Tres veces el objetivo de 30 minutos. Pero es una
INFERENCIA sobre el envolvente, no la medida que el reloj hace: el primer dato
de verdad lo dará el tren siguiente.

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
- **release-please se auto-bloquea con un release PR de UNA sola release, la
  de la raíz** («untagged, merged release PRs outstanding» es el síntoma: PR
  merged con `autorelease: pending` y sin tag). Causa y arreglo en «Lo que
  aprendió el tren de 1.27.0»; mientras el arreglo de config no esté en los
  tres repos, `merge-bot-pr.sh` aplica `untag-recipe.sh` solo (tag por SHA +
  `gh release create` + relabel a `autorelease: tagged` — sin el relabel el
  siguiente corte vuelve a abortar).
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

Un `feat(x)!:` o un pie `BREAKING CHANGE:` en cualquier pilar propone un
MAJOR de ese pilar, y QADR-0002 (lockstep) lo arrastra a la suite entera. No
hay excepción y NO se corrige después con `Release-As` (ADR-032 de nucleus):
la decisión de que algo es incompatible se toma ANTES del merge, con el
título del squash. Un movimiento de EMPAQUETADO con error guiado (código que
se muda a un módulo y avisa con el `go get` exacto) es una MINOR con la
frase «packaging move with guided error» en el cuerpo, sin `!`. Si un `!`
se cuela por error, el remedio es revertir el commit antes del corte, no
maquillar el número. `Release-As` queda solo para el caso legítimo de
«arreglar sólo un módulo no corta el root» (más arriba).

### Lo que aprendió el tren de 1.29.0 (A2)

- **Un minor de quark deja rojo el CI de nucleus hasta re-pinar sus
  ejemplos.** `check_example_pins.sh` (lane Showcase Example Smoke) exige
  que `examples/*/go.mod` pinen el último tag de cada hermano con una minor
  de tolerancia: cortado quark v1.12.0, el showcase (quark v1.10.1) quedó a
  dos y el PR de suelos de nucleus (#485) no pudo fusionarse. `Repin
  Showcase` sólo corre tras las releases de nucleus, no de quark. Remedio:
  `bash scripts/release/repin_examples.sh` en nucleus (PR `chore(examples)`,
  nucleus#486) ANTES de su fase; desde este tren `sube_suelos` de nucleus
  lo hace en el mismo PR de suelos (segundo commit `chore(examples)`).
- **El proxy de Go va unos minutos por detrás del tag.** Recién cortados
  quark v1.12.0 y nucleus v1.25.0, el `go mod tidy` de `align_set.sh`
  murió con «sum.golang.org … 404 … unknown revision v1.25.0».
  `align-orbit-pins.sh` pregunta ahora a sum.golang.org (hasta 30 min) por
  los dos tags antes de escribir — `go list -m` no vale de sonda: contesta
  desde la caché o desde GitHub y la que muere es la verificación. La misma clase que el
  «INTERNAL_ERROR en tandas»: se espera, no se toca código.
- **El cuerpo del squash puede dejar a release-please ciego.** Con `gh pr
  merge --squash` sin `--body`, GitHub compone el cuerpo con la lista de
  commits del PR; si alguno lleva una línea «Docs: …» o «Tests: …», el parser
  de conventional commits la toma por pie de página y aborta: «commit could
  not be parsed». quark#355 (`feat`) desapareció del cálculo y el release PR
  se quedó en 1.11.1 con un minor en main. `merge-group.sh` fusiona ahora con
  `--subject` (el título del PR) y un cuerpo controlado (el del PR con esas
  líneas neutralizadas + el trailer). Si vuelve a pasar: un commit real
  mínimo que re-enuncie el `feat` con cuerpo limpio (quark#357).

### Lo que aprendió el tren de 1.28.0 (A1: quark, nucleus y orbit cortados el mismo día)

- **Los pines CRUZADOS de orbit no son suelos tolerados.** Si quark y nucleus
  se cortan en el mismo tren, la fase orbit corta con los `require` viejos y
  el manifest-guard §5 FALLA («undisclosed staleness»): sólo `declared_lags`
  lo excusa, y eso es deuda declarada, no alineación. Costó un segundo corte
  de orbit (v1.9.2, sin cambio de producto). Desde este tren la fase orbit
  corre `align-orbit-pins.sh --check` (los últimos tags de ../quark y
  ../nucleus contra los seis go.mod) y, si va atrás, `alinea_pines_orbit`:
  rama + `align_set.sh` de orbit + PR + merge-group + espera de Release
  Please — gemela de `sube_suelos`. El propio `align_set.sh` escribía el
  commit en español y el guard de títulos lo rechazaba: ya en inglés.
- **La deuda de doc de quark (RT-9) se paga sola.** `quark-doc-debt.sh` abre
  un worktree de la rama del bot, le mete `main` si no lo trae, corre
  `gen_release_notes_skeleton.sh` (sección del sitio, `RELEASE_NOTES`, línea
  marcada de CLAUDE.md y, desde 1.28.0, el puntero del README a las notas de
  la minor) y empuja. Sólo para si el esqueleto dejó `TODO`: la prosa no se
  delega. Dos causas de la vuelta perdida: la entrada de CLAUDE.md y el
  puntero del README eran manuales, y un `docs(release):` fusionado DESPUÉS
  de que el bot generase la rama NO la regenera (los docs no cambian el
  changelog), así que la rama no traía las notas de main y el guard local
  mentía hasta meterle `main`.
- **Un `docs(release):` que sube la marca de versión de orbit sin sección**:
  el release PR bumpa la línea «current release is vX.Y.Z» de las notas y
  `check_docs_version_claims.sh` exige la sección `## vX.Y.Z`. Una release
  de alineación (sin cambio de producto) también la necesita: tres líneas
  que lo digan, en la rama del release.
- **Los historiales pesan.** El handoff del paraguas llegó a 203 KB y 58
  sesiones y el arranque lo cargaba truncado; el CLAUDE.md de quark llevaba
  una línea de 16 KB. Régimen desde hoy: §3 = estado vigente + dos sesiones
  (guard `umbrella-handoff-size`, archivo en `docs/handoff/`); quark guarda
  tres entradas en CLAUDE.md y el resto en `.claude/HISTORIAL.md`.

### Lo que aprendió el tren de 1.27.0 (ADR-006 y la causa del auto-bloqueo)

- **El auto-bloqueo de release-please tiene causa, y no es aleatoria.** Las
  dos veces del 4 de septiembre (orbit#399 → v1.8.21, nucleus#466 → v1.23.2)
  el release PR llevaba UNA sola release: la de la raíz. El log lo dice:
  `PR component: undefined does not match configured component:
  github.com/jcsvwinston/orbit`. En release-please 17.x
  (`src/strategies/base.ts`, `buildRelease`) un PR con una sola release sin
  componente se trata como «standalone» y compara el componente de la rama
  —ninguno: con `separate-pull-requests: false` la rama es
  `release-please--branches--main`— con `getBranchComponent()`, que cae en el
  `package-name` de la raíz. No casan, TODAS las estrategias descartan el PR,
  no sale ningún tag, el PR se queda `autorelease: pending` y la corrida
  siguiente aborta. Con dos o más releases en el PR va por la otra rama del
  código y funciona — por eso la cascada de 1.26.2 y v1.9.0 etiquetaron solas.
  **Arreglo**: sin `package-name` en el paquete raíz de
  `release-please-config.json` (orbit#426, nucleus#467, quark#347); la
  estrategia `go` no lo usa para nada más y la raíz ya etiqueta sin
  componente, así que tags, nombres de release y changelog no cambian. La
  prueba en vivo es el siguiente corte de raíz sola. **Red mientras tanto**:
  `merge-bot-pr.sh` lee el log de la corrida del commit de merge y, si ve esa
  línea (o si la corrida termina sin etiquetar), aplica `untag-recipe.sh`.
- **`bump-set.sh` escribe ahora la parte del manifiesto que se rompía a
  mano**: versión de suite por QADR-0002 (calculada del salto real de los
  pilares), `released`, el comentario de `status`, las notes anteriores a
  `CHANGELOG.md` (DX-25) y un esqueleto de notes con los movimientos del set
  y marcadores `REDACTAR`. `manifest-guard` §0 rechaza el marcador (el driver
  lo tolera en local con `QUANTUM_ALLOW_NOTES_SKELETON=1`), así que un set no
  certifica con el esqueleto sin redactar. Ejecutarlo dos veces no sube dos
  veces la suite ni entierra un borrador: con esqueleto presente solo acepta
  `--set` para cambiar el número. El recorte a offset rancio que perdió
  `declared_lags` en 1.26.1 ya no tiene dónde ocurrir.
- **Los suelos de los módulos hermanos (QM-19) tienen escritor y momento**:
  `align-module-floors.sh <nucleus|quark>`, y corre **al principio de cada
  corte** (decisión de Carlos, 2026-09-05). El commit es `fix(deps)` (un
  `chore` deja módulos con cambios sin tag) y corta un patch de cada módulo
  tocado, así que va como primer commit de un corte que sale de todas
  formas, nunca como corte propio. El driver lo hace solo en la fase de cada
  repo: rama desde main, PR, fusión y espera de la corrida de «Release
  Please» que regenera el release PR con los módulos dentro.
- **`untag-recipe.sh` ya no hace checkout**: lee el manifest y el CHANGELOG
  con `git show <sha>:` y etiqueta por SHA, así que vale sobre el checkout
  hermano, sobre el submódulo pinado o sobre un clon temporal.

### Lo que aprendió el tren de 1.26.2 (dos días de cortes de orbit)

- **Módulo con cambios sin tag = raíz no certificable.** Los `chore(deps)` de
  Dependabot en `proto`/`agent`/`server`/`quarkdatasource` no cortan tag y
  `manifest-guard` §3b rechaza la raíz que los contiene. Liberarlos exige un
  commit `fix(deps)` que toque el módulo (con las notas del root en el mismo
  commit) y, si el módulo es `proto`, la cascada. Desde ADR-006 Dependabot
  usa `fix(deps)` en los módulos publicados e ignora `proto`.
- **La cascada de pines internos** (`proto` → `agent` → `server`) costó dos
  cortes por tren. ADR-006 quita la arista `server` → `agent` (los tests que
  arrancan un agente viven en `orbit/internal/fleettest`, módulo de solo
  test); la que queda (`agent`/`server` → `proto`) la converge
  `orbit-converge.sh` sin manos.
- **`go.work` del paraguas y módulos nuevos del pin.** Un módulo que aparece
  en un submódulo (p. ej. `orbit/internal/fleettest`) solo puede entrar en el
  `go.work` cuando el PIN lo contiene: antes, `go` no puede cargarlo. Regla:
  el `use` nuevo va en el PR de re-pin, no antes; `check_gowork_covers_manifest`
  lo reclama en ese momento.
- **El manifiesto también se rompe a mano.** `versions.yaml` de 1.26.1 perdió
  `declared_lags` por un recorte con offset rancio al redactar las notas.
  `manifest-guard` §0 exige ahora las diez claves de primer nivel; y las
  notas se escriben DESPUÉS de cualquier sustitución sobre el fichero.
- **`merge-bot-pr.sh` se lanza desde la raíz del paraguas**: con `cd` a un
  producto muere en silencio (ruta relativa).

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
