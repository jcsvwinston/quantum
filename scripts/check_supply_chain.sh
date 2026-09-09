#!/usr/bin/env bash
# check_supply_chain.sh — los tres productos siguen publicando sus binarios
# con SBOM, firma y procedencia.
#
# Qué cierra: el hallazgo QM-14 de la auditoría de madurez del 2026-09-03
# decía que la suite publicaba binarios sin nada que permitiera comprobar de
# dónde salían. El arco A3 lo arregló repositorio a repositorio —bloque
# `sboms:` y `signs:` en la config de GoReleaser, y un paso
# `actions/attest-build-provenance` en el workflow de release—, y eso deja un
# problema nuevo: son cuatro líneas de YAML en tres repos que nadie mira, y su
# desaparición no rompe ninguna corrida. Un release sin firma sale VERDE.
#
# Por eso el guard mira las CUATRO mitades de la misma decisión, y no sólo la
# firma:
#
#   1. `sboms:` en la config de GoReleaser — qué lleva dentro el artefacto;
#   2. `signs:` — quién lo construyó, comprobable sin confiar en la página de
#      releases;
#   3. el paso de atestación de procedencia en el workflow de release — qué
#      corrida lo produjo, en formato verificable con `gh attestation verify`;
#   4. los permisos que esas dos cosas necesitan (`id-token: write` para la
#      firma sin clave, `attestations: write` para la atestación). Sin ellos
#      los pasos existen y fallan, que es la forma más cara de no tener nada.
#
# El PARAGUAS entró en la lista con quantum#166, que publica el set como
# paquete verificable (manifiesto, bloque require, gitlinks y sumas). No tiene
# GoReleaser —no compila nada— así que de él se comprueban las dos mitades que
# sí tiene: la firma del fichero de sumas y la atestación, con sus permisos.
#
# Corre AL PIN para los tres productos, como el resto del registro: lo que
# certifica es lo que el set publica, no lo que hay en la rama de nadie. El
# paraguas se comprueba en el árbol de trabajo, que es donde vive.
#
# Uso: bash scripts/check_supply_chain.sh
set -uo pipefail
cd "$(dirname "$0")/.."

status=0

# repo|fichero de goreleaser|workflow de release
OBJETIVOS="
.|—|.github/workflows/release-set.yml
quark|.goreleaser.yaml|.github/workflows/release.yml
nucleus|.goreleaser.yaml|.github/workflows/release.yml
orbit|.goreleaser.yaml|.github/workflows/release.yml
"

falta() {
  echo "FAIL: $1" >&2
  status=1
}

for linea in $OBJETIVOS; do
  repo=${linea%%|*}
  resto=${linea#*|}
  gorel=${resto%%|*}
  wf=${resto#*|}
  [ -n "$repo" ] || continue

  if [ "$repo" != "." ] && [ ! -d "$repo" ]; then
    falta "falta el submódulo $repo — ¿git submodule update --init?"
    continue
  fi

  if [ "$repo" = "." ]; then
    # El paraguas no compila binarios: no hay config de GoReleaser que mirar.
    if [ ! -f "$wf" ]; then
      falta "el paraguas no tiene $wf — el set se publicaría sin firma ni procedencia"
      continue
    fi
    if ! grep -q "cosign" "$wf"; then
      falta "$wf no firma nada — falta la firma sin clave sobre el fichero de sumas"
    fi
    if ! grep -q "actions/attest-build-provenance" "$wf"; then
      falta "$wf no atesta la procedencia — falta el paso actions/attest-build-provenance"
    fi
    for permiso in "id-token: write" "attestations: write" "contents: write"; do
      if ! grep -qE "^[[:space:]]*${permiso}([[:space:]]|$)" "$wf"; then
        falta "$wf no pide \`${permiso}\` — el paso que lo necesita existiría y fallaría en la corrida del tag"
      fi
    done
    continue
  fi

  if [ ! -f "$repo/$gorel" ]; then
    falta "$repo no tiene $gorel — el producto publica binarios sin config de GoReleaser reproducible"
    continue
  fi
  for bloque in sboms signs; do
    if ! grep -qE "^${bloque}:" "$repo/$gorel"; then
      falta "$repo/$gorel no declara el bloque \`${bloque}:\` — los artefactos salen sin $([ "$bloque" = sboms ] && echo 'lista de materiales' || echo 'firma')"
    fi
  done

  if [ ! -f "$repo/$wf" ]; then
    falta "$repo no tiene $wf — nada corta la release con la config de arriba"
    continue
  fi
  if ! grep -q "actions/attest-build-provenance" "$repo/$wf"; then
    falta "$repo/$wf no atesta la procedencia — falta el paso actions/attest-build-provenance"
  fi
  for permiso in "id-token: write" "attestations: write"; do
    if ! grep -qE "^[[:space:]]*${permiso}([[:space:]]|$)" "$repo/$wf"; then
      falta "$repo/$wf no pide \`${permiso}\` — el paso que lo necesita existiría y fallaría en la corrida del tag"
    fi
  done
done

if [ "$status" -eq 0 ]; then
  echo "OK: cadena de suministro — quark, nucleus y orbit publican con SBOM, firma sin clave y atestación de procedencia, y el paraguas publica el set firmado y atestado"
fi
exit $status
