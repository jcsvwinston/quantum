// Sincroniza el histórico de versiones de cada producto desde su submódulo a la
// convención que Docusaurus espera para una instancia con id <X>:
//   <siteDir>/<X>_versions.json, <X>_versioned_docs/, <X>_versioned_sidebars/
// La instancia con id `default` (nucleus, ver docusaurus.config.ts) usa la
// convención SIN prefijo: <siteDir>/versions.json, versioned_docs/, …
// La fuente vive en el repo de cada producto (QADR-0003): aquí solo se ENSAMBLA en
// build-time. Lo copiado está gitignored y se regenera en cada `build`/`start`.
import {
  cpSync,
  copyFileSync,
  rmSync,
  existsSync,
  readFileSync,
  readdirSync,
  writeFileSync,
} from 'node:fs';

const PRODUCTS = [
  {id: 'quark', src: '../quark/website', prefix: 'quark_'},
  // nucleus es la instancia `default` → convención sin prefijo. Su sitio propio
  // llama al sidebar `tutorialSidebar`; la instancia de la suite lo llama
  // `nucleusSidebar` (y la navbar lo referencia) — se renombra al ensamblar,
  // sin tocar la fuente (QADR-0003).
  {
    id: 'nucleus',
    src: '../nucleus/website',
    prefix: '',
    renameSidebar: {from: 'tutorialSidebar', to: 'nucleusSidebar'},
  },
];

for (const {id, src, prefix, renameSidebar} of PRODUCTS) {
  const versionsFile = `${src}/versions.json`;
  if (!existsSync(versionsFile)) {
    console.log(`[sync-versions] ${id}: sin versions.json — salto (instancia solo "current")`);
    continue;
  }
  for (const suffix of ['versioned_docs', 'versioned_sidebars']) {
    rmSync(`${prefix}${suffix}`, {recursive: true, force: true});
  }
  cpSync(`${src}/versioned_docs`, `${prefix}versioned_docs`, {recursive: true});
  cpSync(`${src}/versioned_sidebars`, `${prefix}versioned_sidebars`, {recursive: true});
  copyFileSync(versionsFile, `${prefix}versions.json`);
  if (renameSidebar) {
    for (const file of readdirSync(`${prefix}versioned_sidebars`)) {
      const path = `${prefix}versioned_sidebars/${file}`;
      const sidebars = JSON.parse(readFileSync(path, 'utf8'));
      if (renameSidebar.from in sidebars) {
        sidebars[renameSidebar.to] = sidebars[renameSidebar.from];
        delete sidebars[renameSidebar.from];
        writeFileSync(path, JSON.stringify(sidebars, null, 2) + '\n');
      }
    }
  }
  const n = JSON.parse(readFileSync(versionsFile, 'utf8')).length;
  console.log(`[sync-versions] ${id}: ${n} versiones sincronizadas`);
}
