#!/usr/bin/env bash
# dispatch-app-bump.sh — última pieza mecánica del tren: avisa al consumidor
# EXTERNO de referencia (quantum-app) de que hay set certificado, y le pasa el
# bloque require que scripts/print-requires.sh deriva de versions.yaml.
#
# Por qué (RT-5 / decisión D6 de la auditoría, QADR-0008): quantum-app se
# describe como «reference application consuming the Quantum suite as a real
# external integrator», pero mientras su bump fue manual se quedó pinado al
# set 1.10.0 con el set vigente en 1.24.0. Catorce sets sin que ningún
# consumidor externo compilara contra ellos: la validación externa del set
# certificado no existía. Este script la vuelve mecánica.
#
# Qué NO hace: no reescribe nada en quantum-app ni fusiona nada. Manda un
# repository_dispatch; el workflow de allí (.github/workflows/set-bump.yml)
# reescribe el pin, corre SUS gates y abre un PR que un humano revisa. Los
# rojos de ese PR son deuda de quantum-app contra el set, no de este script.
#
# Como el resto de scripts/train/, es un ESCRITOR/CONDUCTOR, no un guard: no
# está en el registro de guards ni en el escaneo anti-fósil.
#
# Uso: dispatch-app-bump.sh [--dry-run] [--repo owner/nombre] [--sin-tag]
#   --dry-run   imprime la llamada exacta sin mandarla.
#   --repo      repositorio destino (por defecto jcsvwinston/quantum-app).
#   --sin-tag   no exigir que el tag de suite exista ya en origin (para
#               ensayar un set antes de cortarlo; el tren normal NO lo usa).
set -euo pipefail
cd "$(dirname "$0")/../.."

DRY=0
REPO="jcsvwinston/quantum-app"
EXIGE_TAG=1
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --repo) shift; REPO="${1:-}" ;;
    --sin-tag) EXIGE_TAG=0 ;;
    -h|--help) sed -n '2,28p' "$0"; exit 0 ;;
    *) echo "dispatch-app-bump.sh: argumento desconocido: $1 (ver --help)" >&2; exit 64 ;;
  esac
  shift
done

die() { echo "dispatch-app-bump.sh: $*" >&2; exit 1; }

# ---- 1. el set que vamos a anunciar ----------------------------------------
VER=$(sed -nE 's/^quantum:[[:space:]]+"([^"]+)".*/\1/p' versions.yaml | head -1)
[ -n "$VER" ] || die "no pude leer la versión de suite de versions.yaml"
ESTADO=$(sed -nE 's/^status:[[:space:]]+([a-z-]+).*/\1/p' versions.yaml | head -1)
[ "$ESTADO" = "certified" ] \
  || die "versions.yaml declara status: '${ESTADO:-?}' — solo se anuncia un set CERTIFICADO (el bump del consumidor externo sigue al set, no al mid-tren)"

if [ "$EXIGE_TAG" -eq 1 ]; then
  git fetch --tags --quiet origin || true
  git rev-parse -q --verify "refs/tags/v$VER" >/dev/null \
    || die "no existe el tag de suite v$VER — el anuncio va DESPUÉS del tag (fase cierre). Con --sin-tag se puede ensayar."
fi

REQUIRES=$(bash scripts/print-requires.sh) || die "print-requires.sh falló — sin bloque require no hay nada que anunciar"

echo "== anuncio del set certificado Quantum $VER a $REPO =="
printf '%s\n' "$REQUIRES" | sed 's/^/  /'
echo
echo "  → gh api repos/$REPO/dispatches -f event_type=quantum-set-certified \\"
echo "        -f 'client_payload[set]=$VER' -f 'client_payload[requires]=<bloque de arriba>'"

if [ "$DRY" -eq 1 ]; then
  echo
  echo "DRY-RUN: no se ha mandado nada."
  exit 0
fi

# ---- 2. el dispatch --------------------------------------------------------
gh api "repos/$REPO/dispatches" \
  -f event_type=quantum-set-certified \
  -f "client_payload[set]=$VER" \
  -f "client_payload[requires]=$REQUIRES" \
  || die "el dispatch a $REPO falló. Relánzalo cuando esté resuelto:
    bash scripts/train/dispatch-app-bump.sh
  o dispara el bump a mano desde la pestaña Actions de $REPO
  (workflow «Bump al set certificado», con set=$VER y el bloque require de
  scripts/print-requires.sh)."

echo "OK: anunciado. El workflow de $REPO reescribe el pin, corre sus gates y"
echo "abre el PR del bump — que NO se fusiona solo:"
echo "  gh run list -R $REPO --workflow 'Bump al set certificado' --limit 3"
echo "  gh pr list -R $REPO --head chore/set-$VER"
