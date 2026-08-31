import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

// ESPEJO del sidebar curado de ../nucleus/website/sidebars.ts (clave renombrada
// tutorialSidebar→nucleusSidebar, que es la que referencia la navbar). Al
// cambiar la estructura en nucleus, portarla aquí — el paraguas no puede
// importar el fichero del submódulo directamente porque su clave difiere.
const sidebars: SidebarsConfig = {
  nucleusSidebar: [
    'intro',
    {
      type: 'category',
      label: 'Getting started',
      collapsed: false,
      link: {
        type: 'generated-index',
        title: 'Getting started',
        description: 'Install the CLI, scaffold a project, run the server.',
      },
      items: [
        'getting-started/installation',
        'getting-started/quickstart',
        'getting-started/minimal-api',
        'getting-started/project-structure',
        'getting-started/testing',
      ],
    },
    {
      type: 'category',
      label: 'Concepts',
      collapsed: false,
      link: {
        type: 'generated-index',
        title: 'Concepts',
        description:
          'The runtime building blocks: application container, configuration, routing, models.',
      },
      items: [
        'concepts/application',
        'concepts/configuration',
        'concepts/routing',
        'concepts/models-and-database',
      ],
    },
    {
      type: 'category',
      label: 'Features',
      collapsed: false,
      link: {
        type: 'generated-index',
        title: 'Features',
        description:
          'Auth, multi-tenancy, observability, storage, background tasks, and the orbit admin module.',
      },
      items: [
        {
          type: 'category',
          label: 'Authentication & authorization',
          link: {type: 'doc', id: 'features/auth/index'},
          items: [
            'features/auth/your-first-login',
            'features/auth/sessions-and-passwords',
            'features/auth/jwt',
            'features/auth/rbac-and-middleware',
            'features/auth/backends-and-federation',
          ],
        },
        'features/using-quark',
        'features/storage-and-tasks',
        'features/events',
        'features/i18n',
        'features/cache',
        'features/observability',
        'features/admin',
      ],
    },
    {
      type: 'category',
      label: 'Operations',
      collapsed: false,
      link: {
        type: 'generated-index',
        title: 'Operations',
        description:
          'Running Nucleus in production: deployment, security hardening, and upgrades.',
      },
      items: [
        'operations/deployment',
        'operations/security',
        'operations/upgrade',
      ],
    },
    {
      type: 'category',
      label: 'Reference',
      collapsed: false,
      link: {
        type: 'generated-index',
        title: 'Reference',
        description:
          'The nucleus CLI, every configuration key, and what changed in each release.',
      },
      items: [
        'cli/overview',
        'reference/configuration',
        'reference/release-notes',
      ],
    },
    {
      type: 'category',
      label: 'Architecture',
      collapsed: false,
      link: {
        type: 'generated-index',
        title: 'Architecture',
        description:
          'Principles, contracts and the compatibility policy that pin the public surface.',
      },
      items: ['architecture/principles', 'architecture/compatibility'],
    },
    'faq',
  ],
};

export default sidebars;
