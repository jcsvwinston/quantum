# Guía de estilo y tono para documentación de usuario

> Interna (no se sirve en el sitio). Aplica a toda página que un LECTOR ve:
> `website/docs/` del paraguas y los `website/docs/` de los tres productos.
> No aplica a docs internos (`docs/`, ADRs, playbooks), donde la voz de
> mantenedor es la correcta.
>
> Origen: la 9ª ronda de auditoría observó que el patrón del getting-started
> de quark es el mejor tono de la suite, y que la voz de mantenedor se filtra
> en páginas de usuario. Esta guía codifica el patrón y muestra reescrituras
> reales.

## El patrón (el del getting-started de quark)

1. **Promete resultado y tiempo en el primer párrafo.** «By the end of this
   page you'll have X. It takes about ten minutes.» El lector decide en dos
   frases si la página es para él. Si no puedes prometer un resultado
   concreto, la página probablemente son dos páginas.

2. **Muestra las salidas, no solo el código.** Cada snippet que imprime algo
   lleva su salida (`// =>` inline, o un bloque de output tras el comando).
   Una salida real es la diferencia entre «confía en mí» y «compruébalo».
   Corolario: las salidas se capturan EJECUTANDO el código antes de publicar,
   nunca se redactan de memoria.

3. **Anticipa la duda en el punto exacto donde surge.** Un `:::note` corto
   junto al paso que sorprende (el 403 del default-deny, el WARN del update
   parcial), no una sección de troubleshooting a tres páginas de distancia.

4. **Honestidad sobre los límites, en la propia página.** «Cuándo NO usar
   esto» no va escondido en un FAQ: la página de elección de capa de datos
   dice cuándo no necesitas quark; el intro de la suite dice cuándo no usar
   la suite. La honestidad técnica es la única forma de credibilidad que no
   se compra con adjetivos.

5. **Cero hype.** La regla anti-marketing de los tres repos aplica a las
   docs con el mismo rigor que a los commits: nada de «production-ready»,
   «battle-tested», «blazing fast», «enterprise-grade». Describe lo que hace
   y su coste; el adjetivo lo pone el lector.

6. **Voz de producto, no de mantenedor.** La página de usuario habla de LO
   QUE EL LECTOR PUEDE HACER HOY. La historia del repo (qué se movió, qué se
   retiró, en qué ronda se arregló) pertenece a release notes y docs
   internos. Señales de que se ha colado la voz de mantenedor:
   - narrativa de cambio («previously shipped», «has been removed», «was
     moved out of») fuera de release notes o de una nota de migración
     marcada como tal;
   - identificadores de expediente (hallazgos de auditoría, números de
     ronda, referencias a ficheros internos del repo);
   - primera persona de equipo («we want», «our decision») fuera de páginas
     de principios/arquitectura, donde sí es legítima.

## Reescrituras reales

### 1. La portada del sitio (aplicada en esta misma ronda)

**Antes** (contaba la topología del repo):

> A web framework, an ORM and an admin panel for Go: developed separately,
> coordinated as a suite.
>
> Each product's documentation lives in its own repository; this site
> *assembles* it under one roof.

Dónde vive cada README no es un argumento para usar el producto: es la
organización interna del proyecto mirándose al espejo.

**Después** (cuenta el valor y el siguiente paso):

> The pieces most Go applications end up needing — web framework, data
> layer, admin panel — versioned to work together.
>
> Nucleus hosts your application on the standard library; Quark types your
> SQL across six engines; Orbit mounts an admin panel inside the same
> process. Each certified set is a trio of versions tested together, so
> upgrading the suite is one known-good step — not three separate bets.

### 2. Narrativa de cambio en una página de features (nucleus, pendiente)

`nucleus/website/docs/features/admin.md`, sección «Effective-config
inspection».

**Antes** (historia del repo en una página de usuario):

> The `GET /_/config` HTTP endpoint that previously shipped with the admin
> subsystem has been removed from the framework core. Use
> `nucleus config print --effective` from the CLI for effective merged
> configuration inspection:

El lector nuevo jamás conoció ese endpoint; se le cuenta la mudanza de una
casa que nunca visitó. La instrucción útil queda subordinada a la historia.

**Después** (instrucción primero; la historia, si hace falta, en una nota de
migración marcada):

> To inspect the effective merged configuration, use the CLI:
>
> ```bash
> nucleus config print --effective --config nucleus.yml
> ```
>
> :::note Migrating from an older version?
> The `GET /_/config` endpoint no longer exists; this CLI command replaces it.
> :::

### 3. Historia de la extracción en el intro de orbit (orbit, pendiente)

`orbit/website/docs/intro.md`, primer pantallazo.

**Antes** (organización del proyecto como argumento):

> Orbit is a separate Go module with its own release cadence. The admin
> panel was moved out of the framework core so the core stays lean and the
> panel can evolve as its own product.

La segunda frase es un acta de decisión interna. Lo que el lector necesita
es la consecuencia práctica.

**Después** (la consecuencia para el lector):

> Orbit is its own Go module with its own releases: your app depends on the
> framework, and adds the panel only if it wants one — the framework carries
> no admin code either way.

## Checklist antes de publicar una página de usuario

- [ ] ¿El primer párrafo promete un resultado y (si es un tutorial) un tiempo?
- [ ] ¿Todo snippet que imprime lleva su salida, capturada ejecutándolo?
- [ ] ¿Las dudas previsibles tienen su nota AL LADO del paso que las provoca?
- [ ] ¿La página dice cuándo NO usar lo que documenta?
- [ ] ¿Cero superlativos de marketing?
- [ ] ¿Cero narrativa de cambio, expedientes de auditoría y primera persona
      de equipo (salvo release notes, notas de migración marcadas y páginas
      de principios)?

Guardas relacionadas: `scripts/check_served_jargon.sh` caza los
identificadores internos en el HTML servido; el tono, de momento, solo lo
caza la revisión humana con esta guía delante.
