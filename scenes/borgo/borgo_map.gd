class_name BorgoMap
extends Node2D
## Il borgo: un paese medievale in cima a una collina, con vie tortuose,
## vicoli, una piazza irregolare, case addossate, il sagrato con la chiesa e
## le mura; più in basso vigneti, uliveti e boschi.
##
## La pianta (terreno, altezze, lotti) è in BorgoLayout, generata da
## tools/gen_borgo.py. Il terreno è una superficie continua: ogni cella è
## inclinata tra le altezze dei suoi quattro vertici. Toccando un edificio il
## contadino ci va per le vie col percorso più breve; all'arrivo la mappa
## emette building_reached.
##
## Due strati: questo nodo disegna il terreno (ridisegnato solo se serve), il
## figlio _objects disegna ogni fotogramma edifici, alberi, contadino, fumo.

signal building_reached(id: String)

const TILE_W := Iso.TILE_W
const TILE_H := Iso.TILE_H
const SIZE := BorgoLayout.SIZE
const LEVEL_H := 52.0               ## pixel di un livello d'altezza
const WALL_EXTRA := 0.85            ## altezza delle mura (in livelli)
const FOUNTAIN := Vector2(23.0, 21.5)
const WALK_SPEED := 3.2             ## celle al secondo
const DRAG_THRESHOLD := 8.0

const TEX_GRASS := preload("res://assets/graphics/tiles/grass.png")
const TEX_GRASS_FLOWERS := preload("res://assets/graphics/tiles/grass_flowers.png")
const TEX_COBBLES := preload("res://assets/graphics/tiles/cobbles.png")
const TEX_DIRT := preload("res://assets/graphics/tiles/dirt.png")
const WALKABLE := ["#", "p", "c", "r"]

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
const SMALL := {"bacheca": Vector2i(24, 20), "caldarroste": Vector2i(20, 22)}
## Auto d'epoca: parcheggiate fuori dalla porta e qualcuna in salita.
const CARS := [
	[Vector2(23.6, 36.6), "d9412b"], [Vector2(21.0, 36.4), "e6d3a3"], [Vector2(23.8, 38.2), "5aa3c8"],
	[Vector2(19.8, 28.6), "7c9a3c"], [Vector2(27.8, 31.4), "e6d3a3"],
]
const BIKES := [Vector2(20.3, 22.9), Vector2(15.4, 27.8), Vector2(29.6, 21.8), Vector2(22.6, 33.4)]

var camera: WorldCamera
var buildings: Dictionary = {}     ## id -> {"cell", "size", "h"}
var _houses: Array = []            ## [cella, sprite]
var _trees: Array = []             ## [punto, tipo: sprite o "albero", scala]
var _objects: Node2D               ## strato che si ridisegna ogni fotogramma
var _ci: CanvasItem                ## dove disegnano le funzioni degli oggetti
var _astar := AStarGrid2D.new()
var _farmer := Vector2(BorgoLayout.ENTRY) + Vector2(0.5, 0.5)
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
var _streets: Array = []           ## celle percorribili, per le passeggiate
var _walkers: Array = []           ## abitanti e visitatori a spasso
var _event: Dictionary = {}        ## scena di restauro in corso: {"id", "t"}
const EVENT_TIME := 6.0
const REVEAL_AT := 1.6             ## quando, nella scena, l'edificio torna com'era


func _ready() -> void:
	_font = load("res://assets/fonts/Fredoka-SemiBold.ttf")
	GameState.changed.connect(func() -> void: _objects.queue_redraw())
	_build()
	camera = WorldCamera.new()
	add_child(camera)
	var top := world(Vector2(0, 0), 0.0)
	var left := world(Vector2(0, SIZE.y), 0.0)
	var right := world(Vector2(SIZE.x, 0), 0.0)
	var bottom := world(Vector2(SIZE), 0.0)
	# la cima della collina sale di molto sopra la griglia: si allarga verso l'alto
	camera.bounds = Rect2(left.x - 80, top.y - 300 - 13.0 * LEVEL_H, right.x - left.x + 160, bottom.y - top.y + 360 + 13.0 * LEVEL_H)
	camera.zoom = Vector2(0.7, 0.7)
	camera.center_on(world(Vector2(22, 26)))
	_objects = Node2D.new()
	add_child(_objects)
	_ci = _objects
	_objects.draw.connect(_draw_objects)


## Edifici, case, alberi e percorsi dalla pianta.
func _build() -> void:
	for lot in BorgoLayout.LOTS:
		var cell: Vector2i = lot[0]
		var id: String = lot[1]
		if id == "":
			_houses.append([cell, _house_sprite(cell)])
		else:
			var h := 170 if id == "campanile" else (0 if id == "bocce" else 52)
			buildings[id] = {"cell": cell, "size": lot[2], "h": h}
	for id in SMALL:
		buildings[id] = {"cell": SMALL[id], "size": Vector2i(1, 1), "h": 40}
	# alberi: uliveti a file, boschi fitti, qualche cipresso nei prati e negli orti
	for y in SIZE.y:
		for x in SIZE.x:
			var cell := Vector2i(x, y)
			var t := terrain(cell)
			var r := posmod(hash(cell + Vector2i(7, 3)), 100)
			var jit := Vector2(posmod(hash(cell), 7) - 3, posmod(hash(cell + Vector2i(1, 0)), 7) - 3) * 0.05
			match t:
				"o":
					if (x + y) % 2 == 0:
						_trees.append([Vector2(cell) + Vector2(0.5, 0.6) + jit, "ulivo_albero_c", 0.9])
				"b":
					_trees.append([Vector2(cell) + Vector2(0.5, 0.5) + jit * 3.0, "cipresso" if r < 22 else "albero", 0.8 + r * 0.006])
				" ":
					if r < 5 and not _near_building(cell):
						_trees.append([Vector2(cell) + Vector2(0.5, 0.6), "cipresso", 1.0])
				".":
					if r < 30 and not _in_lot(cell):
						_trees.append([Vector2(cell) + Vector2(0.5, 0.6), "ulivo_albero_c" if r < 12 else "cipresso", 0.9])
	# percorsi: solo vie e piazza, senza attraversare edifici e fontana
	_astar.region = Rect2i(Vector2i.ZERO, SIZE)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.update()
	for y in SIZE.y:
		for x in SIZE.x:
			var cell := Vector2i(x, y)
			_astar.set_point_solid(cell, not (terrain(cell) in WALKABLE) or building_at(cell) != "")
	for c in [Vector2i(22, 21), Vector2i(23, 21)]:
		_astar.set_point_solid(c, true)
	for y in SIZE.y:
		for x in SIZE.x:
			if not _astar.is_point_solid(Vector2i(x, y)) and terrain(Vector2i(x, y)) != "r":
				_streets.append(Vector2i(x, y))
	GameState.building_restored.connect(_on_building_restored)


