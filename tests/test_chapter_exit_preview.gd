extends SceneTree
## Real imported rooms: a destination preview must never occupy the current room.

const World = preload("res://scripts/world/chapter_world.gd")
const Director = preload("res://scripts/progression/basement_loop_director.gd")
const OUTPUT := "D:/aphasia/outputs/basement_followup_20261010/doors"
var checks := 0
var failures: Array[String] = []
var rows: Array[Dictionary] = []
var viewport: SubViewport

func _init() -> void:
	root.visible = false
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for visit in 5:
		var progress: Dictionary = Director.initial_progress()
		progress.phase = "basement"
		progress.narrator_completed = true
		progress.opening_knock_completed = true
		progress.round_index = visit
		progress.transition_serial = visit + 1
		progress.entrance_locked = true
		progress.completed_task_ids = Director.TASK_IDS.slice(0, visit + 1)
		var world = World.new()
		viewport.add_child(world)
		_check(world.configure_stage(progress, {}), "visit %d actual GLB binds" % (visit + 1))
		var camera := Camera3D.new()
		viewport.add_child(camera)
		camera.current = true
		camera.cull_mask = 0xFFFFF & ~World.XRAY_RENDER_LAYER
		camera.position = Vector3(1.45, 1.56, -3.3)
		var target := Vector3(-3.2, 1.1, -3.43)
		camera.look_at(target)
		await process_frame
		await physics_frame
		var hits := _visible_hits(world, camera.global_position, target)
		rows.append({"visit": visit + 1, "closed_view_hits": hits})
		print("visit %d closed view: %s" % [visit + 1, JSON.stringify(hits.slice(0, 4))])
		_check(not hits.is_empty() and str(hits[0].node).ends_with("ExitDoor_Leaf"), "closed exit is visible from NPC corridor without a preview wall in front")
		var preview: Node = world.get_node("NextBasementThroughDoor")
		var shared_room_geometry := 0
		var marker_geometry := 0
		for geometry: GeometryInstance3D in preview.find_children("*", "GeometryInstance3D", true, false):
			if geometry.get_world_3d() == world.get_world_3d() and not (geometry is MeshInstance3D and geometry.mesh is QuadMesh):
				shared_room_geometry += 1
			if (geometry.layers & World.XRAY_RENDER_LAYER) != 0:
				marker_geometry += 1
		_check(shared_room_geometry == 0, "destination architecture belongs to an isolated World3D, only the aperture shares current room")
		_check(marker_geometry == 0, "preview cannot leak future X-ray clues")
		if visit < 4:
			var next_visit: Node = preview.find_child("NextVisitScenery", true, false)
			_check(next_visit != null and next_visit.get("_bound_round") == visit + 1, "preview builds the following visit instead of duplicating the current visit")
			_check(next_visit.get_node_or_null("NextBasementThroughDoor") == null, "destination preview never recursively spawns further rooms")
			var next_atmosphere: Node = next_visit.get_node("BasementAtmosphere")
			_check(next_atmosphere.get_meta("anomaly") == ["flicker", "blackout", "clock_wall", "xray_broken_clock"][visit], "preview uses the next visit's lighting and clock dressing")
		var door: Node = world.get_door("exit")
		_check(not door.is_passable(), "closed ordinary door still blocks the player")
		await _capture("visit_%d_closed" % (visit + 1))
		_check(door.request_open(), "unlocked ordinary door begins opening")
		await create_timer(0.9).timeout
		_check(not door.is_passable(), "partially open door retains its cinematic blocker")
		await _capture("visit_%d_opening" % (visit + 1))
		await door.opened
		await process_frame
		_check(door.is_passable(), "fully open door releases its original blocker")
		await _capture("visit_%d_open" % (visit + 1))
		camera.free()
		world.free()
		await process_frame
	viewport.free()
	var report := {"checks": checks, "failures": failures, "rooms": rows, "renderer": RenderingServer.get_current_rendering_method()}
	FileAccess.open(OUTPUT.path_join("exit_preview_results.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	for failure in failures:
		push_error(failure)
	print("chapter exit preview: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _visible_hits(world: Node3D, origin: Vector3, target: Vector3) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	var direction := (target - origin).normalized()
	for node: MeshInstance3D in world.find_children("*", "MeshInstance3D", true, false):
		if node.mesh == null or not node.is_visible_in_tree() or node.get_world_3d() != world.get_world_3d() or (node.layers & 1) == 0:
			continue
		var local_origin := node.to_local(origin)
		var local_direction := node.global_basis.inverse() * direction
		if not node.get_aabb().intersects_ray(local_origin, local_direction):
			continue
		var vertices := node.mesh.get_faces()
		var nearest := INF
		for index in range(0, vertices.size(), 3):
			var point: Variant = Geometry3D.ray_intersects_triangle(local_origin, local_direction, vertices[index], vertices[index + 1], vertices[index + 2])
			if point is Vector3:
				nearest = minf(nearest, origin.distance_to(node.to_global(point)))
		if nearest <= origin.distance_to(target) + 0.12:
			hits.append({"node": str(world.get_path_to(node)), "distance": nearest})
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.distance) < float(b.distance))
	return hits

func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	RenderingServer.force_draw()
	viewport.get_texture().get_image().save_png(OUTPUT.path_join(label + ".png"))

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
