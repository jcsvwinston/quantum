import React, {type ReactNode} from 'react';
import Logo from '@theme-original/Navbar/Logo';
import type LogoType from '@theme/Navbar/Logo';
import type {WrapperProps} from '@docusaurus/types';
import {useLocation} from '@docusaurus/router';
import styles from './styles.module.css';

type Props = WrapperProps<typeof LogoType>;

// El sitio unificado es UNA marca (Quantum) que ensambla las docs de cada producto
// como instancias internas, así que el navbar es global y su logo no cambia solo.
// Para orientar al lector sin perder la marca paraguas, al entrar en las docs de un
// producto anexamos su nombre al brand: «Quantum · Quark», «Quantum · Nucleus».
// El pathname incluye el baseUrl (/quantum/), por eso detectamos por segmento.
const PRODUCTS: ReadonlyArray<readonly [string, string]> = [
  ['/quark/', 'Quark'],
  ['/nucleus/', 'Nucleus'],
  ['/orbit/', 'Orbit'],
];

export default function NavbarLogoWrapper(props: Props): ReactNode {
  const {pathname} = useLocation();
  const active = PRODUCTS.find(([seg]) => pathname.includes(seg));
  return (
    <>
      <Logo {...props} />
      {active && (
        <span className={styles.product} aria-label={`Section: ${active[1]}`}>
          <span className={styles.sep} aria-hidden="true">·</span>
          {active[1]}
        </span>
      )}
    </>
  );
}
