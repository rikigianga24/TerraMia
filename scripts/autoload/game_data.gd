extends Node
## Dati statici del gioco, presi dal documento di design.
##
## Tempi e livelli sono una proposta da bilanciare con i test.
## I valori economici di grano e pomodoro sono fissati a mano; gli altri
## vengono dalla stessa formula, da rifinire con i test:
##   seme = 1,5·√minuti (×4 per alberi e arbusti, che restano piantati)
##   valore del raccolto ≈ seme + 3·minuti^0,6, diviso per la resa
##   esperienza = 0,9·√minuti
## Gli animali restano fuori finché non ci sono i recinti.

## Crediti mostrati nelle impostazioni.
const CREATOR := "Riccardo"

const MIN := 60
const HOUR := 3600
const DAY := 86400

## kind: "crop" (si ripianta a ogni raccolto), "tree"/"bush" (resta piantato
## e rifà i frutti), "animal" (produce a ciclo continuo, va nutrito con grano:
## arriverà con i recinti). yield = pezzi per raccolto, color = grafica provvisoria.
const CROPS := {
	"grano":       {"name": "Grano",       "kind": "crop",  "time": 2 * MIN,   "product": "grano",      "level": 1, "seed_cost": 2,  "sell_price": 3,  "xp": 1, "yield": 2, "color": "e8c547"},
	"lattuga":     {"name": "Lattuga",     "kind": "crop",  "time": 5 * MIN,   "product": "lattuga",    "level": 1, "seed_cost": 3,  "sell_price": 5,  "xp": 2, "yield": 2, "color": "9ccf4f"},
	"pomodoro":    {"name": "Pomodoro",    "kind": "crop",  "time": 10 * MIN,  "product": "pomodori",   "level": 1, "seed_cost": 5,  "sell_price": 9,  "xp": 3, "yield": 2, "color": "d9412b"},
	"carota":      {"name": "Carota",      "kind": "crop",  "time": 15 * MIN,  "product": "carote",     "level": 2, "seed_cost": 6,  "sell_price": 11, "xp": 3, "yield": 2, "color": "ee8a2a"},
	"basilico":    {"name": "Basilico",    "kind": "crop",  "time": 30 * MIN,  "product": "basilico",   "level": 2, "seed_cost": 8,  "sell_price": 16, "xp": 5, "yield": 2, "color": "3f9b3a"},
	"gallina":     {"name": "Gallina",     "kind": "animal","time": 20 * MIN,  "product": "uova",       "level": 3, "seed_cost": 0,  "sell_price": 0,  "xp": 0, "yield": 0, "color": "f4f0e6"},
	"fragola":     {"name": "Fragola",     "kind": "crop",  "time": 40 * MIN,  "product": "fragole",    "level": 3, "seed_cost": 9,  "sell_price": 18, "xp": 6, "yield": 2, "color": "e0314f"},
	"zucchina":    {"name": "Zucchina",    "kind": "crop",  "time": 45 * MIN,  "product": "zucchine",   "level": 3, "seed_cost": 10, "sell_price": 20, "xp": 6, "yield": 2, "color": "4e8a32"},
	"cipolla":     {"name": "Cipolla",     "kind": "crop",  "time": 25 * MIN,  "product": "cipolle",    "level": 4, "seed_cost": 8,  "sell_price": 14, "xp": 4, "yield": 2, "color": "c9a0c8"},
	"carciofo":    {"name": "Carciofo",    "kind": "crop",  "time": 1 * HOUR,  "product": "carciofi",   "level": 4, "seed_cost": 12, "sell_price": 23, "xp": 7, "yield": 2, "color": "6f8f5a"},
	"ulivo":       {"name": "Ulivo",       "kind": "tree",  "time": 4 * HOUR,  "product": "olive",      "level": 4, "seed_cost": 92, "sell_price": 47, "xp": 14,"yield": 3, "color": "58683a"},
	"mucca":       {"name": "Mucca",       "kind": "animal","time": 1 * HOUR,  "product": "latte",      "level": 5, "seed_cost": 0,  "sell_price": 0,  "xp": 0, "yield": 0, "color": "ffffff"},
	"patata":      {"name": "Patata",      "kind": "crop",  "time": 1 * HOUR,  "product": "patate",     "level": 5, "seed_cost": 12, "sell_price": 23, "xp": 7, "yield": 2, "color": "c49a5a"},
	"melanzana":   {"name": "Melanzana",   "kind": "crop",  "time": 90 * MIN,  "product": "melanzane",  "level": 5, "seed_cost": 14, "sell_price": 29, "xp": 9, "yield": 2, "color": "5b2a6e"},
	"rovo_more":   {"name": "Rovo di more","kind": "bush",  "time": 2 * HOUR,  "product": "more",       "level": 5, "seed_cost": 64, "sell_price": 31, "xp": 10,"yield": 3, "color": "2c1d3f"},
	"aglio":       {"name": "Aglio",       "kind": "crop",  "time": 1 * HOUR,  "product": "aglio",      "level": 6, "seed_cost": 12, "sell_price": 23, "xp": 7, "yield": 2, "color": "efe8dc"},
	"peperoncino": {"name": "Peperoncino", "kind": "crop",  "time": 2 * HOUR,  "product": "peperoncini","level": 6, "seed_cost": 16, "sell_price": 35, "xp": 10,"yield": 2, "color": "c41e1e"},
	"vite":        {"name": "Vite",        "kind": "tree",  "time": 8 * HOUR,  "product": "uva",        "level": 6, "seed_cost": 132,"sell_price": 70, "xp": 20,"yield": 3, "color": "6a2c5e"},
	"rucola":      {"name": "Rucola",      "kind": "crop",  "time": 20 * MIN,  "product": "rucola",     "level": 7, "seed_cost": 7,  "sell_price": 13, "xp": 4, "yield": 2, "color": "4a7d2e"},
	"fagioli":     {"name": "Fagioli",     "kind": "crop",  "time": 90 * MIN,  "product": "fagioli",    "level": 7, "seed_cost": 14, "sell_price": 29, "xp": 9, "yield": 2, "color": "b5653a"},
	"fico":        {"name": "Fico",        "kind": "tree",  "time": 6 * HOUR,  "product": "fichi",      "level": 7, "seed_cost": 112,"sell_price": 59, "xp": 17,"yield": 3, "color": "7a4a6a"},
	"finocchio":   {"name": "Finocchio",   "kind": "crop",  "time": 2 * HOUR,  "product": "finocchi",   "level": 8, "seed_cost": 16, "sell_price": 35, "xp": 10,"yield": 2, "color": "dfe8c0"},
	"rosmarino":   {"name": "Rosmarino",   "kind": "bush",  "time": 3 * HOUR,  "product": "rosmarino",  "level": 8, "seed_cost": 80, "sell_price": 40, "xp": 12,"yield": 3, "color": "5d7f6a"},
	"nocciolo":    {"name": "Nocciolo",    "kind": "tree",  "time": 10 * HOUR, "product": "nocciole",   "level": 8, "seed_cost": 148,"sell_price": 80, "xp": 22,"yield": 3, "color": "9a6b3c"},
	"origano":     {"name": "Origano",     "kind": "crop",  "time": 1 * HOUR,  "product": "origano",    "level": 9, "seed_cost": 12, "sell_price": 23, "xp": 7, "yield": 2, "color": "6d8c3c"},
	"zucca":       {"name": "Zucca",       "kind": "crop",  "time": 3 * HOUR,  "product": "zucche",     "level": 9, "seed_cost": 20, "sell_price": 44, "xp": 12,"yield": 2, "color": "e27a1f"},
	"castagno":    {"name": "Castagno",    "kind": "tree",  "time": 12 * HOUR, "product": "castagne",   "level": 9, "seed_cost": 160,"sell_price": 89, "xp": 24,"yield": 3, "color": "7b4a26"},
	"ciliegio":    {"name": "Ciliegio",    "kind": "tree",  "time": 8 * HOUR,  "product": "ciliegie",   "level": 10,"seed_cost": 132,"sell_price": 70, "xp": 20,"yield": 3, "color": "b0142c"},
	"mandorlo":    {"name": "Mandorlo",    "kind": "tree",  "time": 12 * HOUR, "product": "mandorle",   "level": 10,"seed_cost": 160,"sell_price": 89, "xp": 24,"yield": 3, "color": "d8c09a"},
	"anguria":     {"name": "Anguria",     "kind": "crop",  "time": 4 * HOUR,  "product": "angurie",    "level": 11,"seed_cost": 23, "sell_price": 52, "xp": 14,"yield": 2, "color": "3d8c3a"},
	"pesco":       {"name": "Pesco",       "kind": "tree",  "time": 8 * HOUR,  "product": "pesche",     "level": 11,"seed_cost": 132,"sell_price": 70, "xp": 20,"yield": 3, "color": "f2a46b"},
	"limone":      {"name": "Limone",      "kind": "tree",  "time": 8 * HOUR,  "product": "limoni",     "level": 8, "seed_cost": 130,"sell_price": 60, "xp": 18,"yield": 3, "color": "f2d64b"},
	"arancio":     {"name": "Arancio",     "kind": "tree",  "time": 10 * HOUR, "product": "arance",     "level": 12,"seed_cost": 148,"sell_price": 80, "xp": 22,"yield": 3, "color": "f08a12"},
	"zafferano":   {"name": "Zafferano",   "kind": "crop",  "time": 1 * DAY,   "product": "zafferano",  "level": 12,"seed_cost": 57, "sell_price": 219,"xp": 34,"yield": 2, "color": "8a4fc0", "rare": true},
	"pistacchio":  {"name": "Pistacchio",  "kind": "tree",  "time": 1 * DAY,   "product": "pistacchi",  "level": 13,"seed_cost": 228,"sell_price": 200,"xp": 34,"yield": 3, "color": "93b04a", "rare": true},
}

