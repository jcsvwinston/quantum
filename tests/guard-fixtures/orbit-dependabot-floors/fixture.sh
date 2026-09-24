#!/usr/bin/env bash
# Fixture de orbit-dependabot-floors.
#
# Rotura: la entrada de Dependabot de un directorio pierde UNA línea de su
# lista de ignore — la del patrón de hermanos `github.com/jcsvwinston/orbit/*`
# en quarkdatasource, que requiere el hermano `orbit/datasource`.
#
# Es la clase de rotura que el guard existe para cazar, y la que ya ocurrió
# con la ruta desnuda: hasta ADR-012 quarkdatasource requería la RAÍZ de orbit
# y el patrón `/*` no la cubría, así que se quedó con el suelo de su propio
# repositorio sin ignorar. Desde orbit v1.13.0 ningún módulo requiere la raíz
# (el contrato es el módulo `datasource`), así que la línea que muerde es la
# del patrón: sin ella, el `require` de `orbit/datasource` queda sin ignorar.
# No rompe nada: aparece un PR que sube un suelo que nadie decidió, y el set
# se corta alrededor.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

# El guard lee su config y TODOS los go.mod que esa config cubre: la lista
# se deriva de la propia config, para que un módulo nuevo (datasource, con
# orbit v1.13.0) no deje la fixture con un árbol rancio.
gomods=$(awk '$1 == "directory:" { d = $2; gsub(/"/, "", d); print d }' "$ROOT/orbit/.github/dependabot.yml" \
  | sort -u | while read -r d; do
      m="${d#/}/go.mod"; m="${m#/}"
      if [ -f "$ROOT/orbit/$m" ]; then echo "$m"; fi
    done)
# shellcheck disable=SC2086
fx_copy "$ROOT/orbit" "$TREE" \
  scripts/ci/check_dependabot_floors.sh \
  .github/dependabot.yml \
  $gomods

python3 - "$TREE/.github/dependabot.yml" <<'PYEOF'
import re, sys

p = sys.argv[1]
s = open(p, encoding='utf-8').read()
# La linea se borra de la entrada de quarkdatasource, que requiere el hermano
# orbit/datasource: una fixture que no muerde no prueba nada.
i = s.index('directory: /quarkdatasource')
cabeza, cola = s[:i], s[i:]
# Se borra el PATRON de hermanos y queda la ruta desnuda, que es lo que hace
# creible la rotura: la lista sigue pareciendo completa.
cola, n = re.subn(r'(?m)^[ \t]*- dependency-name: github\.com/jcsvwinston/orbit/\*[ \t]*\n', '', cola, count=1)
assert n == 1, 'la fixture no encontro el ignore de hermanos en quarkdatasource'
open(p, 'w', encoding='utf-8').write(cabeza + cola)
PYEOF

fx_assert_doctored "$TREE/.github/dependabot.yml" 'dependency-name: github.com/jcsvwinston/orbit$'

echo "workdir=$TREE"
echo "expect=does not ignore github.com/jcsvwinston/orbit/datasource, required by a module in its scope"
