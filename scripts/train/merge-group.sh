#!/usr/bin/env bash
# merge-group.sh <repo> <método> <pr>... — fusiona en serie: update-branch si BEHIND, espera checks, merge.
set -uo pipefail
TMPBODY=$(mktemp); trap 'rm -f "$TMPBODY"' EXIT
repo=$1; method=$2; shift 2
for n in "$@"; do
  echo "== $repo#$n"
  for attempt in 1 2 3; do
    st=$(gh pr view "$n" -R "jcsvwinston/$repo" --json mergeStateStatus --jq .mergeStateStatus)
    if [ "$st" = "BEHIND" ]; then
      echo "  BEHIND → update-branch"; gh pr update-branch "$n" -R "jcsvwinston/$repo" >/dev/null 2>&1 || true; sleep 45
    fi
    until s=$(gh pr checks "$n" -R "jcsvwinston/$repo" 2>/dev/null | awk -F'\t' '{print $2}' | sort | uniq -c | tr '\n' ' '); [ -n "$s" ] && ! echo "$s" | grep -q pending; do sleep 30; done
    echo "  checks: $s"
    if echo "$s" | grep -q fail; then echo "  ROJO: no fusiono $repo#$n"; break; fi
    # Con --squash, el cuerpo del commit lo compone GitHub con la lista de
    # commits del PR, y ese cuerpo puede tirar el parser de release-please. Si
    # lo tira, el commit DESAPARECE: el log dice «commit could not be parsed» y
    # después «No user facing commits found … skipping», así que un feat o un
    # fix no corta release y no hay nada rojo que lo delate. Aquí el squash
    # lleva título = título del PR y un cuerpo controlado, con las dos formas
    # conocidas neutralizadas.
    #
    # FORMA 1, «Palabra: texto» al principio de línea. El parser la lee como
    # pie de página. Costó quark#355: release-please no vio el feat y propuso
    # un patch (1.11.1) con un minor ya en main.
    #
    # FORMA 2, una línea que EMPIEZA por un token seguido de paréntesis
    # ANIDADOS. release-please 17 no usa el parser laxo de conventional
    # commits, usa una gramática que revienta con
    # «unexpected token '(' … valid tokens [)]». Costó orbit#443: su fix quedó
    # sin publicar y orbit sin PR de release. Medido con release-please
    # 17.11.2 sobre ese cuerpo real:
    #
    #     `f(g(x))` es la llamada.    → ROMPE  (empieza por el token)
    #     f(g(x)) es la llamada.      → ROMPE  (los backticks dan igual)
    #      `f(g(x))` es la llamada.   → parsea (basta UN espacio delante)
    #     usa `f(g(x))` para leer.    → parsea (basta que algo la preceda)
    #     | a | `f(g(x))` |           → parsea (empieza por «|»)
    #
    # Por eso la segunda regla solo antepone un espacio. Sobre el cuerpo de
    # orbit#443 toca 2 líneas de 283 y lo deja parseando; verificado llamando
    # a parseConventionalCommits de release-please, no a ojo.
    extra=()
    if [ "$method" = "--squash" ]; then
      title=$(gh pr view "$n" -R "jcsvwinston/$repo" --json title --jq .title)
      body=$(gh pr view "$n" -R "jcsvwinston/$repo" --json body --jq .body \
        | sed -E 's/^([A-Za-z][A-Za-z -]*): /\1 — /' \
        | sed -E 's/^(`?[A-Za-z_][A-Za-z0-9_.-]*\()/ \1/' \
        | grep -v '^🤖 Generated with' )
      # El coautor sigue al modelo en uso, así que vive en una variable: al
      # cambiar de modelo se ajusta aquí (o por entorno) y no en la lógica.
      body=$(printf '%s\n\nCo-Authored-By: %s\n' "$body" "${TRAIN_CO_AUTHOR:-Claude Opus 5 <noreply@anthropic.com>}")
      printf '%s' "$body" > "$TMPBODY"
      extra=(--subject "$title (#$n)" --body-file "$TMPBODY")
    fi
    if gh pr merge "$n" -R "jcsvwinston/$repo" "$method" --delete-branch ${extra[@]+"${extra[@]}"} >/dev/null 2>&1; then
      echo "  FUSIONADO $repo#$n"; break
    else
      st=$(gh pr view "$n" -R "jcsvwinston/$repo" --json state,mergeStateStatus --jq '"\(.state) \(.mergeStateStatus)"'); echo "  merge falló (intento $attempt): $st"
      [ "${st%% *}" = "MERGED" ] && break
      sleep 20
    fi
  done
done
