extends Node
## Impostazioni del dispositivo (non della partita): lingua e volumi.
## Stanno in user://settings.cfg, separate dal salvataggio del gioco.
##
## Lingua all'avvio: quella scelta dal giocatore, altrimenti quella del
## sistema se è tra le supportate, altrimenti l'inglese.
##
## Volumi: due bus audio, "Music" e "SFX", creati qui se il progetto non li
## ha. Musica ed effetti vanno suonati su questi bus (AudioStreamPlayer.bus).

signal language_changed(code: String)

const PATH := "user://settings.cfg"
const LANGUAGES := ["it", "en", "fr", "es"]
const FALLBACK := "en"
const BUSES := ["Music", "SFX"]

var language: String = FALLBACK
var volumes := {"Music": 0.8, "SFX": 0.8}   ## 0..1


func _ready() -> void:
	var cfg := ConfigFile.new()
	var saved := ""
	if cfg.load(PATH) == OK:
		saved = str(cfg.get_value("general", "language", ""))
		for bus in BUSES:
			volumes[bus] = clampf(float(cfg.get_value("audio", bus, volumes[bus])), 0.0, 1.0)
	var system := OS.get_locale_language()
	if saved in LANGUAGES:
		language = saved
	elif system in LANGUAGES:
		language = system
	else:
		language = FALLBACK
	TranslationServer.set_locale(language)
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
		_apply_volume(bus)


func set_language(code: String) -> void:
	if not code in LANGUAGES or code == language:
		return
	language = code
	TranslationServer.set_locale(code)
	_save("general", "language", code)
	language_changed.emit(code)


func set_volume(bus: String, value: float) -> void:
	if not bus in BUSES:
		return
	volumes[bus] = clampf(value, 0.0, 1.0)
	_apply_volume(bus)
	_save("audio", bus, volumes[bus])


func _apply_volume(bus: String) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(volumes[bus], 0.0001)))
	AudioServer.set_bus_mute(i, volumes[bus] <= 0.001)


func _save(section: String, key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value(section, key, value)
	cfg.save(PATH)


## Nome della lingua scritto in quella lingua ("Français", "Español"...).
func language_name(code: String) -> String:
	var t := TranslationServer.get_translation_object(code)
	return t.get_message("LANG_NAME") if t else code
