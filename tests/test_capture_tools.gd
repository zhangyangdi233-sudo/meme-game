extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for script_path in [
		"res://tools/capture_hand_xray.gd",
		"res://tools/capture_main_scene.gd",
		"res://tools/capture_phone_launcher.gd",
		"res://tools/capture_notebook_scene.gd",
		"res://tools/capture_publish_scene.gd",
		"res://tools/capture_doll_discovery.gd",
		"res://tools/capture_doll_dialogue.gd",
		"res://tools/capture_doll_reward.gd",
		"res://tools/capture_reality_scene.gd",
		"res://tools/capture_reality_district.gd",
		"res://tools/capture_dreamcore_artifacts.gd",
		"res://tools/capture_authored_horror_events.gd",
		"res://tools/capture_npc_character_scene.gd",
		"res://tools/capture_ending_scene.gd",
		"res://tools/capture_day_transition.gd",
		"res://tools/capture_main_menu.gd",
		"res://tools/capture_prologue.gd",
	]:
		_assert_capture_script_guarded(script_path)
	_assert_distinct_capture_sequence([
		"res://tools/current_horror_cover_watcher.png",
		"res://tools/current_horror_cover_watcher_retreat.png",
		"res://tools/current_horror_cover_watcher_gone.png",
	], "cover-watcher appearance, retreat, and disappearance")
	_assert_distinct_capture_sequence([
		"res://tools/current_doll_discovery.png",
		"res://tools/current_doll_dialogue.png",
		"res://tools/current_doll_reward.png",
	], "doll discovery, authored choice, and notebook reward")
	_assert_distinct_capture_sequence([
		"res://tools/current_phone_camera_connection_searching.png",
		"res://tools/current_phone_camera_connection_error.png",
		"res://tools/current_phone_camera_connection_ready.png",
	], "phone camera searching, recoverable error, and real-frame ready states")

	if _failures.is_empty():
		print("capture tool tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _assert_capture_script_guarded(script_path: String) -> void:
	var source := FileAccess.get_file_as_string(script_path)
	_assert_true(not source.is_empty(), "capture script should be readable: %s" % script_path)
	_assert_true(load(script_path) is Script, "capture script should compile before any rendered evidence is trusted: %s" % script_path)
	_assert_true(source.contains("DisplayServer.get_name"), "capture script should check the display server before reading viewport textures: %s" % script_path)
	_assert_true(source.contains("headless"), "capture script should explicitly handle headless display mode: %s" % script_path)
	_assert_true(source.contains("HEADLESS_CAPTURE_ERROR"), "capture script should use a clear headless error message: %s" % script_path)
	_assert_true(source.contains("quit(2)"), "capture script should exit with a distinct status for unsupported capture mode: %s" % script_path)
	_assert_true(source.find("if not _ensure_capture_supported()") >= 0 and source.find("if not _ensure_capture_supported()") < source.find("root.get_texture"), "capture script should guard before calling root.get_texture: %s" % script_path)


func _assert_distinct_capture_sequence(paths: Array[String], label: String) -> void:
	var digests: Array[String] = []
	var unique_digests := {}
	for path in paths:
		_assert_true(FileAccess.file_exists(path), "%s evidence should exist: %s" % [label, path])
		if FileAccess.file_exists(path):
			var digest := FileAccess.get_md5(path)
			digests.append(digest)
			unique_digests[digest] = true
	_assert_true(digests.size() == paths.size() and unique_digests.size() == paths.size(), "%s should contain distinct rendered frames" % label)


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
