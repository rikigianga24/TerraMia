#!/usr/bin/env python3
"""Porta nel gioco le immagini generate con Flux (una per file).

Uso:
    python3 tools/import_flux.py CARTELLA

Ogni file si chiama come l'asset (vedi docs/asset_prompts.md), per esempio
grano_2.png, mulino_restaurato.png, tex_grass.png, icon_coin.png. Lo script:

  - copia l'originale in assets/graphics/source/flux/ (resta la sorgente);
  - tex_*      texture quadrate viste dall'alto: le rende ripetibili senza
               giunture e le piega nel rombo 3:2 della griglia
               -> assets/graphics/tiles/<nome del gioco>.png
  - cielo      -> assets/graphics/backdrop/cielo.jpg
  - colline    toglie il cielo sopra le colline -> assets/graphics/backdrop/colline.png
  - icon_*     toglie lo sfondo, quadrato 256 -> assets/graphics/icons/<nome>.png
  - <coltura>_<0|1|2>  pianta in uno dei tre stadi: toglie lo sfondo e aggiorna
               assets/graphics/plants/plants.json (base della pianta al centro
               del quadrante)
  - tutto il resto: toglie lo sfondo -> assets/graphics/sprites/<nome>.png

Lo sfondo da togliere è quello uniforme chiesto nei prompt: si prende il
colore degli angoli e si cancella ciò che gli somiglia ed è collegato ai bordi.
Gli asset importati da Flux hanno la precedenza su quelli ritagliati dai fogli
(tools/cut_sprites.py non li sovrascrive).
"""
import json
import re
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
FLUX = ROOT / "assets/graphics/source/flux"
SPRITES = ROOT / "assets/graphics/sprites"
TILES = ROOT / "assets/graphics/tiles"
ICONS = ROOT / "assets/graphics/icons"
BACKDROP = ROOT / "assets/graphics/backdrop"
PLANTS_JSON = ROOT / "assets/graphics/plants/plants.json"
TILE_W, TILE_H = 240, 160          # doppio di Iso.TILE_W / Iso.TILE_H
PLANT_FILL = 0.92                  # larghezza delle piante rispetto al quadrante
TREE_FILL = 1.35                   # gli alberi sporgono dal quadrante

## texture -> mattonella del gioco
TEXTURES = {
    "tex_grass": "grass", "tex_grass_flowers": "grass_flowers", "tex_grass_wild": "grass_wild",
    "tex_grass_dry": "grass_dry", "tex_soil": "soil", "tex_soil_wet": "soil_wet",
    "tex_dirt": "dirt", "tex_sand": "bank", "tex_cobbles": "cobbles", "tex_water": "water",
    "tex_road": "road", "tex_road_puddles": "road_puddles", "tex_road_flowers": "road_flowers",
}
TOL = 38.0


def crops():
    """Id delle piante e loro tipo, letti da scripts/autoload/game_data.gd."""
    src = (ROOT / "scripts/autoload/game_data.gd").read_text()
    block = src[src.index("const CROPS := {"):src.index("}\n", src.index("const CROPS := {"))]
    out = {}
    for m in re.finditer(r'^\t"([a-z_]+)":\s*\{.*?"kind": "([a-z]+)"', block, re.M):
        out[m.group(1)] = m.group(2)
    return out


# --- sfondo -------------------------------------------------------------------

def remove_background(img: Image.Image, tol: float = TOL) -> Image.Image:
    # già trasparente (per esempio tolto in ComfyUI): basta ritagliare
    if img.mode in ("RGBA", "LA") or "transparency" in img.info:
        rgba = img.convert("RGBA")
        a = np.asarray(rgba)[..., 3]
        if a[0, 0] < 10 and a[-1, -1] < 10:
            bbox = rgba.getchannel("A").point(lambda v: 255 if v > 10 else 0).getbbox()
            return rgba.crop(bbox) if bbox else rgba
    rgb = np.asarray(img.convert("RGB")).astype(float)
    h, w, _ = rgb.shape
    corners = np.array([rgb[3, 3], rgb[3, w - 4], rgb[h - 4, 3], rgb[h - 4, w - 4]])
    bg = np.median(corners, axis=0)
    near = np.sqrt(((rgb - bg) ** 2).sum(axis=2)) < tol
    mask = Image.fromarray(np.where(near, 255, 0).astype(np.uint8), "L").copy()
    for x in range(0, w, 5):
        for y in (0, h - 1):
            if mask.getpixel((x, y)) == 255:
                ImageDraw.floodfill(mask, (x, y), 128)
    for y in range(0, h, 5):
        for x in (0, w - 1):
            if mask.getpixel((x, y)) == 255:
                ImageDraw.floodfill(mask, (x, y), 128)
    alpha = Image.fromarray(np.where(np.asarray(mask) == 128, 0, 255).astype(np.uint8), "L")
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    out = img.convert("RGBA")
    out.putalpha(alpha)
    # niente frammenti staccati (granelli dello sfondo): resta il disegno principale
    sys.path.insert(0, str(ROOT / "tools"))
    from cut_sprites import keep_main  # noqa: E402
    out = keep_main(out, 0.02)
    bbox = out.getchannel("A").point(lambda v: 255 if v > 10 else 0).getbbox()
    return out.crop(bbox) if bbox else out


# --- texture -> mattonella ----------------------------------------------------

