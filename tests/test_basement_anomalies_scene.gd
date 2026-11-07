extends SceneTree
## #114 in the main scene: a room event the stage starts is saved by the state at once; round three's switch answers F
## in the dark ("F  开灯") and brings the light back over the scattered chairs; holding X shows round five's missing
## numbers; and a window out of focus holds the events' clock like open settings do.

const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const TEST_SAVE_PATH := "user://test_basement_anomalies_scene_save.dat"
const TEST_PREFERENCES_PATH := "user://test_basement_anomalies_scene_preferences.cfg"

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
		print("basement anomalies scene tests passed")
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
	await _test_a_lost_focus_holds_the_whisper(game_root)
	await _test_the_whisper_is_saved_when_it_starts(game_root)
	await _test_the_switch_brings_round_threes_light_back(game_root)
	await _test_x_shows_round_fives_missing_numbers(game_root)
	game_root.queue_free()
	await process_frame


func _test_a_lost_focus_holds_the_whisper(game_root) -> void:
	await _jump(game_root, 2)
	await _stand_at(game_root, Vector3(-1.0, 0.0, 1.5))
	game_root.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _physics(200)
	_assert_eq(game_root.game.basement_started_events(), [], "a window out of focus should hold the whisper's clock")
	game_root.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _physics(200)
	_assert_eq(game_root.game.basement_started_events(), ["whisper"], "the whisper should come once the window is back")


func _test_the_whisper_is_saved_when_it_starts(game_root) -> void:
	await _jump(game_root, 2)
	await _stand_at(game_root, Vector3(-1.0, 0.0, 1.5))
	await _physics(170)
	_assert_eq(game_root.game.basement_started_events(), ["whisper"], "the state should save the whisper the moment it starts")
	var restored := MemeGameState.new()
	restored.load_save_data(game_root.game.to_save_data())
	_assert_eq(restored.basement_started_events(), ["whisper"], "a save made during the whisper should not replay it")


func _test_the_switch_brings_round_threes_light_back(game_root) -> void:
	await _jump(game_root, 3)
	await _stand_at(game_root, Vector3(-1.0, 0.0, 1.5))
	await _physics(90)
	_assert_eq(game_root.game.room_world_state().get("lights"), false, "round three should go dark once the player is down")
	var stage: Node = game_root.find_child("ChapterOneStage", true, false)
	await _stand_at(game_root, stage.switch_reach_position())
	_assert_eq(str(game_root._world_prompt.text), "F  开灯", "the switch should offer the light")
	_push_key(game_root, KEY_F)
	await _frames(3)
	_assert_eq(game_root.game.basement_ended_events(), ["blackout"], "F at the switch should end the outage")
	_assert_eq(game_root.game.room_world_state().get("lights", true), true, "the lights should come back")
	_assert_true((stage.get_node("ScatteredChairs") as Node3D).visible, "the chairs should lie scattered once the light is back")


func _test_x_shows_round_fives_missing_numbers(game_root) -> void:
	await _jump(game_root, 5)
	var stage: Node = game_root.find_child("ChapterOneStage", true, false)
	var numeral := stage.find_child("XRayNumeral3", true, false) as Node3D
	_assert_true(numeral != null and not numeral.visible, "the missing number should hide in the plain view")
	Input.action_press("reality_xray")
	await _frames(3)
	_assert_true(numeral != null and numeral.visible, "holding X should show the missing number")
	Input.action_release("reality_xray")
	await _frames(3)
	_assert_true(numeral != null and not numeral.visible, "letting go of X should hide it again")


func _jump(game_root, round_number: int) -> void:
	GameEventBus.raise(UiIntentsScript.CHAPTER_ROUND_JUMP_REQUESTED, {UiIntentsScript.KEY_INDEX: round_number})
	await _frames(2)
	_assert_eq(ProgressScript.round_of(game_root.game.chapter_one_progress), round_number, "setup should reach round %d" % round_number)


func _stand_at(game_root, reach: Vector3) -> void:
	var adapter = game_root._reality_scene_adapter
	adapter.player.position = reach + Vector3(0.0, 0.05, 0.0)
	adapter.player.velocity = Vector3.ZERO
	await _physics(6)
	await process_frame


func _physics(count: int) -> void:
	for frame in count:
		await physics_frame


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
