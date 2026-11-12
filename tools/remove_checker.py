#!/usr/bin/env python3
"""Toglie lo sfondo "a scacchi" disegnato dentro un'immagine.

Alcuni generatori di immagini, quando si chiede lo sfondo trasparente,
disegnano la scacchiera grigia dentro un JPG invece di lasciare il vuoto.
Questo script la riconosce (pixel grigi neutri dei due toni presi dal bordo)
e la rende trasparente, ma solo dove è collegata al bordo dell'immagine: le
parti grigie dei disegni (pietre, metallo) restano.

Uso:  python3 tools/remove_checker.py INGRESSO.jpg USCITA.png
"""
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SAT_MAX = 12      # quanto può essere "colorato" un pixel della scacchiera
TONE_TOL = 16     # distanza di luminosità da uno dei due toni


def checker_tones(rgb: np.ndarray):
    border = np.concatenate([rgb[:4].reshape(-1, 3), rgb[-4:].reshape(-1, 3),
                             rgb[:, :4].reshape(-1, 3), rgb[:, -4:].reshape(-1, 3)]).astype(float)
    sat = border.max(1) - border.min(1)
    lum = border.mean(1)[sat <= SAT_MAX]
    # due gruppi di luminosità: chiaro e scuro
    lo, hi = np.percentile(lum, 20), np.percentile(lum, 80)
    for _ in range(10):
        mid = (lo + hi) / 2
        lo, hi = lum[lum < mid].mean(), lum[lum >= mid].mean()
    return lo, hi


def _isolated_squares(like: np.ndarray) -> np.ndarray:
    """Quadretti della scacchiera rimasti chiusi dentro un disegno (tra le
    pale di un mulino, sotto un tavolo): macchie neutre quasi perfettamente
    quadrate. Pietre e metallo hanno forme irregolari e restano."""
    from collections import deque
    h, w = like.shape
    seen = np.zeros_like(like)
    out = np.zeros_like(like)
    ys, xs = np.nonzero(like)
    for y0, x0 in zip(ys, xs):
        if seen[y0, x0]:
            continue
        q = deque([(y0, x0)])
        seen[y0, x0] = True
        pts = []
        while q:
            y, x = q.popleft()
            pts.append((y, x))
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and like[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    q.append((ny, nx))
        if len(pts) < 60:
            continue
        py = [p[0] for p in pts]
        px = [p[1] for p in pts]
        bw, bh = max(px) - min(px) + 1, max(py) - min(py) + 1
        fill = len(pts) / (bw * bh)
        if fill > 0.8 and 0.6 < bw / bh < 1.6 and max(bw, bh) <= 70:
            for y, x in pts:
                out[y, x] = True
    return out


def remove(src: str, dst: str) -> None:
    img = Image.open(src).convert("RGB")
    rgb = np.asarray(img).astype(float)
    lo, hi = checker_tones(rgb)
    lum = rgb.mean(2)
    sat = rgb.max(2) - rgb.min(2)
    like = (sat <= SAT_MAX) & ((np.abs(lum - lo) <= TONE_TOL) | (np.abs(lum - hi) <= TONE_TOL))
    mask = Image.fromarray(np.where(like, 255, 0).astype(np.uint8), "L").copy()
    w, h = mask.size
    for x in range(0, w, 3):
        for y in (0, h - 1):
            if mask.getpixel((x, y)) == 255:
                ImageDraw.floodfill(mask, (x, y), 128)
    for y in range(0, h, 3):
        for x in (0, w - 1):
            if mask.getpixel((x, y)) == 255:
                ImageDraw.floodfill(mask, (x, y), 128)
    bg = np.asarray(mask) == 128
    bg |= _isolated_squares(like & ~bg)
    alpha = Image.fromarray(np.where(bg, 0, 255).astype(np.uint8), "L")
    # via il bordino di pixel misti lasciato dal JPG, poi bordo morbido
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.7))
    out = img.convert("RGBA")
    out.putalpha(alpha)
    out.save(dst)
    print(f"{dst}: toni scacchiera {lo:.0f} e {hi:.0f}, trasparente {bg.mean() * 100:.0f}%")


if __name__ == "__main__":
    remove(sys.argv[1], sys.argv[2])
