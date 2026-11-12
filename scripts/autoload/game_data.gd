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
	"arancio":     {"name": "Arancio",     "kind": "tree",  "time": 10 * HOUR, "product": "arance",     "level": 12,"seed_cost": 148,"sell_price": 80, "xp": 22,"yield": 3, "color": "f08a12"},
	"zafferano":   {"name": "Zafferano",   "kind": "crop",  "time": 1 * DAY,   "product": "zafferano",  "level": 12,"seed_cost": 57, "sell_price": 219,"xp": 34,"yield": 2, "color": "8a4fc0", "rare": true},
	"pistacchio":  {"name": "Pistacchio",  "kind": "tree",  "time": 1 * DAY,   "product": "pistacchi",  "level": 13,"seed_cost": 228,"sell_price": 200,"xp": 34,"yield": 3, "color": "93b04a", "rare": true},
}

## Edifici del borgo. Nel prototipo esiste solo il mulino.
## restore: costo del restauro (monete + prodotti).
## recipe: trasformazione sbloccata dopo il restauro.
const BUILDINGS := {
	"mulino": {
		"name": "Mulino",
		"resident": "Gino, il mugnaio",
		"level": 2,
		"prototype": true,
		"restore": {"coins": 60, "items": {"grano": 10}},
		"recipe": {"in": {"grano": 3}, "out": {"farina": 1}, "time": 2 * MIN},
		"lines": ["Piove? Non piove? Mamma mia!", "Allora... farina fresca!"],
	},
	"forno":           {"name": "Forno",                  "resident": "Rosa, la fornaia",       "level": 4},
	"ufficio_postale": {"name": "Ufficio postale",        "resident": "Beppe, il postino",      "level": 4},
	"frantoio":        {"name": "Frantoio",               "resident": "Aldo, il frantoiano",    "level": 5},
	"conserve":        {"name": "Bottega delle conserve", "resident": "Zia Carmela",            "level": 5},
	"caseificio":      {"name": "Caseificio",             "resident": "Mario, il casaro",       "level": 6},
	"cantina":         {"name": "Cantina",                "resident": "Sergio, il vignaiolo",   "level": 7},
	"gelateria":       {"name": "Gelateria",              "resident": "Luigi, il gelataio",     "level": 7},
	"pastificio":      {"name": "Pastificio",             "resident": "Nonna Pina",             "level": 8},
	"campanile":       {"name": "Campanile",              "resident": "Don Peppino, il parroco", "level": 8},
	"bar":             {"name": "Bar della piazza",       "resident": "Totò, il barista",       "level": 9},
	"osteria":         {"name": "Osteria",                "resident": "Franco, l'oste",         "level": 10},
	"pasticceria":     {"name": "Pasticceria",            "resident": "Lucia, la pasticcera",   "level": 11},
	"caldarroste":     {"name": "Caldarroste in piazza",  "resident": "Il caldarrostaio",       "level": 11},
	"bocce":           {"name": "Campo da bocce",         "resident": "I nonni del paese",      "level": 12},
}

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
## Annaffiare una pianta costa una goccia e toglie il 30% del tempo che manca.
## Si annaffia una volta per ciclo di crescita.
const WATER_INTERVAL := 90
const WATER_MAX := 20
const WATER_START := 10
const WATER_SPEEDUP := 0.3

## Concime: raddoppia il raccolto della pianta su cui lo spargi (una volta per ciclo).
const FERTILIZER_PRICE := 10
const FERTILIZER_MULTIPLIER := 2
const FERTILIZER_LEVEL := 2

const ORDER_BOARD_SIZE := 3
const ORDER_GIVERS := ["Gino", "Rosa", "Beppe", "Zia Carmela", "Nonna Pina"]


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


static func format_time(seconds: int) -> String:
	if seconds >= HOUR:
		return "%dh %02dm" % [seconds / HOUR, (seconds % HOUR) / MIN]
	return "%d:%02d" % [seconds / MIN, seconds % MIN]
