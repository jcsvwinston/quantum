#!/usr/bin/env bash
# check_schedule_notify.sh — toda lane del PARAGUAS con disparador `schedule:`
# lleva su job `notify-schedule-failure`, y ese job avisa de verdad.
#
# Por qué: QM8-1 declaró insuficiente el único canal que Actions da por
# defecto para un cron rojo —un email a la cuenta del propietario, que nadie
# mira—. El remedio del paraguas es un job que abre o actualiza un issue
# (scripts/notify_schedule_failure.sh). La regla estaba escrita en
# docs/AUDITORIA_CONTINUA.md §7 y sostenida sólo por la costumbre: las dos
# lanes programadas lo llevaban porque se copiaron la una a la otra. La
# TERCERA nació sin él —scorecard.yml, en este mismo PR— y la lane de
# certificación salió 40/40 verde con la omisión dentro. Una regla que sólo
# vive en la prosa se pierde en el siguiente workflow escrito a mano.
#
# Qué exige, por cada workflow con `- cron:`:
#
#   1. Existe el job `notify-schedule-failure`.
#   2. Su `if:` nombra failure(), cancelled() (MAQ-4/(c): un schedule
#      cancelado por `concurrency` perdía el aviso) y acota a
#      `github.event_name == 'schedule'` — en un PR el rojo ya se ve.
#   3. Declara `issues: write`: sin ese permiso el aviso falla en silencio y
#      el rojo degrada justo al email que QM8-1 descartó.
#   4. Ejecuta scripts/notify_schedule_failure.sh — el canal común, no un
#      `echo` que parezca un aviso.
#   5. RT-8: su `needs` lista TODOS los demás jobs del workflow. `failure()`
#      sólo mira la cadena de dependencias, así que un job fuera de la lista
#      enrojece el lunes SIN abrir issue. Ya pasó con `showcase-smoke` en
#      integration.yml: el job existía, el aviso también, y aun así el fallo
#      se perdió.
#
# Alcance: los workflows de ESTE repositorio (los de nucleus, quark y orbit
# los gobierna cada producto). Un workflow sin `schedule:` no se mira: la
# regla es sobre el cron, no sobre los PRs.
#
# Dónde muerde: `scripts/suite-integral.sh` (registro de guards), que en CI
# corre desde `.github/workflows/suite-integral.yml` — cuyo filtro de rutas
# incluye '.github/workflows/**', así que el veredicto llega en el PR que
# añade la lane, no en el cron siguiente (§8).
set -uo pipefail
cd "$(dirname "$0")/.."

DIR=${1:-.github/workflows}
NOTIFY_JOB="notify-schedule-failure"
NOTIFY_SCRIPT="scripts/notify_schedule_failure.sh"
status=0
scheduled=0
files=0

if [ ! -d "$DIR" ]; then
  echo "FAIL: no existe el directorio de workflows $DIR" >&2
  exit 2
fi

