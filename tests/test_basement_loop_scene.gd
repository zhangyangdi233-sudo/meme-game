extends SceneTree
## In the main scene the basement is played in five rounds: F at the round's NPC starts its one route, text keys type
## the player's line (arrows and held repeats do not), each reply plays out by itself and the last ends the
## conversation. With this round's post the exit opens and walking out starts the next round at the top of the
## stairs; the fifth exit leads to the empty crossroads. A save comes back on the same round and delivery, and the
## F9 debug panel jumps between rounds.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const TEST_SAVE_PATH := "user://test_basement_loop_scene_save.dat"
const TEST_PREFERENCES_PATH := "user://test_basement_loop_scene_preferences.cfg"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	root.size = Vector2i(1600, 900)
	_remove_files()
	await _run()
	_remove_files()
	if _failures.is_empty():
		print("basement loop scene tests passed")
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
	await _test_f9_shows_the_debug_panel_and_jumps_to_a_round(game_root)
	await _test_the_npc_conversation_types_and_plays_out_by_itself(game_root)
	await _test_without_a_post_the_exit_stays_shut(game_root)
	await _test_with_this_rounds_post_the_exit_leads_to_the_next_round(game_root)
	await _test_a_save_comes_back_on_the_same_round(game_root)
	await _test_the_fifth_exit_leads_to_the_empty_crossroads(game_root)
	game_root.queue_free()
	await process_frame


func _test_f9_shows_the_debug_panel_and_jumps_to_a_round(game_root) -> void:
	_assert_true(Harness.find_node_by_name(game_root, "ChapterDebugPanel") == null, "the chapter debug panel should wait for F9")
	_push_key(game_root, KEY_F9)
	await process_frame
	var panel := Harness.find_node_by_name(game_root, "ChapterDebugPanel") as Control
	_assert_true(panel != null and panel.is_visible_in_tree(), "F9 in a debug build should show the chapter debug panel")
	(Harness.find_node_by_name(panel, "ChapterDebugRound2Button") as Button).pressed.emit()
	await process_frame
	await process_frame
	_assert_eq(ProgressScript.round_of(game_root.game.chapter_one_progress), 2, "the panel should jump to round two")
	_assert_true(Harness.find_node_by_name(game_root, "BasementRoom") != null, "the jump should build the basement")
	_assert_eq(str(game_root.game.view_state), "npc_up", "the jump should put the phone down")
	_push_key(game_root, KEY_F9)
	await process_frame
	_assert_true(not panel.is_visible_in_tree(), "F9 again should put the panel away")
	game_root._dialog_debug_enabled = false
	_push_key(game_root, KEY_F9)
	await process_frame
	_assert_true(not panel.is_visible_in_tree(), "a release build should not show the chapter debug panel")
	game_root._dialog_debug_enabled = true
	GameEventBus.raise(UiIntentsScript.CHAPTER_ROUND_JUMP_REQUESTED, {UiIntentsScript.KEY_INDEX: 1})
	await process_frame
	await process_frame
	_assert_eq(ProgressScript.round_of(game_root.game.chapter_one_progress), 1, "a jump request should land on round one")


func _test_the_npc_conversation_types_and_plays_out_by_itself(game_root) -> void:
	await _talk_to_the_npc(game_root)
	var game = game_root.game
	_assert_eq(game.conversation_phase, "typing", "F at the NPC should start the player's turn")
	var continue_button := Harness.find_node_by_name(game_root, "RealityConversationContinue") as Button
	_assert_true(continue_button == null or not continue_button.is_visible_in_tree(), "the conversation should show no button")
	var choices := Harness.find_node_by_name(game_root, "RealityResponseChoices") as Control
	_assert_true(choices == null or not choices.is_visible_in_tree(), "the conversation should show no choices")
	for keycode in [KEY_LEFT, KEY_UP, KEY_SHIFT, KEY_TAB]:
		_push_key(game_root, keycode)
	await process_frame
	_assert_eq(game.conversation_reveal_index, 0, "arrows, modifiers and Tab should not type")
	_assert_eq(str(game.view_state), "npc_up", "Tab in a conversation should not raise the phone")
	_push_key(game_root, KEY_A)
	await process_frame
	_assert_eq(game.conversation_reveal_index, 1, "a letter key should type one unit")
	_push_key(game_root, KEY_A, true)
	await process_frame
	_assert_eq(game.conversation_reveal_index, 1, "a held key's repeat should not type")
	_push_key(game_root, KEY_F)
	await process_frame
	_assert_eq(game.conversation_reveal_index, 2, "F should type inside a conversation instead of leaving it")
	await _type_line(game_root)
	_assert_eq(game.conversation_phase, "result", "the NPC's reply should follow the typed line")
	_push_key(game_root, KEY_F)
	await process_frame
	_assert_true(game_root._reality_interaction_is_active(), "a key during the reply should not leave the conversation")
	game_root._process(0.5)
	_assert_eq(game.conversation_phase, "result", "the reply should stay while it is read")
	game_root._process(30.0)
	_assert_eq(game.conversation_phase, "typing", "the next turn should follow once the reply was read")
	game_root._exit_reality_interaction()


