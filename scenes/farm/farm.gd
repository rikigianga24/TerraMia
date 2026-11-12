class_name Farm
extends Node2D
## La fattoria in 2.5D: griglia isometrica di quadranti a filo del prato (6×6 all'inizio).
## I blocchi sono SVG (assets/graphics/tiles); piante, contadino e staccionata
## sono disegnati da codice in _draw() con ombre e luci, finché non arrivano
## sprite definitivi.
##
## Strumenti (scelti dalla barra in basso):
##   mano       raccoglie le piante pronte
##   zappa      mette in coda la lavorazione di un quadrante d'erba (15 s l'uno)
##   semi       pianta il seme selezionato sulla terra lavorata
##   acqua      annaffia (1 goccia, accorcia la crescita)
##   concime    raddoppia il prossimo raccolto
## Le piante pronte si raccolgono con qualsiasi strumento. Tenendo premuto e
## trascinando si applica lo strumento a tutti i quadranti toccati.

signal tool_changed(tool: String)

const TILE_W := 112.0
const TILE_H := 56.0

const TEX_GRASS := preload("res://assets/graphics/tiles/grass.png")
const TEX_GRASS_FLOWERS := preload("res://assets/graphics/tiles/grass_flowers.png")
const TEX_SOIL := preload("res://assets/graphics/tiles/soil.png")
const TEX_SOIL_WET := preload("res://assets/graphics/tiles/soil_wet.png")

const COLOR_HOVER := Color(1, 1, 1, 0.9)
const COLOR_QUEUED := Color(1, 0.97, 0.85, 0.95)
const COLOR_SHADOW := Color(0.18, 0.12, 0.05, 0.28)
const COLOR_LEAF := Color("6a9e35")
const COLOR_LEAF_DARK := Color("4f7f2a")
const COLOR_LEAF_LIGHT := Color("93c25a")
const COLOR_WOOD := Color("9a6a3e")
const COLOR_WOOD_DARK := Color("6e4626")

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

const FARMER_SPEED := 220.0
const POPUP_TIME := 1.3

var tool: String = "hand":
	set(value):
		tool = value
		tool_changed.emit(value)
var selected_crop: String = "grano"

var _hover := Vector2i(-1, -1)
var _painting := false
var _stroke: Dictionary = {}       ## celle già toccate nel trascinamento
var _stroke_first := true
var _popups: Array = []            ## [{"pos", "text", "color", "t"}]
var _farmer_pos := Vector2.ZERO
var _farmer_flip := false
var _font: Font
var _font_bold: Font
var _clock := 0.0
var _decor: Array = []             ## alberi e cespugli decorativi nel prato
var _overlay_layer: CanvasLayer
var _plant_sprites: Dictionary = {}  ## coltura -> [ {tex, anchor, scale} ×3 stadi ]


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_font_bold = load("res://assets/fonts/Fredoka-SemiBold.ttf")
	GameState.changed.connect(queue_redraw)
	GameState.harvested.connect(_on_harvested)
	get_viewport().size_changed.connect(_recenter)
	_recenter()
	_farmer_pos = cell_center(Vector2i(0, GameState.grid_size.y)) + Vector2(-10, 20)
	_build_decor()
	_load_plant_sprites()
	# Etichette, fumetti e scritte del raccolto vanno sopra il filtro "tempera"
	# (livello 7), così restano nitidi.
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 7
	add_child(_overlay_layer)
	var overlay := FarmOverlay.new()
	overlay.farm = self
	_overlay_layer.add_child(overlay)


func _process(delta: float) -> void:
	_clock += delta
	_overlay_layer.visible = visible
	GameState.update_plowing()
	_update_farmer(delta)
	for p in _popups:
		p["t"] += delta
	_popups = _popups.filter(func(p: Dictionary) -> bool: return p["t"] < POPUP_TIME)
	# I timer sono reali: ridisegna per mostrare la crescita.
	queue_redraw()


func _recenter() -> void:
	var vp := get_viewport_rect().size
	var grid_h := (GameState.grid_size.x + GameState.grid_size.y) * TILE_H * 0.5
	# Il campo sta sul prato, sotto l'orizzonte (Backdrop.HORIZON).
	position = Vector2(vp.x * 0.5, maxf(vp.y * (Backdrop.HORIZON + 0.035), vp.y - grid_h - 150.0))


# --- Coordinate isometriche -------------------------------------------------

