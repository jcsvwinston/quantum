#!/usr/bin/env bash
# check_why_quantum.sh — cada cifra de «Why Quantum» es la de su fuente, al pin.
#
# La página website/docs/why-quantum.md compara la suite con Gin+GORM, Echo,
# Django, Rails, Laravel y Spring Boot, y apoya lo que dice de la suite en
# cifras: bancos de producto, el tamaño del binario, el coste del quickstart,
# los módulos que instala `nucleus add`. Una página así es el sitio donde una
# cifra se queda vieja sin que nada se ponga rojo: la fuente se mueve en un
# submódulo, el set se re-pina, y la página sigue afirmando el número de
# antes con el enlace al de ahora al lado. Este guard es el gate W1 del arco
# A11 (control ST-02 del banco del sitio, tests/sitebench/sitebench.sh).
#
# Lo que comprueba, en el ÁRBOL PINADO:
#
#   1. cada AFIRMACIÓN de la tabla de abajo está en la página, con la cifra
#      que su fuente da hoy, y con el enlace a esa fuente en el MISMO párrafo
#      (o en la misma fila de tabla): una cifra sin su cita no se puede
#      comprobar al leer, aunque este guard sí la compruebe;
#   2. no queda en la prosa de la página NINGÚN número que no sea una de esas
#      afirmaciones —ni en cifras ni en palabras («six», «hundreds»)—: el
#      contrato es «toda cifra tiene fuente», y una cifra nueva entra
#      añadiendo su afirmación aquí, no escribiéndola y ya;
#   3. la frase de what-is-quantum.md que dice qué instala `nucleus add`
#      (la que sustituyó a «not breadth of plugins», ST-12) da el número de
#      módulos que el set certifica y que la tabla de `nucleus add` conoce al
#      pin; si esa tabla gana entradas que no son módulos (capacidades del
#      core que `add` cablea), la frase se queda corta y este guard lo dice;
#   4. sin superlativos de marketing en la página (la regla anti-hype de los
#      tres repos, docs/ESTILO_DOCS.md §5).
#
# Fuentes (todas al pin, salvo las del propio paraguas):
#
#   nucleus/docs/{api,auth,jobs}-bench.md          titulares y familias de banco
#   orbit/docs/admin-bench.md                      titular del banco del panel
#   quark/docs/{query,enterprise}-bench.md         titulares de los bancos de quark
#   quark/website/docs/reference/benchmarks.mdx    el banco de motores: el bloque de
#                                                  veredictos que escribe
#                                                  TestEngineBenchPage y el objetivo
#                                                  propuesto (la comparación con
#                                                  GORM de esa página está fechada
#                                                  y la página no la cita)
#   nucleus/website/docs/getting-started/installation.md   módulos y MB del starter
#   website/docs/quickstart.md                     sus comandos, contados con el
#                                                  parser que ejecuta la lane
#   versions.yaml (nucleus_modules) + el árbol     los módulos que `nucleus add`
#   + nucleus/internal/knownproviders/*.go         instala, y la tabla que lee
#
# Lo que NO comprueba: lo que la página dice de los OTROS frameworks. Nada en
# este árbol los mide, así que la página no les pone cifras (el punto 2 lo
# impide) y lo que dice de ellos es descripción, revisada a mano en el PR.
#
# Cuando falle tras un re-pin: la fuente se movió. Cambia la cifra de la
# página (y su prosa, si el cambio la desmiente) — no el patrón de aquí. El
# patrón se toca sólo si la FRASE de la página se reescribe.
#
# Uso: bash scripts/check_why_quantum.sh        (desde cualquier sitio)
# Compatibilidad: bash 3.2 (macOS); perl para las expresiones de la página.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

# shellcheck source=scripts/lib/quickstart-fences.sh
source scripts/lib/quickstart-fences.sh
# shellcheck source=scripts/lib/manifest-modules.sh
source scripts/lib/manifest-modules.sh

