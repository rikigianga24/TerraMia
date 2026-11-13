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
const WOOD := Color("8a5a2b")
const WOOD_LIGHT := Color("b07a44")
const GREEN_TOP := Color("9ad24a")
const GREEN_BOTTOM := Color("5fa22c")
const GREEN_BORDER := Color("3d6e1c")
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


## Pulsante "in rilievo" disegnato in un'immagine: bordo scuro spesso,
## sfumatura dall'alto, riflesso lucido nella metà alta, un labbro più scuro
## in basso che fa da spessore (sparisce quando è premuto).
static func glossy(top: Color, bottom: Color, border: Color, radius: int, pad: Vector4,
		pressed := false, border_w := 3.0, lip := 6.0, flat := false) -> StyleBoxTexture:
	var w := radius * 2 + 24
	var h := radius * 2 + 24 + int(lip)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var body_h := float(h) - (0.0 if pressed else lip)
	var y_off := lip if pressed else 0.0
	for y in h:
		for x in w:
			var px := Vector2(x + 0.5, y + 0.5)
			# rettangolo arrotondato del labbro (sotto) e del corpo (sopra)
			var d_body := _rrect_dist(px, Vector2(0, y_off), Vector2(w, body_h), radius)
			var d_lip := _rrect_dist(px, Vector2(0, lip + y_off * 0.0), Vector2(w, float(h) - lip), radius) if not pressed else 1e9
			var col := Color(0, 0, 0, 0)
			if d_lip < 0.5:
				col = border.darkened(0.1)
				col.a = clampf(0.5 - d_lip, 0.0, 1.0)
			if d_body < 0.5:
				var a := clampf(0.5 - d_body, 0.0, 1.0)
				var c := border
				if d_body < -border_w:
					var t := clampf((px.y - y_off) / body_h, 0.0, 1.0)
					c = top.lerp(bottom, t)
					if not flat:
						# riflesso lucido nella metà alta
						if t < 0.48:
							c = c.lerp(Color.WHITE, 0.16 * (1.0 - t / 0.48))
						# filo di luce sotto il bordo alto
						if d_body > -border_w - 2.2 and px.y - y_off < body_h * 0.5:
							c = c.lerp(Color.WHITE, 0.45)
				col = col.blend(Color(c, a)) if col.a > 0.0 else Color(c, a)
			img.set_pixel(x, y, col)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	var m := float(radius) + 4.0
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m + lip
	sb.content_margin_left = pad.x
	sb.content_margin_right = pad.z
	sb.content_margin_top = pad.y + (lip if pressed else 0.0)
	sb.content_margin_bottom = pad.w + (0.0 if pressed else lip)
	return sb


static func _rrect_dist(p: Vector2, pos: Vector2, size: Vector2, r: float) -> float:
	var c := pos + size * 0.5
	var q := (p - c).abs() - (size * 0.5 - Vector2(r, r))
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r


