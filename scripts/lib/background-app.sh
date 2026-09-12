#!/usr/bin/env bash
# background-app.sh — arrancar un servidor en segundo plano de forma que `$!`
# sea EL SERVIDOR, y pararlo de verdad.
#
# Lo usan las dos lanes que arrancan una app y la matan en su trap EXIT:
#
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
#
# La cota es REAL también cuando `pid` es hijo de esta shell (el caso de las
# lanes): `wait "$pid"` sobre un hijo bloquea hasta que muere, así que un
# `wait` a secas antes de sondear convertía un servidor que ignora TERM (o se
# atasca en su parada limpia) en un trap EXIT colgado hasta el timeout del
# job, con el KILL de después como código muerto. Por eso el KILL lo dispara
# un vigilante en segundo plano a los 5 s: el `wait` vuelve cuando el hijo
# muere por TERM o por ese KILL. Si `pid` no es hijo, `wait` sale al instante
# y se sondea con kill -0 hasta la misma cota. Avisa por stderr cuando el
# vigilante tuvo que disparar. El autotest tests/background-app/selftest.sh
# lo prueba con un servidor que ignora SIGTERM (falla contra el `wait` sin
# cota: vuelve a los 10 s de la red de seguridad del test).
bg_stop() {
  local pid=$1 wd i
  [[ -n "$pid" ]] || return 0
  kill -0 "$pid" 2>/dev/null || return 0
  kill "$pid" 2>/dev/null
  # Vigilante: a los 5 s, KILL si el PID sigue ahí (sale 0 sólo si disparó).
  ( sleep 5; kill -0 "$pid" 2>/dev/null || exit 1; kill -9 "$pid" 2>/dev/null ) 2>/dev/null &
  wd=$!
  # Hijo: vuelve cuando muere (TERM o el KILL del vigilante). No hijo: al instante.
  wait "$pid" 2>/dev/null
  for i in $(seq 1 55); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
  done
  # Parar el vigilante sin dejar su `sleep` huérfano (con el stdout del step
  # abierto): se mata al sleep, el subshell ve al PID ya muerto y sale 1.
  pkill -P "$wd" 2>/dev/null || kill "$wd" 2>/dev/null
  if wait "$wd" 2>/dev/null; then
    echo "background-app: el PID $pid no murió con TERM en 5 s; KILL" >&2
  fi
  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    sleep 0.2
  fi
  ! kill -0 "$pid" 2>/dev/null
}
