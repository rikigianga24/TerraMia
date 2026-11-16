#!/usr/bin/env python3
"""Porta nel gioco i fotogrammi di un'animazione disegnati in un foglio a
caselle (righe di riquadri con il bordo nero, sfondo bianco, scritte fuori o
dentro i riquadri).

Uso:
    python3 tools/import_frames.py FOGLIO ANIMALE RIGA:ANIMAZIONE[:N] ...

Le righe di caselle si contano dall'alto (da 0); N è quanti riquadri prendere
dalla riga (di serie tutti quelli non vuoti). Esempio:

    python3 tools/import_frames.py gallina_sud.jpg gallina 0:cammina_s 1:becca_s 2:ferma_s:1

Scrive assets/graphics/animals/<animale>/<animazione>_<i>.png e aggiorna
assets/graphics/animals/<animale>/anims.json:

    {"cammina_s": {"h": altezza tipica, "frames": [{"file": ..., "anchor": [x, y]}, ...]}, ...}

"anchor" è il punto d'appoggio nel fotogramma: in basso (le zampe) e, in
orizzontale, il centro del riquadro del foglio. Così l'animale resta fermo nel
punto in cui è disegnato e si muove solo come nel disegno (passo, beccata).
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from import_plants import cut_plant_white  # noqa: E402
from split_sheet import labels  # noqa: E402

OUT = ROOT / "assets/graphics/animals"
DARK = 90           ## un pixel di linea del riquadro è più scuro di così
LINE_FILL = 0.6     ## una riga (o colonna) è una linea se è scura per questa frazione
INSET = 7           ## pixel tolti dentro il bordo del riquadro
KEEP = 0.04         ## si tengono le macchie grandi almeno così rispetto alla più grande
## fogli senza riquadri (find_figures)
FIG_GROW = 5        ## allargamento della maschera (piccolo: le righe sono vicine)
FIG_MIN_H = 80      ## una figura è alta almeno così
FIG_TEXT_H = (0, 48)   ## altezza di una lettera delle scritte
FIG_ATTACH = 45     ## pezzetti staccati (semi, zolle) entro questa distanza vanno alla figura
FIG_ROW_GAP = 90    ## figure con il centro più vicino di così sono nella stessa riga


def runs(mask: np.ndarray) -> list[tuple[int, int]]:
    """Tratti consecutivi a True: [(inizio, fine)]."""
    out, start = [], None
    for i, v in enumerate(mask):
        if v and start is None:
            start = i
        if not v and start is not None:
            out.append((start, i))
            start = None
    if start is not None:
        out.append((start, len(mask)))
    return out


def find_cells(gray: np.ndarray) -> list[list[tuple[int, int, int, int]]]:
    """Righe di riquadri: per ognuna i riquadri (x0, y0, x1, y1), da sinistra."""
    dark = gray < DARK
    h, w = dark.shape
    # linee orizzontali: righe con un tratto scuro lungo
    # (un tratto continuo: le penne scure di tanti animali in fila non contano)
    longest = np.array([max((b - a for a, b in runs(r)), default=0) for r in dark])
    hlines = [int((a + b) / 2) for a, b in runs(longest > w * 0.12)]
    rows = []
    for top, bottom in zip(hlines, hlines[1:]):
        if bottom - top < 60:
            continue
        band = dark[top + 3:bottom - 3]
        vcols = [int((a + b) / 2) for a, b in runs(band.mean(axis=0) > LINE_FILL)]
        cells = [(x0, top, x1, bottom) for x0, x1 in zip(vcols, vcols[1:]) if x1 - x0 > 60]
        if cells:
            rows.append(cells)
    return rows


def find_figures(rgb: np.ndarray) -> tuple[list[list[tuple]], np.ndarray]:
    """Fogli senza riquadri: i disegni sono macchie sul bianco.

    1. Macchie con un allargamento minimo (FIG_GROW).
    2. Le scritte (lettere: alte FIG_TEXT_H, scure e grigie) si scartano.
    3. Le macchie alte almeno FIG_MIN_H sono figure; le altre (semi lanciati,
       terra che salta, il manico della zappa staccato) vanno alla figura più
       vicina, se è entro FIG_ATTACH pixel.
    4. Le figure si raggruppano in righe dall'alto.
    Restituisce le righe di (x0, y0, x1, y1, etichetta) e una mappa in cui ogni
    pixel disegnato ha l'etichetta della sua figura (0 = niente)."""
    lum = rgb @ np.array([0.299, 0.587, 0.114])
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    ink = (lum < 225) | (sat > 30)
    grown = np.asarray(Image.fromarray(ink.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(FIG_GROW))) > 0
    lab, n = labels(grown)
    flat = lab.ravel()
    inkf = ink.ravel()
    boxes = {}
    for k in range(1, n + 1):
        boxes[k] = None
    ys, xs = np.nonzero(ink)
    ks = lab[ys, xs]
    order = np.argsort(ks, kind="stable")
    ks, ys, xs = ks[order], ys[order], xs[order]
    cuts = np.flatnonzero(np.diff(ks)) + 1
    figs, small = [], []
    for part in np.split(np.arange(len(ks)), cuts):
        if len(part) == 0:
            continue
        k = int(ks[part[0]])
        py, px = ys[part], xs[part]
        x0, y0, x1, y1 = int(px.min()), int(py.min()), int(px.max()) + 1, int(py.max()) + 1
        h = y1 - y0
        if h < FIG_TEXT_H[1] and lum[py, px].mean() < 120 and sat[py, px].mean() < 45:
            continue     # lettera di una scritta (scura e grigia; semi e zolle sono marroni)
        if h >= FIG_MIN_H and len(part) >= 300:
            figs.append([x0, y0, x1, y1, k])
        else:
            small.append((x0, y0, x1, y1, k))
    owner = np.zeros(n + 1, dtype=np.int32)
    for f in figs:
        owner[f[4]] = f[4]
    for x0, y0, x1, y1, k in small:
        best, dist = None, FIG_ATTACH
        for f in figs:
            dx = max(f[0] - x1, x0 - f[2], 0)
            dy = max(f[1] - y1, y0 - f[3], 0)
            d = (dx * dx + dy * dy) ** 0.5
            if d < dist:
                best, dist = f, d
        if best is not None:
            owner[k] = best[4]
            best[0], best[1] = min(best[0], x0), min(best[1], y0)
            best[2], best[3] = max(best[2], x1), max(best[3], y1)
    fig_lab = np.where(ink, owner[lab], 0)
    figs = [tuple(f) for f in figs]
    figs.sort(key=lambda f: (f[1] + f[3]) / 2)
    rows: list[list[tuple]] = []
    for f in figs:
        cy = (f[1] + f[3]) / 2
        if rows and abs(cy - np.mean([(g[1] + g[3]) / 2 for g in rows[-1]])) < FIG_ROW_GAP:
            rows[-1].append(f)
        else:
            rows.append([f])
    return [sorted(r) for r in rows], fig_lab