## Casa del paese: le varianti casa_1..casa_8 se ci sono, altrimenti le vecchie.
func _house_sprite(cell: Vector2i) -> String:
	var std: Array = []
	for i in range(1, 9):
		if Sprites.tex("casa_%d" % i) != null:
			std.append("casa_%d" % i)
	var pool: Array = std if not std.is_empty() else HOUSE_SPRITES
	return pool[posmod(hash(cell), pool.size())]


func _in_lot(cell: Vector2i) -> bool:
	for lot in BorgoLayout.LOTS:
		if Rect2i(lot[0], lot[2]).has_point(cell):
			return true
	return false


func _near_building(cell: Vector2i) -> bool:
	for lot in BorgoLayout.LOTS:
		if Rect2i(lot[0] - Vector2i(1, 1), lot[2] + Vector2i(2, 2)).has_point(cell):
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
	_update_walkers(delta)
	if not _event.is_empty():
		_event["t"] = float(_event["t"]) + delta
		if float(_event["t"]) >= EVENT_TIME:
			_event = {}
	_objects.queue_redraw()


## Il contadino arriva dalla fattoria: entra dalla porta delle mura.
func arrive() -> void:
	_farmer = Vector2(BorgoLayout.ENTRY) + Vector2(0.5, 0.5)
	_route = []
	_target_building = ""
	camera.center_on(world(Vector2(22, 30)))


# --- Pianta e coordinate ----------------------------------------------------

