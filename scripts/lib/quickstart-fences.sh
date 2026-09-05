#!/usr/bin/env bash
# quickstart-fences.sh — parser COMPARTIDO de la fuente markdown del quickstart.
#
# Lo usan dos consumidores, a propósito el mismo código:
#
#   - scripts/check_quickstart_cost.sh   — el guard que cuenta comandos y
#                                          conceptos de la página (techo 5/5).
#   - scripts/ci/quickstart_smoke.sh     — la lane que EJECUTA los curl de la
#                                          página contra la app generada.
#
# Si el guard contara con un parser y la lane con otro, la página podría
# pasar el techo con un parser y romper la lane con el otro. Un parser, dos
# veredictos sobre la misma lectura. Por la misma razón vive aquí el
# predicado de ENCENDIDO del arco (qs_nucleus_knows_with): guard y lane se
# activan con la misma lectura de la misma fuente pinada. Se cuenta sobre la FUENTE (.md), no sobre
# el HTML construido: Docusaurus no arranca en todos los entornos y la fuente
# es lo que el autor edita.
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

# qs_commands <page.md> — un comando por línea (ver cabecera). Las
# continuaciones ya vienen unidas en una sola línea, con un espacio entre
# los trozos. Los `<GoInstallCLI` se emiten como `go install <GoInstallCLI/>`
# para que quien lea la lista sepa de dónde sale ese comando.
qs_commands() {
  qs_body "$1" | awk '
    function flush() {
      if (acc == "") return
      line = acc; acc = ""
      sub(/^[[:space:]]+/, "", line); sub(/[[:space:]]+$/, "", line)
      if (line == "" || line ~ /^#/) return
      print line
    }
    # close_re_of(línea de apertura) — el regex de la línea que CIERRA esa
    # fence: mismo marcador (``` o ~~~, tres o más), sangría opcional, nada
    # más. Una fence abierta con ``` no la cierra una línea ~~~ ni al revés.
    function close_re_of(open,    m) {
      m = open; sub(/^[[:space:]]*/, "", m)
      return (substr(m, 1, 1) == "~") ? "^[[:space:]]*~~~+[[:space:]]*$" : "^[[:space:]]*```+[[:space:]]*$"
    }
    # Apertura de fence de shell: ```bash / ~~~bash, sh, shell (+ atributos),
    # en columna 0 o sangrada (fence dentro de un paso de lista).
    !infence && !skipping && $0 ~ /^[[:space:]]*(```+|~~~+)(bash|sh|shell)([[:space:]]|$)/ { infence = 1; acc = ""; close_re = close_re_of($0); next }
    # Cualquier otra fence: se salta entera (json, go, salidas…) hasta la
    # línea que la cierra con su propio marcador.
    !infence && !skipping && $0 ~ /^[[:space:]]*(```+|~~~+)/ { skipping = 1; close_re = close_re_of($0); next }
    skipping && $0 ~ close_re { skipping = 0; next }
    skipping { next }
    infence && $0 ~ close_re { flush(); infence = 0; next }
    infence {
      line = $0
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
    # Fuera de fences: el componente que renderiza `go install`.
    /<GoInstallCLI/ { n = gsub(/<GoInstallCLI/, "&"); for (i = 0; i < n; i++) print "go install <GoInstallCLI/>" }
  '
}

# qs_identifiers <page.md> — identificadores cualificados de la suite
# (`nucleus.New`, `orbit.Config`, `quarkdatasource.Register`…) que la página
# nombra en su FUENTE — prosa, código inline o fences —, sin repetir y en
# orden de aparición. Las rutas de import (`…/orbit/quarkdatasource`) no
# cuentan: el carácter anterior no puede ser `/`, `.`, letra, dígito ni `_`.
# Lo que una fence `file=…` importa en build NO está en la fuente y por tanto
# no se cuenta: eso es «leer lo que se generó», no un concepto que la página
# explique.
qs_identifiers() {
  qs_body "$1" \
    | grep -oE '(^|[^A-Za-z0-9_./])(nucleus|orbit|quark|quarkbridge|quarkdatasource)\.[A-Z][A-Za-z0-9]*' \
    | sed -E 's/^[^A-Za-z]//' \
    | awk '!seen[$0]++'
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
