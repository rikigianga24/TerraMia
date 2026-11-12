extends Node
## Scena principale: tiene insieme sfondo, Fattoria, Borgo, Negozio e HUD.
##
## HUD:
##   in alto a sinistra  monete, Lire d'oro, gocce, espresso
##   in alto a destra    livello ed esperienza
##   in basso al centro  strumenti e semi (solo in fattoria)
##   in basso ai lati    Fattoria / Borgo e Negozio
## Il pulsante Borgo mostra un pallino quando c'è qualcosa da fare.

const TOOLS := [
	{"id": "hand", "label": "Raccogli", "icon": "hand"},
	{"id": "hoe", "label": "Zappa", "icon": "hoe"},
	{"id": "water", "label": "Annaffia", "icon": "watering_can"},
	{"id": "fertilizer", "label": "Concime", "icon": "fertilizer"},
]

@onready var farm: Farm = $Farm
@onready var borgo: Borgo = $BorgoLayer/Borgo
@onready var hud: Control = $HUD/Root

var _backdrop: Backdrop
var _coins: Label
var _lire: Label
var _water: Label
var _water_timer: Label
var _espresso: Label
var _level: Label
var _xp_bar: ProgressBar
var _xp_text: Label
var _toast_panel: PanelContainer
var _toast: Label
var _toast_tween: Tween
var _dock: PanelContainer
var _tool_buttons: Dictionary = {}     ## id strumento -> Button
var _seed_row: HBoxContainer
var _seed_buttons: Dictionary = {}     ## coltura -> Button
var _tool_group := ButtonGroup.new()
var _farm_btn: Button
var _borgo_btn: Button
var _shop_btn: Button
var _shop: Shop


func _ready() -> void:
	_build_backdrop()
	_build_hud()
	GameState.changed.connect(_refresh_hud)
	GameState.toast.connect(show_toast)
	farm.tool_changed.connect(func(_t: String) -> void: _sync_tool_buttons())
	show_farm()
	_refresh_hud()

	# Moka e pozzo si ricaricano anche mentre si gioca.
	var regen := Timer.new()
	regen.wait_time = 1.0
	regen.autostart = true
	regen.timeout.connect(_on_regen_tick)
	add_child(regen)


func _on_regen_tick() -> void:
	GameState.tick_moka()
	GameState.tick_water()
	_refresh_stats()


func show_farm() -> void:
	farm.visible = true
	borgo.visible = false
	_backdrop.mode = "farm"
	_dock.visible = true
	_farm_btn.button_pressed = true


func show_borgo() -> void:
	farm.visible = false
	borgo.visible = true
	_backdrop.mode = "borgo"
	_dock.visible = false
	_shop.hide()
	_borgo_btn.button_pressed = true


func show_toast(message: String) -> void:
	_toast.text = message
	_toast_panel.modulate.a = 1.0
	_toast_panel.visible = true
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_panel.scale = Vector2(0.9, 0.9)
	_toast_tween.tween_property(_toast_panel, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.5)


func select_seed(crop_id: String) -> void:
	farm.selected_crop = crop_id
	farm.tool = "seed"


# --- Costruzione HUD --------------------------------------------------------

func _build_backdrop() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	move_child(layer, 0)
	_backdrop = Backdrop.new()
	layer.add_child(_backdrop)