## Stati di un pulsante in rilievo, con testo (bianco col contorno se colorato).
func _glossy_states(t: Theme, type: String, top: Color, bottom: Color, border: Color, text: Color,
		radius: int, pad: Vector4, pressed_top := Color.TRANSPARENT, pressed_bottom := Color.TRANSPARENT, outline := true) -> void:
	var p_top := pressed_top if pressed_top.a > 0.0 else bottom
	var p_bottom := pressed_bottom if pressed_bottom.a > 0.0 else bottom.darkened(0.1)
	var p_border := border if pressed_top.a == 0.0 else pressed_bottom.darkened(0.45)
	t.set_stylebox("normal", type, glossy(top, bottom, border, radius, pad))
	t.set_stylebox("hover", type, glossy(top.lightened(0.08), bottom.lightened(0.08), border, radius, pad))
	var pr := glossy(p_top, p_bottom, p_border, radius, pad, true)
	t.set_stylebox("pressed", type, pr)
	t.set_stylebox("hover_pressed", type, pr)
	t.set_stylebox("disabled", type, glossy(DISABLED, DISABLED.darkened(0.08), DISABLED.darkened(0.3), radius, pad, false, 3.0, 6.0, true))
	var focus := box(Color.TRANSPARENT, radius + 2, Color(1, 1, 1, 0.0), 0, 0, Vector4.ZERO)
	focus.draw_center = false
	t.set_stylebox("focus", type, focus)
	var pressed_text := Color.WHITE if pressed_top.a > 0.0 else text
	for c in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(c, type, text)
	t.set_color("font_pressed_color", type, pressed_text)
	t.set_color("font_hover_pressed_color", type, pressed_text)
	t.set_color("font_disabled_color", type, INK_SOFT.lerp(DISABLED, 0.3))
	if outline:
		t.set_color("font_outline_color", type, border.darkened(0.25))
		t.set_constant("outline_size", type, 5)
	for c in ["icon_normal_color", "icon_pressed_color", "icon_hover_color", "icon_hover_pressed_color"]:
		t.set_color(c, type, Color.WHITE)
	t.set_color("icon_disabled_color", type, Color(1, 1, 1, 0.45))


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
	# Pulsante normale: crema, bordo legno, testo scuro
	_glossy_states(t, "Button", Color("fffaf0"), CREAM_DARK, WOOD, INK, 14, Vector4(16, 8, 16, 8),
		GREEN_TOP, GREEN_BOTTOM, false)
	t.set_font("font", "Button", bold)
	t.set_constant("h_separation", "Button", 8)
	t.set_constant("icon_max_width", "Button", 32)

	# Pulsante principale: verde (conferma: consegna, compra, restaura)
	t.set_type_variation("PrimaryButton", "Button")
	_glossy_states(t, "PrimaryButton", GREEN_TOP, GREEN_BOTTOM, GREEN_BORDER, Color.WHITE, 14, Vector4(16, 8, 16, 8))
	t.set_font_size("font_size", "PrimaryButton", 19)

	# Strumenti della fattoria: crema, verdi quando selezionati
	t.set_type_variation("ToolButton", "Button")
	_glossy_states(t, "ToolButton", Color("fffaf0"), CREAM_DARK, WOOD, INK, 16, Vector4(8, 6, 8, 6),
		GREEN_TOP, GREEN_BOTTOM, false)
	t.set_color("font_outline_color", "ToolButton", GREEN_BORDER)
	t.set_constant("icon_max_width", "ToolButton", 40)
	t.set_font_size("font_size", "ToolButton", 14)

	# Semi: come gli strumenti ma più compatti
	t.set_type_variation("SeedButton", "Button")
	_glossy_states(t, "SeedButton", Color("fffaf0"), CREAM_DARK, WOOD, INK, 14, Vector4(10, 4, 12, 4),
		GREEN_TOP, GREEN_BOTTOM, false)
	t.set_constant("icon_max_width", "SeedButton", 26)
	t.set_font_size("font_size", "SeedButton", 15)

	# Navigazione Fattoria / Borgo / Negozio: arancio terracotta, verde se attivo
	t.set_type_variation("NavButton", "Button")
	_glossy_states(t, "NavButton", Color("f39a4c"), TERRACOTTA, TERRACOTTA_DARK.darkened(0.15), Color.WHITE, 20, Vector4(16, 6, 20, 6),
		GREEN_TOP, GREEN_BOTTOM)
	t.set_font_size("font_size", "NavButton", 21)
	t.set_constant("icon_max_width", "NavButton", 40)

	# Pulsante tondo solo icona (chiudi)
	t.set_type_variation("IconButton", "Button")
	var flat := box(Color.TRANSPARENT, 99, Color.TRANSPARENT, 0, 0, Vector4(2, 2, 2, 2))
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(state, "IconButton", flat)
	t.set_constant("icon_max_width", "IconButton", 36)
	t.set_color("icon_hover_color", "IconButton", Color(1.1, 1.1, 1.1))


