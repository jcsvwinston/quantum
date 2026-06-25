# Marca Quantum

Identidad de la suite. Dirección elegida: **"el estado fijado"** — niveles de
energía cuantizados, estética de instrumento de medida (osciloscopio).

Brand board completo: [`quantum-brandboard.html`](quantum-brandboard.html) — ábrelo
en el navegador (autocontenido, se adapta a claro/oscuro).

## Concepto

Quantum *coordina, no contiene*: fija un trío de versiones probadas juntas. La
identidad lo traduce a **cuantización** — tres niveles discretos (los tres pilares)
y una release como un **estado certificado** que solo cambia en saltos. Estética
sobria de instrumento, no de marketing (cultura anti-hype heredada de Quark).

## Símbolo

Tres niveles cuantizados (longitudes distintas = la asimetría real de la suite; el
central, Nucleus, es el host) y **el cuanto**: un punto de señal que reposa en un
nivel y salta al siguiente. Assets estáticos (sin animación, para README/favicon/web):
[`quantum-mark.svg`](quantum-mark.svg) (tema claro) y
[`quantum-mark-dark.svg`](quantum-mark-dark.svg) (tema oscuro); en la portada se
sirven con `<picture>` + `prefers-color-scheme`. En el brand board el cuanto está
animado (respetando `prefers-reduced-motion`).

Glifos por pilar (en el brand board): **Nucleus** = nivel lleno (host); **Quark** =
partícula entre corchetes (suelta, independiente); **Orbit** = punto en arco ligado
al núcleo (su única dependencia dura).

## Wordmark

`Quantum` en monoespaciada (display), peso 500, con la **«u» en verde señal** — el
cuanto resaltado dentro de la palabra.

## Paleta

| Rol | Claro | Oscuro |
|---|---|---|
| Tinta (texto) | `#0E1116` | `#EAEEF5` |
| Texto secundario | `#4A5366` | `#A4AEC2` |
| **Señal** (verde fósforo · el cuanto) | `#00A86B` | `#2BE49B` |
| Cobalto (acento frío secundario) | `#2D5BD6` | `#6E97FF` |
| Líneas / hairlines | `#D7DCE5` | `#2A2F3A` |
| Papel (superficie) | `#F2F5F9` | `#1B1F27` |

El verde fósforo de osciloscopio es la firma. Dos acentos con sentido (señal = el
cuanto; cobalto = distinguir pilares), nunca arcoíris.

## Tipografía

- **Display / código**: monoespaciada del sistema — `ui-monospace, "SF Mono", "JetBrains Mono", Menlo, Consolas, monospace`.
- **Texto**: grotesca neutra del sistema — `system-ui, -apple-system, "Segoe UI", Roboto, sans-serif`.
- Pesos 400 / 500. Sin webfonts (cero dependencias externas).

## Uso

- **Anti-hype**: los textos describen, no venden. La estética puede ser fuerte; el
  lenguaje, sobrio.
- **Claro y oscuro**: todo asset debe funcionar en ambos temas.
- El sitio de docs unificado (Fase 2) tomará esta paleta y tipografía como tokens.
