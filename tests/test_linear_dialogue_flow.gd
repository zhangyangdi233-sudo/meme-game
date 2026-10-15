extends SceneTree

const State := preload("res://scripts/meme_game_state.gd")
const Director := preload("res://scripts/progression/basement_loop_director.gd")

var failures: Array[String] = []
var checks := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_playback_clock()
	var main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._save_path = "user://aphasia_test_linear_dialogue.dat"
	main._locale.preferences_path = "user://aphasia_test_linear_dialogue_preferences.cfg"
	main._camera_session_decided = true
	main._camera_enabled = false
	root.add_child(main)
	main._resolve_camera_consent(false)
	for locale_code in ["zh", "en", "ja"]:
		var state = State.new()
		state.new_run()
		state.set_view_state("npc_up")
		main._locale.set_locale(locale_code)
		main._begin_game_session(state, {}, false)
		await process_frame
		_check(main.game.start_typed_reality_conversation("floor_1_key", "key_npc", "关键住户"), "authored NPC starts in %s" % locale_code)
		main._localize_active_conversation()
		main._reality_interaction_active = true
		main._render()
		_check(main.game.conversation_phase == "typing", "NPC proceeds directly to the single protagonist line in %s" % locale_code)
		_check(not main._reality_choice_row.visible and main._reality_choice_row.get_child_count() == 0, "NPC has no response options in %s" % locale_code)
		_check(main.find_child("RealityConversationContinue", true, false) == null, "dialogue has no continue, end or leave button")
		var keyboard: Node = main._ui_root.get_node_or_null("LinearDialogueKeyboard")
		_check(keyboard != null, "dialogue owns a keyboard input receiver")
		if keyboard == null:
			continue
		_check(not main._reality_typing_progress.text.is_empty(), "first protagonist line explains typing in %s" % locale_code)
		var saved_state = State.new()
		_check(saved_state.load_save_data(main.game.to_save_data()) and saved_state.dialogue_typing_hint_seen, "the first typing instruction remains acknowledged after save/load")
		_check(main._reality_typing_progress.offset_top >= main._reality_typing_line.offset_bottom, "typing instruction sits below protagonist speech")
		if locale_code == "zh":
			await _test_modal_keyboard_routing(main)
		var first_index: int = main.game.conversation_reveal_index
		var unit_count: int = main.game.get_typed_reality_unit_count()
		Input.parse_input_event(_key(KEY_A, "a"))
		await process_frame
		_check(main.game.conversation_reveal_index == first_index + 1, "a real printable key advances exactly one dialogue unit")
		for ignored in [_key(KEY_SHIFT), _key(KEY_LEFT), _key(KEY_ENTER), _key(KEY_A, "a", true), _key(KEY_A, "a", false, true)]:
			keyboard._input(ignored)
		_check(main.game.conversation_reveal_index == first_index + 1, "modifiers, arrows, Enter, key repeat and shortcuts do not type dialogue")
		main._settings_open = true
		keyboard._input(_key(KEY_B, "b"))
		_check(main.game.conversation_reveal_index == first_index + 1, "settings pause typing")
		main._settings_open = false
		main._application_focused = false
		keyboard._input(_key(KEY_B, "b"))
		_check(main.game.conversation_reveal_index == first_index + 1, "focus loss pauses typing")
		main._application_focused = true
		keyboard._input(_key(KEY_NONE, "字"))
		_check(main.game.conversation_reveal_index == mini(first_index + 2, unit_count), "Unicode input respects the available dialogue units in %s" % locale_code)
		_finish_turn(main, keyboard)
		_check(main.game.conversation_can_continue, "the key NPC keeps its authored next turn")
		if locale_code == "zh":
			await _test_reply_pause(main)
		_advance_reply(main)
		_check(main.game.conversation_phase == "typing", "continuation chooses the next authored line without options")
		_check(main._reality_typing_progress.text.is_empty() and not main._reality_typing_progress.visible, "typing instruction appears only on the first protagonist line")
		_finish_turn(main, keyboard)
		_check(main.game.conversation_completed, "single route completes all key NPC dialogue")
		_check(main.game.is_prerequisite_item_revealed(str(main.game.get_prerequisite_item_for_floor(1).id)), "single route retains the hidden-clue reward")
		_advance_reply(main)
		_check(not main._reality_interaction_active, "the final NPC reply automatically returns to exploration")
		await process_frame
		await process_frame
		var previous_npc_sentence: String = main.game.last_clean_sentence
		main.game.start_typed_reality_conversation("doctor", "doctor", "医生")
		main._localize_active_conversation()
		main._reality_interaction_active = true
		main._render()
		_check(main.game.conversation_phase == "typing" and not main._reality_language_frame.visible, "doctor also speaks a fixed keyboard line without a composer menu")
		_check(main.game.conversation_clean_sentence != previous_npc_sentence, "doctor's fixed reply must not accidentally repeat the previous NPC conversation")
		keyboard._input(_key(KEY_NONE, "字"))
		_check(main.game.conversation_reveal_index == 1, "committed Unicode types the doctor line in every locale")
		_finish_conversation(main, keyboard)
		_check(main.game.conversation_completed, "doctor line completes without requiring old menu selections")
		_advance_reply(main)
		_check(not main._reality_interaction_active, "the doctor's final reply automatically ends without a menu")
		await process_frame
		await process_frame
	_test_reply_cancellation(main)
	await _test_chapter_delivery(main)
	await process_frame
	await process_frame
	main.free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("linear dialogue flow tests passed (%d checks; three locales, real input, automatic replies, pause/focus/cancellation, five NPC deliveries)" % checks)
	quit(0 if failures.is_empty() else 1)


