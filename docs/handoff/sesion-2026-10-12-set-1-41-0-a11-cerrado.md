# Handoff archivado — sesión 2026-10-12 (set 1.41.0 certificado, A11 cerrado)

> Movido tal cual desde el §3 de `.claude/commands/next-session.md` el
> 2026-10-16, al entrar la sesión de `M0-G` (el §3 lleva como mucho dos
> sesiones; `scripts/check_handoff_size.sh`). Historia para buscar con
> grep, no para cargar.

### Sesión 2026-10-12 — **set 1.41.0 certificado: A11 cerrado, y un tren con una vuln de Go el mismo día**

- **Publicado**: Quantum 1.41.0 (quantum#281 y quantum#282). quark v1.17.0,
  nucleus v1.32.0 (+ `cmd/nucleus` v1.32.0, auth-saml y errors-sentry
  v0.1.0), orbit v1.19.2 y v1.19.3 (segundo corte para re-pinar `ui`,
  `proto` y `datasource`). A11 `S-fin` (b): `umbrella-catalog-posture` (60º
  guard, catálogo 36 de 38), suelo de la extensión de quark a 22, NU-111
  hecho y **A11 en `arcos_cerrados`**.
- **Lo que paró el tren y cómo se resolvió** (detalle en
  `scripts/train/README.md`, sección 1.41.0, y en la memoria de Claude):
  GO-2026-6617 salió el mismo día → Go 1.26.9 en los tres productos con la
  directiva `toolchain` (quark#466, nucleus#623, orbit#556 con x/net
  v0.60.0); los módulos nuevos de nucleus salían en v1.9.2 → `release-as`
  (nucleus#622, quitado en nucleus#627); el driver no para para las notas
  de nucleus ni de orbit → suelos/pines a mano, notas en la rama del
  release y relanzar; bump-set borraba la fila de la CLI (arreglado en el
  PR de set); N1 (nucleus#607) rebasado con un paquete más en el techo de
  hello-size (NU-118).
- **Lo siguiente**: A12 `M0` (preparar el 2.0; A11 ya está cerrado), con
  el contrato en [`docs/planes/quantum-2.0.md`](../../docs/planes/quantum-2.0.md)
  y la «DX al 5» como precondición; en paralelo, las sesiones cortas de los
  P3 abiertos. El set siguiente, por cadencia, el lunes 2026-10-19.
