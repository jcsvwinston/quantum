#!/usr/bin/env bash
# Fixture de orbit-dependabot-floors.
#
# Rotura: la entrada de Dependabot de un directorio pierde UNA línea de su
# lista de ignore — la del propio repositorio, `github.com/jcsvwinston/orbit`,
# en el módulo que la necesita.
#
# Es la rotura exacta que el guard existe para cazar, y la que ya ocurrió: el
# patrón `github.com/jcsvwinston/orbit/*` NO casa con la ruta desnuda
# `github.com/jcsvwinston/orbit`, así que quarkdatasource —el único módulo que
# requiere quark, nucleus y la raíz a la vez— se quedó con el suelo de su
# propio repositorio sin ignorar. No rompe nada: aparece un PR que sube un
# suelo que nadie decidió, y el set se corta alrededor.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

# El guard lee su config y TODOS los go.mod que esa config cubre.
fx_copy "$ROOT/orbit" "$TREE" \
  scripts/ci/check_dependabot_floors.sh \
  .github/dependabot.yml \
  go.mod proto/go.mod agent/go.mod server/go.mod quarkbridge/go.mod quarkdatasource/go.mod

python3 - "$TREE/.github/dependabot.yml" <<'PYEOF'
import re, sys

p = sys.argv[1]
s = open(p, encoding='utf-8').read()
# La linea se borra de la entrada de quarkdatasource, que es el modulo que
# requiere la raiz de orbit: en los demas directorios quitarla no rompe nada
# porque ninguno la requiere, y una fixture que no muerde no prueba nada.
i = s.index('directory: /quarkdatasource')
cabeza, cola = s[:i], s[i:]
# Se borra la ruta DESNUDA y queda la de `/*`, que es lo que hace creible la
# rotura: la lista sigue pareciendo completa.
cola, n = re.subn(r'(?m)^[ \t]*- dependency-name: github\.com/jcsvwinston/orbit[ \t]*\n', '', cola, count=1)
assert n == 1, 'la fixture no encontro el ignore de la raiz en quarkdatasource'
open(p, 'w', encoding='utf-8').write(cabeza + cola)
PYEOF

fx_assert_doctored "$TREE/.github/dependabot.yml" 'dependency-name: github.com/jcsvwinston/orbit/\*'

echo "workdir=$TREE"
echo "expect=does not ignore github.com/jcsvwinston/orbit, required by a module in its scope"
