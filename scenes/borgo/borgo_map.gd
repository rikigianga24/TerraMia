class_name BorgoMap
extends Node2D
## Il borgo: un paese su una collina, a terrazze.
##
## Quattro livelli (3 in cima, 0 all'ingresso) uniti da una via principale in
## salita (colonne MAIN_X); su ogni livello una via trasversale (STREET_ROWS)
## con gli edifici affacciati. A metà, al livello 2, la piazza con fontana e
## bacheca. Tra un livello e l'altro muri di pietra.
## Edifici del gioco (BUILDINGS) in rudere o restaurati; case del paese
## (HOUSES) col fumo dal comignolo; auto d'epoca parcheggiate, biciclette,
## cipressi. Toccando un edificio il contadino ci va a piedi per le vie;
## all'arrivo la mappa emette building_reached.
##
## Coordinate: tutto in coordinate di cella (Vector2) più un'altezza in
## livelli; world() le porta sullo schermo.

signal building_reached(id: String)

const TILE_W := Iso.TILE_W
const TILE_H := Iso.TILE_H
const SIZE := Vector2i(20, 24)
const LEVEL_H := 40.0               ## pixel di dislivello tra due terrazze
const LEVEL_ROWS := [6, 12, 18]     ## righe dove inizia il livello più basso
const STREET_ROWS := [4, 10, 16, 22]  ## via trasversale di ogni livello (3, 2, 1, 0)
const MAIN_X := Vector2(9, 11)      ## via principale: colonne 9 e 10
const PIAZZA := Rect2i(6, 6, 8, 4)
const FOUNTAIN := Vector2(12.0, 8.0)
const ENTRY := Vector2(10.0, 23.6)  ## da dove arriva il contadino
const WALK_SPEED := 3.2             ## celle al secondo
const DRAG_THRESHOLD := 8.0

const TEX_GRASS := preload("res://assets/graphics/tiles/grass.png")
const TEX_GRASS_FLOWERS := preload("res://assets/graphics/tiles/grass_flowers.png")
const TEX_COBBLES := preload("res://assets/graphics/tiles/cobbles.png")