func in_map(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE.x and cell.y < SIZE.y


func terrain(cell: Vector2i) -> String:
	return BorgoLayout.TERRAIN[cell.y][cell.x] if in_map(cell) else " "


## Altezza di un vertice della griglia, in livelli.
func vh(v: Vector2i) -> float:
	var x := clampi(v.x, 0, SIZE.x)
	var y := clampi(v.y, 0, SIZE.y)
	return float(BorgoLayout.VHEIGHT[y].unicode_at(x) - 48) * 0.2


## Altezza media di una cella (per gli edifici, che stanno su lotti spianati).
func cell_h(cell: Vector2i) -> float:
	return (vh(cell) + vh(cell + Vector2i(1, 0)) + vh(cell + Vector2i(0, 1)) + vh(cell + Vector2i(1, 1))) * 0.25


## Altezza del terreno sotto un punto (interpolata tra i vertici).
func elev(p: Vector2) -> float:
	var c := Vector2i(floori(p.x), floori(p.y))
	var f := p - Vector2(c)
	return lerpf(lerpf(vh(c), vh(c + Vector2i(1, 0)), f.x), lerpf(vh(c + Vector2i(0, 1)), vh(c + Vector2i(1, 1)), f.x), f.y)


## Per i controlli dei percorsi: altezza al centro della cella.
func _ground_h(cell: Vector2i) -> float:
	return elev(Vector2(cell) + Vector2(0.5, 0.5))


func cell_to_local(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * TILE_W * 0.5, (cell.x + cell.y) * TILE_H * 0.5)


## Punto della mappa sullo schermo, sollevato della sua altezza (in livelli).
func world(p: Vector2, h := INF) -> Vector2:
	var z := elev(p) if h == INF else h
	return cell_to_local(p) - Vector2(0, z * LEVEL_H)


## I quattro angoli della cella sullo schermo: alto, destra, basso, sinistra.
func cell_poly(cell: Vector2i, extra := 0.0) -> PackedVector2Array:
	var c := Vector2(cell)
	return PackedVector2Array([
		world(c, vh(cell) + extra), world(c + Vector2(1, 0), vh(cell + Vector2i(1, 0)) + extra),
		world(c + Vector2(1, 1), vh(cell + Vector2i(1, 1)) + extra), world(c + Vector2(0, 1), vh(cell + Vector2i(0, 1)) + extra)])


func is_street(cell: Vector2i) -> bool:
	return terrain(cell) in ["#", "p", "c"]


func pick_cell(local: Vector2) -> Vector2i:
	for depth in range(SIZE.x + SIZE.y - 2, -1, -1):
		for x in range(SIZE.x - 1, -1, -1):
			var y := depth - x
			if y < 0 or y >= SIZE.y:
				continue
			var cell := Vector2i(x, y)
			var base := cell_to_local(Vector2(cell) + Vector2(0.5, 0.5))
			if absf(base.x - local.x) > TILE_W or local.y > base.y + TILE_H or local.y < base.y - TILE_H - 16.0 * LEVEL_H:
				continue
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
	var h := maxf(float(b["h"]), 30.0) + 50.0 + (60.0 if s.x > 2 else 0.0)
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

## Terreno: celle inclinate, mura, vigne. Si ridisegna solo quando serve.
func _draw() -> void:
	for depth in SIZE.x + SIZE.y - 1:
		for x in SIZE.x:
			var y := depth - x
			if y >= 0 and y < SIZE.y:
				_draw_cell(Vector2i(x, y))


func _draw_objects() -> void:
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
		items.append({"d": t[0].x + t[0].y, "kind": "tree", "p": t[0], "sprite": t[1], "s": t[2]})
	items.append({"d": FOUNTAIN.x + FOUNTAIN.y + 0.6, "kind": "fountain"})
	items.append({"d": _farmer.x + _farmer.y + 0.05, "kind": "farmer"})
	for w in _walkers:
		var wp: Vector2 = w["p"]
		items.append({"d": wp.x + wp.y + 0.04, "kind": "walker", "w": w})
	if _has_tourist("camperisti"):
		items.append({"d": CAMPER_SPOT.x + CAMPER_SPOT.y, "kind": "camper"})
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
				if it["sprite"] == "albero":
					_draw_tree(world(it["p"]), it["s"], it["p"])
				else:
					var w: float = (40.0 if it["sprite"] == "cipresso" else 76.0) * it["s"]
					Sprites.draw(_ci, it["sprite"], world(it["p"]), w, 0.05)
			"fountain":
				_draw_fountain()
			"farmer":
				FarmerDrawer.draw(_ci, world(_farmer), _clock, not _route.is_empty(), "", _farmer_flip)
			"walker":
				_draw_walker(it["w"])
			"camper":
				_draw_camper(world(CAMPER_SPOT))
	if hid != "":
		_name_pill(hid)
	_draw_event_effects()


const TERRAIN_TINT := {
	"c": Color(1.08, 1.06, 1.02), "v": Color(1.02, 1.0, 0.86), "o": Color(0.98, 1.0, 0.9),
	"b": Color(0.8, 0.88, 0.76),
}


func _draw_cell(cell: Vector2i) -> void:
	var t := terrain(cell)
	var poly := cell_poly(cell)
	var c := Vector2(cell)
	var h_top := vh(cell)
	var h_right := vh(cell + Vector2i(1, 0))
	var h_bottom := vh(cell + Vector2i(1, 1))
	var h_left := vh(cell + Vector2i(0, 1))
	# luce da sinistra: i pendii rivolti a sinistra e verso lo spettatore sono più chiari
	var shade := clampf(1.0 + 0.55 * ((h_right - h_left) + 0.5 * (h_top - h_bottom)), 0.68, 1.2)
	var tint: Color = TERRAIN_TINT.get(t, Color.WHITE)
	tint = Color(tint.r * shade, tint.g * shade, tint.b * shade)
	var tex: Texture2D = TEX_GRASS
	if t in ["#", "p", "c"]:
		tex = TEX_COBBLES
	elif t == "r":
		tex = TEX_DIRT
	elif t in [" ", "."] and posmod(hash(cell), 6) == 0:
		tex = TEX_GRASS_FLOWERS
	var uv := PackedVector2Array([Vector2(0.5, 0), Vector2(1, 0.5), Vector2(0.5, 1), Vector2(0, 0.5)])
	draw_polygon(poly, PackedColorArray([tint, tint, tint, tint]), uv, tex)
	if t == "v":
		_draw_vines(cell)
	if t == "w":
		_draw_town_wall(cell)
	# bordo della mappa: la terra sotto la collina
	if cell.y == SIZE.y - 1:
		_skirt(c + Vector2(0, 1), c + Vector2(1, 1), h_left, h_bottom, Color("8a5f3a"))
	if cell.x == SIZE.x - 1:
		_skirt(c + Vector2(1, 0), c + Vector2(1, 1), h_right, h_bottom, Color("6e4a2c"))


func _skirt(a: Vector2, b: Vector2, ha: float, hb: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([world(a, ha), world(b, hb), world(b, -0.8), world(a, -0.8)]), color)


## Filari di vite lungo la cella: pali, foglie e grappoli.
func _draw_vines(cell: Vector2i) -> void:
	var c := Vector2(cell)
	for fy in [0.28, 0.78]:
		var pa := world(c + Vector2(0.0, fy))
		var pb := world(c + Vector2(1.0, fy))
		draw_line(pa + Vector2(0, 2), pb + Vector2(0, 2), Color(0.2, 0.28, 0.1, 0.35), 7.0)
		draw_line(pa + Vector2(0, -6), pb + Vector2(0, -6), Color("5b8a2e"), 8.0)
		draw_line(pa + Vector2(0, -9), pb + Vector2(0, -9), Color("7fae45"), 4.0)
		var post := world(c + Vector2(0.1, fy))
		draw_line(post, post + Vector2(0, -14), Color("7a5a3a"), 2.0)
		if posmod(hash(cell + Vector2i(int(fy * 10), 0)), 3) == 0:
			var g := world(c + Vector2(0.55, fy))
			draw_circle(g + Vector2(0, -3), 2.6, Color("5b2a6e"))
			draw_circle(g + Vector2(3, -2), 2.2, Color("6a3480"))


## Mura sottili lungo i lati della cella che danno verso l'esterno del paese,
## con i merli in cima. Prima i lati in fondo, poi quelli davanti.
func _draw_town_wall(cell: Vector2i) -> void:
	var c := Vector2(cell)
	var edges := [
		[c, c + Vector2(1, 0), Vector2i(0, -1), Color("b29d77")],
		[c, c + Vector2(0, 1), Vector2i(-1, 0), Color("a28e69")],
		[c + Vector2(0, 1), c + Vector2(1, 1), Vector2i(0, 1), Color("cdb88f")],
		[c + Vector2(1, 0), c + Vector2(1, 1), Vector2i(1, 0), Color("ae9973")],
	]
	for e in edges:
		var n: Vector2i = cell + e[2]
		if terrain(n) in [".", "#", "p", "c", "w"]:
			continue
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var ha := elev(a)
		var hb := elev(b)
		var ta := world(a, ha + WALL_EXTRA)
		var tb := world(b, hb + WALL_EXTRA)
		var col: Color = e[3]
		draw_colored_polygon(PackedVector2Array([ta, tb, world(b, hb), world(a, ha)]), col)
		for k in range(1, 4):
			var f := k / 4.0
			draw_line(ta.lerp(world(a, ha), f), tb.lerp(world(b, hb), f), col.darkened(0.12), 1.0)
		draw_line(ta, tb, Color("e2d3b2"), 3.0)
		for k in 3:
			var q := ta.lerp(tb, (k + 0.5) / 3.0)
			draw_rect(Rect2(q + Vector2(-5, -9), Vector2(10, 9)), Color("d6c49f"))
			draw_rect(Rect2(q + Vector2(-5, -9), Vector2(10, 9)), col.darkened(0.2), false, 1.0)


## Albero del bosco: tronco e chioma a tre volumi (finché non c'è lo sprite).
func _draw_tree(p: Vector2, s: float, cell_p: Vector2) -> void:
	var dark := Color("3f6a2c") if posmod(int(cell_p.x * 7 + cell_p.y * 3), 2) == 0 else Color("4a7a30")
	_ci.draw_set_transform(p + Vector2(6, 2), 0.0, Vector2(1.0, 0.45))
	_ci.draw_circle(Vector2.ZERO, 26.0 * s, Color(0.15, 0.2, 0.08, 0.3))
	_ci.draw_set_transform(Vector2.ZERO)
	_ci.draw_line(p, p + Vector2(0, -26 * s), Color("6b4a2b"), 7.0 * s)
	var crown := p + Vector2(0, -42 * s)
	_ci.draw_circle(crown + Vector2(8, 6) * s, 22 * s, dark.darkened(0.15))
	_ci.draw_circle(crown + Vector2(-9, 3) * s, 20 * s, dark)
	_ci.draw_circle(crown + Vector2(0, -9) * s, 20 * s, dark.lightened(0.12))
	_ci.draw_circle(crown + Vector2(-7, -15) * s, 8 * s, Color(1, 1, 1, 0.1))


## Chiesa romanica col campanile (rudere o restaurata), disegnata da codice
## finché non c'è lo sprite. Il lotto è 3x4: navata larga 2 e lunga 4 col
## tetto a capanna, facciata col rosone e il portale verso il sagrato;
## campanile quadrato accanto alla facciata, sul lato destro.
func _draw_church(cell: Vector2i, lv: float, restored: bool) -> void:
	var a := Vector2(cell)
	var wall_l := Color("eddcb8") if restored else Color("bfae90")
	var wall_r := Color("d4bd93") if restored else Color("a99a7e")
	var h := 1.5 if restored else 0.9
	# navata: celle x 0..2, y 0..4
	var top := world(a, lv)
	var right := world(a + Vector2(2, 0), lv)
	var front := world(a + Vector2(2, 4), lv)
	var left := world(a + Vector2(0, 4), lv)
	var up := Vector2(0, -h * LEVEL_H)
	_ci.draw_colored_polygon(PackedVector2Array([front, right, right + up, front + up]), wall_r)
	_ci.draw_colored_polygon(PackedVector2Array([left, front, front + up, left + up]), wall_l)
	var gable := left.lerp(front, 0.5) + up + Vector2(0, -0.8 * LEVEL_H)
	_ci.draw_colored_polygon(PackedVector2Array([left + up, front + up, gable]), wall_l.lightened(0.05))
	var fc := left.lerp(front, 0.5)
	if restored:
		var back_gable := gable + (right - front)
		_ci.draw_colored_polygon(PackedVector2Array([front + up, right + up, back_gable, gable]), Color("b65a3c"))
		for k in range(1, 6):
			var f := k / 6.0
			_ci.draw_line((front + up).lerp(gable, f), (right + up).lerp(back_gable, f), Color("94442b"), 1.5)
		_ci.draw_line(gable, back_gable, Color("7a321d"), 3.0)
		_ci.draw_circle(fc + up + Vector2(0, -8), 12.0, Color("6e8fa8"))
		_ci.draw_arc(fc + up + Vector2(0, -8), 12.0, 0, TAU, 24, Color("8a6a44"), 3.0)
		for k in 6:
			_ci.draw_line(fc + up + Vector2(0, -8), fc + up + Vector2(0, -8) + Vector2(11, 0).rotated(k * TAU / 6.0), Color("8a6a44"), 1.0)
		_ci.draw_colored_polygon(_wall_rect(fc, left, front, 24, 44), Color("6b4a2b"))
		_ci.draw_circle(fc + Vector2(0, -44), 12.0, Color("6b4a2b"))
		_ci.draw_colored_polygon(_wall_rect(fc + Vector2(0, -50), left, front, 34, 6), wall_l.darkened(0.12))
		for i in 4:
			var q := front.lerp(right, (i + 0.5) / 4.0) + up * 0.6
			_ci.draw_colored_polygon(_wall_rect(q, front, right, 7, 20), Color("6e8fa8"))
	else:
		for i in 4:
			var q := front.lerp(right, (i + 0.5) / 4.0) + up
			_ci.draw_line(q, q + (left - front) * 0.6 + Vector2(0, -10), Color("6b4a2b"), 3.0)
		for i in 10:
			var q := left.lerp(front, posmod(i * 37, 100) / 100.0) + Vector2(0, -posmod(i * 53, 40) - 6)
			_ci.draw_circle(q, 6.0, Color("4f7f2a"))
	# campanile: cella x 2..3, y 3..4 (accanto alla facciata, a destra)
	var tb := a + Vector2(2.1, 3.0)
	var t_top := world(tb, lv)
	var t_right := world(tb + Vector2(0.8, 0), lv)
	var t_front := world(tb + Vector2(0.8, 0.9), lv)
	var t_left := world(tb + Vector2(0, 0.9), lv)
	var th := (4.2 if restored else 1.8) * LEVEL_H
	var tu := Vector2(0, -th)
	_ci.draw_colored_polygon(PackedVector2Array([t_left, t_front, t_front + tu, t_left + tu]), wall_l.darkened(0.02))
	_ci.draw_colored_polygon(PackedVector2Array([t_front, t_right, t_right + tu, t_front + tu]), wall_r.darkened(0.04))
	for k in range(1, 5):
		var f := k / 5.0
		_ci.draw_line(t_left.lerp(t_left + tu, f), t_front.lerp(t_front + tu, f), wall_l.darkened(0.1), 1.2)
	if restored:
		# cella campanaria con le bifore e la campana, cuspide in coppi
		var bell := t_left.lerp(t_front, 0.5) + tu * 0.86
		_ci.draw_colored_polygon(_wall_rect(bell + Vector2(0, 14), t_left, t_front, 26, 30), Color("4a3423"))
		_ci.draw_circle(bell + Vector2(0, -2), 7.0, Color("d9a441"))
		var bell_r := t_front.lerp(t_right, 0.5) + tu * 0.86
		_ci.draw_colored_polygon(_wall_rect(bell_r + Vector2(0, 14), t_front, t_right, 22, 30), Color("3b2a1c"))
		var apex := (t_top + t_front) * 0.5 + tu + Vector2(0, -50)
		_ci.draw_colored_polygon(PackedVector2Array([t_left + tu, t_front + tu, apex]), Color("c0603e"))
		_ci.draw_colored_polygon(PackedVector2Array([t_front + tu, t_right + tu, apex]), Color("a24a2c"))
		_ci.draw_line(apex, apex + Vector2(0, -16), Color("6b5a3a"), 2.0)
		_ci.draw_line(apex + Vector2(-5, -11), apex + Vector2(5, -11), Color("6b5a3a"), 2.0)
	else:
		for k in 5:
			var q := t_left.lerp(t_front, k / 4.0) + tu + Vector2(0, -posmod(k * 37, 14))
			_ci.draw_circle(q, 5.0, Color("4f7f2a"))


## Casa del paese: sprite sul lotto 2x2 e fumo dal comignolo.
func _draw_house(cell: Vector2i, sprite: String) -> void:
	var a := Vector2(cell)
	var front := world(a + Vector2(2, 2), cell_h(cell))
	var t := Sprites.tex(sprite)
	if t == null:
		return
	var w := TILE_W * 2.0 * 1.06
	Sprites.draw(_ci, sprite, front + Vector2(0, 10), w, 0.0, posmod(hash(cell), 2) == 0)
	if posmod(hash(cell), 3) != 0:
		var hgt := t.get_height() * w / t.get_width()
		_smoke(front + Vector2(w * 0.12, -hgt * 0.92), float(posmod(hash(cell), 10)))


func _smoke(p: Vector2, seed_t: float) -> void:
	for i in 5:
		var k := fposmod(_clock * 0.35 + seed_t * 0.13 + i * 0.2, 1.0)
		var q := p + Vector2(sin(k * 5.0 + seed_t) * 6.0 + k * 10.0, -k * 60.0)
		_ci.draw_circle(q, 4.0 + k * 9.0, Color(0.93, 0.92, 0.9, 0.55 * (1.0 - k)))


func _draw_car(p: Vector2, body: Color) -> void:
	var foot := world(p)
	_ci.draw_set_transform(foot, 0.0, Vector2(1.0, 0.45))
	_ci.draw_circle(Vector2(0, 4), 30.0, Color(0.18, 0.12, 0.05, 0.25))
	_ci.draw_set_transform(Vector2.ZERO)
	_ci.draw_rect(Rect2(foot + Vector2(-26, -20), Vector2(52, 14)), body)
	_ci.draw_circle(foot + Vector2(-6, -22), 14.0, body)
	_ci.draw_rect(Rect2(foot + Vector2(-14, -31), Vector2(16, 9)), Color("a9cfe0"))
	_ci.draw_rect(Rect2(foot + Vector2(-26, -10), Vector2(52, 3)), body.darkened(0.3))
	for x in [-16.0, 16.0]:
		_ci.draw_circle(foot + Vector2(x, -4), 6.5, Color("2e2a26"))
		_ci.draw_circle(foot + Vector2(x, -4), 2.5, Color("c8c2b4"))
	_ci.draw_circle(foot + Vector2(25, -15), 3.0, Color("fff3c4"))


func _draw_bike(p: Vector2) -> void:
	var col := Color("2f6d8a")
	for x in [-11.0, 11.0]:
		_ci.draw_arc(p + Vector2(x, -8), 8.0, 0.0, TAU, 18, Color("2e2a26"), 2.0)
	_ci.draw_line(p + Vector2(-11, -8), p + Vector2(0, -8), col, 2.5)
	_ci.draw_line(p + Vector2(0, -8), p + Vector2(-5, -18), col, 2.5)
	_ci.draw_line(p + Vector2(-5, -18), p + Vector2(7, -18), col, 2.5)
	_ci.draw_line(p + Vector2(7, -18), p + Vector2(11, -8), col, 2.5)
	_ci.draw_line(p + Vector2(7, -18), p + Vector2(9, -24), Color("3b2a17"), 2.5)
	_ci.draw_rect(Rect2(p + Vector2(-8, -21), Vector2(7, 3)), Color("3b2a17"))
	_ci.draw_rect(Rect2(p + Vector2(8, -23), Vector2(9, 6)), Color("c8a46a"))


func _draw_fountain() -> void:
	var c := world(FOUNTAIN)
	if Sprites.tex("fontana") != null:
		Sprites.draw(_ci, "fontana", c + Vector2(0, 34), 150.0, 0.0)
		return
	_ci.draw_set_transform(c, 0.0, Vector2(1.0, 0.5))
	_ci.draw_circle(Vector2.ZERO, 52.0, Color("bfae8e"))
	_ci.draw_circle(Vector2.ZERO, 44.0, Color("5aa3c8"))
	_ci.draw_set_transform(Vector2.ZERO)


## Edificio del gioco: rudere o restaurato, sprite o disegno da codice.
var _draw_lights_later: Array = []


## Edificio e, se restaurato, le sue luci e il fumo dal camino.
func _draw_building(id: String) -> void:
	_draw_lights_later.clear()
	_draw_building_body(id)
	if not _draw_lights_later.is_empty():
		_draw_life(id)


func _draw_building_body(id: String) -> void:
	var b: Dictionary = buildings[id]
	var cell: Vector2i = b["cell"]
	var s: Vector2i = b["size"]
	var h: float = b["h"]
	var restored := id == "bacheca" or id == "caldarroste" or GameState.is_restored(id)
	# durante la scena di restauro si vede ancora il rudere sotto la polvere
	if not _event.is_empty() and _event["id"] == id and float(_event["t"]) < REVEAL_AT:
		restored = false
	var a := Vector2(cell)
	var lv := cell_h(cell)
	if restored and GameData.BUILDINGS.has(id):
		_draw_lights_later.append(id)
	var top := world(a, lv)
	var right := world(a + Vector2(s.x, 0), lv)
	var front := world(a + Vector2(s), lv)
	var left := world(a + Vector2(0, s.y), lv)
	# prima i nomi standard (<id>_rudere / <id>_restaurato, vedi docs/asset_prompts.md),
	# poi le coppie ritagliate dai fogli vecchi
	var std := "%s_%s" % [id, "restaurato" if restored else "rudere"]
	if Sprites.tex(std) != null:
		var k := 1.0 if s.x <= 2 else 0.95
		Sprites.draw(_ci, std, front + Vector2(0, 14), TILE_W * float(s.x) * 1.04 * k, 0.0)
		if restored and GameData.BUILDINGS.has(id):
			_draw_lights_later.append(id)
		return
	if PAIRS.has(id):
		var sprite: String = PAIRS[id][1 if restored else 0]
		if sprite != "" and Sprites.tex(sprite) != null:
			Sprites.draw(_ci, sprite, front + Vector2(0, 14), TILE_W * float(s.x) * 1.04, 0.0)
			return
	if id == "campanile":
		_draw_church(cell, lv, restored)
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
		Sprites.draw(_ci, SPRITES[id], front + Vector2(0, 8), TILE_W * float(s.x) * 1.12 * k, 0.0)
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
		_ci.draw_line(hub, tip, Color("8a5a2b"), 3.0)
		var side := Vector2(-sin(ang), cos(ang) * 0.9) * 9.0
		_ci.draw_colored_polygon(PackedVector2Array([hub.lerp(tip, 0.25), tip, tip + side, hub.lerp(tip, 0.25) + side]), Color("f4ead4"))
	_ci.draw_circle(hub, 5.0, Color("6b4a2b"))


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
		_ci.draw_colored_polygon(pts, face[2])
		# pietre e una finestra vuota
		for k in 8:
			var t := rng.randf()
			var p := a.lerp(b, t) + Vector2(0, -rng.randf_range(4, h * 0.3))
			_ci.draw_rect(Rect2(p, Vector2(8, 4)), Color(face[2]).darkened(0.12))
	# edera e macerie
	for k in 10:
		var t := rng.randf()
		var p := left.lerp(front, t) + Vector2(0, -rng.randf_range(4, h * 0.4))
		_ci.draw_circle(p, rng.randf_range(4, 7), Color("4f7f2a"))
	for k in 5:
		var p := front + Vector2(rng.randf_range(-30, 20), rng.randf_range(2, 10))
		_ci.draw_circle(p, rng.randf_range(3, 6), Color("a3927a"))


func _draw_board(c: Vector2) -> void:
	_ci.draw_line(c + Vector2(-16, 0), c + Vector2(-16, -46), Color("6e4626"), 4.0)
	_ci.draw_line(c + Vector2(16, 0), c + Vector2(16, -46), Color("6e4626"), 4.0)
	_ci.draw_rect(Rect2(c + Vector2(-22, -54), Vector2(44, 30)), Color("9a6a3e"))
	_ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-26, -54), c + Vector2(26, -54), c + Vector2(0, -66)]), Color("c0603e"))
	for i in GameState.orders.size():
		var ok := GameState.can_fulfill(i)
		_ci.draw_rect(Rect2(c + Vector2(-18 + i * 13, -50), Vector2(10, 14)), Color("f6eedb") if not ok else Color("e9f2c9"))
		_ci.draw_circle(c + Vector2(-13 + i * 13, -49), 1.8, Color("c0503a"))


