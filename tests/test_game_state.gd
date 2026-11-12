extends SceneTree
## Test delle regole di gioco, senza grafica.
## Avvio:  godot --headless --path . -s tests/test_game_state.gd
## Esce con codice 1 se un controllo fallisce.
##
## Il tempo si fa avanzare spostando indietro i timestamp salvati nello stato.

var _failures := 0
var gs: Node
var gd: Node


func _initialize() -> void:
	await process_frame
	gs = root.get_node("GameState")
	gd = root.get_node("GameData")
	# Il test non deve toccare il salvataggio vero.
	var save_manager := root.get_node("SaveManager")
	save_manager.set_process(false)
	gs.changed.disconnect(save_manager._on_state_changed)

	_test_new_game()
	_test_plow_queue()
	_test_seeds_and_planting()
	_test_water()
	_test_fertilizer_and_harvest()
	_test_trees_regrow()
	_test_sectors_and_antiques()
	_test_v2_save_migration()
	_test_orders_and_levels()
	_test_save_roundtrip()
	_test_v1_save_migration()
	_test_translations()

	if _failures == 0:
		print("TUTTI I TEST OK")
	else:
		print("TEST FALLITI: %d" % _failures)
	quit(1 if _failures > 0 else 0)


func check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		print("  FALLITO: ", what)


func _advance_plow(seconds: float) -> void:
	for job in gs.plow_queue:
		job["start"] -= seconds
		job["end"] -= seconds


func _test_new_game() -> void:
	print("partita nuova")
	gs.new_game()
	check(gs.tilled.size() == 4, "4 quadranti lavorati all'inizio")
	check(gs.seed_count("grano") == 4, "4 semi di grano all'inizio")
	check(gs.water == gd.WATER_START, "gocce iniziali")
	check(gs.orders.size() == gd.ORDER_BOARD_SIZE, "bacheca piena")


func _test_plow_queue() -> void:
	print("zappa")
	gs.new_game()
	var a := Vector2i(0, 0)
	var b := Vector2i(1, 0)
	check(gs.queue_plow(a), "metto in coda il primo quadrante")
	check(not gs.queue_plow(a), "niente doppioni in coda")
	check(not gs.queue_plow(Vector2i(2, 2)), "non si zappa la terra già lavorata")
	check(gs.queue_plow(b), "secondo quadrante in coda")
	var j0: Dictionary = gs.plow_queue[0]
	var j1: Dictionary = gs.plow_queue[1]
	check(is_equal_approx(j0["end"] - j0["start"], gd.PLOW_TIME), "15 secondi a quadrante")
	check(is_equal_approx(j1["start"], j0["end"]), "il secondo parte quando finisce il primo")
	_advance_plow(10)
	gs.update_plowing()
	check(not gs.is_tilled(a), "dopo 10 s non è ancora pronto")
	_advance_plow(6)
	gs.update_plowing()
	check(gs.is_tilled(a) and not gs.is_tilled(b), "dopo 16 s il primo è lavorato, il secondo no")
	_advance_plow(15)
	gs.update_plowing()
	check(gs.is_tilled(b), "dopo altri 15 s anche il secondo")
	# cancellazione e slittamento
	gs.queue_plow(Vector2i(0, 1))
	gs.queue_plow(Vector2i(0, 2))
	gs.cancel_plow(Vector2i(0, 1))
	check(gs.plow_queue.size() == 1, "cancellato un lavoro")
	check(gs.plow_queue[0]["end"] - gs.now() <= gd.PLOW_TIME + 0.5, "il lavoro dopo slitta avanti")


func _test_seeds_and_planting() -> void:
	print("semi e semina")
	gs.new_game()
	check(not gs.plant(Vector2i(0, 0), "grano"), "non si pianta sull'erba")
	check(gs.plant(Vector2i(2, 2), "grano"), "si pianta sulla terra lavorata")
	check(gs.seed_count("grano") == 3, "un seme consumato")
	check(not gs.plant(Vector2i(2, 2), "grano"), "quadrante occupato")
	check(not gs.buy_seeds("carota", 1), "la carota è bloccata al livello 1")
	var coins: int = gs.coins
	check(gs.buy_seeds("pomodoro", 2), "compro 2 semi di pomodoro")
	check(gs.coins == coins - 10 and gs.seed_count("pomodoro") == 2, "pagati 10 monete")
	gs.coins = 0
	check(not gs.buy_seeds("pomodoro", 1), "senza monete non si compra")
	check(not gs.buy_seeds("gallina", 1), "gli animali non sono semi")


