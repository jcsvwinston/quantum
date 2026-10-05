#!/usr/bin/env bash
# selftest.sh — autotest del parser compartido scripts/lib/quickstart-fences.sh.
#
# El guard umbrella-quickstart-cost y la lane quickstart-smoke leen la página
# con ESTE parser; si dejara de unir continuaciones, de saltar comentarios o
# de ignorar las fences que no son shell, o volviera a ver sólo las fences
# ``` de columna 0 (las ~~~ y las sangradas bajo un paso de lista son
# bloques de código igual), el guard contaría mal y la lane ejecutaría
# basura — los dos en verde. También prueba el predicado de encendido que
# guard y lane comparten (qs_nucleus_knows_with) y el lector de fences
# `file=…` del guard umbrella-quickstart-embeds (qs_embeds), y los PASOS que
# la lane de tutoriales ejecuta (qs_steps: comandos, ficheros con título y
# salidas pegadas a su fence de shell; qs_fence_body: el contenido sin la
# sangría de la apertura). Las dos lanes lo corren como paso 0 en cada PR
# (scripts/ci/quickstart_smoke.sh, scripts/ci/tutorials_smoke.sh) y se puede
# lanzar a mano desde la raíz del paraguas: bash tests/quickstart-fences/selftest.sh
set -uo pipefail

cd "$(dirname "$0")/../.."
source scripts/lib/quickstart-fences.sh

