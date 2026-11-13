#!/usr/bin/env python3
"""Genera la pianta del borgo: scenes/borgo/borgo_layout.gd.

Un borgo medievale in cima a una collina. Dentro le mura: vie tortuose,
vicoli, una piazza irregolare, case addossate, il sagrato con la chiesa e il
campanile in alto. Fuori, scendendo: vigneti a filari, uliveti, boschi e una
strada bianca che scende dalla porta.

Il terreno è una superficie continua: l'altezza è data ai vertici delle celle
(VHEIGHT) e ogni cella è inclinata tra i suoi quattro angoli, quindi i
dislivelli sono dolci. Lotti, piazza e sagrato sono spianati.

TERRAIN (una lettera per cella):
  ' ' prato   'v' vigna   'o' uliveto   'b' bosco   'r' strada bianca
  '.' orto/cortile dentro le mura   'w' mura   '#' via   'p' piazza   'c' sagrato

Uso:  python3 tools/gen_borgo.py   (deterministico: stessa pianta ogni volta)
"""
import math
import random
from collections import deque
from pathlib import Path

W, H = 44, 48
OUT = Path(__file__).resolve().parent.parent / "scenes/borgo/borgo_layout.gd"
random.seed(11)

OX, OY = 10, 8                      # spostamento del borgo dentro la mappa
CENTER = (12.0 + OX, 13.0 + OY)     # centro dell'ovale delle mura
HILL_TOP = (13.0 + OX, 9.0 + OY)    # cima della collina (verso la chiesa)
GATE = (12 + OX, 27 + OY)
CHURCH = (12 + OX, -1 + OY)         # lotto della chiesa: 3 di larghezza, 4 di profondità
CHURCH_SIZE = (3, 4)
SAGRATO = [(x, y) for x in range(10 + OX, 16 + OX) for y in range(3 + OY, 5 + OY)]


def inside_walls(x, y):
    """Il paese è un ovale irregolare in cima al colle, con la chiesa dentro."""
    if CHURCH[0] - 1 <= x < CHURCH[0] + CHURCH_SIZE[0] + 1 and CHURCH[1] <= y < CHURCH[1] + 5:
        return True
    dx = (x + 0.5 - CENTER[0]) / 10.6
    dy = (y + 0.5 - CENTER[1]) / 13.2
    wob = 0.08 * math.sin(x * 0.9) + 0.06 * math.cos(y * 0.7)
    return dx * dx + dy * dy < 1.0 + wob


def hill(x, y):
    """Altezza (in livelli) della collina in un punto: dolce, con la cima al borgo."""
    d = math.hypot((x - HILL_TOP[0]) / 1.15, (y - HILL_TOP[1]) / 1.0)
    h = 7.5 * max(0.0, 1.0 - (d / 27.0) ** 1.7)
    h += 0.35 * math.sin(x * 0.31 + y * 0.17) + 0.25 * math.cos(y * 0.29 - x * 0.11)
    return max(0.0, h)


def shift(poly):
    return [(x + OX, y + OY) for x, y in poly]


STREETS = [shift(p) for p in [
    [(12, 27), (12, 24), (9, 22), (9, 19), (13, 17), (15, 14), (12, 12), (11, 9), (14, 7), (13, 5)],
    [(9, 19), (5, 19), (4, 15), (6, 12)],
    [(15, 14), (19, 13), (19, 9)],
    [(11, 9), (7, 8), (6, 5)],
    [(12, 24), (17, 23), (18, 20)],
    [(14, 7), (18, 6)],
    [(4, 15), (2, 15)],
    [(6, 12), (11, 12)],
    [(18, 20), (20, 18)],
]]
PIAZZA = [(x + OX, y + OY) for x in range(10, 16) for y in range(12, 15)] + shift([(11, 15), (12, 15), (15, 12), (16, 13)])
ROAD = [(12 + OX, 28 + OY), (10 + OX, 31 + OY), (13 + OX, 34 + OY), (11 + OX, 37 + OY), (12 + OX, 39 + OY)]


