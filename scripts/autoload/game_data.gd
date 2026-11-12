extends Node
## Dati statici del gioco, presi dal documento di design.
##
## Tempi e livelli sono una proposta da bilanciare con i test.
## I campi economici (seed_cost, sell_price, xp, yield) sono valorizzati
## solo per le colture del prototipo (grano e pomodori): le altre restano
## a 0 finché non vengono bilanciate.

const MIN := 60
const HOUR := 3600
const DAY := 86400

## kind: "crop" (si ripianta a ogni raccolto), "tree"/"bush" (resta piantato),
## "animal" (produce a ciclo continuo, va nutrito con grano).
const CROPS := {
	"grano":       {"name": "Grano",        "kind": "crop",   "time": 2 * MIN,   "product": "grano",       "level": 1,  "prototype": true,  "seed_cost": 2, "sell_price": 3,  "xp": 1, "yield": 2},
	"lattuga":     {"name": "Lattuga",      "kind": "crop",   "time": 5 * MIN,   "product": "lattuga",     "level": 1},
	"pomodoro":    {"name": "Pomodoro",     "kind": "crop",   "time": 10 * MIN,  "product": "pomodori",    "level": 1,  "prototype": true,  "seed_cost": 5, "sell_price": 9,  "xp": 3, "yield": 2},
	"carota":      {"name": "Carota",       "kind": "crop",   "time": 15 * MIN,  "product": "carote",      "level": 2},
	"basilico":    {"name": "Basilico",     "kind": "crop",   "time": 30 * MIN,  "product": "basilico",    "level": 2},
	"gallina":     {"name": "Gallina",      "kind": "animal", "time": 20 * MIN,  "product": "uova",        "level": 3},
	"fragola":     {"name": "Fragola",      "kind": "crop",   "time": 40 * MIN,  "product": "fragole",     "level": 3},
	"zucchina":    {"name": "Zucchina",     "kind": "crop",   "time": 45 * MIN,  "product": "zucchine",    "level": 3},
	"cipolla":     {"name": "Cipolla",      "kind": "crop",   "time": 25 * MIN,  "product": "cipolle",     "level": 4},
	"carciofo":    {"name": "Carciofo",     "kind": "crop",   "time": 1 * HOUR,  "product": "carciofi",    "level": 4},
	"ulivo":       {"name": "Ulivo",        "kind": "tree",   "time": 4 * HOUR,  "product": "olive",       "level": 4},
	"mucca":       {"name": "Mucca",        "kind": "animal", "time": 1 * HOUR,  "product": "latte",       "level": 5},
	"patata":      {"name": "Patata",       "kind": "crop",   "time": 1 * HOUR,  "product": "patate",      "level": 5},
	"melanzana":   {"name": "Melanzana",    "kind": "crop",   "time": 90 * MIN,  "product": "melanzane",   "level": 5},
	"rovo_more":   {"name": "Rovo di more", "kind": "bush",   "time": 2 * HOUR,  "product": "more",        "level": 5},
	"aglio":       {"name": "Aglio",        "kind": "crop",   "time": 1 * HOUR,  "product": "aglio",       "level": 6},
	"peperoncino": {"name": "Peperoncino",  "kind": "crop",   "time": 2 * HOUR,  "product": "peperoncini", "level": 6},
	"vite":        {"name": "Vite",         "kind": "tree",   "time": 8 * HOUR,  "product": "uva",         "level": 6},
	"rucola":      {"name": "Rucola",       "kind": "crop",   "time": 20 * MIN,  "product": "rucola",      "level": 7},
	"fagioli":     {"name": "Fagioli",      "kind": "crop",   "time": 90 * MIN,  "product": "fagioli",     "level": 7},
	"fico":        {"name": "Fico",         "kind": "tree",   "time": 6 * HOUR,  "product": "fichi",       "level": 7},
	"finocchio":   {"name": "Finocchio",    "kind": "crop",   "time": 2 * HOUR,  "product": "finocchi",    "level": 8},
	"rosmarino":   {"name": "Rosmarino",    "kind": "bush",   "time": 3 * HOUR,  "product": "rosmarino",   "level": 8},
	"nocciolo":    {"name": "Nocciolo",     "kind": "tree",   "time": 10 * HOUR, "product": "nocciole",    "level": 8},
	"origano":     {"name": "Origano",      "kind": "crop",   "time": 1 * HOUR,  "product": "origano",     "level": 9},
	"zucca":       {"name": "Zucca",        "kind": "crop",   "time": 3 * HOUR,  "product": "zucche",      "level": 9},
	"castagno":    {"name": "Castagno",     "kind": "tree",   "time": 12 * HOUR, "product": "castagne",    "level": 9},
	"ciliegio":    {"name": "Ciliegio",     "kind": "tree",   "time": 8 * HOUR,  "product": "ciliegie",    "level": 10},
	"mandorlo":    {"name": "Mandorlo",     "kind": "tree",   "time": 12 * HOUR, "product": "mandorle",    "level": 10},
	"anguria":     {"name": "Anguria",      "kind": "crop",   "time": 4 * HOUR,  "product": "angurie",     "level": 11},
	"pesco":       {"name": "Pesco",        "kind": "tree",   "time": 8 * HOUR,  "product": "pesche",      "level": 11},
	"arancio":     {"name": "Arancio",      "kind": "tree",   "time": 10 * HOUR, "product": "arance",      "level": 12},
	"zafferano":   {"name": "Zafferano",    "kind": "crop",   "time": 1 * DAY,   "product": "zafferano",   "level": 12, "rare": true},
	"pistacchio":  {"name": "Pistacchio",   "kind": "tree",   "time": 1 * DAY,   "product": "pistacchi",   "level": 13, "rare": true},
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
## Il prototipo copre i livelli 1–3.
const XP_FOR_LEVEL := [0, 0, 12, 40, 90]
const MAX_PROTOTYPE_LEVEL := 3

## Espresso: la moka di casa ne fa 1 ogni 2 ore, fino a 3.
const MOKA_INTERVAL := 2 * HOUR
const MOKA_MAX := 3

const ORDER_BOARD_SIZE := 3
const ORDER_GIVERS := ["Gino", "Rosa", "Beppe", "Zia Carmela", "Nonna Pina"]


func crop(id: String) -> Dictionary:
	return CROPS.get(id, {})


func building(id: String) -> Dictionary:
	return BUILDINGS.get(id, {})


## Colture piantabili nel prototipo e già sbloccate al livello dato.
func plantable_crops(level: int) -> Array[String]:
	var result: Array[String] = []
	for id in CROPS:
		var c: Dictionary = CROPS[id]
		if c.get("prototype", false) and int(c["level"]) <= level:
			result.append(id)
	return result


func xp_for_level(level: int) -> int:
	if level < XP_FOR_LEVEL.size():
		return XP_FOR_LEVEL[level]
	return XP_FOR_LEVEL[-1]


func product_label(product: String) -> String:
	return product.capitalize()