func _draw_stand(c: Vector2) -> void:
	_ci.draw_rect(Rect2(c + Vector2(-16, -20), Vector2(32, 18)), Color("8a5a2b"))
	_ci.draw_circle(c + Vector2(0, -24), 10.0, Color("3b2a17"))
	for i in 5:
		_ci.draw_circle(c + Vector2(-6 + i * 3, -27), 2.5, Color("7b4a26"))
	var smoke := fmod(_clock, 2.0) / 2.0
	_ci.draw_circle(c + Vector2(4 + smoke * 6, -34 - smoke * 24), 5 + smoke * 6, Color(0.9, 0.88, 0.85, 0.5 - smoke * 0.5))


func _draw_bocce(top: Vector2, right: Vector2, front: Vector2, left: Vector2) -> void:
	_ci.draw_colored_polygon(PackedVector2Array([top, right, front, left]), Color("d9c49a"))
	_ci.draw_polyline(PackedVector2Array([top, right, front, left, top]), Color("8a5a2b"), 3.0)
	var c := (top + front) * 0.5
	for p in [Vector2(-14, 2), Vector2(10, -4), Vector2(2, 8)]:
		_ci.draw_circle(c + p, 4.0, Color("8e9aa6"))
	_ci.draw_circle(c + Vector2(-2, -2), 2.0, Color("c0503a"))