# Jobs declarados en un workflow: las claves a DOS espacios que siguen a la
# línea `jobs:` de nivel cero, hasta la siguiente clave de nivel cero.
jobs_of() {
  awk '
    /^jobs:[[:space:]]*$/ { injobs = 1; next }
    injobs && /^[^[:space:]#]/ { injobs = 0 }
    injobs && /^  [A-Za-z0-9_.-]+:[[:space:]]*$/ {
      line = $0
      sub(/:[[:space:]]*$/, "", line)
      sub(/^  /, "", line)
      print line
    }
  ' "$1"
}

# Cuerpo de un job: de su clave a dos espacios hasta la siguiente clave a dos
# espacios (o al fin del fichero).
job_block() {
  awk -v job="$2" '
    $0 ~ "^  " job ":[[:space:]]*$" { inblock = 1; next }
    inblock && /^  [A-Za-z0-9_.-]+:[[:space:]]*$/ { inblock = 0 }
    inblock && /^[^[:space:]#]/ { inblock = 0 }
    inblock { print }
  ' "$1"
}

for f in "$DIR"/*.yml "$DIR"/*.yaml; do
  [ -e "$f" ] || continue
  files=$((files + 1))

  # La clave `cron:` sólo aparece bajo el disparador `schedule:`; una lane sin
  # cron no entra en la regla. Se busca la clave en cualquier posición (y no
  # sólo como `- cron:` al principio de línea) para que la forma en flujo
  # —`schedule: [{cron: '0 7 * * 1'}]`— no se escape: en este guard el falso
  # NEGATIVO es el peligroso, porque deja una lane sin aviso y en verde. Los
  # comentarios se descartan antes, para no exigir el job a un workflow que
  # sólo NOMBRA un cron en su prosa.
  grep -vE '^[[:space:]]*#' "$f" | grep -qE '(^|[[:space:]{,])cron:' || continue
  scheduled=$((scheduled + 1))

  all_jobs=$(jobs_of "$f")
  if [ -z "$all_jobs" ]; then
    echo "FAIL: $f tiene disparador «schedule:» pero no se le reconoce ningún job — ¿cambió el formato del fichero? (este guard lee las claves a dos espacios bajo «jobs:»)" >&2
    status=1
    continue
  fi

  if ! printf '%s\n' "$all_jobs" | grep -qxF "$NOTIFY_JOB"; then
    echo "FAIL: $f dispara por «schedule:» y no tiene el job «$NOTIFY_JOB» — el cron rojo degradaría al email por defecto de Actions, que QM8-1 declaró insuficiente (docs/AUDITORIA_CONTINUA.md §7; copia el job de suite-integral.yml)" >&2
    status=1
    continue
  fi

  block=$(job_block "$f" "$NOTIFY_JOB")
  if [ -z "$block" ]; then
    echo "FAIL: $f — el job «$NOTIFY_JOB» existe pero su cuerpo sale vacío al leerlo; ¿sangría no estándar?" >&2
    status=1
    continue
  fi

  cond=$(printf '%s\n' "$block" | grep -E '^[[:space:]]*if:' | head -1)
  for token in 'failure()' 'cancelled()' "github.event_name == 'schedule'"; do
    if ! printf '%s\n' "$cond" | grep -qF "$token"; then
      echo "FAIL: $f — el «if:» de $NOTIFY_JOB no nombra «$token»; el aviso debe cubrir el rojo Y la cancelación por concurrency (MAQ-4/(c)) y sólo en corridas programadas. Esperado: if: (failure() || cancelled()) && github.event_name == 'schedule'" >&2
      status=1
    fi
  done

  if ! printf '%s\n' "$block" | grep -qE '^[[:space:]]*issues:[[:space:]]*write[[:space:]]*$'; then
    echo "FAIL: $f — el job $NOTIFY_JOB no declara «issues: write»; sin ese permiso el aviso falla en silencio y el schedule rojo vuelve al email por defecto (QM8-1)" >&2
    status=1
  fi

  if ! printf '%s\n' "$block" | grep -qF "$NOTIFY_SCRIPT"; then
    echo "FAIL: $f — el job $NOTIFY_JOB no ejecuta $NOTIFY_SCRIPT; el canal es común a las tres lanes (dedupe server-side por etiqueta + título)" >&2
    status=1
  fi

  # RT-8: needs completo. Formato en línea `needs: [a, b, c]`, que es el que
  # usan los tres workflows.
  needs_line=$(printf '%s\n' "$block" | grep -E '^[[:space:]]*needs:' | head -1)
  if [ -z "$needs_line" ]; then
    echo "FAIL: $f — el job $NOTIFY_JOB no declara «needs:»; sin dependencias, failure() no ve ningún job y el aviso nunca se dispara (RT-8)" >&2
    status=1
    continue
  fi
  if ! printf '%s\n' "$needs_line" | grep -qE '\[.*\]'; then
    echo "FAIL: $f — el «needs:» de $NOTIFY_JOB no está en la forma «needs: [a, b, c]» que este guard sabe leer; escríbelo en línea para que la comprobación RT-8 siga siendo posible" >&2
    status=1
    continue
  fi
  declared=$(printf '%s\n' "$needs_line" | sed -e 's/.*\[//' -e 's/\].*//' -e 's/[",'"'"']//g' -e 's/,/ /g')

  for job in $all_jobs; do
    [ "$job" = "$NOTIFY_JOB" ] && continue
    found=0
    for dep in $declared; do
      [ "$dep" = "$job" ] && found=1
    done
    if [ "$found" -eq 0 ]; then
      echo "FAIL: $f — el «needs:» de $NOTIFY_JOB no incluye el job «$job»: failure() sólo mira la cadena de dependencias, así que ese job puede enrojecer el lunes sin que se abra issue (RT-8, le pasó a showcase-smoke)" >&2
      status=1
    fi
  done
  for dep in $declared; do
    found=0
    for job in $all_jobs; do
      [ "$dep" = "$job" ] && found=1
    done
    if [ "$found" -eq 0 ]; then
      echo "FAIL: $f — el «needs:» de $NOTIFY_JOB nombra «$dep», que no es un job de este workflow (¿renombrado o retirado?)" >&2
      status=1
    fi
  done
done

if [ "$scheduled" -eq 0 ]; then
  echo "FAIL: ninguno de los $files workflows de $DIR dispara por «schedule:» — o la ruta es la equivocada, o el paraguas perdió sus crons (que son los que hacen aflorar la deriva externa sin esperar a un PR)" >&2
  exit 2
fi

[ "$status" -eq 0 ] && echo "OK: $scheduled/$files workflows disparan por «schedule:»; todos con su job «$NOTIFY_JOB» (failure+cancelled, sólo en schedule, issues: write, canal común y needs completo)"
exit $status
