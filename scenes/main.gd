extends Node
## Scena principale: tiene insieme Fattoria, Borgo e HUD.
## Due pulsanti fissi in basso, Fattoria e Borgo; il pulsante Borgo mostra
## un pallino quando c'è un ordine pronto da consegnare.

@onready var farm: Farm = $Farm
@onready var borgo: Borgo = $BorgoLayer/Borgo
@onready var hud: Control = $HUD/Root

var _stats: Label
var _xp_bar: ProgressBar
var _toast: Label
var _toast_tween: Tween
var _seed_bar: HBoxContainer
var _farm_btn: Button
var _borgo_btn: Button


func _ready() -> void:
	_build_hud()
	GameState.changed.connect(_refresh_hud)
	GameState.toast.connect(show_toast)
	GameState.leveled_up.connect(func(_l: int) -> void: _rebuild_seed_bar())
	show_farm()
	_refresh_hud()

	# La moka produce anche mentre si gioca.
	var moka := Timer.new()
	moka.wait_time = 30.0
	moka.autostart = true
	moka.timeout.connect(GameState.tick_moka)
	add_child(moka)


func show_farm() -> void:
	farm.visible = true
	borgo.visible = false
	_seed_bar.visible = true
	_farm_btn.disabled = true
	_borgo_btn.disabled = false


func show_borgo() -> void:
	farm.visible = false
	borgo.visible = true
	_seed_bar.visible = false
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


# --- HUD --------------------------------------------------------------------

func _build_hud() -> void:
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Barra in alto: monete, Lire d'oro, livello, espresso
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 16)
	top.add_child(top_row)
	_stats = Label.new()
	_stats.add_theme_font_size_override("font_size", 20)
	_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_stats)
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(200, 24)
	_xp_bar.show_percentage = false
	top_row.add_child(_xp_bar)

	# Messaggi brevi
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 64
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.add_theme_color_override("font_color", Color.WHITE)
	_toast.add_theme_color_override("font_outline_color", Color("3b2a17"))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_toast)

	# Barra in basso: semi (solo in fattoria) e navigazione
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bottom)

	_seed_bar = HBoxContainer.new()
	_seed_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_seed_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_seed_bar)
	_rebuild_seed_bar()

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 12)
	nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(nav)
	_farm_btn = _nav_button(nav, "Fattoria", show_farm)
	_borgo_btn = _nav_button(nav, "Borgo", show_borgo)


func _nav_button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(180, 56)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _rebuild_seed_bar() -> void:
	for child in _seed_bar.get_children():
		child.queue_free()
	var group := ButtonGroup.new()
	for id in GameData.plantable_crops(GameState.level):
		var c := GameData.crop(id)
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.text = "%s (%d)" % [c["name"], int(c["seed_cost"])]
		b.custom_minimum_size = Vector2(150, 44)
		b.button_pressed = id == farm.selected_crop
		b.pressed.connect(func() -> void: farm.selected_crop = id)
		_seed_bar.add_child(b)


func _refresh_hud() -> void:
	_stats.text = "  Monete %d   ·   Lire d'oro %d   ·   Espresso %d/%d   ·   Livello %d" % [
		GameState.coins, GameState.lire_oro, GameState.espresso, GameData.MOKA_MAX, GameState.level]
	_xp_bar.value = GameState.xp_progress() * 100.0
	_borgo_btn.text = "Borgo •" if GameState.any_order_ready() or GameState.can_restore("mulino") else "Borgo"
