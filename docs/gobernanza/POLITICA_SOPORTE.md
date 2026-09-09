# Política de soporte, LTS y calendario de releases de la suite

> **Estado: APROBADO EN PARTE el 2026-09-09, sin publicar todavía.** El
> propietario aprobó **S1, S2 y S4–S8**. **S3 (la LTS) queda sin aprobar y sin
> declarar**, por la razón que el propio [§7.1](#7-maquinaria-que-falta-para-que-cada-promesa-sea-cumplible)
> da: no existe carril de mantenimiento, y hasta que exista y se ensaye no hay
> forma de cumplir una línea de seis meses. Prometerla sería prometer lo que la
> maquinaria no puede sostener.
>
> Sigue **sin publicar** mientras el §7 tenga puntos abiertos: no está en el
> sitio (`website/`) ni enlazado desde ningún `SECURITY.md`, así que todavía no
> compromete a nadie. El [§8](#8-plan-de-adopción-el-día-que-se-apruebe) dice
> exactamente qué ficheros cambian el día que se publique.
>
> Redactado el 2026-09-08 sobre el set vigente **Quantum 1.29.0**.
> Relacionados: [QADR-0002](../adr/QADR-0002-versionado-dos-niveles.md)
> (majors en lockstep), [QADR-0004](../adr/QADR-0004-versions-yaml-manifiesto.md)
> (el manifiesto certifica conjuntos),
> [QADR-0008](../adr/QADR-0008-cadencia-de-certificacion.md) (cadencia
> semanal), [SECURITY.md](../../SECURITY.md) del paraguas y los de los tres
> productos, y `docs/governance/COMPATIBILITY_SLO.md` de nucleus.

## 1. Qué promete la suite hoy

Cuatro documentos públicos, cuatro promesas distintas, y ninguna en unidades
de tiempo:

| Dónde | Qué dice hoy |
|---|---|
| `quantum/SECURITY.md` | «los parches siguen la ventana de cada producto (últimos dos minors etiquetados en Nucleus y Quark; último minor de cada módulo en Orbit)» |
| `nucleus/SECURITY.md` | `main` y «the latest two tagged minor lines» |
| `quark/SECURITY.md` | `main` y «Latest two tagged minors» (tabla) |
| `orbit/SECURITY.md` | «the latest tagged minor **of each module**» — uno, no dos, y sobre seis módulos con versiones desacopladas |

Tres defectos concretos, no de redacción:

1. **Las ventanas se contradicen.** Dos minors en dos productos, uno en el
   tercero. Un set es un trío: su ventana real es la intersección de las
   tres, y esa intersección no está escrita en ninguna parte.
2. **«Minors» no es una unidad de tiempo.** Con la cadencia medida en el §2,
   dos líneas minor han llegado a durar **un día** (1.27.0 y 1.28.0 se
   certificaron ambas el 2026-09-05). Nadie puede planificar contra eso.
3. **Nadie promete cuándo sale un set.** QADR-0008 fija la cadencia pegada al
   cron del lunes, pero no hay ninguna fecha publicada — ni en el sitio, ni
   en el manifiesto, ni en un fichero que una máquina pueda leer.

## 2. El terreno medido

Medido el 2026-09-08: las cifras de sets salen de los tags de este
repositorio; las de ramas, de `git ls-remote` contra los cuatro remotos.
Ninguna es una estimación, y la columna «Cómo se obtiene» dice con qué
comando se rehace cada una.

| Medida | Valor | Cómo se obtiene |
|---|---|---|
| Sets certificados | **38**, del 2026-07-11 (`v1.0.0`) al 2026-09-08 (`v1.29.0`): 59 días | `git tag --sort=creatordate` |
| Sets en los últimos 60 días | **38** (todos) | idem |
| Ráfaga más densa | **11 sets en 6 días**, del 2026-08-25 al 2026-08-30: 1.15.0, 1.16.0, 1.17.0 y 1.17.1 (los **cuatro el mismo 08-25**), 1.18.0, 1.19.0, 1.20.0, 1.21.0, 1.22.0, 1.23.0 y 1.24.0 | ventana deslizante de 6 días naturales, extremos incluidos, sobre `git tag -l 'v*' --sort=creatordate --format='%(refname:short) %(creatordate:short)'` |
| Ráfaga más reciente | **6 sets en 6 días**: 1.26.0 (09-03), 1.26.1 (09-04), 1.26.2 + 1.27.0 + 1.28.0 (los tres el 09-05), 1.29.0 (09-08) | idem, con la ventana pegada al set vigente. **No es el máximo**: la fila anterior lo casi duplica |
| Silencio más largo | **25 días**, del 2026-07-22 (`v1.10.0`) al 2026-08-16 (`v1.10.1`) | mayor diferencia entre fechas de dos tags consecutivos, sobre la misma lista de `git tag -l 'v*' --sort=creatordate --format='%(refname:short) %(creatordate:short)'` |
| Cadencia objetivo | semanal, `cron: '0 6 * * 1'` (lunes 06:00 UTC) | `.github/workflows/suite-integral.yml` + QADR-0008 |
| Ramas de mantenimiento | **cero** en los cuatro repos: ninguna rama remota casa con `maint`, `lts`, `backport`, `stable` ni `N.x`, y las únicas `release-*` son ramas de release-please sobre `main` (nucleus 2, quark 1, orbit 2; el paraguas ninguna) | `git ls-remote --heads <origin>` contra cada remoto vivo — **nunca** `git branch -r` de un clon local: ahí sobreviven refs de ramas de componente ya borradas en el remoto y la cuenta sale inflada |

La última fila manda sobre todo lo demás. Hoy **no existe ningún carril para
parchear una línea antigua**, y no por descuido: la maquinaria lo prohíbe a
propósito.

- `scripts/manifest-guard.sh` §3b exige que el tag de cada módulo sea
  **ancestro** del commit raíz pinado («a module tag cut after the root tag
  cannot be certified»).
- `scripts/check_suite_tag.sh` §5 exige que el tag de suite **capture HEAD**:
  los gitlinks del tag deben ser los de HEAD y los del manifiesto de HEAD.
- release-please trabaja sobre `main` en los **tres repos de producto** (un
  `release-please.yml` en cada uno). El paraguas **no tiene release-please**:
  `scripts/train/*` pilota el de los tres productos y el tag de suite lo corta
  `scripts/train/train.sh` en el HEAD de `main`.

**Consecuencia que la política tiene que decir en voz alta:** la única forma
física de corregir un set certificado es **certificar uno nuevo**. Un set no
se re-etiqueta, no se parchea en su sitio y no recibe un backport. Cualquier
frase que insinúe lo contrario es un incumplimiento escrito.

## 3. Los ocho números — BLOQUE QUE DECIDE EL PROPIETARIO

<!-- INICIO BLOQUE DE DECISIÓN — es lo único que hay que aprobar o cambiar. -->

| id | Qué fija | Propuesto | Decisión del propietario |
|---|---|---|---|
| **S1** | Cadencia de certificación | Cadencia **objetivo** de **1 set por semana**, anclada a la corrida del lunes 06:00 UTC. **No es un intervalo máximo garantizado**: un lunes puede pasar sin corte (§5). Cortar fuera de cadencia es legítimo, con razón escrita en el PR de re-pin | **APROBADO** 2026-09-09 |
| **S2** | Ventana de soporte de un set | **60 días naturales** desde su certificación, y en todo caso **los 3 últimos sets**, lo que sea más amplio | **APROBADO** 2026-09-09 |
| **S3** | LTS | **1 set por trimestre**, soportado **6 meses**. Primera candidata: el primer set certificado en o después del **2026-10-05**, con nombre `Quantum LTS 2026Q4` — **y no antes de que exista el carril de mantenimiento del §7.1** | **NO APROBADO** — sin declarar hasta que exista el carril de mantenimiento (§7.1) |
| **S4** | Deprecación | Aviso publicado **≥ 90 días naturales** antes de la retirada; la retirada **sólo en un major de suite** (QADR-0002) | **APROBADO** 2026-09-09 |
| **S5** | Aviso escrito de fin de vida | **30 días** antes de estrechar esta política o de terminar una línea LTS. Un set ordinario **no** lleva aviso: su fin de ventana es aritmética (certificación + S2) | **APROBADO** 2026-09-09 |
| **S6** | Acuse de un reporte de vulnerabilidad | **72 horas** | **APROBADO** 2026-09-09 |
| **S7** | Respuesta y plan | Respuesta sustantiva en **7 días naturales**; para severidad **alta o crítica**, plan de corrección o mitigación **con fecha** en **14 días** | **APROBADO** 2026-09-09 |
| **S8** | Divulgación coordinada | **90 días** | **APROBADO** 2026-09-09 |

<!-- FIN BLOQUE DE DECISIÓN -->

Lo que **no** se decide aquí: los umbrales de cadena de suministro (nota de
OpenSSF Scorecard, firma, SBOM, procedencia) son números operativos de otro
documento, no compromisos con el lector.

## 4. Qué significa cada número, y por qué ese

### S1 — Cadencia semanal: objetivo, no suelo

Ya está decidida en QADR-0008 y ya tiene reloj: el cron del lunes de
`suite-integral.yml`. Esta política sólo la hace **pública** y le pone
fechas (§6). La cadencia real ha sido mucho más rápida (38 sets en 59 días),
así que el semanal describe con holgura lo que ya viene pasando.

Aun así S1 se redacta como **objetivo y no como suelo**, y la razón está en
los mismos datos del §2. Un «mínimo de 1 set por semana» se lee, del lado de
quien lo recibe, como **un intervalo máximo de 7 días**; el silencio más
largo medido son **25 días** (2026-07-22 → 2026-08-16), así que ese suelo
nacería ya incumplido por la propia historia de la suite. Prometerlo
exigiría además un carril que garantice el corte aunque no haya nada que
certificar, y QADR-0008 desacopló arcos y sets precisamente para no tenerlo.
Por eso el §5 dice que no se promete intervalo máximo: es esta misma frase
vista desde el otro lado, no una excepción a S1.

### S2 — 60 días, y qué significa exactamente «soportado»

Un set **en ventana** significa tres cosas concretas, todas cumplibles hoy:

1. Si aparece una vulnerabilidad que le afecta, el aviso **nombra ese set**
   como afectado, en vez de dejar al lector adivinando desde qué versión
   estaba expuesto.
2. La corrección se publica **en un set nuevo**, fuera de cadencia si hace
   falta (QADR-0008 ya admite «seguridad» como razón de corte).
3. Se documenta la **ruta de actualización** desde ese set hasta el que trae
   la corrección; dentro de `v1.x` esa ruta está acotada por el SLO de
   compatibilidad de nucleus (las superficies estables no rompen en un
   minor), que es una promesa **medida**, no prosa.

Un set **fuera de ventana** no se queda sin arreglo: la corrección sale
igual en el set vigente, porque la garantía 2 no depende de la ventana. Lo
que pierde son la 1 y la 3 — nadie comprueba si le afectaba, y nadie
documenta el camino de vuelta salto a salto.

Por qué 60 y no «los dos últimos minors»: a un minor por semana, «los dos
últimos minors» son catorce días — y al ritmo real, un día. 60 días son
**~8,5 sets a la cadencia objetivo** y **los 38 sets que existen** al ritmo
medido: cubre entera la historia de la suite sin prometer ni una rama de
mantenimiento.

> **Corrección respecto al plan del arco.** El plan justificaba los 60 días
> con «~15 sets al ritmo de la última semana». La cuenta no sale: al ritmo
> de la última semana (1 set/día) serían ~60, y los sets realmente
> certificados en los últimos 60 días son 38. El número 60 se sostiene; la
> aritmética que lo defendía, no.

El **suelo de 3 sets** no ha hecho falta ni una vez: el silencio más largo
medido son 25 días, muy dentro de los 60. Existe para el caso que rompería
la ventana — un parón de más de 60 días sin cortar set — y evita que la
suite se quede formalmente sin ninguna versión soportada.

### S3 — Qué significa LTS en una suite que corta cada semana

Una LTS aquí **no** es «una versión que se sigue usando»: es la única línea
sobre la que se acepta **cortar un parche sin arrastrar todo lo demás**. Con
cadencia semanal, el valor de una LTS es exactamente ese — poder recibir una
corrección de seguridad sin tragarse de golpe todo lo acumulado desde
entonces, que a este ritmo son decenas de sets.

Forma propuesta: un set por trimestre se designa LTS y se soporta 6 meses.
Con esas dos cifras hay **siempre dos líneas LTS vivas** y **3 meses de
solape** para migrar (aritmética exacta: 91 días entre cortes, 182 días de
soporte, 2026-10-05 → fin 2027-04-05, y la siguiente LTS entra el
2027-01-04, 91 días antes de ese fin). Los parches de una LTS saldrían de una
rama `release/1.x-lts-<trimestre>` en cada producto, y el paraguas los
certificaría como set `X.Y.Z+lts`.

**La condición es la parte importante, y no es la fecha: es la maquinaria.**
No se declara ninguna LTS mientras no exista el carril del §7.1 y no se haya
ensayado un corte real sobre una línea antigua. La fecha del 2026-10-05 es
el objetivo; si el carril no está, la primera LTS se corre al trimestre
siguiente y no pasa nada. Declararla antes convertiría esta política en un
incumplimiento el primer día que alguien la invoque.

### S4 — Deprecación: 90 días, y ninguna cuenta de minors

La regla dura ya existe y arrastra a los tres pilares: una superficie
estable **no se retira en `v1.x`** — las retiradas son de major, y un major
de suite mueve los tres productos a la vez (QADR-0002). Lo que falta es el
plazo mínimo del aviso.

> **Corrección respecto al plan del arco.** El plan proponía «2 líneas minor
> de suite y no menos de 30 días». La cuenta de minors hay que **quitarla**,
> no ajustarla: dos líneas minor de suite han durado un día (1.27.0 y 1.28.0,
> ambas el 2026-09-05), así que el término no acota nada y sólo da la
> impresión de acotar. Y 30 días son ~4 sets a cadencia nominal: un aviso que
> nace y muere dentro del mes no es un aviso. Queda **un solo plazo**, en
> tiempo: 90 días, que además coincide con la divulgación coordinada (S8) y
> con el trimestre de la LTS (S3), de modo que sólo hay una cifra que
> recordar.

Cada deprecación lleva su registro en el producto dueño, con la forma que
nucleus ya usa (`DEP-YYYY-NNN` + spec de asistente de migración; hoy 8 y 8),
más una fila en el índice de suite. Ese índice es el documento del §7.5, no
éste.

### S5 — Aviso de fin de vida sólo cuando lleva información

> **Corrección respecto al plan del arco.** El plan proponía «30 días de
> aviso escrito antes de que un set salga de la ventana». Aplicado a la
> cadencia real, eso son **38 avisos cada 60 días**, todos previsibles y
> todos idénticos: ruido que enseña a no leer los avisos. El fin de ventana
> de un set ordinario es **aritmética pública** (fecha de certificación +
> S2), y en cuanto exista el calendario legible por máquina del §7.2 lo
> calcula una máquina.

El aviso escrito de 30 días queda para los dos casos en los que aporta algo
que el lector no puede deducir: **estrechar esta política** (bajar S2, acortar
S3) y **terminar una línea LTS**.

### S6, S7, S8 — Vulnerabilidades: alinear sin aflojar

> **Corrección respecto al plan del arco.** El plan proponía «acuse en 3 días
> hábiles» y «plan de corrección en 14 días para alta o crítica». Lo primero
> **afloja** una promesa ya publicada: quark y orbit prometen acuse en **72
> horas** (3 días hábiles pueden ser 5 naturales con un fin de semana en
> medio) y respuesta sustantiva en **7 días**. Una política de suite no puede
> ser más laxa que la del producto que ya la publicó.

Queda entonces: **S6 = 72 h** y **S7 = 7 días**, que es lo que quark y orbit
ya prometen (nucleus no da ninguna cifra: «we aim to acknowledge reports
quickly» — esto se la pone). **Nuevo** es el plan de corrección o mitigación
**con fecha** en 14 días para severidad alta o crítica: hoy no lo promete
nadie. Y **S8 = 90 días** de divulgación coordinada es literalmente lo que ya
dicen quark y orbit; el paraguas lo hereda en vez de inventar otro número.

El corte del set con la corrección sale fuera de cadencia en cuanto el
arreglo sea público: eso ya está en `quantum/SECURITY.md` y en QADR-0008, y
aquí sólo se fecha.

## 5. Qué NO promete esta política

- **No se parchea un set en su sitio.** Ni re-etiquetado, ni backport, ni
  «1.26.1 con el arreglo». La corrección viaja siempre en un set nuevo (§2).
- **No hay LTS hasta que haya carril** (§3, S3, y §7.1). Mientras tanto, la
  ventana de S2 es toda la promesa.
- **El calendario no promete contenido.** Una fecha del §6 dice cuándo corre
  la lane, no qué traerá el set ni que vaya a haberlo: QADR-0008 desacopló
  arcos y sets a propósito, así que un lunes puede pasar sin corte.
- **No se promete un intervalo máximo entre sets.** S1 es cadencia
  objetivo, no suelo (§4): la historia desmentiría el suelo, porque hay un
  silencio medido de 25 días. El único plazo que corre contra el proyecto es
  la ventana de S2.
- **No cubre combinaciones que nadie certificó.** Mezclar el nucleus de este
  set con el orbit de otro es un trío que no ha pasado por ningún guard, y
  el manifiesto existe precisamente para evitarlo.

## 6. Calendario

Fechas de corte previstas — lunes, la corrida de `suite-integral.yml` a las
06:00 UTC. Verificadas una a una: las 17 son lunes.

| Fecha | Nota |
|---|---|
| 2026-09-14 | |
| 2026-09-21 | |
| 2026-09-28 | |
| **2026-10-05** | candidata a `Quantum LTS 2026Q4` (sujeta a §7.1) |
| 2026-10-12 | |
| 2026-10-19 | |
| 2026-10-26 | |
| 2026-11-02 | |
| 2026-11-09 | |
| 2026-11-16 | |
| 2026-11-23 | |
| 2026-11-30 | |
| 2026-12-07 | |
| 2026-12-14 | |
| 2026-12-21 | |
| 2026-12-28 | |
| **2027-01-04** | candidata a `Quantum LTS 2027Q1` |

Esta tabla es prosa y por eso es provisional: se desincroniza en dos cortes.
El calendario definitivo tiene que salir del YAML del §7.2, igual que la
página de instalación ya se genera del manifiesto en tiempo de build y por
eso no puede quedarse rancia.

## 7. Maquinaria que falta para que cada promesa sea cumplible

Ninguno de estos puntos bloquea aprobar los números; todos bloquean
**publicarlos** enteros. Están ordenados por lo que impiden.

1. **Carril de mantenimiento** (bloquea S3, y sólo S3). Ramas
   `release/1.x-lts-<trimestre>` en los tres productos, procedimiento de
   cherry-pick, configuración de release-please para esa rama, y las
   excepciones correspondientes en `manifest-guard.sh` §3b (el tag dejaría de
   ser ancestro del pin raíz) y en `check_suite_tag.sh` §5 (el tag de suite
   dejaría de capturar HEAD). Es trabajo de un arco posterior. **Hasta que
   exista y se ensaye, no se declara ninguna LTS.**
2. **Calendario legible por máquina** (bloquea publicar el §6 sin que se
   pudra): `docs/releases/calendario.yml` con un registro por set —versión,
   fecha, si es LTS, hasta cuándo está en ventana— y el guard
   `umbrella-release-calendar` registrado en `scripts/lib/guard-registry.sh`
   con su fixture obligatoria en `tests/guard-fixtures/`. Debe correr en la
   corrida programada del lunes, no sólo en PR: un retraso de cadencia sólo
   se ve en el reloj de la lane.
3. **Campos de soporte en el manifiesto** (bloquea que una máquina conteste
   «¿sigue soportado mi set?»): hoy `versions.yaml` sólo describe el set
   vigente y su `status` sólo toma `certified`. Cualquier campo nuevo hay que
   enseñárselo a `scripts/bump-set.sh` y a `manifest-guard.sh` §0, o el
   primer tren lo borra en silencio.
4. **Alineación de las cuatro `SECURITY.md`** (bloquea publicar S2): mientras
   orbit prometa «el último minor de cada módulo» y nucleus y quark «los dos
   últimos minors», la ventana de suite contradice a sus propios productos.
   La decisión de orbit —subir a dos o que la ventana de suite mande sobre
   las tres— hay que tomarla antes de publicar, no después.
5. **Política de deprecación de suite** (bloquea publicar S4): hoy sólo
   nucleus tiene ciclo, plantilla y registros; quark y orbit no tienen
   ninguno. Documento aparte, ya previsto en este mismo arco.

## 8. Plan de adopción, el día que se apruebe

En este orden, y ninguno antes de que el §3 esté decidido:

1. **Este documento** pierde la marca de borrador y fija los números
   aprobados.
2. **QADR-0010** registra la decisión y su relación con QADR-0002 (majors) y
   QADR-0008 (cadencia). Un número en un documento de gobernanza sin ADR que
   lo respalde se cambia sin dejar rastro.
3. **`quantum/SECURITY.md`**: la sección «Qué cubre un set certificado»
   sustituye la ventana en minors por S2, y añade S6/S7/S8.
4. **Los tres `SECURITY.md` de producto**: la ventana de cada uno pasa a
   apuntar a la de suite (§7.4), y nucleus adopta las cifras de S6/S7.
5. **`website/docs/support.md`** (inglés, guía de estilo del sitio) con S1,
   S2, S3 y el calendario generado del YAML del §7.2, más su entrada en
   `website/sidebarsStart.ts` — que hoy tiene cinco.
6. **El guard del §7.2** entra con su fixture: a partir de ahí, la política
   deja de depender de que alguien se acuerde.
