#!/usr/bin/env bash
# check_retired_claims.sh — ninguna afirmación RETIRADA en el HTML servido.
#
# Hermano de check_served_jargon.sh: corre tras `npm run build` sobre el HTML
# emitido — lo que el lector VE — y falla si alguna página sigue afirmando
# algo que la suite retiró. La auditoría 2026-09-03 (QM-4/QM-5/C8) encontró el
# sitio sirviendo, en siete páginas de la versión vigente de nucleus, «MSSQL
# and Oracle are opt-in via Go build tags (-tags mssql)» y «ships as a single
# Go module», con la release del set diciendo lo contrario. Un evaluador que
# lee «-tags mssql» y luego `nucleus add mssql` deja de fiarse del resto.
#
# Las frases retiradas, con el arco que las retiró:
#   - `-tags mssql` / `-tags oracle` / «build tags»  → D3 (Quantum 1.26.0):
#     los drivers son módulos (`nucleus add <nombre>`); no hay build tags.
#   - «single Go module»  → nucleus es multi-módulo desde v1.15.0.
#   - «Nine modules»  → el set certifica los módulos de cuatro bloques del
#     manifiesto, no nueve.
# Añadir aquí una frase = retirar una afirmación de la suite; quitarla, nunca
# (si vuelve a ser verdad, es una decisión, no una limpieza).
#
# Fuera del gate, con porqué:
#   - Snapshots VERSIONADOS (/<instancia>/X.Y.Z/…): documentan la versión que
#     nombran, y en ella la afirmación FUE verdad. Historia inmutable
#     (QADR-0003); se vigila lo que se sirve como vigente.
#   - Páginas de release notes (…/reference/release-notes/…): son el sitio
#     legítimo de la narrativa de cambio («-tags mssql are gone» nombra la
#     frase para decir que se fue — docs/ESTILO_DOCS.md, regla 6).
#
# Transición AUTO-EXPIRANTE (mismo mecanismo que el token ADR-010 de
# check_served_jargon.sh): el pin de nucleus ≤ v1.23.0 trae esas frases en su
# doc vigente; se reescriben en nucleus (patch en curso) y el paraguas las
# recibirá al re-pinar. Mientras `modules.nucleus` siga en ≤ v1.23.0 los hits
# bajo /nucleus/ (no versionado) se ignoran con AVISO; al re-pinar, la
# excepción muere sola — sin lista que recordar vaciar.
#
# Verde-vacío vetado (QM8-4): 0 HTML escaneados es FAIL, no «0 hallazgos».
set -uo pipefail

cd "$(dirname "$0")/.."

BUILD_DIR="${1:-website/build}"

if [[ ! -d "$BUILD_DIR" ]]; then
  echo "check_retired_claims: $BUILD_DIR no existe — ejecuta 'npm run build' antes" >&2
  exit 2
fi

REGEX='-tags (mssql|oracle)|build tags|single Go module|Nine modules'

# Transición ligada al pin de nucleus (ver cabecera): activa mientras el pin
# sea ≤ v1.23.0, la última versión cuya doc vigente afirma los build tags.
NUCLEUS_PIN=$(sed -n 's/^  nucleus:[[:space:]]*"\(v[0-9.]*\)".*/\1/p' versions.yaml | head -1)
TRANSITIONAL_MAX='v1.23.0'
transitional=0
if [[ -n "$NUCLEUS_PIN" && "$(printf '%s\n' "$NUCLEUS_PIN" "$TRANSITIONAL_MAX" | sort -V | tail -1)" == "$TRANSITIONAL_MAX" ]]; then
  transitional=1
fi

status=0
count=0
scanned=0
skipped_versioned=0
skipped_notes=0
skipped_transitional=0
while IFS= read -r -d '' f; do
  scanned=$((scanned + 1))
  rel=${f#"$BUILD_DIR"/}
  # Snapshots versionados: historia, fuera del gate.
  if [[ "$rel" =~ ^(nucleus|quark|orbit)/[0-9]+\.[0-9]+\.[0-9]+/ ]]; then
    skipped_versioned=$((skipped_versioned + 1))
    continue
  fi
  # Release notes: narrativa de cambio legítima.
  if [[ "$rel" == *"/reference/release-notes/"* ]]; then
    skipped_notes=$((skipped_notes + 1))
    continue
  fi
  out=$(grep -noiE -e "$REGEX" "$f" | head -3 || true)
  [[ -n "$out" ]] || continue
  if [[ $transitional -eq 1 && "$rel" == nucleus/* ]]; then
    skipped_transitional=$((skipped_transitional + 1))
    continue
  fi
  if [[ $status -eq 0 ]]; then
    echo "Afirmaciones retiradas en el HTML servido:" >&2
    echo >&2
  fi
  status=1
  count=$((count + 1))
  printf '  %s\n%s\n' "$f" "$(sed 's/^/    /' <<<"$out")" >&2
done < <(find "$BUILD_DIR" -name '*.html' -print0)

if [[ $status -ne 0 ]]; then
  echo >&2
  echo "$count página(s) servidas afirman lo retirado (build tags, single Go module, Nine modules…)." >&2
  echo "La fuente está en el repo del producto (website/docs) o en website/docs del" >&2
  echo "paraguas: reescríbela allí — este check no se pasa editando el HTML." >&2
  exit 1
fi

if [[ $scanned -eq 0 ]]; then
  echo "FAIL: 0 ficheros HTML escaneados en $BUILD_DIR — build vacío o ruta equivocada; un «0 hallazgos» sin superficie escaneada es verde-vacío, no un veredicto (QM8-4)" >&2
  exit 1
fi

if [[ $transitional -eq 1 && $skipped_transitional -gt 0 ]]; then
  echo "AVISO: $skipped_transitional página(s) de la doc vigente de nucleus afirman lo retirado — toleradas mientras modules.nucleus ($NUCLEUS_PIN) sea ≤ $TRANSITIONAL_MAX (la reescritura va en nucleus; al re-pinar, esta excepción muere sola)"
fi
echo "OK: 0 afirmaciones retiradas en el HTML servido como vigente ($scanned HTML escaneados en $BUILD_DIR; $skipped_versioned de snapshots versionados y $skipped_notes de release notes fuera del gate)"
