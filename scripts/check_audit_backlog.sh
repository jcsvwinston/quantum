#!/usr/bin/env bash
# check_audit_backlog.sh — el gate de A1 del plan «Quantum a 5 de 5», y la
# contabilidad de los hallazgos de la auditoría de madurez 2026-09-03.
#
# Lee docs/auditoria/madurez-2026-09-03/registro.csv y falla si:
#   1. un hallazgo con id y severidad en los seis informes no tiene fila;
#   2. una fila abierta no tiene arco (A1…A12) — un hallazgo sin dueño se
#      pierde, que es lo que el registro existe para impedir;
#   3. un arco declarado CERRADO en la primera línea del registro
#      («# arcos_cerrados: A1 …») tiene hallazgos abiertos. Cerrar un arco es
#      añadirlo ahí; este guard dice si se puede. El gate de A1 son cero
#      P1/P2 abiertos: los P3 que queden se reasignan por escrito a otro arco.
# Imprime además cuántos P1/P2/P3 quedan abiertos por arco (información).
#
# Uso: bash scripts/check_audit_backlog.sh   (desde la raíz del paraguas)
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
DIR=docs/auditoria/madurez-2026-09-03
REG="$DIR/registro.csv"
[[ -f "$REG" ]] || { echo "FAIL: falta $REG" >&2; exit 1; }
status=0

closed=$(sed -nE '1s/^# arcos_cerrados:[[:space:]]*//p' "$REG")

# 1. Todo id de los informes tiene fila.
ids_informes=$(grep -hoE '^\| [A-Z]+-?[0-9]+ \| \**P[0-3]\**' "$DIR"/*.md | sed -E 's/^\| ([A-Z]+-?[0-9]+) .*/\1/' | sort -u)
ids_registro=$(grep -vE '^#|^id,' "$REG" | cut -d, -f1 | sort -u)
missing=$(comm -23 <(printf '%s\n' "$ids_informes") <(printf '%s\n' "$ids_registro"))
if [[ -n "$missing" ]]; then
  echo "FAIL: hallazgos de los informes sin fila en registro.csv: $(printf '%s ' $missing)" >&2; status=1
fi
ghost=$(comm -13 <(printf '%s\n' "$ids_informes") <(printf '%s\n' "$ids_registro"))
if [[ -n "$ghost" ]]; then
  echo "FAIL: filas del registro cuyo id no está en ningún informe: $(printf '%s ' $ghost)" >&2; status=1
fi

# 2 y 3. Por fila: arco presente si está abierta; arco cerrado ⇒ hecho.
n_open=0
while IFS=, read -r id sev repo arco estado rest; do
  [[ "$id" == "#"* || "$id" == "id" || -z "$id" ]] && continue
  case "$estado" in
    hecho) continue ;;
    abierto) ;;
    *) echo "FAIL: $id — estado «$estado» no es hecho|abierto" >&2; status=1; continue ;;
  esac
  n_open=$((n_open+1))
  if ! [[ "$arco" =~ ^A([1-9]|1[0-2])$ ]]; then
    echo "FAIL: $id ($sev, $repo) — abierto y sin arco del plan (A1…A12): un hallazgo sin dueño" >&2; status=1
  fi
  for c in $closed; do
    if [[ "$arco" == "$c" ]]; then
      echo "FAIL: $id ($sev, $repo) — sigue abierto y su arco $arco está declarado cerrado" >&2; status=1
    fi
  done
done < "$REG"

for a in A1 A2 A3 A4 A5 A6 A7 A8 A9 A10 A11 A12; do
  line=$(grep -vE '^#|^id,' "$REG" | awk -F, -v a="$a" '$4==a && $5=="abierto" {n[$2]++} END {if (n["P1"]+n["P2"]+n["P3"]>0) printf "P1=%d P2=%d P3=%d", n["P1"], n["P2"], n["P3"]}')
  [[ -n "$line" ]] && echo "INFO: $a abiertos — $line"
done
total=$(grep -cvE '^#|^id,' "$REG")
if [[ $status -eq 0 ]]; then
  echo "OK: audit-backlog — $total hallazgos registrados, $n_open abiertos con arco; arcos cerrados: ${closed:-ninguno}"
fi
exit $status
