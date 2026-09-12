extends SceneTree

var _failures: Array[String] = []
const TEST_SAVE_PATH := "user://test_babel_meme_save.dat"


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _run()
	_remove_test_save()
	if _failures.is_empty():
		print("save progress tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_remove_test_save()
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "save test should load the main scene")
	if scene == null:
		return
	var game_root = scene.instantiate()
	root.add_child(game_root)
	game_root._save_path = TEST_SAVE_PATH
	game_root.new_game()
	game_root._skip_prologue()
	game_root.game.day = 4
	game_root.game.pollution = 47
	game_root.game.money = 31
	game_root.game.tower_floor = 2
	game_root.game.actions_remaining = 3
	game_root.game.completed_memes = [{
		"id": "saved-meme", "title": "路口旧词", "text": "旧词在路口", "tags": ["日常"],
		"rarity": 1, "pollution_bias": 0, "clarity_bias": 0, "source_passives": [],
	}]
	game_root.set_view_state("npc_up")
	game_root._ensure_reality_floor_current()
	var watcher_event := _find_node_by_name(game_root._reality_scene_adapter.floor, "CoverWatcherEvent") as Node3D
	var watcher_sprite := _find_node_by_name(game_root._reality_scene_adapter.floor, "CoverWatcherSprite") as Sprite3D
	_assert_true(watcher_event != null and watcher_sprite != null, "an unseen floor should build its cover watcher before saving")
	if watcher_event != null and watcher_sprite != null:
		var watcher_start: Vector3 = game_root._reality_scene_adapter.floor.start_position()
		game_root._reality_scene_adapter.player.position = watcher_start
		var toward_watcher := (watcher_event.global_position - watcher_start).normalized()
		game_root._reality_scene_adapter.floor.update_authored_events(0.80, watcher_start, toward_watcher)
		_assert_true(watcher_sprite.visible and game_root.game.has_seen_cover_watcher(2), "runtime observation should route through the main-scene signal and record floor two")
		var stinger := game_root.get_node_or_null("CoverWatcherStinger") as AudioStreamPlayer
		_assert_true(stinger != null and stinger.playing, "the real watcher appearance signal should start its short horror cue")
		var near_watcher := watcher_event.global_position + Vector3(0.0, 0.0, 5.7)
		game_root._reality_scene_adapter.floor.update_authored_events(0.08, near_watcher, toward_watcher)
		game_root._reality_scene_adapter.floor.update_authored_events(0.72, near_watcher, toward_watcher)
		_assert_true(not watcher_sprite.visible and bool(game_root._reality_scene_adapter.floor.get_cover_watcher_state().get("vanished", false)), "approaching through the runtime path should fully withdraw the watcher")
	var saved_position := Vector3(2.25, 0.08, 17.5)
	game_root._reality_scene_adapter.player.position = saved_position
	game_root._reality_scene_adapter.yaw = 38.0
	game_root._reality_scene_adapter.pitch = -12.0
	game_root.show_main_menu()
	await process_frame

	_assert_true(FileAccess.file_exists(TEST_SAVE_PATH), "returning to the main menu should create an automatic save")
	var continue_button := _find_node_by_name(game_root, "MainMenuContinueButton") as Button
	_assert_true(continue_button != null and not continue_button.disabled, "main menu should enable Continue when a save exists")
	_assert_true(game_root.continue_game(), "Continue should load a valid automatic save")
	await process_frame
	_assert_eq(game_root.game.day, 4, "Continue should restore the saved day")
	_assert_eq(game_root.game.pollution, 47, "Continue should restore pollution")
	_assert_eq(game_root.game.money, 31, "Continue should restore money")
	_assert_eq(game_root.game.tower_floor, 2, "Continue should restore tower progress")
	_assert_eq(game_root.game.actions_remaining, 3, "Continue should restore today's remaining actions")
	_assert_eq(game_root.game.completed_memes.size(), 1, "Continue should restore crafted memes")
	_assert_true(game_root.game.has_seen_cover_watcher(2), "Continue should restore the watcher floor history from the actual save file")
	_assert_true(_find_node_by_name(game_root._reality_scene_adapter.floor, "CoverWatcherEvent") == null, "reloading the same floor should not rebuild an already observed watcher")
	_assert_eq(game_root.game.view_state, "npc_up", "Continue should restore the previous phone or reality view")
	var restored_position: Vector3 = game_root._reality_scene_adapter.player.position
	var planar_error := Vector2(restored_position.x, restored_position.z).distance_to(Vector2(saved_position.x, saved_position.z))
	_assert_true(planar_error < 0.05, "Continue should return the player to the saved world position (got %s)" % str(restored_position))
	_assert_true(is_equal_approx(game_root._reality_scene_adapter.yaw, 38.0) and is_equal_approx(game_root._reality_scene_adapter.pitch, -12.0), "Continue should restore camera orientation")
	var prologue := _find_node_by_name(game_root, "PrologueOverlay") as Control
	_assert_true(prologue != null and not prologue.visible, "Continue should not replay the prologue")
	game_root.queue_free()
	await process_frame


func _remove_test_save() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_SAVE_PATH)
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(absolute_path)


func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found := _find_node_by_name(child, target_name)
		if found != null:
			return found
	return null


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
