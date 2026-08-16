#!/usr/bin/env bash
# check_exit0_regressions.sh — guard nº16: los 7 repros "exit 0 sin efecto"
# del informe DX (2026-08-16, §4.A) NO pueden volver a salir con éxito.
#
# La clase A del informe era la dominante: comandos y constructores que
# fracasaban en silencio (EXIT=0, WARN o nada) mientras el usuario creía que
# habían funcionado. Cada caso se cerró en su producto con test de regresión
# propio; este guard repite los 7 repros EXACTOS del informe contra el árbol
# AL PIN, porque la clase ya reapareció una vez "en sitios nuevos" y la
# defensa por producto no cubre el set certificado como conjunto.
#
#   A1  nucleus health --config <inexistente>      → debe fallar (y no crear nucleus.db)
#   A2  nucleus migrate --migrations <inexistente> → debe fallar (y NO crear el directorio)
#   A3  5 erratas de tag en un modelo quark        → RegisterModel debe fallar nombrándolas
#   A4  quark.New con opciones inválidas           → debe fallar nombrando tipo y posición
#   A5  quark.New con driver desconocido           → debe fallar (no fallback a postgres)
#   A6  nucleus health con clave 'prot:' en el yml → debe fallar con did-you-mean
#   A7  nucleus routes                             → debe declarar que solo lista rutas del framework
#
# Entra al set con Quantum 1.12.0: exige quark ≥ v1.5.0 y nucleus ≥ v1.8.0 al
# pin (los tags anteriores no llevan los fixes DX y este guard sale rojo —
# eso es información de certificación, no ruido).
#
# A3/A4/A5 se ejercen vía un módulo sonda temporal con `replace` al submódulo
# de quark al pin: mismo código, misma API pública que un consumidor real.
#
# Compatibilidad: bash 3.2 (macOS).
set -uo pipefail

ROOT=$(pwd)
NUCLEUS_DIR="${QUANTUM_EXIT0_NUCLEUS:-$ROOT/nucleus}"
QUARK_DIR="${QUANTUM_EXIT0_QUARK:-$ROOT/quark}"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail=0
say_fail() { echo "FAIL $1" >&2; fail=1; }

# --- nucleus: compilar el CLI al pin una sola vez --------------------------
if ! (cd "$NUCLEUS_DIR" && go build -o "$TMP/nucleus" ./cmd/nucleus) >"$TMP/build.log" 2>&1; then
  echo "FAIL setup: no compila el CLI de nucleus al pin:" >&2
  tail -5 "$TMP/build.log" >&2
  exit 1
fi

# A1 — config explícita inexistente: EXIT!=0 y sin nucleus.db en el cwd.
mkdir -p "$TMP/a1" && cd "$TMP/a1"
if "$TMP/nucleus" health --config "$TMP/no-such-file.yml" >out.log 2>&1; then
  say_fail "A1: 'nucleus health --config <inexistente>' salió con EXIT=0 (informe DX §4.A1)"
elif [ -e nucleus.db ]; then
  say_fail "A1: el health fallido creó un nucleus.db en el cwd"
else
  echo "OK  A1: config explícita inexistente → error ($(grep -o 'does not exist' out.log | head -1))"
fi

# A2 — directorio de migraciones inexistente: EXIT!=0 y NO se crea.
mkdir -p "$TMP/a2" && cd "$TMP/a2"
if "$TMP/nucleus" migrate --migrations "$TMP/a2/nope" up >out.log 2>&1; then
  say_fail "A2: 'nucleus migrate --migrations <inexistente> up' salió con EXIT=0 (informe DX §4.A2)"
elif [ -d "$TMP/a2/nope" ]; then
  say_fail "A2: el migrate fallido CREÓ el directorio de migraciones"
else
  echo "OK  A2: migrations inexistente → error sin efectos secundarios"
fi

# A6 — clave desconocida en el yml: EXIT!=0 con did-you-mean.
mkdir -p "$TMP/a6" && cd "$TMP/a6"
printf 'prot: 9999\n' > bad.yml
if "$TMP/nucleus" health --config bad.yml >out.log 2>&1; then
  say_fail "A6: 'nucleus health' aceptó 'prot: 9999' con EXIT=0 (informe DX §4.A6)"
elif ! grep -q "did you mean" out.log; then
  say_fail "A6: el error por clave desconocida no sugiere la clave correcta (did-you-mean)"
else
  echo "OK  A6: clave desconocida → error con did-you-mean"
