class_name BorgoMap
extends Node2D
## Il borgo come mappa isometrica dove il contadino cammina tra gli edifici.
##
## Al centro la piazza con la fontana e la bacheca degli ordini; attorno gli
## edifici del documento di design. Un edificio non restaurato è un rudere con
## l'edera; quelli restaurati hanno muri color sabbia e tetto in coppi.
## Toccando un edificio il contadino ci va a piedi; quando arriva la mappa
## emette building_reached e main.gd apre il pannello giusto.

signal building_reached(id: String)

const TILE_W := Iso.TILE_W
const TILE_H := Iso.TILE_H
const SIZE := Vector2i(14, 14)
const WALK_SPEED := 240.0
const DRAG_THRESHOLD := 8.0

const TEX_GRASS := preload("res://assets/graphics/tiles/grass.png")
const TEX_GRASS_FLOWERS := preload("res://assets/graphics/tiles/grass_flowers.png")

## Edifici: cella in alto a sinistra dell'ingombro, ingombro, altezza dei muri.
const BUILDINGS := {
	"mulino":          {"cell": Vector2i(0, 0),   "size": Vector2i(2, 2), "h": 70},
	"forno":           {"cell": Vector2i(3, 2),   "size": Vector2i(2, 2), "h": 52},
	"bar":             {"cell": Vector2i(2, 4),   "size": Vector2i(2, 2), "h": 50},
	"ufficio_postale": {"cell": Vector2i(8, 2),   "size": Vector2i(2, 2), "h": 56},
	"campanile":       {"cell": Vector2i(10, 1),  "size": Vector2i(2, 2), "h": 150},
	"osteria":         {"cell": Vector2i(10, 4),  "size": Vector2i(2, 2), "h": 56},
	"bocce":           {"cell": Vector2i(12, 0),  "size": Vector2i(2, 2), "h": 0},
	"frantoio":        {"cell": Vector2i(2, 8),   "size": Vector2i(2, 2), "h": 48},
	"gelateria":       {"cell": Vector2i(4, 10),  "size": Vector2i(2, 2), "h": 48},
	"pasticceria":     {"cell": Vector2i(2, 12),  "size": Vector2i(2, 2), "h": 50},
	"caseificio":      {"cell": Vector2i(0, 10),  "size": Vector2i(2, 2), "h": 46},
	"pastificio":      {"cell": Vector2i(8, 10),  "size": Vector2i(2, 2), "h": 52},
	"cantina":         {"cell": Vector2i(10, 8),  "size": Vector2i(2, 2), "h": 46},
	"conserve":        {"cell": Vector2i(11, 11), "size": Vector2i(2, 2), "h": 46},
	"caldarroste":     {"cell": Vector2i(8, 8),   "size": Vector2i(1, 1), "h": 26},
	"bacheca":         {"cell": Vector2i(5, 5),   "size": Vector2i(1, 1), "h": 40},
}
## Sprite illustrato di ogni edificio restaurato (assets/graphics/sprites).
## Senza sprite, o finché non è restaurato, l'edificio si disegna da codice.
const SPRITES := {
	"mulino": "mulino", "forno": "forno", "bar": "casetta", "osteria": "casale",
	"ufficio_postale": "casa_piccola", "campanile": "torre", "conserve": "bancarella",
	"caseificio": "capanno", "cantina": "fienile", "gelateria": "bancarella_c",
	"pastificio": "casa_pergola", "pasticceria": "villa",
}
## Larghezza dello sprite rispetto all'ingombro (torri e mulini sono alti e stretti).
## Edifici disegnati sulla loro base 2x2, in due versioni: [rudere, restaurato]
## (fogli edifici_conserve e edifici_misti). Hanno la precedenza su SPRITES.
const PAIRS := {
	"mulino": ["mulino_rudere", "mulino_restaurato"],
	"forno": ["forno_rudere", "forno"],
	"ufficio_postale": ["ufficio_postale_rudere", "ufficio_postale_b"],
	"frantoio": ["frantoio_rudere", ""],
	"conserve": ["conserve_rudere", "conserve"],
	"caseificio": ["caseificio_rudere", "caseificio"],
	"cantina": ["cantina_rudere", "cantina"],
	"gelateria": ["gelateria_rudere", "gelateria"],
	"bocce": ["bocce_rudere", "bocce"],
}
const SPRITE_SCALE := {"campanile": 0.62, "mulino": 0.9, "conserve": 0.95, "gelateria": 0.95}
const PIAZZA := Rect2i(5, 5, 4, 4)
const FOUNTAIN := Vector2(7.0, 7.0)

