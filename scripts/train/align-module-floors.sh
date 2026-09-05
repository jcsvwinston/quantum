#!/usr/bin/env bash
# align-module-floors.sh <nucleus|quark> [--check|--dry-run] [--no-commit]
#                        [--target vX.Y.Z] [--checkout <dir>]
#
# Sube el SUELO que los módulos hermanos de un repo declaran de su propia raíz
# (`require github.com/jcsvwinston/<repo> vX.Y.Z` en drivers/*, providers/*,
# exporters/*) a la versión certificada del set (modules.<repo> de
# versions.yaml) o a la que se pase con --target. Es la mitad que faltaba de
# QM-19 (auditoría 2026-09-03): orbit tiene align_set.sh para sus pines
# cross-repo e internos; nucleus y quark no tenían escritor para este borde y
# los suelos se quedaban varias releases atrás (manifest-guard §5b lo avisa en
# cada corrida: ruido que tapa señal).
#
# Lo que hay que saber antes de usarlo, porque decide CUÁNDO se ejecuta:
#   - El suelo es informativo: MVS resuelve al máximo y un consumidor compila
#     contra la raíz certificada diga lo que diga el go.mod del módulo.
#     manifest-guard §5b AVISA, no falla. Alinear es higiene, no corrección.
#   - Un módulo que requiere su propia raíz NUNCA puede estar al día en el
#     commit que corta esa raíz: el tag no existe todavía. Un suelo una
#     release por detrás es el borde topológico, no un olvido.
#   - El commit es `fix(deps)` a propósito: un `chore` dejaría el módulo con
#     cambios sin tag y manifest-guard §3b rechazaría la raíz siguiente
#     (lección de 1.26.2). Y `fix` significa que release-please corta un
#     patch de CADA módulo tocado (y de la raíz) en el corte siguiente. Por
#     eso se ejecuta AL PRINCIPIO de un corte que va a salir de todas formas
#     —en la rama del trabajo real o justo antes del release PR—, nunca como
#     corte propio: doce tags para mover doce suelos no es un release.
#
# Modos:
#   --check     no toca nada; lista los suelos por detrás y sale 1 si hay
#               alguno (lo que el driver imprime antes de cada repo).
#   --dry-run   imprime los `go mod edit` que haría, sale 0.
#   (default)   reescribe los require, `GOWORK=off go mod tidy` por módulo
#               (necesita red: el target tiene que estar publicado) y commit.
#   --no-commit deja los cambios en el árbol para que el llamante los una a
#               otro commit.
#
# orbit no entra aquí: sus pines internos los escribe
# orbit/scripts/release/align_set.sh (con la excepción topológica de
# quarkdatasource) y los converge orbit-converge.sh.
set -euo pipefail
OWNER=jcsvwinston
Q=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
REPO=""; MODE=write; COMMIT=1; TARGET=""; DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE=check ;;
    --dry-run) MODE=dry ;;
    --no-commit) COMMIT=0 ;;
    --target) shift; TARGET=${1:-} ;;
    --checkout) shift; DIR=${1:-} ;;
    -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
    -*) echo "flag desconocido: $1" >&2; exit 64 ;;
    *) REPO=$1 ;;
  esac
  shift
done
case "$REPO" in
  nucleus|quark) : ;;
  orbit) echo "orbit: usa orbit/scripts/release/align_set.sh (pines cross-repo e internos) y orbit-converge.sh" >&2; exit 64 ;;
  *) echo "uso: align-module-floors.sh <nucleus|quark> [--check|--dry-run] [--no-commit] [--target vX.Y.Z] [--checkout <dir>]" >&2; exit 64 ;;
esac
ROOT_MOD="github.com/$OWNER/$REPO"
[ -n "$TARGET" ] || TARGET=$(sed -nE "s/^  $REPO:[[:space:]]+\"(v[^\"]+)\".*/\1/p" "$Q/versions.yaml" | head -1)
[ -n "$TARGET" ] || { echo "no pude leer modules.$REPO de versions.yaml" >&2; exit 1; }
[ -n "$DIR" ] || DIR="$Q/../$REPO"
DIR=$(cd "$DIR" 2>/dev/null && pwd) || { echo "checkout de $REPO no encontrado: $DIR (usa --checkout)" >&2; exit 1; }
[ -f "$DIR/go.mod" ] || { echo "$DIR no parece el repo $REPO (sin go.mod)" >&2; exit 1; }

# Mismo descubrimiento que manifest-guard: módulos publicables del árbol, sin
# ejemplos, sitio, benchmarks, bugbash ni internal/*.
behind=""; total=0
while IFS= read -r gm; do
  [ -n "$gm" ] || continue
  rel=${gm#$DIR/}; [ "$rel" = "go.mod" ] && continue
  ver=$(awk -v p="$ROOT_MOD" '$1 == p && $NF != "indirect" {print $2}' "$gm")
  [ -n "$ver" ] || continue
  total=$((total+1))
  if [ "$ver" != "$TARGET" ]; then
    behind="$behind ${rel%/go.mod}:$ver"
  fi
done < <(find "$DIR" -name go.mod -not -path '*/.git/*' -not -path '*/examples/*' -not -path '*/website/*' -not -path '*/benchmarks/*' -not -path '*/bugbash/*' -not -path '*/internal/*' | sort)

if [ -z "$(printf '%s' "$behind" | tr -d ' ')" ]; then
  echo "OK: $REPO — los $total módulos hermanos que requieren $ROOT_MOD lo hacen a $TARGET"
  exit 0
fi
n=$(printf '%s\n' $behind | grep -c .)
echo "$REPO — $n de $total suelos por detrás de $TARGET:"
for item in $behind; do echo "  ${item%%:*}  requires $ROOT_MOD ${item#*:}"; done
case "$MODE" in
  check) echo "  (--check: nada tocado; para subirlos, align-module-floors.sh $REPO [--no-commit])"; exit 1 ;;
  dry) for item in $behind; do echo "  → (cd $DIR/${item%%:*} && go mod edit -require=$ROOT_MOD@$TARGET && GOWORK=off go mod tidy)"; done; exit 0 ;;
esac

touched=""
for item in $behind; do
  mod=${item%%:*}
  echo "  → $mod: go mod edit -require=$ROOT_MOD@$TARGET && GOWORK=off go mod tidy"
  (cd "$DIR/$mod" && go mod edit -require="$ROOT_MOD@$TARGET" && GOWORK=off go mod tidy)
  touched="$touched $mod/go.mod"
  [ -f "$DIR/$mod/go.sum" ] && touched="$touched $mod/go.sum"
done
if [ "$COMMIT" -eq 0 ]; then echo "cambios en el árbol sin commit (--no-commit):$touched"; exit 0; fi
mods=$(printf '%s\n' $behind | sed 's/:.*//' | tr '\n' ' ' | sed 's/ $//')
git -C "$DIR" add $touched
git -C "$DIR" commit -q -F - <<MSG
fix(deps): raise the sibling module floors to $REPO $TARGET

$(printf '%s\n' $behind | sed 's|\(.*\):\(.*\)|- \1: \2 → '"$TARGET"'|')

A sibling module's require of its own root is a floor, not a pin: MVS
resolves a consumer against the newest root in the build whatever the
module's go.mod says. Raising it keeps the floor at the certified set so the
umbrella's manifest-guard stops warning about it. fix(deps) on purpose: a
chore would leave the module changed without a tag, and the next root cut
would not certify.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
MSG
echo "commit hecho en $DIR ($(git -C "$DIR" rev-parse --short HEAD)): $mods"