func _outline_building(id: String) -> void:
	var b: Dictionary = buildings[id]
	var a := Vector2(b["cell"])
	var s := Vector2(b["size"])
	var lv := cell_h(b["cell"])
	var pts := PackedVector2Array([world(a, lv), world(a + Vector2(s.x, 0), lv), world(a + s, lv), world(a + Vector2(0, s.y), lv), world(a, lv)])
	_ci.draw_polyline(pts, Color(1, 1, 1, 0.85), 2.5, true)


func _name_pill(id: String) -> void:
	var r := _building_rect(id)
	var p := Vector2(r.get_center().x, r.position.y - 24.0)
	var text := GameData.building_name(id)
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 20.0
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.27, 0.19, 0.13, 0.88)
	box.set_corner_radius_all(12)
	_ci.draw_style_box(box, Rect2(p - Vector2(w * 0.5, 14), Vector2(w, 26)))
	_ci.draw_string(_font, p + Vector2(-w * 0.5 + 10, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f6eedb"))


# --- Vita del borgo -----------------------------------------------------------

const CAMPER_SPOT := Vector2(26.4, 37.6)
const VILLAGER_COLORS := [Color("c8463a"), Color("3f6ea8"), Color("6f8f3e"), Color("d9a441"), Color("8a5a9a"), Color("e8e2d4")]


## Luci calde alla porta, fumo dal camino se l'edificio produce.
func _draw_life(id: String) -> void:
	var b: Dictionary = buildings[id]
	var a := Vector2(b["cell"])
	var s := Vector2(b["size"])
	var lv := cell_h(b["cell"])
	var front := world(a + s, lv)
	var door := world(a + Vector2(s.x * 0.5, s.y), lv)
	var k := 0.85 + 0.15 * sin(_clock * 2.3 + float(posmod(hash(id), 10)))
	_ci.draw_circle(door + Vector2(-14, -34), 16.0 * k, Color(1.0, 0.82, 0.4, 0.18))
	_ci.draw_circle(door + Vector2(-14, -34), 5.0, Color(1.0, 0.9, 0.55, 0.95))
	_ci.draw_line(door + Vector2(-14, -40), door + Vector2(-14, -46), Color("4a3423"), 2.0)
	if GameData.BUILDINGS[id].has("recipe") or id in ["osteria", "bar"]:
		_smoke(front + Vector2(TILE_W * 0.15, -150.0), float(posmod(hash(id), 10)))


func _has_tourist(type: String) -> bool:
	for t in GameState.tourists:
		if t["type"] == type:
			return true
	return false


## Quanti abitanti e visitatori ci devono essere per strada: crescono con la
## popolazione e con i gruppi di turisti in paese.
func _wanted_walkers() -> Array:
	var want: Array = []
	for i in mini(GameState.population() / 3, 16):
		want.append("villager")
	for t in GameState.tourists:
		for j in mini(int(t["size"]), 3):
			want.append(str(t["type"]))
	return want


func _update_walkers(delta: float) -> void:
	if _streets.is_empty():
		return
	var count := {}
	for k in _wanted_walkers():
		count[k] = int(count.get(k, 0)) + 1
	# toglie chi è di troppo (non quelli della scena di restauro), aggiunge chi manca
	for i in range(_walkers.size() - 1, -1, -1):
		var kind: String = _walkers[i]["kind"]
		if _walkers[i].get("event", false):
			continue
		if int(count.get(kind, 0)) > 0:
			count[kind] = int(count[kind]) - 1
		else:
			_walkers.remove_at(i)
	for kind in count:
		for j in int(count[kind]):
			var start: Vector2i = _streets[randi() % _streets.size()]
			_walkers.append(_new_walker(kind, Vector2(start) + Vector2(0.5, 0.5)))
	for w in _walkers:
		if float(w["wait"]) > 0.0:
			w["wait"] = float(w["wait"]) - delta
			continue
		if (w["route"] as Array).is_empty():
			if w.get("event", false) and _event.is_empty():
				w["event"] = false
			var dest: Vector2i = _streets[randi() % _streets.size()]
			w["route"] = route(w["p"], Vector2(dest) + Vector2(0.5, 0.5))
			w["wait"] = randf_range(0.5, 4.0)
			continue
		var next: Vector2 = w["route"][0]
		var d: Vector2 = next - w["p"]
		var step: float = float(w["speed"]) * delta
		if d.length() <= step:
			w["p"] = next
			(w["route"] as Array).pop_front()
		else:
			w["p"] = (w["p"] as Vector2) + d.normalized() * step
			w["flip"] = (world(next).x - world(w["p"]).x) < 0.0


func _new_walker(kind: String, p: Vector2) -> Dictionary:
	var speed := 1.6
	if kind == "ciclisti":
		speed = 3.4
	elif kind == "villager":
		speed = 1.2
	return {"kind": kind, "p": p, "route": [], "wait": randf_range(0.0, 3.0), "speed": speed * randf_range(0.85, 1.15),
		"flip": false, "color": VILLAGER_COLORS[randi() % VILLAGER_COLORS.size()], "old": randf() < 0.35}


## Figurine (finché non ci sono gli sprite): abitanti, turisti con la macchina
## fotografica, ciclisti in bici, camperisti con lo zaino, stranieri con la cartina.
func _draw_walker(w: Dictionary) -> void:
	var p := world(w["p"])
	var moving: bool = not (w["route"] as Array).is_empty() and float(w["wait"]) <= 0.0
	var bob := absf(sin(_clock * 9.0 + p.x * 0.05)) * -2.0 if moving else 0.0
	var dir := -1.0 if w["flip"] else 1.0
	var kind: String = w["kind"]
	var shirt: Color = w["color"]
	_ci.draw_set_transform(p + Vector2(0, 1), 0.0, Vector2(1.0, 0.45))
	_ci.draw_circle(Vector2.ZERO, 9.0, Color(0.18, 0.12, 0.05, 0.25))
	_ci.draw_set_transform(Vector2.ZERO)
	if kind == "ciclisti":
		for x in [-9.0, 9.0]:
			_ci.draw_arc(p + Vector2(x, -7), 7.0, 0.0, TAU, 14, Color("2e2a26"), 2.0)
		_ci.draw_line(p + Vector2(-9, -7), p + Vector2(4, -16), Color("d0643c"), 2.5)
		_ci.draw_line(p + Vector2(9, -7), p + Vector2(4, -16), Color("d0643c"), 2.5)
		_ci.draw_rect(Rect2(p + Vector2(-3, -30 + bob), Vector2(8, 12)), Color("f2c75c"))
		_ci.draw_circle(p + Vector2(1, -34 + bob), 4.5, Color("f0c9a0"))
		_ci.draw_arc(p + Vector2(1, -35 + bob), 5.0, PI, TAU, 8, Color("d0643c"), 3.0)
		return
	match kind:
		"turisti":
			shirt = Color("5aa3c8")
		"stranieri":
			shirt = Color("f2f2ea")
		"camperisti":
			shirt = Color("7c9a3c")
	var step := sin(_clock * 9.0 + p.x * 0.05) * 2.0 if moving else 0.0
	_ci.draw_line(p + Vector2(-2, 0), p + Vector2(-2 + step, -9), Color("3b3a44"), 3.0)
	_ci.draw_line(p + Vector2(2, 0), p + Vector2(2 - step, -9), Color("3b3a44"), 3.0)
	_ci.draw_rect(Rect2(p + Vector2(-5, -21 + bob), Vector2(10, 13)), shirt)
	var head := p + Vector2(0, -25 + bob)
	_ci.draw_circle(head, 4.5, Color("f0c9a0"))
	match kind:
		"villager":
			if w["old"]:
				_ci.draw_circle(head + Vector2(0, -2), 4.5, Color("dcdcd4"))
				_ci.draw_line(p + Vector2(5 * dir, -14), p + Vector2(7 * dir, 0), Color("6b4a2b"), 1.5)
			else:
				_ci.draw_arc(head + Vector2(0, -1), 4.8, PI, TAU, 8, Color("4a3423"), 3.0)
		"turisti":
			_ci.draw_rect(Rect2(head + Vector2(-7, -5), Vector2(14, 2)), Color("e8c870"))
			_ci.draw_rect(Rect2(head + Vector2(-4, -8), Vector2(8, 4)), Color("e8c870"))
			_ci.draw_rect(Rect2(p + Vector2(2 * dir, -18 + bob), Vector2(5, 4)), Color("2e2a26"))
		"stranieri":
			_ci.draw_rect(Rect2(p + Vector2(4 * dir - 4, -20 + bob), Vector2(10, 7)), Color("f6eedb"))
			_ci.draw_line(p + Vector2(4 * dir - 1, -20 + bob), p + Vector2(4 * dir - 1, -13 + bob), Color("5aa3c8"), 1.0)
			_ci.draw_arc(head + Vector2(0, -1), 4.8, PI, TAU, 8, Color("e8d38a"), 3.0)
		"camperisti":
			_ci.draw_rect(Rect2(p + Vector2(-7 * dir - 3, -21 + bob), Vector2(5, 11)), Color("c0603e"))


func _draw_camper(p: Vector2) -> void:
	_ci.draw_set_transform(p + Vector2(0, 4), 0.0, Vector2(1.0, 0.45))
	_ci.draw_circle(Vector2.ZERO, 44.0, Color(0.18, 0.12, 0.05, 0.25))
	_ci.draw_set_transform(Vector2.ZERO)
	_ci.draw_rect(Rect2(p + Vector2(-40, -44), Vector2(80, 36)), Color("f2efe6"))
	_ci.draw_rect(Rect2(p + Vector2(-40, -24), Vector2(80, 5)), Color("5aa3c8"))
	_ci.draw_rect(Rect2(p + Vector2(22, -40), Vector2(16, 12)), Color("a9cfe0"))
	_ci.draw_rect(Rect2(p + Vector2(-30, -40), Vector2(20, 10)), Color("a9cfe0"))
	_ci.draw_rect(Rect2(p + Vector2(-36, -54), Vector2(46, 10)), Color("e6e1d4"))
	for x in [-24.0, 24.0]:
		_ci.draw_circle(p + Vector2(x, -6), 7.5, Color("2e2a26"))
		_ci.draw_circle(p + Vector2(x, -6), 3.0, Color("c8c2b4"))
	# tendalino
	_ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-40, -44), p + Vector2(-70, -30), p + Vector2(-70, -26), p + Vector2(-40, -38)]), Color("e27a4f"))
	_ci.draw_line(p + Vector2(-68, -28), p + Vector2(-68, 0), Color("8e9aa6"), 1.5)


