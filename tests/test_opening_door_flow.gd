extends SceneTree

var failures: Array[String] = []
var main


func _init() -> void:
	root.visible = false
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1600, 900)
	main = load("res://scenes/babel_meme_game.tscn").instantiate()
	# Both preferences and progress are redirected BEFORE _ready touches them.
	var test_stem := "user://aphasia-opening-flow-%d" % OS.get_process_id()
	main._save_path = test_stem + ".dat"
	main._locale.preferences_path = test_stem + ".cfg"
	main._locale.select_language("zh")
	main._locale.save_preferences(50.0, false, false, "computer")
	root.add_child(main)
	main.start_chapter1_game()
	main.set_process(false)
	main.set_physics_process(false)
	await process_frame
	await process_frame
	var world = main._reality_floor
	var knock := world.get_node_or_null("OpeningDoorKnock") as AudioStreamPlayer3D
	_check(knock != null and knock.stream != null, "opening binds the licensed positional knock recording")
	if knock == null or knock.stream == null:
		_finish()
		return
	_check(not main._chapter_opening_narration.visible, "the opening begins with two seconds of black before narration")
	_click(Vector2(800, 800))
	_check(_line() == 1, "a click during the black opening cannot skip line one")
	main._animate_world(1.9)
	_check(not main._chapter_opening_narration.visible, "line one stays hidden before two active seconds")
	_press(KEY_ESCAPE)
	_check(main._settings_open, "Escape opens settings during the opening")
	_check(not main._reality_mouse_look_enabled, "settings releases the cursor")
	var return_button := main._settings_window.find_child("SettingsReturnMainButton", true, false) as Button
	var footer := main._settings_window.find_child("SettingsSystemFooter", true, false) as Control
	_check(footer.is_ancestor_of(return_button), "return to main menu stays in the always-visible system footer")
	main._animate_world(30.0)
	_check(not main._advance_chapter_opening_narration(), "settings cannot advance narration")
	_check(not knock.playing and not world.is_opening_narration_ready(), "settings pauses the black opening")
	_press(KEY_ESCAPE)
	_check(not main._settings_open and not main._reality_mouse_look_enabled, "closing settings resumes narration without capturing the cursor")
	main._animate_world(0.11)
	_check(main._chapter_opening_narration.visible and _line() == 1, "line one appears after two active seconds")
	_check(not main._chapter_opening_narration.line_label.text.is_empty(), "the first line contains the authored narration")
	main._animate_world(90.0)
	_check(_line() == 1 and not knock.playing, "narration never auto-advances and elapsed time alone never starts the knock")

	var yaw: float = main._reality_yaw
	var pitch: float = main._reality_pitch
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(200, 120)
	root.push_input(motion, true)
	var pan := InputEventPanGesture.new()
	pan.delta = Vector2(3, 4)
	root.push_input(pan, true)
	_mouse(MOUSE_BUTTON_WHEEL_DOWN, true)
	_press(KEY_SPACE)
	_press(KEY_TAB)
	_press(KEY_F)
	_check(_line() == 1 and main.game.view_state == "npc_up", "wheel, keys, phone and interaction cannot advance narration")
	_check(is_equal_approx(main._reality_yaw, yaw) and is_equal_approx(main._reality_pitch, pitch), "narration blocks mouse and trackpad camera turning")
	var position: Vector3 = main._reality_player.position
	Input.action_press("reality_forward")
	main._update_reality_player(0.25)
	Input.action_release("reality_forward")
	_check(main._reality_player.position == position, "narration blocks movement while its world clock keeps running")
	_mouse(MOUSE_BUTTON_LEFT, true)
	_check(_line() == 2, "one physical mouse press advances one sentence")
	_mouse(MOUSE_BUTTON_LEFT, true)
	_check(_line() == 2, "repeated press events while held do not advance twice")
	_mouse(MOUSE_BUTTON_LEFT, false)
	_check(_line() == 2, "mouse release cannot advance narration")
	_touch(true, 0)
	_check(_line() == 3, "native touch advances one sentence")
	_mouse(MOUSE_BUTTON_LEFT, true, -1)
	_mouse(MOUSE_BUTTON_LEFT, false, -1)
	_touch(true, 1)
	_check(_line() == 3, "emulated mouse and a second finger cannot duplicate a touch advance")
	_touch(false, 1)
	_touch(false, 0)
	main._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_click(Vector2(800, 800))
	main._animate_world(20.0)
	_check(_line() == 3 and not main._reality_mouse_look_enabled, "unfocused input cannot advance or capture the pointer")
	main._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	main._input_locked = true
	_click(Vector2(800, 800))
	_check(_line() == 3, "cinematic locks cannot advance narration")
	main._input_locked = false
	for sentence in 7:
		_click(Vector2(800, 800))
	main._save_progress()
	_check(main.continue_game(), "narration can be saved and continued")
	await process_frame
	await process_frame
	world = main._reality_floor
	knock = world.get_node("OpeningDoorKnock")
	main._animate_world(2.01)
	_check(_line() == 10 and main._chapter_opening_narration.line_number == 10, "continue restores the exact current sentence")
	main._locale.select_language("ja")
	main._refresh_localized_ui()
	var translated: String = main._chapter_opening_narration.line_label.text
	main._locale.select_language("zh")
	main._refresh_localized_ui()
	_check(translated != main._chapter_opening_narration.line_label.text and not translated.is_empty(), "opening narration follows Chinese and Japanese language selection")
	for sentence in 16:
		_click(Vector2(800, 800))
	main._animate_world(120.0)
	_check(not knock.playing, "no knock occurs anywhere before sentence 28")
	_click(Vector2(800, 800))
	await physics_frame
	_check(_line() == 28 and main._chapter_opening_narration.line_number == 28, "sentence 26 advances directly to 28, skipping the sound-stage instruction")
	_check(knock.playing, "the knock starts when sentence 28 appears")
	_check(knock.global_position.distance_to(world.anchor_world_position("DoorArrival")) < 3.0, "the sound comes from the door")
	var door = world.get_door("opening")
	main._reality_player.position = world.anchor_world_position("DoorArrival") + Vector3(0, 0.04, 1.0)
	_press(KEY_F)
	_check(not door.is_passable(), "narration and audio must finish before the door can open")
	_press(KEY_ESCAPE)
	for frame in 4:
		await physics_frame
		await process_frame
	_check(knock.stream_paused, "settings pauses the in-progress knock")
	_check(not main._chapter_opening_narration.visible, "settings hides the narration beneath its controls")
	var paused_position := knock.get_playback_position()
	await create_timer(0.15).timeout
	_check(absf(knock.get_playback_position() - paused_position) < 0.05, "paused settings does not consume the knock audio")
	_press(KEY_ESCAPE)
	_check(not knock.stream_paused, "leaving settings resumes the knock")
	_check(main._chapter_opening_narration.visible and _line() == 28, "leaving settings retains the current sentence")
	await create_timer(knock.stream.get_length() + 0.5).timeout
	_check(main.game.chapter1_progress.get("opening_knock_completed", false), "actual audio completion is saved")
	_check(not main.game.chapter1_progress.narrator_completed, "audio completion alone does not complete narration")
	_press(KEY_F)
	_check(not door.is_passable(), "a completed knock cannot bypass the remaining narration")
	_click(Vector2(800, 800))
	_check(_line() == 29, "sentence 29 follows sentence 28")
	_click(Vector2(800, 800))
	_check(_line() == 30 and not main.game.chapter1_progress.narrator_completed, "sentence 30 remains visible until the player advances")
	_touch(true, 0)
	_mouse(MOUSE_BUTTON_LEFT, true, -1)
	_touch(false, 0)
	_mouse(MOUSE_BUTTON_LEFT, false, -1)
	_check(main.game.chapter1_progress.narrator_completed and not main._chapter_opening_narration.visible, "a final click completes and hides narration")
	_check(not main._reality_mouse_look_enabled and not main._input_locked and not door.is_passable(), "the final pointer gesture cannot capture the cursor or open the door")
	main._refresh_nearby_reality_actor()
	_check(main._world_prompt.text.contains("F"), "the ready door exposes its F interaction hint")
	main._save_progress()
	_check(main.continue_game(), "the opening can be continued after narration and knock")
	await process_frame
	await process_frame
	world = main._reality_floor
	knock = world.get_node("OpeningDoorKnock")
	main._reality_player.position = world.start_position()
	main._animate_world(20.0)
	_check(not knock.playing and not main._chapter_opening_narration.visible, "continuing a completed opening does not replay its narration or knock")
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
	main._animate_world(2.01)
	for sentence in 29:
		main._advance_chapter_opening_narration()
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


func _line() -> int:
	return int(main.game.chapter1_progress.get("opening_line_number", 1))


func _press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)


func _mouse(button: MouseButton, pressed: bool, device: int = 0, position: Vector2 = Vector2(800, 800)) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = position
	event.global_position = position
	event.pressed = pressed
	event.device = device
	root.push_input(event, true)


func _click(position: Vector2) -> void:
	_mouse(MOUSE_BUTTON_LEFT, true, 0, position)
	_mouse(MOUSE_BUTTON_LEFT, false, 0, position)


func _touch(pressed: bool, index: int) -> void:
	var event := InputEventScreenTouch.new()
	event.pressed = pressed
	event.index = index
	event.position = Vector2(800, 800)
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
