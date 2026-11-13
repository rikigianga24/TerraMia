extends Node
## Stato della partita: monete, esperienza, magazzino, quadranti, ordini, borgo.
##
## Tutti i timer sono timestamp Unix assoluti, quindi il tempo scorre anche
## a gioco chiuso: al rientro basta confrontarli con l'ora attuale.

signal changed  ## Qualsiasi modifica: HUD e salvataggio la ascoltano.
signal leveled_up(level: int)
signal toast(message: String)
signal harvested(cell: Vector2i, product: String, qty: int)
signal planted(cell: Vector2i)
signal chest_opened(cell: Vector2i, antiques: Dictionary, coins: int)
signal sector_bought(sector: Vector2i)
signal building_restored(id: String)

var coins: int = 30
var nostalgie: int = 0
var xp: int = 0
var level: int = 1
var espresso: int = 1
var moka_last_tick: float = 0.0
var water: int = GameData.WATER_START
var water_last_tick: float = 0.0
var fertilizer: int = 0

var inventory: Dictionary = {}       ## prodotto -> quantità
var seeds: Dictionary = {}           ## coltura -> semi posseduti
var tilled: Dictionary = {}          ## "x,y" -> true: terra lavorata con la zappa
var plow_queue: Array = []           ## [{"cell": "x,y", "start": unix, "end": unix}]
var plots: Dictionary = {}           ## "x,y" -> {"crop", "planted_at", "watered", "fertilized", "harvests"}
var owned_sectors: Array = []        ## lotti 6×6 posseduti, come "x,y"
var antiques: Dictionary = {}        ## oggetto antico -> quantità
var chest: Dictionary = {}           ## forziere di oggi: {"cell": "x,y"}, vuoto se non c'è
var last_chest_day: String = ""      ## giorno (AAAA-MM-GG) dell'ultimo forziere comparso
var orders: Array = []               ## [{"giver", "items": {prodotto: qty}, "coins", "xp"}]
var restored: Array = []             ## id degli edifici restaurati
var productions: Dictionary = {}     ## edificio -> {"started_at": unix}
var placed: Array = []               ## oggetti sulla fattoria (vedi "Oggetti sulla fattoria")
var next_uid: int = 1
var decor_inv: Dictionary = {}       ## decorazione -> quante da posizionare
var biberon: int = 0
var tourists: Array = []             ## [{"type", "size", "items", "coins", "arrived", "leaves"}]
var next_tourist_at: float = 0.0
var reviews: Array = []              ## ultime recensioni, da 1 a 5 stelle
var visitors_today: int = 0
var visitors_day: String = ""
var last_bocce_day: String = ""


static func now() -> float:
	return Time.get_unix_time_from_system()


static func plot_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


static func key_to_cell(key: String) -> Vector2i:
	var parts := key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))


# --- Avvio e progresso offline ---------------------------------------------

func new_game() -> void:
	coins = 30
	nostalgie = 0
	xp = 0
	level = 1
	espresso = 1
	moka_last_tick = now()
	water = GameData.WATER_START
	water_last_tick = now()
	fertilizer = 0
	inventory = {}
	seeds = GameData.START_SEEDS.duplicate()
	tilled = {}
	for cell in GameData.START_TILLED:
		tilled[plot_key(cell)] = true
	plow_queue = []
	plots = {}
	owned_sectors = [GameData.sector_key(GameData.START_SECTOR)]
	antiques = {}
	chest = {}
	last_chest_day = ""
	placed = []
	next_uid = 1
	decor_inv = {}
	biberon = 0
	tourists = []
	next_tourist_at = 0.0
	reviews = []
	visitors_today = 0
	visitors_day = ""
	last_bocce_day = ""
	orders = []
	restored = []
	productions = {}
	refill_orders()
	changed.emit()


## Applica in un colpo il tempo passato a gioco chiuso.
## Le colture non hanno bisogno di nulla (timestamp assoluti); moka, pozzo,
## zappa e forziere del giorno sì.
func apply_offline_progress() -> void:
	tick_moka()
	tick_water()
	update_plowing()
	tick_chest()
	tick_tourism()


func tick_moka() -> void:
	var r := _regen(espresso, moka_last_tick, GameData.MOKA_INTERVAL, GameData.MOKA_MAX)
	if r[0] != espresso or r[1] != moka_last_tick:
		var gained: bool = r[0] != espresso
		espresso = r[0]
		moka_last_tick = r[1]
		if gained:
			changed.emit()


func tick_water() -> void:
	var r := _regen(water, water_last_tick, GameData.WATER_INTERVAL, GameData.WATER_MAX)
	if r[0] != water or r[1] != water_last_tick:
		var gained: bool = r[0] != water
		water = r[0]
		water_last_tick = r[1]
		if gained:
			changed.emit()


