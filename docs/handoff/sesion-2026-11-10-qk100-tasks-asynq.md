# Handoff archivado — sesión 2026-11-10 (QK-100 y el nacimiento de `providers/tasks-asynq`)

> Movido tal cual desde el §3 de `.claude/commands/next-session.md` el
> 2026-11-12, al entrar la sesión de `DX-N3n2` (el §3 lleva como mucho dos
> sesiones; `scripts/check_handoff_size.sh`). Historia para buscar con
> grep, no para cargar.

### Sesión 2026-11-10 — **QK-100 resuelto y el nacimiento de `providers/tasks-asynq`: el módulo existe en 1.x reenviando al paquete del árbol, y `nucleus add tasks-asynq` deja de apuntar al vacío**

- **Arranque**: Carlos preguntó por QK-100 (el `--from-models` del CLI de
  quark que nucleus necesita para `DX-N3n2`) y dijo «resuélvelo ya»; después,
  «adelante con tasks-asynq», la sesión propia que `M0-E` y `M0-F` dejaron
  anunciada.
- **QK-100 (quark#487, fusionado; registro en quantum#305)**: la causa real
  no era la que la fila decía (ninguna de las dos rutas sigue a `--config`):
  el cargador de paquetes corría en el cwd y un paquete de OTRO módulo —el
  caso de `nucleus makemigrations`— salía como «no Go package found» aunque
  la ruta fuese absoluta. Ahora carga dentro del directorio de los modelos;
  test que carga la fixture por ruta absoluta desde fuera de su módulo.
- **`providers/tasks-asynq` (nucleus#651)**: DEP-2026-020 mueve el
  proveedor asynq a módulo propio EN el major (decisión 4), pero
  `nucleus add tasks-asynq` apuntaba a un módulo inexistente. La forma que
  cabe en 1.x: el módulo nace **reenviando** —`package asynqprovider` con
  import en blanco del paquete del árbol (que es quien registra el
  proveedor), aliases de tipo y funciones envoltorio de la superficie entera
  (`Name`, las dos constantes del lock, los siete `Err*`, siete tipos, seis
  constructores)—, pina nucleus v1.34.0 (ya trae el registro de
  proveedores, nucleus#638) y pasa `check_modules_standalone.sh` desde el
  primer día. Un test en `contracts/` compara por `go/parser` los
  identificadores exportados de los dos paquetes, para que el reenvío no
  derive en silencio hasta el 2.0. Entrada `tasks-asynq` en el catálogo de
  `nucleus add` (grupo nuevo «jobs providers», receta con
  `jobs_provider: asynq` y `jobs_redis_url`), alta en
  release-please/manifest/modules.json con `0.0.0` (la release corta el
  primer tag), dependabot, codeql, SECURITY, README, SPEC, CLAUDE.md
  (dieciséis hermanos: ocho providers), la lane de providers de `ci.yml`,
  CI_MATRIX e inventario; DEP-2026-020 y MA-2026-020 dicen que el módulo
  existe desde la minor siguiente a v1.34.0 y que el import ya puede
  escribirse (la retirada del paquete del árbol y la salida de asynq/redis
  del `go.mod` raíz siguen siendo del 2.0: `M1` mueve el código, que ya
  está ensayado en `dry-run/2.0`). Nada cambia en el módulo raíz.
- **Paraguas (este PR)**: `umbrella-why-quantum` aprende la clase
  «jobs provider» en los dos sentidos (si el set certifica un
  `providers/tasks-*` la página tiene que nombrarlo, y al revés), la sesión
  en el plan de A12 y la fila de DEP-2026-020 en la política.
- **Lo siguiente**: el set del 2026-11-16 publica los dos módulos nuevos de
  nucleus (`quarkmake` y `tasks-asynq`) además del bloque A; sus trampas en
  el §5. Después `DX-N3n2` y D9…D11.

