#!/usr/bin/env bash
# guard-registry.sh — registro EXPLÍCITO de los guards de certificación de la
# suite (7ª ronda, certificación mecánica).
#
# Este fichero es la única fuente de verdad sobre QUÉ comprueba la certificación
# mecánica: cada entrada es un guard ejecutable con su directorio de trabajo y
# su comando exacto. Lo comparten dos consumidores:
#
#   - scripts/suite-integral.sh   — ejecuta TODOS los guards al pin actual
#                                   (la lane de certificación).
#   - scripts/guard-of-guards.sh  — ejecuta cada guard contra una fixture de
#                                   fallo y exige EXIT!=0 (prueba que el guard
#                                   sigue mordiendo).
#
# Reglas del registro:
#   1. Cada guard nuevo se registra aquí Y recibe una fixture en
#      tests/guard-fixtures/<nombre>/fixture.sh. guard-of-guards falla si
#      falta cualquiera de las dos cosas.
#   2. La aserción anti-fósil (guard_registry_selfcheck) recorre los
#      directorios de scripts de los 4 repos y falla si encuentra un script
#      de guard NO registrado: cuando un producto añade un guard y el
#      paraguas re-pina, la lane se pone roja hasta registrarlo. Un guard que
#      existe pero no se ejecuta es un fósil — la clase de deriva que esta
#      ronda cierra.
#
# Los guards de producto corren AL PIN (el submódulo tal y como lo fija
# versions.yaml). Un fallo con el árbol pinado significa que el set NO es
# certificable — exactamente la semántica de la auditoría manual que esta lane
# mecaniza.
#
# Compatibilidad: bash 3.2 (macOS) — sin arrays asociativos, sin mapfile.

# Formato de entrada: "nombre|directorio|comando"
#   nombre     — id estable del guard; nombra también su fixture.
#   directorio — cwd relativo a la raíz del paraguas donde se lanza el comando
#                ("." = paraguas; nucleus/quark/orbit = el submódulo al pin).
#   comando    — invocación EXACTA, la misma que usa el CI del repo dueño.
GUARDS=(
  # --- paraguas -------------------------------------------------------------
  # pin ↔ tag ↔ gitlink + tags de módulo de orbit + disclosure de lags (§1-§5).
  "umbrella-manifest-guard|.|bash scripts/manifest-guard.sh"
  # Jerga interna en el HTML SERVIDO (QM5-1 + IDs de hallazgo, 7ª ronda).
  # Requiere website/build construido — suite-integral construye el sitio antes.
  "umbrella-served-jargon|.|bash scripts/check_served_jargon.sh website/build"
  # Sidebars espejadas sincronizadas con el sidebar del submódulo pinado (QM7-4).
  "umbrella-sidebar-sync|.|bash scripts/check_sidebar_sync.sh"
  # El tag de suite respalda lo que afirma: existe, su versions.yaml declara la
  # versión del tag y los gitlinks del tag == workspace_pins del tag (QM8-6).
  # Mid-tren (versión nueva sin tag) verifica el último tag existente contra su
  # propio árbol, con AVISO — ver cabecera del script y AUDITORIA_CONTINUA.md.
  "umbrella-suite-tag|.|bash scripts/check_suite_tag.sh"

  # --- nucleus (al pin) -----------------------------------------------------
  # Marcadores x-release-please-version + directivas Go del scaffold + coherencia
  # de estados README↔inventario (NU-P0-2, NU5-3, NU-1).
  "nucleus-version-claims|nucleus|bash scripts/ci/check_version_claims.sh"
  # Vocabulario interno fuera de website/docs.
  "nucleus-product-voice|nucleus|bash scripts/ci/check_docs_product_voice.sh"
  # Freeze de contratos estables (baselines sin removals + firewall).
  "nucleus-contract-freeze|nucleus|bash scripts/ci/check_contract_freeze.sh"
  # Drift de la web pública: tokens legacy, covers: colgantes, bodycheck (§9).
  "nucleus-docs-coverage|nucleus|bash scripts/website/check-coverage.sh --strict"
  # Fact-check del CUERPO de las páginas (versión de Go, símbolos, tags db:).
  # -strict: sin él, el binario avisa pero sale 0 — no sería un guard.
  "nucleus-bodycheck|nucleus|go run ./scripts/website/bodycheck -strict"
  # --- quark (al pin) -------------------------------------------------------
  # La versión del manifiesto mencionada en README/SECURITY/CLAUDE/release-notes
  # + roadmap sin versiones hardcodeadas (H-Q6, QK6-5).
  "quark-version-coherence|quark|bash scripts/check-version-coherence.sh"
  # Vocabulario interno fuera de website/docs.
  "quark-product-voice|quark|bash scripts/ci/check_docs_product_voice.sh"
  # Anti-marketing, fugas RELEASE_NOTES_V1 y enlaces relativos rotos (F0-10).
  "quark-lint-docs|quark|bash scripts/lint-docs.sh"

  # --- orbit (al pin) -------------------------------------------------------
  # Vocabulario interno (incluye la regla de IDs de hallazgo) fuera de website/docs.
  "orbit-product-voice|orbit|bash scripts/ci/check_docs_product_voice.sh"
  # Marcadores x-release-please-version contra la versión publicada (QM5-3).
  "orbit-docs-version-claims|orbit|bash scripts/ci/check_docs_version_claims.sh"
  # Pins entre módulos hermanos == último tag publicado (OR5-1). OJO: consulta
  # `git tag` — necesita los tags fetcheados en el submódulo (y por tanto red
  # la primera vez). Si la ronda en curso ya cortó tags nuevos de orbit en el
  # remoto, este guard se pone rojo AL PIN: eso es información de certificación
  # (el set pinado quedó atrás), no ruido. Ver docs/AUDITORIA_CONTINUA.md.
  "orbit-internal-pins|orbit|bash scripts/ci/check_internal_pins.sh"
)