var camera: WorldCamera
var _farmer_pos := Vector2.ZERO
var _farmer_flip := false
var _target := Vector2.ZERO
var _target_building := ""
var _clock := 0.0
var _hover := Vector2i(-1, -1)
var _press := false
var _press_pos := Vector2.ZERO
var _panning := false
var _font: Font


func _ready() -> void:
	_font = load("res://assets/fonts/Fredoka-SemiBold.ttf")
	GameState.changed.connect(queue_redraw)
	_farmer_pos = cell_center(Vector2i(7, 10))
	_target = _farmer_pos
	camera = WorldCamera.new()
	add_child(camera)
	var top := cell_to_local(Vector2(0, 0))
	var left := cell_to_local(Vector2(0, SIZE.y))
	var right := cell_to_local(Vector2(SIZE.x, 0))
	var bottom := cell_to_local(Vector2(SIZE.x, SIZE.y))
	camera.bounds = Rect2(left.x - 60, top.y - 200, right.x - left.x + 120, bottom.y - top.y + 260)
	camera.zoom = Vector2(0.75, 0.75)
	camera.center_on(cell_to_local(FOUNTAIN))


func _process(delta: float) -> void:
	_clock += delta
	var d := _target - _farmer_pos
	if d.length() > 1.0:
		_farmer_flip = d.x < 0.0
		_farmer_pos += d.limit_length(WALK_SPEED * delta)
	elif _target_building != "":
		var id := _target_building
		_target_building = ""
		building_reached.emit(id)
	queue_redraw()


# --- Coordinate --------------------------------------------------------------

func cell_to_local(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * TILE_W * 0.5, (cell.x + cell.y) * TILE_H * 0.5)


func cell_center(cell: Vector2i) -> Vector2:
	return cell_to_local(Vector2(cell)) + Vector2(0, TILE_H * 0.5)


func local_to_cell(p: Vector2) -> Vector2i:
	var a := p.x / (TILE_W * 0.5)
	var b := p.y / (TILE_H * 0.5)
	return Vector2i(floori((a + b) * 0.5), floori((b - a) * 0.5))


func building_at(cell: Vector2i) -> String:
	for id in BUILDINGS:
		var b: Dictionary = BUILDINGS[id]
		if Rect2i(b["cell"], b["size"]).has_point(cell):
			return id
	return ""


## Davanti alla porta: la cella sotto lo spigolo anteriore dell'edificio.
func door_point(id: String) -> Vector2:
	var b: Dictionary = BUILDINGS[id]
	var c: Vector2i = b["cell"]
	var s: Vector2i = b["size"]
	return cell_to_local(Vector2(c.x + s.x * 0.5, c.y + s.y + 0.45))


func is_path(cell: Vector2i) -> bool:
	if PIAZZA.has_point(cell):
		return true
	return cell.x == 6 or cell.x == 7 or cell.y == 6 or cell.y == 7


# --- Input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press = true
			_panning = false
			_press_pos = event.position
			get_viewport().set_input_as_handled()
		else:
			if _press and not _panning:
				_tap(local_to_cell(get_local_mouse_position()))
			_press = false
	elif event is InputEventMouseMotion:
		_hover = local_to_cell(get_local_mouse_position())
		if _press and (_panning or event.position.distance_to(_press_pos) > DRAG_THRESHOLD):
			_panning = true
			camera.pan_by(event.relative)


func _tap(cell: Vector2i) -> void:
	var id := building_at(cell)
	if id != "":
		_target = door_point(id)
		_target_building = id
	elif Rect2i(Vector2i.ZERO, SIZE).has_point(cell):
		_target = cell_center(cell)
		_target_building = ""


# --- Disegno ----------------------------------------------------------------

