# Plan por sesiones — cómo trabajar un arco sin memoria previa

Cada sesión empieza en frío: no recuerda la anterior. Este directorio existe
para que eso no cueste nada. Aquí está el **contrato de una sesión** —cómo
averiguar dónde estamos, qué puede decidir sola y qué deja escrito al
terminar— y, por arco, el troceado en sesiones.

Lo que NO es: un calendario. Las semanas del plan a 5/5 son cota superior y
han fallado siempre por exceso (A1 se estimó en 3 semanas y costó 2 días; A2
en 4 y costó 3; A3 en 2 semanas y costó un día de trabajo más un tren largo).

---

## 1. Los cinco comandos que dicen dónde estamos

Se corren desde la raíz del paraguas, en este orden, antes de tocar nada.
Ninguno escribe.

```bash
sed -n '1,12p' versions.yaml          # 1. el set certificado y su fecha
bash scripts/check_audit_backlog.sh   # 2. arcos cerrados y hallazgos abiertos por arco
sed -n '/^## Estado real/,/^- \*\*Auditoría/p' docs/RUMBO.md   # 3. estado en prosa y arco siguiente
ls docs/planes/                       # 4. qué arcos tienen troceado escrito
git submodule status                  # 5. si el checkout está en el set o ha derivado
```

El 2 es el que manda sobre «qué arco toca»: imprime `arcos cerrados: …` y los
hallazgos abiertos por arco. El 3 lo dice en prosa y el guard
`umbrella-rumbo-estado` obliga a que coincida con el manifiesto.

Y una sexta, que sólo hace falta si vas a certificar o sospechas deriva:

```bash
bash scripts/suite-integral.sh --cierre   # los 47 guards sobre el árbol pinado
```

## 2. Lo que una sesión NO decide sola

Están en los QADR y en el brief de arranque; se repiten aquí las que más
caro cuestan si se olvidan:

- **Un `!` o un footer BREAKING CHANGE arrastra un major de los tres
  pilares** (QADR-0002). Nunca se escribe sin decisión explícita.
- **El idioma** (QADR-0009): los productos en inglés —código, comentarios,
  docs, commits y títulos de PR—; el paraguas en español.
- **Ajustes de repositorio** (protección de rama, `allow_auto_merge`,
  visibilidad de paquetes, secretos, aprobación de corridas): del propietario.
  Una sesión los NOMBRA en su informe, no los toca.
- **La licencia, la cadencia y los números de las políticas**: del propietario.
- **Anti-hype**: sin superlativos de marketing en commits, README, ADRs ni
  roadmap. El grep de esos términos sigue vacío y así se queda.

## 3. Qué fichero manda para cada pregunta

| Pregunta | Fichero que manda | Quién lo vigila |
|---|---|---|
| Qué versiones son el set | `versions.yaml` | `manifest-guard` |
| Qué arcos están cerrados | primera línea de `docs/auditoria/madurez-2026-09-03/registro.csv` | `umbrella-audit-backlog` |
| Qué hallazgos quedan y de quién son | ese mismo `registro.csv` | idem |
| Cuántos guards hay y qué comprueban | `scripts/lib/guard-registry.sh` | `guard-of-guards` |
| Qué es verdad hoy, en prosa | `docs/RUMBO.md` §Estado real | `umbrella-rumbo-estado` |
| Cómo se corta un set y qué trampas tiene | `scripts/train/README.md` | — |
| Qué hay a medias de las dos últimas sesiones | `.claude/commands/next-session.md` §3 | `umbrella-handoff-size` |

Si la prosa y el guard se contradicen, **manda el guard**: la prosa se
corrige en el mismo PR que lo descubre.

## 4. El contrato de una sesión

**Antes de empezar** — la sesión comprueba su precondición con el comando que
su entrada del arco declara. Si no pasa, no empieza: lo dice y para. Una
sesión que arranca sobre una precondición falsa produce trabajo que hay que
tirar.

**Mientras** — una unidad de trabajo, un PR. Título de Conventional Commits
que describa el cambio (en squash-only, **el título del PR ES el commit que
llega a main**, y release-please sólo ve eso). Rama propia; nunca commits
directos a `main`.

