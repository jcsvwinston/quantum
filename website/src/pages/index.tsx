import React from 'react';
import Layout from '@theme/Layout';
import Link from '@docusaurus/Link';

// Portada provisional del sitio unificado (Fase 2). El doble selector de versión
// y la instancia de Orbit llegan en pasos posteriores.
export default function Home(): React.ReactNode {
  return (
    <Layout
      title="Quantum"
      description="Suite Go: Nucleus (framework web), Quark (ORM) y Orbit (admin), coordinados.">
      <main style={{maxWidth: 760, margin: '0 auto', padding: '4rem 1.5rem'}}>
        <h1
          style={{
            fontFamily: 'var(--ifm-font-family-monospace)',
            fontSize: '2.6rem',
            marginBottom: '0.4rem',
          }}>
          Quantum
        </h1>
        <p style={{fontSize: '1.2rem', color: 'var(--ifm-color-emphasis-800)'}}>
          Framework web, ORM y panel de administración para Go: desarrollados por
          separado, coordinados como suite.
        </p>
        <p style={{color: 'var(--ifm-color-emphasis-700)'}}>
          La documentación de cada producto vive en su propio repositorio; este
          sitio la <em>ensambla</em> bajo una sola marca.
        </p>
        <div
          style={{
            display: 'flex',
            gap: '0.75rem',
            marginTop: '1.75rem',
            flexWrap: 'wrap',
          }}>
          <Link className="button button--primary button--lg" to="/nucleus/">
            Nucleus · framework web →
          </Link>
          <Link className="button button--secondary button--lg" to="/quark/">
            Quark · ORM →
          </Link>
        </div>
        <p style={{marginTop: '1.5rem', color: 'var(--ifm-color-emphasis-600)'}}>
          <small>
            Orbit (admin) se incorporará cuando se escriba su documentación
            (Fase 3). Pre-fusión: ver{' '}
            <Link to="https://github.com/jcsvwinston/quantum">el repo de la suite</Link>.
          </small>
        </p>
      </main>
    </Layout>
  );
}