PAGE=website/docs/why-quantum.md
INTRO=website/docs/what-is-quantum.md
QUICKSTART=website/docs/quickstart.md
API_BENCH=nucleus/docs/api-bench.md
AUTH_BENCH=nucleus/docs/auth-bench.md
JOBS_BENCH=nucleus/docs/jobs-bench.md
ADMIN_BENCH=orbit/docs/admin-bench.md
QUERY_BENCH=quark/docs/query-bench.md
ENTERPRISE_BENCH=quark/docs/enterprise-bench.md
ENGINE_BENCH=quark/website/docs/reference/benchmarks.mdx
INSTALL=nucleus/website/docs/getting-started/installation.md
ADD_TABLE_DIR=nucleus/internal/knownproviders

# Enlaces que la página usa como cita de cada fuente (lo que el lector pulsa).
GH=https://github.com/jcsvwinston
L_API="$GH/nucleus/blob/main/docs/api-bench.md"
L_AUTH="$GH/nucleus/blob/main/docs/auth-bench.md"
L_JOBS="$GH/nucleus/blob/main/docs/jobs-bench.md"
L_ADMIN="$GH/orbit/blob/main/docs/admin-bench.md"
L_QUERY="$GH/quark/blob/main/docs/query-bench.md"
L_ENTERPRISE="$GH/quark/blob/main/docs/enterprise-bench.md"
L_ENGINE="/quark/reference/benchmarks/"
L_INSTALL="/nucleus/getting-started/installation/"
L_QUICKSTART="quickstart.md"
L_SET="$GH/quantum/blob/main/versions.yaml"
L_WHY="why-quantum.md"

fail=0
report() { echo "FAIL: why-quantum — $1" >&2; fail=1; }

for f in "$PAGE" "$INTRO" "$QUICKSTART" "$API_BENCH" "$AUTH_BENCH" "$JOBS_BENCH" \
         "$ADMIN_BENCH" "$QUERY_BENCH" "$ENTERPRISE_BENCH" "$ENGINE_BENCH" "$INSTALL"; do
  [[ -f "$f" ]] || report "falta $f — sin la página o sin su fuente no hay nada que comparar (¿submódulos sin inicializar?)"
done
add_files=""
for f in "$ADD_TABLE_DIR"/*.go; do
  [[ -f "$f" && "$f" != *_test.go ]] && add_files+="$f "
done
[[ -n "$add_files" ]] || report "falta $ADD_TABLE_DIR/*.go — la tabla que lee \`nucleus add\` al pin"
[[ $fail -eq 0 ]] || exit 1

# ---- fuentes: cada función imprime la cifra tal como la página debe escribirla

# «N of M» del titular «**N of M controls present» (el primero: admin-bench
# tiene un segundo titular para su mitad de navegador).
bench_headline() { grep -oE '\*\*[0-9]+ of [0-9]+ controls present' "$1" | head -1 | grep -oE '[0-9]+ of [0-9]+'; }
# El número de «N partial.» o «N absent.» en la línea de ese titular.
bench_count() { grep -E '^\*\*[0-9]+ of [0-9]+ controls present' "$1" | head -1 | grep -oE "[0-9]+ $2" | grep -oE '^[0-9]+'; }
# «present of total» de la fila de una familia en la tabla por familias.
bench_family() {
  awk -F'|' -v fam="$2" '
    { f = $2; gsub(/^ +| +$/, "", f) }
    f == fam && $3 ~ /^ *[0-9]+ *$/ && $4 ~ /^ *[0-9]+ *$/ && $5 ~ /^ *[0-9]+ *$/ {
      p = $3 + 0; pa = $4 + 0; a = $5 + 0; print p " of " (p + pa + a); exit
    }' "$1"
}
# El banco de motores de quark, del bloque que escribe TestEngineBenchPage
# (entre engine-bench:begin y engine-bench:end): una celda de la fila de un
# control, por el nombre de su columna, con «;» donde la tabla pone «·»
# entre baselines y sin espacios.
engine_cell() {
  awk -F'|' -v id="$1" -v col="$2" '
    /engine-bench:begin/ { on = 1; next }
    /engine-bench:end/   { on = 0 }
    on && !c && /^\| *control *\|/ {
      for (i = 2; i < NF; i++) { h = $i; gsub(/^ +| +$/, "", h); if (h == col) c = i }
      next
    }
    on && c {
      k = $2; gsub(/[ `]/, "", k)
      if (k == id) { print $c; exit }
    }' "$ENGINE_BENCH" | perl -CSD -ne 'chomp; s/[\s`]+//g; s/\x{b7}/;/g; print "$_\n"'
}
# «presentes of controles» del mismo bloque.
engine_present() {
  awk -F'|' '
    /engine-bench:begin/ { on = 1; next }
    /engine-bench:end/   { on = 0 }
    on && $2 ~ /^ *`[A-Z]+-[0-9]+` *$/ { n++; if ($0 ~ /\*\*present\*\*/) p++ }
    END { if (n) print (p + 0) " of " n }' "$ENGINE_BENCH"
}
# El objetivo propuesto: «… stays at or under **1.15** …».
engine_target() {
  perl -0777 -ne 's/\s+/ /g; print "$1\n" if /stays at or under \*\*([0-9.]+)\*\*/' "$ENGINE_BENCH"
}
# «módulos;MB;MB stripped» del párrafo del starter con el driver de SQLite.
install_figures() {
  perl -0777 -ne 's/\s+/ /g; if (/resolves (\d+) modules and links to a (\d+) MB binary \((\d+) MB stripped\)/) { print "$1;$2;$3\n" }' "$INSTALL"
}

