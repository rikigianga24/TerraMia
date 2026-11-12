class_name Farm
extends Node2D
## La fattoria in 2.5D: una mappa isometrica di 18×18 quadranti (3×3 lotti
## da 6×6), a filo del prato. Si parte dal lotto in fondo; gli altri si
## comprano con monete e oggetti antichi.
##
## Attorno: il fiume a sinistra, il bosco a destra, una strada di pietrisco
## davanti dove ogni tanto passa un carretto o un'auto d'epoca.
## I blocchi di terra sono PNG dipinti (tools/paint_tiles.py); piante,
## contadino, fiume, alberi e veicoli sono disegnati da codice.
##
## Strumenti (barra in basso):
##   mano       raccoglie le piante pronte; trascinando sposta la vista
##   zappa      mette in coda la lavorazione di un quadrante (15 s l'uno)
##   semi       il contadino semina subito (resta un sacchetto di semi)
##   acqua      fa partire la crescita (1 goccia)
##   concime    raddoppia il prossimo raccolto
## Le piante pronte si raccolgono con qualsiasi strumento; il forziere si
## apre toccandolo. Tenendo premuto e trascinando si lavorano più quadranti.

signal tool_changed(tool: String)
signal sector_tapped(sector: Vector2i)

const TILE_W := 112.0
const TILE_H := 56.0

const TEX_GRASS := preload("res://assets/graphics/tiles/grass.png")
const TEX_GRASS_FLOWERS := preload("res://assets/graphics/tiles/grass_flowers.png")
const TEX_SOIL := preload("res://assets/graphics/tiles/soil.png")
const TEX_SOIL_WET := preload("res://assets/graphics/tiles/soil_wet.png")
const TEX_SEEDS := preload("res://assets/graphics/icons/seeds.png")

const COLOR_HOVER := Color(1, 1, 1, 0.9)
const COLOR_QUEUED := Color(1, 0.97, 0.85, 0.95)
const COLOR_SHADOW := Color(0.18, 0.12, 0.05, 0.28)
const COLOR_LEAF := Color("6a9e35")
const COLOR_LEAF_DARK := Color("4f7f2a")
const COLOR_LEAF_LIGHT := Color("93c25a")
const COLOR_WOOD := Color("9a6a3e")
const COLOR_WOOD_DARK := Color("6e4626")
const COLOR_LOCKED := Color(0.82, 0.86, 0.74)
const COLOR_WATER := Color("5aa3c8")
const COLOR_WATER_DEEP := Color("3f86ad")
const COLOR_BANK := Color("b89a62")
const COLOR_ROAD := Color("cbb48a")
const COLOR_ROAD_DARK := Color("ad9468")

## Forma della pianta (solo grafica): grano, foglie, radici, frutti, grossi, fiori.
const SHAPES := {
	"grano": "grain",
	"lattuga": "leafy", "rucola": "leafy", "basilico": "leafy", "origano": "leafy",
	"carota": "root", "cipolla": "root", "patata": "root", "aglio": "root", "finocchio": "root",
	"pomodoro": "fruit", "fragola": "fruit", "zucchina": "fruit", "melanzana": "fruit",
	"peperoncino": "fruit", "fagioli": "fruit", "carciofo": "fruit",
	"zucca": "big", "anguria": "big",
	"zafferano": "flower",
}

## Le piante illustrate occupano un po' meno del quadrante: resta un filo di terra.
const PLANT_SCALE := 0.88
const FARMER_SPEED := 220.0
const SOW_TIME := 0.7
const POPUP_TIME := 1.3
const DRAG_THRESHOLD := 8.0
## Fasce attorno alla mappa, in quadranti: fiume (x < 0), bosco (y < 0),
## strada (x > lato), prato aperto (y > lato).
const RIVER_FROM := -3.2
const RIVER_TO := -0.5
const ROAD_FROM := 0.6
const ROAD_TO := 1.8

var tool: String = "hand":
	set(value):
		tool = value
		tool_changed.emit(value)
var selected_crop: String = "grano"
var camera: WorldCamera

var _hover := Vector2i(-1, -1)
var _press := false
var _press_pos := Vector2.ZERO
var _panning := false
var _painting := false
var _stroke: Dictionary = {}       ## celle già toccate nel trascinamento
var _popups: Array = []            ## [{"pos", "text", "color", "t"}]
var _farmer_pos := Vector2.ZERO
var _farmer_flip := false
var _sow_t := -1.0                 ## animazione di semina in corso (0..1), -1 se no
var _font: Font
var _font_bold: Font
var _clock := 0.0
var _trees: Array = []             ## bosco e alberi sparsi, posizioni fisse
var _vehicles: Array = []          ## veicoli sulla strada
var _next_vehicle := 4.0
var _overlay_layer: CanvasLayer
var _plant_sprites: Dictionary = {}  ## coltura -> [ {tex, anchor, scale} ×3 stadi ]


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_font_bold = load("res://assets/fonts/Fredoka-SemiBold.ttf")
	GameState.changed.connect(queue_redraw)
	GameState.harvested.connect(_on_harvested)
	GameState.planted.connect(_on_planted)
	GameState.chest_opened.connect(_on_chest_opened)
	_build_trees()
	_load_plant_sprites()
	_farmer_pos = cell_center(Vector2i(2, 4)) + Vector2(-20, 10)

	camera = WorldCamera.new()
	add_child(camera)
	var w := GameData.world_size()
	var top := cell_to_local(Vector2i(0, 0))
	var left := cell_to_local(Vector2i(int(RIVER_FROM), w.y))
	var right := cell_to_local(Vector2i(w.x + int(ROAD_TO) + 1, 0))
	var bottom := cell_to_local(w)
	camera.bounds = Rect2(left.x - 40, top.y - 220, right.x - left.x + 80, bottom.y - top.y + 300)
	camera.zoom = Vector2(1.2, 1.2)
	camera.center_on(cell_center(Vector2i(3, 3)))

	# Etichette, fumetti e scritte del raccolto vanno sopra il filtro (livello
	# 7), così restano nitidi; il livello segue la telecamera.
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 7
	_overlay_layer.follow_viewport_enabled = true
	add_child(_overlay_layer)
	var overlay := FarmOverlay.new()
	overlay.farm = self
	_overlay_layer.add_child(overlay)


