#!/usr/bin/env python3
"""Porta nel gioco un foglio di piante: una riga per pianta, gli stadi di
crescita da sinistra a destra, su sfondo uniforme, senza blocco di terra (la
pianta poggia sulla terra del campo).

Uso:
    python3 tools/import_plants.py FOGLIO coltura1 coltura2 ... [--riga X,Y=N ...]

Le colture vanno nell'ordine delle righe, dall'alto; "-" salta una riga (per
esempio una pianta già presa da un altro foglio). Un disegno grande che
scavalca due righe si assegna a mano con --riga: il disegno che contiene il
punto X,Y del foglio va nella riga N (da 0).

Scrive:
  assets/graphics/sprites/pianta_<coltura>_<stadio>.png   uno per stadio
  assets/graphics/plants/plants.json                      stadi della coltura:
      "anchor" è la base della pianta (in basso al centro), che il gioco mette
      al centro del quadrante; "tile_w" è la larghezza del quadrante in pixel
      dello sprite, la stessa per tutti gli stadi, così il germoglio resta
      piccolo e la pianta matura grande come nel foglio.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from import_flux import remove_background  # noqa: E402
from split_sheet import labels  # noqa: E402

SPRITES = ROOT / "assets/graphics/sprites"
PLANTS_JSON = ROOT / "assets/graphics/plants/plants.json"
TOL = 30.0
GROW = 3            ## si allarga la maschera: foglie e fiori staccati restano con la pianta
MIN_AREA = 150
FILL = 0.8          ## larghezza della pianta matura "tipica" del foglio rispetto al quadrante
MAX_FILL = 1.15     ## nessuna pianta matura più larga di così


def blobs(img: Image.Image) -> list[tuple[int, int, int, int]]:
    rgb = np.asarray(img.convert("RGB")).astype(float)
    h, w, _ = rgb.shape
    bg = np.median(np.array([rgb[3, 3], rgb[3, w - 4], rgb[h - 4, 3], rgb[h - 4, w - 4]]), axis=0)
    mask = np.sqrt(((rgb - bg) ** 2).sum(axis=2)) >= TOL
    grown = Image.fromarray(mask.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(GROW))
    lab, n = labels(np.asarray(grown) > 0)
    out = []
    for k in range(1, n + 1):
        ys, xs = np.nonzero((lab == k) & mask)
        if len(ys) >= MIN_AREA:
            out.append((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    return out


def main() -> None:
    args = sys.argv[1:]
    forced = {}
    while "--riga" in args:
        i = args.index("--riga")
        point, row = args[i + 1].split("=")
        forced[tuple(int(v) for v in point.split(","))] = int(row)
        del args[i:i + 2]
    if len(args) < 2:
        print(__doc__)
        sys.exit(1)
    sheet = Image.open(args[0]).convert("RGB")
    crops = args[1:]
    found = blobs(sheet)
    # basi delle righe: il fondo dei germogli della prima colonna
    left = min(b[0] for b in found)
    first = sorted((b for b in found if b[0] < left + 80), key=lambda b: b[3])
    if len(first) != len(crops):
        sys.exit(f"trovate {len(first)} righe nella prima colonna, ma le colture sono {len(crops)}")
    bases = [b[3] for b in first]
    rows: list[list] = [[] for _ in crops]
    for b in found:
        row = min(range(len(bases)), key=lambda r: abs(bases[r] - b[3]))
        for (x, y), r in forced.items():
            if b[0] <= x < b[2] and b[1] <= y < b[3]:
                row = r
        rows[row].append(b)
    finals = [max(r, key=lambda b: b[0])[2] - max(r, key=lambda b: b[0])[0] for r in rows]
    typical = float(np.median(finals))
    plants = json.loads(PLANTS_JSON.read_text()) if PLANTS_JSON.exists() else {}
    for crop, row, final_w in zip(crops, rows, finals):
        if crop == "-":
            continue
        row.sort(key=lambda b: b[0])
        tile_w = max(typical / FILL, final_w / MAX_FILL)
        stages = []
        for i, (x0, y0, x1, y1) in enumerate(row):
            pad = 12
            box = (max(x0 - pad, 0), max(y0 - pad, 0), min(x1 + pad, sheet.width), min(y1 + pad, sheet.height))
            cut = remove_background(sheet.crop(box), TOL)
            name = f"pianta_{crop}_{i}"
            cut.save(SPRITES / f"{name}.png")
            stages.append({"file": f"res://assets/graphics/sprites/{name}.png",
                           "anchor": [round(cut.width / 2, 1), round(cut.height * 0.98, 1)],
                           "tile_w": round(tile_w, 1), "sheet": Path(args[0]).name})
        plants[crop] = stages
        print(f"{crop}: {len(stages)} stadi")
    PLANTS_JSON.write_text(json.dumps(plants, indent=2) + "\n")


if __name__ == "__main__":
    main()
