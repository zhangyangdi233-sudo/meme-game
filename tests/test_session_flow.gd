extends SceneTree
## Adapter Session mode: boot injects five states; new run, continue, title, and narrative go through the manager.

var _failures: Array[String] = []
const TEST_SAVE_PATH := "user://test_session_flow_save.dat"
const SESSION_IDS := ["main_menu", "prologue", "gameplay", "narrative", "ending"]


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	root.size = Vector2i(1600, 900)
	await _run()
	_remove_test_save()
	if _failures.is_empty():
		print("session flow tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_remove_test_save()
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "session flow should load the main scene")
	if scene == null:
		return
	var game_root = scene.instantiate()
	game_root._save_path = TEST_SAVE_PATH
	root.add_child(game_root)
	await process_frame
	game_root._locale.set_locale("zh")

	_assert_true(
		game_root.has_method("session_mode") and game_root.has_method("has_session_state"),
		"adapter should expose Session mode through the flow manager"
	)
	_assert_true(
		not game_root.has_method("current_input_owner"),
		"adapter should not expose a flag-derived input owner"
	)
	if not game_root.has_method("session_mode") or not game_root.has_method("has_session_state"):
		game_root.queue_free()
		await process_frame
		return

	for state_id in SESSION_IDS:
		_assert_true(
			game_root.has_session_state(state_id),
			"boot should inject session state %s" % state_id
		)
	_assert_true(not game_root.has_session_state("settings"), "in-run settings is not a sixth Session mode")
	_assert_true(not game_root.has_session_state("language_picker"), "language picker is not a Session mode")
	_assert_true(not game_root.has_session_state("camera_consent"), "camera consent is not a Session mode")
	_assert_eq(game_root.session_mode(), "main_menu", "boot should start on the main menu")
	_assert_host_applied_screens(game_root, ["title"], "boot title")
	await _assert_world_hotkeys_inert(game_root, "boot title")

	game_root._build_language_selection_overlay(true)
	await process_frame
	_assert_eq(game_root.session_mode(), "main_menu", "language picker should stay on the main menu")
	_assert_host_applied_screens(game_root, ["title"], "language picker")
	await _assert_world_hotkeys_inert(game_root, "language picker")
	var language_overlay := _find_node_by_name(game_root, "LanguageSelectionOverlay") as Control
	await _assert_fullscreen_overlay_eats_clicks(game_root, language_overlay, "language picker overlay")
	game_root._close_language_selection_overlay()
	await process_frame
	await _assert_main_menu_overlay_eats_clicks(game_root)

	game_root._build_camera_consent_overlay()
	await process_frame
	_assert_eq(game_root.session_mode(), "main_menu", "camera consent should stay on the main menu")
	_assert_host_applied_screens(game_root, ["title"], "camera consent")
	await _assert_world_hotkeys_inert(game_root, "camera consent")
	if game_root.has_method("_resolve_camera_consent"):
		game_root._resolve_camera_consent(false)
	await process_frame

	game_root.new_game()
	await process_frame
	_assert_eq(game_root.session_mode(), "prologue", "a new run should set Session mode to prologue")
	_assert_host_applied_screens(game_root, ["prologue", "play"], "prologue")
	await _assert_world_hotkeys_inert(game_root, "prologue")
	await _assert_prologue_overlay_eats_phone_clicks(game_root)

	game_root._skip_prologue()
	await process_frame
	_assert_eq(game_root.session_mode(), "gameplay", "finishing the prologue should set Session mode to gameplay")
	_assert_host_applied_screens(game_root, ["play"], "gameplay after prologue")
	await _assert_gameplay_world_hotkeys_live(game_root)
	await _assert_gameplay_phone_toggle_click(game_root)
	game_root._toggle_settings_window()
	await process_frame
	_assert_eq(game_root.session_mode(), "gameplay", "in-run settings should stay in gameplay")
	_assert_screen_set(game_root, ["play"], "in-run settings")
	_assert_true(not game_root.has_session_state("settings"), "opening settings should not add a sixth Session mode")
	await _assert_gameplay_world_hotkeys_live(game_root)
	game_root._close_settings_window()
	await process_frame
	game_root.set_view_state("npc_up")

	game_root.game.pollution = 60
	game_root.game.check_pollution_flashback(59)
	game_root._narrative_director.play_pollution_flashback()
	await process_frame
	_assert_eq(game_root.session_mode(), "narrative", "a flashback should set Session mode to narrative")
	_assert_host_applied_screens(game_root, ["narrative", "play"], "flashback")
	await _assert_world_hotkeys_inert(game_root, "flashback")
	var flashback_overlay := _find_node_by_name(game_root, "PollutionFlashbackOverlay") as Control
	await _assert_overlay_eats_phone_clicks(game_root, flashback_overlay, "flashback overlay")
	game_root._narrative_director.finish_pollution_flashback()
	await process_frame
	_assert_eq(game_root.session_mode(), "gameplay", "finishing a flashback should set Session mode to gameplay")
	_assert_host_applied_screens(game_root, ["play"], "gameplay after flashback")
	await _assert_gameplay_world_hotkeys_live(game_root)

	game_root.game.actions_remaining = 1
	_assert_true(game_root.game.spend_action("session-flow-narrative"), "last daily action should be spendable")
	game_root._narrative_director.play_action_spend_animation(1, 0)
	await process_frame
	_assert_eq(game_root.session_mode(), "narrative", "spending an action should set Session mode to narrative")
	_assert_host_applied_screens(game_root, ["narrative", "play"], "action spend")
	await _assert_world_hotkeys_inert(game_root, "action spend")
	var spend_overlay := _find_node_by_name(game_root, "ActionSpendOverlay") as Control
	await _assert_overlay_eats_phone_clicks(game_root, spend_overlay, "action spend overlay")
	game_root._narrative_director.finish_action_spend_animation()
	await process_frame
	_assert_eq(game_root.session_mode(), "narrative", "a chained day transition should stay in narrative")
	_assert_host_applied_screens(game_root, ["narrative", "play"], "day transition")
	await _assert_world_hotkeys_inert(game_root, "day transition")
	var day_overlay := _find_node_by_name(game_root, "DayTransitionOverlay") as Control
	await _assert_overlay_eats_phone_clicks(game_root, day_overlay, "day transition overlay")
	game_root._narrative_director.finish_day_transition()
	await process_frame
	_assert_eq(game_root.session_mode(), "gameplay", "finishing a day transition should set Session mode to gameplay")
	await _assert_gameplay_world_hotkeys_live(game_root)

	game_root.set_view_state("npc_up")
	game_root.game.ending_unlocked = false
	game_root.show_main_menu()
	await process_frame
	_assert_eq(game_root.session_mode(), "main_menu", "returning to title should set Session mode to main menu")
	_assert_host_applied_screens(game_root, ["title"], "returned title")
	await _assert_world_hotkeys_inert(game_root, "returned title")
	await _assert_main_menu_overlay_eats_clicks(game_root)

	_assert_true(game_root.continue_game(), "continue should load the non-ending save")
	await process_frame
	_assert_eq(game_root.session_mode(), "gameplay", "continuing a non-ending save should set Session mode to gameplay")
	_assert_host_applied_screens(game_root, ["play"], "continued gameplay")
	await _assert_gameplay_world_hotkeys_live(game_root)

	_assert_true(
		not game_root.game.get_progression_snapshot().has("current_screen"),
		"rules snapshot should not grow a current-screen field"
	)
	_assert_true(
		not game_root.game.get_progression_snapshot().has("session_mode"),
		"Session mode belongs to the flow manager, not MemeGameState"
	)
	game_root.game.actions_remaining = 1
	_assert_true(game_root.game.spend_action("session-flow-ending"), "last action should spend before the ending unlock")
	game_root._narrative_director.play_action_spend_animation(1, 0)
	await process_frame
	_assert_eq(game_root.session_mode(), "narrative", "spending the last action should stay in narrative")
	game_root.game.ending_unlocked = true
	game_root._narrative_director.finish_action_spend_animation()
	await process_frame
	_assert_eq(game_root.session_mode(), "narrative", "a chained day transition should stay in narrative after ending unlock")
	_assert_host_applied_screens(game_root, ["narrative", "play"], "ending-pending narrative")
	await _assert_world_hotkeys_inert(game_root, "ending-pending narrative")
	game_root._narrative_director.finish_day_transition()
	await process_frame
	_assert_eq(game_root.session_mode(), "ending", "finishing narrative with ending unlocked should set Session mode to ending")
	_assert_host_applied_screens(game_root, ["ending"], "ending unlock")
	await _assert_world_hotkeys_inert(game_root, "ending unlock")
	await _assert_ending_overlay_eats_clicks(game_root)

	_assert_true(game_root._save_progress(), "an ending run should still save")
	game_root.show_main_menu()
	await process_frame
	_assert_eq(game_root.session_mode(), "main_menu", "returning to title after continue should restore the main menu")
	await _assert_world_hotkeys_inert(game_root, "title after continue")

	_assert_true(game_root.continue_game(), "continue should load the ending-unlocked save")
	await process_frame
	_assert_eq(game_root.session_mode(), "ending", "continuing an ending-unlocked save should set Session mode to ending")
	_assert_host_applied_screens(game_root, ["ending"], "ending continue")
	await _assert_world_hotkeys_inert(game_root, "ending continue")
	await _assert_ending_overlay_eats_clicks(game_root)
	var ending_floor := _find_node_by_name(game_root, "RealityFloor")
	_assert_true(ending_floor != null, "ending continue should still mount the floor node")
	if ending_floor != null:
		_assert_eq(
			ending_floor.get_child_count(),
			0,
			"continuing an ending-unlocked save should not generate a playable floor behind the ending screen"
		)

	await _run_narrative_beat(game_root)

	game_root.queue_free()
	await process_frame