func _process(delta: float) -> void:
	_clock += delta
	_overlay_layer.visible = visible
	GameState.update_plowing()
	_update_farmer(delta)
	_update_vehicles(delta)
	for p in _popups:
		p["t"] += delta
	_popups = _popups.filter(func(p: Dictionary) -> bool: return p["t"] < POPUP_TIME)
	# I timer sono reali: ridisegna per mostrare la crescita.
	queue_redraw()


# --- Coordinate isometriche -------------------------------------------------

## Vertice superiore del rombo della cella (accetta anche coordinate frazionarie).
func cell_to_local(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * TILE_W * 0.5, (cell.x + cell.y) * TILE_H * 0.5)


func cell_center(cell: Vector2i) -> Vector2:
	return cell_to_local(cell) + Vector2(0, TILE_H * 0.5)


func local_to_cell(p: Vector2) -> Vector2i:
	var a := p.x / (TILE_W * 0.5)
	var b := p.y / (TILE_H * 0.5)
	return Vector2i(floori((a + b) * 0.5), floori((b - a) * 0.5))


func _diamond(cell: Vector2i, inset := 0.0) -> PackedVector2Array:
	var c := cell_center(cell)
	var w := TILE_W * 0.5 - inset * 2.0
	var h := TILE_H * 0.5 - inset
	return PackedVector2Array([c + Vector2(0, -h), c + Vector2(w, 0), c + Vector2(0, h), c + Vector2(-w, 0)])


## Quadrilatero isometrico tra due angoli in coordinate di cella.
func _iso_quad(a: Vector2, b: Vector2) -> PackedVector2Array:
	return PackedVector2Array([cell_to_local(a), cell_to_local(Vector2(b.x, a.y)), cell_to_local(b), cell_to_local(Vector2(a.x, b.y))])


# --- Input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press = true
			_panning = false
			_painting = false
			_press_pos = event.position
			_stroke = {}
			var cell := local_to_cell(get_local_mouse_position())
			# con la mano si dipinge solo partendo da una pianta pronta;
			# altrimenti il trascinamento sposta la vista
			if tool != "hand" or GameState.is_ready(cell):
				_painting = true
				_apply_at(get_local_mouse_position(), true)
			get_viewport().set_input_as_handled()
		else:
			if _press and not _painting and not _panning:
				_tap(local_to_cell(get_local_mouse_position()))
			_press = false
			_painting = false
			_panning = false
	elif event is InputEventMouseMotion:
		_hover = local_to_cell(get_local_mouse_position())
		if _press:
			if _painting:
				_apply_at(get_local_mouse_position(), false)
			elif _panning or event.position.distance_to(_press_pos) > DRAG_THRESHOLD:
				_panning = true
				camera.pan_by(event.relative)


## Tocco semplice con la mano (o su un forziere / terreno in vendita).
func _tap(cell: Vector2i) -> void:
	if GameState.chest_cell() == cell:
		GameState.open_chest(cell)
	elif GameState.is_in_world(cell) and not GameState.is_in_grid(cell):
		sector_tapped.emit(GameData.sector_of(cell))
	elif GameState.is_ready(cell):
		GameState.harvest(cell)
	elif GameState.is_in_grid(cell) and not GameState.is_tilled(cell) and not GameState.is_plow_queued(cell):
		GameState.toast.emit(tr("MSG_TAKE_HOE"))


func _apply_at(local: Vector2, first: bool) -> void:
	var cell := local_to_cell(local)
	if _stroke.has(cell):
		return
	_stroke[cell] = true
	if first and (GameState.chest_cell() == cell or (GameState.is_in_world(cell) and not GameState.is_in_grid(cell))):
		_tap(cell)
		return
	if GameState.is_in_grid(cell):
		_use_tool(cell, first)


func _use_tool(cell: Vector2i, first: bool) -> void:
	# Le piante pronte si raccolgono sempre, qualunque strumento sia in mano.
	if GameState.is_ready(cell):
		GameState.harvest(cell)
		return
	match tool:
		"hoe":
			if GameState.is_plow_queued(cell):
				if first:
					GameState.cancel_plow(cell)
			elif not GameState.is_tilled(cell):
				GameState.queue_plow(cell)
		"seed":
			if GameState.get_plot(cell).is_empty():
				if GameState.is_tilled(cell) or first:
					GameState.plant(cell, selected_crop)
		"water":
			if not GameState.water_plot(cell) and first and not GameState.needs_water(cell):
				GameState.toast.emit(tr("MSG_WATER_HINT"))
		"fertilizer":
			if not GameState.fertilize_plot(cell) and first and GameState.get_plot(cell).is_empty():
				GameState.toast.emit(tr("MSG_FERTILIZER_HINT"))


func _on_harvested(cell: Vector2i, product: String, qty: int) -> void:
	var color := Color.WHITE
	var id := GameData.crop_for_product(product)
	if id != "":
		color = Color(GameData.crop(id)["color"])
	_popups.append({"pos": cell_center(cell) + Vector2(0, -40), "text": "+%d %s" % [qty, GameData.product_name(product)], "color": color, "t": 0.0})


