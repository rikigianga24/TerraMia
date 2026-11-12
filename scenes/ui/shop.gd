class_name Shop
extends PanelContainer
## Negozio del consorzio agrario: semi di tutte le piante (bloccate fino al
## loro livello) e concime, a schede su tre colonne.

signal seed_bought(crop_id: String)

const KIND_LABEL := {"crop": "Coltura", "tree": "Albero", "bush": "Arbusto"}
const COLUMNS := 3

var _grid: GridContainer
var _coins: Label
var _tab := "crop"
var _tab_buttons: Dictionary = {}


func _ready() -> void:
	theme_type_variation = "Sheet"
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -440
	offset_right = 440
	offset_top = -300
	offset_bottom = 250
	mouse_filter = Control.MOUSE_FILTER_STOP

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	add_child(col)

	# Intestazione: titolo, monete, chiudi
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	top.add_child(UiKit.texture_rect(UiKit.icon("shop"), 48))
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -4)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(titles)
	titles.add_child(UiKit.label("Consorzio agrario", "Title"))
	titles.add_child(UiKit.label("Semi, piantine e concime per la tua terra", "Small"))
	var coins := UiKit.stat_pill("coin")
	_coins = coins[1]
	top.add_child(coins[0])
	var close := UiKit.button("", "IconButton", "close")
	close.pressed.connect(hide)
	top.add_child(close)

	# Schede: colture, alberi e arbusti, concime
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	col.add_child(tabs)
	var group := ButtonGroup.new()
	for t in [["crop", "Colture", "seeds"], ["tree", "Alberi e arbusti", "farm"], ["extra", "Concime", "fertilizer"]]:
		var b := UiKit.button(t[1], "ToolButton", t[2])
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_constant_override("icon_max_width", 28)
		var id: String = t[0]
		b.pressed.connect(_select_tab.bind(id))
		tabs.add_child(b)
		_tab_buttons[id] = b
	_tab_buttons[_tab].button_pressed = true

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)

	GameState.changed.connect(_refresh)
	visibility_changed.connect(_refresh)
	_refresh()


func _select_tab(id: String) -> void:
	_tab = id
	_refresh()


func _refresh() -> void:
	if not visible or _grid == null:
		return
	_coins.text = str(GameState.coins)
	for child in _grid.get_children():
		child.queue_free()
	if _tab == "extra":
		_add_card(UiKit.icon("fertilizer"), "Concime",
			"Raddoppia il prossimo raccolto della pianta su cui lo spargi.",
			"Ne hai %d" % GameState.fertilizer, GameData.FERTILIZER_LEVEL, GameData.FERTILIZER_PRICE,
			func(qty: int) -> void: GameState.buy_fertilizer(qty))
		return
	for id in GameData.all_plants():
		var perennial := GameData.is_perennial(id)
		if perennial != (_tab == "tree"):
			continue
		var c := GameData.crop(id)
		var detail := "%s · %s\nResa %d %s · %d monete l'uno" % [
			KIND_LABEL.get(c["kind"], c["kind"]), GameData.format_time(int(c["time"])),
			int(c["yield"]), c["product"], int(c["sell_price"])]
		if perennial:
			detail += "\nResta piantato e rifà i frutti"
		var buy := func(qty: int) -> void:
			if GameState.buy_seeds(id, qty):
				seed_bought.emit(id)
		_add_card(UiKit.crop_icon(id), c["name"], detail, "Ne hai %d" % GameState.seed_count(id),
			int(c["level"]), int(c["seed_cost"]), buy)


func _add_card(icon: Texture2D, title: String, detail: String, owned: String,
		unlock_level: int, price: int, buy: Callable) -> void:
	var locked := GameState.level < unlock_level
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(250, 0)
	_grid.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)
	var pic := UiKit.texture_rect(UiKit.icon("lock") if locked else icon, 40)
	head.add_child(pic)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -4)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	names.add_child(UiKit.label(title, "Heading"))
	names.add_child(UiKit.label("Si sblocca al livello %d" % unlock_level if locked else owned, "Small"))

	var info := UiKit.label(detail, "Small")
	info.add_theme_font_size_override("font_size", 13)
	col.add_child(info)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	col.add_child(buttons)
	for qty in [1, 5]:
		var b := UiKit.button("%s%d" % ["" if qty == 1 else "×5  ", price * qty], "PrimaryButton", "coin")
		b.add_theme_constant_override("icon_max_width", 20)
		b.add_theme_font_size_override("font_size", 16)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = locked or GameState.coins < price * qty
		b.pressed.connect(buy.bind(qty))
		buttons.add_child(b)
	if locked:
		card.modulate = Color(1, 1, 1, 0.6)
