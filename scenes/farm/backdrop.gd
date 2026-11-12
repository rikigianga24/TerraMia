class_name Backdrop
extends Control
## Sfondo: cielo sfumato, colline in lontananza con cipressi e il paese su un
## colle, nuvole che scorrono piano, e il prato fino in primo piano, sullo
## stesso piano della fattoria. Tutto disegnato da codice.

const SKY_TOP := Color("86bde0")
const SKY_BOTTOM := Color("f3e7c8")
const HILL_FAR := Color("b4cc86")
const HILL_MID := Color("9cbf62")
const HILL_NEAR := Color("a2c45c")
const GROUND_FAR := Color("6c8934")   ## come la banda verde in fondo alle colline
const GROUND_NEAR := Color("8db347")
## Linea dell'orizzonte, in frazione dell'altezza dello schermo: sotto c'è il
## prato su cui sta la fattoria.
const HORIZON := 0.40
const SKY_TEX: Texture2D = preload("res://assets/graphics/backdrop/cielo.jpg")
const HILLS_TEX: Texture2D = preload("res://assets/graphics/backdrop/colline.png")
const HILLS_BAND := 520.0 / 672.0

## "farm": colline e cipressi; "borgo": il paese sulla collina.
var mode := "farm":
	set(value):
		mode = value
		queue_redraw()
var _clock := 0.0
var _sky: GradientTexture2D
var _ground: GradientTexture2D


func _ready() -> void:
	# Il genitore è un CanvasLayer: niente ancore, la dimensione segue la viewport.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = get_viewport_rect().size
	get_viewport().size_changed.connect(func() -> void: size = get_viewport_rect().size)
	var g := Gradient.new()
	g.set_color(0, SKY_TOP)
	g.set_color(1, SKY_BOTTOM)
	_sky = GradientTexture2D.new()
	_sky.gradient = g
	_sky.fill_from = Vector2(0, 0)
	_sky.fill_to = Vector2(0, 1)
	_sky.width = 4
	_sky.height = 256
	var gg := Gradient.new()
	gg.set_color(0, GROUND_FAR)
	gg.set_color(1, GROUND_NEAR)
	_ground = GradientTexture2D.new()
	_ground.gradient = gg
	_ground.fill_from = Vector2(0, 0)
	_ground.fill_to = Vector2(0, 1)
	_ground.width = 4
	_ground.height = 256


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	var horizon := s.y * HORIZON
	if SKY_TEX != null and HILLS_TEX != null:
		_draw_illustrated(s, horizon)
	else:
		_draw_painted(s, horizon)
	# il prato su cui sta la fattoria: dall'orizzonte (più chiaro, velato) a
	# primo piano (più pieno)
	draw_texture_rect(_ground, Rect2(0, horizon, s.x, s.y - horizon), false)
	_meadow_strokes(s, horizon)


## Cielo e colline illustrati (assets/graphics/backdrop). Le colline sono
## larghe quanto lo schermo e la loro banda verde finisce sull'orizzonte.
func _draw_illustrated(s: Vector2, horizon: float) -> void:
	var sky_h := horizon + 60.0
	var sky_k := maxf(s.x / SKY_TEX.get_width(), sky_h / SKY_TEX.get_height())
	var sky_size := SKY_TEX.get_size() * sky_k
	draw_texture_rect(SKY_TEX, Rect2(Vector2((s.x - sky_size.x) * 0.5, sky_h - sky_size.y), sky_size), false)
	var k := s.x / HILLS_TEX.get_width()
	var hills_size := HILLS_TEX.get_size() * k
	# la banda verde piatta dell'immagine inizia a HILLS_BAND (frazione dell'altezza)
	var y := horizon + 6.0 - hills_size.y * HILLS_BAND
	draw_texture_rect(HILLS_TEX, Rect2(Vector2(0, y), hills_size), false)


## Sfondo disegnato da codice, se mancano le illustrazioni.
func _draw_painted(s: Vector2, horizon: float) -> void:
	draw_texture_rect(_sky, Rect2(Vector2.ZERO, Vector2(s.x, horizon + 40)), false)
	var sun := Vector2(s.x * 0.84, s.y * 0.11)
	draw_circle(sun, 56.0, Color(1, 0.94, 0.8, 0.25))
	draw_circle(sun, 34.0, Color(0.98, 0.9, 0.68, 0.9))
	for i in 4:
		var speed := 6.0 + i * 2.5
		var x := fposmod(i * 360.0 + _clock * speed, s.x + 300.0) - 150.0
		_cloud(Vector2(x, s.y * (0.05 + 0.04 * (i % 3))), 0.6 + 0.12 * (i % 2))
	_hills(s, horizon - 34.0, 26.0, 0.004, 1.3, HILL_FAR)
	_cypresses(s, horizon - 34.0)
	if mode == "farm":
		_village(s, horizon - 22.0, 0.42, 0.60, 0.86)
	_hills(s, horizon - 8.0, 14.0, 0.006, 4.0, HILL_MID)