## Il contadino semina subito: compare sul quadrante e lancia i semi.
func _on_planted(cell: Vector2i) -> void:
	_farmer_pos = cell_center(cell) + Vector2(-22, 4)
	_farmer_flip = false
	_sow_t = 0.0


func _on_chest_opened(cell: Vector2i, found: Dictionary, coins: int) -> void:
	var names: PackedStringArray = []
	for id in found:
		names.append("+%d %s" % [found[id], GameData.antique_name(id)])
	_popups.append({"pos": cell_center(cell) + Vector2(0, -40), "text": ", ".join(names), "color": Color("f2c75c"), "t": 0.0})
	_popups.append({"pos": cell_center(cell) + Vector2(0, -12), "text": "+%d" % coins, "color": Color("f2c75c"), "t": -0.3})


# --- Contadino --------------------------------------------------------------

func _farmer_target() -> Vector2:
	if _sow_t >= 0.0:
		return _farmer_pos
	var job := GameState.current_plow_job()
	if job.is_empty() and not GameState.plow_queue.is_empty():
		job = GameState.plow_queue[0]
	if job.is_empty():
		return _farmer_pos
	return cell_center(GameState.key_to_cell(job["cell"])) + Vector2(-24, 2)


func _update_farmer(delta: float) -> void:
	if _sow_t >= 0.0:
		_sow_t += delta / SOW_TIME
		if _sow_t >= 1.0:
			_sow_t = -1.0
		return
	var target := _farmer_target()
	var d := target - _farmer_pos
	if d.length() > 1.0:
		_farmer_flip = d.x < 0.0
		_farmer_pos += d.limit_length(FARMER_SPEED * delta)


func _draw_farmer() -> void:
	var walking := _farmer_pos.distance_to(_farmer_target()) >= 2.0
	var action := ""
	if _sow_t >= 0.0:
		action = "sow"
	elif not walking and not GameState.current_plow_job().is_empty():
		action = "hoe"
	FarmerDrawer.draw(self, _farmer_pos, _clock, walking, action, _farmer_flip, maxf(_sow_t, 0.0))


# --- Veicoli sulla strada ----------------------------------------------------

## Ogni tanto passa qualcuno: carretto con l'asino, carro col cavallo o
## un'auto d'epoca, in una delle due direzioni.
func _update_vehicles(delta: float) -> void:
	_next_vehicle -= delta
	if _next_vehicle <= 0.0:
		_next_vehicle = randf_range(14.0, 34.0)
		var kinds := ["donkey", "horse", "car"]
		var dir := 1 if randf() < 0.5 else -1
		var w := GameData.world_size()
		var lane := float(w.x) + (ROAD_FROM + ROAD_TO) * 0.5 + (0.22 if dir > 0 else -0.22)
		_vehicles.append({"kind": kinds.pick_random(), "dir": dir, "lane": lane,
			"y": -3.6 if dir > 0 else float(w.y) + 8.0, "speed": randf_range(0.9, 1.3)})
	var limit := float(GameData.world_size().y) + 9.0
	for v in _vehicles:
		var sp: float = (2.6 if v["kind"] == "car" else 1.1) * v["speed"]
		v["y"] += v["dir"] * sp * delta
	_vehicles = _vehicles.filter(func(v: Dictionary) -> bool: return v["y"] > -3.8 and v["y"] < limit)


func _draw_vehicle(v: Dictionary) -> void:
	var p := cell_to_local(Vector2(v["lane"], v["y"]))
	# lungo la strada si va "verso" lo spettatore (giù a sinistra) o "via"
	var flip: bool = v["dir"] > 0
	var s := -1.0 if flip else 1.0
	var bump := absf(sin(_clock * 8.0 + v["y"])) * 1.5
	_shadow(p + Vector2(0, 4), 30.0)
	match v["kind"]:
		"car":
			# auto d'epoca color crema, tondeggiante
			var body := Color("e6d3a3")
			draw_rect(Rect2(p + Vector2(-26, -20 - bump), Vector2(52, 14)), body)
			draw_circle(p + Vector2(-8 * s, -22 - bump), 14.0, body)
			draw_rect(Rect2(p + Vector2(-16 * s - (12 if s > 0 else 0), -30 - bump), Vector2(12, 8)), Color("9fc3d4"))
			draw_rect(Rect2(p + Vector2(-26, -10 - bump), Vector2(52, 3)), Color("b03a2e"))
			for x in [-16.0, 16.0]:
				draw_circle(p + Vector2(x, -4), 6.5, Color("2e2a26"))
				draw_circle(p + Vector2(x, -4), 2.5, Color("c8c2b4"))
			draw_circle(p + Vector2(25 * -s, -15 - bump), 3.0, Color("fff3c4"))
		_:
			# carretto di legno tirato da un asino o da un cavallo
			var horse: bool = v["kind"] == "horse"
			var animal := Color("8a6a4e") if horse else Color("8f8a84")
			var a := p + Vector2(-36 * s, 0)
			var legs := sin(_clock * 9.0) * 3.0
			for lx in [-8.0, 8.0]:
				draw_line(a + Vector2(lx, -14), a + Vector2(lx + legs * (1 if lx > 0 else -1), 0), animal.darkened(0.25), 3.0)
			draw_set_transform(a + Vector2(0, -18), 0.0, Vector2(1.0, 0.6))
			draw_circle(Vector2.ZERO, 13.0 if horse else 11.0, animal)
			draw_set_transform(Vector2.ZERO)
			var head := a + Vector2(-14 * s, -26 if horse else -22)
			draw_line(a + Vector2(-8 * s, -20), head, animal, 7.0)
			draw_circle(head, 5.0, animal)
			if horse:
				draw_line(head + Vector2(4 * s, -2), a + Vector2(-4 * s, -24), Color("3b2a17"), 2.0)
			else:
				draw_line(head, head + Vector2(2 * s, -10), animal.darkened(0.2), 2.5)
				draw_line(head, head + Vector2(-2 * s, -10), animal.darkened(0.2), 2.5)
			draw_line(a + Vector2(6 * s, -18), p + Vector2(-14 * s, -14), COLOR_WOOD_DARK, 2.0)
			# il carretto, con qualche cassetta o balla di fieno
			draw_rect(Rect2(p + Vector2(-16, -24 - bump), Vector2(32, 14)), COLOR_WOOD)
			draw_rect(Rect2(p + Vector2(-16, -24 - bump), Vector2(32, 3)), COLOR_WOOD_DARK)
			draw_rect(Rect2(p + Vector2(-12, -34 - bump), Vector2(12, 10)), Color("d9b45a"))
			draw_rect(Rect2(p + Vector2(2, -32 - bump), Vector2(10, 8)), Color("c0603e"))
			draw_circle(p + Vector2(0, -6), 8.0, COLOR_WOOD_DARK)
			draw_circle(p + Vector2(0, -6), 5.0, COLOR_WOOD)


