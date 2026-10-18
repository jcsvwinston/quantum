# Handoff archivado — sesión 2026-10-16 (segunda) (A12 `M0-G`: el guard de deprecaciones)

> Movido tal cual desde el §3 de `.claude/commands/next-session.md` el
> 2026-10-18, al entrar la sesión del tren de 1.42.0 (el §3 lleva como mucho
> dos sesiones; `scripts/check_handoff_size.sh`). Historia para buscar con
> grep, no para cargar.

### Sesión 2026-10-16 (segunda) — **A12 `M0-G`: el guard de deprecaciones lee los avisos sin marca y la lista cerrada del major**

- **Lo que hizo** (quantum#285, apilado sobre quantum#284; **sin fusionar:
  Carlos decide**): `scripts/check_deprecations.sh` lee, además de las 12
  marcas de godoc, cada `<repo>/docs/deprecations/DEP-*.md` con `Status:
  active` al pin —versión y «no earlier than» obligatorias, FAIL por
  versión ≤ pin, AVISO con los días por fecha vencida— y, si nombra el
  major, exige su fila en el §3.0 de `quantum-2.0.md` en `publicado`; y
  cruza la tabla entera (fila `publicado` sin fichero al pin FAIL; `por
  escribir` y `decisión` AVISO con recuento; producto o estado desconocidos
  y avisos repetidos FAIL; el producto se lee de la columna «Producto»,
  porque los tres repos numeran por su cuenta). Al pin de 1.41.0: 13
  avisos `active` (5 de retirada, 7 de volteo, 1 tolerado), 29 filas, 17
  pendientes antes de `M1`. Fixture con cinco roturas; `guard-of-guards`
  60 de 60. Política §1/§5/§6, nota del §3.0, comentario del registro de
  guards y **QM-20 `hecho`**. No toca ningún producto.
- **Lo que midió**: los doce avisos publicados llevan la viñeta de ventana
  con tres grafías («Earliest removal», «Behaviour flip», «Earliest
  change») y el guard las lee todas tal cual: ninguno está mal escrito, y
  `M0-N`/`M0-Q` no tienen nada que corregir en los que ya existen.
  `DEP-2026-003` de nucleus (`active` sin fecha) se tolera con AVISO
  **sólo** porque su fila 20 está en `decisión`: en cuanto D2 se decida y
  la fila cambie de estado, el guard exige la fecha.
- **Trampa anunciada para el tren**: el PR de set que re-pine quark con los
  avisos de `M0-Q` (o nucleus con los de `M0-N`) sale ROJO en
  `umbrella-deprecations` hasta que sus filas del §3.0 pasen de `por
  escribir` a `publicado` en ese mismo PR. Es a propósito —la tabla no
  puede quedarse rancia—, pero hay que saberlo antes de lanzar `train.sh`.
- **Pila de PRs**: quantum#285 contiene el commit de quantum#284. Cuando
  #284 se fusione con squash, `git rebase --onto origin/main
  docs/a12-m0-s0-inventario-major` en `claude/confident-goldstine-b07287` y
  push forzado; si se fusiona #285 primero, se lleva consigo el §3.0 y el
  troceado de `M0-S0` y #284 queda vacío. No fusionar el primero con
  `--delete-branch` sin reapuntar antes (trampa de 1.32.0).
- **Lo siguiente**: `M0-Q` arrancó en paralelo el mismo día (quark, sesión
  aparte); `M0-N` espera D1…D8; `M0-O`, la release de nucleus con `M0-N`.