# ---------------------------------------------------------------------------
# API de consulta (iteración simple; bash 3.2).
# ---------------------------------------------------------------------------

# guard_names — un nombre por línea, en orden de registro.
guard_names() {
  local g
  for g in "${GUARDS[@]}"; do
    printf '%s\n' "${g%%|*}"
  done
}

# guard_field <nombre> <2|3> — campo del guard (2=directorio, 3=comando).
guard_field() {
  local name=$1 idx=$2 g
  for g in "${GUARDS[@]}"; do
    if [[ "${g%%|*}" == "$name" ]]; then
      printf '%s\n' "$g" | cut -d'|' -f"$idx"
      return 0
    fi
  done
  return 1
}

guard_dir() { guard_field "$1" 2; }
guard_cmd() { guard_field "$1" 3; }

# ---------------------------------------------------------------------------
# Aserción anti-fósil: ningún script de guard sin registrar.
# ---------------------------------------------------------------------------
# Directorios que se escanean por repo: scripts/, scripts/ci/ y
# scripts/website/ — donde viven los guards hoy en los 4 repos. scripts/dev/
# y scripts/release/ quedan fuera del escaneo a propósito: son utillaje
# operacional (labs locales, informes de release), no checks de CI.
#
# Exclusiones EXPLÍCITAS dentro de los directorios escaneados — scripts que no
# son guards de certificación. Cada entrada lleva su porqué; añadir aquí sin
# razón es fabricar un fósil con permiso.
GUARD_SCAN_EXCLUDE=(
  # Los ORQUESTADORES de esta certificación: ejecutan guards, no lo son.
  # Registrarlos crearía recursión (la lane lanzándose a sí misma).
  "scripts/suite-integral.sh"
  "scripts/guard-of-guards.sh"
  # Utillaje de CONSUMO del manifiesto (DX-25): imprime el bloque require
  # pegable desde versions.yaml. No certifica nada — genera texto para el
  # usuario; su corrección la cubre la verificación de las 9 versiones que
  # manifest-guard hace sobre el mismo fichero.
  "scripts/print-requires.sh"
  # Utillaje de NOTIFICACIÓN de los workflows programados (QM8-1): abre o
  # actualiza el issue del schedule rojo vía gh. No certifica nada del árbol —
  # avisa de que la certificación falló; registrarlo como guard sería circular.
  "scripts/notify_schedule_failure.sh"
  # GENERADOR de nucleus (produce la referencia de config de la web), no un
  # check: no tiene veredicto sobre el árbol — emite ficheros. Su salida la
  # vigilan los guards de docs de nucleus (coverage/bodycheck). Exclusión del
  # escaneo de guards Go (QM8-7).
  "nucleus/scripts/website/gen-config-reference"
  # Setup one-shot de protección de ramas vía gh api; requiere permisos de
  # admin del repo. Se ejecuta una vez a mano, no certifica nada del árbol.
  "nucleus/scripts/ci/configure_branch_protection.sh"
  # Arneses PESADOS del CI del producto (compat multi-versión / estabilidad
  # exploratoria): son lanes de test del producto, con sus propios jobs en el
  # CI de nucleus — no guards de certificación del set que el paraguas repita.
  "nucleus/scripts/ci/run_compatibility_harness.sh"
  "nucleus/scripts/ci/run_exploratory_stability.sh"
  # Arnés de EJECUCIÓN del showcase (compila la app de ejemplo, la arranca y
  # aserta por HTTP): lane requerida del CI de nucleus, misma familia run_*
  # que los dos anteriores — no un check estático que el paraguas repita.
  # Entró al set con nucleus v1.4.0.
  "nucleus/scripts/ci/run_showcase_smoke.sh"
  # Helper PARAMETRIZADO del CI de nucleus (MAQ-5/NU7-4): aserta vía
  # `go test -list` que cada rama de un filtro `-run` sigue seleccionando su
  # test (caza el false-green de un -run que ya no casa nada tras renombrar).
  # NO es un guard de certificación del set que el paraguas repita: (1) exige
  # argumentos <pkg> <run-regex> — sin ellos es un error de uso, no un check
  # con veredicto propio; (2) esos regex son los filtros de las lanes de test
  # de nucleus y viven en su workflow de CI, no aquí — registrarlo obligaría al
  # paraguas a duplicar y fosilizar la lista de nombres de test de nucleus; (3)
  # protege la integridad de las lanes de nucleus, que el CI de nucleus ejerce
  # en cada corrida con los args reales. Entró al set con nucleus v1.6.0
  # (Arco de endurecimiento #1). Ver docs/AUDITORIA_CONTINUA.md §4.
  "nucleus/scripts/ci/assert_run_selects.sh"
  # Guard-RECORDATORIO del CI de nucleus, NO de coherencia del set: compara
  # los pins de examples/ contra los tags remotos EN VIVO (git ls-remote).
  # Al pin quedará rojo de forma ESTRUCTURAL tras cada tren — nucleus taggea
  # antes que orbit por orden de dependencias, así que el ejemplo dentro del
  # tag de nucleus siempre apunta al orbit del momento del corte, no al
  # recién taggeado. Ese rojo pertenece a MAIN de nucleus (donde su CI fuerza
  # el chore de re-pin post-tren, como hizo en la 7ª), no al set certificado
  # que esta lane valida. Probado en la certificación 1.8.0: registrado aquí
  # salía rojo con el set correcto. Ver docs/AUDITORIA_CONTINUA.md §4.
  "nucleus/scripts/ci/check_example_pins.sh"
)