# --- Disegno ----------------------------------------------------------------

func _draw() -> void:
	var w := GameData.world_size()
	_draw_river(w)
	_draw_road(w)
	for t in _trees:
		if t["back"]:
			_draw_tree_decor(t)

	# Pittore isometrico: un quadrante alla volta, dal fondo verso lo
	# spettatore, prima la terra e poi la pianta.
	var farmer_drawn := false
	for depth in w.x + w.y - 1:
		for x in w.x:
			var y := depth - x
			if y < 0 or y >= w.y:
				continue
			var cell := Vector2i(x, y)
			if not farmer_drawn and cell_center(cell).y > _farmer_pos.y:
				_draw_farmer()
				farmer_drawn = true
			if not GameState.is_in_grid(cell):
				_draw_locked_cell(cell)
				continue
			if not _draw_plant_sprite(cell):
				_draw_ground(cell)
				if cell == _hover:
					draw_polyline(_closed(_diamond(cell, 2.0)), COLOR_HOVER, 2.5, true)
				_draw_plant(cell)
			if GameState.chest_cell() == cell:
				_draw_chest(cell)
	if not farmer_drawn:
		_draw_farmer()
	_draw_sector_signs(w)
	for t in _trees:
		if not t["back"]:
			_draw_tree_decor(t)
	for v in _vehicles:
		_draw_vehicle(v)
	if GameState.is_in_world(_hover) and not GameState.is_in_grid(_hover):
		_draw_sector_outline(GameData.sector_of(_hover))


func _closed(poly: PackedVector2Array) -> PackedVector2Array:
	var out := poly.duplicate()
	out.append(poly[0])
	return out


func _draw_ground(cell: Vector2i) -> void:
	var rect := Rect2(cell_to_local(cell) - Vector2(TILE_W * 0.5, 0), Vector2(TILE_W, TILE_H))
	var plot := GameState.get_plot(cell)
	if GameState.is_tilled(cell):
		var wet: bool = not plot.is_empty() and plot.get("watered", false)
		draw_texture_rect(TEX_SOIL_WET if wet else TEX_SOIL, rect, false)
		return
	var flowers := posmod(cell.x * 7 + cell.y * 13, 5) == 0
	draw_texture_rect(TEX_GRASS_FLOWERS if flowers else TEX_GRASS, rect, false)
	if GameState.is_plow_queued(cell):
		var prog := GameState.plow_progress(cell)
		if prog > 0.0:
			draw_texture_rect(TEX_SOIL, rect, false, Color(1, 1, 1, prog))
		var poly := _diamond(cell, 5.0)
		for i in 4:
			draw_dashed_line(poly[i], poly[(i + 1) % 4], COLOR_QUEUED, 2.5, 7.0, true, true)


## Terra non ancora tua: erba più selvatica, un po' spenta.
func _draw_locked_cell(cell: Vector2i) -> void:
	var rect := Rect2(cell_to_local(cell) - Vector2(TILE_W * 0.5, 0), Vector2(TILE_W, TILE_H))
	var flowers := posmod(cell.x * 7 + cell.y * 13, 4) == 0
	draw_texture_rect(TEX_GRASS_FLOWERS if flowers else TEX_GRASS, rect, false, COLOR_LOCKED)
	# ciuffi d'erba alta e qualche sasso
	var h := posmod(cell.x * 31 + cell.y * 17, 7)
	var c := cell_center(cell)
	if h < 3:
		for i in 3:
			var o := Vector2((i - 1) * 9.0 + h * 3.0, (i % 2) * 6.0 - 3.0)
			draw_line(c + o, c + o + Vector2(-3, -12), Color("6f8f3e"), 2.0)
			draw_line(c + o, c + o + Vector2(3, -11), Color("7fa840"), 2.0)
	elif h == 4:
		draw_circle(c + Vector2(10, 4), 5.0, Color("b9ad98"))
		draw_circle(c + Vector2(8, 2), 3.0, Color("d8cbb5"))


func _draw_sector_outline(sector: Vector2i) -> void:
	var n := float(GameData.SECTOR_SIZE)
	var a := Vector2(sector) * n
	var poly := _iso_quad(a, a + Vector2(n, n))
	for i in 4:
		draw_dashed_line(poly[i], poly[(i + 1) % 4], Color(1, 0.97, 0.85, 0.9), 3.0, 10.0, true, true)


