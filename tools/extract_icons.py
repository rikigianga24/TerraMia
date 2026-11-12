#!/usr/bin/env python3
"""Ritaglia le icone dal foglio assets/graphics/source/icons_sheet.webp.

Per ogni icona: ritaglio nel riquadro indicato, rimozione dello sfondo beige
(riempimento dai bordi con tolleranza, bordo sfumato), taglio al contenuto,
quadrato trasparente 256x256 in assets/graphics/icons/<nome>.png.

Uso:  python3 tools/extract_icons.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SHEET = ROOT / "assets/graphics/source/icons_sheet.webp"
OUT = ROOT / "assets/graphics/icons"
SIZE = 256
BG = np.array([237, 226, 197], dtype=float)   # beige dello sfondo
TOL = 44.0                                    # distanza di colore ancora "sfondo" (ombre comprese)
# Icone con parti chiare vicine al beige: tolleranza più bassa.
TOL_OVERRIDE = {"espresso": 16.0, "seeds": 36.0, "fertilizer": 36.0}

# Riquadri (x0, y0, x1, y1) sul foglio 1536x1024, sopra le scritte.
BOXES = {
    "borgo":        (12, 80, 218, 264),
    "close":        (222, 100, 366, 256),
    "coin":         (378, 100, 532, 262),
    "drop":         (545, 78, 682, 262),
    "espresso":     (695, 88, 840, 260),
    "farm":         (848, 86, 1054, 264),
    "fertilizer":   (1058, 92, 1210, 262),
    "hand":         (1218, 96, 1356, 262),
    "hoe":          (1370, 84, 1510, 264),
    "lira":         (26, 362, 186, 530),
    "lock":         (206, 352, 344, 530),
    "seeds":        (368, 356, 524, 532),
    "shop":         (536, 364, 710, 530),
    "star":         (714, 364, 872, 526),
    "watering_can": (884, 366, 1102, 532),
}


def cut(img: Image.Image, box, tol: float = TOL) -> Image.Image:
    crop = img.crop(box).convert("RGB")
    a = np.asarray(crop, dtype=float)
    dist = np.sqrt(((a - BG) ** 2).sum(axis=2))
    # 255 = simile allo sfondo, 0 = disegno; poi riempimento dai bordi
    mask = Image.fromarray(np.where(dist < tol, 255, 0).astype(np.uint8), "L").copy()
    w, h = mask.size
    for x in range(w):
        for y in (0, h - 1):
            if mask.getpixel((x, y)) == 255:
                ImageDraw.floodfill(mask, (x, y), 128)
    for y in range(h):
        for x in (0, w - 1):
            if mask.getpixel((x, y)) == 255:
                ImageDraw.floodfill(mask, (x, y), 128)
    bg = np.asarray(mask) == 128
    alpha = np.where(bg, 0, 255).astype(np.uint8)
    # bordo morbido: un pixel di sfumatura e niente alone beige
    alpha_img = Image.fromarray(alpha, "L").filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    rgba = crop.convert("RGBA")
    rgba.putalpha(alpha_img)
    bbox = alpha_img.point(lambda v: 255 if v > 8 else 0).getbbox()
    rgba = rgba.crop(bbox)
    # quadrato con un po' di margine
    side = int(max(rgba.size) * 1.06)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(rgba, ((side - rgba.width) // 2, (side - rgba.height) // 2), rgba)
    return canvas.resize((SIZE, SIZE), Image.LANCZOS)


def main() -> None:
    img = Image.open(SHEET)
    OUT.mkdir(parents=True, exist_ok=True)
    for name, box in BOXES.items():
        cut(img, box, TOL_OVERRIDE.get(name, TOL)).save(OUT / f"{name}.png")
        print("ok", name)


if __name__ == "__main__":
    main()
