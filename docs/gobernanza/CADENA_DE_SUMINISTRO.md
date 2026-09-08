# Cadena de suministro de la suite: qué se publica, cómo se firma y qué lo vigila

> Estado del arco **A3** al 2026-09-09, sobre el set vigente **Quantum
> 1.29.0**. El [§5](#5-lo-que-sólo-puede-tocar-el-propietario) es lo único que
> necesita una decisión.
>
> Relacionados: hallazgo **QM-14** del registro de la auditoría de madurez
> (`docs/auditoria/madurez-2026-09-03/registro.csv`),
> [`POLITICA_SOPORTE.md`](POLITICA_SOPORTE.md) y
> [`POLITICA_DEPRECACION.md`](POLITICA_DEPRECACION.md).

## 1. Qué publica cada producto, y con qué

QM-14 decía que la suite publicaba binarios sin nada que permitiera
comprobar de dónde salían: nucleus era el único repo con GoReleaser y su
config no tenía bloque `sboms:` ni `signs:`. El arco A3 lo cierra repo a
repo. Estado medido en `main` de cada producto:

| | quark | nucleus | orbit |
|---|---|---|---|
| Config de GoReleaser | sí | sí | en orbit#445 |
| Bloque `sboms:` | sí | sí | en orbit#445 |
| Bloque `signs:` (cosign sin clave) | sí | sí | en orbit#445 |
| Atestación de procedencia en el release | sí | sí | en orbit#445 |
| CodeQL | sí (setup por defecto) | sí (workflow) | sí (workflow) |
| OpenSSF Scorecard | sí | sí | sí |
| Actions fijadas por SHA, con guard | sí | en nucleus#499 | no |

Lo que no cambia con esto: los módulos que son **librería** no publican
binario. Llegan por el proxy de Go, donde la base de datos de sumas es la
garantía equivalente, y ahí no hay nada que firmar.

## 2. La primera medición de Scorecard

Los tres workflows se lanzaron a mano el 2026-09-08 (`workflow_dispatch`;
ninguno había corrido todavía, porque los tres se fusionaron después de su
franja semanal). Las tres corridas terminaron en verde.

| Repo | Hallazgos en el SARIF | Cuál |
|---|---|---|
| quark | 1 | `Branch-Protection`, puntuación 0 |
| nucleus | 0 | — |
| orbit | 1 | `Branch-Protection`, puntuación 0 |

**Lo que esta medición NO da, y hay que decirlo:** la nota agregada. El
workflow pide `results_format: sarif`, y el SARIF lleva los checks que
suspenden, no el total. Leer la nota exige una segunda salida en `json`, y
sin nota no hay umbral que fijar — así que el §5 no propone ninguno. Es la
misma frase que el comentario de cabecera de los tres workflows ya trae:
primero se lee la nota, después se decide qué exigir. Queda como el trabajo
siguiente de este frente.

El único hallazgo es además el que ya sabíamos, y lo confirma desde fuera.

## 3. Protección de rama: lo medido

`gh api repos/jcsvwinston/<repo>/branches/main/protection`, el 2026-09-09:

| Repo | `main` protegida | Checks exigidos | Revisión de PR | Aplica a admins |
|---|---|---|---|---|
| quantum | **no** | — | — | — |
| quark | **no** | — | — | — |
| nucleus | sí | `CI Required Gate` | sí | sí |
| orbit | **no** | — | — | — |

Tres de los cuatro repositorios aceptan hoy un push directo a `main`. La
disciplina que los mantiene sanos es de proceso, no de máquina.

El arco deja la mitad mecánica lista: **cada producto tiene ya un agregador
de un solo nombre**, para que la regla de protección no sea una lista que
caduca cada vez que se añade un lane.

| Repo | Nombre exacto a exigir | De dónde sale |
|---|---|---|
| nucleus | `CI Required Gate` | ya exigido |
| quark | `CI Required Gate` | quark#372 |
| orbit | `CI Required Gate` | orbit#446 |

**Dos avisos que van con la regla, no después:**

1. **En quark, CodeQL no cabe en el agregador.** Corre por el *setup por
   defecto* de code scanning, no por un workflow del repo, así que pone
   `Analyze (actions)`, `Analyze (go)` y `Analyze (javascript-typescript)` en
   cada PR y `needs:` no puede alcanzarlos. Si se quieren obligatorios, van
   en la regla junto al agregador — con el mismo problema de caducidad, porque
   ese conjunto de nombres cambia con los lenguajes detectados.
2. **En orbit, el lane `internal-pins` está rojo por diseño** en la ventana
   entre cortar un tag hermano y subir los pines. El día que la puerta sea
   obligatoria, esa ventana bloquea **todos** los PRs abiertos, no sólo el de
   alineación. El remedio es cerrar la ventana en `main`, no aflojar el
   guard.

## 4. Qué vigila el árbol, y qué no

Dos guards nuevos del paraguas, los dos **escritos y verificados, todavía sin
registrar**: al pin de 1.29.0 fallan porque lo que comprueban entró en los
productos después del corte. Se registran en el PR de set que mueva los
gitlinks; la entrada exacta y las fixtures están en
`docs/handoff/deuda-registro-guards-a3.md`.

- **`umbrella-supply-chain`** (`scripts/check_supply_chain.sh`) — los tres
  productos siguen declarando `sboms:`, `signs:`, el paso de atestación y los
  dos permisos que esos pasos necesitan (`id-token: write`,
  `attestations: write`). Se comprueba en el árbol y no en la corrida por una
  razón concreta: **un release sin firma sale verde**. Borrar cuatro líneas de
  YAML no rompe nada hasta que alguien intenta verificar un binario.
- **`umbrella-deprecations`** (`scripts/check_deprecations.sh`) — descrito en
  [`POLITICA_DEPRECACION.md`](POLITICA_DEPRECACION.md) §5.

Y uno por repo para los pines de Actions: quark ya lo tiene registrado como
deuda del set (`docs/handoff/deuda-registro-quark-action-pins.md`), nucleus
lo trae en nucleus#499, orbit no lo tiene todavía.

**Lo que ningún guard cubre hoy**, dicho para que no se confunda con estar
cubierto:

- que la firma **verifique de verdad** contra la identidad esperada. Eso sólo
  se sabe corriendo `cosign verify-blob` contra un artefacto publicado, y
  el primer artefacto firmado sale en el próximo corte;
- la nota de Scorecard, por el §2;
- que las Actions de orbit estén fijadas por SHA.

## 5. Lo que sólo puede tocar el propietario

Nada de esto se puede hacer desde un PR: son ajustes del repositorio.

| id | Qué | Dónde | Por qué ahora |
|---|---|---|---|
| **C1** | Proteger `main` en **quark** exigiendo `CI Required Gate` | Settings → Branches | Es el hallazgo de Scorecard y el único que salió. El nombre ya existe: lo produjo la corrida de quark#372 |
| **C2** | Ídem en **orbit** | Settings → Branches | El nombre ya existe: corrida de orbit#446. Leer antes el aviso 2 del §3 |
| **C3** | Ídem en **quantum** (paraguas), exigiendo la lane de certificación | Settings → Branches | El paraguas es el que fija el set; hoy admite push directo |
| **C4** | Activar `allow_auto_merge` en los cuatro repos | Settings → General | Sin esto el tren fusiona a mano cada PR del bot |
| **C5** | Decidir si el agregador se exige **también** con los tres `Analyze (…)` de quark | Settings → Branches | Ver aviso 1 del §3 |

Referencia útil que ya existe en el árbol:
`nucleus/scripts/ci/configure_branch_protection.sh` hace por API lo que C1–C3
pide, y es el que dejó nucleus como está. Necesita permisos de admin, así que
lo ejecuta el propietario.
