extends SceneTree
## In the main scene the basement is played in five rounds: F at the round's NPC starts its one route, text keys type
## the player's line (arrows and held repeats do not), each reply plays out by itself and the last ends the
## conversation. With this round's post the exit opens and walking out starts the next round at the top of the
## stairs; the fifth exit leads to the white door passage, and walking into the light ends on the demo's end screen in
## the chosen language. A save comes back on the same round and delivery, in the passage or on the end screen, and the
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
	await _test_the_fifth_exit_leads_through_the_light_to_the_demo_end(game_root)
	await _test_a_save_comes_back_in_the_passage_and_on_the_demo_end(game_root)
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


func _test_the_fifth_exit_leads_through_the_light_to_the_demo_end(game_root) -> void:
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
	_assert_eq(str(game_root.game.chapter_one_progress.get("phase")), ProgressScript.PHASE_PASSAGE, "the fifth exit should lead to the passage")
	_assert_true(Harness.find_node_by_name(game_root, "BasementRoom") == null, "the passage should replace the basement")
	_assert_true(Harness.find_node_by_name(game_root, "OpeningWorld") != null, "the passage should be the black water with the white door")
	_assert_true(not game_root._reality_scene_adapter.floor.visible, "the tower's street should stay out of reach")
	await _walk_into_the_light(game_root)
	_assert_eq(str(game_root.game.chapter_one_progress.get("phase")), ProgressScript.PHASE_DEMO_END, "walking into the light should end the demo")
	_assert_eq(game_root.session_mode(), "gameplay", "the end screen should wait for the light to cover the screen")
	_assert_true(game_root._phone_locked(), "the phone should stay down in the light")
	var fade: ColorRect = null
	for frame in 400:
		await process_frame
		fade = Harness.find_node_by_name(game_root, "DoorFade") as ColorRect
		if fade != null and fade.color.a > 0.5:
			break
	_assert_true(fade != null and fade.color.r > 0.99 and fade.color.g > 0.99 and fade.color.b > 0.99, "the screen should fill with white, not black")
	for frame in 400:
		await process_frame
		if game_root.session_mode() == "ending":
			break
	_assert_eq(game_root.session_mode(), "ending", "the light should turn into the end screen")
	var text := Harness.find_node_by_name(game_root, "DemoEndText") as Label
	_assert_true(text != null and text.is_visible_in_tree(), "the demo end text should show")
	_assert_eq(text.text if text != null else "", "Demo 到此结束", "the end screen should use the chosen language")
	_assert_true(Harness.find_node_by_name(game_root, "EndingScreen") == null, "the tower's ending should stay out of the demo")
	_assert_eq(game_root.game.tower_floor, 1, "the tower should not have been climbed")


func _test_a_save_comes_back_in_the_passage_and_on_the_demo_end(game_root) -> void:
	_assert_true(game_root._save_progress(), "the end screen should save")
	await _reload(game_root)
	_assert_eq(game_root.session_mode(), "ending", "a save at the demo's end should come back on its screen")
	_assert_true(Harness.find_node_by_name(game_root, "DemoEndText") != null, "the demo end text should come back")
	var menu_button := Harness.find_node_by_name(game_root, "DemoEndMenuButton") as Button
	_assert_true(menu_button != null, "the end screen should offer the way back to the menu")
	if menu_button != null:
		menu_button.pressed.emit()
	await process_frame
	await process_frame
	_assert_eq(game_root.session_mode(), "main_menu", "the end screen's button should leave for the main menu")
	_assert_true(Harness.find_node_by_name(game_root, "DemoEndText") == null, "the end screen should go away with the run")
	await _continue(game_root)
	GameEventBus.raise(UiIntentsScript.CHAPTER_ROUND_JUMP_REQUESTED, {UiIntentsScript.KEY_INDEX: 5})
	await process_frame
	await process_frame
	_assert_eq(game_root.session_mode(), "gameplay", "a debug jump should leave the end screen")
	_post(game_root)
	await _talk_to_the_npc(game_root)
	await _play_out(game_root)
	for frame in 90:
		await process_frame
	await _walk_out(game_root)
	await process_frame
	var adapter = game_root._reality_scene_adapter
	var door: Vector3 = adapter.chapter_door_position()
	adapter.player.position = Vector3(door.x, adapter.player.position.y, door.z + 10.0)
	var saved_at: Vector3 = adapter.player.position
	_assert_true(game_root._save_progress(), "the passage should save")
	await _reload(game_root)
	_assert_eq(str(game_root.game.chapter_one_progress.get("phase")), ProgressScript.PHASE_PASSAGE, "a save in the passage should come back in it")
	_assert_eq(game_root.session_mode(), "gameplay", "a save in the passage should be played on")
	_assert_true(Harness.find_node_by_name(game_root, "OpeningWorld") != null, "a save in the passage should stand on the black water")
	var restored: Vector3 = game_root._reality_scene_adapter.player.position
	_assert_true(Vector2(restored.x, restored.z).distance_to(Vector2(saved_at.x, saved_at.z)) < 0.2, "a save in the passage should come back where it was: %s" % str(restored))
	await _walk_into_the_light(game_root)
	_assert_true(game_root._save_progress(), "the walk through the light should save")
	await _reload(game_root)
	_assert_eq(game_root.session_mode(), "ending", "a save in the light should come back on the end screen")
	game_root.new_game()
	await process_frame
	while game_root.game.advance_opening_narration():
		pass
	game_root.game.complete_opening_knock()
	_assert_true(game_root._open_reality_door(), "a new run's white door should open")
	_assert_eq(game_root._door_fade_color(), UiPalette.VOID, "the light left behind should not whiten a new run's door")


func _reload(game_root) -> void:
	game_root.show_main_menu()
	await process_frame
	await _continue(game_root)


func _continue(game_root) -> void:
	game_root.continue_game()
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
	await process_frame


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
