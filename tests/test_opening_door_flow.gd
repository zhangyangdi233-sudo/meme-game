extends SceneTree

var failures: Array[String] = []
var main


func _init() -> void:
	root.visible = false
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1600, 900)
	main = load("res://scenes/babel_meme_game.tscn").instantiate()
	root.add_child(main)
	main._save_path = "user://test_opening_door_flow.dat"
	main.start_chapter1_game()
	main.set_process(false)
	main.set_physics_process(false)
	await process_frame
	await process_frame
	_press(KEY_ESCAPE)
	_check(main._settings_open, "Escape opens settings during the opening")
	_check(not main._reality_mouse_look_enabled, "settings releases the cursor")
	var return_button := main._settings_window.find_child("SettingsReturnMainButton", true, false) as Button
	var footer := main._settings_window.find_child("SettingsSystemFooter", true, false) as Control
	_check(footer.is_ancestor_of(return_button), "return to main menu stays in the always-visible system footer")
	_press(KEY_ESCAPE)
	_check(not main._settings_open and main._reality_mouse_look_enabled, "Escape closes settings and resumes mouse look")
	var world = main._reality_floor
	var knock := world.get_node_or_null("OpeningDoorKnock") as AudioStreamPlayer3D
	_check(knock != null and knock.stream != null, "opening binds the licensed positional knock recording")
	if knock == null or knock.stream == null:
		_finish()
		return
	var door = world.get_door("opening")
	main._reality_player.position = world.anchor_world_position("DoorArrival") + Vector3(0, 0.04, 1.0)
	main._animate_world(9.9)
	_check(not knock.playing, "knocking cannot begin before ten active seconds")
	_press(KEY_F)
	await process_frame
	_check(main.game.chapter1_progress.phase == "opening" and not door.is_passable(), "F cannot open the door before the knock")
	_press(KEY_ESCAPE)
	main._animate_world(30.0)
	_check(not knock.playing, "settings pauses the ten-second opening wait")
	_press(KEY_ESCAPE)
	main._animate_world(0.1)
	_check(knock.playing, "the door knocks at ten active seconds")
	_check(knock.global_position.distance_to(world.anchor_world_position("DoorArrival")) < 3.0, "the sound comes from the door")
	_press(KEY_F)
	_check(not door.is_passable(), "the whole knock plays before opening becomes available")
	_press(KEY_ESCAPE)
	for frame in 4:
		await physics_frame
	_check(knock.stream_paused, "settings pauses the in-progress knock")
	var paused_position := knock.get_playback_position()
	await create_timer(0.15).timeout
	_check(absf(knock.get_playback_position() - paused_position) < 0.05, "paused settings does not consume the knock audio")
	_press(KEY_ESCAPE)
	_check(not knock.stream_paused, "leaving settings resumes the knock")
	await create_timer(knock.stream.get_length() + 0.5).timeout
	_check(main.game.chapter1_progress.get("opening_knock_completed", false), "actual audio completion unlocks the interaction")
	_check(not main.game.chapter1_progress.narrator_completed, "the opening no longer requires fabricated narration completion")
	_check(not door.is_passable(), "finishing the knock does not automatically open the door")
	main._refresh_nearby_reality_actor()
	_check(main._world_prompt.text.contains("F"), "the ready door exposes its F interaction hint")
	main._save_progress()
	_check(main.continue_game(), "the opening can be continued after the knock")
	await process_frame
	await process_frame
	world = main._reality_floor
	knock = world.get_node("OpeningDoorKnock")
	main._reality_player.position = world.start_position()
	main._animate_world(20.0)
	_check(not knock.playing, "continuing a completed knock does not replay it")
	_press(KEY_F)
	await process_frame
	_check(main.game.chapter1_progress.phase == "opening", "F from far away cannot open the door")
	main._reality_player.position = world.anchor_world_position("DoorArrival") + Vector3(0, 0.04, 1.0)
	_press(KEY_F)
	await process_frame
	_check(main._input_locked, "opening the door locks movement for the close-up animation")
	var portal_light := world.imported_root.find_child("OpeningDoor_LightPlane", true, false) as Node3D
	_check(portal_light != null and not portal_light.visible, "opening the door reveals darkness instead of an opaque white plane over the moving leaf")
	_press(KEY_F)
	await create_timer(3.3).timeout
	_check(main.game.chapter1_progress.phase == "basement", "opening the door enters the basement without walking across a threshold")
	_check(main._reality_player.position.distance_to(main._reality_floor.start_position()) < 0.1, "the player arrives at the authored basement spawn")
	_check(not main._input_locked, "the basement becomes controllable after the fade")
	_press(KEY_ESCAPE)
	_check(main._settings_open, "Escape also opens settings in the basement")
	await process_frame
	return_button = main._settings_window.find_child("SettingsReturnMainButton", true, false)
	_click(return_button.get_global_rect().get_center())
	await process_frame
	await process_frame
	_check(not main._game_started, "the settings footer returns to the main menu")
	# Leaving halfway through a new door animation must cancel its room callback.
	main.start_chapter1_game()
	main.notify_chapter1("opening_knock_completed", {"sequence_id": "chapter1_opening"})
	main._reality_player.position = main._reality_floor.anchor_world_position("DoorArrival") + Vector3(0, 0.04, 1.0)
	_press(KEY_F)
	await process_frame
	await create_timer(0.5).timeout
	_press(KEY_ESCAPE)
	_check(main._settings_open, "Escape remains available while the door animation locks gameplay")
	await process_frame
	return_button = main._settings_window.find_child("SettingsReturnMainButton", true, false)
	_click(return_button.get_global_rect().get_center())
	await process_frame
	await create_timer(3.0).timeout
	_check(not main._game_started, "a canceled door animation cannot leave the main menu")
	_check(not main._input_locked, "returning to the menu clears cinematic input locks")
	_finish()


func _press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)


func _click(position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.global_position = position
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)


func _finish() -> void:
	main._set_reality_mouse_look(false)
	main.free()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("opening door flow tests passed")
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
