import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

// Sidebar de la instancia `start` (puerta de entrada de la suite). A diferencia
// de sidebarsNucleus/sidebarsQuark, NO es un espejo de ningún submódulo: la
// fuente vive aquí, en website/docs/ del paraguas, así que no participa en
// check_sidebar_sync.sh. Orden = el recorrido del lector nuevo.
const sidebars: SidebarsConfig = {
  startSidebar: [
    'what-is-quantum',
    'quickstart',
    'install',
    'choosing-a-data-layer',
    'certified-sets',
  ],
};

export default sidebars;
