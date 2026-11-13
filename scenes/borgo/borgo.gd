class_name Borgo
extends Control
## Finestre del borgo, una alla volta, aperte quando il contadino arriva
## all'edificio sulla mappa (BorgoMap):
##   "orders"    la bacheca: ordini degli abitanti (con il loro perché) e i
##               visitatori in paese, con valutazione e visitatori di oggi
##   "building"  un edificio: prima la storia del suo abitante e cosa serve
##               per restaurarlo, poi la sua produzione o il suo effetto

var _panels: Dictionary = {}         ## "orders" / "building" -> PanelContainer
var _orders_box: VBoxContainer
var _building_box: VBoxContainer
var _building_title: Label
var _building_sub: Label
var _building_id := ""
var _bar: ProgressBar
var _ready_shown := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var o := _make_panel(center, "orders", tr("BORGO_ORDERS"), tr("BORGO_ORDERS_SUB"), "borgo", 640)
	_orders_box = o[0]
	var b := _make_panel(center, "building", "", "", "borgo", 520)
	_building_box = b[0]
	_building_title = b[1]
	_building_sub = b[2]
	close_panels()
	GameState.changed.connect(_refresh)


func _process(_delta: float) -> void:
	# barra della produzione in corso; i pulsanti si ricostruiscono solo
	# quando la produzione è pronta, così i clic non vanno persi
	if not _panels["building"].visible or not GameState.productions.has(_building_id):
		return
	var p := GameState.production_progress(_building_id)
	if is_instance_valid(_bar):
		_bar.value = p * 100.0
	if p >= 1.0 and not _ready_shown:
		_refresh()


func open_orders() -> void:
	_show("orders")


func open_building(id: String) -> void:
	_building_id = id
	_show("building")


func _show(which: String) -> void:
	for k in _panels:
		_panels[k].visible = k == which
	_refresh()


func close_panels() -> void:
	for k in _panels:
		_panels[k].visible = false


func is_open() -> bool:
	for k in _panels:
		if _panels[k].visible:
			return true
	return false


## Restituisce [corpo, titolo, sottotitolo].
func _make_panel(parent: Control, key: String, title: String, subtitle: String, icon_name: String, width: float) -> Array:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Sheet"
	panel.custom_minimum_size = Vector2(width, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(panel)
	_panels[key] = panel
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	head.add_child(UiKit.texture_rect(UiKit.icon(icon_name), 44))
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -4)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	var t := UiKit.label(title, "Title")
	titles.add_child(t)
	var sub := UiKit.label(subtitle, "Small")
	titles.add_child(sub)
	var close := UiKit.button("", "IconButton", "close")
	close.pressed.connect(close_panels)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 420)
	col.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	return [body, t, sub]


func _clear(box: Container) -> void:
	for child in box.get_children():
		child.queue_free()


func _refresh() -> void:
	if not is_inside_tree():
		return
	if _panels["orders"].visible:
		_refresh_orders()
	if _panels["building"].visible:
		_refresh_building()


# --- Bacheca: ordini e visitatori ---------------------------------------------

func _refresh_orders() -> void:
	_clear(_orders_box)
	for i in GameState.orders.size():
		var order: Dictionary = GameState.orders[i]
		var why := tr("ORDER_WHY_%d" % int(order.get("why", 0)))
		_request_card(_orders_box, tr("BORGO_ASKS") % order["giver"], "\"" + why + "\"", order["items"],
			int(order["coins"]), int(order["xp"]), GameState.can_fulfill(i), GameState.fulfill_order.bind(i), tr("BORGO_DELIVER"))

	_orders_box.add_child(HSeparator.new())
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_orders_box.add_child(head)
	var t := UiKit.label(tr("BORGO_TOURISTS"), "Heading")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UiKit.label(tr("UI_VISITORS") % GameState.visitors_today, "Small"))
	if not GameState.tourism_active():
		_orders_box.add_child(UiKit.label(tr("BORGO_NO_TOURISTS"), "Small"))
		return
	for i in GameState.tourists.size():
		var tour: Dictionary = GameState.tourists[i]
		var left := maxi(0, ceili(float(tour["leaves"]) - GameState.now()))
		var who := tr("BORGO_TOURIST_ASKS") % [tr("TOURIST_" + str(tour["type"]).to_upper()), int(tour["size"])]
		_request_card(_orders_box, who, tr("BORGO_LEAVES") % GameData.format_time(left), tour["items"],
			int(tour["coins"]), 5, GameState.can_serve_tourist(i), GameState.serve_tourist.bind(i), tr("BORGO_SERVE"))


func _request_card(parent: Control, who: String, line: String, wanted: Dictionary, coins: int, xp: int,
		ok: bool, action: Callable, button_text: String) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	parent.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	row.add_child(info)
	info.add_child(UiKit.label(who, "Heading"))
	var l := UiKit.label(line, "Small")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(l)
	info.add_child(_items_row(wanted))
	var reward := VBoxContainer.new()
	reward.add_theme_constant_override("separation", 2)
	row.add_child(reward)
	var coin_row := HBoxContainer.new()
	coin_row.add_child(UiKit.texture_rect(UiKit.icon("coin"), 22))
	coin_row.add_child(UiKit.label(str(coins), "Heading"))
	coin_row.add_child(UiKit.texture_rect(UiKit.icon("star"), 22))
	coin_row.add_child(UiKit.label(str(xp), "Heading"))
	reward.add_child(coin_row)
	var button := UiKit.button(button_text, "PrimaryButton")
	button.disabled = not ok
	button.pressed.connect(action)
	reward.add_child(button)


