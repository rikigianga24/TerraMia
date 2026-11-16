#!/usr/bin/env python3
"""Copre una scritta dipinta su un cartello con un foglio di carta inchiodato,
così il gioco può scriverci sopra il testo tradotto (tr("LAND_SIGN")).

Uso:
    python3 tools/sign_paper.py IMMAGINE USCITA X1,Y1 X2,Y2 X3,Y3 X4,Y4

I quattro angoli del foglio, in senso orario dall'alto a sinistra, seguono
l'inclinazione della tavola. Stampa il centro del foglio e l'angolo della
tavola: servono al gioco per mettere il testo (CARTELLO_* in scenes/farm/farm_overlay.gd).
"""
import math
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

PAPER = (243, 231, 200)
EDGE = (120, 92, 60)
NAIL = (70, 60, 52)


def main() -> None:
    if len(sys.argv) != 7:
        print(__doc__)
        sys.exit(1)
    img = Image.open(sys.argv[1]).convert("RGB")
    pts = [tuple(float(v) for v in a.split(",")) for a in sys.argv[3:7]]
    # ombra morbida sotto il foglio
    shadow = Image.new("L", img.size, 0)
    ImageDraw.Draw(shadow).polygon([(x + 6, y + 8) for x, y in pts], fill=110)
    shadow = shadow.filter(ImageFilter.GaussianBlur(6))
    dark = Image.new("RGB", img.size, (40, 25, 15))
    img = Image.composite(dark, img, shadow)
    # foglio con una leggera sfumatura (più chiaro in alto a sinistra) e bordo
    paper = Image.new("RGB", img.size, PAPER)
    yy, xx = np.mgrid[0:img.size[1], 0:img.size[0]]
    shade = 1.0 - 0.08 * ((xx - pts[0][0]) / max(1.0, pts[1][0] - pts[0][0])).clip(0, 1) \
        - 0.06 * ((yy - pts[0][1]) / 300.0).clip(0, 1)
    paper = Image.fromarray((np.asarray(paper).astype(float) * shade[..., None]).clip(0, 255).astype(np.uint8))
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    img.paste(paper, (0, 0), mask)
    d = ImageDraw.Draw(img)
    d.line(pts + [pts[0]], fill=EDGE, width=4)
    # chiodi agli angoli, un po' verso l'interno
    cx = sum(p[0] for p in pts) / 4
    cy = sum(p[1] for p in pts) / 4
    for x, y in pts:
        nx, ny = x + (cx - x) * 0.1, y + (cy - y) * 0.1
        d.ellipse([nx - 6, ny - 6, nx + 6, ny + 6], fill=NAIL)
    img.save(sys.argv[2])
    ang = math.atan2(pts[1][1] - pts[0][1], pts[1][0] - pts[0][0])
    width = math.dist(pts[0], pts[1])
    print(f"centro del foglio: {cx:.0f},{cy:.0f}  angolo: {ang:.3f} rad  larghezza: {width:.0f} px")


if __name__ == "__main__":
    main()
