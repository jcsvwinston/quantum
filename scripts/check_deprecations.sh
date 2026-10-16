#!/usr/bin/env bash
# check_deprecations.sh — todo lo que los tres productos han prometido
# retirar o cambiar tiene aviso, versión y fecha, y lo que va al major está
# en la lista cerrada del 2.0. Tres cosas, en este orden:
#
#   A. las marcas `// Deprecated:` escritas a mano en los .go (al pin);
#   B. los avisos <repo>/docs/deprecations/DEP-*.md con `Status: active`
#      (al pin), tengan marca o no;
#   C. la tabla del §3.0 de docs/planes/quantum-2.0.md —la lista cerrada del
#      major— cruzada con B en las dos direcciones.
#
# A. El problema que cierra, medido el 2026-09-09 sobre el pin 1.29.0: quark
# llevaba cinco marcas `// Deprecated:` y una de ellas —el alias
# `RowLevelSecurity`— prometía la retirada «in v1.0». Quark iba por v1.12.0,
# así que la promesa había vencido doce minors atrás sin que nada lo dijera.
# Una deprecación sin fecha de caducidad no es una deprecación: es una nota.
# Y una nota que nombra una versión ya publicada es peor, porque dice al
# lector que el símbolo ya no debería existir. Para cada marca a mano:
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
# B. Existe porque A no bastaba (QM-20, medido el 2026-10-16 por `M0-S0` de
# A12 sobre el pin de 1.41.0): siete avisos anunciaban un cambio de
# comportamiento —`UpdateBatch` comprobando versiones por defecto, seis
# negativas de configuración de `WithoutDefaults()`— y ninguno tenía marca,
# porque el símbolo se queda y lo que cambia es lo que hace. Un guard que
# sólo recorre marcas no veía ni su fecha, ni su versión, ni si estaban en la
# lista del major. Para cada aviso `active`:
#
#   1. una línea de la cabecera dice cuándo: «Earliest removal», «Behaviour
#      flip» o «Earliest change» con `vX.Y.Z` y «no earlier than YYYY-MM-DD»
#      (FALLA si falta);
#   2. esa vX.Y.Z es MAYOR que el pin del repo (FALLA si no);
#   3. la fecha no ha pasado (AVISA con los días, como en A);
#   4. si esa versión es un major respecto al pin, el aviso está en la tabla
#      del §3.0 (FALLA si no: es la mitad «el guard ve el 100 % de lo que va
#      al major»).
#
#   Los avisos `removed`, `completed` y `proposed` se ignoran: no prometen
#   nada pendiente. Un aviso `active` SIN versión ni fecha se tolera —con
#   AVISO— sólo mientras la tabla lo tenga en `decisión` o en `por
#   escribir`: es DEP-2026-003 de nucleus (las filas de política de 3
#   columnas), que esperó D2 de quantum-2.0.md §3.3 (decidida el
#   2026-10-16: fecharlo al 2.0) y ahora espera a que M0-N escriba la fecha
#   en el aviso y un set la traiga al pin. En cuanto la fila diga `en main`
#   o `publicado` la fecha se exige; con cualquier otro estado, o sin fila,
#   FALLA.
#
# C. La tabla misma. Por cada fila: `publicado` exige el fichero al pin
# (FALLA si no está); `por escribir` y `decisión` AVISAN y se cuentan —son
# lo que falta antes de `M1`—; `en main` se cuenta (el fichero llega con el
# set que lo publique); un estado que no sea uno de esos, un producto que no
# sea quark/nucleus/orbit o un aviso repetido FALLAN. Y al revés: un aviso
# que ya está al pin con su fecha en una fila que no dice `publicado` es una
# tabla rancia, y FALLA (se corrige en el PR de set que trae el aviso). El id
# se lee de la columna «Aviso» y el producto de la columna «Producto», no
# del id: los tres repos numeran por su cuenta y DEP-2026-001 de orbit no es
# DEP-2026-001 de quark.
#
# La versión FALLA y la fecha AVISA, por el mismo motivo que manifest-guard
# reparte así sus secciones: una versión ya publicada es una contradicción
# entre lo que dice el código y lo que hay en el proxy, y eso se arregla
# editando el código; una fecha cumplida es trabajo pendiente —retirar el
# símbolo o voltear el comportamiento—, y ese trabajo no puede secuestrar el
# CI de un cambio que no lo toca. El aviso dice cuántos días lleva vencida,
# que es lo que hace que se note.
#
# Fuera de alcance, por construcción:
#   - el código generado (cabecera `Code generated ... DO NOT EDIT.`): sus
#     marcas las escribe protoc o ent, no nosotros, y reescribirlas se
#     perdería en la siguiente generación;
#   - website/ y node_modules/, que no son código del producto;
#   - un repo sin docs/deprecations/ (orbit al pin de 1.41.0): no hay aviso
#     que leer, y se dice. Su primer aviso lo trae `M0-O`.
#
# Uso: bash scripts/check_deprecations.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

