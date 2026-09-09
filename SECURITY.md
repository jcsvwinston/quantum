# Política de seguridad

Quantum es el repositorio **paraguas**: coordina un set certificado de tres
productos y no contiene código que se ejecute en la aplicación de nadie. El
código —y por tanto la superficie de ataque— vive en los repos de los
productos, cada uno con su propia política, su canal privado y su ventana de
soporte:

| Producto | Política | Canal privado |
|---|---|---|
| Nucleus (framework web) | [nucleus/SECURITY.md](https://github.com/jcsvwinston/nucleus/blob/main/SECURITY.md) | [Security → Report a vulnerability](https://github.com/jcsvwinston/nucleus/security/advisories/new) |
| Quark (ORM) | [quark/SECURITY.md](https://github.com/jcsvwinston/quark/blob/main/SECURITY.md) | [Security → Report a vulnerability](https://github.com/jcsvwinston/quark/security/advisories/new) |
| Orbit (panel de administración) | [orbit/SECURITY.md](https://github.com/jcsvwinston/orbit/blob/main/SECURITY.md) | [Security → Report a vulnerability](https://github.com/jcsvwinston/orbit/security/advisories/new) |

## Cómo reportar

**No abras un issue público** para una vulnerabilidad.

1. Si sabes en qué producto está, usa el advisory privado de ESE repo (tabla
   de arriba).
2. Si no lo sabes, o afecta a la combinación certificada (un set cuyos
   módulos son seguros por separado y no juntos), abre un advisory privado en
   este repo: [Security → Report a vulnerability](https://github.com/jcsvwinston/quantum/security/advisories/new).
3. Si ninguno está disponible, escribe a **serrano.juan.carlos@gmail.com**.

Incluye qué versión (el número de set `Quantum X.Y.Z` o el tag del módulo),
cómo reproducirlo y el impacto que ves. Se acusa recibo en el plazo que
declara cada producto; la corrección sale como patch del producto afectado y
un set nuevo la certifica (fuera de cadencia si hace falta — ver
[QADR-0008](docs/adr/QADR-0008-cadencia-de-certificacion.md)).

## Qué cubre un set certificado

Certificar un set significa que las versiones que `versions.yaml` declara
compilan y pasan sus guards juntas, y que cada versión corresponde al tag
publicado. **No** significa que cada set reciba parches de seguridad de por
vida: los parches siguen la ventana de cada producto (últimos dos minors
etiquetados en Nucleus y Quark; último minor de cada módulo en Orbit). Un set
antiguo con un pilar fuera de esa ventana no recibe corrección — se actualiza
al set vigente.

Los tres CI de producto ejecutan `govulncheck`; el paraguas mantiene sus
dependencias de sitio y de Actions con Dependabot (`.github/dependabot.yml`).

## Cómo comprobar que un set es el que publicamos

Desde el primer tag firmado, la release de cada set publica el manifiesto, el
bloque `require` pegable y los gitlinks de los tres productos junto a un
`checksums.txt` firmado **sin clave** por la corrida que lo construyó
(`.github/workflows/release-set.yml`), más una atestación de procedencia. No
hay clave de firma que custodiar: lo que se comprueba es qué workflow, de qué
repositorio y en qué tag firmó.

Las invocaciones exactas de `cosign verify-blob` y `gh attestation verify`,
con la identidad que hay que exigir, están en
[Verifying a set](https://jcsvwinston.github.io/quantum/start/verifying-a-set).

Lo que esto **no** cubre: el tag de suite en sí es un tag anotado sin firmar
—se firma el contenido del set, no el puntero— y los binarios de cada producto
se verifican en su propio repositorio, donde se publican.
