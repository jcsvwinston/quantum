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
# Qué se exige del tag verificado:
#   AL TAG (autoconsistencia — el tag respalda su propio nombre):
#   1. El tag existe.
#   2. El versions.yaml DE ESE TAG declara exactamente la versión del tag.
#   3. Los gitlinks del tag (quark/nucleus/orbit) coinciden con los
#      workspace_pins del versions.yaml de ese tag.
#   4. El tag es ancestro de HEAD (el tag pertenece a esta historia; un tag
#      igual de nombre sobre otra rama no respalda nada).
#   TAG ↔ HEAD (captura — el tag apunta al set que HEAD certifica; MAQ-1/B.1):
#   5. Los gitlinks del tag == los gitlinks de HEAD == los workspace_pins del
#      versions.yaml de HEAD. Un tag AUTOCONSISTENTE (asserts 2-4 verdes) puede
#      seguir siendo RANCIO: cortado antes del re-pin final, congela un set
#      viejo (gitlink viejo + su propio manifiesto viejo, coherentes entre sí)
#      bajo el nombre correcto. Los asserts 2-4 no lo cazan (el tag es coherente
#      consigo mismo); el 5 sí — es la clase QM7-3 que este guard decía cazar y
#      solo cubría a medias (la variante inconsistente). Abajo, cuándo aplica.
#
# Modo CERTIFICACIÓN (--cierre / env QUANTUM_CERTIFYING=1; MAQ-2/B.2). El acto
# de certificar EXIGE que el tag de suite exista Y capture HEAD; la lane semanal
# normal es más laxa (entre arcos HEAD puede ir por delante del último tag con
# el set drifteado, y eso es legítimo). Por eso el assert 5 y el trato del caso
# mid-tren dependen del modo:
#   - assert 5 (captura de HEAD): se EXIGE cuando certificamos (--cierre) o
#     cuando el tag ES HEAD (tag==HEAD, el commit de certificación por diseño de
#     B.2). FUERA de ahí NO se fuerza — romper ahí pondría roja la lane semanal
#     en un estado legítimo.
#
# Caso mid-tren (decisión QM8-6, documentada en docs/AUDITORIA_CONTINUA.md):
# «versión nueva en main pero tag aún no cortado» es un estado LEGÍTIMO EN LA
# LANE SEMANAL — el procedimiento de ronda corta el tag después del último PR,
# así que el PR de re-pin corre esta lane con la versión nueva y sin tag. Fallar
# ahí (o exigir un escape) haría in-certificable el flujo correcto. En ese
# estado el guard, FUERA de modo certificación:
#   - verifica el ÚLTIMO tag de suite existente contra SU PROPIO árbol
#     (asserts 2-4 con su propia versión), y
#   - deja un AVISO visible de que la versión actual sigue pre-tag («tren en
#     marcha») — la corrida semanal lo repite hasta que el tag se corte, y la
#     plantilla de CIERRE exige este guard con el tag YA cortado (EXIT=0 sin
#     aviso), así que un tag olvidado no puede llegar a un cierre.
# En modo CERTIFICACIÓN el mismo estado mid-tren es NO-PASA (B.2): certificar
# exige que el tag EXISTA y capture HEAD, así que el AVISO deja de contar como
# EXIT=0 y pasa a FAIL. Así «15/15 EXIT=0 en --cierre» ya no puede significar
# «tren a medias sin tag», solo «tag cortado que captura HEAD».
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

# Modo certificación (B.2): env QUANTUM_CERTIFYING=1 (lo exporta
# suite-integral.sh --cierre para toda la tanda de guards) o el flag --cierre
# (invocación directa / la orden de la plantilla de CIERRE). En este modo el
# mid-tren sin tag es FAIL y el assert 5 (captura de HEAD) se exige aunque el
# tag no sea HEAD. Fuera de él, la lane semanal es laxa (ver cabecera).
certifying=0
if [[ "${QUANTUM_CERTIFYING:-0}" == "1" ]]; then certifying=1; fi
for arg in "$@"; do
  case "$arg" in
    --cierre) certifying=1 ;;
    *) echo "AVISO: argumento no reconocido '$arg' (uso: check_suite_tag.sh [--cierre])" >&2 ;;
  esac
done

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

