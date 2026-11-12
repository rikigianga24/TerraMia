class_name Sprites
extends RefCounted
## Sprite illustrati ritagliati dai fogli (assets/graphics/sprites, vedi
## tools/cut_sprites.py), caricati una volta sola.

static var _cache: Dictionary = {}


static func tex(name: String) -> Texture2D:
	if not _cache.has(name):
		var path := "res://assets/graphics/sprites/%s.png" % name
		_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _cache[name]


## Disegna lo sprite con il centro della base in "foot", largo "width" pixel.
## "base" è quanto sopra il bordo inferiore dello sprite sta il punto
## d'appoggio, in frazione dell'altezza (la base isometrica non è una riga).
static func draw(ci: CanvasItem, name: String, foot: Vector2, width: float, base := 0.06, flip := false, modulate := Color.WHITE) -> void:
	var t := tex(name)
	if t == null:
		return
	var k := width / t.get_width()
	var size := t.get_size() * k
	var pos := foot - Vector2(size.x * 0.5, size.y * (1.0 - base))
	if flip:
		ci.draw_set_transform(Vector2(pos.x + size.x, pos.y), 0.0, Vector2(-1, 1))
		ci.draw_texture_rect(t, Rect2(Vector2.ZERO, size), false, modulate)
		ci.draw_set_transform(Vector2.ZERO)
	else:
		ci.draw_texture_rect(t, Rect2(pos, size), false, modulate)
