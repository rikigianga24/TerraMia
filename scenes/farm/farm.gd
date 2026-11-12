class_name Farm
extends Node2D
## La fattoria: griglia isometrica di quadranti (6×6 all'inizio).
## Grafica vettoriale provvisoria disegnata in _draw(); andrà sostituita dagli SVG.
##
## Tocco su un quadrante vuoto: pianta il seme selezionato.
## Tocco su un quadrante pronto: raccoglie.

signal cell_tapped(cell: Vector2i)

const TILE_W := 112.0
const TILE_H := 56.0

const COLOR_SOIL := Color("8a6a43")
const COLOR_SOIL_DARK := Color("6e5233")
const COLOR_GRASS := Color("8fb35a")
const COLOR_GRASS_EDGE := Color("5c7a33")
const COLOR_HOVER := Color(1, 1, 1, 0.25)
const CROP_COLORS := {
	"grano": Color("e8c547"),
	"pomodoro": Color("d9412b"),
}

var selected_crop: String = "grano"
var _hover := Vector2i(-1, -1)
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	GameState.changed.connect(queue_redraw)
	get_viewport().size_changed.connect(_recenter)
	_recenter()


func _process(_delta: float) -> void:
	# I timer sono reali: ridisegna per mostrare la crescita.
	queue_redraw()


func _recenter() -> void:
	var vp := get_viewport_rect().size
	var grid_h := (GameState.grid_size.x + GameState.grid_size.y) * TILE_H * 0.5
	position = Vector2(vp.x * 0.5, (vp.y - grid_h) * 0.5)


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


func _diamond(cell: Vector2i) -> PackedVector2Array:
	var top := cell_to_local(cell)
	return PackedVector2Array([
		top,
		top + Vector2(TILE_W * 0.5, TILE_H * 0.5),
		top + Vector2(0, TILE_H),
		top + Vector2(-TILE_W * 0.5, TILE_H * 0.5),
	])


# --- Input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseMotion:
		_hover = local_to_cell(get_local_mouse_position())
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := local_to_cell(get_local_mouse_position())
		if GameState.is_in_grid(cell):
			_tap(cell)
			get_viewport().set_input_as_handled()


func _tap(cell: Vector2i) -> void:
	var plot := GameState.get_plot(cell)
	if plot.is_empty():
		GameState.plant(cell, selected_crop)
	elif GameState.plot_progress(cell) >= 1.0:
		GameState.harvest(cell)
	cell_tapped.emit(cell)


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

	for y in grid.y:
		for x in grid.x:
			_draw_cell(Vector2i(x, y))


func _draw_cell(cell: Vector2i) -> void:
	var poly := _diamond(cell)
	var plot := GameState.get_plot(cell)
	draw_colored_polygon(poly, COLOR_SOIL if plot.is_empty() else COLOR_SOIL_DARK)
	draw_polyline(poly + PackedVector2Array([poly[0]]), COLOR_GRASS_EDGE, 1.5)
	if cell == _hover:
		draw_colored_polygon(poly, COLOR_HOVER)
	if plot.is_empty():
		return

	var progress := GameState.plot_progress(cell)
	var center := cell_center(cell)
	var color: Color = CROP_COLORS.get(plot["crop"], Color.WHITE)
	var stem := Color("4f7d2a")
	var height := lerpf(6.0, 26.0, progress)
	# Piantine: quattro steli che crescono, frutto colorato quando maturo
	for offset in [Vector2(-18, 0), Vector2(18, 0), Vector2(0, -9), Vector2(0, 9)]:
		var base: Vector2 = center + offset
		draw_line(base, base + Vector2(0, -height), stem, 3.0)
		if progress >= 1.0:
			draw_circle(base + Vector2(0, -height), 6.0, color)
		else:
			draw_circle(base + Vector2(0, -height), 3.0, stem.lightened(0.3))

	if progress >= 1.0:
		draw_string(_font, center + Vector2(-30, -36), "Pronto!", HORIZONTAL_ALIGNMENT_CENTER, 60, 14, Color.WHITE)
	else:
		var left := GameState.plot_seconds_left(cell)
		var text := "%d:%02d" % [left / 60, left % 60]
		draw_string(_font, center + Vector2(-30, -34), text, HORIZONTAL_ALIGNMENT_CENTER, 60, 13, Color.WHITE)
