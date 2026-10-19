extends SceneTree

# Render the real chapter crossroads in a private offscreen viewport. No input
# is sent to the user's running game, and no persistent progress is written.
const PALETTE := {"bg": "B7D957", "surface": "FFF1C9", "text": "10140F", "ink": "10140F", "accent": "365B2D", "muted": "DDEB8A"}

func _init() -> void:
	root.visible = false
	_run.call_deferred()

func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Use a native renderer for pixel evidence")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world = load("res://scripts/world/chapter_world.gd").new()
	viewport.add_child(world)
	var director = load("res://scripts/progression/basement_loop_director.gd")
	var progress: Dictionary = director.initial_progress(false)
	progress.merge({"phase": "crossroads", "round_index": 4, "transition_serial": 6, "narrator_completed": true, "opening_knock_completed": true, "opening_line_number": 30, "entrance_locked": true, "completed_task_ids": director.TASK_IDS.duplicate(), "unlocked_app_ids": ["social", "notebook"]}, true)
	assert(world.configure_stage(director.normalize_progress(progress), PALETTE))
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.current = true
	camera.fov = 68.0
	var output := OS.get_environment("APHASIA_CAPTURE_OUTPUT")
	if output.is_empty():
		output = "res://artifacts/crossroads-decor-removal-20261019/capture"
	DirAccess.make_dir_recursive_absolute(output)
	camera.position = Vector3(19.0, 1.65, -2.8)
	camera.look_at(Vector3(53.0, 2.4, 0.0))
	await _capture(viewport, output.path_join("east-branch.png"))
	camera.position = Vector3(-19.0, 1.65, 2.8)
	camera.look_at(Vector3(-53.0, 2.4, 0.0))
	await _capture(viewport, output.path_join("west-branch.png"))
	camera.position = Vector3(-3.2, 1.65, 2.0)
	camera.look_at(Vector3(-5.5, 2.0, -30.0))
	await _capture(viewport, output.path_join("small-walls-retained.png"))
	var pivot: Node3D = world.find_child("ChapterFarGatePivot", true, false)
	var leaf_size: Vector3 = load("res://scripts/world/chapter_white_gate.gd").SOURCE_LEAF_SIZE
	var gate_center := pivot.to_global(Vector3(leaf_size.x * 0.5, leaf_size.y * 0.5, 0.0))
	camera.position = gate_center + Vector3(-3.4, 0.45, 5.0)
	camera.look_at(gate_center)
	await _capture(viewport, output.path_join("white-exit-retained.png"))
	var counts := {}
	for pattern in ["ThresholdBeam*", "CeilingLightSlot*", "ThresholdLight*", "FalseDoor*", "BrickTurn", "CrossroadBoundary*"]:
		counts[pattern] = world.find_children(pattern, "", true, false).size()
	var file := FileAccess.open(output.path_join("scene-counts.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(counts, "\t"))
	file.close()
	print("crossroads native capture passed: ", counts)
	viewport.free()
	await process_frame
	quit()

func _capture(viewport: SubViewport, path: String) -> void:
	for frame in 10:
		await process_frame
		RenderingServer.force_draw()
	assert(viewport.get_texture().get_image().save_png(path) == OK)
	print("captured ", path)
