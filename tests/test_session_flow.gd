extends SceneTree
## Adapter Session mode: boot injects five states, continue and title go through the manager.

var _failures: Array[String] = []
const TEST_SAVE_PATH := "user://test_session_flow_save.dat"
const SESSION_IDS := ["main_menu", "prologue", "gameplay", "narrative", "ending"]


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	root.size = Vector2i(1600, 900)
	await _run()
	_remove_test_save()
	if _failures.is_empty():
		print("session flow tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_remove_test_save()
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "session flow should load the main scene")
	if scene == null:
		return
	var game_root = scene.instantiate()
	game_root._save_path = TEST_SAVE_PATH
	root.add_child(game_root)
	await process_frame
	game_root._locale.set_locale("zh")

	_assert_true(
		game_root.has_method("session_mode") and game_root.has_method("has_session_state"),
		"adapter should expose Session mode through the flow manager"
	)
	if not game_root.has_method("session_mode") or not game_root.has_method("has_session_state"):
		game_root.queue_free()
		await process_frame
		return

	for state_id in SESSION_IDS:
		_assert_true(
			game_root.has_session_state(state_id),
			"boot should inject session state %s" % state_id
		)
	_assert_eq(game_root.session_mode(), "main_menu", "boot should start on the main menu")
	await _assert_title_world_hotkeys_inert(game_root, "boot title")

	game_root.new_game()
	game_root._skip_prologue()
	game_root.set_view_state("npc_up")
	game_root.game.ending_unlocked = false
	game_root.show_main_menu()
	await process_frame
	_assert_eq(game_root.session_mode(), "main_menu", "returning to title should set Session mode to main menu")
	await _assert_title_world_hotkeys_inert(game_root, "returned title")

	_assert_true(game_root.continue_game(), "continue should load the non-ending save")
	await process_frame
	_assert_eq(game_root.session_mode(), "gameplay", "continuing a non-ending save should set Session mode to gameplay")
	await _assert_gameplay_world_hotkeys_live(game_root)

	game_root.show_main_menu()
	await process_frame
	_assert_eq(game_root.session_mode(), "main_menu", "returning to title after continue should restore the main menu")
	await _assert_title_world_hotkeys_inert(game_root, "title after continue")

	game_root.queue_free()
	await process_frame


func _assert_title_world_hotkeys_inert(game_root, label: String) -> void:
	var yaw_before := float(game_root._reality_yaw)
	var view_before := str(game_root.game.view_state) if game_root.game != null else ""
	var interacting_before: bool = game_root._reality_interaction_active
	game_root._unhandled_input(_key_event(KEY_F))
	game_root._unhandled_input(_key_event(KEY_TAB))
	var look := InputEventMouseMotion.new()
	look.relative = Vector2(96.0, 0.0)
	game_root._unhandled_input(look)
	_assert_true(
		is_equal_approx(float(game_root._reality_yaw), yaw_before),
		"%s should ignore look hotkeys" % label
	)
	_assert_eq(
		str(game_root.game.view_state) if game_root.game != null else "",
		view_before,
		"%s should ignore the phone hotkey" % label
	)
	_assert_true(
		game_root._reality_interaction_active == interacting_before,
		"%s should ignore the interact hotkey" % label
	)
	var player := game_root.get_node_or_null("RealityPlayer") as CharacterBody3D
	if player == null:
		return
	var start := player.position
	for _frame in 8:
		await physics_frame
	_assert_true(
		start.distance_to(player.position) < 0.01,
		"%s should not walk while Session mode is the main menu" % label
	)


func _assert_gameplay_world_hotkeys_live(game_root) -> void:
	game_root.set_view_state("npc_up")
	var yaw_before := float(game_root._reality_yaw)
	var look := InputEventMouseMotion.new()
	look.relative = Vector2(96.0, 0.0)
	game_root._unhandled_input(look)
	_assert_true(
		not is_equal_approx(float(game_root._reality_yaw), yaw_before),
		"gameplay look should rotate the first-person view"
	)
	var view_before := str(game_root.game.view_state)
	game_root._unhandled_input(_key_event(KEY_TAB))
	_assert_true(
		str(game_root.game.view_state) != view_before,
		"gameplay phone hotkey should toggle the phone"
	)
	game_root.set_view_state("npc_up")
	var player := game_root.get_node_or_null("RealityPlayer") as CharacterBody3D
	_assert_true(player != null, "gameplay should expose the walking body")
	if player == null:
		return
	var walk_start := player.position
	Input.action_press("reality_forward")
	for _frame in 24:
		await physics_frame
	Input.action_release("reality_forward")
	_assert_true(
		walk_start.distance_to(player.position) > 0.25,
		"gameplay walk hotkeys should move the body"
	)


func _key_event(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.echo = false
	event.keycode = keycode
	event.physical_keycode = keycode
	return event


func _remove_test_save() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_SAVE_PATH)
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(absolute_path)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
