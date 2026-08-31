import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';
import {themes as prismThemes} from 'prism-react-renderer';
import * as fs from 'node:fs';
import * as path from 'node:path';
// remark-code-import es ESM-only; se consume vía require en la evaluación del
// config — el mismo shim que usa el sitio standalone de nucleus
// (nucleus/website/docusaurus.config.ts).
// eslint-disable-next-line @typescript-eslint/no-require-imports
const codeImport = require('remark-code-import').default;

// Lee el trío declarado en ../versions.yaml (sin dependencia de YAML: parse simple).
// El número Quantum y los tags reales de cada producto se muestran en la navbar
// (doble selector): versión de la suite arriba + versión real de cada módulo.
const suiteYaml = fs.readFileSync('../versions.yaml', 'utf8');
const block = (key: string): string =>
  suiteYaml.match(new RegExp(`^${key}:\\s*([\\s\\S]*?)\\n\\w`, 'm'))?.[1] ?? suiteYaml;
const modulesBlock = block('modules');
const pick = (name: string, from: string = modulesBlock): string =>
  (from.match(new RegExp(`${name}:\\s*"?([^"#\\n]+)`))?.[1] ?? '').trim();

// Bloque `require` con los NUEVE módulos del set certificado (los tres
// pilares + nucleus_modules + orbit_modules), generado desde versions.yaml en
// cada build — el espejo web de scripts/print-requires.sh. Lo consume la
// página de instalación de la instancia `start`
// (src/components/CertifiedSet.tsx): ninguna versión se transcribe a mano.
const nucleusModulesBlock = block('nucleus_modules');
const orbitModulesBlock = block('orbit_modules');
const requireBlock = [
  'require (',
  `\tgithub.com/jcsvwinston/quark ${pick('quark')}`,
  `\tgithub.com/jcsvwinston/nucleus ${pick('nucleus')}`,
  `\tgithub.com/jcsvwinston/nucleus/providers/ldap ${pick('ldap', nucleusModulesBlock)}`,
  `\tgithub.com/jcsvwinston/orbit ${pick('orbit')}`,
  ...['proto', 'agent', 'server', 'quarkbridge', 'quarkdatasource'].map(
    (m) => `\tgithub.com/jcsvwinston/orbit/${m} ${pick(m, orbitModulesBlock)}`,
  ),
  ')',
].join('\n');

