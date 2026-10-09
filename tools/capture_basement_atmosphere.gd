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
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--visit="):
			visit = clampi(int(arg.trim_prefix("--visit=")), 0, 4)
		if arg == "--xray":
			xray = true
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
	DirAccess.make_dir_recursive_absolute("res://docs/handoff/2026-10-10/evidence/atmosphere")
	for view_name: String in views:
		camera.position = views[view_name][0]
		camera.look_at(views[view_name][1])
		for frame in 5:
			await process_frame
			RenderingServer.force_draw()
		var prefix := "" if visit == 0 else "visit%d_" % (visit + 1)
		if xray:
			prefix += "xray_"
		viewport.get_texture().get_image().save_png("res://docs/handoff/2026-10-10/evidence/atmosphere/%s%s.png" % [prefix, view_name])
		print("captured ", view_name)
	world.free()
	viewport.free()
	quit()
