extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._save_path = "user://retired_guide_ui.dat"
	main._locale.preferences_path = "user://retired_guide_ui.cfg"
	root.add_child(main)
	main._resolve_camera_consent(false)
	main.new_game()
	main._skip_prologue()
	main.set_process(false)
	main.set_physics_process(false)
	# A debug build or a stale tool flag must not restore the retired player UI.
	main._playtest_assist_enabled = true
	for floor_number in range(1, 5):
		main.game.tower_floor = floor_number
		main._render()
		await process_frame
		_check(main.find_child("PlaytestAssistPanel", true, false) == null, "floor %d has no testing instructions" % floor_number)
		_check(main.find_child("DollGuideOverlay", true, false) == null, "floor %d has no doll guidance popup" % floor_number)
		_check(main._reality_floor.find_children("PlaytestMarker", "Label3D", true, false).is_empty(), "floor %d has no yellow TEST world labels" % floor_number)
		_check(is_instance_valid(main._world_prompt), "normal F interaction prompt remains available")
	main._save_progress()
	_check(main.continue_game(), "ordinary save still loads after removing guide overlays")
	_check(main.find_child("PlaytestAssistPanel", true, false) == null and main.find_child("DollGuideOverlay", true, false) == null, "continue never reconstructs retired overlays")
	main.free()
	for failure in failures:
		push_error(failure)
	print("retired guide UI tests passed" if failures.is_empty() else "retired guide UI tests failed")
	quit(0 if failures.is_empty() else 1)

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
