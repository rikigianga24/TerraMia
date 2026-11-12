#!/usr/bin/env python3
"""Ritaglia gli sprite delle piante da un foglio illustrato.

Il foglio ha una riga per pianta e tre colonne per gli stadi (germoglio,
crescita, maturazione); ogni disegno sta sopra il suo blocco di terra.
Vedi docs/art_direction.md.

Per ogni disegno lo script:
  1. toglie lo sfondo chiaro (riempimento dai bordi con tolleranza);
  2. trova i disegni come zone connesse e scarta le scritte (troppo piccole);
  3. li ordina in righe e colonne;
  4. trova il blocco di terra (pixel terracotta): i suoi vertici sinistro e
     destro danno larghezza e centro, che il gioco usa per allinearlo;
  5. salva assets/graphics/plants/<pianta>_<stadio>.png e aggiorna plants.json.

Uso:
  python3 tools/extract_plants.py FOGLIO pianta1 pianta2 ...
Esempio:
  python3 tools/extract_plants.py assets/graphics/source/plants_01.webp ulivo pomodoro grano
I nomi sono gli id di game_data.gd, nell'ordine delle righe del foglio.
"""
import json
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/graphics/plants"
TOL = 34.0
MIN_AREA = 4000      # sotto questa area (in pixel) non è un disegno intero
FRAGMENT_AREA = 150  # frammenti più piccoli si ignorano del tutto
STAGES = 3


def background_mask(img: Image.Image) -> np.ndarray:
    """True dove c'è sfondo: colore vicino a quello degli angoli, raggiunto dai bordi."""
    a = np.asarray(img.convert("RGB"), dtype=float)
    h, w, _ = a.shape
    corners = np.array([a[2, 2], a[2, w - 3], a[h - 3, 2], a[h - 3, w - 3]])
    bg = np.median(corners, axis=0)
    near = np.sqrt(((a - bg) ** 2).sum(axis=2)) < TOL
    m = Image.fromarray(np.where(near, 255, 0).astype(np.uint8), "L").copy()
    for x in range(0, w, 7):
        for y in (0, h - 1):
            if m.getpixel((x, y)) == 255:
                ImageDraw.floodfill(m, (x, y), 128)
    for y in range(0, h, 7):
        for x in (0, w - 1):
            if m.getpixel((x, y)) == 255:
                ImageDraw.floodfill(m, (x, y), 128)
    return np.asarray(m) == 128


def components(fg: np.ndarray, step: int = 4):
    """Zone connesse del disegno, cercate su una griglia ridotta per velocità."""
    small = fg[::step, ::step]
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
            if n * step * step >= FRAGMENT_AREA:
                boxes.append(((x0 * step, y0 * step, (x1 + 1) * step, (y1 + 1) * step), n * step * step))
    return boxes


def merge_close(boxes, gap=10):
    """Tiene i disegni grandi e vi attacca i frammenti vicini (una foglia
    staccata appartiene alla pianta); i frammenti lontani sono scritte."""
    big = [list(b) for b, area in boxes if area >= MIN_AREA]
    for b, area in boxes:
        if area >= MIN_AREA:
            continue
        for o in big:
            if b[0] - gap < o[2] and o[0] - gap < b[2] and b[1] - gap < o[3] and o[1] - gap < b[3]:
                o[0], o[1], o[2], o[3] = min(b[0], o[0]), min(b[1], o[1]), max(b[2], o[2]), max(b[3], o[3])
                break
    return [tuple(o) for o in big]


def grid_order(boxes, rows):
    """Ordina le zone in righe (dall'alto) e colonne (da sinistra)."""
    boxes = sorted(boxes, key=lambda b: (b[1] + b[3]) / 2)
    out = []
    for r in range(rows):
        row = boxes[r * STAGES:(r + 1) * STAGES]
        out.append(sorted(row, key=lambda b: (b[0] + b[2]) / 2))
    return out


def soil_anchor(rgba: np.ndarray):
    """Centro della faccia superiore e larghezza del blocco di terra.

    I pixel terracotta (rosso > verde > blu, abbastanza scuri) più a sinistra e
    più a destra sono i vertici laterali del rombo: la loro distanza è la
    larghezza del blocco, la loro media il centro.
    """
    r, g, b, a = (rgba[..., i].astype(int) for i in range(4))
    soil = (a > 200) & (r > g + 25) & (g > b) & (r > 90) & (r < 215) & (g < 130)
    # solo la metà bassa: la terra sta sotto la pianta
    h = soil.shape[0]
    soil[: h // 2] = False
    ys, xs = np.nonzero(soil)
    if len(xs) < 50:
        raise SystemExit("blocco di terra non trovato: controlla i colori del foglio")
    left = xs.min()
    right = xs.max()
    y_left = int(np.median(ys[xs <= left + 2]))
    y_right = int(np.median(ys[xs >= right - 2]))
    return (float(left + right) / 2.0, float(y_left + y_right) / 2.0), float(right - left)


def main() -> None:
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    sheet = Path(sys.argv[1])
    plants = sys.argv[2:]
    img = Image.open(sheet).convert("RGBA")
    bg = background_mask(img)
    boxes = merge_close(components(~bg))
    expected = len(plants) * STAGES
    if len(boxes) != expected:
        raise SystemExit(f"trovati {len(boxes)} disegni, attesi {expected}: {boxes}")
    alpha = Image.fromarray(np.where(bg, 0, 255).astype(np.uint8), "L")
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    img.putalpha(alpha)

    OUT.mkdir(parents=True, exist_ok=True)
    manifest_path = OUT / "plants.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    for plant, row in zip(plants, grid_order(boxes, len(plants))):
        stages = []
        for stage, box in enumerate(row):
            pad = 4
            box = (max(0, box[0] - pad), max(0, box[1] - pad), min(img.width, box[2] + pad), min(img.height, box[3] + pad))
            sprite = img.crop(box)
            (ax, ay), tile_w = soil_anchor(np.asarray(sprite))
            name = f"{plant}_{stage}.png"
            sprite.save(OUT / name)
            stages.append({"file": name, "anchor": [round(ax, 1), round(ay, 1)], "tile_w": round(tile_w, 1)})
            print(f"{name}: blocco largo {tile_w:.0f}px, centro ({ax:.0f}, {ay:.0f})")
        manifest[plant] = stages
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print("aggiornato", manifest_path)


if __name__ == "__main__":
    main()
