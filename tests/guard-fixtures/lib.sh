#!/usr/bin/env bash
# lib.sh — helpers compartidos por las fixtures del guard-of-guards.
#
# Contrato de una fixture (tests/guard-fixtures/<guard>/fixture.sh):
#
#   - Se invoca desde la RAÍZ del paraguas: `bash fixture.sh <TMPDIR>`.
#   - Prepara en $TMPDIR/tree una COPIA doctorada del árbol mínimo que el
#     guard valida (patrón overlay: ficheros REALES del repo al pin, incluida
#     la copia del propio script del guard, con UNA rotura concreta).
#   - Imprime por stdout las líneas de protocolo:
#         workdir=<ruta absoluta donde el harness lanzará el comando del guard>
#         expect=<regex grep -E que la salida del guard DEBE contener>
#         env=KEY=VALUE   (OPCIONAL, 0..N líneas)
#     `expect` fija la causa de muerte esperada: si el guard sale !=0 por otra
#     razón (p. ej. un error de setup de la propia fixture), el harness lo
#     trata como fallo — un EXIT!=0 accidental no demuestra que el guard muerde.
#     `env=` (opcional) declara el entorno con el que el harness invoca el guard
#     sobre la copia — para guards con MODOS que solo muerden en cierto entorno
#     (p. ej. check_suite_tag.sh en modo certificación, QUANTUM_CERTIFYING=1).
#     Solo afecta a la subshell de ese guard; sin env= nada cambia (las fixtures
#     existentes son retrocompatibles).
#   - EXIT 0. Cualquier otro EXIT = fixture rota (falla el harness).
#
# Compatibilidad: bash 3.2 (macOS).
set -uo pipefail

# fx_copy <src_root> <dst_root> <ruta-relativa>... — copia rutas concretas
# preservando la estructura de directorios.
fx_copy() {
  local src=$1 dst=$2 p
  shift 2
  for p in "$@"; do
    if [[ ! -e "$src/$p" ]]; then
      echo "fixture: $src/$p no existe (¿cambió el árbol del producto?)" >&2
      return 1
    fi
    mkdir -p "$dst/$(dirname "$p")"
    cp -R "$src/$p" "$dst/$p"
  done
}

# fx_copy_tree <src_root> <dst_root> — copia el árbol completo de un repo,
# menos .git, cachés y artefactos de build (lo que un checkout limpio
# tendría). cp + purga en vez de tar --exclude: los patrones de exclusión de
# bsdtar (macOS) y GNU tar no coinciden, y aquí tiene que portarse igual en
# local y en CI.
fx_copy_tree() {
  local src=$1 dst=$2
  mkdir -p "$dst"
  cp -R "$src/." "$dst/"
  rm -rf "$dst/.git" "$dst/.cache" \
         "$dst/website/node_modules" "$dst/website/build" "$dst/website/.docusaurus"
}

# fx_clone_at <src_repo> <dst> <commit> — clon --shared del repo local (rápido:
# los objetos no se copian) con checkout --detach al commit dado. Trae los tags
# que el repo origen tenga fetcheados — las fixtures que dependen de tags
# necesitan que el submódulo real los tenga (suite/CI los fetchea antes).
fx_clone_at() {
  local src=$1 dst=$2 commit=$3
  git clone --quiet --shared "$src" "$dst" || return 1
  git -C "$dst" checkout --quiet --detach "$commit" || return 1
}

# fx_assert_doctored <fichero> <regex> — la rotura tiene que estar de verdad en
# la copia; si el formato del fichero cambió y el sed/awk de la fixture no
# enganchó, mejor reventar aquí (fixture rota) que dejar pasar un falso verde.
fx_assert_doctored() {
  local f=$1 re=$2
  if ! grep -qE "$re" "$f"; then
    echo "fixture: la rotura no se aplicó — $f no contiene /$re/ (¿cambió el formato del fichero?)" >&2
    return 1
  fi
}
