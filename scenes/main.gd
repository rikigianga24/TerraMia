extends Node
## Scena principale: tiene insieme Fattoria, Borgo, Negozio e HUD.
## Due pulsanti fissi in basso, Fattoria e Borgo; il pulsante Borgo mostra
## un pallino quando c'è qualcosa da fare.

const TOOLS := [
	{"id": "hand", "label": "Mano"},
	{"id": "hoe", "label": "Zappa"},
	{"id": "water", "label": "Annaffia"},
	{"id": "fertilizer", "label": "Concime"},
]

@onready var farm: Farm = $Farm
@onready var borgo: Borgo = $BorgoLayer/Borgo
@onready var hud: Control = $HUD/Root

var _stats: Label
var _xp_bar: ProgressBar
var _toast: Label
var _toast_tween: Tween
var _farm_bar: VBoxContainer
var _tool_buttons: Dictionary = {}     ## id strumento -> Button
var _seed_row: HBoxContainer
var _seed_buttons: Dictionary = {}     ## coltura -> Button
var _tool_group := ButtonGroup.new()
var _farm_btn: Button
var _borgo_btn: Button
var _shop: Shop


func _ready() -> void:
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
	_farm_bar.visible = true
	_farm_btn.disabled = true
	_borgo_btn.disabled = false


func show_borgo() -> void:
	farm.visible = false
	borgo.visible = true
	_farm_bar.visible = false
	_shop.hide()
	_farm_btn.disabled = false
	_borgo_btn.disabled = true


func show_toast(message: String) -> void:
	_toast.text = message
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


func select_seed(crop_id: String) -> void:
	farm.selected_crop = crop_id
	farm.tool = "seed"


# --- HUD --------------------------------------------------------------------

func _build_hud() -> void:
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Barra in alto: monete, Lire d'oro, gocce, espresso, livello
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 16)
	top.add_child(top_row)
	_stats = Label.new()
	_stats.add_theme_font_size_override("font_size", 18)
	_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_stats)
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(180, 24)
	_xp_bar.show_percentage = false
	top_row.add_child(_xp_bar)

	# Messaggi brevi
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 56
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.add_theme_color_override("font_color", Color.WHITE)
	_toast.add_theme_color_override("font_outline_color", Color("3b2a17"))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_toast)

	# Barra in basso: strumenti e semi (solo in fattoria), poi navigazione
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 6)
	hud.add_child(bottom)

	_farm_bar = VBoxContainer.new()
	_farm_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_farm_bar)

	var tools := HBoxContainer.new()
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_farm_bar.add_child(tools)
	for t in TOOLS:
		var b := _toggle_button(t["label"], Vector2(120, 44))
		var id: String = t["id"]
		b.pressed.connect(func() -> void: farm.tool = id)
		tools.add_child(b)
		_tool_buttons[id] = b

	var seed_scroll := ScrollContainer.new()
	seed_scroll.custom_minimum_size = Vector2(0, 52)
	seed_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	seed_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_farm_bar.add_child(seed_scroll)
	var seed_center := CenterContainer.new()
	seed_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seed_scroll.add_child(seed_center)
	_seed_row = HBoxContainer.new()
	_seed_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seed_center.add_child(_seed_row)

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 12)
	nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(nav)
	_farm_btn = _nav_button(nav, "Fattoria", show_farm)
	_nav_button(nav, "Negozio", _toggle_shop)
	_borgo_btn = _nav_button(nav, "Borgo", show_borgo)

	_shop = Shop.new()
	_shop.visible = false
	_shop.seed_bought.connect(select_seed)
	hud.add_child(_shop)


func _toggle_button(text: String, min_size: Vector2) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = _tool_group
	b.text = text
	b.custom_minimum_size = min_size
	return b


func _nav_button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(160, 52)
	b.add_theme_font_size_override("font_size", 20)
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
			_seed_buttons[id].text = "%s ×%d" % [GameData.crop(id)["name"], GameState.seed_count(id)]
		return
	for child in _seed_row.get_children():
		child.queue_free()
	_seed_buttons = {}
	if owned.is_empty():
		var hint := Label.new()
		hint.text = "Niente semi: comprali al Negozio."
		_seed_row.add_child(hint)
		if farm.tool == "seed":
			farm.tool = "hand"
		return
	for id in owned:
		var b := _toggle_button("", Vector2(130, 44))
		b.text = "%s ×%d" % [GameData.crop(id)["name"], GameState.seed_count(id)]
		b.modulate = Color(GameData.crop(id)["color"]).lerp(Color.WHITE, 0.6)
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


func _refresh_stats() -> void:
	var water_text := "Gocce %d/%d" % [GameState.water, GameData.WATER_MAX]
	var next := GameState.water_seconds_to_next()
	if next > 0:
		water_text += " (+1 in %s)" % GameData.format_time(next)
	_stats.text = "  Monete %d  ·  Lire d'oro %d  ·  %s  ·  Espresso %d/%d  ·  Concime %d  ·  Livello %d" % [
		GameState.coins, GameState.lire_oro, water_text, GameState.espresso, GameData.MOKA_MAX,
		GameState.fertilizer, GameState.level]


func _refresh_hud() -> void:
	_refresh_stats()
	_xp_bar.value = GameState.xp_progress() * 100.0
	_tool_buttons["fertilizer"].text = "Concime ×%d" % GameState.fertilizer
	_rebuild_seed_row()
	_borgo_btn.text = "Borgo •" if GameState.any_order_ready() or GameState.can_restore("mulino") else "Borgo"
