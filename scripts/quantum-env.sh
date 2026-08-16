#!/usr/bin/env bash
# quantum-env.sh — DX-24: one .env, two configuration grammars.
#
# quark reads QUARK_* (viper, `_` nesting) and nucleus reads NUCLEUS_*
# (koanf, `__` nesting). An app using both used to need a hand-written
# bridge script (55 lines in the reference app) just to feed the same
# values to the two products. This generator emits BOTH spellings from one
# neutral .env file.
#
# Usage:
#   eval "$(scripts/quantum-env.sh path/to/.env)"     # export into the shell
#   scripts/quantum-env.sh path/to/.env > both.env    # or materialize a file
#
# Neutral keys understood (everything else passes through untouched):
#   DATABASE_URL      -> QUARK_DATABASE_DEFAULT_DSN + NUCLEUS_DATABASES__DEFAULT__URL
#   DATABASE_DRIVER   -> QUARK_DATABASE_DEFAULT_DRIVER              (quark-only)
#   ADMIN_DATABASE_URL-> QUARK_DATABASE_ADMIN_DSN                   (quark-only)
#   REDIS_URL         -> NUCLEUS_REDIS_URL + NUCLEUS_JOBS_REDIS_URL (nucleus-only)
#   TENANT_STRATEGY   -> QUARK_TENANT_STRATEGY                      (quark-only)
#   TENANT_DSN_TEMPLATE -> QUARK_TENANT_DSN_TEMPLATE                (quark-only)
#   JWT_SECRET        -> NUCLEUS_JWT_SECRET                         (nucleus-only)
#   LOG_LEVEL         -> NUCLEUS_LOG_LEVEL                          (nucleus-only)
set -euo pipefail

envfile="${1:?usage: quantum-env.sh <path/to/.env>}"
[ -f "$envfile" ] || { echo "quantum-env: $envfile does not exist" >&2; exit 1; }

emit() { printf 'export %s=%q\n' "$1" "$2"; }

while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in ''|\#*) continue ;; esac
  key="${line%%=*}"
  val="${line#*=}"
  case "$key" in
    DATABASE_URL)
      emit QUARK_DATABASE_DEFAULT_DSN "$val"
      emit NUCLEUS_DATABASES__DEFAULT__URL "$val"
      ;;
    DATABASE_DRIVER)       emit QUARK_DATABASE_DEFAULT_DRIVER "$val" ;;
    ADMIN_DATABASE_URL)    emit QUARK_DATABASE_ADMIN_DSN "$val"; emit QUARK_DATABASE_ADMIN_DRIVER "${DATABASE_DRIVER:-postgresql}" ;;
    REDIS_URL)             emit NUCLEUS_REDIS_URL "$val"; emit NUCLEUS_JOBS_REDIS_URL "$val" ;;
    TENANT_STRATEGY)       emit QUARK_TENANT_STRATEGY "$val" ;;
    TENANT_DSN_TEMPLATE)   emit QUARK_TENANT_DSN_TEMPLATE "$val" ;;
    JWT_SECRET)            emit NUCLEUS_JWT_SECRET "$val" ;;
    LOG_LEVEL)             emit NUCLEUS_LOG_LEVEL "$val" ;;
    *)                     emit "$key" "$val" ;;
  esac
done < "$envfile"