func _draw() -> void:
	# terreno: erba e ciottoli
	for y in SIZE.y:
		for x in SIZE.x:
			var cell := Vector2i(x, y)
			var rect := Rect2(cell_to_local(Vector2(cell)) - Vector2(TILE_W * 0.5, 0), Vector2(TILE_W, TILE_H))
			if is_path(cell):
				_draw_cobbles(cell)
			else:
				var flowers := posmod(x * 7 + y * 13, 5) == 0
				draw_texture_rect(TEX_GRASS_FLOWERS if flowers else TEX_GRASS, rect, false)
	if building_at(_hover) != "":
		_outline_building(building_at(_hover))

	# fontana, edifici e contadino in ordine di profondità
	var items: Array = []
	for id in BUILDINGS:
		var b: Dictionary = BUILDINGS[id]
		var front: Vector2i = b["cell"] + b["size"]
		items.append({"depth": front.x + front.y, "id": id})
	items.append({"depth": FOUNTAIN.x + FOUNTAIN.y + 1.0, "id": "_fountain"})
	var farmer_cell := local_to_cell(_farmer_pos)
	items.append({"depth": farmer_cell.x + farmer_cell.y + 1.5, "id": "_farmer"})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["depth"] < b["depth"])
	for it in items:
		match it["id"]:
			"_fountain":
				_draw_fountain()
			"_farmer":
				var walking := _farmer_pos.distance_to(_target) > 1.0
				FarmerDrawer.draw(self, _farmer_pos, _clock, walking, "", _farmer_flip)
			_:
				_draw_building(it["id"])
	# nome dell'edificio sotto il cursore
	var hid := building_at(_hover)
	if hid != "":
		_name_pill(hid)


func _draw_cobbles(cell: Vector2i) -> void:
	var c := cell_center(cell)
	var poly := PackedVector2Array([c + Vector2(0, -TILE_H * 0.5), c + Vector2(TILE_W * 0.5, 0), c + Vector2(0, TILE_H * 0.5), c + Vector2(-TILE_W * 0.5, 0)])
	draw_colored_polygon(poly, Color("cdb994"))
	var rng := RandomNumberGenerator.new()
	rng.seed = cell.x * 97 + cell.y * 13
	for i in 14:
		var u := rng.randf_range(-0.42, 0.42)
		var v := rng.randf_range(-0.42, 0.42)
		var p := c + Vector2((u - v) * TILE_W * 0.5, (u + v) * TILE_H * 0.5)
		var r := rng.randf_range(4.0, 7.0)
		draw_set_transform(p, 0.0, Vector2(1.0, 0.55))
		draw_circle(Vector2(0, 1.5), r, Color("a99470"))
		draw_circle(Vector2.ZERO, r, Color("ddcca8") if rng.randf() < 0.5 else Color("d2bf98"))
		draw_set_transform(Vector2.ZERO)


func _draw_fountain() -> void:
	var c := cell_to_local(FOUNTAIN)
	if Sprites.tex("fontana") != null:
		Sprites.draw(self, "fontana", c + Vector2(0, 34), 150.0, 0.0)
		return
	draw_set_transform(c, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2(0, 8), 54.0, Color(0.2, 0.15, 0.1, 0.18))
	draw_circle(Vector2.ZERO, 52.0, Color("bfae8e"))
	draw_circle(Vector2.ZERO, 44.0, Color("5aa3c8"))
	draw_circle(Vector2(-10, -8), 16.0, Color(1, 1, 1, 0.2))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(c + Vector2(-7, -40), Vector2(14, 40)), Color("cdbd9b"))
	draw_set_transform(c + Vector2(0, -40), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 18.0, Color("cdbd9b"))
	draw_circle(Vector2.ZERO, 14.0, Color("6fb3d6"))
	draw_set_transform(Vector2.ZERO)
	# zampilli
	for i in 6:
		var a := i * TAU / 6.0 + _clock * 0.5
		var t := fmod(_clock * 1.4 + i * 0.3, 1.0)
		var p := c + Vector2(cos(a) * 16.0 * t, -52.0 + 40.0 * t * t - 10.0 * t)
		draw_circle(p, 2.2, Color(0.85, 0.95, 1.0, 1.0 - t))


