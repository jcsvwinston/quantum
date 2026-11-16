#!/usr/bin/env bash
# Fixture de umbrella-migration-guide. Una rotura, la del caso real que
# motivó el guard (D14, 2026-11-16): el pin trae un aviso de deprecación
# `active` que la guía no tiene. Es lo que pasa en cada re-pin que publica
# un aviso nuevo —así se quedó la guía tres sets en 23 entradas con 34
# avisos activos al pin—, y lo que bump-set regenera ahora en cada re-pin.
#
# Se añade a la copia de nucleus un aviso DEP-2026-099 con la cabecera que
# el generador parsea (ID, Status `active`, la viñeta de ventana «Earliest
# removal», Scope) y las secciones que lleva todo aviso (Summary, Migration
# Path, Detection, What breaks if this is ignored), con la forma exacta de
# un aviso real (DEP-2026-023 de nucleus). La guía copiada deja de ser lo
# que el generador produce sobre esa copia.
#
# El árbol parte del guard, del generador, de la guía y de los tres
# docs/deprecations/ REALES al pin; el guard pasa sobre la copia sin
# doctorar, así que el EXIT!=0 es atribuible al aviso añadido. La causa
# esperada lleva la cifra de avisos activos de la copia doctorada (los del
# pin más uno), contada aquí con el mismo criterio que el generador (la
# viñeta Status): si el generador dejara de contar el aviso nuevo como
# activo, la cifra no casaría y el harness lo trataría como causa
# equivocada, no como mordida.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" \
  scripts/check_migration_guide.sh scripts/lib/migration-guide.py \
  docs/planes/guia-migracion-2.0.md \
  quark/docs/deprecations nucleus/docs/deprecations orbit/docs/deprecations

# Sin doctorar, el guard pasa: si no, el EXIT!=0 de abajo no demostraría nada.
if ! (cd "$TREE" && bash scripts/check_migration_guide.sh >/dev/null 2>&1); then
  echo "fixture: el guard ya falla sobre la copia SIN doctorar — regenera la guía (python3 scripts/lib/migration-guide.py --root . --out docs/planes/guia-migracion-2.0.md) antes de probar la mordida" >&2
  (cd "$TREE" && bash scripts/check_migration_guide.sh) >&2 || true
  exit 1
fi

# La rotura: un aviso `active` más en nucleus, que la guía copiada no tiene.
aviso="$TREE/nucleus/docs/deprecations/DEP-2026-099-fixture-umbrella-migration-guide.md"
cat >"$aviso" <<'MD'
# Deprecation Notice: a notice the guide does not have (fixture of umbrella-migration-guide)

- ID: `DEP-2026-099`
- Status: `active`
- Announced in: `v1.36.0` (fixture)
- Earliest removal: `v2.0.0`, no earlier than 2027-02-07 — major-only per
  `docs/governance/DEPRECATION_TEMPLATE.md` and the suite's deprecation policy.
- Scope: `api`
- Affected lifecycle tag: `stable`

## Summary

A notice the committed guide does not have. The fixture of the umbrella guard
`umbrella-migration-guide` adds it to the doctored copy so that the guide stops
being what the generator produces from the notices.

## Affected Surfaces

- None: the notice exists only in the doctored copy.

## Migration Path

- Replacement: none.
- Behavior differences: none.
- Required app changes: none.

## Detection

- Detection rule: `grep -rn 'DEP-2026-099'`.

## What breaks if this is ignored

Nothing: the notice is a fixture.
MD
fx_assert_doctored "$aviso" '^- Status: `active`$'
fx_assert_doctored "$aviso" '^- Earliest removal: `v2\.0\.0`, no earlier than 2027-02-07'

# La cifra que el guard tiene que decir: los avisos `active` de la copia
# doctorada, contados con el mismo criterio que el generador (la viñeta
# Status de la cabecera). Al pin de 1.45.0 son 34, más el de la fixture.
n=$(grep -l '^- Status: `active`' \
      "$TREE"/quark/docs/deprecations/DEP-*.md \
      "$TREE"/nucleus/docs/deprecations/DEP-*.md \
      "$TREE"/orbit/docs/deprecations/DEP-*.md | wc -l | tr -d ' ')
[[ "$n" -gt 1 ]] || { echo "fixture: la copia cuenta $n avisos activos — ¿cambió la forma de la viñeta Status?" >&2; exit 1; }

echo "workdir=$TREE"
echo "expect=FAIL: docs/planes/guia-migracion-2\.0\.md no es lo que generan los avisos \($n activos\)"
