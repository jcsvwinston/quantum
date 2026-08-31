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

Multi-módulo desde v1.15.0: el release PR de `providers/ldap` (si lo hay) se
fusiona **antes** que el del root — manifest-guard §3b exige que el tag del
módulo sea ancestro del pin raíz, y un tag de módulo cortado DESPUÉS del de la
raíz no es certificable. Tras fusionar ldap, el PR del root puede quedar
**anclado al main viejo**: `check-anchored-release-branch.sh nucleus` antes de
fusionarlo (pasó en #391→#395).

### 3. orbit

Seis módulos con `separate-pull-requests` y manifest compartido. Orden:
hojas → dependientes → **ROOT EL ÚLTIMO** (`proto` → `agent` → bump del pin de
agent en server → `server` → `quarkbridge`/`quarkdatasource` → root). Trampas:

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
4. El CIERRE de ronda se escribe con la plantilla de `AUDITORIA_CONTINUA.md`
   §6 (conteos COPIADOS de las tablas de las lanes) y se actualiza
   `docs/RUMBO.md`.

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
- **PRs zombi** al cambiar la configuración de ramas de release-please (rama
  vieja sin componente + rama nueva): cerrar el de la rama vieja y borrar la
  rama.
