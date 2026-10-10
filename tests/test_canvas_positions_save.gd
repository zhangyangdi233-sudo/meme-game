extends SceneTree
## Saving writes the resting word tiles' canvas positions into the position model once.
## A tile still moving or held by the pointer stays on the canvas and is not written.

const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")

const TEST_SAVE_PATH := "user://test_canvas_positions_save.dat"

var _failures: Array[String] = []
var _writes: Array = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _run()
	_remove_test_save()
	if _failures.is_empty():
		print("canvas positions save tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_remove_test_save()
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "canvas save test should load the main scene")
	if scene == null:
		return
	var game_root = scene.instantiate()
	root.add_child(game_root)
	game_root._save_path = TEST_SAVE_PATH
	game_root.new_game()
	game_root._skip_prologue()
	await process_frame

	for unit in ["门", "开", "打"]:
		game_root.game.pick_social_char("floor_13", unit, "zh")
	game_root.game.set_active_app("notebook")
	game_root._ensure_notebook_window_home()
	game_root._render()
	await process_frame
	var canvas := _find_node_by_name(game_root, "NotebookWordCanvas") as WordPhysicsCanvas
	_assert_true(canvas != null, "the open notebook should show the word canvas")
	if canvas == null:
		return
	for _step in 240:
		if canvas.settled_tile_positions().size() == 3:
			break
		await physics_frame
	_assert_eq(canvas.settled_tile_positions().size(), 3, "every tile should come to rest before saving")

	var manager := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	var positions_model := manager.model(PropertyKeysScript.CHAR_CANVAS_POSITIONS) as MapPropertyModel
	var writes := _writes
	positions_model.changed.connect(_on_positions_changed)
	_assert_true((positions_model.read() as Dictionary).is_empty(), "no tile position should be stored before the first save")

	# 一个还在动，一个被指针抓着；两个都不该被写进去。
	var moving_body := canvas.get_node_or_null("WordPhysicsRoot/WordBody_开") as RigidBody2D
	_assert_true(moving_body != null, "the moving tile should have a body")
	if moving_body != null:
		moving_body.linear_velocity = Vector2(280.0, 0.0)
	var grab := InputEventMouseButton.new()
	grab.button_index = MOUSE_BUTTON_LEFT
	grab.pressed = true
	grab.position = canvas.get_tile_position("打") + Vector2(22.0, 20.0)
	canvas._gui_input(grab)
	_assert_true(canvas.is_dragging(), "pressing a tile should grab it")

	_assert_true(game_root._save_progress(), "saving should succeed")
	_assert_eq(writes.size(), 1, "saving should write the canvas positions in one batch")
	var stored := positions_model.read() as Dictionary
	_assert_true(stored.has("zh|门"), "a resting tile should be written before saving")
	_assert_true(not stored.has("zh|开"), "a tile still moving should not be written")
	_assert_true(not stored.has("zh|打"), "a tile held by the pointer should not be written")
	_assert_true(game_root.game.char_canvas_positions.has("zh|门"), "the state should read the saved position back from the model")

	_assert_true(game_root._save_progress(), "saving again should succeed")
	_assert_eq(writes.size(), 1, "saving again with nothing moved should not write")

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	canvas._gui_input(release)
	_assert_true(not canvas.is_dragging(), "releasing the pointer should drop the tile")
	positions_model.changed.disconnect(_on_positions_changed)


func _on_positions_changed(value: Variant) -> void:
	_writes.append(value)


func _remove_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


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