## Edifici del borgo: il cuore del gioco. Ognuno ha un abitante che chiede
## aiuto per riaprirlo (STORY_<id> nelle traduzioni), un costo di restauro,
## gli abitanti che riporta in paese (pop: abitanti, commercianti, famiglie) e,
## una volta restaurato, una produzione ("recipe") o un effetto ("effect").
const BUILDINGS := {
	"mulino": {"level": 2, "restore": {"coins": 60, "items": {"grano": 10}}, "pop": [2, 1, 1],
		"recipe": {"in": {"grano": 3}, "out": {"farina": 1}, "time": 2 * MIN},
		"lines": ["Piove? Non piove? Mamma mia!", "Allora... farina fresca!"]},
	"forno": {"level": 3, "restore": {"coins": 120, "items": {"farina": 4, "grano": 10}}, "pop": [2, 1, 1],
		"recipe": {"in": {"farina": 2, "uova": 1}, "out": {"pane": 1}, "time": 10 * MIN}},
	"ufficio_postale": {"level": 4, "restore": {"coins": 150, "items": {"grano": 15, "pomodori": 6}}, "pop": [2, 1, 1],
		"effect": "tourism"},
	"conserve": {"level": 4, "restore": {"coins": 160, "items": {"pomodori": 15}}, "pop": [2, 1, 1],
		"recipe": {"in": {"pomodori": 4}, "out": {"passata": 1}, "time": 5 * MIN}},
	"frantoio": {"level": 5, "restore": {"coins": 220, "items": {"olive": 10}}, "pop": [3, 1, 1],
		"recipe": {"in": {"olive": 5}, "out": {"olio": 1}, "time": 15 * MIN}},
	"caseificio": {"level": 6, "restore": {"coins": 250, "items": {"latte": 4, "grano": 20}}, "pop": [2, 1, 1],
		"recipe": {"in": {"latte_pecora": 3}, "out": {"pecorino": 1}, "time": 20 * MIN}},
	"cantina": {"level": 7, "restore": {"coins": 300, "items": {"uva": 10}}, "pop": [3, 1, 1],
		"recipe": {"in": {"uva": 5}, "out": {"chianti": 1}, "time": 30 * MIN}},
	"gelateria": {"level": 7, "restore": {"coins": 220, "items": {"latte": 4, "fragole": 6}}, "pop": [2, 1, 1],
		"recipe": {"in": {"latte": 2, "fragole": 3}, "out": {"gelato": 1}, "time": 8 * MIN}},
	"pastificio": {"level": 8, "restore": {"coins": 280, "items": {"farina": 8, "uova": 6}}, "pop": [2, 1, 1],
		"recipe": {"in": {"farina": 2, "uova": 2}, "out": {"pasta_fresca": 1}, "time": 10 * MIN}},
	"campanile": {"level": 8, "restore": {"coins": 400, "items": {"grano": 20, "olio": 2}}, "pop": [1, 0, 1],
		"effect": "rating"},
	"bar": {"level": 9, "restore": {"coins": 300, "items": {"limoni": 8, "latte": 6}}, "pop": [2, 1, 1],
		"recipe": {"in": {"limoni": 5}, "out": {"limoncello": 1}, "time": 20 * MIN}},
	"osteria": {"level": 10, "restore": {"coins": 450, "items": {"passata": 3, "pasta_fresca": 3, "basilico": 5}}, "pop": [2, 1, 1],
		"effect": "tips"},
	"pasticceria": {"level": 11, "restore": {"coins": 400, "items": {"mandorle": 8, "farina": 6}}, "pop": [2, 1, 1],
		"recipe": {"in": {"mandorle": 3, "farina": 2, "uova": 2}, "out": {"cantucci": 1}, "time": 15 * MIN}},
	"caldarroste": {"level": 11, "restore": {"coins": 120, "items": {"castagne": 10}}, "pop": [1, 1, 0],
		"recipe": {"in": {"castagne": 4}, "out": {"caldarroste": 1}, "time": 5 * MIN}},
	"bocce": {"level": 12, "restore": {"coins": 200, "items": {"grano": 30}}, "pop": [4, 0, 1],
		"effect": "daily"},
}
## Abitanti rimasti nel borgo abbandonato all'inizio.
const START_POPULATION := 3
## Gli edifici che si aprono con la bacheca, senza restauro.
const ALWAYS_OPEN := ["bacheca"]

