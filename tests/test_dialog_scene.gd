extends SceneTree
## The host binds the dialog screen manager at boot; the title shows a debug-only panel that opens sample dialogs;
## the same panel simulates the save for START without touching the save file;
## an open dialog sits above every other game UI and a rebuilt world leaves it closed and reusable.

const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const TEST_SAVE_PATH := "user://test_dialog_scene_save.dat"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	root.size = Vector2i(1600, 900)
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "dialog scene test should load the main scene")
	if scene != null:
		var game_root := scene.instantiate()
		root.add_child(game_root)
		game_root._locale.set_locale("zh")
		await process_frame
		_test_boot_binds_the_dialog_manager(game_root)
		await _test_the_title_debug_panel_opens_sample_dialogs(game_root)
		await _test_the_debug_panel_simulates_the_save(game_root)
		_test_the_debug_panel_needs_a_debug_build(game_root)
		await _test_an_open_dialog_sits_above_every_game_ui(game_root)
		game_root.queue_free()
		await process_frame
	if _failures.is_empty():
		print("dialog scene tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_boot_binds_the_dialog_manager(game_root: Node) -> void:
	_assert_true(RegistryScript.has(ServiceKeysScript.DIALOG), "boot should bind the dialog under ServiceKeys.DIALOG")
	var manager := _dialog()
	_assert_true(manager != null, "the bound dialog service should be a ScreenManager")
	if manager == null:
		return
	var screen := manager.open({"message": "开机", "buttons": [{"text": "好"}]})
	var ui_root := _find(game_root, "UIRoot")
	_assert_true(screen != null and screen.visible and ui_root != null and ui_root.is_ancestor_of(screen), "the dialog should open on the title UI layer")
	_buttons(screen)[0].pressed.emit()


func _test_the_title_debug_panel_opens_sample_dialogs(game_root: Node) -> void:
	var panel := _find(game_root, "DialogDebugPanel") as Control
	_assert_true(panel != null and panel.is_visible_in_tree(), "a debug build should show the dialog debug panel on the title")
	_assert_true(_find(game_root, "PlaytestAssistPanel") == null, "the dialog debug panel should stand apart from the playtest assist panel")
	if panel == null:
		return
	var log := _find(panel, "DialogDebugLog") as Label
	for count in [1, 2, 3]:
		var opener := _find(panel, "DialogDebugOpen%dButton" % count) as BaseButton
		_assert_true(opener != null, "the debug panel should have a button for the %d-button sample" % count)
		if opener == null:
			continue
		opener.pressed.emit()
		var screen := _find(game_root, "DialogLayer") as Control
		_assert_true(screen != null and screen.visible, "the %d-button sample should open the dialog" % count)
		var buttons := _buttons(screen)
		_assert_eq(buttons.size(), count, "the %d-button sample should show %d buttons" % [count, count])
		if buttons.is_empty():
			continue
		buttons.back().pressed.emit()
		_assert_true(not screen.visible, "pressing a sample button should close the dialog")
		_assert_true(log != null and log.text.contains("%d/%d" % [count, count]), "the debug log should name the pressed button of the %d-button sample (got %s)" % [count, log.text if log != null else "<none>"])
	await process_frame


func _test_the_debug_panel_simulates_the_save(game_root: Node) -> void:
	game_root._save_path = TEST_SAVE_PATH
	_remove_test_save()
	game_root.uninstall_title_screen()
	game_root.install_title_screen()
	await process_frame
	var panel := _live(game_root, "DialogDebugPanel")
	var follow := _find(panel, "DialogDebugSaveFollowButton") as BaseButton
	var simulate_saved := _find(panel, "DialogDebugSaveYesButton") as BaseButton
	var simulate_empty := _find(panel, "DialogDebugSaveNoButton") as BaseButton
	var actual := _find(panel, "DialogDebugSaveActual") as Label
	_assert_true(follow != null and simulate_saved != null and simulate_empty != null and actual != null, "the debug panel should offer the three save simulations and the actual save")
	if follow == null or simulate_saved == null or simulate_empty == null or actual == null:
		return
	_assert_true(follow.button_pressed and not simulate_saved.button_pressed and not simulate_empty.button_pressed, "the panel should start by following the actual save")
	_assert_true(actual.text.contains("无"), "without a file the panel should show no actual save (got %s)" % actual.text)

	simulate_saved.pressed.emit()
	_assert_eq(_has_save(), true, "simulating a save should write the has_save model")
	_assert_true(not FileAccess.file_exists(TEST_SAVE_PATH), "simulating a save should not write the save file")
	_assert_true(actual.text.contains("无"), "simulating a save should still show the actual save (got %s)" % actual.text)
	_assert_true(simulate_saved.button_pressed and not follow.button_pressed, "the pressed simulation should stay selected")
	var start := _find(game_root, "MainMenuStartButton") as BaseButton
	start.pressed.emit()
	await process_frame
	await process_frame
	_assert_eq(game_root.session_mode(), "prologue", "START on a simulated save without a file should fall back to a new game with the prologue")

	game_root._skip_prologue()
	game_root.show_main_menu()
	await process_frame
	_assert_true(FileAccess.file_exists(TEST_SAVE_PATH), "returning to the title should write a real save")
	var saved_bytes := FileAccess.get_file_as_bytes(TEST_SAVE_PATH)
	panel = _live(game_root, "DialogDebugPanel")
	actual = _find(panel, "DialogDebugSaveActual") as Label
	_assert_true(actual != null and actual.text.contains("有"), "with a file the panel should show the actual save")
	(_find(panel, "DialogDebugSaveNoButton") as BaseButton).pressed.emit()
	_assert_eq(_has_save(), false, "simulating no save should write the has_save model")
	(_find(panel, "DialogDebugSaveFollowButton") as BaseButton).pressed.emit()
	_assert_eq(_has_save(), true, "following the actual save should publish the file again")
	_assert_eq(FileAccess.get_file_as_bytes(TEST_SAVE_PATH), saved_bytes, "the save simulations should leave the save file untouched")
	_remove_test_save()
	game_root._save_path = game_root.SAVE_PATH


func _has_save() -> Variant:
	var manager := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	return manager.model(PropertyKeysScript.HAS_SAVE).read() if manager != null else null


func _remove_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


## The panel mounted now; a remount leaves the old one queued for deletion.
func _live(node: Node, wanted: String) -> Node:
	if node == null or node.is_queued_for_deletion():
		return null
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _live(child, wanted)
		if found != null:
			return found
	return null


func _test_the_debug_panel_needs_a_debug_build(game_root: Node) -> void:
	game_root.set("_playtest_assist_enabled", false)
	game_root.uninstall_title_screen()
	game_root.install_title_screen()
	var panel := _find(game_root, "DialogDebugPanel")
	_assert_true(panel == null or panel.is_queued_for_deletion(), "a release build should not show the dialog debug panel")
	game_root.set("_playtest_assist_enabled", true)


func _test_an_open_dialog_sits_above_every_game_ui(game_root: Node) -> void:
	game_root.new_game()
	game_root._skip_prologue()
	await process_frame
	if _dialog() == null:
		_failures.append("a run should still have the dialog bound")
		return
	var screen := _dialog().open({"message": "最上层", "buttons": [{"text": "好"}]})
	var ui_root := _find(game_root, "UIRoot") as Control
	_assert_true(screen != null and screen.visible and ui_root != null and ui_root.is_ancestor_of(screen), "a dialog opened in a run should sit on the run UI layer")
	if screen == null or ui_root == null:
		return
	var dialog_z := _effective_z(screen)
	var highest := {"z": -4096, "name": ""}
	_collect_highest(ui_root, screen, 0, highest)
	_assert_true(dialog_z > int(highest["z"]), "the dialog (z %d) should sit above every other game UI (highest %s at z %d)" % [dialog_z, highest["name"], highest["z"]])

	game_root.new_game()
	game_root._skip_prologue()
	await process_frame
	_assert_true(not is_instance_valid(screen) or not screen.visible, "a rebuilt world should leave the dialog closed")
	var reopened := _dialog().open({"message": "又一次", "buttons": [{"text": "好"}]})
	_assert_true(reopened != null and reopened.visible and reopened.is_inside_tree(), "the dialog should open again after the world is rebuilt")
	if reopened != null:
		_buttons(reopened)[0].pressed.emit()


func _dialog() -> ScreenManager:
	return RegistryScript.resolve(ServiceKeysScript.DIALOG) as ScreenManager if RegistryScript.has(ServiceKeysScript.DIALOG) else null


func _effective_z(item: CanvasItem) -> int:
	var z := 0
	var node: Node = item
	while node is CanvasItem:
		var canvas_item := node as CanvasItem
		z += canvas_item.z_index
		if not canvas_item.z_as_relative:
			break
		node = node.get_parent()
	return z


func _collect_highest(node: Node, skip: Node, parent_z: int, highest: Dictionary) -> void:
	if node == skip:
		return
	var z := parent_z
	if node is CanvasItem:
		var item := node as CanvasItem
		z = item.z_index + (parent_z if item.z_as_relative else 0)
		if z > int(highest["z"]):
			highest["z"] = z
			highest["name"] = str(node.name)
	for child in node.get_children():
		_collect_highest(child, skip, z, highest)


func _buttons(screen: Node) -> Array[Button]:
	var found: Array[Button] = []
	var row := _find(screen, "DialogButtonRow")
	if row == null:
		return found
	for child in row.get_children():
		if child is Button and not child.is_queued_for_deletion():
			found.append(child as Button)
	return found


func _find(node: Node, wanted: String) -> Node:
	if node == null:
		return null
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find(child, wanted)
		if found != null:
			return found
	return null


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
