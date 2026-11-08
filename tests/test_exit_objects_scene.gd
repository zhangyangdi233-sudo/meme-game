extends SceneTree
## #144: in the main scene, the object an exit rule names is the way out. 椅子是出口 makes the chairs answer F while the
## locked door and the other objects do nothing; the exit survives a save; F at a chair pushes the view in, darkens
## the screen and lifts it again at the next round's start.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const TEST_SAVE_PATH := "user://test_exit_objects_scene_save.dat"
const TEST_PREFERENCES_PATH := "user://test_exit_objects_scene_preferences.cfg"
const CHAIR_RULE := ["椅", "子", "是", "出", "口"]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	root.size = Vector2i(1600, 900)
	_remove_files()
	await _run()
	_remove_files()
	if _failures.is_empty():
		print("exit objects scene tests passed")
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
	await _enter_round_one(game_root)
	await _test_only_the_named_object_leads_out(game_root)
	await _test_a_saved_exit_still_leads_out(game_root)
	await _test_leaving_pushes_in_darkens_and_lifts_at_the_next_round(game_root)
	game_root.queue_free()
	await process_frame


func _test_only_the_named_object_leads_out(game_root) -> void:
	game_root.game.free_sentence_units = CHAIR_RULE.duplicate()
	_assert_true(bool(game_root.game.submit_free_sentence("zh").get("submitted")), "setup should post 椅子是出口")
	_assert_eq(game_root.game.basement_exits(), ["chair"], "椅子是出口 should make the chair the exit")
	var adapter = game_root._reality_scene_adapter
	for object_name: String in ["door", "table", "tv", "light"]:
		await _stand_at(game_root, adapter.chapter_exit_reaches(object_name)[0])
		_assert_true(str(adapter.nearby_outcome().get("kind")) != "exit", "the %s should not answer as the exit" % object_name)
		_push_key(game_root, KEY_F)
		await process_frame
		_exit_anything(game_root)
		_assert_eq(ProgressScript.round_of(game_root.game.chapter_one_progress), 1, "F at the %s should not leave the round" % object_name)
	await _stand_at(game_root, adapter.chapter_exit_reaches("chair")[0])
	_assert_eq(str(adapter.nearby_outcome().get("kind")), "exit", "the chair should answer as the exit")
	_assert_true(game_root._world_prompt.text.begins_with("F"), "the prompt should offer F at the chair: %s" % game_root._world_prompt.text)


func _test_a_saved_exit_still_leads_out(game_root) -> void:
	_assert_true(game_root._save_progress(), "the run should save with the chair as the exit")
	game_root.show_main_menu()
	await process_frame
	_assert_true(game_root.continue_game(), "the save should continue")
	await process_frame
	await process_frame
	_assert_eq(game_root.game.basement_exits(), ["chair"], "the loaded run should keep the chair as the exit")
	var adapter = game_root._reality_scene_adapter
	await _stand_at(game_root, adapter.chapter_exit_reaches("chair")[1])
	_assert_eq(str(adapter.nearby_outcome().get("kind")), "exit", "another chair should answer after the load too")


func _test_leaving_pushes_in_darkens_and_lifts_at_the_next_round(game_root) -> void:
	var adapter = game_root._reality_scene_adapter
	var room: Node = Harness.find_node_by_name(game_root, "BasementRoom")
	_push_key(game_root, KEY_F)
	await process_frame
	_assert_eq(str(adapter.interaction_outcome().get("kind")), "exit", "F at the chair should start the exit transition")
	_assert_eq(ProgressScript.round_of(game_root.game.chapter_one_progress), 2, "leaving by the chair should move the run to round two")
	_assert_true(game_root._phone_locked(), "the phone should stay down during the transition")
	var darkest := 0.0
	for frame in 900:
		await process_frame
		var fade := Harness.find_node_by_name(game_root, "DoorFade") as ColorRect
		if fade != null:
			darkest = maxf(darkest, fade.color.a)
		if str(adapter.interaction_outcome().get("kind")) == "exit":
			_assert_true(Harness.find_node_by_name(game_root, "BasementRoom") == room, "round one should stay built while the view pushes in")
		elif fade == null:
			break
	_assert_true(darkest > 0.95, "the screen should darken fully before the next round: %s" % darkest)
	_assert_true(Harness.find_node_by_name(game_root, "DoorFade") == null, "the screen should lighten again")
	var rebuilt: Node = Harness.find_node_by_name(game_root, "BasementRoom")
	_assert_true(rebuilt != null and rebuilt != room, "round two should be built")
	var start: Vector3 = adapter.pose().get("player_position")
	_assert_true(start.distance_to(ChapterOneStage.BASEMENT_SPAWN) < 0.2, "round two should start at the top of the stairs: %s" % start)
	_assert_true(not game_root._phone_locked(), "the phone should come back once the next round stands")


## A new run read to the end, knocked, and in basement round one with the phone.
func _enter_round_one(game_root) -> void:
	game_root.new_game()
	await process_frame
	while game_root.game.advance_opening_narration():
		pass
	game_root.game.complete_opening_knock()
	game_root.game.open_opening_door()
	game_root.game.pick_up_phone()
	_assert_true(game_root._save_progress(), "setup should save the run in the basement")
	game_root.show_main_menu()
	await process_frame
	_assert_true(game_root.continue_game(), "setup should continue the basement save")
	await process_frame
	await process_frame
	_assert_eq(ProgressScript.round_of(game_root.game.chapter_one_progress), 1, "setup should stand in round one")


func _stand_at(game_root, reach: Vector3) -> void:
	var adapter = game_root._reality_scene_adapter
	adapter.player.position = reach + Vector3(0.0, 0.05, 0.0)
	adapter.player.velocity = Vector3.ZERO
	for frame in 6:
		await physics_frame
	await process_frame


## Leaves whatever F may have entered (the CRT), so the next object is tried from the room.
func _exit_anything(game_root) -> void:
	if game_root._terminal_is_open():
		game_root._exit_terminal()


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