func _run_narrative_beat(game_root) -> void:
	game_root.new_game()
	await process_frame
	game_root._skip_prologue()
	await process_frame
	_assert_eq(game_root.session_mode(), "gameplay", "narrative beat should start from gameplay")
	await _assert_gameplay_world_hotkeys_live(game_root)

	game_root.game.actions_remaining = 2
	_assert_true(game_root.game.spend_action("narrative-beat"), "the beat should spend an action")
	game_root.game.pollution = 60
	game_root.game.check_pollution_flashback(59)
	var action_overlay := _find_node_by_name(game_root, "ActionSpendOverlay") as Control
	var day_overlay := _find_node_by_name(game_root, "DayTransitionOverlay") as Control
	var flashback_overlay := _find_node_by_name(game_root, "PollutionFlashbackOverlay") as Control
	game_root._after_effective_action(2)
	await process_frame
	_assert_eq(game_root.session_mode(), "narrative", "the beat should enter narrative when the action is spent")
	_assert_true(action_overlay != null and action_overlay.visible, "the beat should show the action pulse")
	_assert_true(day_overlay != null and not day_overlay.visible, "the day transition should wait until the action pulse finishes")
	_assert_true(flashback_overlay != null and not flashback_overlay.visible, "the flashback should wait until the day transition finishes")
	await _assert_world_hotkeys_inert(game_root, "narrative beat action")

	game_root._narrative_director.finish_action_spend_animation()
	await process_frame
	_assert_eq(game_root.session_mode(), "narrative", "the day transition should stay in narrative")
	_assert_true(day_overlay != null and day_overlay.visible, "the beat should show the day transition after the action pulse")
	_assert_true(flashback_overlay != null and not flashback_overlay.visible, "the flashback should still be waiting during the day transition")
	await _assert_world_hotkeys_inert(game_root, "narrative beat day")
	_assert_eq(game_root.game.day, 1, "day settlement should wait for the transition midpoint")
	game_root._narrative_director.commit_day_transition_settlement()
	_assert_eq(game_root.game.day, 2, "the transition midpoint should settle the day")
	game_root._narrative_director.finish_day_transition()
	await process_frame
	_assert_eq(game_root.session_mode(), "narrative", "the flashback should stay in narrative after the day transition")
	_assert_true(day_overlay != null and not day_overlay.visible, "the day transition should hide before the flashback")
	_assert_true(flashback_overlay != null and flashback_overlay.visible, "the beat should show the flashback after the day transition")
	await _assert_world_hotkeys_inert(game_root, "narrative beat flashback")
	_assert_eq(game_root.game.day, 2, "the flashback should not settle a second day")
	game_root._narrative_director.finish_pollution_flashback()
	await process_frame
	_assert_eq(game_root.session_mode(), "gameplay", "finishing the beat should return to gameplay")
	_assert_host_applied_screens(game_root, ["play"], "gameplay after narrative beat")
	await _assert_gameplay_world_hotkeys_live(game_root)

	game_root.new_game()
	await process_frame
	game_root._skip_prologue()
	await process_frame
	game_root.game.actions_remaining = 1
	_assert_true(game_root.game.spend_action("narrative-beat-ending"), "the ending beat should spend the last action")
	game_root.game.pollution = 60
	game_root.game.pollution_flashback_seen = false
	game_root.game.check_pollution_flashback(59)
	game_root._after_effective_action(1)
	await process_frame
	_assert_eq(game_root.session_mode(), "narrative", "the ending beat should open in narrative")
	game_root._narrative_director.finish_action_spend_animation()
	await process_frame
	game_root._narrative_director.finish_day_transition()
	await process_frame
	_assert_eq(game_root.session_mode(), "narrative", "the ending should wait until the flashback finishes")
	await _assert_world_hotkeys_inert(game_root, "narrative beat before ending")
	game_root.game.ending_unlocked = true
	game_root._narrative_director.finish_pollution_flashback()
	await process_frame
	_assert_eq(game_root.session_mode(), "ending", "finishing the beat with the ending unlocked should enter the ending")
	_assert_host_applied_screens(game_root, ["ending"], "narrative beat ending")
	await _assert_world_hotkeys_inert(game_root, "narrative beat ending")


