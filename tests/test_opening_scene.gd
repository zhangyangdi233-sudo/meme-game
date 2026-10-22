extends SceneTree
## A new run plays chapter one's opening in the main scene: black, the white door and the narration, the knock on
## its line, F at the door once both are done, and the basement behind it. The narration locks movement, look and
## the phone, settings pauses it, and a save in the middle continues on the same line without replaying the knock.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const GameEventsScript = preload("res://scripts/game_events.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const TEST_SAVE_PATH := "user://test_opening_scene_save.dat"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	root.size = Vector2i(1600, 900)
	_remove_save()
	await _run()
	_remove_save()
	if _failures.is_empty():
		print("opening scene tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	var game_root = scene.instantiate()
	game_root._save_path = TEST_SAVE_PATH
	root.add_child(game_root)
	await process_frame
	game_root._locale.set_locale("zh")
	game_root.new_game()
	await process_frame
	await process_frame
	await _test_a_new_run_opens_on_black_water_and_the_narration(game_root)
	await _test_the_narration_locks_movement_look_and_the_phone(game_root)
	await _test_a_click_reads_the_next_line(game_root)
	await _test_the_knock_sounds_on_its_line_and_settings_pauses_it(game_root)
	await _test_a_save_continues_on_the_same_line_without_the_knock(game_root)
	await _test_the_door_waits_for_the_knock_then_opens_into_the_basement(game_root)
	game_root.queue_free()
	await process_frame


func _test_a_new_run_opens_on_black_water_and_the_narration(game_root) -> void:
	_assert_eq(game_root.session_mode(), "prologue", "a new run should open on the narration")
	var panel := Harness.find_node_by_name(game_root, "OpeningNarrationPanel") as Control
	_assert_true(panel != null and panel.visible, "a new run should mount the opening narration")
	_assert_true(Harness.find_node_by_name(game_root, "OpeningWorld") != null, "a new run should build the black water and the white door")
	_assert_true(Harness.find_node_by_name(game_root, "PrologueOverlay") == null, "the old prologue should be gone")
	_assert_eq(str(game_root.game.view_state), "npc_up", "the opening should look at the world, not the phone")
	var black := Harness.find_node_by_name(panel, "OpeningBlack") as ColorRect
	_assert_true(black != null and black.visible, "the opening should start on black")
	panel._process(2.1)
	var line := Harness.find_node_by_name(panel, "OpeningNarrationLine") as Label
	_assert_true(line != null and line.visible, "the first line should follow the black")
	_assert_eq(line.text, "你好", "the first line should be the manuscript's first line")


func _test_the_narration_locks_movement_look_and_the_phone(game_root) -> void:
	var toggle := Harness.find_node_by_name(game_root, "PhoneViewToggleButton") as Control
	_assert_true(toggle == null or not toggle.visible, "the narration should hide the phone toggle")
	game_root.set_view_state("phone_down")
	_assert_eq(str(game_root.game.view_state), "npc_up", "the narration should refuse to raise the phone")
	_push_key(game_root, KEY_TAB)
	await process_frame
	_assert_eq(str(game_root.game.view_state), "npc_up", "Tab should not raise the phone during the narration")
	var pose_before: Dictionary = game_root._reality_scene_adapter.pose()
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(240, 120)
	motion.position = Vector2(800, 450)
	game_root.get_viewport().push_input(motion, true)
	var drag := InputEventScreenDrag.new()
	drag.relative = Vector2(240, 0)
	drag.screen_relative = Vector2(240, 0)
	game_root.get_viewport().push_input(drag, true)
	var pan := InputEventPanGesture.new()
	pan.delta = Vector2(4, 0)
	game_root.get_viewport().push_input(pan, true)
	Input.action_press("ui_up")
	var forward := InputEventKey.new()
	forward.physical_keycode = KEY_W
	forward.keycode = KEY_W
	forward.pressed = true
	Input.parse_input_event(forward)
	for frame in 20:
		await physics_frame
	forward.pressed = false
	Input.parse_input_event(forward)
	Input.action_release("ui_up")
	var pose_after: Dictionary = game_root._reality_scene_adapter.pose()
	_assert_near(float(pose_after.get("yaw")), float(pose_before.get("yaw")), 0.001, "the narration should lock turning")
	_assert_near(float(pose_after.get("pitch")), float(pose_before.get("pitch")), 0.001, "the narration should lock looking up and down")
	var moved: float = (pose_after.get("player_position") as Vector3).distance_to(pose_before.get("player_position") as Vector3)
	_assert_true(moved < 0.05, "the narration should lock walking (moved %.3f m)" % moved)


func _test_a_click_reads_the_next_line(game_root) -> void:
	await _click(game_root, Vector2(800, 450))
	_assert_eq(int(game_root.game.chapter_one_progress.get("line_index")), 1, "a click on the narration should read the next line")
	var line := Harness.find_node_by_name(game_root, "OpeningNarrationLine") as Label
	_assert_eq(line.text, "看来你又一次遗忘了我……", "the panel should show the next line")


func _test_the_knock_sounds_on_its_line_and_settings_pauses_it(game_root) -> void:
	var knock := Harness.find_node_by_name(game_root, "OpeningKnock") as AudioStreamPlayer3D
	while int(game_root.game.chapter_one_progress.get("line_index")) < ProgressScript.KNOCK_LINE_INDEX - 1:
		GameEventBus.raise(UiIntentsScript.OPENING_NARRATION_ADVANCED)
	await process_frame
	_assert_true(knock != null and not knock.playing, "the knock should wait for its line")
	GameEventBus.raise(UiIntentsScript.OPENING_NARRATION_ADVANCED)
	await process_frame
	_assert_true(knock.playing, "the knock should sound on its line")
	await physics_frame
	await physics_frame
	game_root._toggle_settings_window()
	await process_frame
	_assert_true(knock.stream_paused, "opening settings should pause the knock")
	var line_before := int(game_root.game.chapter_one_progress.get("line_index"))
	var panel := Harness.find_node_by_name(game_root, "OpeningNarrationPanel") as Control
	panel._gui_input(_left_click(Vector2(800, 450), true))
	_assert_eq(int(game_root.game.chapter_one_progress.get("line_index")), line_before, "the narration should hold while settings is open")
	game_root._close_settings_window()
	await process_frame
	_assert_true(not knock.stream_paused, "closing settings should resume the knock")
	knock.finished.emit()
	await process_frame
	_assert_true(bool(game_root.game.chapter_one_progress.get("knock_complete")), "a finished knock should be recorded on the run")
	GameEventBus.raise(UiIntentsScript.OPENING_NARRATION_ADVANCED)
	await process_frame


func _test_a_save_continues_on_the_same_line_without_the_knock(game_root) -> void:
	var line_before := int(game_root.game.chapter_one_progress.get("line_index"))
	_assert_true(game_root._save_progress(), "saving in the middle of the narration should write the save")
	game_root.show_main_menu()
	await process_frame
	_assert_true(game_root.continue_game(), "the save should continue")
	await process_frame
	await process_frame
	_assert_eq(game_root.session_mode(), "prologue", "a save in the narration should continue in the narration")
	_assert_eq(int(game_root.game.chapter_one_progress.get("line_index")), line_before, "continuing should come back on the same line")
	var panel := Harness.find_node_by_name(game_root, "OpeningNarrationPanel") as Control
	panel._process(2.1)
	var line := Harness.find_node_by_name(game_root, "OpeningNarrationLine") as Label
	_assert_true(line != null and line.visible, "continuing should show the saved line after the black")
	var knock := Harness.find_node_by_name(game_root, "OpeningKnock") as AudioStreamPlayer3D
	for frame in 3:
		await process_frame
	_assert_true(knock != null and not knock.playing, "a knock already heard should not play again after continuing")


func _test_the_door_waits_for_the_knock_then_opens_into_the_basement(game_root) -> void:
	# A fresh run read to the end before the knock finishes: the door must still refuse.
	game_root.new_game()
	await process_frame
	while ProgressScript.is_reading_narration(game_root.game.chapter_one_progress):
		GameEventBus.raise(UiIntentsScript.OPENING_NARRATION_ADVANCED)
	await process_frame
	_assert_eq(game_root.session_mode(), "gameplay", "reading the last line should hand the player the world")
	_assert_true(Harness.find_node_by_name(game_root, "OpeningNarrationPanel") == null, "the narration should unmount once read")
	var adapter = game_root._reality_scene_adapter
	var door: Vector3 = adapter.chapter_door_position()
	adapter.player.position = Vector3(door.x, adapter.player.position.y, door.z + 0.9)
	await process_frame
	_push_key(game_root, KEY_F)
	await process_frame
	_assert_eq(str(game_root.game.chapter_one_progress.get("phase")), ProgressScript.PHASE_OPENING, "F should not open the door before the knock finishes")
	_assert_eq(str(adapter.interaction_outcome().get("kind")), "none", "the door should not start opening before the knock finishes")
	GameEventBus.raise_event(GameEventsScript.OPENING_KNOCK_FINISHED)
	await process_frame
	await process_frame
	_assert_eq(str(adapter.nearby_outcome().get("kind")), "door", "the door should answer once the knock has finished")
	var prompt := Harness.find_node_by_name(game_root, "WorldPrompt") as Label
	if prompt != null:
		_assert_true(prompt.visible and prompt.text.contains("F"), "the world prompt should offer F at the door")
	_push_key(game_root, KEY_F)
	await process_frame
	_assert_eq(str(game_root.game.chapter_one_progress.get("phase")), ProgressScript.PHASE_BASEMENT, "F at the ready door should enter the basement")
	_assert_eq(str(adapter.interaction_outcome().get("kind")), "door", "the door should open slowly")
	game_root._try_reality_interaction()
	game_root.set_view_state("phone_down")
	_assert_eq(str(adapter.interaction_outcome().get("kind")), "door", "neither F nor the phone should cut the door opening short")
	_assert_eq(str(game_root.game.view_state), "npc_up", "the phone should stay down while the door opens")
	var fade := Harness.find_node_by_name(game_root, "DoorFade") as ColorRect
	var darkest := 0.0
	for step in 40:
		game_root._physics_process(0.1)
		game_root._process(0.1)
		if fade != null:
			darkest = maxf(darkest, fade.color.a)
		fade = Harness.find_node_by_name(game_root, "DoorFade") as ColorRect
	_assert_true(darkest > 0.9, "the door opening should fade to black (darkest %.2f)" % darkest)
	_assert_true(Harness.find_node_by_name(game_root, "BasementRoom") != null, "the basement should follow the door")
	_assert_true(Harness.find_node_by_name(game_root, "OpeningWorld") == null, "the opening should be gone in the basement")
	_assert_eq(str(adapter.interaction_outcome().get("kind")), "none", "the basement should hand the player back control")
	_assert_true(fade == null or fade.color.a < 0.05, "the black should lift in the basement")
	_assert_eq(int(game_root.game.chapter_one_progress.get("round")), 1, "the basement should be round one")
	var toggle := Harness.find_node_by_name(game_root, "PhoneViewToggleButton") as Control
	_assert_true(toggle != null and toggle.visible, "the phone toggle should come back in the basement")


func _push_key(game_root, keycode: Key) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = keycode
		key.physical_keycode = keycode
		key.pressed = pressed
		game_root.get_viewport().push_input(key, true)


func _click(game_root, point: Vector2) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	game_root.get_viewport().push_input(_left_click(point, true), true)
	await process_frame
	game_root.get_viewport().push_input(_left_click(point, false), true)
	await process_frame


func _left_click(point: Vector2, pressed: bool) -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.position = point
	click.global_position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	click.pressed = pressed
	return click


func _remove_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])


func _assert_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
