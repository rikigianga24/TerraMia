#!/usr/bin/env python3
"""Dipinge i blocchi di terreno a pennellate: assets/graphics/tiles/*.png.

Ogni quadrante è un rombo isometrico 224x112 a filo del terreno (disegnato a
metà dimensione nel gioco); con flat=False si ottiene un blocco con 28 px di
fianchi, per eventuali aiuole rialzate. Su un colore di base si stendono centinaia di
pennellate ellittiche con tono e trasparenza variabili, poi la grana della
carta. Il risultato imita la tempera stesa a mano.

Uso:  python3 tools/paint_tiles.py
"""
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "assets/graphics/tiles"
W, H, D = 224, 112, 28          # rombo e spessore
TOP = [(112, 0), (224, 56), (112, 112), (0, 56)]
LEFT = [(0, 56), (112, 112), (112, 112 + D), (0, 56 + D)]
RIGHT = [(112, 112), (224, 56), (224, 56 + D), (112, 112 + D)]


def hexc(h: str):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def jitter(c, amount):
    return tuple(max(0, min(255, int(v + random.uniform(-amount, amount)))) for v in c)


def mask(poly) -> Image.Image:
    m = Image.new("L", (W, H + D), 0)
    ImageDraw.Draw(m).polygon(poly, fill=255)
    return m


def strokes(layer: Image.Image, area: Image.Image, palette, n, size, angle, angle_var, alpha):
    """Pennellate ellittiche dentro l'area, con colori dalla palette."""
    box = area.getbbox()
    for _ in range(n):
        x = random.uniform(box[0] - 6, box[2] + 6)
        y = random.uniform(box[1] - 4, box[3] + 4)
        length = random.uniform(size * 0.6, size * 1.4)
        thick = length * random.uniform(0.25, 0.45)
        col = jitter(hexc(random.choice(palette)), 10)
        a = int(random.uniform(*alpha))
        dab = Image.new("RGBA", (int(length * 2 + 4), int(length * 2 + 4)), (0, 0, 0, 0))
        cx, cy = dab.width / 2, dab.height / 2
        ImageDraw.Draw(dab).ellipse((cx - length / 2, cy - thick / 2, cx + length / 2, cy + thick / 2), fill=col + (a,))
        dab = dab.filter(ImageFilter.GaussianBlur(0.6))
        dab = dab.rotate(angle + random.uniform(-angle_var, angle_var), resample=Image.BICUBIC)
        layer.alpha_composite(dab, (int(x - cx), int(y - cy)))
    # tieni solo dentro l'area
    a = layer.getchannel("A")
    layer.putalpha(ImageChops.multiply(a, area))


