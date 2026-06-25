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

// Sitio de documentación unificado de la suite Quantum (Fase 2).
// ENSAMBLA las docs de cada producto desde su submódulo — la fuente NO sale de
// cada repo (QADR-0003). Cada producto es una instancia de plugin-content-docs
// que apunta al `website/docs` del submódulo correspondiente.
//   - Nucleus → ../nucleus/website/docs   (sirve en /quantum/nucleus/)
//   - Quark   → ../quark/website/docs      (sirve en /quantum/quark/)
//   - Orbit   → pendiente: aún no tiene website/docs (se escribe en Fase 3).
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

  // Las docs vienen de otros repos: los enlaces/anclas/imágenes que asuman su
  // baseUrl propio pueden no resolver aquí. No tumbamos el build por eso.
  onBrokenLinks: 'warn',
  onBrokenMarkdownLinks: 'warn',
  onBrokenAnchors: 'warn',

  i18n: {defaultLocale: 'es', locales: ['es']},

  markdown: {mermaid: true},
  // Búsqueda: pendiente. @easyops-cn/docusaurus-search-local rompe el SSR con
  // React 19 (Docusaurus 3.10). Reevaluar cuando el plugin lo soporte, o usar
  // Algolia DocSearch.
  themes: ['@docusaurus/theme-mermaid'],

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
        id: 'nucleus',
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
              docsPluginId: 'nucleus',
              label: `Nucleus · framework web · ${suite.nucleus}`,
            },
            {
              type: 'docSidebar',
              sidebarId: 'quarkSidebar',
              docsPluginId: 'quark',
              label: `Quark · ORM · ${suite.quark}`,
            },
            {label: `Orbit · admin · ${suite.orbit} (pronto)`, to: '/'},
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
