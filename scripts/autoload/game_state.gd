extends Node
## Stato della partita: monete, esperienza, magazzino, quadranti, ordini, borgo.
##
## Tutti i timer sono timestamp Unix assoluti, quindi il tempo scorre anche
## a gioco chiuso: al rientro basta confrontarli con l'ora attuale.

signal changed  ## Qualsiasi modifica: HUD e salvataggio la ascoltano.
signal leveled_up(level: int)
signal toast(message: String)

const GRID_START := Vector2i(6, 6)

var coins: int = 30
var lire_oro: int = 0
var xp: int = 0
var level: int = 1
var espresso: int = 1
var moka_last_tick: float = 0.0

var inventory: Dictionary = {}       ## prodotto -> quantità
var plots: Dictionary = {}           ## "x,y" -> {"crop": id, "planted_at": unix}
var grid_size: Vector2i = GRID_START
var orders: Array = []               ## [{"giver", "items": {prodotto: qty}, "coins", "xp"}]
var restored: Array = []             ## id degli edifici restaurati
var productions: Dictionary = {}     ## edificio -> {"started_at": unix}


static func now() -> float:
	return Time.get_unix_time_from_system()


static func plot_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


# --- Avvio e progresso offline ---------------------------------------------

func new_game() -> void:
	coins = 30
	lire_oro = 0
	xp = 0
	level = 1
	espresso = 1
	moka_last_tick = now()
	inventory = {}
	plots = {}
	grid_size = GRID_START
	orders = []
	restored = []
	productions = {}
	refill_orders()
	changed.emit()


## Applica in un colpo il tempo passato a gioco chiuso.
## Le colture non hanno bisogno di nulla (timestamp assoluti); la moka sì.
func apply_offline_progress() -> void:
	tick_moka()


func tick_moka() -> void:
	var t := now()
	if espresso >= GameData.MOKA_MAX:
		moka_last_tick = t
		return
	var elapsed := t - moka_last_tick
	var made := int(elapsed / GameData.MOKA_INTERVAL)
	if made > 0:
		espresso = mini(espresso + made, GameData.MOKA_MAX)
		moka_last_tick += made * GameData.MOKA_INTERVAL
		if espresso >= GameData.MOKA_MAX:
			moka_last_tick = t
		changed.emit()


# --- Fattoria ---------------------------------------------------------------

func is_in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y


func get_plot(cell: Vector2i) -> Dictionary:
	return plots.get(plot_key(cell), {})


## Avanzamento 0..1 della coltura sul quadrante (0 se vuoto).
func plot_progress(cell: Vector2i) -> float:
	var p := get_plot(cell)
	if p.is_empty():
		return 0.0
	var duration := float(GameData.crop(p["crop"])["time"])
	return clampf((now() - float(p["planted_at"])) / duration, 0.0, 1.0)


func plot_seconds_left(cell: Vector2i) -> int:
	var p := get_plot(cell)
	if p.is_empty():
		return 0
	var duration := float(GameData.crop(p["crop"])["time"])
	return maxi(0, ceili(float(p["planted_at"]) + duration - now()))


func can_plant(cell: Vector2i, crop_id: String) -> bool:
	var c := GameData.crop(crop_id)
	return is_in_grid(cell) and get_plot(cell).is_empty() and not c.is_empty() \
		and int(c["level"]) <= level and coins >= int(c.get("seed_cost", 0))


func plant(cell: Vector2i, crop_id: String) -> bool:
	if not can_plant(cell, crop_id):
		if coins < int(GameData.crop(crop_id).get("seed_cost", 0)):
			toast.emit("Non hai abbastanza monete per i semi.")
		return false
	coins -= int(GameData.crop(crop_id).get("seed_cost", 0))
	plots[plot_key(cell)] = {"crop": crop_id, "planted_at": now()}
	changed.emit()
	return true


func harvest(cell: Vector2i) -> bool:
	var p := get_plot(cell)
	if p.is_empty() or plot_progress(cell) < 1.0:
		return false
	var c := GameData.crop(p["crop"])
	add_item(c["product"], int(c.get("yield", 1)))
	plots.erase(plot_key(cell))
	add_xp(int(c.get("xp", 1)))
	changed.emit()
	return true


# --- Magazzino --------------------------------------------------------------

func item_count(product: String) -> int:
	return int(inventory.get(product, 0))


func add_item(product: String, qty: int) -> void:
	inventory[product] = item_count(product) + qty


func has_items(items: Dictionary) -> bool:
	for product in items:
		if item_count(product) < int(items[product]):
			return false
	return true


func remove_items(items: Dictionary) -> void:
	for product in items:
		inventory[product] = item_count(product) - int(items[product])
		if inventory[product] <= 0:
			inventory.erase(product)


# --- Esperienza -------------------------------------------------------------

func add_xp(amount: int) -> void:
	xp += amount
	while level < GameData.MAX_PROTOTYPE_LEVEL and xp >= GameData.xp_for_level(level + 1):
		level += 1
		lire_oro += 1
		leveled_up.emit(level)
		toast.emit("Livello %d! +1 Lira d'oro" % level)


