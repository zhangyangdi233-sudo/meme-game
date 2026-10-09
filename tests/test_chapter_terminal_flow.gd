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
	main._save_path = "user://test_chapter_terminal_flow.dat"
	main._locale.preferences_path = "user://test_chapter_terminal_flow_preferences.cfg"
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
		var submit := _button(main, "ChapterTaskSubmitButton")
		var panel := main.find_child("ChapterTaskPanel", true, false) as Control
		_check(panel != null and panel.visible, "real NPC interaction opens its task panel")
		_check(submit != null and submit.disabled, "NPC submit is disabled until this visit has an expression")
		if visit == 0:
			hidden_item_id = await _reveal_first_key_clue(main)
		elif visit == 1 and not hidden_item_id.is_empty():
			var collect := _button(main, "ChapterHiddenClueCollectButton")
			_check(collect != null and collect.visible and not collect.disabled, "a revealed first-floor clue remains collectable from the next visit's NPC")
			var apps_before: Array = main.game.chapter1_progress.unlocked_app_ids.duplicate()
			if collect != null and not collect.disabled:
				collect.pressed.emit()
				await _frames()
			_check(main.game.collected_prerequisite_item_ids.has(hidden_item_id), "the real clue collection button preserves the existing hidden-ending item route")
			_check(main.game.chapter1_progress.unlocked_app_ids == apps_before and not main.game.chapter1_progress.completed_task_ids.has(task_id), "collecting the clue neither grants app permissions nor completes the tutorial task")
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
			await _frames()
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
		main.call("_end_chapter_terminal")
		var player_at_exit: Vector3 = main._reality_player.position
		_check(main._camera.position.is_equal_approx(player_at_exit + Vector3(0.0, 1.56, 0.0)), "leaving CRT immediately restores camera position to the player's first-person eye point")
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
		submit = _button(main, "ChapterTaskSubmitButton")
		_check(submit != null and not submit.disabled, "current NPC enables explicit delivery only after the matching expression")
		if submit == null or submit.disabled:
			return
		submit.pressed.emit()
		await _frames()
		_check(main.game.chapter1_progress.completed_task_ids.has(task_id), "NPC button delivers the current NPC/task/token in visit %d" % (visit + 1))
		var expected_apps: Array = ["social"]
		if visit >= 2:
			expected_apps.append("notebook")
		if visit >= 4:
			expected_apps.append("babel")
		_check(main.game.chapter1_progress.unlocked_app_ids == expected_apps, "phone apps unlock exactly at deliveries 1, 3, and 5")
		_dismiss_task(main)
		await _frames()
		if visit in [0, 2, 4]:
			_check(main._save_progress(), "visit %d writes the ordinary save envelope" % (visit + 1))
			_check(main.continue_game(), "visit %d continues through the actual main save loader" % (visit + 1))
			main._set_reality_mouse_look(false)
			await _frames()
			_check(main.game.chapter1_progress.unlocked_app_ids == expected_apps and main.game.is_social_char_collected("门", "zh"), "continue preserves earned phone permissions and the shared vocabulary")
			_check(main.game.has_current_chapter_submission() and main.game.chapter1_progress.completed_task_ids.has(task_id), "continue preserves both expression provenance and delivered task")
			_check(not main.call("_chapter_terminal_active"), "a terminal session never persists into a continued game")
		_check(main.notify_chapter1("basement_tunnel_entered", {"round_token": token}).accepted, "completed-task fixture enters the tunnel before the white-door transition")
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
	main._save_path = "user://test_chapter_terminal_settings.dat"
	main._locale.preferences_path = "user://test_chapter_terminal_flow_preferences.cfg"
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
	var talk := _button(main, "ChapterTaskTalkButton")
	# RealityFloorGenerator._make_actor derives this ID from type, floor and
	# the original KeyNPC node name; chapter IDs must not replace that source.
	_check(actor != null and str(actor.get_meta("source_actor_id", "")) == "key_npc_1_keynpc" and str(actor.get_meta("source_actor_type", "")) == "key_npc", "first tutorial NPC retains its existing canonical key NPC source")
	_check(talk != null and not talk.disabled, "task panel retains the separate authored talk route")
	if actor == null or talk == null:
		return ""
	talk.pressed.emit()
	await _frames()
	_check(main.game.conversation_actor_id == actor.get_meta("source_actor_id") and main.game.conversation_actor_type == "key_npc", "Talk opens existing key NPC content with its canonical source ID")
	var item_id := str(main.game.get_prerequisite_item_for_floor(1).get("id", ""))
	for turn in range(2):
		var choice_id := ""
		for choice: Dictionary in main.game.get_typed_reality_choices():
			if bool(choice.get("correct", false)):
				choice_id = str(choice.get("id", ""))
		_check(not choice_id.is_empty(), "existing key clue turn %d retains its authored correct answer" % (turn + 1))
		if choice_id.is_empty():
			break
		main._on_reality_choice_selected(choice_id)
		var safety := 0
		while main.game.conversation_phase == "typing" and safety < 1000:
			main.game.advance_typed_reality_character()
			safety += 1
		if turn == 0:
			main._on_reality_continue_pressed()
			await _frames()
	_check(main.game.is_prerequisite_item_revealed(item_id), "two existing authored answers reveal the original hidden-ending clue")
	_check(not main.game.collected_prerequisite_item_ids.has(item_id), "revealing a clue remains separate from collecting it")
	_check(main.game.chapter1_progress.unlocked_app_ids.is_empty() and main.game.chapter1_progress.completed_task_ids.is_empty(), "old key dialogue neither grants apps nor delivers a tutorial task")
	main._exit_reality_interaction()
	await _frames()
	return item_id


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
	main._refresh_nearby_reality_actor()
	var accepted: bool = main._try_reality_interaction()
	_check(accepted, "nearby F interaction reaches %s through the real world event" % actor_type)
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
	var button := _button(main, "ChapterTaskDismissButton")
	if button != null and button.is_visible_in_tree():
		button.pressed.emit()


func _basement_state() -> MemeGameState:
	var state := State.new()
	state.new_run()
	state.start_chapter1()
	state.notify_chapter1("opening_knock_completed", {"sequence_id": "chapter1_opening"})
	state.notify_chapter1("opening_door_opened")
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
