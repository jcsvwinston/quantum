import React, {type ReactNode} from 'react';
import Layout from '@theme/Layout';
import Link from '@docusaurus/Link';
import ThemedImage from '@theme/ThemedImage';
import useBaseUrl from '@docusaurus/useBaseUrl';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import styles from './index.module.css';

// Glifos de marca por pilar (ver docs/brand/): estructura en currentColor,
// el "punto activo" en verde señal. SVG, no emojis (checklist UI/UX).
const box = (
  <rect x="3" y="3" width="18" height="18" rx="4" fill="none"
    stroke="currentColor" strokeWidth="1" opacity="0.35" />
);
function NucleusGlyph(): ReactNode {
  return (
    <svg viewBox="0 0 24 24" width="26" height="26" role="img" aria-label="Nucleus">
      {box}
      <line x1="7" y1="12" x2="17" y2="12" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" />
      <circle cx="12" cy="12" r="2.2" fill="var(--qtm-signal)" />
    </svg>
  );
}
function QuarkGlyph(): ReactNode {
  return (
    <svg viewBox="0 0 24 24" width="26" height="26" role="img" aria-label="Quark">
      {box}
      <path d="M9 6 H7 V18 H9 M15 6 H17 V18 H15" fill="none" stroke="currentColor"
        strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx="12" cy="12" r="2.6" fill="var(--qtm-signal)" />
    </svg>
  );
}
function OrbitGlyph(): ReactNode {
  return (
    <svg viewBox="0 0 24 24" width="26" height="26" role="img" aria-label="Orbit">
      {box}
      <circle cx="12" cy="12" r="2" fill="currentColor" />
      <path d="M12 5.2 A6.8 6.8 0 0 1 18.8 12" fill="none" stroke="currentColor"
        strokeWidth="1.4" strokeLinecap="round" opacity="0.6" />
      <circle cx="18.8" cy="12" r="2.2" fill="var(--qtm-signal)" />
    </svg>
  );
}

type Suite = {quantum: string; nucleus: string; quark: string; orbit: string};

export default function Home(): ReactNode {
  const {siteConfig} = useDocusaurusContext();
  const suite = siteConfig.customFields!.suite as Suite;
  const markLight = useBaseUrl('/img/quantum-mark.svg');
  const markDark = useBaseUrl('/img/quantum-mark-dark.svg');

  const pillars = [
    {
      name: 'Nucleus', role: 'el anfitrión', ver: suite.nucleus, to: '/nucleus/',
      glyph: <NucleusGlyph />,
      desc: 'Framework web MVC/REST, stdlib-first. Las apps montan sobre él; Orbit monta dentro.',
    },
    {
      // A /quark/intro/ (ruta real), no a /quark/ (la raíz de Quark es solo un
      // redirect estático: 404 en navegación SPA). Ver docusaurus.config.ts.
      name: 'Quark', role: 'la capa de datos · suelto', ver: suite.quark, to: '/quark/intro/',
      glyph: <QuarkGlyph />,
      desc: 'ORM type-safe para seis motores SQL. Usable en solitario en cualquier app Go.',
    },
    {
      name: 'Orbit', role: 'la administración', ver: suite.orbit, to: '/orbit/',
      glyph: <OrbitGlyph />,
      desc: 'Panel de admin que monta in-process en Nucleus: Data Studio, feed en vivo, sesiones, RBAC y métricas.',
    },
  ];

  return (
    <Layout
      title="Quantum"
      description="Suite Go: Nucleus (framework web), Quark (ORM) y Orbit (admin), coordinados como un solo estado certificado.">
      <header className={styles.hero}>
        <div className={styles.heroInner}>
          <ThemedImage className={styles.mark} alt="Quantum"
            sources={{light: markLight, dark: markDark}} />
          <h1 className={styles.title}>Q<span className={styles.em}>u</span>antum</h1>
          <p className={styles.tagline}>
            Framework web, ORM y panel de administración para Go: desarrollados por
            separado, coordinados como suite.
          </p>
          <p className={styles.sub}>
            La documentación de cada producto vive en su repositorio; este sitio la
            <em> ensambla</em> bajo una sola marca.
          </p>
          <div className={styles.chips}>
            <span className={`${styles.chip} ${styles.chipSuite}`}>suite <b>{suite.quantum}</b></span>
            <span className={styles.chip}>nucleus <b>{suite.nucleus}</b></span>
            <span className={styles.chip}>quark <b>{suite.quark}</b></span>
            <span className={styles.chip}>orbit <b>{suite.orbit}</b></span>
          </div>
          <div className={styles.actions}>
            <Link className="button button--primary button--lg" to="/nucleus/">Nucleus&nbsp;→</Link>
            <Link className="button button--secondary button--lg" to="/quark/intro/">Quark&nbsp;→</Link>
          </div>
        </div>
      </header>

      <main className={styles.pillars}>
        {pillars.map((p) => {
          const inner = (
            <>
              <div className={styles.pillarHead}>
                {p.glyph}
                <span className={styles.pillarName}>{p.name}</span>
                <span className={styles.pillarVer}>{p.ver}</span>
              </div>
              <div className={styles.pillarRole}>{p.role}</div>
              <p className={styles.pillarDesc}>{p.desc}</p>
            </>
          );
          return p.to ? (
            <Link key={p.name} className={styles.pillar} to={p.to}>{inner}</Link>
          ) : (
            <div key={p.name} className={`${styles.pillar} ${styles.pillarSoon}`}>{inner}</div>
          );
        })}
      </main>
    </Layout>
  );
}
