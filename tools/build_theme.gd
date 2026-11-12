extends SceneTree
## Genera il tema dell'interfaccia (assets/theme/terramia_theme.tres).
## È l'equivalente del foglio di stile: colori, bordi, font e varianti dei controlli.
##
## Rigenerare dopo ogni modifica:
##   godot --headless --path . -s tools/build_theme.gd
##
## Varianti (si assegnano con theme_type_variation):
##   Button:         PrimaryButton, ToolButton, SeedButton, NavButton, IconButton
##   PanelContainer: Card, Pill, Dock, Toast, Sheet
##   Label:          Title, Heading, Small, PillValue, Badge, ToastLabel

const OUT := "res://assets/theme/terramia_theme.tres"

# Palette: campagna italiana
const CREAM := Color("fbf3e2")
const CREAM_DARK := Color("f1e3c6")
const PARCHMENT := Color("e9d6b0")
const BORDER := Color("c9a97a")
const INK := Color("4a3423")
const INK_SOFT := Color("7a5e44")
const TERRACOTTA := Color("d0643c")
const TERRACOTTA_LIGHT := Color("e27a4f")
const TERRACOTTA_DARK := Color("a94c2a")
const OLIVE := Color("7c9a3c")
const OLIVE_LIGHT := Color("93b24d")
const OLIVE_DARK := Color("5e7a28")
const DISABLED := Color("d9ccb4")
const SHADOW := Color(0.29, 0.2, 0.12, 0.28)


func _initialize() -> void:
	var t := Theme.new()
	var regular: FontFile = load("res://assets/fonts/Fredoka-Regular.ttf")
	var bold: FontFile = load("res://assets/fonts/Fredoka-SemiBold.ttf")
	t.default_font = regular
	t.default_font_size = 18

	_buttons(t, bold)
	_panels(t)
	_labels(t, bold)
	_misc(t)

	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var err := ResourceSaver.save(t, OUT)
	print("Tema salvato in ", OUT, " (", error_string(err), ")")
	quit(0 if err == OK else 1)


static func box(bg: Color, radius := 12, border := Color.TRANSPARENT, border_w := 0,
		shadow := 0, pad := Vector4(14, 8, 14, 8), bottom_w := -1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.corner_detail = 6
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
		if bottom_w >= 0:
			s.border_width_bottom = bottom_w
	if shadow > 0:
		s.shadow_color = SHADOW
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * 0.5)
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	s.anti_aliasing = true
	return s


## Stati di un pulsante "a pastiglia": il bordo inferiore spesso fa da rilievo,
## e quando è premuto si abbassa.
func _button_states(t: Theme, type: String, base: Color, light: Color, dark: Color,
		text: Color, radius: int, pad: Vector4, pressed_bg := Color.TRANSPARENT) -> void:
	var press := pressed_bg if pressed_bg.a > 0.0 else dark
	t.set_stylebox("normal", type, box(base, radius, dark, 2, 3, pad, 5))
	t.set_stylebox("hover", type, box(light, radius, dark, 2, 4, pad, 5))
	var p := box(press, radius, press.darkened(0.25), 2, 1, Vector4(pad.x, pad.y + 3, pad.z, pad.w - 3), 2)
	t.set_stylebox("pressed", type, p)
	t.set_stylebox("hover_pressed", type, p)
	t.set_stylebox("disabled", type, box(DISABLED, radius, DISABLED.darkened(0.12), 2, 0, pad, 4))
	var focus := box(Color.TRANSPARENT, radius + 2, Color(1, 1, 1, 0.7), 3, 0, Vector4.ZERO)
	focus.draw_center = false
	t.set_stylebox("focus", type, focus)
	for c in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(c, type, text)
	t.set_color("font_pressed_color", type, Color.WHITE if pressed_bg.a > 0.0 else text)
	t.set_color("font_hover_pressed_color", type, Color.WHITE if pressed_bg.a > 0.0 else text)
	t.set_color("font_disabled_color", type, INK_SOFT.lerp(DISABLED, 0.4))
	t.set_color("icon_normal_color", type, Color.WHITE)
	t.set_color("icon_pressed_color", type, Color.WHITE)
	t.set_color("icon_hover_color", type, Color.WHITE)
	t.set_color("icon_hover_pressed_color", type, Color.WHITE)
	t.set_color("icon_disabled_color", type, Color(1, 1, 1, 0.45))