func _build_hud() -> void:
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# In alto a sinistra: risorse
	var stats := HBoxContainer.new()
	stats.position = Vector2(14, 12)
	stats.add_theme_constant_override("separation", 10)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(stats)
	var p := UiKit.stat_pill("coin")
	stats.add_child(p[0]); _coins = p[1]
	p = UiKit.stat_pill("lira")
	stats.add_child(p[0]); _lire = p[1]
	p = UiKit.stat_pill("drop")
	stats.add_child(p[0]); _water = p[1]; _water_timer = p[2]
	p = UiKit.stat_pill("espresso")
	stats.add_child(p[0]); _espresso = p[1]
	(p[0] as Control).tooltip_text = "Espresso: la moka ne fa uno ogni 2 ore"

	# In alto a destra: livello
	var level_box := PanelContainer.new()
	level_box.theme_type_variation = "Pill"
	level_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud.add_child(level_box)
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 8)
	level_box.add_child(level_row)
	var star := Control.new()
	star.custom_minimum_size = Vector2(44, 44)
	level_row.add_child(star)
	var star_icon := UiKit.texture_rect(UiKit.icon("star"), 44)
	star_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	star.add_child(star_icon)
	_level = UiKit.label("1", "PillValue")
	_level.set_anchors_preset(Control.PRESET_FULL_RECT)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level.add_theme_font_size_override("font_size", 17)
	_level.add_theme_color_override("font_color", Color("7a4a10"))
	_level.position.y = 2
	star.add_child(_level)
	var xp_col := VBoxContainer.new()
	xp_col.alignment = BoxContainer.ALIGNMENT_CENTER
	xp_col.add_theme_constant_override("separation", 2)
	level_row.add_child(xp_col)
	_xp_text = UiKit.label("Livello 1", "Small")
	xp_col.add_child(_xp_text)
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(150, 14)
	_xp_bar.show_percentage = false
	xp_col.add_child(_xp_bar)
	level_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)

	# Messaggi brevi, centrati sopra la barra degli strumenti
	var toast_holder := CenterContainer.new()
	toast_holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	toast_holder.offset_top = -150
	toast_holder.offset_bottom = -110
	toast_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(toast_holder)
	_toast_panel = PanelContainer.new()
	_toast_panel.theme_type_variation = "Toast"
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.visible = false
	toast_holder.add_child(_toast_panel)
	_toast = UiKit.label("", "ToastLabel")
	_toast_panel.add_child(_toast)
	_toast_panel.resized.connect(func() -> void: _toast_panel.pivot_offset = _toast_panel.size * 0.5)

	# In basso a sinistra: Fattoria / Borgo
	var nav := VBoxContainer.new()
	nav.grow_vertical = Control.GROW_DIRECTION_BEGIN
	nav.add_theme_constant_override("separation", 8)
	hud.add_child(nav)
	var nav_group := ButtonGroup.new()
	_farm_btn = _nav_button(nav, "Fattoria", "farm", show_farm, nav_group)
	_borgo_btn = _nav_button(nav, "Borgo", "borgo", show_borgo, nav_group)
	nav.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 14)

	# In basso a destra: Negozio
	_shop_btn = UiKit.button("Negozio", "NavButton", "shop")
	_shop_btn.custom_minimum_size = Vector2(170, 58)
	_shop_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_shop_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_shop_btn.pressed.connect(_toggle_shop)
	hud.add_child(_shop_btn)
	_shop_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 14)

	# In basso al centro: strumenti e semi
	var dock_holder := CenterContainer.new()
	dock_holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dock_holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dock_holder.offset_bottom = -12
	dock_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(dock_holder)
	_dock = PanelContainer.new()
	_dock.theme_type_variation = "Dock"
	dock_holder.add_child(_dock)
	var dock_row := HBoxContainer.new()
	dock_row.add_theme_constant_override("separation", 8)
	_dock.add_child(dock_row)
	for t in TOOLS:
		var b := _tool_button(t["label"], t["icon"])
		var id: String = t["id"]
		b.pressed.connect(func() -> void: farm.tool = id)
		dock_row.add_child(b)
		_tool_buttons[id] = b
	var sep := VSeparator.new()
	sep.add_theme_constant_override("separation", 10)
	dock_row.add_child(sep)
	var seed_scroll := ScrollContainer.new()
	seed_scroll.custom_minimum_size = Vector2(420, 76)
	seed_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dock_row.add_child(seed_scroll)
	_seed_row = HBoxContainer.new()
	_seed_row.add_theme_constant_override("separation", 6)
	_seed_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_seed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	seed_scroll.add_child(_seed_row)

	_shop = Shop.new()
	_shop.visible = false
	_shop.seed_bought.connect(select_seed)
	hud.add_child(_shop)


