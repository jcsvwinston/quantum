# La re-auditoría — el método, para repetirla sin reconstruir nada

Este directorio es el **brief** con el que A12 `R1` repite la auditoría de
madurez del 2026-09-03 (y con el que `R2` hace la confirmación ligera sobre el
2.0). Lo escribió A12 `R0` porque aquella no se podía repetir tal cual
(QM-21): los prompts de los auditores no se guardaron, la tabla de qué
significa un 5 vivía en un artefacto, el «rendimiento 3» salió de leer código
y lo que se auditó entonces (`examples/`) ya no existe.

Lo que hay aquí:

| Fichero | Para quién | Qué es |
|---|---|---|
| este README | quien dirige `R1` | qué se audita, quién, en qué orden, qué sale y cómo se consolida |
| [`prompts/comun.md`](prompts/comun.md) | todos los auditores | las reglas comunes: lectura de código, ejecución, severidades, formato del informe, ids, límites |
| [`prompts/quark.md`](prompts/quark.md) … [`prompts/rendimiento.md`](prompts/rendimiento.md) | cada auditor | su alcance, sus dimensiones, sus instrumentos y lo que tiene que verificar |
| [`prompts/adversarial.md`](prompts/adversarial.md) | los revisores | la pasada que intenta tumbar cada nota y cada hallazgo |
| [`prompts/consolidacion.md`](prompts/consolidacion.md) | quien consolida | del informe al registro, las notas en CSV y los guards |

La escala con la que se puntúa es [`../criterios-5.csv`](../criterios-5.csv)
(explicada en [`../criterios-5.md`](../criterios-5.md)); los hallazgos van al
mismo [`../madurez-2026-09-03/registro.csv`](../madurez-2026-09-03/registro.csv)
que lleva el plan desde el 2026-09-03. Los resultados de cada re-auditoría van
a un directorio con su fecha, `docs/auditoria/reauditoria/<AAAA-MM-DD>/`, que
los dos guards ya leen.

## 1. Qué se audita, y cuándo

- **El último set 1.x certificado**, desde el paraguas y con los submódulos
  AL PIN: `bash scripts/estado.sh` tiene que decir `ok` en los tres. No los
  checkouts hermanos (`~/GolandProjects/{quark,nucleus,orbit}`): esos van por
  `main` y lo que se mide ahí no es el set.
- **Más la lista cerrada del major** que deja `M0`: lo que el 2.0 retira y
  voltea se audita como intención —¿está entero, tiene aviso, tiene guía?—,
  no como código que todavía no existe.
- **Cuándo**: con `Q*`, `N*`, `O1`, `R0` y `M0` hechas (la precondición de
  `R1` en [`../../planes/A12-rendimiento-reauditoria-cierre.md`](../../planes/A12-rendimiento-reauditoria-cierre.md)).
  Va ANTES del major (decisión 3 de A12): lo rompiente que encuentre todavía
  entra en `M1` en vez de forzar un 3.0.
- **`R2`** repite sólo los bancos, los guards y las dimensiones que `M1`
  tocó, con el mismo método y los mismos prompts.

La línea base es la nota del 2026-09-03 que lleva cada fila de la escala.
Ninguna re-auditoría se hizo entre medias: el plan preveía una ligera al
cerrar A4 y otra al cerrar A8, y no se corrieron.

## 2. El equipo

Siete auditores **en paralelo**, cada uno con `prompts/comun.md` más su
prompt, y cada dimensión con **un solo dueño** que la puntúa. Lo que un
auditor vea de una dimensión que no es suya lo deja en su informe como
hallazgo, y la consolidación lo aplica (§4).

