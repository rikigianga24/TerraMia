#!/usr/bin/env python3
"""Ritaglia gli sprite dai fogli illustrati e prepara i dati per il gioco.

Legge assets/graphics/sprites/sprites.json (nome -> foglio e riquadro; i
riquadri si trovano con tools/find_sprites.py) e scrive:

  assets/graphics/sprites/<nome>.png    uno sprite per disegno, bordi puliti
  assets/graphics/plants/plants.json    stadi delle piante, allineati al
                                        blocco di terra (vedi farm.gd)
  assets/graphics/tiles/grass.png,      erba e terra dei fogli, riportate sul
  soil.png, soil_wet.png                rombo 224x112 della griglia del gioco

Uso:  python3 tools/cut_sprites.py
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/graphics/source"
OUT = ROOT / "assets/graphics/sprites"
sys.path.insert(0, str(ROOT / "tools"))
from extract_plants import soil_anchor  # noqa: E402

## Coltura del gioco -> sprite dei tre stadi (germoglio, crescita, maturazione)
PLANTS = {
    "grano": ["grano_0", "grano_1", "grano_2"],
    "pomodoro": ["pomodoro_0", "pomodoro_1", "pomodoro_2"],
    "ulivo": ["ulivo_0", "ulivo_1", "ulivo_2"],
    "vite": ["vite_0", "vite_1", "vite_2"],
    "arancio": ["arancio_0", "arancio_1", "arancio_2"],
    "peperoncino": ["peperoncino_0", "peperoncino_1", "peperoncino_2"],
    "lattuga": ["lattuga_0", "lattuga_1", "lattuga_2"],
    "melanzana": ["melanzana_0", "melanzana_1", "melanzana_2"],
    "zucchina": ["zucchina_0", "zucchina_1", "zucchina_2"],
}

TILE_W, TILE_H = 224, 112


def cut(sheet: Image.Image, box) -> Image.Image:
    pad = 3
    box = (max(0, box[0] - pad), max(0, box[1] - pad), min(sheet.width, box[2] + pad), min(sheet.height, box[3] + pad))
    img = sheet.crop(box).convert("RGBA")
    a = np.asarray(img).copy()
    # la compressione webp lascia l'alfa un po' "sporco": pieno dentro, zero fuori
    alpha = a[..., 3].astype(float)
    alpha = np.clip((alpha - 24.0) * 255.0 / 200.0, 0, 255)
    a[..., 3] = alpha.astype(np.uint8)
    img = Image.fromarray(a, "RGBA")
    bbox = img.getchannel("A").point(lambda v: 255 if v > 10 else 0).getbbox()
    return img.crop(bbox) if bbox else img


def to_grid_tile(tile: Image.Image) -> Image.Image:
    """Porta la faccia superiore di una mattonella sul rombo 224x112 del gioco."""
    a = np.asarray(tile)[..., 3] > 128
    ys, xs = np.nonzero(a)
    top_y = ys.min()
    top_x = int(np.median(xs[ys <= top_y + 1]))
    left_x = xs.min()
    left_y = int(np.median(ys[xs <= left_x + 1]))
    right_x = xs.max()
    right_y = int(np.median(ys[xs >= right_x - 1]))
    # affine inversa: punto del rombo del gioco -> punto della mattonella
    src = np.array([[top_x, top_y], [left_x, left_y], [right_x, right_y]], dtype=float)
    dst = np.array([[112, 0], [0, 56], [224, 56]], dtype=float)
    m = np.linalg.solve(np.c_[dst, np.ones(3)], src)   # 3x2
    coeffs = (m[0, 0], m[1, 0], m[2, 0], m[0, 1], m[1, 1], m[2, 1])
    out = tile.transform((TILE_W, TILE_H), Image.AFFINE, coeffs, resample=Image.BICUBIC)
    mask = Image.new("L", (TILE_W, TILE_H), 0)
    ImageDraw.Draw(mask).polygon([(112, 0), (224, 56), (112, 112), (0, 56)], fill=255)
    out.putalpha(mask)
    return out


def main() -> None:
    manifest = json.loads((OUT / "sprites.json").read_text())
    sheets = {}
    for name, entry in manifest.items():
        sheet = sheets.setdefault(entry["sheet"], Image.open(SRC / entry["sheet"]).convert("RGBA"))
        cut(sheet, entry["box"]).save(OUT / f"{name}.png")
    print(len(manifest), "sprite in", OUT)

    plants = {}
    for crop, stages in PLANTS.items():
        out = []
        for name in stages:
            img = Image.open(OUT / f"{name}.png")
            (ax, ay), w = soil_anchor(np.asarray(img))
            out.append({"file": f"res://assets/graphics/sprites/{name}.png", "anchor": [round(ax, 1), round(ay, 1)], "tile_w": round(w, 1)})
        plants[crop] = out
    plants_path = ROOT / "assets/graphics/plants/plants.json"
    plants_path.parent.mkdir(parents=True, exist_ok=True)
    plants_path.write_text(json.dumps(plants, indent=2) + "\n")
    print(len(plants), "piante in", plants_path)

    tiles = ROOT / "assets/graphics/tiles"
    grass = to_grid_tile(Image.open(OUT / "tile_erba.png"))
    grass.save(tiles / "grass.png")
    # variante con meno fiori: la stessa erba specchiata
    grass.transpose(Image.FLIP_LEFT_RIGHT).save(tiles / "grass_flowers.png")
    soil = to_grid_tile(Image.open(OUT / "tile_terra.png"))
    soil.save(tiles / "soil.png")
    wet = ImageEnhance.Brightness(soil).enhance(0.72)
    ImageEnhance.Color(wet).enhance(1.1).save(tiles / "soil_wet.png")
    print("mattonelle riportate sulla griglia in", tiles)


if __name__ == "__main__":
    main()
