extends Node
## Scena principale: tiene insieme sfondo, Fattoria, Borgo, Negozio e HUD.
##
## HUD:
##   in alto a sinistra  monete, Nostalgie, gocce, espresso
##   in alto al centro   abitanti del borgo; valutazione e visitatori
##   in alto a destra    livello ed esperienza
##   in basso al centro  strumenti e semi (solo in fattoria)
##   in basso ai lati    Fattoria / Borgo e Negozio
## Il pulsante Borgo mostra un pallino quando c'è qualcosa da fare.

const TOOLS := [
	{"id": "hand", "label": "TOOL_HAND", "icon": "hand"},
	{"id": "hoe", "label": "TOOL_HOE", "icon": "hoe"},
	{"id": "water", "label": "TOOL_WATER", "icon": "watering_can"},
	{"id": "fertilizer", "label": "TOOL_FERTILIZER", "icon": "fertilizer"},
]

@onready var farm: Farm = $Farm
@onready var borgo: Borgo = $BorgoLayer/Borgo
@onready var hud: Control = $HUD/Root

var _backdrop: Backdrop
var _coins: Label
var _lire: Label
var _pop_label: Label
var _pop_bar: ProgressBar
var _rating_row: HBoxContainer
var _stars: Array = []
var _visitors: Label
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
var _land: LandPanel
var _structure: StructurePanel
var _place_bar: PanelContainer
var borgo_map: BorgoMap
var _travel: TravelOverlay
var _travel_dest := ""
var _settings: SettingsPanel
## Dopo un cambio di lingua la scena si ricarica: riapre le impostazioni.
static var reopen_settings := false


func _ready() -> void:
	_build_backdrop()
	_build_paint_filter()
	# il borgo è una seconda mappa, accanto alla fattoria
	borgo_map = BorgoMap.new()
	borgo_map.visible = false
	add_child(borgo_map)
	move_child(borgo_map, farm.get_index() + 1)
	borgo_map.building_reached.connect(_on_building_reached)
	farm.sector_tapped.connect(_on_sector_tapped)
	_build_hud()
	GameState.changed.connect(_refresh_hud)
	GameState.toast.connect(show_toast)
	# Cambiando lingua si ricostruisce la scena; la partita è negli autoload e resta.
	Settings.language_changed.connect(_on_language_changed)
	farm.tool_changed.connect(func(_t: String) -> void: _sync_tool_buttons())
	_show_farm_now()
	_refresh_hud()

	# Moka e pozzo si ricaricano anche mentre si gioca.
	var regen := Timer.new()
	regen.wait_time = 1.0
	regen.autostart = true
	regen.timeout.connect(_on_regen_tick)
	add_child(regen)


func _on_language_changed(_code: String) -> void:
	reopen_settings = true
	get_tree().reload_current_scene.call_deferred()


func _on_regen_tick() -> void:
	GameState.tick_moka()
	GameState.tick_water()
	_refresh_stats()


## Fattoria e borgo: il passaggio fa vedere il viaggio tra le nuvole.
func show_farm() -> void:
	_travel_to("farm")


func show_borgo() -> void:
	_travel_to("borgo")


func _travel_to(place: String) -> void:
	var here := "farm" if farm.visible else "borgo"
	if place == here or _travel.is_playing():
		(_farm_btn if here == "farm" else _borgo_btn).button_pressed = true
		return
	_shop.hide()
	_land.hide()
	_settings.hide()
	_travel_dest = place
	_travel.play()


func _on_travel_covered() -> void:
	if _travel_dest == "farm":
		_show_farm_now()
	else:
		_show_borgo_now()


func _show_farm_now() -> void:
	farm.visible = true
	borgo_map.visible = false
	borgo.close_panels()
	borgo_map.camera.active = false
	farm.camera.activate()
	_backdrop.mode = "farm"
	_dock.visible = true
	_farm_btn.button_pressed = true


func _show_borgo_now() -> void:
	farm.visible = false
	borgo_map.visible = true
	farm.camera.active = false
	borgo_map.camera.activate()
	borgo_map.arrive()
	_backdrop.mode = "borgo"
	_dock.visible = false
	_shop.hide()
	_land.hide()
	_borgo_btn.button_pressed = true


