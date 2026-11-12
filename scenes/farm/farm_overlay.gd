class_name FarmOverlay
extends Node2D
## Etichette della fattoria disegnate sopra il filtro pittorico: tempi di
## crescita, fumetti "pronto", icone di acqua e concime, scritte del raccolto.
## Segue la posizione della fattoria e legge i dati da lei.

const ICON_DROP := preload("res://assets/graphics/icons/drop.png")
const ICON_FERTILIZER := preload("res://assets/graphics/icons/fertilizer.png")

var farm: Farm
var _font_bold: Font
var _pill_style: StyleBoxFlat


func _ready() -> void:
	_font_bold = load("res://assets/fonts/Fredoka-SemiBold.ttf")
	_pill_style = StyleBoxFlat.new()
	_pill_style.set_corner_radius_all(10)
	_pill_style.anti_aliasing = true


func _process(_delta: float) -> void:
	position = farm.position
	queue_redraw()


func _draw() -> void:
	var grid := GameData.world_size()
	for y in grid.y:
		for x in grid.x:
			if GameState.is_in_grid(Vector2i(x, y)):
				_draw_labels(Vector2i(x, y))
	_draw_sign_labels()
	_draw_popups()


## Scritta "In vendita" sui cartelli dei lotti che si possono comprare.
func _draw_sign_labels() -> void:
	var n := GameData.SECTOR_SIZE
	var text := tr("LAND_SIGN")
	for sy in GameData.WORLD_SECTORS.y:
		for sx in GameData.WORLD_SECTORS.x:
			var sector := Vector2i(sx, sy)
			if GameState.is_sector_owned(sector) or not GameState.is_sector_buyable(sector):
				continue
			var p := farm.cell_to_local(Vector2(sx * n + n * 0.5, sy * n + n * 0.5))
			draw_string(_font_bold, p + Vector2(-26, -40), text, HORIZONTAL_ALIGNMENT_CENTER, 52, 11, Color("fbf3e2"))


func _draw_labels(cell: Vector2i) -> void:
	var plot := GameState.get_plot(cell)
	var c := farm.cell_center(cell)
	if plot.is_empty():
		var job := GameState.current_plow_job()
		if not job.is_empty() and job["cell"] == GameState.plot_key(cell):
			var left := maxi(0, ceili(float(job["end"]) - GameState.now()))
			_pill(c + Vector2(0, -4), "%ds" % left, GameState.plow_progress(cell))
		return
	var kind: String = GameData.crop(plot["crop"])["kind"]
	var top := -86.0 if kind == "tree" else (-48.0 if kind == "bush" else -40.0)
	# da annaffiare: goccia che pulsa sopra il sacchetto (o l'albero)
	if GameState.needs_water(cell):
		var k := 1.0 + sin(farm._clock * 4.0 + cell.x + cell.y) * 0.12
		var bubble := c + Vector2(0, top + 4.0)
		draw_circle(bubble, 13.0 * k, Color("f6eedb"))
		draw_arc(bubble, 13.0 * k, 0.0, TAU, 32, Color("7fb6d8"), 1.5, true)
		draw_texture_rect(ICON_DROP, Rect2(bubble - Vector2(9, 9) * k, Vector2(18, 18) * k), false)
		return
	if plot.get("fertilized", false):
		draw_texture_rect(ICON_FERTILIZER, Rect2(c + Vector2(-46, -6), Vector2(18, 18)), false)
	if GameState.is_ready(cell):
		_ready_bubble(c + Vector2(0, top - 4.0 * absf(sin(farm._clock * 3.5 + cell.x))), Color(GameData.crop(plot["crop"])["color"]))
	elif cell == farm._hover or plot.get("watered", false) or GameState.plot_seconds_left(cell) < 60:
		_pill(c + Vector2(0, top + 6), GameData.format_time(GameState.plot_seconds_left(cell)), GameState.plot_progress(cell))


## Fumetto color carta con il frutto: la pianta è pronta.
func _ready_bubble(p: Vector2, color: Color) -> void:
	var paper := Color("f6eedb")
	draw_circle(p + Vector2(0, 2), 13.0, Color(0.25, 0.17, 0.1, 0.22))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-5, 9), p + Vector2(5, 9), p + Vector2(0, 17)]), paper)
	draw_circle(p, 13.0, paper)
	draw_arc(p, 13.0, 0.0, TAU, 32, Color("b89a72"), 1.5, true)
	draw_circle(p + Vector2(0.8, 0.8), 7.0, color.darkened(0.3))
	draw_circle(p, 7.0, color)
	draw_circle(p + Vector2(-2.4, -2.4), 2.0, Color(1, 1, 1, 0.45))


## Pastiglia scura con il tempo e una barra di avanzamento sotto.
func _pill(p: Vector2, text: String, progress: float) -> void:
	var size := 14
	var w := _font_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 16.0
	var rect := Rect2(p - Vector2(w * 0.5, 11), Vector2(w, 20))
	_pill_style.bg_color = Color(0.27, 0.19, 0.13, 0.85)
	draw_style_box(_pill_style, rect)
	draw_string(_font_bold, rect.position + Vector2(8, 15), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("f6eedb"))
	var bar := Rect2(rect.position + Vector2(5, 17), Vector2((w - 10) * clampf(progress, 0.0, 1.0), 3))
	draw_rect(bar, Color("b5c27e"))


func _draw_popups() -> void:
	for p in farm._popups:
		var k: float = p["t"] / Farm.POPUP_TIME
		var col: Color = p["color"].lightened(0.35)
		col.a = 1.0 - k * k
		var pos: Vector2 = p["pos"] + Vector2(0, -46.0 * (1.0 - pow(1.0 - k, 2.0)))
		var w := 160.0
		draw_string_outline(_font_bold, pos + Vector2(-w * 0.5, 0), p["text"], HORIZONTAL_ALIGNMENT_CENTER, w, 22, 6, Color(0.27, 0.19, 0.13, col.a))
		draw_string(_font_bold, pos + Vector2(-w * 0.5, 0), p["text"], HORIZONTAL_ALIGNMENT_CENTER, w, 22, col)