func _test_water() -> void:
	print("acqua")
	gs.new_game()
	var cell := Vector2i(2, 2)
	gs.seeds["pomodoro"] = 1
	gs.plant(cell, "pomodoro")
	check(gs.needs_water(cell), "appena seminato aspetta l'acqua")
	gs.plots[gs.plot_key(cell)]["planted_at"] -= 99999
	check(gs.plot_progress(cell) == 0.0 and not gs.is_ready(cell), "senz'acqua non cresce, anche dopo tanto tempo")
	check(gs.plot_seconds_left(cell) == int(gd.CROPS["pomodoro"]["time"]), "il tempo resta tutto da fare")
	var w: int = gs.water
	check(gs.water_plot(cell), "annaffio")
	check(gs.water == w - 1, "una goccia usata")
	check(gs.is_growing(cell) and not gs.needs_water(cell), "ora cresce")
	check(abs(gs.plot_seconds_left(cell) - int(gd.CROPS["pomodoro"]["time"])) <= 1, "la crescita parte adesso")
	check(not gs.water_plot(cell), "una volta per ciclo")
	gs.water = 0
	gs.plant(Vector2i(3, 2), "grano")
	check(not gs.water_plot(Vector2i(3, 2)), "senza gocce non si annaffia")
	# ricarica del pozzo
	gs.water_last_tick = gs.now() - gd.WATER_INTERVAL * 3.5
	gs.tick_water()
	check(gs.water == 3, "il pozzo ricarica 3 gocce in 3,5 intervalli")
	gs.water_last_tick = gs.now() - 99999
	gs.tick_water()
	check(gs.water == gd.WATER_MAX, "non supera il massimo")


func _grow(cell: Vector2i) -> void:
	gs.water = maxi(gs.water, 1)
	gs.water_plot(cell)
	gs.plots[gs.plot_key(cell)]["planted_at"] -= 999999


func _test_fertilizer_and_harvest() -> void:
	print("concime e raccolto")
	gs.new_game()
	var a := Vector2i(2, 2)
	var b := Vector2i(3, 2)
	gs.plant(a, "grano")
	gs.plant(b, "grano")
	check(not gs.buy_fertilizer(1), "concime bloccato al livello 1")
	gs.level = gd.FERTILIZER_LEVEL
	gs.coins = 100
	check(gs.buy_fertilizer(2), "compro concime")
	check(gs.fertilize_plot(a), "concimo il primo (anche prima dell'acqua)")
	check(not gs.fertilize_plot(a), "una volta per ciclo")
	check(not gs.harvest(a), "non si raccoglie prima del tempo")
	_grow(a)
	_grow(b)
	check(gs.harvest(a) and gs.item_count("grano") == 4, "raccolto concimato: 4 grano")
	check(gs.harvest(b) and gs.item_count("grano") == 6, "raccolto normale: 2 grano")
	check(gs.get_plot(a).is_empty() and gs.is_tilled(a), "la terra resta lavorata e libera")


func _test_trees_regrow() -> void:
	print("alberi")
	gs.new_game()
	gs.level = 4
	gs.seeds["ulivo"] = 1
	var cell := Vector2i(2, 2)
	check(gs.plant(cell, "ulivo"), "pianto un ulivo")
	_grow(cell)
	check(gs.harvest(cell), "raccolgo le olive")
	check(gs.item_count("olive") == 3, "3 olive")
	check(not gs.get_plot(cell).is_empty(), "l'ulivo resta piantato")
	check(gs.needs_water(cell), "e per rifare i frutti va annaffiato di nuovo")


func _test_sectors_and_antiques() -> void:
	print("lotti, oggetti antichi e forziere")
	gs.new_game()
	check(gs.is_in_grid(Vector2i(5, 5)) and not gs.is_in_grid(Vector2i(6, 0)), "si parte con il lotto 6x6")
	check(gs.is_in_world(Vector2i(17, 17)) and not gs.is_in_world(Vector2i(18, 0)), "mappa 18x18")
	check(not gs.queue_plow(Vector2i(7, 1)), "non si zappa fuori dai propri lotti")
	var east := Vector2i(1, 0)
	check(gs.is_sector_buyable(east) and not gs.is_sector_buyable(Vector2i(1, 1)), "si compra solo un lotto confinante")
	check(not gs.can_buy_sector(east), "servono monete, livello e oggetti antichi")
	gs.level = 3
	gs.coins = 1000
	check(not gs.can_buy_sector(east), "mancano ancora gli oggetti antichi")
	for id in gd.SECTORS["1,0"]["antiques"]:
		gs.add_antique(id, int(gd.SECTORS["1,0"]["antiques"][id]))
	check(gs.buy_sector(east), "compro il lotto")
	check(gs.is_in_grid(Vector2i(7, 1)), "il lotto ora è mio")
	check(gs.coins == 1000 - int(gd.SECTORS["1,0"]["coins"]), "pagate le monete")
	check(gs.antique_count("anfora") == 0, "consumati gli oggetti antichi")
	check(gs.is_sector_buyable(Vector2i(1, 1)), "ora confina anche il lotto centrale")
	# forziere: uno al giorno
	gs.last_chest_day = ""
	gs.tick_chest()
	check(not gs.chest.is_empty(), "compare il forziere del giorno")
	var where: Vector2i = gs.chest_cell()
	check(gs.is_in_grid(where) and gs.get_plot(where).is_empty(), "su un quadrante libero della fattoria")
	gs.tick_chest()
	check(gs.chest_cell() == where, "non ne compare un altro lo stesso giorno")
	var total := 0
	for id in gd.ANTIQUES:
		total += gs.antique_count(id)
	var coins_before: int = gs.coins
	check(gs.open_chest(where), "apro il forziere")
	var after := 0
	for id in gd.ANTIQUES:
		after += gs.antique_count(id)
	check(after - total >= 1 and after - total <= 2, "dentro 1 o 2 oggetti antichi")
	check(gs.coins > coins_before, "e qualche moneta")
	check(gs.chest.is_empty() and not gs.open_chest(where), "si apre una volta sola")