CONTRATO=docs/planes/quantum-2.0.md

status=0
hoy=$(date -u +%Y-%m-%d)

# A. marcas
total=0
malas=0
vencidas=0
# B. avisos
avisos=0
avisos_retirada=0
avisos_volteo=0
avisos_malos=0
avisos_vencidos=0
avisos_tolerados=0
avisos_ignorados=0
# C. filas
filas=0
filas_publicado=0
filas_en_main=0
filas_por_escribir=0
filas_decision=0
filas_descartado=0
filas_malas=0

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

# major_de vX.Y.Z -> X
major_de() {
  local v=${1#v}
  echo "${v%%.*}"
}

# ---------------------------------------------------------------------------
# C (lectura). La tabla del §3.0 del contrato del 2.0, una línea por fila:
#   n|producto|id|estado|hallazgo|sesion
# Las columnas se localizan por su NOMBRE en la cabecera, no por posición,
# para que reordenar la tabla no deje al guard leyendo la columna de al lado
# sin decirlo. El estado es lo que va entre los primeros acentos graves de
# su celda (`decisión` (D7) → decisión); el id, el primer DEP-YYYY-NNN de la
# celda «Aviso» (DEP-2026-001 (orbit) → DEP-2026-001).
# ---------------------------------------------------------------------------
if [ ! -f "$CONTRATO" ]; then
  echo "FAIL: falta $CONTRATO — la lista cerrada del major vive en su §3.0 y este guard la cruza con los avisos al pin." >&2
  exit 1
fi

tabla=$(awk -F'|' '
  function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
  function entre_graves(s,   m) {
    if (match(s, /`[^`]+`/)) { m = substr(s, RSTART + 1, RLENGTH - 2); return trim(m) }
    return trim(s)
  }
  /^### 3\.0/ { en = 1; next }
  en && /^### / { exit }
  !en || !/^\|/ { next }
  {
    if (!cab) {
      for (i = 1; i <= NF; i++) {
        c = trim($i)
        if (c == "#") cn = i
        else if (c == "Producto") cp = i
        else if (c == "Aviso") ca = i
        else if (c == "Estado") ce = i
        else if (c == "Hallazgo") ch = i
        else if (c == "Sesión") cs = i
      }
      cab = 1
      if (!cn || !cp || !ca || !ce) { print "CABECERA_SIN_COLUMNAS"; exit }
      next
    }
    if ($0 ~ /^\|[[:space:]]*-+/) next
    n = trim($cn); if (n == "") next
    prod = trim($cp)
    id = ""
    if (match($ca, /DEP-[0-9][0-9][0-9][0-9]-[0-9][0-9][0-9]/)) id = substr($ca, RSTART, RLENGTH)
    est = entre_graves($ce)
    hal = (ch ? trim($ch) : "")
    ses = (cs ? entre_graves($cs) : "")
    print n "|" prod "|" id "|" est "|" hal "|" ses
  }
' "$CONTRATO")

if [ -z "$tabla" ]; then
  echo "FAIL: $CONTRATO no tiene la tabla del §3.0 (o está vacía) — es la lista cerrada del major y el guard no puede cruzarla." >&2
  exit 1
fi
if [ "$tabla" = "CABECERA_SIN_COLUMNAS" ]; then
  echo "FAIL: la tabla del §3.0 de $CONTRATO no tiene las columnas #, Producto, Aviso y Estado — el guard las busca por nombre." >&2
  exit 1
fi

# fila_de PRODUCTO ID -> la línea de la tabla para ese aviso (vacío si no está).
fila_de() {
  printf '%s\n' "$tabla" | awk -F'|' -v p="$1" -v i="$2" '$2 == p && $3 == i { print; exit }'
}

# ---------------------------------------------------------------------------
# A. Las marcas de godoc.
# ---------------------------------------------------------------------------
echo "-- A. marcas // Deprecated: escritas a mano (al pin)"
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
echo

# ---------------------------------------------------------------------------
# B. Los avisos `active` al pin, con marca o sin ella.
# ---------------------------------------------------------------------------
echo "-- B. avisos docs/deprecations/DEP-*.md con Status: active (al pin)"
for repo in quark nucleus orbit; do
  pin=$(pin_de "$repo")
  if [ ! -d "$repo/docs/deprecations" ]; then
    echo "  --  $repo: sin docs/deprecations/ al pin (ningún aviso que leer)"
    continue
  fi
  for f in "$repo"/docs/deprecations/DEP-*.md; do
    [ -f "$f" ] || continue
    id=$(basename "$f" | sed -nE 's/^(DEP-[0-9]{4}-[0-9]{3})-.*/\1/p')
    if [ -z "$id" ]; then
      echo "FAIL: $f — el nombre no es DEP-YYYY-NNN-<slug>.md." >&2
      avisos_malos=$((avisos_malos + 1))
      status=1
      continue
    fi
    # La cabecera son las viñetas anteriores a la primera sección `## `;
    # una viñeta partida en varias líneas (las continuaciones van sangradas)
    # se une en una, igual que los párrafos de godoc en A.
    cabecera=$(awk '
      /^## / { exit }
      /^# / { next }
      /^- / { if (acc != "") print acc; acc = $0; next }
      /^[[:space:]]+[^[:space:]]/ { if (acc != "") { t = $0; sub(/^[[:space:]]+/, "", t); acc = acc " " t }; next }
      { if (acc != "") { print acc; acc = "" } }
      END { if (acc != "") print acc }
    ' "$f")
    estado=$(printf '%s\n' "$cabecera" | sed -nE 's/^- Status:[[:space:]]*`?([a-z]+).*/\1/p' | head -1)
    if [ -z "$estado" ]; then
      echo "FAIL: $f — la cabecera no tiene línea «- Status:» (proposed/active/completed/removed)." >&2
      avisos_malos=$((avisos_malos + 1))
      status=1
      continue
    fi
    if [ "$estado" != "active" ]; then
      avisos_ignorados=$((avisos_ignorados + 1))
      continue
    fi
    avisos=$((avisos + 1))
    fila=$(fila_de "$repo" "$id")
    n_fila=$(printf '%s' "$fila" | cut -d'|' -f1)
    estado_fila=$(printf '%s' "$fila" | cut -d'|' -f4)
    ventana=$(printf '%s\n' "$cabecera" | grep -m1 'no earlier than' || true)
    ver=$(printf '%s' "$ventana" | sed -nE 's/.*(v[0-9]+\.[0-9]+\.[0-9]+).*/\1/p')
    fecha=$(printf '%s' "$ventana" | sed -nE 's/.*no earlier than `?([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/p')
    if [ -z "$ver" ] || [ -z "$fecha" ]; then
      if [ "$estado_fila" = "decisión" ] || [ "$estado_fila" = "por escribir" ]; then
        echo "AVISO: $f — \`active\` sin versión ni fecha; la fila $n_fila del §3.0 lo tiene en \`$estado_fila\`, así que se tolera hasta que el aviso lleve la fecha al pin (en \`en main\` o \`publicado\` FALLARÍA)."
        avisos_tolerados=$((avisos_tolerados + 1))
        continue
      fi
      echo "FAIL: $f — el aviso no dice cuándo se retira o cambia." >&2
      echo "      Escribe en la cabecera «Earliest removal | Behaviour flip | Earliest change: \`vX.Y.Z\`, no earlier than YYYY-MM-DD»" >&2
      echo "      (ver docs/gobernanza/POLITICA_DEPRECACION.md §5). Sólo una fila en \`decisión\` o \`por escribir\` del §3.0 de $CONTRATO lo excusa." >&2
      avisos_malos=$((avisos_malos + 1))
      status=1
      continue
    fi
    if ! semver_gt "$ver" "$pin"; then
      echo "FAIL: $f — promete cambiar en $ver y $repo ya va por $pin." >&2
      echo "      La promesa ha vencido: retira o voltea, o fecha de nuevo el aviso." >&2
      avisos_malos=$((avisos_malos + 1))
      status=1
      continue
    fi
    # Retirada o volteo lo dice la CLAVE de la viñeta («Earliest removal»
    # frente a «Behaviour flip» / «Earliest change»), no su texto: la prosa
    # de un volteo suele decir «not a symbol removal».
    clave=$(printf '%s' "$ventana" | sed -nE 's/^- ([^:]+):.*/\1/p')
    if printf '%s' "$clave" | grep -qi 'removal'; then
      tipo=retirada
      avisos_retirada=$((avisos_retirada + 1))
    else
      tipo=volteo
      avisos_volteo=$((avisos_volteo + 1))
    fi
    if [ "$(major_de "$ver")" -gt "$(major_de "$pin")" ]; then
      if [ -z "$fila" ]; then
        echo "FAIL: $f — nombra $ver (el major) y no está en la tabla del §3.0 de $CONTRATO." >&2
        echo "      La lista cerrada del major tiene que tener el 100 % de lo que va al major: añade la fila ($repo, $id)." >&2
        avisos_malos=$((avisos_malos + 1))
        status=1
        continue
      fi
      if [ "$estado_fila" != "publicado" ]; then
        echo "FAIL: $f — está al pin con su fecha y la fila $n_fila del §3.0 dice \`$estado_fila\`; tiene que decir \`publicado\`." >&2
        echo "      La tabla se ha quedado rancia: corrígela en el PR de set que trae el aviso." >&2
        avisos_malos=$((avisos_malos + 1))
        status=1
        continue
      fi
      donde="§3.0 fila $n_fila"
    else
      donde="fuera del major"
    fi
    if [ "$fecha" \< "$hoy" ]; then
      dias=$(dias_entre "$fecha" "$hoy")
      echo "AVISO: $f — la ventana venció hace $dias día(s) ($fecha); el cambio en $ver está pendiente ($donde)."
      avisos_vencidos=$((avisos_vencidos + 1))
      continue
    fi
    echo "  ok  $f → $tipo, $ver, no antes de $fecha ($donde; pin $repo $pin)"
  done
done
echo

# ---------------------------------------------------------------------------
# C. La tabla del §3.0, fila a fila.
# ---------------------------------------------------------------------------
echo "-- C. la lista cerrada del major ($CONTRATO §3.0)"
vistas=""
while IFS='|' read -r n prod id est hal ses; do
  [ -n "$n" ] || continue
  filas=$((filas + 1))
  case "$prod" in
    quark|nucleus|orbit) ;;
    *)
      echo "FAIL: §3.0 fila $n — el producto es «$prod» y tiene que ser quark, nucleus u orbit." >&2
      filas_malas=$((filas_malas + 1)); status=1; continue ;;
  esac
  if [ -n "$id" ]; then
    if printf '%s\n' "$vistas" | grep -qxF "$prod|$id"; then
      echo "FAIL: §3.0 fila $n — $prod $id ya está en otra fila; un aviso es una decisión y una fila." >&2
      filas_malas=$((filas_malas + 1)); status=1; continue
    fi
    vistas="$vistas
$prod|$id"
  fi
  etiqueta="$prod ${id:-sin aviso}"
  [ -n "$hal" ] && [ "$hal" != "—" ] && etiqueta="$etiqueta ($hal)"
  case "$est" in
    publicado)
      if [ -z "$id" ]; then
        echo "FAIL: §3.0 fila $n — dice \`publicado\` y la columna Aviso no tiene ningún DEP-YYYY-NNN." >&2
        filas_malas=$((filas_malas + 1)); status=1; continue
      fi
      if ! ls "$prod"/docs/deprecations/"$id"-*.md >/dev/null 2>&1; then
        echo "FAIL: §3.0 fila $n — $etiqueta dice \`publicado\` y no hay $prod/docs/deprecations/$id-*.md al pin." >&2
        echo "      O el aviso no ha salido en ningún set todavía (\`en main\`) o nunca se escribió (\`por escribir\`)." >&2
        filas_malas=$((filas_malas + 1)); status=1; continue
      fi
      filas_publicado=$((filas_publicado + 1))
      echo "  ok  §3.0 fila $n — $etiqueta publicado, fichero al pin" ;;
    "en main")
      filas_en_main=$((filas_en_main + 1))
      echo "  --  §3.0 fila $n — $etiqueta en main (llega con el próximo set de $prod)" ;;
    "por escribir")
      filas_por_escribir=$((filas_por_escribir + 1))
      echo "AVISO: §3.0 fila $n — $etiqueta por escribir${ses:+ → $ses}" ;;
    "decisión")
      filas_decision=$((filas_decision + 1))
      echo "AVISO: §3.0 fila $n — $etiqueta espera decisión${ses:+ → $ses}" ;;
    descartado)
      filas_descartado=$((filas_descartado + 1))
      echo "  --  §3.0 fila $n — $etiqueta descartado (el número no se reutiliza)" ;;
    *)
      echo "FAIL: §3.0 fila $n — estado «$est» desconocido; vale \`publicado\`, \`en main\`, \`por escribir\`, \`decisión\` o \`descartado\`." >&2
      filas_malas=$((filas_malas + 1)); status=1 ;;
  esac
done <<EOF
$tabla
EOF
echo

pendientes=$((filas_por_escribir + filas_decision))
if [ "$status" -eq 0 ]; then
  echo "OK: deprecaciones — $total marca(s) a mano ($vencidas vencida(s)); $avisos aviso(s) \`active\` al pin: $avisos_retirada de retirada, $avisos_volteo de volteo, $avisos_tolerados sin fecha tolerado(s) por su fila del §3.0 (decisión/por escribir), $avisos_vencidos vencido(s), $avisos_ignorados no activo(s) ignorado(s); §3.0: $filas fila(s) — $filas_publicado publicado con fichero al pin, $filas_en_main en main, $filas_por_escribir por escribir, $filas_decision en decisión → $pendientes pendiente(s) antes de M1"
else
  echo "FAIL: $malas marca(s), $avisos_malos aviso(s) y $filas_malas fila(s) del §3.0 incumplen docs/gobernanza/POLITICA_DEPRECACION.md §5 (de $total, $avisos y $filas)" >&2
fi
exit $status