def make_seamless(img: Image.Image) -> Image.Image:
    """Mescola la texture con se stessa spostata di mezzo lato: i bordi diventano
    quelli dell'interno, così le mattonelle si accostano senza giunture."""
    a = np.asarray(img.convert("RGB")).astype(float)
    h, w, _ = a.shape
    rolled = np.roll(np.roll(a, h // 2, axis=0), w // 2, axis=1)
    y = np.abs(np.linspace(-1, 1, h))[:, None]
    x = np.abs(np.linspace(-1, 1, w))[None, :]
    weight = np.clip((1 - x) * 1.6, 0, 1) * np.clip((1 - y) * 1.6, 0, 1)
    out = a * weight[..., None] + rolled * (1 - weight[..., None])
    return Image.fromarray(out.astype(np.uint8), "RGB")


def square_to_tile(img: Image.Image) -> Image.Image:
    """Piega un quadrato visto dall'alto nel rombo 3:2 del gioco (240x160)."""
    s = min(img.size)
    img = img.crop(((img.width - s) // 2, (img.height - s) // 2, (img.width + s) // 2, (img.height + s) // 2))
    # vertici del rombo: alto (0,0) del quadrato, destra (s,0), basso (s,s), sinistra (0,s)
    dst = np.array([[TILE_W / 2, 0], [TILE_W, TILE_H / 2], [0, TILE_H / 2]], dtype=float)
    src = np.array([[0, 0], [s, 0], [0, s]], dtype=float)
    m = np.linalg.solve(np.c_[dst, np.ones(3)], src)
    coeffs = (m[0, 0], m[1, 0], m[2, 0], m[0, 1], m[1, 1], m[2, 1])
    out = img.convert("RGBA").transform((TILE_W, TILE_H), Image.AFFINE, coeffs, resample=Image.BICUBIC)
    mask = Image.new("L", (TILE_W, TILE_H), 0)
    ImageDraw.Draw(mask).polygon([(TILE_W / 2, 0), (TILE_W, TILE_H / 2), (TILE_W / 2, TILE_H), (0, TILE_H / 2)], fill=255)
    out.putalpha(mask)
    return out


# --- import -------------------------------------------------------------------

def import_one(path: Path, crop_kinds: dict, plants: dict) -> str:
    name = path.stem.lower()
    img = Image.open(path)
    FLUX.mkdir(parents=True, exist_ok=True)
    shutil.copy(path, FLUX / f"{name}{path.suffix.lower()}")
    if name in TEXTURES:
        tile = square_to_tile(make_seamless(img))
        tile.save(TILES / f"{TEXTURES[name]}.png")
        return f"mattonella {TEXTURES[name]}"
    if name == "cielo":
        BACKDROP.mkdir(parents=True, exist_ok=True)
        img.convert("RGB").save(BACKDROP / "cielo.jpg", quality=92)
        return "cielo"
    if name == "colline":
        BACKDROP.mkdir(parents=True, exist_ok=True)
        rgb = img.convert("RGBA")
        cut = remove_background(img, 30.0)
        # le colline restano larghe come l'immagine: si rimette il ritaglio sulla tela intera
        canvas = Image.new("RGBA", rgb.size, (0, 0, 0, 0))
        canvas.alpha_composite(cut, (0, rgb.height - cut.height))
        canvas.save(BACKDROP / "colline.png")
        return "colline"
    if name.startswith("icon_"):
        cut = remove_background(img)
        side = int(max(cut.size) * 1.06)
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.alpha_composite(cut, ((side - cut.width) // 2, (side - cut.height) // 2))
        sq.resize((256, 256), Image.LANCZOS).save(ICONS / f"{name[5:]}.png")
        return f"icona {name[5:]}"
    cut = remove_background(img)
    SPRITES.mkdir(parents=True, exist_ok=True)
    cut.save(SPRITES / f"{name}.png")
    m = re.fullmatch(r"([a-z_]+)_([012])", name)
    if m and m.group(1) in crop_kinds:
        crop, stage = m.group(1), int(m.group(2))
        tree = crop_kinds[crop] in ("tree", "bush")
        fill = TREE_FILL if tree else PLANT_FILL
        entry = {"file": f"res://assets/graphics/sprites/{name}.png",
                 # base della pianta (centro in basso, un po' sopra l'ombra) al centro del quadrante
                 "anchor": [round(cut.width / 2, 1), round(cut.height * 0.97, 1)],
                 "tile_w": round(cut.width / fill, 1)}
        stages = plants.get(crop, [None, None, None])
        while len(stages) < 3:
            stages.append(None)
        stages[stage] = entry
        plants[crop] = stages
        return f"pianta {crop}, stadio {stage}"
    return f"sprite {name}"


def main() -> None:
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    folder = Path(sys.argv[1])
    files = sorted(p for p in folder.iterdir() if p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"))
    crop_kinds = crops()
    plants = json.loads(PLANTS_JSON.read_text()) if PLANTS_JSON.exists() else {}
    for p in files:
        print(f"{p.name}: {import_one(p, crop_kinds, plants)}")
    # nel file delle piante solo quelle con tutti e tre gli stadi
    complete = {k: v for k, v in plants.items() if all(v)}
    PLANTS_JSON.parent.mkdir(parents=True, exist_ok=True)
    PLANTS_JSON.write_text(json.dumps(complete, indent=2) + "\n")
    missing = [k for k, v in plants.items() if not all(v)]
    if missing:
        print("piante con stadi mancanti (non ancora in gioco):", ", ".join(missing))
    print("Fatto. Poi: godot --headless --import")


if __name__ == "__main__":
    main()