## Edifici del gioco: cella in alto a sinistra dell'ingombro, ingombro,
## altezza dei muri (per il disegno da codice, se manca lo sprite).
const BUILDINGS := {
	"mulino":          {"cell": Vector2i(0, 2),   "size": Vector2i(2, 2), "h": 70},
	"ufficio_postale": {"cell": Vector2i(4, 2),   "size": Vector2i(2, 2), "h": 56},
	"campanile":       {"cell": Vector2i(11, 2),  "size": Vector2i(2, 2), "h": 150},
	"bocce":           {"cell": Vector2i(15, 2),  "size": Vector2i(2, 2), "h": 0},
	"forno":           {"cell": Vector2i(0, 8),   "size": Vector2i(2, 2), "h": 52},
	"bar":             {"cell": Vector2i(2, 8),   "size": Vector2i(2, 2), "h": 50},
	"osteria":         {"cell": Vector2i(4, 8),   "size": Vector2i(2, 2), "h": 56},
	"pasticceria":     {"cell": Vector2i(14, 8),  "size": Vector2i(2, 2), "h": 50},
	"frantoio":        {"cell": Vector2i(0, 14),  "size": Vector2i(2, 2), "h": 48},
	"caseificio":      {"cell": Vector2i(2, 14),  "size": Vector2i(2, 2), "h": 46},
	"cantina":         {"cell": Vector2i(11, 14), "size": Vector2i(2, 2), "h": 46},
	"conserve":        {"cell": Vector2i(15, 14), "size": Vector2i(2, 2), "h": 46},
	"gelateria":       {"cell": Vector2i(2, 20),  "size": Vector2i(2, 2), "h": 48},
	"pastificio":      {"cell": Vector2i(6, 20),  "size": Vector2i(2, 2), "h": 52},
	"caldarroste":     {"cell": Vector2i(8, 21),  "size": Vector2i(1, 1), "h": 26},
	"bacheca":         {"cell": Vector2i(7, 7),   "size": Vector2i(1, 1), "h": 40},
}
## Sprite dell'edificio restaurato, se non c'è la coppia rudere/restaurato.
const SPRITES := {
	"bar": "casetta", "osteria": "casale", "campanile": "torre",
	"pastificio": "casa_pergola", "pasticceria": "villa",
}
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
const SPRITE_SCALE := {"campanile": 0.62}
## Case del paese (solo decorazione): cella e sprite.
const HOUSES := [
	[Vector2i(2, 2), "casetta"], [Vector2i(6, 2), "casa_piccola"], [Vector2i(13, 2), "casa_grande"],
	[Vector2i(17, 2), "casa_pergola"], [Vector2i(16, 8), "casa_piccola"], [Vector2i(18, 8), "casetta"],
	[Vector2i(4, 14), "casa_grande"], [Vector2i(6, 14), "casetta"], [Vector2i(13, 14), "casa_piccola"],
	[Vector2i(17, 14), "casa_pergola"], [Vector2i(0, 20), "casa_piccola"], [Vector2i(4, 20), "casetta"],
	[Vector2i(11, 20), "casa_grande"], [Vector2i(13, 20), "casetta"], [Vector2i(15, 20), "casa_pergola"],
	[Vector2i(17, 20), "casa_piccola"],
]
## Auto d'epoca parcheggiate (posizione, colore, sulla rampa?) e biciclette.
const CARS := [
	[Vector2(10.75, 5.5), "d9412b"], [Vector2(10.75, 11.5), "e6d3a3"], [Vector2(10.75, 13.6), "5aa3c8"],
	[Vector2(10.75, 17.5), "7c9a3c"], [Vector2(10.75, 19.8), "e6d3a3"], [Vector2(15.5, 22.6), "c0603e"],
	[Vector2(4.2, 16.6), "5aa3c8"], [Vector2(17.0, 4.6), "e6d3a3"],
]
const BIKES := [Vector2(6.3, 10.3), Vector2(13.6, 16.3), Vector2(1.6, 22.3), Vector2(8.6, 4.3), Vector2(18.6, 10.4)]
const TREES := [
	[Vector2(8.4, 1.2), "cipresso"], [Vector2(19.4, 1.4), "cipresso"], [Vector2(1.6, 5.5), "cipresso"],
	[Vector2(5.6, 5.6), "ulivo_albero_c"], [Vector2(14.0, 5.5), "cipresso"], [Vector2(18.0, 5.6), "cipresso"],
	[Vector2(0.8, 6.8), "ulivo_albero_c"], [Vector2(15.8, 6.6), "cipresso"], [Vector2(0.6, 12.6), "cipresso"],
	[Vector2(7.6, 12.8), "ulivo_albero_c"], [Vector2(12.6, 12.5), "cipresso"], [Vector2(18.8, 12.8), "cipresso"],
	[Vector2(3.4, 18.6), "ulivo_albero_c"], [Vector2(14.5, 18.5), "cipresso"], [Vector2(19.3, 19.0), "cipresso"],
	[Vector2(7.5, 17.6), "cipresso"],
]

var camera: WorldCamera
var _farmer := ENTRY               ## posizione del contadino (celle)
var _route: Array = []             ## tappe ancora da fare
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
	camera = WorldCamera.new()
	add_child(camera)
	var top := world(Vector2(0, 0))
	var left := world(Vector2(0, SIZE.y))
	var right := world(Vector2(SIZE.x, 0))
	var bottom := world(Vector2(SIZE), -0.6)
	camera.bounds = Rect2(left.x - 80, top.y - 220, right.x - left.x + 160, bottom.y - top.y + 300)
	camera.zoom = Vector2(0.7, 0.7)
	camera.center_on(world(Vector2(10, 14)))


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


## Il contadino arriva dalla fattoria: entra dal fondo della via principale.
func arrive() -> void:
	_farmer = ENTRY
	_route = []
	_target_building = ""
	camera.center_on(world(Vector2(10, 18)))


# --- Rilievo e coordinate ---------------------------------------------------

