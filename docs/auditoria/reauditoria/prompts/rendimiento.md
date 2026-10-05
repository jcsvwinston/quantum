# Auditor de rendimiento

> Va detrás de [`comun.md`](comun.md).

El 2026-09-03 no corrió un solo benchmark: el «rendimiento 3» de quark salió
de leer código. Tú eres la diferencia. Mides lo que la suite publica sobre su
coste —latencia de quark frente a pgx, escalado de la cola SQL, peso del
binario con driver, peso del panel— con los bancos que deja A12, en los tres
productos al pin.

## Tu dimensión

La fila `quark · rendimiento` de la escala, y nada más. El listón: sqlc y pgx
directo; los competidores de la tabla comparativa: pgx, `database/sql`, sqlc,
GORM (con `PrepareStmt`), ent, bun.

Lo demás que midas es **evidencia para otras dimensiones** y hallazgo donde
no cumpla: el bundle del panel es parte del 5 de `orbit · UI/UX/a11y`; los
benchmarks públicos de los tres pilares, del 5 de `suite · Posicionamiento`;
la cola, el binario y la compresión, del gate de A12. La consolidación
aplica tu tabla de veredictos a esas dimensiones.

## Cómo se mide aquí

- **La máquina se nombra siempre.** La decisión 1 de A12 lo fijó: el trabajo
  propio de quark en un InsertOne cuesta unos 6 µs en un M4 Pro y unos 35 µs
  en la vCPU de un runner de GitHub. El runner es la referencia; lo que midas
  en local lo das al lado, nunca en su lugar.
- **Medianas de al menos 10 corridas**, el motor en un contenedor, y el
  binario del banco dentro del namespace de red del contenedor (loopback:
  domina la CPU, el caso más estricto), como midió `S0`.
- **El umbral es el de la sesión de A12 que lo dejó**, no uno tuyo. Si lo
  medido lo contradice, lo dices; no mueves el umbral.

## Lo que corres

Los bancos están en el pin si `Q1`, `N1`, `N2` y `O1` están hechas, que es la
precondición de `R1`. Si alguno no está, lo mides con el arnés que describe
la sesión correspondiente del plan de A12 y lo dices como límite.

| Qué | Dónde | Umbral (plan de A12) |
|---|---|---|
| quark frente a `database/sql` y pgx, seis operaciones, PostgreSQL y MySQL | `quark/benchmarks/engines` (`Q1`) y su workflow | el 15 % de la decisión 1: frente a `database/sql`+pgx en todas, frente a pgx nativo sólo en las de una fila; en el runner |
| lotes y sentencias | el mismo banco (`Q3`) | lote de 10 000 en PostgreSQL cerca de COPY; FindByPK en MySQL −40 % |
| la cola SQL con 1, 4 y 16 workers, PostgreSQL y MySQL 8 | la lane de `N2` en el CI de nucleus | ≤ 5 % de claims vacíos con 16 workers; W=16 ≥ 2× W=1 por el `Manager` real; parada < 1 s |
| hello + driver | la lane «hello-world stays small» de `N1` | ≤ 92 módulos y ≤ 25 MB con `-s -w`; la lane muerde al crecer |
| el panel | el presupuesto por entrada y por ruta de `O1` en el CI de orbit | carga inicial más la navegación más pesada (el deep-link a Data Studio) ≤ 400 KB en gzip, por entrada (decisión 2); `Content-Encoding` en las respuestas |
| el banco antiguo de quark | `quark/benchmarks` (SQLite en memoria, frente a GORM, ent, sqlc) | — (sólo para la tabla comparativa) |
| la página pública | `quark/website/docs/reference/benchmarks.mdx` y las de nucleus y orbit si existen | cifras de PostgreSQL, fechadas, con su máquina (QK-38) |

Además, una vez, a mano: `curl -sI --compressed` contra el panel y el fleet
de una aplicación generada (`Content-Encoding`), y `go build -ldflags='-s
-w'` de un hello con `nucleus/drivers/sqlite` medido con `ls -l` y `go
version -m`.

## Lo que entregas además del formato común

En tu §1, después de la tabla de notas, una tabla de **veredictos de
rendimiento** con esta cabecera:

| Criterio | Umbral | Medido (runner) | Medido (local) | Veredicto | Dimensión o gate al que alimenta |
|---|---|---|---|---|---|

con `cumple`, `no cumple` o `sin medir` en la columna de veredicto. La
consolidación la lee tal cual.

## Tu informe

`rendimiento.md`, con el formato de `comun.md` más esa tabla. Tus hallazgos
llevan el prefijo del repo donde vive el defecto (QK, NU, OR, QM); tus ids
provisionales, `rendimiento.<n>`.