func _test_v2_save_migration() -> void:
	print("salvataggio v2")
	var v2 := {"version": 2, "plots": {"2,2": {"crop": "grano", "planted_at": gs.now() - 9999, "watered": false, "fertilized": false}}, "tilled": ["2,2"]}
	gs.from_dict(v2)
	check(gs.is_ready(Vector2i(2, 2)), "le piante della v2 continuano a crescere come prima")
	check(gs.owned_sectors == [gd.sector_key(gd.START_SECTOR)], "si possiede il lotto iniziale")


func _test_orders_and_levels() -> void:
	print("ordini e livelli")
	gs.new_game()
	for id in gd.all_plants():
		gs.inventory[gd.crop(id)["product"]] = 100
	var n := 0
	while n < 200 and gs.level < gd.MAX_LEVEL:
		var done := false
		for i in gs.orders.size():
			if gs.can_fulfill(i):
				gs.fulfill_order(i)
				done = true
				n += 1
				break
		if not done:
			for id in gd.all_plants():
				gs.inventory[gd.crop(id)["product"]] = 100
	check(gs.level == gd.MAX_LEVEL, "con gli ordini si arriva al livello %d (%d ordini)" % [gd.MAX_LEVEL, n])
	check(gd.plantable_crops(gs.level).size() == gd.all_plants().size(), "tutte le piante sbloccate")


func _test_save_roundtrip() -> void:
	print("salvataggio")
	gs.new_game()
	gs.plant(Vector2i(2, 2), "grano")
	gs.queue_plow(Vector2i(0, 0))
	gs.fertilizer = 3
	var d: Dictionary = JSON.parse_string(JSON.stringify(gs.to_dict()))
	gs.new_game()
	gs.from_dict(d)
	check(gs.fertilizer == 3, "concime salvato")
	check(gs.seed_count("grano") == 3, "semi salvati")
	check(gs.is_plow_queued(Vector2i(0, 0)), "coda della zappa salvata")
	check(not gs.get_plot(Vector2i(2, 2)).is_empty(), "piante salvate")
	check(gs.tilled.size() == 4, "terra lavorata salvata")


func _test_v1_save_migration() -> void:
	print("salvataggio vecchio (v1)")
	var v1 := {"version": 1, "coins": 50, "level": 2, "plots": {"0,5": {"crop": "grano", "planted_at": gs.now()}}}
	gs.from_dict(v1)
	check(gs.is_tilled(Vector2i(0, 5)), "i campi già seminati risultano lavorati")
	check(gs.is_tilled(Vector2i(2, 2)), "più i quadranti iniziali")
	check(gs.water == gd.WATER_START, "gocce di default")


func _test_translations() -> void:
	print("traduzioni")
	var it := TranslationServer.get_translation_object("it")
	check(it != null, "traduzione italiana caricata")
	if it == null:
		return
	var placeholder := RegEx.create_from_string("%[ds]")
	for code in ["en", "fr", "es"]:
		var t := TranslationServer.get_translation_object(code)
		check(t != null and t.locale.begins_with(code), "traduzione %s caricata" % code)
		if t == null:
			continue
		for key in it.get_message_list():
			var a: String = it.get_message(key)
			var b: String = t.get_message(key)
			check(b != "", "%s: manca %s" % [code, key])
			var pa := placeholder.search_all(a).map(func(m: RegExMatch) -> String: return m.get_string())
			var pb := placeholder.search_all(b).map(func(m: RegExMatch) -> String: return m.get_string())
			check(pa == pb, "%s: segnaposto diversi in %s" % [code, key])
	# ogni pianta e prodotto ha il suo nome tradotto
	TranslationServer.set_locale("en")
	for id in gd.CROPS:
		check(gd.crop_name(id) != "CROP_" + id.to_upper(), "nome tradotto per " + id)
		var prod: String = gd.CROPS[id]["product"]
		check(gd.product_name(prod) != "PROD_" + prod.to_upper(), "prodotto tradotto: " + prod)
	check(gd.crop_name("grano") == "Wheat", "grano in inglese è Wheat")
	TranslationServer.set_locale("fr")
	check(gd.product_name("farina") == "farine", "farina in francese è farine")
