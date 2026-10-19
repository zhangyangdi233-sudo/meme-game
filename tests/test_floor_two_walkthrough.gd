extends SceneTree

# Exercise the shipped CharacterBody3D controller continuously; route points are
# steering targets, never positions assigned to the body.
const OUTPUT := "res://artifacts/maze-xray-20261019"
const REACH_DISTANCE := 0.42
const MAX_SEGMENT_STEPS := 720
const MAX_STALLED_STEPS := 180
var checks := 0
var failures: Array[String] = []
var report := {"points": [], "samples": [], "stalls": [], "discontinuities": []}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# Keep the production 1/60 s integration interval while running eight times
	# faster in wall-clock time. This does not increase slope/step tolerance.
	Engine.time_scale = 8.0
	Engine.physics_ticks_per_second = 480
	Engine.max_physics_steps_per_frame = 32
	var main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._save_path = "user://test_floor_two_walkthrough.dat"
	main._locale.preferences_path = "user://test_floor_two_walkthrough.cfg"
	main._locale.save_preferences(80, false, false, "computer")
	root.add_child(main)
	main._resolve_camera_consent(false)
	var state = load("res://scripts/meme_game_state.gd").new()
	state.new_run()
	state.chapter1_progress = {}
	state.tower_floor = 2
	main._begin_game_session(state, {}, false)
	main._application_focused = true
	main.set_view_state("npc_up")
	var player: CharacterBody3D = main._reality_player
	var world: Node3D = main._reality_floor
	var route: Array = world.get_floor_two_map_layout().primary_route
	_check(route.size() == 91, "actual expanded primary route contains all 91 waypoints")
	_check(_route_length(route) >= 720.0, "walk the complete expanded 720 metre route")
	_check(is_equal_approx(player.get_node("PlayerCollision").shape.radius, 0.34), "use actual full-size player collision capsule")
	for frame in 60:
		await physics_frame
	_check(player.is_on_floor(), "real gravity settles the player onto the starting terrain")
	_check(is_equal_approx(main.get_physics_process_delta_time(), 1.0 / 60.0), "accelerated run retains normal 1/60 second movement integration")
	report["start"] = _vector(player.position)
	report["capsule_radius"] = player.get_node("PlayerCollision").shape.radius
	report["capsule_height"] = player.get_node("PlayerCollision").shape.height
	report["physics_delta"] = main.get_physics_process_delta_time()
	report["route_length_metres"] = _route_length(route)
	var min_standing_y := player.position.y
	var max_standing_y := player.position.y
	var min_foot_clearance := INF
	var max_foot_clearance := -INF
	var grounded_frames := 0
	var supported_frames := 0
	var total_steps := 0
	var previous_position := player.position
	for point_index in route.size():
		var target: Vector3 = route[point_index]
		var start_position := player.position
		var steps := 0
		var stalled_steps := 0
		var best_distance := _flat_distance(player.position, target)
		while _flat_distance(player.position, target) > REACH_DISTANCE and steps < MAX_SEGMENT_STEPS:
			var direction := target - player.position
			main._reality_yaw = rad_to_deg(atan2(-direction.x, -direction.z))
			Input.action_press("reality_forward")
			await physics_frame
			steps += 1
			total_steps += 1
			var travelled := player.position.distance_to(previous_position)
			if travelled > 0.25:
				report.discontinuities.append({"point": point_index, "step": total_steps, "from": _vector(previous_position), "to": _vector(player.position), "distance": travelled})
			previous_position = player.position
			min_standing_y = minf(min_standing_y, player.position.y)
			max_standing_y = maxf(max_standing_y, player.position.y)
			if player.is_on_floor():
				grounded_frames += 1
			var ground := _ground_hit(player)
			if not ground.is_empty():
				supported_frames += 1
				var foot_clearance := player.position.y + 0.02 - float(ground.position.y)
				min_foot_clearance = minf(min_foot_clearance, foot_clearance)
				max_foot_clearance = maxf(max_foot_clearance, foot_clearance)
			var distance := _flat_distance(player.position, target)
			if distance < best_distance - 0.025:
				best_distance = distance
				stalled_steps = 0
			else:
				stalled_steps += 1
			if total_steps % 12 == 0:
				report.samples.append({"step": total_steps, "point": point_index, "position": _vector(player.position), "grounded": player.is_on_floor()})
			if stalled_steps >= MAX_STALLED_STEPS:
				report.stalls.append({"point": point_index, "target": _vector(target), "position": _vector(player.position), "distance": distance, "velocity": _vector(player.velocity), "collisions": _collisions(player)})
				break
		var reached := _flat_distance(player.position, target) <= REACH_DISTANCE
		report.points.append({"index": point_index, "target": _vector(target), "start": _vector(start_position), "finish": _vector(player.position), "steps": steps, "distance": _flat_distance(player.position, target), "reached": reached})
		_check(reached, "walk continuously to route point %d %s; actual %s" % [point_index, target, player.position])
		if not reached:
			break
	Input.action_release("reality_forward")
	for frame in 60:
		await physics_frame
	_check(report.points.size() == route.size(), "visit every main-route waypoint without repositioning")
	_check(report.stalls.is_empty(), "never stall for three physics seconds on a threshold, slope, wall, or NPC")
	_check(report.discontinuities.is_empty(), "no teleport or recovery discontinuity masks a blocked path")
	_check(_flat_distance(player.position, route.back()) < 0.5, "stop within half a metre of the physical exit destination")
	_check(player.is_on_floor(), "finish standing on actual terrain")
	_check(grounded_frames == total_steps and supported_frames == total_steps, "actual ground supports the body throughout every movement step")
	_check(min_foot_clearance > -0.03 and max_foot_clearance < 0.05, "feet stay against terrain without penetration or floating")
	report["total_steps"] = total_steps
	report["simulated_walk_seconds"] = total_steps / 60.0
	report["grounded_frames"] = grounded_frames
	report["supported_frames"] = supported_frames
	report["min_standing_y"] = min_standing_y
	report["max_standing_y"] = max_standing_y
	report["min_foot_clearance"] = min_foot_clearance
	report["max_foot_clearance"] = max_foot_clearance
	report["final_position"] = _vector(player.position)
	report["checks"] = checks
	report["failures"] = failures
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var file := FileAccess.open(OUTPUT.path_join("walkthrough.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	main._set_reality_mouse_look(false)
	main.free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("floor two walkthrough %s: %d checks; %d/%d points; %d physics steps; min standing y %.4f; final %s" % ["passed" if failures.is_empty() else "FAILED", checks, report.points.size(), route.size(), total_steps, min_standing_y, report.final_position])
	quit(0 if failures.is_empty() else 1)

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

func _route_length(route: Array) -> float:
	var distance := 0.0
	for index in range(1, route.size()):
		distance += _flat_distance(route[index - 1], route[index])
	return distance

func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _collisions(player: CharacterBody3D) -> Array:
	var result := []
	for index in player.get_slide_collision_count():
		var hit := player.get_slide_collision(index)
		var collider := hit.get_collider() as Node
		result.append({"collider": str(collider.get_path()) if collider != null else "unknown", "normal": _vector(hit.get_normal()), "position": _vector(hit.get_position())})
	return result

func _ground_hit(player: CharacterBody3D) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(player.position + Vector3.UP * 0.12, player.position + Vector3.DOWN * 2.0, 1)
	query.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(query)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
