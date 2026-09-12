# Rumbo — el roadmap VIVO del paraguas

Documento corto y honesto: qué es verdad hoy y qué frentes están abiertos.
No es un acta — las actas (ROADMAP de convergencia, cierres de ronda) viven en
[`ROADMAP.md`](ROADMAP.md) y [`auditoria/`](auditoria/). Los ids (SD-01,
RT-3, D1…) referencian los hallazgos y decisiones de la auditoría integral
del 2026-08-30 (dictámenes en [`auditoria/registro/`](auditoria/registro/)).

**Regla de mantenimiento:** este fichero se actualiza al cerrar cada arco (y
en el PR de re-pin de cada set, si el arco cambió lo que aquí se afirma). Un
frente cerrado se borra o se mueve a su acta; no se acumula prosa. Si la fecha
de abajo tiene más de un par de sets de antigüedad, desconfía y verifica.

## Estado real (2026-09-12)

- **Set certificado: Quantum 1.32.0** (2026-09-12) — quark v1.14.0 (con el
  CLI en v1.0.1 y los cinco drivers en v0.2.1) · nucleus v1.28.0 (doce
  módulos hermanos) · orbit v1.9.6 (proto v0.4.4, agent v0.6.20, server
  v0.11.6, quarkbridge v1.8.24, quarkdatasource v1.8.25).
  1.32.0 publica el arco **A5** (auth de producto): nucleus tenía el sustrato
  —sesiones, tokens, hash de contraseñas, motor de políticas y dos costuras
  de extensión— y ninguna ruta que iniciara sesión a nadie. Ahora hay
  `pkg/accounts` (registro, verificación, login, reset, enlace mágico,
  bloqueo progresivo), segundo factor TOTP con códigos de recuperación,
  `pkg/auth/apikeys`, un proveedor OIDC que llena la costura federada que
  estaba vacía desde v1.15.0, permisos por objeto, y la postura mapeada a
  ASVS 4.0.3 L2 con 27 requisitos medidos. El banco de conformidad de auth
  pasa de **14 a 40 de 43** controles. Minor de suite por la minor de
  nucleus. **Arco en curso: A6** (Orbit como admin de producto), cuya sesión
  de medición dejó el banco de admin de orbit en **32 de 59 controles** y
  encontró **NU-73**: el envoltorio de respuesta del gestor de sesiones no
  implementa `Hijack`, así que ningún websocket de ninguna aplicación
  completa el upgrade y el feed en vivo del panel no conecta en un
  despliegue real. A6 lleva dos P1 abiertos (OR-4 y NU-73); su troceado está
  en [`planes/A6-orbit-admin-de-producto.md`](planes/A6-orbit-admin-de-producto.md).
  La fuente de verdad es [`versions.yaml`](../versions.yaml), siempre — y
  desde esta cabecera lo vigila `check_rumbo_estado.sh`. El troceado de cada
  arco en sesiones, y el contrato que permite trabajarlo sin recordar la
  anterior, están en [`planes/`](planes/README.md).
- **Certificación mecánica:** 49 guards en el registro (los 48 de 1.31.0 más
  `umbrella-auth-posture`, que A5 registró: vigila que lo que la suite
  AFIRMA sobre su autenticación sea lo que sus propias medidas dicen), lane
  semanal + modo `--cierre` ([`AUDITORIA_CONTINUA.md`](AUDITORIA_CONTINUA.md)).
