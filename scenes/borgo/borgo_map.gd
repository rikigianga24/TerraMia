class_name BorgoMap
extends Node2D
## Il borgo: un paese medievale su un colle, con vie tortuose, vicoli, una
## piazza irregolare, case addossate e le mura attorno.
##
## La pianta (vie, altezze, lotti) è in BorgoLayout, generata da
## tools/gen_borgo.py. Qui si disegna e ci si muove: le altezze sono a mezzi
## livelli, tra due celle di altezza diversa si disegna un muro di pietra (o un
## gradino, sulle vie). Toccando un edificio il contadino ci va per le vie col
## percorso più breve; all'arrivo la mappa emette building_reached.

signal building_reached(id: String)

const TILE_W := Iso.TILE_W
const TILE_H := Iso.TILE_H
const SIZE := BorgoLayout.SIZE
const HALF_H := 20.0                ## pixel di un mezzo livello
const WALL_EXTRA := 1.5             ## le mura sono più alte del terreno (in mezzi livelli)
const FOUNTAIN := Vector2(13.0, 13.5)
const WALK_SPEED := 3.2             ## celle al secondo
const DRAG_THRESHOLD := 8.0

const TEX_GRASS := preload("res://assets/graphics/tiles/grass.png")
const TEX_GRASS_FLOWERS := preload("res://assets/graphics/tiles/grass_flowers.png")
const TEX_COBBLES := preload("res://assets/graphics/tiles/cobbles.png")

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
## Sprite dell'edificio restaurato, se non c'è la coppia rudere/restaurato.
const SPRITES := {
	"bar": "casetta", "osteria": "casale", "campanile": "torre",
	"pastificio": "casa_pergola", "pasticceria": "villa",
}
const HOUSE_SPRITES := ["casetta", "casa_piccola", "casa_grande", "casa_pergola", "casale", "casa_piccola", "casetta"]
## Edifici piccoli in piazza (1x1).
const SMALL := {"bacheca": Vector2i(14, 12), "caldarroste": Vector2i(10, 14)}
## Auto d'epoca: parcheggiate fuori dalla porta e qualcuna in salita.
const CARS := [
	[Vector2(14.6, 26.6), "d9412b"], [Vector2(16.0, 26.4), "e6d3a3"], [Vector2(17.4, 26.7), "5aa3c8"],
	[Vector2(9.8, 20.6), "7c9a3c"], [Vector2(17.8, 23.4), "e6d3a3"],
]
const BIKES := [Vector2(10.3, 14.9), Vector2(5.4, 19.8), Vector2(19.6, 13.8), Vector2(12.6, 25.4)]

var camera: WorldCamera
var buildings: Dictionary = {}     ## id -> {"cell", "size", "h"}
var _houses: Array = []            ## [cella, sprite]
var _trees: Array = []             ## [punto, sprite]
var _astar := AStarGrid2D.new()
var _farmer := Vector2(BorgoLayout.GATE) + Vector2(0.5, 0.5)
var _route: Array = []
var _farmer_flip := false
var _target_building := ""
var _clock := 0.0
var _hover := Vector2i(-1, -1)
var _hover_building := ""
var _press := false
var _press_pos := Vector2.ZERO
var _panning := false
var _font: Font


func _ready() -> void:
	_font = load("res://assets/fonts/Fredoka-SemiBold.ttf")
	GameState.changed.connect(queue_redraw)
	_build()
	camera = WorldCamera.new()
	add_child(camera)
	var top := world(Vector2(0, 0), 0.0)
	var left := world(Vector2(0, SIZE.y), 0.0)
	var right := world(Vector2(SIZE.x, 0), 0.0)
	var bottom := world(Vector2(SIZE), 0.0)
	camera.bounds = Rect2(left.x - 80, top.y - 300, right.x - left.x + 160, bottom.y - top.y + 360)
	camera.zoom = Vector2(0.7, 0.7)
	camera.center_on(world(Vector2(12, 18)))


