#!/usr/bin/env bash
# check_quickstart_listings.sh — los listados del quickstart de la suite son
# lo que el scaffold ESCRIBE, comprobado contra un proyecto recién generado.
#
# Hasta el 2026-09-12 la página no copiaba código: sus tres listados eran
# fences ```go file=<rootDir>/examples/showcase_demo/…``` que remark-code-import
# resolvía en build contra el submódulo, y un guard estático
# (`check_quickstart_embeds.sh`) los ataba a su contenido. Con los ejemplos
# fuera del árbol —la suite los retiró hasta cerrar su plan— no queda árbol
# contra el que resolver, así que los listados viven EN la página y la
# comprobación se mueve aquí: a la lane que ya genera el proyecto.
#
# Es la comprobación fuerte, no una sustituta pobre: antes se comparaba la
# página con un fichero comiteado que alguien tenía que regenerar; ahora se
# compara con lo que `nucleus new --template suite` acaba de escribir.
#
# Qué exige, leyendo el front matter `embeds:` de la página (una entrada por
# listado, '<ruta en el proyecto generado>[#Lx-Ly] | token | token…'):
#
#   1. tantas entradas como bloques de código Go tiene la página, en orden
#      (un listado sin entrada es contrabando; una entrada sin listado, una
#      declaración colgante);
#   2. el bloque es IGUAL, línea a línea, al fichero generado (con su rango
#      si lo declara);
#   3. el bloque contiene lo que su entrada declara: `^texto` ata la primera
#      línea, `texto$` la última, cualquier otro token es subcadena literal.
#      Así el rango queda atado a su contenido y no a un número de línea.
#
# Uso: bash scripts/ci/check_quickstart_listings.sh <dir del proyecto generado> [página]
set -uo pipefail
cd "$(dirname "$0")/../.."

PROJECT="${1:?uso: check_quickstart_listings.sh <dir del proyecto generado> [página]}"
PAGE="${2:-website/docs/quickstart.md}"

[[ -d "$PROJECT" ]] || { echo "check_quickstart_listings: $PROJECT no existe" >&2; exit 2; }
[[ -f "$PAGE" ]] || { echo "check_quickstart_listings: $PAGE no existe" >&2; exit 2; }

PROJECT="$PROJECT" PAGE="$PAGE" python3 - <<'PY'
import os, re, sys, textwrap, pathlib

page = pathlib.Path(os.environ["PAGE"])
project = pathlib.Path(os.environ["PROJECT"])
text = page.read_text().split("\n")

# --- front matter: embeds ---
declared, infm, inlist = [], False, False
for i, line in enumerate(text):
    if i == 0 and line == "---":
        infm = True; continue
    if infm and line == "---":
        break
    if not infm:
        break
    if re.match(r"^embeds:\s*$", line):
        inlist = True; continue
    if inlist:
        m = re.match(r"^\s+-\s*(.*)$", line)
        if not m:
            inlist = False; continue
        declared.append(m.group(1).strip().strip("'\""))

if not declared:
    print("check_quickstart_listings: %s no declara `embeds:` — sin manifiesto no se puede decir "
          "si el listado es lo que el scaffold escribe" % page, file=sys.stderr)
    sys.exit(2)

# --- bloques de código Go de la página, en orden ---
blocks, cur, lang = [], None, None
for line in text:
    m = re.match(r"^```(\w*)\s*$", line)
    if m and cur is None:
        lang = m.group(1); cur = []
        continue
    if line.strip() == "```" and cur is not None:
        if lang in ("go", "sql"):
            blocks.append("\n".join(cur))
        cur, lang = None, None
        continue
    if cur is not None:
        cur.append(line)

status = 0
def fail(msg):
    global status
    print("FAIL quickstart-listings: " + msg, file=sys.stderr)
    status = 1

if len(blocks) != len(declared):
    fail("la página tiene %d listados de código y declara %d en `embeds:` — "
         "un listado sin entrada es contrabando y una entrada sin listado, una declaración colgante"
         % (len(blocks), len(declared)))

for entry, block in zip(declared, blocks):
    parts = [p.strip() for p in entry.split("|")]
    ref, tokens = parts[0], parts[1:]
    rng = None
    if "#" in ref:
        ref, frag = ref.split("#", 1)
        m = re.fullmatch(r"L(\d+)-L?(\d+)", frag)
        if not m:
            fail("rango %r ilegible en la entrada %r" % (frag, entry)); continue
        rng = (int(m.group(1)), int(m.group(2)))
    target = project / ref
    if not target.is_file():
        fail("`%s` no está en el proyecto generado: el scaffold ya no escribe el fichero que la página muestra" % ref)
        continue
    want = target.read_text().rstrip("\n").split("\n")
    if rng:
        want = want[rng[0]-1:rng[1]]
    want_text = textwrap.dedent("\n".join(want)).rstrip("\n")
    if block.rstrip("\n") != want_text:
        fail("el listado de `%s` no es lo que el scaffold escribe; regenera el proyecto y pega el fichero "
             "(o el rango declarado) tal cual" % ref)
        continue
    first, last = block.split("\n")[0], block.rstrip("\n").split("\n")[-1]
    for tok in tokens:
        if tok.startswith("^"):
            if not first.startswith(tok[1:]):
                fail("el listado de `%s` debía empezar por %r y empieza por %r" % (ref, tok[1:], first))
        elif tok.endswith("$"):
            if not last.endswith(tok[:-1]):
                fail("el listado de `%s` debía terminar en %r y termina en %r" % (ref, tok[:-1], last))
        elif tok not in block:
            fail("el listado de `%s` no contiene %r, que su entrada de `embeds:` declara" % (ref, tok))

if status == 0:
    print("OK: quickstart-listings — %d listados iguales a lo que el scaffold escribe, con sus anclas" % len(blocks))
sys.exit(status)
PY