## Ricarica a tempo: restituisce [nuovo valore, nuovo ultimo tick].
func _regen(value: int, last_tick: float, interval: float, max_value: int) -> Array:
	var t := now()
	if value >= max_value:
		return [value, t]
	var made := int((t - last_tick) / interval)
	if made <= 0:
		return [value, last_tick]
	value = mini(value + made, max_value)
	last_tick = t if value >= max_value else last_tick + made * interval
	return [value, last_tick]


## Secondi alla prossima goccia (0 se il pozzo è pieno).
func water_seconds_to_next() -> int:
	if water >= GameData.WATER_MAX:
		return 0
	return maxi(0, ceili(water_last_tick + GameData.WATER_INTERVAL - now()))


# --- Terra e zappa ----------------------------------------------------------

## Dentro la mappa (posseduto o no).
func is_in_world(cell: Vector2i) -> bool:
	var w := GameData.world_size()
	return cell.x >= 0 and cell.y >= 0 and cell.x < w.x and cell.y < w.y


## Quadrante utilizzabile: dentro un lotto posseduto.
func is_in_grid(cell: Vector2i) -> bool:
	return is_in_world(cell) and is_sector_owned(GameData.sector_of(cell))


func is_sector_owned(sector: Vector2i) -> bool:
	return GameData.sector_key(sector) in owned_sectors


func is_tilled(cell: Vector2i) -> bool:
	return tilled.has(plot_key(cell))


func plow_job_index(cell: Vector2i) -> int:
	var key := plot_key(cell)
	for i in plow_queue.size():
		if plow_queue[i]["cell"] == key:
			return i
	return -1


func is_plow_queued(cell: Vector2i) -> bool:
	return plow_job_index(cell) >= 0


## Mette in coda la zappatura di un quadrante d'erba.
func queue_plow(cell: Vector2i) -> bool:
	if not is_in_grid(cell) or is_tilled(cell) or is_plow_queued(cell) or not object_at(cell).is_empty():
		return false
	if plow_queue.size() >= GameData.PLOW_QUEUE_MAX:
		toast.emit(tr("MSG_QUEUE_FULL"))
		return false
	var start := now()
	if not plow_queue.is_empty():
		start = maxf(start, float(plow_queue[-1]["end"]))
	plow_queue.append({"cell": plot_key(cell), "start": start, "end": start + GameData.PLOW_TIME})
	changed.emit()
	return true


func cancel_plow(cell: Vector2i) -> bool:
	var i := plow_job_index(cell)
	if i < 0:
		return false
	plow_queue.remove_at(i)
	_reschedule_plow_queue()
	changed.emit()
	return true


## Dopo una cancellazione i lavori successivi slittano in avanti.
func _reschedule_plow_queue() -> void:
	var t := now()
	for job in plow_queue:
		if float(job["start"]) <= t:
			t = float(job["end"])  # lavoro già iniziato: resta com'è
			continue
		job["start"] = t
		job["end"] = t + GameData.PLOW_TIME
		t = float(job["end"])


## Sposta tra la terra lavorata i quadranti la cui zappatura è finita.
func update_plowing() -> void:
	var t := now()
	var done := 0
	while not plow_queue.is_empty() and float(plow_queue[0]["end"]) <= t:
		tilled[plow_queue[0]["cell"]] = true
		plow_queue.pop_front()
		done += 1
	if done > 0:
		add_xp(done)  # 1 punto esperienza per quadrante lavorato
		changed.emit()


## Lavoro in corso (o vuoto se il contadino è libero).
func current_plow_job() -> Dictionary:
	if plow_queue.is_empty():
		return {}
	var job: Dictionary = plow_queue[0]
	return job if float(job["start"]) <= now() else {}


func plow_progress(cell: Vector2i) -> float:
	var i := plow_job_index(cell)
	if i < 0:
		return 0.0
	var job: Dictionary = plow_queue[i]
	return clampf((now() - float(job["start"])) / GameData.PLOW_TIME, 0.0, 1.0)


# --- Semi e concime ---------------------------------------------------------

func seed_count(crop_id: String) -> int:
	return int(seeds.get(crop_id, 0))


func is_unlocked(crop_id: String) -> bool:
	return GameData.is_plant(crop_id) and int(GameData.crop(crop_id)["level"]) <= level


func buy_seeds(crop_id: String, qty: int) -> bool:
	if not is_unlocked(crop_id) or qty <= 0:
		return false
	var cost := int(GameData.crop(crop_id)["seed_cost"]) * qty
	if coins < cost:
		toast.emit(tr("MSG_NO_COINS"))
		return false
	coins -= cost
	seeds[crop_id] = seed_count(crop_id) + qty
	changed.emit()
	return true


