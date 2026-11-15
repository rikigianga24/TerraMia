#!/usr/bin/env python3
"""Divide un foglio di edifici (griglia regolare su sfondo uniforme) in
un'immagine per disegno, pronta per tools/import_flux.py.

Uso:
    python3 tools/split_sheet.py FOGLIO RIGHE COLONNE CARTELLA nome1 nome2 ...

I nomi vanno per righe, da sinistra a destra; "-" salta un disegno. Ogni
disegno viene riconosciuto come insieme di macchie diverse dallo sfondo, quindi
anche se sconfina un po' nella cella vicina resta intero; due disegni che si
toccano si separano lungo la linea dove il contatto è più sottile. Le macchie
degli altri disegni nel suo riquadro vengono ricoperte col colore dello sfondo.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

TOL = 38.0
MIN_AREA = 40      # macchie più piccole (granelli) si ignorano
PAD = 16


def labels(mask: np.ndarray) -> tuple[np.ndarray, int]:
    """Componenti connesse (4-vicini) di una maschera booleana."""
    h, w = mask.shape
    lab = np.zeros((h, w), dtype=np.int32)
    n = 0
    flat = mask.ravel()
    lflat = lab.ravel()
    for start in np.flatnonzero(flat):
        if lflat[start]:
            continue
        n += 1
        stack = [start]
        lflat[start] = n
        while stack:
            i = stack.pop()
            y, x = divmod(i, w)
            for j, ok in ((i - 1, x > 0), (i + 1, x < w - 1), (i - w, y > 0), (i + w, y < h - 1)):
                if ok and flat[j] and not lflat[j]:
                    lflat[j] = n
                    stack.append(j)
    return lab, n


def cut_line(profile: np.ndarray, center: float, cell: float) -> int:
    """Riga (o colonna) col minimo di pixel disegnati entro un quarto di cella dal bordo atteso."""
    a, b = int(center - cell * 0.25), int(center + cell * 0.25)
    return a + int(np.argmin(profile[a:b]))


def drop_fragments(crop: np.ndarray, bg: np.ndarray) -> np.ndarray:
    """Toglie i pezzi dei disegni vicini (per esempio la punta di un tetto della
    riga sotto) rimasti sotto la base. La base di terra è un rombo visto di
    tre quarti: il suo bordo inferiore è una V che va dagli angoli di sinistra e
    di destra fino alla punta in basso, e sotto non c'è mai altro disegno. Si
    ricava la V dal profilo inferiore (i pezzi estranei lo possono solo
    abbassare, quindi si prende la pendenza più bassa plausibile) e si cancella
    quello che sta sotto."""
    h, w, _ = crop.shape
    near = np.sqrt(((crop.astype(float) - bg) ** 2).sum(axis=2)) < TOL
    lab, _ = labels(near)
    border = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    solid = ~np.isin(lab, border[border > 0])
    cols = np.flatnonzero(solid.any(axis=0))
    if len(cols) < 40:
        return crop
    bottom = np.full(w, -1.0)
    for x in cols:
        bottom[x] = np.flatnonzero(solid[:, x])[-1]
    x0, x1 = cols[0], cols[-1]
    mid = (x0 + x1) / 2
    out = crop.copy()
    for corner, side in ((x0, np.arange(x0 + 10, int(mid))), (x1, np.arange(int(mid) + 1, x1 - 9))):
        side = side[bottom[side] >= 0]
        if len(side) < 10:
            continue
        # angolo: la media delle colonne più esterne, per non cadere su un pixel isolato
        near_corner = cols[np.abs(cols - corner) <= 4]
        y_corner = float(np.median(bottom[near_corner]))
        slopes = (bottom[side] - y_corner) / np.abs(side - corner)
        slope = float(np.percentile(slopes, 25))
        for x in side:
            limit = int(y_corner + slope * abs(x - corner) + 4)
            if limit < h:
                cut = solid[limit:, x]
                out[limit:, x][cut] = bg.astype(np.uint8)
    return out


def main() -> None:
    if len(sys.argv) < 6:
        print(__doc__)
        sys.exit(1)
    sheet, rows, cols, out = Path(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3]), Path(sys.argv[4])
    names = sys.argv[5:]
    if len(names) != rows * cols:
        sys.exit(f"servono {rows * cols} nomi, ne ho {len(names)}")
    img = Image.open(sheet).convert("RGB")
    rgb = np.asarray(img).astype(float)
    h, w, _ = rgb.shape
    bg = np.median(np.array([rgb[3, 3], rgb[3, w - 4], rgb[h - 4, 3], rgb[h - 4, w - 4]]), axis=0)
    mask = np.sqrt(((rgb - bg) ** 2).sum(axis=2)) >= TOL
    lab, n = labels(mask)
    # linee di taglio: dove il disegno è più sottile, vicino ai bordi attesi delle celle
    col_cut = [0] + [cut_line(mask.sum(axis=0), w * c / cols, w / cols) for c in range(1, cols)] + [w]
    cell_px = np.zeros((h, w), dtype=np.int32)
    for c in range(cols):
        x0, x1 = col_cut[c], col_cut[c + 1]
        prof = mask[:, x0:x1].sum(axis=1)
        row_cut = [0] + [cut_line(prof, h * r / rows, h / rows) for r in range(1, rows)] + [h]
        for r in range(rows):
            cell_px[row_cut[r]:row_cut[r + 1], x0:x1] = r * cols + c
    # una macchia quasi tutta in una cella resta intera; una a cavallo si taglia
    cell_of = np.full((h, w), -1, dtype=np.int32)
    ys, xs = np.nonzero(lab)
    ids = lab[ys, xs]
    cells = cell_px[ys, xs]
    order = np.argsort(ids, kind="stable")
    ids, cells, ys, xs = ids[order], cells[order], ys[order], xs[order]
    bounds = np.flatnonzero(np.diff(ids)) + 1
    for part in np.split(np.arange(len(ids)), bounds):
        if len(part) < MIN_AREA:
            continue
        counts = np.bincount(cells[part], minlength=rows * cols)
        main_cell = counts.argmax()
        if counts[main_cell] >= 0.9 * len(part):
            cell_of[ys[part], xs[part]] = main_cell
        else:
            cell_of[ys[part], xs[part]] = cells[part]
    out.mkdir(parents=True, exist_ok=True)
    src = np.asarray(img)
    for idx, name in enumerate(names):
        if name == "-":
            continue
        mine = cell_of == idx
        yy, xx = np.nonzero(mine)
        if len(yy) == 0:
            print(f"{name}: vuoto")
            continue
        y0, y1 = max(yy.min() - PAD, 0), min(yy.max() + PAD + 1, h)
        x0, x1 = max(xx.min() - PAD, 0), min(xx.max() + PAD + 1, w)
        crop = src[y0:y1, x0:x1].copy()
        crop[~mine[y0:y1, x0:x1] & mask[y0:y1, x0:x1]] = bg.astype(np.uint8)
        crop = drop_fragments(crop, bg)
        Image.fromarray(crop).save(out / f"{name}.png")
        print(f"{name}: {x1 - x0}x{y1 - y0}")


if __name__ == "__main__":
    main()
