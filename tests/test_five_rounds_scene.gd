extends SceneTree
## #127: in the main scene the five basement rounds are played by their rules alone, from the white door to the demo's
## end: nobody needs helping (the NPCs behind the door in rounds two and four are a side path, #129), each round's own words spell a clean exit rule, posting it makes its object the way out,
## and F there plays the shared transition into the next round. The fifth round's way out leads through the passage's
## light to the end screen. #131: the same run is played in every language the game ships, without the camera.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const RoomContentScript = preload("res://scripts/game/room_content.gd")
const WordDropScript = preload("res://scripts/game/word_drop.gd")
const TEST_SAVE_PATH := "user://test_five_rounds_scene_save.dat"
const TEST_PREFERENCES_PATH := "user://test_five_rounds_scene_preferences.cfg"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	root.size = Vector2i(1600, 900)
	_remove_files()
	await _run()
	_remove_files()
	if _failures.is_empty():
		print("five rounds scene tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	for locale_code: String in ["zh", "ja", "en"]:
		await _play_the_demo(locale_code)
		_remove_files()


func _play_the_demo(locale_code: String) -> void:
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	var game_root = scene.instantiate()
	game_root._save_path = TEST_SAVE_PATH
	root.add_child(game_root)
	await process_frame
	game_root._locale.preferences_path = TEST_PREFERENCES_PATH
	game_root._locale.set_locale(locale_code)
	await _enter_round_one(game_root)
	_assert_true(game_root._camera_session == null or not game_root._camera_session.enabled, "the %s run should be played without the camera" % locale_code)
	var used: Array = []
	for round_number in range(1, ProgressScript.BASEMENT_ROUND_COUNT + 1):
		_assert_eq(ProgressScript.round_of(game_root.game.chapter_one_progress), round_number, "the %s run should stand in round %d" % [locale_code, round_number])
		# Rounds two and four keep someone behind the sealed door (#129); helping them is a side path the run never takes here.
		_assert_eq(Harness.find_node_by_name(game_root, "BasementNPC") != null, round_number in [2, 4], "round %d's NPC behind the door" % round_number)
		used.append(await _leave_by_a_clean_exit_rule(game_root, round_number, locale_code))
	_assert_eq(used.size(), ProgressScript.BASEMENT_ROUND_COUNT, "every %s round should have been left by a rule" % locale_code)
	var distinct: Array = []
	for object_name: String in used:
		if object_name not in distinct:
			distinct.append(object_name)
	_assert_eq(distinct.size(), used.size(), "each round should go out by another thing: %s" % [used])
	_assert_eq(str(game_root.game.chapter_one_progress.get("phase")), ProgressScript.PHASE_PASSAGE, "the fifth round should lead to the passage")
	await _walk_into_the_light(game_root)
	for frame in 900:
		await process_frame
		if game_root.session_mode() == "ending":
			break
	_assert_eq(str(game_root.game.chapter_one_progress.get("phase")), ProgressScript.PHASE_DEMO_END, "the light should end the %s demo" % locale_code)
	_assert_eq(game_root.session_mode(), "ending", "the %s end screen should show" % locale_code)
	game_root.queue_free()
	await process_frame


## Posts the first exit rule the round drops clean, then F at its object; answers the object.
func _leave_by_a_clean_exit_rule(game_root, round_number: int, locale_code: String) -> String:
	var game = game_root.game
	var room: Dictionary = RoomContentScript.room(round_number)
	var dropped: Array = WordDropScript.dropped_exit_rules(room, locale_code, game.polluted_words, game.pollution_policy)
	_assert_true(dropped.size() >= 3, "%s round %d should drop three clean exit rules" % [locale_code, round_number])
	if dropped.is_empty():
		return ""
	var rule: Dictionary = dropped[0]
	var units: Array = WordDropScript.sentence_units(rule, locale_code, room)
	var on_offer: Array = game.get_pickup_unit_pool(locale_code)
	_assert_true(units.all(func(unit: String) -> bool: return unit in on_offer), "%s round %d should offer the words of %s: %s" % [locale_code, round_number, rule["id"], units])
	game.free_sentence_units = units
	_assert_eq(str(game.submit_free_sentence(locale_code).get("tier")), "rule", "%s round %d should hear %s from %s" % [locale_code, round_number, rule["id"], units])
	var object_name := str(rule["object"])
	_assert_eq(game.basement_exits(), [object_name], "round %d's %s should make the %s the way out" % [round_number, rule["id"], object_name])
	var adapter = game_root._reality_scene_adapter
	await _stand_at(game_root, adapter.chapter_exit_reaches(object_name)[0])
	_assert_eq(str(adapter.nearby_outcome().get("object")), object_name, "the %s should answer F in round %d" % [object_name, round_number])
	_push_key(game_root, KEY_F)
	await process_frame
	for frame in 900:
		if str(adapter.interaction_outcome().get("kind")) != "exit" and Harness.find_node_by_name(game_root, "DoorFade") == null:
			break
		await process_frame
	await process_frame
	return object_name


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


func _walk_into_the_light(game_root) -> void:
	var adapter = game_root._reality_scene_adapter
	var door: Vector3 = adapter.chapter_door_position()
	adapter.player.position = Vector3(door.x, adapter.player.position.y, door.z + 2.0)
	adapter.player.velocity = Vector3.ZERO
	adapter.yaw = 0.0
	var before: Dictionary = game_root.game.chapter_one_progress
	Input.action_press("reality_forward")
	for frame in 180:
		await physics_frame
		if game_root.game.chapter_one_progress != before:
			break
	Input.action_release("reality_forward")


func _stand_at(game_root, reach: Vector3) -> void:
	var adapter = game_root._reality_scene_adapter
	adapter.player.position = reach + Vector3(0.0, 0.05, 0.0)
	adapter.player.velocity = Vector3.ZERO
	for frame in 6:
		await physics_frame
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
