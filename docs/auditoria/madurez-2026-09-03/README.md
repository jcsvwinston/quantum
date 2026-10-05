# Auditoría de madurez 2026-09-03 — registro de hallazgos

Los seis informes de la auditoría de madurez frente al mercado (Quantum
1.26.0 → sets 1.26.1, 1.26.2 y 1.27.0), copiados aquí desde el proyecto de
trabajo para que el paraguas los tenga a mano, y **`registro.csv`**, la fuente
machine-readable que el guard `umbrella-audit-backlog`
(`scripts/check_audit_backlog.sh`) valida en cada corrida:

- cada hallazgo con id y severidad de los informes tiene fila, y ningún id
  se repite —ni en el registro ni en las tablas de los informes— (hubo dos
  NU-50 hasta el 2026-10-04);
- cada fila tiene arco (`A<n>`, sin techo: lo que A12 deje abierto va a un
  `A13`) o está `hecho` con su evidencia (PR);
- la primera línea, `# arcos_cerrados: A1 A3 …`, declara los arcos del plan
  que ya se dieron por cerrados: ningún hallazgo asignado a uno de ellos
  puede seguir `abierto`. Cerrar un arco es añadirlo ahí, y el guard es quien
  dice si se puede.

El gate de A1 (plan «Quantum a 5 de 5») es exactamente eso: A1 en
`arcos_cerrados` con cero P1/P2 abiertos de los cuatro informes. Un P3 que se
quede fuera de A1 se reasigna a otro arco por escrito, no se pierde.

Convención: el plan habla de 147 hallazgos porque contó los cuatro informes
principales; las tablas de los seis ficheros suman 190 filas (los P0 y los
del fleet y la SPA de orbit van aparte). El registro cuenta filas, no
resúmenes.

**Las re-auditorías usan este mismo registro.** Sus informes van a
[`../reauditoria/<fecha>/`](../reauditoria/README.md) y el guard los lee junto
a los seis de aquí: un hallazgo nuevo de una re-auditoría es una fila más de
este fichero, con su `informe` apuntando a ese directorio. La escala con la
que se puntúan las 36 dimensiones está en
[`../criterios-5.csv`](../criterios-5.csv).
