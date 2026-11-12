#!/usr/bin/env python3
"""Ritaglia gli sprite dai fogli illustrati e prepara i dati per il gioco.

Legge assets/graphics/sprites/sprites.json (nome -> foglio e riquadro; i
riquadri si trovano con tools/find_sprites.py) e scrive:

  assets/graphics/sprites/<nome>.png    uno sprite per disegno, bordi puliti
  assets/graphics/plants/plants.json    stadi delle piante, allineati al
                                        blocco di terra (vedi farm.gd)
  assets/graphics/tiles/*.png           le mattonelle del foglio del terreno,
                                        riportate sul rombo 240x160 della griglia (3:2)

Uso:  python3 tools/cut_sprites.py
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

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

TILE_W, TILE_H = 240, 160   # doppio di Iso.TILE_W / Iso.TILE_H (scripts/world/iso.gd)

## Mattonelle del gioco (assets/graphics/tiles/<nome>.png) -> sprite del foglio del terreno
TILES = {
    "grass": "terreno_erba",
    "grass_flowers": "terreno_erba_fiori",
    "grass_wild": "terreno_erba_selvatica",
    "grass_dry": "terreno_erba_secca",
    "soil": "terreno_arato",
    "soil_wet": "terreno_bagnato",
    "dirt": "terreno_sterrato",
    "bank": "terreno_sponda",
}


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
    """Porta la faccia superiore di una mattonella sul rombo 240x160 del gioco."""
    a = np.asarray(tile)[..., 3] > 128
    ys, xs = np.nonzero(a)
    # Vertici laterali e inferiore: affidabili (l'erba alta può sporgere
    # sopra il vertice superiore, che quindi si ricava per simmetria).
    left_x = xs.min()
    left_y = float(np.median(ys[xs <= left_x + 1]))
    right_x = xs.max()
    right_y = float(np.median(ys[xs >= right_x - 1]))
    bottom_y = float(ys.max())
    cx = (left_x + right_x) / 2.0
    side_y = (left_y + right_y) / 2.0
    top_y = 2.0 * side_y - bottom_y
    # un filo verso l'interno, così ai bordi non si campiona il vuoto
    k = 0.965
    def inset(x, y):
        return cx + (x - cx) * k, side_y + (y - side_y) * k
    tx, ty = inset(cx, top_y)
    lx, ly = inset(left_x, side_y)
    rx, ry = inset(right_x, side_y)
    # affine inversa: punto del rombo del gioco -> punto della mattonella
    src = np.array([[tx, ty], [lx, ly], [rx, ry]], dtype=float)
    dst = np.array([[TILE_W / 2, 0], [0, TILE_H / 2], [TILE_W, TILE_H / 2]], dtype=float)
    m = np.linalg.solve(np.c_[dst, np.ones(3)], src)   # 3x2
    coeffs = (m[0, 0], m[1, 0], m[2, 0], m[0, 1], m[1, 1], m[2, 1])
    out = tile.transform((TILE_W, TILE_H), Image.AFFINE, coeffs, resample=Image.BICUBIC)
    mask = Image.new("L", (TILE_W, TILE_H), 0)
    ImageDraw.Draw(mask).polygon([(TILE_W / 2, 0), (TILE_W, TILE_H / 2), (TILE_W / 2, TILE_H), (0, TILE_H / 2)], fill=255)
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
    for out_name, sprite in TILES.items():
        tile = to_grid_tile(Image.open(OUT / f"{sprite}.png"))
        if out_name == "bank":
            # nel foglio l'acqua è in basso a destra; il fiume del gioco sta
            # in alto a sinistra della sponda: si gira di mezzo giro
            tile = tile.rotate(180)
        tile.save(tiles / f"{out_name}.png")
    print("mattonelle riportate sulla griglia in", tiles)


if __name__ == "__main__":
    main()
