extends SceneTree

const OUTPUT := "D:/aphasia/outputs/opening_door_audit"
var viewport: SubViewport
var main


func _init() -> void:
	root.visible = false
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Door captures require a renderer")
		quit(1)
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._save_path = OUTPUT.path_join("capture_save.dat")
	viewport.add_child(main)
	main._locale.set_locale("zh")
	main.start_chapter1_game()
	# This is a rendering fixture; the integration test verifies the actual wait
	# and audio completion before this event may occur in a normal game.
	main.notify_chapter1("opening_knock_completed", {"sequence_id": "chapter1_opening"})
	main._reality_player.position = main._reality_floor.anchor_world_position("DoorArrival") + Vector3(0, 0.04, 1.5)
	await create_timer(0.7).timeout
	await _capture("01_ready")
	var key := InputEventKey.new()
	key.keycode = KEY_F
	key.physical_keycode = KEY_F
	key.pressed = true
	viewport.push_input(key, true)
	await process_frame
	await process_frame
	if not is_instance_valid(main._chapter_door_transition):
		push_error("Door interaction did not start the transition")
		quit(1)
		return
	main._chapter_door_transition.room_requested.connect(_capture_black)
	await create_timer(0.5).timeout
	await _capture("02_closeup")
	await create_timer(0.75).timeout
	await _capture("03_opening")
	await create_timer(1.8).timeout
	await _capture("05_basement")
	key = InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	viewport.push_input(key, true)
	await create_timer(0.25).timeout
	await _capture("06_settings")
	print("door transition captures saved to ", OUTPUT)
	main._set_reality_mouse_look(false)
	main.queue_free()
	await process_frame
	quit()


func _capture_black() -> void:
	await _capture("04_black")


func _capture(label: String) -> void:
	await process_frame
	RenderingServer.force_draw()
	var frame := viewport.get_texture().get_image()
	var path := OUTPUT.path_join("door_%s.png" % label)
	var result := frame.save_png(path)
	if result != OK:
		push_error("Could not save %s: %s" % [path, result])
