extends Node
## Impostazioni del dispositivo (non della partita): per ora la lingua.
## Stanno in user://settings.cfg, separate dal salvataggio del gioco.
##
## Lingua all'avvio: quella scelta dal giocatore, altrimenti quella del
## sistema se è tra le supportate, altrimenti l'inglese.

signal language_changed(code: String)

const PATH := "user://settings.cfg"
const LANGUAGES := ["it", "en", "fr", "es"]
const FALLBACK := "en"

var language: String = FALLBACK


func _ready() -> void:
	var cfg := ConfigFile.new()
	var saved := ""
	if cfg.load(PATH) == OK:
		saved = str(cfg.get_value("general", "language", ""))
	var system := OS.get_locale_language()
	if saved in LANGUAGES:
		language = saved
	elif system in LANGUAGES:
		language = system
	else:
		language = FALLBACK
	TranslationServer.set_locale(language)


func set_language(code: String) -> void:
	if not code in LANGUAGES or code == language:
		return
	language = code
	TranslationServer.set_locale(code)
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("general", "language", code)
	cfg.save(PATH)
	language_changed.emit(code)


## Nome della lingua scritto in quella lingua ("Français", "Español"...).
func language_name(code: String) -> String:
	var t := TranslationServer.get_translation_object(code)
	return t.get_message("LANG_NAME") if t else code