# --- Scena del restauro -------------------------------------------------------

## Un edificio è stato restaurato: la telecamera ci va, la polvere lo copre,
## torna come nuovo, esce l'abitante, si accendono le luci, arrivano visitatori.
func _on_building_restored(id: String) -> void:
	if not buildings.has(id):
		return
	_event = {"id": id, "t": 0.0}
	var b: Dictionary = buildings[id]
	var door := Vector2(door_cell(id)) + Vector2(0.5, 0.5)
	camera.center_on(world(Vector2(b["cell"]) + Vector2(b["size"]) * 0.5))
	var res := _new_walker("villager", door)
	res["event"] = true
	res["wait"] = REVEAL_AT + 0.6
	_walkers.append(res)
	for i in 2:
		var v := _new_walker("turisti" if i == 0 else "stranieri", Vector2(BorgoLayout.ENTRY) + Vector2(0.5, 0.5))
		v["event"] = true
		v["wait"] = REVEAL_AT + 0.4 * i
		v["route"] = route(v["p"], door)
		_walkers.append(v)


func _draw_event_effects() -> void:
	if _event.is_empty():
		return
	var id: String = _event["id"]
	var t: float = _event["t"]
	var b: Dictionary = buildings[id]
	var a := Vector2(b["cell"])
	var s := Vector2(b["size"])
	var c := world(a + s * 0.5, cell_h(b["cell"]))
	# polvere e scintille mentre si ripulisce
	if t < REVEAL_AT + 0.6:
		var fade := clampf((REVEAL_AT + 0.6 - t) / 0.6, 0.0, 1.0)
		for i in 14:
			var ang := i * TAU / 14.0 + t * 1.5
			var r := 40.0 + 30.0 * sin(t * 3.0 + i)
			var q := c + Vector2(cos(ang) * r * 1.5, sin(ang) * r * 0.7 - 50.0 - t * 10.0)
			_ci.draw_circle(q, 22.0 + 8.0 * sin(t * 4.0 + i), Color(0.9, 0.84, 0.72, 0.75 * fade))
		for i in 8:
			var q2 := c + Vector2(sin(t * 5.0 + i * 2.1) * 80.0, -40.0 - fposmod(t * 90.0 + i * 37.0, 160.0))
			var k := 6.0 * fade
			_ci.draw_line(q2 + Vector2(-k, 0), q2 + Vector2(k, 0), Color(1, 0.95, 0.7, fade), 2.0)
			_ci.draw_line(q2 + Vector2(0, -k), q2 + Vector2(0, k), Color(1, 0.95, 0.7, fade), 2.0)
	# "È tornato ...!" sopra l'edificio
	if t > REVEAL_AT:
		var k2 := clampf((t - REVEAL_AT) / 0.3, 0.0, 1.0) * clampf((EVENT_TIME - t) / 0.6, 0.0, 1.0)
		var text := tr("MSG_RETURNS") % GameData.resident_name(id)
		var size := 26
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var p := c + Vector2(-w * 0.5, -150.0 - 20.0 * k2)
		_ci.draw_string_outline(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 10, Color(0.45, 0.25, 0.1, k2))
		_ci.draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 0.96, 0.85, k2))
