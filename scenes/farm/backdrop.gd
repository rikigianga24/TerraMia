class_name Backdrop
extends Control
## Sfondo della fattoria: cielo sfumato, colline in lontananza con cipressi
## e nuvole che scorrono piano. Tutto disegnato da codice.

const SKY_TOP := Color("7fb8e0")
const SKY_BOTTOM := Color("dcefe6")
const HILL_FAR := Color("a9c98a")
const HILL_MID := Color("8fb96a")
const HILL_NEAR := Color("9cc866")

## "farm": colline e cipressi; "borgo": il paese sulla collina.
var mode := "farm":
	set(value):
		mode = value
		queue_redraw()
var _clock := 0.0
var _sky: GradientTexture2D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Il genitore è un CanvasLayer: la dimensione va presa dalla viewport.
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


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var s := size
	draw_texture_rect(_sky, Rect2(Vector2.ZERO, s), false)
	# sole
	var sun := Vector2(s.x * 0.84, s.y * 0.16)
	draw_circle(sun, 64.0, Color(1, 0.96, 0.75, 0.25))
	draw_circle(sun, 40.0, Color(1, 0.93, 0.6, 0.9))
	# nuvole
	for i in 4:
		var speed := 6.0 + i * 2.5
		var x := fposmod(i * 360.0 + _clock * speed, s.x + 300.0) - 150.0
		_cloud(Vector2(x, s.y * (0.1 + 0.07 * (i % 3))), 0.7 + 0.15 * (i % 2))
	# colline: tre fasce dalla più lontana
	_hills(s, s.y * 0.40, 36.0, 0.004, 1.3, HILL_FAR)
	_cypresses(s, s.y * 0.40)
	_hills(s, s.y * 0.50, 30.0, 0.006, 4.0, HILL_MID)
	_hills(s, s.y * 0.60, 20.0, 0.005, 2.2, HILL_NEAR)
	draw_rect(Rect2(0, s.y * 0.62, s.x, s.y * 0.38), HILL_NEAR)
	if mode == "borgo":
		_village(s, s.y * 0.93)


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
		draw_colored_polygon(PackedVector2Array([Vector2(x, y - h), Vector2(x + 6, y - h * 0.4), Vector2(x + 4, y), Vector2(x - 4, y), Vector2(x - 6, y - h * 0.4)]), Color("5e8a4a"))


func _cloud(p: Vector2, k: float) -> void:
	var c := Color(1, 1, 1, 0.85)
	draw_circle(p + Vector2(-30, 6) * k, 22 * k, c)
	draw_circle(p + Vector2(0, -6) * k, 30 * k, c)
	draw_circle(p + Vector2(32, 4) * k, 24 * k, c)
	draw_rect(Rect2(p + Vector2(-30, 6) * k, Vector2(62, 22) * k), c)


## Il borgo sulla collina: case color sabbia con tetti in coppi e un campanile.
func _village(s: Vector2, base: float) -> void:
	var walls := [Color("f0d2a6"), Color("e8c08f"), Color("f6e0bd"), Color("e2b07c")]
	var x := s.x * 0.16
	var i := 0
	while x < s.x * 0.86:
		var w := 54.0 + (i * 37) % 40
		var h := 48.0 + (i * 53) % 46
		var y := base - absf(x - s.x * 0.5) * 0.08
		if i == 4:
			# campanile
			draw_rect(Rect2(x, y - 150, 34, 150), Color("e2b07c"))
			draw_rect(Rect2(x + 9, y - 132, 16, 22), Color("6b4a2b"))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 4, y - 150), Vector2(x + 17, y - 176), Vector2(x + 38, y - 150)]), Color("b8573a"))
			x += 40.0
		draw_rect(Rect2(x, y - h, w, h), walls[i % walls.size()])
		draw_rect(Rect2(x + w * 0.62, y - h, w * 0.38, h), Color(0, 0, 0, 0.07))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 5, y - h), Vector2(x + w * 0.5, y - h - 18), Vector2(x + w + 5, y - h)]), Color("c0603e"))
		for k in int(w / 22.0):
			draw_rect(Rect2(x + 8 + k * 20, y - h + 14, 9, 12), Color("6e8fa8"))
			draw_rect(Rect2(x + 6 + k * 20, y - h + 14, 3, 12), Color("5e7a3a"))
		x += w + 4.0
		i += 1
