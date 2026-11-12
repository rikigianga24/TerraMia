# Direzione artistica

Tutte le illustrazioni del gioco (piante, edifici, icone, terreno, personaggi)
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

Un foglio = 4 edifici, ognuno in due versioni affiancate: a sinistra il rudere,
a destra restaurato (stessa base, stessa dimensione, stessa posizione). Testo da
aggiungere dopo il prompt base:

```
Sprite sheet on a transparent background, 4 rows and 2 columns, wide empty spacing, no labels, no text anywhere (shop signs show only pictograms, never letters).
Isometric 3/4 view, ground footprint is a diamond two thirds as tall as it is wide (same angle as the previous ground tiles), light from the upper left. Every building stands on a small base that exactly fills a 2x2 tile footprint (cobblestone or grass), with no trees, people or extra props outside the footprint.
Left column: the building as an abandoned ruin, crumbling stone walls, collapsed or missing roof, wooden beams, ivy, rubble, faded colors, same footprint and size as the restored version.
Right column: the same building restored, sand-colored plaster or warm stone walls, terracotta tile roof, green wooden shutters, flower pots, cozy and lively.
Rows from top to bottom: [ELENCO]
```

Fogli previsti (inglese per il prompt, tra parentesi l'edificio del gioco):

1. a windmill with canvas sails (mulino); a village bakery with a wood-fired oven and a bread pictogram sign (forno); a small post office with a postal horn pictogram and a red letterbox (ufficio postale); an olive oil mill with a large stone millstone and olive jars (frantoio)
2. a preserves shop with jars of tomato sauce on shelves and a tomato pictogram sign (bottega delle conserve); a small dairy with wheels of cheese and milk churns (caseificio); a wine cellar with oak barrels at the door and a grape pictogram sign (cantina); an ice cream shop with a striped awning and an ice cream cone pictogram (gelateria)
3. a pasta workshop with pasta drying on wooden racks (pastificio); a small Romanesque church with a tall bell tower, on a 2x2 footprint (campanile); a village café with small outdoor tables and a coffee cup pictogram (bar della piazza); a rustic tavern with a vine pergola and wooden tables outside (osteria)
4. a pastry shop with almond biscuits in the window and a cake pictogram (pasticceria); a roasted chestnut cart with a small brazier, 1x1 footprint (caldarroste); a bocce court with low wooden borders and bocce balls, flat, 2x2 footprint (campo da bocce); a village notice board with a small tiled roof and paper notes, 1x1 footprint (bacheca)

Fattoria (stesso testo, ma solo la versione restaurata, una per cella in una
griglia 2x2): a stone farmhouse; a wooden barn with a small fence; a chicken coop with a tiny yard; a round stone granary silo with a wooden storage shed.

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

Fogli attuali: `sheet_a.webp`, `sheet_b.webp`, `sheet_c.webp` (piante, edifici,
decorazioni, prodotti, attrezzi, terreni, personaggi) e `terreno.webp` (le 8
mattonelle: erba, erba fiorita, erba selvatica, erba secca, terra arata, terra
bagnata, sterrato, sponda). Le mattonelle vengono riportate sul rombo 3:2 del
gioco anche se il foglio ha un'angolazione diversa.
