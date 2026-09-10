#!/usr/bin/env bash
# Fixture de umbrella-supply-chain. Dos roturas, las dos formas en que la
# cadena de suministro se desarma sin que ninguna corrida se ponga roja:
#
# (A) desaparece el bloque `signs:` de la config de GoReleaser. Es un borrado
#     de cuatro líneas: la release sigue saliendo, con sus binarios y su
#     checksum, y lo único que falta es la firma que nadie mira hasta que la
#     necesita.
#
# (B) el workflow de release conserva el paso de atestación y pierde el
#     permiso `attestations: write`. Es la variante cara: el paso existe, así
#     que la config parece completa, y falla en la corrida del tag — cuando ya
#     no hay marcha atrás sin retirar el tag.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

# El paraguas entró en el guard con quantum#167, así que su workflow de
# release viaja en la copia: sin él la copia moriría por una causa de setup
# además de por las dos roturas declaradas.
fx_copy "$ROOT" "$TREE" scripts/check_supply_chain.sh .github/workflows/release-set.yml
for repo in quark nucleus orbit; do
  fx_copy "$ROOT" "$TREE" "$repo/.goreleaser.yaml" "$repo/.github/workflows/release.yml"
done

# (A) quark se queda sin firma.
python3 - "$TREE/quark/.goreleaser.yaml" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s, n = re.subn(r'(?m)^signs:', '# signs:', s, count=1)
assert n == 1, 'la fixture no encontró el bloque signs: de quark'
open(p, 'w', encoding='utf-8').write(s)
PY

# (B) nucleus conserva el paso y pierde el permiso.
python3 - "$TREE/nucleus/.github/workflows/release.yml" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s, n = re.subn(r'(?m)^([ \t]*)attestations: write[ \t]*$', r'\1# attestations: write', s, count=1)
assert n == 1, 'la fixture no encontró el permiso attestations: write de nucleus'
assert 'actions/attest-build-provenance' in s, 'la fixture quiere el paso INTACTO: es lo que hace creíble la rotura'
open(p, 'w', encoding='utf-8').write(s)
PY

fx_assert_doctored "$TREE/quark/.goreleaser.yaml" '^# signs:'
fx_assert_doctored "$TREE/nucleus/.github/workflows/release.yml" '# attestations: write'

echo "workdir=$TREE"
echo "expect=quark/\.goreleaser\.yaml no declara el bloque .signs:"
echo "expect=nucleus/\.github/workflows/release\.yml no pide .attestations: write"
