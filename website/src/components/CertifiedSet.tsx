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

// El bloque `require` con TODOS los módulos del set certificado, generado
// desde los cuatro bloques de versions.yaml (modules + quark_modules +
// nucleus_modules + orbit_modules) con la ruta de cada módulo descubierta
// del árbol del submódulo (ver docusaurus.config.ts).
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

// `go install` del CLI de Nucleus AL TAG certificado. `@latest` puede ir por
// delante del set (QM-17): el CLI que escribe el scaffold debe ser el de la
// versión que el set certifica, no la última que el proxy conozca.
export function GoInstallCLI(): ReactNode {
  const suite = useSuite();
  return (
    <CodeBlock language="bash">
      {`go install github.com/jcsvwinston/nucleus/cmd/nucleus@${suite.nucleus}`}
    </CodeBlock>
  );
}