func _assert_screen_set(game_root, expected: Array, label: String) -> void:
	_assert_true(game_root.has_method("session_screen_set"), "adapter should expose the declared screen set")
	if not game_root.has_method("session_screen_set"):
		return
	var declared: PackedStringArray = game_root.session_screen_set()
	var ids: Array[String] = []
	for screen_id in declared:
		ids.append(str(screen_id))
	_assert_eq(ids, expected, "%s should declare its screen set" % label)


func _assert_host_applied_screens(game_root, expected: Array, label: String) -> void:
	_assert_screen_set(game_root, expected, label)
	_assert_screen_node(game_root, "MainMenuLayer", "title" in expected, label)
	_assert_screen_node(game_root, "PrologueOverlay", "prologue" in expected, label)
	_assert_screen_node(game_root, "PhoneViewToggleButton", "play" in expected, label)
	_assert_screen_node(game_root, "EndingScreen", "ending" in expected, label)


func _assert_screen_node(game_root, node_name: String, should_show: bool, label: String) -> void:
	var node := _find_node_by_name(game_root, node_name) as CanvasItem
	if should_show:
		_assert_true(node != null and node.visible, "%s should show %s" % [label, node_name])
		return
	# Title and opening are installed on enter and unloaded on exit, so the node is gone.
	if node_name == "MainMenuLayer" or node_name == "PrologueOverlay":
		_assert_true(node == null, "%s should unload %s" % [label, node_name])
		return
	_assert_true(node == null or not node.visible, "%s should hide %s" % [label, node_name])


