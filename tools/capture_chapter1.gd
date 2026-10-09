extends SceneTree

const OUTPUT := "D:/aphasia/outputs/basement_integration_audit"
const State := preload("res://scripts/meme_game_state.gd")
var viewport: SubViewport
var main
var results: Array = []


func _init() -> void:
	root.visible = false
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Chapter captures require a real renderer; use hidden window with offscreen viewport")
		quit(2)
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._save_path = OUTPUT.path_join("capture_chapter1_save.dat")
	main._chapter_dev_enabled = true
	viewport.add_child(main)
	main._locale.set_locale("zh")
	if "--lighting-review" in OS.get_cmdline_user_args():
		await _capture_lighting_review()
		return
	if "--basement-only" not in OS.get_cmdline_user_args():
		main.start_chapter1_game()
		main._set_reality_mouse_look(false)
		if not main._chapter_world_ready:
			push_error("Opening capture cannot bind v2 asset")
			quit(1)
			return
		await _capture("chapter1_opening_18m.png")
		await _capture_clean("chapter1_opening_clean.png")
		var door: Vector3 = main._reality_floor.anchor_world_position("DoorArrival")
		_look_from(Vector3(0, 0.03, door.z + 5.35), door + Vector3(0, 1.1, 0))
		await _capture("chapter1_opening_near.png")
	for visit in range(5):
		var state := _fixture(visit)
		main._begin_game_session(state, {}, false)
		main._set_reality_mouse_look(false)
		if not main._chapter_world_ready:
			push_error("Basement capture failed to bind: %s" % main._reality_floor.diagnostics)
			quit(1)
			return
		await _capture("chapter1_visit_%d_stairs.png" % (visit + 1))
		if visit == 0:
			await _capture_clean("chapter1_stairs_clean.png")
			var tv: Vector3 = main._reality_floor.anchor_world_position("TVAnchor")
			_look_from(Vector3(0.0, 0.03, 2.0), tv + Vector3(0, 0.30, 0))
			await _capture("chapter1_tv_zone.png")
			await _capture_clean("chapter1_tv_clean.png")
			var npc: Vector3 = main._reality_floor.anchor_world_position("NPCAnchor")
			_look_from(Vector3(2.40, 0.03, -2.0), npc + Vector3(0, 1.2, 0))
			await _capture("chapter1_right_passage.png")
			_look_from(Vector3(1.30, 0.03, -3.20), npc + Vector3(0, 0.90, 0))
			await _capture("chapter1_npc_and_exit.png")
			var token: int = state.chapter1_progress.transition_serial
			main.notify_chapter1("entrance_threshold_crossed", {"round_token": token})
			var spawn: Vector3 = main._reality_floor.anchor_world_position("EntrySpawn")
			_look_from(spawn + Vector3(0, 0, 0.15), spawn + Vector3(-1.2, 1.0, 0))
			await _capture("chapter1_sealed_entry.png")
	var crossed := _fixture(5)
	main._begin_game_session(crossed, {}, false)
	main._set_reality_mouse_look(false)
	await _capture("chapter1_crossroads.png")
	var gate := main._reality_floor.find_child("ChapterFarGatePivot", true, false) as Node3D
	if gate != null:
		_look_from(gate.global_position + Vector3(1.5, 0.03, 7.0), gate.global_position + Vector3(1.5, 1.3, 0))
		await _capture("chapter1_far_gate.png")
	var file := FileAccess.open(OUTPUT.path_join("chapter1_capture_results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer": RenderingServer.get_video_adapter_name(), "captures": results, "fixture_note": "Main game rendered with explicit development states; physical playthrough verified separately."}, "\t"))
	file.close()
	main.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame
	print("chapter1 captures passed")
	quit(0)


func _capture_lighting_review() -> void:
	# A bounded two-view colour check of the latest imported basement. This
	# leaves the full route evidence intact and never enters the opening.
	main._begin_game_session(_fixture(0), {}, false)
	main._set_reality_mouse_look(false)
	if not main._chapter_world_ready:
		push_error("Lighting review cannot bind basement: %s" % main._reality_floor.diagnostics)
		quit(1)
		return
	var crt := main._reality_floor.find_child("ChapterVideoScreen", true, false) as Node3D
	var crt_glow := main._reality_floor.find_child("ChapterCRTGreenGlow", true, false) as OmniLight3D
	crt.power_off()
	if crt_glow == null or crt_glow.visible:
		push_error("CRT power_off must disable its local green light")
		quit(1)
		return
	crt.power_on()
	if not crt_glow.visible:
		push_error("CRT power_on must restore its local green light")
		quit(1)
		return
	# Ground-level first-person views match the material references: stair
	# handrail with wooden drawing furniture, then CRT with its local spill.
	_look_from(Vector3(1.4, 0.03, 2.5), Vector3(-1.8, 1.6, 0.0))
	await _capture_clean("chapter1_lighting_review_stairs.png")
	var screen_center: Vector3 = main._reality_floor.anchor_world_position("TVAnchor") + Vector3(0, 0.30, 0)
	_look_from(Vector3(0.0, 0.03, 2.0), screen_center)
	await _capture_clean("chapter1_lighting_review_tv.png")
	var lights: Array = []
	for light: Light3D in main._reality_floor.find_children("*", "Light3D", true, false):
		lights.append({"name": light.name, "visible": light.is_visible_in_tree(), "energy": light.light_energy, "color": light.light_color.to_html(false)})
	var file := FileAccess.open(OUTPUT.path_join("chapter1_lighting_review_results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer": RenderingServer.get_video_adapter_name(), "captures": results, "lights": lights, "crt_power_link_verified": true, "scope": "Two HUD-free colour checks and CRT power/light scene binding; no full regression rerun."}, "\t"))
	file.close()
	main.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame
	print("chapter1 lighting review captures passed")
	quit(0)


func _fixture(completed_visits: int) -> MemeGameState:
	var state := State.new()
	state.new_run()
	state.start_chapter1()
	state.view_state = "npc_up"
	state.active_app_window = ""
	state.notify_chapter1("opening_knock_completed", {"sequence_id": "chapter1_opening"})
	state.notify_chapter1("opening_door_opened", {})
	for visit in completed_visits:
		var token: int = state.chapter1_progress.transition_serial
		state.notify_chapter1("entrance_threshold_crossed", {"round_token": token})
		state.notify_chapter1("npc_help_completed", {"round_token": token, "npc_id": "basement_npc_%02d" % (visit + 1), "task_id": "basement_help_%02d" % (visit + 1)})
		state.notify_chapter1("basement_exit_requested", {"round_token": token})
	return state


func _look_from(feet: Vector3, target: Vector3) -> void:
	main._reality_player.position = feet
	main._reality_player.velocity = Vector3.ZERO
	var direction := (target - feet - Vector3(0, 1.56, 0)).normalized()
	main._reality_yaw = rad_to_deg(atan2(-direction.x, -direction.z))
	main._reality_pitch = rad_to_deg(asin(direction.y))


func _capture_clean(filename: String) -> void:
	main._chapter_dev_collapsed = true
	main._update_chapter_development_panel()
	await _capture(filename)
	main._chapter_dev_collapsed = false
	main._update_chapter_development_panel()


func _capture(filename: String) -> void:
	for frame in 24:
		await process_frame
		RenderingServer.force_draw()
	var rendered := viewport.get_texture().get_image()
	var error := rendered.save_png(OUTPUT.path_join(filename))
	results.append({"file": filename, "error": error, "position": str(main._reality_player.position), "frame_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0})
	print("CHAPTER_CAPTURE: ", filename, " error=", error)
