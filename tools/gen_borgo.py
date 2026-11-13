#!/usr/bin/env python3
"""Genera la pianta del borgo: scenes/borgo/borgo_layout.gd.

Un borgo medievale su un colle: vie tortuose che salgono, vicoli, una piazza
irregolare, case addossate lungo le vie, mura attorno con una porta in basso.

- Altezza: colle con la cima in alto (verso il fondo dello schermo), a mezzi
  livelli; le vie salgono a gradini di mezzo livello.
- Vie: polilinee scritte qui sotto (STREETS), larghe una cella.
- Lotti: 2x2, piani, appoggiati con la facciata (davanti o a destra) su una via;
  riempiti in modo fitto, così le case risultano attaccate.
- Edifici del gioco: assegnati ai lotti più adatti (campanile in cima, mulino
  fuori dalle mura, edifici del primo livello vicino alla porta...).

Uso:  python3 tools/gen_borgo.py   (deterministico: stessa pianta ogni volta)
"""
import math
import random
from collections import deque
from pathlib import Path

W, H = 24, 28
OUT = Path(__file__).resolve().parent.parent / "scenes/borgo/borgo_layout.gd"
random.seed(11)

GATE = (12, 27)
CENTER = (12.0, 13.0)


def inside_walls(x, y):
    """Il paese è un ovale irregolare attorno al colle."""
    dx = (x + 0.5 - CENTER[0]) / 10.6
    dy = (y + 0.5 - CENTER[1]) / 13.2
    wob = 0.08 * math.sin(x * 0.9) + 0.06 * math.cos(y * 0.7)
    return dx * dx + dy * dy < 1.0 + wob


def hill(x, y):
    """Altezza del colle in mezzi livelli (0..8): cima in alto, un po' a destra."""
    cx, cy = 13.0, 4.0
    d = math.hypot((x + 0.5 - cx) / 1.25, (y + 0.5 - cy))
    h = 8.2 - d * 0.36 + 0.5 * math.sin(x * 0.55 + y * 0.2)
    return max(0, min(8, int(round(h))))


# Vie: la via principale sale a zig-zag dalla porta alla chiesa; i vicoli si diramano.
STREETS = [
    [(12, 27), (12, 24), (9, 22), (9, 19), (13, 17), (15, 14), (12, 12), (11, 9), (14, 7), (14, 4)],
    [(9, 19), (5, 19), (4, 15), (6, 12)],
    [(15, 14), (19, 13), (19, 9)],
    [(11, 9), (7, 8), (6, 5)],
    [(12, 24), (17, 23), (18, 20)],
    [(14, 7), (18, 6)],
    [(4, 15), (2, 15)],
    [(6, 12), (11, 12)],
    [(18, 20), (20, 18)],
]
PIAZZA = [(x, y) for x in range(10, 16) for y in range(12, 15)] + [(11, 15), (12, 15), (15, 12), (16, 13)]


def line_cells(a, b):
    """Celle di un tratto: prima in orizzontale poi in verticale (vie a gomito)."""
    (x0, y0), (x1, y1) = a, b
    cells = []
    sx = 1 if x1 >= x0 else -1
    for x in range(x0, x1 + sx, sx):
        cells.append((x, y0))
    sy = 1 if y1 >= y0 else -1
    for y in range(y0, y1 + sy, sy):
        cells.append((x1, y))
    return cells