func buy_fertilizer(qty: int) -> bool:
	if level < GameData.FERTILIZER_LEVEL:
		toast.emit(tr("MSG_FERTILIZER_LOCKED") % GameData.FERTILIZER_LEVEL)
		return false
	var cost := GameData.FERTILIZER_PRICE * qty
	if coins < cost:
		toast.emit(tr("MSG_NO_COINS"))
		return false
	coins -= cost
	fertilizer += qty
	changed.emit()
	return true


# --- Coltivazione -----------------------------------------------------------

func get_plot(cell: Vector2i) -> Dictionary:
	return plots.get(plot_key(cell), {})


func _plot_duration(p: Dictionary) -> float:
	return float(GameData.crop(p["crop"])["time"])


## Avanzamento 0..1 della pianta sul quadrante (0 se vuoto o non annaffiata).
func plot_progress(cell: Vector2i) -> float:
	var p := get_plot(cell)
	if p.is_empty() or not p.get("watered", false):
		return 0.0
	return clampf((now() - float(p["planted_at"])) / _plot_duration(p), 0.0, 1.0)


## La pianta sta crescendo: è stata annaffiata e non è ancora pronta.
func is_growing(cell: Vector2i) -> bool:
	var p := get_plot(cell)
	return not p.is_empty() and p.get("watered", false) and plot_progress(cell) < 1.0


## Seminata (o raccolta, se è un albero) e in attesa d'acqua.
func needs_water(cell: Vector2i) -> bool:
	var p := get_plot(cell)
	return not p.is_empty() and not p.get("watered", false)


func is_ready(cell: Vector2i) -> bool:
	return not get_plot(cell).is_empty() and plot_progress(cell) >= 1.0


func plot_seconds_left(cell: Vector2i) -> int:
	var p := get_plot(cell)
	if p.is_empty():
		return 0
	if not p.get("watered", false):
		return int(_plot_duration(p))
	return maxi(0, ceili(float(p["planted_at"]) + _plot_duration(p) - now()))


func plant(cell: Vector2i, crop_id: String) -> bool:
	if not is_in_grid(cell) or not get_plot(cell).is_empty():
		return false
	if not is_tilled(cell):
		toast.emit(tr("MSG_HOE_FIRST"))
		return false
	if not is_unlocked(crop_id):
		return false
	if seed_count(crop_id) <= 0:
		toast.emit(tr("MSG_NO_SEEDS_OF") % GameData.crop_name(crop_id).to_lower())
		return false
	seeds[crop_id] = seed_count(crop_id) - 1
	if seeds[crop_id] <= 0:
		seeds.erase(crop_id)
	# Resta un sacchetto di semi finché non viene annaffiato.
	plots[plot_key(cell)] = {"crop": crop_id, "planted_at": 0.0, "watered": false, "fertilized": false}
	planted.emit(cell)
	changed.emit()
	return true


## Annaffiare fa partire la crescita (una goccia, una volta per ciclo).
func water_plot(cell: Vector2i) -> bool:
	if not needs_water(cell):
		return false
	if water <= 0:
		toast.emit(tr("MSG_WELL_EMPTY"))
		return false
	if water >= GameData.WATER_MAX:
		water_last_tick = now()  # da pieno riparte la ricarica
	water -= 1
	var p := get_plot(cell)
	p["planted_at"] = now()
	p["watered"] = true
	changed.emit()
	return true


## Il concime moltiplica il raccolto (una volta per ciclo).
func fertilize_plot(cell: Vector2i) -> bool:
	var p := get_plot(cell)
	if p.is_empty() or is_ready(cell) or p.get("fertilized", false):
		return false
	if fertilizer <= 0:
		toast.emit(tr("MSG_NO_FERTILIZER"))
		return false
	fertilizer -= 1
	p["fertilized"] = true
	changed.emit()
	return true


func harvest(cell: Vector2i) -> bool:
	if not is_ready(cell):
		return false
	var key := plot_key(cell)
	var p: Dictionary = plots[key]
	var c := GameData.crop(p["crop"])
	var qty := int(c["yield"])
	if p.get("fertilized", false):
		qty *= GameData.FERTILIZER_MULTIPLIER
	add_item(c["product"], qty)
	if GameData.is_perennial(p["crop"]):
		# Alberi e arbusti restano piantati; il nuovo ciclo parte con l'acqua.
		p["planted_at"] = 0.0
		p["watered"] = false
		p["fertilized"] = false
		p["harvests"] = int(p.get("harvests", 0)) + 1
	else:
		plots.erase(key)
		if GameData.RETILL_AFTER_HARVEST:
			tilled.erase(key)
	add_xp(int(c["xp"]))
	harvested.emit(cell, c["product"], qty)
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
	while level < GameData.MAX_LEVEL and xp >= GameData.xp_for_level(level + 1):
		level += 1
		nostalgie += 1
		leveled_up.emit(level)
		var unlocked: PackedStringArray = []
		for id in GameData.all_plants():
			if int(GameData.crop(id)["level"]) == level:
				unlocked.append(GameData.crop_name(id))
		var msg: String = tr("MSG_LEVEL_UP") % level
		if not unlocked.is_empty():
			msg += tr("MSG_NEW_SEEDS") % ", ".join(unlocked)
		toast.emit(msg)


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
	for id in restored:
		var prod := GameData.building_product(id)
		if prod != "":
			available.append(prod)
	var items := {}
	var value := 0
	var n_products := 1 if randf() < 0.6 or available.size() < 2 else 2
	available.shuffle()
	for i in n_products:
		var product: String = available[i]
		var qty := _order_qty(product)
		items[product] = qty
		value += qty * _unit_value(product)
	return {
		"giver": GameData.ORDER_GIVERS.pick_random(),
		"why": randi() % ORDER_REASONS,
		"items": items,
		"coins": int(value * 1.3),
		"xp": maxi(2, int(value / 4.0)),
	}


