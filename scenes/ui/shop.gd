class_name Shop
extends PanelContainer
## Negozio del consorzio agrario, a schede: semi, alberi, scorte (concime e
## biberon), animali, strutture e le decorazioni costruite da posizionare.

signal seed_bought(crop_id: String)
## Animale, struttura o decorazione da posizionare sulla fattoria.
signal place_requested(kind: String, type: String, source: String)

const KIND_LABEL := {"crop": "KIND_CROP", "tree": "KIND_TREE", "bush": "KIND_BUSH"}
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
	titles.add_child(UiKit.label(tr("SHOP_TITLE"), "Title"))
	titles.add_child(UiKit.label(tr("SHOP_SUBTITLE"), "Small"))
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
	for t in [["crop", "SHOP_TAB_CROPS", "seeds"], ["tree", "SHOP_TAB_TREES", "farm"], ["extra", "SHOP_TAB_FERTILIZER", "fertilizer"],
			["animals", "SHOP_TAB_ANIMALS", "farm"], ["structures", "SHOP_TAB_STRUCTURES", "shop"], ["decor", "SHOP_TAB_DECOR", "star"]]:
		var b := UiKit.button(tr(t[1]), "ToolButton", t[2])
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_constant_override("icon_max_width", 24)
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
		_add_card(UiKit.icon("fertilizer"), tr("TOOL_FERTILIZER"),
			tr("SHOP_FERTILIZER_DESC"),
			tr("SHOP_OWNED") % GameState.fertilizer, GameData.FERTILIZER_LEVEL, GameData.FERTILIZER_PRICE,
			func(qty: int) -> void: GameState.buy_fertilizer(qty))
		_add_card(UiKit.icon("drop"), tr("SHOP_BIBERON"), tr("SHOP_BIBERON_DESC"),
			tr("SHOP_OWNED") % GameState.biberon, 1, GameData.BIBERON_PRICE,
			func(qty: int) -> void: GameState.buy_biberon(qty))
		return
	if _tab == "animals":
		for id in GameData.ANIMALS:
			var a: Dictionary = GameData.ANIMALS[id]
			var detail: String = tr("SHOP_ANIMAL_DESC") % [int(a["bottles"]), GameData.product_name(a["product"])]
			_add_card(_object_icon("animal", id), GameData.animal_name(id, true) + " / " + GameData.animal_name(id), detail, "",
				int(a["level"]), int(a["price"]), _requester("animal", id, "buy"), true)
		return
	if _tab == "structures":
		for id in GameData.STRUCTURES:
			var st: Dictionary = GameData.STRUCTURES[id]
			_add_card(_object_icon("structure", id), GameData.structure_name(id), tr("STRUCT_DESC_" + id.to_upper()), "",
				int(st["level"]), int(st["price"]), _requester("structure", id, "buy"), true)
		return
	if _tab == "decor":
		if GameState.decor_inv.is_empty():
			_grid.add_child(UiKit.label(tr("SHOP_DECOR_NONE")))
		for id in GameState.decor_inv:
			_add_card(_object_icon("decor", id), GameData.recipe_name(id), "", tr("SHOP_OWNED") % int(GameState.decor_inv[id]),
				1, 0, _requester("decor", id, "decor"), true, tr("SHOP_DECOR_PLACE"))
		return
	for id in GameData.all_plants():
		var perennial := GameData.is_perennial(id)
		if perennial != (_tab == "tree"):
			continue
		var c := GameData.crop(id)
		var detail: String = tr("SHOP_DETAIL") % [
			tr(KIND_LABEL.get(c["kind"], c["kind"])), GameData.format_time(int(c["time"])),
			int(c["yield"]), GameData.product_name(c["product"]), int(c["sell_price"])]
		if perennial:
			detail += "\n" + tr("SHOP_PERENNIAL")
		var buy := func(qty: int) -> void:
			if GameState.buy_seeds(id, qty):
				seed_bought.emit(id)
		_add_card(UiKit.crop_icon(id), GameData.crop_name(id), detail, tr("SHOP_OWNED") % GameState.seed_count(id),
			int(c["level"]), int(c["seed_cost"]), buy)


## Pulsante che chiede alla fattoria di posizionare (il negozio si chiude).
func _requester(kind: String, type: String, source: String) -> Callable:
	return func(_qty: int) -> void:
		place_requested.emit(kind, type, source)
		hide()


const OBJECT_SPRITES := {
	"gallina": "gallina", "mucca": "mucca", "falegnameria": "capanno", "cucina": "casetta",
	"staccionata": "staccionata", "barile": "botte", "panchina": "panchina",
}


func _object_icon(_kind: String, type: String) -> Texture2D:
	var t := Sprites.tex(OBJECT_SPRITES.get(type, ""))
	return t if t != null else UiKit.icon("farm")


func _add_card(icon: Texture2D, title: String, detail: String, owned: String,
		unlock_level: int, price: int, buy: Callable, single := false, button_text := "") -> void:
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
	names.add_child(UiKit.label(tr("SHOP_UNLOCK") % unlock_level if locked else owned, "Small"))

	var info := UiKit.label(detail, "Small")
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(220, 0)
	info.add_theme_font_size_override("font_size", 13)
	col.add_child(info)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	col.add_child(buttons)
	for qty in ([1] if single else [1, 5]):
		var text := button_text if button_text != "" else "%s%d" % ["" if qty == 1 else "×5  ", price * qty]
		var b := UiKit.button(text, "PrimaryButton", "" if button_text != "" else "coin")
		b.add_theme_constant_override("icon_max_width", 20)
		b.add_theme_font_size_override("font_size", 16)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = locked or GameState.coins < price * qty
		b.pressed.connect(buy.bind(qty))
		buttons.add_child(b)
	if locked:
		card.modulate = Color(1, 1, 1, 0.6)
