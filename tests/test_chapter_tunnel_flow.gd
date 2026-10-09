extends SceneTree
## Covers the real host and its opaque scene-change boundary. Run with a renderer
## to also save frames; headless runs the same transition and save assertions.

const OUTPUT := "D:/aphasia/outputs/tunnel_readability_20261009"
var main
var viewport: SubViewport
var failures: Array[String] = []
var checks := 0
var swaps: Array[Dictionary] = []


func _init() -> void:
	root.visible = false
	_run.call_deferred()


func _run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._save_path = OUTPUT.path_join("tunnel_flow_save.dat")
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
		var asset_id: int = world.imported_root.get_instance_id()
		var tunnel: Node3D = world.get_node("BasementExitTunnel")
		main._reality_player.position = world.anchor_world_position("ExitThreshold") + Vector3(0.85, 0, 0)
		world.get_door("exit").request_open()
		await create_timer(0.42).timeout
		world.update_authored_events(0.1, main._reality_player.position, Vector3.LEFT)
		_place(tunnel, Vector3(0, 0.02, -0.6))
		world.update_authored_events(0.1, main._reality_player.position, Vector3.LEFT)
		await process_frame
		await physics_frame
		var eye: Vector3 = main._reality_player.position + Vector3(0, 1.56, 0)
		var ray := PhysicsRayQueryParameters3D.create(eye, tunnel.to_global(Vector3(0, 1.4, -12.3)), 1)
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
		_check(not hit.is_empty() and eye.distance_to(hit.position) > 8.0, "authored exit back wall no longer blocks sight or physical passage to the white door")
		_check(main.game.chapter1_progress.transition_serial == token and world.imported_root.get_instance_id() == asset_id, "old doorway preserves the same room and visit")
		_check(not main.game.chapter1_progress.exit_tunnel_entered, "door does not seal on the player's body")
		if visit == 0:
			await _capture("01_exit_reveals_tunnel")
		_place(tunnel, Vector3(0, 0.02, -3.8))
		world.update_authored_events(0.1, main._reality_player.position, Vector3.LEFT)
		await process_frame
		_check(main.game.chapter1_progress.exit_tunnel_entered and main.game.chapter1_progress.transition_serial == token, "entering corridor marks progress without scene replacement")
		_check(world.imported_root.get_instance_id() == asset_id, "corridor is attached to the unchanged basement")
		_check(world.contains_playable_position(main._reality_player.position, 1.2), "corridor does not trigger out-of-bounds recovery")
		if visit == 0:
			await _capture("02_dark_corridor")
			var saved_position: Vector3 = main._reality_player.position
			main._save_progress()
			_check(main.continue_game(), "continue accepts tunnel save")
			main.set_process(false)
			main.set_physics_process(false)
			await process_frame
			_check(main._reality_player.position.distance_to(saved_position) < 0.01 and main.game.chapter1_progress.exit_tunnel_entered, "continue restores exact position and tunnel flag")
			world = main._reality_floor
			tunnel = world.get_node("BasementExitTunnel")
			_check(not world.get_door("tunnel").is_passable(), "restored white door is closed and can be opened again")
		_place(tunnel, Vector3(0, 0.02, -9.3))
		if visit == 0:
			await _capture("03_white_door_ready")
		_press(KEY_F)
		await process_frame
		_check(is_instance_valid(main._chapter_door_transition) and main._input_locked, "actual nearby F starts white-door transition and locks motion")
		if not is_instance_valid(main._chapter_door_transition):
			break
		var transition: Node = main._chapter_door_transition
		_press(KEY_F)
		_check(main._chapter_door_transition == transition, "repeat F retains the same transition")
		transition.room_requested.connect(func():
			var overlay: ColorRect = main._ui_root.get_node("ChapterDoorTransitionOverlay")
			var covered: bool = overlay.color.is_equal_approx(Color.WHITE)
			_check(covered, "actual room replacement is behind opaque white")
			_check(main._input_locked, "new room stays locked during white hold")
			swaps.append({"from_visit": visit + 1, "opaque_white": covered, "phase": main.game.chapter1_progress.phase, "round_index": main.game.chapter1_progress.round_index})
			if visit == 0:
				_capture("05_opaque_swap")
		)
		if visit == 0:
			await create_timer(0.55).timeout
			_press(KEY_ESCAPE)
			_check(main._settings_open, "Esc opens settings during white door animation")
			var pivot: Node3D = tunnel.get_node("TunnelWhiteDoorPivot")
			var angle := pivot.rotation.y
			await create_timer(0.3).timeout
			_check(is_equal_approx(pivot.rotation.y, angle) and main.game.chapter1_progress.transition_serial == token, "settings freezes door and prevents early scene change")
			_press(KEY_ESCAPE)
			await create_timer(0.45).timeout
			await _capture("04_white_door_opening")
		await _wait_unlocked(5.0)
		var expected := "crossroads" if visit == 4 else "basement"
		_check(main.game.chapter1_progress.phase == expected and main.game.chapter1_progress.transition_serial == token + 1, "completed white door reaches correct next destination once")
		_check(main._reality_player.position.distance_to(main._reality_floor.start_position()) < 0.01, "new destination uses its intended arrival anchor")
		_check(not main._input_locked and not is_instance_valid(main._chapter_door_transition), "fade-in releases input and transition owner")
		if visit == 0 or visit == 4:
			await _capture("06_next_basement" if visit == 0 else "07_crossroads_arrival")
	# Returning to the menu mid-transition must cancel a pending scene callback.
	main.start_chapter1_game()
	main.set_process(false)
	main.set_physics_process(false)
	main.notify_chapter1("opening_knock_completed", {"sequence_id": "chapter1_opening"})
	main.notify_chapter1("opening_door_opened")
	var token: int = main.game.chapter1_progress.transition_serial
	main.notify_chapter1("entrance_threshold_crossed", {"round_token": token})
	main.notify_chapter1("npc_help_completed", {"round_token": token, "npc_id": "basement_npc_01", "task_id": "basement_help_01"})
	main.notify_chapter1("basement_tunnel_entered", {"round_token": token})
	_place(main._reality_floor.get_node("BasementExitTunnel"), Vector3(0, 0.02, -9.3))
	var retry_position: Vector3 = main._reality_player.position
	_press(KEY_F)
	main._reality_floor.get_door("tunnel").set_locked(true)
	await create_timer(0.65).timeout
	_check(not main._input_locked and not is_instance_valid(main._chapter_door_transition), "rejected door opening releases the cinematic lock")
	_check(main._reality_player.position.distance_to(retry_position) < 0.01 and main.game.chapter1_progress.transition_serial == token, "cancel recovery preserves corridor position and visit")
	_press(KEY_F)
	await create_timer(0.5).timeout
	_check(is_instance_valid(main._chapter_door_transition), "white door can be retried after a rejected opening")
	main.show_main_menu()
	await create_timer(2.8).timeout
	_check(not main._game_started and not main._input_locked, "canceling to menu prevents a late tunnel callback")
	main._set_reality_mouse_look(false)
	main.free()
	await process_frame
	var file := FileAccess.open(OUTPUT.path_join("tunnel_flow_results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "swaps": swaps, "renderer": DisplayServer.get_name()}, "\t"))
	for failure in failures:
		push_error(failure)
	print("chapter tunnel flow: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _place(tunnel: Node3D, local: Vector3) -> void:
	main._reality_player.position = tunnel.to_global(local)
	main._camera.position = main._reality_player.position + Vector3(0, 1.56, 0)
	main._camera.look_at(tunnel.to_global(Vector3(0, 1.4, -12)))
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
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while main._input_locked and Time.get_ticks_msec() < end:
		await process_frame
	_check(not main._input_locked, "transition completes within deadline")


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	RenderingServer.force_draw()
	viewport.get_texture().get_image().save_png(OUTPUT.path_join("tunnel_" + label + ".png"))


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
