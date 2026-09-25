# Sesión 2026-09-25 — A9 S11 hecha y A9 cerrado en Quantum 1.38.0

> Archivado desde el §3 de `.claude/commands/next-session.md` el 2026-09-26,
> al entrar la sesión de A10 `S1`. Historia para buscar con grep, no para cargar.

### Sesión 2026-09-25 — **A9 `S11` HECHA y A9 CERRADO en Quantum 1.38.0 (orbit#527, cortes v1.17.0 y v1.18.0, quantum#245)**: el clúster de tres agentes, OR-60, la tabla rancia del banco, `umbrella-fleet-posture`, la parte 2 de `S10` (50/50), la release sin activos y el tren

- **Fusionados** orbit#526 (`S10`) y quantum#242 por orden de Carlos.
- **El clúster**: `TestFleetParityThreeAgents` en
  `orbit/internal/fleettest/fleetbench/cluster_test.go` (orbit#527). Dos
  servidores en malla, tres agentes con BD propia; las cinco preguntas del
  operador a los dos servidores. Verificado por mutación (dos mutaciones,
  las dos tiran el test), `-count=3` estable, `server` y `fleettest` en
  verde. **Trampa del propio test**: al parar, el agente envía Goodbye y el
  servidor BORRA la entrada del registro (no la marca desconectada), así que
  «ausente» también es «no conectado»; la primera versión trataba la
  ausencia como fallo y culpaba al producto.
- **OR-60** (P3, hecho): `ListModelsResponse.node_id` y
  `PaginatedRecords.node_id` vacíos — el servidor tiraba el nodo que
  `dispatch` devuelve. Lo vio el clúster; ninguna sonda pone dos nodos
  detrás de un servidor.
- **La tabla por familias de `fleet-bench.md`** decía 26/3/21 desde `S5`
  bajo un titular al día: se retipaba a mano. `TestFleetBenchTable` la
  genera ahora y el guard nuevo la compara con el catálogo. Contra el pin
  v1.16.0 el guard ya la habría cazado (38/2/10 medidos, 26/3/21 escritos).
- **`umbrella-fleet-posture`** con fixture de cuatro roturas, verificado en
  una copia del paraguas con `orbit` apuntando al hermano (OK sobre #527;
  las cuatro causas sobre la fixture). En rama, no en PR: al pin es rojo.
- **Deuda de doc de v1.17.0** en la rama del bot (notas, snapshot, cinco
  guards de docs, `check-anchored` OK). Se queda ahí hasta la orden de
  cortar; nada más puede entrar en main antes (release-please regenera la
  rama).
- **Corte 1 hecho por orden de Carlos** (`merge-bot-pr.sh orbit 523`):
  v1.17.0, proto/v0.8.0, agent/v0.14.0, server/v0.19.0, ui/v1.0.0. **La
  release salió sin activos**: `server/go.sum` sin la suma de `ui/v1.0.0`
  (nació en el mismo corte) y el build read-only del workflow se plantó.
  El nacimiento de `datasource` no lo sufrió porque el servidor no lo
  requería. Endurecido en #527 con `GOFLAGS=-mod=mod` en la verificación y
  en GoReleaser; el árbol de v1.17.0 no se puede arreglar y el set pina la
  convergencia. Trampa nueva del tren: va a `scripts/train/README.md` con la
  sección de 1.38.0.
- **Parte 2 de `S10`** en el mismo #527: tenant relleno en servidor y
  agente, `UI-09` present, **50 de 50**; pines a los tags nuevos y fuera el
  `replace` de `ui`. **Trampa**: el contrato nombra el campo tenant por
  COLUMNA (`tenant_id`) y el cable lleva NOMBRES de campo (`TenantID`); la
  sonda cazó la columna y el agente traduce ahora como el handler ya hacía.
- **Por orden de Carlos, el cierre**: #527 y quantum#244 fusionados; deuda
  de doc de v1.18.0 en la rama del bot; corte de convergencia **v1.18.0**
  (agent/v0.15.0, server/v0.20.0) con sus quince activos firmados
  comprobados; guard-of-guards en local al pin nuevo ANTES del tren (regla
  de 1.37.0), que cazó la fixture de `admin-posture` mordiendo por la causa
  equivocada (dos drivers de navegador en la lane; anclada al del panel);
  `train.sh --desde paraguas --hasta cierre` con cinco `--incluye` (guard,
  fixture, registro, y el guard y la fixture de admin-posture) y
  `./orbit/ui` en el go.work: bump-set paró una vez por la fila `orbit/ui`
  del README (se escribe a mano UNA vez), prosa redactada, quantum#245
  fusionado por merge-group, tag v1.38.0, `--cierre` en verde; 18m46s de
  punta a punta. quantum-app#29 (bump) rojo: deuda suya, no frena. Queda lo
  humano del tren: el cierre de ronda de `docs/AUDITORIA_CONTINUA.md` §6,
  como en los sets anteriores.
- **Siguiente**: `bash scripts/estado.sh --breve` dice el arco; A9 no deja
  nada pendiente salvo OR-57 y OR-59 en A12.
