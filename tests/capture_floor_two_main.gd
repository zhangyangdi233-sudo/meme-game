extends SceneTree
## Render the production scene host (including visibility and palette plumbing),
## in a hidden independent viewport. This never opens the user's game window.

const OUTPUT := "res://artifacts/floor-two-maze-20261016"

func _init() -> void:
	root.visible = false
	_run.call_deferred()

func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1440, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var main = load("res://scenes/babel_meme_game.tscn").instantiate()
	viewport.add_child(main)
	main.new_game()
	main._skip_prologue()
	main.game.tower_floor = 2
	main._ensure_reality_floor_current()
	main.set_view_state("npc_up")
	main._render()
	for frame in 12:
		await process_frame
		RenderingServer.force_draw()
	main.set_process(false)
	main.set_physics_process(false)
	var camera: Camera3D = main.get_node("Camera3D")
	var world: Node3D = main.get_node("RealityFloor")
	var data: Dictionary = world.get_floor_two_map_layout()
	var views := [
		{"name": "main-entrance", "feet": Vector2(-40, 40), "look": Vector2(-40, 17)},
		{"name": "main-first-turn", "feet": Vector2(-40, 10), "look": Vector2(-12, 8)},
		{"name": "main-white-exit", "feet": Vector2(40, -34), "look": Vector2(40, -44)},
	]
	for view: Dictionary in views:
		var point := Vector3(view.feet.x, 0, view.feet.y)
		point.y = float(world.floor_two_probe(point).ground_height)
		main.get_node("RealityPlayer").position = point
		camera.position = point + Vector3.UP * 1.56
		var look := Vector3(view.look.x, 0, view.look.y)
		look.y = float(world.floor_two_probe(look).ground_height) + 1.5
		camera.look_at(look)
		for frame in 6:
			await process_frame
			RenderingServer.force_draw()
		assert(viewport.get_texture().get_image().save_png(OUTPUT.path_join(str(view.name) + ".png")) == OK)
	var visible_legacy: Array[String] = []
	for name in ["Road", "Tower", "NPC", "Ground", "Street"]:
		var legacy: Node3D = main.get_node_or_null(name)
		if legacy != null and legacy.is_visible_in_tree():
			visible_legacy.append(name)
	var report := {"renderer": RenderingServer.get_current_rendering_method(), "display_server": DisplayServer.get_name(), "floor": main.game.tower_floor, "host_script": world.get_script().resource_path, "layout_version": data.version, "visible_legacy_nodes": visible_legacy}
	FileAccess.open(OUTPUT.path_join("main-capture.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	assert(visible_legacy.is_empty(), "Legacy world geometry must stay hidden")
	main.free()
	viewport.free()
	await process_frame
	print("floor two production scene capture passed")
	quit()
