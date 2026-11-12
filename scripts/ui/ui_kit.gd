class_name UiKit
extends RefCounted
## Pezzi d'interfaccia riusati da HUD, negozio e borgo.
## Gli stili veri stanno nel tema (assets/theme/terramia_theme.tres, generato
## da tools/build_theme.gd): qui si scelgono solo le varianti.

const ICONS := {
	"coin": preload("res://assets/graphics/icons/coin.png"),
	"lira": preload("res://assets/graphics/icons/lira.png"),
	"drop": preload("res://assets/graphics/icons/drop.png"),
	"espresso": preload("res://assets/graphics/icons/espresso.png"),
	"fertilizer": preload("res://assets/graphics/icons/fertilizer.png"),
	"star": preload("res://assets/graphics/icons/star.png"),
	"hand": preload("res://assets/graphics/icons/hand.png"),
	"hoe": preload("res://assets/graphics/icons/hoe.png"),
	"watering_can": preload("res://assets/graphics/icons/watering_can.png"),
	"seeds": preload("res://assets/graphics/icons/seeds.png"),
	"shop": preload("res://assets/graphics/icons/shop.png"),
	"farm": preload("res://assets/graphics/icons/farm.png"),
	"borgo": preload("res://assets/graphics/icons/borgo.png"),
	"close": preload("res://assets/graphics/icons/close.png"),
	"lock": preload("res://assets/graphics/icons/lock.png"),
}

static var _crop_icons: Dictionary = {}


static func icon(name: String) -> Texture2D:
	return ICONS[name]


## Icona tonda nel colore della pianta, con riflesso: segnaposto finché non
## ci sono le illustrazioni di ogni coltura.
static func crop_icon(crop_id: String) -> Texture2D:
	if _crop_icons.has(crop_id):
		return _crop_icons[crop_id]
	var color := Color(GameData.crop(crop_id).get("color", "ffffff"))
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(c + Vector2(0, 2))
			var col := Color(0, 0, 0, 0)
			if d < 28.0:
				col = color.darkened(0.3)
			var d2 := p.distance_to(c)
			if d2 < 27.0:
				col = color
				if p.distance_to(c + Vector2(-9, -9)) < 7.0:
					col = color.lerp(Color.WHITE, 0.55)
			# bordo morbido
			if d < 28.0 and d > 27.0:
				col.a = 28.0 - d
			img.set_pixel(x, y, col)
	# fogliolina in alto
	for y in range(2, 14):
		for x in range(30, 46):
			if Vector2(x, y).distance_to(Vector2(38, 8)) < 5.5:
				img.set_pixel(x, y, Color("5f9a34"))
	var tex := ImageTexture.create_from_image(img)
	_crop_icons[crop_id] = tex
	return tex


static func texture_rect(tex: Texture2D, size: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func label(text: String, variation := "") -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Pastiglia con icona e valore, come quelle in alto nella HUD.
## Restituisce [pannello, etichetta valore, etichetta piccola].
static func stat_pill(icon_name: String) -> Array:
	var pill := PanelContainer.new()
	pill.theme_type_variation = "Pill"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	row.add_child(texture_rect(icon(icon_name), 34))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var value := label("0", "PillValue")
	col.add_child(value)
	var small := label("", "Small")
	small.add_theme_font_size_override("font_size", 12)
	small.visible = false
	col.add_child(small)
	return [pill, value, small]


static func button(text: String, variation := "", icon_name := "") -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	if icon_name != "":
		b.icon = icon(icon_name)
	return b
