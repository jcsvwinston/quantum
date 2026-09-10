#!/usr/bin/env bash
# check_release_assets.sh — la release del tag pinado publicó de verdad lo que
# el árbol promete firmar.
#
# POR QUÉ EXISTE, con fecha. El arco A3 dejó a los cuatro repos publicando
# binarios con SBOM, firma sin clave y atestación de procedencia, y dos guards
# que lo comprueban: check_supply_chain.sh mira que las configuraciones lo
# declaren, y umbrella-actions-pinned que las acciones estén fijadas. Los dos
# leen el ÁRBOL, y el propio comentario de check_supply_chain.sh lo dice: «un
# release sin firma sale VERDE».
#
# El 2026-09-10 dejó de ser una nota al pie. Un bump había subido
# sigstore/cosign-installer a v4, y con él cosign a v3, que cambió `sign-blob`
# para escribir un bundle de Sigstore sin valor por defecto para `--bundle`.
# La firma murió en una ruta vacía: **nucleus v1.26.0 se publicó con CERO
# activos** y el paquete del set tampoco salió. Los 47 guards pasaron. No
# podían verlo: el `.goreleaser.yaml` seguía declarando `sboms:` y `signs:`,
# que es lo único que miraban.
#
# QUÉ COMPRUEBA. Para cada pilar en el tag que versions.yaml pina, y para el
# tag de suite: que exista la release y que entre sus activos estén
# `checksums.txt`, `checksums.txt.sig` y `checksums.txt.pem`. Esos tres son el
# mínimo que hace verificable todo lo demás — el fichero de sumas cubre por
# digest a los otros activos, y la firma y el certificado son lo que permite
# comprobar QUÉ corrida lo construyó, sin confiar en la página de releases.
#
# QUÉ NO COMPRUEBA, dicho para que no se lea de más:
#   - No verifica la firma criptográficamente. Eso es `cosign verify-blob`, que
#     exige descargar los activos; aquí sólo se afirma que ESTÁN.
#   - No mira la atestación de procedencia, que no es un activo de la release:
#     vive en la API de atestaciones. Comprobarla es `gh attestation verify`.
#   - No sustituye a check_supply_chain.sh. Aquel dice que la configuración
#     promete firmar; este, que la corrida cumplió. Hacen falta los dos: sin el
#     primero, alguien borra cuatro líneas de YAML y nadie se entera hasta el
#     corte siguiente.
#
# NECESITA RED, y es el primer guard del registro que la necesita. Si no puede
# preguntar, FALLA — no salta. Un guard que se salta en silencio cuando no
# tiene datos es indistinguible de uno que pasa, que es justo el modo de fallo
# que este guard existe para cerrar.
#
# El cliente de GitHub se puede sustituir con QUANTUM_GH, que es lo que usa la
# fixture para servir una release doctorada sin salir a la red.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

GH=${QUANTUM_GH:-gh}
OWNER=${QUANTUM_OWNER:-jcsvwinston}
REQUERIDOS=(checksums.txt checksums.txt.sig checksums.txt.pem)
status=0

# yaml_value <sección> <clave> — el mismo bloque de dos espacios que lee el
# manifest-guard.
yaml_value() {
  awk -v sec="$1:" -v key="$2:" '
    $0 == sec            { inb = 1; next }
    inb && /^[^[:space:]]/ { inb = 0 }
    inb && $1 == key     { gsub(/"/, "", $2); print $2; exit }
  ' versions.yaml
}

suite=$(sed -nE 's/^quantum:[[:space:]]+"([^"]+)".*/\1/p' versions.yaml | head -1)
[ -n "$suite" ] || { echo "FAIL: versions.yaml no declara 'quantum:'" >&2; exit 1; }

# repo → tag que hay que mirar. Los tres pilares, en el tag que el set pina; y
# el paraguas, en su propio tag de suite.
objetivos="quark $(yaml_value modules quark)
nucleus $(yaml_value modules nucleus)
orbit $(yaml_value modules orbit)
quantum v$suite"

while read -r repo tag; do
  [ -n "$repo" ] && [ -n "$tag" ] || { echo "FAIL: no pude leer el pin de '$repo' en versions.yaml" >&2; status=1; continue; }

  activos=$("$GH" release view "$tag" -R "$OWNER/$repo" --json assets --jq '[.assets[].name] | .[]' 2>&1)
  rc=$?
  if [ $rc -ne 0 ]; then
    case "$activos" in
      *"release not found"*|*"Not Found"*|*"not found"*)
        echo "FAIL: $repo $tag — no hay release publicada para el tag que el set certifica" >&2 ;;
      *)
        echo "FAIL: $repo $tag — no pude preguntar a GitHub por su release: $(printf '%s' "$activos" | head -1)" >&2
        echo "      (este guard necesita red y un gh autenticado; si no puede preguntar, no puede afirmar nada)" >&2 ;;
    esac
    status=1
    continue
  fi

  if [ -z "$activos" ]; then
    echo "FAIL: $repo $tag — la release existe y NO tiene ningún activo. Es el modo de fallo de 2026-09-10: la firma murió y la release salió igual." >&2
    status=1
    continue
  fi

  faltan=""
  for req in "${REQUERIDOS[@]}"; do
    printf '%s\n' "$activos" | grep -qx "$req" || faltan="$faltan $req"
  done

  if [ -n "$faltan" ]; then
    echo "FAIL: $repo $tag — la release no publica:$faltan" >&2
    echo "      Sin el fichero de sumas y su firma, lo que el árbol promete no se puede comprobar desde fuera." >&2
    status=1
  else
    n=$(printf '%s\n' "$activos" | grep -c .)
    echo "OK: $repo $tag — $n activo(s), con checksums.txt firmado y su certificado"
  fi
done <<< "$objetivos"

if [ $status -eq 0 ]; then
  echo "OK: activos de release — los tres pilares y el paraguas publican lo que sus configuraciones prometen firmar"
fi
exit $status
