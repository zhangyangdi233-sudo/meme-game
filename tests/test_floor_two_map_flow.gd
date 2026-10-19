extends SceneTree

const State = preload("res://scripts/meme_game_state.gd")
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	root.visible = false
	_run.call_deferred()

func _run() -> void:
	var state = State.new()
	state.new_run()
	_check(not state.is_phone_app_unlocked("map"), "new games start without the map app")
	_check(State.SAVE_FIELD_NAMES.has("floor_two_progress"), "route quest is persisted independently of chapter one")
	_check(State.SAVE_FIELD_NAMES.has("exploration_maps"), "explored map cells have a save field")
	state.tower_floor = 2
	state.pollution = 100
	state.pending_floor_transition = 3
	state.settle_day_if_needed()
	_check(state.tower_floor == 2, "pollution and stale pending transitions cannot bypass the maze")
	_check(load("res://scripts/progression/floor_two_journey.gd").has_method("complete_map_intro"), "map reward has a presentation-completion entry point")
	_check(state.has_method("visit_floor_two_turn"), "walking can still record optional route turns")
	_check(state.has_method("try_exit_floor_two"), "the second floor has a physical exit gate")
	if not state.has_method("finish_floor_two_dialogue"):
		_finish()
		return
	state.new_run()
	state.tower_floor = 2
	_check(not state.try_exit_floor_two(), "a fresh arrival cannot exit before obtaining the map")
	_check(not state.can_use_app("map", "terminal"), "basement CRT does not gain a map app")
	var main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._save_path = "user://test_floor_two_map_flow.dat"
	main._locale.preferences_path = "user://test_floor_two_map_flow.cfg"
	main._locale.save_preferences(80, false, false, "computer")
	root.add_child(main)
	main._resolve_camera_consent(false)
	main._locale.set_locale("zh")
	state.set_view_state("npc_up")
	main._begin_game_session(state, {}, false)
	await _frames()
	_check(main._reality_floor.built_floor == 2, "actual game session builds the new second floor")
	_check(not main._road.visible, "old RoadTile geometry is absent from the residential maze")
	var layout: Dictionary = main._reality_floor.get_floor_two_map_layout()
	_check(not layout.is_empty(), "rendered level exposes its shared layout")
	if not await _exercise_arrival(main):
		main.free()
		_finish()
		return
	await _exercise_note(main)
	main.set_view_state("npc_up")
	# Held movement keys must never travel or reveal streets behind a modal.
	for overlay in ["connection", "prologue"]:
		if overlay == "connection":
			main._show_phone_camera_connection_overlay()
		else:
			main._prologue_overlay.show()
		var paused_position: Vector3 = main._reality_player.position
		var paused_exploration: PackedByteArray = main._floor_two_map_snapshot().explored.duplicate()
		Input.action_press("reality_forward")
		for frame in 30:
			await physics_frame
		Input.action_release("reality_forward")
		_check(main._reality_player.position.is_equal_approx(paused_position), "%s blocks actual player physics movement" % overlay)
		_check(main._floor_two_map_snapshot().explored == paused_exploration, "%s pauses map discovery" % overlay)
		var paused_yaw: float = main._reality_yaw
		var pan := InputEventPanGesture.new()
		pan.delta = Vector2(8, 0)
		main._input(pan)
		_check(is_equal_approx(main._reality_yaw, paused_yaw), "%s blocks trackpad look" % overlay)
		var tab := InputEventKey.new()
		tab.keycode = KEY_TAB
		tab.pressed = true
		main._unhandled_input(tab)
		_check(main.game.view_state == "npc_up", "%s blocks phone toggle behind the overlay" % overlay)
		main._reality_player.position = layout.exit_position + Vector3(0, 0, 1.0)
		main._refresh_nearby_reality_actor()
		_check(not main._try_reality_interaction(), "%s blocks the actual nearby exit interaction" % overlay)
		main._reality_player.position = layout.turn_points[0]
		main._update_floor_two_exploration(2.1)
		_check(main._floor_two_map_snapshot().explored == paused_exploration, "%s cannot discover a displaced player position" % overlay)
		main._reality_player.position = paused_position
		if overlay == "connection":
			main._hide_phone_camera_connection_overlay()
		else:
			main._prologue_overlay.hide()
	_check(main._reality_floor.find_child("CoverWatcherEvent", true, false) == null, "retired watcher visual is absent")
	_check(not main.game.floor_two_progress.accepted and main.game.is_phone_app_unlocked("map"), "arrival grants the map without removed NPCs or acceptance history")
	main._open_phone_launcher()
	main._on_app_pressed("map")
	await _frames()
	_check(main.game.active_app_window == "map" and main._app_windows.map.visible, "awarded map opens inside the phone")
	_check(main._phone_map_page != null, "map page is embedded in the phone window")
	_check(main._app_windows.map.find_children("*", "ScrollContainer", true, false).is_empty(), "phone map fits without scroll controls")
	var before: Dictionary = main.game.exploration_maps.duplicate(true)
	var position_before: Vector3 = main._reality_player.position
	_check(not before.is_empty(), "walked cells are recorded in game state")
	_check(main._save_progress(), "route and map save through normal save path")
	main.continue_game()
	await _frames()
	_check(main.game.is_phone_app_unlocked("map"), "Continue preserves map reward")
	if main.game.exploration_maps != before:
		var previous: PackedByteArray = before.floor_2.explored
		var restored: PackedByteArray = main.game.exploration_maps.floor_2.explored
		var lost := 0
		var added := 0
		for index in mini(previous.size(), restored.size()):
			lost += 1 if previous[index] == 1 and restored[index] == 0 else 0
			added += 1 if previous[index] == 0 and restored[index] == 1 else 0
		print("MAP RESTORE: lost=%d added=%d position=%s -> %s" % [lost, added, position_before, main._reality_player.position])
	_check(main.game.exploration_maps == before, "Continue preserves the visited cells")
	_check(main.game.floor_two_progress.map_intro_completed and not main.game.floor_two_progress.accepted, "Continue retains the completed map introduction without NPC history")
	_check(not main.game.try_exit_floor_two(), "map ownership alone cannot bypass the Xray discoveries")
	# Spatial hand-frame evidence is covered by test_floor_two_phone_xray_flow;
	# this flow verifies that the resulting ordered discoveries reach the F gate.
	var journey = load("res://scripts/progression/floor_two_journey.gd")
	for id in journey.XRAY_OBSERVATION_IDS:
		main.game.floor_two_progress = journey.record_xray_observation(main.game.floor_two_progress, id)
	main.set_view_state("npc_up")
	main._reality_player.position = layout.exit_position + Vector3(0, 0, 1.0)
	main._refresh_nearby_reality_actor()
	_check(main._try_reality_interaction(), "F at the physical exit is handled")
	await _frames()
	_check(main.game.tower_floor == 3, "only the physical exit advances to the third floor")
	_check(main.game.is_phone_app_unlocked("map"), "the acquired app stays installed after leaving")
	_check(main._load_save_payload().game.state.tower_floor == 3, "physical exit persists the destination")
	var floor_two_exploration: Dictionary = main.game.exploration_maps.duplicate(true)
	main.continue_game()
	await _frames()
	_check(main.game.tower_floor == 3 and main.game.is_phone_app_unlocked("map"), "Continue on floor three retains the map app")
	main._open_phone_launcher()
	main._on_app_pressed("map")
	await _frames()
	_check(not bool(main._floor_two_map_snapshot().active), "map outside floor two shows the saved streets without a false live position")
	_check(main.game.exploration_maps == floor_two_exploration, "opening archived streets on another floor preserves discovery")
	main.new_game()
	await _frames()
	_check(not main.game.is_phone_app_unlocked("map") and main.game.exploration_maps.is_empty(), "new game resets app permissions and map exploration")
	var accepted_legacy = State.new()
	accepted_legacy.load_save_data({"version": 5, "state": {"tower_floor": 2, "floor_two_progress": {"accepted": true}, "view_state": "npc_up"}})
	main._begin_game_session(accepted_legacy, {}, false)
	await _frames()
	_check(main.game.is_phone_app_unlocked("map") and not main._floor_two_map_unlock_active() and not main._day_transition_overlay.visible, "accepted legacy saves keep their map without replaying title or unlock")
	main._set_reality_mouse_look(false)
	main.free()
	await _frames()
	var legacy = State.new()
	_check(legacy.load_save_data({"version": 5, "state": {"tower_floor": 2}}), "old second-floor saves still load")
	_check(not legacy.is_phone_app_unlocked("map"), "old saves do not silently unlock the new app")
	_finish()