## --- Turismo ---------------------------------------------------------------
## Dopo TOURISM_FROM restauri arrivano i visitatori: chiedono prodotti tipici,
## pagano e lasciano una recensione (5 stelle se serviti, 2 se se ne vanno).
const TOURISM_FROM := 2
const TOURIST_TYPES := ["ciclisti", "turisti", "camperisti", "stranieri"]
const TOURIST_INTERVAL := 15 * MIN          ## uno ogni tanto, più spesso con più edifici
const TOURIST_PATIENCE := 3 * HOUR
const TOURIST_MAX := 4
const TOURIST_PAY := 1.5                     ## rispetto al prezzo di vendita
const REVIEWS_KEPT := 20
const BOCCE_DAILY := 40

## Esperienza totale necessaria per raggiungere ogni livello (indice = livello).
## L'ultima coltura (pistacchio) si sblocca al livello 13.
const XP_FOR_LEVEL := [0, 0, 12, 40, 90, 160, 250, 370, 520, 700, 920, 1180, 1480, 1830]
const MAX_LEVEL := 13

## Espresso: la moka di casa ne fa 1 ogni 2 ore, fino a 3.
const MOKA_INTERVAL := 2 * HOUR
const MOKA_MAX := 3

## Zappa: il contadino lavora un quadrante d'erba in 15 secondi.
## I lavori si mettono in coda e vanno avanti anche a gioco chiuso.
const PLOW_TIME := 15
const PLOW_QUEUE_MAX := 12
## Se true, dopo il raccolto di una coltura la terra torna erba e va rizappata.
const RETILL_AFTER_HARVEST := false
## Quadranti già lavorati a inizio partita (il tutorial ne usa 4).
const START_TILLED := [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3)]
const START_SEEDS := {"grano": 4}

