# Direzione artistica

> **Da novembre 2026 gli asset si generano con Flux, uno per immagine: i prompt
> aggiornati sono in [`asset_prompts.md`](asset_prompts.md).** Quello che segue
> resta come storia dei fogli fatti prima.

Tutte le illustrazioni del gioco (piante, icone, terreno, personaggi)
seguono questo prompt. Va usato così com'è per ogni nuovo foglio di sprite,
così lo stile resta uniforme.

## Prompt

```
Premium Italian farming game asset, stylized cartoon 2.5D, Tuscan countryside aesthetic, FarmVille 2 level quality, original artwork, chunky readable shapes, vibrant Mediterranean colors, terracotta roofs, olive trees, cypress trees, hand-painted shading, soft ambient occlusion, toy-like materials, highly readable at small scale, modular isometric tiles, warm sunlight, charming rural Italy atmosphere, polished casual game production quality, clean silhouettes, no text, transparent background.
```

"FarmVille 2 level quality" indica il livello di cura, non lo stile da
copiare: personaggi, edifici e oggetti devono essere originali.

## Fogli di sprite

- **Sfondo:** uniforme e chiaro (beige), oppure trasparente. Niente scritte vicino ai disegni.
  Se ci sono etichette, devono stare ben staccate (a sinistra o in alto).
- **Piante:** una riga per pianta e tre colonne per gli stadi: germoglio,
  crescita, maturazione. Ogni stadio sta sopra il proprio blocco di terra,
  nella stessa vista isometrica dei quadranti del gioco: rombo 3:2, alto due
  terzi della larghezza (circa 34 gradi), come le mattonelle di `terreno.webp`.
- **Icone:** una per cella, ben distanziate.
- **Sorgenti:** i fogli originali vanno in `assets/graphics/source/`; gli
  script in `tools/` ne ritagliano gli sprite.

## Angolo isometrico nei prompt

La mappa usa quadranti 3:2 (scripts/world/iso.gd). In ogni prompt con
mattonelle, basi o edifici va scritto:

```
isometric 3/4 view, ground footprint is a diamond two thirds as tall as it is wide (same angle as the previous ground tiles), light from the upper left
```

e non "2:1 isometric".

## Edifici

Stile nuovo: fogli di 12 edifici (3 righe x 4 colonne) su sfondo grigio
uniforme, vista isometrica di tre quarti, ognuno sulla sua base quadrata in
rilievo (lastra di ciottoli o di prato con il bordo di terra), tetti in coppi,
contorni scuri, colori caldi. I fogli stanno in `assets/graphics/source/edifici/`:

| Foglio | Contenuto |
| --- | --- |
| `ruderi.jpg` | ruderi (base di prato) |
| `botteghe.jpg` | botteghe restaurate (base di ciottoli) |
| `case_ciottoli.jpg` | case del paese, base di ciottoli (`casa_1`…`casa_12`, senza `casa_11`) |
| `case_prato.jpg` | le stesse case su base di prato (`casa_prato_*`, `casale`, `cucina`, `falegnameria`) |

Per portarli nel gioco si dividono in un'immagine per edificio e si importano:

```bash
python3 tools/split_sheet.py assets/graphics/source/edifici/FOGLIO.jpg 3 4 CARTELLA nome1 nome2 ... nome12
python3 tools/import_flux.py CARTELLA
```

Lo script toglie lo zoccolo sotto la base (i fianchi di terra o di pietra):
resta la superficie di ciottoli o di prato, che nel gioco poggia a filo del
terreno del lotto, con la punta in basso sull'angolo davanti. Con `--zoccolo`
si tiene. "-" al posto di un nome salta un disegno.

I nomi vanno per righe, da sinistra a destra (quelli usati sono in
`docs/asset_prompts.md`, sezione 6). Gli edifici del gioco usano
`<id>_rudere` / `<id>_restaurato`; quelli che nei fogli non hanno un disegno
proprio prendono il più simile (`SUBSTITUTES` in `scenes/borgo/borgo_map.gd`),
e le botteghe in più (`bottega_*`) stanno tra le case del paese.

## Palette di riferimento

- Terra coltivata: terracotta (#a8532e) con sassolini chiari.
- Erba: verde caldo e vivo (#8fb34a, #a5c45a).
- Legno: #9a6a3e. Tetti: coppi terracotta (#c0603e). Muri: sabbia (#f0d2a6).
- Interfaccia: crema (#fbf3e2), terracotta (#d0643c), verde oliva (#7c9a3c).

## Dal foglio al gioco

1. Salva il foglio (sfondo trasparente) in `assets/graphics/source/`.
2. `python3 tools/find_sprites.py assets/graphics/source/FOGLIO.webp anteprima.png`
   trova i disegni e salva un'anteprima con un numero su ciascuno.
3. Aggiungi i disegni che servono a `assets/graphics/sprites/sprites.json`
   (nome, foglio, riquadro): il modo più rapido è chiedere a Claude.
4. `python3 tools/cut_sprites.py` ritaglia tutto. Le piante vanno anche in
   `PLANTS` dentro lo script (coltura -> tre stadi).

Fogli attuali: `sheet_a.webp`, `sheet_b.webp`, `sheet_c.webp` (piante,
decorazioni, prodotti, attrezzi, terreni, personaggi) e `terreno.webp` (le 8
mattonelle: erba, erba fiorita, erba selvatica, erba secca, terra arata, terra
bagnata, sterrato, sponda). Le mattonelle vengono riportate sul rombo 3:2 del
gioco anche se il foglio ha un'angolazione diversa.

## Immagini con la scacchiera disegnata

Se il generatore consegna un JPG con lo "sfondo trasparente" a scacchi
disegnato dentro l'immagine, l'originale va in `assets/graphics/source/originali/`
e si pulisce con:

```
python3 tools/remove_checker.py assets/graphics/source/originali/FOGLIO.jpg assets/graphics/source/FOGLIO.png
```

Due disegni che si toccano nel foglio si separano in `sprites.json` con
`above_seam` / `below_seam` (la y approssimativa del punto di contatto): lo
script taglia lungo la linea dove si toccano meno pixel.
