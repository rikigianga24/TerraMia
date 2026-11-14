# Prompt degli asset per Flux

Tutti gli asset di Terra Mia, da generare con Flux in locale. Sostituisce i
fogli di sprite fatti finora: **un asset per immagine**, stesso stile per tutti.

## Come si lavora

1. **Un'immagine per asset**, salvata col **nome del file indicato** (per
   esempio `grano_2.png`, `mulino_rudere.png`, `tex_grass.png`).
2. Metti tutte le immagini in una cartella, poi dalla cartella del progetto:

   ```bash
   python3 tools/import_flux.py CARTELLA
   ```

   Toglie lo sfondo, ritaglia, piega le texture nel rombo della griglia,
   aggiorna le piante e copia gli originali in `assets/graphics/source/flux/`.
   Poi in Godot gli asset nuovi si vedono subito (o `godot --headless --import`).
3. In alternativa carica le immagini su GitHub in `assets/graphics/source/flux/`
   e chiedi a Claude di importarle.

### Impostazioni consigliate

| | Flux dev | Flux schnell |
| --- | --- | --- |
| Passi | 25-30 | 4 |
| Guidance | 3.0-3.5 | 0 (non usata) |
| Dimensione oggetti e texture | 1024 x 1024 | 1024 x 1024 |
| Dimensione sfondi | 1536 x 640 | 1536 x 640 |

- **Niente prompt negativo**: Flux non lo usa. Tutto va scritto in positivo, in
  frasi semplici (come nei prompt qui sotto).
- **Coerenza dello stile**: usa sempre lo STILE qui sotto parola per parola.
  Per una famiglia di asset (i tre stadi di una pianta, rudere e restaurato)
  tieni **lo stesso seed** e cambia solo la parte finale.
- **Il passo migliore**: quando hai 15-20 immagini approvate, allena una LoRA
  di stile (per esempio con FluxGym o ai-toolkit) e aggiungi la sua parola
  chiave in testa al prompt. Da lì in poi lo stile resta identico.
- **Sfondo**: Flux non fa la trasparenza. Si chiede uno sfondo grigio chiaro
  uniforme e lo toglie lo script. Se in ComfyUI hai un nodo di rimozione dello
  sfondo (BiRefNet, RMBG), puoi salvare già PNG trasparenti: lo script li accetta.
- **Niente scritte**: Flux scrive bene, quindi tende a mettere insegne con
  lettere. Ogni prompt dice "no text"; se compare una scritta, rigenera.

## Blocchi da incollare