## Cartello "in vendita" al centro di ogni lotto che si può comprare.
func _draw_sector_signs(w: Vector2i) -> void:
	var n := GameData.SECTOR_SIZE
	for sy in GameData.WORLD_SECTORS.y:
		for sx in GameData.WORLD_SECTORS.x:
			var sector := Vector2i(sx, sy)
			if GameState.is_sector_owned(sector) or not GameState.is_sector_buyable(sector):
				continue
			var p := cell_to_local(Vector2(sx * n + n * 0.5, sy * n + n * 0.5))
			_shadow(p + Vector2(0, 2), 14.0)
			draw_line(p, p + Vector2(0, -34), COLOR_WOOD_DARK, 5.0)
			draw_rect(Rect2(p + Vector2(-26, -58), Vector2(52, 26)), COLOR_WOOD)
			draw_rect(Rect2(p + Vector2(-26, -58), Vector2(52, 26)), COLOR_WOOD_DARK, false, 2.0)


func _draw_chest(cell: Vector2i) -> void:
	var c := cell_center(cell) + Vector2(0, 4)
	var bob := absf(sin(_clock * 2.5)) * 3.0
	_shadow(c + Vector2(0, 2), 18.0)
	# luccichio
	draw_circle(c + Vector2(0, -16), 22.0 + bob, Color(1, 0.9, 0.5, 0.18))
	var body := Rect2(c + Vector2(-16, -18), Vector2(32, 18))
	draw_rect(body, Color("8a5a2b"))
	draw_rect(Rect2(body.position + Vector2(16, 0), Vector2(16, 18)), Color("764a22"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-16, -18), c + Vector2(16, -18), c + Vector2(13, -28), c + Vector2(-13, -28)]), Color("9c6a35"))
	for x in [-11.0, 9.0]:
		draw_rect(Rect2(c + Vector2(x, -28), Vector2(3, 28)), Color("d9a441"))
	draw_rect(Rect2(c + Vector2(-3, -16), Vector2(6, 7)), Color("f2c75c"))
	# stellina che brilla
	var t := fmod(_clock, 2.0)
	if t < 0.6:
		var sp := c + Vector2(12, -30)
		var k := sin(t / 0.6 * PI) * 6.0
		draw_line(sp + Vector2(-k, 0), sp + Vector2(k, 0), Color("fff6d0"), 2.0)
		draw_line(sp + Vector2(0, -k), sp + Vector2(0, k), Color("fff6d0"), 2.0)


## Il fiume a sinistra: acqua con riflessi che scorrono, sponde di sabbia e canne.
func _draw_river(w: Vector2i) -> void:
	var y0 := -3.6   # nasce dietro il bosco
	var y1 := float(w.y) + 10.0
	draw_colored_polygon(_iso_quad(Vector2(RIVER_FROM - 0.4, y0), Vector2(RIVER_TO + 0.35, y1)), COLOR_BANK)
	# acqua con bordo ondulato
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var y := y0
	while y <= y1:
		var wob := sin(y * 0.9) * 0.18
		left.append(cell_to_local(Vector2(RIVER_FROM + wob, y)))
		right.append(cell_to_local(Vector2(RIVER_TO - 0.05 + wob * 0.6, y)))
		y += 0.5
	right.reverse()
	draw_colored_polygon(left + right, COLOR_WATER)
	var mid := PackedVector2Array()
	y = y0
	while y <= y1:
		mid.append(cell_to_local(Vector2((RIVER_FROM + RIVER_TO) * 0.5 + sin(y * 0.9) * 0.15, y)))
		y += 0.5
	draw_polyline(mid, COLOR_WATER_DEEP, 26.0, true)
	# riflessi che scorrono verso lo spettatore
	for i in 40:
		var fy := fposmod(i * 0.83 + _clock * 0.35, y1 - y0) + y0
		var fx := lerpf(RIVER_FROM + 0.4, RIVER_TO - 0.4, fposmod(i * 0.37, 1.0))
		var p := cell_to_local(Vector2(fx, fy))
		draw_line(p, p + Vector2(-10, 5), Color(1, 1, 1, 0.45), 2.0, true)
	# canne lungo la sponda verso il campo
	for i in int(y1 - y0):
		var p := cell_to_local(Vector2(RIVER_TO + 0.15, y0 + i + 0.3 * (i % 3)))
		if i % 2 == 0:
			for k in 3:
				draw_line(p + Vector2(k * 4 - 4, 0), p + Vector2(k * 5 - 6, -18 - k * 3), Color("6f8f3e"), 2.0)
			draw_line(p + Vector2(-2, -16), p + Vector2(-2, -22), Color("8a5a2b"), 4.0)