const suite = {
  quantum: (suiteYaml.match(/^quantum:\s*"?([^"#\n]+)/m)?.[1] ?? '').trim(),
  nucleus: pick('nucleus'),
  quark: pick('quark'),
  orbit: pick('orbit'),
  requireBlock,
};

// Reescribe, durante el ENSAMBLAJE, los enlaces absolutos `/docs/*` que la
// fuente de Quark usa internamente (su routeBasePath standalone es `docs`, así
// que `/docs/X` resuelve allí a `/quark/docs/X`). Aquí Quark se sirve bajo
// `/quark/*`, donde esos enlaces caerían en `/quantum/docs/*` (404 + warning de
// broken link + 404 en navegación SPA). El plugin opera sobre el AST en memoria
// ANTES de los remark por defecto (que luego prefijan el baseUrl): el fichero
// fuente del submódulo NO se toca (QADR-0003), pero las rutas emitidas son
// reales (no un redirect estático), así que el checker de enlaces queda limpio y
// la navegación SPA funciona. Los snapshots versionados llevan los mismos
// enlaces absolutos sin versión: se reescriben a la doc ACTUAL de Quark, el
// mismo comportamiento que tienen en el sitio standalone de Quark.
function remarkQuarkDocsBase() {
  return (tree: unknown): void => {
    const visit = (node: any): void => {
      if (!node || typeof node !== 'object') return;
      if (node.type === 'link' && typeof node.url === 'string') {
        node.url = node.url.replace(/^\/docs(\/|#|$)/, '/quark$1');
      }
      if (Array.isArray(node.children)) node.children.forEach(visit);
    };
    visit(tree);
  };
}

// Sitio de documentación unificado de la suite Quantum (Fase 2).
// ENSAMBLA las docs de cada producto desde su submódulo — la fuente NO sale de
// cada repo (QADR-0003). Cada producto es una instancia de plugin-content-docs
// que apunta al `website/docs` del submódulo correspondiente.
//   - Nucleus → ../nucleus/website/docs   (sirve en /quantum/nucleus/)
//   - Quark   → ../quark/website/docs      (sirve en /quantum/quark/)
//   - Orbit   → ../orbit/website/docs      (sirve en /quantum/orbit/)
const config: Config = {
  title: 'Quantum',
  tagline:
    'A web framework, an ORM and an admin panel for Go: developed separately, coordinated as a suite.',
  favicon: 'img/quantum-mark.svg',

  url: 'https://jcsvwinston.github.io',
  baseUrl: '/quantum/',
  organizationName: 'jcsvwinston',
  projectName: 'quantum',

  // Expone el trío de versions.yaml a las páginas (la portada lo usa en sus chips).
  customFields: {suite},

  // Enlaces ROTOS tumban el build (QM6-3): tras el recorte de snapshots de la
  // 5ª ronda, un enlace colgante a una ruta retirada pasaría en 'warn' y el
  // lector aterrizaría en el 404. Hoy hay 0 rotos; 'throw' evita que vuelvan.
  // Las ANCLAS siguen en 'warn': quedan anclas rotas HEREDADAS en los
  // snapshots versionados CONGELADOS de Quark (p. ej. `#tx` en 0.8–1.0 de
  // reference/api/client) — historia inmutable (QADR-0003), rotas también en
  // su día en el sitio standalone.
  onBrokenLinks: 'throw',
  onBrokenAnchors: 'warn',

  // Idioma único del sitio: inglés (QADR-0007). Las docs de los tres
  // productos ya estaban en inglés; el chrome (portada, navegación, tema)
  // se alinea con ellas. Revertir = traducir las cadenas de chrome y
  // devolver este locale a 'es' (decisión reversible, ver el QADR).
  i18n: {defaultLocale: 'en', locales: ['en']},

  markdown: {
    mermaid: true,
    // Ubicación nueva en Docusaurus 3.10+ (el top-level está deprecado).
    hooks: {onBrokenMarkdownLinks: 'warn'},
  },
  // Búsqueda local offline (sin dependencia externa): indexa las tres
  // instancias de docs. El plugin soporta React 19 desde v0.47.0; aquí 0.55.2
  // sobre Docusaurus 3.10. Solo `en` desde QADR-0007 (sitio íntegro en inglés).
  themes: [
    '@docusaurus/theme-mermaid',
    [
      '@easyops-cn/docusaurus-search-local',
      {
        hashed: true,
        language: ['en'],
        docsRouteBasePath: ['start', 'nucleus', 'quark', 'orbit'],
        indexBlog: false,
        indexPages: false,
        highlightSearchTermsOnTargetPage: true,
      },
    ],
  ],

  presets: [
    [
      'classic',
      {
        // La instancia de docs por defecto se desactiva: usamos una instancia
        // por producto (abajo, en `plugins`).
        docs: false,
        blog: false,
        theme: {customCss: './src/css/custom.css'},
      } satisfies Preset.Options,
    ],
  ],

  plugins: [
    [
      '@docusaurus/plugin-content-docs',
      {
        // id `default`: @easyops-cn/docusaurus-search-local asume una instancia de
        // docs por defecto (su SearchBar y la página /search la requieren). Como
        // usamos `docs: false` + instancias con id propio, designamos a Nucleus
        // (la raíz host) como la default. No cambia su URL (routeBasePath sigue
        // `nucleus`); solo el id del plugin.
        id: 'default',
        path: '../nucleus/website/docs',
        routeBasePath: 'nucleus',
        sidebarPath: './sidebarsNucleus.ts',
        // editUrl como FUNCIÓN, no string: con string Docusaurus concatena la
        // ruta del doc RELATIVA AL SITIO, que aquí es `../nucleus/website/docs/…`
        // — el enlace "Edit this page" resultante normalizaba a
        // `edit/main/nucleus/website/docs/…`, una ruta que no existe en el repo
        // (206 enlaces rotos en el sitio publicado, las tres instancias). Para
        // los snapshots (convención sin prefijo de la instancia default),
        // versionDocsDirPath = `versioned_docs/version-X`, que coincide con el
        // layout del repo nucleus y se conserva tal cual.
        editUrl: ({versionDocsDirPath, docPath}) =>
          versionDocsDirPath.startsWith('..')
            ? `https://github.com/jcsvwinston/nucleus/edit/main/website/docs/${docPath}`
            : `https://github.com/jcsvwinston/nucleus/edit/main/website/${versionDocsDirPath}/${docPath}`,
        // remark-code-import: las fences ```go file=<rootDir>/…``` de los docs
        // de nucleus (quickstart, project-structure) las resuelve este plugin
        // en build time; su sitio standalone lo cablea en su preset
        // (nucleus/website/docusaurus.config.ts) y sin este espejo el
        // ensamblaje publicaba los bloques de código VACÍOS — Docusaurus emite
        // <code></code> sin avisar y el build sale verde (SD-01, 9ª ronda; lo
        // vigila scripts/check_built_codeblocks.sh sobre el HTML emitido).
        // rootDir = el SUBMÓDULO ../nucleus, que es lo que este sitio publica.
        //
        // Tradeoff aceptado: los snapshots versionados también importan el
        // ejemplo ACTUAL del submódulo pinado (la fence del snapshot referencia
        // <rootDir>, no una copia congelada) — el mismo criterio que ya rige
        // para los enlaces /docs/* de quark (ver remarkQuarkDocsBase arriba),
        // y el mismo comportamiento que tienen esos snapshots en el sitio
        // standalone de nucleus, cuyo rootDir es igualmente su árbol actual.
        remarkPlugins: [
          [codeImport, {
            rootDir: path.resolve(__dirname, '../nucleus'),
            removeRedundantIndentations: true,
            allowImportingFromOutside: true,
          }],
        ],
        // La raíz servida es SIEMPRE la doc actual, etiquetada con el tag real
        // del manifiesto. Sin esto, Docusaurus sirve por defecto el último
        // snapshot versionado — así es como el sitio publicado llegó a enseñar
        // docs viejas que contradecían la portada (QM5-1, 5ª auditoría).
        lastVersion: 'current',
        versions: {current: {label: suite.nucleus}},
      },
    ],
    [
      '@docusaurus/plugin-content-docs',
      {
        id: 'quark',
        path: '../quark/website/docs',
        routeBasePath: 'quark',
        sidebarPath: './sidebarsQuark.ts',
        // Función por la misma razón que la instancia default. Los snapshots de
        // Quark se sincronizan a `quark_versioned_docs/` en el paraguas
        // (sync-versions.mjs), pero en el REPO quark viven en
        // `website/versioned_docs/` — el replace deshace el prefijo del sync.
        editUrl: ({versionDocsDirPath, docPath}) =>
          versionDocsDirPath.startsWith('..')
            ? `https://github.com/jcsvwinston/quark/edit/main/website/docs/${docPath}`
            : `https://github.com/jcsvwinston/quark/edit/main/website/${versionDocsDirPath.replace(/^quark_/, '')}/${docPath}`,
        // Reescribe los enlaces `/docs/*` heredados de Quark a `/quark/*` (ver
        // remarkQuarkDocsBase arriba). Solo la instancia de Quark lo necesita.
        beforeDefaultRemarkPlugins: [remarkQuarkDocsBase],
        // Raíz = doc actual con el tag real (ver la instancia default arriba).
        lastVersion: 'current',
        versions: {current: {label: suite.quark}},
      },
    ],
    [
      '@docusaurus/plugin-content-docs',
      {
        id: 'orbit',
        path: '../orbit/website/docs',
        routeBasePath: 'orbit',
        sidebarPath: './sidebarsOrbit.ts',
        // Función porque un editUrl string concatena la ruta RELATIVA AL SITIO
        // y manda a los lectores a un 404 (así vivieron meses los 206 enlaces
        // «Edit this page» rotos de las tres instancias). Desde que orbit
        // versiona (v1.6.7), además hay que distinguir la doc actual de un
        // snapshot: `versionDocsDirPath` empieza por `..` solo para current.
        // Y los snapshots se sincronizan a `orbit_versioned_docs/` en el
        // paraguas, mientras en el REPO viven en `website/versioned_docs/` —
        // el replace deshace el prefijo del sync, igual que en Quark. Sin él
        // el enlace «Edit this page» de cada página de snapshot apunta a una
        // ruta que no existe en GitHub (lo cazó el guard de enlaces).
        editUrl: ({versionDocsDirPath, docPath}) =>
          versionDocsDirPath.startsWith('..')
            ? `https://github.com/jcsvwinston/orbit/edit/main/website/docs/${docPath}`
            : `https://github.com/jcsvwinston/orbit/edit/main/website/${versionDocsDirPath.replace(/^orbit_/, '')}/${docPath}`,
        // La raíz servida es SIEMPRE la doc actual, etiquetada con el tag real
        // del manifiesto — igual que nucleus y quark. Sin esto Docusaurus
        // sirve por defecto el último snapshot, que es como el sitio llegó a
        // enseñar docs viejas contradiciendo la portada (QM5-1).
        //
        // Consecuencia deliberada: NINGUNA ruta existente se mueve. `/orbit/…`
        // sigue sirviendo la doc actual; los snapshots aparecen bajo su ruta
        // de versión. El cambio es aditivo.
        lastVersion: 'current',
        versions: {current: {label: suite.orbit}},
      },
    ],
    [
      // La instancia de Quark no genera su raíz (`/quark/`): el intro de Quark no
      // declara `slug: /` (el de Nucleus sí), así que su raíz da 404 y a ella
      // apuntan los enlaces "home" internos de sus docs. Redirigimos a la primera
      // página, sin tocar la fuente de Quark (QADR-0003).
      //
      // OJO: este redirect es un fichero estático (meta-refresh), NO una ruta del
      // router. Cubre el acceso DIRECTO a /quark/ (recarga, enlace externo), pero
      // un <Link to="/quark/"> dentro del sitio navega por SPA y cae en el 404 del
      // router. Por eso TODOS los enlaces internos a Quark apuntan a /quark/intro/
      // (la portada, el footer y el dropdown vía docSidebar), no a la raíz pelada.
      '@docusaurus/plugin-client-redirects',
      {
        redirects: [
          {from: '/quark', to: '/quark/intro'},
          // QM6-2: la 5ª ronda retiró 13 rutas de snapshot del paraguas (la
          // cola pasó a «último patch por minor de la línea 1.x»), pero el
          // redirector de Pages de quark sigue reenviando URLs profundas
          // antiguas hacia aquí — sin esto aterrizaban en el 404. Los roots
          // 0.x van al intro del producto (contenido pre-1.0 sin gemelo
          // servido); los patch retirados 1.2.0/1.2.1 se cubren ruta a ruta
          // en createRedirects, abajo.
          ...['0.3.0', '0.4.0', '0.5.0', '0.6.0', '0.7.0', '0.8.0', '0.9.0',
              '0.10.0', '0.11.0', '0.12.0', '0.13.0'].map((v) => ({
            from: `/quark/${v}`,
            to: '/quark/intro',
          })),
        ],
        // Cada página del snapshot conservado 1.2.2 responde también por las
        // rutas de los patch retirados de su minor (1.2.0/1.2.1): el lector
        // con una URL vieja cae en el MISMO documento, un patch más nuevo.
        createRedirects(existingPath) {
          const m = existingPath.match(/^\/quark\/1\.2\.2(\/.*)?$/);
          if (m) {
            const tail = m[1] ?? '';
            return [`/quark/1.2.0${tail}`, `/quark/1.2.1${tail}`];
          }
          return undefined;
        },
      },
    ],
    [
      // Instancia `start` — la puerta de entrada de la SUITE (9ª ronda). A
      // diferencia de las tres instancias de producto, su fuente NO es un
      // submódulo: vive en website/docs/ del propio paraguas, porque cuenta lo
      // que ningún producto puede contar solo (qué es Quantum, el quickstart
      // integrador, la elección de capa de datos, el set certificado y su
      // instalación). Sin versionado: la puerta de entrada siempre habla del
      // set vigente.
      '@docusaurus/plugin-content-docs',
      {
        id: 'start',
        path: 'docs',
        routeBasePath: 'start',
        sidebarPath: './sidebarsStart.ts',
        // editUrl string: aquí sí funciona la concatenación por defecto — el
        // path es relativo al sitio (docs/…), a diferencia de las instancias
        // de producto (../<producto>/…), que necesitan la forma función.
        editUrl: 'https://github.com/jcsvwinston/quantum/edit/main/website/',
      },
    ],
  ],

  themeConfig: {
    image: 'img/quantum-mark.svg',
    colorMode: {respectPrefersColorScheme: true},
    navbar: {
      title: 'Quantum',
      logo: {
        alt: 'Quantum',
        src: 'img/quantum-mark.svg',
        srcDark: 'img/quantum-mark-dark.svg',
      },
      items: [
        {
          // «Start» PRIMERO: la puerta de entrada de la suite (instancia
          // `start`). Antes de esto el navbar solo ofrecía topología (tres
          // productos, tres versiones) y ninguna respuesta a «¿por dónde
          // empiezo?».
          type: 'docSidebar',
          sidebarId: 'startSidebar',
          docsPluginId: 'start',
          label: 'Start',
          position: 'left',
        },
        {
          // Selector "Quantum": el número de la suite arriba (de versions.yaml) y,
          // como items, los tres pilares con su tag real (switcher + versión).
          type: 'dropdown',
          label: `Quantum ${suite.quantum}`,
          position: 'left',
          items: [
            {
              type: 'docSidebar',
              sidebarId: 'nucleusSidebar',
              docsPluginId: 'default',
              label: `Nucleus · web framework · ${suite.nucleus}`,
            },
            {
              type: 'docSidebar',
              sidebarId: 'quarkSidebar',
              docsPluginId: 'quark',
              label: `Quark · ORM · ${suite.quark}`,
            },
            {
              type: 'docSidebar',
              sidebarId: 'orbitSidebar',
              docsPluginId: 'orbit',
              label: `Orbit · admin panel · ${suite.orbit}`,
            },
          ],
        },
        {
          // Selector de versión de Quark. Docusaurus pinta estos dropdowns en
          // TODAS las páginas; el swizzle de
          // src/theme/NavbarItem/DocsVersionDropdownNavbarItem los limita a
          // las rutas de su producto (sin él, leyendo nucleus veías el chip de
          // versión de quark al lado del suyo).
          type: 'docsVersionDropdown',
          docsPluginId: 'quark',
          position: 'right',
        },
        {
          // Selector de versión de Nucleus (instancia `default`). Mismo
          // scoping por swizzle que el de Quark.
          type: 'docsVersionDropdown',
          docsPluginId: 'default',
          position: 'right',
        },
        {
          // Selector de versión de Orbit. Existe desde que orbit versiona
          // (v1.6.7); mismo scoping por swizzle que los otros dos.
          type: 'docsVersionDropdown',
          docsPluginId: 'orbit',
          position: 'right',
        },
        {
          href: 'https://github.com/jcsvwinston/quantum',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Products',
          items: [
            {label: 'Start here', to: '/start/'},
            {label: 'Nucleus', to: '/nucleus/'},
            {label: 'Quark', to: '/quark/intro/'},
            {label: 'Orbit', to: '/orbit/'},
          ],
        },
        {
          title: 'Suite',
          items: [
            {label: 'quantum', href: 'https://github.com/jcsvwinston/quantum'},
            {label: 'nucleus', href: 'https://github.com/jcsvwinston/nucleus'},
            {label: 'quark', href: 'https://github.com/jcsvwinston/quark'},
            {label: 'orbit', href: 'https://github.com/jcsvwinston/orbit'},
          ],
        },
      ],
      copyright: `Quantum · suite · Apache-2.0`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['go', 'bash', 'sql'],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
