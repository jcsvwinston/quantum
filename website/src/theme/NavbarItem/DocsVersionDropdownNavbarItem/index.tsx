import React, {type ReactNode} from 'react';
import DocsVersionDropdownNavbarItem from '@theme-original/NavbarItem/DocsVersionDropdownNavbarItem';
import type DocsVersionDropdownNavbarItemType from '@theme/NavbarItem/DocsVersionDropdownNavbarItem';
import type {WrapperProps} from '@docusaurus/types';
import {useLocation} from '@docusaurus/router';

type Props = WrapperProps<typeof DocsVersionDropdownNavbarItemType>;

// Docusaurus pinta los `docsVersionDropdown` del navbar en TODAS las páginas,
// no solo en la sección de su instancia — con dos productos versionados
// (quark y nucleus) eso ponía dos chips de versión distintos, uno al lado del
// otro, en cualquier página del sitio: leyendo nucleus veías «v1.3.1» (quark)
// junto a «v1.3.2». Este wrapper limita cada selector a las rutas de SU
// producto, con la misma detección por segmento del pathname que el swizzle
// del logo contextual («Quantum · Quark»): cubre también las rutas de
// snapshot (/quark/1.2.2/…) y no depende del baseUrl.
const ROUTE_SEGMENT_BY_PLUGIN: Readonly<Record<string, string>> = {
  // La instancia `default` es Nucleus (ver docusaurus.config.ts).
  default: '/nucleus/',
  quark: '/quark/',
  orbit: '/orbit/',
};

export default function DocsVersionDropdownNavbarItemWrapper(
  props: Props,
): ReactNode {
  const {pathname} = useLocation();
  const segment = ROUTE_SEGMENT_BY_PLUGIN[props.docsPluginId ?? 'default'];
  if (segment && !pathname.includes(segment)) {
    return null;
  }
  return <DocsVersionDropdownNavbarItem {...props} />;
}
