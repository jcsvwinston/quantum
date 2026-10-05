#!/usr/bin/env bash
# check_audit_backlog.sh — el gate de A1 del plan «Quantum a 5 de 5», y la
# contabilidad de los hallazgos de la auditoría de madurez 2026-09-03 y de
# las re-auditorías que la repiten.
#
# Lee docs/auditoria/madurez-2026-09-03/registro.csv y falla si:
#   1. un hallazgo con id y severidad en los informes no tiene fila, o una
#      fila no tiene hallazgo. Los informes son los seis del 2026-09-03 y los
#      de cada re-auditoría consolidada (docs/auditoria/reauditoria/<fecha>/,
#      A12 R1): un solo registro para todo el plan;
#      Una fila de defectos de un informe sin id válido también falla: es
#      el id provisional que una consolidación olvidó cambiar;
#   2. un id está repetido — dos filas del registro con el mismo id, o dos
#      filas de las tablas de los informes. Hubo dos NU-50 hasta el
#      2026-10-04 y nada lo vio: la comprobación 1 compara conjuntos, y un
#      conjunto no tiene repetidos (QM-21);
#   3. una fila abierta no tiene arco (A<n>, sin techo: lo que la re-auditoría
#      deje abierto va a un A13) — un hallazgo sin dueño se pierde, que es lo
#      que el registro existe para impedir;
#   4. un arco declarado CERRADO en la primera línea del registro
#      («# arcos_cerrados: A1 …») tiene hallazgos abiertos. Cerrar un arco es
#      añadirlo ahí; este guard dice si se puede. El gate de A1 son cero
#      P1/P2 abiertos: los P3 que queden se reasignan por escrito a otro arco.
# Imprime además cuántos P1/P2/P3 quedan abiertos por arco (información), y
# los P0 cuando los hay: antes no salían, y un P0 abierto no se veía aquí.
#
# Uso: bash scripts/check_audit_backlog.sh   (desde la raíz del paraguas)
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
DIR=docs/auditoria/madurez-2026-09-03
REG="$DIR/registro.csv"
[[ -f "$REG" ]] || { echo "FAIL: falta $REG" >&2; exit 1; }
status=0

# Un arco del plan: A1, A2, … sin techo. Una sola definición para la
# validación de cada fila y para el recuento: si dejara de aceptar un arco,
# su línea INFO desaparecería con él.
arco_valido() { [[ "$1" =~ ^A[1-9][0-9]*$ ]]; }

closed=$(sed -nE '1s/^# arcos_cerrados:[[:space:]]*//p' "$REG")
for c in $closed; do
  arco_valido "$c" || { echo "FAIL: «$c» en arcos_cerrados no es un arco (A<n>)" >&2; status=1; }
done

