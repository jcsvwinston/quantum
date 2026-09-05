#!/usr/bin/env bash
# check_handoff_size.sh — el handoff del paraguas (.claude/commands/next-session.md)
# se carga ENTERO al arrancar cada sesión. El 2026-09-05 pesaba 203 KB y 40
# sesiones en su §3, y el cargador lo truncaba: el arranque leía un estado a
# medias sin saberlo. Este guard fija el régimen que lo evita: el §3 lleva el
# estado vigente y como mucho DOS sesiones; el resto se archiva en
# docs/handoff/ (historia que se busca con grep, no que se carga).
set -uo pipefail
cd "$(dirname "$0")/.."
f=.claude/commands/next-session.md
MAX_BYTES=${HANDOFF_MAX_BYTES:-70000}
MAX_SESIONES=${HANDOFF_MAX_SESIONES:-2}
status=0
bytes=$(wc -c < "$f" | tr -d ' ')
if [ "$bytes" -gt "$MAX_BYTES" ]; then
  echo "FAIL: $f pesa $bytes bytes (> $MAX_BYTES) — el arranque lo carga truncado; archiva sesiones en docs/handoff/" >&2
  status=1
fi
sesiones=$(awk '/^## 3\./{f=1;next} /^## 4\./{f=0} f && /^### Sesión /{n++} END{print n+0}' "$f")
if [ "$sesiones" -gt "$MAX_SESIONES" ]; then
  echo "FAIL: el §3 de $f lleva $sesiones sesiones (> $MAX_SESIONES) — mueve las viejas a docs/handoff/ (el §3 es estado, no historia)" >&2
  status=1
fi
if ! grep -q '^### Estado vigente' "$f"; then
  echo "FAIL: el §3 de $f no abre con «### Estado vigente» — el arranque necesita el estado antes que la historia" >&2
  status=1
fi
[ "$status" -eq 0 ] && echo "OK: handoff — $bytes bytes, $sesiones sesión(es) en el §3, estado vigente presente"
exit $status
