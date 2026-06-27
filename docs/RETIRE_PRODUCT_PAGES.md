# Retirar los Pages standalone de cada producto y redirigirlos al sitio unificado

> Runbook de **coordinación** (Fase 2, cierre). El sitio unificado
> (https://jcsvwinston.github.io/quantum/) ya sirve las docs de los tres
> productos; sus Pages standalone quedan redundantes. Aquí se documentan los pasos
> exactos para **retirarlos sin romper enlaces externos**: cada Pages se sustituye
> por un *redirector* estático que manda al lector a la sección equivalente del
> sitio unificado.
>
> **Estos pasos se ejecutan en los repos de PRODUCTO** (quark, nucleus, orbit), no
> en `quantum`. Esta sesión solo deja el plan; la ejecución es outward-facing
> (cambia URLs públicas) y la decide/ejecuta el responsable en cada repo.

## Por qué redirigir y no apagar

Apagar Pages (Settings → Pages → *None*) deja en 404 cualquier enlace externo o
marcador a `…/quark/docs/*` y a `…/nucleus/docs/*`, y pierde el SEO acumulado. En
su lugar, cada Pages se mantiene vivo pero publicando un **redirector**:

- `index.html` (servido con 200 en la raíz) → `meta-refresh` a la entrada
  unificada del producto.
- `404.html` (GitHub Pages lo sirve para cualquier ruta no encontrada) → un script
  que **mapea la ruta profunda** y reenvía, preservando enlaces a páginas concretas.

> Limitación honesta: el `404.html` se sirve con estado HTTP 404, así que el
> redirect es de cliente (JS/meta), no un 301. Es lo máximo que permite Pages
> estático; los buscadores acabarán reindexando hacia el sitio unificado vía el
> `<link rel="canonical">`.

## Lo que NO cambia (preserva las reglas duras)

- **La fuente de docs de cada producto se queda en su repo** (`website/docs`), y su
  sitio Docusaurus **sigue siendo construible en local**. Solo se retira el
  *deploy* hospedado, no el contenido (QADR-0003). [Regla dura: Quark usable en
  solitario — su código, su `go get` y su fuente de docs siguen intactos.]
- El sitio unificado no se toca: ya sirve los tres productos.

## Mapa de URLs (origen → destino)

| Producto | URL standalone (hoy) | Destino unificado |
|---|---|---|
| **Quark** | `…/quark/docs/<rest>` · raíz `…/quark/` | `…/quantum/quark/<rest>` · raíz → `…/quantum/quark/intro` |
| **Nucleus** | `…/nucleus/docs/<rest>` · raíz `…/nucleus/` | `…/quantum/nucleus/<rest>` · raíz → `…/quantum/nucleus/` |
| **Orbit** | `…/orbit/<cualquiera>` (solo landing estática) | `…/quantum/orbit/` |

El mapeo de Quark y Nucleus es una **sustitución de prefijo**: `/<prod>/docs` →
`/quantum/<prod>`. Orbit no tenía docs standalone (solo `site/index.html`), así que
todo va a la raíz unificada de Orbit.

> Nota sobre la raíz de Quark: en el sitio unificado, `/quantum/quark/` redirige por
> SPA-404 (ver `docusaurus.config.ts`), por eso el redirector apunta a
> `/quantum/quark/intro`, nunca a la raíz pelada.

## Ficheros del redirector

Crea en cada repo de producto una carpeta `pages-redirect/` con estos dos ficheros.
Ajusta `OLD` y `NEW` por producto (tabla abajo).

`pages-redirect/index.html` (raíz, 200):

```html
<!doctype html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <title>Movido a Quantum</title>
    <link rel="canonical" href="https://jcsvwinston.github.io/quantum/quark/intro" />
    <meta http-equiv="refresh" content="0; url=/quantum/quark/intro" />
    <meta name="robots" content="noindex" />
  </head>
  <body>
    Las docs viven ahora en
    <a href="/quantum/quark/intro">Quantum · Quark</a>.
  </body>
</html>
```

`pages-redirect/404.html` (rutas profundas):

```html
<!doctype html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <title>Movido a Quantum</title>
    <meta name="robots" content="noindex" />
    <script>
      (function () {
        // Ajusta estas dos constantes por repo (ver tabla).
        var OLD = '/quark/docs';
        var NEW = '/quantum/quark';
        var p = location.pathname;
        var rest = p.indexOf(OLD) === 0 ? p.slice(OLD.length) : '';
        var target = NEW + (rest && rest !== '/' ? rest : '/intro');
        location.replace(target + location.search + location.hash);
      })();
    </script>
  </head>
  <body>
    Esta página se ha movido al
    <a href="/quantum/quark/intro">sitio unificado de Quantum</a>.
  </body>
</html>
```

Constantes por producto:

| Producto | `OLD` | `NEW` | raíz `index.html` apunta a |
|---|---|---|---|
| Quark | `/quark/docs` | `/quantum/quark` | `/quantum/quark/intro` |
| Nucleus | `/nucleus/docs` | `/quantum/nucleus` | `/quantum/nucleus/` |
| Orbit | `/orbit` | `/quantum/orbit` | `/quantum/orbit/` |

> Para Nucleus y Orbit, el fallback de la raíz en `404.html` (`'/intro'`) debe ser
> `'/'` en lugar de `/intro` (Nucleus sirve su intro en la raíz vía `slug:/`; Orbit
> no tiene intro versionada). Es la única diferencia respecto al snippet de Quark.

## Cambio en el workflow de cada repo

La idea es dejar de **construir** Docusaurus y publicar el `pages-redirect/`.
Mantener Pages con *Source: GitHub Actions* (sin cambios en Settings).

- **Quark** — [`.github/workflows/deploy.yml`]: quita los pasos `setup-node` /
  `install` / `build`; cambia el `path:` de `actions/upload-pages-artifact` de
  `website/build` a `pages-redirect`.
- **Nucleus** — [`.github/workflows/docs.yml`]: igual (es el mismo patrón
  `upload-pages-artifact` → `website/build`).
- **Orbit** — [`.github/workflows/pages.yml`]: ya publica `./site` estático; basta
  con sustituir `site/index.html` por el redirector y añadir `site/404.html`. No
  hace falta tocar el workflow.

> Reversible: como solo se cambian los pasos de build/artefacto y la fuente
> Docusaurus se queda en `website/`, revertir = restaurar esos pasos.

## Orden y verificación

1. (Recomendado) Mergear antes los PRs de paraguas que dejan el sitio unificado
   limpio: enlaces `/docs/*` de Quark y búsqueda. No es bloqueante (el unificado ya
   sirve los tres), pero deja el destino pulido.
2. Aplicar el cambio en **un** repo primero (sugerido: Orbit, el más simple) y
   verificar antes de seguir con Quark/Nucleus.
3. Tras el deploy, comprobar (los redirects de cliente no se ven con `curl -I`;
   mira el cuerpo o abre en navegador):
   - `…/quark/docs/reference/api/errors` → `…/quantum/quark/reference/api/errors`
   - `…/nucleus/docs/` → `…/quantum/nucleus/`
   - `…/orbit/` → `…/quantum/orbit/`
4. Confirmar que el sitio unificado responde 200 en esos destinos.

## Pendiente relacionado (no parte de este runbook)

- **Hueco de CI**: el repo `quantum` no construye `website/` en PRs (solo
  `integration.yml` de Go + `deploy.yml` en `main`). Un cambio de sitio roto se
  vería al desplegar. Considerar un job `npm run build` en PRs que toquen
  `website/`.
