extends SceneTree
## Returning to the title writes the save; START continues from it, and starts a new game when the save is missing or unreadable.
## Holding START with a save and answering YES starts a new game through the host.

const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const Harness = preload("res://tests/harness/minimal_game_harness.gd")

var _failures: Array[String] = []
var _warnings := WarningLog.new()
const TEST_SAVE_PATH := "user://test_babel_meme_save.dat"


## Collects the warnings pushed while a test runs.
class WarningLog extends Logger:
	var lines: Array[String] = []

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			lines.append(rationale if not rationale.is_empty() else code)

	func take() -> Array[String]:
		var taken := lines.duplicate()
		lines.clear()
		return taken


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
	game_root.game.tower_floor = 2
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
	game_root._reality_scene_adapter.restore_world_pose({
		"player_position": saved_position,
		"yaw": 38.0,
		"pitch": -12.0,
	})
	game_root.show_main_menu()
	await process_frame

	_assert_true(FileAccess.file_exists(TEST_SAVE_PATH), "returning to the main menu should create an automatic save")
	_assert_true(_find_node_by_name(game_root, "MainMenuContinueButton") == null, "the main menu should have no separate continue button")
	_assert_eq(_has_save_model(), true, "returning to the main menu should publish the save")
	await _press_start(game_root)
	_assert_eq(game_root.game.day, 4, "Continue should restore the saved day")
	_assert_eq(game_root.game.pollution, 47, "Continue should restore pollution")
	_assert_eq(game_root.game.tower_floor, 2, "Continue should restore tower progress")
	_assert_eq(game_root.game.completed_memes.size(), 1, "Continue should restore crafted memes")
	_assert_true(game_root.game.has_seen_cover_watcher(2), "Continue should restore the watcher floor history from the actual save file")
	_assert_true(_find_node_by_name(game_root._reality_scene_adapter.floor, "CoverWatcherEvent") == null, "reloading the same floor should not rebuild an already observed watcher")
	_assert_eq(game_root.game.view_state, "npc_up", "Continue should restore the previous phone or reality view")
	var restored_pose: Dictionary = game_root._reality_scene_adapter.pose()
	var restored_position: Vector3 = restored_pose.get("player_position", Vector3.ZERO)
	var planar_error := Vector2(restored_position.x, restored_position.z).distance_to(Vector2(saved_position.x, saved_position.z))
	_assert_true(planar_error < 0.05, "Continue should return the player to the saved world position (got %s)" % str(restored_position))
	_assert_true(is_equal_approx(float(restored_pose.get("yaw", 0.0)), 38.0) and is_equal_approx(float(restored_pose.get("pitch", 0.0)), -12.0), "Continue should restore camera orientation")
	var prologue := _find_node_by_name(game_root, "PrologueOverlay") as Control
	_assert_true(prologue == null, "Continue should not replay the prologue")
	game_root._render()
	_assert_eq(Harness.guidance_leftovers(game_root), [], "a loaded save should show no guide, test aid or tower app")
	_assert_true(not (game_root.game.to_save_data().get("state", {}) as Dictionary).has("tutorial_progress"), "a loaded run should save no tutorial progress")
	await _test_holding_start_and_yes_starts_a_new_game(game_root)
	await _test_start_without_a_save_starts_a_new_game(game_root)
	await _test_start_with_a_broken_save_starts_a_new_game(game_root)
	game_root.queue_free()
	await process_frame


func _test_holding_start_and_yes_starts_a_new_game(game_root: Node) -> void:
	game_root._skip_prologue()
	game_root.game.day = 5
	game_root.show_main_menu()
	await process_frame
	_assert_eq(_has_save_model(), true, "the title should see the save before the hold")
	var hint := _find_node_by_name(game_root, "MainMenuHoldHint") as Label
	_assert_true(hint != null and hint.is_visible_in_tree(), "with a save the title shows the hold hint")
	var start := _find_node_by_name(game_root, "MainMenuStartButton") as BaseButton
	var screen := _find_node_by_name(game_root, "MainMenuLayer")
	if start == null or screen == null:
		_assert_true(false, "the title should show START")
		return
	start.button_down.emit()
	screen._process(1.21)
	var dialog := _find_node_by_name(game_root, "DialogLayer") as Control
	_assert_true(dialog != null and dialog.is_visible_in_tree(), "holding START with a save opens the restart dialog")
	var row := _find_node_by_name(dialog, "DialogButtonRow") if dialog != null else null
	if row == null or row.get_child_count() != 2:
		_assert_true(false, "the restart dialog should offer YES and NO")
		return
	start.button_up.emit()
	(row.get_child(0) as Button).pressed.emit()
	await process_frame
	await process_frame
	_assert_eq(game_root.game.day, 1, "YES should start a new run")
	_assert_true(_find_node_by_name(game_root, "PrologueOverlay") != null, "YES should play the prologue")
	_assert_true(FileAccess.file_exists(TEST_SAVE_PATH), "YES should leave the old save for the next save to overwrite")


func _test_start_without_a_save_starts_a_new_game(game_root: Node) -> void:
	game_root.show_main_menu()
	await process_frame
	_remove_test_save()
	game_root._publish_has_save()
	_assert_eq(_has_save_model(), false, "the title should publish that the save is gone")
	await _press_start(game_root)
	_assert_eq(game_root.game.day, 1, "START without a save should start a new run")
	_assert_true(_find_node_by_name(game_root, "PrologueOverlay") != null, "START without a save should play the prologue")


func _test_start_with_a_broken_save_starts_a_new_game(game_root: Node) -> void:
	for broken in ["corrupt", "missing", "older-version"]:
		game_root._skip_prologue()
		game_root.game.day = 6
		game_root.show_main_menu()
		await process_frame
		if broken == "corrupt":
			var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
			file.store_string("not a save")
			file.close()
		elif broken == "older-version":
			# A run saved before the action economy was removed: the file reads, but its state is version five.
			var reader := FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
			var payload: Dictionary = reader.get_var()
			reader.close()
			(payload["game"] as Dictionary)["version"] = 5
			var writer := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
			writer.store_var(payload)
			writer.close()
		else:
			_remove_test_save()
		# The title still believes a save exists, as when the file breaks after the title read it.
		_write_has_save(true)
		_warnings.take()
		OS.add_logger(_warnings)
		await _press_start(game_root)
		OS.remove_logger(_warnings)
		var logged := _warnings.take()
		_assert_eq(game_root.game.day, 1, "START with a %s save should start a new run" % broken)
		_assert_true(_find_node_by_name(game_root, "PrologueOverlay") != null, "START with a %s save should play the prologue" % broken)
		_assert_eq(logged.size(), 1, "a %s save should be reported with one warning (got %s)" % [broken, str(logged)])


func _press_start(game_root: Node) -> void:
	var start := _find_node_by_name(game_root, "MainMenuStartButton") as BaseButton
	_assert_true(start != null and start.is_visible_in_tree(), "the title should show START")
	if start != null:
		start.pressed.emit()
	await process_frame
	await process_frame


func _has_save_model() -> Variant:
	var manager := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	return manager.model(PropertyKeysScript.HAS_SAVE).read() if manager != null else null


func _write_has_save(value: bool) -> void:
	var manager := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	if manager != null:
		(manager.model(PropertyKeysScript.HAS_SAVE) as ValuePropertyModel).write(value)


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