**STILE** (all'inizio di ogni prompt):

```
Stylized hand-painted casual mobile game asset, cozy Tuscan countryside, warm Mediterranean palette of terracotta, olive green, ochre, cream and soft sky blue, chunky readable shapes, clean dark brown outlines of medium thickness, soft painterly shading with gentle ambient occlusion, warm sunlight coming from the upper left, original design.
```

**OGGETTO** (alla fine dei prompt di oggetti, piante, edifici, personaggi):

```
A single object, centered, seen in isometric three-quarter view from above at about 35 degrees, fully visible with plenty of empty space around it, with only a soft round contact shadow underneath. Plain flat uniform light grey background, no ground, no scenery, no text, no letters, no watermark.
```

**TEXTURE** (alla fine dei prompt del terreno):

```
Seamless tileable texture seen straight from above, orthographic top-down view, flat even lighting, no perspective, no horizon, no objects sticking out, the pattern fills the whole square edge to edge, no text.
```

**ICONA** (alla fine dei prompt delle icone):

```
A single game interface icon, centered, slightly tilted three-quarter view, bold simple shape that reads well at 32 pixels, thick dark brown outline, plain flat uniform light grey background, no text, no letters.
```

Schema: `STILE` + descrizione + `OGGETTO` (o `TEXTURE` o `ICONA`).

---

## 1. Terreno (texture)

Quadrate, viste dall'alto: lo script le rende ripetibili e le piega nella
griglia isometrica. Prompt: `STILE` + descrizione + `TEXTURE`.

| File | Descrizione |
| --- | --- |
| `tex_grass` | Lush short green meadow grass, small tufts and subtle color variation. |
| `tex_grass_flowers` | Lush short green meadow grass with a few scattered tiny wildflowers in white, yellow and pink. |
| `tex_grass_wild` | Wild untended tall grass with a few small grey stones and dry stalks. |
| `tex_grass_dry` | Dry golden stubble field after harvest, short cut straw. |
| `tex_soil` | Freshly tilled terracotta-colored farm soil with straight parallel furrows running horizontally, a few small pale pebbles. |
| `tex_soil_wet` | The same tilled terracotta soil with straight horizontal furrows, darker and wet after watering, small shiny puddles in the furrows. |
| `tex_dirt` | Packed light brown dirt path with small stones. |
| `tex_road` | Light cream gravel country road surface (strada bianca), fine gravel with two faint wheel ruts running vertically. |
| `tex_road_puddles` | The same light gravel road with two faint vertical wheel ruts and a few small rain puddles and stones. |
| `tex_road_flowers` | The same light gravel road with two faint vertical wheel ruts and a few poppies and lavender sprigs along the edges. |
| `tex_sand` | Warm golden riverbank sand with small round pebbles. |
| `tex_cobbles` | Old Italian village cobblestone pavement, rounded pale beige stones of different sizes with thin dark joints. |
| `tex_water` | Calm clear turquoise river water with soft painted ripples and light reflections. |

## 2. Sfondi

1536 x 640. Prompt: `STILE` + descrizione (senza blocco finale).

| File | Descrizione |
| --- | --- |
| `cielo` | Wide panoramic summer sky over Tuscany, gradient from clear blue at the top to warm pale cream at the bottom, a soft glowing sun in the upper right, a few fluffy painted clouds, nothing else, no ground, no hills, no text. |
| `colline` | Wide panoramic landscape of rolling Tuscan hills in three layers fading into the distance, rows of cypress trees on the ridges, vineyards and olive groves as soft patterns, a small medieval hilltop village with a bell tower, sand-colored walls and terracotta roofs slightly right of center. Above the hills the background is plain flat uniform light grey instead of sky. The bottom fifth of the image is a flat uniform band of meadow green across the whole width. No text. |

## 3. Piante (tre stadi)

Per ogni pianta tre immagini, **stesso seed**: `<id>_0` (germoglio),
`<id>_1` (crescita), `<id>_2` (matura). Niente blocco di terra: la pianta sta
appoggiata, la terra la mette il gioco.

Prompt colture: `STILE` + `A <pianta> plant <stadio>, standing directly on the ground.` + `OGGETTO`

Prompt alberi e arbusti: `STILE` + `A <pianta> <stadio>, standing directly on the ground.` + `OGGETTO`

Stadi colture:
- `_0`: `as a tiny young sprout just coming out of the ground, two or three small fresh leaves`
- `_1`: `half grown, healthy green leaves, no fruit yet`
- `_2`: `fully grown and ripe, ready to harvest, with <frutto>`

Stadi alberi e arbusti:
- `_0`: `as a small young sapling with a few leaves`
- `_1`: `as a young leafy tree without fruit`
- `_2`: `as a mature tree full of ripe <frutto>`

| Id | Pianta (inglese) | Frutto maturo (`_2`) | Tipo |
| --- | --- | --- | --- |
| `grano` | durum wheat | golden ripe wheat ears | coltura |
| `lattuga` | lettuce | a big round head of crisp green lettuce | coltura |
| `pomodoro` | San Marzano tomato | clusters of long red ripe tomatoes on a small wooden stake | coltura |
| `carota` | carrot | bushy green tops and orange carrot shoulders showing | coltura |
| `basilico` | basil | lush bright green basil leaves | coltura |
| `fragola` | strawberry | bright red strawberries among the leaves | coltura |
| `zucchina` | zucchini | green zucchini and yellow zucchini flowers | coltura |
| `cipolla` | onion | round golden onions half out of the ground with green stalks | coltura |
| `carciofo` | artichoke | big purple-green artichoke heads | coltura |
| `patata` | potato | bushy potato plant with a few potatoes showing at the base | coltura |
| `melanzana` | eggplant | glossy dark purple eggplants | coltura |
| `aglio` | garlic | white garlic bulbs half out of the ground with long leaves | coltura |
| `peperoncino` | chili pepper | many small shiny red chili peppers | coltura |
| `rucola` | arugula | a dense tuft of jagged arugula leaves | coltura |
| `fagioli` | borlotti bean | climbing bean plant on two sticks with speckled bean pods | coltura |
| `finocchio` | fennel | a white fennel bulb with feathery green fronds | coltura |
| `origano` | oregano | a small bushy oregano plant with tiny pink flowers | coltura |
| `zucca` | pumpkin | a big orange pumpkin on a sprawling vine | coltura |
| `anguria` | watermelon | a big striped green watermelon on a sprawling vine | coltura |
| `zafferano` | saffron crocus | purple crocus flowers with bright red saffron threads | coltura |
| `ulivo` | olive tree | small black and green olives, silvery leaves, twisted trunk | albero |
| `vite` | grapevine on a wooden trellis | hanging bunches of dark purple grapes | albero |
| `fico` | fig tree | ripe purple figs among broad leaves | albero |
| `nocciolo` | hazelnut tree | clusters of hazelnuts | albero |
| `castagno` | chestnut tree | spiky green chestnut burrs | albero |
| `ciliegio` | cherry tree | bright red cherries | albero |
| `mandorlo` | almond tree | green almond fruits | albero |
| `pesco` | peach tree | ripe orange-pink peaches | albero |
| `limone` | lemon tree | bright yellow lemons | albero |
| `arancio` | orange tree | ripe orange oranges | albero |
| `pistacchio` | pistachio tree | clusters of pink-red pistachio nuts | albero |
| `rovo_more` | blackberry bush | ripe black blackberries | arbusto |
| `rosmarino` | rosemary bush | small pale blue rosemary flowers | arbusto |

## 4. Animali

Prompt: `STILE` + descrizione + `OGGETTO`. Tutti girati verso destra.

| File | Descrizione |
| --- | --- |
| `pulcino` | A tiny fluffy yellow chick, cute and round. |
| `gallina` | A plump brown farm hen with a red comb. |
| `vitellino` | A small cute calf, brown and white, big eyes. |
| `mucca` | A friendly brown and white dairy cow with a small bell on the collar. |
| `agnellino` | A tiny fluffy white lamb, cute. |
| `pecora` | A fluffy white sheep with a dark face. |

## 5. Persone

Prompt: `STILE` + descrizione + `OGGETTO`. Figure intere, girate verso destra.

| File | Descrizione |
| --- | --- |
| `contadino` | A young farmer in blue overalls, red checked shirt and straw hat, holding a hoe over his shoulder. |
| `abitante_uomo` | A middle-aged Italian villager man in a waistcoat and flat cap. |
| `abitante_donna` | A middle-aged Italian villager woman in a flowered dress and apron. |
| `anziano` | An old Italian man with a walking stick and white mustache. |
| `anziana` | An old Italian grandmother in a black dress with a shopping basket. |
| `turista` | A cheerful tourist with a sun hat, backpack and camera. |
| `ciclista` | A cyclist in a bright jersey and helmet riding a road bike. |
| `camperista` | A relaxed traveller in shorts carrying a folding chair. |
| `straniero` | A foreign traveller in a light shirt looking at a paper map. |

Ritratti degli abitanti, per le loro storie (`ritratto_<edificio>`). Prompt:
`STILE` + `Head and shoulders portrait of <persona>, friendly expression, facing the viewer.` +
`Plain flat uniform light grey background, no text.`

| File | Persona |
| --- | --- |
| `ritratto_mulino` | Gino the miller, big mustache, flour on his apron, worried about the weather |
| `ritratto_forno` | Rosa the baker, warm smile, white bandana, rosy cheeks |
| `ritratto_ufficio_postale` | Beppe the postman, cap and satchel, always in a hurry |
| `ritratto_conserve` | Aunt Carmela, curly grey hair, knowing smile, the village gossip |
| `ritratto_frantoio` | Aldo the olive oil miller, strong arms, sleeves rolled up |
| `ritratto_caseificio` | Mario the cheesemaker, white coat and cap |
| `ritratto_cantina` | Sergio the winemaker, sunburnt, holding a glass of red wine |
| `ritratto_gelateria` | Luigi the ice cream man, singing, striped shirt |
| `ritratto_pastificio` | Grandma Pina, flour on her hands, glasses, very caring |
| `ritratto_campanile` | Father Peppino the village priest, round glasses, gentle |
| `ritratto_bar` | Totò the barman, gesturing, football scarf |
| `ritratto_osteria` | Franco the innkeeper, apron, proud and a bit grumpy |
| `ritratto_pasticceria` | Lucia the pastry chef, pastry chef hat, sweet smile |
| `ritratto_caldarroste` | the chestnut roaster, wool hat, scarf, warm smile |
| `ritratto_bocce` | two old men playing bocce, laughing |

## 6. Edifici del borgo (rudere e restaurato)

Per ogni edificio due immagini con **lo stesso seed**:
`<id>_rudere` e `<id>_restaurato`. Prompt:

`STILE` + `<edificio>, <stato>. The building stands on a small square base of cobblestones that is exactly its footprint, with nothing outside it. Shop signs show only pictures, never letters.` + `OGGETTO`

Stati:
- rudere: `as an abandoned ruin, crumbling stone walls, collapsed or missing roof, broken wooden beams, ivy, rubble, faded colors`
- restaurato: `beautifully restored, sand-colored plaster or warm stone walls, terracotta tile roof, green wooden shutters, flower pots, lively and welcoming`

| Id | Edificio (inglese) |
| --- | --- |
| `mulino` | A small Tuscan stone windmill with canvas sails |
| `forno` | A village bakery with a wood-fired oven and a bread picture sign |
| `ufficio_postale` | A small village post office with a postal horn picture sign and a red letterbox |
| `conserve` | A small preserves shop with shelves of tomato sauce jars and a tomato picture sign |
| `frantoio` | An olive oil mill with a big stone millstone and terracotta oil jars |
| `caseificio` | A small dairy with wheels of pecorino cheese on wooden racks and milk churns |
| `cantina` | A stone wine cellar with a big arched wooden door, oak barrels and a grapevine over the entrance |
| `gelateria` | A small ice cream shop with a striped awning, a gelato counter and little round tables |
| `pastificio` | A pasta workshop with fresh pasta drying on wooden racks in front |
| `campanile` | A small Romanesque stone church with a rose window and a tall square bell tower beside the facade (bigger than the other buildings) |
| `bar` | A village café with small outdoor tables, a coffee cup picture sign and lemon trees in pots |
| `osteria` | A rustic tavern with a vine pergola and wooden tables outside |
| `pasticceria` | A pastry shop with almond biscuits in the window and a cake picture sign |
| `caldarroste` | A small roasted chestnut cart with a smoking brazier (smaller, single tile) |
| `bocce` | A flat bocce court with low wooden borders and a few bocce balls (no building) |

**Case del paese** (`casa_1` … `casa_8`), solo restaurate, stesso prompt degli
edifici con queste descrizioni:

| File | Casa |
| --- | --- |
| `casa_1` | A narrow tall two-story medieval stone house with a small balcony |
| `casa_2` | A sand-colored house with an outside stone staircase to the upper floor |
| `casa_3` | A house with a loggia with arches on the upper floor |
| `casa_4` | A small ochre house with green shutters and laundry hanging from a window |
| `casa_5` | A house with a small shop on the ground floor (vegetables in crates) |
| `casa_6` | A stone house with a small walled garden and a lemon tree |
| `casa_7` | A pink plaster house with flower boxes and a vine climbing the wall |
| `casa_8` | A corner house with a small tower room on top |

**Mura e piazza** (`STILE` + descrizione + `OGGETTO`):

| File | Descrizione |
| --- | --- |
| `mura_tratto` | A straight section of medieval stone town wall with battlements |
| `mura_torre` | A square medieval stone wall tower with battlements |
| `mura_porta` | A medieval town gate with a stone arch and a wooden door open |
| `fontana` | A round stone village fountain with water jets and a small bush ring |
| `bacheca` | A small wooden village notice board with a tiled roof and pinned paper notes, no writing |

## 7. Fattoria

`STILE` + descrizione + `OGGETTO`.

| File | Descrizione |
| --- | --- |
| `casale` | A Tuscan stone farmhouse with a terracotta roof, an outside staircase and flower pots |
| `pozzo` | An old round stone well with a wooden roof and a bucket |
| `falegnameria` | A small wooden carpenter's workshop with a workbench, planks and tools outside |
| `cucina` | A small rustic outdoor country kitchen house with a smoking chimney and a pergola |
| `forziere` | An old wooden treasure chest with brass bands, slightly glowing |
| `cartello_vendita` | A small wooden "for sale" signpost with a picture of a house, no letters |
| `balle_fieno` | Two round hay bales |
| `carretto_asino` | A wooden cart with vegetable crates pulled by a small grey donkey |
| `carro_cavallo` | A wooden farm wagon pulled by a brown horse |
| `auto_rossa` | A small red vintage Italian car from the 1960s |
| `auto_crema` | A small cream-colored vintage Italian car from the 1950s |
| `auto_azzurra` | A small light blue vintage Italian delivery van from the 1960s |
| `camper` | A white vintage camper van with a striped awning |
| `bici` | A vintage city bicycle with a basket |

## 8. Natura e decorazioni

`STILE` + descrizione + `OGGETTO`.

| File | Descrizione |
| --- | --- |
| `ulivo_albero_c` | A big old olive tree with a twisted trunk and silvery leaves |
| `cipresso` | A tall slender Italian cypress tree |
| `quercia` | A round leafy oak tree for a forest |
| `cespuglio_fiori` | A small round bush with pink flowers |
| `canne` | A clump of river reeds with brown cattails |
| `staccionata` | A short section of rustic wooden fence |
| `secchio` | A galvanized metal bucket |
| `barile` | A wooden barrel with iron hoops |
| `panchina` | A wooden garden bench |

## 9. Prodotti (`item_<prodotto>`)

Usati nella barra, nel negozio, negli ordini. Prompt: `STILE` + `<prodotto>` + `ICONA`.

| File | Prodotto |
| --- | --- |
| `item_grano` | a bundle of golden wheat ears |
| `item_lattuga` | a head of lettuce |
| `item_pomodori` | three red San Marzano tomatoes |
| `item_carote` | a bunch of carrots |
| `item_basilico` | a bunch of basil |
| `item_fragole` | a few strawberries |
| `item_zucchine` | two zucchini |
| `item_cipolle` | two golden onions |
| `item_carciofi` | two artichokes |
| `item_olive` | a small pile of black and green olives with a leaf |
| `item_patate` | a few potatoes |
| `item_melanzane` | an eggplant |
| `item_more` | a few blackberries |
| `item_aglio` | a garlic bulb |
| `item_peperoncini` | a bunch of red chili peppers |
| `item_uva` | a bunch of purple grapes |
| `item_rucola` | a bunch of arugula |
| `item_fagioli` | borlotti bean pods |
| `item_fichi` | two purple figs |
| `item_finocchi` | a fennel bulb |
| `item_rosmarino` | a sprig of rosemary |
| `item_nocciole` | a few hazelnuts |
| `item_origano` | a sprig of oregano |
| `item_zucche` | a small pumpkin |
| `item_castagne` | a few chestnuts |
| `item_ciliegie` | a pair of cherries |
| `item_mandorle` | a few almonds |
| `item_angurie` | a watermelon slice |
| `item_pesche` | a peach |
| `item_limoni` | two lemons with a leaf |
| `item_arance` | an orange with a leaf |
| `item_zafferano` | a small heap of saffron threads |
| `item_pistacchi` | a few pistachios |
| `item_farina` | a small burlap sack of flour |
| `item_pane` | a round rustic loaf of Tuscan bread |
| `item_passata` | a glass bottle of tomato passata |
| `item_olio` | a glass bottle of golden extra virgin olive oil |
| `item_pecorino` | a wheel of pecorino cheese with a cut wedge |
| `item_chianti` | a straw-covered fiasco bottle of red wine |
| `item_gelato` | a gelato cone with two scoops |
| `item_pasta_fresca` | a nest of fresh tagliatelle |
| `item_limoncello` | a small bottle of yellow limoncello |
| `item_cantucci` | a few almond cantucci biscuits |
| `item_caldarroste` | a paper cone of roasted chestnuts |
| `item_bruschetta` | a slice of bruschetta with tomatoes and basil |
| `item_pesto` | a small jar of green pesto |
| `item_pizza` | a margherita pizza |
| `item_uova` | two brown eggs |
| `item_latte` | a glass milk bottle |
| `item_latte_pecora` | a small metal milk can |

## 10. Icone dell'interfaccia (`icon_<nome>`)

Prompt: `STILE` + descrizione + `ICONA`.

| File | Descrizione |
| --- | --- |
| `icon_coin` | a shiny gold coin with a wheat ear engraved |
| `icon_nostalgia` | an old sepia photograph of a village with a small red heart on it |
| `icon_drop` | a blue water drop |
| `icon_espresso` | a small espresso cup on a saucer with steam |
| `icon_fertilizer` | a small burlap sack of fertilizer with a sprout |
| `icon_star` | a golden star |
| `icon_hand` | an open hand |
| `icon_hoe` | a garden hoe |
| `icon_watering_can` | a green watering can |
| `icon_seeds` | a small seed bag with seeds |
| `icon_shop` | a small market stall with a striped awning |
| `icon_farm` | a small red farmhouse |
| `icon_borgo` | a small hilltop village with a bell tower |
| `icon_close` | a round red button with a white cross |
| `icon_lock` | a padlock |
| `icon_settings` | a golden gear |
| `icon_biberon` | a baby animal feeding bottle |
| `icon_ant_moneta_romana` | an ancient Roman coin |
| `icon_ant_anfora` | an ancient terracotta amphora |
| `icon_ant_lucerna` | an ancient Roman oil lamp |
| `icon_ant_mosaico` | a fragment of ancient mosaic tiles |
| `icon_ant_fibula` | an ancient bronze brooch |
| `icon_ant_chiave_antica` | an old iron key |

---

## Cosa entra subito in gioco e cosa va collegato

Entrano senza toccare il codice: terreno, sfondi, piante, `pulcino`,
`gallina`, `vitellino`, `mucca`, `agnellino`, `pecora`, `contadino`, gli
edifici `<id>_rudere` / `<id>_restaurato`, `casa_1`…`casa_8`, `fontana`,
`casale`, `pozzo`, `balle_fieno`, `cipresso`, `ulivo_albero_c`,
`cespuglio_fiori`, `staccionata`, `panchina`, `item_<prodotto>` e le icone
`icon_*` che sostituiscono quelle esistenti.

Da collegare nel codice quando arrivano (oggi disegnati da codice): abitanti e
turisti a passeggio, ritratti, mura, veicoli, camper, bici, forziere,
cartello, falegnameria, cucina, `quercia`, `canne`, `secchio`, `barile`, icone
nuove (biberon, oggetti antichi), `tex_water`.
