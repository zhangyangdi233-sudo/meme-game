extends Logger
## Collects the errors `UiPalette` reports, so a test can tell a complete palette from a guessed color.

var _lines: Array[String] = []


func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	var text := rationale if not rationale.is_empty() else code
	if error_type == ERROR_TYPE_ERROR and text.begins_with("UiPalette"):
		_lines.append(text)


func take() -> Array[String]:
	var taken := _lines.duplicate()
	_lines.clear()
	return taken
