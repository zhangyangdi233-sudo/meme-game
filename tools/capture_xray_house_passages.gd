extends SceneTree

const Layout = preload("res://scripts/world/floor_two_maze_layout.gd")
var viewport: SubViewport
var camera: Camera3D
var world: Node3D
var output := "res://artifacts/xray-house-passages-20261019/render"

func _init() -> void:
	root.visible = false
	_run.call_deferred()

func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Use a real native renderer for visual evidence")
	if not OS.get_environment("APHASIA_CAPTURE_OUTPUT").is_empty():
		output = OS.get_environment("APHASIA_CAPTURE_OUTPUT")
	DirAccess.make_dir_recursive_absolute(output)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1440, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	world = load("res://scripts/reality_floor_generator.gd").new()
	viewport.add_child(world)
	world.rebuild(2, {}, {}, 1, true, {}, false)
	camera = Camera3D.new()
	camera.fov = 68.0
	camera.current = true
	viewport.add_child(camera)
	await physics_frame
	var layout: Dictionary = world.get_floor_two_map_layout()
	for difference: Dictionary in layout.xray_differences:
		if difference.kind != "false_residence":
			continue
		var center: Vector2 = difference.rect.get_center()
		var standing := Vector3(center.x + 0.8, 0, center.y + 14.0)
		standing.y = float(world.floor_two_probe(standing).ground_height) + 1.65
		camera.position = standing
		var look := Vector3(center.x, 0, center.y + 4.0)
		look.y = float(world.floor_two_probe(look).ground_height) + minf(3.5, float(difference.height) * 0.5)
		camera.look_at(look)
		camera.cull_mask = 1 | Layout.NORMAL_ONLY_LAYER
		await _capture(str(difference.id) + "-normal")
		camera.cull_mask = 1 | Layout.XRAY_RENDER_LAYER
		await _capture(str(difference.id) + "-xray")
	var exit_point: Vector3 = layout.exit_position
	camera.position = exit_point + Vector3(0, 1.6, 3)
	camera.look_at(exit_point + Vector3(0, 1.45, -3.5))
	camera.cull_mask = 1 | Layout.NORMAL_ONLY_LAYER
	await _capture("white-exit-normal")
	camera.cull_mask = 1 | Layout.XRAY_RENDER_LAYER
	await _capture("white-exit-xray")
	viewport.free()
	await process_frame
	print("xray house native capture passed using ", RenderingServer.get_current_rendering_method())
	quit()

func _capture(label: String) -> void:
	for frame in 8:
		await process_frame
		RenderingServer.force_draw()
	assert(viewport.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK)
	print("captured ", label)
