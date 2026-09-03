# Contribuir al paraguas

Gracias por leer esto antes de abrir un PR. Este repo **coordina, no
contiene** ([QADR-0001](docs/adr/QADR-0001-multirepo-paraguas.md)): el código
de los productos vive en [nucleus](https://github.com/jcsvwinston/nucleus),
[quark](https://github.com/jcsvwinston/quark) y
[orbit](https://github.com/jcsvwinston/orbit), cada uno con su propio
CONTRIBUTING. Aquí se cambia lo que es de la suite: el manifiesto, el sitio
unificado, los guards de certificación y el tren de releases.

## Idioma

- **Este repo se escribe en español**: README, docs internos, commits, PRs,
  comentarios de scripts.
- **El sitio (`website/`) se escribe en inglés**, como las docs de los tres
  productos ([QADR-0007](docs/adr/QADR-0007-idioma-del-paraguas.md)), y sigue
  la [guía de estilo de documentación de usuario](docs/ESTILO_DOCS.md).

## Antes de tocar nada

```bash
git clone --recurse-submodules https://github.com/jcsvwinston/quantum.git
cd quantum
go build $(bash scripts/gowork-patterns.sh)   # el set fijado compila junto
```

Los submódulos deben quedarse en el pin que `versions.yaml` declara. **No
muevas un gitlink en un PR normal**: el re-pin es parte del tren de releases
(abajo) y lo verifica `manifest-guard`.

## Qué tipo de cambio es el tuyo

| Cambias… | Reglas |
|---|---|
| Docs del sitio (`website/docs/`, portada, config) | Inglés, guía de estilo, `cd website && npm ci && npm run build`, y los guards sobre lo servido: `check_built_links.sh`, `check_built_codeblocks.sh`, `check_served_jargon.sh`, `check_retired_claims.sh` (todos con `website/build`). Las docs de un producto se cambian **en su repo**: el sitio las ensambla ([QADR-0003](docs/adr/QADR-0003-docs-sitio-unico-fuente-en-repos.md)). |
| Un script de `scripts/` | `bash -n`, y si es un **guard** (tiene veredicto sobre el árbol), la regla dura de abajo. |
| `versions.yaml`, submódulos, README (tablas de versiones) | Solo dentro del tren de releases. `bash scripts/manifest-guard.sh` es el juez. |
| `docs/RUMBO.md` | Su cabecera «Estado real» debe decir el set del manifiesto (`scripts/check_rumbo_estado.sh`). |
| `go.work` | Debe cubrir todo módulo publicable (`scripts/check_gowork_covers_manifest.sh`); los patrones de build salen de él (`scripts/gowork-patterns.sh`). |

## Regla dura: un guard nuevo trae fixture

Un **guard** es un script con veredicto sobre el árbol (EXIT≠0 cuando algo
está mal). Todo guard nuevo:

1. se registra en [`scripts/lib/guard-registry.sh`](scripts/lib/guard-registry.sh)
   (nombre, cwd, comando exacto),
2. recibe una fixture en `tests/guard-fixtures/<nombre>/fixture.sh` que
   prepara una copia rota del árbol mínimo y declara `expect=` con la causa
   de muerte,
3. y `bash scripts/guard-of-guards.sh` sigue en verde: prueba que cada guard
   registrado **muerde** sobre su fixture, y que no hay guards sin fixture ni
   fixtures huérfanas.

Un script de `scripts/` que NO es guard (genera texto, escribe, orquesta) se
añade a `GUARD_SCAN_EXCLUDE` con su porqué; sin porqué, la aserción anti-fósil
pone la lane roja. Detalle y semántica en
[`docs/AUDITORIA_CONTINUA.md`](docs/AUDITORIA_CONTINUA.md).

## El tren de releases

Cortar un set certificado es un procedimiento con orden de dependencias
(quark → nucleus → orbit → re-pin del paraguas → tag → anuncio a
`quantum-app`) y varias trampas conocidas. Está scriptado y documentado en
[`scripts/train/README.md`](scripts/train/README.md); no lo improvises. Un
PR de re-pin debe salir verde en `suite-integral` **sin escapes**.

## Commits y PRs

- [Conventional Commits](https://www.conventionalcommits.org/) en español:
  `fix(guard): …`, `docs(tren): …`, `chore(set): …`. Un `!` (ruptura) en un
  pilar arrastra el major de toda la suite
  ([QADR-0002](docs/adr/QADR-0002-versionado-dos-niveles.md)); no lo pongas
  por un cambio de empaquetado.
- Sin superlativos de marketing en commits, README ni docs; describe lo que
  hace y su coste.
- Trabaja en rama y abre PR contra `main` con la plantilla; `main` está
  protegido y los PRs se fusionan con merge commit.
- Antes de pedir revisión: `bash scripts/manifest-guard.sh`,
  `bash scripts/guard-of-guards.sh` (si tocaste guards o fixtures) y el build
  del sitio (si tocaste `website/`).

## Reportar problemas

Usa las [plantillas de issue](.github/ISSUE_TEMPLATE/). Un defecto en el
código de un producto se reporta **en el repo del producto**; aquí van los del
set (no compila junto, el manifiesto miente, el sitio sirve algo roto) y los
del tren. Las vulnerabilidades, por el canal privado de
[SECURITY.md](SECURITY.md), nunca como issue.