func _test_modal_keyboard_routing(main: Node) -> void:
	var original_index: int = main.game.conversation_reveal_index
	Input.parse_input_event(_key(KEY_ESCAPE))
	await process_frame
	_check(main._settings_open, "real Escape opens settings while typing")
	main._settings_exit_button.pressed.emit()
	Input.parse_input_event(_key(KEY_F10))
	await process_frame
	_check(main._exit_confirmation_overlay.visible and main._settings_open, "F10 cannot close settings behind the exit confirmation")
	Input.parse_input_event(_key(KEY_A, "a"))
	await process_frame
	_check(main.game.conversation_reveal_index == original_index, "typing behind the exit confirmation never reaches dialogue")
	Input.parse_input_event(_key(KEY_ESCAPE))
	await process_frame
	_check(not main._exit_confirmation_overlay.visible and main._settings_open, "Escape dismisses only the exit confirmation and leaves settings paused")
	main._cancel_quit_game()
	if not main._settings_open:
		main._toggle_settings_window()
	# Showing the connection panel itself avoids starting a physical camera.
	main._show_phone_camera_connection_overlay()
	Input.parse_input_event(_key(KEY_ESCAPE))
	await process_frame
	_check(not main._phone_camera_connection_overlay.visible and main._settings_open, "Escape dismisses the connection panel before the underlying settings")
	main._hide_phone_camera_connection_overlay()
	if not main._settings_open:
		main._toggle_settings_window()
	Input.parse_input_event(_key(KEY_ESCAPE))
	await process_frame
	_check(not main._settings_open, "another Escape returns from settings to the same dialogue")
	var before_connection: int = main.game.conversation_reveal_index
	main._show_phone_camera_connection_overlay()
	Input.parse_input_event(_key(KEY_A, "a"))
	await process_frame
	_check(main.game.conversation_reveal_index == before_connection, "a connection panel also blocks dialogue when settings is already closed")
	main._hide_phone_camera_connection_overlay()
	main._request_quit_game()
	Input.parse_input_event(_key(KEY_A, "a"))
	await process_frame
	_check(main.game.conversation_reveal_index == before_connection, "an exit confirmation independently blocks dialogue without relying on settings state")
	main._cancel_quit_game()
	_check(not main._settings_open and main.game.conversation_phase == "typing", "closing modals preserves the in-progress protagonist turn")


