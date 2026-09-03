#!/usr/bin/env bash
# check_rumbo_estado.sh — la cabecera «Estado real» de docs/RUMBO.md dice el
# set que versions.yaml certifica.
#
# RUMBO.md es el roadmap VIVO y su regla de mantenimiento dice que se
# actualiza en el PR de re-pin de cada set. En Quantum 1.26.0 la cabecera se
# quedó en «Set certificado: Quantum 1.25.0 … quark v1.8.0» mientras el
# manifiesto decía 1.26.0 y el propio §1 del fichero decía «PUBLICADO en
# Quantum 1.26.0» (QM-6, auditoría 2026-09-03). Un roadmap que se contradice a
# tres párrafos de distancia no lo caza nadie más que un lector; desde aquí lo
# caza la lane.
#
# Qué exige, sobre la línea «Set certificado: Quantum X.Y.Z» del bloque
# «## Estado real» (y el resto de ese bullet, que puede continuar en las
# líneas siguientes):
#   1. X.Y.Z == `quantum:` del manifiesto.
#   2. Cada pilar nombrado en el bullet («quark vA.B.C», «nucleus vD.E.F»,
#      «orbit vG.H.I») == `modules:` del manifiesto.
# No mira la fecha: la fecha del set está en `released:` y la del RUMBO es la
# de su última revisión, que puede ser posterior legítimamente.
set -uo pipefail

cd "$(dirname "$0")/.."

rumbo=docs/RUMBO.md
manifest=versions.yaml
status=0

yaml_top() { awk -v key="$1" '$1 == key":" { v=$2; gsub(/"/, "", v); print v; exit }' "$manifest"; }
yaml_mod() {
  awk -v key="$1" '
    /^modules:/ { inb=1; next }
    /^[a-zA-Z_]/ { inb=0 }
    inb && $1 == key":" { v=$2; gsub(/"/, "", v); print v; exit }
  ' "$manifest"
}

want=$(yaml_top quantum)
[[ -n "$want" ]] || { echo "FAIL: $manifest no declara 'quantum:'" >&2; exit 1; }
[[ -f "$rumbo" ]] || { echo "FAIL: $rumbo no existe — el roadmap vivo del paraguas es un entregable" >&2; exit 1; }

# El bullet del set: desde la línea «Set certificado:» hasta el siguiente
# bullet («- **») o línea en blanco, dentro de la sección «## Estado real».
bullet=$(awk '
  /^## Estado real/ { insec=1; next }
  /^## / { insec=0 }
  insec && /Set certificado: Quantum/ { inb=1 }
  insec && inb && (/^- \*\*/ && !/Set certificado/ || /^[[:space:]]*$/) { exit }
  insec && inb { print }
' "$rumbo" | tr '\n' ' ')

if [[ -z "$bullet" ]]; then
  echo "FAIL: $rumbo no tiene una línea «Set certificado: Quantum X.Y.Z» bajo «## Estado real» — la cabecera del roadmap vivo tiene que nombrar el set" >&2
  exit 1
fi

got=$(sed -nE 's/.*Set certificado: Quantum ([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' <<<"$bullet")
if [[ "$got" != "$want" ]]; then
  echo "FAIL: $rumbo afirma «Set certificado: Quantum ${got:-?}» pero $manifest certifica quantum \"$want\" — la cabecera «Estado real» se actualiza en el PR de re-pin (regla de mantenimiento del propio RUMBO)" >&2
  status=1
else
  echo "OK: $rumbo — Set certificado: Quantum $got == manifiesto"
fi

for m in quark nucleus orbit; do
  mv=$(yaml_mod "$m")
  rv=$(sed -nE "s/.*[^a-z]$m (v[0-9]+\.[0-9]+\.[0-9]+).*/\1/p" <<<"$bullet")
  if [[ -z "$rv" ]]; then
    echo "FAIL: $rumbo — el bullet del set no nombra «$m vX.Y.Z»" >&2
    status=1
  elif [[ "$rv" != "$mv" ]]; then
    echo "FAIL: $rumbo dice $m $rv pero $manifest certifica $mv" >&2
    status=1
  else
    echo "OK: $rumbo — $m $rv == manifiesto"
  fi
done

if [[ $status -ne 0 ]]; then
  echo >&2
  echo "check_rumbo_estado: FALLO — docs/RUMBO.md no dice el set que versions.yaml certifica (ver arriba)." >&2
  exit 1
fi
echo "check_rumbo_estado: OK — la cabecera «Estado real» de docs/RUMBO.md coincide con versions.yaml"
