class_name Farm
extends Node2D
## La fattoria: griglia isometrica di quadranti (6×6 all'inizio).
## Grafica vettoriale provvisoria disegnata in _draw(); andrà sostituita dagli SVG.
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

const COLOR_GRASS := Color("8fb35a")
const COLOR_GRASS_LIGHT := Color("9cc066")
const COLOR_GRASS_EDGE := Color("5c7a33")
const COLOR_SOIL := Color("8a6a43")
const COLOR_SOIL_WET := Color("5e4529")
const COLOR_FURROW := Color("6e5233")
const COLOR_HOVER := Color(1, 1, 1, 0.25)
const COLOR_QUEUED := Color(1, 1, 1, 0.8)
const COLOR_WATER := Color("4aa3df")
const COLOR_FERTILIZER := Color("c9b26b")
const COLOR_STEM := Color("4f7d2a")

const FARMER_SPEED := 260.0
const POPUP_TIME := 1.2

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
var _clock := 0.0


func _ready() -> void:
	_font = ThemeDB.fallback_font
	GameState.changed.connect(queue_redraw)
	GameState.harvested.connect(_on_harvested)
	get_viewport().size_changed.connect(_recenter)
	_recenter()
	_farmer_pos = cell_center(Vector2i(0, GameState.grid_size.y)) + Vector2(-20, 10)


func _process(delta: float) -> void:
	_clock += delta
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
	position = Vector2(vp.x * 0.5, (vp.y - grid_h) * 0.5 - 10.0)


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
				GameState.toast.emit("Annaffia una pianta che sta crescendo.")
		"fertilizer":
			if not GameState.fertilize_plot(cell) and first and GameState.get_plot(cell).is_empty():
				GameState.toast.emit("Spargi il concime su una pianta che sta crescendo.")
		_:
			if first and not GameState.is_tilled(cell) and not GameState.is_plow_queued(cell):
				GameState.toast.emit("Prendi la zappa per lavorare la terra.")


func _on_harvested(cell: Vector2i, product: String, qty: int) -> void:
	var color := Color.WHITE
	var id := GameData.crop_for_product(product)
	if id != "":
		color = Color(GameData.crop(id)["color"])
	_popups.append({"pos": cell_center(cell) + Vector2(0, -30), "text": "+%d %s" % [qty, product], "color": color, "t": 0.0})


# --- Contadino --------------------------------------------------------------

func _farmer_target() -> Vector2:
	var job := GameState.current_plow_job()
	if job.is_empty() and not GameState.plow_queue.is_empty():
		job = GameState.plow_queue[0]
	if job.is_empty():
		return _farmer_pos
	return cell_center(GameState.key_to_cell(job["cell"])) + Vector2(-26, -4)


func _update_farmer(delta: float) -> void:
	var target := _farmer_target()
	var d := target - _farmer_pos
	if d.length() > 1.0:
		_farmer_flip = d.x < 0.0
		_farmer_pos += d.limit_length(FARMER_SPEED * delta)


func _draw_farmer() -> void:
	var p := _farmer_pos
	var working := not GameState.current_plow_job().is_empty() and p.distance_to(_farmer_target()) < 2.0
	var walking := p.distance_to(_farmer_target()) >= 2.0
	var bob := sin(_clock * 12.0) * 2.0 if walking else 0.0
	var dir := -1.0 if _farmer_flip else 1.0
	# ombra
	draw_set_transform(p + Vector2(0, 2), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)
	# gambe e corpo
	draw_line(p + Vector2(-4, 0), p + Vector2(-4, -14 + bob), Color("3b4a6b"), 4.0)
	draw_line(p + Vector2(4, 0), p + Vector2(4, -14 - bob), Color("3b4a6b"), 4.0)
	draw_rect(Rect2(p + Vector2(-8, -34 + bob), Vector2(16, 22)), Color("c0503a"))
	# testa e cappello di paglia
	draw_circle(p + Vector2(0, -42 + bob), 8.0, Color("f0c9a0"))
	draw_rect(Rect2(p + Vector2(-13, -50 + bob), Vector2(26, 4)), Color("e3c26a"))
	draw_rect(Rect2(p + Vector2(-7, -56 + bob), Vector2(14, 7)), Color("e3c26a"))
	# zappa: oscilla mentre lavora
	var angle := (sin(_clock * 6.0) * 0.6 + 0.3) if working else 0.5
	var hand := p + Vector2(8 * dir, -24 + bob)
	var tip := hand + Vector2(cos(angle) * 26 * dir, sin(angle) * 26)
	draw_line(hand, tip, Color("8a5a2b"), 3.0)
	draw_line(tip, tip + Vector2(6 * dir, 6), Color("9aa0a6"), 4.0)