## Edifici, case, alberi e percorsi dalla pianta.
func _build() -> void:
	for lot in BorgoLayout.LOTS:
		var cell: Vector2i = lot[0]
		var id: String = lot[1]
		if id == "":
			_houses.append([cell, HOUSE_SPRITES[posmod(hash(cell), HOUSE_SPRITES.size())]])
		else:
			var h := 150 if id == "campanile" else (0 if id == "bocce" else 52)
			buildings[id] = {"cell": cell, "size": Vector2i(2, 2), "h": h}
	for id in SMALL:
		buildings[id] = {"cell": SMALL[id], "size": Vector2i(1, 1), "h": 40}
	# cipressi e ulivi fuori dalle mura, qualche albero negli orti
	for y in SIZE.y:
		for x in SIZE.x:
			var cell := Vector2i(x, y)
			var t := terrain(cell)
			var r := posmod(hash(cell + Vector2i(7, 3)), 100)
			if t == " " and r < 14 and not _near_building(cell):
				_trees.append([Vector2(cell) + Vector2(0.5, 0.6), "cipresso" if r < 9 else "ulivo_albero_c"])
			elif t == "." and r < 30 and not _in_lot(cell):
				_trees.append([Vector2(cell) + Vector2(0.5, 0.6), "ulivo_albero_c" if r < 12 else "cipresso"])
	# percorsi: solo vie e piazza, senza attraversare edifici e fontana
	_astar.region = Rect2i(Vector2i.ZERO, SIZE)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()
	for y in SIZE.y:
		for x in SIZE.x:
			var cell := Vector2i(x, y)
			_astar.set_point_solid(cell, not (terrain(cell) in ["#", "p"]) or building_at(cell) != "")
	for c in [Vector2i(12, 13), Vector2i(13, 13)]:
		_astar.set_point_solid(c, true)


func _in_lot(cell: Vector2i) -> bool:
	for lot in BorgoLayout.LOTS:
		if Rect2i(lot[0], Vector2i(2, 2)).has_point(cell):
			return true
	return false


func _near_building(cell: Vector2i) -> bool:
	for lot in BorgoLayout.LOTS:
		if Rect2i(lot[0] - Vector2i(1, 1), Vector2i(4, 4)).has_point(cell):
			return true
	return false


func _process(delta: float) -> void:
	_clock += delta
	if not _route.is_empty():
		var next: Vector2 = _route[0]
		var d := next - _farmer
		var step := WALK_SPEED * delta
		if d.length() <= step:
			_farmer = next
			_route.pop_front()
		else:
			_farmer += d.normalized() * step
			var screen_dx := world(next).x - world(_farmer).x
			if absf(screen_dx) > 0.5:
				_farmer_flip = screen_dx < 0.0
	elif _target_building != "":
		var id := _target_building
		_target_building = ""
		building_reached.emit(id)
	queue_redraw()


## Il contadino arriva dalla fattoria: entra dalla porta delle mura.
func arrive() -> void:
	_farmer = Vector2(BorgoLayout.GATE) + Vector2(0.5, 0.5)
	_route = []
	_target_building = ""
	camera.center_on(world(Vector2(12, 21)))


# --- Pianta e coordinate ----------------------------------------------------