| Auditor | Prompt | Alcance | Puntúa |
|---|---|---|---|
| quark | [`quark.md`](prompts/quark.md) | `quark/` al pin, sus módulos de driver y su CLI | 8 de quark: todas salvo rendimiento |
| nucleus | [`nucleus.md`](prompts/nucleus.md) | `nucleus/` al pin y sus módulos hermanos | las 10 de nucleus |
| orbit | [`orbit.md`](prompts/orbit.md) | el panel in-process: `orbit/` raíz, `internal/admin`, `datasource`, `quarkbridge`, `quarkdatasource` | 8 de orbit: todas salvo Fleet y UI/UX/a11y |
| orbit-fleet | [`orbit-fleet.md`](prompts/orbit-fleet.md) | el plano fleet: `proto`, `agent`, `server`, `internal/fleettest` y la entrada fleet de la SPA | Fleet |
| orbit-ui | [`orbit-ui.md`](prompts/orbit-ui.md) | la SPA `orbit/ui`, sus dos entradas, y el instrumento de navegador | UI/UX/a11y |
| suite | [`suite.md`](prompts/suite.md) | el paraguas: README, sitio, quickstart, tutoriales, tren, gobernanza, coherencia | las 7 de la suite |
| rendimiento | [`rendimiento.md`](prompts/rendimiento.md) | los bancos de A12 en los tres productos | Quark · rendimiento |

Es el reparto del 2026-09-03 —cuatro auditores más dos sub-auditorías de
orbit, la SPA y el fleet— con dos cambios: el auditor de rendimiento es
nuevo, y las dos sub-auditorías puntúan su dimensión en vez de alimentar la
nota de otro, porque así pueden correr a la vez sin esperarse.

Después, **la pasada adversarial** ([`adversarial.md`](prompts/adversarial.md)):
un revisor por informe, que no es su autor, re-ejecuta lo que el informe dice
haber ejecutado e intenta tumbar cada 5, cada ausente y cada P0/P1. Y al
final **la consolidación** ([`consolidacion.md`](prompts/consolidacion.md)),
una sola, que es la única que escribe en el repo.

Cada auditor trabaja en su propio directorio de scratch (`mktemp -d`, nunca
la raíz de `$TMPDIR`) y **no edita ningún repo**: entrega su informe como un
fichero en su scratch y lo devuelve.

## 3. Lo que el 2026-09-03 no pudo hacer, y cómo lo hace `R1`

| Límite de entonces | Qué costó | Cómo lo hace `R1` |
|---|---|---|
| Sin Docker ni motores externos: las 47 suites de motor de quark y las lanes de motor de nucleus «quedan para el CI» | multi-tenant, migraciones y tipos se puntuaron sobre SQLite y leyendo | Docker está disponible en la máquina de trabajo (A12 `S0` y `Q1` midieron sobre PostgreSQL 16 y MySQL reales). Cada auditor corre la lane de motor como la corre el CI de su producto, o lee la corrida verde del CI al commit del pin (`gh run list -R jcsvwinston/<repo> --commit <sha>`), y **dice cuál de las dos** |
| Sin un solo benchmark | «rendimiento 3» salió de leer código | un auditor de rendimiento dedicado con los bancos que deja A12: quark frente a pgx y `database/sql` sobre PostgreSQL y MySQL (`Q1`), la cola SQL con 1 a 16 workers (`N2`), el binario con driver (`N1`), el panel comprimido (`O1`) |
| `shellcheck` no estaba instalado | los scripts del paraguas sin lint | está instalado en la máquina de trabajo (`command -v shellcheck`); el auditor de la suite lo corre sobre `scripts/` y `tests/`, y lo que no pase es hallazgo P3. Si falta, lo dice como límite |
| Se auditó `examples/`: el ejemplo canónico de nucleus, el showcase, el ejemplo mínimo de orbit | tres P0 salieron de ahí | `examples/` no existe desde el 2026-09-12 y **no se repone hasta 5/5** (decisión del propietario). Lo sustituyen el starter de `nucleus new --template suite` (lane quickstart-smoke), los tres tutoriales del sitio (lane tutorials-smoke), el arnés `quark/acceptance` y los bancos de A6 y A9, que montan orbit en una aplicación real. Proponer reponer un ejemplo no es un hallazgo |
| Los prompts no se guardaron | repetirla era reconstruirla | `prompts/`. Si `R1` cambia un prompt, lo cambia AQUÍ, en el mismo PR, y lo dice en el informe |
| La escala vivía en un artefacto y sólo decía qué es un 5 | dos auditores podían leer distinto un 3 | [`../criterios-5.csv`](../criterios-5.csv), con el 1, el 3 y el 5 de cada dimensión y su guard |
| Las notas eran juicio experto, no una métrica | — | donde la escala nombra un instrumento, se corre y manda; donde dice `juicio`, el informe dice qué se miró |
| Se auditaron los checkouts de trabajo de cada producto | — | se audita el paraguas con los submódulos al pin. Los checkouts hermanos (`~/GolandProjects/<producto>`) van por `main` y pueden llevar trabajo de después del corte: lo que se mide ahí no es el set |
| Un id salió dos veces (NU-50) y nada lo vio | un hallazgo contado por otro | `umbrella-audit-backlog` falla ante un id repetido, en el registro o en los informes, y ante una fila de defecto sin id válido |
| Sin internet para comparar con el listón | — | igual: la comparación con el listón se hace con lo que el auditor sabe del producto de referencia, y lo dice. Si consulta documentación pública, cita la URL y la fecha |

