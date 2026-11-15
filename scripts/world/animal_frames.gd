class_name AnimalFrames
extends RefCounted
## Animazioni degli animali a fotogrammi (assets/graphics/animals/<animale>,
## preparate con tools/import_frames.py). Ogni animazione ha i suoi fotogrammi
## col punto d'appoggio ("anchor", le zampe) e un'altezza tipica "h", che serve
## a portare tutte le animazioni alla stessa scala.

static var _cache: Dictionary = {}   ## animale -> {animazione -> {"h", "frames": [{tex, anchor}]}}


## Le animazioni dell'animale ({} se non ne ha).
static func anims(animal: String) -> Dictionary:
	if _cache.has(animal):
		return _cache[animal]
	var out := {}
	var path := "res://assets/graphics/animals/%s/anims.json" % animal
	if FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			for name in data:
				var frames: Array = []
				for f in data[name]["frames"]:
					var tex := load(str(f["file"])) as Texture2D
					if tex != null:
						frames.append({"tex": tex, "anchor": Vector2(f["anchor"][0], f["anchor"][1])})
				if not frames.is_empty():
					out[name] = {"h": float(data[name]["h"]), "frames": frames}
	_cache[animal] = out
	return out


static func has(animal: String, anim: String) -> bool:
	return anims(animal).has(anim)


## Disegna il fotogramma "frame" (si ripete in cerchio) con le zampe in "foot".
## "scale_h" è l'altezza tipica di riferimento: l'animazione si scala così che
## quell'altezza diventi "height" pixel (per la beccata si passa quella della
## camminata, perché con la testa giù l'animale è più basso).
static func draw(ci: CanvasItem, animal: String, anim: String, frame: int, foot: Vector2,
		height: float, scale_h: float, flip := false, modulate := Color.WHITE) -> void:
	var a: Dictionary = anims(animal).get(anim, {})
	if a.is_empty():
		return
	var frames: Array = a["frames"]
	var f: Dictionary = frames[posmod(frame, frames.size())]
	var tex: Texture2D = f["tex"]
	var k := height / scale_h
	var size := tex.get_size() * k
	var anchor: Vector2 = f["anchor"] * k
	if flip:
		ci.draw_set_transform(foot, 0.0, Vector2(-1, 1))
		ci.draw_texture_rect(tex, Rect2(-anchor, size), false, modulate)
		ci.draw_set_transform(Vector2.ZERO)
	else:
		ci.draw_texture_rect(tex, Rect2(foot - anchor, size), false, modulate)


static func scale_of(animal: String, anim: String) -> float:
	return float(anims(animal).get(anim, {}).get("h", 1.0))
