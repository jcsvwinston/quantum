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
#   3. reescribe en versions.yaml: modules (3) y los bloques de módulos
#      hermanos (quark_modules, nucleus_modules, orbit_modules — REGENERADOS
#      enteros desde el .release-please-manifest.json del repo AL PIN, no de
#      tags sueltos) y workspace_pins (3 SHAs cortos, con el comentario de
#      ancestría regenerado desde el manifiesto completo: TODOS los módulos
#      hermanos que el tag de la raíz contiene, no solo uno),
#   4. actualiza las versiones de las tablas del README (pilares + los cinco
#      módulos hermanos de orbit).
#
#   5. (scripts/lib/set-notes.py) calcula la versión de SUITE por QADR-0002
#      desde el salto real de los pilares, escribe released y el comentario
#      de status, mueve las notes anteriores a CHANGELOG.md (DX-25) y deja un
#      ESQUELETO de notes con los movimientos del set y marcadores REDACTAR,
#      que manifest-guard §0 rechaza hasta que alguien los redacte. Hasta
#      1.27.0 esto se hacía a mano, y en 1.26.1 un recorte a offset rancio se
#      llevó la clave declared_lags. `--set X.Y.Z` fuerza el número (corte
#      deliberado); `--sin-notas` deja los pasos 1-4 solos.
#
# Certificar sigue siendo una decisión humana: redactar las notes (sustituir
# cada REDACTAR) y correr scripts/suite-integral.sh. manifest-guard sigue
# siendo el juez.
#
# Uso: bump-set.sh [quark_tag] [nucleus_tag] [orbit_tag] [--set X.Y.Z] [--sin-notas]
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

latest_tag() { git -C "$1" tag --list 'v*' --sort=-v:refname | head -1; }

for m in quark nucleus orbit; do git -C "$m" fetch --tags --quiet origin; done

SET_OVERRIDE=""; NOTES=1; POS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --set) shift; SET_OVERRIDE="${1:-}" ;;
    --set=*) SET_OVERRIDE="${1#--set=}" ;;
    --sin-notas) NOTES=0 ;;
    -h|--help) sed -n '2,36p' "$0"; exit 0 ;;
    -*) echo "bump-set: flag desconocido: $1" >&2; exit 64 ;;
    *) POS="$POS $1" ;;
  esac
  shift
done
set -- $POS
QT="${1:-$(latest_tag quark)}"
NT="${2:-$(latest_tag nucleus)}"
OT="${3:-$(latest_tag orbit)}"

# El estado ANTES del re-pin, para que set-notes.py calcule el salto de suite
# y mueva las notes vigentes al CHANGELOG (se captura antes de tocar nada).
OLD_STATE=$(mktemp); trap 'rm -f "$OLD_STATE"' EXIT
python3 scripts/lib/set-notes.py --capture > "$OLD_STATE"

for pair in "quark:$QT" "nucleus:$NT" "orbit:$OT"; do
  m="${pair%%:*}"; t="${pair#*:}"
  git -C "$m" checkout --quiet "$t"
  echo "pin: $m → $t ($(git -C "$m" rev-parse --short=8 HEAD))"
done

QS=$(git -C quark rev-parse --short=8 HEAD)
NS=$(git -C nucleus rev-parse --short=8 HEAD)
OS=$(git -C orbit rev-parse --short=8 HEAD)

# Versiones de los módulos de orbit, leídas del manifest AL PIN (no de tags
# sueltos): es lo que el tag del root realmente contiene. Se usan para las
# filas de la tabla de orbit del README.
read -r O_PROTO O_AGENT O_SERVER O_QB O_QDS <<<"$(python3 -c "
import json
m=json.load(open('orbit/.release-please-manifest.json'))
print('v'+m['proto'],'v'+m['agent'],'v'+m['server'],'v'+m['quarkbridge'],'v'+m['quarkdatasource'])")"

# Comentario de ancestría del pin de un repo: TODOS los módulos hermanos del
# manifiesto al pin, con la versión que ese manifiesto declara. Hasta la
# auditoría 2026-09-03 (QM-8) el comentario de nucleus nombraba solo
# providers/ldap con doce módulos en el tag, y el de quark ninguno con cinco.
# El tag de cada módulo DEBE salir del mismo commit que el de la raíz
# (manifest-guard §3b: un tag de módulo cortado después del de la raíz no es
# certificable), y eso es exactamente lo que este comentario afirma.
pin_comment() {
  local repo=$1 tag=$2
  python3 - "$repo" "$tag" <<'PYEOF'
import json, sys
repo, tag = sys.argv[1], sys.argv[2]
man = json.load(open(f'{repo}/.release-please-manifest.json'))
mods = [f'{k}/v{v}' for k, v in sorted(man.items()) if k != '.']
if not mods:
    print(f'= {tag} exacto')
else:
    print(f'= {tag} exacto (contiene {", ".join(mods)} como ancestros — tags cortados en el MISMO commit o antes, que es lo que permite certificar cada módulo: manifest-guard §3/§3b lo verifica en cada corrida de CI)')
PYEOF
}

