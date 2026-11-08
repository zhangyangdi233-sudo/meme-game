extends SceneTree
## #129 in the main scene with the authored rooms: in rounds two and four someone behind the sealed door under the
## landing knocks, a few seconds at a time, until the player first talks to them through it. A save keeps each round
## as it was. Nobody opens that door; finished with this round's post, the one behind it says they will help, and the
## exit door opens for the player to walk out. Rounds one, three and five have nobody there.

const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const StateScript = preload("res://scripts/meme_game_state.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const TEST_SAVE_PATH := "user://test_door_npc_scene_save.dat"
const TEST_PREFERENCES_PATH := "user://test_door_npc_scene_preferences.cfg"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	root.size = Vector2i(1600, 900)
	_remove_files()
	await _run()
	_remove_files()
	if _failures.is_empty():
		print("door npc scene tests passed")
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
	await _test_round_one_has_nobody_behind_the_door(game_root)
	await _test_round_two_knocks_until_the_first_talk(game_root)
	await _test_a_save_keeps_round_two_quiet(game_root)
	await _test_the_npcs_help_opens_the_exit_door(game_root)
	await _test_round_four_knocks_on_its_own(game_root)
	game_root.queue_free()
	await process_frame


func _test_round_one_has_nobody_behind_the_door(game_root) -> void:
	await _jump(game_root, 1)
	_assert_true(_find(game_root, "StairCloset_Door") != null, "the sealed door should stand under the landing in round one")
	_assert_true(_find(game_root, "SealedDoorKnock") == null, "nobody should knock in round one")
	_assert_true(_find(game_root, "BasementNPC") == null, "nobody should answer behind the door in round one")


func _test_round_two_knocks_until_the_first_talk(game_root) -> void:
	await _jump(game_root, 2)
	_assert_true(_knock(game_root) != null and _knock(game_root).playing, "round two should start with knocking behind the door")
	await _talk_to_the_npc(game_root)
	_assert_true(ProgressScript.talked_to_npc(game_root.game.chapter_one_progress), "the talk should be recorded")
	await process_frame
	_assert_true(not _knock(game_root).playing, "the first talk should stop the knocking")
	await _play_out(game_root)
	_assert_true(not ProgressScript.exit_open(game_root.game.chapter_one_progress), "without this round's post the exit should stay shut")
	_assert_true(not _knocks_within_a_cycle(game_root), "the door should stay quiet after the conversation")


func _test_a_save_keeps_round_two_quiet(game_root) -> void:
	_assert_true(game_root._save_progress(), "the run should save in round two")
	game_root.show_main_menu()
	await process_frame
	_assert_true(game_root.continue_game(), "the save should continue")
	await process_frame
	await process_frame
	_assert_eq(ProgressScript.round_of(game_root.game.chapter_one_progress), 2, "the save should come back in round two")
	_assert_true(_knock(game_root) != null, "the loaded round should still have someone behind the door")
	_assert_true(not _knocks_within_a_cycle(game_root), "a loaded round already talked to should stay quiet")


func _test_the_npcs_help_opens_the_exit_door(game_root) -> void:
	game_root.game.free_sentence_units = ["我", "是", "你"]
	_assert_true(bool(game_root.game.submit_free_sentence("zh").get("submitted")), "setup should post a sentence")
	_assert_true(not ProgressScript.exit_open(game_root.game.chapter_one_progress), "a post that hits no exit rule should open nothing by itself")
	await _talk_to_the_npc(game_root)
	await _type_until_the_last_reply(game_root)
	_assert_true(game_root.game.conversation_feedback.ends_with(StateScript.BASEMENT_HELPED_LINE), "the one behind the door should say they will help the player out")
	await _play_out(game_root)
	_assert_eq(game_root.game.basement_exits(), ["door"], "the NPC's help should open the exit door")
	for frame in 90:
		await process_frame
	var exit_door := _find(game_root, "ExitDoorPivot") as Node3D
	_assert_true(exit_door != null and absf(exit_door.rotation_degrees.y) > 45.0, "the exit door should swing open")
	await _walk_out(game_root)
	_assert_eq(ProgressScript.round_of(game_root.game.chapter_one_progress), 3, "walking out of the exit door should start round three")
	_assert_true(_find(game_root, "SealedDoorKnock") == null, "nobody should knock in round three")


func _test_round_four_knocks_on_its_own(game_root) -> void:
	await _jump(game_root, 4)
	_assert_true(not ProgressScript.talked_to_npc(game_root.game.chapter_one_progress), "round four's NPC should not have been talked to")
	_assert_true(_knock(game_root) != null and _knock(game_root).playing, "round four should knock on its own")
	await _talk_to_the_npc(game_root)
	await process_frame
	_assert_true(not _knock(game_root).playing, "talking in round four should stop its knocking too")
	await _play_out(game_root)


func _jump(game_root, round_number: int) -> void:
	GameEventBus.raise(UiIntentsScript.CHAPTER_ROUND_JUMP_REQUESTED, {UiIntentsScript.KEY_INDEX: round_number})
	await process_frame
	await process_frame
	_assert_eq(ProgressScript.round_of(game_root.game.chapter_one_progress), round_number, "the jump should land on round %d" % round_number)


func _knock(game_root) -> AudioStreamPlayer3D:
	return _find(game_root, "SealedDoorKnock") as AudioStreamPlayer3D


## Whether the door knocks at any point over one whole cycle of knocking and pausing.
func _knocks_within_a_cycle(game_root) -> bool:
	var stage := _find(game_root, "ChapterOneStage") as ChapterOneStage
	var knock := _knock(game_root)
	var step := 0.5
	var elapsed := 0.0
	while elapsed < ChapterOneStage.DOOR_KNOCK_SECONDS + ChapterOneStage.DOOR_KNOCK_PAUSE_SECONDS:
		stage.advance_door_knock(step)
		elapsed += step
		if knock.playing:
			return true
	return false


func _talk_to_the_npc(game_root) -> void:
	var adapter = game_root._reality_scene_adapter
	var npc: Vector3 = adapter.chapter_npc_position()
	# In front of the sealed door, between the stairs and the Windsor chair.
	adapter.player.position = Vector3(npc.x + 0.35, 0.1, npc.z + 0.5)
	adapter.player.velocity = Vector3.ZERO
	for frame in 6:
		await physics_frame
	await process_frame
	_assert_eq(str(adapter.nearby_outcome().get("actor_type")), "basement_npc", "the one behind the door should answer in front of it")
	_push_key(game_root, KEY_F)
	await process_frame
	_assert_true(game_root._reality_interaction_is_active(), "F at the sealed door should start the conversation")


func _type_line(game_root) -> void:
	var guard := 0
	while game_root.game.conversation_phase == "typing" and guard < 200:
		_push_key(game_root, KEY_J)
		guard += 1
	await process_frame


## Types every line until the NPC's last reply is showing.
func _type_until_the_last_reply(game_root) -> void:
	var guard := 0
	while guard < 20:
		await _type_line(game_root)
		if game_root.game.conversation_completed:
			return
		game_root._process(30.0)
		await process_frame
		guard += 1


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
	# Walking out plays the exit transition every exit object shares before the next stage is built.
	for frame in 900:
		if str(adapter.interaction_outcome().get("kind")) != "exit":
			break
		await process_frame
	await process_frame


func _find(game_root, node_name: String) -> Node:
	return game_root.find_child(node_name, true, false)


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
