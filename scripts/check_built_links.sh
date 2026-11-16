#!/usr/bin/env bash
# check_built_links.sh — los enlaces del sitio CONSTRUIDO resuelven de verdad.
#
# Docusaurus verifica sus enlaces internos (onBrokenLinks: throw) y sus anclas,
# pero NO mira los `<a href="https://…">`: un enlace a nuestros propios repos
# puede apuntar a una ruta que no existe y el build sale verde. Así vivieron
# meses los 206 enlaces «Edit this page» del sitio publicado, rotos en las tres
# instancias por una plantilla de editUrl equivocada — los vio un humano
# navegando, no el CI.
#
# Este guard cierra esa clase. Sobre el HTML construido:
#
#   1. extrae cada href a github.com/jcsvwinston/<repo>/{blob,tree,edit}/main/<ruta>,
#   2. resuelve <ruta> contra el CHECKOUT LOCAL de ese repo (el submódulo al
#      pin) y falla si el fichero o directorio no existe,
#   3. comprueba también los enlaces internos absolutos (/quantum/...) contra
#      los ficheros generados, por si una ruta se escapa del router,
#   4. y busca en los chunks de contenido compilados (assets/js/*.js menos los
#      bundles de runtime main.* y runtime~main.*) cualquier `href:"…"` RELATIVO
#      (sin `/`, `#` ni esquema): un enlace de MDX que Docusaurus no resolvió a
#      su ruta final queda relativo en el bundle y el router lo resuelve contra
#      la URL ACTUAL — desde la forma con barra con la que GitHub Pages sirve
#      toda entrada directa cae en Page Not Found, mientras el HTML estático
#      lleva el href correcto (el servidor lo resolvió sin barra). Así vivieron
#      los 129 enlaces `guides/x` de la doc de quark y los 2 085 de sus
#      snapshots hasta el 2026-11-16 (QM-45); el ensamblaje los resuelve ahora
#      (remarkResolveRelativeDocLinks en website/docusaurus.config.ts) y esta
#      comprobación es la que ve la clase, porque ningún lector del HTML puede.
#
# La verificación es contra el árbol, NO por red: es determinista, funciona sin
# credenciales y no dispara el rate-limit de GitHub (429), que es exactamente lo
# que arruina el chequeo ingenuo con curl en paralelo.
#
# Uso: bash scripts/check_built_links.sh [build_dir]   (default website/build)
set -uo pipefail

BUILD_DIR="${1:-website/build}"
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if [ ! -d "$BUILD_DIR" ]; then
  echo "FAIL: no existe el directorio construido $BUILD_DIR — construye el sitio antes (cd website && npm run build)."
  exit 1
fi

html_count=$(find "$BUILD_DIR" -name '*.html' | wc -l | tr -d ' ')
if [ "$html_count" -eq 0 ]; then
  echo "FAIL: $BUILD_DIR no contiene HTML: un verde aquí sería vacío, no un veredicto."
  exit 1
fi

BUILD_DIR="$BUILD_DIR" ROOT="$ROOT" python3 - <<'PY'
import html
import os
import re
import sys
import urllib.parse

build = os.environ["BUILD_DIR"]
root = os.environ["ROOT"]

# Checkout local de cada repo propio. En el paraguas son submódulos al pin.
repos = {name: os.path.join(root, name) for name in ("quark", "nucleus", "orbit")}
repos["quantum"] = root

repo_links = {}   # (repo, ruta) -> página que lo emite
internal = {}     # ruta /quantum/... -> página que lo emite

repo_re = re.compile(
    r'href="https://github\.com/jcsvwinston/(quark|nucleus|orbit|quantum)/(blob|tree|edit)/main/([^"#?]+)')
href_re = re.compile(r'href="(/quantum/[^"#?]*)"')

pages = 0
for dirpath, _dirnames, filenames in os.walk(build):
    for filename in filenames:
        if not filename.endswith(".html"):
            continue
        pages += 1
        path = os.path.join(dirpath, filename)
        page = "/" + os.path.relpath(path, build)
        try:
            content = open(path, encoding="utf-8", errors="ignore").read()
        except OSError as exc:
            print(f"FAIL: no se pudo leer {path}: {exc}")
            sys.exit(1)
        for repo, _kind, target in repo_re.findall(content):
            target = urllib.parse.unquote(html.unescape(target))
            repo_links.setdefault((repo, os.path.normpath(target)), page)
        for link in href_re.findall(content):
            internal.setdefault(html.unescape(link), page)

