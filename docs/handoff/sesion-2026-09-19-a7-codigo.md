# Sesión 2026-09-19 (antes del tren) — A7 completo en código

Archivada del §3 de `.claude/commands/next-session.md` el 2026-09-20 al
cerrar A8 `S1`: el §3 es estado vigente más dos sesiones, y lo anterior se
busca aquí con grep (guard `umbrella-handoff-size`).

### Sesión 2026-09-19 (antes del tren) — **A7 completo en código**: de 12 a 40 de 40, nueve sesiones en una tanda, y el gate medido

- **S3 a S11 hechas** (nucleus#554…#562, apilados). El banco cierra en **40 de
  40 con todas las familias completas**: cola 13/13, eventos 12/12, tiempo real
  8/8, operación 7/7.
- **Lo que entró, por sesión**: `S3` inspección real y métricas para los tres
  proveedores más `TaskInspectorFrom` (NU-81, NU-82, NU-83); `S4` cron con
  **líder por lock de base de datos** y unicidad de job; `S5` el bus deja de
  hacer daño a quien emite (NU-78, NU-79); `S6` **bus tipado junto al que hay**
  y el outbox como su transporte; `S7` el outbox cuenta por topic (NU-76);
  `S8` **canales WS y SSE con el protocolo escrito en el framework**; `S9`
  `/livez` y `/readyz` separados, pprof protegido, relay entre réplicas y
  **NU-77 cerrado por sus dos causas**; `S10` `Server.Stream` con `Quiet`;
  `S11` el gate, el guard y la retención (NU-86).
- **El gate, medido de verdad**: 10 000 jobs, el worker muerto con **SIGKILL**
  y **trabajo en vuelo asertado** —matar un proceso ocioso también pasa y mide
  nada—, resultado **10 000 hechos, 0 muertos, 0 perdidos, 0 duplicados**. Corre
  en el CI.
- **`umbrella-jobs-posture` es el guard 51º**, con fixture de tres roturas: la
  página que publica otra cifra, el CI que deja de correr la prueba, y la
  prueba que deja de exigir trabajo en vuelo.
- **Cuatro lecciones sobre medir, todas pagadas en esta tanda**: (1) una sonda
  que **no recorre el cableado** certifica algo que no existe — el banco daba
  por buenos cuatro controles mientras `jobs_provider: sql` **panicaba en el
  arranque**; (2) un veredicto correcto **por la razón equivocada** no lo caza
  ningún test; (3) **el orden de los tests es un instrumento** — el defecto de
  los instrumentos de métricas sólo se vio porque una sonda corría después de
  otra; y (4) **un `replace` silencioso miente**: el paso de CI que `S2` decía
  haber añadido no estaba, y su PR lo afirmaba.
- **Lo que falta, y no lo hace una sesión sola: EL TREN.** Fusionar los nueve
  PRs, cortar la release de nucleus, cerrar con ella **OR-53** (la mitad de
  orbit: `orbit.Config` necesita un campo para el `tasks.Inspector`, y no
  compila hasta que la release exista — la trampa que A6 dejó escrita), y
  certificar el set. **A7 se declara cerrado ahí**, no antes.
