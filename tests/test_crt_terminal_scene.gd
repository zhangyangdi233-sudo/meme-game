extends SceneTree
## In the main scene's basement, F at the CRT pushes the view into its screen and Tab (or the screen's exit) gives
## the original look back. Words picked on the terminal and on the phone are one notebook, a post from the terminal
## records the round, and the terminal's VHS is a preference of its own.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const TEST_SAVE_PATH := "user://test_crt_terminal_scene_save.dat"
const TEST_PREFERENCES_PATH := "user://test_crt_terminal_scene_preferences.cfg"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	root.size = Vector2i(1600, 900)
	_remove_files()
	await _run()
	_remove_files()
	if _failures.is_empty():
		print("crt terminal scene tests passed")
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
	await _enter_the_basement(game_root)
	await _test_f_at_the_crt_enters_the_screen_and_tab_returns_the_view(game_root)
	await _test_the_screen_exit_leaves_the_terminal(game_root)
	await _test_a_word_picked_on_either_side_is_one_notebook(game_root)
	await _test_a_post_from_the_terminal_records_the_round(game_root)
	await _test_the_terminal_vhs_is_its_own_preference(game_root)
	game_root.queue_free()
	await process_frame


## A new run read to the end, knocked, and saved behind the white door continues in basement round one.
func _enter_the_basement(game_root) -> void:
	game_root.new_game()
	await process_frame
	while game_root.game.advance_opening_narration():
		pass
	game_root.game.complete_opening_knock()
	game_root.game.open_opening_door()
	_assert_true(game_root._save_progress(), "setup should save the run in the basement")
	game_root.show_main_menu()
	await process_frame
	_assert_true(game_root.continue_game(), "setup should continue the basement save")
	await process_frame
	await process_frame
	_assert_true(Harness.find_node_by_name(game_root, "BasementRoom") != null, "setup should stand in the basement")


func _test_f_at_the_crt_enters_the_screen_and_tab_returns_the_view(game_root) -> void:
	var adapter = game_root._reality_scene_adapter
	await _stand_at_the_crt(game_root)
	_assert_eq(str(adapter.nearby_outcome().get("kind")), "terminal", "the CRT should answer in reach")
	var prompt := Harness.find_node_by_name(game_root, "WorldPrompt") as Label
	_assert_true(prompt != null and prompt.visible and prompt.text.contains("F"), "the world prompt should offer F at the CRT")
	adapter.yaw = 25.0
	adapter.pitch = -6.0
	_settle_camera(game_root)
	var eye: Vector3 = game_root._camera.global_position
	_push_key(game_root, KEY_F)
	await process_frame
	_assert_eq(str(adapter.interaction_outcome().get("kind")), "terminal", "F at the CRT should enter its screen")
	var display := Harness.find_node_by_name(game_root, "CrtTerminalDisplay") as SubViewport
	_assert_true(display != null and display.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "the terminal's display should be live")
	var glass := _glass_material(game_root)
	_assert_true(glass != null and display != null and glass.get_shader_parameter("content_texture") == display.get_texture(), "the CRT's glass should show the terminal's display")
	_settle_camera(game_root)
	var view: Vector3 = adapter.pose().get("view_position", Vector3.INF)
	_assert_true(game_root._camera.global_position.distance_to(view) < 0.05, "the view should push in to the screen")
	_assert_true(prompt == null or not prompt.visible, "the world prompt should hide inside the screen")
	_push_key(game_root, KEY_TAB)
	await process_frame
	_assert_eq(str(adapter.interaction_outcome().get("kind")), "none", "Tab should leave the screen")
	_assert_eq(str(game_root.game.view_state), "npc_up", "Tab in the screen should not raise the phone")
	_assert_near(float(adapter.pose().get("yaw")), 25.0, 0.001, "leaving should give the yaw back")
	_assert_near(float(adapter.pose().get("pitch")), -6.0, 0.001, "leaving should give the pitch back")
	_assert_true(display.render_target_update_mode == SubViewport.UPDATE_DISABLED, "the terminal's display should rest once left")
	_settle_camera(game_root)
	_assert_true(game_root._camera.global_position.distance_to(eye) < 0.05, "the view should return to the player's eye: %s -> %s" % [str(eye), str(game_root._camera.global_position)])


func _test_the_screen_exit_leaves_the_terminal(game_root) -> void:
	await _enter_terminal(game_root)
	GameEventBus.raise(UiIntentsScript.TERMINAL_EXIT_REQUESTED)
	await process_frame
	_assert_eq(str(game_root._reality_scene_adapter.interaction_outcome().get("kind")), "none", "the screen's exit should leave the terminal")