## Vertice superiore del rombo della cella.
func cell_to_local(cell: Vector2i) -> Vector2:
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


# --- Input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_painting = true
			_stroke = {}
			_stroke_first = true
			if _apply_at(get_local_mouse_position()):
				get_viewport().set_input_as_handled()
		else:
			_painting = false
	elif event is InputEventMouseMotion:
		_hover = local_to_cell(get_local_mouse_position())
		if _painting:
			_apply_at(get_local_mouse_position())


func _apply_at(local: Vector2) -> bool:
	var cell := local_to_cell(local)
	if not GameState.is_in_grid(cell) or _stroke.has(cell):
		return false
	_stroke[cell] = true
	var first := _stroke_first
	_stroke_first = false
	_use_tool(cell, first)
	return true


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
			if not GameState.water_plot(cell) and first and GameState.get_plot(cell).is_empty():
				GameState.toast.emit(tr("MSG_WATER_HINT"))
		"fertilizer":
			if not GameState.fertilize_plot(cell) and first and GameState.get_plot(cell).is_empty():
				GameState.toast.emit(tr("MSG_FERTILIZER_HINT"))
		_:
			if first and not GameState.is_tilled(cell) and not GameState.is_plow_queued(cell):
				GameState.toast.emit(tr("MSG_TAKE_HOE"))


func _on_harvested(cell: Vector2i, product: String, qty: int) -> void:
	var color := Color.WHITE
	var id := GameData.crop_for_product(product)
	if id != "":
		color = Color(GameData.crop(id)["color"])
	_popups.append({"pos": cell_center(cell) + Vector2(0, -40), "text": "+%d %s" % [qty, GameData.product_name(product)], "color": color, "t": 0.0})


# --- Contadino --------------------------------------------------------------

func _farmer_target() -> Vector2:
	var job := GameState.current_plow_job()
	if job.is_empty() and not GameState.plow_queue.is_empty():
		job = GameState.plow_queue[0]
	if job.is_empty():
		return _farmer_pos
	return cell_center(GameState.key_to_cell(job["cell"])) + Vector2(-24, 2)


func _update_farmer(delta: float) -> void:
	var target := _farmer_target()
	var d := target - _farmer_pos
	if d.length() > 1.0:
		_farmer_flip = d.x < 0.0
		_farmer_pos += d.limit_length(FARMER_SPEED * delta)


func _draw_farmer() -> void:
	var p := _farmer_pos
	var target := _farmer_target()
	var walking := p.distance_to(target) >= 2.0
	var working := not GameState.current_plow_job().is_empty() and not walking
	var bob := absf(sin(_clock * 10.0)) * -3.0 if walking else 0.0
	var step := sin(_clock * 10.0) * 4.0 if walking else 0.0
	var dir := -1.0 if _farmer_flip else 1.0
	var swing := (sin(_clock * 5.0) * 0.5 + 0.5) if working else 0.0
	_shadow(p + Vector2(0, 2), 16.0)
	# gambe (pantaloni blu) e scarponi
	draw_line(p + Vector2(-4, -2 + step * 0.3), p + Vector2(-4, -16 + bob), Color("34507a"), 6.0)
	draw_line(p + Vector2(4, -2 - step * 0.3), p + Vector2(4, -16 + bob), Color("2c4569"), 6.0)
	draw_circle(p + Vector2(-4 + step * 0.5, 0), 3.5, Color("5a3a22"))
	draw_circle(p + Vector2(4 - step * 0.5, 0), 3.5, Color("4a2e1a"))
	# camicia a quadri (rosso) con bretelle
	var torso := Rect2(p + Vector2(-10, -38 + bob), Vector2(20, 24))
	draw_rect(torso, Color("c8463a"))
	draw_rect(Rect2(torso.position, Vector2(10, 24)), Color("d65a4a"))
	draw_line(torso.position + Vector2(5, 0), torso.position + Vector2(5, 24), Color("34507a"), 3.0)
	draw_line(torso.position + Vector2(15, 0), torso.position + Vector2(15, 24), Color("34507a"), 3.0)
	# testa, baffi, cappello di paglia
	var head := p + Vector2(0, -47 + bob)
	draw_circle(head, 9.0, Color("f0c9a0"))
	draw_circle(head + Vector2(3 * dir, -1), 1.6, Color("3b2a17"))
	draw_line(head + Vector2(-5 + 3 * dir, 4), head + Vector2(5 + 3 * dir, 4), Color("5a3a22"), 3.0)
	draw_set_transform(head + Vector2(0, -7), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 17.0, Color("d9b45a"))
	draw_circle(Vector2.ZERO, 15.0, Color("e8c870"))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(head + Vector2(-8, -16), Vector2(16, 9)), Color("e8c870"))
	draw_rect(Rect2(head + Vector2(-8, -9), Vector2(16, 3)), Color("c0503a"))
	# zappa: si alza e batte mentre lavora
	var angle := lerpf(-1.2, 0.6, swing) if working else 0.9
	var hand := p + Vector2(10 * dir, -28 + bob)
	var tip := hand + Vector2(cos(angle) * 30 * dir, sin(angle) * 30)
	draw_line(hand, tip, COLOR_WOOD, 3.5)
	draw_line(tip, tip + Vector2(7 * dir, 8).rotated(angle * 0.3 * dir), Color("8e9aa6"), 5.0)
	draw_circle(hand, 3.5, Color("f0c9a0"))
	# zolle che saltano a ogni colpo
	if working and swing > 0.85:
		for i in 3:
			var o := Vector2((i - 1) * 6.0 * dir + 34 * dir, -6 - (swing - 0.85) * 60.0 - i * 2.0)
			draw_circle(p + o, 2.2, Color("7a5230"))


