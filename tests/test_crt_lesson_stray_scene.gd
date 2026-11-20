extends SceneTree
## In the main scene's round one, a word placed on the phone before the CRT lesson must not leave the lesson's compose
## step stuck (the terminal's notebook has no take-out control): with every lesson word held and the terminal's notebook
## showing, the lesson takes the stray word out of the sentence, and the lesson's words then bring it to the post step.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const LessonScript = preload("res://scripts/game/crt_lesson.gd")
const PickupCharPoolScript = preload("res://scripts/narrative/pickup_char_pool.gd")
const RoomContentScript = preload("res://scripts/game/room_content.gd")
const TEST_SAVE_PATH := "user://test_crt_lesson_stray_scene_save.dat"
const TEST_PREFERENCES_PATH := "user://test_crt_lesson_stray_scene_preferences.cfg"
const STRAY := "我"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	root.size = Vector2i(1600, 900)
	_remove_files()
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	var game_root = scene.instantiate()
	game_root._save_path = TEST_SAVE_PATH
	root.add_child(game_root)
	await process_frame
	game_root._locale.preferences_path = TEST_PREFERENCES_PATH
	game_root._locale.set_locale("zh")
	await _test_the_lesson_takes_a_stray_word_out(game_root)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	game_root.queue_free()
	await process_frame
	_remove_files()
	if _failures.is_empty():
		print("crt lesson stray scene tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_the_lesson_takes_a_stray_word_out(game_root) -> void:
	game_root.new_game()
	await process_frame
	game_root._jump_to_basement_round(1)
	await process_frame
	await process_frame
	var game = game_root.game
	var teaching: Array = LessonScript.teaching_units(RoomContentScript.room(1), "zh")
	for unit: String in teaching + [STRAY]:
		_assert_true(bool(game.pick_social_char(_post_offering(unit), unit, "zh").get("picked", false)), "setup should pick up %s" % unit)
	_assert_true(game.free_sentence_place(STRAY, "zh"), "setup should place a word that is not the lesson's, as the phone lets the player")
	var adapter = game_root._reality_scene_adapter
	adapter.player.position = adapter.chapter_terminal_position() + Vector3(0.0, 0.02, 0.0)
	adapter.player.velocity = Vector3.ZERO
	for frame in 10:
		await physics_frame
	game_root.set_view_state("npc_up")
	_push_key(game_root, KEY_F)
	for frame in 4:
		await process_frame
	_assert_eq(str(adapter.interaction_outcome().get("kind")), "terminal", "setup should enter the terminal")
	var panel = game_root._crt_terminal_panel
	_assert_eq(panel.lesson_step(), LessonScript.STEP_NOTEBOOK, "every lesson word held should ask for the notebook")
	var display := Harness.find_node_by_name(game_root, "CrtTerminalDisplay")
	(Harness.find_node_by_name(display, "TerminalAppNotebook") as Button).pressed.emit()
	for frame in 6:
		await process_frame
	_assert_eq(panel.lesson_step(), LessonScript.STEP_COMPOSE, "the notebook showing should ask for the sentence")
	_assert_true(STRAY not in game.free_sentence_units, "the lesson should take the stray word out of the sentence: %s" % str(game.free_sentence_units))
	for unit: String in teaching:
		_assert_true(game.free_sentence_place(unit, "zh"), "%s should be placed once the stray word is gone" % unit)
	for frame in 4:
		await process_frame
	_assert_eq(panel.lesson_step(), LessonScript.STEP_PUBLISH, "the lesson's words alone should bring the post step")


func _post_offering(unit: String) -> String:
	for post_id in PickupCharPoolScript.get_post_ids():
		if PickupCharPoolScript.is_unit_seeded_in_post(str(post_id), unit, "zh"):
			return str(post_id)
	return ""


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
