#!/usr/bin/env bash
# quickstart-fences.sh — parser COMPARTIDO de la fuente markdown del quickstart.
#
# Lo usan tres consumidores, a propósito el mismo código:
#
#   - scripts/check_quickstart_cost.sh   — el guard que cuenta comandos y
#                                          conceptos de la página (techo 5/5).
#   - scripts/ci/quickstart_smoke.sh     — la lane que EJECUTA los curl de la
#                                          página contra la app generada.
#   - scripts/ci/tutorials_smoke.sh      — la lane que ejecuta los TUTORIALES
#                                          del sitio paso a paso (qs_steps):
#                                          comandos, ficheros y salidas.
#
# Si el guard contara con un parser y la lane con otro, la página podría
# pasar el techo con un parser y romper la lane con el otro. Un parser, dos
# veredictos sobre la misma lectura. Por la misma razón vive aquí el
# predicado de ENCENDIDO del arco (qs_nucleus_knows_with): guard y lane se
# activan con la misma lectura de la misma fuente pinada. Se cuenta sobre la FUENTE (.md), no sobre
# el HTML construido: Docusaurus no arranca en todos los entornos y la fuente
# es lo que el autor edita. qs_commands es una VISTA de qs_steps (los pasos
# `cmd` y `cli`), no un segundo lector: lo que el guard cuenta y lo que la
# lane de tutoriales ejecuta salen del mismo awk.
#
# Qué es un comando (qs_commands):
#   - una línea dentro de una fence de shell: ```bash / ```sh / ```shell o
#     ~~~bash / ~~~sh / ~~~shell (con o sin atributos tras el lenguaje),
#     abierta en la columna 0 O sangrada — la fence dentro de un paso de
#     lista («1. …» + fence con tres espacios) es el quickstart numerado de
#     toda la vida y Docusaurus/MDX la renderiza igual que la de columna 0.
#     Una fence se cierra sólo con SU marcador (una línea ``` dentro de un
#     bloque ~~~ es contenido, y al revés), como manda CommonMark;
#   - tras unir las continuaciones con `\` al final de línea (un curl de
#     cuatro líneas es UN comando),
#   - no vacía y que no empieza por `#` (los comentarios explican, no cuestan).
#   - Además, cada `<GoInstallCLI` de la página cuenta como un comando: el
#     componente renderiza `go install …@<tag>` (website/src/components/
#     CertifiedSet.tsx) y el lector lo teclea igual que una fence. No está en
#     una fence porque la versión sale del manifiesto en build; ocultarlo al
#     conteo sería un comando gratis.
#
# Qué más es un paso (qs_steps, lo que un tutorial manda hacer):
#   - un FICHERO: una fence que no es de shell y lleva `title="<ruta>"` en su
#     cadena de información (```go title="projects/projects.go"). Docusaurus
#     pinta ese título como cabecera del bloque, y es el nombre con el que el
#     lector guarda el contenido. Una fence de shell con título sigue siendo
#     de comandos: el título no la convierte en fichero;
#   - una SALIDA: una fence ```json o ```text sin título que sigue a una fence
#     de shell sin más que líneas en blanco entre ambas. Es lo que imprime el
#     ÚLTIMO comando de esa fence, y la lane lo compara. Con prosa en medio
#     («The last lines look like this:») la fence es ilustrativa y no se
#     compara: así se escribe el log de un `go run .`, que no es determinista.
#   No hay heredocs: una fence de shell es una lista de comandos de una línea
#   (con continuaciones); un fichero se escribe con una fence con título.
#
# Compatibilidad: bash 3.2 (macOS) — sin mapfile, sin arrays asociativos.

# qs_body <page.md> — el cuerpo de la página sin el front matter (el bloque
# entre el primer `---` y el segundo). Si no hay front matter, la página entera.
qs_body() {
  awk '
    NR == 1 && $0 == "---" { infm = 1; next }
    infm && $0 == "---"   { infm = 0; next }
    !infm { print }
  ' "$1"
}