# --- Disegno ----------------------------------------------------------------

func _draw() -> void:
	var grid := GameState.grid_size
	# Bordo d'erba attorno alla griglia
	var border := PackedVector2Array([
		cell_to_local(Vector2i(0, 0)) + Vector2(0, -12),
		cell_to_local(Vector2i(grid.x, 0)) + Vector2(18, 0),
		cell_to_local(Vector2i(grid.x, grid.y)) + Vector2(0, 12),
		cell_to_local(Vector2i(0, grid.y)) + Vector2(-18, 0),
	])
	draw_colored_polygon(border, COLOR_GRASS)
	draw_polyline(border + PackedVector2Array([border[0]]), COLOR_GRASS_EDGE, 3.0)

	# Prima il terreno, poi le piante in ordine di profondità (dal fondo).
	for y in grid.y:
		for x in grid.x:
			_draw_ground(Vector2i(x, y))
	var farmer_drawn := false
	var farmer_depth := _farmer_pos.y
	for depth in grid.x + grid.y - 1:
		for x in grid.x:
			var y := depth - x
			if y < 0 or y >= grid.y:
				continue
			var cell := Vector2i(x, y)
			if not farmer_drawn and cell_center(cell).y > farmer_depth:
				_draw_farmer()
				farmer_drawn = true
			_draw_plant(cell)
	if not farmer_drawn:
		_draw_farmer()

	for y in grid.y:
		for x in grid.x:
			_draw_labels(Vector2i(x, y))
	_draw_popups()


func _draw_ground(cell: Vector2i) -> void:
	var poly := _diamond(cell)
	var plot := GameState.get_plot(cell)
	var checker := (cell.x + cell.y) % 2 == 0
	if GameState.is_tilled(cell):
		var wet: bool = not plot.is_empty() and plot.get("watered", false)
		draw_colored_polygon(poly, COLOR_SOIL_WET if wet else COLOR_SOIL)
		# solchi
		var c := cell_center(cell)
		for i in [-1, 0, 1]:
			var o := Vector2(i * TILE_W * 0.14, i * TILE_H * 0.14)
			draw_line(c + o + Vector2(-TILE_W * 0.2, -TILE_H * 0.2) * 0.9, c + o + Vector2(TILE_W * 0.2, TILE_H * 0.2) * 0.9, COLOR_FURROW, 2.0)
		draw_polyline(poly + PackedVector2Array([poly[0]]), COLOR_FURROW, 1.5)
	else:
		draw_colored_polygon(poly, COLOR_GRASS_LIGHT if checker else COLOR_GRASS)
		draw_polyline(poly + PackedVector2Array([poly[0]]), COLOR_GRASS_EDGE.lerp(COLOR_GRASS, 0.5), 1.0)
		if GameState.is_plow_queued(cell):
			var prog := GameState.plow_progress(cell)
			if prog > 0.0:
				draw_colored_polygon(_diamond(cell, (1.0 - prog) * 12.0 + 2.0), COLOR_SOIL.lerp(COLOR_GRASS, 0.4))
			_draw_dashed_diamond(cell, COLOR_QUEUED)
	if cell == _hover:
		draw_colored_polygon(poly, COLOR_HOVER)


func _draw_dashed_diamond(cell: Vector2i, color: Color) -> void:
	var poly := _diamond(cell, 4.0)
	for i in 4:
		draw_dashed_line(poly[i], poly[(i + 1) % 4], color, 2.0, 6.0)