## La strada di pietrisco davanti, lungo il lato destro della mappa.
func _draw_road(w: Vector2i) -> void:
	var x0 := float(w.x) + ROAD_FROM
	var x1 := float(w.x) + ROAD_TO
	draw_colored_polygon(_iso_quad(Vector2(x0, -3.6), Vector2(x1, float(w.y) + 10.0)), COLOR_ROAD)
	# bordi d'erba e sassolini
	draw_line(cell_to_local(Vector2(x0, -3.6)), cell_to_local(Vector2(x0, float(w.y) + 10.0)), COLOR_ROAD_DARK, 3.0)
	draw_line(cell_to_local(Vector2(x1, -3.6)), cell_to_local(Vector2(x1, float(w.y) + 10.0)), COLOR_ROAD_DARK, 3.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 260:
		var p := cell_to_local(Vector2(rng.randf_range(x0 + 0.05, x1 - 0.05), rng.randf_range(-3.6, float(w.y) + 10.0)))
		draw_circle(p, rng.randf_range(1.2, 2.6), COLOR_ROAD_DARK if rng.randf() < 0.6 else Color("e2d3b2"))
	# solchi delle ruote
	for lane in [0.35, 0.85]:
		draw_line(cell_to_local(Vector2(x0 + lane, -3.6)), cell_to_local(Vector2(x0 + lane, float(w.y) + 10.0)), Color(0.55, 0.45, 0.3, 0.25), 4.0)


## Bosco a destra (oltre il lato in fondo) e qualche albero sparso davanti.
func _build_trees() -> void:
	var w := GameData.world_size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	_trees = []
	var x := -4.6
	while x < float(w.x) + 2.8:
		for row in 3:
			var y := -1.1 - row * 1.1 - rng.randf() * 0.5
			var kind := "cypress" if rng.randf() < 0.4 else "tree"
			_trees.append({"cell": Vector2(x + rng.randf() * 0.6, y), "kind": kind, "s": rng.randf_range(0.9, 1.3), "back": true})
		x += rng.randf_range(0.9, 1.5)
	# davanti, sul prato aperto: il casale del contadino col pozzo, alberi e fieno
	_trees.append({"cell": Vector2(5.0, float(w.y) + 3.4), "kind": "sprite", "name": "casale", "w": 300.0, "back": false})
	_trees.append({"cell": Vector2(9.2, float(w.y) + 1.9), "kind": "sprite", "name": "pozzo", "w": 92.0, "back": false})
	_trees.append({"cell": Vector2(1.6, float(w.y) + 1.7), "kind": "sprite", "name": "balle_fieno", "w": 78.0, "back": false})
	_trees.append({"cell": Vector2(12.5, float(w.y) + 1.8), "kind": "sprite", "name": "carretto_fieno", "w": 96.0, "back": false})
	_trees.append({"cell": Vector2(15.5, float(w.y) + 2.2), "kind": "tree", "s": 1.0, "back": false})
	_trees.append({"cell": Vector2(-0.6, float(w.y) + 3.0), "kind": "bush", "s": 1.0, "back": false})
	# ordina dal fondo, così si coprono nel modo giusto
	_trees.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["cell"].x + a["cell"].y < b["cell"].x + b["cell"].y)


func _draw_tree_decor(t: Dictionary) -> void:
	var c: Vector2 = t["cell"]
	var p := cell_to_local(c) + Vector2(0, TILE_H * 0.5)
	var s: float = t.get("s", 1.0)
	# illustrati, se ci sono gli sprite; altrimenti disegnati da codice
	var illustrated := {"tree": ["ulivo_albero_c"], "cypress": ["cipresso", "cipressi_coppia"], "bush": ["cespuglio_fiori"], "hay": ["balle_fieno"]}
	var widths := {"tree": 92.0, "cypress": 40.0, "bush": 64.0, "hay": 78.0}
	if t["kind"] == "sprite":
		Sprites.draw(self, t["name"], p, t["w"], 0.04)
		return
	if illustrated.has(t["kind"]):
		var options: Array = illustrated[t["kind"]]
		var pick: String = options[posmod(int(c.x * 7.0 + c.y * 3.0), options.size())]
		if Sprites.tex(pick) != null:
			Sprites.draw(self, pick, p, widths[t["kind"]] * s, 0.05, posmod(int(c.x * 5.0), 2) == 0)
			return
	match t["kind"]:
		"tree":
			_draw_round_tree(p, s, Color(0, 0, 0, 0), 1.0)
		"cypress":
			_shadow(p, 12.0 * s)
			draw_line(p, p + Vector2(0, -10 * s), COLOR_WOOD_DARK, 5.0)
			var pts := PackedVector2Array([p + Vector2(0, -88 * s), p + Vector2(14 * s, -44 * s), p + Vector2(10 * s, -8 * s), p + Vector2(-10 * s, -8 * s), p + Vector2(-14 * s, -44 * s)])
			draw_colored_polygon(pts, Color("335a2c"))
			draw_colored_polygon(PackedVector2Array([pts[0], pts[1], pts[2], p + Vector2(0, -8 * s)]), Color("40703a"))
		"bush":
			_draw_bush_shape(p, 16.0 * s, Color(0, 0, 0, 0), 0.0)
		"hay":
			_shadow(p, 22.0)
			draw_set_transform(p + Vector2(0, -14), 0.0, Vector2(1.0, 0.8))
			draw_circle(Vector2.ZERO, 20.0, Color("d9b45a"))
			draw_circle(Vector2(-4, -4), 15.0, Color("e8c870"))
			draw_set_transform(Vector2.ZERO)
			draw_arc(p + Vector2(0, -14), 12.0, 0.4, 2.6, 12, Color("b8913a"), 2.0)


func _shadow(p: Vector2, r: float, alpha := 1.0) -> void:
	draw_set_transform(p, 0.0, Vector2(1.0, 0.45))
	var c := COLOR_SHADOW
	c.a *= alpha
	draw_circle(Vector2.ZERO, r, c)
	draw_set_transform(Vector2.ZERO)


# --- Piante -----------------------------------------------------------------

## Sprite illustrati delle piante (assets/graphics/plants), ritagliati dai
## fogli con tools/extract_plants.py. Ogni sprite comprende il suo blocco di
## terra; "anchor" è il centro della faccia superiore del blocco, "tile_w" la
## sua larghezza: servono ad allinearlo al quadrante. Le piante senza sprite
## si disegnano da codice.
func _load_plant_sprites() -> void:
	const MANIFEST := "res://assets/graphics/plants/plants.json"
	if not FileAccess.file_exists(MANIFEST):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not (data is Dictionary):
		return
	for crop_id in data:
		var stages: Array = []
		for st in data[crop_id]:
			var path := str(st["file"])
			if not path.begins_with("res://"):
				path = "res://assets/graphics/plants/" + path
			var tex := load(path) as Texture2D
			if tex == null:
				stages = []
				break
			stages.append({"tex": tex, "anchor": Vector2(st["anchor"][0], st["anchor"][1]), "scale": TILE_W * PLANT_SCALE / float(st["tile_w"])})
		if stages.size() == 3:
			_plant_sprites[crop_id] = stages