func _test_a_word_picked_on_either_side_is_one_notebook(game_root) -> void:
	await _enter_terminal(game_root)
	var terminal_social := Harness.find_node_by_name(game_root, "TerminalSocialFeedPanel") as SocialFeedPanel
	terminal_social.open_post(0)
	await process_frame
	var display := Harness.find_node_by_name(game_root, "CrtTerminalDisplay")
	var line := Harness.find_node_by_name(display, "SocialPickupLineText") as RichTextLabel
	_assert_true(line != null and line.text.contains("[url=门]"), "the terminal's post should offer 门")
	if line != null:
		line.meta_clicked.emit("门")
	await process_frame
	_assert_true(game_root.game.is_social_char_collected("门", "zh"), "a pickup on the terminal should collect the word")
	GameEventBus.raise(UiIntentsScript.SOCIAL_PICKUP_UNIT_CLICKED, {UiIntentsScript.KEY_META: "开", UiIntentsScript.KEY_POST_ID: "floor_13"})
	await process_frame
	(Harness.find_node_by_name(display, "TerminalAppNotebook") as Button).pressed.emit()
	await process_frame
	await process_frame
	var terminal_canvas := Harness.find_node_by_name(display, "NotebookWordCanvas") as WordPhysicsCanvas
	_assert_true(terminal_canvas != null and terminal_canvas.has_tile("开"), "a word picked off the terminal should show on the terminal's notebook")
	_push_key(game_root, KEY_TAB)
	await process_frame
	game_root.set_view_state("phone_down")
	game_root.game.open_app_window("notebook")
	game_root._render()
	await process_frame
	await process_frame
	var phone_canvas: WordPhysicsCanvas = null
	for canvas in game_root.find_children("NotebookWordCanvas", "WordPhysicsCanvas", true, false):
		if not display.is_ancestor_of(canvas):
			phone_canvas = canvas
	_assert_true(phone_canvas != null and phone_canvas.has_tile("门"), "a word picked on the terminal should show in the phone's notebook")
	game_root.set_view_state("npc_up")
	await process_frame


func _test_a_post_from_the_terminal_records_the_round(game_root) -> void:
	await _enter_terminal(game_root)
	game_root.game.free_sentence_units = ["门"]
	await process_frame
	await process_frame
	var display := Harness.find_node_by_name(game_root, "CrtTerminalDisplay")
	var craft := Harness.find_node_by_name(display, "NotebookCraftButton") as Button
	_assert_true(craft != null and not craft.disabled, "the terminal's notebook should offer the post")
	var posts_before: int = game_root.game.published_memes.size()
	if craft != null:
		craft.pressed.emit()
	await process_frame
	_assert_eq(game_root.game.published_memes.size(), posts_before + 1, "posting from the terminal should publish")
	_assert_eq(int(game_root.game.published_memes[0].get("round", -1)), 1, "a post from the terminal should record basement round one")
	_assert_true(game_root.game.has_posted_this_round(), "the round should count as posted")
	_push_key(game_root, KEY_TAB)
	await process_frame


func _test_the_terminal_vhs_is_its_own_preference(game_root) -> void:
	await _enter_terminal(game_root)
	var full_screen_before: bool = game_root._vhs_enabled
	GameEventBus.raise(UiIntentsScript.TERMINAL_VHS_TOGGLED, {UiIntentsScript.KEY_VALUE: false})
	await process_frame
	var glass := _glass_material(game_root)
	_assert_true(glass != null and glass.get_shader_parameter("vhs_enabled") == false, "turning the terminal VHS off should reach the CRT's glass")
	_assert_eq(game_root._vhs_enabled, full_screen_before, "the terminal VHS should leave the full-screen VHS alone")
	var config := ConfigFile.new()
	_assert_eq(config.load(TEST_PREFERENCES_PATH), OK, "the terminal VHS should be saved to the preferences")
	_assert_eq(config.get_value("visual", "terminal_vhs_enabled", true), false, "the preferences should keep the terminal VHS off")
	GameEventBus.raise(UiIntentsScript.VHS_TOGGLED, {UiIntentsScript.KEY_VALUE: not full_screen_before})
	await process_frame
	_assert_true(glass.get_shader_parameter("vhs_enabled") == false, "the full-screen VHS should not switch the terminal's")
	GameEventBus.raise(UiIntentsScript.VHS_TOGGLED, {UiIntentsScript.KEY_VALUE: full_screen_before})
	GameEventBus.raise(UiIntentsScript.TERMINAL_VHS_TOGGLED, {UiIntentsScript.KEY_VALUE: true})
	await process_frame
	_assert_true(glass.get_shader_parameter("vhs_enabled") == true, "turning the terminal VHS back on should reach the glass")
	_push_key(game_root, KEY_TAB)
	await process_frame


func _enter_terminal(game_root) -> void:
	await _stand_at_the_crt(game_root)
	_push_key(game_root, KEY_F)
	await process_frame
	_assert_eq(str(game_root._reality_scene_adapter.interaction_outcome().get("kind")), "terminal", "setup should enter the terminal")


func _stand_at_the_crt(game_root) -> void:
	var adapter = game_root._reality_scene_adapter
	var reach: Vector3 = adapter.chapter_terminal_position()
	adapter.player.position = reach + Vector3(0.0, 0.02, 0.0)
	adapter.player.velocity = Vector3.ZERO
	for frame in 10:
		await physics_frame


func _settle_camera(game_root) -> void:
	for step in 60:
		game_root._process(0.1)


func _glass_material(game_root) -> ShaderMaterial:
	var glass := Harness.find_node_by_name(game_root, "Prop_CRT_TV_Screen_Video") as MeshInstance3D
	return glass.get_surface_override_material(0) as ShaderMaterial if glass != null else null


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


func _assert_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