func _test_without_a_post_the_exit_stays_shut(game_root) -> void:
	await _talk_to_the_npc(game_root)
	await _play_out(game_root)
	_assert_true(not game_root._reality_interaction_is_active(), "the last reply should end the conversation by itself")
	_assert_true(not ProgressScript.exit_open(game_root.game.chapter_one_progress), "without this round's post the exit should stay shut")


func _test_with_this_rounds_post_the_exit_leads_to_the_next_round(game_root) -> void:
	_post(game_root)
	await _talk_to_the_npc(game_root)
	await _play_out(game_root)
	_assert_true(ProgressScript.exit_open(game_root.game.chapter_one_progress), "with this round's post the exit should open")
	for frame in 90:
		await process_frame
	await _walk_out(game_root)
	_assert_eq(ProgressScript.round_of(game_root.game.chapter_one_progress), 2, "walking out should start round two")
	await process_frame
	var start: Vector3 = game_root._reality_scene_adapter.pose().get("player_position")
	_assert_true(start.y > 2.0, "round two should start at the top of the stairs: %s" % str(start))
	_assert_true(not ProgressScript.exit_open(game_root.game.chapter_one_progress), "round two's exit should be shut")


func _test_a_save_comes_back_on_the_same_round(game_root) -> void:
	_post(game_root)
	await _talk_to_the_npc(game_root)
	await _play_out(game_root)
	_assert_true(game_root._save_progress(), "the run should save in round two")
	game_root.show_main_menu()
	await process_frame
	_assert_true(game_root.continue_game(), "the save should continue")
	await process_frame
	await process_frame
	_assert_eq(ProgressScript.round_of(game_root.game.chapter_one_progress), 2, "the save should come back on round two")
	_assert_true(ProgressScript.exit_open(game_root.game.chapter_one_progress), "the save should keep round two delivered")
	_assert_true(Harness.find_node_by_name(game_root, "BasementRoom") != null, "the save should come back in the basement")


func _test_the_fifth_exit_leads_to_the_empty_crossroads(game_root) -> void:
	GameEventBus.raise(UiIntentsScript.CHAPTER_ROUND_JUMP_REQUESTED, {UiIntentsScript.KEY_INDEX: 5})
	await process_frame
	await process_frame
	_post(game_root)
	await _talk_to_the_npc(game_root)
	_assert_eq(str(game_root.game.conversation_actor_label), "无名信徒", "round five should be played with the nameless believer")
	await _play_out(game_root)
	for frame in 90:
		await process_frame
	await _walk_out(game_root)
	await process_frame
	_assert_eq(str(game_root.game.chapter_one_progress.get("phase")), ProgressScript.PHASE_TOWER, "the fifth exit should leave chapter one")
	_assert_eq(game_root.game.tower_floor, 1, "the crossroads should be the tower's first floor")
	_assert_true(Harness.find_node_by_name(game_root, "BasementRoom") == null, "the crossroads should replace the basement")
	_assert_true(game_root._reality_scene_adapter.floor.get_interactable_actors().is_empty(), "nobody should stand at the crossroads")


func _talk_to_the_npc(game_root) -> void:
	var adapter = game_root._reality_scene_adapter
	var npc: Vector3 = adapter.chapter_npc_position()
	adapter.player.position = Vector3(npc.x, 0.1, npc.z + 1.2)
	adapter.player.velocity = Vector3.ZERO
	for frame in 6:
		await physics_frame
	await process_frame
	_assert_eq(str(adapter.nearby_outcome().get("actor_type")), "basement_npc", "the round's NPC should answer in reach")
	_push_key(game_root, KEY_F)
	await process_frame
	_assert_true(game_root._reality_interaction_is_active(), "F at the NPC should start the conversation")


func _type_line(game_root) -> void:
	var guard := 0
	while game_root.game.conversation_phase == "typing" and guard < 200:
		_push_key(game_root, KEY_J)
		guard += 1
	await process_frame


## Types every line and lets every reply play out.
func _play_out(game_root) -> void:
	var guard := 0
	while game_root._reality_interaction_is_active() and guard < 20:
		await _type_line(game_root)
		game_root._process(30.0)
		await process_frame
		guard += 1


func _walk_out(game_root) -> void:
	var adapter = game_root._reality_scene_adapter
	var exit: Vector3 = adapter.chapter_exit_position()
	adapter.player.position = Vector3(exit.x + 0.7, 0.1, exit.z)
	adapter.player.velocity = Vector3.ZERO
	adapter.yaw = 90.0
	var before: Dictionary = game_root.game.chapter_one_progress
	Input.action_press("reality_forward")
	for frame in 120:
		await physics_frame
		if game_root.game.chapter_one_progress != before:
			break
	Input.action_release("reality_forward")
	await process_frame


func _post(game_root) -> void:
	game_root.game.free_sentence_units = ["灯"]
	_assert_true(bool(game_root.game.submit_free_sentence("zh").get("submitted")), "setup should post a sentence")


func _push_key(game_root, keycode: Key, echo: bool = false) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = keycode
		key.physical_keycode = keycode
		var text := OS.get_keycode_string(keycode)
		key.unicode = text.to_lower().unicode_at(0) if text.length() == 1 else 0
		key.pressed = pressed
		key.echo = echo and pressed
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