func _assert_gameplay_phone_toggle_click(game_root) -> void:
	game_root.set_view_state("phone_down")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await process_frame
	var toggle := _find_node_by_name(game_root, "PhoneViewToggleButton") as Button
	_assert_true(toggle != null and toggle.visible, "gameplay should show the phone view toggle")
	if toggle == null:
		return
	_assert_true(not toggle.disabled, "gameplay should not lock the phone view toggle")
	_assert_true(not game_root.get_tree().paused, "gameplay should not pause the scene tree to gate clicks")
	var view_before := str(game_root.game.view_state)
	await _click_at(game_root, toggle.get_global_rect().get_center())
	_assert_true(
		str(game_root.game.view_state) != view_before,
		"gameplay phone toggle click should change the view when Session mode allows it"
	)
	game_root.set_view_state("phone_down")


func _assert_main_menu_overlay_eats_clicks(game_root) -> void:
	var overlay := _find_node_by_name(game_root, "MainMenuLayer") as Control
	await _assert_fullscreen_overlay_eats_clicks(game_root, overlay, "main menu overlay")
	_assert_true(
		_find_node_by_name(game_root, "PhoneViewToggleButton") == null,
		"main menu should not keep phone UI under the overlay"
	)


func _assert_fullscreen_overlay_eats_clicks(game_root, overlay: Control, label: String) -> void:
	_assert_true(overlay != null and overlay.visible, "%s should be visible" % label)
	if overlay == null:
		return
	_assert_eq(
		overlay.mouse_filter,
		Control.MOUSE_FILTER_STOP,
		"%s should stop mouse events" % label
	)
	_assert_true(not game_root.get_tree().paused, "%s should not pause the scene tree to gate clicks" % label)
	var mode_before := str(game_root.session_mode())
	var view_before := str(game_root.game.view_state) if game_root.game != null else ""
	var click_point := overlay.get_global_rect().position + Vector2(36.0, 36.0)
	_assert_true(overlay.get_global_rect().has_point(click_point), "%s should cover its own chrome" % label)
	await _click_at(game_root, click_point)
	_assert_eq(str(game_root.session_mode()), mode_before, "%s should eat clicks without changing Session mode" % label)
	if game_root.game != null:
		_assert_eq(str(game_root.game.view_state), view_before, "%s should eat clicks" % label)


