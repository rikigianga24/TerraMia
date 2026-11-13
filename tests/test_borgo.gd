extends SceneTree
## Test della pianta del borgo: ogni edificio si raggiunge a piedi dalla porta
## e lungo le vie non ci sono salti più alti di mezzo livello.
## Avvio:  godot --headless --path . -s tests/test_borgo.gd

func _initialize() -> void:
	await process_frame
	var m = load("res://scenes/borgo/borgo_map.gd").new()
	root.add_child(m)
	await process_frame
	var failures := 0
	for id in m.buildings:
		var path: Array = m._astar.get_id_path(BorgoLayout.ENTRY, m.door_cell(id))
		if path.is_empty():
			print("  FALLITO: irraggiungibile ", id)
			failures += 1
			continue
		for i in range(1, path.size()):
			if absf(m._ground_h(path[i]) - m._ground_h(path[i - 1])) > 0.5:
				print("  FALLITO: salto troppo alto verso ", id, " in ", path[i])
				failures += 1
				break
	print("BORGO OK" if failures == 0 else "BORGO: %d errori" % failures)
	quit(1 if failures > 0 else 0)
