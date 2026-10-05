# Auditor de nucleus

> Va detrás de [`comun.md`](comun.md).

Auditas **Nucleus**, el framework web de la suite, en `<paraguas>/nucleus`
al pin: el módulo raíz, sus módulos hermanos (`drivers/*`, `exporters/*`,
`providers/*`, `storage-*`…, los que lista `nucleus_modules` en
`versions.yaml`), su CLI y lo que genera, y `pkg/nucleustest`.

## Tus dimensiones

Las diez filas de `pilar=nucleus` de la escala: `Routing/HTTP`, `Datos`,
`Auth/Authz`, `Jobs/Eventos`, `Observabilidad`, `Seguridad`, `Testing`,
`Docs/DX`, `CLI/generadores`, `Ecosistema/plugins`.

El listón: Echo y Goa en HTTP; el ORM y las migraciones de Django en datos;
Laravel Fortify/Sanctum y Spring Security en auth; Sidekiq, Oban y Solid
Queue en jobs; Spring Actuator en observabilidad; Django con OWASP ASVS L2 en
seguridad; Rails y Encore en testing; las docs de Django y Laravel; los
generadores de Rails y Buffalo; los starters de Spring y los paquetes de
Laravel. Los competidores de la tabla comparativa: Django, Rails, Laravel,
Spring Boot, NestJS, Phoenix, Encore, Buffalo, Gin+GORM+Casbin.

## Lo que corres

```bash
cd <paraguas>/nucleus
go build ./... && go vet ./... && go test -count=1 ./...
go test ./internal/authbench/ -run TestAuthBench -v     # Auth/Authz (43) + contracts/baseline/asvs_l2.txt
go test ./internal/jobsbench/ -run TestJobsBench -v     # Jobs/Eventos (40), /livez y /readyz
go test ./internal/apibench/  -run TestAPIBench  -v     # Routing/HTTP, Testing, OpenAPI (46)
bash scripts/ci/check_contract_freeze.sh                # postura de seguridad, CLI y config congelados
```

- **El banco del catálogo** (`internal/catalogbench`, A11) si el pin lo
  trae: es el instrumento de `Ecosistema/plugins`.
- **Las lanes de motor** del CI de nucleus (`.github/workflows/ci.yml`):
  PostgreSQL y MySQL en local con Docker, el resto por la corrida verde al
  commit del pin. La prueba de durabilidad de 10 000 jobs con el worker
  muerto a mitad (A7) y el claim de la cola con `SKIP LOCKED` (A12 `N2`)
  viven ahí.
- **Una aplicación nueva, como la haría un usuario**, en tu scratch, con el
  CLI construido de fuente al pin y `replace` a los checkouts del paraguas:
  `nucleus new --template suite --with orbit,quark,quarkbridge,quarkdatasource`,
  arrancarla, y recorrer lo que la página del quickstart promete. Después
  `nucleus generate module`, `routes`, `migrate status`, `dev` y
  `completion` sobre ESA aplicación: el 5 de `CLI/generadores` pide que vean
  el binario real.
- **`nucleus add <entrada>`** para cada entrada del catálogo sobre la
  aplicación recién generada: compila, arranca y deja la capacidad cableada
  (es el gate de A11).
- **Los módulos publicados por separado** con `GOWORK=off`, como los
  compilará quien los instale (NU-1 fue eso).
- **Los guards de doc** de nucleus (`scripts/ci/check_version_claims.sh`,
  `scripts/website/check-coverage.sh --strict`, `go run
  ./scripts/website/bodycheck -strict`, `check_internal_docs_drift.sh`,
  `check_retired_claims.sh`).

## Lo que verificas en particular

- **A5** (auth), **A7** (jobs, eventos, tiempo real), **A10** (testing y
  OpenAPI) y **A11** (catálogo): lee sus planes y comprueba cada sesión
  «hecha» de nucleus contra el pin.
- **El grafo**: cuántos módulos, paquetes y MB arrastra un hello con un
  driver (A12 `N1`, NU-106). Lo mide el auditor de rendimiento; tú miras que
  `go.mod` raíz no lleve dependencias que sólo usan los tests o la CLI, y que
  `nucleustest` no importe un driver en código de producción.
- **Los volteos del major** (`M0`): `session_idle_timeout` (NU-72),
  problem+json por defecto, `pkg/model` y cada constructor que cambia de
  firma tienen aviso `DEP-`, fila en la política y guía. `Context.Set`
  promocionado desde `router.Context` es la trampa conocida: quitarlo no hace
  nada.
- **Lo que `examples/` cubría**: el arranque del ejemplo canónico lo cubre
  ahora el starter. Las dos mediciones que se perdieron con los ejemplos
  —que el quickstart de nucleus sea copiable (NU-74) y los símbolos de la
  página «minimal API» (NU-75)— se repusieron en A10 (nucleus#583):
  comprueba que esas pruebas siguen en el pin y siguen contando.

## Tu informe

`nucleus.md`, con el formato de `comun.md`. Tu prefijo definitivo será NU;
tus ids provisionales, `nucleus.<n>`.
