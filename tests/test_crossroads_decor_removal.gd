extends SceneTree

const PALETTE := {"bg": "B7D957", "surface": "FFF1C9", "text": "10140F", "ink": "10140F", "accent": "365B2D", "muted": "DDEB8A"}
const OUTPUT := "res://artifacts/crossroads-decor-removal-20261019"
var failures: Array[String] = []
var checks := 0
var routes: Array = []

class Walker extends CharacterBody3D:
	var target := Vector3.ZERO
	var moving := false
	var grounded_steps := 0
	var movement_steps := 0
	var min_y := INF
	var max_y := -INF

	func _physics_process(delta: float) -> void:
		var direction := Vector3(target.x - position.x, 0.0, target.z - position.z).normalized() if moving else Vector3.ZERO
		velocity.x = direction.x * 6.0
		velocity.z = direction.z * 6.0
		velocity.y = -0.2 if is_on_floor() else velocity.y - 18.0 * delta
		move_and_slide()
		if moving:
			movement_steps += 1
			grounded_steps += int(is_on_floor())
			min_y = minf(min_y, position.y)
			max_y = maxf(max_y, position.y)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# Preserve the usual 1/60 s collision integration while accelerating the test.
	Engine.time_scale = 8.0
	Engine.physics_ticks_per_second = 480
	Engine.max_physics_steps_per_frame = 32
	for floor_number in [1, 4]:
		await _test_floor(floor_number)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var file := FileAccess.open(OUTPUT.path_join("passage-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "routes": routes}, "\t"))
	file.close()
	for failure in failures:
		push_error(failure)
	print("crossroads decor removal %s: %d checks; %d continuous four-arm routes" % ["passed" if failures.is_empty() else "FAILED", checks, routes.size()])
	quit(0 if failures.is_empty() else 1)

func _test_floor(floor_number: int) -> void:
	var world = load("res://scripts/reality_floor_generator.gd").new()
	root.add_child(world)
	world.rebuild(floor_number, PALETTE, {}, 1, true, {}, false)
	for pattern in ["DreamcoreThresholdRhythm", "ThresholdBeam*", "CeilingLightSlot*", "ThresholdLight*", "FalseDoor*"]:
		_check(world.find_children(pattern, "", true, false).is_empty(), "floor %d has no %s decoration" % [floor_number, pattern])
	_check(not world.find_children("BrickTurn", "StaticBody3D", true, false).is_empty(), "floor %d retains its colliding small yellow walls" % floor_number)
	_check(world.find_child("CrossRoad", true, false) != null and world.find_child("CrossroadGround", true, false) != null, "floor %d retains visible road and colliding ground" % floor_number)
	_check(int(world.get_meta("terrain_boundary_wall_count")) == 12, "floor %d retains every boundary wall" % floor_number)
	var body := Walker.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.72
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.88
	body.add_child(collision)
	body.floor_snap_length = 0.22
	body.position = Vector3(-50.0, 0.5, 0.0)
	root.add_child(body)
	for frame in 60:
		await physics_frame
	_check(body.is_on_floor(), "floor %d capsule settles on real ground" % floor_number)
	_check(is_equal_approx(body.get_physics_process_delta_time(), 1.0 / 60.0), "floor %d uses normal physics timestep" % floor_number)
	var points: Array = []
	# Start on the west branch, cross the middle, then walk both trunk arms.
	for target in [Vector3(50, 0, 0), Vector3.ZERO, Vector3(0, 0, -60), Vector3(0, 0, 60), Vector3.ZERO]:
		body.target = target
		body.moving = true
		var steps := 0
		while Vector2(body.position.x - target.x, body.position.z - target.z).length() > 0.35 and steps < 1600:
			await physics_frame
			steps += 1
		body.moving = false
		var reached := Vector2(body.position.x - target.x, body.position.z - target.z).length() <= 0.35
		_check(reached, "floor %d continuously reaches %s without teleporting; actual %s" % [floor_number, target, body.position])
		points.append({"target": _vector(target), "finish": _vector(body.position), "steps": steps, "reached": reached})
		if not reached:
			break
	_check(body.grounded_steps == body.movement_steps, "floor %d has continuous ground support across all four arms" % floor_number)
	routes.append({"floor": floor_number, "points": points, "movement_steps": body.movement_steps, "grounded_steps": body.grounded_steps, "min_y": body.min_y, "max_y": body.max_y, "final_position": _vector(body.position)})
	body.free()
	world.free()
	await process_frame

func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