## Edificio come scatola isometrica: due muri visibili e tetto, oppure rudere.
func _draw_building(id: String) -> void:
	var b: Dictionary = BUILDINGS[id]
	var cell: Vector2i = b["cell"]
	var s: Vector2i = b["size"]
	var h: float = b["h"]
	var restored := id == "bacheca" or id == "caldarroste" or GameState.is_restored(id)
	var a := Vector2(cell)
	var top := cell_to_local(a)
	var right := cell_to_local(a + Vector2(s.x, 0))
	var front := cell_to_local(a + Vector2(s))
	var left := cell_to_local(a + Vector2(0, s.y))
	# ombra
	draw_colored_polygon(PackedVector2Array([left, front, front + Vector2(30, 10), left + Vector2(30, 10)]), Color(0.2, 0.15, 0.1, 0.16))
	if PAIRS.has(id):
		var sprite: String = PAIRS[id][1 if restored else 0]
		if sprite != "" and Sprites.tex(sprite) != null:
			# la base dello sprite riempie l'ingombro: punta davanti sullo spigolo
			Sprites.draw(self, sprite, front + Vector2(0, 14), TILE_W * float(s.x) * 1.04, 0.0)
			return
	match id:
		"bacheca":
			_draw_board(cell_center(cell))
			return
		"caldarroste":
			_draw_stand(cell_center(cell))
			return
		"bocce":
			_draw_bocce(top, right, front, left)
			return
	if not restored:
		_draw_ruin(id, top, right, front, left, h)
		return
	if SPRITES.has(id) and Sprites.tex(SPRITES[id]) != null:
		# lo sprite ha il suo pezzo di terreno: la punta davanti sullo spigolo
		Sprites.draw(self, SPRITES[id], front + Vector2(0, 8), TILE_W * float(s.x) * 1.12 * SPRITE_SCALE.get(id, 1.0), 0.0)
		return
	var up := Vector2(0, -h)
	var wall_l := Color("f0d2a6")
	var wall_r := Color("dcb789")
	if id == "campanile":
		wall_l = Color("e8c08f")
		wall_r = Color("cfa16c")
	draw_colored_polygon(PackedVector2Array([left, front, front + up, left + up]), wall_l)
	draw_colored_polygon(PackedVector2Array([front, right, right + up, front + up]), wall_r)
	# finestre e porta sul muro di sinistra (verso lo spettatore)
	var n := maxi(1, int(s.x))
	for i in n:
		var t := (i + 0.5) / n
		var base := left.lerp(front, t)
		draw_colored_polygon(_wall_rect(base + Vector2(0, -h * 0.25), left, front, 12, 22), Color("6b4a2b"))
		if h > 60:
			draw_colored_polygon(_wall_rect(base + Vector2(0, -h * 0.62), left, front, 10, 14), Color("6e8fa8"))
	for i in maxi(1, int(s.y)):
		var t2 := (i + 0.5) / maxi(1, int(s.y))
		var base2 := front.lerp(right, t2)
		draw_colored_polygon(_wall_rect(base2 + Vector2(0, -h * 0.55), front, right, 10, 14), Color("6e8fa8"))
		draw_colored_polygon(_wall_rect(base2 + Vector2(-7, -h * 0.55), front, right, 3, 14), Color("5e7a3a"))
	# tetto a padiglione in coppi
	var peak := cell_to_local(a + Vector2(s) * 0.5) + up + Vector2(0, -26 if id != "campanile" else -40)
	var eave := 6.0
	draw_colored_polygon(PackedVector2Array([left + up + Vector2(-eave, 0), front + up + Vector2(0, eave * 0.5), peak]), Color("c0603e"))
	draw_colored_polygon(PackedVector2Array([front + up + Vector2(0, eave * 0.5), right + up + Vector2(eave, 0), peak]), Color("a24a2c"))
	for k in 4:
		var t3 := (k + 1) / 5.0
		draw_line((left + up).lerp(peak, t3), (front + up).lerp(peak, t3), Color(0.5, 0.2, 0.1, 0.35), 1.5)
	if id == "campanile":
		draw_colored_polygon(_wall_rect(left.lerp(front, 0.5) + Vector2(0, -h * 0.85), left, front, 16, 22), Color("4a3423"))
	if id == "mulino":
		_draw_sails(front.lerp(right, 0.5) + Vector2(0, -h * 0.75))


## Rettangolo "appoggiato" su un muro isometrico, centrato in base.
func _wall_rect(base: Vector2, a: Vector2, b: Vector2, w: float, h: float) -> PackedVector2Array:
	var along := (b - a).normalized() * w * 0.5
	return PackedVector2Array([base - along, base + along, base + along + Vector2(0, -h), base - along + Vector2(0, -h)])


func _draw_sails(hub: Vector2) -> void:
	for i in 4:
		var ang := _clock * 0.8 + i * PI * 0.5
		var tip := hub + Vector2(cos(ang), sin(ang) * 0.9) * 46.0
		draw_line(hub, tip, Color("8a5a2b"), 3.0)
		var side := Vector2(-sin(ang), cos(ang) * 0.9) * 9.0
		draw_colored_polygon(PackedVector2Array([hub.lerp(tip, 0.25), tip, tip + side, hub.lerp(tip, 0.25) + side]), Color("f4ead4"))
	draw_circle(hub, 5.0, Color("6b4a2b"))