func _tool_button(text: String, icon_name: String) -> Button:
	var b := UiKit.button(text, "ToolButton", icon_name)
	b.toggle_mode = true
	b.button_group = _tool_group
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.expand_icon = false
	b.custom_minimum_size = Vector2(82, 76)
	return b


func _nav_button(parent: Control, text: String, icon_name: String, action: Callable, group: ButtonGroup) -> Button:
	var b := UiKit.button(text, "NavButton", icon_name)
	b.toggle_mode = true
	b.button_group = group
	b.custom_minimum_size = Vector2(170, 54)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _toggle_shop() -> void:
	if _shop.visible:
		_shop.hide()
	else:
		show_farm()
		_shop.show()


## Un pulsante per ogni seme posseduto; se non ne hai, invita al negozio.
func _rebuild_seed_row() -> void:
	var owned: Array = []
	for id in GameData.all_plants():
		if GameState.seed_count(id) > 0:
			owned.append(id)
	if owned == _seed_buttons.keys():
		for id in owned:
			_seed_buttons[id].text = "%s\n×%d" % [GameData.crop(id)["name"], GameState.seed_count(id)]
		return
	for child in _seed_row.get_children():
		child.queue_free()
	_seed_buttons = {}
	if owned.is_empty():
		var hint := Button.new()
		hint.text = "Niente semi: vai al Negozio"
		hint.icon = UiKit.icon("seeds")
		hint.theme_type_variation = "SeedButton"
		hint.pressed.connect(_toggle_shop)
		_seed_row.add_child(hint)
		if farm.tool == "seed":
			farm.tool = "hand"
		return
	for id in owned:
		var b := UiKit.button("", "SeedButton")
		b.icon = UiKit.crop_icon(id)
		b.text = "%s\n×%d" % [GameData.crop(id)["name"], GameState.seed_count(id)]
		b.toggle_mode = true
		b.button_group = _tool_group
		b.custom_minimum_size = Vector2(0, 66)
		b.pressed.connect(select_seed.bind(id))
		_seed_row.add_child(b)
		_seed_buttons[id] = b
	if farm.tool == "seed" and GameState.seed_count(farm.selected_crop) <= 0:
		select_seed(owned[0])
	_sync_tool_buttons()


func _sync_tool_buttons() -> void:
	for id in _tool_buttons:
		_tool_buttons[id].set_pressed_no_signal(farm.tool == id)
	for id in _seed_buttons:
		_seed_buttons[id].set_pressed_no_signal(farm.tool == "seed" and farm.selected_crop == id)


# --- Aggiornamento ----------------------------------------------------------

func _refresh_stats() -> void:
	_coins.text = str(GameState.coins)
	_lire.text = str(GameState.lire_oro)
	_water.text = "%d/%d" % [GameState.water, GameData.WATER_MAX]
	var next := GameState.water_seconds_to_next()
	_water_timer.visible = next > 0
	_water_timer.text = "+1 tra %s" % GameData.format_time(next)
	_espresso.text = "%d/%d" % [GameState.espresso, GameData.MOKA_MAX]


func _refresh_hud() -> void:
	_refresh_stats()
	_level.text = str(GameState.level)
	var next_xp := GameData.xp_for_level(GameState.level + 1)
	_xp_text.text = "Livello %d · %d/%d esp." % [GameState.level, GameState.xp, next_xp] if GameState.level < GameData.MAX_LEVEL else "Livello massimo"
	_xp_bar.value = GameState.xp_progress() * 100.0
	_tool_buttons["fertilizer"].text = "Concime ×%d" % GameState.fertilizer
	_rebuild_seed_row()
	_borgo_btn.text = "Borgo  •" if GameState.any_order_ready() or GameState.can_restore("mulino") else "Borgo"
