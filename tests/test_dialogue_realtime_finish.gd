extends SceneTree

const State = preload("res://scripts/meme_game_state.gd")
const Flow = preload("res://scripts/ui/linear_dialogue_flow.gd")
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	root.visible = false
	root.size = Vector2i(1600, 900)
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
	_check(main.game.floor_two_progress.accepted, "completing the reply accepts the wayfinder task")
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
	_check(main.game.is_phone_app_unlocked("map"), "completing the reply delivers the map")
	_check(main.game.conversation_phase == "idle", "the end button clears the conversation state")
	_check(not main._reality_subtitle_panel.visible, "the end button removes the blocking dialogue presentation")
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
	for code in ["ja", "en"]:
		main._locale.set_locale(code)
		await _speak_through_keys(main, "floor2_cartographer")
		await _wait_for_last_reply(main, "%s-repeat" % code)
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
	var japanese: bool = main._locale.current_locale == "ja"
	if main._locale.current_locale != "zh":
		var source: Dictionary = main.game._reality_dialogue_for_actor(actor_id, "npc")
		_check(main.game.conversation_prompt != str(source.get("line", "")), "actual NPC dialogue uses the selected locale instead of Chinese fallback")
	for unit in 400:
		if main.game.conversation_phase != "typing":
			break
		var previous: int = main.game.conversation_reveal_index
		var last_character: bool = previous + 1 == main.game.get_typed_reality_unit_count()
		_press(KEY_A, 97)
		if last_character:
			_check(main.game.conversation_phase == "result", "the last key enters the NPC reply synchronously, without a post-typing delay")
		await process_frame
		if japanese:
			_check(main.game.conversation_reveal_index == previous + 1, "an actual Japanese key event advances one character")
			var revealed: Dictionary = main.game.conversation_revealed_units[previous]
			_check(str(revealed.clean).length() == 1 and str(revealed.display).length() == 1, "Japanese clean and corrupted displays both reveal a single character")
	_check(main.game.conversation_phase == "result" and main.game.conversation_completed, "real typing reaches the final NPC reply even at maximum pollution")
	await process_frame
	_check(not main._reality_subtitle_label.get_parsed_text().contains(main.game.conversation_prompt), "the final keystroke immediately replaces the old prompt with the NPC reply")
	var button := main.find_child("RealityConversationEnd", true, false) as Button
	_check(button != null and not button.visible, "the end button stays hidden until the last reply finishes")

func _wait_for_last_reply(main, label: String) -> void:
	# Only the newly displayed response needs reading time. The opening line was
	# already visible throughout typing and must not start a second long delay.
	var allowance := Flow.reading_seconds(main.game.conversation_feedback) + 0.6
	var elapsed := 0.0
	var button := main.find_child("RealityConversationEnd", true, false) as Button
	while main._reality_interaction_active and (button == null or not button.visible) and elapsed < allowance:
		await process_frame
		elapsed += main.get_process_delta_time()
	print("REALTIME %s elapsed=%.3f allowance=%.3f active=%s" % [label, elapsed, allowance, main._reality_interaction_active])
	_check(main._reality_interaction_active and button != null and button.visible, "%s offers the end button after real reply frames and waits for a click" % label)
	if button == null or not button.visible:
		return
	_check(button.text == main._locale.translate("结束对话"), "the only exit button follows the selected language")
	if label == "wayfinder":
		main._toggle_settings_window()
		_check(not button.visible, "settings hides the completed dialogue button")
		main._on_reality_end_pressed()
		_check(main._reality_interaction_active, "a blocked End callback cannot close dialogue behind settings")
		main._close_settings_window()
		_check(button.visible, "closing settings restores the completed dialogue button")
	main._render()
	await _wait_frames_for(0.2)
	_check(button.visible and not main._ui_root.get_node("LinearDialogueFlow").pending, "rerendering never restarts a completed reply")
	var click := InputEventMouseButton.new()
	click.position = button.get_global_rect().get_center()
	click.global_position = click.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	_check(not main._reality_interaction_active and main.game.conversation_phase == "idle", "clicking the end button exits synchronously without another frame or key")

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
	# Deliver Godot's accumulated key events now, so the immediate-phase check
	# measures the input handler rather than the engine's next-frame queue flush.
	Input.flush_buffered_events()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
