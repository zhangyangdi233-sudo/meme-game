extends SceneTree
## Render evidence uses the production NPC factory in an isolated lit fixture.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var output := "res://artifacts/npc-lighting-20261019"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	var view := SubViewport.new()
	view.size = Vector2i(640, 640)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.positional_shadow_atlas_size = 2048
	root.add_child(view)
	var world := Node3D.new()
	view.add_child(world)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10, 10)
	floor.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("AAAA99")
	material.roughness = 1
	floor.material_override = material
	world.add_child(floor)
	var factory = load("res://scripts/reality_floor_generator.gd").new()
	var actor: Node3D = factory._make_actor("LightingFixtureNPC", "npc", "NPC", Vector3.ZERO, load("res://assets/generated/characters/npc_late_arrival.png"), 0)
	world.add_child(actor)
	var light := SpotLight3D.new()
	light.position = Vector3(-1.6, 4.2, 2)
	light.light_energy = 5
	light.spot_range = 10
	light.spot_angle = 48
	light.shadow_enabled = true
	world.add_child(light)
	light.look_at(Vector3(0, 0.6, 0))
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("191C1B")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	world.add_child(env)
	var camera := Camera3D.new()
	camera.position = Vector3(3.2, 2.6, 5)
	camera.fov = 44
	view.add_child(camera)
	camera.look_at(Vector3(0, 0.75, 0))
	camera.current = true
	await _draw_frames()
	var lit := view.get_texture().get_image()
	lit.save_png(output + "/npc-lit-shadow.png")
	# Rendering the same world through another camera must not rotate the
	# main viewport's shadow. This also exercises the X-ray viewport contract.
	var secondary_view := SubViewport.new()
	secondary_view.size = Vector2i(320, 320)
	secondary_view.world_3d = view.world_3d
	secondary_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(secondary_view)
	var secondary_camera := Camera3D.new()
	secondary_camera.position = Vector3(-3.2, 2.6, -5)
	secondary_view.add_child(secondary_camera)
	secondary_camera.look_at(Vector3(0, 0.75, 0))
	secondary_camera.current = true
	await _draw_frames()
	var dual_view := view.get_texture().get_image()
	dual_view.save_png(output + "/npc-secondary-camera-active.png")
	secondary_view.free()
	actor.get_node("NPCShadowBody").hide()
	await _draw_frames()
	var without_shadow := view.get_texture().get_image()
	without_shadow.save_png(output + "/npc-lit-no-shadow-comparison.png")
	light.hide()
	await _draw_frames()
	var dark := view.get_texture().get_image()
	dark.save_png(output + "/npc-no-light.png")
	# An external wall must still shadow the portrait. Hiding its surface only
	# keeps the fixture's measurements free of direct camera occlusion.
	light.show()
	actor.get_node("NPCShadowBody").show()
	var blocker := MeshInstance3D.new()
	var blocker_mesh := BoxMesh.new()
	blocker_mesh.size = Vector3(3, 0.1, 3)
	blocker.mesh = blocker_mesh
	blocker.position = Vector3(-0.4, 2.5, 0.6)
	blocker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	world.add_child(blocker)
	await _draw_frames()
	var blocked := view.get_texture().get_image()
	blocked.save_png(output + "/npc-external-occluder.png")
	blocker.hide()
	# A separate unlit portrait mask distinguishes clothes from the ground.
	# The old test counted the incorrectly black torso as a successful shadow.
	floor.hide()
	actor.get_node("NPCShadowBody").hide()
	actor.get_node("FaceScribbleOverlay").hide()
	(actor.get_node("Billboard") as Sprite3D).shaded = false
	env.environment.background_color = Color.BLACK
	await _draw_frames()
	var mask := view.get_texture().get_image()
	mask.save_png(output + "/npc-measurement-mask.png")
	var shadow_pixels := 0
	var lit_pixels := 0
	var portrait_pixels := 0
	var self_shadow_pixels := 0
	var external_shadow_pixels := 0
	var secondary_camera_ground_changes := 0
	var self_shadow_loss := 0.0
	# Ignore the intentionally animated black face overlay when measuring light.
	var face_bottom := int(camera.unproject_position(Vector3(0, 1.35, 0)).y)
	for y in range(face_bottom, 640):
		for x in 640:
			var difference := without_shadow.get_pixel(x,y).get_luminance() - lit.get_pixel(x,y).get_luminance()
			if mask.get_pixel(x,y).get_luminance() > 0.04:
				portrait_pixels += 1
				self_shadow_loss += maxf(0, difference)
				if difference > 0.04:
					self_shadow_pixels += 1
				if lit.get_pixel(x,y).get_luminance() - dark.get_pixel(x,y).get_luminance() > 0.05:
					lit_pixels += 1
				if lit.get_pixel(x,y).get_luminance() - blocked.get_pixel(x,y).get_luminance() > 0.05:
					external_shadow_pixels += 1
			else:
				if difference > 0.04:
					shadow_pixels += 1
				if absf(dual_view.get_pixel(x,y).get_luminance() - lit.get_pixel(x,y).get_luminance()) > 0.04:
					secondary_camera_ground_changes += 1
	var mean_self_shadow_loss := self_shadow_loss / maxf(1, portrait_pixels)
	var passed := shadow_pixels > 150 and lit_pixels > 1000 and external_shadow_pixels > 1000 and mean_self_shadow_loss < 0.015 and secondary_camera_ground_changes < 20
	var report := {"passed":passed,"ground_shadow_pixels":shadow_pixels,"portrait_light_affected_pixels":lit_pixels,"portrait_pixels":portrait_pixels,"self_shadow_pixels":self_shadow_pixels,"mean_self_shadow_loss":mean_self_shadow_loss,"external_shadow_pixels":external_shadow_pixels,"secondary_camera_ground_changes":secondary_camera_ground_changes,"fixture":"Production factory NPC under one external spotlight; separate portrait/ground masks, external wall occlusion and simultaneous second camera"}
	var file := FileAccess.open(output + "/results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("NPC lighting render %s: %s" % ["passed" if passed else "FAILED", report])
	factory.free()
	view.free()
	quit(0 if passed else 1)

func _draw_frames() -> void:
	for frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
