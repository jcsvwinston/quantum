# La escala de la re-auditoría — qué significa un 1, un 3 y un 5

[`criterios-5.csv`](criterios-5.csv) es la escala con la que se repite la
auditoría de madurez del 2026-09-03: **una fila por cada una de las 36
dimensiones que aquella puntuó** (quark 9, nucleus 10, orbit 10, suite 7),
con lo que significa un 1, un 3 y un 5 en cada una y con qué se mide hoy.
Hasta A12 `R0` la tabla del 5 vivía sólo en el artefacto del plan a 5/5 y los
niveles intermedios no estaban escritos en ninguna parte (QM-21). La usa
[`reauditoria/`](reauditoria/README.md), el método con el que A12 `R1` la
repite.

El guard `umbrella-audit-criteria` (`scripts/check_audit_criteria.sh`)
falla si falta o sobra una dimensión respecto a las que puntuaron los
informes, si la nota del 2026-09-03 de una fila no es la del informe, si una
fila deja sin escribir el listón, el 1, el 3 o el 5, o si su instrumento no
existe en el árbol.

## De dónde sale cada columna

| Columna | Qué es | De dónde sale |
|---|---|---|
| `pilar`, `dimension` | la clave de la fila | el nombre EXACTO de la tabla de notas de cada informe ([`madurez-2026-09-03/`](madurez-2026-09-03/README.md)); para quark, su línea «Notas de madurez». El guard lee la lista de ahí |
| `nota_2026_09_03` | la nota de entonces, con punto decimal | el mismo informe; ninguna re-auditoría se hizo entre medias (el plan preveía una ligera al cerrar A4 y otra al cerrar A8; no se corrieron) |
| `liston` | el producto que fija el listón en esa dimensión | §1 del plan a 5/5 («Qué significa 5 en cada dimensión») |
| `cinco` | el criterio verificable del 5 | §1 del plan a 5/5, copiado sin reescribir |
| `tres`, `uno` | qué es un 3 y qué un 1 | escritos en A12 `R0` a partir del «motivo en una línea» de cada informe y de su tabla comparativa: el 3 describe lo que un auditor vio en una dimensión que puntuó 3; el 1, la ausencia de lo que da el 3 |
| `arcos` | los arcos que dicen haber subido un escalón de esa dimensión | §0c del plan a 5/5 (el mapa del hoy al 5) |
| `instrumento` | con qué se mide hoy: rutas del árbol separadas por `;`, o `juicio` | el árbol al pin de 1.39.0; cada ruta existe y el guard lo comprueba |
| `notas` | qué parte del 5 cubre el instrumento, qué queda a juicio, y los instrumentos que llegan con el siguiente pin | — |

## Cómo se puntúa con ella

- **Medios puntos**, como en el 2026-09-03 (orbit puntuó 2,5, 3,5 y 1,5).
- **Un 5 exige el criterio del 5 ENTERO.** Un 4 es el 3 entero y una parte
  del 5; un 2, una parte del 3. El informe dice qué parte falta.
- **Donde hay instrumento, el instrumento manda**, y se CORRE: no se lee su
  página. Si cubre sólo una parte del 5, el informe dice cuál y lo demás es
  juicio, con lo que se miró para emitirlo.
- **`juicio` no es «sin evidencia»**: es una dimensión, o un trozo de ella,
  que ningún banco, guard ni lane mide hoy. La nota lleva igual fichero:línea
  o el comando que se ejecutó.

## Lo que no cambia, y lo que sí

- **Las 36 dimensiones y sus nombres no cambian en una re-auditoría.** Son lo
  que permite comparar con el 2026-09-03. Si `R1` cree que falta una —el
  rendimiento de nucleus o de orbit, por ejemplo, que hoy entran como
  hallazgos y como parte del 5 de otra dimensión—, la propone como decisión
  de Carlos; no la añade.
- **El `instrumento` sí cambia con el pin.** Sólo nombra rutas que existen
  en el árbol pinado. Al pin de 1.39.0 faltan cuatro que ya están escritas en
  `main` de su producto y que cada fila cita en `notas`:
  `quark/benchmarks/engines` (quark#431, A12 `Q1`),
  `quark/internal/extbench` (quark#422, A11), `nucleus/internal/catalogbench`
  (nucleus#587, A11) y la familia `extension` de `orbit/internal/adminbench`
  (orbit#531, A11). La sesión que audite sobre un pin que los contenga los
  mueve a `instrumento` en el mismo PR.
- **Comunidad** queda fuera del objetivo por decisión del propietario: se
  puntúa, y el gate de A12 la excluye.