func _buttons(t: Theme, bold: FontFile) -> void:
	# Pulsante normale: crema con bordo
	_button_states(t, "Button", CREAM, Color.WHITE, BORDER, INK, 12, Vector4(16, 8, 16, 10))
	t.set_font("font", "Button", bold)
	t.set_constant("h_separation", "Button", 8)
	t.set_constant("icon_max_width", "Button", 32)

	# Pulsante principale: terracotta
	t.set_type_variation("PrimaryButton", "Button")
	_button_states(t, "PrimaryButton", TERRACOTTA, TERRACOTTA_LIGHT, TERRACOTTA_DARK, Color.WHITE, 12, Vector4(16, 8, 16, 10))

	# Strumenti della fattoria: quadrati, verde oliva quando selezionati
	t.set_type_variation("ToolButton", "Button")
	_button_states(t, "ToolButton", CREAM, Color.WHITE, BORDER, INK, 16, Vector4(8, 6, 8, 8), OLIVE)
	t.set_constant("icon_max_width", "ToolButton", 40)
	t.set_font_size("font_size", "ToolButton", 14)

	# Semi: come gli strumenti ma più compatti
	t.set_type_variation("SeedButton", "Button")
	_button_states(t, "SeedButton", CREAM, Color.WHITE, BORDER, INK, 14, Vector4(10, 4, 12, 6), OLIVE)
	t.set_constant("icon_max_width", "SeedButton", 26)
	t.set_font_size("font_size", "SeedButton", 15)

	# Navigazione Fattoria / Borgo / Negozio
	t.set_type_variation("NavButton", "Button")
	_button_states(t, "NavButton", TERRACOTTA, TERRACOTTA_LIGHT, TERRACOTTA_DARK, Color.WHITE, 18, Vector4(18, 8, 22, 10), OLIVE)
	t.set_font_size("font_size", "NavButton", 20)
	t.set_constant("icon_max_width", "NavButton", 34)

	# Pulsante tondo solo icona (chiudi)
	t.set_type_variation("IconButton", "Button")
	var flat := box(Color.TRANSPARENT, 99, Color.TRANSPARENT, 0, 0, Vector4(2, 2, 2, 2))
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(state, "IconButton", flat)
	t.set_constant("icon_max_width", "IconButton", 36)
	t.set_color("icon_hover_color", "IconButton", Color(1.1, 1.1, 1.1))


func _panels(t: Theme) -> void:
	t.set_stylebox("panel", "PanelContainer", box(CREAM, 16, BORDER, 2, 6, Vector4(16, 14, 16, 14)))
	t.set_stylebox("panel", "Panel", box(CREAM, 16, BORDER, 2, 6))

	t.set_type_variation("Sheet", "PanelContainer")
	t.set_stylebox("panel", "Sheet", box(CREAM, 22, BORDER, 3, 18, Vector4(22, 18, 22, 18), 7))

	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", box(Color.WHITE.lerp(CREAM, 0.5), 14, CREAM_DARK.darkened(0.08), 2, 0, Vector4(12, 10, 12, 10), 4))

	t.set_type_variation("Pill", "PanelContainer")
	t.set_stylebox("panel", "Pill", box(Color(1, 0.98, 0.93, 0.94), 99, BORDER, 2, 3, Vector4(6, 3, 16, 3), 4))

	t.set_type_variation("Dock", "PanelContainer")
	t.set_stylebox("panel", "Dock", box(Color(0.98, 0.95, 0.89, 0.92), 22, BORDER, 2, 8, Vector4(12, 10, 12, 10), 5))

	t.set_type_variation("Toast", "PanelContainer")
	t.set_stylebox("panel", "Toast", box(Color(0.29, 0.2, 0.14, 0.92), 99, Color.TRANSPARENT, 0, 6, Vector4(22, 8, 22, 10)))


func _labels(t: Theme, bold: FontFile) -> void:
	t.set_color("font_color", "Label", INK)
	t.set_constant("line_spacing", "Label", 0)

	t.set_type_variation("Title", "Label")
	t.set_font("font", "Title", bold)
	t.set_font_size("font_size", "Title", 30)
	t.set_color("font_color", "Title", TERRACOTTA_DARK)

	t.set_type_variation("Heading", "Label")
	t.set_font("font", "Heading", bold)
	t.set_font_size("font_size", "Heading", 20)

	t.set_type_variation("Small", "Label")
	t.set_font_size("font_size", "Small", 14)
	t.set_color("font_color", "Small", INK_SOFT)

	t.set_type_variation("PillValue", "Label")
	t.set_font("font", "PillValue", bold)
	t.set_font_size("font_size", "PillValue", 20)

	t.set_type_variation("Badge", "Label")
	t.set_font("font", "Badge", bold)
	t.set_font_size("font_size", "Badge", 13)
	t.set_color("font_color", "Badge", Color.WHITE)
	t.set_stylebox("normal", "Badge", box(TERRACOTTA, 99, Color.WHITE, 2, 0, Vector4(6, 0, 6, 1)))

	t.set_type_variation("ToastLabel", "Label")
	t.set_font("font", "ToastLabel", bold)
	t.set_font_size("font_size", "ToastLabel", 20)
	t.set_color("font_color", "ToastLabel", CREAM)


func _misc(t: Theme) -> void:
	# Barra dell'esperienza e delle produzioni
	t.set_stylebox("background", "ProgressBar", box(Color(0.29, 0.2, 0.14, 0.18), 99, Color.TRANSPARENT, 0, 0, Vector4(0, 0, 0, 0)))
	t.set_stylebox("fill", "ProgressBar", box(OLIVE_LIGHT, 99, OLIVE_DARK, 2, 0, Vector4(0, 0, 0, 0), 3))
	t.set_color("font_color", "ProgressBar", INK)

	# Barre di scorrimento sottili
	for sb in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb, box(Color(0.29, 0.2, 0.14, 0.08), 99, Color.TRANSPARENT, 0, 0, Vector4(4, 4, 4, 4)))
		t.set_stylebox("grabber", sb, box(BORDER, 99))
		t.set_stylebox("grabber_highlight", sb, box(BORDER.darkened(0.1), 99))
		t.set_stylebox("grabber_pressed", sb, box(BORDER.darkened(0.2), 99))

	var sep := StyleBoxLine.new()
	sep.color = CREAM_DARK.darkened(0.1)
	sep.thickness = 2
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 6)

	t.set_stylebox("panel", "TooltipPanel", box(INK, 8, Color.TRANSPARENT, 0, 4, Vector4(10, 6, 10, 6)))
	t.set_color("font_color", "TooltipLabel", CREAM)