func _draw_plant(cell: Vector2i) -> void:
	var plot := GameState.get_plot(cell)
	if plot.is_empty():
		return
	var crop := GameData.crop(plot["crop"])
	var progress := GameState.plot_progress(cell)
	var color := Color(crop["color"])
	var c := cell_center(cell)
	match crop["kind"]:
		"tree":
			var h := lerpf(14.0, 34.0, minf(progress * 2.0, 1.0))
			draw_line(c, c + Vector2(0, -h), Color("6b4a2b"), 6.0)
			var crown := c + Vector2(0, -h - 12)
			draw_circle(crown, lerpf(10.0, 24.0, minf(progress * 2.0, 1.0)), Color("4f7d2a"))
			if progress >= 0.5:
				var fruit_r := lerpf(2.0, 5.0, (progress - 0.5) * 2.0)
				for o in [Vector2(-10, -4), Vector2(9, -8), Vector2(2, 8), Vector2(-4, -14), Vector2(12, 6)]:
					draw_circle(crown + o, fruit_r, color)
		"bush":
			var r := lerpf(8.0, 20.0, progress)
			draw_circle(c + Vector2(0, -r * 0.7), r, Color("3f6b2a"))
			if progress >= 0.6:
				for o in [Vector2(-8, -4), Vector2(7, -9), Vector2(1, 4), Vector2(-3, -14)]:
					draw_circle(c + Vector2(0, -r * 0.7) + o * (r / 20.0), 3.5, color)
		_:
			var height := lerpf(6.0, 26.0, progress)
			for o in [Vector2(-18, 0), Vector2(18, 0), Vector2(0, -9), Vector2(0, 9)]:
				var base: Vector2 = c + o
				draw_line(base, base + Vector2(0, -height), COLOR_STEM, 3.0)
				if progress >= 1.0:
					draw_circle(base + Vector2(0, -height), 6.0, color)
				else:
					draw_circle(base + Vector2(0, -height), 3.0, COLOR_STEM.lightened(0.3))


func _draw_labels(cell: Vector2i) -> void:
	var plot := GameState.get_plot(cell)
	var c := cell_center(cell)
	if plot.is_empty():
		if GameState.is_plow_queued(cell):
			var job := GameState.current_plow_job()
			if not job.is_empty() and job["cell"] == GameState.plot_key(cell):
				var left := maxi(0, ceili(float(job["end"]) - GameState.now()))
				_label(c + Vector2(0, -20), "%ds" % left, Color.WHITE)
		return
	# icone di stato: goccia e concime
	if plot.get("watered", false):
		_draw_drop(c + Vector2(TILE_W * 0.3, -6), 5.0)
	if plot.get("fertilized", false):
		draw_circle(c + Vector2(-TILE_W * 0.3, -4), 5.0, COLOR_FERTILIZER)
		draw_circle(c + Vector2(-TILE_W * 0.3 + 5, -8), 3.0, COLOR_FERTILIZER.darkened(0.2))
	var top := -44.0 if GameData.crop(plot["crop"])["kind"] == "tree" else -34.0
	if GameState.is_ready(cell):
		_label(c + Vector2(0, top - 3.0 * sin(_clock * 5.0)), "Pronto!", Color("fff3b0"))
	else:
		_label(c + Vector2(0, top), GameData.format_time(GameState.plot_seconds_left(cell)), Color.WHITE)


func _draw_drop(p: Vector2, r: float) -> void:
	draw_circle(p, r, COLOR_WATER)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.8, -r * 0.4), p + Vector2(0, -r * 2.2), p + Vector2(r * 0.8, -r * 0.4)]), COLOR_WATER)


func _draw_popups() -> void:
	for p in _popups:
		var k: float = p["t"] / POPUP_TIME
		var col: Color = p["color"]
		col.a = 1.0 - k
		_label(p["pos"] + Vector2(0, -40.0 * k), p["text"], col, 18)


func _label(pos: Vector2, text: String, color: Color, size := 13) -> void:
	var w := 120.0
	draw_string_outline(_font, pos + Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_CENTER, w, size, 4, Color(0.15, 0.1, 0.05, color.a * 0.8))
	draw_string(_font, pos + Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_CENTER, w, size, color)
