extends SceneTree

const FORBIDDEN_PATTERNS := [
	"res://scripts/",
	"MemeGameState",
	"babel_meme_game",
	"pollution",
	"tower_floor",
	"meme_game_state",
]

var _failures: Array[String] = []


func _init() -> void:
	_scan_directory("res://framework")
	if _failures.is_empty():
		print("framework boundary tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _scan_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		_failures.append("framework directory missing: %s" % path)
		return

	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while entry_name != "":
		if entry_name.begins_with("."):
			entry_name = dir.get_next()
			continue

		var entry_path := "%s/%s" % [path, entry_name]
		if dir.current_is_dir():
			_scan_directory(entry_path)
		elif entry_name.ends_with(".gd"):
			_scan_file(entry_path)
		entry_name = dir.get_next()
	dir.list_dir_end()


func _scan_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_failures.append("could not read %s" % path)
		return

	var line_number := 0
	while not file.eof_reached():
		line_number += 1
		var line := file.get_line()
		for pattern in FORBIDDEN_PATTERNS:
			if line.find(pattern) != -1:
				_failures.append(
					"%s:%d contains forbidden token %s" % [path, line_number, pattern]
				)
	file.close()
