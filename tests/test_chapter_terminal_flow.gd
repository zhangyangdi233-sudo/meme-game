extends SceneTree

const State := preload("res://scripts/meme_game_state.gd")
const Director := preload("res://scripts/progression/basement_loop_director.gd")

class FakeReceiver:
	extends RefCounted
	signal frame_received(hands: Array, timestamp_msec: int)
	signal status_changed(status: String)
	signal source_ready(source: String, selected_index: int)
	var camera_source := "computer"
	var start_count := 0
	func start(_launch_sidecar: bool = true) -> bool:
		start_count += 1
		return true
	func stop() -> void:
		pass
	func poll() -> void:
		pass
	func get_status() -> String:
		return "验收测试：摄像头未启动"

var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://scenes/babel_meme_game.tscn").instantiate()
	var receiver := FakeReceiver.new()
	main._hand_tracking_receiver = receiver
	receiver.frame_received.connect(main._on_hand_tracking_frame)
	receiver.status_changed.connect(main._on_hand_tracking_status_changed)
	receiver.source_ready.connect(main._on_camera_source_ready)
	main._save_path = "user://aphasia_test_chapter_terminal_flow.dat"
	main._locale.preferences_path = "user://aphasia_test_chapter_terminal_flow_preferences.cfg"
	main._locale.set_crt_vhs_enabled(true)
	main._locale.save_preferences(80, true, false, "computer")
	root.add_child(main)
	main._resolve_camera_consent(false)
	main._begin_game_session(_basement_state(), {}, false)
	main._set_reality_mouse_look(false)
	await _frames()
	var implemented := true
	for method_name in ["_begin_chapter_terminal", "_end_chapter_terminal", "_chapter_terminal_active", "_on_chapter_terminal_app_pressed", "_on_crt_vhs_toggled", "_show_chapter_task", "_complete_chapter_tutorial_task"]:
		var present: bool = main.has_method(method_name)
		_check(present, "main must implement %s for the real terminal/task flow" % method_name)
		implemented = implemented and present
	if implemented:
		await _test_five_visits(main)
	_check(receiver.start_count == 0, "terminal walkthrough never starts a physical camera or hand sidecar")
	main.free()
	await _frames()
	if implemented:
		await _test_settings_lifecycle()
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("chapter terminal flow tests passed (%d checks; actual UI handlers, five NPC deliveries, three save/continues, fake camera)" % _checks)
	quit(0 if _failures.is_empty() else 1)