func _exercise_arrival(main) -> bool:
	_check(main._day_transition_overlay.visible and not main.game.is_phone_app_unlocked("map"), "fresh arrival plays the floor title before granting access")
	_check(not main._open_floor_two_note() and not main._floor_two_note_active(), "the visible floor title cannot be interrupted by opening the note")
	var phone_tab: Button = main._phone_panel.tab
	_check(is_instance_valid(phone_tab) and phone_tab.visible and phone_tab.get_global_rect().has_area(), "the arrival test targets the actual visible phone edge button")
	_click(phone_tab.get_global_rect().get_center())
	await _frames()
	_check(main._day_transition_overlay.visible and main.game.view_state == "npc_up" and main.game.active_app_window.is_empty() and not main._phone_panel._open and main._phone_panel._slide_fraction < 0.01, "a real GUI click on the phone edge cannot interrupt the floor title or slide the phone out early")
	if not await _wait_for(func(): return main._floor_two_map_unlock_active(), 5.0, "real frames finish the title and start the phone introduction"):
		return false
	var map_icon: Button = main._phone_panel.app_buttons.map
	_check(map_icon.visible and map_icon.disabled and float(map_icon.get_meta("unlock_brightness")) < 0.05, "phone initially presents a visible gray disabled map icon")
	_check(not main._day_transition_overlay.visible and main.game.view_state == "phone_down", "the title is gone before the phone slides out")
	_check(not main._open_floor_two_note() and not main._floor_two_note_active(), "map unlock rejects the note until its presentation finishes")
	main._on_app_pressed("map")
	_check(main.game.active_app_window != "map", "gray map cannot be opened through callbacks")
	var locked_position: Vector3 = main._reality_player.position
	var locked_camera: Transform3D = main._camera.global_transform
	var locked_exploration: PackedByteArray = main._floor_two_map_snapshot().explored.duplicate()
	Input.action_press("reality_forward")
	for frame in 12:
		await physics_frame
	Input.action_release("reality_forward")
	_key(KEY_TAB)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(80, 25)
	Input.parse_input_event(motion)
	await _frames()
	_check(main._reality_player.position.is_equal_approx(locked_position) and main._camera.global_transform.is_equal_approx(locked_camera), "unlock freezes real movement and camera input")
	_check(main.game.view_state == "phone_down" and main._floor_two_map_unlock_active(), "Tab cannot close the phone during its introduction")
	_check(main._floor_two_map_snapshot().explored == locked_exploration, "frozen presentation does not reveal map cells")
	_key(KEY_ESCAPE)
	await _frames()
	_check(main._settings_open, "actual Esc opens settings during map introduction")
	_check(not main._floor_two_unlock_shield.visible, "settings immediately hide the unlock input shield so its controls remain usable")
	var brightness: float = map_icon.get_meta("unlock_brightness")
	var slide: float = main._phone_panel._slide_fraction
	await create_timer(0.45).timeout
	_check(is_equal_approx(float(map_icon.get_meta("unlock_brightness")), brightness) and is_equal_approx(main._phone_panel._slide_fraction, slide), "settings pause both map brightness and the phone slide")
	_key(KEY_ESCAPE)
	await _frames()
	_check(not main._settings_open, "Esc closes settings without dismissing the introduction")
	main._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	brightness = map_icon.get_meta("unlock_brightness")
	await create_timer(0.25).timeout
	_check(is_equal_approx(float(map_icon.get_meta("unlock_brightness")), brightness) and main._floor_two_map_unlock_active(), "application focus loss pauses the introduction without rewarding it")
	main._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	if not await _wait_for(func(): return float(map_icon.get_meta("unlock_brightness")) > 0.1 and float(map_icon.get_meta("unlock_brightness")) < 0.95, 2.0, "real frames visibly brighten the still-disabled icon"):
		return false
	_check(map_icon.disabled and not main.game.is_phone_app_unlocked("map"), "partial animation cannot grant app permission")
	_check(main._save_progress(), "an interrupted introduction can be saved")
	main.show_main_menu()
	await _frames()
	_check(not main._floor_two_map_unlock_active(), "leaving the session cancels the presentation")
	_check(main.continue_game(), "Continue loads an interrupted introduction")
	await _frames()
	_check(not main.game.is_phone_app_unlocked("map") and main._day_transition_overlay.visible, "Continue replays the title while the unfinished map stays locked")
	_check(main.game.view_state == "npc_up" and main.game.active_app_window.is_empty() and not main._phone_panel._open and main._phone_panel._slide_fraction < 0.01, "an interrupted phone save is restored closed until the replayed title ends")
	if not await _wait_for(func(): return main._floor_two_map_unlock_active(), 5.0, "interrupted introduction safely starts again after its title"):
		return false
	if not await _wait_for(func(): return main.game.is_phone_app_unlocked("map"), 3.5, "real unpaused frames complete and grant the map"):
		return false
	_check(not main._floor_two_map_unlock_active() and not main._phone_panel.app_buttons.map.disabled, "completion releases input and enables the icon")
	_check(main.game.view_state == "phone_down" and main.game.active_app_window.is_empty() and main._phone_launcher_open, "completion leaves the phone open on its homepage")
	_check(bool(main._load_save_payload().game.state.floor_two_progress.map_intro_completed), "completion immediately saves its one-time reward")
	_check(main._cover_watcher_stinger.get_meta("generated_audio_path", "") == main.FLOOR_TWO_WHISPER_PATH, "new second floor plays the familiar whisper without a watcher model after arrival input is released")
	var layout: Dictionary = main._reality_floor.get_floor_two_map_layout()
	var route: Array = layout.primary_route
	var direction: Vector3 = (route[1] - route[0]).normalized()
	main._reality_player.position = route[0]
	main._reality_yaw = rad_to_deg(atan2(-direction.x, -direction.z))
	var before: Vector3 = main._reality_player.position
	Input.action_press("reality_forward")
	for frame in 18:
		await physics_frame
	Input.action_release("reality_forward")
	_check(Vector2(main._reality_player.position.x, main._reality_player.position.z).distance_to(Vector2(before.x, before.z)) > 0.2, "actual walking resumes while the unlocked phone stays open")
	_click(main._phone_panel.tab.get_global_rect().get_center())
	await _frames()
	_check(main.game.view_state == "npc_up" and not main._phone_panel._open, "the same real GUI click closes the phone once the introduction releases input")
	_click(main._phone_panel.tab.get_global_rect().get_center())
	await _frames()
	_check(main.game.view_state == "phone_down" and main._phone_panel._open, "the edge button can reopen the phone after the introduction")
	return true

