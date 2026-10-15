extends SceneTree

const World = preload("res://scripts/world/chapter_world.gd")
const Director = preload("res://scripts/progression/basement_loop_director.gd")
const NORMAL_DOOR_SIZE := Vector3(1.12, 2.25, 0.08)
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := World.new()
	root.add_child(world)
	var progress := _progress()
	_check(world.configure_stage(progress, {}), "production crossroads configures")
	var source: Node3D = world.imported_root
	var gate := world.get_interactable_actors()[0] as Area3D
	var pivot := world.find_child("ChapterFarGatePivot", true, false) as Node3D
	var far_z := -float(source.map_length) * 0.5 + 14.0
	_check(pivot.position.is_equal_approx(Vector3(-NORMAL_DOOR_SIZE.x * 0.5, 0, far_z)), "normal single-door hinge keeps the opening centered on the street")
	_check(gate.global_position.is_equal_approx(source.to_global(Vector3(0, 0.02, far_z + 1.1))), "F interaction actor keeps original location")
	_check(world.find_child("CrossroadsWhiteDoor", true, false) != null, "far gate reuses the existing authored white door")
	_check(pivot.find_child("OpeningDoor_Leaf", true, false) != null, "detailed source door leaf replaces the solid green box")
	var moving: Node3D = pivot.get_node("ChapterFarGateLeaf")
	_check(moving.scale.is_equal_approx(Vector3.ONE), "authored white door is not stretched horizontally or vertically")
	var leaf := pivot.find_child("OpeningDoor_Leaf", true, false) as MeshInstance3D
	# The authored mesh is 0.078 m deep; its collision adds a 1 mm margin per face.
	_check(leaf != null and leaf.get_aabb().size.is_equal_approx(Vector3(1.12, 2.25, 0.078)), "actual source leaf retains its original 1.12 by 2.25 metre dimensions")
	_check(pivot.find_children("Panel_*", "MeshInstance3D", true, false).size() == 12, "all six inset panels and their moulding move with the hinge")
	_check(pivot.find_child("Handle_RoundKnob", true, false) != null, "existing door knob remains visible")
	var frame := world.find_child("Frame_Top", true, false) as Node3D
	var light_plane := world.find_child("OpeningDoor_LightPlane", true, false) as MeshInstance3D
	_check(frame != null and not pivot.is_ancestor_of(frame), "white frame remains fixed outside the moving leaf")
	_check(light_plane != null and not pivot.is_ancestor_of(light_plane), "white portal glow remains behind the doorway")
	_check(world.find_child("ReferencePortal", true, false) == null and world.find_children("MemoryPanel*", "MeshInstance3D", true, false).is_empty(), "retired crossroads picture panels stay absent")
	var controller := world.get_door("gate")
	var blocker: CollisionShape3D = controller._blocker
	_check((blocker.shape as BoxShape3D).size.is_equal_approx(NORMAL_DOOR_SIZE), "doorway collision matches the restored single-door dimensions")
	_check(not blocker.disabled, "closed gate still blocks passage")
	await physics_frame
	_check(not _door_ray(world, source, far_z).is_empty(), "closed single door physically blocks the center of its opening")
	var missing_app := progress.duplicate(true)
	missing_app.unlocked_app_ids = ["social"]
	world.sync_progress(missing_app)
	_check(not world.interact(gate), "white gate still rejects missing notebook permission")
	var missing_task := progress.duplicate(true)
	missing_task.completed_task_ids = Director.TASK_IDS.slice(0, 4)
	world.sync_progress(missing_task)
	_check(not world.interact(gate), "white gate still requires all five basement tasks")
	world.sync_progress(progress)
	var frame_pose := frame.global_transform if frame != null else Transform3D.IDENTITY
	_check(world.interact(gate), "valid F interaction opens the white gate")
	await create_timer(0.5).timeout
	_check(controller.is_passable() and blocker.disabled, "opening releases the existing blocker")
	await physics_frame
	_check(_door_ray(world, source, far_z).is_empty(), "a player can pass through the center after the narrow door opens")
	_check(frame == null or frame.global_transform.is_equal_approx(frame_pose), "frame does not swing with the leaf")
	var requested := [0]
	world.event_requested.connect(func(event: String, _payload: Dictionary):
		if event == "crossroads_gate_requested": requested[0] += 1
	)
	# This x coordinate was inside the former 3 m trigger but is outside the
	# restored 1.12 m doorway. Walking beside the leaf must not change levels.
	var beside := gate.global_position + Vector3(1.0, 0, 0)
	world.update_authored_events(0.0, beside, Vector3.FORWARD)
	world.update_authored_events(0.1, beside + Vector3(0, 0, -3.0), Vector3.FORWARD)
	_check(requested[0] == 0, "passing beside the normal-width door cannot activate the former oversized trigger")
	# Match the production player's body and use real physics steps, so narrowing
	# the door cannot hide a leaf-collision snag behind a teleported crossing.
	var player := CharacterBody3D.new()
	player.name = "DoorPassagePlayer"
	player.collision_layer = 1
	player.collision_mask = 1
	world.add_child(player)
	var player_collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.72
	player_collision.shape = capsule
	player_collision.position.y = 0.88
	player.add_child(player_collision)
	player.global_position = gate.global_position
	world.update_authored_events(0.0, player.global_position, Vector3.FORWARD)
	for step in 90:
		await physics_frame
		player.velocity = Vector3(0, -0.5 if player.is_on_floor() else player.velocity.y - 9.8 / 60.0, -2.4)
		player.move_and_slide()
		world.update_authored_events(1.0 / 60.0, player.global_position, Vector3.FORWARD)
	var final_local := source.to_local(player.global_position)
	_check(final_local.z < far_z - 1.5, "production-size player capsule walks completely through the restored doorway without snagging")
	_check(absf(final_local.x) < 0.01 and final_local.y > -0.1, "physical door passage stays centered and on the street")
	_check(requested[0] == 1, "physical passage through the white door requests the next stage exactly once")
	print("door passage capsule radius=", capsule.radius, " height=", capsule.height, " final_local=", final_local, " gate_plane_z=", far_z, " stage_requests=", requested[0])
	world.free()
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("crossroads white gate tests passed")
	quit(0 if failures.is_empty() else 1)

func _door_ray(world: Node3D, source: Node3D, far_z: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(source.to_global(Vector3(0, 1.0, far_z + 0.6)), source.to_global(Vector3(0, 1.0, far_z - 0.6)), 1)
	return world.get_world_3d().direct_space_state.intersect_ray(query)

func _progress() -> Dictionary:
	var progress := Director.initial_progress(false)
	progress.merge({"phase": "crossroads", "round_index": 4, "transition_serial": 6, "narrator_completed": true, "opening_knock_completed": true, "opening_line_number": 30, "entrance_locked": true, "completed_task_ids": Director.TASK_IDS.duplicate(), "unlocked_app_ids": ["social", "notebook"]}, true)
	return Director.normalize_progress(progress)

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