func _test_five_visits(main: Node) -> void:
	var hidden_item_id := ""
	_check(not main.game.chapter1_progress.phone_collected and not main._phone_panel.visible and not main._phone_tab.visible, "new basement visit has no phone UI before picking up the physical phone")
	main._toggle_view_state()
	_check(main.game.view_state == "npc_up", "Tab cannot summon a phone that has not been picked up")
	if not await _interact(main, "chapter1_phone"):
		return
	_check(main.game.chapter1_progress.phone_collected and main._phone_tab.visible, "F on the physical phone grants ownership and reveals its right-edge handle")
	_check(main._phone_panel.app_buttons.values().filter(func(button: Button): return button.visible).size() == 2 and not main._phone_panel.app_buttons.map.visible and main._phone_panel.app_buttons.social.disabled and main._phone_panel.app_buttons.notebook.disabled, "picking up the phone exposes exactly two locked apps, keeps map hidden and does not grant NPC permissions")
	main._on_pickup_unit_meta("门", "floor_13")
	_check(not main.game.is_social_char_collected("门", "zh"), "direct pickup callback cannot bypass the initially locked phone app")
	for visit in range(5):
		var token: int = main.game.chapter1_progress.transition_serial
		var task_id: String = Director.TASK_IDS[visit]
		_check(main.game.chapter1_progress.round_index == visit, "visit %d retains the correct task identity" % (visit + 1))
		var sealed: Dictionary = main.notify_chapter1("entrance_threshold_crossed", {"round_token": token})
		_check(sealed.accepted or main.game.chapter1_progress.entrance_locked, "visit %d seals its own entrance" % (visit + 1))
		await _frames()
		main._on_app_pressed("babel")
		await _frames()
		_check(main.game.view_state == "npc_up" and main.game.active_app_window == "", "locked phone handler cannot open Babel before visit %d delivery" % (visit + 1))
		_check(not bool(main._open_app_windows.get("babel", false)), "locked phone click cannot leave a latent Babel window")
		main.game.active_app = "babel"
		main.set_view_state("phone_down")
		await _frames()
		_check(main.game.active_app_window == "", "lowering phone never reopens locked active_app")
		main.set_view_state("npc_up")
		await _frames()
		_check(not main.game.has_current_chapter_submission(), "a previous visit's expression never satisfies this visit")
		if not await _interact(main, "chapter1_npc"):
			return
		var panel := main.find_child("ChapterTaskPanel", true, false) as Control
		_check(panel == null and main._reality_interaction_active, "real NPC interaction immediately opens the single authored conversation without a task menu")
		_check(main.game.conversation_phase == "typing" and main._reality_choice_row.get_child_count() == 0, "NPC's protagonist line is ready for typing without response choices")
		if visit == 0:
			hidden_item_id = await _reveal_first_key_clue(main)
		else:
			await _finish_npc_conversation(main)
			_check(not main.game.chapter1_progress.completed_task_ids.has(task_id), "finishing dialogue without this visit's submission does not deliver its task")
			_check(main.game.collected_prerequisite_item_ids.has(hidden_item_id), "the independently collected hidden clue survives later NPC conversations")
		_dismiss_task(main)
		await _frames()
		var original_controls: Dictionary = {}
		for app_id: String in Director.REQUIRED_APP_IDS:
			var window: Control = main._app_windows.get(app_id)
			_check(window != null, "the existing %s app window is available before terminal entry" % app_id)
			if window != null:
				original_controls[app_id] = {"instance": window.get_instance_id(), "parent": window.get_parent().get_instance_id()}
		if not await _interact(main, "chapter1_terminal"):
			return
		_check(main.call("_chapter_terminal_active"), "world terminal event opens the physical CRT session")
		if not main.call("_chapter_terminal_active"):
			return
		var session: Variant = main.get("_chapter_terminal_session")
		_check(session != null and session.has_method("get_terminal"), "active session exposes its physical terminal")
		if session == null or not session.has_method("get_terminal"):
			return
		var terminal: Node = session.get_terminal()
		_check(terminal != null and terminal.is_active(), "the bound CRT is active while used")
		if terminal == null:
			return
		if visit == 0:
			await _test_crt_setting(main, terminal)
		main.call("_on_chapter_terminal_app_pressed", "social")
		await _frames()
		main._on_pickup_unit_meta("门", "floor_13")
		if main._pickup_flight_layer != null:
			main._pickup_flight_layer.finish_all_immediately()
		await _frames()
		_check(main.game.is_social_char_collected("门", "zh"), "real terminal pickup reaches the shared vocabulary")
		_check(main.call("_chapter_terminal_active") and main.game.view_state != "phone_down" and main.game.active_app_window == "", "pickup's automatic notebook stays in the terminal without opening a locked phone window")
		main.call("_on_chapter_terminal_app_pressed", "notebook")
		await _frames()
		var notebook: Control = main._app_windows.get("notebook")
		_check(notebook != null and terminal.get_content_root().is_ancestor_of(notebook), "notebook is displayed inside the terminal render target")
		main._on_composer_bank_tapped("门")
		await _frames()
		if visit == 0:
			# A real allowed terminal operation supplies a valid draft. The same
			# callbacks must cease working after that temporary context closes.
			main._on_pickup_unit_meta("开", "floor_13")
			main.call("_end_chapter_terminal")
			await create_timer(0.75).timeout
			var draft_before: Array = main.game.get_free_sentence_units()
			var locked_records: int = main.game.sentence_records.size()
			main._on_composer_bank_tapped("开")
			main._on_composer_answer_tapped(0)
			main._on_composer_submit_pressed()
			await _frames()
			_check(draft_before == ["门"] and main.game.get_free_sentence_units() == draft_before, "locked notebook callbacks cannot add or remove units from a valid shared draft")
			_check(main.game.sentence_records.size() == locked_records and not main.game.has_current_chapter_submission(), "direct submit callback cannot bypass a locked phone notebook")
			_check(main.game.active_app_window == "" and main.game.view_state == "npc_up", "denied callbacks do not reopen a locked phone window")
			if not await _interact(main, "chapter1_terminal"):
				return
			main.call("_on_chapter_terminal_app_pressed", "notebook")
			await _frames()
		var records_before: int = main.game.sentence_records.size()
		main._on_composer_submit_pressed()
		await _frames()
		_check(main.game.sentence_records.size() == records_before + 1 and main.game.has_current_chapter_submission(), "real composer handler records this visit's successful expression")
		if visit == 0:
			for retry in range(24):
				main._on_composer_bank_tapped("门")
				main._on_composer_submit_pressed()
				await _frames()
				_check(main.game.sentence_records.size() == records_before + retry + 2, "terminal practice retry %d records a real successful submission" % (retry + 2))
				_check(main.game.actions_remaining == 5 and not main.game.needs_day_settlement and not main.game.pollution_flashback_pending, "terminal practice retry %d cannot consume the daily budget or queue forced settlement" % (retry + 2))
			_check(main.game.pollution >= State.POLLUTION_FLASHBACK_THRESHOLD, "repeated terminal practice really crosses the ordinary pollution flashback threshold")
		_check(not main.game.chapter1_progress.completed_task_ids.has(task_id), "a submission alone does not deliver the NPC task")
		_check(main.game.actions_remaining == 5 and not main.game.needs_day_settlement, "tutorial retries do not consume the normal daily action budget")
		var screen_pose: Transform3D = main._camera.global_transform
		main.call("_end_chapter_terminal")
		var player_at_exit: Vector3 = main._reality_player.position
		_check(main._camera.global_transform.is_equal_approx(screen_pose) and main._chapter_terminal_session.is_camera_moving(), "leaving CRT starts a continuous return from the screen camera")
		await create_timer(0.75).timeout
		await _frames()
		_check(not main.call("_chapter_terminal_active") and main.game.view_state == "npc_up", "leaving CRT returns to first-person world interaction")
		_check(main._camera.current and main._camera.get_viewport() == main.get_viewport(), "leaving CRT restores the main first-person camera")
		var player_after_frames: Vector3 = main._reality_player.position
		var tracking_error: float = main._camera.position.distance_to(player_after_frames + Vector3(0.0, 1.56, 0.0))
		_check(tracking_error <= player_at_exit.distance_to(player_after_frames) + 0.02, "after exit, normal camera interpolation follows only the player's subsequent movement")
		for app_id: String in original_controls:
			var window: Control = main._app_windows.get(app_id)
			var before: Dictionary = original_controls[app_id]
			_check(window != null and window.get_instance_id() == before.instance and window.get_parent().get_instance_id() == before.parent, "%s returns from CRT to its exact original parent without being replaced" % app_id)
		if not await _interact(main, "chapter1_npc"):
			return
		_check(main._reality_interaction_active and not main.game.chapter1_progress.completed_task_ids.has(task_id), "a valid submission still waits for the player's current NPC dialogue to finish")
		await _finish_npc_conversation(main)
		_check(main.game.chapter1_progress.completed_task_ids.has(task_id), "typed dialogue naturally delivers the current NPC/task/token in visit %d" % (visit + 1))
		var expected_apps: Array = ["social"]
		if visit >= 2:
			expected_apps.append("notebook")
		_check(main.game.chapter1_progress.unlocked_app_ids == expected_apps, "phone apps unlock at deliveries 1 and 3; the fifth delivery opens the exit")
		_dismiss_task(main)
		await _frames()
		if visit in [0, 2, 4]:
			_check(main._save_progress(), "visit %d writes the ordinary save envelope" % (visit + 1))
			_check(main.continue_game(), "visit %d continues through the actual main save loader" % (visit + 1))
			main._set_reality_mouse_look(false)
			await _frames()
			_check(main.game.chapter1_progress.unlocked_app_ids == expected_apps and main.game.is_social_char_collected("门", "zh"), "continue preserves earned phone permissions and the shared vocabulary")
			_check(main.game.chapter1_progress.phone_collected and main.game.dialogue_typing_hint_seen and main._phone_tab.visible, "continue preserves the acquired phone and acknowledged first typing hint")
			_check(main.game.has_current_chapter_submission() and main.game.chapter1_progress.completed_task_ids.has(task_id), "continue preserves both expression provenance and delivered task")
			_check(not main.call("_chapter_terminal_active"), "a terminal session never persists into a continued game")
		var departed: Dictionary = main.notify_chapter1("basement_exit_requested", {"round_token": token})
		_check(departed.accepted, "normal completed-task exit advances visit %d" % (visit + 1))
		await _frames()
	_check(main.game.chapter1_progress.phase == "crossroads", "five actual UI submissions and deliveries reach the crossroads")
	_check(main.game.collected_prerequisite_item_ids.has(hidden_item_id), "hidden-ending collection survives the complete tutorial loop independently")
	var gate: Dictionary = main.notify_chapter1("crossroads_gate_requested")
	_check(gate.accepted and main.game.chapter1_progress.phase == "tower", "all earned app permissions and all five delivered tasks open the far gate")