# assert_tag_captures_head TAG — assert 5 (MAQ-1/B.1): el tag apunta al MISMO
# set que HEAD certifica. Compara, por módulo:
#   gitlink del TAG  ==  gitlink de HEAD  ==  workspace_pin del versions.yaml
#   de HEAD (el fichero del árbol de trabajo; suite-integral exige árbol limpio,
#   así que == HEAD:versions.yaml).
# Es lo que verify_tag NO mira: aquel compara el tag consigo mismo; este lo
# compara con HEAD. Un tag rancio-pero-autoconsistente pasa verify_tag y muere
# aquí. Acumula en $status.
assert_tag_captures_head() {
  local tag=$1 m tag_gl head_gl head_pin
  for m in quark nucleus orbit; do
    tag_gl=$(git ls-tree "$tag" "$m" 2>/dev/null | awk '$2 == "commit" {print $3}')
    head_gl=$(git ls-tree HEAD "$m" 2>/dev/null | awk '$2 == "commit" {print $3}')
    head_pin=$(yaml_section "$manifest" workspace_pins "$m")
    if [[ -z "$tag_gl" || -z "$head_gl" || -z "$head_pin" ]]; then
      echo "FAIL: $tag — no se pudo leer gitlink de $m (tag='${tag_gl:0:8}' HEAD='${head_gl:0:8}' pin='$head_pin') para el assert de captura de HEAD" >&2
      status=1
    elif [[ "$tag_gl" != "$head_gl" ]]; then
      echo "FAIL: $tag — el gitlink de $m del tag (${tag_gl:0:8}) NO captura el de HEAD (${head_gl:0:8}) — el tag no apunta al set que HEAD certifica (QM7-3: tag rancio, aunque sea autoconsistente)" >&2
      status=1
    elif [[ "$head_gl" != "$head_pin"* ]]; then
      echo "FAIL: $tag — el gitlink de $m de HEAD (${head_gl:0:8}) no coincide con workspace_pins de HEAD ($head_pin) — HEAD no es autoconsistente" >&2
      status=1
    else
      echo "OK: $tag — captura el set de $m de HEAD (${head_gl:0:8} == pin $head_pin)"
    fi
  done
}

if git rev-parse -q --verify "refs/tags/v$current" >/dev/null; then
  echo "== tag de suite v$current (la versión que $manifest declara) =="
  verify_tag "v$current"

  # Assert 5 (B.1): ¿el tag captura el set de HEAD? Solo se EXIGE al certificar
  # (--cierre) o cuando el tag ES HEAD (el commit de certificación). Entre arcos
  # la lane semanal puede ver HEAD por delante del tag con el set drifteado —
  # legítimo, no fallo — así que fuera de esos casos NO se fuerza.
  tag_commit=$(git rev-parse -q --verify "refs/tags/v$current^{commit}" 2>/dev/null)
  head_commit=$(git rev-parse -q --verify HEAD 2>/dev/null)
  if [[ $certifying -eq 1 || ( -n "$tag_commit" && "$tag_commit" == "$head_commit" ) ]]; then
    if [[ $certifying -eq 1 ]]; then why="certificación"; else why="tag==HEAD"; fi
    echo "-- assert de captura ($why): el tag v$current debe apuntar al MISMO set que HEAD certifica"
    assert_tag_captures_head "v$current"
  else
    echo "nota: v$current tiene tag pero HEAD va por delante — la captura del set (assert 5) solo se EXIGE al certificar (--cierre/QUANTUM_CERTIFYING=1) o con tag==HEAD; la lane semanal lo tolera (HEAD>tag entre arcos es legítimo)."
  fi
else
  # Mid-tren: la versión actual aún no tiene tag.
  latest=$(git tag -l 'v*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
  if [[ -z "$latest" ]]; then
    echo "FAIL: no existe NINGÚN tag de suite v* — hay tag de suite desde v1.0.0; sin tags no hay estado certificado que verificar (¿faltó fetch --tags?)" >&2
    exit 1
  fi
  if [[ $certifying -eq 1 ]]; then
    # Certificar exige tag que exista y capture HEAD: el mid-tren es NO-PASA.
    echo "FAIL(certificación): v$current (la versión de $manifest) aún SIN tag de suite — certificar (--cierre/QUANTUM_CERTIFYING=1) exige que el tag EXISTA y capture HEAD. Corta el tag en HEAD antes de certificar. Último tag existente para contexto: $latest." >&2
    status=1
    echo "== (contexto) tag de suite $latest (último existente; v$current sin tag) =="
    verify_tag "$latest"
  else
    # Verifica el último existente contra su propio árbol (ver cabecera) y deja
    # el estado pre-tag a la vista. Legítimo en la lane semanal.
    echo "AVISO: v$current (la versión de $manifest) aún SIN tag — tren en marcha; se verifica el último tag existente ($latest) contra su propio árbol. El cierre de ronda exige este guard con el tag ya cortado (o --cierre, que lo hace FAIL)."
    echo "== tag de suite $latest (último existente; v$current pre-tag) =="
    verify_tag "$latest"
  fi
fi

if [[ $status -ne 0 ]]; then
  echo >&2
  echo "check_suite_tag: FALLO — el tag de suite no respalda lo que afirma (ver arriba)." >&2
  exit 1
fi
echo "check_suite_tag: OK"
