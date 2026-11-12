#!/usr/bin/env python3
"""Trova i disegni in un foglio con sfondo trasparente e ne stampa i riquadri.

Uso:  python3 tools/find_sprites.py FOGLIO [ANTEPRIMA.png]
Stampa un riquadro (x0, y0, x1, y1) per disegno, numerato; con ANTEPRIMA
salva il foglio con i riquadri e i numeri disegnati sopra, per dare un nome a
ciascuno in assets/graphics/sprites/sprites.json (vedi tools/cut_sprites.py).
"""
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageDraw

MIN_AREA = 900


def find(img: Image.Image, step: int = 3, alpha_min: int = 40):
    a = np.asarray(img.convert("RGBA"))[..., 3] > alpha_min
    small = a[::step, ::step]
    h, w = small.shape
    seen = np.zeros_like(small, dtype=bool)
    boxes = []
    for y in range(h):
        for x in range(w):
            if not small[y, x] or seen[y, x]:
                continue
            q = deque([(y, x)])
            seen[y, x] = True
            x0 = x1 = x
            y0 = y1 = y
            n = 0
            while q:
                cy, cx = q.popleft()
                n += 1
                x0, x1, y0, y1 = min(x0, cx), max(x1, cx), min(y0, cy), max(y1, cy)
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ny, nx = cy + dy, cx + dx
                        if 0 <= ny < h and 0 <= nx < w and small[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            q.append((ny, nx))
            boxes.append(((x0 * step, y0 * step, (x1 + 1) * step, (y1 + 1) * step), n * step * step))
    big = [list(b) for b, area in boxes if area >= MIN_AREA]
    # i frammenti piccoli vicini a un disegno (foglie, fumo) gli appartengono
    for b, area in boxes:
        if area >= MIN_AREA:
            continue
        for o in big:
            if b[0] - 8 < o[2] and o[0] - 8 < b[2] and b[1] - 8 < o[3] and o[1] - 8 < b[3]:
                o[0], o[1], o[2], o[3] = min(b[0], o[0]), min(b[1], o[1]), max(b[2], o[2]), max(b[3], o[3])
                break
    big.sort(key=lambda b: (round(b[1] / 40), b[0]))
    return [tuple(b) for b in big]


def main():
    img = Image.open(sys.argv[1]).convert("RGBA")
    boxes = find(img)
    for i, b in enumerate(boxes):
        print(i, b)
    if len(sys.argv) > 2:
        prev = Image.new("RGBA", img.size, (255, 255, 255, 255))
        prev.alpha_composite(img)
        d = ImageDraw.Draw(prev)
        for i, b in enumerate(boxes):
            d.rectangle(b, outline=(220, 0, 0, 255), width=2)
            d.rectangle((b[0], b[1], b[0] + 26, b[1] + 16), fill=(220, 0, 0, 255))
            d.text((b[0] + 3, b[1] + 2), str(i), fill=(255, 255, 255, 255))
        prev.convert("RGB").save(sys.argv[2])


if __name__ == "__main__":
    main()