func in_map(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE.x and cell.y < SIZE.y


func terrain(cell: Vector2i) -> String:
	return BorgoLayout.TERRAIN[cell.y][cell.x] if in_map(cell) else " "


## Altezza della cella in livelli (le mura sporgono un po').
func cell_h(cell: Vector2i) -> float:
	if not in_map(cell):
		return -0.6
	var h := float(BorgoLayout.HEIGHT[cell.y].unicode_at(cell.x) - 48) * 0.5
	if terrain(cell) == "w":
		h += WALL_EXTRA * 0.5
	return h


## Altezza del terreno sotto un punto, sfumata tra le celle (per il contadino).
func elev(p: Vector2) -> float:
	var q := p - Vector2(0.5, 0.5)
	var c := Vector2i(floori(q.x), floori(q.y))
	var f := q - Vector2(c)
	var h00 := _ground_h(c)
	var h10 := _ground_h(c + Vector2i(1, 0))
	var h01 := _ground_h(c + Vector2i(0, 1))
	var h11 := _ground_h(c + Vector2i(1, 1))
	var own := _ground_h(Vector2i(floori(p.x), floori(p.y)))
	var smooth := lerpf(lerpf(h00, h10, f.x), lerpf(h01, h11, f.x), f.y)
	# vicino al centro della cella si sta alla sua altezza (gradini netti)
	return lerpf(own, smooth, 0.6)


func _ground_h(cell: Vector2i) -> float:
	if not in_map(cell):
		return 0.0
	return float(BorgoLayout.HEIGHT[cell.y].unicode_at(cell.x) - 48) * 0.5


func cell_to_local(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * TILE_W * 0.5, (cell.x + cell.y) * TILE_H * 0.5)


## Punto della mappa sullo schermo, sollevato della sua altezza (in livelli).
func world(p: Vector2, h := INF) -> Vector2:
	var z := elev(p) if h == INF else h
	return cell_to_local(p) - Vector2(0, z * HALF_H * 2.0)


func cell_poly(cell: Vector2i) -> PackedVector2Array:
	var h := cell_h(cell)
	var c := Vector2(cell)
	return PackedVector2Array([world(c, h), world(c + Vector2(1, 0), h), world(c + Vector2(1, 1), h), world(c + Vector2(0, 1), h)])


func is_street(cell: Vector2i) -> bool:
	return terrain(cell) in ["#", "p"]


func pick_cell(local: Vector2) -> Vector2i:
	for depth in range(SIZE.x + SIZE.y - 2, -1, -1):
		for x in range(SIZE.x - 1, -1, -1):
			var y := depth - x
			if y < 0 or y >= SIZE.y:
				continue
			var cell := Vector2i(x, y)
			if Geometry2D.is_point_in_polygon(local, cell_poly(cell)):
				return cell
	return Vector2i(-1, -1)


func building_at(cell: Vector2i) -> String:
	for id in buildings:
		var b: Dictionary = buildings[id]
		if Rect2i(b["cell"], b["size"]).has_point(cell):
			return id
	return ""


func pick_building(local: Vector2) -> String:
	var best := ""
	var best_depth := -INF
	for id in buildings:
		var b: Dictionary = buildings[id]
		var depth := float(b["cell"].x + b["cell"].y)
		if _building_rect(id).has_point(local) and depth > best_depth:
			best = id
			best_depth = depth
	return best if best != "" else building_at(pick_cell(local))


func _building_rect(id: String) -> Rect2:
	var b: Dictionary = buildings[id]
	var s: Vector2i = b["size"]
	var a := Vector2(b["cell"])
	var lv := cell_h(b["cell"])
	var left := world(a + Vector2(0, s.y), lv)
	var right := world(a + Vector2(s.x, 0), lv)
	var front := world(a + Vector2(s), lv)
	var h := maxf(float(b["h"]), 30.0) + 50.0
	return Rect2(Vector2(left.x, right.y - h), Vector2(right.x - left.x, front.y - right.y + h))


## Cella di via davanti all'edificio (davanti, poi a destra, dietro, a sinistra).
func door_cell(id: String) -> Vector2i:
	var b: Dictionary = buildings[id]
	var c: Vector2i = b["cell"]
	var s: Vector2i = b["size"]
	var cands: Array = []
	for i in s.x:
		cands.append(c + Vector2i(i, s.y))
	for i in s.y:
		cands.append(c + Vector2i(s.x, i))
	for i in s.x:
		cands.append(c + Vector2i(i, -1))
	for i in s.y:
		cands.append(c + Vector2i(-1, i))
	for cand in cands:
		if in_map(cand) and not _astar.is_point_solid(cand):
			return cand
	return BorgoLayout.GATE


func door_point(id: String) -> Vector2:
	return Vector2(door_cell(id)) + Vector2(0.5, 0.5)


## Percorso più breve per le vie, come centri di cella.
func route(from: Vector2, to: Vector2) -> Array:
	var a := Vector2i(floori(from.x), floori(from.y))
	var b := Vector2i(floori(to.x), floori(to.y))
	if not _astar.is_in_boundsv(a) or not _astar.is_in_boundsv(b):
		return []
	var path := _astar.get_id_path(a, b, true)
	if path.is_empty():
		return []
	var out: Array = []
	for i in range(1, path.size()):
		out.append(Vector2(path[i]) + Vector2(0.5, 0.5))
	if out.is_empty() or (out[-1] as Vector2).distance_to(to) > 0.05:
		out.append(to)
	return out


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
				_tap(get_local_mouse_position())
			_press = false
	elif event is InputEventMouseMotion:
		_hover = pick_cell(get_local_mouse_position())
		_hover_building = pick_building(get_local_mouse_position())
		if _press and (_panning or event.position.distance_to(_press_pos) > DRAG_THRESHOLD):
			_panning = true
			camera.pan_by(event.relative)


func _tap(local: Vector2) -> void:
	var id := pick_building(local)
	if id != "":
		_route = route(_farmer, door_point(id))
		_target_building = id
		return
	var cell := pick_cell(local)
	if in_map(cell) and not _astar.is_point_solid(cell):
		_route = route(_farmer, Vector2(cell) + Vector2(0.5, 0.5))
		_target_building = ""


# --- Disegno ----------------------------------------------------------------

func _draw() -> void:
	for depth in SIZE.x + SIZE.y - 1:
		for x in SIZE.x:
			var y := depth - x
			if y >= 0 and y < SIZE.y:
				_draw_cell(Vector2i(x, y))
	var hid := _hover_building
	if hid != "":
		_outline_building(hid)

	var items: Array = []
	for id in buildings:
		var b: Dictionary = buildings[id]
		var front: Vector2i = b["cell"] + b["size"]
		items.append({"d": front.x + front.y - 0.5, "kind": "building", "id": id})
	for h in _houses:
		items.append({"d": h[0].x + h[0].y + 3.5, "kind": "house", "cell": h[0], "sprite": h[1]})
	for c in CARS:
		items.append({"d": c[0].x + c[0].y, "kind": "car", "p": c[0], "color": c[1]})
	for bk in BIKES:
		items.append({"d": bk.x + bk.y, "kind": "bike", "p": bk})
	for t in _trees:
		items.append({"d": t[0].x + t[0].y, "kind": "tree", "p": t[0], "sprite": t[1]})
	items.append({"d": FOUNTAIN.x + FOUNTAIN.y + 0.6, "kind": "fountain"})
	items.append({"d": _farmer.x + _farmer.y + 0.05, "kind": "farmer"})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["d"] < b["d"])
	for it in items:
		match it["kind"]:
			"building":
				_draw_building(it["id"])
			"house":
				_draw_house(it["cell"], it["sprite"])
			"car":
				_draw_car(it["p"], Color(it["color"]))
			"bike":
				_draw_bike(world(it["p"]))
			"tree":
				var w := 40.0 if it["sprite"] == "cipresso" else 80.0
				Sprites.draw(self, it["sprite"], world(it["p"]), w, 0.05)
			"fountain":
				_draw_fountain()
			"farmer":
				FarmerDrawer.draw(self, world(_farmer), _clock, not _route.is_empty(), "", _farmer_flip)
	if hid != "":
		_name_pill(hid)