func _test_crt_setting(main: Node, terminal: Node) -> void:
	var toggle := main.find_child("SettingsCRTVHSToggle", true, false) as CheckButton
	_check(toggle != null, "settings expose an independent CRT VHS toggle")
	if toggle == null:
		return
	var global_vhs: bool = main._vhs_enabled
	toggle.toggled.emit(false)
	await _frames()
	_check(not terminal.is_vhs_enabled() and main._vhs_enabled == global_vhs, "real CRT toggle disables only the terminal effect")
	var locale = load("res://scripts/localization/game_locale.gd").new()
	locale.preferences_path = main._locale.preferences_path
	_check(not bool(locale.load_preferences(80, true).get("crt_vhs_enabled", true)), "CRT setting is saved through the real settings handler")
	toggle.toggled.emit(true)
	await _frames()
	_check(terminal.is_vhs_enabled() and main._vhs_enabled == global_vhs, "CRT VHS can be enabled without changing full-screen VHS")


func _test_settings_lifecycle() -> void:
	var main = load("res://scenes/babel_meme_game.tscn").instantiate()
	var receiver := FakeReceiver.new()
	main._hand_tracking_receiver = receiver
	receiver.frame_received.connect(main._on_hand_tracking_frame)
	receiver.status_changed.connect(main._on_hand_tracking_status_changed)
	receiver.source_ready.connect(main._on_camera_source_ready)
	main._save_path = "user://aphasia_test_chapter_terminal_settings.dat"
	main._locale.preferences_path = "user://aphasia_test_chapter_terminal_flow_preferences.cfg"
	root.add_child(main)
	main._resolve_camera_consent(false)
	main._begin_game_session(_basement_state(), {}, false)
	main._set_reality_mouse_look(false)
	await _frames()
	var controls: Array[Control] = []
	for app_id: String in Director.REQUIRED_APP_IDS:
		controls.append(main._app_windows[app_id])
	controls.append(main._social_detail_window)
	controls.append(main._pickup_flight_layer)
	var original_parents: Dictionary = {}
	for control in controls:
		original_parents[control.get_instance_id()] = control.get_parent().get_instance_id()
	if not await _interact(main, "chapter1_terminal"):
		main.free()
		await _frames()
		return
	var session: Node = main._chapter_terminal_session
	var terminal: Node = session.get_terminal()
	var session_id := session.get_instance_id()
	var terminal_id := terminal.get_instance_id()
	var detail: Control = main._social_detail_window
	main._apply_responsive_layouts_if_needed(true)
	_check(detail.position.is_equal_approx(Vector2(16, 90)) and detail.size.is_equal_approx(Vector2(776, 1070)), "responsive relayout preserves the terminal's paired social detail rectangle")
	var exit_button := terminal.find_child("TerminalExit", true, false) as Button
	_check(exit_button != null, "terminal provides its actual exit button for held-input regression")
	if exit_button == null:
		main.free()
		await _frames()
		return
	var clicks := [0]
	exit_button.pressed.connect(func(): clicks[0] += 1)
	var position: Vector2 = _terminal_button_position(main, terminal, exit_button)
	main._input(_mouse_motion(position))
	main._input(_mouse_button(position, true))
	_check(exit_button.button_pressed and not terminal.get("_pressed_buttons").is_empty(), "main input route really holds an existing CRT control before Esc")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	main._input(escape)
	_check(main._settings_open and main.call("_chapter_terminal_active") and not terminal.is_active(), "Esc pauses terminal input while retaining its session")
	_check(terminal.get("_pressed_buttons").is_empty() and not exit_button.button_pressed and clicks[0] == 0, "opening settings cancels the held press without activating Exit")
	if not main.call("_chapter_terminal_active"):
		main.free()
		await _frames()
		return
	var paused_pointer: Vector2 = terminal.get_pointer_position()
	main._input(_mouse_button(position, false))
	_check(main.call("_chapter_terminal_active") and terminal.get_pointer_position() == paused_pointer and clicks[0] == 0, "mouse release inside settings does not route back into the paused CRT")
	main._input(escape)
	await _frames()
	_check(not main._settings_open and main.call("_chapter_terminal_active") and terminal.is_active(), "closing settings resumes the same terminal session")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not main._reality_mouse_look_enabled, "returning from settings keeps the CRT cursor free and first-person look uncaptured")
	var notebook_button := terminal.find_child("TerminalAppNotebook", true, false) as Button
	_check(notebook_button != null, "terminal provides its existing notebook tab")
	if notebook_button != null:
		position = _terminal_button_position(main, terminal, notebook_button)
		main._input(_mouse_motion(position))
		main._input(_mouse_button(position, true))
		main._input(_mouse_button(position, false))
		_check(main.game.active_app == "notebook" and terminal.get("_pressed_buttons").is_empty(), "fresh physical CRT click works after settings resume and clears capture on release")
	var restored_before_free: Dictionary = {}
	for control in controls:
		var control_id := control.get_instance_id()
		restored_before_free[control_id] = false
		control.tree_exiting.connect(_observe_restored_parent.bind(control, original_parents[control_id], restored_before_free))
	main._input(escape)
	var menu := main.find_child("SettingsReturnMainButton", true, false) as Button
	_check(menu != null and menu.is_visible_in_tree(), "terminal settings expose the real return-to-main-menu action")
	if menu != null:
		menu.pressed.emit()
	await _frames()
	_check(not main._game_started and main.find_child("MainMenuLayer", true, false) != null, "return-to-menu button reaches the ordinary main menu")
	_check(not main.call("_chapter_terminal_active") and main.get("_chapter_terminal_session") == null and not is_instance_id_valid(session_id) and not is_instance_id_valid(terminal_id), "returning to menu releases both terminal component and session")
	for control_id in restored_before_free:
		_check(restored_before_free[control_id], "shared Control %d is restored to its exact original parent before the old UI is freed" % control_id)
	_check(receiver.start_count == 0, "settings lifecycle never starts a physical camera")
	main.free()
	await _frames()


