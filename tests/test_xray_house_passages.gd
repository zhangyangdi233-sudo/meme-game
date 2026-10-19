extends SceneTree

const Layout = preload("res://scripts/world/floor_two_maze_layout.gd")
const MapState = preload("res://scripts/world/exploration_map_state.gd")
var failures: Array[String] = []
var checks := 0
var journeys: Array = []

class Walker extends CharacterBody3D:
	var target := Vector3.ZERO
	var moving := false
	var steps := 0
	var grounded := 0
	var largest_step := 0.0
	func _physics_process(delta: float) -> void:
		var old_position := position
		var direction := Vector3(target.x - position.x, 0, target.z - position.z).normalized() if moving else Vector3.ZERO
		velocity.x = direction.x * 4.5
		velocity.z = direction.z * 4.5
		velocity.y = -0.2 if is_on_floor() else velocity.y - 18.0 * delta
		move_and_slide()
		if moving:
			steps += 1
			grounded += int(is_on_floor())
			largest_step = maxf(largest_step, position.distance_to(old_position))

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	Engine.time_scale = 8.0
	Engine.physics_ticks_per_second = 480
	Engine.max_physics_steps_per_frame = 32
	var world = load("res://scripts/reality_floor_generator.gd").new()
	root.add_child(world)
	world.rebuild(2, {}, {}, 1, true, {}, false)
	await physics_frame
	var layout: Dictionary = world.get_floor_two_map_layout()
	var true_map := MapState.new()
	true_map.configure(layout)
	_check(layout.version == 2, "a facade-only revision preserves the physical topology save version")
	true_map.reveal_at(layout.spawn)
	var old_exploration: Dictionary = true_map.to_save_data()
	var restored_map := MapState.new()
	restored_map.configure(layout, old_exploration)
	_check(restored_map.snapshot(layout.spawn, 0.0).explored == true_map.snapshot(layout.spawn, 0.0).explored and old_exploration.explored.count(1) > 0, "existing exploration survives the unchanged physical layout")
	var normal_layout := layout.duplicate(true)
	normal_layout.rows = layout.normal_rows
	normal_layout.blocking_rects = layout.normal_blocking_rects
	var normal_map := MapState.new()
	normal_map.configure(normal_layout)
	var true_snapshot := true_map.snapshot(layout.spawn, 0.0)
	var normal_snapshot := normal_map.snapshot(layout.spawn, 0.0)
	var camera := Camera3D.new()
	root.add_child(camera)
	for difference: Dictionary in layout.xray_differences:
		if not difference.normal_visible:
			continue
		_check(difference.kind == "false_residence", "concealed passage is a residence, not a freestanding facade")
		_check(difference.rect.size.is_equal_approx(Vector2(8, 8)), "concealed residence has the same full parcel depth as its neighbours")
		if not difference.has("residence"):
			_check(false, "concealed residence shares the ordinary building recipe")
			continue
		var house: Node3D = world.find_child(str(difference.id), true, false)
		_check(house != null, "concealed residence exists in the actual generated world")
		if house == null:
			continue
		_check(not house.has_meta("teaching_clue") and house.find_children("Frame*", "", true, false).is_empty(), "no special white frame identifies the passage")
		_check(house.find_children("RecessedResidentialDoor", "Node3D", true, false).size() == 2, "both road-facing elevations use normal residential doors")
		_check(house.find_children("Window_*", "Node3D", true, false).size() == int(difference.residence.storeys) * 4, "full storeys use the ordinary two-window frontage on both sides")
		_check(house.find_children("*", "CollisionShape3D", true, false).is_empty(), "the complete house including doors, base and roof has no collision")
		var geometry := house.find_children("*", "GeometryInstance3D", true, false)
		_check(geometry.size() > 3, "complete residence includes real shell and batched detail geometry")
		for item: GeometryInstance3D in geometry:
			_check(item.layers == Layout.NORMAL_ONLY_LAYER and item.gi_mode == GeometryInstance3D.GI_MODE_DISABLED, "all residence surfaces disappear together in X-ray without shared-layer detail leaks")
		var rect: Rect2 = difference.rect
		for z in 4:
			for x in 4:
				var flat := rect.position + Vector2(x * 2 + 1, z * 2 + 1)
				var cell := Vector2i((flat - layout.bounds.position) / 2.0)
				var index: int = cell.y * true_snapshot.columns + cell.x
				_check(normal_snapshot.walkable[index] == 0 and true_snapshot.walkable[index] == 1, "ordinary map sees the complete house footprint while the true map sees its passable road")
		var center := rect.get_center()
		var start := Vector3(center.x, 0, center.y + 6.0)
		start.y = float(world.floor_two_probe(start).ground_height) + 0.3
		var body := Walker.new()
		var collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.34
		capsule.height = 1.72
		collision.shape = capsule
		collision.position.y = 0.88
		body.add_child(collision)
		body.floor_snap_length = 0.22
		body.position = start
		root.add_child(body)
		for frame in 60:
			await physics_frame
		_check(body.is_on_floor() and is_equal_approx(body.get_physics_process_delta_time(), 1.0 / 60.0), "real capsule settles on the original terrain at the normal physics interval")
		var shapes_before: Array[Node] = world.find_children("*", "CollisionShape3D", true, false)
		for direction in [-1.0, 1.0]:
			body.target = Vector3(center.x, 0, center.y + direction * 6.0)
			body.moving = true
			var steps := 0
			while absf(body.position.z - body.target.z) > 0.25 and steps < 240:
				camera.cull_mask = 1 | (Layout.NORMAL_ONLY_LAYER if steps % 40 < 20 else Layout.XRAY_RENDER_LAYER)
				await physics_frame
				steps += 1
			body.moving = false
			_check(absf(body.position.z - body.target.z) <= 0.25, "actual capsule continuously crosses the full house in direction %s with render mode changing mid-passage" % direction)
		_check(body.grounded == body.steps, "the original ground supports every frame through the house")
		_check(body.largest_step < 0.12, "no teleport or recovery hides a blocked crossing")
		_check(world.find_children("*", "CollisionShape3D", true, false) == shapes_before, "camera changes never replace or toggle the physical scene")
		journeys.append({"id": difference.id, "steps": body.steps, "grounded": body.grounded, "largest_step": body.largest_step, "final_position": str(body.position)})
		body.free()
	camera.free()
	world.free()
	await process_frame
	var output := "res://artifacts/xray-house-passages-20261019"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	FileAccess.open(output.path_join("passages.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "journeys": journeys}, "\t"))
	for failure in failures:
		push_error(failure)
	print("xray house passages %s: %d checks, %d real capsule round trips" % ["passed" if failures.is_empty() else "FAILED", checks, journeys.size()])
	quit(0 if failures.is_empty() else 1)

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
