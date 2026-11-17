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
  nella stessa vista isometrica dei quadranti del gioco: rombo 2:1, alto metà
  della larghezza (circa 26,6 gradi), come le basi degli edifici del nuovo stile.
- **Icone:** una per cella, ben distanziate.
- **Sorgenti:** i fogli originali vanno in `assets/graphics/source/`; gli
  script in `tools/` ne ritagliano gli sprite.

## Angolo isometrico nei prompt

La mappa usa quadranti 2:1, l'isometria classica dei giochi (scripts/world/iso.gd),
la stessa degli edifici del nuovo stile. In ogni prompt con mattonelle, basi o
edifici va scritto:

```
classic 2:1 isometric game view, ground footprint is a diamond half as tall as it is wide, light from the upper left
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

## Piante

Stile nuovo: fogli con una riga per pianta e gli stadi di crescita da sinistra
a destra (quanti se ne vuole, almeno 3), sullo stesso sfondo grigio uniforme,
**senza blocco di terra**: nel gioco la pianta poggia sulla terra arata del
campo, con la base al centro del quadrante. Le piante di una riga sono
disegnate alla stessa scala (il germoglio piccolo, la pianta matura grande).
I fogli stanno in `assets/graphics/source/piante/` e si importano con:

```bash
python3 tools/import_plants.py assets/graphics/source/piante/FOGLIO.jpg coltura1 coltura2 ... [--riga X,Y=N]
```

Le colture vanno nell'ordine delle righe ("-" salta una riga); un disegno grande
che scavalca due righe si assegna con `--riga`. Lo script scrive gli sprite
`pianta_<coltura>_<stadio>` e `assets/graphics/plants/plants.json`; il gioco
mostra l'ultimo stadio quando la pianta è pronta e divide gli altri sulla crescita.

| Foglio | Righe |
| --- | --- |
| `piante_5.jpg` | peperoncino, rucola, fagioli (`--secca`) |
| `piante_6.jpg` | patata, melanzana, aglio (`--secca`) |
| `piante_7.jpg` | zucchina, cipolla, carciofo (`--secca`) |
| `piante_8.jpg` | carota, basilico, fragola (`--secca`) |
| `pomodoro.png` | pomodoro (`--secca`; sfondo marrone, convertito dal webp) |
| `grano.jpg` | grano (`--secca`) |
| `alberi_1.jpg` | vite, ciliegio, castagno (`--secca --larghezza 1.3 --cancella 0,300,2000,350`: via le scritte) |
| `alberi_2.jpg` | ulivo, nocciolo, fico (`--secca --larghezza 1.3`) |
| `piante_9.jpg` | anguria, zafferano (`--secca --cancella 0,470,2000,532 --cancella 0,980,2000,1040`) |
| `alberi_vite_pergola.jpg` | vite a pergola (una riga, non importata: variante della vite di `alberi_1`) |
| `piante_1.jpg` … `piante_4.jpg` | fogli precedenti (sfondo grigio, senza la pianta secca): da lì viene ancora il finocchio (`piante_1.jpg peperoncino rucola fagioli finocchio --riga 1200,190=0 --riga 630,450=2 --riga 890,450=2`, `piante_4.jpg pomodoro grano - basilico`); vanno importati **prima** dei fogli nuovi, che sovrascrivono le colture in comune |

I fogli nuovi (5-8) hanno sfondo bianco, l'ombra morbida sotto la pianta e
nell'ultima colonna la pianta secca: con `--secca` diventa
`pianta_<coltura>_secca`, pronta per quando il gioco avrà le piante che seccano.
L'ombra diventa trasparente e la base della pianta è il centro dell'ombra.

Ancora nel vecchio stile: lattuga, origano, zucca, anguria, zafferano e gli
alberi e arbusti (ulivo, vite, arancio e gli altri).

## Animali animati

Fogli a caselle (riquadri col bordo nero su sfondo bianco), una riga per
animazione: camminata, beccata (o mangiare), posa ferma. Servono due direzioni:
di tre quarti verso il basso ("_s") e di profilo verso destra ("_e"); verso
sinistra il gioco le specchia. I fogli stanno in `assets/graphics/source/animali/`
e si importano con:

```bash
python3 tools/import_frames.py assets/graphics/source/animali/gallina_sud.jpg gallina 0:cammina_s 1:becca_s 2:ferma_s:1
python3 tools/import_frames.py assets/graphics/source/animali/gallina_est.jpg gallina 0:cammina_e 1:becca_e 2:ferma_e:1
```

Il contadino viene da fogli senza riquadri (figure sparse con le scritte
sotto): lo script se ne accorge, toglie le scritte, raccoglie semi e zolle
staccati con la figura vicina e mette i piedi di una riga sulla stessa linea.

```bash
python3 tools/import_frames.py assets/graphics/source/animali/contadino_zappa.jpg contadino 0:zappa
python3 tools/import_frames.py assets/graphics/source/animali/contadino_semina.jpg contadino 0:semina
python3 tools/import_frames.py assets/graphics/source/animali/contadino_cammina.jpg contadino 0:cammina 4:corre
```

Per i fogli a riquadri, lo script trova i riquadri dalle linee nere, ritaglia ogni fotogramma (via lo
sfondo e le scritte) e scrive `assets/graphics/animals/<animale>/anims.json`.
Nel gioco l'animale adulto girella nel suo quadrante, cammina, si ferma a
beccare o a guardarsi intorno (`_draw_wandering` in `scenes/farm/farm.gd`).
Per un animale nuovo bastano gli stessi nomi di animazione e la sua altezza in
`ANIMAL_H`.

## Terra coltivata in rilievo, veicoli, cartello

- **Terra coltivata:** `slab_soil.jpg` (una lastra di terra arata vista in
  isometria, su magenta) importata con `import_flux.py` dà la mattonella piatta
  e il blocco in rilievo `soil_block.png` (faccia di sopra + fianchi), più le
  versioni bagnate. In fattoria i quadranti coltivati stanno `SOIL_LIFT` pixel
  sopra il prato e le piante poggiano sul blocco.
- **Auto e bici:** più disegni in fila su magenta si dividono con
  `split_sheet.py FOGLIO 1 N CARTELLA nomi... --zoccolo` e si importano. Nomi:
  `auto_rossa`, `auto_spider`, `auto_blu`, `bici_rossa`, `bici_blu`,
  `bici_crema` (la tandem verde ha un difetto nel disegno e non si usa).
- **Cartello "In vendita":** il disegno ha una scritta in inglese; la si copre
  con un foglio di carta (`tools/sign_paper.py`, che stampa centro e angolo del
  foglio per `SIGN_PAPER` / `SIGN_ANGLE` in `farm.gd`) e il gioco ci scrive
  `tr("LAND_SIGN")`. Nei prompt: cartelli e insegne sempre senza scritte.

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
bagnata, sterrato, sponda). Le mattonelle vengono riportate sul rombo 2:1 del
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