## Gocce d'acqua: il pozzo ne riempie una ogni 90 secondi, fino a 20.
## Una pianta seminata resta un sacchetto di semi finché non la annaffi:
## l'acqua (una goccia) fa partire la crescita. Alberi e arbusti, dopo il
## raccolto, vanno annaffiati di nuovo per rifare i frutti.
const WATER_INTERVAL := 90
const WATER_MAX := 20
const WATER_START := 10

## Concime: raddoppia il raccolto della pianta su cui lo spargi (una volta per ciclo).
const FERTILIZER_PRICE := 10
const FERTILIZER_MULTIPLIER := 2
const FERTILIZER_LEVEL := 2

const ORDER_BOARD_SIZE := 3
const ORDER_GIVERS := ["Gino", "Rosa", "Beppe", "Zia Carmela", "Nonna Pina"]

## Mappa della fattoria: lotti di 6×6 quadranti, 3×3 lotti in tutto.
## Si parte dal lotto (0,0), in fondo tra il fiume (a sinistra) e il bosco
## (a destra); ci si allarga verso la strada, davanti.
const SECTOR_SIZE := 6
const WORLD_SECTORS := Vector2i(3, 3)
const START_SECTOR := Vector2i(0, 0)
## Prezzo dei lotti: monete, livello minimo e oggetti antichi. Si compra solo
## un lotto confinante con uno già tuo.
const SECTORS := {
	"1,0": {"coins": 150, "level": 3, "antiques": {"moneta_romana": 1, "anfora": 1}},
	"0,1": {"coins": 150, "level": 3, "antiques": {"moneta_romana": 1, "lucerna": 1}},
	"1,1": {"coins": 400, "level": 5, "antiques": {"anfora": 1, "mosaico": 2}},
	"2,0": {"coins": 400, "level": 5, "antiques": {"lucerna": 2, "fibula": 1}},
	"0,2": {"coins": 400, "level": 5, "antiques": {"moneta_romana": 2, "fibula": 1}},
	"2,1": {"coins": 900, "level": 7, "antiques": {"mosaico": 2, "chiave_antica": 1}},
	"1,2": {"coins": 900, "level": 7, "antiques": {"anfora": 2, "chiave_antica": 1}},
	"2,2": {"coins": 1600, "level": 9, "antiques": {"chiave_antica": 2, "mosaico": 2, "fibula": 2}},
}

