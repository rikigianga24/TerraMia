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
from split_sheet import labels  # noqa: E402

SPRITES = ROOT / "assets/graphics/sprites"
PLANTS_JSON = ROOT / "assets/graphics/plants/plants.json"
TOL = 30.0
GROW = 3            ## si allarga la maschera: foglie e fiori staccati restano con la pianta
MIN_AREA = 150
## Ritaglio (matting): sotto BG_NEAR un pixel è sfondo; tra BG_NEAR e BG_FAR, se
## tocca lo sfondo, è un bordo misto pianta-sfondo e diventa semitrasparente.
BG_NEAR = 14.0
BG_FAR = 60.0
## Tasche di sfondo chiuse tra foglie e steli: zone fino a POCKET_NEAR dallo
## sfondo, di almeno POCKET_MIN pixel, luminose in media quanto lo sfondo e poco
## sature. Si guarda la luminosità perché il JPEG tinge di verde (a metà
## risoluzione) il grigio chiuso tra le foglie, ma ne conserva la luminosità;
## le parti chiare delle piante (bulbi, fiori bianchi) sono più chiare.
POCKET_NEAR = 40.0
POCKET_MIN = 4
POCKET_MEAN_L = 12.0
POCKET_MEAN_SAT = 30.0
SAME_SAT = 16.0     ## pixel praticamente identici allo sfondo: saturazione massima
FILL = 0.8          ## larghezza della pianta matura "tipica" del foglio rispetto al quadrante
MAX_FILL = 1.15     ## nessuna pianta matura più larga di così


def sheet_background(rgb: np.ndarray) -> np.ndarray:
    h, w, _ = rgb.shape
    return np.median(np.array([rgb[3, 3], rgb[3, w - 4], rgb[h - 4, 3], rgb[h - 4, w - 4]]), axis=0)


def blobs(img: Image.Image) -> tuple[list[tuple[int, int, int, int, int]], np.ndarray]:
    """Disegni del foglio: (x0, y0, x1, y1, etichetta) e la mappa delle etichette."""
    rgb = np.asarray(img.convert("RGB")).astype(float)
    bg = sheet_background(rgb)
    mask = np.sqrt(((rgb - bg) ** 2).sum(axis=2)) >= TOL
    grown = Image.fromarray(mask.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(GROW))
    lab, n = labels(np.asarray(grown) > 0)
    out = []
    for k in range(1, n + 1):
        ys, xs = np.nonzero((lab == k) & mask)
        if len(ys) >= MIN_AREA:
            out.append((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1, k))
    return out, lab


def cut_plant(rgb: np.ndarray, others: np.ndarray, bg: np.ndarray) -> Image.Image:
    """Ritaglia una pianta dal suo riquadro del foglio.

    - Sfondo: i pixel quasi del colore dello sfondo collegati al bordo, più le
      tasche di sfondo chiuse tra foglie e steli (abbastanza grandi da non
      essere un riflesso), più i pixel delle piante vicine ("others").
    - Bordo: i pixel che toccano lo sfondo e gli somigliano in parte sono un
      misto pianta-sfondo; diventano semitrasparenti e gli si toglie il grigio
      dello sfondo dal colore (niente alone chiaro intorno alle foglie sottili).
    """
    # lo sfondo del foglio non è uniforme (più chiaro al centro): si prende il
    # grigio della cornice del riquadro, dove c'è solo sfondo
    ring = np.concatenate([rgb[:4].reshape(-1, 3), rgb[-4:].reshape(-1, 3),
                           rgb[:, :4].reshape(-1, 3), rgb[:, -4:].reshape(-1, 3)])
    ring_d = np.sqrt(((ring - bg) ** 2).sum(axis=1))
    bg = np.median(ring[ring_d < 40], axis=0) if (ring_d < 40).sum() > 20 else bg
    d = np.sqrt(((rgb - bg) ** 2).sum(axis=2))
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    # sfondo collegato al bordo del riquadro
    lab, n = labels(d < BG_NEAR)
    border = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    outside = np.isin(lab, border[border > 0])
    # tasche chiuse di grigio neutro
    plab, pn = labels(d < POCKET_NEAR)
    flat = plab.ravel()
    size = np.bincount(flat, minlength=pn + 1)
    lum = rgb @ np.array([0.299, 0.587, 0.114])
    dl = np.abs(lum - float(bg @ np.array([0.299, 0.587, 0.114])))
    mean_l = np.bincount(flat, weights=dl.ravel(), minlength=pn + 1) / np.maximum(size, 1)
    mean_sat = np.bincount(flat, weights=sat.ravel(), minlength=pn + 1) / np.maximum(size, 1)
    pocket = (size >= POCKET_MIN) & (mean_l < POCKET_MEAN_L) & (mean_sat < POCKET_MEAN_SAT)
    pocket[0] = False
    # e ogni gruppetto di pixel praticamente identici allo sfondo, anche chiuso
    # (le piante non usano mai proprio quel grigio)
    same = (d < BG_NEAR) & (sat < SAME_SAT)
    slab, sn = labels(same)
    tiny = np.bincount(slab.ravel(), minlength=sn + 1) < 3
    tiny[0] = True
    background = outside | pocket[plab] | ~tiny[slab] | others
    # bordo misto: entro 2 pixel dallo sfondo
    near_bg = np.asarray(Image.fromarray(background.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(5))) > 0
    alpha = np.ones(d.shape)
    edge = near_bg & ~background
    alpha[edge] = np.clip((d[edge] - BG_NEAR) / (BG_FAR - BG_NEAR), 0.0, 1.0)
    alpha[background] = 0.0
    # colore senza la parte di sfondo: c = a * pianta + (1 - a) * sfondo
    a = np.maximum(alpha, 1e-3)[..., None]
    color = np.clip((rgb - (1.0 - a) * bg) / a, 0, 255)
    out = np.dstack([color, alpha * 255.0]).astype(np.uint8)
    img = Image.fromarray(out, "RGBA")
    bbox = img.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    return img.crop(bbox) if bbox else img


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
    sheet_rgb = np.asarray(sheet).astype(float)
    bg = sheet_background(sheet_rgb)
    crops = args[1:]
    found, lab = blobs(sheet)
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
        for i, (x0, y0, x1, y1, k) in enumerate(row):
            pad = 12
            bx0, by0 = max(x0 - pad, 0), max(y0 - pad, 0)
            bx1, by1 = min(x1 + pad, sheet.width), min(y1 + pad, sheet.height)
            region = lab[by0:by1, bx0:bx1]
            cut = cut_plant(sheet_rgb[by0:by1, bx0:bx1], (region > 0) & (region != k), bg)
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