## Pannello con cornice: legno attorno, crema dentro.
static func framed(fill: Color, frame: Color, radius: int, frame_w: int, pad: Vector4, shadow := 10) -> StyleBoxFlat:
	var sb := box(fill, radius, frame, frame_w, shadow, pad, frame_w + 3)
	sb.expand_margin_top = 0
	return sb


func _panels(t: Theme) -> void:
	t.set_stylebox("panel", "PanelContainer", framed(CREAM, WOOD, 16, 4, Vector4(16, 14, 16, 14), 6))
	t.set_stylebox("panel", "Panel", framed(CREAM, WOOD, 16, 4, Vector4(0, 0, 0, 0), 6))

	t.set_type_variation("Sheet", "PanelContainer")
	t.set_stylebox("panel", "Sheet", framed(CREAM, WOOD, 22, 6, Vector4(24, 18, 24, 20), 18))

	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", framed(Color("fffaf0"), CREAM_DARK.darkened(0.18), 14, 3, Vector4(12, 10, 12, 10), 0))

	t.set_type_variation("Pill", "PanelContainer")
	t.set_stylebox("panel", "Pill", framed(Color(1, 0.98, 0.93, 0.97), WOOD, 99, 3, Vector4(6, 2, 16, 2), 3))

	t.set_type_variation("Dock", "PanelContainer")
	t.set_stylebox("panel", "Dock", framed(Color(0.66, 0.45, 0.25, 0.96), WOOD.darkened(0.25), 22, 4, Vector4(12, 10, 12, 10), 8))

	t.set_type_variation("Toast", "PanelContainer")
	t.set_stylebox("panel", "Toast", framed(Color(0.29, 0.2, 0.14, 0.94), Color("f2c75c"), 99, 3, Vector4(22, 8, 22, 10), 6))


func _labels(t: Theme, bold: FontFile) -> void:
	t.set_color("font_color", "Label", INK)
	t.set_constant("line_spacing", "Label", 0)

	t.set_type_variation("Title", "Label")
	t.set_font("font", "Title", bold)
	t.set_font_size("font_size", "Title", 30)
	t.set_color("font_color", "Title", Color.WHITE)
	t.set_color("font_outline_color", "Title", TERRACOTTA_DARK)
	t.set_constant("outline_size", "Title", 8)

	t.set_type_variation("Heading", "Label")
	t.set_font("font", "Heading", bold)
	t.set_font_size("font_size", "Heading", 20)

	t.set_type_variation("Small", "Label")
	t.set_font_size("font_size", "Small", 14)
	t.set_color("font_color", "Small", INK_SOFT)

	t.set_type_variation("PillValue", "Label")
	t.set_font("font", "PillValue", bold)
	t.set_font_size("font_size", "PillValue", 21)
	t.set_color("font_color", "PillValue", INK)

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

	# Slider del volume: binario crema, parte piena verde oliva
	t.set_stylebox("slider", "HSlider", box(Color(0.29, 0.2, 0.14, 0.15), 99, Color.TRANSPARENT, 0, 0, Vector4(0, 5, 0, 5)))
	t.set_stylebox("grabber_area", "HSlider", box(OLIVE_LIGHT, 99, Color.TRANSPARENT, 0, 0, Vector4(0, 5, 0, 5)))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(OLIVE, 99, Color.TRANSPARENT, 0, 0, Vector4(0, 5, 0, 5)))
	var knob := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	for y in 28:
		for x in 28:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(14, 14))
			if d < 12.5:
				knob.set_pixel(x, y, TERRACOTTA if d < 10.0 else TERRACOTTA_DARK)
			elif d < 13.5:
				knob.set_pixel(x, y, Color(TERRACOTTA_DARK, 13.5 - d))
	var knob_tex := ImageTexture.create_from_image(knob)
	t.set_icon("grabber", "HSlider", knob_tex)
	t.set_icon("grabber_highlight", "HSlider", knob_tex)

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