## 4. Cómo se consolida (resumen; el detalle en `consolidacion.md`)

1. **Ids definitivos.** Los auditores numeran sus hallazgos con ids
   provisionales (`quark.1`, `orbit-ui.4`…) porque varios comparten prefijo
   y corren a la vez. La consolidación les da el siguiente id libre de su
   prefijo (QK, NU, OR, QM, por el repo donde vive el defecto) en todos los
   ficheros del directorio. Un id provisional olvidado hace fallar
   `umbrella-audit-backlog`.
2. **Una fila de `registro.csv` por hallazgo**, con `informe` =
   `reauditoria/<fecha>/<fichero>.md`, `arco` = `A12` y `estado` = `abierto`.
   `R2` reasigna por escrito a `A13` lo que A12 no cierre (el guard ya acepta
   A13+).
3. **`notas.csv`**: `pilar,dimension,nota,evidencia`, las 36 dimensiones con
   los nombres exactos de la escala. `umbrella-audit-criteria` exige las 36,
   en medios puntos y con evidencia.
4. **Lo que la pasada adversarial cambió se aplica**, y una dimensión no
   queda en 5 si un hallazgo P0 o P1 confirmado de CUALQUIER informe cae en
   ella, o si el auditor de rendimiento declara incumplido un criterio de
   rendimiento que su 5 incluye.
5. **El veredicto del gate de A12**: 5 en todas salvo comunidad, o la lista
   de lo que falta, que `R2` convierte en A13.

## 5. Arranque de `R1`, en comandos

```bash
bash scripts/estado.sh                        # set, arcos; submódulos «ok», sin DERIVADO
bash scripts/check_audit_criteria.sh          # la escala, completa y con instrumentos al pin
bash scripts/check_audit_backlog.sh           # el registro, sin repetidos
F=$(date +%F); mkdir -p docs/auditoria/reauditoria/$F
git -C quark rev-parse HEAD; git -C nucleus rev-parse HEAD; git -C orbit rev-parse HEAD   # los commits que se auditan
```

Si el pin ya contiene los instrumentos que la escala cita en `notas` como
«entra con el siguiente pin», primero se mueven a `instrumento` (el guard
comprueba que existan) y después se lanza el equipo.

Se lanzan los siete auditores a la vez, cada uno con el texto de
`prompts/comun.md` seguido del de su prompt, el set y los tres commits. Cuando
vuelvan los siete, los revisores adversariales; cuando vuelvan, la
consolidación.