func _test_reply_pause(main: Node) -> void:
	_check(main.has_method("_update_reality_dialogue"), "NPC replies have automatic playback progression")
	if not main.has_method("_update_reality_dialogue"):
		return
	main._update_reality_dialogue(0.1)
	_check(main.game.conversation_phase == "result", "NPC response stays visible long enough to read")
	main._settings_open = true
	main._update_reality_dialogue(1000.0)
	_check(main.game.conversation_phase == "result", "settings pause the NPC response countdown")
	main._settings_open = false
	main._application_focused = false
	main._update_reality_dialogue(1000.0)
	_check(main.game.conversation_phase == "result", "focus loss pauses the NPC response countdown")
	main._application_focused = true
	main._input_locked = true
	main._update_reality_dialogue(1000.0)
	_check(main.game.conversation_phase == "result", "world transitions pause the NPC response countdown")
	main._input_locked = false
	main._show_phone_camera_connection_overlay()
	main._update_reality_dialogue(1000.0)
	_check(main.game.conversation_phase == "result", "a modal independently pauses the NPC response countdown")
	main._hide_phone_camera_connection_overlay()
	for code in [KEY_F, KEY_TAB]:
		Input.parse_input_event(_key(code))
		await process_frame
		_check(main._reality_interaction_active and main.game.conversation_phase == "result" and main.game.view_state == "npc_up", "world shortcut cannot cut off an NPC response")
	main._update_reality_dialogue(0.1)
	_check(main.game.conversation_phase == "result", "returning from a pause resumes remaining reading time")


func _advance_reply(main: Node) -> void:
	main._update_reality_dialogue(1000.0)


func _test_playback_clock() -> void:
	var flow = load("res://scripts/ui/linear_dialogue_flow.gd").new()
	for texts in [["好。", "这是一段需要让玩家有充足时间阅读的回复。"], ["Yes.", "Take enough time to read this complete reply before moving on."], ["はい。", "次の会話に進む前に、ここにある返事をゆっくり読んでください。"]]:
		_check(flow.reading_seconds(texts[1]) > flow.reading_seconds(texts[0]), "longer NPC replies receive longer reading time in every writing system")
	flow.begin_reply("OK.")
	_check(not flow.advance(0.5, false), "an NPC response is never immediately skipped")
	_check(not flow.advance(1000.0, true), "a paused playback clock does not elapse")
	_check(not flow.advance(-100.0, false), "negative frame time cannot finish a reply")
	_check(not flow.advance(1.9, false), "pausing preserves the exact remaining reading time")
	_check(flow.advance(0.2, false), "reply ends after its remaining unpaused time elapses")
	_check(not flow.advance(1000.0, false), "a completed clock can advance only one turn")
	flow.begin_reply("OK.")
	flow.cancel()
	_check(not flow.advance(1000.0, false), "cancelled dialogue never fires a stale continuation")
	flow.free()


func _test_reply_cancellation(main: Node) -> void:
	main.game.start_typed_reality_conversation("floor_1_key", "key_npc", "关键住户")
	main._localize_active_conversation()
	main._reality_interaction_active = true
	main._render()
	var keyboard: Node = main._ui_root.get_node("LinearDialogueKeyboard")
	_finish_turn(main, keyboard)
	main._update_reality_dialogue(0.5)
	main._exit_reality_interaction()
	main._update_reality_dialogue(1000.0)
	_check(not main._reality_interaction_active and main.game.conversation_phase == "idle", "explicit exit cancels the old reply instead of reopening dialogue")
	main.game.start_typed_reality_conversation("floor_1_key", "key_npc", "关键住户")
	main._localize_active_conversation()
	main._reality_interaction_active = true
	main._render()
	_finish_turn(main, keyboard)
	main._update_reality_dialogue(0.1)
	_check(main.game.conversation_phase == "result", "a restarted conversation receives a fresh reading interval")
	# A different actor can replace a dialogue without inheriting its pending reply.
	main.game.start_typed_reality_conversation("doctor", "doctor", "医生")
	main._localize_active_conversation()
	main._render()
	main._update_reality_dialogue(1000.0)
	_check(main.game.conversation_phase == "typing" and main.game.conversation_reveal_index == 0, "an old reply cannot type or exit a new actor's dialogue")
	_finish_turn(main, keyboard)
	main._update_reality_dialogue(0.1)
	_check(main.game.conversation_phase == "result", "the replacement actor's response receives a fresh interval")
	main._process(1000.0)
	_check(not main._reality_interaction_active, "the production frame update automatically finishes the final NPC reply")
	main.game.start_typed_reality_conversation("doctor", "doctor", "医生")
	main._localize_active_conversation()
	main._reality_interaction_active = true
	main._render()
	_finish_turn(main, keyboard)
	# Rebuilding the session removes the playback node along with its old UI.
	var fresh_state = State.new()
	fresh_state.new_run()
	fresh_state.set_view_state("npc_up")
	main._begin_game_session(fresh_state, {}, false)
	main._update_reality_dialogue(1000.0)
	_check(not main._reality_interaction_active, "rebuilding the interface discards pending dialogue playback")


