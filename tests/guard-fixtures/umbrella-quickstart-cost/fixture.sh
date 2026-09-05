#!/usr/bin/env bash
# Fixture de umbrella-quickstart-cost.
#
# Rotura: un quickstart doctorado con SEIS comandos (el techo es cinco:
# `<GoInstallCLI />` + cinco líneas de fence) y un `concepts:` correcto, para
# que el guard muera por el techo de comandos — la esencia del gate — y no
# por el cruce de conceptos. El sexto es la deriva más probable en la vida
# real: un `go mod tidy` que vuelve a colarse y parte `cd blog && go run .`
# en dos líneas.
#
# El guard tiene una transición ligada al pin de nucleus (≤ v1.24.0 mide y
# no exige, porque `nucleus new --with` aún no existe al pin). La fixture
# copia el versions.yaml REAL y lo doctora al primer pin por ENCIMA del
# umbral que el propio script copiado declara (TRANSITIONAL_MAX), así prueba
# la activación real —no un escape— y sobrevive a los re-pins: si alguien
# sube el umbral, la fixture lo lee del script y sigue mordiendo.
#
# Las demás causas de muerte (concepto de contrabando, declaración colgante,
# `concepts:` ausente → EXIT 2, página ausente → EXIT 2) se probaron por
# comando en la ronda que trajo el guard (PR del arco A2); el harness ejecuta
# UNA fixture por guard y la rotura permanente elegida es la del techo.
set -euo pipefail
source tests/guard-fixtures/lib.sh

TMP=$1
TREE="$TMP/tree"
ROOT=$(pwd)

fx_copy "$ROOT" "$TREE" scripts/check_quickstart_cost.sh scripts/lib/quickstart-fences.sh versions.yaml

# Pin de nucleus por encima del umbral de transición del script copiado.
max=$(sed -n "s/^TRANSITIONAL_MAX='\(v[0-9.]*\)'.*/\1/p" "$TREE/scripts/check_quickstart_cost.sh" | head -1)
[[ -n "$max" ]] || { echo "fixture: el guard ya no declara TRANSITIONAL_MAX='vX.Y.Z' — actualizar la fixture" >&2; exit 1; }
above=$(awk -F. -v v="${max#v}" 'BEGIN { split(v, p, "."); printf "v%d.%d.0", p[1], p[2] + 1 }')
sed -E "s/^(  nucleus:[[:space:]]*)\"v[0-9.]+\"/\1\"$above\"/" "$TREE/versions.yaml" > "$TREE/versions.yaml.tmp"
mv "$TREE/versions.yaml.tmp" "$TREE/versions.yaml"
fx_assert_doctored "$TREE/versions.yaml" "^  nucleus:[[:space:]]*\"$above\""

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

```bash
curl -s localhost:8080/api/articles
curl -s -X POST localhost:8080/api/articles \
    -H 'Content-Type: application/json' \
    -d '{"author_id":1,"title":"probe","body":"written over curl"}'
```

`nucleus.New()` is the builder; `orbit.Module(orbit.Config{...})` mounts the
admin; `quark.New` opens the client; `quarkdatasource.New` plus
`quarkdatasource.Register[T]` back Data Studio; `quarkbridge.New` feeds the
live SQL view.
MD
fx_assert_doctored "$TREE/website/docs/quickstart.md" '&& go mod tidy$'

echo "workdir=$TREE"
echo "expect=6 comandos > 5"