**Para darla por hecha** — el comando que la entrada declara como criterio,
en verde. No «parece que funciona»: el comando.

**Al terminar** — tres escrituras, ninguna opcional:

1. Marcar la sesión en el fichero del arco (`docs/planes/A<N>-*.md`), con el
   PR que la cierra y lo que se midió.
2. Si el arco cambió algo de lo que `docs/RUMBO.md` §Estado real afirma,
   corregirlo ahí.
3. Si quedó trabajo a medias, el §3 de `.claude/commands/next-session.md`
   —estado vigente y como mucho dos sesiones; lo demás se archiva en
   `docs/handoff/`, que es historia para buscar con grep, no para cargar.

## 5. Cuándo se trocea un arco, y por qué no antes

El troceado de un arco se escribe **al empezarlo**, no meses antes, y
empieza por una sesión de **medición**. No es ceremonia: es lo que ha pasado
las tres veces.

- En D3 la medición encontró que `asynq` ya no estaba en el grafo (el plan
  decía extraerlo), y que los 57 paquetes de AWS entraban por el gestor de
  secretos y no por storage. Ejecutar el plan escrito habría dejado fuera el
  bloque mayor.
- En A3 la medición de `docs/dependency-surface.md` cambió el alcance del
  troceado de quark antes de tocarlo.
- En este corte, medir antes de escribir el suelo del CLI evitó publicar un
  módulo que no se podía instalar.

Por eso cada fichero de arco abre con una sesión `S0` cuyo producto es
**reescribir las demás**. Un troceado escrito antes de medir es una hipótesis
con formato de plan.

## 6. Los nueve arcos que quedan

El detalle de cada uno —qué entrega, qué gate lo cierra, qué hallazgos
descuenta— está en el artefacto «Los nueve arcos que quedan». Aquí sólo lo
que una sesión necesita para orientarse.

| Arco | Qué entrega | Depende de | Troceado |
|---|---|---|---|
| **A4** | Quark como capa de datos de nucleus | decisión de ruptura controlada | [`A4-capa-de-datos.md`](A4-capa-de-datos.md) |
| A5 | Auth de producto (OIDC, API keys, accounts, MFA) | — (puede solaparse con A4: repos distintos) | al empezarlo |
| A6 | Orbit como admin de producto | decisión del contrato datasource | al empezarlo |
| A7 | Jobs, eventos y tiempo real | A6 para el panel de colas | al empezarlo |
| A8 | Quark enterprise (migraciones v2, RLS en tres motores) | A4 | al empezarlo |
| A9 | Fleet unificado y una sola SPA | A6 | al empezarlo |
| A10 | Testing y OpenAPI de primera clase | A5 para el cliente de test con sesión | al empezarlo |
| A11 | Extensibilidad y catálogo | A5, A7 (los módulos que cataloga) | al empezarlo |
| A12 | Rendimiento, re-auditoría y cierre a 5 | todos | al empezarlo |

**A4 y A5 pueden ir en paralelo** (tocan repos distintos), igual que A8 y A9.
Lo demás respeta las dependencias de la tabla.

## 7. Cómo se cierra un arco

Tres cosas, todas mecánicas, y en este orden:

1. **El registro no deja declararlo cerrado** mientras le quede un hallazgo
   abierto: se añade el arco a la primera línea de `registro.csv` y
   `check_audit_backlog.sh` dice si se puede.
2. **El gate del arco se registra como guard propio** con su fixture, y a
   partir de ahí corre en la lane semanal como los demás.
3. **Un set lo publica**: `bash scripts/train/train.sh` desde `preflight`,
   con las trampas de `scripts/train/README.md` delante.

Un guard del paraguas que comprueba algo de los productos **no se puede
registrar hasta que el pin lo contenga**: el escaneo anti-fósil recorre los
productos AL PIN. Se escribe con su fixture, se deja fuera con su porqué en
`GUARD_SCAN_EXCLUDE`, y entra en el commit del set que mueve los gitlinks.
