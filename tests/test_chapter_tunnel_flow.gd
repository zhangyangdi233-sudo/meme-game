extends SceneTree
## Regression for the former tunnel route: each ordinary door now joins rooms.

const OUTPUT := "D:/aphasia/outputs/door_camera_revision"
var main
var viewport: SubViewport
var failures: Array[String] = []
var checks := 0
var swaps: Array[Dictionary] = []

func _init() -> void:
	root.visible = false
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._save_path = OUTPUT.path_join("door_flow_save.dat")
	viewport.add_child(main)
	main._resolve_camera_consent(false)
	main._locale.set_locale("zh")
	main.start_chapter1_game()
	main.set_process(false)
	main.set_physics_process(false)
	main.notify_chapter1("opening_knock_completed", {"sequence_id": "chapter1_opening"})
	main.notify_chapter1("opening_door_opened")
	for visit in 5:
		var token: int = main.game.chapter1_progress.transition_serial
		main.notify_chapter1("entrance_threshold_crossed", {"round_token": token})
		main.notify_chapter1("npc_help_completed", {"round_token": token, "npc_id": "basement_npc_%02d" % (visit + 1), "task_id": "basement_help_%02d" % (visit + 1)})
		var world = main._reality_floor
		var destination_pose: Transform3D
		var exit_pose: Transform3D = world.get("_exit_camera_pose")
		destination_pose = world.get("_destination_mapping") * exit_pose
		_check(world.get_node_or_null("BasementExitTunnel") == null, "visit has no detached tunnel")
		_check(world.get_node_or_null("NextBasementThroughDoor") != null, "ordinary exit reveals aligned next entrance")
		if visit == 2:
			main._reality_player.position = Vector3(1.45, 0.02, -3.3)
			main._camera.position = Vector3(1.45, 1.56, -3.3)
			main._camera.look_at(Vector3(-3.2, 1.1, -3.43))
			await _capture("03a_third_visit_corridor")
		_place_at_exit(world)
		if visit == 0:
			await _capture("01_ordinary_exit")
		_press(KEY_F)
		await process_frame
		_check(is_instance_valid(main._chapter_door_transition) and main._input_locked, "nearby F starts ordinary door animation")
		if not is_instance_valid(main._chapter_door_transition):
			break
		var transition: Node = main._chapter_door_transition
		_press(KEY_F)
		_check(main._chapter_door_transition == transition, "repeat F preserves one transition")
		transition.room_requested.connect(func():
			var overlay: ColorRect = main._ui_root.get_node("ChapterDoorTransitionOverlay")
			_check(is_zero_approx(overlay.color.a), "room change never flashes white or fades to black")
			swaps.append({"from_visit": visit + 1, "cover_alpha": overlay.color.a, "phase": main.game.chapter1_progress.phase})
		)
		if visit == 0:
			await create_timer(0.65).timeout
			var before: Vector3 = main._camera.global_position
			await create_timer(0.3).timeout
			_check(main._camera.global_position.distance_to(before) > 0.02, "camera advances during slow opening")
			await _capture("02_door_and_camera_opening")
			_press(KEY_ESCAPE)
			_check(main._settings_open, "Esc opens settings during door animation")
			var paused: Transform3D = main._camera.global_transform
			await create_timer(0.25).timeout
			_check(main._camera.global_transform.is_equal_approx(paused), "settings pauses camera motion")
			_press(KEY_ESCAPE)
			await create_timer(0.85).timeout
			await _capture("02b_inside_next_entrance")
			await create_timer(0.35).timeout
			await _capture("02c_before_room_replacement")
		if visit == 4:
			await create_timer(0.65).timeout
			await _capture("04a_door_aperture_only")
			await create_timer(0.85).timeout
			await _capture("04a_crossroads_visible_through_door")
			await create_timer(0.72).timeout
			await _capture("04b_crossroads_before_arrival")
		await _wait_unlocked(5.0)
		var expected := "crossroads" if visit == 4 else "basement"
		_check(main.game.chapter1_progress.phase == expected and main.game.chapter1_progress.transition_serial == token + 1, "door reaches correct next destination exactly once")
		_check(main._reality_player.position.distance_to(main._reality_floor.start_position()) < 0.01, "new destination uses entrance anchor")
		_check(main._camera.global_transform.is_equal_approx(destination_pose), "view through door ends at exactly the receiving camera pose")
		_check(not main._input_locked and not is_instance_valid(main._chapter_door_transition), "arrival releases input lock")
		if visit == 0 or visit == 4:
			await _capture("03_next_basement" if visit == 0 else "04_crossroads_arrival")
	main.start_chapter1_game()
	main.notify_chapter1("opening_knock_completed", {"sequence_id": "chapter1_opening"})
	main.notify_chapter1("opening_door_opened")
	var token: int = main.game.chapter1_progress.transition_serial
	main.notify_chapter1("entrance_threshold_crossed", {"round_token": token})
	main.notify_chapter1("npc_help_completed", {"round_token": token, "npc_id": "basement_npc_01", "task_id": "basement_help_01"})
	_place_at_exit(main._reality_floor)
	_press(KEY_F)
	await create_timer(0.5).timeout
	main.show_main_menu()
	await create_timer(2.8).timeout
	_check(not main._game_started and not main._input_locked, "returning to menu cancels pending door transfer")
	main._set_reality_mouse_look(false)
	main.free()
	await process_frame
	viewport.free()
	await process_frame
	var file := FileAccess.open(OUTPUT.path_join("door_flow_results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "swaps": swaps, "renderer": RenderingServer.get_current_rendering_method(), "display_server": DisplayServer.get_name()}, "\t"))
	for failure in failures:
		push_error(failure)
	print("chapter ordinary door flow: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _place_at_exit(world: Node3D) -> void:
	main._reality_player.position = world.anchor_world_position("ExitThreshold") + Vector3(1.0, 0, 0)
	main._camera.position = main._reality_player.position + Vector3(0, 1.56, 0)
	main._camera.look_at(world.anchor_world_position("ExitThreshold") + Vector3(0, 1.56, 0))
	main._reality_yaw = main._camera.rotation_degrees.y
	main._reality_pitch = main._camera.rotation_degrees.x
	main._refresh_nearby_reality_actor()

func _press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	viewport.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	viewport.push_input(event, true)

func _wait_unlocked(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while main._input_locked and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not main._input_locked, "transition completes within deadline")

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	RenderingServer.force_draw()
	viewport.get_texture().get_image().save_png(OUTPUT.path_join(label + ".png"))

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
