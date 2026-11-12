class_name LandPanel
extends PanelContainer
## Acquisto di un lotto di terra 6×6: livello, monete e oggetti antichi
## richiesti, ciascuno con quanto ne hai.

var sector := Vector2i.ZERO
var _body: VBoxContainer


func _ready() -> void:
	theme_type_variation = "Sheet"
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -260
	offset_right = 260
	offset_top = -240
	offset_bottom = 200
	mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	top.add_child(UiKit.texture_rect(UiKit.icon("farm"), 48))
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -4)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(titles)
	titles.add_child(UiKit.label(tr("LAND_TITLE"), "Title"))
	titles.add_child(UiKit.label(tr("LAND_SUB"), "Small"))
	var close := UiKit.button("", "IconButton", "close")
	close.pressed.connect(hide)
	top.add_child(close)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	col.add_child(_body)
	GameState.changed.connect(_refresh)


func open(s: Vector2i) -> void:
	sector = s
	show()
	_refresh()


func _refresh() -> void:
	if not visible or _body == null:
		return
	for child in _body.get_children():
		child.queue_free()
	if GameState.is_sector_owned(sector):
		hide()
		return
	var cost := GameState.sector_cost(sector)
	if not GameState.is_sector_buyable(sector):
		var l := UiKit.label(tr("LAND_NOT_ADJACENT"))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(l)
		return
	_body.add_child(UiKit.label(tr("LAND_NEED"), "Heading"))
	_need_row(UiKit.icon("star"), tr("LAND_LEVEL") % int(cost["level"]), GameState.level >= int(cost["level"]))
	_need_row(UiKit.icon("coin"), "%d / %d" % [mini(GameState.coins, int(cost["coins"])), int(cost["coins"])], GameState.coins >= int(cost["coins"]))
	for id in cost["antiques"]:
		var need := int(cost["antiques"][id])
		var have := GameState.antique_count(id)
		_need_row(UiKit.antique_icon(id), "%s  %d / %d" % [GameData.antique_name(id), mini(have, need), need], have >= need)
	var hint := UiKit.label(tr("LAND_HINT"), "Small")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(hint)
	var buy := UiKit.button(tr("LAND_BUY"), "PrimaryButton", "coin")
	buy.add_theme_constant_override("icon_max_width", 24)
	buy.custom_minimum_size = Vector2(0, 48)
	buy.disabled = not GameState.can_buy_sector(sector)
	buy.pressed.connect(func() -> void: GameState.buy_sector(sector))
	_body.add_child(buy)


func _need_row(icon: Texture2D, text: String, ok: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiKit.texture_rect(icon, 30))
	var l := UiKit.label(text, "Heading")
	l.add_theme_color_override("font_color", Color("5e7a28") if ok else Color("a94c2a"))
	row.add_child(l)
	_body.add_child(row)
