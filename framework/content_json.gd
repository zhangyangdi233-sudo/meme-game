class_name ContentJson
extends RefCounted
## Shared res:// JSON loading helpers for authored content catalogs.

static var _cache_by_path: Dictionary = {}


static func read_dictionary(path: String, label: String = "ContentJson") -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("%s: missing file %s" % [label, path])
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("%s: expected dictionary at %s" % [label, path])
		return {}
	return (parsed as Dictionary).duplicate(true)


static func load_dictionary_cached(path: String, label: String = "ContentJson") -> Dictionary:
	if _cache_by_path.has(path):
		return _cache_by_path[path]
	var loaded := read_dictionary(path, label)
	_cache_by_path[path] = loaded
	return loaded


static func duplicate_array(source: Variant) -> Array:
	if typeof(source) != TYPE_ARRAY:
		return []
	var result: Array = []
	for item in source:
		if typeof(item) == TYPE_DICTIONARY:
			result.append((item as Dictionary).duplicate(true))
		else:
			result.append(item)
	return result


static func clear_cache(path: String = "") -> void:
	if path.is_empty():
		_cache_by_path.clear()
		return
	_cache_by_path.erase(path)