TMP=$(mktemp -d "${TMPDIR:-/tmp}/quickstart-fences.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
PAGE="$TMP/page.md"

cat > "$PAGE" <<'MD'
---
title: "Probe"
concepts:
  - nucleus.New
  - "orbit.Module"   # comentario
---

import {GoInstallCLI} from '@site/src/components/CertifiedSet';

Text with `nucleus.New` and `orbit.Config` and a path github.com/x/orbit/quarkdatasource
and `quarkbridge.New` and nucleus.yml (no cuenta) and `quark.For` and `quarkdatasource.Register`.

<GoInstallCLI />

```bash
# a comment, not a command
nucleus new blog --with orbit
cd blog && go run .
```

```bash title="curls"
curl -s localhost:8080/api/articles
curl -s -X POST localhost:8080/api/articles \
    -H 'Content-Type: application/json' \
    -d '{"title":"probe"}'

```

```go
// nucleus.Run in a go fence: it is an identifier, not a command
nucleus.Run(app)
```

```json
{"not": "a command"}
```

```sh
go test ./...
```

```text
curl this-is-output-not-a-command
```

~~~bash
echo tilde-one
echo tilde-two
~~~

1. A numbered step with its fence indented under the list item:

   ```bash
   echo indented-one
   echo indented-two \
     --flag
   ```

~~~text
```bash
echo inside-a-tilde-block-this-is-content
```
~~~

```text
~~~bash
echo inside-a-backtick-block-this-is-content
~~~
```

```sh
echo after-the-nested-blocks
```

```go file=<rootDir>/examples/x/main.go
```

1. Indented, with a range and a title after the file token:

   ~~~go file=<rootDir>/examples/x/shop/module.go#L24-L66 title="module.go"
   ~~~

~~~text
```go file=<rootDir>/inside-a-fence-is-content.go
```
~~~
MD

fails=0
check() {
  local name=$1 want=$2 got=$3
  if [[ "$got" == "$want" ]]; then
    echo "OK: $name"
  else
    echo "FAIL: $name" >&2
    echo "  esperado: $want" >&2
    echo "  obtenido: $got" >&2
    fails=$((fails + 1))
  fi
}

# 1. Comandos: continuaciones unidas, comentarios y fences no-shell fuera,
#    GoInstallCLI contado, orden de la página.
want_cmds='go install <GoInstallCLI/>
nucleus new blog --with orbit
cd blog && go run .
curl -s localhost:8080/api/articles
curl -s -X POST localhost:8080/api/articles -H '"'"'Content-Type: application/json'"'"' -d '"'"'{"title":"probe"}'"'"'
go test ./...
echo tilde-one
echo tilde-two
echo indented-one
echo indented-two --flag
echo after-the-nested-blocks'
check "qs_commands" "$want_cmds" "$(qs_commands "$PAGE")"
check "qs_commands cuenta 11" "11" "$(qs_commands "$PAGE" | wc -l | tr -d ' ')"
# 1b. Las fences que la primera versión no veía, una por una: ~~~bash y la
#     fence sangrada bajo un paso de lista (Docusaurus/MDX las renderiza
#     como bloque de código igual que ``` en columna 0); una fence sólo la
#     cierra su propio marcador (``` dentro de ~~~text es contenido).
check "qs_commands ~~~bash" $'echo tilde-one\necho tilde-two' "$(qs_commands "$PAGE" | grep '^echo tilde')"
check "qs_commands fence sangrada en lista" $'echo indented-one\necho indented-two --flag' "$(qs_commands "$PAGE" | grep '^echo indented')"
check "qs_commands fence anidada es contenido" "" "$(qs_commands "$PAGE" | grep 'inside-a-' || true)"

# 2. Front matter: lista en bloque, comillas y comentarios fuera.
check "qs_front_matter_list bloque" $'nucleus.New\norbit.Module' "$(qs_front_matter_list "$PAGE" concepts)"
printf -- '---\nconcepts: [a.B, "c.D", e.F]\n---\nbody\n' > "$TMP/inline.md"
check "qs_front_matter_list inline" $'a.B\nc.D\ne.F' "$(qs_front_matter_list "$TMP/inline.md" concepts)"
printf -- 'sin front matter\n' > "$TMP/nofm.md"
check "qs_front_matter_list sin front matter" "" "$(qs_front_matter_list "$TMP/nofm.md" concepts)"

# 3. Identificadores: sin repetir, sin rutas de import, sin minúsculas tras el
#    punto y SIN los de las fences de código — el techo mide lo que la página
#    EXPLICA, y un listado es «lee lo que se generó». Hasta el 2026-09-12 esto
#    salía gratis (los listados entraban en build por fences `file=`, así que
#    no estaban en la fuente); al mudarse a la página hizo falta decirlo.
want_ids='nucleus.New
orbit.Config
quarkbridge.New
quark.For
quarkdatasource.Register'
check "qs_identifiers" "$want_ids" "$(qs_identifiers "$PAGE")"
check "qs_identifiers ignora el contenido de las fences" "" "$(qs_identifiers "$PAGE" | grep 'nucleus.Run' || true)"

# 4. Página sin fences: cero comandos (el guard decide qué hacer con eso).
check "qs_commands vacío" "" "$(qs_commands "$TMP/nofm.md")"

# 5. El predicado de encendido compartido por guard y lane: reconoce el flag
#    "with" registrado en new.go en las formas de flag/pflag, no en prosa ni
#    en listas de palabras; sin fichero, EXIT 2 (no es un «no»).
mkdir -p "$TMP/nuc/internal/cli"
printf 'func runNew() {\n\tfs := flag.NewFlagSet("new", flag.ContinueOnError)\n\ttmpl := fs.String("template", "mvc", "use --with to add siblings")\n\tkeywords := []string{"select", "with"}\n}\n' > "$TMP/nuc/internal/cli/new.go"
qs_nucleus_knows_with "$TMP/nuc"; check "qs_nucleus_knows_with sin flag (prosa y lista no cuentan)" "1" "$?"
printf '\twith := fs.String("with", "", "sibling modules")\n' >> "$TMP/nuc/internal/cli/new.go"
qs_nucleus_knows_with "$TMP/nuc"; check "qs_nucleus_knows_with fs.String" "0" "$?"
printf 'func runNew() {\n\tvar with string\n\tfs.StringVar(&with, "with", "", "sibling modules")\n}\n' > "$TMP/nuc/internal/cli/new.go"
qs_nucleus_knows_with "$TMP/nuc"; check "qs_nucleus_knows_with fs.StringVar" "0" "$?"
printf 'func runNew() {\n\tcmd.Flags().StringSlice("with", nil, "sibling modules")\n}\n' > "$TMP/nuc/internal/cli/new.go"
qs_nucleus_knows_with "$TMP/nuc"; check "qs_nucleus_knows_with pflag StringSlice" "0" "$?"
qs_nucleus_knows_with "$TMP/no-such-dir"; check "qs_nucleus_knows_with sin new.go es 2" "2" "$?"

# 6. Fences que importan código (qs_embeds): el token file= de la cadena de
#    información, con rango y con atributos detrás, en columna 0 o sangrada;
#    una fence con file= DENTRO de otra fence es contenido, no un embed.
want_embeds=$'go\tfile=<rootDir>/examples/x/main.go\ngo\tfile=<rootDir>/examples/x/shop/module.go#L24-L66'
check "qs_embeds" "$want_embeds" "$(qs_embeds "$PAGE" | cut -f2-)"
check "qs_embeds cuenta 2" "2" "$(qs_embeds "$PAGE" | wc -l | tr -d ' ')"
check "qs_embeds fence anidada es contenido" "" "$(qs_embeds "$PAGE" | grep 'inside-a-fence' || true)"
check "qs_embeds vacío" "" "$(qs_embeds "$TMP/nofm.md")"

# 7. Pasos de un tutorial (qs_steps): comandos con la línea de la PÁGINA
#    donde empiezan (front matter incluido), ficheros por title="…" en una
#    fence que no es de shell, y salidas: la fence json/text sin título que
#    pega con la fence de shell anterior (sólo líneas en blanco en medio).
#    Con prosa en medio la salida es ilustrativa y no es un paso; una fence
#    de shell con título sigue siendo de comandos.
cat > "$TMP/tutorial.md" <<'MD'
---
title: "Tutorial probe"
---

Create the file:

```go title="tasks/tasks.go"
package tasks

func Answer() int { return 42 }
```

```bash
cd app
curl -s localhost:8080/tasks \
    -H 'X-Probe: 1'
```

```json
{"tasks":[],"count":0}
```

```bash title="terminal"
go run .
```

The last lines look like this:

```text
level=INFO msg="not compared: prose in between"
```

1. A file inside a list item:

   ```yaml title="nucleus.yml"
   port: 8080
     nested: kept
   ```

```sh
curl -s -o /dev/null -w '%{http_code}\n' localhost:8080/nope
```
```text
404
```

```go
// a fence with neither title nor shell: skipped
```
MD
want_steps=$'file\t7\ttasks/tasks.go\ncmd\t14\tcd app\ncmd\t15\tcurl -s localhost:8080/tasks -H \'X-Probe: 1\'\nout\t19\tjson\ncmd\t24\tgo run .\nfile\t35\tnucleus.yml\ncmd\t41\tcurl -s -o /dev/null -w \'%{http_code}\\n\' localhost:8080/nope\nout\t43\ttext'
check "qs_steps" "$want_steps" "$(qs_steps "$TMP/tutorial.md")"
check "qs_steps: la salida con prosa en medio no es un paso" "" "$(qs_steps "$TMP/tutorial.md" | grep 'not compared' || true)"
check "qs_commands es la vista cmd de qs_steps" "$(qs_steps "$TMP/tutorial.md" | awk -F'\t' '$1=="cmd"' | cut -f3-)" "$(qs_commands "$TMP/tutorial.md")"

# 8. qs_fence_body: el contenido tal cual (líneas en blanco incluidas), sin
#    los delimitadores y sin la sangría de la apertura (la sangría PROPIA del
#    contenido se queda); una línea que no abre fence es EXIT 2.
check "qs_fence_body fichero" $'package tasks\n\nfunc Answer() int { return 42 }' "$(qs_fence_body "$TMP/tutorial.md" 7)"
check "qs_fence_body fence sangrada" $'port: 8080\n  nested: kept' "$(qs_fence_body "$TMP/tutorial.md" 35)"
check "qs_fence_body salida" '{"tasks":[],"count":0}' "$(qs_fence_body "$TMP/tutorial.md" 19)"
qs_fence_body "$TMP/tutorial.md" 5 >/dev/null; check "qs_fence_body en una línea de prosa es 2" "2" "$?"
qs_fence_body "$TMP/tutorial.md" 999 >/dev/null; check "qs_fence_body tras el final es 2" "2" "$?"

if [[ $fails -ne 0 ]]; then
  echo "quickstart-fences selftest: FALLO ($fails aserciones)" >&2
  exit 1
fi
echo "quickstart-fences selftest: OK — el parser compartido lee comandos, pasos, front matter e identificadores como se documenta"