func _assert_ending_overlay_eats_clicks(game_root) -> void:
	var overlay := _find_node_by_name(game_root, "EndingScreen") as Control
	_assert_true(overlay != null and overlay.visible, "ending screen should be visible")
	if overlay == null:
		return
	_assert_eq(
		overlay.mouse_filter,
		Control.MOUSE_FILTER_STOP,
		"ending screen should stop mouse events"
	)
	await _assert_overlay_eats_clicks_at(
		game_root,
		overlay.get_global_rect().get_center(),
		"ending screen"
	)


func _assert_prologue_overlay_eats_phone_clicks(game_root) -> void:
	var overlay := _find_node_by_name(game_root, "PrologueOverlay") as Control
	await _assert_overlay_eats_phone_clicks(game_root, overlay, "prologue overlay")


func _assert_overlay_eats_phone_clicks(game_root, overlay: Control, label: String) -> void:
	_assert_true(overlay != null and overlay.visible, "%s should be visible" % label)
	if overlay == null:
		return
	var toggle := _find_node_by_name(game_root, "PhoneViewToggleButton") as Button
	_assert_true(toggle != null, "phone view toggle should exist under %s" % label)
	if toggle == null:
		return
	var click_point := toggle.get_global_rect().get_center()
	_assert_true(
		overlay.get_global_rect().has_point(click_point),
		"%s should cover the phone view toggle" % label
	)
	_assert_true(not toggle.disabled, "%s should not disable the phone toggle; overlay eats clicks" % label)
	_assert_true(not game_root.get_tree().paused, "%s should not pause the scene tree to gate clicks" % label)
	await _assert_overlay_eats_clicks_at(game_root, click_point, "%s aimed at phone UI" % label)


func _assert_overlay_eats_clicks_at(game_root, click_point: Vector2, label: String) -> void:
	var view_before := str(game_root.game.view_state)
	await _click_at(game_root, click_point)
	_assert_eq(
		str(game_root.game.view_state),
		view_before,
		"%s should eat clicks" % label
	)


func _click_at(game_root, click_point: Vector2) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var press := InputEventMouseButton.new()
	press.position = click_point
	press.global_position = click_point
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	game_root.get_viewport().push_input(press, true)
	await process_frame
	var release := InputEventMouseButton.new()
	release.position = click_point
	release.global_position = click_point
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	game_root.get_viewport().push_input(release, true)
	await process_frame


