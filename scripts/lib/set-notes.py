#!/usr/bin/env python3
"""set-notes.py — la parte del manifiesto que se rompía a mano (DX-25 + QADR-0002).

bump-set.sh mueve los submódulos y reescribe pines y tablas; este script hace
lo que hasta 1.27.0 se escribía a mano sobre versions.yaml y CHANGELOG.md, y
que en 1.26.1 costó la clave declared_lags (un recorte con offset rancio):

  --capture        imprime en JSON el estado ANTES del re-pin (versión de
                   suite, pilares, bloques de módulos, notes). bump-set lo
                   guarda y lo pasa después con --old.
  --old <json>     con el estado viejo y el versions.yaml YA re-pinado:
                     1. calcula la versión de suite por QADR-0002 desde el
                        salto REAL de los pilares (major → major, minor →
                        minor, patch → patch; solo módulos → patch); --set
                        la sobreescribe para un corte deliberado;
                     2. mueve las notes anteriores a CHANGELOG.md bajo
                        «## Quantum <vieja> — <título>» (título derivado de
                        su primera frase; revisarlo); idempotente;
                     3. escribe quantum, released (hoy), el comentario de
                        status y un ESQUELETO de notes con los movimientos
                        del set y marcadores REDACTAR. manifest-guard §0
                        rechaza el marcador: un set no certifica sin
                        redactar.

Si versions.yaml ya lleva el esqueleto (REDACTAR) no vuelve a mover nada:
con --set reescribe solo el número; sin él, para. Ejecutar bump-set dos
veces no puede subir dos veces la suite ni enterrar un borrador.
"""
import argparse, datetime, json, re, sys, textwrap

SECTIONS = ('quark_modules', 'nucleus_modules', 'orbit_modules')
PILLARS = ('quark', 'nucleus', 'orbit')
NAMES = {1: 'Patch', 2: 'Minor', 3: 'Major'}


def read(path):
    return open(path, encoding='utf-8').read()


def val(s, key):
    m = re.search(rf'^{key}:\s+"([^"]+)"', s, re.M)
    return m.group(1) if m else None


def block(s, sec):
    m = re.search(rf'^{sec}:\n((?:  \S+:.*\n)+)', s, re.M)
    if not m:
        return {}
    return dict(re.findall(r'^  (\S+):\s+"([^"]+)"', m.group(1), re.M))


def notes_of(s):
    m = re.search(r'^notes: >\n', s, re.M)
    return (s[m.end():], m) if m else ('', None)


def state(s):
    return {'quantum': val(s, 'quantum'), 'modules': block(s, 'modules'),
            'blocks': {k: block(s, k) for k in SECTIONS}, 'notes': notes_of(s)[0]}


def sv(v):
    return tuple(int(x) for x in v.lstrip('v').split('.'))


def level(a, b):
    if a == b or a is None or b is None:
        return 0
    A, B = sv(a), sv(b)
    if A[0] != B[0]:
        return 3
    if A[1] != B[1]:
        return 2
    return 1


def bump(v, lv):
    M, m, p = sv(v)
    return {3: f'{M + 1}.0.0', 2: f'{M}.{m + 1}.0', 1: f'{M}.{m}.{p + 1}'}[lv]


def wrap(par):
    return textwrap.fill(' '.join(par.split()), width=76, initial_indent='  ', subsequent_indent='  ')


