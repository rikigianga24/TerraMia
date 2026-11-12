class_name SettingsPanel
extends PanelContainer
## Impostazioni del gioco: lingua, volumi di musica ed effetti, informazioni
## (versione, creatore, crediti). Si apre dall'ingranaggio in alto a destra.

func _ready() -> void:
	theme_type_variation = "Sheet"
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -300
	offset_right = 300
	offset_top = -260
	offset_bottom = 230
	mouse_filter = Control.MOUSE_FILTER_STOP

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	top.add_child(UiKit.texture_rect(UiKit.icon("settings"), 44))
	var title := UiKit.label(tr("UI_SETTINGS"), "Title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close := UiKit.button("", "IconButton", "close")
	close.pressed.connect(hide)
	top.add_child(close)

	# Lingua: cambiandola la scena si ricarica (vedi main.gd)
	col.add_child(UiKit.label(tr("UI_LANGUAGE"), "Heading"))
	var langs := HBoxContainer.new()
	langs.add_theme_constant_override("separation", 8)
	col.add_child(langs)
	var group := ButtonGroup.new()
	for code in Settings.LANGUAGES:
		var b := UiKit.button(Settings.language_name(code), "ToolButton")
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = code == Settings.language
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(Settings.set_language.bind(code))
		langs.add_child(b)

	col.add_child(HSeparator.new())
	col.add_child(UiKit.label(tr("SET_AUDIO"), "Heading"))
	_volume_row(col, "SET_MUSIC", "Music")
	_volume_row(col, "SET_SFX", "SFX")

	col.add_child(HSeparator.new())
	col.add_child(UiKit.label(tr("SET_INFO"), "Heading"))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	col.add_child(info)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	info.add_child(name_row)
	name_row.add_child(UiKit.label("Terra Mia", "Heading"))
	name_row.add_child(UiKit.label(tr("SET_VERSION") % str(ProjectSettings.get_setting("application/config/version", "")), "Small"))
	var tagline := UiKit.label(tr("SET_TAGLINE"))
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(tagline)
	info.add_child(UiKit.label(tr("SET_CREATOR") % GameData.CREATOR, "Small"))
	info.add_child(UiKit.label(tr("SET_ENGINE"), "Small"))
	info.add_child(UiKit.label(tr("SET_FONT"), "Small"))


func _volume_row(parent: Control, label_key: String, bus: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := UiKit.label(tr(label_key))
	label.custom_minimum_size = Vector2(130, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = Settings.volumes[bus] * 100.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value := UiKit.label("%d%%" % int(slider.value), "Heading")
	value.custom_minimum_size = Vector2(56, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	slider.value_changed.connect(_on_volume.bind(bus, value))


func _on_volume(v: float, bus: String, value: Label) -> void:
	Settings.set_volume(bus, v / 100.0)
	value.text = "%d%%" % int(v)
