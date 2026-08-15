# Verificación dirigida de cierre — Arco de endurecimiento #1, parte (b)

**Qué cubre.** La evidencia del punto **(b)** que solicita
[`CIERRE_ENDURECIMIENTO_1.md`](CIERRE_ENDURECIMIENTO_1.md): que **B.1**
(assert 5 — el tag debe CAPTURAR el set de HEAD) y **B.2** (modo `--cierre`) **no
rompen un flujo de certificación legítimo**, es decir, que no generan falsos
positivos en la lane semanal normal.

La parte **(a)** (SEC-1/SEC-2 no dejan vivo ningún camino de auth débil) está en
[`VERIFICACION_DIRIGIDA_END1_a.md`](VERIFICACION_DIRIGIDA_END1_a.md).

---

## La pregunta, desdoblada

«Sin falsos positivos» es la mitad fácil: se consigue trivialmente desactivando
el guard. Por eso (b) se verifica en **dos direcciones a la vez**:

1. **NO muerde donde no debe** — los estados legítimos entre arcos y a mitad de
   tren pasan la lane semanal con EXIT=0.
2. **SIGUE mordiendo donde sí debe** — esos mismos estados, al **certificar**
   (`--cierre`), son NO-PASA. Si solo se comprobara (1), la conclusión sería
   compatible con un guard inútil.

La prueba central es (b2): **el mismo árbol, dos modos, veredictos opuestos.**

---

## Evidencia empírica: tres lanes semanales verdes, sin intervención humana

Desde la certificación (2026-07-22) hasta hoy (2026-08-15), la lane programada
corrió **tres veces sobre el repo real** con B.1/B.2 ya activos, sin nadie
delante. Ningún falso positivo; el notificador de fallo nunca se disparó (cero
issues auto-abiertos en `quantum`):