# guard_registry_selfcheck — EXIT!=0 si algún script escaneado no está ni
# registrado (por su ruta exacta dentro de un comando del registro) ni
# excluido. Debe ejecutarse desde la raíz del paraguas.
#
# QM8-7: el escaneo cubre también los guards NO-shell — programas Go bajo los
# mismos directorios (un subdirectorio con main.go, el patrón de bodycheck,
# que entró al registro por lista manual porque el escaneo solo veía *.sh).
# Un guard Go se reconoce registrado por el token de ruta tras `go run` en el
# comando del registro; lo que no es guard (generadores) se excluye con porqué.
guard_registry_selfcheck() {
  local st=0 repo dir f d rel full registered registered_go g cmd gdir tok

  # Rutas registradas, formato repo-relativo: "repo/ruta/al/script.sh" (primer
  # token *.sh del comando) y "repo/ruta/al/paquete" (token tras `go run`).
  registered=""
  registered_go=""
  for g in "${GUARDS[@]}"; do
    gdir=$(printf '%s\n' "$g" | cut -d'|' -f2)
    cmd=$(printf '%s\n' "$g" | cut -d'|' -f3)
    for tok in $cmd; do
      case "$tok" in
        *.sh)
          if [[ "$gdir" == "." ]]; then
            registered+="$tok"$'\n'
          else
            registered+="$gdir/$tok"$'\n'
          fi
          break
          ;;
      esac
    done
    tok=$(printf '%s\n' "$cmd" | sed -n 's/.*go run \([^ ]*\).*/\1/p')
    if [[ -n "$tok" ]]; then
      tok="${tok#./}"
      if [[ "$gdir" == "." ]]; then
        registered_go+="$tok"$'\n'
      else
        registered_go+="$gdir/$tok"$'\n'
      fi
    fi
  done

  for repo in . nucleus quark orbit; do
    for dir in scripts scripts/ci scripts/website; do
      [[ -d "$repo/$dir" ]] || continue
      for f in "$repo/$dir"/*.sh; do
        [[ -e "$f" ]] || continue
        # Normaliza "./scripts/x.sh" → "scripts/x.sh".
        full="${f#./}"
        rel="$full"
        # ¿Registrado?
        if grep -qxF "$rel" <<<"$registered"; then
          continue
        fi
        # ¿Excluido explícitamente?
        local excluded=0 e
        for e in ${GUARD_SCAN_EXCLUDE[@]+"${GUARD_SCAN_EXCLUDE[@]}"}; do
          if [[ "$rel" == "$e" ]]; then excluded=1; break; fi
        done
        [[ $excluded -eq 1 ]] && continue
        echo "FAIL: guard sin registrar: $rel — regístralo en scripts/lib/guard-registry.sh (y dale fixture en tests/guard-fixtures/<nombre>/) o añádelo a GUARD_SCAN_EXCLUDE con su porqué" >&2
        st=1
      done
      # Guards Go (QM8-7): subdirectorio con main.go bajo el directorio
      # escaneado. Misma regla que los .sh: registrado o excluido con porqué.
      for d in "$repo/$dir"/*/; do
        [[ -d "$d" && -e "${d}main.go" ]] || continue
        full="${d%/}"
        rel="${full#./}"
        if grep -qxF "$rel" <<<"$registered_go"; then
          continue
        fi
        local excluded_go=0 eg
        for eg in ${GUARD_SCAN_EXCLUDE[@]+"${GUARD_SCAN_EXCLUDE[@]}"}; do
          if [[ "$rel" == "$eg" ]]; then excluded_go=1; break; fi
        done
        [[ $excluded_go -eq 1 ]] && continue
        echo "FAIL: guard (Go) sin registrar: $rel — regístralo en scripts/lib/guard-registry.sh (comando \`go run\`, y dale fixture en tests/guard-fixtures/<nombre>/) o añádelo a GUARD_SCAN_EXCLUDE con su porqué" >&2
        st=1
      done
    done
  done

  if [[ $st -eq 0 ]]; then
    echo "OK: registro de guards completo — ningún script de guard (shell o Go) sin registrar en los 4 repos"
  fi
  return $st
}