## Quante ragioni diverse ha un ordine (ORDER_WHY_0.. nelle traduzioni).
const ORDER_REASONS := 6


## Le piante lente si chiedono in quantità più piccole.
func _order_qty(product: String) -> int:
	if GameData.crop_for_product(product) == "":
		return randi_range(1, 2)
	var t := int(GameData.crop(GameData.crop_for_product(product))["time"])
	if t <= 15 * GameData.MIN:
		return randi_range(2, 5)
	if t <= GameData.HOUR:
		return randi_range(2, 3)
	if t <= 4 * GameData.HOUR:
		return randi_range(1, 2)
	return 1


func _unit_value(product: String) -> int:
	if GameData.SELL_PRICES.has(product):
		return int(GameData.SELL_PRICES[product])
	var id := GameData.crop_for_product(product)
	return int(GameData.crop(id).get("sell_price", 1)) if id != "" else 1


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
	toast.emit(tr("MSG_ORDER_THANKS") % [order["giver"], int(order["coins"])])
	if randf() < GameData.ANTIQUE_ORDER_CHANCE:
		var found := _random_antique()
		add_antique(found, 1)
		toast.emit(tr("MSG_ANTIQUE_FOUND") % [order["giver"], GameData.antique_name(found)])
	changed.emit()
	return true


# --- Oggetti antichi e forziere --------------------------------------------

func antique_count(id: String) -> int:
	return int(antiques.get(id, 0))


func add_antique(id: String, qty: int) -> void:
	antiques[id] = antique_count(id) + qty


func _random_antique() -> String:
	return GameData.ANTIQUES.keys().pick_random()


static func today() -> String:
	return Time.get_date_string_from_system()


## Ogni giorno compare un forziere in un punto libero della fattoria.
func tick_chest() -> void:
	if last_chest_day == today():
		return
	var free: Array = []
	var fallback: Array = []
	var w := GameData.world_size()
	for y in w.y:
		for x in w.x:
			var cell := Vector2i(x, y)
			if not is_in_grid(cell) or not get_plot(cell).is_empty() or is_plow_queued(cell) or not object_at(cell).is_empty():
				continue
			fallback.append(cell)
			if not is_tilled(cell):
				free.append(cell)
	var pool := free if not free.is_empty() else fallback
	last_chest_day = today()
	if pool.is_empty():
		return
	chest = {"cell": plot_key(pool.pick_random())}
	toast.emit(tr("MSG_CHEST_APPEARED"))
	changed.emit()


func chest_cell() -> Vector2i:
	return key_to_cell(chest["cell"]) if not chest.is_empty() else Vector2i(-999, -999)


func open_chest(cell: Vector2i) -> bool:
	if chest.is_empty() or chest_cell() != cell:
		return false
	var found := {}
	for i in randi_range(GameData.CHEST_ANTIQUES.x, GameData.CHEST_ANTIQUES.y):
		var id := _random_antique()
		found[id] = int(found.get(id, 0)) + 1
		add_antique(id, 1)
	var c := randi_range(GameData.CHEST_COINS.x, GameData.CHEST_COINS.y)
	coins += c
	chest = {}
	var names: PackedStringArray = []
	for id in found:
		names.append("%d %s" % [found[id], GameData.antique_name(id)])
	toast.emit(tr("MSG_CHEST_OPENED") % [", ".join(names), c])
	chest_opened.emit(cell, found, c)
	changed.emit()
	return true


# --- Lotti di terra ---------------------------------------------------------

func sector_cost(sector: Vector2i) -> Dictionary:
	return GameData.SECTORS.get(GameData.sector_key(sector), {})


## Un lotto si compra se confina con uno già posseduto.
func is_sector_buyable(sector: Vector2i) -> bool:
	if is_sector_owned(sector) or sector_cost(sector).is_empty():
		return false
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if is_sector_owned(sector + d):
			return true
	return false


