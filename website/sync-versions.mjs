// Sincroniza el histórico de versiones de cada producto desde su submódulo a la
// convención que Docusaurus espera para una instancia con id <X>:
//   <siteDir>/<X>_versions.json, <X>_versioned_docs/, <X>_versioned_sidebars/
// La fuente vive en el repo de cada producto (QADR-0003): aquí solo se ENSAMBLA en
// build-time. Lo copiado está gitignored y se regenera en cada `build`/`start`.
import {cpSync, copyFileSync, rmSync, existsSync, readFileSync} from 'node:fs';

const PRODUCTS = [{id: 'quark', src: '../quark/website'}];

for (const {id, src} of PRODUCTS) {
  const versionsFile = `${src}/versions.json`;
  if (!existsSync(versionsFile)) {
    console.log(`[sync-versions] ${id}: sin versions.json — salto (instancia solo "current")`);
    continue;
  }
  for (const suffix of ['_versioned_docs', '_versioned_sidebars']) {
    rmSync(`${id}${suffix}`, {recursive: true, force: true});
  }
  cpSync(`${src}/versioned_docs`, `${id}_versioned_docs`, {recursive: true});
  cpSync(`${src}/versioned_sidebars`, `${id}_versioned_sidebars`, {recursive: true});
  copyFileSync(versionsFile, `${id}_versions.json`);
  const n = JSON.parse(readFileSync(versionsFile, 'utf8')).length;
  console.log(`[sync-versions] ${id}: ${n} versiones sincronizadas`);
}
