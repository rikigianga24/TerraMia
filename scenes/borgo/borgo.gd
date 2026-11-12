class_name Borgo
extends Control
## Finestre del borgo: bacheca degli ordini e mulino. Si aprono quando il
## contadino arriva all'edificio sulla mappa (BorgoMap), una alla volta.

var _panels: Dictionary = {}         ## "orders" / "mill" -> PanelContainer
var _orders_box: VBoxContainer
var _mill_box: VBoxContainer
var _mill_bar: ProgressBar
var _mill_ready_shown := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_orders_box = _make_panel(center, "orders", tr("BORGO_ORDERS"), tr("BORGO_ORDERS_SUB"), "borgo", 560)
	_mill_box = _make_panel(center, "mill", tr("MILL_TITLE"), GameData.resident_name("mulino"), "farm", 420)
	close_panels()

	GameState.changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	# Aggiorna la barra del mulino mentre lavora; ricostruisce i pulsanti
	# solo quando la farina diventa pronta, così i clic non vanno persi.
	if not visible or not GameState.productions.has("mulino"):
		return
	var progress := GameState.production_progress("mulino")
	if is_instance_valid(_mill_bar):
		_mill_bar.value = progress * 100.0
	if progress >= 1.0 and not _mill_ready_shown:
		_refresh_mill()


func open_panel(which: String) -> void:
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


func _make_panel(parent: Control, key: String, title: String, subtitle: String, icon_name: String, width: float) -> VBoxContainer:
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
	head.add_child(titles)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(UiKit.label(title, "Title"))
	titles.add_child(UiKit.label(subtitle, "Small"))
	var close := UiKit.button("", "IconButton", "close")
	close.pressed.connect(close_panels)
	head.add_child(close)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	col.add_child(body)
	return body


func _clear(box: Container) -> void:
	for child in box.get_children():
		child.queue_free()


func _refresh() -> void:
	if not is_inside_tree():
		return
	_refresh_orders()
	_refresh_mill()


## Un biglietto per ordine: chi lo chiede, cosa serve (con quanto ne hai), premio.
func _refresh_orders() -> void:
	_clear(_orders_box)
	for i in GameState.orders.size():
		var order: Dictionary = GameState.orders[i]
		var card := PanelContainer.new()
		card.theme_type_variation = "Card"
		_orders_box.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 4)
		row.add_child(info)
		info.add_child(UiKit.label(tr("BORGO_ASKS") % order["giver"], "Heading"))
		var items := HBoxContainer.new()
		items.add_theme_constant_override("separation", 12)
		info.add_child(items)
		for product in order["items"]:
			var need := int(order["items"][product])
			var have := GameState.item_count(product)
			var item := HBoxContainer.new()
			item.add_theme_constant_override("separation", 4)
			var crop_id := GameData.crop_for_product(product)
			var tex: Texture2D = UiKit.crop_icon(crop_id) if crop_id != "" else UiKit.icon("seeds")
			item.add_child(UiKit.texture_rect(tex, 24))
			var l := UiKit.label("%s %d/%d" % [GameData.product_name(product), mini(have, need), need])
			l.add_theme_color_override("font_color", Color("5e7a28") if have >= need else Color("a94c2a"))
			item.add_child(l)
			items.add_child(item)

		var reward := VBoxContainer.new()
		reward.add_theme_constant_override("separation", 2)
		row.add_child(reward)
		var coin_row := HBoxContainer.new()
		coin_row.add_child(UiKit.texture_rect(UiKit.icon("coin"), 22))
		coin_row.add_child(UiKit.label(str(int(order["coins"])), "Heading"))
		coin_row.add_child(UiKit.texture_rect(UiKit.icon("star"), 22))
		coin_row.add_child(UiKit.label(str(int(order["xp"])), "Heading"))
		reward.add_child(coin_row)
		var button := UiKit.button(tr("BORGO_DELIVER"), "PrimaryButton")
		button.disabled = not GameState.can_fulfill(i)
		button.pressed.connect(GameState.fulfill_order.bind(i))
		reward.add_child(button)


func _refresh_mill() -> void:
	_clear(_mill_box)
	_mill_bar = null
	_mill_ready_shown = false
	var b := GameData.building("mulino")
	var label := UiKit.label("")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(220, 0)
	_mill_box.add_child(label)

	if not GameState.is_restored("mulino"):
		var cost: Dictionary = b["restore"]
		label.text = tr("MILL_RUIN") % GameData.resident_name("mulino")
		var need := HBoxContainer.new()
		need.add_theme_constant_override("separation", 6)
		need.add_child(UiKit.texture_rect(UiKit.icon("coin"), 24))
		need.add_child(UiKit.label("%d" % int(cost["coins"]), "Heading"))
		need.add_child(UiKit.texture_rect(UiKit.crop_icon("grano"), 24))
		need.add_child(UiKit.label("%s %d/%d" % [GameData.product_name("grano"), mini(GameState.item_count("grano"), int(cost["items"]["grano"])), int(cost["items"]["grano"])], "Heading"))
		_mill_box.add_child(need)
		if GameState.level < int(b["level"]):
			_mill_box.add_child(UiKit.label(tr("MILL_UNLOCK") % int(b["level"]), "Small"))
		var restore_btn := UiKit.button(tr("MILL_RESTORE"), "PrimaryButton")
		restore_btn.disabled = not GameState.can_restore("mulino")
		restore_btn.pressed.connect(GameState.restore.bind("mulino"))
		_mill_box.add_child(restore_btn)
		return

	var recipe: Dictionary = b["recipe"]
	label.text = "\"%s\"\n%s" % [GameData.building_line("mulino", 1),
		tr("MILL_RECIPE") % [int(recipe["in"]["grano"]), int(recipe["out"]["farina"]), int(recipe["time"]) / 60]]
	_mill_box.add_child(UiKit.label(tr("MILL_FLOUR") % GameState.item_count("farina"), "Heading"))

	var button: Button
	if GameState.productions.has("mulino"):
		var progress := GameState.production_progress("mulino")
		_mill_bar = ProgressBar.new()
		_mill_bar.custom_minimum_size = Vector2(0, 16)
		_mill_bar.show_percentage = false
		_mill_bar.value = progress * 100.0
		_mill_box.add_child(_mill_bar)
		_mill_ready_shown = progress >= 1.0
		button = UiKit.button(tr("MILL_COLLECT") if progress >= 1.0 else tr("MILL_WORKING"), "PrimaryButton")
		button.disabled = progress < 1.0
		button.pressed.connect(GameState.collect_production.bind("mulino"))
	else:
		button = UiKit.button(tr("MILL_GRIND"), "PrimaryButton")
		button.disabled = not GameState.has_items(recipe["in"])
		button.pressed.connect(GameState.start_production.bind("mulino"))
	_mill_box.add_child(button)
