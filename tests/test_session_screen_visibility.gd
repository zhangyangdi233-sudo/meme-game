extends SceneTree
## Whole-screen visibility follows each Session mode's enter and exit. The host does not keep a mode-string matrix.

var _failures: Array[String] = []


func _init() -> void:
	test_host_does_not_decide_whole_screen_visibility_from_the_mode_string()
	if _failures.is_empty():
		print("session screen visibility tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_host_does_not_decide_whole_screen_visibility_from_the_mode_string() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/babel_meme_game.gd")
	for func_name in [
		"_process",
		"_refresh_phone_shell",
		"_refresh_reality_hud",
		"_refresh_ending",
		"_refresh_play_surfaces",
		"_render",
		"_update_visibility",
		"_request_session_mode",
	]:
		var body := _function_body(source, func_name)
		_assert_true(not body.is_empty(), "host should still define %s" % func_name)
		_assert_true(
			not body.contains("session_mode()"),
			"%s should not read the current Session mode string to decide the screen" % func_name
		)
	var transition := _function_body(source, "_request_session_mode")
	_assert_true(
		not transition.contains("_update_visibility("),
		"a mode change should not apply whole-screen visibility; enter and exit do that"
	)


func _function_body(source: String, func_name: String) -> String:
	var header := "func %s(" % func_name
	var start := source.find(header)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + header.length())
	if next < 0:
		return source.substr(start)
	return source.substr(start, next - start)


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