E_API=$(bench_headline "$API_BENCH")
E_API_OA=$(bench_family "$API_BENCH" openapi)
E_AUTH=$(bench_headline "$AUTH_BENCH")
E_JOBS=$(bench_headline "$JOBS_BENCH")
E_ADMIN=$(bench_headline "$ADMIN_BENCH")
E_QUERY="$(grep -oE '^\*\*[0-9]+ of [0-9]+ typed' "$QUERY_BENCH" | head -1 | grep -oE '[0-9]+ of [0-9]+');$(grep -oE '^\*\*[0-9]+ of [0-9]+ typed\. [0-9]+ emit the wrong SQL' "$QUERY_BENCH" | head -1 | grep -oE '[0-9]+ emit' | grep -oE '[0-9]+')"
E_ENTERPRISE="$(bench_headline "$ENTERPRISE_BENCH");$(bench_count "$ENTERPRISE_BENCH" partial);$(bench_count "$ENTERPRISE_BENCH" absent)"
E_INSERT=$(engine_cell PG-01 'recorded ratio')
E_READ=$(engine_cell PG-02 'recorded ratio')
E_TARGET=$(engine_target)
E_ENGINE=$(engine_present)
# La frase dice qué baseline es cada cifra («`database/sql` … pgx»): si la
# fila cambia de baselines o de orden, la cifra seguiría casando con la
# fila y diría otra cosa.
for pk in PG-01 PG-02; do
  against=$(engine_cell "$pk" 'judged against')
  [[ "$against" == 'database/sql;pgx' ]] || report "[engine] $pk se juzga contra «$against» en $ENGINE_BENCH y la página dice «\`database/sql\` … pgx» en ese orden: reescribe la frase"
done
E_INSTALL=$(install_figures)
E_QUICKSTART=$(qs_commands "$QUICKSTART" | grep -c .)

