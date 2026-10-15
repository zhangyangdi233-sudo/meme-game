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
	progress.merge({"phase": "crossroads", "round_index": 4, "transition_serial": 6, "narrator_completed": true, "opening_knock_completed": true, "opening_line_number": 30, "entrance_locked": true, "completed_task_ids": director.TASK_IDS.duplicate(), "unlocked_app_ids": ["social", "notebook"]}, true)
	progress = director.normalize_progress(progress)
	assert(world.configure_stage(progress, {"bg": "B7D957", "surface": "FFF1C9", "text": "10140F", "ink": "10140F", "accent": "365B2D", "muted": "DDEB8A"}))
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.current = true
	camera.fov = 68
	var pivot: Node3D = world.find_child("ChapterFarGatePivot", true, false)
	var source_size: Vector3 = load("res://scripts/world/chapter_white_gate.gd").SOURCE_LEAF_SIZE
	var center := pivot.to_global(Vector3(source_size.x * 0.5, source_size.y * 0.5, 0))
	var output := OS.get_environment("APHASIA_CAPTURE_OUTPUT")
	if output.is_empty():
		output = "res://artifacts/crossroads-gate-20261015"
	DirAccess.make_dir_recursive_absolute(output)
	camera.position = center + Vector3(0.0, 0.25, 4.0)
	camera.look_at(center)
	await _capture(viewport, output.path_join("gate-closed-front.png"))
	camera.position = center + Vector3(-3.4, 0.45, 5.0)
	camera.look_at(center)
	await _capture(viewport, output.path_join("gate-closed-side.png"))
	camera.position = center + Vector3(0.0, 0.35, 12.0)
	camera.look_at(center)
	await _capture(viewport, output.path_join("gate-approach.png"))
	assert(world.interact(world.get_interactable_actors()[0]))
	await create_timer(0.5).timeout
	camera.position = center + Vector3(0.0, 0.25, 4.0)
	camera.look_at(center)
	await _capture(viewport, output.path_join("gate-open.png"))
	world.free()
	viewport.free()
	await process_frame
	print("crossroads white gate capture passed")
	quit()

func _capture(viewport: SubViewport, path: String) -> void:
	for frame in 6:
		await process_frame
		RenderingServer.force_draw()
	assert(viewport.get_texture().get_image().save_png(path) == OK)
	print("captured ", path)
