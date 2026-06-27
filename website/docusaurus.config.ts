import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';
import {themes as prismThemes} from 'prism-react-renderer';
import * as fs from 'node:fs';

// Lee el trío declarado en ../versions.yaml (sin dependencia de YAML: parse simple).
// El número Quantum y los tags reales de cada producto se muestran en la navbar
// (doble selector): versión de la suite arriba + versión real de cada módulo.
const suiteYaml = fs.readFileSync('../versions.yaml', 'utf8');
const modulesBlock = suiteYaml.match(/modules:\s*([\s\S]*?)\n\w/)?.[1] ?? suiteYaml;
const pick = (name: string): string =>
  (modulesBlock.match(new RegExp(`${name}:\\s*"?([^"#\\n]+)`))?.[1] ?? '').trim();
const suite = {
  quantum: (suiteYaml.match(/^quantum:\s*"?([^"#\n]+)/m)?.[1] ?? '').trim(),
  nucleus: pick('nucleus'),
  quark: pick('quark'),
  orbit: pick('orbit'),
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
    'Framework web, ORM y panel de administración para Go: desarrollados por separado, coordinados como suite.',
  favicon: 'img/quantum-mark.svg',

  url: 'https://jcsvwinston.github.io',
  baseUrl: '/quantum/',
  organizationName: 'jcsvwinston',
  projectName: 'quantum',

  // Expone el trío de versions.yaml a las páginas (la portada lo usa en sus chips).
  customFields: {suite},

  // Las docs vienen de otros repos. Los enlaces `/docs/*` de Quark se reescriben
  // en el ensamblaje (remarkQuarkDocsBase), pero quedan anclas rotas HEREDADAS en
  // los snapshots versionados CONGELADOS de Quark (p. ej. `#tx` en versiones
  // 0.8–1.0 de reference/api/client): son historia inmutable de Quark — no se
  // tocan (QADR-0003) y rotas están también en su sitio standalone. Por eso
  // `onBrokenAnchors: 'warn'` (avisa, no tumba el build).
  onBrokenLinks: 'warn',
  onBrokenAnchors: 'warn',

  i18n: {defaultLocale: 'es', locales: ['es']},

  markdown: {
    mermaid: true,
    // Ubicación nueva en Docusaurus 3.10+ (el top-level está deprecado).
    hooks: {onBrokenMarkdownLinks: 'warn'},
  },
  // Búsqueda local offline (sin dependencia externa): indexa las tres instancias
  // de docs. El plugin soporta React 19 desde v0.47.0; aquí 0.55.2 sobre
  // Docusaurus 3.10. `en` + `es` porque las docs de Quark están en inglés y las
  // de Nucleus/Orbit en español.
  themes: [
    '@docusaurus/theme-mermaid',
    [
      '@easyops-cn/docusaurus-search-local',
      {
        hashed: true,
        language: ['en', 'es'],
        docsRouteBasePath: ['nucleus', 'quark', 'orbit'],
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
        editUrl: 'https://github.com/jcsvwinston/nucleus/edit/main/website/',
      },
    ],
    [
      '@docusaurus/plugin-content-docs',
      {
        id: 'quark',
        path: '../quark/website/docs',
        routeBasePath: 'quark',
        sidebarPath: './sidebarsQuark.ts',
        editUrl: 'https://github.com/jcsvwinston/quark/edit/main/website/',
        // Reescribe los enlaces `/docs/*` heredados de Quark a `/quark/*` (ver
        // remarkQuarkDocsBase arriba). Solo la instancia de Quark lo necesita.
        beforeDefaultRemarkPlugins: [remarkQuarkDocsBase],
      },
    ],
    [
      '@docusaurus/plugin-content-docs',
      {
        id: 'orbit',
        path: '../orbit/website/docs',
        routeBasePath: 'orbit',
        sidebarPath: './sidebarsOrbit.ts',
        editUrl: 'https://github.com/jcsvwinston/orbit/edit/main/website/',
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
        redirects: [{from: '/quark', to: '/quark/intro'}],
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
              label: `Nucleus · framework web · ${suite.nucleus}`,
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
              label: `Orbit · admin · ${suite.orbit}`,
            },
          ],
        },
        {
          // Selector de versión real de Quark (su histórico: 13 versiones).
          // Aparece en las páginas de la instancia Quark.
          type: 'docsVersionDropdown',
          docsPluginId: 'quark',
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
          title: 'Productos',
          items: [
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