## Livello della terrazza di una riga (3 in cima, 0 all'ingresso).
static func level_of_row(y: float) -> int:
	var lv := 3
	for b in LEVEL_ROWS:
		if y >= b:
			lv -= 1
	return lv


static func is_main_street_x(x: float) -> bool:
	return x >= MAIN_X.x and x < MAIN_X.y


## Altezza della via principale: piana sulle terrazze, rampa di una riga
## prima di ogni dislivello.
static func ramp(y: float) -> float:
	var h := 3.0
	for b in LEVEL_ROWS:
		h -= clampf(y - (b - 1), 0.0, 1.0)
	return h


## Altezza (in livelli) di un punto della mappa.
static func elev(p: Vector2) -> float:
	return ramp(p.y) if is_main_street_x(p.x) else float(level_of_row(floorf(p.y)))


func cell_to_local(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * TILE_W * 0.5, (cell.x + cell.y) * TILE_H * 0.5)


## Punto della mappa sullo schermo, sollevato della sua altezza.
func world(p: Vector2, h := INF) -> Vector2:
	var z := elev(p) if h == INF else h
	return cell_to_local(p) - Vector2(0, z * LEVEL_H)


## Altezze dei quattro angoli di una cella: [alto, destra, basso, sinistra].
func corner_heights(cell: Vector2i) -> Array:
	if is_main_street_x(cell.x):
		return [ramp(cell.y), ramp(cell.y), ramp(cell.y + 1), ramp(cell.y + 1)]
	var lv := float(level_of_row(cell.y))
	return [lv, lv, lv, lv]


func cell_poly(cell: Vector2i) -> PackedVector2Array:
	var h := corner_heights(cell)
	var c := Vector2(cell)
	return PackedVector2Array([world(c, h[0]), world(c + Vector2(1, 0), h[1]), world(c + Vector2(1, 1), h[2]), world(c + Vector2(0, 1), h[3])])


func is_street(cell: Vector2i) -> bool:
	return is_main_street_x(cell.x) or cell.y in STREET_ROWS or PIAZZA.has_point(cell)


