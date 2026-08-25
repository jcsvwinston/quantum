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
  mkdirSync,
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
  // orbit versiona desde v1.6.7 (antes servía siempre su doc actual, así que
  // quien corría una versión anterior leía la del set vigente). Su sidebar
  // versionada ya se llama `orbitSidebar` y es autogenerada, así que no hay
  // renombrado que hacer al ensamblar.
  {id: 'orbit', src: '../orbit/website', prefix: 'orbit_'},
];

// Cola de snapshots servidos por el paraguas (decisión de la 5ª ronda, QM5-1):
// SOLO el último patch de cada minor de la línea 1.x. La historia 0.x queda en
// el repo de cada producto; los patches superados (1.2.0, 1.2.1…) no aportan al
// lector y multiplican la superficie que el linter post-build debe mantener
// limpia. La doc por defecto es SIEMPRE "current" (lastVersion en
// docusaurus.config.ts); los snapshots que pasan este filtro se sirven como
// archivo bajo su ruta de versión y están sujetos al mismo linter de jerga que
// el resto del sitio.
function servedVersions(all) {
  const byMinor = new Map();
  for (const v of all) {
    const m = v.match(/^(\d+)\.(\d+)\.(\d+)$/);
    if (!m || Number(m[1]) < 1) continue;
    const key = `${m[1]}.${m[2]}`;
    const cur = byMinor.get(key);
    if (!cur || Number(m[3]) > cur.patch) byMinor.set(key, {v, patch: Number(m[3])});
  }
  const keep = new Set([...byMinor.values()].map((e) => e.v));
  return all.filter((v) => keep.has(v)); // conserva el orden de versions.json
}

for (const {id, src, prefix, renameSidebar} of PRODUCTS) {
  const versionsFile = `${src}/versions.json`;
  if (!existsSync(versionsFile)) {
    console.log(`[sync-versions] ${id}: sin versions.json — salto (instancia solo "current")`);
    continue;
  }
  for (const suffix of ['versioned_docs', 'versioned_sidebars']) {
    rmSync(`${prefix}${suffix}`, {recursive: true, force: true});
  }
  const all = JSON.parse(readFileSync(versionsFile, 'utf8'));
  const served = servedVersions(all);
  mkdirSync(`${prefix}versioned_docs`, {recursive: true});
  mkdirSync(`${prefix}versioned_sidebars`, {recursive: true});
  for (const v of served) {
    cpSync(`${src}/versioned_docs/version-${v}`, `${prefix}versioned_docs/version-${v}`, {
      recursive: true,
    });
    copyFileSync(
      `${src}/versioned_sidebars/version-${v}-sidebars.json`,
      `${prefix}versioned_sidebars/version-${v}-sidebars.json`,
    );
  }
  writeFileSync(`${prefix}versions.json`, JSON.stringify(served, null, 2) + '\n');
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
  console.log(
    `[sync-versions] ${id}: ${served.length}/${all.length} snapshots servidos (último patch por minor ≥1.x): ${served.join(', ')}`,
  );
}
