# Sesión 2026-09-19 — A7 cerrado, y el tren de Quantum 1.34.0

> Archivado desde el §3 de `.claude/commands/next-session.md` el 2026-09-21,
> al entrar la sesión de A9 `S0`. Historia para buscar con grep, no para cargar.

### Sesión 2026-09-19 — **A7 CERRADO**: de 12 a 40 de 40, y un tren que encontró nueve defectos que el banco no vio

- **El tren, y lo que costó.** Diecisiete PRs de nucleus (los nueve del arco
  apilados, siete de corrección y el de suelos), nucleus **v1.30.0** con sus
  doce tags de módulo, orbit **v1.10.2** con cuatro, y el set **Quantum
  1.34.0**. La pila no se podía fusionar con squash tal cual: el squash de cada
  PR tiene el MISMO diff que el commit que la rama siguiente todavía lleva, así
  que ambos lados cambian los mismos hunks desde la misma base y GitHub
  responde `CONFLICTING`. Se rebasa cada rama sobre `main` antes de fusionar
  (`git rebase` descarta el commit ya aplicado por patch-id) y se comprueba que
  el ÁRBOL no cambie. Y antes de todo eso, reapuntar la pila entera a `main`:
  fusionar el primero con `--delete-branch` cierra los PRs que colgaban de su
  rama, y un PR cerrado no se reabre.
- **Lo que el tren encontró y ninguna sesión vio: NUEVE defectos**, dos de
  ellos paradas de release, registrados como NU-89…NU-95, OR-54 y OR-55. La
  lección de método está arriba, en el estado vigente, y es la más cara del
  arco: **escribir la documentación es una medición.** Las dos paradas
  salieron de redactar la página de canales y la sección de notas, no de las
  cuarenta sondas.
- **Cuatro tests medían la máquina y no la cola** (NU-95) y pusieron el CI en
  rojo cuatro veces: ventana fija leída entre el claim y el release, 120 s
  fijos para drenar 10 000 jobs, el gate corriendo además en la lane de
  `-race` y en la de asynq, y schedulers arrancados con `Start()` —que no
  escucha al contexto— sin cerrar. La regla: **esperar al hecho, no al reloj**.
- **Tres trampas del tren, dos ya escritas y una nueva.** (1) release-please
  **regeneró la rama del release de orbit** entre el push de la deuda de doc y
  el clon del conductor, y se llevó la sección: se rehace sobre la punta nueva
  y se vigila hasta fusionar. (2) El workflow `Release` de nucleus estuvo en
  cola ~40 min por runner: hasta que publica, la release no tiene
  `checksums.txt` firmado y `umbrella-release-assets` no certificaría. (3)
  **NUEVA, y de las que se ríen de uno**: en `align-module-floors.sh`, una
  COMA dentro de un comentario en un `{ … } | sort` de sustitución de procesos
  hace que bash deje de leerlo como grupo de comandos; el bloque muere, la
  pasada de módulos internos se salta EN SILENCIO (el error va a stderr y el
  script sigue) y vuelve justo la trampa de 1.31.0 que ese comentario
  describía. Arreglado sacando el descubrimiento fuera del grupo.
- **Y una de MDX**: una línea que empieza por `{` se lee como expresión JSX. Un
  code span en línea se partió al ajustar el párrafo y dejó la continuación
  empezando por la llave. No lo ve ningún test de Go ni ningún guard: sólo el
  build del sitio.