## Il contadino è arrivato a un edificio del borgo.
func _on_building_reached(id: String) -> void:
	if id == "bacheca":
		borgo.open_orders()
	elif GameData.BUILDINGS.has(id):
		borgo.open_building(id)


## Barra in alto durante il posizionamento: cosa fare e "Annulla".
func _build_place_bar() -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	holder.offset_top = 70
	holder.offset_bottom = 130
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(holder)
	_place_bar = PanelContainer.new()
	_place_bar.theme_type_variation = "Pill"
	_place_bar.visible = false
	holder.add_child(_place_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_place_bar.add_child(row)
	row.add_child(UiKit.label(tr("PLACE_HINT"), "Heading"))
	var cancel := UiKit.button(tr("PLACE_CANCEL"), "NavButton")
	cancel.pressed.connect(farm.cancel_placing)
	row.add_child(cancel)


func _on_place_requested(kind: String, type: String, source: String) -> void:
	if not farm.visible:
		_show_farm_now()
	farm.start_placing(kind, type, source)


func _on_placing_changed(active: bool) -> void:
	_place_bar.visible = active
	_dock.visible = not active and farm.visible


func _on_structure_tapped(uid: int) -> void:
	_shop.hide()
	_land.hide()
	_settings.hide()
	_structure.open(uid)


func _on_sector_tapped(sector: Vector2i) -> void:
	_shop.hide()
	_settings.hide()
	_land.open(sector)


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

## Filtro "tempera" sopra sfondo e fattoria (livello 5), sotto borgo e HUD.
func _build_paint_filter() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(func() -> void: rect.size = get_viewport().get_visible_rect().size)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/painterly.gdshader")
	rect.material = mat
	layer.add_child(rect)


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
	p = UiKit.stat_pill("nostalgia")
	stats.add_child(p[0]); _lire = p[1]
	(p[0] as Control).tooltip_text = tr("UI_NOSTALGIA")
	(p[0] as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	p = UiKit.stat_pill("drop")
	stats.add_child(p[0]); _water = p[1]; _water_timer = p[2]
	p = UiKit.stat_pill("espresso")
	stats.add_child(p[0]); _espresso = p[1]
	(p[0] as Control).tooltip_text = tr("UI_ESPRESSO_TIP")

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

	# In alto al centro: gli abitanti del borgo, il vero progresso del gioco
	var pop_holder := CenterContainer.new()
	pop_holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	pop_holder.offset_top = 8
	pop_holder.offset_bottom = 96
	pop_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(pop_holder)
	var pop_box := PanelContainer.new()
	pop_box.theme_type_variation = "Pill"
	pop_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop_holder.add_child(pop_box)
	var pop_row := HBoxContainer.new()
	pop_row.add_theme_constant_override("separation", 8)
	pop_box.add_child(pop_row)
	pop_row.add_child(UiKit.texture_rect(UiKit.icon("borgo"), 40))
	var pop_col := VBoxContainer.new()
	pop_col.add_theme_constant_override("separation", 1)
	pop_row.add_child(pop_col)
	_pop_label = UiKit.label("", "Heading")
	_pop_label.add_theme_font_size_override("font_size", 16)
	pop_col.add_child(_pop_label)
	_pop_bar = ProgressBar.new()
	_pop_bar.custom_minimum_size = Vector2(250, 14)
	_pop_bar.show_percentage = false
	pop_col.add_child(_pop_bar)
	_rating_row = HBoxContainer.new()
	_rating_row.add_theme_constant_override("separation", 2)
	pop_col.add_child(_rating_row)
	for i in 5:
		var st := UiKit.texture_rect(UiKit.icon("star"), 16)
		_rating_row.add_child(st)
		_stars.append(st)
	_visitors = UiKit.label("", "Small")
	_visitors.add_theme_font_size_override("font_size", 12)
	_rating_row.add_child(Control.new())
	_rating_row.get_child(-1).custom_minimum_size = Vector2(8, 0)
	_rating_row.add_child(_visitors)

	# Accanto al livello: impostazioni (lingua, volumi, informazioni)
	var gear := UiKit.button("", "IconButton", "settings")
	gear.tooltip_text = tr("UI_SETTINGS")
	gear.add_theme_constant_override("icon_max_width", 48)
	gear.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hud.add_child(gear)
	gear.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	gear.offset_top = 80
	gear.offset_bottom = 132
	gear.pressed.connect(_toggle_settings)

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
	_farm_btn = _nav_button(nav, tr("UI_FARM"), "farm", show_farm, nav_group)
	_borgo_btn = _nav_button(nav, tr("UI_BORGO"), "borgo", show_borgo, nav_group)
	nav.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 14)

	# In basso a destra: Negozio
	_shop_btn = UiKit.button(tr("UI_SHOP"), "NavButton", "shop")
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
		var b := _tool_button(tr(t["label"]), t["icon"])
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
	_shop.place_requested.connect(_on_place_requested)
	hud.add_child(_shop)

	_structure = StructurePanel.new()
	_structure.visible = false
	hud.add_child(_structure)
	farm.structure_tapped.connect(_on_structure_tapped)
	farm.placing_changed.connect(_on_placing_changed)
	_build_place_bar()

	_land = LandPanel.new()
	_land.visible = false
	hud.add_child(_land)

	var travel_layer := CanvasLayer.new()
	travel_layer.layer = 30
	add_child(travel_layer)
	_travel = TravelOverlay.new()
	_travel.covered.connect(_on_travel_covered)
	travel_layer.add_child(_travel)

	_settings = SettingsPanel.new()
	_settings.visible = reopen_settings
	reopen_settings = false
	hud.add_child(_settings)


func _toggle_settings() -> void:
	_structure.hide()
	_shop.hide()
	_land.hide()
	_settings.visible = not _settings.visible


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
		_settings.hide()
		_land.hide()
		_shop.show()


## Un pulsante per ogni seme posseduto; se non ne hai, invita al negozio.
func _rebuild_seed_row() -> void:
	var owned: Array = []
	for id in GameData.all_plants():
		if GameState.seed_count(id) > 0:
			owned.append(id)
	if owned == _seed_buttons.keys():
		for id in owned:
			_seed_buttons[id].text = "%s\n×%d" % [GameData.crop_name(id), GameState.seed_count(id)]
		return
	for child in _seed_row.get_children():
		child.queue_free()
	_seed_buttons = {}
	if owned.is_empty():
		var hint := Button.new()
		hint.text = tr("UI_NO_SEEDS")
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
		b.text = "%s\n×%d" % [GameData.crop_name(id), GameState.seed_count(id)]
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
	_lire.text = str(GameState.nostalgie)
	_water.text = "%d/%d" % [GameState.water, GameData.WATER_MAX]
	var next := GameState.water_seconds_to_next()
	_water_timer.visible = next > 0
	_water_timer.text = tr("UI_WATER_NEXT") % GameData.format_time(next)
	_espresso.text = "%d/%d" % [GameState.espresso, GameData.MOKA_MAX]


func _refresh_hud() -> void:
	_refresh_stats()
	_level.text = str(GameState.level)
	var next_xp := GameData.xp_for_level(GameState.level + 1)
	_xp_text.text = tr("UI_LEVEL_XP") % [GameState.level, GameState.xp, next_xp] if GameState.level < GameData.MAX_LEVEL else tr("UI_LEVEL_MAX")
	_xp_bar.value = GameState.xp_progress() * 100.0
	_tool_buttons["fertilizer"].text = tr("TOOL_FERTILIZER_N") % GameState.fertilizer
	_rebuild_seed_row()
	var todo := GameState.any_order_ready() or GameState.any_restorable()
	for i in GameState.tourists.size():
		todo = todo or GameState.can_serve_tourist(i)
	_borgo_btn.text = tr("UI_BORGO") + ("  •" if todo else "")
	# abitanti del borgo, valutazione e visitatori
	var pop := GameState.population()
	_pop_label.text = "%s  %d / %d" % [tr("UI_POPULATION"), pop, GameData.max_population()]
	_pop_bar.value = 100.0 * pop / GameData.max_population()
	_rating_row.visible = GameState.tourism_active()
	var r := GameState.rating()
	for i in _stars.size():
		_stars[i].modulate = Color.WHITE if r >= i + 0.75 else (Color(1, 1, 1, 0.55) if r >= i + 0.25 else Color(0.3, 0.3, 0.3, 0.35))
	_visitors.text = tr("UI_VISITORS") % GameState.visitors_today
