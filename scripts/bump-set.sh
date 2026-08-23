#!/usr/bin/env bash
# bump-set.sh — el ESCRITOR mecánico del set (capa 1 de automatización de docs).
#
# El paraguas siempre tuvo verificadores (manifest-guard exige que
# versions.yaml, los gitlinks y los tags coincidan) pero ningún escritor: cada
# re-pin se transcribía a mano. Este script hace la parte mecánica:
#
#   1. trae tags en los submódulos quark/nucleus/orbit,
#   2. mueve cada submódulo al último tag semver publicado (o al que se pase:
#      bump-set.sh [quark_tag] [nucleus_tag] [orbit_tag]),
#   3. reescribe en versions.yaml: modules (3), orbit_modules (5, leídos del
#      .release-please-manifest.json de orbit AL PIN) y workspace_pins (3,
#      SHAs cortos con el comentario de ancestría regenerado),
#   4. actualiza las versiones de las tablas del README (pilares + módulos de
#      integración).
#
# NO toca: quantum (versión de suite), released, status, notes, CHANGELOG.
# Certificar sigue siendo una decisión humana: sube la versión de suite según
# QADR-0002, redacta notes, mueve las notes anteriores al CHANGELOG (DX-25) y
# corre scripts/suite-integral.sh. manifest-guard sigue siendo el juez.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

latest_tag() { git -C "$1" tag --list 'v*' --sort=-v:refname | head -1; }

for m in quark nucleus orbit; do git -C "$m" fetch --tags --quiet origin; done

QT="${1:-$(latest_tag quark)}"
NT="${2:-$(latest_tag nucleus)}"
OT="${3:-$(latest_tag orbit)}"

for pair in "quark:$QT" "nucleus:$NT" "orbit:$OT"; do
  m="${pair%%:*}"; t="${pair#*:}"
  git -C "$m" checkout --quiet "$t"
  echo "pin: $m → $t ($(git -C "$m" rev-parse --short=8 HEAD))"
done

QS=$(git -C quark rev-parse --short=8 HEAD)
NS=$(git -C nucleus rev-parse --short=8 HEAD)
OS=$(git -C orbit rev-parse --short=8 HEAD)

# Versiones de los módulos de orbit, leídas del manifest AL PIN (no de tags
# sueltos): es lo que el tag del root realmente contiene.
read -r O_PROTO O_AGENT O_SERVER O_QB O_QDS <<<"$(python3 -c "
import json
m=json.load(open('orbit/.release-please-manifest.json'))
print('v'+m['proto'],'v'+m['agent'],'v'+m['server'],'v'+m['quarkbridge'],'v'+m['quarkdatasource'])")"

export QT NT OT QS NS OS O_PROTO O_AGENT O_SERVER O_QB O_QDS
python3 - <<'PY'
import os, re
e=os.environ
p='versions.yaml'; s=open(p).read()
def sub(pat, rep):
    global s
    if not re.search(pat, s, re.M):
        raise SystemExit(f"bump-set: no encontré el patrón {pat!r} en versions.yaml — el formato cambió; ajusta el script")
    s=re.sub(pat, rep, s, count=1, flags=re.M)
sub(r'^(  quark:   )"v[^"]+"', rf'\1"{e["QT"]}"')
sub(r'^(  nucleus: )"v[^"]+"', rf'\1"{e["NT"]}"')
sub(r'^(  orbit:   )"v[^"]+"', rf'\1"{e["OT"]}"')
sub(r'^(  proto:           )"v[^"]+"', rf'\1"{e["O_PROTO"]}"')
sub(r'^(  agent:           )"v[^"]+"', rf'\1"{e["O_AGENT"]}"')
sub(r'^(  server:          )"v[^"]+"', rf'\1"{e["O_SERVER"]}"')
sub(r'^(  quarkbridge:     )"v[^"]+"', rf'\1"{e["O_QB"]}"')
sub(r'^(  quarkdatasource: )"v[^"]+"', rf'\1"{e["O_QDS"]}"')
sub(r'^  quark:   "[0-9a-f]+"( +)#.*$', rf'  quark:   "{e["QS"]}"\1# = {e["QT"]} exacto')
sub(r'^  nucleus: "[0-9a-f]+"( +)#.*$', rf'  nucleus: "{e["NS"]}"\1# = {e["NT"]} exacto')
sub(r'^  orbit:   "[0-9a-f]+"( +)#.*$',
    rf'  orbit:   "{e["OS"]}"\1# = {e["OT"]} exacto (contiene server/{e["O_SERVER"]}, agent/{e["O_AGENT"]}, proto/{e["O_PROTO"]}, quarkbridge/{e["O_QB"]}, quarkdatasource/{e["O_QDS"]} como ancestros — verificado por el manifest-guard §3/§3b en cada corrida de CI)')
open(p,'w').write(s)

p='README.md'; s=open(p).read()
def rsub(pat, rep):
    global s
    if not re.search(pat, s):
        raise SystemExit(f"bump-set: no encontré el patrón {pat!r} en README.md")
    s=re.sub(pat, rep, s, count=1)
rsub(r'`v[\d.]+` \| \[`nucleus/`\]\(nucleus\)', f'`{e["NT"]}` | [`nucleus/`](nucleus)')
rsub(r'`v[\d.]+` \| \[`quark/`\]\(quark\)', f'`{e["QT"]}` | [`quark/`](quark)')
rsub(r'`v[\d.]+` \| \[`orbit/`\]\(orbit\)', f'`{e["OT"]}` | [`orbit/`](orbit)')
rsub(r'(el feed vivo de Orbit \| )`v[\d.]+`', rf'\1`{e["O_QB"]}`')
rsub(r'(el Data Studio de Orbit \| )`v[\d.]+`', rf'\1`{e["O_QDS"]}`')
open(p,'w').write(s)
print('versions.yaml y README reescritos')
PY

echo
echo "Hecho. Te queda la parte HUMANA de la certificación:"
echo "  1. quantum: sube la versión de suite (QADR-0002) + released + status"
echo "  2. mueve las notes del set anterior a CHANGELOG.md y redacta las nuevas (DX-25)"
echo "  3. bash scripts/manifest-guard.sh && bash scripts/suite-integral.sh"