func can_buy_sector(sector: Vector2i) -> bool:
	if not is_sector_buyable(sector):
		return false
	var cost := sector_cost(sector)
	if level < int(cost["level"]) or coins < int(cost["coins"]):
		return false
	for id in cost["antiques"]:
		if antique_count(id) < int(cost["antiques"][id]):
			return false
	return true


func buy_sector(sector: Vector2i) -> bool:
	if not can_buy_sector(sector):
		return false
	var cost := sector_cost(sector)
	coins -= int(cost["coins"])
	for id in cost["antiques"]:
		antiques[id] = antique_count(id) - int(cost["antiques"][id])
	owned_sectors.append(GameData.sector_key(sector))
	add_xp(15)
	toast.emit(tr("MSG_SECTOR_BOUGHT"))
	sector_bought.emit(sector)
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


## Edificio che si può già restaurare (per il pallino sul pulsante Borgo).
func any_restorable() -> bool:
	for id in GameData.BUILDINGS:
		if can_restore(id):
			return true
	return false


func restore(building_id: String) -> bool:
	if not can_restore(building_id):
		return false
	var b := GameData.building(building_id)
	coins -= int(b["restore"]["coins"])
	remove_items(b["restore"]["items"])
	restored.append(building_id)
	nostalgie += 2
	add_xp(10 + 5 * restored.size())
	var pop: Array = b["pop"]
	toast.emit(tr("MSG_RESTORED_POP") % [int(pop[0]), int(pop[1]), int(pop[2])])
	if restored.size() == GameData.TOURISM_FROM:
		next_tourist_at = now() + 60.0
		toast.emit(tr("MSG_TOURISM_START"))
	building_restored.emit(building_id)
	changed.emit()
	return true


## Abitanti del borgo: quelli rimasti più quelli tornati con i restauri.
func population() -> int:
	var n := GameData.START_POPULATION
	for id in restored:
		for v in GameData.BUILDINGS.get(id, {}).get("pop", []):
			n += int(v)
	return n


# --- Turismo ----------------------------------------------------------------

func tourism_active() -> bool:
	return restored.size() >= GameData.TOURISM_FROM


func tourist_interval() -> float:
	var k := 1.0 + 0.15 * restored.size()
	if is_restored("ufficio_postale"):
		k += 0.5
	return GameData.TOURIST_INTERVAL / k


func max_tourists() -> int:
	return mini(GameData.TOURIST_MAX, 1 + restored.size() / 3)


## Valutazione del borgo: media delle recensioni (3 se non ce ne sono), più
## il campanile restaurato; da 1 a 5.
func rating() -> float:
	var r := 3.0
	if not reviews.is_empty():
		var sum := 0.0
		for v in reviews:
			sum += float(v)
		r = sum / reviews.size()
	if is_restored("campanile"):
		r += 0.5
	return clampf(r, 1.0, 5.0)


## Arrivi e partenze dei visitatori (anche per il tempo passato a gioco chiuso)
## e il premio giornaliero delle bocce.
func tick_tourism() -> void:
	var t := now()
	var dirty := false
	if visitors_day != today():
		visitors_day = today()
		visitors_today = 0
		dirty = true
	if is_restored("bocce") and last_bocce_day != today():
		last_bocce_day = today()
		coins += GameData.BOCCE_DAILY
		toast.emit(tr("MSG_BOCCE") % GameData.BOCCE_DAILY)
		dirty = true
	# chi ha aspettato troppo se ne va, deluso
	for i in range(tourists.size() - 1, -1, -1):
		if float(tourists[i]["leaves"]) <= t:
			tourists.remove_at(i)
			_add_review(2)
			dirty = true
	if tourism_active():
		if next_tourist_at <= 0.0:
			next_tourist_at = t + 60.0
		var guard := 0
		while next_tourist_at <= t and guard < 20:
			guard += 1
			if tourists.size() < max_tourists():
				tourists.append(_make_tourist(next_tourist_at))
				dirty = true
			next_tourist_at += tourist_interval()
	if dirty:
		changed.emit()


func _make_tourist(arrived: float) -> Dictionary:
	var wanted: Array = []
	for id in restored:
		var prod := GameData.building_product(id)
		if prod != "":
			wanted.append(prod)
	for o in placed:
		if o["kind"] == "structure" and o["type"] == "cucina":
			for rid in GameData.STRUCTURES["cucina"]["recipes"]:
				wanted.append(GameData.RECIPES[rid]["out"])
			break
	if wanted.is_empty():
		wanted = ["pomodori", "grano"]
	var prod: String = wanted.pick_random()
	var qty := randi_range(1, 2)
	var size := randi_range(1, 4)
	visitors_today += size
	var pay := float(_unit_value(prod)) * qty * GameData.TOURIST_PAY
	if is_restored("osteria"):
		pay *= 1.25
	return {"type": GameData.TOURIST_TYPES.pick_random(), "size": size, "items": {prod: qty},
		"coins": int(pay), "arrived": arrived, "leaves": arrived + GameData.TOURIST_PATIENCE}


