import React, {type ReactNode} from 'react';
import CodeBlock from '@theme/CodeBlock';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';

// Piezas de la página de instalación (docs/install.md, instancia `start`).
// Todas las versiones salen de customFields.suite, que docusaurus.config.ts
// lee de ../versions.yaml EN BUILD — el mismo mecanismo que los chips de la
// portada y las etiquetas del navbar. Aquí no hay ningún número escrito a
// mano: si el manifiesto cambia, la página cambia con el siguiente build.

type Suite = {
  quantum: string;
  nucleus: string;
  quark: string;
  orbit: string;
  requireBlock: string;
};

function useSuite(): Suite {
  const {siteConfig} = useDocusaurusContext();
  return siteConfig.customFields!.suite as Suite;
}

// La versión certificada de un campo del manifiesto, como <code> inline.
export function SuiteVersion({of}: {of: keyof Omit<Suite, 'requireBlock'>}): ReactNode {
  return <code>{useSuite()[of]}</code>;
}

// El bloque `require` con los nueve módulos del set certificado, generado
// desde versions.yaml (modules + nucleus_modules + orbit_modules).
export function CertifiedRequire(): ReactNode {
  return <CodeBlock language="go">{useSuite().requireBlock}</CodeBlock>;
}

// `go get` por pilar, a la versión certificada.
export function GoGetPillar({pillar}: {pillar: 'quark' | 'nucleus' | 'orbit'}): ReactNode {
  const suite = useSuite();
  return (
    <CodeBlock language="bash">
      {`go get github.com/jcsvwinston/${pillar}@${suite[pillar]}`}
    </CodeBlock>
  );
}