# Los informes: los seis del 2026-09-03 y los de cada re-auditoría.
informes=("$DIR"/*.md)
for f in docs/auditoria/reauditoria/[0-9]*/*.md; do
  [[ -f "$f" ]] && informes+=("$f")
done
filas_informes=$(grep -HoE '^\| [A-Z]+-?[0-9]+ \| \**P[0-3]\**' "${informes[@]}" | sed -E 's/^([^:]+):\| ([A-Z]+-?[0-9]+) .*/\2 \1/')
ids_informes=$(printf '%s\n' "$filas_informes" | awk 'NF {print $1}' | sort -u)
ids_registro=$(grep -vE '^#|^id,' "$REG" | cut -d, -f1 | sort -u)

# 1. Todo id de los informes tiene fila, y toda fila tiene hallazgo.
missing=$(comm -23 <(printf '%s\n' "$ids_informes") <(printf '%s\n' "$ids_registro"))
if [[ -n "$missing" ]]; then
  echo "FAIL: hallazgos de los informes sin fila en registro.csv: $(printf '%s ' $missing)" >&2; status=1
fi
ghost=$(comm -13 <(printf '%s\n' "$ids_informes") <(printf '%s\n' "$ids_registro"))
if [[ -n "$ghost" ]]; then
  echo "FAIL: filas del registro cuyo id no está en ningún informe: $(printf '%s ' $ghost)" >&2; status=1
fi

# Una fila de defectos (segunda celda = severidad) cuya primera celda no es un
# id se escapa de todo lo anterior: la regex de arriba no la ve. Es lo que
# queda si la consolidación de una re-auditoría olvida cambiar un id
# provisional («quark.3») por el definitivo.
sin_id=$(grep -HE '^\| [^|]+ \| \**P[0-3]\**' "${informes[@]}" | grep -vE '^[^:]+:\| [A-Z]+-?[0-9]+ \| ' | sed -E 's/^([^:]+):\| ([^|]+) \|.*/\2 (\1)/')
if [[ -n "$sin_id" ]]; then
  echo "FAIL: fila de defecto sin id válido (PREFIJO-n) en los informes: $(printf '%s; ' "$sin_id")— ¿un id provisional sin consolidar?" >&2; status=1
fi

# 2. Ids repetidos: en el registro y en las tablas de los informes.
dup_registro=$(grep -vE '^#|^id,' "$REG" | cut -d, -f1 | awk 'NF' | sort | uniq -d)
if [[ -n "$dup_registro" ]]; then
  echo "FAIL: id duplicado en registro.csv: $(printf '%s ' $dup_registro)— dos hallazgos con un solo id: uno de los dos no se cuenta" >&2; status=1
fi
dup_informes=$(printf '%s\n' "$filas_informes" | awk 'NF {n[$1]++; donde[$1]=donde[$1] " " $2} END {for (i in n) if (n[i]>1) printf "%s (%s ) ", i, donde[i]}')
if [[ -n "$dup_informes" ]]; then
  echo "FAIL: id repetido en las tablas de los informes: $dup_informes— renumera el posterior con el siguiente libre de su prefijo" >&2; status=1
fi

# 3 y 4. Por fila: arco presente si está abierta; arco cerrado ⇒ hecho.
n_open=0
while IFS=, read -r id sev repo arco estado rest; do
  [[ "$id" == "#"* || "$id" == "id" || -z "$id" ]] && continue
  case "$estado" in
    hecho) continue ;;
    abierto) ;;
    *) echo "FAIL: $id — estado «$estado» no es hecho|abierto" >&2; status=1; continue ;;
  esac
  n_open=$((n_open+1))
  if ! arco_valido "$arco"; then
    echo "FAIL: $id ($sev, $repo) — abierto y sin arco del plan (A<n>): un hallazgo sin dueño" >&2; status=1
  fi
  for c in $closed; do
    if [[ "$arco" == "$c" ]]; then
      echo "FAIL: $id ($sev, $repo) — sigue abierto y su arco $arco está declarado cerrado" >&2; status=1
    fi
  done
done < "$REG"

arcos=$(grep -vE '^#|^id,' "$REG" | cut -d, -f4 | sort -u | while read -r a; do arco_valido "$a" && echo "${a#A}"; done | sort -n)
for n in $arcos; do
  a="A$n"
  line=$(grep -vE '^#|^id,' "$REG" | awk -F, -v a="$a" '$4==a && $5=="abierto" {n[$2]++} END {t=n["P0"]+n["P1"]+n["P2"]+n["P3"]; if (t>0) printf "%sP1=%d P2=%d P3=%d", (n["P0"]>0 ? "P0=" n["P0"] " " : ""), n["P1"], n["P2"], n["P3"]}')
  [[ -n "$line" ]] && echo "INFO: $a abiertos — $line"
done
total=$(grep -cvE '^#|^id,' "$REG")
if [[ $status -eq 0 ]]; then
  echo "OK: audit-backlog — $total hallazgos registrados, $n_open abiertos con arco; arcos cerrados: ${closed:-ninguno}"
fi
exit $status
