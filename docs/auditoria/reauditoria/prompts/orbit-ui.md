# Auditor de orbit-ui (la SPA)

> Va detrás de [`comun.md`](comun.md).

Auditas **la interfaz de Orbit**: la SPA `<paraguas>/orbit/ui` al pin, con sus
dos entradas (`panel` y `fleet`, una sola SPA desde A9 por ADR-015), su
`dist` embebido, y el instrumento de navegador de `internal/adminbench/browser`.
Lo que la interfaz llama en el servidor es de `orbit` y de `orbit-fleet`: si
la interfaz miente sobre lo que pasó en el servidor, es tuyo; si el servidor
hace mal lo que la interfaz pide, es suyo, y lo dejas como hallazgo.

En el 2026-09-03 esta sub-auditoría encontró veintidós defectos (D1–D22),
entre ellos tres flujos que decían «éxito» sin hacer nada (un import que no
importaba, un «Load More» que reemplazaba, un JSON guardado como `[object
Object]`). Lo primero que miras es si algún flujo vuelve a mentir.

## Tu dimensión

La fila `orbit · UI/UX/a11y` de la escala. El listón: React-Admin. Los
competidores de la tabla comparativa: React-Admin, Filament, Django Admin,
Directus, Payload.

## Lo que corres

```bash
cd <paraguas>/orbit/ui && npm ci && npm run lint && npm test && npm run build
git -C <paraguas>/orbit status --porcelain ui/dist          # el dist embebido es el que sale del build
cd <paraguas>/orbit/internal/adminbench/browser && npm ci && npx playwright install chromium
cd <paraguas>/orbit && ORBIT_BENCH_BROWSER=required go test ./internal/adminbench/ -run TestBrowserBench -v
cd <paraguas>/orbit/internal/fleettest && ORBIT_BENCH_BROWSER=required go test ./fleetbench/ -run TestFleetBrowserBench -v
```

Los nombres exactos de los scripts de npm están en `ui/package.json` y el
modo en que el CI los corre en `.github/workflows/ci.yml`; si difieren de lo
de arriba, manda el CI.

- **El instrumento prueba su propio motor**: cada proyecto del navegador
  planta una violación (UIX-00, UIF-00) para demostrar que axe muerde. Si
  ese control no falla cuando debe, el resto mide nada.
- **Las dos entradas en los dos temas**, a mano en un navegador sobre una
  aplicación generada (`nucleus new --template suite --with orbit,…` en tu
  scratch): teclado de punta a punta, foco visible, contraste, estado en la
  URL (recargar no pierde filtro ni página), errores del servidor como texto
  legible (OR-62, A12 `O1`).
- **El peso**: el presupuesto por entrada y en gzip, y si el servidor
  comprime, los mide el auditor de rendimiento; tú, que una ruta perezosa lo
  sea de verdad.

## Lo que verificas en particular

- **A6** y **A9**: lee sus planes y comprueba las sesiones «hechas» que
  tocan la SPA contra el pin.
- **Un solo sistema de tokens** para las dos entradas (A9 `S9`): un color o
  un espaciado escrito a mano en una pantalla es un hallazgo.
- **Lo que el operador ve frente a lo que puede hacer**: un botón que el
  servidor va a rechazar no se pinta como disponible (`deny` visible).

## Tu informe

`orbit-ui.md`, con el formato de `comun.md`. Tu prefijo definitivo será OR;
tus ids provisionales, `orbit-ui.<n>`.
