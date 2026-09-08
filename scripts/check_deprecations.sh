#!/usr/bin/env bash
# check_deprecations.sh — toda deprecación ESCRITA A MANO en los tres
# productos nombra su recambio y una versión de retirada que todavía no ha
# salido.
#
# El problema que cierra, medido el 2026-09-09 sobre el pin 1.29.0: quark
# llevaba cinco marcas `// Deprecated:` y una de ellas —el alias
# `RowLevelSecurity`— prometía la retirada «in v1.0». Quark iba por v1.12.0,
# así que la promesa había vencido doce minors atrás sin que nada lo dijera.
# Nucleus y orbit no tenían ninguna: su forma de retirar algo ha sido
# quitarlo en un minor con un error guiado (el arco D3), que es una decisión
# legítima pero distinta, y hasta hoy no estaba escrita en ninguna parte.
#
# Una deprecación sin fecha de caducidad no es una deprecación: es una nota.
# Y una nota que nombra una versión ya publicada es peor, porque dice al
# lector que el símbolo ya no debería existir. Este guard exige las dos
# mitades del contrato que fija docs/gobernanza/POLITICA_DEPRECACION.md:
#
#   1. el párrafo empieza por `Deprecated: ` (convención de Go, que es lo que
#      leen `go doc`, los editores y staticcheck SA1019);
#   2. dentro del mismo párrafo aparece «scheduled for removal in vX.Y.Z, no
#      earlier than YYYY-MM-DD»;
#   3. esa vX.Y.Z es MAYOR que la versión que versions.yaml pina para ese
#      repositorio — o sea, la promesa sigue viva;
#   4. el párrafo cita un aviso `DEP-YYYY-NNN` y ese aviso EXISTE en
#      <repo>/docs/deprecations/. Es la mitad que convierte la marca de godoc
#      en algo consultable: el aviso lleva la guía de migración, y sin él la
#      marca dice «no uses esto» sin decir cómo dejar de usarlo.
#
# La versión FALLA y la fecha AVISA, por el mismo motivo que manifest-guard
# reparte así sus secciones: una versión ya publicada es una contradicción
# entre lo que dice el código y lo que hay en el proxy, y eso se arregla
# editando el código; una fecha cumplida es trabajo pendiente —retirar el
# símbolo—, y ese trabajo no puede secuestrar el CI de un cambio que no lo
# toca. El aviso dice cuántos días lleva vencida, que es lo que hace que se
# note.
#
# Fuera de alcance, por construcción:
#   - el código generado (cabecera `Code generated ... DO NOT EDIT.`): sus
#     marcas las escribe protoc o ent, no nosotros, y reescribirlas se
#     perdería en la siguiente generación;
#   - website/ y node_modules/, que no son código del producto.
#
# Uso: bash scripts/check_deprecations.sh
set -uo pipefail
cd "$(dirname "$0")/.."

status=0
total=0
malas=0
vencidas=0
hoy=$(date -u +%Y-%m-%d)

# dias_entre DESDE HASTA — días naturales entre dos fechas ISO. `date -j -f`
# es la forma de BSD (macOS); `date -d` la de GNU (el CI). Se prueban las dos
# y, si ninguna contesta, el aviso sale sin la cuenta en vez de romper.
dias_entre() {
  local a b
  a=$(date -u -j -f %Y-%m-%d "$1" +%s 2>/dev/null || date -u -d "$1" +%s 2>/dev/null) || { echo "?"; return; }
  b=$(date -u -j -f %Y-%m-%d "$2" +%s 2>/dev/null || date -u -d "$2" +%s 2>/dev/null) || { echo "?"; return; }
  echo $(( (b - a) / 86400 ))
}