func _draw_cell(cell: Vector2i) -> void:
	var t := terrain(cell)
	var poly := cell_poly(cell)
	if t == "w":
		# cammino di ronda delle mura: pietra, con la merlatura sul bordo
		draw_colored_polygon(poly, Color("cbb894"))
		draw_polyline(PackedVector2Array([poly[3], poly[2], poly[1]]), Color("e2d3b2"), 3.0)
	else:
		var tex: Texture2D = TEX_COBBLES if is_street(cell) else (TEX_GRASS_FLOWERS if posmod(hash(cell), 6) == 0 else TEX_GRASS)
		var tint := Color.WHITE if t != " " else Color(0.96, 1.0, 0.92)
		var uv := PackedVector2Array([Vector2(0.5, 0), Vector2(1, 0.5), Vector2(0.5, 1), Vector2(0, 0.5)])
		draw_polygon(poly, PackedColorArray([tint, tint, tint, tint]), uv, tex)
	var h := cell_h(cell)
	var c := Vector2(cell)
	var stone_l := Color("c9b48f") if t != "w" else Color("bba57d")
	var stone_r := Color("a8946f") if t != "w" else Color("9a8662")
	_wall(c + Vector2(0, 1), c + Vector2(1, 1), h, cell_h(cell + Vector2i(0, 1)), stone_l, is_street(cell))
	_wall(c + Vector2(1, 0), c + Vector2(1, 1), h, cell_h(cell + Vector2i(1, 0)), stone_r, is_street(cell))
	if t == "w":
		# merli
		for k in 3:
			var p := world(c + Vector2(0.15 + k * 0.3, 1.0), h)
			draw_rect(Rect2(p + Vector2(-5, -10), Vector2(10, 10)), Color("cbb894"))


