extends SceneTree

func _init() -> void:
	root.visible = false
	call_deferred("_run")

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world: Node3D = load("res://scripts/world/chapter_world.gd").new()
	viewport.add_child(world)
	var director = load("res://scripts/progression/basement_loop_director.gd")
	var progress: Dictionary = director.initial_progress()
	progress = director.dispatch(progress, "opening_knock_completed", {"sequence_id": "chapter1_opening"}).progress
	progress = director.dispatch(progress, "opening_door_opened").progress
	var visit := 0
	var xray := false
	var wall_wear_only := false
	var output := "res://docs/handoff/2026-10-10/evidence/atmosphere"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visit="):
			visit = clampi(int(arg.trim_prefix("--visit=")), 0, 4)
		if arg == "--xray":
			xray = true
		if arg == "--wall-wear-only":
			wall_wear_only = true
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	for index in visit:
		var token: int = progress.transition_serial
		progress = director.dispatch(progress, "entrance_threshold_crossed", {"round_token": token}).progress
		progress = director.dispatch(progress, "npc_help_completed", {"round_token": token, "npc_id": director.NPC_IDS[index], "task_id": director.TASK_IDS[index]}).progress
		progress = director.dispatch(progress, "basement_tunnel_entered", {"round_token": token}).progress
		progress = director.dispatch(progress, "basement_exit_requested", {"round_token": token}).progress
	var portrait := load("res://assets/generated/characters/npc_archive_witness.png") as Texture2D
	world.configure_stage(progress, {}, null, {}, {"key_npc": portrait, "npcs": [portrait, portrait, portrait, portrait]})
	if world.find_child("BasementAtmosphere", true, false) == null:
		var dressing: Node3D = load("res://scripts/world/basement_atmosphere.gd").new()
		dressing.name = "BasementAtmosphere"
		world.add_child(dressing)
		dressing.configure(world.imported_root, {}, progress)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.current = true
	camera.fov = 78
	camera.cull_mask &= ~(1 << 19)
	if xray:
		camera.cull_mask |= 1 << 19
	var views := {
		"ceiling": [Vector3(0.1, 1.65, 2.6), Vector3(-2.3, 3.7, 0)],
		"furniture": [Vector3(1.5, 1.65, 1.8), Vector3(-0.9, 0.85, -0.6)],
		"crt": [Vector3(-0.3, 1.65, 1.8), Vector3(1.6, 1.5, 3.6)],
		"rear": [Vector3(1.2, 1.65, -3.2), Vector3(-1.9, 1.0, -3.8)],
		"npc_close": [Vector3(0.0, 1.65, -2.86), Vector3(0.0, 0.4, -3.7)],
	}
	if wall_wear_only:
		views = {
			"wall_wear_front_far": [Vector3(-0.3, 1.65, 1.8), Vector3(1.6, 1.5, 3.6)],
			"wall_wear_front_close": [Vector3(-1.7, 1.40, 2.92), Vector3(-1.5, 1.30, 4.19)],
			"wall_wear_partition": [Vector3(1.5, 1.65, 1.8), Vector3(-0.9, 0.85, -0.6)],
			"wall_wear_east_far": [Vector3(0.1, 1.65, 1.2), Vector3(3.19, 1.2, -0.3)],
			"wall_wear_east_close": [Vector3(1.9, 1.4, -0.6), Vector3(3.19, 1.35, -0.8)],
		}
	DirAccess.make_dir_recursive_absolute(output)
	for view_name: String in views:
		camera.position = views[view_name][0]
		camera.look_at(views[view_name][1])
		if view_name == "wall_wear_east_close":
			var wear := world.get_node_or_null("BasementAtmosphere/WallWearEast") as MeshInstance3D
			if wear != null:
				var focus := _dense_wear_position(wear)
				camera.position = focus + Vector3(-0.90, 0.03, 0)
				camera.look_at(focus)
		for frame in 5:
			await process_frame
			RenderingServer.force_draw()
		var prefix := "" if visit == 0 else "visit%d_" % (visit + 1)
		if xray:
			prefix += "xray_"
		viewport.get_texture().get_image().save_png(output.path_join("%s%s.png" % [prefix, view_name]))
		print("captured ", view_name)
	world.free()
	viewport.free()
	quit()


func _dense_wear_position(wear: MeshInstance3D) -> Vector3:
	# Frame an actual authored cluster for close-up inspection, rather than
	# accidentally sampling untouched wallpaper between the sparse marks.
	var points: PackedVector3Array = wear.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var bins: Dictionary = {}
	for point in points:
		var cell := Vector2i(floori(point.z / 0.5), floori(point.y / 0.5))
		if not bins.has(cell):
			bins[cell] = {"sum": Vector3.ZERO, "count": 0}
		bins[cell].sum += point
		bins[cell].count += 1
	var largest := 0
	var focus := Vector3(3.188, 1.4, -0.8)
	for entry: Dictionary in bins.values():
		if int(entry.count) > largest:
			largest = int(entry.count)
			focus = entry.sum / float(entry.count)
	return wear.to_global(focus)