def feet_y(img: Image.Image) -> tuple[float, float]:
    """Punto d'appoggio di una figura ritagliata: la x del baricentro e il
    fondo dei pixel nella fascia centrale (così la lama della zappa o i semi
    che cadono di lato non contano come piedi)."""
    a = np.asarray(img)[..., 3] > 100
    ys, xs = np.nonzero(a)
    cx = float(np.median(xs))
    half = (xs.max() - xs.min()) * 0.22
    band = np.abs(xs - cx) <= half
    return cx, float(ys[band].max())


def cut_frame(rgb: np.ndarray) -> Image.Image | None:
    """Ritaglia l'animale dal riquadro: sfondo trasparente, via le scritte."""
    bg = np.array([255.0, 255.0, 255.0])
    img, _ = cut_plant_white(rgb, np.zeros(rgb.shape[:2], dtype=bool), bg)
    a = np.asarray(img)[..., 3] > 40
    if a.sum() < 200:
        return None
    lab, n = labels(a)
    sizes = np.bincount(lab.ravel(), minlength=n + 1)
    sizes[0] = 0
    keep = sizes[lab] >= KEEP * sizes.max()
    arr = np.asarray(img).copy()
    arr[~keep] = 0
    return Image.fromarray(arr, "RGBA")


def _figure_frames(rgb: np.ndarray, lab: np.ndarray, row: list, folder: Path, animal: str, name: str) -> list:
    """Fotogrammi di una riga di figure senza riquadri. I piedi di tutti i
    fotogrammi stanno sulla stessa riga del foglio (la mediana): così il passo
    e il chinarsi restano come nel disegno."""
    cuts = []
    for x0, y0, x1, y1, k in row:
        pad = 10
        bx0, by0 = max(x0 - pad, 0), max(y0 - pad, 0)
        bx1, by1 = min(x1 + pad, rgb.shape[1]), min(y1 + pad, rgb.shape[0])
        region = rgb[by0:by1, bx0:bx1].copy()
        reg_lab = lab[by0:by1, bx0:bx1]
        # resta solo questa figura (con i suoi pezzetti): il resto diventa bianco
        region[reg_lab != k] = 255.0
        img = cut_frame(region)
        if img is None:
            continue
        bbox = img.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
        img = img.crop(bbox)
        cx, fy = feet_y(img)
        cuts.append((img, cx, by0 + bbox[1] + fy, by0 + bbox[1]))
    if not cuts:
        return []
    ground = float(np.median([c[2] for c in cuts]))
    frames = []
    for i, (img, cx, _, top) in enumerate(cuts):
        path = folder / f"{name}_{i}.png"
        img.save(path)
        frames.append({"file": f"res://assets/graphics/animals/{animal}/{path.name}",
                       "anchor": [round(cx, 1), round(ground - top, 1)]})
    return frames