func in_map(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE.x and cell.y < SIZE.y


## Cella sotto un punto dello schermo, tenendo conto delle terrazze: si
## provano le celle dalla più vicina allo spettatore.
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
	for id in BUILDINGS:
		var b: Dictionary = BUILDINGS[id]
		if Rect2i(b["cell"], b["size"]).has_point(cell):
			return id
	return ""


## Edificio sotto il punto: prima il disegno (alto più dell'ingombro), poi la cella.
func pick_building(local: Vector2) -> String:
	var best := ""
	var best_depth := -INF
	for id in BUILDINGS:
		var r := _building_rect(id)
		var b: Dictionary = BUILDINGS[id]
		var depth := float(b["cell"].x + b["cell"].y)
		if r.has_point(local) and depth > best_depth:
			best = id
			best_depth = depth
	return best if best != "" else building_at(pick_cell(local))


## Riquadro dello schermo occupato dall'edificio (per toccarlo e per il nome).
func _building_rect(id: String) -> Rect2:
	var b: Dictionary = BUILDINGS[id]
	var s: Vector2i = b["size"]
	var a := Vector2(b["cell"])
	var lv := float(level_of_row(a.y))
	var left := world(a + Vector2(0, s.y), lv)
	var right := world(a + Vector2(s.x, 0), lv)
	var front := world(a + Vector2(s), lv)
	var h := maxf(float(b["h"]), 30.0) + 40.0
	return Rect2(Vector2(left.x, right.y - h), Vector2(right.x - left.x, front.y - right.y + h))


## Davanti alla porta: sulla via, sotto lo spigolo anteriore dell'edificio.
func door_point(id: String) -> Vector2:
	var b: Dictionary = BUILDINGS[id]
	var c: Vector2i = b["cell"]
	var s: Vector2i = b["size"]
	return Vector2(c.x + s.x * 0.5, c.y + s.y + 0.5)


## Percorso a piedi: alla via trasversale del proprio livello, lungo la via
## principale fino al livello giusto, poi lungo la via fino alla meta.
func route(from: Vector2, to: Vector2) -> Array:
	var r0: float = STREET_ROWS[3 - level_of_row(floorf(from.y))] + 0.5
	var r1: float = STREET_ROWS[3 - level_of_row(floorf(to.y))] + 0.5
	var main_x := (MAIN_X.x + MAIN_X.y) * 0.5
	var pts: Array = []
	pts.append(Vector2(from.x, r0))
	if absf(r0 - r1) > 0.01:
		pts.append(Vector2(main_x, r0))
		pts.append(Vector2(main_x, r1))
	pts.append(Vector2(to.x, r1))
	pts.append(to)
	var out: Array = []
	var last := from
	for p in pts:
		if p.distance_to(last) > 0.05:
			out.append(p)
			last = p
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
	if in_map(cell) and is_street(cell):
		_route = route(_farmer, Vector2(cell) + Vector2(0.5, 0.5))
		_target_building = ""


# --- Disegno ----------------------------------------------------------------

func _draw() -> void:
	# terreno e muri, dal fondo verso lo spettatore
	for depth in SIZE.x + SIZE.y - 1:
		for x in SIZE.x:
			var y := depth - x
			if y >= 0 and y < SIZE.y:
				_draw_cell(Vector2i(x, y))
	var hid := _hover_building
	if hid != "":
		_outline_building(hid)

	# oggetti in ordine di profondità
	var items: Array = []
	for id in BUILDINGS:
		var b: Dictionary = BUILDINGS[id]
		var front: Vector2i = b["cell"] + b["size"]
		items.append({"d": front.x + front.y - 0.5, "kind": "building", "id": id})
	for h in HOUSES:
		items.append({"d": h[0].x + h[0].y + 3.5, "kind": "house", "cell": h[0], "sprite": h[1]})
	for c in CARS:
		items.append({"d": c[0].x + c[0].y, "kind": "car", "p": c[0], "color": c[1]})
	for bk in BIKES:
		items.append({"d": bk.x + bk.y, "kind": "bike", "p": bk})
	for t in TREES:
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
				var w := 40.0 if it["sprite"] == "cipresso" else 86.0
				Sprites.draw(self, it["sprite"], world(it["p"]), w, 0.05)
			"fountain":
				_draw_fountain()
			"farmer":
				FarmerDrawer.draw(self, world(_farmer), _clock, not _route.is_empty(), "", _farmer_flip)
	if hid != "":
		_name_pill(hid)


func _draw_cell(cell: Vector2i) -> void:
	var poly := cell_poly(cell)
	var tex: Texture2D = TEX_COBBLES
	if not is_street(cell):
		tex = TEX_GRASS_FLOWERS if posmod(hash(cell), 6) == 0 else TEX_GRASS
	var uv := PackedVector2Array([Vector2(0.5, 0), Vector2(1, 0.5), Vector2(0.5, 1), Vector2(0, 0.5)])
	draw_polygon(poly, PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]), uv, tex)
	var h := corner_heights(cell)
	var c := Vector2(cell)
	# muro sul lato davanti-sinistra (verso la cella y+1)
	var below := Vector2i(cell.x, cell.y + 1)
	var nb: Array = corner_heights(below) if in_map(below) else [-0.6, -0.6, -0.6, -0.6]
	_wall(c + Vector2(0, 1), c + Vector2(1, 1), h[3], h[2], nb[0], nb[1], Color("c9b48f"))
	# muro sul lato davanti-destra (verso la cella x+1)
	var right := Vector2i(cell.x + 1, cell.y)
	var nr: Array = corner_heights(right) if in_map(right) else [-0.6, -0.6, -0.6, -0.6]
	_wall(c + Vector2(1, 0), c + Vector2(1, 1), h[1], h[2], nr[0], nr[3], Color("a8946f"))