## Muro di pietra lungo uno spigolo, dall'altezza della cella a quella più
## bassa della vicina; sulle vie i salti piccoli sono gradini.
func _wall(a: Vector2, b: Vector2, h: float, low: float, color: Color, step: bool) -> void:
	if h <= low + 0.01:
		return
	var p := PackedVector2Array([world(a, h), world(b, h), world(b, low), world(a, low)])
	draw_colored_polygon(p, color)
	var top_a := world(a, h)
	var top_b := world(b, h)
	var depth_px := (h - low) * HALF_H * 2.0
	if step and depth_px <= HALF_H + 1.0:
		# gradino: pedata chiara e alzata
		draw_line(top_a, top_b, Color("e8dcc0"), 3.0)
		draw_line(top_a + Vector2(0, depth_px * 0.5), top_b + Vector2(0, depth_px * 0.5), color.darkened(0.15), 1.5)
		return
	var y := 9.0
	var row := 0
	while y < depth_px - 2.0:
		draw_line(top_a + Vector2(0, y), top_b + Vector2(0, y), color.darkened(0.18), 1.2)
		# giunti sfalsati
		for k in 4:
			var f := (k + 0.5 * (row % 2) + 0.25) / 4.0
			var q := top_a.lerp(top_b, f) + Vector2(0, y)
			draw_line(q, q + Vector2(0, -9), color.darkened(0.14), 1.0)
		y += 9.0
		row += 1
	draw_line(top_a, top_b, color.lightened(0.2), 2.0)


## Casa del paese: sprite sul lotto 2x2 e fumo dal comignolo.
func _draw_house(cell: Vector2i, sprite: String) -> void:
	var a := Vector2(cell)
	var front := world(a + Vector2(2, 2), cell_h(cell))
	var t := Sprites.tex(sprite)
	if t == null:
		return
	var w := TILE_W * 2.0 * 1.06
	Sprites.draw(self, sprite, front + Vector2(0, 10), w, 0.0, posmod(hash(cell), 2) == 0)
	if posmod(hash(cell), 3) != 0:
		var hgt := t.get_height() * w / t.get_width()
		_smoke(front + Vector2(w * 0.12, -hgt * 0.92), float(posmod(hash(cell), 10)))


func _smoke(p: Vector2, seed_t: float) -> void:
	for i in 5:
		var k := fposmod(_clock * 0.35 + seed_t * 0.13 + i * 0.2, 1.0)
		var q := p + Vector2(sin(k * 5.0 + seed_t) * 6.0 + k * 10.0, -k * 60.0)
		draw_circle(q, 4.0 + k * 9.0, Color(0.93, 0.92, 0.9, 0.55 * (1.0 - k)))


func _draw_car(p: Vector2, body: Color) -> void:
	var foot := world(p)
	draw_set_transform(foot, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2(0, 4), 30.0, Color(0.18, 0.12, 0.05, 0.25))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(foot + Vector2(-26, -20), Vector2(52, 14)), body)
	draw_circle(foot + Vector2(-6, -22), 14.0, body)
	draw_rect(Rect2(foot + Vector2(-14, -31), Vector2(16, 9)), Color("a9cfe0"))
	draw_rect(Rect2(foot + Vector2(-26, -10), Vector2(52, 3)), body.darkened(0.3))
	for x in [-16.0, 16.0]:
		draw_circle(foot + Vector2(x, -4), 6.5, Color("2e2a26"))
		draw_circle(foot + Vector2(x, -4), 2.5, Color("c8c2b4"))
	draw_circle(foot + Vector2(25, -15), 3.0, Color("fff3c4"))


