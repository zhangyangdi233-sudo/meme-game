extends SceneTree
## The planner's 2026-11-16 decision (overriding #129): the demo has no NPC knocking behind the sealed door. In the main
## scene with the authored rooms nobody knocks on their own, and before round four's bang F in front of the door starts
## no conversation and the world prompt never offers "交谈". The door itself stays: taped shut, and in round four it is
## banged once from inside after the player has come near it and walked away, once a run, also across a save.
## The planner's 2026-11-20 request: once round four's door has been banged on, standing in front of it offers the talk
## (F), which runs round four's conversation; it opens no exit, and no other round answers.

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
	await _test_no_round_stands_anybody_behind_the_door(game_root)
	await _test_round_four_bangs_the_door_once_and_a_save_keeps_it_quiet(game_root)
	game_root.queue_free()
	await process_frame


func _test_no_round_stands_anybody_behind_the_door(game_root) -> void:
	for round_number in range(1, ProgressScript.BASEMENT_ROUND_COUNT + 1):
		await _jump(game_root, round_number)
		_assert_true(_find(game_root, "StairCloset_Door") != null, "the sealed door should stand under the landing in round %d" % round_number)
		if round_number != 4:
			_assert_true(_find(game_root, "BasementNPC") == null, "nobody should answer behind the door in round %d" % round_number)
		_assert_true(_knock(game_root) == null or not _knock(game_root).playing, "nobody should knock on their own in round %d" % round_number)
		await _stand_in_front_of_the_door(game_root)
		_assert_true(str(game_root._reality_scene_adapter.nearby_outcome().get("kind")) != "actor", "the door should offer no conversation before any bang in round %d" % round_number)
		_assert_true(not game_root._world_prompt.text.contains("交谈"), "the world prompt should offer no talk before any bang in round %d" % round_number)
		_push_key(game_root, KEY_F)
		await process_frame
		_assert_true(not game_root._reality_interaction_is_active(), "F in front of the sealed door should start no conversation in round %d" % round_number)
		_assert_true(not ProgressScript.talked_to_npc(game_root.game.chapter_one_progress), "no talk should be recorded in round %d" % round_number)


func _test_round_four_bangs_the_door_once_and_a_save_keeps_it_quiet(game_root) -> void:
	await _jump(game_root, 4)
	_assert_true("door_bang" not in ProgressScript.started_events(game_root.game.chapter_one_progress), "round four should start without the bang")
	await _come_near_and_walk_away(game_root)
	_assert_true("door_bang" in ProgressScript.started_events(game_root.game.chapter_one_progress), "walking away from the door should record the bang")
	_assert_true(_knock(game_root) != null and _knock(game_root).playing, "the door should be heard banging")
	await _stand_in_front_of_the_door(game_root)
	_assert_true(str(game_root._reality_scene_adapter.nearby_outcome().get("action")) != "converse", "the door should not answer while it is still being hit")
	# The bang lasts as long as one piece of the knocking; the talk is offered once it is over.
	await create_timer(ChapterOneStage.DOOR_KNOCK_SECONDS + 0.5).timeout
	await _stand_in_front_of_the_door(game_root)
	_assert_eq(str(game_root._reality_scene_adapter.nearby_outcome().get("action")), "converse", "after the bang the door should offer the talk")
	_assert_true(game_root._world_prompt.text.contains("交谈"), "after the bang the world prompt should offer the talk")
	_assert_true(game_root._save_progress(), "the run should save after the bang")
	game_root.show_main_menu()
	await process_frame
	_assert_true(game_root.continue_game(), "the save should continue")
	await process_frame
	await process_frame
	_assert_eq(ProgressScript.round_of(game_root.game.chapter_one_progress), 4, "the save should come back in round four")
	_assert_true("door_bang" in ProgressScript.started_events(game_root.game.chapter_one_progress), "the save should keep the bang")
	await _come_near_and_walk_away(game_root)
	_assert_true(_knock(game_root) == null or not _knock(game_root).playing, "a loaded round already banged should stay quiet: nobody knocks on their own")
	await _stand_in_front_of_the_door(game_root)
	_assert_eq(str(game_root._reality_scene_adapter.nearby_outcome().get("action")), "converse", "a loaded round already banged should still offer the talk")
	_push_key(game_root, KEY_F)
	await process_frame
	_assert_true(game_root._reality_interaction_is_active(), "F in front of the banged door should start the conversation")
	_assert_true(ProgressScript.talked_to_npc(game_root.game.chapter_one_progress), "the talk should be recorded")
	_assert_eq(game_root.game.conversation_actor_type, ProgressScript.BASEMENT_NPC_ACTOR_TYPE, "the talk should be round four's conversation behind the door")
	_assert_eq(game_root.game.basement_exits(), [], "talking should open no exit in round four")


func _jump(game_root, round_number: int) -> void:
	GameEventBus.raise(UiIntentsScript.CHAPTER_ROUND_JUMP_REQUESTED, {UiIntentsScript.KEY_INDEX: round_number})
	await process_frame
	await process_frame
	_assert_eq(ProgressScript.round_of(game_root.game.chapter_one_progress), round_number, "the jump should land on round %d" % round_number)


func _knock(game_root) -> AudioStreamPlayer3D:
	return _find(game_root, "SealedDoorKnock") as AudioStreamPlayer3D


## Walks the player down past the entry's seal, up to the sealed door, then away from it down the stairs' foot.
func _come_near_and_walk_away(game_root) -> void:
	var adapter = game_root._reality_scene_adapter
	for point in [Vector3(-1.0, 0.1, 1.5), Vector3(-1.0, 0.1, -1.0), Vector3(-1.0, 0.1, 1.5)]:
		adapter.player.position = point
		adapter.player.velocity = Vector3.ZERO
		for frame in 12:
			await physics_frame
			await process_frame


func _stand_in_front_of_the_door(game_root) -> void:
	var adapter = game_root._reality_scene_adapter
	# In front of the sealed door, between the stairs and the Windsor chair.
	var door: Vector3 = ChapterOneStage.SEALED_DOOR_ANCHOR
	adapter.player.position = Vector3(door.x + 0.35, 0.1, door.z + 0.5)
	adapter.player.velocity = Vector3.ZERO
	for frame in 6:
		await physics_frame
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
