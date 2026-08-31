# Registro normativo de la auditoría

Copias de los dictámenes que gobiernan el régimen de certificación de la
suite. Hasta ahora vivían solo fuera de los repos (en la carpeta de trabajo
del responsable), así que el runbook citaba documentos que un mantenedor no
podía abrir (hallazgo DI-8 de la auditoría integral 2026-08-30). Son **actas**:
no se editan; si algo cambia, lo cambia un documento posterior.

| Documento | Qué es |
|---|---|
| [`REAUDITORIA8_QUANTUM.md`](REAUDITORIA8_QUANTUM.md) | La 8ª pasada manual — **la última** — sobre Quantum 1.8.0, y el **dictamen** que instaura el régimen de auditoría continua: condiciones, disparadores de mini-pasada y decisor. Es el documento que `AUDITORIA_CONTINUA.md` §6 cita como fuente. |
| [`CIERRE_5A_RONDA.md`](CIERRE_5A_RONDA.md) | Cierre de la 5ª ronda → Quantum 1.7.1. Primer cierre con verificación por ejecución casilla a casilla (cada gate con su EXIT; guards nuevos probados en negativo). |
| [`CIERRE_6A_RONDA.md`](CIERRE_6A_RONDA.md) | Cierre de la 6ª ronda → Quantum 1.7.2. Aplica la lección «la rama que nunca se ejecutó»: cada fix llega con el test o la lane que lo habría cazado. |
| [`CIERRE_7A_RONDA.md`](CIERRE_7A_RONDA.md) | Cierre de la 7ª ronda («cierre definitivo») → Quantum 1.8.0. Estrena la certificación mecánica (registro de guards + suite-integral + guard-of-guards) y el procedimiento del tag de suite tras el último PR (QM7-3). Contiene el ✅-con-asimetría que motivó la regla «se escribe ⚠️» (lección OR8-1). |
| [`CIERRE_8A_RONDA.md`](CIERRE_8A_RONDA.md) | Cierre de la 8ª ronda → Quantum 1.9.0. Ejecuta las condiciones del dictamen (QM8-*): schedule + aviso activo de integration.yml, §6 del runbook, guard del tag de suite. Último cierre de la era de pasadas manuales. |

Contexto alrededor:

- El régimen vivo que estos documentos instauran está operativo en
  [`../../AUDITORIA_CONTINUA.md`](../../AUDITORIA_CONTINUA.md).
- Los cierres de arcos posteriores al régimen viven en el directorio padre
  ([`../`](../), p. ej. `CIERRE_ENDURECIMIENTO_1.md`) y en las notes de
  `versions.yaml`/CHANGELOG del paraguas.
- La serie completa (auditorías 1ª–7ª, planes de ejecución, briefs) sigue en
  el archivo externo del responsable; aquí se copia lo **normativo** — lo que
  el runbook necesita citar —, no el histórico entero.
