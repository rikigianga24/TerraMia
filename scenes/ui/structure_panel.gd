class_name StructurePanel
extends PanelContainer
## Pannello di una struttura posata (falegnameria, cucina): ricette con
## ingredienti, espresso, monete e tempo; la ricetta in corso con la barra e
## il pulsante per ritirarla; in cucina anche la vendita dei prodotti fatti in casa.

var uid := -1
var _body: VBoxContainer
var _title: Label
var _bar: ProgressBar
var _ready_shown := false


func _ready() -> void:
	theme_type_variation = "Sheet"
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -380
	offset_right = 380
	offset_top = -300
	offset_bottom = 240
	mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	_title = UiKit.label("", "Title")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	var close := UiKit.button("", "IconButton", "close")
	close.pressed.connect(hide)
	top.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	scroll.add_child(_body)
	GameState.changed.connect(_refresh)


func open(structure_uid: int) -> void:
	uid = structure_uid
	show()
	_refresh()


func _process(_delta: float) -> void:
	if not visible or uid < 0:
		return
	var o := GameState.get_object(uid)
	if o.is_empty() or not o.has("recipe"):
		return
	var p := GameState.recipe_progress(uid)
	if is_instance_valid(_bar):
		_bar.value = p * 100.0
	if p >= 1.0 and not _ready_shown:
		_refresh()


func _refresh() -> void:
	if not visible or _body == null:
		return
	for c in _body.get_children():
		c.queue_free()
	_bar = null
	_ready_shown = false
	var o := GameState.get_object(uid)
	if o.is_empty():
		hide()
		return
	var type: String = o["type"]
	_title.text = GameData.structure_name(type)

	# ricetta in corso
	if o.has("recipe"):
		var card := PanelContainer.new()
		card.theme_type_variation = "Card"
		_body.add_child(card)
		var row := VBoxContainer.new()
		card.add_child(row)
		var p := GameState.recipe_progress(uid)
		row.add_child(UiKit.label(tr("PANEL_WORKING") % GameData.recipe_name(o["recipe"]), "Heading"))
		_bar = ProgressBar.new()
		_bar.show_percentage = false
		_bar.custom_minimum_size = Vector2(0, 16)
		_bar.value = p * 100.0
		row.add_child(_bar)
		_ready_shown = p >= 1.0
		var b := UiKit.button(tr("PANEL_COLLECT"), "PrimaryButton")
		b.disabled = p < 1.0
		b.pressed.connect(func() -> void: GameState.collect_recipe(uid))
		row.add_child(b)

	# ricette
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_body.add_child(grid)
	for rid in GameData.STRUCTURES[type]["recipes"]:
		_recipe_card(grid, rid, o.has("recipe"))

	# vendita dei prodotti fatti in casa
	if type == "cucina":
		_body.add_child(HSeparator.new())
		_body.add_child(UiKit.label(tr("PANEL_SELL_TITLE"), "Heading"))
		var any := false
		for rid in GameData.STRUCTURES["cucina"]["recipes"]:
			var prod: String = GameData.RECIPES[rid]["out"]
			var n := GameState.item_count(prod)
			if n <= 0:
				continue
			any = true
			var row2 := HBoxContainer.new()
			row2.add_theme_constant_override("separation", 10)
			_body.add_child(row2)
			var l := UiKit.label("%s ×%d" % [GameData.recipe_name(prod), n], "Heading")
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row2.add_child(l)
			var sb := UiKit.button("%s  %d" % [tr("PANEL_SELL"), int(GameData.SELL_PRICES[prod])], "PrimaryButton", "coin")
			sb.add_theme_constant_override("icon_max_width", 20)
			sb.pressed.connect(func() -> void: GameState.sell(prod, 1))
			row2.add_child(sb)
		if not any:
			_body.add_child(UiKit.label(tr("PANEL_NOTHING_TO_SELL"), "Small"))


func _recipe_card(parent: Control, rid: String, busy: bool) -> void:
	var r: Dictionary = GameData.RECIPES[rid]
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(330, 0)
	parent.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var name_l := UiKit.label(GameData.recipe_name(rid), "Heading")
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_l)
	head.add_child(UiKit.label(GameData.format_time(int(r["time"])), "Small"))
	var needs := HBoxContainer.new()
	needs.add_theme_constant_override("separation", 10)
	col.add_child(needs)
	for prod in r["in"]:
		var need := int(r["in"][prod])
		var have := GameState.item_count(prod)
		var crop := GameData.crop_for_product(prod)
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 3)
		if crop != "":
			item.add_child(UiKit.texture_rect(UiKit.crop_icon(crop), 20))
		var l := UiKit.label("%s %d/%d" % [GameData.product_name(prod), mini(have, need), need], "Small")
		l.add_theme_color_override("font_color", Color("5e7a28") if have >= need else Color("a94c2a"))
		item.add_child(l)
		needs.add_child(item)
	if int(r["espresso"]) > 0:
		var e := HBoxContainer.new()
		e.add_child(UiKit.texture_rect(UiKit.icon("espresso"), 20))
		var l2 := UiKit.label("%d/%d" % [mini(GameState.espresso, int(r["espresso"])), int(r["espresso"])], "Small")
		l2.add_theme_color_override("font_color", Color("5e7a28") if GameState.espresso >= int(r["espresso"]) else Color("a94c2a"))
		e.add_child(l2)
		needs.add_child(e)
	if int(r["coins"]) > 0:
		var cbox := HBoxContainer.new()
		cbox.add_child(UiKit.texture_rect(UiKit.icon("coin"), 20))
		cbox.add_child(UiKit.label(str(int(r["coins"])), "Small"))
		needs.add_child(cbox)
	var b := UiKit.button(tr("PANEL_MAKE"), "PrimaryButton")
	b.disabled = busy or not GameState.can_start_recipe(uid, rid)
	b.pressed.connect(func() -> void: GameState.start_recipe(uid, rid))
	col.add_child(b)