func xp_progress() -> float:
	var from := GameData.xp_for_level(level)
	var to := GameData.xp_for_level(level + 1)
	if to <= from:
		return 1.0
	return clampf(float(xp - from) / float(to - from), 0.0, 1.0)


# --- Bacheca degli ordini ---------------------------------------------------

func refill_orders() -> void:
	while orders.size() < GameData.ORDER_BOARD_SIZE:
		orders.append(_make_order())


func _make_order() -> Dictionary:
	var available: Array = []
	for id in GameData.plantable_crops(level):
		available.append(GameData.crop(id)["product"])
	if "mulino" in restored:
		available.append("farina")
	var items := {}
	var value := 0
	var n_products := 1 if randf() < 0.6 or available.size() < 2 else 2
	available.shuffle()
	for i in n_products:
		var product: String = available[i]
		var qty := randi_range(2, 5) if product != "farina" else randi_range(1, 2)
		items[product] = qty
		value += qty * _unit_value(product)
	return {
		"giver": GameData.ORDER_GIVERS.pick_random(),
		"items": items,
		"coins": int(value * 1.3),
		"xp": maxi(2, int(value / 4.0)),
	}


func _unit_value(product: String) -> int:
	if product == "farina":
		return 15
	for id in GameData.CROPS:
		var c: Dictionary = GameData.CROPS[id]
		if c["product"] == product:
			return int(c.get("sell_price", 1))
	return 1


func can_fulfill(index: int) -> bool:
	return index >= 0 and index < orders.size() and has_items(orders[index]["items"])


func any_order_ready() -> bool:
	for i in orders.size():
		if can_fulfill(i):
			return true
	return false


func fulfill_order(index: int) -> bool:
	if not can_fulfill(index):
		return false
	var order: Dictionary = orders[index]
	remove_items(order["items"])
	coins += int(order["coins"])
	add_xp(int(order["xp"]))
	orders.remove_at(index)
	refill_orders()
	toast.emit("%s ringrazia: +%d monete" % [order["giver"], int(order["coins"])])
	changed.emit()
	return true


# --- Borgo ------------------------------------------------------------------

func is_restored(building_id: String) -> bool:
	return building_id in restored


func can_restore(building_id: String) -> bool:
	var b := GameData.building(building_id)
	if b.is_empty() or not b.has("restore") or is_restored(building_id):
		return false
	return level >= int(b["level"]) and coins >= int(b["restore"]["coins"]) \
		and has_items(b["restore"]["items"])


func restore(building_id: String) -> bool:
	if not can_restore(building_id):
		return false
	var b := GameData.building(building_id)
	coins -= int(b["restore"]["coins"])
	remove_items(b["restore"]["items"])
	restored.append(building_id)
	add_xp(10)
	toast.emit("%s è tornato! %s" % [b["resident"], b["lines"][0]])
	changed.emit()
	return true


func production_progress(building_id: String) -> float:
	if not productions.has(building_id):
		return 0.0
	var recipe: Dictionary = GameData.building(building_id)["recipe"]
	var started := float(productions[building_id]["started_at"])
	return clampf((now() - started) / float(recipe["time"]), 0.0, 1.0)


func start_production(building_id: String) -> bool:
	var b := GameData.building(building_id)
	if not is_restored(building_id) or productions.has(building_id):
		return false
	if not has_items(b["recipe"]["in"]):
		toast.emit("Mancano gli ingredienti.")
		return false
	remove_items(b["recipe"]["in"])
	productions[building_id] = {"started_at": now()}
	changed.emit()
	return true


func collect_production(building_id: String) -> bool:
	if production_progress(building_id) < 1.0:
		return false
	var out: Dictionary = GameData.building(building_id)["recipe"]["out"]
	for product in out:
		add_item(product, int(out[product]))
	productions.erase(building_id)
	add_xp(2)
	changed.emit()
	return true


# --- Serializzazione --------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": 1,
		"saved_at": now(),
		"coins": coins,
		"lire_oro": lire_oro,
		"xp": xp,
		"level": level,
		"espresso": espresso,
		"moka_last_tick": moka_last_tick,
		"inventory": inventory,
		"plots": plots,
		"grid_size": [grid_size.x, grid_size.y],
		"orders": orders,
		"restored": restored,
		"productions": productions,
	}


func from_dict(d: Dictionary) -> void:
	coins = int(d.get("coins", 30))
	lire_oro = int(d.get("lire_oro", 0))
	xp = int(d.get("xp", 0))
	level = int(d.get("level", 1))
	espresso = int(d.get("espresso", 1))
	moka_last_tick = float(d.get("moka_last_tick", now()))
	inventory = {}
	for k in d.get("inventory", {}):
		inventory[k] = int(d["inventory"][k])
	plots = d.get("plots", {})
	var gs: Array = d.get("grid_size", [GRID_START.x, GRID_START.y])
	grid_size = Vector2i(int(gs[0]), int(gs[1]))
	orders = d.get("orders", [])
	restored = d.get("restored", [])
	productions = d.get("productions", {})
	refill_orders()
	changed.emit()