func can_serve_tourist(i: int) -> bool:
	return i >= 0 and i < tourists.size() and has_items(tourists[i]["items"])


func serve_tourist(i: int) -> bool:
	if not can_serve_tourist(i):
		return false
	var tr_: Dictionary = tourists[i]
	remove_items(tr_["items"])
	coins += int(tr_["coins"])
	nostalgie += 1
	add_xp(5)
	tourists.remove_at(i)
	_add_review(5 if randf() < 0.7 else 4)
	toast.emit(tr("MSG_TOURIST_THANKS") % [tr("TOURIST_" + str(tr_["type"]).to_upper()), int(tr_["coins"])])
	changed.emit()
	return true


func _add_review(stars: int) -> void:
	reviews.append(stars)
	while reviews.size() > GameData.REVIEWS_KEPT:
		reviews.pop_front()


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
		toast.emit(tr("MSG_MISSING_INGREDIENTS"))
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


# --- Oggetti sulla fattoria -------------------------------------------------
## Ogni oggetto: {"uid", "kind": "animal"|"structure"|"decor", "type", "cell": "x,y"}
## più, per gli animali, "bottles", "last_bottle", "fed_at" (0 = da nutrire) e,
## per le strutture, "recipe" e "started_at" (ricetta in corso).

func object_at(cell: Vector2i) -> Dictionary:
	for o in placed:
		var size := GameData.footprint(o["kind"], o["type"])
		if Rect2i(key_to_cell(o["cell"]), size).has_point(cell):
			return o
	return {}


func get_object(uid: int) -> Dictionary:
	for o in placed:
		if int(o["uid"]) == uid:
			return o
	return {}


## Quadrante libero per posare qualcosa: tuo, non zappato, senza piante, lavori,
## forziere o altri oggetti.
func is_cell_free(cell: Vector2i) -> bool:
	return is_in_grid(cell) and not is_tilled(cell) and get_plot(cell).is_empty() \
		and not is_plow_queued(cell) and object_at(cell).is_empty() and chest_cell() != cell


func can_place(kind: String, type: String, cell: Vector2i) -> bool:
	var size := GameData.footprint(kind, type)
	for y in size.y:
		for x in size.x:
			if not is_cell_free(cell + Vector2i(x, y)):
				return false
	return true


func buy_price(kind: String, type: String) -> int:
	return int((GameData.ANIMALS if kind == "animal" else GameData.STRUCTURES)[type]["price"])


func unlock_level(kind: String, type: String) -> int:
	return int((GameData.ANIMALS if kind == "animal" else GameData.STRUCTURES)[type]["level"])


func can_buy(kind: String, type: String) -> bool:
	return level >= unlock_level(kind, type) and coins >= buy_price(kind, type)


## Compra un animale o una struttura e lo mette nel quadrante scelto.
func buy_and_place(kind: String, type: String, cell: Vector2i) -> bool:
	if not can_buy(kind, type):
		toast.emit(tr("MSG_NO_COINS") if level >= unlock_level(kind, type) else tr("SHOP_UNLOCK") % unlock_level(kind, type))
		return false
	if not can_place(kind, type, cell):
		toast.emit(tr("MSG_PLACE_BLOCKED"))
		return false
	coins -= buy_price(kind, type)
	var o := {"uid": next_uid, "kind": kind, "type": type, "cell": plot_key(cell)}
	next_uid += 1
	if kind == "animal":
		o["bottles"] = 0
		o["last_bottle"] = 0.0
		o["fed_at"] = 0.0
	placed.append(o)
	add_xp(3)
	changed.emit()
	return true


func place_decor(type: String, cell: Vector2i) -> bool:
	if int(decor_inv.get(type, 0)) <= 0:
		return false
	if not can_place("decor", type, cell):
		toast.emit(tr("MSG_PLACE_BLOCKED"))
		return false
	decor_inv[type] = int(decor_inv[type]) - 1
	if decor_inv[type] <= 0:
		decor_inv.erase(type)
	placed.append({"uid": next_uid, "kind": "decor", "type": type, "cell": plot_key(cell)})
	next_uid += 1
	changed.emit()
	return true


## Rimette in magazzino una decorazione posata (per spostarla).
func pick_up_decor(uid: int) -> bool:
	var o := get_object(uid)
	if o.is_empty() or o["kind"] != "decor":
		return false
	placed.erase(o)
	decor_inv[o["type"]] = int(decor_inv.get(o["type"], 0)) + 1
	changed.emit()
	return true


