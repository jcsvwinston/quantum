#!/usr/bin/env bash
# check_tag_grammar.sh — ningún modelo escribe el tag `db` en la gramática de
# la OTRA capa de datos.
#
# El problema que cierra (NU-50, medido en A4/S0). Quark y `pkg/model` de
# nucleus leen los dos un tag llamado `db` y no coinciden en qué lleva dentro:
#
#   quark    db:"email,size=255"        el tag es el NOMBRE de la columna, con
#                                       opciones por COMAS; las directivas van
#                                       en quark:"…" y la clave en pk:"true"
#   nucleus  db:"column:email;unique"   el tag son DIRECTIVAS por PUNTO Y COMA,
#                                       y el nombre es una de ellas
#
# Las dos son correctas EN SU REPO. El defecto es cruzarlas: dado un modelo
# escrito a la manera de nucleus, quark creaba una columna llamada literalmente
# `column:email;unique;not null`, sin error y sin aviso. Al revés, nucleus
# recuperaba los nombres por casualidad —snake-casea el campo Go— y perdía
# `size=` con sólo un WARN de arranque.
#
# Desde A4/S6 cada producto lo detecta al registrar el modelo. Este guard lo
# comprueba en el ÁRBOL, que es lo que ninguna corrida enseña: un modelo con la
# gramática cambiada puede vivir en un fichero que nadie ejecuta.
#
# Sólo mira TAGS DE VERDAD —los que van entre acentos graves en la definición
# de un campo—, no las menciones en comentarios y mensajes de error, que
# abundan precisamente en el código que implementa estas reglas. Los ficheros
# _test.go quedan fuera: las pruebas de esta defensa necesitan escribirlos mal.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

fail=0
report() { echo "FAIL: tag-grammar — $1" >&2; fail=1; }

# tags_in <repo> imprime "fichero:línea:valor" por cada db:"…" que aparezca
# dentro de un tag de campo (entre acentos graves).
tags_in() {
  # La línea tiene que ser una DEFINICIÓN DE CAMPO: sangría, nombre exportado,
  # tipo y el tag entre acentos graves. Sin eso, el propio código que
  # implementa estas reglas se denuncia a sí mismo — sus mensajes de ayuda
  # citan las dos gramáticas, con acentos graves incluidos.
  grep -rEn --include='*.go' '^[[:space:]]+[A-Z][A-Za-z0-9_]*[[:space:]]+[^[:space:]]+[[:space:]]+`[^`]*db:"[^"]*"[^`]*`' "$1" 2>/dev/null \
    | grep -v '_test\.go:' \
    | sed -E 's/^([^:]+):([0-9]+):.*`[^`]*db:"([^"]*)"[^`]*`.*/\1:\2:\3/'
}

# En quark el tag db es un NOMBRE de columna con opciones por comas.
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  file=${hit%%:*}; rest=${hit#*:}; line=${rest%%:*}; tag=${rest#*:}
  [ "$tag" = "-" ] && continue
  col=${tag%%,*}
  case "$col" in
    *[!A-Za-z0-9_]*)
      report "$file:$line — db:\"$tag\": \"$col\" no puede ser un nombre de columna. En quark el tag db lleva el nombre; las directivas van en quark:\"…\" y la clave en pk:\"true\"" ;;
  esac
done < <(tags_in quark)

# En nucleus el tag db son DIRECTIVAS por punto y coma. Las opciones de
# dimensionado son de quark y aquí no hacen nada.
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  file=${hit%%:*}; rest=${hit#*:}; line=${rest%%:*}; tag=${rest#*:}
  [ "$tag" = "-" ] && continue
  case "$tag" in
    *size=*|*precision=*|*scale=*)
      report "$file:$line — db:\"$tag\" lleva opciones de dimensionado, que son la gramática de quark. En pkg/model el tag son directivas por punto y coma: db:\"column:<name>;…\"" ;;
  esac
done < <(tags_in nucleus)

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "OK: tag-grammar — ningún modelo mezcla las gramáticas del tag db"