func _observe_restored_parent(control: Control, parent_id: int, restored: Dictionary) -> void:
	# Reparenting emits tree_exiting before restoration, then menu teardown
	# emits it again from the original parent. Observe that second boundary.
	if control.get_parent() != null and control.get_parent().get_instance_id() == parent_id:
		restored[control.get_instance_id()] = true


func _terminal_button_position(main: Node, terminal: Node, button: Button) -> Vector2:
	var uv := button.get_global_rect().get_center() / Vector2(1600, 1200)
	var mesh: MeshInstance3D = terminal.get("_mesh")
	for triangle: Dictionary in terminal.get("_triangles"):
		var edge_b: Vector2 = triangle.uv_b - triangle.uv_a
		var edge_c: Vector2 = triangle.uv_c - triangle.uv_a
		var offset: Vector2 = uv - triangle.uv_a
		var determinant := edge_b.cross(edge_c)
		var u := offset.cross(edge_c) / determinant
		var v := edge_b.cross(offset) / determinant
		if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001:
			var local_point: Vector3 = triangle.a + (triangle.b - triangle.a) * u + (triangle.c - triangle.a) * v
			return main._camera.unproject_position(mesh.to_global(local_point))
	_check(false, "actual terminal button must fit inside the authored screen UV bounds")
	return Vector2(-100, -100)