# Versión pinada de cada producto, del manifiesto. Es la referencia de «ya
# publicada»: el guard corre AL PIN, así que un vX.Y.Z <= pin es pasado.
pin_de() {
  awk -v repo="$1" '
    /^modules:/ { in_mod = 1; next }
    /^[a-z_]+:/ { in_mod = 0 }
    in_mod && $1 == repo":" { gsub(/"/, "", $2); print $2; exit }
  ' versions.yaml
}

# semver_gt A B -> 0 si A > B. Sin prereleases: los tres productos etiquetan
# vX.Y.Z limpio.
semver_gt() {
  local a=${1#v} b=${2#v}
  local a1 a2 a3 b1 b2 b3
  IFS=. read -r a1 a2 a3 <<EOF
$a
EOF
  IFS=. read -r b1 b2 b3 <<EOF
$b
EOF
  [ "${a1:-0}" -ne "${b1:-0}" ] && { [ "${a1:-0}" -gt "${b1:-0}" ]; return; }
  [ "${a2:-0}" -ne "${b2:-0}" ] && { [ "${a2:-0}" -gt "${b2:-0}" ]; return; }
  [ "${a3:-0}" -gt "${b3:-0}" ]
}

for repo in quark nucleus orbit; do
  [ -d "$repo" ] || { echo "FAIL: falta el submódulo $repo — ¿git submodule update --init?" >&2; exit 1; }
  pin=$(pin_de "$repo")
  if [ -z "$pin" ]; then
    echo "FAIL: versions.yaml no pina $repo en el bloque modules:" >&2
    exit 1
  fi

  # Un párrafo de deprecación son las líneas `//` contiguas desde la que
  # abre con `Deprecated:`. awk las une en una sola línea para que la
  # comprobación no dependa de dónde cayó el salto de línea.
  while IFS='|' read -r file line texto; do
    [ -n "$file" ] || continue
    total=$((total + 1))
    ver=$(printf '%s' "$texto" | sed -nE 's/.*[Ss]cheduled for removal in (v[0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/p')
    fecha=$(printf '%s' "$texto" | sed -nE 's/.*no earlier than ([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/p')
    dep=$(printf '%s' "$texto" | sed -nE 's/.*(DEP-[0-9]{4}-[0-9]{3}).*/\1/p')
    if [ -z "$ver" ] || [ -z "$fecha" ]; then
      echo "FAIL: $file:$line — la deprecación no dice cuándo se retira." >&2
      echo "      Escribe «Scheduled for removal in vX.Y.Z, no earlier than YYYY-MM-DD.»" >&2
      echo "      en el mismo párrafo (ver docs/gobernanza/POLITICA_DEPRECACION.md)." >&2
      echo "      Texto: $texto" >&2
      malas=$((malas + 1))
      status=1
      continue
    fi
    if ! semver_gt "$ver" "$pin"; then
      echo "FAIL: $file:$line — promete retirarse en $ver y $repo ya va por $pin." >&2
      echo "      La promesa ha vencido: retira el símbolo o fecha de nuevo la nota." >&2
      malas=$((malas + 1))
      status=1
      continue
    fi
    if [ -z "$dep" ]; then
      echo "FAIL: $file:$line — la deprecación no cita ningún aviso DEP-YYYY-NNN." >&2
      echo "      El aviso lleva la guía de migración; la marca de godoc sola no." >&2
      malas=$((malas + 1))
      status=1
      continue
    fi
    if ! ls "$repo"/docs/deprecations/"$dep"-*.md >/dev/null 2>&1; then
      echo "FAIL: $file:$line — cita $dep y no hay $repo/docs/deprecations/$dep-*.md." >&2
      echo "      Escribe el aviso con la plantilla del producto antes de marcar el símbolo." >&2
      malas=$((malas + 1))
      status=1
      continue
    fi
    if [ "$fecha" \< "$hoy" ]; then
      dias=$(dias_entre "$fecha" "$hoy")
      echo "AVISO: $file:$line — la ventana venció hace $dias día(s) ($fecha); la retirada en $ver está pendiente ($dep)."
      vencidas=$((vencidas + 1))
      continue
    fi
    echo "  ok  $file:$line → $dep, $ver, no antes de $fecha (pin $repo $pin)"
  done <<EOF
$(find "$repo" -name '*.go' -not -path '*/node_modules/*' -not -path '*/website/*' -print0 2>/dev/null \
  | xargs -0 awk '
      # El fichero es generado si su cabecera —todo lo anterior a la
      # cláusula package— lleva la línea que fija la convención de Go.
      # protoc-gen-go la escribe DESPUÉS de los comentarios del .proto, así
      # que no vale con mirar las tres primeras líneas.
      /^package / { encabezado[FILENAME] = 0 }
      !seen[FILENAME]++ { encabezado[FILENAME] = 1 }
      encabezado[FILENAME] && /^\/\/ Code generated .* DO NOT EDIT\.$/ { generado[FILENAME] = 1 }
      generado[FILENAME] { next }
      {
        if ($0 ~ /^[[:space:]]*\/\/ Deprecated:/) { acc = ""; ln = FNR; enbloc = 1 }
        if (enbloc) {
          if ($0 ~ /^[[:space:]]*\/\//) {
            t = $0
            sub(/^[[:space:]]*\/\/[[:space:]]?/, "", t)
            acc = (acc == "" ? t : acc " " t)
            next
          }
          print FILENAME "|" ln "|" acc
          enbloc = 0
        }
      }
      END { if (enbloc) print FILENAME "|" ln "|" acc }
    ')
EOF
done

if [ "$status" -eq 0 ]; then
  echo "OK: deprecaciones — $total marca(s) escrita(s) a mano, $vencidas con la ventana vencida (aviso), ninguna prometiendo una versión ya publicada"
else
  echo "FAIL: $malas de $total deprecación(es) incumplen docs/gobernanza/POLITICA_DEPRECACION.md" >&2
fi
exit $status