# --- Disegno ----------------------------------------------------------------

func _draw() -> void:
	var grid := GameState.grid_size
	_draw_fence(grid, true)
	_draw_decor(true)

	# Pittore isometrico: un quadrante alla volta, dal fondo verso lo
	# spettatore, prima la terra e poi la pianta. Così ogni blocco copre i
	# fianchi di quello dietro, e una pianta illustrata (che ha il suo blocco
	# di terra) si sovrappone correttamente ai vicini.
	var farmer_drawn := false
	for depth in grid.x + grid.y - 1:
		for x in grid.x:
			var y := depth - x
			if y < 0 or y >= grid.y:
				continue
			var cell := Vector2i(x, y)
			if not farmer_drawn and cell_center(cell).y > _farmer_pos.y:
				_draw_farmer()
				farmer_drawn = true
			if not _draw_plant_sprite(cell):
				_draw_ground(cell)
				if cell == _hover:
					draw_polyline(_closed(_diamond(cell, 2.0)), COLOR_HOVER, 2.5, true)
				_draw_plant(cell)
	if not farmer_drawn:
		_draw_farmer()
	if GameState.is_in_grid(_hover) and not GameState.get_plot(_hover).is_empty():
		draw_polyline(_closed(_diamond(_hover, 2.0)), Color(1, 1, 1, 0.5), 2.0, true)

	_draw_fence(grid, false)
	_draw_decor(false)


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


## Staccionata di legno: i lati in fondo prima del campo, quelli davanti dopo.
func _draw_fence(grid: Vector2i, back: bool) -> void:
	var o := 0.6  # distanza dal campo, in quadranti
	var tl := cell_to_local(Vector2i(0, 0)) + Vector2(0, -o * TILE_H)
	var tr := cell_to_local(Vector2i(grid.x, 0)) + Vector2(o * TILE_W, 0)
	var br := cell_to_local(Vector2i(grid.x, grid.y)) + Vector2(0, o * TILE_H)
	var bl := cell_to_local(Vector2i(0, grid.y)) + Vector2(-o * TILE_W, 0)
	if back:
		_fence_side(bl, tl, grid.y)
		_fence_side(tl, tr, grid.x)
	else:
		# davanti lascia un varco al centro per il cancello
		_fence_side(tr, br, grid.y)
		var gate_a := bl.lerp(br, 0.42)
		var gate_b := bl.lerp(br, 0.58)
		_fence_side(bl, gate_a, 3)
		_fence_side(gate_b, br, 3)


func _fence_side(a: Vector2, b: Vector2, posts: int) -> void:
	var n := maxi(2, posts + 1)
	var rail := Vector2(0, -14)
	_shadow_line(a + Vector2(4, 4), b + Vector2(4, 4))
	draw_line(a + rail, b + rail, COLOR_WOOD_DARK, 4.0)
	draw_line(a + rail * 1.8, b + rail * 1.8, COLOR_WOOD, 4.0)
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		draw_line(p, p + Vector2(0, -30), COLOR_WOOD_DARK, 6.0)
		draw_line(p + Vector2(-1, 0), p + Vector2(-1, -30), COLOR_WOOD, 3.0)
		draw_circle(p + Vector2(0, -30), 3.0, COLOR_WOOD)


