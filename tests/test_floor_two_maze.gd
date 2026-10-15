extends SceneTree

const Layout = preload("res://scripts/world/floor_two_maze_layout.gd")
const World = preload("res://scripts/reality_floor_generator.gd")
var checks := 0
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var data := Layout.data()
	_check(data.rows.size() == 13 and data.walkable_cells.size() == 46, "fixed shared plan has thirteen rows and forty-six walkable cells")
	_check(_distance(Layout.SPAWN_CELL, Layout.EXIT_CELL) == 32, "shortest full route is 256 metres")
	for cell in [Layout.WAYFINDER_CELL, Layout.TURN_CELLS[0], Layout.TURN_CELLS[1], Layout.CARTOGRAPHER_CELL]:
		_check(_distance(Layout.SPAWN_CELL, Layout.EXIT_CELL, cell) == -1, "required NPC/turn cell %s cannot be bypassed" % cell)
	for index in 13:
		_check(not Layout.is_walkable(Vector2i(index, 0)) and not Layout.is_walkable(Vector2i(index, 12)) and not Layout.is_walkable(Vector2i(0, index)) and not Layout.is_walkable(Vector2i(12, index)), "continuous outer residences prevent perimeter shortcut")
	var world := World.new()
	root.add_child(world)
	world.rebuild(2, {}, {})
	await process_frame
	await physics_frame
	data = world.get_floor_two_map_layout()
	_check(world.get_meta("layout_mode") == "residential_maze", "actual generator selects residential maze")
	_check(world.get_meta("terrain_profile") == "undulating_irregular_disc" and world.get_meta("disc_mound_count") == 13, "original hill terrain remains")
	_check(world.get_meta("ordinary_npc_count") == 2 and world.get_interactable_actors().size() == 3, "only two journey NPCs and physical exit remain")
	_check(data.blocking_rects.size() == 4, "phone fine grid receives all four passage side-wall footprints")
	for rect: Rect2 in data.blocking_rects:
		var center := rect.get_center()
		var point := Vector3(center.x, 0, center.y)
		point.y = float(world.floor_two_probe(point).ground_height)
		_check(not world.floor_two_probe(point).walkable and not _body_hits(world, point).is_empty(), "passage map wall matches actual collision")
		var recovered := world.clamp_to_playable_position(point)
		_check(world.floor_two_probe(recovered).walkable and _body_hits(world, recovered).is_empty(), "old save in a passage wall recovers to its clear center")
	_check(world.get_interactable_items().is_empty(), "old room and prerequisite pickups are absent")
	_check(world.find_child("DreamcoreArtifacts", true, false) == null and world.find_child("SuspenseOcclusion", true, false) == null, "clutter and freestanding screens are absent")
	_check(world.find_child("CoverWatcherEvent", true, false) == null and world.get_cover_watcher_state().is_empty(), "no old watcher model or trigger remains")
	var ids: Array[String] = []
	for actor in world.get_interactable_actors():
		ids.append(actor.get_meta("actor_id"))
	_check(ids == ["floor2_wayfinder", "floor2_cartographer", "floor2_exit"], "stable actor ids match journey and F routing")
	for day in range(1, 13):
		world.configure_authored_events(day, {})
		_check(world.get_meta("authored_event_count") == 0 and World.authored_event_kinds_for_floor_day(2, day).is_empty() and world.find_child("AuthoredHorrorEvents", true, false) == null, "day %d cannot resurrect old second-floor props/events" % day)
	_check(not World.authored_event_kinds_for_floor_day(3, 1).is_empty(), "third-floor authored schedule remains active")
	for point: Vector3 in data.primary_route:
		_check(_body_hits(world, point).is_empty(), "main route center has physical player clearance at %s" % point)
		var ground_hit := _ground_hit(world, point)
		_check(not ground_hit.is_empty() and ground_hit.collider.name == "IrregularDiscGround", "main route remains supported by original terrain")
	for index in range(1, data.primary_route.size()):
		var a: Vector3 = data.primary_route[index - 1]
		var b: Vector3 = data.primary_route[index]
		for step in range(1, 16):
			var point := a.lerp(b, float(step) / 16.0)
			point.y = float(world.floor_two_probe(point).ground_height)
			_check(_body_hits(world, point).is_empty(), "each half-metre between route cells remains walkable")
	for building: Dictionary in data.buildings:
		var center: Vector2 = building.rect.get_center()
		var original := Vector3(center.x, -50, center.y)
		var recovered := world.clamp_to_playable_position(original)
		_check(world.contains_playable_position(recovered) and _body_hits(world, recovered).is_empty(), "old building-interior save recovers to a clear passage")
		_check(recovered.y > float(world.floor_two_probe(recovered).ground_height), "save recovery preserves terrain elevation")
	for cell in data.walkable_cells:
		var point := Layout.point_at_cell(cell)
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if Layout.is_walkable(cell + offset):
				continue
			var wall_point := point + Vector3(offset.x, 0, offset.y) * 4.1
			wall_point.y = float(world.floor_two_probe(wall_point).ground_height)
			_check(not _body_hits(world, wall_point).is_empty(), "map wall has matching physical collision")
	var terrain := world.get_node("Architecture/IrregularDiscGround/DiscSurface") as MeshInstance3D
	var material := terrain.material_override as StandardMaterial3D
	var color_before := material.albedo_color
	world.apply_palette({"ink": "FF0000", "muted": "00FF00", "accent": "FFFF00"})
	_check(material.albedo_color == color_before and material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "theme updates preserve authored stone texture")
	_check(material.albedo_texture.get_width() == 128 and not material.emission_enabled, "stone surface uses original 128px texture without green emission")
	_check(material.cull_mode == BaseMaterial3D.CULL_DISABLED, "original radial terrain winding remains visible from above")
	_check(world.find_child("FloorTwoWhiteExit", true, false) != null, "white building doorway exists at the F destination")
	var exit_host := world.find_child("FloorTwoWhiteExit", true, false) as Node3D
	var exit_pivot := exit_host.get_node("WhiteExitPivot") as Node3D
	_check(exit_pivot.position.is_equal_approx(Vector3(-0.56, 0, 0)), "second-floor single-door hinge keeps its source-width leaf centered")
	var exit_leaf := exit_pivot.get_node("ChapterFarGateLeaf") as Node3D
	_check(exit_leaf.scale.is_equal_approx(Vector3.ONE), "second-floor exit keeps the original tall single-door proportions")
	for turn_index in 2:
		_check(world.floor_two_probe(data.turn_points[turn_index]).checkpoint == "turn_%d" % (turn_index + 1), "journey checkpoints share exact layout cells")
	world.free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("floor two maze: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _body_hits(world: Node3D, point: Vector3) -> Array[Dictionary]:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.29
	shape.height = 1.4
	query.shape = shape
	query.transform.origin = point + Vector3.UP * 0.95
	query.collision_mask = 1
	return world.get_world_3d().direct_space_state.intersect_shape(query)

func _ground_hit(world: Node3D, point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.4, point + Vector3.DOWN * 1.0, 1)
	return world.get_world_3d().direct_space_state.intersect_ray(query)

func _distance(start: Vector2i, finish: Vector2i, excluded := Vector2i(-1, -1)) -> int:
	var queue: Array[Vector2i] = [start]
	var distances := {start: 0}
	while not queue.is_empty():
		var cell := queue.pop_front() as Vector2i
		if cell == finish:
			return int(distances[cell])
		for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + direction
			if next == excluded or not Layout.is_walkable(next) or distances.has(next):
				continue
			distances[next] = int(distances[cell]) + 1
			queue.append(next)
	return -1

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