def main() -> None:
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(1)
    sheet = Image.open(sys.argv[1]).convert("RGB")
    animal = sys.argv[2]
    rgb = np.asarray(sheet).astype(float)
    rows = find_cells(np.asarray(sheet.convert("L")))
    figures = not rows
    if figures:
        rows, fig_lab = find_figures(rgb)
        print("righe trovate:", [len(r) for r in rows])
    folder = OUT / animal
    folder.mkdir(parents=True, exist_ok=True)
    manifest = folder / "anims.json"
    anims = json.loads(manifest.read_text()) if manifest.exists() else {}
    for spec in sys.argv[3:]:
        parts = spec.split(":")
        row, name = int(parts[0]), parts[1]
        limit = int(parts[2]) if len(parts) > 2 else None
        frames = []
        if figures:
            frames = _figure_frames(rgb, fig_lab, rows[row][:limit], folder, animal, name)
        for x0, y0, x1, y1 in ([] if figures else rows[row]):
            if limit is not None and len(frames) >= limit:
                break
            cell = rgb[y0 + INSET:y1 - INSET, x0 + INSET:x1 - INSET]
            img = cut_frame(cell)
            if img is None:
                continue
            bbox = img.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
            img = img.crop(bbox)
            # appoggio: le zampe in basso, il centro del riquadro in orizzontale
            cx = (x1 - x0) / 2 - INSET - bbox[0]
            path = folder / f"{name}_{len(frames)}.png"
            img.save(path)
            frames.append({"file": f"res://assets/graphics/animals/{animal}/{path.name}",
                           "anchor": [round(cx, 1), float(img.height)]})
        for old in folder.glob(f"{name}_*.png"):
            if int(old.stem.rsplit("_", 1)[1]) >= len(frames):
                old.unlink()
        # altezza tipica (mediana) dei fotogrammi: serve al gioco per portare
        # tutte le animazioni alla stessa scala anche se i riquadri del foglio
        # hanno disegni di grandezza diversa
        heights = sorted(f["anchor"][1] for f in frames)
        anims[name] = {"h": heights[len(heights) // 2] if heights else 0.0, "frames": frames}
        print(f"{name}: {len(frames)} fotogrammi")
    manifest.write_text(json.dumps(anims, indent=1) + "\n")


if __name__ == "__main__":
    main()
