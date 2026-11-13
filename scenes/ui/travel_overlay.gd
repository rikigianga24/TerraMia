class_name TravelOverlay
extends Control
## Breve caricamento tra fattoria e borgo: il cielo si riempie di nuvole che
## scorrono, con la scritta "In viaggio". A metà (schermo coperto) si cambia
## mappa, poi le nuvole si aprono.

signal covered   ## lo schermo è coperto: è il momento di cambiare mappa

const DURATION := 1.4

var _t := -1.0
var _font: Font
var _switched := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = load("res://assets/fonts/Fredoka-SemiBold.ttf")
	visible = false


func play() -> void:
	_t = 0.0
	_switched = false
	visible = true


func is_playing() -> bool:
	return _t >= 0.0


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta / DURATION
	if _t >= 0.45 and not _switched:
		_switched = true
		covered.emit()
	if _t >= 1.0:
		_t = -1.0
		visible = false
	queue_redraw()


func _draw() -> void:
	if _t < 0.0:
		return
	var s := get_viewport_rect().size
	# copertura: sale fino a 0.35, resta, si apre dopo 0.7
	var cover := clampf(_t / 0.35, 0.0, 1.0) if _t < 0.7 else clampf((1.0 - _t) / 0.3, 0.0, 1.0)
	var e := cover * cover * (3.0 - 2.0 * cover)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.62, 0.8, 0.93, e))
	# nuvole che arrivano dai lati e scorrono
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 22:
		var row := float(i % 6) / 5.0
		var from_left := i % 2 == 0
		var y := s.y * (0.05 + row * 0.9) + rng.randf_range(-30, 30)
		var r := rng.randf_range(70, 140)
		var home := rng.randf_range(-0.1, 1.1) * s.x
		var off := (1.0 - e) * (s.x * 0.8 + r * 2.0) * (-1.0 if from_left else 1.0)
		var drift := sin(_t * 3.0 + i) * 20.0
		_cloud(Vector2(home + off + drift, y), r)
	if e > 0.6:
		var a := (e - 0.6) / 0.4
		var text := tr("UI_TRAVELING") + ".".repeat(1 + int(_t * 9.0) % 3)
		var size := 40
		var w := _font.get_string_size(tr("UI_TRAVELING") + "...", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var p := Vector2((s.x - w) * 0.5, s.y * 0.5 + 14)
		draw_string_outline(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 10, Color(0.42, 0.28, 0.17, a))
		draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 0.98, 0.93, a))


func _cloud(c: Vector2, r: float) -> void:
	var shade := Color(0.86, 0.9, 0.96)
	var white := Color(1, 1, 1)
	for k in [[Vector2(-0.6, 0.15), 0.55], [Vector2(0.55, 0.2), 0.5], [Vector2(0, 0), 0.7], [Vector2(-0.25, -0.3), 0.5], [Vector2(0.3, -0.25), 0.45]]:
		draw_circle(c + k[0] * r + Vector2(0, r * 0.08), r * k[1], shade)
	for k in [[Vector2(-0.6, 0.1), 0.5], [Vector2(0.55, 0.15), 0.45], [Vector2(0, -0.05), 0.65], [Vector2(-0.25, -0.35), 0.45], [Vector2(0.3, -0.3), 0.4]]:
		draw_circle(c + k[0] * r, r * k[1], white)
