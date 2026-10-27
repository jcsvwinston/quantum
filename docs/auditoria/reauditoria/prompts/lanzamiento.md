# Nota de lanzamiento — lo que quien dirige la re-auditoría añade a cada prompt

> Va DETRÁS de `comun.md` y del prompt de cada auditor (y del de cada
> revisor). Rellena lo que el brief deja a quien lanza el equipo; manda
> sobre el texto anterior sólo en lo operativo. `R1` la escribió a mano el
> 2026-10-23; esta es la plantilla, con lo que esa corrida enseñó.

- **Fecha de la re-auditoría**: `<AAAA-MM-DD>`. **Set**: Quantum `<versión>`
  (certificado `<fecha>`): quark `<tag>` (`<sha>`), nucleus `<tag>` (`<sha>`),
  orbit `<tag>` (`<sha>`). Los tres submódulos del paraguas `<paraguas>`
  están AL PIN (`git submodule status`); los checkouts hermanos de
  `~/GolandProjects/` van por `main` y NO se miran.
- **La lista cerrada del major**: el §3.0 de `docs/planes/quantum-2.0.md` y
  los avisos en `*/docs/deprecations/` al pin. Lo que esa tabla registra
  como `en main` NO está al pin y no es hallazgo; lo que sí está se audita
  como intención (aviso, recambio, guía). Lo que el plan de A12 ya llama
  «fix de 1.x» se cita, no se abre con otro id.
- **Tu scratch y tu entregable**: `SCRATCH=$(mktemp -d)` y todo ahí; el
  informe o la revisión se escribe INCREMENTALMENTE, y **al terminar se
  copia a `<carpeta persistente>/<fichero>.md`** además de devolver la
  ruta. El scratch de la sesión y el `mktemp` de cada agente se borran
  entre días: en `R1` los siete informes desaparecieron antes de la
  revisión y hubo que recuperarlos de las transcripciones. La carpeta
  persistente es la de notas compartidas de la sesión (fuera del repo) o
  el propio directorio de la re-auditoría.
- **Varios auditores corren A LA VEZ sobre el mismo árbol**. Docker está
  arrancado. Contenedores a mano: con tu prefijo y puertos de host
  ALEATORIOS (`-p 127.0.0.1:0:5432`, o testcontainers), nunca
  5432/3306/1433/1521 fijos; bórralos al terminar (`docker rm -f` de los
  tuyos), nunca `docker system prune`. Si no puedes reproducir una lane,
  vale la corrida verde del CI al commit del pin
  (`gh run list -R jcsvwinston/<repo> --commit <sha> --limit 30`), diciendo
  cuál de las dos usaste.
- **Go**: dentro del paraguas el `go.work` está activo; para medir un
  módulo como lo instala un usuario, `GOWORK=off`. macOS no trae `timeout`:
  `perl -e 'alarm shift; exec @ARGV' 1800 <cmd>`; lo que no termine en 30
  minutos es un límite. Un `go` bajo el `go.work` de orbit le añade líneas
  a `orbit/go.work.sum` (OR-138) y `check_modules_standalone.sh` deja
  `cmd/nucleus/nucleus` (NU-140): dilo en tu fichero; quien consolida lo
  restaura antes de `suite-integral`.
- **Una aplicación generada**: `scripts/ci/quickstart_smoke.sh` enseña cómo
  el CI construye el CLI de nucleus de fuente, genera el starter y lo apunta
  al árbol con un `go.work` propio en el temporal. Copia ese patrón en tu
  scratch (nunca en el árbol).
- **Git**: sólo lectura en los cuatro repos. Nunca `checkout`, `stash`,
  `clean`, `submodule update`, `reset` ni commits. No crees ficheros dentro
  del árbol; `npm ci` sólo donde el prompt lo dice y el `.gitignore` lo
  cubre; la SPA se construye en una copia.
- **La línea base**: los informes del 2026-09-03 y el registro en
  `docs/auditoria/madurez-2026-09-03/`; la escala en
  `docs/auditoria/criterios-5.csv`; la re-auditoría anterior en
  `docs/auditoria/reauditoria/<fecha anterior>/`; los planes en
  `docs/planes/`.
- **Trabajas solo y sin preguntar**: nadie contesta. Lo que no puedas
  decidir o ejecutar es un límite en tu §6, con el porqué.
- **Al final** devuelves, además del resumen, la salida estructurada que se
  te pide (ruta del entregable, notas o veredictos, recuentos, P0/P1).

Y para quien lanza: los auditores y los revisores van en dos fases con
barrera (los revisores miran los duplicados entre informes); si el
workflow se corta a mitad (límite de uso, día nuevo), se reanuda con el
mismo guion y `resumeFromRunId` —lo terminado se cachea— DESPUÉS de
comprobar que los entregables de la fase anterior siguen en disco.
