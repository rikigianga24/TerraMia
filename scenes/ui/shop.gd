class_name Shop
extends PanelContainer
## Negozio: semi di tutte le piante (bloccate fino al loro livello) e concime.
## Interfaccia costruita da codice, come il resto della grafica provvisoria.

signal seed_bought(crop_id: String)

const KIND_LABEL := {"crop": "coltura", "tree": "albero", "bush": "arbusto"}

var _list: VBoxContainer
var _header: Label


func _ready() -> void:
	# Centrato, 780×520, sopra la fattoria.
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -390
	offset_right = 390
	offset_top = -300
	offset_bottom = 220
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("3d4a52")
	style.set_corner_radius_all(10)
	style.shadow_size = 12
	style.shadow_color = Color(0, 0, 0, 0.35)
	add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	var top := HBoxContainer.new()
	col.add_child(top)
	var title := Label.new()
	title.text = "Negozio del consorzio agrario"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 18)
	top.add_child(_header)
	var close := Button.new()
	close.text = "  Chiudi  "
	close.pressed.connect(hide)
	top.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	GameState.changed.connect(_refresh)
	visibility_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if not visible:
		return
	_header.text = "Monete %d   " % GameState.coins
	for child in _list.get_children():
		child.queue_free()

	_add_row(
		"Concime",
		"Raddoppia il prossimo raccolto della pianta su cui lo spargi.",
		"Hai %d" % GameState.fertilizer,
		GameData.FERTILIZER_LEVEL,
		GameData.FERTILIZER_PRICE,
		func(qty: int) -> void: GameState.buy_fertilizer(qty))

	for id in GameData.all_plants():
		var c := GameData.crop(id)
		var detail := "%s · %s · resa %d %s · vale %d l'uno" % [
			KIND_LABEL.get(c["kind"], c["kind"]), GameData.format_time(int(c["time"])),
			int(c["yield"]), c["product"], int(c["sell_price"])]
		if GameData.is_perennial(id):
			detail += " · resta piantato"
		var buy := func(qty: int) -> void:
			if GameState.buy_seeds(id, qty):
				seed_bought.emit(id)
		_add_row(c["name"], detail, "Hai %d" % GameState.seed_count(id), int(c["level"]), int(c["seed_cost"]), buy)


func _add_row(title: String, detail: String, owned: String, unlock_level: int, price: int, buy: Callable) -> void:
	var locked := GameState.level < unlock_level
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if locked:
		row.modulate = Color(1, 1, 1, 0.45)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	var name_label := Label.new()
	name_label.text = title
	name_label.add_theme_font_size_override("font_size", 18)
	text.add_child(name_label)
	var detail_label := Label.new()
	detail_label.text = detail
	detail_label.add_theme_font_size_override("font_size", 13)
	text.add_child(detail_label)
	row.add_child(text)

	var owned_label := Label.new()
	owned_label.text = "Livello %d" % unlock_level if locked else owned
	owned_label.custom_minimum_size = Vector2(80, 0)
	row.add_child(owned_label)

	for qty in [1, 5]:
		var b := Button.new()
		b.text = "+%d · %d" % [qty, price * qty]
		b.custom_minimum_size = Vector2(96, 40)
		b.disabled = locked or GameState.coins < price * qty
		b.pressed.connect(buy.bind(qty))
		row.add_child(b)
	_list.add_child(row)
	_list.add_child(HSeparator.new())
