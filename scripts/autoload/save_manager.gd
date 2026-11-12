extends Node
## Salvataggio locale (user://). Su web Godot lo mappa su IndexedDB.
## Supabase arriverà solo con gli acquisti in-app.

const SAVE_PATH := "user://terramia_save.json"
const AUTOSAVE_DELAY := 2.0

var _dirty := false
var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = AUTOSAVE_DELAY
	_timer.timeout.connect(save_game)
	add_child(_timer)

	if not load_game():
		GameState.new_game()
	GameState.apply_offline_progress()
	GameState.changed.connect(_on_state_changed)


func _on_state_changed() -> void:
	_dirty = true
	if _timer.is_stopped():
		_timer.start()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if _dirty:
				save_game()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			GameState.apply_offline_progress()


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Salvataggio fallito: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(GameState.to_dict()))
	_dirty = false


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		push_warning("Salvataggio illeggibile, si riparte da capo.")
		return false
	GameState.from_dict(data)
	return true


func reset_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	GameState.new_game()
	save_game()
