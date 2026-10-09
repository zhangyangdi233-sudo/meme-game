extends SceneTree

const World = preload("res://scripts/world/chapter_world.gd")
const Director = preload("res://scripts/progression/basement_loop_director.gd")
const Transition = preload("res://scripts/world/chapter_door_transition.gd")
const Door = preload("res://scripts/world/chapter_door.gd")
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var opening := World.new()
	root.add_child(opening)
	var progress: Dictionary = Director.initial_progress()
	_check(opening.configure_stage(progress, {}), "opening asset binds")
	_check(not opening.imported_root.visible, "opening begins fully black")
	var distance := opening.start_position().distance_to(opening.anchor_world_position("DoorArrival"))
	_check(distance > 27.0 and distance < 31.0, "door is about 8–9 walking seconds away")
	opening.update_authored_events(1.9, opening.start_position(), Vector3.FORWARD)
	_check(not opening.imported_root.visible, "door stays hidden during first two seconds")
	opening.update_authored_events(0.2, opening.start_position(), Vector3.FORWARD)
	_check(opening.imported_root.visible, "door appears after two seconds")
	opening.free()
	progress = Director.dispatch(progress, "opening_knock_completed", {"sequence_id": Director.OPENING_SEQUENCE_ID}).progress
	progress = Director.dispatch(progress, "opening_door_opened", {}).progress
	var world := World.new()
	root.add_child(world)
	_check(world.configure_stage(progress, {}), "basement asset binds")
	_check(world.get_node_or_null("BasementExitTunnel") == null, "basement has no detached tunnel")
	var terminal: Area3D
	for actor in world.get_interactable_actors():
		if actor.get_meta("actor_type") == "chapter1_terminal":
			terminal = actor
	_check(terminal != null, "terminal interaction exists")
	_check(not world.is_actor_reachable(terminal, terminal.global_position + Vector3(2.0, 0, 0)), "terminal cannot be opened from two metres away")
	_check(world.is_actor_reachable(terminal, terminal.global_position + Vector3(0.25, 0, 0)), "terminal works from close range")
	await _test_terminal_camera(world)
	world.free()
	await _test_door_motion()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("chapter camera revision tests passed")
	quit(0 if failures.is_empty() else 1)

func _test_door_motion() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var camera := Camera3D.new()
	host.add_child(camera)
	camera.position = Vector3(0, 1.5, 3)
	var ui := Control.new()
	host.add_child(ui)
	var pivot := Node3D.new()
	host.add_child(pivot)
	var body := StaticBody3D.new()
	host.add_child(body)
	var blocker := CollisionShape3D.new()
	blocker.shape = BoxShape3D.new()
	body.add_child(blocker)
	var door := Door.new()
	host.add_child(door)
	door.bind(pivot, blocker, 90, 1.0)
	door.set_locked(false)
	var transition := Transition.new()
	host.add_child(transition)
	transition.begin(camera, ui, door, Vector3(0, 1.5, -0.3), Vector3(0, 1.5, -2))
	await create_timer(0.55).timeout
	var before := camera.position
	await create_timer(0.25).timeout
	_check(pivot.rotation.y > 0.0 and pivot.rotation.y < PI * 0.5, "door opens slowly")
	_check(camera.position.distance_to(before) > 0.05, "camera advances while the door is opening")
	transition.cancel(false)
	host.free()

func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _test_terminal_camera(world: Node3D) -> void:
	var session: Node = load("res://scripts/ui/chapter_terminal_session.gd").new()
	root.add_child(session)
	_check(session.has_method("animate_camera_to_screen"), "terminal has eased camera travel")
	if not session.has_method("animate_camera_to_screen"):
		session.free()
		return
	session.set("_world", world)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.global_position = world.terminal_camera_position() + Vector3(1.0, 0.3, 1.0)
	var original := camera.global_transform
	session.animate_camera_to_screen(camera)
	_check(camera.global_transform.is_equal_approx(original), "CRT entry starts at the player's current view")
	await create_timer(0.3).timeout
	_check(camera.global_position.distance_to(original.origin) > 0.01, "CRT entry visibly advances")
	_check(camera.global_position.distance_to(world.terminal_camera_position()) > 0.01, "CRT entry does not teleport to screen")
	await create_timer(0.7).timeout
	_check(camera.global_position.distance_to(world.terminal_camera_position()) < 0.001, "CRT entry finishes at screen")
	var ended := [false]
	session.animate_camera_back(camera, func(): ended[0] = true)
	await create_timer(0.8).timeout
	_check(ended[0] and camera.global_transform.is_equal_approx(original), "CRT exit returns to exact original player view")
	camera.free()
	session.free()
