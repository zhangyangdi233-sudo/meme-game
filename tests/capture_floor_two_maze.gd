extends SceneTree

const World = preload("res://scripts/reality_floor_generator.gd")
const Layout = preload("res://scripts/world/floor_two_maze_layout.gd")
const OUTPUT := "res://artifacts/maze-xray-20261019/render"
var _output := OUTPUT
var viewport: SubViewport
var camera: Camera3D
var world: Node3D

func _init() -> void:
	root.visible = false
	_run.call_deferred()

func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Capture needs real rendered frames")
	if not OS.get_environment("APHASIA_CAPTURE_OUTPUT").is_empty():
		_output = OS.get_environment("APHASIA_CAPTURE_OUTPUT")
	DirAccess.make_dir_recursive_absolute(_output)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1440, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	world = World.new()
	viewport.add_child(world)
	var textures := [load("res://assets/generated/characters/npc_late_arrival.png"), load("res://assets/generated/characters/npc_echo_tenant.png")]
	world.rebuild(2, {}, {"npcs": textures})
	camera = Camera3D.new()
	camera.fov = 68
	camera.current = true
	camera.cull_mask = 1 | Layout.NORMAL_ONLY_LAYER
	viewport.add_child(camera)
	await physics_frame
	await _view("entrance", Vector2(-56, 88), Vector2(-56, 68))
	await _view("wayfinder-room", Vector2(-56, 77), Vector2(-55.5, 70))
	await _view("first-turn", Vector2(-56, 58), Vector2(-24, 56))
	await _view("cartographer-room", Vector2(-14, 56), Vector2(-4, 56))
	await _layer_views("xray-intro", Vector2(8, 46), Vector2(8, 40))
	await _layer_views("hidden-path", Vector2(24, -50), Vector2(24, -56))
	await _layer_views("solid-partition", Vector2(38, -18), Vector2(38, -24))
	await _layer_views("white-exit", Vector2(-72, 27), Vector2(-72, 20.4))
	camera.position = Vector3(135, 200, 165)
	camera.look_at(Vector3(0, 0, 0))
	await _capture("overview")
	var triangles := 0
	var material_ids := {}
	var mesh_count := 0
	for mesh: MeshInstance3D in world.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		mesh_count += 1
		triangles += mesh.mesh.get_faces().size() / 3
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			if material != null:
				material_ids[material.get_instance_id()] = true
	var detail_instances := 0
	var detail_batches := 0
	for batch: MultiMeshInstance3D in world.find_children("*", "MultiMeshInstance3D", true, false):
		detail_batches += 1
		detail_instances += batch.multimesh.instance_count
		triangles += batch.multimesh.mesh.get_faces().size() / 3 * batch.multimesh.instance_count
		material_ids[batch.material_override.get_instance_id()] = true
	var report := {"renderer": RenderingServer.get_current_rendering_method(), "display_server": DisplayServer.get_name(), "source": "actual RealityFloorGenerator.rebuild(2); authored lighting, no review lights", "layout_version": world.get_floor_two_map_layout().version, "mesh_instances": mesh_count, "detail_instances": detail_instances, "detail_material_batches": detail_batches, "render_triangles_including_terrain": triangles, "material_resources": material_ids.size(), "original_texture_size": 128}
	FileAccess.open(_output.path_join("capture.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	world.free()
	viewport.free()
	await process_frame
	print("floor two maze render capture passed")
	quit()

func _view(label: String, feet: Vector2, target: Vector2) -> void:
	var point := Vector3(feet.x, 0, feet.y)
	point.y = float(world.floor_two_probe(point).ground_height) + 1.56
	camera.position = point
	var look := Vector3(target.x, 0, target.y)
	look.y = float(world.floor_two_probe(look).ground_height) + 1.5
	camera.look_at(look)
	await _capture(label)

func _layer_views(label: String, feet: Vector2, target: Vector2) -> void:
	camera.cull_mask = 1 | Layout.NORMAL_ONLY_LAYER
	await _view(label + "-normal", feet, target)
	camera.cull_mask = 1 | Layout.XRAY_RENDER_LAYER
	await _capture(label + "-xray")
	camera.cull_mask = 1 | Layout.NORMAL_ONLY_LAYER

func _capture(label: String) -> void:
	for frame in 8:
		await process_frame
		RenderingServer.force_draw()
	assert(viewport.get_texture().get_image().save_png(_output.path_join(label + ".png")) == OK)
	print("captured ", label)