## Stadio dello sprite: 0 germoglio, 1 crescita, 2 maturazione (pronta).
## Alberi e arbusti già raccolti ripartono dalla crescita, non dal germoglio.
func _plant_stage(cell: Vector2i, plot: Dictionary) -> int:
	if GameState.is_ready(cell):
		return 2
	if int(plot.get("harvests", 0)) > 0:
		return 1
	return 0 if GameState.plot_progress(cell) < 0.34 else 1


func _draw_plant_sprite(cell: Vector2i) -> bool:
	var plot := GameState.get_plot(cell)
	if plot.is_empty() or not _plant_sprites.has(plot["crop"]):
		return false
	# un seme appena piantato (non un albero da ri-annaffiare) è un sacchetto
	if GameState.needs_water(cell) and int(plot.get("harvests", 0)) == 0:
		return false
	var st: Dictionary = _plant_sprites[plot["crop"]][_plant_stage(cell, plot)]
	var tex: Texture2D = st["tex"]
	var k: float = st["scale"]
	var pos: Vector2 = cell_center(cell) - st["anchor"] * k
	draw_texture_rect(tex, Rect2(pos, tex.get_size() * k), false)
	if cell == _hover:
		draw_polyline(_closed(_diamond(cell, 2.0)), COLOR_HOVER, 2.5, true)
	return true


func _draw_plant(cell: Vector2i) -> void:
	var plot := GameState.get_plot(cell)
	if plot.is_empty():
		return
	# Seminata e non ancora annaffiata: resta il sacchetto di semi.
	if GameState.needs_water(cell) and int(plot.get("harvests", 0)) == 0:
		_draw_seed_bag(cell_center(cell), Color(GameData.crop(plot["crop"])["color"]))
		return
	var id: String = plot["crop"]
	var crop := GameData.crop(id)
	var progress := GameState.plot_progress(cell)
	var color := Color(crop["color"])
	var c := cell_center(cell) + Vector2(0, 2)
	var sway := sin(_clock * 1.6 + cell.x * 1.3 + cell.y * 0.7) * 1.5
	match crop["kind"]:
		"tree":
			# già raccolto una volta: resta grande, i frutti ricrescono
			var size_p := 1.0 if int(plot.get("harvests", 0)) > 0 else progress
			_draw_round_tree(c, lerpf(0.55, 1.0, minf(size_p * 1.6, 1.0)), color, progress)
		"bush":
			var size_b := 1.0 if int(plot.get("harvests", 0)) > 0 else progress
			_draw_bush_shape(c, lerpf(9.0, 20.0, size_b), color, progress)
		_:
			# quattro piantine per quadrante, disposte sul rombo
			for o in [Vector2(0, -11), Vector2(-24, 1), Vector2(24, 1), Vector2(0, 13)]:
				_draw_crop(c + o, SHAPES.get(id, "fruit"), color, progress, sway)


func _draw_crop(p: Vector2, shape: String, color: Color, progress: float, sway: float) -> void:
	var ripe := progress >= 1.0
	var g := lerpf(0.35, 1.0, progress)  # crescita
	_shadow(p + Vector2(2, 1), 9.0 * g, 0.8)
	if progress < 0.15:
		# germoglio: due foglioline
		_leaf(p, Vector2(-5, -6), COLOR_LEAF_LIGHT)
		_leaf(p, Vector2(5, -6), COLOR_LEAF)
		return
	match shape:
		"grain":
			var head := color if ripe else COLOR_LEAF_LIGHT.lerp(color, progress * 0.6)
			for i in 5:
				var x := (i - 2) * 3.5
				var top := p + Vector2(x + sway * (1.0 + i * 0.2), -26.0 * g)
				draw_line(p + Vector2(x, 0), top, COLOR_LEAF.lerp(color, 0.5 if ripe else 0.0), 2.0)
				draw_set_transform(top + Vector2(0, -4), 0.1 * (i - 2), Vector2(0.55, 1.0))
				draw_circle(Vector2.ZERO, 4.5 * g, head)
				draw_set_transform(Vector2.ZERO)
		"leafy":
			var r := 11.0 * g
			draw_circle(p + Vector2(0, -r * 0.6), r, COLOR_LEAF_DARK if shape == "leafy" else COLOR_LEAF)
			draw_circle(p + Vector2(-r * 0.4, -r * 0.9), r * 0.7, color.lerp(COLOR_LEAF, 0.3))
			draw_circle(p + Vector2(r * 0.35, -r * 1.0), r * 0.6, color.lightened(0.15))
			draw_circle(p + Vector2(-r * 0.2, -r * 1.2), r * 0.25, Color(1, 1, 1, 0.25))
		"root":
			for i in 3:
				var a := (i - 1) * 0.45
				var tip := p + Vector2(sin(a) * 16 * g + sway, -cos(a) * 20 * g)
				draw_line(p, tip, COLOR_LEAF if i != 1 else COLOR_LEAF_LIGHT, 3.0)
				draw_circle(tip, 3.0, COLOR_LEAF)
			if progress > 0.6:
				draw_set_transform(p + Vector2(0, -1), 0.0, Vector2(1.0, 0.7))
				draw_circle(Vector2.ZERO, 6.0 * g, color)
				draw_circle(Vector2(-2, -2), 2.0 * g, color.lightened(0.35))
				draw_set_transform(Vector2.ZERO)
		"big":
			var r := 9.0 * g
			draw_circle(p + Vector2(-8, -6), r * 0.9, COLOR_LEAF_DARK)
			draw_circle(p + Vector2(8, -8), r * 0.8, COLOR_LEAF)
			if progress > 0.5:
				var fr := lerpf(4.0, 11.0, (progress - 0.5) * 2.0)
				draw_set_transform(p + Vector2(0, -fr * 0.6), 0.0, Vector2(1.15, 0.85))
				draw_circle(Vector2.ZERO, fr, color.darkened(0.1))
				draw_circle(Vector2(-fr * 0.25, -fr * 0.2), fr * 0.75, color)
				draw_circle(Vector2(-fr * 0.4, -fr * 0.45), fr * 0.22, Color(1, 1, 1, 0.35))
				draw_set_transform(Vector2.ZERO)
		"flower":
			for i in 3:
				var x := (i - 1) * 6.0
				var top := p + Vector2(x + sway, -18.0 * g)
				draw_line(p + Vector2(x, 0), top, COLOR_LEAF, 2.0)
				if progress > 0.5:
					for k in 5:
						draw_circle(top + Vector2(4, 0).rotated(k * TAU / 5.0), 3.0, color)
					draw_circle(top, 2.0, Color("ff8a00"))
		_:  # "fruit": cespuglio con frutti
			var r := 10.0 * g
			var top := p + Vector2(sway * 0.5, -r * 1.1)
			draw_line(p, top, COLOR_LEAF_DARK, 3.0)
			draw_circle(top + Vector2(-5, 2), r * 0.8, COLOR_LEAF_DARK)
			draw_circle(top + Vector2(5, 0), r * 0.75, COLOR_LEAF)
			draw_circle(top + Vector2(0, -5), r * 0.6, COLOR_LEAF_LIGHT)
			if progress > 0.6:
				var fr := 2.5 + (3.5 if ripe else 1.5)
				var fc := color if ripe else COLOR_LEAF_LIGHT.lerp(color, 0.4)
				for o in [Vector2(-6, 3), Vector2(6, 4), Vector2(1, -4)]:
					_fruit(top + o, fr, fc)