func _draw_ruin(id: String, top: Vector2, right: Vector2, front: Vector2, left: Vector2, h: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var stone_l := Color("b8a78c")
	var stone_r := Color("a3927a")
	for face in [[left, front, stone_l], [front, right, stone_r]]:
		var a: Vector2 = face[0]
		var b: Vector2 = face[1]
		var pts := PackedVector2Array([a, b])
		var steps := 6
		for i in range(steps, -1, -1):
			var t := float(i) / steps
			var jag := h * rng.randf_range(0.25, 0.7)
			pts.append(a.lerp(b, t) + Vector2(0, -jag))
		draw_colored_polygon(pts, face[2])
		# pietre e una finestra vuota
		for k in 8:
			var t := rng.randf()
			var p := a.lerp(b, t) + Vector2(0, -rng.randf_range(4, h * 0.3))
			draw_rect(Rect2(p, Vector2(8, 4)), Color(face[2]).darkened(0.12))
	# edera e macerie
	for k in 10:
		var t := rng.randf()
		var p := left.lerp(front, t) + Vector2(0, -rng.randf_range(4, h * 0.4))
		draw_circle(p, rng.randf_range(4, 7), Color("4f7f2a"))
	for k in 5:
		var p := front + Vector2(rng.randf_range(-30, 20), rng.randf_range(2, 10))
		draw_circle(p, rng.randf_range(3, 6), Color("a3927a"))


func _draw_board(c: Vector2) -> void:
	draw_line(c + Vector2(-16, 0), c + Vector2(-16, -46), Color("6e4626"), 4.0)
	draw_line(c + Vector2(16, 0), c + Vector2(16, -46), Color("6e4626"), 4.0)
	draw_rect(Rect2(c + Vector2(-22, -54), Vector2(44, 30)), Color("9a6a3e"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-26, -54), c + Vector2(26, -54), c + Vector2(0, -66)]), Color("c0603e"))
	for i in GameState.orders.size():
		var ok := GameState.can_fulfill(i)
		draw_rect(Rect2(c + Vector2(-18 + i * 13, -50), Vector2(10, 14)), Color("f6eedb") if not ok else Color("e9f2c9"))
		draw_circle(c + Vector2(-13 + i * 13, -49), 1.8, Color("c0503a"))


func _draw_stand(c: Vector2) -> void:
	draw_rect(Rect2(c + Vector2(-16, -20), Vector2(32, 18)), Color("8a5a2b"))
	draw_circle(c + Vector2(0, -24), 10.0, Color("3b2a17"))
	for i in 5:
		draw_circle(c + Vector2(-6 + i * 3, -27), 2.5, Color("7b4a26"))
	var smoke := fmod(_clock, 2.0) / 2.0
	draw_circle(c + Vector2(4 + smoke * 6, -34 - smoke * 24), 5 + smoke * 6, Color(0.9, 0.88, 0.85, 0.5 - smoke * 0.5))


func _draw_bocce(top: Vector2, right: Vector2, front: Vector2, left: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([top, right, front, left]), Color("d9c49a"))
	draw_polyline(PackedVector2Array([top, right, front, left, top]), Color("8a5a2b"), 3.0)
	var c := (top + front) * 0.5
	for p in [Vector2(-14, 2), Vector2(10, -4), Vector2(2, 8)]:
		draw_circle(c + p, 4.0, Color("8e9aa6"))
	draw_circle(c + Vector2(-2, -2), 2.0, Color("c0503a"))


func _outline_building(id: String) -> void:
	var b: Dictionary = BUILDINGS[id]
	var a := Vector2(b["cell"])
	var s := Vector2(b["size"])
	var pts := PackedVector2Array([cell_to_local(a), cell_to_local(a + Vector2(s.x, 0)), cell_to_local(a + s), cell_to_local(a + Vector2(0, s.y)), cell_to_local(a)])
	draw_polyline(pts, Color(1, 1, 1, 0.85), 2.5, true)


func _name_pill(id: String) -> void:
	var b: Dictionary = BUILDINGS[id]
	var a := Vector2(b["cell"]) + Vector2(b["size"]) * 0.5
	var p := cell_to_local(a) + Vector2(0, -float(b["h"]) - 46.0)
	var text := GameData.building_name(id)
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 20.0
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.27, 0.19, 0.13, 0.88)
	box.set_corner_radius_all(12)
	draw_style_box(box, Rect2(p - Vector2(w * 0.5, 14), Vector2(w, 26)))
	draw_string(_font, p + Vector2(-w * 0.5 + 10, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f6eedb"))
