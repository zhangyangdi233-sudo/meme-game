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
	_check(state.has_method("finish_floor_two_dialogue"), "quest reward has an actual dialogue completion entry point")
	_check(state.has_method("visit_floor_two_turn"), "walking through mandatory turns updates the quest")
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
		for actor: Area3D in main._reality_floor.get_interactable_actors():
			if str(actor.get_meta("actor_id", "")) == "floor2_wayfinder":
				main._reality_player.position = main._reality_floor.clamp_to_playable_position(actor.position + Vector3(0, 0, 1), 0.45)
		_check(not main._try_reality_interaction(), "%s blocks an actual nearby NPC interaction" % overlay)
		main._reality_player.position = layout.turn_points[0]
		main._update_floor_two_exploration(2.1)
		_check(main._floor_two_map_snapshot().explored == paused_exploration, "%s cannot discover a displaced player position" % overlay)
		main._reality_player.position = paused_position
		if overlay == "connection":
			main._hide_phone_camera_connection_overlay()
		else:
			main._prologue_overlay.hide()
	var map_icon: Button = main._phone_panel.app_buttons.get("map")
	_check(map_icon != null and map_icon.visible and map_icon.disabled, "second floor shows a locked map icon")
	main._on_app_pressed("map")
	_check(main.game.active_app_window != "map", "locked map cannot be opened through callbacks")
	_check(main._cover_watcher_stinger.get_meta("generated_audio_path", "") == main.FLOOR_TWO_WHISPER_PATH, "new second floor plays the familiar whisper without a watcher model")
	_check(main._reality_floor.find_child("CoverWatcherEvent", true, false) == null, "retired watcher visual is absent")
	# Speaking to the cartographer before accepting the task never awards an app.
	await _speak(main, "floor2_cartographer")
	_check(not main.game.is_phone_app_unlocked("map"), "early cartographer dialogue does not unlock the map")
	await _speak(main, "floor2_wayfinder")
	_check(bool(main.game.floor_two_progress.get("accepted", false)), "completed keyboard dialogue records the first NPC conversation")
	_check(main.game.floor_two_progress.visited_turn_ids.is_empty(), "map reward does not require reaching either old checkpoint")
	_check(main.game.is_phone_app_unlocked("map"), "first wayfinder dialogue immediately awards the map")
	_check(not map_icon.disabled, "reward immediately enables the phone icon")
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
	_check(main.game.floor_two_progress.accepted and main.game.floor_two_progress.visited_turn_ids.is_empty(), "Continue retains the map with only the first NPC completed")
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
	main._set_reality_mouse_look(false)
	main.free()
	await _frames()
	var legacy = State.new()
	_check(legacy.load_save_data({"version": 5, "state": {"tower_floor": 2}}), "old second-floor saves still load")
	_check(not legacy.is_phone_app_unlocked("map"), "old saves do not silently unlock the new app")
	_finish()

func _speak(main, actor_id: String) -> void:
	main.set_view_state("npc_up")
	var actor: Area3D
	for candidate: Area3D in main._reality_floor.get_interactable_actors():
		if str(candidate.get_meta("actor_id", "")) == actor_id:
			actor = candidate
	_check(actor != null, "%s exists as an actual NPC" % actor_id)
	if actor == null:
		return
	main._reality_player.position = main._reality_floor.clamp_to_playable_position(actor.position + Vector3(0, 0, 1), 0.45)
	main._refresh_nearby_reality_actor()
	_check(main._try_reality_interaction(), "%s starts via F interaction" % actor_id)
	_check(main.game.conversation_phase == "typing", "NPC retains the protagonist keyboard mechanism")
	var guard := 0
	while main.game.conversation_phase == "typing" and guard < 400:
		main._advance_typed_reality_character()
		guard += 1
	_check(main.game.conversation_phase == "result", "typed reply reaches the automatic response phase")
	main._update_reality_dialogue(120.0)
	await _frames()
	_check(main._reality_interaction_active and main._reality_end_button.visible, "the final reply waits at the End button")
	main._reality_end_button.pressed.emit()
	_check(not main._reality_interaction_active, "the End button immediately closes dialogue")

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