# ---- el catálogo de `nucleus add` al pin -----------------------------------
# Los módulos hermanos de nucleus que el set certifica, clasificados por su
# directorio en el árbol pinado; cada uno tiene que estar en la tabla que lee
# `nucleus add`, y la tabla no puede tener módulos que el set no certifica.
n_mod=0; n_drv=0; n_exp=0; n_sto=0; n_ldap=0; n_sec=0
set_dirs=""
for key in $(mm_keys nucleus_modules); do
  dir=$(mm_path_for_key nucleus "$key") || { report "[catalog] la clave $key de nucleus_modules es ambigua en el árbol"; continue; }
  if [[ -z "$dir" ]]; then report "[catalog] versions.yaml certifica nucleus_modules.$key y el árbol pinado no tiene su go.mod"; continue; fi
  n_mod=$((n_mod + 1)); set_dirs+="$dir"$'\n'
  case "$dir" in
    drivers/*)           n_drv=$((n_drv + 1)) ;;
    exporters/*)         n_exp=$((n_exp + 1)) ;;
    providers/storage-*) n_sto=$((n_sto + 1)) ;;
    providers/ldap)      n_ldap=$((n_ldap + 1)) ;;
    providers/secrets-*) n_sec=$((n_sec + 1)) ;;
    *) report "[catalog] nucleus_modules.$key vive en $dir, una clase de módulo que la página no nombra: añádela a la frase y aquí" ;;
  esac
  # shellcheck disable=SC2086
  grep -qE "/${dir}\"" $add_files || report "[catalog] el set certifica $dir y la tabla de \`nucleus add\` al pin ($ADD_TABLE_DIR) no lo conoce: la página diría que lo instala"
done
# shellcheck disable=SC2086
table_dirs=$(grep -ohE '/(drivers|exporters|providers)/[a-z0-9-]+"' $add_files | sed 's|^/||; s|"$||' | sort -u)
for d in $table_dirs; do
  grep -qxF "$d" <<<"$set_dirs" || report "[catalog] la tabla de \`nucleus add\` al pin instala $d y el set no lo certifica (versions.yaml nucleus_modules)"
done
# Entradas que `add` cablea sin ser un módulo: el catálogo de A11 las añade
# (capacidades del core). Mientras la frase hable sólo de módulos, cada una
# la deja corta.
# shellcheck disable=SC2086
n_core=$(cat $add_files | grep -cE 'Ships:[[:space:]]*InCore' || true)
if [[ "${n_core:-0}" -gt 0 ]]; then
  report "[catalog] la tabla de \`nucleus add\` al pin cablea además $n_core capacidades del core que no son módulos: las frases de $PAGE y $INTRO cuentan sólo los $n_mod módulos y se quedan cortas — reescríbelas con lo que el catálogo publica"
fi
if [[ $n_ldap -ne 1 || $n_sec -ne 1 ]]; then
  report "[catalog] la página nombra UN backend LDAP y UN resolvedor de secretos; el set certifica $n_ldap y $n_sec"
fi

# ---- las afirmaciones: id | página | patrón (perl, una captura por cifra) | esperado | cita
# El patrón se aplica a la prosa de la página con los párrafos unidos en una
# línea y los espacios normalizados; las capturas, unidas por «;», tienen que
# ser el esperado. La cita tiene que estar en el mismo párrafo o fila.
WORK=$(mktemp -d "${TMPDIR:-/tmp}/why-quantum.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
CLAIMS="$WORK/claims.tsv"; WHY_PROSE="$WORK/why.txt"; INTRO_PROSE="$WORK/intro.txt"
: >"$CLAIMS"

claim() { printf '%s\t%s\t%s\t%s\t%s\n' "$@" >>"$CLAIMS"; }
claim quickstart why 'in \*\*(\d+)\*\* commands' "$E_QUICKSTART" "$L_QUICKSTART"
claim install why 'resolves \*\*(\d+)\*\* modules and links to a \*\*(\d+) MB\*\* binary, \*\*(\d+) MB\*\* stripped' "$E_INSTALL" "$L_INSTALL"
claim catalog-total why '`nucleus add` installs the \*\*(\d+)\*\* optional modules' "$n_mod" "$L_SET"
claim catalog-drivers why '\*\*(\d+)\*\* database drivers' "$n_drv" "$L_SET"
claim catalog-exporters why '\*\*(\d+)\*\* telemetry exporters' "$n_exp" "$L_SET"
claim catalog-storage why '\*\*(\d+)\*\* object-storage providers' "$n_sto" "$L_SET"
claim catalog-intro intro '`nucleus add` installs the (\d+) optional modules' "$n_mod" "$L_WHY"
claim admin-bench why 'Its bench: \*\*(\d+ of \d+)\*\* controls present' "$E_ADMIN" "$L_ADMIN"
claim query-bench why '\*\*(\d+ of \d+)\*\* are expressed with the typed API, and \*\*(\d+)\*\* run' "$E_QUERY" "$L_QUERY"
claim enterprise-bench why 'enterprise bench has \*\*(\d+ of \d+)\*\* controls present, \*\*(\d+)\*\* partial and \*\*(\d+)\*\* absent' "$E_ENTERPRISE" "$L_ENTERPRISE"
claim engine-insert why 'a single-row insert takes \*\*([\d.]+)\*\* times as long as through `database/sql` and \*\*([\d.]+)\*\* times as long as through pgx' "$E_INSERT" "$L_ENGINE"
claim engine-read why 'a read by primary key \*\*([\d.]+)\*\* and \*\*([\d.]+)\*\* times' "$E_READ" "$L_ENGINE"
claim engine-target why 'a target of at most \*\*([\d.]+)\*\* times each baseline' "$E_TARGET" "$L_ENGINE"
claim engine-verdicts why '\*\*(\d+ of \d+)\*\* of its controls meet it' "$E_ENGINE" "$L_ENGINE"
claim api-bench why 'OpenAPI document has \*\*(\d+ of \d+)\*\* controls present' "$E_API" "$L_API"
claim api-bench-openapi why 'OpenAPI family: \*\*(\d+ of \d+)\*\* present' "$E_API_OA" "$L_API"
claim auth-bench why 'Its auth bench: \*\*(\d+ of \d+)\*\* controls present' "$E_AUTH" "$L_AUTH"
claim jobs-bench why 'Its jobs bench: \*\*(\d+ of \d+)\*\* controls present' "$E_JOBS" "$L_JOBS"

# Una fuente que no da cifra (formato cambiado) no puede compararse con nada:
# se dice, en vez de comparar la página con una cadena vacía.
while IFS=$'\t' read -r id _page _re want _link; do
  case "$want" in ''|*';;'*|';'*|*';') report "[$id] su fuente no da cifra (¿cambió el formato del fichero fuente?) — no hay contra qué comparar la página" ;; esac
done <"$CLAIMS"

# prose <página> — el cuerpo sin front matter ni fences, un párrafo, ítem de
# lista o fila de tabla por línea, espacios normalizados.
prose() {
  qs_body "$1" | qs_strip_fences | awk '
    function flush() { if (buf != "") print buf; buf = "" }
    /^[[:space:]]*$/                        { flush(); next }
    /^[[:space:]]*\|/ || /^#/ || /^:::/      { flush(); print; next }
    /^[[:space:]]*([-*]|[0-9]+\.)[[:space:]]/ { flush(); buf = $0; next }
    { buf = (buf == "" ? $0 : buf " " $0) }
    END { flush() }
  ' | sed -E 's/[[:space:]]+/ /g; s/^ //'
}
prose "$PAGE" >"$WHY_PROSE"
prose "$INTRO" >"$INTRO_PROSE"

out=$(CLAIMS="$CLAIMS" WHY_TXT="$WHY_PROSE" INTRO_TXT="$INTRO_PROSE" WHY_PAGE="$PAGE" INTRO_PAGE="$INTRO" perl -CSD -e '
  use strict; use warnings; use utf8;
  sub slurp { my ($f) = @_; open(my $h, "<:encoding(UTF-8)", $f) or die "$f: $!"; my @l = <$h>; chomp @l; return \@l; }
  my %text = (why => slurp($ENV{WHY_TXT}), intro => slurp($ENV{INTRO_TXT}));
  my %label = (why => $ENV{WHY_PAGE}, intro => $ENV{INTRO_PAGE});
  my @mask;   # spans [línea, inicio, fin] de la página why que son cifras con fuente
  open(my $c, "<:encoding(UTF-8)", $ENV{CLAIMS}) or die;
  while (my $row = <$c>) {
    chomp $row;
    my ($id, $page, $re, $want, $link) = split /\t/, $row, -1;
    my $lines = $text{$page};
    my $hits = 0;
    for my $n (0 .. $#$lines) {
      my $line = $lines->[$n];
      while ($line =~ /$re/g) {
        $hits++;
        my @got;
        for my $i (1 .. $#-) {
          next unless defined $-[$i];
          push @got, substr($line, $-[$i], $+[$i] - $-[$i]);
          push @mask, [$n, $-[$i], $+[$i]] if $page eq "why";
        }
        my $got = join(";", @got);
        if ($got ne $want) {
          print "FAIL [$id] $label{$page} dice «$got» y su fuente dice «$want»\n";
        }
        if (index($line, $link) < 0) {
          print "FAIL [$id] la cifra «$got» de $label{$page} no cita su fuente ($link) en el mismo párrafo\n";
        }
      }
    }
    if (!$hits) {
      print "FAIL [$id] no encuentro en $label{$page} la frase de esta cifra (/$re/): si se reescribió, actualiza el patrón en el guard; si se quitó, quita la afirmación\n";
    }
  }
  # Completitud: ningún número en la prosa de la página que no sea una cifra con fuente.
  my @why = @{ $text{why} };
  for my $m (@mask) {
    my ($n, $s, $e) = @$m;
    substr($why[$n], $s, $e - $s) = "\x{a7}" x ($e - $s);
  }
  my $words = qr/\b(two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|hundreds?|thousands?|millions?|dozens?)\b/i;
  for my $line (@why) {
    (my $t = $line) =~ s/\]\([^)]*\)/]/g;   # los destinos de los enlaces no son prosa
    while ($t =~ /(?<![\w.\x{a7}])(\d[\d,]*(?:\.\d+)?)(?![\w\x{a7}])/g) {
      my $ctx = substr($t, ($-[0] > 40 ? $-[0] - 40 : 0), 80);
      print "FAIL [sin-fuente] $label{why}: cifra sin fuente «$1» en «…$ctx…» — cítala y añade su afirmación al guard, o quítala\n";
    }
    while ($t =~ /$words/g) {
      my $ctx = substr($t, ($-[0] > 40 ? $-[0] - 40 : 0), 80);
      print "FAIL [sin-fuente] $label{why}: cifra en palabras «$1» en «…$ctx…» — una cuenta en palabras también es una cifra: escríbela con su fuente, o quítala\n";
    }
  }
')
if [[ -n "$out" ]]; then
  while IFS= read -r l; do report "${l#FAIL }"; done <<<"$out"
fi

# Sin superlativos de marketing (docs/ESTILO_DOCS.md §5).
hype=$(grep -noiE 'production-ready|enterprise-grade|battle-tested|blazing|best-in-class|world-class|fastest|cutting-edge|revolutionary|game-chang|seamless' "$PAGE" || true)
[[ -z "$hype" ]] || report "superlativos de marketing en $PAGE: $(tr '\n' ' ' <<<"$hype")"

if [[ $fail -ne 0 ]]; then
  echo "why-quantum: la página dice algo que su fuente al pin no dice. Corrige la PÁGINA (la fuente manda); el patrón del guard sólo cambia si cambia la frase." >&2
  exit 1
fi
n_claims=$(grep -c . "$CLAIMS")
echo "OK: why-quantum — $n_claims afirmaciones con cifra, cada una igual a su fuente al pin y citada en su párrafo; ningún número sin fuente en $PAGE; \`nucleus add\` instala $n_mod módulos ($n_drv drivers, $n_exp exportadores, $n_sto de storage, LDAP y secretos) y $INTRO lo dice"