func _assert_world_hotkeys_inert(game_root, label: String) -> void:
	_assert_true(
		not InputMap.has_action("reality_forward") and not InputMap.has_action("reality_phone"),
		"%s should unload the gameplay world hotkey pack" % label
	)
	var yaw_before := float(game_root._reality_scene_adapter.pose().get("yaw", 0.0))
	var view_before := str(game_root.game.view_state) if game_root.game != null else ""
	var interacting_before: bool = game_root._reality_interaction_is_active()
	game_root._unhandled_input(_key_event(KEY_F))
	game_root._unhandled_input(_key_event(KEY_TAB))
	var look := InputEventMouseMotion.new()
	look.relative = Vector2(96.0, 0.0)
	game_root._input(look)
	game_root._unhandled_input(look)
	_assert_true(
		is_equal_approx(float(game_root._reality_scene_adapter.pose().get("yaw", 0.0)), yaw_before),
		"%s should ignore look hotkeys" % label
	)
	_assert_window_drag(game_root, false, label)
	_assert_eq(
		str(game_root.game.view_state) if game_root.game != null else "",
		view_before,
		"%s should ignore the phone hotkey" % label
	)
	_assert_true(
		game_root._reality_interaction_is_active() == interacting_before,
		"%s should ignore the interact hotkey" % label
	)
	var player := game_root.get_node_or_null("RealityPlayer") as CharacterBody3D
	if player == null:
		return
	var start := player.position
	var had_forward := InputMap.has_action("reality_forward")
	if had_forward:
		Input.action_press("reality_forward")
	for _frame in 8:
		await physics_frame
	if had_forward:
		Input.action_release("reality_forward")
	_assert_true(
		start.distance_to(player.position) < 0.01,
		"%s should not walk while Session mode is not gameplay" % label
	)


func _assert_gameplay_world_hotkeys_live(game_root) -> void:
	_assert_true(
		InputMap.has_action("reality_forward") and InputMap.has_action("reality_phone"),
		"gameplay should install the world hotkey pack"
	)
	game_root.set_view_state("npc_up")
	var yaw_before := float(game_root._reality_scene_adapter.pose().get("yaw", 0.0))
	var look := InputEventMouseMotion.new()
	look.relative = Vector2(96.0, 0.0)
	game_root._input(look)
	game_root._unhandled_input(look)
	_assert_true(
		not is_equal_approx(float(game_root._reality_scene_adapter.pose().get("yaw", 0.0)), yaw_before),
		"gameplay look should rotate the first-person view"
	)
	_assert_window_drag(game_root, true, "gameplay")
	var view_before := str(game_root.game.view_state)
	game_root._unhandled_input(_key_event(KEY_TAB))
	_assert_true(
		str(game_root.game.view_state) != view_before,
		"gameplay phone hotkey should toggle the phone"
	)
	game_root.set_view_state("npc_up")
	var player := game_root.get_node_or_null("RealityPlayer") as CharacterBody3D
	_assert_true(player != null, "gameplay should expose the walking body")
	if player == null:
		return
	var walk_start := player.position
	Input.action_press("reality_forward")
	for _frame in 24:
		await physics_frame
	Input.action_release("reality_forward")
	_assert_true(
		walk_start.distance_to(player.position) > 0.25,
		"gameplay walk hotkeys should move the body"
	)


func _assert_window_drag(game_root, expect_live: bool, label: String) -> void:
	if not game_root.has_method("_move_window_for_test") or not game_root.has_method("_window_position_for_test"):
		_failures.append("%s should expose window drag through the adapter" % label)
		return
	var window_id := "phone"
	var before: Vector2 = game_root._window_position_for_test(window_id)
	if not before.is_finite():
		if expect_live:
			_failures.append("%s should have a draggable phone window" % label)
		return
	var moved: bool = game_root._move_window_for_test(window_id, Vector2(16, -10))
	var after: Vector2 = game_root._window_position_for_test(window_id)
	if expect_live:
		_assert_true(moved, "gameplay windows should drag")
		_assert_true(after.distance_to(before) > 1.0, "gameplay window drag should move the window")
		game_root._move_window_for_test(window_id, Vector2(-16, 10))
		return
	_assert_true(not moved, "%s should ignore window drag" % label)
	_assert_true(after.is_equal_approx(before), "%s should not move windows" % label)


func _find_node_by_name(node: Node, wanted_name: String) -> Node:
	if node == null:
		return null
	if node.name == wanted_name:
		return node
	for child in node.get_children():
		var found := _find_node_by_name(child, wanted_name)
		if found != null:
			return found
	return null


func _key_event(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.echo = false
	event.keycode = keycode
	event.physical_keycode = keycode
	return event


func _remove_test_save() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_SAVE_PATH)
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(absolute_path)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