func _leaf(base: Vector2, dir: Vector2, color: Color) -> void:
	var tip := base + dir
	var n := dir.orthogonal().normalized() * 2.5
	draw_colored_polygon(PackedVector2Array([base, base + dir * 0.5 + n, tip, base + dir * 0.5 - n]), color)


func _fruit(p: Vector2, r: float, color: Color) -> void:
	draw_circle(p + Vector2(0.8, 0.8), r, color.darkened(0.3))
	draw_circle(p, r, color)
	draw_circle(p + Vector2(-r * 0.35, -r * 0.35), r * 0.3, Color(1, 1, 1, 0.5))


## Albero tondo: tronco, chioma a tre volumi, frutti quando maturi.
## Usato anche per gli alberi decorativi (progress = 1, color trasparente).
func _draw_round_tree(p: Vector2, s: float, fruit_color: Color, progress: float) -> void:
	_shadow(p + Vector2(6, 2), 30.0 * s)
	var trunk_top := p + Vector2(0, -34 * s)
	draw_line(p, trunk_top, COLOR_WOOD_DARK, 9.0 * s)
	draw_line(p + Vector2(-2 * s, 0), trunk_top + Vector2(-2 * s, 0), COLOR_WOOD, 4.0 * s)
	var crown := trunk_top + Vector2(0, -14 * s)
	draw_circle(crown + Vector2(8 * s, 6 * s), 24 * s, Color("4a7a2e"))
	draw_circle(crown + Vector2(-10 * s, 2 * s), 22 * s, Color("5c8f36"))
	draw_circle(crown + Vector2(0, -10 * s), 22 * s, Color("72a843"))
	draw_circle(crown + Vector2(-8 * s, -16 * s), 9 * s, Color(1, 1, 1, 0.12))
	if fruit_color.a > 0.0 and progress >= 0.5:
		var ripe := progress >= 1.0
		var fr := lerpf(2.5, 5.5, (progress - 0.5) * 2.0) * s
		var fc := fruit_color if ripe else COLOR_LEAF_LIGHT.lerp(fruit_color, 0.5)
		for o in [Vector2(-16, 4), Vector2(12, -6), Vector2(2, 12), Vector2(-6, -18), Vector2(18, 12), Vector2(-20, -10)]:
			_fruit(crown + o * s, fr, fc)


func _draw_bush_shape(p: Vector2, r: float, fruit_color: Color, progress: float) -> void:
	_shadow(p + Vector2(3, 1), r * 1.3)
	draw_circle(p + Vector2(r * 0.45, -r * 0.6), r * 0.85, Color("4a7a2e"))
	draw_circle(p + Vector2(-r * 0.45, -r * 0.65), r * 0.85, Color("5c8f36"))
	draw_circle(p + Vector2(0, -r * 1.1), r * 0.8, Color("72a843"))
	if fruit_color.a > 0.0 and progress >= 0.6:
		var fc := fruit_color if progress >= 1.0 else COLOR_LEAF_LIGHT.lerp(fruit_color, 0.5)
		for o in [Vector2(-0.5, -0.5), Vector2(0.5, -0.8), Vector2(0.0, -1.4), Vector2(-0.7, -1.1), Vector2(0.7, -0.3)]:
			_fruit(p + o * r, maxf(2.5, r * 0.18), fc)


## Sacchetto di semi appoggiato sulla terra, con un cartellino del colore
## della pianta: aspetta l'acqua.
func _draw_seed_bag(c: Vector2, color: Color) -> void:
	_shadow(c + Vector2(2, 3), 14.0)
	draw_texture_rect(TEX_SEEDS, Rect2(c + Vector2(-17, -30), Vector2(34, 34)), false)
	draw_circle(c + Vector2(9, -4), 5.0, Color("f6eedb"))
	draw_circle(c + Vector2(9, -4), 3.5, color)