## Oggetti antichi: servono a sbloccare i lotti. Si trovano a caso
## consegnando ordini, o nel forziere che compare ogni giorno sulla fattoria.
const ANTIQUES := {
	"moneta_romana": {"color": "d9a441"},
	"anfora": {"color": "c0603e"},
	"lucerna": {"color": "b98a5a"},
	"mosaico": {"color": "4f8fb0"},
	"fibula": {"color": "9aa6ad"},
	"chiave_antica": {"color": "7a5a2a"},
}
const ANTIQUE_ORDER_CHANCE := 0.3
## Forziere: uno al giorno, in un punto libero della fattoria.
const CHEST_ANTIQUES := Vector2i(1, 2)      ## da 1 a 2 oggetti
const CHEST_COINS := Vector2i(20, 60)

## --- Animali ----------------------------------------------------------------
## Si comprano da cuccioli e crescono con i biberon (uno ogni BOTTLE_COOLDOWN);
## da adulti si nutrono ("feed") e dopo "time" danno il loro prodotto.
const BIBERON_PRICE := 12
const BOTTLE_COOLDOWN := 5 * MIN
const ANIMALS := {
	"gallina": {"level": 3, "price": 40, "bottles": 3, "feed": {"grano": 1}, "product": "uova", "yield": 2, "time": 20 * MIN, "xp": 4},
	"mucca": {"level": 5, "price": 160, "bottles": 5, "feed": {"grano": 3}, "product": "latte", "yield": 1, "time": 1 * HOUR, "xp": 10},
	"pecora": {"level": 6, "price": 120, "bottles": 4, "feed": {"grano": 2}, "product": "latte_pecora", "yield": 1, "time": 90 * MIN, "xp": 8},
}

## --- Strutture, ricette e decorazioni -----------------------------------------
## Le strutture si comprano, si posizionano sulla fattoria (su quadranti liberi,
## non zappati) e fanno una ricetta alla volta.
const STRUCTURES := {
	"falegnameria": {"level": 3, "price": 150, "size": Vector2i(2, 2), "recipes": ["staccionata", "secchio", "barile", "panchina"]},
	"cucina": {"level": 4, "price": 250, "size": Vector2i(2, 2), "recipes": ["bruschetta", "pesto", "pizza"]},
}
## in: prodotti consumati; coins: costo in monete; espresso: tazzine consumate;
## out: cosa esce (decorazione per la falegnameria, prodotto per la cucina).
const RECIPES := {
	"staccionata": {"in": {}, "coins": 5, "espresso": 0, "time": 1 * MIN, "out": "staccionata", "xp": 1},
	"secchio": {"in": {}, "coins": 10, "espresso": 0, "time": 2 * MIN, "out": "secchio", "xp": 1},
	"barile": {"in": {}, "coins": 25, "espresso": 0, "time": 5 * MIN, "out": "barile", "xp": 2},
	"panchina": {"in": {}, "coins": 40, "espresso": 0, "time": 10 * MIN, "out": "panchina", "xp": 3},
	"bruschetta": {"in": {"pane": 1, "pomodori": 2, "olio": 1}, "coins": 0, "espresso": 1, "time": 5 * MIN, "out": "bruschetta", "xp": 8},
	"pesto": {"in": {"basilico": 3, "aglio": 1, "olio": 1}, "coins": 0, "espresso": 1, "time": 8 * MIN, "out": "pesto", "xp": 10},
	"pizza": {"in": {"farina": 2, "pomodori": 2, "basilico": 1}, "coins": 0, "espresso": 1, "time": 12 * MIN, "out": "pizza", "xp": 12},
}
const DECOR := ["staccionata", "secchio", "barile", "panchina"]
## Prezzo di vendita dei prodotti fatti in casa (e degli animali).
## Prodotti tipici, fatti in casa e degli animali: si vendono e piacciono ai turisti.
const SELL_PRICES := {
	"farina": 12, "pane": 45, "passata": 50, "olio": 90, "pecorino": 110, "chianti": 160,
	"gelato": 60, "pasta_fresca": 70, "limoncello": 120, "cantucci": 130, "caldarroste": 55,
	"bruschetta": 140, "pesto": 150, "pizza": 170,
	"uova": 6, "latte": 14, "latte_pecora": 16,
}


