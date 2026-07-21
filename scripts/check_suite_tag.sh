#!/usr/bin/env bash
# check_suite_tag.sh — el tag de suite tiene que respaldar lo que dice ser.
#
# La 8ª auditoría (QM8-6) señaló que el procedimiento del tag de suite (QM7-3:
# «el tag se corta DESPUÉS del último PR de la ronda») no tenía guard: nada
# comprobaba mecánicamente que el tag v<quantum> apunte a un árbol cuyo propio
# manifiesto declara esa versión y cuyos gitlinks son los pins certificados.
# Un tag cortado un PR antes de tiempo certificaba un estado que aún iba a
# cambiar — y solo un humano lo notaba.
#
# Qué se exige del tag verificado (las tres coordenadas, todas AL TAG):
#   1. El tag existe.
#   2. El versions.yaml DE ESE TAG declara exactamente la versión del tag.
#   3. Los gitlinks del tag (quark/nucleus/orbit) coinciden con los
#      workspace_pins del versions.yaml de ese tag.
#   4. El tag es ancestro de HEAD (el tag pertenece a esta historia; un tag
#      igual de nombre sobre otra rama no respalda nada).
#
# Caso mid-tren (decisión QM8-6, documentada en docs/AUDITORIA_CONTINUA.md):
# «versión nueva en main pero tag aún no cortado» es un estado LEGÍTIMO — el
# procedimiento de ronda corta el tag después del último PR, así que el PR de
# re-pin corre esta lane con la versión nueva y sin tag. Fallar ahí (o exigir
# un escape) haría in-certificable el flujo correcto. En ese estado el guard:
#   - verifica el ÚLTIMO tag de suite existente contra SU PROPIO árbol
#     (asserts 2-4 con su propia versión), y
#   - deja un AVISO visible de que la versión actual sigue pre-tag («tren en
#     marcha») — la corrida semanal lo repite hasta que el tag se corte, y la
#     plantilla de CIERRE exige este guard con el tag YA cortado (EXIT=0 sin
#     aviso), así que un tag olvidado no puede llegar a un cierre.
# Sin NINGÚN tag de suite (hay tag desde v1.0.0) sí es FAIL: historia rota.
#
# Red: los tags del paraguas se refrescan si hay remoto origin; el fallo de
# fetch sigue la política QM8-8 (FAIL, salvo QUANTUM_OFFLINE=1 en local, que
# degrada a AVISO; en CI siempre estricto). Sin remoto (árboles de fixture,
# clones locales desconectados) se usan los tags locales sin aviso.
set -uo pipefail

cd "$(dirname "$0")/.."

manifest=versions.yaml
status=0

# yaml_top KEY — valor de una clave de nivel superior (`KEY: "valor"`) de un
# contenido de versions.yaml pasado por stdin. Sin yq: fichero plano conocido.
yaml_top() {
  awk -v key="$1" '$1 == key":" { v=$2; gsub(/"/, "", v); print v; exit }'
}

