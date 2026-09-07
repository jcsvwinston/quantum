#!/usr/bin/env bash
# Fixture de umbrella-quickstart-cost.
#
# Rotura: un quickstart doctorado con SEIS comandos (el techo es cinco:
# `<GoInstallCLI />` + cinco líneas de fence) y un `concepts:` correcto, para
# que el guard muera por el techo de comandos — la esencia del gate — y no
# por el cruce de conceptos. El sexto es la deriva más probable en la vida
# real: un `go mod tidy` que vuelve a colarse y parte `cd blog && go run .`
# en dos líneas. Los cinco van repartidos entre una fence ```bash de columna
# 0 y una fence ~~~bash sangrada bajo un paso de lista: las dos formas que
# Docusaurus renderiza como bloque de código y que el parser tiene que ver
# (la primera versión sólo veía ``` en columna 0 y contaba 1 de 5).
#
# El guard tiene una transición ligada a la CAPACIDAD del nucleus pinado
# (mientras `nucleus new` no registre `--with`, mide y no exige) leída con el
# mismo predicado que la lane quickstart-smoke: ¿nucleus/internal/cli/new.go
# registra el flag "with"? La fixture copia el new.go REAL del submódulo y le
# planta la línea del flag, así prueba la activación real —no un escape— y
# sobrevive a los re-pins: cuando el pin traiga el flag de verdad, la línea
# plantada sobra pero no estorba.
#
# Las demás causas de muerte (concepto de contrabando, declaración colgante,
# `concepts:` ausente → EXIT 2, página ausente → EXIT 2, submódulo ausente →
# EXIT 2) se probaron por comando en la ronda que trajo el guard (PR del arco
# A2); el harness ejecuta UNA fixture por guard y la rotura permanente elegida
# es la del techo.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_quickstart_cost.sh scripts/lib/quickstart-fences.sh nucleus/internal/cli/new.go

# El nucleus copiado registra `--with`: la capacidad que enciende el guard.
printf '\n// fixture umbrella-quickstart-cost: el flag que enciende el arco A2\nfunc fixtureWith(fs *flag.FlagSet) *string { return fs.String("with", "", "sibling modules to wire (orbit,quark,…)") }\n' \
  >> "$TREE/nucleus/internal/cli/new.go"
fx_assert_doctored "$TREE/nucleus/internal/cli/new.go" 'fs\.String\("with",'
# …y el predicado compartido tiene que verla (si su regex cambia, mejor
# reventar aquí que dejar pasar un falso verde por «medido, no exigido»).
source "$TREE/scripts/lib/quickstart-fences.sh"
qs_nucleus_knows_with "$TREE/nucleus" || { echo "fixture: qs_nucleus_knows_with no reconoce la línea plantada en new.go — actualizar la fixture o el predicado" >&2; exit 1; }

mkdir -p "$TREE/website/docs"
cat > "$TREE/website/docs/quickstart.md" <<'MD'
---
title: "Quickstart (sonda)"
concepts:
  - nucleus.New
  - orbit.Module
  - quark.New
  - quarkdatasource.New
  - quarkbridge.New
---

import {GoInstallCLI} from '@site/src/components/CertifiedSet';

<GoInstallCLI />

```bash
nucleus new blog --template suite --with orbit,quark,quarkbridge,quarkdatasource
cd blog && go mod tidy
go run .
```

1. Read and write over HTTP:

   ~~~bash
   curl -s localhost:8080/api/articles
   curl -s -X POST localhost:8080/api/articles \
       -H 'Content-Type: application/json' \
       -d '{"author_id":1,"title":"probe","body":"written over curl"}'
   ~~~

`nucleus.New()` is the builder; `orbit.Module(orbit.Config{...})` mounts the
admin; `quark.New` opens the client; `quarkdatasource.New` plus
`quarkdatasource.Register[T]` back Data Studio; `quarkbridge.New` feeds the
live SQL view.
MD
fx_assert_doctored "$TREE/website/docs/quickstart.md" '&& go mod tidy$'
fx_assert_doctored "$TREE/website/docs/quickstart.md" '^   ~~~bash$'

echo "workdir=$TREE"
echo "expect=6 comandos > 5"