fi

# A7 — routes debe declarar su límite (solo rutas del framework) en vez de
# presentar la lista parcial como completa.
mkdir -p "$TMP/a7" && cd "$TMP/a7"
"$TMP/nucleus" routes >out.log 2>&1
if ! grep -q "listing framework-owned routes only" out.log; then
  say_fail "A7: 'nucleus routes' ya no declara que solo lista rutas del framework (informe DX §4.A7)"
else
  echo "OK  A7: routes declara su límite"
fi
cd "$ROOT"

# --- quark: sonda A3/A4/A5 por la API pública, replace al pin --------------
mkdir -p "$TMP/probe"
cat > "$TMP/probe/go.mod" <<EOF
module exit0probe

go 1.25

require github.com/jcsvwinston/quark v0.0.0
replace github.com/jcsvwinston/quark => $QUARK_DIR
EOF
cp "$QUARK_DIR/go.sum" "$TMP/probe/go.sum"
cat > "$TMP/probe/main.go" <<'EOF'
// Sonda del guard nº16 — repros A3/A4/A5 del informe DX por la API pública.
package main

import (
	"database/sql"
	"fmt"
	"os"
	"strings"

	"github.com/jcsvwinston/quark"
	sqlite "modernc.org/sqlite"
)

// El Widget del §4.A3: cinco erratas que un humano escribe de verdad.
type lintWidget struct {
	ID    int64   `db:"id" pk:"True"`
	Name  string  `db:"name" quark:"notnull"`
	Price float64 `db:"price,lenght=10"`
	Qty   int     `db:"qty,size=abc"`
	Extra string  `column:"extra" db:"extra_field"`
}

func main() {
	bad := 0
	oops := func(f string, a ...any) { fmt.Printf("FAIL "+f+"\n", a...); bad = 1 }

	// A3
	c, err := quark.New("sqlite", ":memory:")
	if err != nil {
		oops("setup A3: %v", err)
	} else {
		err = c.RegisterModel(&lintWidget{})
		switch {
		case err == nil:
			oops("A3: RegisterModel aceptó 5 erratas de tag en silencio (informe DX §4.A3)")
		case !strings.Contains(err.Error(), "notnull") || !strings.Contains(err.Error(), "lenght"):
			oops("A3: el error de tags no nombra las erratas: %v", err)
		default:
			fmt.Println("OK  A3: erratas de tag → RegisterModel falla nombrándolas")
		}
		c.Close()
	}

	// A4
	if _, err := quark.New("sqlite", ":memory:", "WithMaxOpenConns(25)", 42, quark.WithMaxOpenConns); err == nil {
		oops("A4: quark.New aceptó tres opciones inválidas en silencio (informe DX §4.A4)")
	} else if !strings.Contains(err.Error(), "string") || !strings.Contains(err.Error(), "int") {
		oops("A4: el error no nombra los tipos de las opciones inválidas: %v", err)
	} else {
		fmt.Println("OK  A4: opciones inválidas → New falla nombrándolas")
	}

	// A5 — el repro del informe: un driver database/sql registrado cuyo
	// nombre quark no conoce (la situación de cualquier driver de terceros).
	// Sin WithDialect tiene que ser un error, no WARN + dialecto PostgreSQL.
	sql.Register("weirddb", &sqlite.Driver{})
	if _, err := quark.New("weirddb", ":memory:"); err == nil {
		oops("A5: driver desconocido sin WithDialect devolvió un cliente (fallback silencioso; informe DX §4.A5)")
	} else if !strings.Contains(err.Error(), "WithDialect") {
		oops("A5: el error no apunta a quark.WithDialect como salida: %v", err)
	} else {
		fmt.Println("OK  A5: driver desconocido sin WithDialect → error")
	}
	os.Exit(bad)
}
EOF
if ! (cd "$TMP/probe" && GOFLAGS=-mod=mod go run .) >"$TMP/probe.out" 2>&1; then
  echo "— salida de la sonda quark —" >&2
  cat "$TMP/probe.out" >&2
  say_fail "A3/A4/A5: la sonda quark detectó regresiones (arriba)"
else
  grep '^OK' "$TMP/probe.out"
fi

if [ "$fail" -ne 0 ]; then
  echo "check_exit0_regressions: FAIL — algún repro del §4.A del informe DX vuelve a salir con éxito." >&2
  exit 1
fi
echo "check_exit0_regressions: OK — los 7 repros §4.A fallan como deben (o declaran su límite)."