func _shadow_line(a: Vector2, b: Vector2) -> void:
	draw_line(a, b, COLOR_SHADOW, 5.0)


func _shadow(p: Vector2, r: float, alpha := 1.0) -> void:
	draw_set_transform(p, 0.0, Vector2(1.0, 0.45))
	var c := COLOR_SHADOW
	c.a *= alpha
	draw_circle(Vector2.ZERO, r, c)
	draw_set_transform(Vector2.ZERO)


## Alberi e cespugli fuori dal campo, in posizioni fisse.
func _build_decor() -> void:
	var g := GameState.grid_size
	_decor = [
		{"cell": Vector2(-1.6, 1.0), "kind": "tree", "s": 1.0},
		{"cell": Vector2(-1.5, 3.6), "kind": "bush", "s": 0.9},
		{"cell": Vector2(1.5, -1.6), "kind": "tree", "s": 1.1},
		{"cell": Vector2(4.2, -1.5), "kind": "cypress", "s": 1.0},
		{"cell": Vector2(5.0, -1.7), "kind": "cypress", "s": 0.9},
		{"cell": Vector2(g.x + 1.3, 1.5), "kind": "bush", "s": 0.9},
		{"cell": Vector2(g.x + 1.4, 4.5), "kind": "tree", "s": 1.0},
		{"cell": Vector2(2.0, g.y + 1.4), "kind": "bush", "s": 0.8},
		{"cell": Vector2(-1.3, g.y + 1.0), "kind": "hay", "s": 1.0},
	]


func _decor_pos(c: Vector2) -> Vector2:
	return Vector2((c.x - c.y) * TILE_W * 0.5, (c.x + c.y) * TILE_H * 0.5 + TILE_H * 0.5)


func _draw_decor(back: bool) -> void:
	var field_center_y := cell_center(GameState.grid_size / 2).y
	for d in _decor:
		var p := _decor_pos(d["cell"])
		if (p.y < field_center_y) != back:
			continue
		var s: float = d["s"]
		match d["kind"]:
			"tree":
				_draw_round_tree(p, s, Color(0, 0, 0, 0), 1.0)
			"cypress":
				_shadow(p, 12.0 * s)
				draw_line(p, p + Vector2(0, -10 * s), COLOR_WOOD_DARK, 5.0)
				var pts := PackedVector2Array([p + Vector2(0, -78 * s), p + Vector2(13 * s, -40 * s), p + Vector2(9 * s, -8 * s), p + Vector2(-9 * s, -8 * s), p + Vector2(-13 * s, -40 * s)])
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
			var tex := load("res://assets/graphics/plants/" + str(st["file"])) as Texture2D
			if tex == null:
				stages = []
				break
			stages.append({"tex": tex, "anchor": Vector2(st["anchor"][0], st["anchor"][1]), "scale": TILE_W / float(st["tile_w"])})
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
	var st: Dictionary = _plant_sprites[plot["crop"]][_plant_stage(cell, plot)]
	var tex: Texture2D = st["tex"]
	var k: float = st["scale"]
	var pos: Vector2 = cell_center(cell) - st["anchor"] * k
	var tint := Color(0.86, 0.82, 0.8) if plot.get("watered", false) else Color.WHITE
	draw_texture_rect(tex, Rect2(pos, tex.get_size() * k), false, tint)
	if cell == _hover:
		draw_polyline(_closed(_diamond(cell, 2.0)), COLOR_HOVER, 2.5, true)
	return true


func _draw_plant(cell: Vector2i) -> void:
	var plot := GameState.get_plot(cell)
	if plot.is_empty():
		return
	var id: String = plot["crop"]
	var crop := GameData.crop(id)
	var progress := GameState.plot_progress(cell)
	var color := Color(crop["color"])
	var c := cell_center(cell) + Vector2(0, 2)
	var sway := sin(_clock * 1.6 + cell.x * 1.3 + cell.y * 0.7) * 1.5
	match crop["kind"]:
		"tree":
			_draw_round_tree(c, lerpf(0.55, 1.0, minf(progress * 1.6, 1.0)), color, progress)
		"bush":
			_draw_bush_shape(c, lerpf(9.0, 20.0, progress), color, progress)
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