- **Auditoría de madurez 2026-09-03 sobre 1.26.0: ejecutada, corregida y
  PUBLICADA en 1.26.1.** Cuatro auditores midieron cada pilar contra el
  mercado (147 defectos, 4 P0, todos en la primera hora del evaluador). Los
  cinco PRs de corrección (quark#338, nucleus#455, orbit#380, orbit#379,
  quantum#136) están fusionados. Informe:
  <https://claude.ai/code/artifact/2ffd4e81-ae29-413c-ba01-555cef7ecedd>.
  Plan de trabajo a 5/5 (doce arcos, cada uno con gate mecánico):
  <https://claude.ai/code/artifact/cbd9d082-7404-4989-bd79-7408f9dbaf38>.
  El orden de los frentes de abajo se subordina a ese plan desde este set.
  La 8ª pasada fue la última auditoría manual completa; rige el régimen del §6.
- **Auditoría integral 2026-08-30 sobre 1.24.0: ejecutada y PUBLICADA.** 147
  hallazgos, 52 graves, 3 P0 — los tres en el embudo de entrada, no en el
  runtime. 20 PRs fusionados y el set 1.25.0 los lleva al público (verificado
  en el sitio construido al pin: 0 bloques de código vacíos donde había 56).
- **Las seis decisiones de rumbo D1–D6 están TOMADAS** (2026-08-31), y fijan
  el orden de trabajo de los frentes de abajo. D1 tiene ADR propio:
  [QADR-0008](adr/QADR-0008-cadencia-de-certificacion.md).

## Frentes abiertos, en orden de trabajo

Las decisiones D1–D6 de la auditoría quedaron tomadas el 2026-08-31; lo que
sigue es su traducción a trabajo. El orden importa: cada frente supone hecho
el anterior.

0. **Cadencia del tren (D1) — EN VIGOR y estrenada.** Arcos y sets se
   desacoplan: el set se certifica **semanalmente**, pegado a la corrida del
   lunes, o antes por hito con razón escrita
   ([QADR-0008](adr/QADR-0008-cadencia-de-certificacion.md)). El tren de
   1.25.0 fue el primero conducido con [`scripts/train/`](../scripts/train/) y
   `align_set.sh`; sus lecciones están en el runbook de esa carpeta. **El
   consumidor externo (quantum-app) se re-pina solo en cada corte** (D6): el
   anuncio abre su PR, que sigue necesitando revisión humana.
1. **Adelgazado del grafo (D3) — CERRADO Y PUBLICADO en Quantum 1.26.0.**

   | | Binario | Paquetes | Módulos |
   | --- | --- | --- | --- |
   | nucleus, antes | 75,6 MB | 1008 | 346 |
   | nucleus, publicado | **19 MB** | **349** | **87** |
   | quark, antes | 24 MB | 304 | 171 |
   | quark, publicado | **6 MB** | **159** | **129** |

   Objetivo: < 30 MB y < 150 módulos. Cumplido con margen en los dos. Salen a
   módulos propios los cuatro backends de nube (ADR-030), los cinco drivers de
   BD y los dos exportadores de telemetría (ADR-031), y en quark los cinco
   drivers más el listener de LISTEN/NOTIFY (ADR-0023). Desaparecen los build
   tags `mssql`/`oracle`. La configuración no cambia; `nucleus add <nombre>`
   escribe el import, y desde quark v1.10.0 el error guiado existe en los dos.

   **Deuda viva del arco, para no perderla:**
   - **Prometheus es el único cambio de comportamiento**: quien scrapea el
     `/metrics` por defecto lo pierde hasta añadir el módulo. Avisa al
     arrancar y sigue; si la clave estaba escrita a mano, para.
   - **nucleus y quark tienen ya escritor para los suelos de sus módulos**
     (`scripts/train/align-module-floors.sh`, QM-19, tren de 1.27.0), y corre
     al principio de cada corte como primer commit (decisión 2026-09-05): es
     un `fix(deps)` que corta un patch por módulo, así que va en un corte que
     sale igual, no en uno propio. Orbit sigue con `align_set.sh`.
   - `mattn/go-sqlite3` deja de clasificarse en el árbol de quark; quien lo use
     registra su clasificador con tres líneas (ADR-0023).

2. **API keys y luego accounts (D4).** `pkg/auth/apikeys`: emisión con
   hash+prefijo mostrable, scopes proyectados como sujeto/roles Casbin,
   middleware Bearer/X-API-Key, CLI (`apikey create/revoke/list`) y rate limit
   por clave — encaja con los registries de ADR-023 (PR-GAP-01). Después, el
   módulo opt-in `accounts` estilo ADR-022 (registro con verificación, reset
   por token de un solo uso, cambio de contraseña) sobre `pkg/mail` y las
   sesiones existentes (PR-GAP-02).
3. **Capa de datos bendecida (D5).** **Quark es la capa de datos de las apps
   de la suite**; `pkg/db`/`pkg/model` quedan como sustrato del framework. Los
   generadores se alinean: `nucleus generate module --data quark` emite modelo
   quark + registro en `quarkdatasource`, para que lo generado aparezca en el
   Data Studio de orbit sin pegamento (PR-COH-01). Incluye documentar el mapeo
   entre las dos gramáticas de tags.
4. **El fleet consume el contrato datasource (D2).** Orbit deja de ser
   bicéfalo: el Data Studio del plano fleet pasa a consumir el mismo
   `datasource.DataSource` que el in-process, de modo que RBAC por-modelo,
   filtrado de tenant y `quarkdatasource` valgan en ambos planos (AO-2, AO-3).
   El borrador está en orbit `docs/adrs/ADR-002`; esta decisión lo acepta en
   esa dirección — la alternativa (declarar el fleet «telemetría + lectura»)
   queda descartada.
5. ~~**quantum-app revive con bump automatizado (D6).**~~ **HECHO** y
   estrenado en el corte de 1.25.0. Queda abierta una pregunta que el bump
   destapó y que no decide un script: si el consumidor de referencia debe
   llevar además una suite in-process sobre `nucleustest`/`quarktest`, hoy
   clasificada como no cubierta. *Mecanizado*: la fase `cierre` del tren llama a
   [`scripts/train/dispatch-app-bump.sh`](../scripts/train/dispatch-app-bump.sh),
   que anuncia el set certificado a quantum-app; allí un workflow reescribe el
   pin, corre sus gates y abre un PR (nunca empuja a main).

## Deuda viva de la auditoría (no bloquea, no se olvida)

- **PR-ORB-02** — el audit log del panel in-process sigue siendo un ring en
  memoria: se evapora en cada deploy. La doc lo dice sin ambigüedad desde
  orbit#349; la persistencia en BD está sin hacer.
- **AO-4** — quedan tests del panel en postura sin-auth; orbit#353 movió los
  críticos (mutación/authz/tenant) a la postura con-auth.
- **95 hallazgos P2/P3** de la auditoría sin cerrar, priorizados en el informe.
  Los baratos van cayendo dentro de los arcos que tocan el mismo código.

## Qué NO está en duda

El diseño del paraguas se mantiene: go.work + submódulos + versions.yaml
(veredicto RT-12 de la auditoría — la simplificación está en el tren, no en el
workspace). «Coordina, no contiene» sigue vigente (QADR-0001).