def joinlist(items):
    return items[0] if len(items) == 1 else ', '.join(items[:-1]) + ' y ' + items[-1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--capture', action='store_true')
    ap.add_argument('--old')
    ap.add_argument('--set', dest='override')
    ap.add_argument('--manifest', default='versions.yaml')
    ap.add_argument('--changelog', default='CHANGELOG.md')
    ap.add_argument('--today', default=datetime.date.today().isoformat())
    a = ap.parse_args()

    s = read(a.manifest)
    if a.capture:
        print(json.dumps(state(s), ensure_ascii=False))
        return
    if not a.old:
        ap.error('hace falta --capture o --old <json>')
    old = json.load(open(a.old, encoding='utf-8'))
    new = state(s)
    oldq = old['quantum']

    # Ya hay un esqueleto sin redactar: no se mueve nada más.
    if 'REDACTAR' in new['notes'] or 'REDACTAR' in old['notes']:
        if not a.override:
            sys.exit(f'set-notes: versions.yaml ya lleva el esqueleto de un set en curso ({new["quantum"]}) '
                     'con marcadores REDACTAR sin redactar — redáctalo, o usa --set X.Y.Z para cambiar solo el número')
        cur = new['quantum']
        s = re.sub(r'^quantum: "[^"]+"', f'quantum: "{a.override}"', s, count=1, flags=re.M)
        s = s.replace(f'Quantum {cur} —', f'Quantum {a.override} —', 1)
        open(a.manifest, 'w', encoding='utf-8').write(s)
        print(f'set-notes: versión de suite {cur} → {a.override} (solo el número; las notes siguen sin redactar)')
        return

    # 1. Versión de suite por QADR-0002.
    lv = 0
    movers, stay = [], []
    for p in PILLARS:
        o, n = old['modules'].get(p), new['modules'].get(p)
        l = level(o, n)
        lv = max(lv, l)
        (movers if l else stay).append((p, o, n, l))
    modch = []
    for sec in SECTIONS:
        ob, nb = old['blocks'].get(sec, {}), new['blocks'].get(sec, {})
        for k in sorted(set(ob) | set(nb)):
            if ob.get(k) != nb.get(k):
                modch.append((sec.split('_')[0], k, ob.get(k), nb.get(k)))
    if a.override:
        newq = a.override
        if newq == oldq:
            sys.exit(f'set-notes: --set {newq} es la versión de suite vigente')
    else:
        if lv == 0 and not modch:
            sys.exit(f'set-notes: ningún pilar ni módulo hermano se mueve respecto a Quantum {oldq} — '
                     'no hay set que certificar (o bump-set ya corrió: mira versions.yaml). Para un corte '
                     'deliberado sin movimiento, --set X.Y.Z')
        newq = bump(oldq, lv or 1)
    slv = level(oldq, newq)
    if slv == 0:
        sys.exit(f'set-notes: {newq} no es un salto sobre {oldq}')

    # 2. Las notes anteriores al CHANGELOG (DX-25), idempotente.
    cl = read(a.changelog)
    head = f'## Quantum {oldq} '
    if head in cl:
        moved = f'ya estaban en CHANGELOG.md bajo «{head.strip()}…»'
    else:
        body = old['notes'].rstrip('\n')
        body = '\n'.join(l[2:] if l.startswith('  ') else l for l in body.split('\n')).strip('\n')
        first = body.split('\n\n')[0].replace('\n', ' ')
        t = re.sub(rf'^Quantum {re.escape(oldq)}\s+[—-]\s*', '', first)
        t = re.split(r'\.\s|\.$', t, maxsplit=1)[0].strip().rstrip('.')
        # Una primera frase larga se recorta en su primer «:» o «,» (un título
        # de CHANGELOG es una línea; la frase entera ya va en el cuerpo).
        if len(t) > 80:
            cut = min([i for i in (t.find(':'), t.find(',')) if 0 < i < 80] or [len(t)])
            t = t[:cut].strip()
        t = (t[:1].upper() + t[1:]) if t else 'REDACTAR el título'
        entry = f'## Quantum {oldq} — {t}\n\n{body}\n\n'
        i = cl.find('\n## Quantum ')
        if i < 0:
            sys.exit('set-notes: CHANGELOG.md sin entradas «## Quantum» — no sé dónde insertar')
        cl = cl[:i + 1] + entry + cl[i + 1:]
        open(a.changelog, 'w', encoding='utf-8').write(cl)
        moved = f'movidas a CHANGELOG.md bajo «## Quantum {oldq} — {t}» (revisa el título)'

    # 3. quantum / released / status / esqueleto de notes.
    def fmt(p, o, n):
        return f'{p} ({o} → {n})'
    if movers:
        mv = f'Se mueve{"n" if len(movers) > 1 else ""} ' + joinlist([fmt(p, o, n) for p, o, n, _ in movers])
        if stay:
            mv += '; ' + joinlist([f'{p} {n}' for p, _, n, _ in stay]) + f' sigue{"n" if len(stay) > 1 else ""} donde estaba{"n" if len(stay) > 1 else ""}'
        mv += '.'
    else:
        mv = 'Ningún pilar se mueve: ' + joinlist([f'{p} {n}' for p, _, n, _ in stay]) + ' siguen donde estaban.'
    if modch:
        parts = []
        for repo, k, o, n in modch:
            if o is None:
                parts.append(f'{repo} {k} (nuevo, {n})')
            elif n is None:
                parts.append(f'{repo} {k} (retirado; era {o})')
            else:
                parts.append(f'{repo} {k} ({o} → {n})')
        mc = 'Módulos hermanos que cambian: ' + joinlist(parts) + '; el resto sin cambio.'
    else:
        mc = 'Ningún módulo hermano cambia.'
    top = [p for p, _, _, l in movers if l == slv]
    if top:
        reason = f'{NAMES[slv]} de suite porque lo es {"la" if slv != 1 else "el"} de {joinlist(top)} (QADR-0002).'
        if slv == 1:
            reason = f'Patch de suite: {joinlist(top)} solo cambia{"n" if len(top) > 1 else ""} de patch (QADR-0002).'
    elif not movers:
        reason = 'Patch de suite: solo se mueven módulos hermanos (QADR-0002).'
    else:
        reason = f'{NAMES[slv]} de suite por decisión (--set {newq}); QADR-0002 no lo exige: REDACTAR el porqué.'
    cadence = ('Si el corte es fuera de la cadencia semanal, REDACTAR aquí la razón (QADR-0008); '
               'si está en cadencia, borrar esta frase.')
    paras = [
        f'Quantum {newq} — REDACTAR: en una frase, qué publica este set. {mv} {mc} {reason} {cadence}',
        'REDACTAR: qué cambia para quien instala (comportamiento, configuración, binarios) '
        'y qué corrige. Si no cambia nada visible, decirlo.',
        'REDACTAR: qué aprendió el tren, o borrar este párrafo si no hubo nada.',
    ]
    skeleton = '\n\n'.join(wrap(p) for p in paras) + '\n'
    comment = (f'{NAMES[slv]} de suite por {"la" if slv != 1 else "el"} {NAMES[slv].lower()} de {joinlist(top)} (QADR-0002)'
               if top else f'{NAMES[slv]} de suite (QADR-0002)') + '; escrito por bump-set, revisar al certificar'

    def sub(pat, rep):
        nonlocal s
        if not re.search(pat, s, re.M):
            sys.exit(f'set-notes: no encontré {pat!r} en {a.manifest} — el formato cambió; ajusta el script')
        s = re.sub(pat, rep, s, count=1, flags=re.M)
    sub(r'^quantum: "[^"]+"', f'quantum: "{newq}"')
    sub(r'^released: \S+', f'released: {a.today}')
    sub(r'^status: certified.*$', f'status: certified           # {comment}')
    # El corte de las notes se calcula DESPUÉS de toda sustitución (1.26.1).
    _, m = notes_of(s)
    if not m:
        sys.exit('set-notes: versions.yaml sin bloque «notes: >»')
    s = s[:m.end()] + skeleton
    open(a.manifest, 'w', encoding='utf-8').write(s)
    print(f'set-notes: Quantum {oldq} → {newq} ({NAMES[slv].lower()} de suite; released {a.today})')
    print(f'  notes anteriores: {moved}')
    print(f'  notes nuevas: esqueleto con {skeleton.count("REDACTAR")} marcadores REDACTAR — manifest-guard §0 no certifica hasta redactarlos')


if __name__ == '__main__':
    main()
