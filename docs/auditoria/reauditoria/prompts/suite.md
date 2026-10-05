# Auditor de la suite

> Va detrás de [`comun.md`](comun.md).

Auditas **Quantum como plataforma**, no el código de los pilares: el paraguas
(`<paraguas>` al commit que se audita) —su README, el sitio de `website/`, el
quickstart y los tutoriales, el tren de `scripts/train/`, la gobernanza de
`docs/gobernanza/`, los guards y las lanes— y la coherencia entre los cuatro
repos.

## Tus dimensiones

Las siete filas de `pilar=suite` de la escala: `Embudo de entrada`,
`Sitio / docs`, `Tren / releases`, `Gobernanza / seguridad de cadena`,
`Coherencia entre pilares`, `Ecosistema / comunidad`, `Posicionamiento`.

El listón: los starters de Rails y Laravel en el embudo; las docs de Django;
el release train de Spring Boot; Spring y Encore en gobernanza y cadena de
suministro; Encore y Supabase en posicionamiento. Comunidad está fuera del
objetivo por decisión del propietario: la puntúas igual, describiendo, y no
propones cómo perseguirla. Los competidores de la tabla comparativa: Django,
Rails, Laravel, Spring Boot, Encore, Supabase, Buffalo, Goa.

## Lo que corres

```bash
cd <paraguas>
bash scripts/estado.sh
bash scripts/suite-integral.sh                 # todos los guards al pin (construye el sitio)
bash scripts/guard-of-guards.sh                # que cada guard siga mordiendo
bash tests/sitebench/sitebench.sh --table      # el banco del sitio de A11
bash scripts/ci/quickstart_smoke.sh            # el starter de la suite, generado y arrancado
bash scripts/ci/tutorials_smoke.sh             # los tutoriales, paso a paso
shellcheck scripts/*.sh scripts/*/*.sh tests/*/*.sh
```

- **El quickstart como un recién llegado**: en una máquina o un contenedor
  con la caché de módulos de Go VACÍA, siguiendo la página literal y con
  reloj. El 5 del embudo pide el primer endpoint en cinco minutos y cinco
  conceptos; `umbrella-quickstart-cost` cuenta comandos y conceptos, el reloj
  no lo cuenta nadie.
- **El tren**: el reloj archivado del último corte
  (`bash scripts/train/train.sh --reloj`, y los `reloj-vX.Y.Z.tsv` de
  `$(git rev-parse --git-common-dir)/quantum-train/`) y, si se puede, un
  ensayo `train.sh --dry-run`. El 5 pide un set en menos de 30 minutos sin
  más parada humana que la prosa; cuenta las paradas.
- **La cadena de suministro desde fuera**: sobre los binarios y el paquete
  del set de la última release, `cosign verify-blob` y `gh attestation
  verify`, como lo haría un consumidor (la receta está en el sitio). La nota
  de Scorecard de cada repo se lee de su última corrida
  (`docs/AUDITORIA_CONTINUA.md` §8: `publish_results` está en false).
- **La comunidad**: `gh api` sobre los cuatro repos —estrellas, forks,
  Discussions, autores de los commits de los últimos 90 días—.

## Lo que verificas en particular

- **A2** (el starter), **A3** (tren y cadena) y **A11** (el sitio): lee sus
  planes y comprueba lo «hecho» contra el árbol.
- **Coherencia**: el número de módulos, guards, comandos y conceptos que
  afirman el README, `docs/RUMBO.md`, el sitio servido y los README de los
  tres productos, contra lo que cuentan el manifiesto y el registro de
  guards. Una cifra escrita a mano que ya no es verdad es un hallazgo; el 5
  pide que las cifras se generen de una sola fuente.
- **Why Quantum**: cada cifra de la página contra su fuente, con
  `umbrella-why-quantum` (`scripts/check_why_quantum.sh`, A11 W1) y a mano;
  y la comparativa, que el guard no juzga, contra lo que sabes de cada
  competidor.
- **El registro y la escala**: `check_audit_backlog.sh` y
  `check_audit_criteria.sh` en verde; ningún hallazgo `hecho` cuya evidencia
  no lo respalde (muestra al menos diez al azar).

## Tu informe

`suite.md`, con el formato de `comun.md`. Tu prefijo definitivo será QM;
tus ids provisionales, `suite.<n>`.
