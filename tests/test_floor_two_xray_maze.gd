extends SceneTree

const Layout = preload("res://scripts/world/floor_two_maze_layout.gd")
var Journey = load("res://scripts/progression/floor_two_journey.gd")
const World = preload("res://scripts/reality_floor_generator.gd")
const NORMAL := 1 << 18
const XRAY := 1 << 19
var checks := 0
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var data := Layout.build()
	_check(int(data.get("version", 0)) >= 2 and data.rows.size() == 25, "expanded fixed plan uses version two and twenty-five rows")
	_check(data.has("normal_rows") and data.has("normal_blocking_rects") and data.has("xray_differences") and data.has("xray_targets"), "physical and perceived plans have explicit independent contracts")
	_check(Journey.has_method("record_xray_observation") and Journey.has_method("can_exit"), "ordered observation and exit APIs exist")
	if not data.has("xray_differences") or not Journey.has_method("record_xray_observation"):
		_finish()
		return
	var progress: Dictionary = Journey.normalize({})
	_check(Journey.record_xray_observation(progress, "xray_intro") == progress, "seeing before map tutorial cannot grant later progress")
	progress = Journey.finish_dialogue(progress, Journey.WAYFINDER)
	_check(progress.map_unlocked and progress.visited_turn_ids.is_empty(), "first NPC alone enables the three observation lessons")
	_check(not Journey.can_exit(progress), "map alone does not reveal the white exit")
	_check(Journey.record_xray_observation(progress, "exit") == progress, "exit observation cannot skip first two lessons")
	_check(Journey.record_xray_observation(progress, "unknown") == progress, "unknown world objects cannot advance a lesson")
	for id in ["xray_intro", "hidden_path", "exit"]:
		var before := progress.duplicate(true)
		progress = Journey.record_xray_observation(progress, id)
		_check(progress.xray_observed_ids.size() == before.xray_observed_ids.size() + 1 and before == Journey.normalize(before), "each observation adds exactly one ordered stage without mutating the input")
		_check(Journey.record_xray_observation(progress, id) == progress, "repeat observations are idempotent")
		_check(Journey.normalize(JSON.parse_string(JSON.stringify(progress))) == progress, "observation prefix persists through JSON")
	_check(Journey.can_exit(progress), "previously observed exit remains usable without an active gesture")
	var malformed := progress.duplicate(true)
	malformed.xray_observed_ids = ["exit", "xray_intro", "hidden_path"]
	malformed.exit_reached = true
	_check(Journey.normalize(malformed).xray_observed_ids.is_empty() and not Journey.normalize(malformed).exit_reached, "out-of-order saves cannot forge exit knowledge")
	var world := World.new()
	root.add_child(world)
	world.rebuild(2, {}, {})
	await process_frame
	await physics_frame
	data = world.get_floor_two_map_layout()
	for difference: Dictionary in data.xray_differences:
		var object := world.find_child(str(difference.id), true, false) as Node3D
		_check(object != null, "authored difference %s exists" % difference.id)
		if object == null:
			continue
		var meshes := object.find_children("*", "MeshInstance3D", true, false)
		_check(not meshes.is_empty(), "difference has actual geometry")
		for mesh: MeshInstance3D in meshes:
			_check(mesh.layers == (NORMAL if difference.normal_visible else XRAY), "difference mesh is isolated from the shared layer")
			_check(mesh.gi_mode == GeometryInstance3D.GI_MODE_DISABLED, "difference does not leak GI into ordinary space")
		var shapes := object.find_children("*", "CollisionShape3D", true, false)
		_check(not shapes.is_empty() if difference.solid else shapes.is_empty(), "collision follows fixed physical contract, not visibility")
		var rect: Rect2 = difference.rect
		var flat := rect.get_center()
		var point := Vector3(flat.x, 0, flat.y)
		point.y = float(world.floor_two_probe(point).ground_height)
		var hits := _body_hits(world, point)
		_check(not hits.is_empty() if difference.solid else hits.is_empty(), "capsule collision agrees with physical difference %s" % difference.id)
		object.hide()
		_check(_body_hits(world, point).size() == hits.size(), "hiding a difference cannot change collision")
		object.show()
		_check(bool(world.floor_two_probe(point).walkable) != bool(difference.solid), "save recovery probe matches fixed collision")
		var recovered: Vector3 = world.clamp_to_playable_position(point)
		_check(_body_hits(world, recovered).is_empty(), "recovery escapes a hidden solid wall")
	var exit_host := world.find_child("FloorTwoWhiteExit", true, false) as Node3D
	_check(exit_host != null, "white exit has an authored visual host")
	if exit_host == null:
		world.free()
		_finish()
		return
	for mesh: GeometryInstance3D in exit_host.find_children("*", "GeometryInstance3D", true, false):
		_check(mesh.layers == XRAY and mesh.gi_mode == GeometryInstance3D.GI_MODE_DISABLED, "every exit surface only renders through Xray")
	for light: Light3D in exit_host.find_children("*", "Light3D", true, false):
		_check(light.layers == XRAY and light.light_cull_mask == XRAY and is_zero_approx(light.light_energy), "exit light cannot illuminate ordinary/shared geometry")
	for target: Dictionary in data.xray_targets:
		_check(target.position.y > float(world.floor_two_probe(target.position).ground_height) + 1.2, "target %s is a visible wall/door point above ground" % target.id)
		_check(target.max_distance >= 4.0 and target.max_distance <= 12.0, "observation distance is bounded")
	world.free()
	await process_frame
	_finish()

func _body_hits(world: Node3D, point: Vector3) -> Array[Dictionary]:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.72
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = point + Vector3.UP * 0.92
	query.collision_mask = 1
	return world.get_world_3d().direct_space_state.intersect_shape(query)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func _finish() -> void:
	for failure in failures:
		push_error(failure)
	print("floor two xray maze: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