def paper(img: Image.Image, strength=14):
    arr = np.asarray(img).astype(np.int16)
    noise = np.random.normal(0, strength / 3, (img.height, img.width, 1))
    coarse = Image.fromarray((np.random.rand(img.height // 6 + 1, img.width // 6 + 1) * 255).astype(np.uint8))
    coarse = np.asarray(coarse.resize((img.width, img.height), Image.BICUBIC)).astype(np.int16)[..., None]
    arr[..., :3] = np.clip(arr[..., :3] + noise + (coarse - 128) * strength / 255, 0, 255)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def block(top_base, top_palette, side_l, side_r, lip=None, extra=None, top_angle=-26.6, top_size=22, n=420, flat=True):
    img = Image.new("RGBA", (W, H + D), (0, 0, 0, 0))
    if flat:
        # quadrante a filo del terreno: niente fianchi
        side_l = side_r = None
        lip = None
    # fianchi: terra, pennellate quasi orizzontali, più scure in basso
    sides = [] if flat else [(LEFT, side_l, [side_l, "#73351b", "#8f4524"]), (RIGHT, side_r, [side_r, "#a85a34", "#8c4424"])]
    for poly, base, pal in sides:
        m = mask(poly)
        layer = Image.new("RGBA", img.size, hexc(base) + (255,))
        layer.putalpha(m)
        s = Image.new("RGBA", img.size, (0, 0, 0, 0))
        strokes(s, m, pal, 120, 12, 26.6 if poly is LEFT else -26.6, 12, (90, 170))
        layer.alpha_composite(s)
        # ombra in basso
        grad = Image.new("L", img.size, 0)
        gd = ImageDraw.Draw(grad)
        for i in range(D):
            gd.line([(0, 56 + i + (0 if poly is RIGHT else 0)), (W, 56 + i)], fill=0)
        img.alpha_composite(layer)
    if lip:
        lm = mask([(0, 56), (112, 112), (112, 120), (0, 64)])
        lr = mask([(112, 112), (224, 56), (224, 64), (112, 120)])
        for m in (lm, lr):
            s = Image.new("RGBA", img.size, (0, 0, 0, 0))
            strokes(s, m, lip, 60, 9, 0, 40, (150, 230))
            img.alpha_composite(s)
    # faccia superiore
    m = mask(TOP)
    top = Image.new("RGBA", img.size, hexc(top_base) + (255,))
    top.putalpha(m)
    s = Image.new("RGBA", img.size, (0, 0, 0, 0))
    strokes(s, m, top_palette, n, top_size, top_angle, 18, (70, 150))
    top.alpha_composite(s)
    if extra:
        extra(top, m)
    # luce morbida in alto a sinistra, ombra in basso a destra
    light = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(light)
    ld.polygon([(112, 0), (0, 56), (56, 56), (112, 20)], fill=(255, 248, 225, 34))
    ld.polygon([(112, 112), (224, 56), (180, 56), (112, 92)], fill=(60, 40, 20, 26))
    light = light.filter(ImageFilter.GaussianBlur(10))
    light.putalpha(ImageChops.multiply(light.getchannel("A"), m))
    top.alpha_composite(light)
    img.alpha_composite(top)
    # bordo appena più scuro, come il pigmento che si raccoglie
    edge = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(edge).line(TOP + [TOP[0]], fill=(70, 50, 30, 60), width=2)
    img.alpha_composite(edge.filter(ImageFilter.GaussianBlur(0.8)))
    img = paper(img)
    return img.crop((0, 0, W, H)) if flat else img


def furrows(dark, light):
    def draw(top: Image.Image, m: Image.Image):
        layer = Image.new("RGBA", top.size, (0, 0, 0, 0))
        for t in (0.18, 0.38, 0.58, 0.78):
            ax, ay = 112 + (0 - 112) * t, 0 + (56 - 0) * t
            for k in range(26):
                u = 0.06 + 0.88 * k / 25
                x, y = ax + 112 * u, ay + 56 * u
                for col, dy, size in ((dark, 4, 11), (light, 0, 10)):
                    dab = Image.new("RGBA", (30, 30), (0, 0, 0, 0))
                    c = jitter(hexc(col), 12) + (int(random.uniform(120, 200)),)
                    ImageDraw.Draw(dab).ellipse((15 - size / 2, 15 - size / 5, 15 + size / 2, 15 + size / 5), fill=c)
                    dab = dab.rotate(-26.6 + random.uniform(-10, 10), resample=Image.BICUBIC)
                    layer.alpha_composite(dab, (int(x - 15 + random.uniform(-1.5, 1.5)), int(y + dy - 15)))
        layer.putalpha(ImageChops.multiply(layer.getchannel("A"), m))
        top.alpha_composite(layer.filter(ImageFilter.GaussianBlur(0.5)))
    return draw


def stones_and(inner):
    """Sassolini chiari sparsi sulla terra, poi il resto (i solchi)."""
    def draw(top: Image.Image, m: Image.Image):
        inner(top, m)
        d = ImageDraw.Draw(top)
        for _ in range(7):
            while True:
                x, y = random.uniform(24, 200), random.uniform(12, 100)
                if abs(x - 112) / 112 + abs(y - 56) / 56 < 0.78:
                    break
            r = random.uniform(2.5, 4.5)
            d.ellipse((x - r, y - r * 0.6 + 1.2, x + r, y + r * 0.6 + 1.2), fill=(90, 50, 30, 120))
            d.ellipse((x - r, y - r * 0.6, x + r, y + r * 0.6), fill=hexc(random.choice(["#d8cbb5", "#c9b9a0", "#e3d8c4"])) + (255,))
    return draw


def flowers(top: Image.Image, m: Image.Image):
    d = ImageDraw.Draw(top)
    for _ in range(9):
        while True:
            x, y = random.uniform(24, 200), random.uniform(12, 100)
            if abs(x - 112) / 112 + abs(y - 56) / 56 < 0.8:
                break
        c = random.choice(["#f4ecd8", "#e9c46a", "#e8a7a0", "#c9b3d6"])
        for k in range(5):
            a = k * 2 * math.pi / 5
            d.ellipse((x + math.cos(a) * 3 - 2, y + math.sin(a) * 1.6 - 1.4, x + math.cos(a) * 3 + 2, y + math.sin(a) * 1.6 + 1.4), fill=hexc(c) + (220,))
        d.ellipse((x - 1.2, y - 1, x + 1.2, y + 1), fill=hexc("#c98a2e") + (255,))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    grass_pal = ["#9cc254", "#8ab449", "#b2cf68", "#7fa840", "#c4d27a", "#a5c45a"]
    lip = ["#6f9a3a", "#7fa840", "#628a33"]
    random.seed(3); np.random.seed(3)
    block("#98bf52", grass_pal, "#8a4122", "#a3542e", lip=lip).save(OUT / "grass.png")
    random.seed(5); np.random.seed(5)
    block("#98bf52", grass_pal, "#8a4122", "#a3542e", lip=lip, extra=flowers).save(OUT / "grass_flowers.png")
    soil_pal = ["#ad5a33", "#9c4d2a", "#b8693f", "#934526"]
    random.seed(7); np.random.seed(7)
    block("#a8532e", soil_pal, "#7e3a1e", "#954626", extra=stones_and(furrows("#7e3a1e", "#c0744a")), n=260).save(OUT / "soil.png")
    wet_pal = ["#7f3c1f", "#71341a", "#8a4524", "#652e17"]
    random.seed(9); np.random.seed(9)
    block("#7a391d", wet_pal, "#5f2b15", "#72351a", extra=stones_and(furrows("#55260f", "#965030")), n=260).save(OUT / "soil_wet.png")
    print("blocchi dipinti in", OUT)


if __name__ == "__main__":
    main()
