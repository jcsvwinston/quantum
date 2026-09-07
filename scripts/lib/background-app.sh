#!/usr/bin/env bash
# background-app.sh — arrancar un servidor en segundo plano de forma que `$!`
# sea EL SERVIDOR, y pararlo de verdad.
#
# Lo usan las dos lanes que arrancan una app y la matan en su trap EXIT:
#
#   - scripts/ci/showcase_smoke.sh    — showcase_demo compilado al pin.
#   - scripts/ci/quickstart_smoke.sh  — el proyecto que genera `nucleus new`.
#
# La trampa que este fichero cierra: `(cd "$dir" && ./app > app.log 2>&1) &`
# devuelve en `$!` el PID del SUBSHELL, no el de `./app`. Bash 3.2 (macOS,
# el objetivo declarado de estos scripts) hace fork del último comando de la
# lista en vez de exec, así que `kill $!` en el trap mata al subshell, `./app`
# pasa a PID 1 y sigue ESCUCHANDO con su binario y su sqlite ya borrados por
# el `rm -rf` del temporal — en cada salida del script, roja o verde. El
# bash 5.2 de ubuntu suele ahorrarse el fork (optimización del último
# comando) y por eso el CI no lo enseña; cada ensayo en local dejaba un
# servidor huérfano. Con `exec` explícito el subshell SE CONVIERTE en el
# servidor: `$!` es el proceso que escucha, y `kill` lo alcanza. El autotest
# tests/background-app/selftest.sh lo demuestra con un servidor real (falla
# contra el patrón sin exec en bash 3.2).
#
# Compatibilidad: bash 3.2 (macOS) — sin mapfile, sin arrays asociativos.

# bg_start <dir> <log> <cmd> [args…] — arranca `cmd` con cwd `dir` y su
# stdout+stderr en `log` (relativo a `dir` si no es absoluto), y deja en
# BG_PID el PID del PROPIO comando. Variables de entorno: pásalas con
# `env VAR=valor cmd` — `env` también hace exec, así que el PID se conserva.
BG_PID=""
bg_start() {
  local dir=$1 log=$2
  shift 2
  (cd "$dir" && exec "$@" > "$log" 2>&1) &
  BG_PID=$!
}

# bg_stop <pid> — TERM al proceso, espera a que desaparezca (hasta 5 s) y si
# sigue, KILL. Devuelve 0 si al final no existe (o si no había PID / ya no
# existía); 1 si sobrevivió a todo. Pensado para el trap EXIT de las lanes,
# pero también sirve como aserción: «después de parar, no queda nada».
bg_stop() {
  local pid=$1 i
  [[ -n "$pid" ]] || return 0
  kill -0 "$pid" 2>/dev/null || return 0
  kill "$pid" 2>/dev/null
  # `wait` sólo aplica si es hijo de esta shell; si no, sale al instante.
  wait "$pid" 2>/dev/null
  for i in $(seq 1 50); do
    kill -0 "$pid" 2>/dev/null || return 0
    sleep 0.1
  done
  kill -9 "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
  sleep 0.2
  ! kill -0 "$pid" 2>/dev/null
}
