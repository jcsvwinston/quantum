### Sesión 2026-11-17 — **F0 de la segunda generación: QADR-0011, el repositorio nuevo, once ADR y el prototipo del núcleo**

- **Arranque**: Carlos pidió la planificación del 2.0 antes de entrar en
  materia; después, decisión a decisión, todo lo que sigue.
- **Las cinco decisiones de base** (QADR-0011): organización
  `the-quantum-platform`; monorepo `quantum` con un solo número de versión;
  Quark con nombre y vida propia; ruta de GitHub sin dominio propio y «2»
  como semver real (`…/quantum/quark/v2`, prelanzamientos
  `v2.0.0-alpha.N`); el repositorio lo opera la cuenta del propietario.
- **El núcleo ligero, medido**: importar `pkg/nucleus` 1.36.0 enlaza 430
  paquetes, 167 de terceros; el prototipo deja una API mínima en 194 y UNO
  (el parser de YAML), y 272/67 con quark y el driver de SQLite (el driver
  pesa 37 de esos 67; quark sin driver, 30, la mitad
  `go-playground/validator`: pendiente del inventario de quark). Cuatro
  decisiones: permisos propios, sólo YAML, interfaz de observación propia
  (con `traceparent`), validador propio.
- **El router y el rendimiento**: grupos, middleware con la firma de
  `net/http`, tags `path`/`query`/`header`, formas libres `Handle` y
  `HandleFunc`. Carga real en un M4 Pro (loopback, 64 conexiones):
  Quantum ≈ Gin ≈ Echo (133–140 mil req/s, 36–39 µs de CPU por petición);
  Fiber un 4–8 % por delante. La diferencia está en `net/http`, no en la
  capa propia (0,1–1,2 µs). Decidido: se queda `net/http`. Sin medir:
  Linux, `net/http` desnudo, un endpoint con base de datos.
- **La comparativa de scaffolds**: la misma aplicación de catálogo en los
  cuatro, con respuestas idénticas a ocho peticiones: 48 líneas en Quantum
  frente a 142 (Gin), 154 (Echo) y 152 (Fiber).
- **Lo que Carlos pidió y condiciona el diseño**: que nada sea magia (cada
  atajo con su forma explícita y un comando que imprima lo resuelto:
  ADR-0010); `modules/` desde el principio; dentro de un módulo, las dos
  divisiones, y `quantum new` genera la de tipo, «como Django»; migraciones
  por módulo; «todo lo ligero que podamos, módulos según necesidad,
  seguridad ante todo»; el norte es servir a un proyecto grande como
  Django y a uno pequeño como FastAPI o Flask.
- **Lo ejecutado**: quantum#328 (QADR-0011 y este handoff); en el
  repositorio nuevo, la rama `design/f1-foundations` con los ADR, la
  licencia, el prototipo y las aplicaciones de comparación; el lienzo de
  la maqueta con tres direcciones (elegida la A).
- **Lo que espera al propietario**: fusionar quantum#328; revisar la
  maqueta en pantalla; confirmar dos elecciones de la sesión (los pilares
  «Lightness by default.» y «Security above all.» en lugar de sus frases
  originales, y el copyright «The Quantum Platform Authors»); el perfil
  de la organización en GitHub; y apagar las lanes programadas de la
  generación 1 cuando quiera (la excepción de GO-2026-6909 caduca el
  2026-12-31 y sólo importa mientras corran).
- **Trampas**: un submódulo con major lleva el `/v2` al final de SU ruta
  (`…/nucleus/data/v2`); los módulos sin publicar necesitan un `replace`
  con versión en el `go.work` para compilar entre sí; `(cd X && ./bin &)`
  devuelve el pid del subshell y deja el servidor huérfano en el puerto;
  el scratchpad es volátil (lo valioso está ya en el repositorio nuevo).
