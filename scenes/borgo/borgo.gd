class_name Borgo
extends Control
## Il borgo: bacheca degli ordini in piazza e il mulino da restaurare.
## Interfaccia costruita da codice finché non arriva la grafica del borgo.

var _orders_box: VBoxContainer
var _mill_box: VBoxContainer
var _mill_bar: ProgressBar
var _mill_ready_shown := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color("e9d8b4")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.add_theme_constant_override("margin_top", 72)
	margin.add_theme_constant_override("margin_bottom", 96)
	add_child(margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	margin.add_child(columns)

	_orders_box = _make_panel(columns, "Bacheca degli ordini")
	_mill_box = _make_panel(columns, "Mulino")

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


func _make_panel(parent: Control, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var inner := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(inner)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	inner.add_child(col)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 24)
	col.add_child(label)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
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


func _refresh_orders() -> void:
	_clear(_orders_box)
	for i in GameState.orders.size():
		var order: Dictionary = GameState.orders[i]
		var row := HBoxContainer.new()
		var parts: PackedStringArray = []
		for product in order["items"]:
			parts.append("%d %s (%d)" % [int(order["items"][product]), product, GameState.item_count(product)])
		var label := Label.new()
		label.text = "%s chiede: %s\n→ %d monete, %d esp." % [order["giver"], ", ".join(parts), int(order["coins"]), int(order["xp"])]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := Button.new()
		button.text = "Consegna"
		button.disabled = not GameState.can_fulfill(i)
		button.pressed.connect(GameState.fulfill_order.bind(i))
		row.add_child(button)
		_orders_box.add_child(row)


func _refresh_mill() -> void:
	_clear(_mill_box)
	_mill_bar = null
	_mill_ready_shown = false
	var b := GameData.building("mulino")
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mill_box.add_child(label)

	if not GameState.is_restored("mulino"):
		var cost: Dictionary = b["restore"]
		label.text = "Un rudere coperto d'edera. Restauralo per riportare %s.\nServono: %d monete e %d grano (hai %d).\nSi sblocca al livello %d." % [
			b["resident"], int(cost["coins"]), int(cost["items"]["grano"]),
			GameState.item_count("grano"), int(b["level"])]
		var restore_btn := Button.new()
		restore_btn.text = "Restaura"
		restore_btn.disabled = not GameState.can_restore("mulino")
		restore_btn.pressed.connect(GameState.restore.bind("mulino"))
		_mill_box.add_child(restore_btn)
		return

	var recipe: Dictionary = b["recipe"]
	label.text = "%s: \"%s\"\n%d grano → %d farina in %d min. Farina in magazzino: %d." % [
		b["resident"], b["lines"][1], int(recipe["in"]["grano"]), int(recipe["out"]["farina"]),
		int(recipe["time"]) / 60, GameState.item_count("farina")]

	var button := Button.new()
	if GameState.productions.has("mulino"):
		var progress := GameState.production_progress("mulino")
		_mill_bar = ProgressBar.new()
		_mill_bar.value = progress * 100.0
		_mill_box.add_child(_mill_bar)
		_mill_ready_shown = progress >= 1.0
		button.text = "Ritira la farina" if progress >= 1.0 else "Macina in corso..."
		button.disabled = progress < 1.0
		button.pressed.connect(GameState.collect_production.bind("mulino"))
	else:
		button.text = "Macina"
		button.disabled = not GameState.has_items(recipe["in"])
		button.pressed.connect(GameState.start_production.bind("mulino"))
	_mill_box.add_child(button)
