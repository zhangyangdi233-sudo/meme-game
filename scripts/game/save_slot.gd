extends RefCounted
## One save file on disk, read back: the payload, and whether it holds a run to continue.
## The host writes the file; the title's debug panel only asks whether it holds a run.

var _path: String
var _version: int


func _init(save_path: String, save_version: int) -> void:
	_path = save_path
	_version = save_version


## Empty when the file is missing, unreadable, from another version, or missing its game or world part.
func load_payload() -> Dictionary:
	if not FileAccess.file_exists(_path):
		return {}
	var file := FileAccess.open(_path, FileAccess.READ)
	if file == null:
		return {}
	var payload: Variant = file.get_var()
	if not payload is Dictionary or int(payload.get("version", -1)) != _version:
		return {}
	if not payload.get("game", {}) is Dictionary or not payload.get("world", {}) is Dictionary:
		return {}
	return payload


func has_progress() -> bool:
	return not load_payload().is_empty()