func _test_chapter_delivery(main: Node) -> void:
	main._locale.set_locale("zh")
	var state = State.new()
	state.new_run()
	state.start_chapter1()
	state.set_view_state("npc_up")
	var progress := Director.initial_progress()
	progress = Director.dispatch(progress, "narration_completed", {"sequence_id": "chapter1_opening"}).progress
	progress = Director.dispatch(progress, "opening_knock_completed", {"sequence_id": "chapter1_opening"}).progress
	state.chapter1_progress = Director.dispatch(progress, "opening_door_opened", {}).progress
	main._begin_game_session(state, {}, false)
	await process_frame
	for visit in range(5):
		var token: int = main.game.chapter1_progress.transition_serial
		main.notify_chapter1("entrance_threshold_crossed", {"round_token": token})
		var actor: Area3D = main._chapter_actor("chapter1_npc")
		_check(actor != null, "visit %d has its NPC" % visit)
		if actor == null:
			return
		main._reality_player.global_position = actor.global_position + Vector3(0, 0, 1.2)
		var payload := {"round_token": token, "task_id": Director.TASK_IDS[visit], "npc_id": "basement_npc_%02d" % (visit + 1)}
		main._show_chapter_task(payload)
		_check(not is_instance_valid(main._chapter_task_panel) and main._reality_interaction_active, "NPC interaction opens dialogue without a task menu")
		var keyboard: Node = main._ui_root.get_node_or_null("LinearDialogueKeyboard")
		if keyboard == null or not main._reality_interaction_active:
			return
		_finish_conversation(main, keyboard)
		_check(not main.game.chapter1_progress.completed_task_ids.has(Director.TASK_IDS[visit]), "speaking without a submitted expression cannot complete delivery")
		_advance_reply(main)
		_check(not main._reality_interaction_active, "the submission reminder closes automatically")
		main.game.pick_social_char("floor_13", "门")
		main.game.free_sentence_place("门")
		_check(main.game.submit_free_sentence().submitted, "visit %d has an actual submitted expression" % visit)
		main.game.pollution = 95
		main._show_chapter_task(payload)
		_finish_conversation(main, keyboard)
		_check(main.game.chapter1_progress.completed_task_ids.has(Director.TASK_IDS[visit]), "completing the dialogue naturally delivers visit %d" % visit)
		_check(not main.game.chapter1_progress.unlocked_app_ids.is_empty(), "NPC app grants remain available on visit %d" % visit)
		_advance_reply(main)
		_check(not main._reality_interaction_active, "task delivery closes automatically after the final NPC response")
		main.notify_chapter1("basement_exit_requested", {"round_token": token})
		await process_frame


func _finish_conversation(main: Node, keyboard: Node) -> void:
	for turn in range(8):
		_finish_turn(main, keyboard)
		if not main.game.conversation_can_continue:
			return
		_advance_reply(main)


func _finish_turn(main: Node, keyboard: Node) -> void:
	for unit in range(500):
		if main.game.conversation_phase != "typing":
			return
		keyboard._input(_key(KEY_A, "a"))
	_check(false, "dialogue must finish within its authored unit count")


func _key(code: Key, character: String = "", repeated: bool = false, shortcut: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.unicode = character.unicode_at(0) if not character.is_empty() else 0
	event.pressed = true
	event.echo = repeated
	event.ctrl_pressed = shortcut
	return event


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
