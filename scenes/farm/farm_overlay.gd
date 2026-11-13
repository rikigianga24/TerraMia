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
	_draw_object_marks()
	_draw_task_marks()
	_draw_popups()


const TASK_ICONS := {"plant": "seeds", "water": "drop", "fertilize": "fertilizer", "harvest": "hand", "chest": "coin",
	"bottle": "drop", "feed": "seeds", "collect": "hand"}


## Lavori in coda: un'icona trasparente sul quadrante, finché il contadino
## non ci arriva.
func _draw_task_marks() -> void:
	for t in farm.pending_tasks():
		var c := farm.cell_center(t["cell"])
		var icon := UiKit.icon(TASK_ICONS.get(t["kind"], "hand"))
		draw_circle(c + Vector2(0, -8), 15.0, Color(1, 0.97, 0.9, 0.55))
		draw_texture_rect(icon, Rect2(c + Vector2(-12, -20), Vector2(24, 24)), false, Color(1, 1, 1, 0.8))


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
	elif cell == farm._hover or GameState.plot_seconds_left(cell) < 60:
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



const PRODUCT_SPRITES := {"uova": "item_uova"}
const PRODUCT_COLORS := {"uova": Color("f4ecd8"), "latte": Color("e8f2f8"), "lana": Color("efe6d2")}


## Indicatori sopra animali e strutture.
func _draw_object_marks() -> void:
	for o in GameState.placed:
		var cell := GameState.key_to_cell(o["cell"])
		var size := GameData.footprint(o["kind"], o["type"])
		var c := farm.cell_center(cell)
		var hover := Rect2i(cell, size).has_point(farm._hover)
		match o["kind"]:
			"animal":
				var st := GameState.animal_state(o)
				var top := c + Vector2(0, -58 if o["type"] == "mucca" else -46)
				match st:
					"bottle":
						_bubble(top)
						_bottle_icon(top)
						_pill(top + Vector2(0, 26), "%d/%d" % [int(o.get("bottles", 0)), int(GameData.ANIMALS[o["type"]]["bottles"])], float(o.get("bottles", 0)) / float(GameData.ANIMALS[o["type"]]["bottles"]))
					"bottle_wait":
						if hover:
							_pill(top, GameData.format_time(GameState.bottle_wait(o)), 0.0)
					"hungry":
						_bubble(top)
						draw_texture_rect(UiKit.crop_icon("grano"), Rect2(top - Vector2(10, 10), Vector2(20, 20)), false)
					"producing":
						if hover:
							_pill(top, GameData.format_time(ceili((1.0 - GameState.animal_progress(o)) * float(GameData.ANIMALS[o["type"]]["time"]))), GameState.animal_progress(o))
					"ready":
						var prod: String = GameData.ANIMALS[o["type"]]["product"]
						var bp := top + Vector2(0, -4.0 * absf(sin(farm._clock * 3.5)))
						_bubble(bp)
						var tex: Texture2D = Sprites.tex(PRODUCT_SPRITES.get(prod, ""))
						if tex != null:
							draw_texture_rect(tex, Rect2(bp - Vector2(11, 11), Vector2(22, 22)), false)
						else:
							var col: Color = PRODUCT_COLORS.get(prod, Color.WHITE)
							draw_circle(bp, 7.0, col)
							draw_arc(bp, 7.0, 0, TAU, 16, col.darkened(0.35), 1.5)
			"structure":
				if not o.has("recipe"):
					continue
				var front := farm.cell_to_local(Vector2(cell + size))
				var top2 := front + Vector2(0, -190)
				var prog := GameState.recipe_progress(int(o["uid"]))
				if prog >= 1.0:
					_bubble(top2 + Vector2(0, -4.0 * absf(sin(farm._clock * 3.5))))
					draw_texture_rect(UiKit.icon("star"), Rect2(top2 - Vector2(10, 14 + 4.0 * absf(sin(farm._clock * 3.5))), Vector2(20, 20)), false)
				else:
					var left := ceili((1.0 - prog) * float(GameData.RECIPES[o["recipe"]]["time"]))
					_pill(top2, GameData.format_time(left), prog)


func _bubble(p: Vector2) -> void:
	var paper := Color("f6eedb")
	draw_circle(p + Vector2(0, 2), 14.0, Color(0.25, 0.17, 0.1, 0.22))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-5, 10), p + Vector2(5, 10), p + Vector2(0, 18)]), paper)
	draw_circle(p, 14.0, paper)
	draw_arc(p, 14.0, 0.0, TAU, 32, Color("b89a72"), 1.5, true)


func _bottle_icon(p: Vector2) -> void:
	draw_rect(Rect2(p + Vector2(-5, -4), Vector2(10, 13)), Color("f8f8f4"))
	draw_rect(Rect2(p + Vector2(-5, -4), Vector2(10, 13)), Color("9fb7c8"), false, 1.2)
	draw_rect(Rect2(p + Vector2(-5, 2), Vector2(10, 7)), Color("fdfdf6"))
	draw_rect(Rect2(p + Vector2(-6, -6), Vector2(12, 3)), Color("5aa3c8"))
	draw_circle(p + Vector2(0, -9), 3.0, Color("e8b48a"))