func _exercise_note(main) -> void:
	main.set_view_state("npc_up")
	var note := main._reality_floor.find_child("FloorTwoNote", true, false) as Area3D
	_check(note != null and note.visible, "the unread note exists as a physical object")
	if note == null:
		return
	main._reality_player.position = main._reality_floor.clamp_to_playable_position(note.position + Vector3(0, 0, 0.65), 0.45)
	main._reality_player.velocity = Vector3.ZERO
	main._refresh_nearby_reality_actor()
	_key(KEY_F)
	await _frames()
	_check(main._floor_two_note_active() and not note.visible and note.collision_layer == 0, "real F opens the nearby paper and hides its world duplicate")
	if not main._floor_two_note_active():
		return
	_key(KEY_F10)
	await _frames()
	_check(main._settings_open and main._floor_two_note_active() and not main._floor_two_note_view.visible and not main.game.floor_two_progress.note_read, "F10 settings temporarily hide the active paper without reading or dismissing it")
	_key(KEY_F10)
	await _frames()
	_check(not main._settings_open and main._floor_two_note_active() and main._floor_two_note_view.visible and not main.game.floor_two_progress.note_read, "closing settings restores the same unread paper")
	var position: Vector3 = main._reality_player.position
	var explored: PackedByteArray = main._floor_two_map_snapshot().explored.duplicate()
	Input.action_press("reality_forward")
	for frame in 12:
		await physics_frame
	Input.action_release("reality_forward")
	_key(KEY_TAB)
	await _frames()
	_check(main._reality_player.position.is_equal_approx(position) and main._floor_two_map_snapshot().explored == explored and main.game.view_state == "npc_up", "reading the note blocks locomotion, fog exploration and Tab")
	_key(KEY_ENTER)
	await _frames()
	_check(not main._floor_two_note_active() and main.game.floor_two_progress.note_read and not note.visible and note.collision_layer == 0, "actual Enter closes the paper and permanently removes the world copy")
	_check(bool(main._load_save_payload().game.state.floor_two_progress.note_read), "closing the paper saves its read state immediately")
	_check(main.continue_game(), "Continue reloads the already-read note")
	await _frames()
	note = main._reality_floor.find_child("FloorTwoNote", true, false) as Area3D
	_check(main.game.floor_two_progress.note_read and note != null and not note.visible and note.collision_layer == 0, "the read paper stays absent after Continue")
	_check(not main._floor_two_note_active() and not main._floor_two_map_unlock_active(), "Continue cannot leave a note overlay or repeat a completed introduction")

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)

func _click(position: Vector2) -> void:
	# The fixture uses Control viewport coordinates; push_input(true) keeps
	# those coordinates unchanged through the real _input -> GUI dispatch.
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	var release := event.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release, true)

func _wait_for(predicate: Callable, timeout: float, message: String) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	var complete := bool(predicate.call())
	_check(complete, message)
	return complete

func _frames() -> void:
	for i in 4:
		await process_frame

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _finish() -> void:
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("floor two map flow tests passed (%d checks)" % checks)
	quit(0 if failures.is_empty() else 1)