## Prodotti richiesti, verdi se li hai e rossi se mancano.
func _items_row(wanted: Dictionary) -> HBoxContainer:
	var items := HBoxContainer.new()
	items.add_theme_constant_override("separation", 12)
	for product in wanted:
		var need := int(wanted[product])
		var have := GameState.item_count(product)
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 4)
		var crop_id := GameData.crop_for_product(product)
		if crop_id != "":
			item.add_child(UiKit.texture_rect(UiKit.crop_icon(crop_id), 24))
		var l := UiKit.label("%s %d/%d" % [GameData.product_name(product), mini(have, need), need])
		l.add_theme_color_override("font_color", Color("5e7a28") if have >= need else Color("a94c2a"))
		item.add_child(l)
		items.add_child(item)
	return items


# --- Edificio: storia, restauro, produzione -----------------------------------

## Restauro: si chiude la finestra per vedere la scena sulla mappa.
func _on_restore(id: String) -> void:
	if GameState.restore(id):
		close_panels()

func _refresh_building() -> void:
	_clear(_building_box)
	_bar = null
	_ready_shown = false
	var id := _building_id
	var b := GameData.building(id)
	_building_title.text = GameData.building_name(id)
	_building_sub.text = GameData.resident_name(id)
	var pop: Array = b["pop"]

	if not GameState.is_restored(id):
		# la storia dell'abitante e cosa serve per riaprire
		var story := UiKit.label("\"" + GameData.building_story(id) + "\"")
		story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		story.custom_minimum_size = Vector2(460, 0)
		_building_box.add_child(story)
		_building_box.add_child(UiKit.label(tr("BUILDING_NEEDS"), "Heading"))
		var cost: Dictionary = b["restore"]
		var need := HBoxContainer.new()
		need.add_theme_constant_override("separation", 12)
		_building_box.add_child(need)
		var lv := UiKit.label(tr("LAND_LEVEL") % int(b["level"]), "Heading")
		lv.add_theme_color_override("font_color", Color("5e7a28") if GameState.level >= int(b["level"]) else Color("a94c2a"))
		need.add_child(lv)
		var coins_row := HBoxContainer.new()
		coins_row.add_child(UiKit.texture_rect(UiKit.icon("coin"), 22))
		var cl := UiKit.label("%d" % int(cost["coins"]), "Heading")
		cl.add_theme_color_override("font_color", Color("5e7a28") if GameState.coins >= int(cost["coins"]) else Color("a94c2a"))
		coins_row.add_child(cl)
		need.add_child(coins_row)
		_building_box.add_child(_items_row(cost["items"]))
		_building_box.add_child(UiKit.label(tr("BUILDING_RETURNS") % [int(pop[0]), int(pop[1]), int(pop[2])], "Small"))
		var restore_btn := UiKit.button(tr("BUILDING_RESTORE"), "PrimaryButton")
		restore_btn.custom_minimum_size = Vector2(0, 50)
		restore_btn.disabled = not GameState.can_restore(id)
		restore_btn.pressed.connect(_on_restore.bind(id))
		_building_box.add_child(restore_btn)
		return

	_building_box.add_child(UiKit.label(tr("BUILDING_THANKS"), "Small"))
	if b.has("effect"):
		var e := UiKit.label(GameData.building_effect(id), "Heading")
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.custom_minimum_size = Vector2(460, 0)
		_building_box.add_child(e)
		return
	var recipe: Dictionary = b["recipe"]
	var product := GameData.building_product(id)
	_building_box.add_child(UiKit.label(tr("BUILDING_MAKES") % GameData.product_name(product) + "  (" + GameData.format_time(int(recipe["time"])) + ")", "Heading"))
	_building_box.add_child(_items_row(recipe["in"]))
	_building_box.add_child(UiKit.label(tr("BUILDING_IN_STORE") % GameState.item_count(product), "Small"))
	var button: Button
	if GameState.productions.has(id):
		var p := GameState.production_progress(id)
		_bar = ProgressBar.new()
		_bar.custom_minimum_size = Vector2(0, 16)
		_bar.show_percentage = false
		_bar.value = p * 100.0
		_building_box.add_child(_bar)
		_ready_shown = p >= 1.0
		button = UiKit.button(tr("PANEL_COLLECT"), "PrimaryButton")
		button.disabled = p < 1.0
		button.pressed.connect(GameState.collect_production.bind(id))
	else:
		button = UiKit.button(tr("BUILDING_START"), "PrimaryButton")
		button.disabled = not GameState.has_items(recipe["in"])
		button.pressed.connect(GameState.start_production.bind(id))
	_building_box.add_child(button)
	if GameData.SELL_PRICES.has(product) and GameState.item_count(product) > 0:
		var sb := UiKit.button("%s  %d" % [tr("PANEL_SELL"), int(GameData.SELL_PRICES[product])], "Button", "coin")
		sb.add_theme_constant_override("icon_max_width", 20)
		sb.pressed.connect(GameState.sell.bind(product, 1))
		_building_box.add_child(sb)
