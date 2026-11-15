extends Node
## Musica di sottofondo e jingle (assets/audio, vedi docs/audio_direction.md).
##
## All'avvio suona il tema "ritorno" (bentornato a casa), poi la musica della
## zona: la fattoria e il borgo hanno ciascuno il proprio brano, che si alterna
## con "ritorno". Cambiando zona i brani si incrociano in dissolvenza. Quando
## si sale di livello parte il jingle sul bus degli effetti e la musica si
## abbassa finché non è finito.
##
## La musica va sul bus "Music", i jingle su "SFX" (creati da Settings), così
## i cursori del volume nelle impostazioni valgono anche qui.

const TRACKS := {
	"fattoria": preload("res://assets/audio/music/fattoria.ogg"),
	"borgo": preload("res://assets/audio/music/borgo.ogg"),
	"ritorno": preload("res://assets/audio/music/ritorno.ogg"),
}
## Zona -> brani in ordine; finito l'ultimo si ricomincia.
const PLAYLISTS := {
	"farm": ["fattoria", "ritorno"],
	"borgo": ["borgo", "ritorno"],
}
const LEVEL_UP := preload("res://assets/audio/sfx/livello.ogg")
const FADE := 2.5          ## secondi della dissolvenza tra due brani
const DUCK_DB := -14.0     ## quanto si abbassa la musica sotto un jingle
const SILENT_DB := -60.0

var area := ""
var _players: Array[AudioStreamPlayer] = []
var _current := 0          ## indice in _players del lettore che suona
var _track := ""           ## brano in corso
var _index := 0            ## posizione nella playlist della zona
var _jingle: AudioStreamPlayer
var _duck: AudioEffectAmplify


func _ready() -> void:
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = SILENT_DB
		p.finished.connect(_on_finished.bind(i))
		add_child(p)
		_players.append(p)
	_jingle = AudioStreamPlayer.new()
	_jingle.bus = "SFX"
	_jingle.finished.connect(_unduck)
	add_child(_jingle)
	# abbassamento sotto i jingle: un amplificatore sul bus della musica, così
	# non si tocca il volume scelto dal giocatore né le dissolvenze
	var bus := AudioServer.get_bus_index("Music")
	if bus >= 0:
		_duck = AudioEffectAmplify.new()
		AudioServer.add_bus_effect(bus, _duck)
	GameState.leveled_up.connect(func(_level: int) -> void: play_jingle())


func _exit_tree() -> void:
	# l'effetto sta nel bus, fuori dall'albero dei nodi: si stacca all'uscita
	var bus := AudioServer.get_bus_index("Music")
	if _duck and bus >= 0:
		for i in AudioServer.get_bus_effect_count(bus):
			if AudioServer.get_bus_effect(bus, i) == _duck:
				AudioServer.remove_bus_effect(bus, i)
				break
	_duck = null
	_jingle.stop()
	_jingle.stream = null
	for pl in _players:
		pl.stop()
		pl.stream = null


## Zona in cui si trova il giocatore ("farm" o "borgo"). La prima volta parte
## il tema di benvenuto; poi, se il brano in corso non è della nuova zona, si
## passa al suo brano principale.
func play_area(new_area: String) -> void:
	if not PLAYLISTS.has(new_area) or new_area == area:
		return
	var first := area == ""
	area = new_area
	if first:
		_play("ritorno")
		_index = -1        # dopo il benvenuto, il primo brano della zona
		return
	if _track in PLAYLISTS[area]:
		_index = PLAYLISTS[area].find(_track)
		return
	_index = 0
	_play(PLAYLISTS[area][0])


func play_jingle() -> void:
	if _silent():
		return
	_jingle.stream = LEVEL_UP      # assegnato qui: all'avvio nessun suono resta in memoria
	_jingle.play()
	if _duck:
		create_tween().tween_property(_duck, "volume_db", DUCK_DB, 0.3)


func _unduck() -> void:
	if _duck:
		create_tween().tween_property(_duck, "volume_db", 0.0, 1.5)


## Incrocia in dissolvenza il brano in corso con quello nuovo.
func _play(track: String) -> void:
	if _silent():
		return
	_track = track
	var old := _players[_current]
	_current = 1 - _current
	var new := _players[_current]
	new.stream = TRACKS[track]
	new.volume_db = SILENT_DB
	new.play()
	var tw := create_tween().set_parallel()
	tw.tween_property(new, "volume_db", 0.0, FADE).set_trans(Tween.TRANS_SINE)
	if old.playing:
		tw.tween_property(old, "volume_db", SILENT_DB, FADE).set_trans(Tween.TRANS_SINE)
		tw.chain().tween_callback(old.stop)


## Senza finestra (test, strumenti a riga di comando) niente suoni.
func _silent() -> bool:
	return DisplayServer.get_name() == "headless"


func _on_finished(player: int) -> void:
	if player != _current or area == "":
		return
	var list: Array = PLAYLISTS[area]
	_index = (_index + 1) % list.size()
	_play(list[_index])