func _mouse_button(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return event


func _mouse_motion(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	return event


func _reveal_first_key_clue(main: Node) -> String:
	var actor := _actor(main, "chapter1_npc")
	# RealityFloorGenerator._make_actor derives this ID from type, floor and
	# the original KeyNPC node name; chapter IDs must not replace that source.
	_check(actor != null and str(actor.get_meta("source_actor_id", "")) == "key_npc_1_keynpc" and str(actor.get_meta("source_actor_type", "")) == "key_npc", "first tutorial NPC retains its existing canonical key NPC source")
	_check(main._reality_interaction_active and main.game.conversation_phase == "typing", "F opens the original authored key NPC content directly")
	if actor == null:
		return ""
	_check(main.game.conversation_actor_id == actor.get_meta("source_actor_id") and main.game.conversation_actor_type == "key_npc", "direct dialogue retains the key NPC's canonical source ID")
	var item_id := str(main.game.get_prerequisite_item_for_floor(1).get("id", ""))
	_check(not main.game.is_prerequisite_item_revealed(item_id) and not main.game.collected_prerequisite_item_ids.has(item_id), "the hidden clue is unavailable before completing the key NPC dialogue")
	await _finish_npc_conversation(main)
	_check(main.game.conversation_history.size() == 2, "both original key NPC turns are spoken")
	_check(main.game.is_prerequisite_item_revealed(item_id), "completing both authored turns reveals the original hidden-ending clue")
	_check(main.game.collected_prerequisite_item_ids.has(item_id), "the single conversation naturally receives its revealed clue without a separate menu")
	_check(main.game.chapter1_progress.unlocked_app_ids.is_empty() and main.game.chapter1_progress.completed_task_ids.is_empty(), "old key dialogue neither grants apps nor delivers a tutorial task")
	return item_id


func _finish_npc_conversation(main: Node) -> void:
	var keyboard: Node = main._ui_root.get_node_or_null("LinearDialogueKeyboard")
	_check(keyboard != null, "conversation has its actual keyboard input control")
	if keyboard == null:
		return
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_A
	event.unicode = "a".unicode_at(0)
	for turn in range(10):
		_check(main.game.conversation_phase == "typing", "each authored protagonist turn enters typing without a menu")
		var expected_units: int = main.game.get_typed_reality_unit_count()
		for unit in range(expected_units):
			keyboard._input(event)
		_check(main.game.conversation_phase == "result", "one key per authored unit completes the current protagonist turn")
		await _frames()
		if not main.game.conversation_can_continue:
			_check(main.game.conversation_completed, "all authored turns finish even after heavy terminal practice pollution")
			return
		_check(_button(main, "RealityConversationContinue") == null and not _button(main, "RealityConversationEnd").visible, "intermediate NPC turns have no Continue or End button")
		main._update_reality_dialogue(1000.0)
		await _frames()
	_check(false, "authored conversation terminates within ten turns")


func _interact(main: Node, actor_type: String) -> bool:
	var actor := _actor(main, actor_type)
	_check(actor != null, "current world provides interactable %s" % actor_type)
	if actor == null:
		return false
	main.set_view_state("npc_up")
	main._set_reality_mouse_look(false)
	main._reality_player.global_position = actor.global_position + Vector3(0.0, 0.05, 0.35)
	main._reality_player.velocity = Vector3.ZERO
	main._reality_last_safe_position = main._reality_player.position
	main._animate_world(1.0)
	main._refresh_nearby_reality_actor()
	var starting_pose: Transform3D = main._camera.global_transform
	var accepted: bool = main._try_reality_interaction()
	_check(accepted, "nearby F interaction reaches %s through the real world event" % actor_type)
	if accepted and actor_type == "chapter1_terminal":
		_check(main._camera.global_transform.is_equal_approx(starting_pose), "CRT approach starts at the current player pose without a snap")
		await create_timer(0.90).timeout
	await _frames()
	return accepted


func _actor(main: Node, actor_type: String) -> Area3D:
	for actor: Area3D in main._reality_floor.get_interactable_actors():
		if str(actor.get_meta("actor_type", "")) == actor_type:
			return actor
	return null


func _button(main: Node, node_name: String) -> Button:
	return main.find_child(node_name, true, false) as Button


func _dismiss_task(main: Node) -> void:
	if main._reality_interaction_active:
		main._update_reality_dialogue(1000.0)
		var button := _button(main, "RealityConversationEnd")
		_check(button != null and button.visible, "the final NPC reply presents End")
		if button != null:
			button.pressed.emit()
	_check(not main._reality_interaction_active, "End immediately returns control to exploration")


func _basement_state() -> MemeGameState:
	var state := State.new()
	state.new_run()
	state.start_chapter1()
	state.notify_chapter1("narration_completed", {"sequence_id": "chapter1_opening"})
	state.notify_chapter1("opening_knock_completed", {"sequence_id": "chapter1_opening"})
	state.notify_chapter1("opening_door_opened")
	# This broad app/task regression starts after onboarding. The dedicated
	# test_chapter_crt_terminal_onboarding starts empty and performs every real
	# UV pickup/drag/publish; this fixture keeps its independent empty inventory.
	state.chapter1_progress.crt_tutorial = preload("res://scripts/tutorial/chapter_crt_tutorial_state.gd").normalize({
		"focus_started": true, "focus_done": true, "focus_line": 7,
		"lesson_phase": "complete", "locale": "zh", "collected": ["门", "打", "开"],
		"dragged": ["门", "打", "开"], "published": true,
	})
	state.view_state = "npc_up"
	state.active_app_window = ""
	return state


func _frames(count: int = 3) -> void:
	for index in range(count):
		await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
