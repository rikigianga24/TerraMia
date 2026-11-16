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
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from import_plants import cut_plant_white  # noqa: E402
from split_sheet import labels  # noqa: E402

OUT = ROOT / "assets/graphics/animals"
DARK = 90           ## un pixel di linea del riquadro è più scuro di così
LINE_FILL = 0.6     ## una riga (o colonna) è una linea se è scura per questa frazione
INSET = 7           ## pixel tolti dentro il bordo del riquadro
KEEP = 0.04         ## si tengono le macchie grandi almeno così rispetto alla più grande


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


def main() -> None:
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(1)
    sheet = Image.open(sys.argv[1]).convert("RGB")
    animal = sys.argv[2]
    rgb = np.asarray(sheet).astype(float)
    rows = find_cells(np.asarray(sheet.convert("L")))
    folder = OUT / animal
    folder.mkdir(parents=True, exist_ok=True)
    manifest = folder / "anims.json"
    anims = json.loads(manifest.read_text()) if manifest.exists() else {}
    for spec in sys.argv[3:]:
        parts = spec.split(":")
        row, name = int(parts[0]), parts[1]
        limit = int(parts[2]) if len(parts) > 2 else None
        frames = []
        for x0, y0, x1, y1 in rows[row]:
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