## Ciuffi d'erba e fiorellini sparsi, sempre negli stessi posti.
func _meadow_strokes(s: Vector2, horizon: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 260:
		var t := rng.randf()
		var y := horizon + 6.0 + (s.y - horizon) * t * t
		var x := rng.randf() * s.x
		var k := 0.5 + t * 1.2  # più grandi in primo piano
		var c := HILL_NEAR.darkened(0.12) if rng.randf() < 0.7 else HILL_NEAR.lightened(0.12)
		draw_line(Vector2(x, y), Vector2(x - 2 * k, y - 6 * k), c, 1.6 * k)
		draw_line(Vector2(x, y), Vector2(x + 2.5 * k, y - 5 * k), c, 1.6 * k)
		if rng.randf() < 0.08:
			draw_circle(Vector2(x + 4 * k, y - 4 * k), 1.8 * k, [Color("f4ecd8"), Color("e9c46a"), Color("e8a7a0")][rng.randi() % 3])


func _hills(s: Vector2, base: float, amp: float, freq: float, phase: float, color: Color) -> void:
	var pts := PackedVector2Array()
	var step := 24.0
	var x := 0.0
	while x <= s.x + step:
		pts.append(Vector2(x, base - amp * (0.6 * sin(x * freq + phase) + 0.4 * sin(x * freq * 2.3 + phase * 1.7))))
		x += step
	pts.append(Vector2(s.x + step, s.y))
	pts.append(Vector2(0, s.y))
	draw_colored_polygon(pts, color)


func _cypresses(s: Vector2, base: float) -> void:
	for i in 9:
		var x := s.x * (0.05 + i * 0.11) + (i % 3) * 14.0
		var y := base - 36.0 * (0.6 * sin(x * 0.004 + 1.3) + 0.4 * sin(x * 0.0092 + 2.21)) + 4.0
		var h := 34.0 + (i % 3) * 8.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, y - h), Vector2(x + 6, y - h * 0.4), Vector2(x + 4, y), Vector2(x - 4, y), Vector2(x - 6, y - h * 0.4)]), Color("4f7a3e"))


func _cloud(p: Vector2, k: float) -> void:
	var c := Color(1, 0.98, 0.93, 0.8)
	draw_circle(p + Vector2(-30, 6) * k, 22 * k, c)
	draw_circle(p + Vector2(0, -6) * k, 30 * k, c)
	draw_circle(p + Vector2(32, 4) * k, 24 * k, c)
	draw_rect(Rect2(p + Vector2(-30, 6) * k, Vector2(62, 22) * k), c)


## Il borgo sulla collina: case color sabbia con tetti in coppi e un campanile.
func _village(s: Vector2, base: float, k: float, from: float, to: float) -> void:
	var walls := [Color("f0d2a6"), Color("e8c08f"), Color("f6e0bd"), Color("e2b07c")]
	var x := s.x * from
	var i := 0
	var mid := s.x * (from + to) * 0.5
	draw_set_transform(Vector2.ZERO)
	while x < s.x * to:
		var w := (54.0 + (i * 37) % 40) * k
		var h := (48.0 + (i * 53) % 46) * k
		var y := base - absf(x - mid) * 0.08 * k
		if i == 4:
			# campanile
			draw_rect(Rect2(x, y - 150 * k, 34 * k, 150 * k), Color("e2b07c"))
			draw_rect(Rect2(x + 9 * k, y - 132 * k, 16 * k, 22 * k), Color("6b4a2b"))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 4 * k, y - 150 * k), Vector2(x + 17 * k, y - 176 * k), Vector2(x + 38 * k, y - 150 * k)]), Color("b8573a"))
			x += 40.0 * k
		draw_rect(Rect2(x, y - h, w, h), walls[i % walls.size()])
		draw_rect(Rect2(x + w * 0.62, y - h, w * 0.38, h), Color(0, 0, 0, 0.07))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 5 * k, y - h), Vector2(x + w * 0.5, y - h - 18 * k), Vector2(x + w + 5 * k, y - h)]), Color("c0603e"))
		for j in int(w / (22.0 * k)):
			draw_rect(Rect2(x + (8 + j * 20) * k, y - h + 14 * k, 9 * k, 12 * k), Color("6e8fa8"))
			draw_rect(Rect2(x + (6 + j * 20) * k, y - h + 14 * k, 3 * k, 12 * k), Color("5e7a3a"))
		x += w + 4.0 * k
		i += 1