func _draw_bike(p: Vector2) -> void:
	var col := Color("2f6d8a")
	for x in [-11.0, 11.0]:
		draw_arc(p + Vector2(x, -8), 8.0, 0.0, TAU, 18, Color("2e2a26"), 2.0)
	draw_line(p + Vector2(-11, -8), p + Vector2(0, -8), col, 2.5)
	draw_line(p + Vector2(0, -8), p + Vector2(-5, -18), col, 2.5)
	draw_line(p + Vector2(-5, -18), p + Vector2(7, -18), col, 2.5)
	draw_line(p + Vector2(7, -18), p + Vector2(11, -8), col, 2.5)
	draw_line(p + Vector2(7, -18), p + Vector2(9, -24), Color("3b2a17"), 2.5)
	draw_rect(Rect2(p + Vector2(-8, -21), Vector2(7, 3)), Color("3b2a17"))
	draw_rect(Rect2(p + Vector2(8, -23), Vector2(9, 6)), Color("c8a46a"))


func _draw_fountain() -> void:
	var c := world(FOUNTAIN)
	if Sprites.tex("fontana") != null:
		Sprites.draw(self, "fontana", c + Vector2(0, 34), 150.0, 0.0)
		return
	draw_set_transform(c, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 52.0, Color("bfae8e"))
	draw_circle(Vector2.ZERO, 44.0, Color("5aa3c8"))
	draw_set_transform(Vector2.ZERO)


## Edificio del gioco: rudere o restaurato, sprite o disegno da codice.
func _draw_building(id: String) -> void:
	var b: Dictionary = buildings[id]
	var cell: Vector2i = b["cell"]
	var s: Vector2i = b["size"]
	var h: float = b["h"]
	var restored := id == "bacheca" or id == "caldarroste" or GameState.is_restored(id)
	var a := Vector2(cell)
	var lv := cell_h(cell)
	var top := world(a, lv)
	var right := world(a + Vector2(s.x, 0), lv)
	var front := world(a + Vector2(s), lv)
	var left := world(a + Vector2(0, s.y), lv)
	if PAIRS.has(id):
		var sprite: String = PAIRS[id][1 if restored else 0]
		if sprite != "" and Sprites.tex(sprite) != null:
			Sprites.draw(self, sprite, front + Vector2(0, 14), TILE_W * float(s.x) * 1.04, 0.0)
			return
	match id:
		"bacheca":
			_draw_board((top + front) * 0.5)
			return
		"caldarroste":
			_draw_stand((top + front) * 0.5)
			return
		"bocce":
			_draw_bocce(top, right, front, left)
			return
	if not restored:
		_draw_ruin(id, top, right, front, left, h)
		return
	if SPRITES.has(id) and Sprites.tex(SPRITES[id]) != null:
		var k := 0.62 if id == "campanile" else 1.0
		Sprites.draw(self, SPRITES[id], front + Vector2(0, 8), TILE_W * float(s.x) * 1.12 * k, 0.0)
		if id in ["osteria", "bar", "pastificio"]:
			_smoke(front + Vector2(TILE_W * 0.25, -h - 90.0), float(posmod(hash(id), 10)))
		return
	_draw_ruin(id, top, right, front, left, h)


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
	var b: Dictionary = buildings[id]
	var a := Vector2(b["cell"])
	var s := Vector2(b["size"])
	var lv := cell_h(b["cell"])
	var pts := PackedVector2Array([world(a, lv), world(a + Vector2(s.x, 0), lv), world(a + s, lv), world(a + Vector2(0, s.y), lv), world(a, lv)])
	draw_polyline(pts, Color(1, 1, 1, 0.85), 2.5, true)


func _name_pill(id: String) -> void:
	var r := _building_rect(id)
	var p := Vector2(r.get_center().x, r.position.y - 24.0)
	var text := GameData.building_name(id)
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 20.0
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.27, 0.19, 0.13, 0.88)
	box.set_corner_radius_all(12)
	draw_style_box(box, Rect2(p - Vector2(w * 0.5, 14), Vector2(w, 26)))
	draw_string(_font, p + Vector2(-w * 0.5 + 10, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f6eedb"))