# --- Animali ----------------------------------------------------------------

func buy_biberon(qty: int) -> bool:
	var cost := GameData.BIBERON_PRICE * qty
	if coins < cost:
		toast.emit(tr("MSG_NO_COINS"))
		return false
	coins -= cost
	biberon += qty
	changed.emit()
	return true


func is_adult(o: Dictionary) -> bool:
	return int(o.get("bottles", 0)) >= int(GameData.ANIMALS[o["type"]]["bottles"])


## Secondi che mancano prima del prossimo biberon (0 = si può dare ora).
func bottle_wait(o: Dictionary) -> int:
	var last := float(o.get("last_bottle", 0.0))
	if last <= 0.0:
		return 0
	return maxi(0, ceili(last + GameData.BOTTLE_COOLDOWN - now()))


## Stato di un animale, per gli indicatori e per decidere cosa fare al tocco:
## "bottle" (cucciolo, pronto per il biberon), "bottle_wait", "hungry" (adulto
## da nutrire), "producing", "ready" (prodotto da raccogliere).
func animal_state(o: Dictionary) -> String:
	if not is_adult(o):
		return "bottle" if bottle_wait(o) == 0 else "bottle_wait"
	var fed := float(o.get("fed_at", 0.0))
	if fed <= 0.0:
		return "hungry"
	return "ready" if animal_progress(o) >= 1.0 else "producing"


func animal_progress(o: Dictionary) -> float:
	var fed := float(o.get("fed_at", 0.0))
	if fed <= 0.0:
		return 0.0
	return clampf((now() - fed) / float(GameData.ANIMALS[o["type"]]["time"]), 0.0, 1.0)


func give_bottle(uid: int) -> bool:
	var o := get_object(uid)
	if o.is_empty() or o["kind"] != "animal" or is_adult(o):
		return false
	if bottle_wait(o) > 0:
		return false
	if biberon <= 0:
		toast.emit(tr("MSG_NO_BIBERON"))
		return false
	biberon -= 1
	o["bottles"] = int(o.get("bottles", 0)) + 1
	o["last_bottle"] = now()
	add_xp(1)
	if is_adult(o):
		toast.emit(tr("MSG_ANIMAL_GROWN") % GameData.animal_name(o["type"]))
	changed.emit()
	return true


func feed_animal(uid: int) -> bool:
	var o := get_object(uid)
	if o.is_empty() or o["kind"] != "animal" or animal_state(o) != "hungry":
		return false
	var feed: Dictionary = GameData.ANIMALS[o["type"]]["feed"]
	if not has_items(feed):
		toast.emit(tr("MSG_NO_FEED"))
		return false
	remove_items(feed)
	o["fed_at"] = now()
	changed.emit()
	return true


func collect_animal(uid: int) -> bool:
	var o := get_object(uid)
	if o.is_empty() or o["kind"] != "animal" or animal_state(o) != "ready":
		return false
	var a: Dictionary = GameData.ANIMALS[o["type"]]
	add_item(a["product"], int(a["yield"]))
	o["fed_at"] = 0.0
	add_xp(int(a["xp"]))
	harvested.emit(key_to_cell(o["cell"]), a["product"], int(a["yield"]))
	changed.emit()
	return true


# --- Strutture e ricette ----------------------------------------------------

func recipe_progress(uid: int) -> float:
	var o := get_object(uid)
	if o.is_empty() or not o.has("recipe"):
		return 0.0
	return clampf((now() - float(o["started_at"])) / float(GameData.RECIPES[o["recipe"]]["time"]), 0.0, 1.0)


func can_start_recipe(uid: int, recipe: String) -> bool:
	var o := get_object(uid)
	if o.is_empty() or o["kind"] != "structure" or o.has("recipe"):
		return false
	if not recipe in GameData.STRUCTURES[o["type"]]["recipes"]:
		return false
	var r: Dictionary = GameData.RECIPES[recipe]
	return has_items(r["in"]) and coins >= int(r["coins"]) and espresso >= int(r["espresso"])


func start_recipe(uid: int, recipe: String) -> bool:
	if not can_start_recipe(uid, recipe):
		var r: Dictionary = GameData.RECIPES.get(recipe, {})
		if not r.is_empty() and espresso < int(r["espresso"]):
			toast.emit(tr("MSG_NO_ESPRESSO"))
		elif not r.is_empty() and not has_items(r["in"]):
			toast.emit(tr("MSG_MISSING_INGREDIENTS"))
		elif not r.is_empty() and coins < int(r["coins"]):
			toast.emit(tr("MSG_NO_COINS"))
		return false
	var o := get_object(uid)
	var r2: Dictionary = GameData.RECIPES[recipe]
	remove_items(r2["in"])
	coins -= int(r2["coins"])
	if int(r2["espresso"]) > 0:
		if espresso >= GameData.MOKA_MAX:
			moka_last_tick = now()   # da piena la moka riparte
		espresso -= int(r2["espresso"])
	o["recipe"] = recipe
	o["started_at"] = now()
	changed.emit()
	return true