# Una página de documentación ARCHIVADA (/nucleus/1.15.0/…, /orbit/1.9.0/…)
# es una copia congelada de lo que la doc decía cuando se cortó ese snapshot,
# y la política de los tres repos es que no se reescribe: un snapshot que se
# corrigiera afirmaría que la doc de hoy fue la de entonces, que es justo lo
# que el mecanismo existe para impedir. Así que un enlace suyo a una ruta que
# el repo YA NO tiene —`examples/` salió del árbol de nucleus el 2026-09-12—
# no es arreglable en su origen, y exigirlo pondría la lane roja para siempre
# sin nada que hacer al respecto.
#
# Se informan igual, como AVISO con su página, para que no desaparezcan de la
# vista: lo que NO hacen es tumbar la certificación. Los enlaces de la doc
# VIVA, que es la que sí se puede arreglar, siguen siendo FAIL.
archived_re = re.compile(r'^/(quark|nucleus|orbit)/\d+\.\d+(\.\d+)?/')

broken_repo = []
archived_broken = []
for (repo, target), page in sorted(repo_links.items()):
    checkout = repos[repo]
    if not os.path.isdir(checkout):
        # Sin el submódulo inicializado no podemos afirmar nada: mejor decirlo
        # que dar un verde que no comprobó nada.
        print(f"FAIL: el checkout de {repo} no está disponible en {checkout} "
              f"(git submodule update --init) — el guard no puede verificar sus enlaces.")
        sys.exit(1)
    if not os.path.exists(os.path.join(checkout, target)):
        if archived_re.match(page):
            archived_broken.append((repo, target, page))
        else:
            broken_repo.append((repo, target, page))

# 4. href relativos en el MDX compilado. Se leen los bundles, no el HTML: el
# HTML lleva el href absoluto que el servidor resolvió (sin barra) y oculta la
# clase; el bundle lleva la cadena que el router usará en el cliente.
href_js_re = re.compile(r'href:"([^"\\]*)"')
scheme_re = re.compile(r'^[a-z][a-z0-9+.\-]*:', re.IGNORECASE)
compiled_relative = {}   # href relativo -> bundle que lo emite
# Sólo los chunks de contenido: `main.*.js` y `runtime~main.*.js` son React,
# el router y el runtime de webpack, y llevan literales como el
# `href:"image"` de la precarga de imágenes de React DOM, que no es un enlace.
js_dir = os.path.join(build, "assets", "js")
if os.path.isdir(js_dir):
    for filename in sorted(os.listdir(js_dir)):
        if not filename.endswith(".js"):
            continue
        if filename.startswith(("main.", "runtime~main.")):
            continue
        try:
            content = open(os.path.join(js_dir, filename), encoding="utf-8", errors="ignore").read()
        except OSError as exc:
            print(f"FAIL: no se pudo leer {filename}: {exc}")
            sys.exit(1)
        for href in href_js_re.findall(content):
            if not href or href.startswith(("/", "#", "?")) or scheme_re.match(href):
                continue
            compiled_relative.setdefault(href, filename)

broken_internal = []
for link, page in sorted(internal.items()):
    rel = link[len("/quantum/"):].rstrip("/")
    candidates = [
        os.path.join(build, rel),
        os.path.join(build, rel, "index.html"),
        os.path.join(build, rel + ".html"),
    ]
    if rel == "":
        candidates = [os.path.join(build, "index.html")]
    if not any(os.path.exists(c) for c in candidates):
        broken_internal.append((link, page))

for repo, target, page in archived_broken:
    print(f"AVISO: {repo}: la ruta {target!r} ya no existe — enlazada desde la doc ARCHIVADA {page}, "
          f"que no se reescribe (la copia es de cuando la ruta existía)")

if broken_repo or broken_internal or compiled_relative:
    total = len(broken_repo) + len(broken_internal) + len(compiled_relative)
    print(f"FAIL: {total} enlace(s) rotos en el sitio construido ({pages} páginas escaneadas):")
    for repo, target, page in broken_repo:
        print(f"  {repo}: la ruta {target!r} no existe en el repo — enlazada desde {page}")
    for link, page in broken_internal:
        print(f"  interno: {link} no resuelve a ninguna página construida — enlazado desde {page}")
    for href, bundle in sorted(compiled_relative.items()):
        print(f"  relativo en el MDX compilado: href {href!r} en assets/js/{bundle} — el router lo "
              f"resuelve contra la URL actual y desde la forma con barra cae en Page Not Found")
    print("")
    print("Los enlaces a nuestros propios repos se verifican contra el checkout local,")
    print("así que una ruta rota aquí lo está también en github.com.")
    sys.exit(1)

suffix = f", {len(archived_broken)} en doc archivada avisados" if archived_broken else ""
print(f"OK: {len(repo_links)} enlaces a repos propios y {len(internal)} enlaces internos "
      f"resuelven ({pages} páginas escaneadas{suffix})")
PY