# qs_front_matter_list <page.md> <clave> — los ítems de una lista YAML del
# front matter, uno por línea. Acepta la forma en bloque (`clave:` + líneas
# `  - item`) y la forma inline (`clave: [a, b, c]`). Sin front matter o sin
# la clave, no imprime nada (el llamante decide si eso es un fallo).
qs_front_matter_list() {
  awk -v key="$2" '
    NR == 1 && $0 == "---" { infm = 1; next }
    infm && $0 == "---"   { exit }
    !infm { exit }
    # Forma inline: clave: [a, b]
    $0 ~ "^" key ":[[:space:]]*\\[" {
      s = $0; sub("^" key ":[[:space:]]*\\[", "", s); sub("\\][[:space:]]*$", "", s)
      n = split(s, parts, ",")
      for (i = 1; i <= n; i++) { v = parts[i]; gsub(/^[[:space:]"'"'"']+|[[:space:]"'"'"']+$/, "", v); if (v != "") print v }
      exit
    }
    # Forma en bloque: clave: seguida de "  - item".
    $0 ~ "^" key ":[[:space:]]*$" { inlist = 1; next }
    inlist && /^[[:space:]]+-[[:space:]]*/ {
      v = $0; sub(/^[[:space:]]+-[[:space:]]*/, "", v)
      sub(/[[:space:]]+#.*$/, "", v)
      gsub(/^["'"'"']+|["'"'"']+$/, "", v)
      if (v != "") print v
      next
    }
    inlist { exit }
  ' "$1"
}

# qs_steps <page.md> — los pasos de la página en orden, uno por línea y
# separados por tabuladores: `<tipo>\t<línea>\t<valor>`. La línea es la de la
# PÁGINA (front matter incluido), para que un fallo apunte donde se edita.
#
#   cmd   <línea donde empieza el comando>  <comando, continuaciones unidas>
#   cli   <línea>                           <GoInstallCLI/>
#   file  <línea de la fence>               <ruta del title="…">
#   out   <línea de la fence>               json | text
#
# El contenido de un `file` o un `out` lo da qs_fence_body con esa línea.
qs_steps() {
  awk '
    function flush() {
      if (acc == "") return
      line = acc; acc = ""
      sub(/^[[:space:]]+/, "", line); sub(/[[:space:]]+$/, "", line)
      if (line == "" || line ~ /^#/) return
      printf "cmd\t%d\t%s\n", accnr, line
    }
    # close_re_of(línea de apertura) — el regex de la línea que CIERRA esa
    # fence: mismo marcador (``` o ~~~, tres o más), sangría opcional, nada
    # más. Una fence abierta con ``` no la cierra una línea ~~~ ni al revés.
    function close_re_of(open,    m) {
      m = open; sub(/^[[:space:]]*/, "", m)
      return (substr(m, 1, 1) == "~") ? "^[[:space:]]*~~~+[[:space:]]*$" : "^[[:space:]]*```+[[:space:]]*$"
    }
    # title_of(cadena de información) — el valor de title="…", o "".
    function title_of(info,    v) {
      if (!match(info, /title="[^"]*"/)) return ""
      v = substr(info, RSTART + 7, RLENGTH - 8)
      return v
    }
    # Front matter: el bloque entre el primer `---` (línea 1) y el segundo.
    NR == 1 && $0 == "---" { infm = 1; next }
    infm { if ($0 == "---") infm = 0; next }
    # Apertura de fence de shell: ```bash / ~~~bash, sh, shell (+ atributos),
    # en columna 0 o sangrada (fence dentro de un paso de lista).
    !infence && !skipping && $0 ~ /^[[:space:]]*(```+|~~~+)(bash|sh|shell)([[:space:]]|$)/ { infence = 1; acc = ""; close_re = close_re_of($0); next }
    # Cualquier otra fence: un fichero si lleva título, una salida si pega
    # con la fence de shell anterior; su contenido se salta entero hasta la
    # línea que la cierra con su propio marcador.
    !infence && !skipping && $0 ~ /^[[:space:]]*(```+|~~~+)/ {
      skipping = 1; close_re = close_re_of($0)
      info = $0; sub(/^[[:space:]]*(```+|~~~+)[[:space:]]*/, "", info)
      lang = info; sub(/[[:space:]].*$/, "", lang)
      title = title_of(info)
      if (title != "") printf "file\t%d\t%s\n", NR, title
      else if (adjacent && (lang == "json" || lang == "text")) printf "out\t%d\t%s\n", NR, lang
      adjacent = 0
      next
    }
    skipping && $0 ~ close_re { skipping = 0; next }
    skipping { next }
    infence && $0 ~ close_re { flush(); infence = 0; adjacent = 1; next }
    infence {
      line = $0
      if (acc == "") accnr = NR
      if (line ~ /\\[[:space:]]*$/) {
        sub(/\\[[:space:]]*$/, "", line); sub(/^[[:space:]]+/, "", line); sub(/[[:space:]]+$/, "", line)
        acc = (acc == "") ? line : acc " " line
        next
      }
      sub(/^[[:space:]]+/, "", line)
      acc = (acc == "") ? line : acc " " line
      flush()
      next
    }
    # Fuera de fences: una línea en blanco no rompe la adyacencia entre una
    # fence de shell y su salida; cualquier otra sí.
    /^[[:space:]]*$/ { next }
    { adjacent = 0 }
    # El componente que renderiza `go install`.
    /<GoInstallCLI/ { n = gsub(/<GoInstallCLI/, "&"); for (i = 0; i < n; i++) printf "cli\t%d\t<GoInstallCLI/>\n", NR }
  ' "$1"
}

# qs_commands <page.md> — un comando por línea (ver cabecera). Las
# continuaciones ya vienen unidas en una sola línea, con un espacio entre
# los trozos. Los `<GoInstallCLI` se emiten como `go install <GoInstallCLI/>`
# para que quien lea la lista sepa de dónde sale ese comando. Es la vista de
# qs_steps que cuenta el guard de coste y de la que la lane del quickstart
# saca sus curl.
qs_commands() {
  qs_steps "$1" | awk -F'\t' '
    $1 == "cmd" { sub(/^cmd\t[0-9]+\t/, ""); print; next }
    $1 == "cli" { print "go install <GoInstallCLI/>" }
  '
}

# qs_fence_body <page.md> <línea> — el contenido de la fence que se abre en
# esa línea de la página (la que qs_steps da para un `file` o un `out`), sin
# los delimitadores y sin la sangría de la apertura: una fence sangrada bajo
# un paso de lista da su contenido en la columna 0, como lo renderiza el
# sitio y como el lector lo copia. EXIT 2 si esa línea no abre una fence.
qs_fence_body() {
  awk -v start="$2" '
    function close_re_of(open,    m) {
      m = open; sub(/^[[:space:]]*/, "", m)
      return (substr(m, 1, 1) == "~") ? "^[[:space:]]*~~~+[[:space:]]*$" : "^[[:space:]]*```+[[:space:]]*$"
    }
    NR == start {
      if ($0 !~ /^[[:space:]]*(```+|~~~+)/) exit 2
      ind = match($0, /[^[:space:]]/) - 1
      close_re = close_re_of($0); body = 1; next
    }
    body && $0 ~ close_re { exit 0 }
    body {
      s = $0; n = 0
      while (n < ind && substr(s, 1, 1) == " ") { s = substr(s, 2); n++ }
      print s
    }
    END { if (!body) exit 2 }
  ' "$1"
}

# qs_identifiers <page.md> — identificadores cualificados de la suite
# (`nucleus.New`, `orbit.Config`, `quarkdatasource.Register`…) que la página
# EXPLICA: prosa y código inline entre backticks, NO lo que muestran sus
# bloques de código. Sin repetir y en orden de aparición. Las rutas de import
# (`…/orbit/quarkdatasource`) no cuentan: el carácter anterior no puede ser
# `/`, `.`, letra, dígito ni `_`.
#
# Por qué los bloques no cuentan: el techo del arco A2 mide lo que el lector
# tiene que ENTENDER, y un listado es «lee lo que se generó», no un concepto
# que la página enseñe. Hasta el 2026-09-12 esto salía gratis —los listados
# entraban en build por fences `file=`, así que no estaban en la fuente—; al
# retirarse los ejemplos del árbol pasaron a vivir en la página, y sin este
# filtro el mismo texto pasaba de 5 conceptos a 12 sin haber explicado uno más.
qs_identifiers() {
  qs_body "$1" \
    | qs_strip_fences \
    | grep -oE '(^|[^A-Za-z0-9_./])(nucleus|orbit|quark|quarkbridge|quarkdatasource)\.[A-Z][A-Za-z0-9]*' \
    | sed -E 's/^[^A-Za-z]//' \
    | awk '!seen[$0]++'
}

# qs_strip_fences — filtro: quita el CONTENIDO de las fences de bloque (y sus
# delimitadores), dejando la prosa. Mismas reglas de cierre que qs_commands:
# cada fence se cierra sólo con su marcador, así que un ``` dentro de un
# bloque ~~~ es contenido.
qs_strip_fences() {
  awk '
    function close_re_of(open,    m) {
      m = open; sub(/^[[:space:]]*/, "", m)
      return (substr(m, 1, 1) == "~") ? "^[[:space:]]*~~~+[[:space:]]*$" : "^[[:space:]]*```+[[:space:]]*$"
    }
    !infence && $0 ~ /^[[:space:]]*(```+|~~~+)/ { infence = 1; close_re = close_re_of($0); next }
    infence && $0 ~ close_re { infence = 0; next }
    !infence { print }
  '
}

# qs_embeds <page.md> — las fences que IMPORTAN código en build: una línea por
# fence cuya cadena de información lleva un token `file=…` (remark-code-import,
# cableado en website/docusaurus.config.ts), en orden de aparición y con el
# formato `<línea>\t<lenguaje>\t<file=…>`. Mismas reglas de fence que
# qs_commands (``` o ~~~, columna 0 o sangrada, cada fence se cierra sólo con
# su marcador; lo que hay DENTRO de una fence es contenido, no otra fence).
# El token es el primero de la cadena que empieza por `file=`, como hace el
# plugin (parte por espacios). Lo consume el guard umbrella-quickstart-embeds:
# lo que la página promete embeber tiene que existir y decir lo que la prosa
# explica EN EL SUBMÓDULO PINADO, no en el main del producto.
qs_embeds() {
  qs_body "$1" | awk '
    function close_re_of(open,    m) {
      m = open; sub(/^[[:space:]]*/, "", m)
      return (substr(m, 1, 1) == "~") ? "^[[:space:]]*~~~+[[:space:]]*$" : "^[[:space:]]*```+[[:space:]]*$"
    }
    # El cuerpo empieza tras el front matter; la línea real de la página es
    # NR + las líneas del front matter, que qs_body ya quitó — se informa la
    # línea del CUERPO, suficiente para localizar la fence.
    !infence && $0 ~ /^[[:space:]]*(```+|~~~+)/ {
      infence = 1; close_re = close_re_of($0)
      info = $0; sub(/^[[:space:]]*(```+|~~~+)[[:space:]]*/, "", info)
      n = split(info, parts, /[[:space:]]+/)
      lang = (n >= 1) ? parts[1] : ""
      for (i = 2; i <= n; i++) if (parts[i] ~ /^file=/) { printf "%d\t%s\t%s\n", NR, lang, parts[i]; break }
      next
    }
    infence && $0 ~ close_re { infence = 0; next }
  '
}

# qs_nucleus_knows_with <dir del submódulo nucleus> — ¿el `nucleus new` de ese
# árbol registra el flag `--with`? Es el criterio de ENCENDIDO del arco A2,
# leído de la FUENTE pinada, y lo comparten el guard (que no compila nada) y
# la lane (que además compila el CLI y comprueba que `nucleus new --help`
# diga lo mismo: si la fuente y el binario discrepan, la lane muere — así el
# predicado no puede quedarse ciego sin que se note). Antes el guard miraba
# un pin fijo (`modules.nucleus ≤ v1.24.0`) y la lane la capacidad: un patch
# de nucleus sin `--with` encendía el guard y no la lane.
#
# Qué se busca: una línea de internal/cli/new.go que registre un flag llamado
# "with" en cualquiera de las formas de `flag`/`pflag`:
#   fs.String("with", …) · fs.StringVar(&w, "with", …) · fs.Var(&l, "with", …)
#   · fs.Func("with", …) · cmd.Flags().StringSlice("with", …)
# Un `"with"` en prosa de ayuda o en una lista de palabras clave no cuenta:
# tiene que ir como argumento «nombre» de una llamada de registro.
#
# EXIT 0 — lo conoce; EXIT 1 — no lo conoce; EXIT 2 — el fichero no existe
# (submódulo sin checkout: el llamante decide, y no debe tomarlo por «no»).
qs_nucleus_knows_with() {
  local f="$1/internal/cli/new.go"
  [[ -f "$f" ]] || return 2
  grep -qE '\.[A-Za-z]*(String|Var|Func|Bool|Int)[A-Za-z]*\(([^,]*,[[:space:]]*)?"with"[[:space:]]*,' "$f"
}
