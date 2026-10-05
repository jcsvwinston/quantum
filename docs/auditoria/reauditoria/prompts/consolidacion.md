# Consolidación

> La hace una sola sesión, la que dirige `R1`, con los siete informes y las
> siete revisiones en la mano. Es la única que escribe en el repo.

## 1. El directorio

```bash
F=<fecha de R1, AAAA-MM-DD>
D=docs/auditoria/reauditoria/$F
mkdir -p $D
```

Dentro van, y nada más:

- los siete informes, con su nombre: `quark.md`, `nucleus.md`, `orbit.md`,
  `orbit-fleet.md`, `orbit-ui.md`, `suite.md`, `rendimiento.md`;
- `adversarial.md`, las siete revisiones una detrás de otra;
- `notas.csv`;
- `README.md`: el veredicto (§6).

Los dos guards leen este directorio: `umbrella-audit-backlog` toma como
hallazgo **toda fila de tabla de cualquier `.md` de aquí cuya segunda celda
sea una severidad** (`P0`…`P3`), y `umbrella-audit-criteria` valida
`notas.csv`. Por eso el README y `adversarial.md` no llevan filas de esa
forma: si un resumen nombra los P0, los nombra en prosa o en una tabla cuya
segunda columna no sea la severidad. Repetir la fila de un hallazgo en el
README es un id repetido y el guard falla.

## 2. Lo que dice la revisión, aplicado

- **Notas.** Si el revisor reprodujo su evidencia, manda la suya. Si los dos
  la sostienen y no coinciden, la más baja, y el README dice por qué.
- **Hallazgos refutados** salen de la tabla de defectos del informe y pasan
  a una sección «Refutados en la revisión», en prosa. Los de severidad
  cambiada cambian en la tabla. Los nuevos del revisor entran en la tabla del
  informe del dueño de su dimensión.
- **Duplicados**: una sola fila, en el informe del dueño de la dimensión; el
  otro informe lo cita en prosa.
- **Ningún 5 con un P0 o P1 confirmado dentro**, venga del informe que
  venga: esa dimensión queda en 4 como mucho, y el README lo dice.
- **La tabla de veredictos de rendimiento**: una dimensión cuyo 5 incluye un
  criterio que el auditor de rendimiento declara `no cumple` (el bundle del
  panel en `orbit · UI/UX/a11y`, los benchmarks públicos en `suite ·
  Posicionamiento`) no queda en 5.

## 3. Los ids definitivos

Los informes llegan con ids provisionales (`quark.3`). Cada hallazgo toma el
prefijo del repo donde vive el defecto —QK quark, NU nucleus, OR orbit, QM el
paraguas— y el siguiente número libre del registro, en el orden de los
informes de §1 y, dentro de cada uno, de P0 a P3:

```bash
reg=docs/auditoria/madurez-2026-09-03/registro.csv
siguiente() { awk -F, -v p="$1" 'index($1, p "-") == 1 { n = substr($1, length(p) + 2) + 0; if (n > m) m = n } END { print p "-" m + 1 }' "$reg"; }
siguiente QK; siguiente NU; siguiente OR; siguiente QM
```

El cambio de provisional a definitivo se hace en TODOS los ficheros de `$D`
(los informes citan ids de otros, y la revisión los nombra todos). Un id
provisional que quede hace fallar `umbrella-audit-backlog` («fila de defecto
sin id válido»).

## 4. El registro

Una fila por hallazgo en `docs/auditoria/madurez-2026-09-03/registro.csv`,
con la forma de las que dejó A12 `S0`:

```
<id>,<sev>,<quark|nucleus|orbit|quantum>,A12,abierto,"nacido en A12 R1: <qué pasa, en una frase>",reauditoria/<F>/<informe>.md,<fichero:línea>
```

Todo lo que `R1` abre va a **A12**: el arco no se cierra con hallazgos suyos
abiertos, y `R2` reasigna por escrito a **A13** lo que quede (el guard ya lo
acepta). Lo rompiente se marca en la evidencia como «va al major» y entra en
la lista de `M1`. Un P0 no espera a `R2`: se nombra en el informe de la sesión
para que se arregle ya.

Un hallazgo `hecho` que la re-auditoría encuentra roto no se reabre: es un
hallazgo nuevo que lo cita.

## 5. Las notas

`$D/notas.csv`, las 36 dimensiones con los nombres EXACTOS de
`docs/auditoria/criterios-5.csv`:

```
pilar,dimension,nota,evidencia
quark,API/query,<nota>,"<instrumento corrido y su resultado, o lo que se miró>"
…
```

Medios puntos con punto decimal (`3.5`). `umbrella-audit-criteria` exige las
36, sin una de más, en la escala y con evidencia. En `R2`, que sólo re-puntúa
lo que `M1` tocó, `notas.csv` lleva igual las 36: las que no se re-puntuaron
copian la nota de `R1` con la evidencia «sin cambios desde <F de R1>: M1 no
la tocó».

## 6. El README del directorio

- **Veredicto**, en un párrafo.
- **Notas**: `Pilar | Dimensión | 2026-09-03 | <F> | Dueño`, las 36, y la
  media por pilar.
- **El gate de A12**: qué dimensiones, salvo comunidad, no están en 5 y qué
  les falta, en una línea cada una. Es la lista que `R2` convierte en A13 si
  sigue en pie.
- **Método**: un enlace a este brief, qué prompts se cambiaron en este PR y
  por qué, los commits auditados.
- **Límites**: los de los §6 de los informes, juntos.

## 7. Antes de abrir el PR

```bash
bash scripts/check_audit_backlog.sh
bash scripts/check_audit_criteria.sh
bash scripts/guard-of-guards.sh
```

Y las tres escrituras del contrato de sesión (`docs/planes/README.md` §4):
la fila de `R1` en el plan de A12 con el PR y lo medido, `docs/RUMBO.md` si
cambió lo que afirma, y el handoff si algo quedó a medias. Título del PR en
español y sin `!`: `docs(auditoria): re-auditoría del <F> sobre Quantum <set> — …`.
