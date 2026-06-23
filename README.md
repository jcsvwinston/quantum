# Quantum

Quantum es la **suite** formada por tres productos Go que se desarrollan por
separado y se coordinan bajo un mismo paraguas:

- **[Nucleus](https://github.com/jcsvwinston/nucleus)** — framework web MVC/REST. Es el anfitrión sobre el que montan los demás. *(v0.9.0)*
- **[Quark](https://github.com/jcsvwinston/quark)** — ORM para Go (SQLite, PostgreSQL, MySQL, MariaDB, MSSQL, Oracle). Pilar de la suite **y** usable en solitario en cualquier app Go. *(v1.1.5)*
- **[Orbit](https://github.com/jcsvwinston/orbit)** — producto de administración que monta in-process en una app Nucleus. *(v0.1.0)*

Las versiones de arriba son las del trío declarado hoy; el conjunto compatible
vigente vive en [`versions.yaml`](versions.yaml).

## El modelo paraguas

Este repositorio **coordina, no contiene**. No aloja el código de los productos
—viven en sus propios repos, con sus propias releases—, sino que fija qué trío de
versiones forma una release de la suite y ofrece un `go.work` para desarrollarlos
a la vez en local. La analogía es una distro de Linux: no incluye el código de
cada paquete, publica un manifiesto de qué versiones, probadas juntas, forman una
release.

Lo que el paraguas **sí** hace: declara conjuntos compatibles
([`versions.yaml`](versions.yaml)), da un `go.work` de desarrollo cruzado y —en
fases siguientes— alojará el sitio de docs unificado. Lo que **no** hace: no
absorbe el código, no decide las subversiones de cada producto, ni condiciona que
`go get github.com/jcsvwinston/quark` siga funcionando para cualquiera.

Decisión registrada en [QADR-0001](docs/adr/QADR-0001-multirepo-paraguas.md).

## Quark se puede usar solo

Quark es un ORM autónomo. Quantum lo presenta *además* como uno de sus pilares,
pero no introduce ninguna dependencia de Nucleus u Orbit para usarlo: `go get
github.com/jcsvwinston/quark` sigue siendo todo lo necesario en cualquier app Go.

## Versionado en dos niveles

- **Cada módulo** mantiene su propio SemVer y cadencia: `Quark v1.1.x`,
  `Nucleus v0.9.x` y `Orbit v0.1.x` avanzan cuando cada uno está listo, sin
  coordinación.
- **La suite** tiene su propio SemVer, que es el del *manifiesto*
  ([`versions.yaml`](versions.yaml)), no el de ningún módulo. Las subversiones de
  cada producto flotan entre releases Quantum; los majors solo se cruzan en una
  release Quantum coordinada (a partir de Quantum 1.0).

El número Quantum nunca sustituye al `vX.Y.Z` real que la gente instala. Detalle
en [QADR-0002](docs/adr/QADR-0002-versionado-dos-niveles.md).

## Desarrollo local cruzado

Los tres productos están enganchados como submódulos git; el `go.work` los enlaza
para trabajarlos a la vez:

```bash
git clone --recurse-submodules https://github.com/jcsvwinston/quantum.git
cd quantum

# Compila el trío fijado. El root del workspace no es un módulo Go, así que se
# pasan patrones explícitos por producto (Orbit es multi-módulo: agent/proto/server
# son módulos aparte y no los cubre ./orbit/...):
go build ./quark/... ./nucleus/... ./orbit/... ./orbit/agent/... ./orbit/proto/... ./orbit/server/...
```

El `go.work` es una conveniencia de desarrollo: **no se publica** como dependencia
y no tiene equivalente `replace` en los `go.mod` de los productos. En release,
cada módulo resuelve sus dependencias por tag real.

## Documentación

- [`docs/ROADMAP.md`](docs/ROADMAP.md) — plan de convergencia por fases.
- [`docs/adr/`](docs/adr/) — decisiones de arquitectura de la suite (QADR).
- Sitio de docs unificado: pendiente (Fase 2 del roadmap).

## Estado

Pre-fusión. Hoy el paraguas declara el trío compatible y habilita el desarrollo
cruzado. El sitio de docs unificado, el tooling de release homogéneo y la primera
release Quantum verificada por CI llegan en fases posteriores; ver
[`docs/ROADMAP.md`](docs/ROADMAP.md).

## Licencia

[Apache-2.0](LICENSE), alineada con Nucleus y Orbit. Cada producto conserva la
licencia de su propio repositorio.
