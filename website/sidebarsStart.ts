import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

// Sidebar de la instancia `start` (puerta de entrada de la suite). A diferencia
// de sidebarsNucleus/sidebarsQuark, NO es un espejo de ningún submódulo: la
// fuente vive aquí, en website/docs/ del paraguas, así que no participa en
// check_sidebar_sync.sh. Orden = el recorrido del lector nuevo.
const sidebars: SidebarsConfig = {
  startSidebar: [
    'what-is-quantum',
    // Por qué la suite y no otra pila, con cada cifra atada a su fuente por
    // scripts/check_why_quantum.sh (guard umbrella-why-quantum).
    'why-quantum',
    'quickstart',
    'install',
    {
      // Tres aplicaciones de punta a punta, cada una ejecutada paso a paso
      // por la lane tutorials-smoke (scripts/ci/tutorials_smoke.sh).
      type: 'category',
      label: 'Tutorials',
      collapsed: false,
      items: [
        'tutorial-multi-tenant-saas',
        'tutorial-api-only',
        'tutorial-mvc-monolith',
      ],
    },
    {
      // Desde otra pila: el mapa de conceptos y una app portada, con los
      // pasos del lado Quantum ejecutados por la misma lane tutorials-smoke.
      type: 'category',
      label: 'Migration guides',
      collapsed: false,
      items: [
        'coming-from-gin-gorm',
        'coming-from-django',
      ],
    },
    'choosing-a-data-layer',
    'certified-sets',
    'verifying-a-set',
    {
      // Generadas del árbol al pin por scripts/lib/site-pages.py (la tabla
      // del CLI de nucleus y los ficheros con los que cada producto congela
      // su API) y comparadas con él por el guard umbrella-generated-pages:
      // no se editan a mano.
      type: 'category',
      label: 'Reference',
      collapsed: false,
      items: [
        'reference/catalog',
        {
          type: 'category',
          label: 'API surface',
          collapsed: true,
          items: ['reference/api-nucleus', 'reference/api-quark', 'reference/api-orbit'],
        },
      ],
    },
  ],
};

export default sidebars;
