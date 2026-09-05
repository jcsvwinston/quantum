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
  # Contabilidad de los hallazgos de la auditoría de madurez 2026-09-03: cada
  # id de los informes tiene fila, cada fila abierta tiene arco, y un arco
  # declarado cerrado no deja hallazgos abiertos (gate de A1 del plan 5/5).
  "umbrella-audit-backlog|.|bash scripts/check_audit_backlog.sh"
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
  # Los enlaces del sitio CONSTRUIDO resuelven: los `<a href>` a nuestros repos
  # se verifican contra el checkout local (sin red, sin 429) y los internos
  # contra el HTML generado. Docusaurus no mira los externos — así vivieron
  # meses los «Edit this page» rotos de las tres instancias.
  "umbrella-built-links|.|bash scripts/check_built_links.sh website/build"
  # Bloques de código VACÍOS en el HTML servido (SD-01, 9ª ronda): una fence
  # ```lang file=…``` sin resolver (remark-code-import descableado en el
  # ensamblaje) se publica como <code></code> y el build sale verde — así salió
  # el quickstart de nucleus con sus 3 bloques vacíos en las 13 versiones.
  # Requiere website/build construido — suite-integral construye el sitio antes.
  "umbrella-built-codeblocks|.|bash scripts/check_built_codeblocks.sh website/build"
  # Los 7 repros "exit 0 sin efecto" del informe DX (§4.A) contra el árbol AL
  # PIN: comandos que fracasaban con éxito aparente. Entra al set con Quantum
  # 1.12.0 — con pines anteriores (quark < v1.5.0, nucleus < v1.8.0) sale rojo
  # porque los tags no llevan los fixes: información de certificación, no ruido.
  "umbrella-exit0-regressions|.|bash scripts/check_exit0_regressions.sh"
  # La cabecera «Estado real» de docs/RUMBO.md nombra el set que versions.yaml
  # certifica (versión de suite y los tres pilares). En 1.26.0 se quedó un set
  # atrás mientras su propio §1 decía 1.26.0 (QM-6, auditoría 2026-09-03).
  "umbrella-rumbo-estado|.|bash scripts/check_rumbo_estado.sh"
  # El go.work cubre TODO módulo publicable: raíz de cada repo, todo go.mod del
  # árbol (salvo examples/benchmarks/bugbash) y toda clave de *_modules del
  # manifiesto. Iba diez módulos por detrás del set y `go build` con módulos de
  # menos sale con EXIT=0 (QM-7, auditoría 2026-09-03).
  "umbrella-gowork-covers-manifest|.|bash scripts/check_gowork_covers_manifest.sh"
  # Afirmaciones RETIRADAS («-tags mssql», «build tags», «single Go module»,
  # «Nine modules») en el HTML servido como vigente — hermano de served-jargon
  # (C8, auditoría 2026-09-03). Snapshots versionados y release notes fuera del
  # gate con porqué; excepción auto-expirante ligada al pin de nucleus ≤ v1.23.0.
  # Requiere website/build construido — suite-integral construye el sitio antes.
  "umbrella-retired-claims|.|bash scripts/check_retired_claims.sh website/build"

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
  # La documentación INTERNA (docs/**) no cita ficheros ausentes: enlaces
  # relativos y rutas entre comillas invertidas resuelven en el árbol. Los
  # registros históricos (adrs/, audits/, iterations/…) quedan fuera a
  # propósito — son actas, no manuales vivos. Entra al set con nucleus v1.11.0.
  "nucleus-docs-drift|nucleus|bash scripts/ci/check_internal_docs_drift.sh"
  # El archivo versionado del sitio no se queda atrás: el snapshot más reciente
  # no puede estar por debajo de la MINOR publicada (un patch no exige corte).
  # Entra al set con nucleus v1.11.0.
  "nucleus-docs-archive|nucleus|bash scripts/ci/check_docs_archive_freshness.sh"
  # Cada ADR del directorio está en el índice, y cada enlace del índice
  # resuelve. El índice se quedó en ADR-022 con veintinueve records: diecisiete
  # decisiones sólo alcanzables listando la carpeta. Entra al set con nucleus
  # v1.17.0.
  "nucleus-adr-index|nucleus|bash scripts/ci/check_adr_index.sh"
  "nucleus-pr-title-english|nucleus|bash scripts/ci/check_pr_title_english.sh \"${PR_TITLE:-}\""
  # La documentación VIVA de nucleus (README, SPEC, docs/ salvo actas,
  # website/docs salvo snapshots) no afirma lo retirado: build tags, «single
  # Go module», MountOpenAPI, sendgrid built-in. Hermano del retired-claims del
  # paraguas (que mira el HTML servido): éste caza la frase en la FUENTE, en el
  # repo del producto, antes de que el sitio la sirva. Entra al set con
  # nucleus v1.23.1 (auditoría de madurez 2026-09-03, NU-24/25/57/60, QM-4).
  "nucleus-retired-claims|nucleus|bash scripts/ci/check_retired_claims.sh"
  # Cada snapshot versionado del sitio anuncia SU propia versión. El snapshot
  # congela la doc antes de que release-please suba el marcador, así que cinco
  # salieron afirmando la versión anterior — y en la página que el sitio sirve
  # en la RAÍZ, porque el archivo más reciente es el que se sirve por defecto.
  # Sólo se ve desde fuera. Entra al set con nucleus v1.17.1: el guard se
  # fusionó DESPUÉS del tag v1.17.0, así que hasta este pin no existía.
  "nucleus-versioned-markers|nucleus|bash scripts/ci/check_versioned_docs_markers.sh"
  # --- quark (al pin) -------------------------------------------------------
  # La versión del manifiesto mencionada en README/SECURITY/CLAUDE/release-notes
  # + roadmap sin versiones hardcodeadas (H-Q6, QK6-5).
  "quark-version-coherence|quark|bash scripts/check-version-coherence.sh"
  # Mismo guard que en nucleus, y por el mismo defecto real: el snapshot de
  # 1.6.0 anunciaba «Quark is v1.5.2». Entra al set con quark v1.7.0.
  "quark-versioned-markers|quark|bash scripts/ci/check_versioned_docs_markers.sh"
  # Vocabulario interno fuera de website/docs.
  "quark-product-voice|quark|bash scripts/ci/check_docs_product_voice.sh"
  # Anti-marketing, fugas RELEASE_NOTES_V1 y enlaces relativos rotos (F0-10).
  "quark-lint-docs|quark|bash scripts/lint-docs.sh"
  # La documentación INTERNA (docs/**) no cita ficheros ausentes — mismo guard
  # que en nucleus, con la lista de directorios de primer nivel de este repo.
  # Entra al set con quark v1.6.0.
  "quark-docs-drift|quark|bash scripts/ci/check_internal_docs_drift.sh"
  # El archivo versionado del sitio cubre la minor publicada. Entra al set con
  # quark v1.6.0.
  "quark-docs-archive|quark|bash scripts/ci/check_docs_archive_freshness.sh"
  "quark-pr-title-english|quark|bash scripts/ci/check_pr_title_english.sh \"${PR_TITLE:-}\""

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
  # El archivo versionado del sitio cubre la minor publicada. Orbit versiona
  # desde v1.6.7 — antes servía siempre su doc actual, así que quien corría
  # una versión anterior leía la del set vigente. Entra al set con orbit
  # v1.6.8.
  "orbit-docs-archive|orbit|bash scripts/ci/check_docs_archive_freshness.sh"
  # Cada snapshot versionado anuncia SU propia versión — mismo guard que en
  # nucleus/quark, y por el mismo defecto real: los snapshots 1.7.0 y 1.8.0 de
  # orbit anunciaban «current release v1.6.7» y «v1.7.4», rancios en
  # producción. orbit-docs-version-claims sólo mira website/docs (el árbol
  # actual), no el archivo. Entra al set con orbit v1.8.11 (arco de deuda QCD).
  "orbit-versioned-markers|orbit|bash scripts/ci/check_versioned_docs_markers.sh"
  # El índice de ADRs de orbit cubre lo que el directorio contiene: un acta que
  # no aparece en él es una decisión que nadie encontrará. Gemelo del guard de
  # nucleus, portado cuando orbit ganó actas retroactivas de las decisiones ya
  # ejecutadas. Entra al set con orbit v1.8.14.
  "orbit-adr-index|orbit|bash scripts/ci/check_adr_index.sh"
  "orbit-pr-title-english|orbit|bash scripts/ci/check_pr_title_english.sh \"${PR_TITLE:-}\""
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
  # usuario; su corrección la cubre la verificación que manifest-guard hace
  # de todos los bloques del mismo fichero, más sus dos self-checks (cada
  # ruta emitida tiene go.mod en el submódulo; una línea por versión).
  "scripts/print-requires.sh"
  # Utillaje de LECTURA del go.work: imprime los patrones `./modulo/...` para
  # `go build`/`go vet` desde la raíz. Emite texto, no tiene veredicto; lo que
  # sí certifica la cobertura del go.work es check_gowork_covers_manifest.sh.
  "scripts/gowork-patterns.sh"
  # Utillaje de ESCRITURA del manifiesto (capa 1 de automatización de docs):
  # mueve los submódulos al tag y reescribe las 8 versiones, los pins y las
  # tablas del README. No certifica nada — PROPONE el re-pin; quien lo juzga
  # es manifest-guard, que corre después sobre lo que este script escribió.
  "scripts/bump-set.sh"
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
  # Arnés de EJECUCIÓN del ejemplo de referencia mvc_api (migra, arranca y
  # hace curl a /healthz y /notes): lane requerida del CI de nucleus desde
  # v1.23.1 (NU-55: el ejemplo canónico no arrancaba y CI sólo lo compilaba),
  # misma familia run_* que el showcase — no un check estático que el
  # paraguas repita.
  "nucleus/scripts/ci/run_mvc_api_smoke.sh"
  # Comprueba que cada módulo hermano compila SOLO (GOWORK=off go mod tidy
  # sin diff + build + vet) — lane requerida del CI de nucleus desde v1.23.1
  # (NU-1). Exige red (proxy de Go) y re-tidy de doce módulos: es la lane
  # standalone del producto, la misma que el paraguas ya cubre por su lado
  # con `go install …@tag` en caché virgen — no un guard estático del set.
  "nucleus/scripts/ci/check_modules_standalone.sh"
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
  # GENERADOR de orbit (DX-26): produce website/docs/reference/module-matrix.md
  # (la matriz de compatibilidad de los 6 módulos). No tiene veredicto propio —
  # emite un fichero; su frescura la exige el paso "module matrix freshness"
  # del CI de orbit (ci.yml, regenera y compara con git diff). Mismo precedente
  # que el gen-config-reference de nucleus. Entró al set con orbit v1.6.0.
  "orbit/scripts/ci/gen_module_matrix.sh"
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
  # SETUP de infraestructura del CI de quark (DX-2): levanta el contenedor de
  # Oracle y espera a que acepte conexiones, para que las lanes de Oracle no
  # dupliquen 40 líneas de YAML. No tiene veredicto sobre el árbol — prepara
  # una base de datos; lo que certifica son los tests que corren después.
  # Entra al set con quark v1.6.0.
  "quark/scripts/ci/oracle-up.sh"
  # GENERADOR de entorno para apps consumidoras (DX-24): traduce un .env
  # neutro a las dos gramáticas de configuración (QUARK_* viper / NUCLEUS_*
  # koanf). Emite exports, no tiene veredicto sobre el árbol — no es un guard.
  "scripts/quantum-env.sh"
  # Arnés PESADO de integración (DX-27): compila y ARRANCA showcase_demo en
  # modo workspace, crea por HTTP y verifica feed en vivo + Data Studio. Es
  # una lane de integration.yml (job showcase-smoke), misma familia que los
  # run_* de nucleus — no un check estático que la certificación repita.
  "scripts/ci/showcase_smoke.sh"
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
