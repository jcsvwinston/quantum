#!/usr/bin/env bash
# check_migration_guide.sh — la guía de migración al 2.0 es lo que generan los avisos al pin.
#
# docs/planes/guia-migracion-2.0.md no la escribe nadie: la produce
# scripts/lib/migration-guide.py con una entrada por aviso de deprecación
# `active` de los tres productos (<repo>/docs/deprecations/DEP-*.md), leídos
# AL PIN —los submódulos tal y como los fija versions.yaml— y en las palabras
# del propio aviso (QADR-0003). Cada re-pin que trae un aviso nuevo, cierra
# uno o le cambia la fecha mueve la fuente, y la guía se queda contando el
# set anterior sin que nada se ponga rojo.
#
# Es lo que pasó: la guía nació el 2026-10-23 (A12 M0-E) con 23 entradas y
# su generador tenía `--check` desde el primer día, pero nadie lo corría —ni
# la certificación ni bump-set—, así que llevó tres sets con 23 entradas
# mientras los avisos activos al pin eran 34; el PR de set de 1.45.0
# (quantum#319) la regeneró a mano. Decisión D14 del propietario
# (2026-11-16): la guía es una página generada más, como las de
# umbrella-generated-pages, y se vigila igual —el generador con --check, que
# la regenera en memoria y falla con la deriva— y se regenera igual:
# bump-set.sh la escribe en cada re-pin y train.sh la cuenta entre las rutas
# del PR de set (RUTAS_REPIN).
#
# Los tres productos tienen docs/deprecations/ al pin (orbit desde 1.42.0) y
# aquí se exige: sin uno de los tres el generador avisa y sigue con menos
# avisos, y una guía regenerada sobre ese árbol sería un verde con un
# producto de menos.
#
# Cuando falle: regenera y commitea:
#   python3 scripts/lib/migration-guide.py --root . --out docs/planes/guia-migracion-2.0.md
# Si lo que está mal es el texto de una entrada, se corrige el AVISO en el
# producto (la guía no se edita: es del generador) y se regenera con el
# re-pin que lo traiga. Dónde se publica la guía en el sitio sigue siendo
# decisión de M1.
#
# Uso: bash scripts/check_migration_guide.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

GUIA=docs/planes/guia-migracion-2.0.md
GENERADOR=scripts/lib/migration-guide.py

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL: migration-guide — python3 no está en el PATH: sin él no hay con qué regenerar la guía para compararla" >&2
  exit 1
fi

for repo in quark nucleus orbit; do
  if [ ! -d "$repo/docs/deprecations" ]; then
    echo "FAIL: migration-guide — falta $repo/docs/deprecations/ (¿git submodule update --init? los tres productos lo tienen al pin desde 1.42.0): sin él la guía se compararía con un producto de menos" >&2
    exit 1
  fi
done

# El veredicto es el del generador: «OK: … al día (N avisos activos)» o
# «FAIL: … no es lo que generan los avisos (N activos); regenera: …», y su
# EXIT (set -e lo propaga).
python3 "$GENERADOR" --root . --out "$GUIA" --check
