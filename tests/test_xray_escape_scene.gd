extends SceneTree
## #127 / #142 Q1: in the main scene the X-ray works from the start without a camera: holding X tints the view. Round
## five hides a way out at its clock: holding X in reach of the clock makes it the exit, with no post, and F there
## leaves for the passage. Holding X anywhere else, or at round four's clock, opens nothing.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const TEST_SAVE_PATH := "user://test_xray_escape_scene_save.dat"
const TEST_PREFERENCES_PATH := "user://test_xray_escape_scene_preferences.cfg"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	root.size = Vector2i(1600, 900)
	_remove_files()
	await _run()
	Input.action_release("reality_xray")
	_remove_files()
	if _failures.is_empty():
		print("xray escape scene tests passed")
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
	game_root._locale.preferences_path = TEST_PREFERENCES_PATH
	game_root._locale.set_locale("zh")
	game_root.new_game()
	await process_frame
	await _test_x_tints_the_view_without_a_camera(game_root)
	await _test_round_four_hides_nothing_at_its_clock(game_root)
	await _test_away_from_the_clock_the_xray_opens_nothing(game_root)
	await _test_the_clock_seen_through_the_xray_leads_out_of_round_five(game_root)
	game_root.queue_free()
	await process_frame


func _test_x_tints_the_view_without_a_camera(game_root) -> void:
	await _jump(game_root, 1)
	_assert_true(not game_root._camera_session.enabled, "the run should have no camera")
	var tint := Harness.find_node_by_name(game_root, "XRayTint") as CanvasItem
	_assert_true(tint != null and not tint.visible, "the X-ray tint should be hidden at first")
	Input.action_press("reality_xray")
	await _frames(3)
	_assert_true(tint != null and tint.visible, "holding X should tint the view")
	Input.action_release("reality_xray")
	await _frames(3)
	_assert_true(tint != null and not tint.visible, "letting go of X should lift the tint")


func _test_round_four_hides_nothing_at_its_clock(game_root) -> void:
	await _jump(game_root, 4)
	await _stand_at(game_root, _clock_reach(game_root))
	Input.action_press("reality_xray")
	await _frames(3)
	Input.action_release("reality_xray")
	_assert_eq(game_root.game.basement_exits(), [], "round four's clock seen through the X-ray should open nothing")


func _test_away_from_the_clock_the_xray_opens_nothing(game_root) -> void:
	await _jump(game_root, 5)
	var adapter = game_root._reality_scene_adapter
	await _stand_at(game_root, adapter.chapter_exit_reaches("door")[0])
	Input.action_press("reality_xray")
	await _frames(3)
	Input.action_release("reality_xray")
	_assert_eq(game_root.game.basement_exits(), [], "the X-ray away from the clock should open nothing")


func _test_the_clock_seen_through_the_xray_leads_out_of_round_five(game_root) -> void:
	var adapter = game_root._reality_scene_adapter
	await _stand_at(game_root, _clock_reach(game_root))
	_assert_true(str(adapter.nearby_outcome().get("kind")) != "exit", "the clock should not answer as the exit unseen")
	Input.action_press("reality_xray")
	await _frames(3)
	Input.action_release("reality_xray")
	await _frames(2)
	_assert_eq(game_root.game.basement_exits(), ["clock"], "the clock seen through the X-ray should be round five's way out")
	_assert_eq(game_root.game.published_memes.size(), 0, "the X-ray way out should need no post")
	_assert_eq(str(adapter.nearby_outcome().get("object")), "clock", "the clock should answer F once seen, with X let go")
	_push_key(game_root, KEY_F)
	await process_frame
	_assert_eq(str(adapter.interaction_outcome().get("kind")), "exit", "F at the clock should play the shared exit transition")
	for frame in 900:
		if str(adapter.interaction_outcome().get("kind")) != "exit":
			break
		await process_frame
	await _frames(2)
	_assert_eq(str(game_root.game.chapter_one_progress.get("phase")), ProgressScript.PHASE_PASSAGE, "leaving by the clock should reach the passage")


func _clock_reach(game_root) -> Vector3:
	return game_root._reality_scene_adapter.chapter_exit_reaches("clock")[0]


func _jump(game_root, round_number: int) -> void:
	GameEventBus.raise(UiIntentsScript.CHAPTER_ROUND_JUMP_REQUESTED, {UiIntentsScript.KEY_INDEX: round_number})
	await _frames(2)
	_assert_eq(ProgressScript.round_of(game_root.game.chapter_one_progress), round_number, "setup should reach round %d" % round_number)


func _stand_at(game_root, reach: Vector3) -> void:
	var adapter = game_root._reality_scene_adapter
	adapter.player.position = reach + Vector3(0.0, 0.05, 0.0)
	adapter.player.velocity = Vector3.ZERO
	for frame in 6:
		await physics_frame
	await process_frame


func _frames(count: int) -> void:
	for frame in count:
		await process_frame


func _push_key(game_root, keycode: Key) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = keycode
		key.physical_keycode = keycode
		key.pressed = pressed
		game_root.get_viewport().push_input(key, true)


func _remove_files() -> void:
	for path in [TEST_SAVE_PATH, TEST_PREFERENCES_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