func crop(id: String) -> Dictionary:
	return CROPS.get(id, {})


func building(id: String) -> Dictionary:
	return BUILDINGS.get(id, {})


## Le piante si seminano nei campi; gli animali arriveranno con i recinti.
func is_plant(id: String) -> bool:
	return CROPS.has(id) and CROPS[id]["kind"] != "animal"


## Resta piantata dopo il raccolto e rifà i frutti (alberi e arbusti).
func is_perennial(id: String) -> bool:
	return CROPS.has(id) and CROPS[id]["kind"] in ["tree", "bush"]


## Tutte le piante in ordine di sblocco, con il livello richiesto.
func all_plants() -> Array[String]:
	var result: Array[String] = []
	for id in CROPS:
		if is_plant(id):
			result.append(id)
	return result


## Piante già sbloccate al livello dato.
func plantable_crops(level: int) -> Array[String]:
	var result: Array[String] = []
	for id in all_plants():
		if int(CROPS[id]["level"]) <= level:
			result.append(id)
	return result


func crop_for_product(product: String) -> String:
	for id in CROPS:
		if CROPS[id]["product"] == product:
			return id
	return ""


func xp_for_level(level: int) -> int:
	if level < XP_FOR_LEVEL.size():
		return XP_FOR_LEVEL[level]
	return XP_FOR_LEVEL[-1]


## Testi tradotti (le chiavi stanno in localization/translations.csv,
## generato da tools/translations_source.py).
func crop_name(id: String) -> String:
	return tr("CROP_" + id.to_upper())


func product_name(product: String) -> String:
	return tr("PROD_" + product.to_upper())


func building_name(id: String) -> String:
	return tr("BLD_" + id.to_upper())


func resident_name(id: String) -> String:
	return tr("RES_" + id.to_upper())


func building_line(id: String, n: int) -> String:
	return tr("LINE_%s_%d" % [id.to_upper(), n])


func animal_name(id: String, baby := false) -> String:
	return tr(("BABY_" if baby else "ANIMAL_") + id.to_upper())


func structure_name(id: String) -> String:
	return tr("STRUCT_" + id.to_upper())


func recipe_name(id: String) -> String:
	return tr("RECIPE_" + id.to_upper())


func is_decor_recipe(id: String) -> bool:
	return RECIPES[id]["out"] in DECOR


func footprint(kind: String, type: String) -> Vector2i:
	if kind == "structure":
		return STRUCTURES[type]["size"]
	return Vector2i(1, 1)


func building_story(id: String) -> String:
	return tr("STORY_" + id.to_upper())


func building_effect(id: String) -> String:
	return tr("EFFECT_" + str(BUILDINGS[id].get("effect", "")).to_upper())


## Prodotto che esce da un edificio del borgo, o "" se ha un effetto.
func building_product(id: String) -> String:
	var r: Dictionary = BUILDINGS.get(id, {}).get("recipe", {})
	return r["out"].keys()[0] if not r.is_empty() else ""


func max_population() -> int:
	var n := START_POPULATION
	for id in BUILDINGS:
		for v in BUILDINGS[id]["pop"]:
			n += int(v)
	return n


func antique_name(id: String) -> String:
	return tr("ANT_" + id.to_upper())


func world_size() -> Vector2i:
	return WORLD_SECTORS * SECTOR_SIZE


static func sector_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(cell.x / float(SECTOR_SIZE)), floori(cell.y / float(SECTOR_SIZE)))


static func sector_key(sector: Vector2i) -> String:
	return "%d,%d" % [sector.x, sector.y]


static func format_time(seconds: int) -> String:
	if seconds >= HOUR:
		return "%dh %02dm" % [seconds / HOUR, (seconds % HOUR) / MIN]
	return "%d:%02d" % [seconds / MIN, seconds % MIN]