# Los bloques de módulos hermanos se REGENERAN enteros, no se parchean línea a
# línea: un módulo nuevo tiene que aparecer solo. Escribir aquí una lista fija
# es el fallo que dejó once módulos en el árbol sin entrada en release-please
# —existían, y nada de lo que enumera módulos lo sabía—. Las versiones se
# leen del manifiesto AL PIN, no del último tag publicado (manifest-guard §3b).
regen_module_block() {
  local repo=$1 section=$2
  python3 - "$repo" "$section" <<'PYEOF'
import json, re, sys, subprocess
repo, section = sys.argv[1], sys.argv[2]
man = json.load(open(f'{repo}/.release-please-manifest.json'))
mods = {k: v for k, v in man.items() if k != '.'}
if not mods:
    sys.exit(0)
# Las versiones se leen del manifiesto AL PIN, no del último tag publicado:
# el tag del módulo debe salir del MISMO commit que el de la raíz
# (manifest-guard §3b), y el manifiesto del pin es lo que lo afirma.
width = max(len(k.split('/')[-1]) for k in mods) + 1
lines = [f'  {k.split("/")[-1] + ":":<{width}} "v{v}"' for k, v in sorted(mods.items())]
s = open('versions.yaml').read()
pat = re.compile(rf'^{section}:\n(?:  \S+:.*\n)+', re.M)
if not pat.search(s):
    raise SystemExit(f"bump-set: no encontré el bloque {section}: en versions.yaml")
s = pat.sub(section + ':\n' + '\n'.join(lines) + '\n', s, count=1)
open('versions.yaml', 'w').write(s)
print(f"  {section}: {len(lines)} módulos")
PYEOF
}

Q_COMMENT=$(pin_comment quark "$QT")
N_COMMENT=$(pin_comment nucleus "$NT")
O_COMMENT=$(pin_comment orbit "$OT")

export QT NT OT QS NS OS O_PROTO O_AGENT O_SERVER O_QB O_QDS Q_COMMENT N_COMMENT O_COMMENT
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
sub(r'^  quark:   "[0-9a-f]+"( +)#.*$', rf'  quark:   "{e["QS"]}"\1# {e["Q_COMMENT"]}')
sub(r'^  nucleus: "[0-9a-f]+"( +)#.*$', rf'  nucleus: "{e["NS"]}"\1# {e["N_COMMENT"]}')
sub(r'^  orbit:   "[0-9a-f]+"( +)#.*$', rf'  orbit:   "{e["OS"]}"\1# {e["O_COMMENT"]}')
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
# La tabla única de módulos de orbit (QM-15): una fila por hermano, con su
# versión — las mismas filas que manifest-guard §4b contrasta.
for mod, ver in (('proto', e["O_PROTO"]), ('agent', e["O_AGENT"]), ('server', e["O_SERVER"]),
                 ('quarkbridge', e["O_QB"]), ('quarkdatasource', e["O_QDS"])):
    rsub(rf'(\[`orbit/{mod}`\]\(orbit/{mod}\) \| [^|]+\| )`v[\d.]+`', rf'\1`{ver}`')
rsub(r'(\[`orbit/`\]\(orbit\) \(raíz\) \| [^|]+\| )`v[\d.]+`', rf'\1`{e["OT"]}`')
open(p,'w').write(s)
print('versions.yaml y README reescritos')
PY

# Los bloques de modulos hermanos, DESPUES de los pines: se leen del
# manifiesto al pin, asi que el submodulo tiene que estar ya en el tag.
regen_module_block nucleus nucleus_modules
regen_module_block quark quark_modules

echo
if [ "$NOTES" -eq 1 ]; then
  # Versión de suite, released, status, notes anteriores al CHANGELOG y el
  # esqueleto de las nuevas — DESPUÉS de todo lo demás, sobre el fichero ya
  # re-pinado (set-notes.py recalcula el corte de las notes en ese momento).
  if [ -n "$SET_OVERRIDE" ]; then
    python3 scripts/lib/set-notes.py --old "$OLD_STATE" --set "$SET_OVERRIDE"
  else
    python3 scripts/lib/set-notes.py --old "$OLD_STATE"
  fi
  echo
  echo "Hecho. Queda lo HUMANO de la certificación:"
  echo "  1. redacta las notes de versions.yaml: sustituye cada REDACTAR (manifest-guard §0 lo"
  echo "     rechaza) y revisa el título de la entrada nueva de CHANGELOG.md"
  echo "  2. QUANTUM_ALLOW_NOTES_SKELETON=1 bash scripts/manifest-guard.sh  (mientras redactas)"
  echo "  3. bash scripts/manifest-guard.sh && bash scripts/suite-integral.sh"
else
  echo "Hecho (--sin-notas). Te queda la parte HUMANA de la certificación:"
  echo "  1. quantum: sube la versión de suite (QADR-0002) + released + status"
  echo "  2. mueve las notes del set anterior a CHANGELOG.md y redacta las nuevas (DX-25)"
  echo "  3. bash scripts/manifest-guard.sh && bash scripts/suite-integral.sh"
fi
