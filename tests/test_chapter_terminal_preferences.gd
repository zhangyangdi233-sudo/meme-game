extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	var locale = load("res://scripts/localization/game_locale.gd").new()
	locale.preferences_path = "user://test_crt_preferences.cfg"
	_check(locale.load_preferences(80, true).get("crt_vhs_enabled", null) is bool, "CRT VHS is present with a boolean default")
	if locale.has_method("set_crt_vhs_enabled"):
		locale.set_crt_vhs_enabled(false)
	else:
		_check(false, "CRT VHS has an independent preference setter")
		_finish()
		return
	_check(locale.save_preferences(43, true, false, "computer"), "screen setting can save with normal preferences")
	var restored = load("res://scripts/localization/game_locale.gd").new()
	restored.preferences_path = locale.preferences_path
	var values: Dictionary = restored.load_preferences(80, true)
	_check(values.crt_vhs_enabled == false and values.vhs_enabled == true, "screen VHS persists independently from full-screen VHS")
	_check(restored.save_preferences(65, false, true, "phone"), "other settings save without a CRT argument")
	values = restored.load_preferences(80, true)
	_check(not values.crt_vhs_enabled and not values.vhs_enabled and values.camera_enabled and values.camera_source == "phone", "other preference saves preserve disabled CRT VHS")
	restored.set_crt_vhs_enabled(true)
	_check(restored.save_preferences(65, false, false, "computer"), "CRT VHS can be re-enabled")
	_check(restored.load_preferences(80, true).crt_vhs_enabled, "re-enabled CRT VHS survives reload")
	_finish()

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _finish() -> void:
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("chapter CRT preference tests passed")
	quit(0 if failures.is_empty() else 1)
