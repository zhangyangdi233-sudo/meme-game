extends SceneTree

func _init() -> void:
	root.visible = false
	_run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world = load("res://scripts/world/chapter_world.gd").new()
	viewport.add_child(world)
	var director = load("res://scripts/progression/basement_loop_director.gd")
	var progress: Dictionary = director.initial_progress(false)
	progress.merge({"phase": "basement", "round_index": 4, "transition_serial": 5, "narrator_completed": true, "opening_knock_completed": true, "opening_line_number": 30, "entrance_locked": true, "completed_task_ids": director.TASK_IDS.slice(0, 4)}, true)
	assert(world.configure_stage(progress, {}))
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.current = true
	camera.fov = 78
	camera.cull_mask &= ~(1 << 19)
	camera.position = Vector3(-0.15, 1.40, 1.0)
	camera.look_at(Vector3(2.2, 0.65, 0.25))
	var anomaly = world.find_child("CRTAnomaly", true, false)
	assert(anomaly != null)
	var output := "res://artifacts/crt-verification"
	DirAccess.make_dir_recursive_absolute(output)
	await create_timer(0.4).timeout
	await _capture(viewport, output.path_join("crt-normal.png"))
	# A side view makes the tapered rear housing and buried lower bezel legible.
	camera.position = Vector3(0.25, 0.85, 0.55)
	camera.look_at(Vector3(0.75, 0.25, 1.65))
	await _capture(viewport, output.path_join("crt-close.png"))
	camera.position = Vector3(-0.15, 1.40, 1.0)
	camera.look_at(Vector3(2.2, 0.65, 0.25))
	anomaly.update_visit(0.0, true, Vector3.ZERO)
	await _capture(viewport, output.path_join("crt-black.png"))
	anomaly.update_visit(2.0, true, Vector3.ZERO)
	await _capture(viewport, output.path_join("crt-red.png"))
	anomaly.update_visit(6.0, true, Vector3.ZERO)
	anomaly.update_visit(0.2, true, Vector3.ZERO)
	await _capture(viewport, output.path_join("crt-restored.png"))
	world.free()
	viewport.free()
	await create_timer(0.1).timeout
	print("basement CRT capture passed")
	quit()

func _capture(viewport: SubViewport, path: String) -> void:
	for frame in 5:
		await process_frame
		RenderingServer.force_draw()
	viewport.get_texture().get_image().save_png(path)
	print("captured ", path)