func collect_recipe(uid: int) -> bool:
	var o := get_object(uid)
	if o.is_empty() or not o.has("recipe") or recipe_progress(uid) < 1.0:
		return false
	var r: Dictionary = GameData.RECIPES[o["recipe"]]
	var out: String = r["out"]
	if out in GameData.DECOR:
		decor_inv[out] = int(decor_inv.get(out, 0)) + 1
	else:
		add_item(out, 1)
	o.erase("recipe")
	o.erase("started_at")
	add_xp(int(r["xp"]))
	toast.emit(tr("MSG_RECIPE_DONE") % GameData.recipe_name(out))
	changed.emit()
	return true


## Vende prodotti del magazzino (fatti in casa, latte, uova...).
func sell(product: String, qty: int) -> bool:
	if not GameData.SELL_PRICES.has(product) or item_count(product) < qty or qty <= 0:
		return false
	remove_items({product: qty})
	coins += int(GameData.SELL_PRICES[product]) * qty
	changed.emit()
	return true


# --- Serializzazione --------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": 5,
		"saved_at": now(),
		"coins": coins,
		"nostalgie": nostalgie,
		"xp": xp,
		"level": level,
		"espresso": espresso,
		"moka_last_tick": moka_last_tick,
		"water": water,
		"water_last_tick": water_last_tick,
		"fertilizer": fertilizer,
		"inventory": inventory,
		"seeds": seeds,
		"tilled": tilled.keys(),
		"plow_queue": plow_queue,
		"plots": plots,
		"owned_sectors": owned_sectors,
		"antiques": antiques,
		"chest": chest,
		"last_chest_day": last_chest_day,
		"placed": placed,
		"next_uid": next_uid,
		"decor_inv": decor_inv,
		"biberon": biberon,
		"tourists": tourists,
		"next_tourist_at": next_tourist_at,
		"reviews": reviews,
		"visitors_today": visitors_today,
		"visitors_day": visitors_day,
		"last_bocce_day": last_bocce_day,
		"orders": orders,
		"restored": restored,
		"productions": productions,
	}


func from_dict(d: Dictionary) -> void:
	coins = int(d.get("coins", 30))
	# le Lire d'oro dei salvataggi fino alla v4 diventano Nostalgie
	nostalgie = int(d.get("nostalgie", d.get("lire_oro", 0)))
	xp = int(d.get("xp", 0))
	level = int(d.get("level", 1))
	espresso = int(d.get("espresso", 1))
	moka_last_tick = float(d.get("moka_last_tick", now()))
	water = int(d.get("water", GameData.WATER_START))
	water_last_tick = float(d.get("water_last_tick", now()))
	fertilizer = int(d.get("fertilizer", 0))
	inventory = _int_values(d.get("inventory", {}))
	seeds = _int_values(d.get("seeds", GameData.START_SEEDS))
	plots = d.get("plots", {})
	tilled = {}
	if d.has("tilled"):
		for key in d["tilled"]:
			tilled[key] = true
	else:
		# Salvataggio v1: niente zappa, la terra lavorata è quella già seminata
		# più i quadranti iniziali.
		for cell in GameData.START_TILLED:
			tilled[plot_key(cell)] = true
		for key in plots:
			tilled[key] = true
	plow_queue = d.get("plow_queue", [])
	if int(d.get("version", 1)) < 3:
		# Fino alla v2 le piante crescevano subito: risultano già annaffiate.
		for key in plots:
			plots[key]["watered"] = true
	owned_sectors = d.get("owned_sectors", [GameData.sector_key(GameData.START_SECTOR)])
	antiques = _int_values(d.get("antiques", {}))
	chest = d.get("chest", {})
	last_chest_day = str(d.get("last_chest_day", ""))
	placed = d.get("placed", [])
	for o in placed:
		o["uid"] = int(o["uid"])
	next_uid = int(d.get("next_uid", 1))
	decor_inv = _int_values(d.get("decor_inv", {}))
	biberon = int(d.get("biberon", 0))
	tourists = d.get("tourists", [])
	next_tourist_at = float(d.get("next_tourist_at", 0.0))
	reviews = d.get("reviews", [])
	visitors_today = int(d.get("visitors_today", 0))
	visitors_day = str(d.get("visitors_day", ""))
	last_bocce_day = str(d.get("last_bocce_day", ""))
	orders = d.get("orders", [])
	restored = d.get("restored", [])
	productions = d.get("productions", {})
	refill_orders()
	changed.emit()


static func _int_values(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src:
		out[k] = int(src[k])
	return out
