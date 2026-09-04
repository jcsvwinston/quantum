## Qué cambia y por qué

<!-- Una o dos frases. Si cierra hallazgos de auditoría, lista sus ids. -->

## Tipo de cambio

- [ ] Docs del sitio (`website/`) — en inglés, guía `docs/ESTILO_DOCS.md`
- [ ] Docs internos / README (español)
- [ ] Scripts o guards (`scripts/`, `tests/guard-fixtures/`)
- [ ] Tren de releases (`scripts/train/`)
- [ ] Re-pin del set (`versions.yaml`, submódulos) — solo dentro del tren
- [ ] CI (`.github/workflows/`)

## Verificación (comando + EXIT, no prosa)

- [ ] `bash scripts/manifest-guard.sh` → EXIT=
- [ ] `bash scripts/guard-of-guards.sh` → EXIT= (si toqué guards o fixtures)
- [ ] `cd website && npm ci && npm run build` + guards sobre `website/build` → EXIT= (si toqué `website/`)
- [ ] `bash -n` de cada script tocado
- [ ] `go build $(bash scripts/gowork-patterns.sh)` → EXIT= (si toqué `go.work`)

## Reglas del repo

- [ ] Un guard nuevo está registrado en `scripts/lib/guard-registry.sh` y tiene fixture
- [ ] No muevo gitlinks ni `versions.yaml` fuera del tren
- [ ] Commits convencionales en español, sin superlativos de marketing
