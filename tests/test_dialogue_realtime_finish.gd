extends SceneTree

const State = preload("res://scripts/meme_game_state.gd")
const Flow = preload("res://scripts/ui/linear_dialogue_flow.gd")
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	root.visible = false
	_run.call_deferred()

func _run() -> void:
	var main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._save_path = "user://test_dialogue_realtime_finish.dat"
	main._locale.preferences_path = "user://test_dialogue_realtime_finish.cfg"
	main._locale.save_preferences(80, false, false, "computer")
	root.add_child(main)
	main._resolve_camera_consent(false)
	main._locale.set_locale("zh")
	var state = State.new()
	state.new_run()
	state.tower_floor = 2
	state.pollution = 100
	state.set_view_state("npc_up")
	main._begin_game_session(state, {}, false)
	await process_frame
	await _speak_through_keys(main, "floor2_wayfinder")
	await _wait_for_last_reply(main, "wayfinder")
	_check(main.game.floor_two_progress.accepted, "automatic completion accepts the wayfinder task")
	if main._reality_interaction_active:
		main._exit_reality_interaction()
	main.game.visit_floor_two_turn("turn_1")
	main.game.visit_floor_two_turn("turn_2")
	await _speak_through_keys(main, "floor2_cartographer")
	var flow = main._ui_root.get_node_or_null("LinearDialogueFlow")
	_check(flow != null and flow.pending, "the final reply owns an active playback clock")
	if flow != null:
		main._toggle_settings_window()
		var before: float = flow.remaining_seconds
		await _wait_frames_for(0.5)
		_check(main._reality_interaction_active and is_equal_approx(flow.remaining_seconds, before), "actual frames pause the reply while Settings is open")
		main._close_settings_window()
		main._show_phone_camera_connection_overlay()
		before = flow.remaining_seconds
		await _wait_frames_for(0.5)
		_check(main._reality_interaction_active and is_equal_approx(flow.remaining_seconds, before), "actual frames pause the reply under a modal")
		main._hide_phone_camera_connection_overlay()
	await _wait_for_last_reply(main, "cartographer")
	_check(main.game.is_phone_app_unlocked("map"), "automatic completion delivers the map without another input")
	_check(main.game.conversation_phase == "idle", "the last reply clears the conversation state")
	_check(not main._reality_subtitle_panel.visible, "the last reply removes the blocking dialogue presentation")
	# The interactive preview starts with the map already earned. Its repeat
	# conversations must close through the same real frame path as first visits.
	await _speak_through_keys(main, "floor2_wayfinder")
	await _wait_for_last_reply(main, "preview-wayfinder-repeat")
	await _speak_through_keys(main, "floor2_cartographer")
	flow = main._ui_root.get_node_or_null("LinearDialogueFlow")
	main._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var focus_remaining: float = flow.remaining_seconds
	await _wait_frames_for(0.4)
	_check(main._reality_interaction_active and is_equal_approx(flow.remaining_seconds, focus_remaining), "focus loss pauses real reply frames without consuming its interval")
	main._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _wait_for_last_reply(main, "preview-cartographer-repeat")
	_check(main.game.is_phone_app_unlocked("map"), "repeat conversations preserve the earned app")
	main._set_reality_mouse_look(false)
	main.queue_free()
	for frame in 4:
		await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("real-time dialogue finish tests passed (%d checks)" % checks)
	quit(0 if failures.is_empty() else 1)

func _speak_through_keys(main, actor_id: String) -> void:
	var found := false
	for actor: Area3D in main._reality_floor.get_interactable_actors():
		if str(actor.get_meta("actor_id", "")) != actor_id:
			continue
		found = true
		main._reality_player.position = main._reality_floor.clamp_to_playable_position(actor.position + Vector3(0, 0, 1), 0.45)
		main._refresh_nearby_reality_actor()
	_check(found, "authored NPC exists for real keyboard interaction")
	_press(KEY_F)
	await process_frame
	_check(main._reality_interaction_active and main.game.conversation_phase == "typing", "real F input starts the fixed protagonist line")
	for unit in 400:
		if main.game.conversation_phase != "typing":
			break
		_press(KEY_A, 97)
		await process_frame
	_check(main.game.conversation_phase == "result" and main.game.conversation_completed, "real typing reaches the final NPC reply even at maximum pollution")

func _wait_for_last_reply(main, label: String) -> void:
	# Only the newly displayed response needs reading time. The opening line was
	# already visible throughout typing and must not start a second long delay.
	var allowance := Flow.reading_seconds(main.game.conversation_feedback) + 0.6
	var elapsed := 0.0
	while main._reality_interaction_active and elapsed < allowance:
		await process_frame
		elapsed += main.get_process_delta_time()
	print("REALTIME %s elapsed=%.3f allowance=%.3f active=%s" % [label, elapsed, allowance, main._reality_interaction_active])
	_check(not main._reality_interaction_active, "%s automatically exits after the last response's reading time using only real frames" % label)

func _wait_frames_for(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await process_frame
		elapsed += root.get_process_delta_time()

func _press(code: Key, unicode_value: int = 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = unicode_value
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
