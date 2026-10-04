# A10 S10 — lo que entra con el commit del set

El guard del gate de A10 comprueba el árbol de nucleus AL PIN, y al pin de
1.38.0 no existe nada de lo que mira. Por eso se escribió en S4–S9 y espera
aquí, fuera del registro, hasta el set que pine el nucleus con A10:

- `scripts/check_api_posture.sh` — el guard. Está en el árbol, excluido en
  `GUARD_SCAN_EXCLUDE` con su porqué.
- `fixture-umbrella-api-posture.sh` — su fixture. No puede estar en
  `tests/guard-fixtures/` antes de registrar el guard: guard-of-guards la
  marca huérfana.

En el commit del set (el que mueve el gitlink de nucleus):

1. `git mv docs/planes/A10-s10/fixture-umbrella-api-posture.sh tests/guard-fixtures/umbrella-api-posture/fixture.sh`
2. registrar `"umbrella-api-posture|.|bash scripts/check_api_posture.sh"`
   en `scripts/lib/guard-registry.sh` (junto a `umbrella-fleet-posture`, con
   su comentario) y quitar `scripts/check_api_posture.sh` de
   `GUARD_SCAN_EXCLUDE`;
3. `website/sidebarsNucleus.ts` gana `'concepts/modules'` (página nueva de S9);
4. filas de DEP-2026-009, DEP-2026-011 y DEP-2026-012 en el §6 de
   `docs/POLITICA_DEPRECACION.md` (nucleus pasa de 0 a 7 marcas vivas);
5. `website/docs/quickstart.md`: los listados de `main.go` (llama a
   `WithOpenAPIDocument`) y de `shop/module.go` (rutas con `nucleus.Handle`,
   tipos `AuthorList`, `ArticleList`, `ArticleFilter`, `CreateArticle`) —
   `scripts/ci/check_quickstart_listings.sh` los compara con el starter
   recién generado en la lane del quickstart;
6. borrar este directorio.

Probado contra el árbol integrado de A10 (los seis PRs apilados): el guard da
OK con 46/46 y la fixture provoca sus tres roturas.