def main():
    terrain = [[" "] * W for _ in range(H)]
    height = [[hill(x, y) for x in range(W)] for y in range(H)]
    for y in range(H):
        for x in range(W):
            if inside_walls(x, y):
                terrain[y][x] = "."
    streets = set()
    for poly in STREETS:
        for a, b in zip(poly, poly[1:]):
            streets.update(line_cells(a, b))
    streets.update(PIAZZA)
    for x, y in streets:
        if 0 <= x < W and 0 <= y < H:
            terrain[y][x] = "p" if (x, y) in PIAZZA else "#"
    # la piazza è piana
    pz = round(sum(height[y][x] for x, y in PIAZZA) / len(PIAZZA))
    for x, y in PIAZZA:
        height[y][x] = pz
    # le vie salgono di al più mezzo livello per cella: si livella dalla porta
    q = deque([GATE])
    seen = {GATE}
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n in streets and n not in seen and 0 <= n[0] < W and 0 <= n[1] < H:
                h0 = height[y][x]
                h1 = height[n[1]][n[0]]
                if (n[0], n[1]) not in PIAZZA:
                    height[n[1]][n[0]] = max(h0 - 1, min(h0 + 1, h1))
                seen.add(n)
                q.append(n)
    # mura: celle del bordo interno dell'ovale, rialzate (non sulle vie)
    for y in range(H):
        for x in range(W):
            if terrain[y][x] in ".#p":
                border = any(not (0 <= x + dx < W and 0 <= y + dy < H) or terrain[y + dy][x + dx] == " "
                             for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if border and terrain[y][x] == ".":
                    terrain[y][x] = "w"
    # lotti 2x2 piani con la facciata su una via, fitti
    used = set()
    lots = []
    order = sorted(((x, y) for y in range(H - 1) for x in range(W - 1)), key=lambda c: (-(c[1]), c[0]))
    for x, y in order:
        cells = [(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)]
        if any(c in used or terrain[c[1]][c[0]] != "." for c in cells):
            continue
        hs = {height[c[1]][c[0]] for c in cells}
        if len(hs) != 1:
            # sul pendio si spiana il lotto all'altezza più bassa
            h = min(hs)
        else:
            h = hs.pop()
        front = [(x, y + 2), (x + 1, y + 2)]
        right = [(x + 2, y), (x + 2, y + 1)]
        faces = any(c in streets for c in front) or any(c in streets for c in right)
        if not faces:
            continue
        for c in cells:
            used.add(c)
            height[c[1]][c[0]] = h
        lots.append((x, y))
    # seconda e terza passata: case addossate a quelle già messe o a una via su
    # qualsiasi lato (lasciando qualche orto qua e là)
    def touches(cells, targets):
        for cx, cy in cells:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if (cx + dx, cy + dy) in targets and (cx + dx, cy + dy) not in cells:
                    return True
        return False
    for _ in range(2):
        for x, y in order:
            cells = [(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)]
            if any(c in used or terrain[c[1]][c[0]] != "." for c in cells):
                continue
            if not (touches(cells, streets) or touches(cells, used)):
                continue
            if random.random() < 0.2:
                continue   # un orto
            h = min(height[c[1]][c[0]] for c in cells)
            for c in cells:
                used.add(c)
                height[c[1]][c[0]] = h
            lots.append((x, y))
    # edifici del gioco nei lotti, per zona: solo lotti affacciati su una via
    def faces_street(l):
        x, y = l
        return any(c in streets for c in [(x, y + 2), (x + 1, y + 2), (x + 2, y), (x + 2, y + 1)])
    def dist(l, p):
        return math.hypot(l[0] + 1 - p[0], l[1] + 1 - p[1])
    wants = [
        ("campanile", (14, 3)), ("ufficio_postale", (12, 18)), ("bar", (14, 15)), ("osteria", (10, 15)),
        ("forno", (8, 18)), ("pasticceria", (16, 11)), ("gelateria", (13, 21)), ("pastificio", (7, 21)),
        ("conserve", (16, 20)), ("cantina", (18, 15)), ("caseificio", (5, 14)), ("frantoio", (5, 10)),
        ("bocce", (19, 10)),
    ]
    assigned = {}
    free = [l for l in lots if faces_street(l)]
    for name, near in wants:
        best = min(free, key=lambda l: dist(l, near))
        assigned[best] = name
        free.remove(best)
    # mulino fuori dalle mura, sul prato a sinistra, sul colle
    mulino = (1, 6)
    for dx in range(2):
        for dy in range(2):
            height[mulino[1] + dy][mulino[0] + dx] = height[mulino[1]][mulino[0]]
    # scrittura
    lines = ["# File generato da tools/gen_borgo.py: non modificarlo a mano.",
             "class_name BorgoLayout", "extends RefCounted", "",
             "## Pianta del borgo. TERRAIN: ' ' prato fuori, '.' prato/orti dentro,",
             "## 'w' mura, '#' via, 'p' piazza. HEIGHT: altezza in mezzi livelli (0-8).", "",
             "const SIZE := Vector2i(%d, %d)" % (W, H),
             "const GATE := Vector2i(%d, %d)" % GATE,
             "const TERRAIN := ["]
    lines += ['\t"%s",' % "".join(r) for r in terrain]
    lines += ["]", "const HEIGHT := ["]
    lines += ['\t"%s",' % "".join(str(h) for h in r) for r in height]
    lines += ["]", "## Lotti 2x2: [cella, edificio del gioco o \"\" per una casa]", "const LOTS := ["]
    for l in lots:
        lines.append('\t[Vector2i(%d, %d), "%s"],' % (l[0], l[1], assigned.get(l, "")))
    lines.append('\t[Vector2i(%d, %d), "mulino"],' % mulino)
    lines += ["]", ""]
    OUT.write_text("\n".join(lines))
    print(f"{len(lots)} lotti, {len(streets)} celle di via -> {OUT}")
    for r in terrain:
        print("".join(r))


if __name__ == "__main__":
    main()