# yaml_section CONTENIDO_FILE SECTION KEY — `KEY: "valor"` bajo `SECTION:`.
yaml_section() {
  awk -v sec="$2" -v key="$3" '
    $0 ~ "^"sec":" { inblock=1; next }
    /^[a-zA-Z_]/   { inblock=0 }
    inblock && $1 == key":" { v=$2; gsub(/"/, "", v); print v; exit }
  ' "$1"
}

current=$(yaml_top quantum < "$manifest")
if [[ -z "$current" ]]; then
  echo "FAIL: $manifest no declara 'quantum:' — sin versión de suite no hay tag que verificar" >&2
  exit 1
fi

# Tags frescos del PARAGUAS (política QM8-8). Sin remoto origin: tags locales.
if git remote get-url origin >/dev/null 2>&1; then
  if ! git fetch --tags --quiet origin; then
    if [[ "${QUANTUM_OFFLINE:-0}" == "1" && -z "${CI:-}" ]]; then
      echo "AVISO(QUANTUM_OFFLINE=1): fetch de tags del paraguas falló — se usan los tags locales (solo iteración local sin red)"
    else
      echo "FAIL: fetch de tags del paraguas falló — sin tags frescos el veredicto se apoyaría en datos viejos (en local sin red: QUANTUM_OFFLINE=1; en CI siempre estricto)" >&2
      exit 1
    fi
  fi
fi

# verify_tag TAG — asserts 2-4 sobre el árbol DEL TAG. Acumula en $status.
verify_tag() {
  local tag=$1 want="${1#v}" tag_manifest declared m pin gitlink

  tag_manifest=$(git show "$tag:$manifest" 2>/dev/null)
  if [[ -z "$tag_manifest" ]]; then
    echo "FAIL: el tag $tag no contiene $manifest — un tag de suite sin manifiesto no certifica nada" >&2
    status=1
    return
  fi

  declared=$(yaml_top quantum <<<"$tag_manifest")
  if [[ "$declared" != "$want" ]]; then
    echo "FAIL: el versions.yaml del tag $tag declara quantum \"$declared\", no \"$want\" — el tag no respalda la versión que su nombre afirma (¿tag cortado antes del bump del manifiesto?)" >&2
    status=1
  else
    echo "OK: $tag — su versions.yaml declara quantum \"$declared\""
  fi

  for m in quark nucleus orbit; do
    pin=$(awk -v sec="workspace_pins" -v key="$m" '
      $0 ~ "^"sec":" { inblock=1; next }
      /^[a-zA-Z_]/   { inblock=0 }
      inblock && $1 == key":" { v=$2; gsub(/"/, "", v); print v; exit }
    ' <<<"$tag_manifest")
    gitlink=$(git ls-tree "$tag" "$m" 2>/dev/null | awk '$2 == "commit" {print $3}')
    if [[ -z "$pin" || -z "$gitlink" ]]; then
      echo "FAIL: $tag — falta workspace_pin ('$pin') o gitlink ('$gitlink') de $m en el árbol del tag" >&2
      status=1
    elif [[ "$gitlink" != "$pin"* ]]; then
      echo "FAIL: $tag — el gitlink de $m es ${gitlink:0:8} pero el versions.yaml del tag pina $pin — el tag certifica un árbol que no es el suyo (la clase QM7-3: tag cortado sobre un estado que aún iba a cambiar)" >&2
      status=1
    else
      echo "OK: $tag — gitlink de $m (${gitlink:0:8}) == workspace_pin ($pin)"
    fi
  done

  if ! git merge-base --is-ancestor "$tag" HEAD 2>/dev/null; then
    echo "FAIL: el tag $tag no es ancestro de HEAD — el tag no pertenece a esta historia (¿re-tag o rama huérfana?)" >&2
    status=1
  else
    echo "OK: $tag — ancestro de HEAD"
  fi
}

if git rev-parse -q --verify "refs/tags/v$current" >/dev/null; then
  echo "== tag de suite v$current (la versión que $manifest declara) =="
  verify_tag "v$current"
else
  # Mid-tren: la versión actual aún no tiene tag. Verifica el último existente
  # contra su propio árbol (ver cabecera) y deja el estado pre-tag a la vista.
  latest=$(git tag -l 'v*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
  if [[ -z "$latest" ]]; then
    echo "FAIL: no existe NINGÚN tag de suite v* — hay tag de suite desde v1.0.0; sin tags no hay estado certificado que verificar (¿faltó fetch --tags?)" >&2
    exit 1
  fi
  echo "AVISO: v$current (la versión de $manifest) aún SIN tag — tren en marcha; se verifica el último tag existente ($latest) contra su propio árbol. El cierre de ronda exige este guard con el tag ya cortado."
  echo "== tag de suite $latest (último existente; v$current pre-tag) =="
  verify_tag "$latest"
fi

if [[ $status -ne 0 ]]; then
  echo >&2
  echo "check_suite_tag: FALLO — el tag de suite no respalda lo que afirma (ver arriba)." >&2
  exit 1
fi
echo "check_suite_tag: OK"
