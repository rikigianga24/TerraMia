class_name WorldCamera
extends Camera2D
## Telecamera di una mappa (fattoria o borgo): zoom e spostamento.
##
##   zoom          rotellina, pizzico (touch e trackpad), tasti + e -
##   spostamento   trascinando col tasto destro o centrale, due dita sul
##                 trackpad, frecce/WASD; la mappa può chiamare pan_by()
##                 per trascinare con il dito (strumento "mano")
##
## "bounds" è il rettangolo della mappa in coordinate del mondo: la vista non
## esce dai bordi, e la parte alta della mappa resta sotto l'orizzonte dello
## sfondo (Backdrop.HORIZON), che è disegnato a schermo.

const ZOOM_MIN := 0.55
const ZOOM_MAX := 2.2
const ZOOM_STEP := 1.12
const KEY_SPEED := 600.0
const BOTTOM_UI := 150.0     ## pixel di schermo coperti dalla barra in basso

var bounds := Rect2(-500, -300, 1000, 600)
var active := false
var _drag := false


func _ready() -> void:
	ignore_rotation = true
	position_smoothing_enabled = false


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					zoom_at(ZOOM_STEP, event.position)
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					zoom_at(1.0 / ZOOM_STEP, event.position)
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_drag = event.pressed
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _drag:
		pan_by(event.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		zoom_at(event.factor, event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		pan_by(-event.delta * 12.0)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		if event.keycode in [KEY_PLUS, KEY_EQUAL, KEY_KP_ADD]:
			zoom_at(ZOOM_STEP, get_viewport_rect().size * 0.5)
		elif event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
			zoom_at(1.0 / ZOOM_STEP, get_viewport_rect().size * 0.5)


func _process(delta: float) -> void:
	if not active:
		return
	var dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"))
	if dir != Vector2.ZERO:
		position += dir * KEY_SPEED * delta / zoom.x
		clamp_to_bounds()


func activate() -> void:
	active = true
	make_current()
	clamp_to_bounds()


## Sposta la vista come se si trascinasse la mappa di "screen_delta" pixel.
func pan_by(screen_delta: Vector2) -> void:
	position -= screen_delta / zoom.x
	clamp_to_bounds()


## Zoom tenendo fermo il punto dello schermo sotto il cursore.
func zoom_at(factor: float, screen_point: Vector2) -> void:
	var before := screen_to_world(screen_point)
	var z := clampf(zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(z, z)
	var after := screen_to_world(screen_point)
	position += before - after
	clamp_to_bounds()


func screen_to_world(p: Vector2) -> Vector2:
	var vp := get_viewport_rect().size
	return position + (p - vp * 0.5) / zoom.x


func center_on(p: Vector2) -> void:
	position = p
	clamp_to_bounds()


func clamp_to_bounds() -> void:
	var vp := get_viewport_rect().size
	var z := zoom.x
	var half := vp * 0.5 / z
	# Orizzontale: tra "bordo sinistro della mappa al bordo dello schermo" e
	# "bordo destro al bordo dello schermo" (vale sia se la mappa è più
	# larga della vista, sia se è più stretta).
	var a := bounds.position.x + half.x
	var b := bounds.end.x - half.x
	position.x = clampf(position.x, minf(a, b), maxf(a, b))
	# Verticale: tra "bordo alto della mappa sull'orizzonte" e "bordo basso
	# della mappa appena sopra la barra degli strumenti".
	var horizon_y := vp.y * Backdrop.HORIZON
	var top_on_horizon := bounds.position.y + half.y - horizon_y / z
	var bottom_on_bar := bounds.end.y - half.y + BOTTOM_UI / z
	position.y = clampf(position.y, minf(top_on_horizon, bottom_on_bar), maxf(top_on_horizon, bottom_on_bar))