def line_cells(a, b):
    (x0, y0), (x1, y1) = a, b
    cells = []
    sx = 1 if x1 >= x0 else -1
    for x in range(x0, x1 + sx, sx):
        cells.append((x, y0))
    sy = 1 if y1 >= y0 else -1
    for y in range(y0, y1 + sy, sy):
        cells.append((x1, y))
    return cells


def noise(x, y, s):
    return math.sin(x * 0.37 + s) * math.cos(y * 0.41 - s * 0.7) + 0.5 * math.sin((x + y) * 0.23 + s * 1.3)


def main():
    terrain = [[" "] * W for _ in range(H)]
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
        terrain[y][x] = "p" if (x, y) in PIAZZA else "#"
    for x, y in SAGRATO:
        terrain[y][x] = "c"
    church_cells = {(CHURCH[0] + i, CHURCH[1] + j) for i in range(CHURCH_SIZE[0]) for j in range(CHURCH_SIZE[1])}
    road = set()
    for a, b in zip(ROAD, ROAD[1:]):
        road.update(line_cells(a, b))
    for x, y in road:
        if terrain[y][x] == " ":
            terrain[y][x] = "r"
    # mura sul bordo interno dell'ovale (non su vie, sagrato, chiesa)
    for y in range(H):
        for x in range(W):
            if terrain[y][x] == "." and (x, y) not in church_cells:
                border = any(not (0 <= x + dx < W and 0 <= y + dy < H) or terrain[y + dy][x + dx] in " r"
                             for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if border:
                    terrain[y][x] = "w"

    # campagna fuori le mura: vigne a sud e a est (al sole), uliveti, boschi a
    # nord e a ovest e verso i bordi, prato qua e là
    for y in range(H):
        for x in range(W):
            if terrain[y][x] != " ":
                continue
            ang = math.atan2(y - CENTER[1], x - CENTER[0])     # 0 = destra, pi/2 = davanti
            dist = math.hypot((x - CENTER[0]) / 1.1, y - CENTER[1])
            n = noise(x, y, 1.0)
            if dist < 15.5:
                kind = " "   # prato attorno alle mura
            elif dist > 25.0 + 2.0 * n or (ang < -0.3 and n > -0.2):
                kind = "b"
            elif 0.2 < ang < 2.6:
                kind = "v" if noise(x // 3, y // 3, 4.0) > -0.3 else "o"
            else:
                kind = "o" if n > -0.4 else " "
            terrain[y][x] = kind

    # altezza ai vertici: collina continua
    vh = [[hill(x, y) for x in range(W + 1)] for y in range(H + 1)]

    def flatten(cells, level=None):
        verts = {(x + i, y + j) for x, y in cells for i in (0, 1) for j in (0, 1)}
        if level is None:
            level = sum(vh[v[1]][v[0]] for v in verts) / len(verts)
        for vx, vy in verts:
            vh[vy][vx] = level
        return level

    # lotti 2x2 con la facciata su una via, poi case addossate
    used = set(church_cells)
    lots = []
    order = sorted(((x, y) for y in range(H - 1) for x in range(W - 1)), key=lambda c: (-(c[1]), c[0]))

    def free_lot(x, y):
        cells = [(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)]
        if any(c in used or terrain[c[1]][c[0]] != "." for c in cells):
            return None
        return cells

    for x, y in order:
        cells = free_lot(x, y)
        if not cells:
            continue
        if any(c in streets for c in [(x, y + 2), (x + 1, y + 2), (x + 2, y), (x + 2, y + 1)]):
            used.update(cells)
            lots.append((x, y))

    def touches(cells, targets):
        for cx, cy in cells:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if (cx + dx, cy + dy) in targets and (cx + dx, cy + dy) not in cells:
                    return True
        return False

    for _ in range(2):
        for x, y in order:
            cells = free_lot(x, y)
            if not cells or not (touches(cells, streets) or touches(cells, used)):
                continue
            if random.random() < 0.2:
                continue
            used.update(cells)
            lots.append((x, y))

    # spianamenti: piazza, sagrato e chiesa, poi ogni lotto
    flatten(PIAZZA)
    church_level = flatten(list(church_cells) + SAGRATO)
    for x, y in lots:
        flatten([(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)])
    # ammorbidisce i vertici liberi vicino agli spianamenti (niente scalini)
    fixed = set()
    for cells in [PIAZZA, SAGRATO, list(church_cells)] + [[(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)] for x, y in lots]:
        for cx, cy in cells:
            for i in (0, 1):
                for j in (0, 1):
                    fixed.add((cx + i, cy + j))
    for _ in range(6):
        new = [row[:] for row in vh]
        for vy in range(1, H):
            for vx in range(1, W):
                if (vx, vy) in fixed:
                    continue
                new[vy][vx] = (vh[vy][vx] * 2 + vh[vy - 1][vx] + vh[vy + 1][vx] + vh[vy][vx - 1] + vh[vy][vx + 1]) / 6.0
        vh = new

    # edifici del gioco nei lotti affacciati su una via, per zona
    def faces_street(l):
        x, y = l
        return any(c in streets for c in [(x, y + 2), (x + 1, y + 2), (x + 2, y), (x + 2, y + 1)])

    def dist(l, p):
        return math.hypot(l[0] + 1 - p[0], l[1] + 1 - p[1])
    wants = [
        ("ufficio_postale", (12, 18)), ("bar", (14, 15)), ("osteria", (10, 15)),
        ("forno", (8, 18)), ("pasticceria", (16, 11)), ("gelateria", (13, 21)), ("pastificio", (7, 21)),
        ("conserve", (16, 20)), ("cantina", (18, 15)), ("caseificio", (5, 14)), ("frantoio", (5, 10)),
        ("bocce", (19, 10)),
    ]
    assigned = {}
    free = [l for l in lots if faces_street(l)]
    for name, near in wants:
        near = (near[0] + OX, near[1] + OY)
        best = min(free, key=lambda l: dist(l, near))
        assigned[best] = name
        free.remove(best)
    # mulino fuori dalle mura, sul prato a sinistra
    mulino = (1 + OX - 1, 6 + OY)
    for i in range(2):
        for j in range(2):
            terrain[mulino[1] + j][mulino[0] + i] = " "
    flatten([(mulino[0], mulino[1]), (mulino[0] + 1, mulino[1]), (mulino[0], mulino[1] + 1), (mulino[0] + 1, mulino[1] + 1)])

    # scrittura: altezze dei vertici in decimi di livello, una lettera ciascuna
    def enc(v):
        return chr(48 + max(0, min(74, int(round(v * 10)))))
    lines = ["# File generato da tools/gen_borgo.py: non modificarlo a mano.",
             "class_name BorgoLayout", "extends RefCounted", "",
             "## Pianta del borgo e della collina. TERRAIN: ' ' prato, 'v' vigna, 'o' uliveto,",
             "## 'b' bosco, 'r' strada bianca, '.' cortile, 'w' mura, '#' via, 'p' piazza,",
             "## 'c' sagrato. VHEIGHT: altezza dei vertici delle celle in decimi di livello",
             "## (carattere - 48), (SIZE.x + 1) x (SIZE.y + 1).", "",
             "const SIZE := Vector2i(%d, %d)" % (W, H),
             "const GATE := Vector2i(%d, %d)" % GATE,
             "const TERRAIN := ["]
    lines += ['\t"%s",' % "".join(r) for r in terrain]
    lines += ["]", "const VHEIGHT := ["]
    lines += ['\t"%s",' % "".join(enc(v) for v in r).replace("\\", "\\\\").replace('"', '\\"') for r in vh]
    lines += ["]", "## Lotti: [cella, edificio del gioco o \"\" per una casa, ingombro]", "const LOTS := ["]
    lines.append('\t[Vector2i(%d, %d), "campanile", Vector2i(%d, %d)],' % (CHURCH[0], CHURCH[1], CHURCH_SIZE[0], CHURCH_SIZE[1]))
    for l in lots:
        lines.append('\t[Vector2i(%d, %d), "%s", Vector2i(2, 2)],' % (l[0], l[1], assigned.get(l, "")))
    lines.append('\t[Vector2i(%d, %d), "mulino", Vector2i(2, 2)],' % mulino)
    lines += ["]", ""]
    OUT.write_text("\n".join(lines))
    print(f"{len(lots)} lotti, chiesa al livello {church_level:.1f} -> {OUT}")
    for r in terrain:
        print("".join(r))


if __name__ == "__main__":
    main()