## Muro di pietra tra lo spigolo alto (ha, hb) e quello basso (la, lb).
func _wall(a: Vector2, b: Vector2, ha: float, hb: float, la: float, lb: float, color: Color) -> void:
	if ha <= la + 0.01 and hb <= lb + 0.01:
		return
	var p := PackedVector2Array([world(a, ha), world(b, hb), world(b, minf(lb, hb)), world(a, minf(la, ha))])
	draw_colored_polygon(p, color)
	# corsi di pietre
	var top_a := world(a, ha)
	var top_b := world(b, hb)
	var depth_px := maxf(ha - la, hb - lb) * LEVEL_H
	var y := 9.0
	while y < depth_px - 2.0:
		draw_line(top_a + Vector2(0, y), top_b + Vector2(0, y), color.darkened(0.18), 1.2)
		y += 9.0
	draw_line(top_a, top_b, color.lightened(0.2), 2.0)


## Casa del paese: sprite sull'ingombro 2x2 e fumo dal comignolo.
func _draw_house(cell: Vector2i, sprite: String) -> void:
	var a := Vector2(cell)
	var lv := float(level_of_row(a.y))
	var front := world(a + Vector2(2, 2), lv)
	var t := Sprites.tex(sprite)
	if t == null:
		return
	var w := TILE_W * 2.0 * 1.05
	Sprites.draw(self, sprite, front + Vector2(0, 10), w, 0.0, posmod(hash(cell), 2) == 0)
	var hgt := t.get_height() * w / t.get_width()
	_smoke(front + Vector2(w * 0.12, -hgt * 0.92), float(posmod(hash(cell), 10)))


func _smoke(p: Vector2, seed_t: float) -> void:
	for i in 5:
		var k := fposmod(_clock * 0.35 + seed_t * 0.13 + i * 0.2, 1.0)
		var q := p + Vector2(sin(k * 5.0 + seed_t) * 6.0 + k * 10.0, -k * 60.0)
		draw_circle(q, 4.0 + k * 9.0, Color(0.93, 0.92, 0.9, 0.55 * (1.0 - k)))


func _draw_car(p: Vector2, body: Color) -> void:
	var foot := world(p)
	var tilt := 0.0
	if is_main_street_x(p.x):
		tilt = (world(p + Vector2(0, 0.5)).y - world(p - Vector2(0, 0.5)).y - TILE_H * 0.5) * 0.004
	draw_set_transform(foot, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2(0, 4), 30.0, Color(0.18, 0.12, 0.05, 0.25))
	draw_set_transform(foot, tilt, Vector2.ONE)
	draw_rect(Rect2(Vector2(-26, -20), Vector2(52, 14)), body)
	draw_circle(Vector2(-6, -22), 14.0, body)
	draw_rect(Rect2(Vector2(-14, -31), Vector2(16, 9)), Color("a9cfe0"))
	draw_rect(Rect2(Vector2(-26, -10), Vector2(52, 3)), body.darkened(0.3))
	for x in [-16.0, 16.0]:
		draw_circle(Vector2(x, -4), 6.5, Color("2e2a26"))
		draw_circle(Vector2(x, -4), 2.5, Color("c8c2b4"))
	draw_circle(Vector2(25, -15), 3.0, Color("fff3c4"))
	draw_set_transform(Vector2.ZERO)


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
	var b: Dictionary = BUILDINGS[id]
	var cell: Vector2i = b["cell"]
	var s: Vector2i = b["size"]
	var h: float = b["h"]
	var restored := id == "bacheca" or id == "caldarroste" or GameState.is_restored(id)
	var a := Vector2(cell)
	var lv := float(level_of_row(a.y))
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
		Sprites.draw(self, SPRITES[id], front + Vector2(0, 8), TILE_W * float(s.x) * 1.12 * SPRITE_SCALE.get(id, 1.0), 0.0)
		if id in ["osteria", "bar", "forno", "pastificio"]:
			_smoke(front + Vector2(TILE_W * 0.25, -h - 90.0), float(posmod(hash(id), 10)))
		return
	# senza sprite: rudere da codice anche da restaurato (in attesa del disegno)
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
	var b: Dictionary = BUILDINGS[id]
	var a := Vector2(b["cell"])
	var s := Vector2(b["size"])
	var lv := float(level_of_row(a.y))
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
