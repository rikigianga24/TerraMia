#!/usr/bin/env python3
"""Porta nel gioco un foglio di piante: una riga per pianta, gli stadi di
crescita da sinistra a destra, su sfondo uniforme, senza blocco di terra (la
pianta poggia sulla terra del campo).

Uso:
    python3 tools/import_plants.py FOGLIO coltura1 coltura2 ... [--riga X,Y=N ...] [--secca]
        [--cancella X0,Y0,X1,Y1 ...] [--larghezza F]

Le colture vanno nell'ordine delle righe, dall'alto; "-" salta una riga (per
esempio una pianta già presa da un altro foglio). Un disegno grande che
scavalca due righe si assegna a mano con --riga: il disegno che contiene il
punto X,Y del foglio va nella riga N (da 0). Con --secca l'ultima colonna è
la pianta secca: diventa pianta_<coltura>_secca e non è uno stadio.
--cancella copre col colore dello sfondo un rettangolo del foglio (per esempio
le scritte sotto i disegni). --larghezza è quanto è larga, in quadranti, la
pianta matura tipica del foglio (di serie 0.8; per gli alberi 1.3).

Lo sfondo può essere grigio uniforme o bianco con un'ombra morbida sotto la
pianta: in quel caso l'ombra diventa trasparente e la base della pianta è il
centro dell'ombra.

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
## Fogli su sfondo bianco (con l'ombra sotto la pianta): vedi cut_plant_white.
WHITE_BG = 235.0
WHITE_NEUTRAL_SAT = 22.0
WHITE_SHADOW_MIN_L = 120.0
PETAL_MAX = 150
PETAL_MIN_SAT = 10.0
WHITE_PURE_L = 236.0          ## bianco dello sfondo
WHITE_SHADOW_ZONE = 0.35      ## l'ombra sta in questa parte bassa del disegno
WHITE_SHADOW_GAIN = 1.6
WHITE_SHADOW_COLOR = (30.0, 22.0, 10.0)
WHITE_POCKET_L = 215.0       ## zone chiuse candidate: luminose ...
WHITE_POCKET_SAT = 30.0      ## ... e poco sature
## Si tolgono se in media molto chiare e quasi senza colore. Misurato sui
## fogli: le tasche di sfondo sono grandi (200-900 px) e grigio neutro
## (saturazione media 6-8); i petali bianchi sono piccoli (40-110 px) e un po'
## tinti (10-22). Le zone piccole si tolgono solo se proprio neutre.
WHITE_POCKET_MEAN_L = 232.0
WHITE_POCKET_MEAN_SAT = 12.5
WHITE_POCKET_MIN = 60
WHITE_POCKET_SMALL_SAT = 6.0
## Tasche tra foglie verdi: il JPEG le tinge di verde (saturazione fino a 22,
## quasi tutta verde); i petali invece tendono al giallo-crema, mai al verde.
WHITE_POCKET_GREEN_L = 240.0    ## tasche verdastre: molto chiare ...
WHITE_POCKET_GREEN = 4.0        ## ... con il verde sopra rosso e blu di almeno tanto ...
WHITE_POCKET_GREEN_SAT = 24.0   ## ... e poco sature
WHITE_DRY_POCKET_SAT = 18.0  ## piante secche: niente fiori, ogni tasca chiara si toglie
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


def cut_plant(rgb: np.ndarray, others: np.ndarray, bg: np.ndarray,
        no_flowers: bool = False) -> tuple[Image.Image, float | None]:
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
    if bg.mean() > WHITE_BG:
        return cut_plant_white(rgb, others, bg, no_flowers)
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
    return _trim(Image.fromarray(out, "RGBA")), None


def _trim(img: Image.Image) -> Image.Image:
    bbox = img.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    return img.crop(bbox) if bbox else img


def cut_plant_white(rgb: np.ndarray, others: np.ndarray, bg: np.ndarray,
        no_flowers: bool = False) -> tuple[Image.Image, float | None]:
    """Ritaglio per i fogli su sfondo bianco con l'ombra morbida sotto la pianta.

    - Fuori: il bianco e l'ombra grigia collegati al bordo (pixel neutri e
      chiari). Diventano un'ombra vera: nera e trasparente in proporzione a
      quanto sono scuri, così sulla terra del campo scuriscono invece di fare
      una chiazza grigia.
    - Bordo della pianta verso il bianco: semitrasparente, senza il bianco nel
      colore.
    - Tasche chiuse tra le foglie: si tolgono solo se bianche pure; i petali
      bianchi hanno sempre un po' di ombreggiatura o di tinta e restano.
    Restituisce anche la y della base (il centro dell'ombra), o None.
    """
    lum = rgb @ np.array([0.299, 0.587, 0.114])
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    d = np.sqrt(((rgb - bg) ** 2).sum(axis=2))
    # fuori: il bianco dappertutto, il grigio dell'ombra solo nella parte bassa
    # del disegno (dove sta l'ombra): più su un grigio chiaro è una foglia
    # argentata, come quelle dell'ulivo
    white = (sat < WHITE_NEUTRAL_SAT) & (lum > WHITE_PURE_L)
    neutral = (sat < WHITE_NEUTRAL_SAT) & (lum > WHITE_SHADOW_MIN_L)
    rows = np.arange(rgb.shape[0])[:, None]
    low = rows >= rgb.shape[0] * (1.0 - WHITE_SHADOW_ZONE)
    lab, _ = labels(white | (neutral & low))
    border = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    outside = np.isin(lab, border[border > 0]) | others
    plab, pn = labels((lum > WHITE_POCKET_L) & (sat < WHITE_POCKET_SAT))
    flat = plab.ravel()
    size = np.bincount(flat, minlength=pn + 1)
    mean_l = np.bincount(flat, weights=lum.ravel(), minlength=pn + 1) / np.maximum(size, 1)
    mean_s = np.bincount(flat, weights=sat.ravel(), minlength=pn + 1) / np.maximum(size, 1)
    def mean(v: np.ndarray) -> np.ndarray:
        return np.bincount(flat, weights=v.ravel(), minlength=pn + 1) / np.maximum(size, 1)
    greenish = ((mean(rgb[..., 1] - np.maximum(rgb[..., 0], rgb[..., 2])) > WHITE_POCKET_GREEN)
                & (mean_l > WHITE_POCKET_GREEN_L) & (mean_s < WHITE_POCKET_GREEN_SAT))
    # i petali toccano il centro giallo del fiore: le zone chiare lì vicino restano
    # centro del fiore: giallo-arancio, il rosso almeno quanto il verde (le foglie
    # giallo-verdi chiare hanno più verde)
    yellow = ((rgb[..., 0] > 170) & (rgb[..., 1] > 130) & (rgb[..., 2] < 110)
              & (rgb[..., 0] - rgb[..., 2] > 90) & (rgb[..., 0] >= rgb[..., 1] - 5))
    near_yellow = np.asarray(Image.fromarray(yellow.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(9))) > 0
    # misurato: i petali sono piccoli (fino a ~110 px) e un po' tinti (saturazione
    # media 10-20); una zona grande o grigio neutro vicino a un giallo (legno
    # chiaro, un fiore giallo) è sfondo
    petal = ((np.bincount(flat, weights=near_yellow.ravel().astype(float), minlength=pn + 1) > 0)
             & (size < PETAL_MAX) & (mean_s >= PETAL_MIN_SAT))
    if no_flowers:      # le piante secche non hanno fiori (e i baccelli secchi sono gialli)
        petal[:] = False
    pocket = (mean_l > WHITE_POCKET_MEAN_L) & ~petal & (
        ((size >= WHITE_POCKET_MIN) & (mean_s < WHITE_POCKET_MEAN_SAT))
        | ((size >= 10) & (mean_s < WHITE_POCKET_SMALL_SAT))
        | ((size >= 6) & greenish)
        | ((size >= 10) & (mean_s < WHITE_DRY_POCKET_SAT) & no_flowers))
    pocket[0] = False
    outside |= pocket[plab]
    bg_l = float(lum[outside & ~others].max()) if (outside & ~others).any() else 255.0
    # ombra: nero trasparente; il bianco pieno sparisce
    shade = np.clip((bg_l - lum) / bg_l * WHITE_SHADOW_GAIN, 0.0, 1.0)
    shade[others | pocket[plab]] = 0.0
    alpha = np.ones(d.shape)
    alpha[outside] = shade[outside]
    color = rgb.copy()
    color[outside] = WHITE_SHADOW_COLOR
    # bordo della pianta verso il bianco: quanto il pixel è scuro rispetto alla
    # pianta lì accanto (255 - canale più basso: il bianco vale 0); un pixel
    # scuro la metà della foglia vicina è mezza foglia e mezzo bianco
    near_out = np.asarray(Image.fromarray(outside.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(5))) > 0
    edge = near_out & ~outside
    dark = 255.0 - rgb.min(axis=2)
    inner = np.where(~near_out & ~outside, dark, 0.0)
    ref = np.asarray(Image.fromarray(np.clip(inner, 0, 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(9))).astype(float)
    ref = np.where(ref > 30.0, ref, np.maximum(dark, 1.0))
    a = np.clip(dark[edge] / ref[edge], 0.0, 1.0)
    alpha[edge] = np.maximum(a, shade[edge])
    am = np.maximum(alpha[edge], 1e-3)[:, None]
    color[edge] = np.clip((rgb[edge] - (1.0 - am) * bg) / am, 0, 255)
    out = np.dstack([color, alpha * 255.0]).astype(np.uint8)
    img = Image.fromarray(out, "RGBA")
    bbox = img.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    if not bbox:
        return img, None
    # base della pianta: il centro dell'ombra (pixel d'ombra nella parte bassa)
    shadow = outside & ~others & (shade > 0.04)
    ys = np.nonzero(shadow)[0]
    low = ys[ys > (bbox[1] + bbox[3]) / 2]
    base = float(np.median(low)) - bbox[1] if len(low) > 20 else None
    return img.crop(bbox), base


def main() -> None:
    args = sys.argv[1:]
    forced = {}
    withered = "--secca" in args
    args = [a for a in args if a != "--secca"]
    erase = []
    fill, max_fill = FILL, MAX_FILL
    while "--cancella" in args:
        i = args.index("--cancella")
        erase.append([int(v) for v in args[i + 1].split(",")])
        del args[i:i + 2]
    if "--larghezza" in args:
        i = args.index("--larghezza")
        fill = float(args[i + 1])
        max_fill = fill * MAX_FILL / FILL
        del args[i:i + 2]
    while "--riga" in args:
        i = args.index("--riga")
        point, row = args[i + 1].split("=")
        forced[tuple(int(v) for v in point.split(","))] = int(row)
        del args[i:i + 2]
    if len(args) < 2:
        print(__doc__)
        sys.exit(1)
    sheet = Image.open(args[0]).convert("RGB")
    # zone da ignorare (per esempio le scritte sotto i disegni): si coprono col colore dello sfondo
    for x0, y0, x1, y1 in erase:
        bgc = tuple(int(v) for v in sheet_background(np.asarray(sheet).astype(float)))
        sheet.paste(bgc, (x0, y0, x1, y1))
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
    for row in rows:
        row.sort(key=lambda b: b[0])
    # con --secca l'ultima colonna è la pianta secca: sprite a parte, non uno stadio
    dry = [row.pop() if withered else None for row in rows]
    finals = [r[-1][2] - r[-1][0] for r in rows]
    typical = float(np.median(finals))
    plants = json.loads(PLANTS_JSON.read_text()) if PLANTS_JSON.exists() else {}

    def cut(b: tuple, name: str, no_flowers: bool = False) -> dict:
        x0, y0, x1, y1, k = b
        pad = 12
        bx0, by0 = max(x0 - pad, 0), max(y0 - pad, 0)
        bx1, by1 = min(x1 + pad, sheet.width), min(y1 + pad, sheet.height)
        region = lab[by0:by1, bx0:bx1]
        img, base = cut_plant(sheet_rgb[by0:by1, bx0:bx1], (region > 0) & (region != k), bg, no_flowers)
        img.save(SPRITES / f"{name}.png")
        # base: il centro dell'ombra se c'è, altrimenti il fondo del disegno
        return {"file": f"res://assets/graphics/sprites/{name}.png",
                "anchor": [round(img.width / 2, 1), round(base if base is not None else img.height * 0.98, 1)]}

    for crop, row, final_w, dry_b in zip(crops, rows, finals, dry):
        if crop == "-":
            continue
        for old in SPRITES.glob(f"pianta_{crop}_*.png"):
            old.unlink()
        tile_w = max(typical / fill, final_w / max_fill)
        stages = []
        for i, b in enumerate(row):
            st = cut(b, f"pianta_{crop}_{i}")
            st.update({"tile_w": round(tile_w, 1), "sheet": Path(args[0]).name})
            stages.append(st)
        if dry_b is not None:
            cut(dry_b, f"pianta_{crop}_secca", no_flowers=True)
        plants[crop] = stages
        print(f"{crop}: {len(stages)} stadi" + (" + secca" if dry_b is not None else ""))
    PLANTS_JSON.write_text(json.dumps(plants, indent=2) + "\n")


if __name__ == "__main__":
    main()
