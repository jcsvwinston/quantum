#!/usr/bin/env bash
# selftest.sh — autotest del parser compartido scripts/lib/quickstart-fences.sh.
#
# El guard umbrella-quickstart-cost y la lane quickstart-smoke leen la página
# con ESTE parser; si dejara de unir continuaciones, de saltar comentarios o
# de ignorar las fences que no son shell, el guard contaría mal y la lane
# ejecutaría basura — los dos en verde. La lane lo corre como paso 0 en cada
# PR (scripts/ci/quickstart_smoke.sh) y se puede lanzar a mano desde la raíz
# del paraguas: bash tests/quickstart-fences/selftest.sh
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
go test ./...'
check "qs_commands" "$want_cmds" "$(qs_commands "$PAGE")"
check "qs_commands cuenta 6" "6" "$(qs_commands "$PAGE" | wc -l | tr -d ' ')"

# 2. Front matter: lista en bloque, comillas y comentarios fuera.
check "qs_front_matter_list bloque" $'nucleus.New\norbit.Module' "$(qs_front_matter_list "$PAGE" concepts)"
printf -- '---\nconcepts: [a.B, "c.D", e.F]\n---\nbody\n' > "$TMP/inline.md"
check "qs_front_matter_list inline" $'a.B\nc.D\ne.F' "$(qs_front_matter_list "$TMP/inline.md" concepts)"
printf -- 'sin front matter\n' > "$TMP/nofm.md"
check "qs_front_matter_list sin front matter" "" "$(qs_front_matter_list "$TMP/nofm.md" concepts)"

# 3. Identificadores: sin repetir, sin rutas de import, sin minúsculas tras el
#    punto, con los de las fences go incluidos (están en la FUENTE).
want_ids='nucleus.New
orbit.Config
quarkbridge.New
quark.For
quarkdatasource.Register
nucleus.Run'
check "qs_identifiers" "$want_ids" "$(qs_identifiers "$PAGE")"

# 4. Página sin fences: cero comandos (el guard decide qué hacer con eso).
check "qs_commands vacío" "" "$(qs_commands "$TMP/nofm.md")"

if [[ $fails -ne 0 ]]; then
  echo "quickstart-fences selftest: FALLO ($fails aserciones)" >&2
  exit 1
fi
echo "quickstart-fences selftest: OK — el parser compartido lee comandos, front matter e identificadores como se documenta"
