# Auditor de orbit-fleet (el plano fleet)

> Va detrás de [`comun.md`](comun.md).

Auditas **el plano fleet de Orbit** en `<paraguas>/orbit` al pin: `proto`,
`agent`, `server`, `internal/fleettest` y la entrada `fleet` de la SPA
`orbit/ui` en lo que toca al plano (qué consulta, qué muestra de un agente).
El panel in-process es de `orbit` y la SPA como interfaz de `orbit-ui`.

En el 2026-09-03 esta sub-auditoría encontró el P0 más grave de la suite: el
servidor arrancaba sus listeners en claro aunque se le dieran certificados, y
el guard contaba TLS como autenticación (OR-1). Empieza por ahí.

## Tu dimensión

La fila `orbit · Fleet` de la escala. Lo que veas de seguridad, testing o
interfaz del plano fleet va como hallazgo: la consolidación lo aplica a la
dimensión de su dueño.

El listón: Kubernetes Dashboard y Grafana. Los competidores de la tabla
comparativa: Kubernetes Dashboard, Grafana, Portainer, Telescope de Laravel
para la mitad de aplicación.

## Lo que corres

```bash
cd <paraguas>/orbit/internal/fleettest
go test ./fleetbench/ -run TestFleetBench -v           # 50 controles
go test ./fleetbench/ -run TestFleetBenchSummary -v
go test -race -count=1 ./...                           # incluye el clúster: tres agentes detrás de dos servidores
cd <paraguas>/orbit && for m in proto agent server; do (cd $m && GOWORK=off go build ./... && go vet ./...); done
```

- **El plano de verdad, fuera de los tests**: construye `server` y `agent`,
  arráncalos en tu scratch con certificados propios (una CA tuya), y
  comprueba desde fuera: que un listener con certificado habla TLS y uno sin
  él no arranca en una interfaz pública sin autenticación; que mTLS rechaza
  un cliente sin certificado de la CA; que el agente habla `https`. Con
  `openssl s_client` o `curl -v`, y la salida en el informe.
- **Varios servidores con estado compartido**: lo que el banco llama HA, con
  dos servidores reales y un agente que cambia de uno a otro.

## Lo que verificas en particular

- **A9** (fleet unificado): lee su plan y comprueba cada sesión «hecha»
  contra el pin. OR-57 (identidad del agente por certificado) va al major:
  comprueba qué queda.
- **El fleet sobre el contrato `datasource`** (D2/ADR-002): una aplicación
  remota se ve en el fleet con lo mismo que el panel de A6 vería en local.
- **Retención y alertas**: que la retención borra de verdad lo viejo, y que
  una alerta se dispara y se resuelve sin intervención.
- **La documentación del plano**: cada afirmación de TLS, mTLS, flags y
  puertos en la doc de orbit, contrastada con lo que arrancaste.

## Tu informe

`orbit-fleet.md`, con el formato de `comun.md`. Tu prefijo definitivo será
OR; tus ids provisionales, `orbit-fleet.<n>`.