| Fecha | Certificación mecánica (suite-integral) | CI de integración |
|---|---|---|
| 2026-07-27 | ✅ [30254910544](https://github.com/jcsvwinston/quantum/actions/runs/30254910544) | ✅ [30258067605](https://github.com/jcsvwinston/quantum/actions/runs/30258067605) |
| 2026-08-03 | ✅ [30801875828](https://github.com/jcsvwinston/quantum/actions/runs/30801875828) | ✅ [30804675779](https://github.com/jcsvwinston/quantum/actions/runs/30804675779) |
| 2026-08-10 | ✅ [31365457511](https://github.com/jcsvwinston/quantum/actions/runs/31365457511) | ✅ [31369117928](https://github.com/jcsvwinston/quantum/actions/runs/31369117928) |

Es la evidencia más fuerte de que B.1/B.2 no rompen el flujo normal: tres
semanas de operación real sin un solo falso positivo. Lo que sigue lo demuestra
además **por construcción**, caso a caso.

---

## (b1) · Estado real de hoy — HEAD por delante del tag, set sin drift

`main` va **6 commits por delante** de `v1.10.0` (los PRs de documentación del
cierre); los gitlinks de los tres submódulos son idénticos a los del tag. Es el
estado en que corrieron las tres lanes de arriba.

```
$ bash scripts/check_suite_tag.sh          # modo lane semanal
OK: v1.10.0 — su versions.yaml declara quantum "1.10.0"
OK: v1.10.0 — gitlink de quark (36a1ab72) == workspace_pin (36a1ab72)
OK: v1.10.0 — gitlink de nucleus (26c5b60a) == workspace_pin (26c5b60a)
OK: v1.10.0 — gitlink de orbit (bf5e0d7e) == workspace_pin (bf5e0d7e)
OK: v1.10.0 — ancestro de HEAD
nota: v1.10.0 tiene tag pero HEAD va por delante — la captura del set (assert 5)
      solo se EXIGE al certificar (--cierre/QUANTUM_CERTIFYING=1) o con tag==HEAD;
      la lane semanal lo tolera (HEAD>tag entre arcos es legítimo).
check_suite_tag: OK                                                    # EXIT=0
```

El guard **declara en voz alta** por qué no aplica el assert 5 en vez de callarse
— la distinción de modos es legible en el log, no implícita.

---

## (b2) · El caso crítico — HEAD por delante del tag **con el set drifteado**

Éste es el estado que la cabecera del guard llama «legítimo entre arcos»: alguien
sube un submódulo en `main` sin cortar tag de suite. Si el assert 5 se exigiera
siempre, aquí habría **falso positivo** y la lane semanal se pondría roja sobre
un estado correcto.

Se usa la **fixture oficial del repo** —la misma que ejecuta `guard-of-guards`
en CI— que construye un árbol git real con un tag *rancio pero autoconsistente*
(gitlink viejo + su propio manifiesto viejo, coherentes entre sí) y un HEAD
re-pinado:

```bash
$ bash tests/guard-fixtures/umbrella-suite-tag/fixture.sh /tmp/b-drift
workdir=/tmp/b-drift/tree
$ cd /tmp/b-drift/tree
  gitlink quark en el tag v1.10.0 : aaaaaaaa      # set viejo
  gitlink quark en HEAD           : 36a1ab72      # set re-pinado  → DRIFT
```

### Modo lane semanal → PASA (sin falso positivo)

```
$ bash scripts/check_suite_tag.sh
OK: v1.10.0 — gitlink de quark (aaaaaaaa) == workspace_pin (aaaaaaaa)
...
nota: … la lane semanal lo tolera (HEAD>tag entre arcos es legítimo).
check_suite_tag: OK                                                    # EXIT=0
```

### Modo certificación → FALLA (el guard sigue mordiendo)

```
$ bash scripts/check_suite_tag.sh --cierre
-- assert de captura (certificación): el tag v1.10.0 debe apuntar al MISMO set que HEAD certifica
FAIL: v1.10.0 — el gitlink de quark del tag (aaaaaaaa) NO captura el de HEAD
      (36a1ab72) — el tag no apunta al set que HEAD certifica (QM7-3: tag rancio,
      aunque sea autoconsistente)
OK: v1.10.0 — captura el set de nucleus de HEAD (26c5b60a == pin 26c5b60a)
OK: v1.10.0 — captura el set de orbit de HEAD (bf5e0d7e == pin bf5e0d7e)
check_suite_tag: FALLO                                                 # EXIT=1
```

**Lectura:** el mismo árbol, byte a byte, da **EXIT=0 en la lane y EXIT=1 al
certificar**. La discriminación es por MODO, no por laxitud: la lane no se rompe
y el tag rancio no puede colarse en una certificación.

---

## (b3) · Mid-tren — versión nueva en `versions.yaml`, tag aún sin cortar

El otro estado legítimo: el PR de re-pin ya está fusionado (el manifiesto declara
la versión nueva) pero el tag se corta *después* del último PR (procedimiento
QM7-3). La lane semanal corre en ese hueco.

Fixture: commit1 = set certificado con tag `v1.10.0`; commit2 = `versions.yaml`
bumpeado a `1.11.0` **sin tag**.

```
$ bash scripts/check_suite_tag.sh          # modo lane semanal
AVISO: v1.11.0 (la versión de versions.yaml) aún SIN tag — tren en marcha; se
       verifica el último tag existente (v1.10.0) contra su propio árbol. El
       cierre de ronda exige este guard con el tag ya cortado (o --cierre, que
       lo hace FAIL).
OK: v1.10.0 — su versions.yaml declara quantum "1.10.0"   … (asserts 2-4 verdes)
check_suite_tag: OK                                                    # EXIT=0

$ bash scripts/check_suite_tag.sh --cierre  # modo certificación
FAIL(certificación): v1.11.0 (la versión de versions.yaml) aún SIN tag de suite —
       certificar exige que el tag EXISTA y capture HEAD. Corta el tag en HEAD
       antes de certificar. Último tag existente para contexto: v1.10.0.
check_suite_tag: FALLO                                                 # EXIT=1
```

**Lectura:** el flujo de certificación legítimo (re-pin → merge → tag → certificar)
no queda in-certificable en ningún momento: mientras el tren rueda la lane pasa,
y solo el acto de certificar exige el tag.

---

## (b4) · Contraprueba — el guard no se ablandó

Que la lane pase no es porque el guard se haya desactivado:

- La fixture de arriba es la **registrada en `guard-of-guards`** con
  `env=QUANTUM_CERTIFYING=1`; en la lane de fixtures del CI el veredicto
  esperado es **muerde (EXIT=1)** — y así salió en la certificación de 1.10.0
  (15/15 muerden).
- Los dos `--cierre` de (b2) y (b3) dan **EXIT=1** aquí mismo.
- La certificación real de Quantum 1.10.0 se hizo con `tag==HEAD` y el assert 5
  **verde y exigido** (ver `CIERRE_ENDURECIMIENTO_1.md` §Certificación).

---

## (b5) · La lane semanal íntegra sobre el repo real

Reproducción local de lo que corre el schedule (los 15 guards al pin, modo
normal):

```
$ ./scripts/suite-integral.sh
== suite-integral: certificación mecánica del set 1.10.0 — modo: lane semanal (HEAD>tag tolerado) ==
guards registrados: 15 · ejecutados: 15 · con fallo: 0
suite-integral: OK — los 15 guards pasan sobre el árbol pinado.        # EXIT=0
```

---

## Matriz resumen

| Escenario | Legítimo en… | Lane semanal | `--cierre` |
|---|---|---|---|
| **(b1)** HEAD>tag, set idéntico (hoy) | entre arcos | ✅ EXIT=0 | — |
| **(b2)** HEAD>tag, **set drifteado** | entre arcos | ✅ EXIT=0 | ❌ EXIT=1 |
| **(b3)** versión nueva **sin tag** (mid-tren) | durante el tren | ✅ EXIT=0 (AVISO) | ❌ EXIT=1 |
| **tag==HEAD, set capturado** | certificación | ✅ | ✅ EXIT=0 (assert 5 exigido) |
| **Lane completa (15 guards)** | operación normal | ✅ 15/15 | ✅ 15/15 en la certificación |

---

## Conclusión de (b)

**B.1 y B.2 no rompen ningún flujo de certificación legítimo.** Los tres estados
que el procedimiento produce de forma natural —HEAD por delante del tag con y sin
drift del set, y el hueco mid-tren sin tag— pasan la lane semanal con EXIT=0, y
el guard lo explicita en el log en lugar de callarlo. Al mismo tiempo, esos
mismos estados son NO-PASA al certificar, de modo que «15/15 EXIT=0 en
`--cierre`» sigue significando exactamente «tag cortado que captura el set de
HEAD». Tres semanas de lane programada verde sin intervención lo confirman en
producción.

**Lo que queda al criterio humano** (y esta nota no sustituye): no si el guard se
comporta como está especificado —eso queda demostrado arriba— sino si la
**política** es la correcta, a saber, que «HEAD por delante del tag con el set
drifteado» deba considerarse un estado legítimo tolerado entre arcos en lugar de
un aviso más ruidoso. Es una decisión de gobernanza, no un test.
