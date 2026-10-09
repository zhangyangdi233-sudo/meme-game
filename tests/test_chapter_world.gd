extends SceneTree

const Director = preload("res://scripts/progression/basement_loop_director.gd")
var failures: Array[String] = []
var events: Array[Dictionary] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ResourceLoader.exists("res://scripts/world/chapter_world.gd"):
		_check(false, "chapter world adapter must exist")
		_finish()
		return
	var script = load("res://scripts/world/chapter_world.gd")
	var contract := _contract_fixture()
	var progress := _basement_progress()
	var world = script.new()
	root.add_child(world)
	world.event_requested.connect(_record_event)
	_check(world.configure_stage(progress, {}, _basement_asset(contract), contract), "synthetic authored basement binds")
	_check(world.start_position().is_equal_approx(Vector3(-2.5, 2.72, -1.85)), "spawn uses actual feet anchor elevation")
	_check(is_equal_approx(world.start_yaw_degrees(), 180.0), "entry yaw follows contract")
	_check(world.contains_playable_position(world.start_position(), 1.2), "narrow landing spawn stays playable with legacy inset")
	_check(is_equal_approx(world.recovery_position(world.start_position()).y, 2.72), "recovery preserves landing height")
	_check(world.get_interactable_actors().size() == 3, "basement exposes NPC, ordinary exit and terminal")
	var npc: Area3D = world.get_interactable_actors()[0]
	_check(npc.get_meta("actor_id") == "basement_npc_01", "NPC uses stable visit ID")
	_check(not world.is_actor_reachable(npc, world.start_position()), "rear NPC is unreachable from landing through partition")
	_check(world.is_actor_reachable(npc, npc.global_position + Vector3(0, 0, 0.8)), "rear NPC is reachable at rear floor")
	world.update_authored_events(0.1, world.start_position(), Vector3.FORWARD)
	_check(events.is_empty(), "spawn alone does not seal entry")
	world.update_authored_events(0.1, Vector3(-2.5, 2.1, -0.9), Vector3.FORWARD)
	_check(_count_event("entrance_threshold_crossed") == 1, "swept first-stair crossing seals entrance")
	_check(events[0].payload.round_token == 1, "threshold captures visit serial")
	world.update_authored_events(0.1, world.start_position(), Vector3.FORWARD)
	world.update_authored_events(0.1, Vector3(-2.5, 2.1, -0.9), Vector3.FORWARD)
	_check(_count_event("entrance_threshold_crossed") == 1, "repeated threshold cannot duplicate event")
	var exit_actor: Area3D = world.get_interactable_actors()[1]
	_check(not world.interact(exit_actor), "exit cannot open before help completion")
	progress = Director.dispatch(progress, "entrance_threshold_crossed", {"round_token": 1}).progress
	world.sync_progress(progress)
	_check(not world.get_door("entry").is_passable(), "synced entrance physically sealed")
	progress = Director.dispatch(progress, "npc_help_completed", {"round_token": 1, "npc_id": "basement_npc_01", "task_id": "basement_help_01"}).progress
	world.sync_progress(progress)
	_check(world.interact(exit_actor), "help unlocks exit F request")
	_check(_count_event("basement_door_requested") == 1, "ordinary exit requests one camera transition")
	_check(not world.interact(exit_actor), "repeat F does not duplicate transition")
	_check(world.get_node_or_null("BasementExitTunnel") == null, "no detached black tunnel exists")
	_check(not world.contains_playable_position(Vector3(-10.0, 0.02, -3.43)), "removed corridor is no longer playable")
	_check(world.get_node_or_null("NextBasementThroughDoor") != null, "next entrance is visible through ordinary door")
	_check(not world.get_door("exit").is_passable(), "cinematic owns the actual door opening")
	var next_progress: Dictionary = Director.dispatch(progress, "basement_exit_requested", {"round_token": 1}).progress
	world.sync_progress(next_progress)
	_check(not world.interact(exit_actor), "stale actor cannot interact after state changes visit")
	world.free()

	var missing = script.new()
	root.add_child(missing)
	_check(not missing.configure_stage(_basement_progress(), {}, Node3D.new(), contract), "missing authored markers fail closed")
	_check(not missing.diagnostics.is_empty(), "binding failure carries explicit diagnostics")
	_check(missing.get_interactable_actors().is_empty(), "failed binding exposes no progression actions")
	missing.free()

	var translated = script.new()
	root.add_child(translated)
	translated.position = Vector3(30, 0, 20)
	_check(translated.configure_stage(_basement_progress(), {}, _basement_asset(contract), contract), "transformed host binds")
	var translated_npc: Area3D = translated.get_interactable_actors()[0]
	_check(translated.is_actor_reachable(translated_npc, translated_npc.global_position + Vector3(0, 0, 0.8)), "reachability operates in global coordinates")
	translated.free()
	var adjusted_contract := contract.duplicate(true)
	adjusted_contract.doors.exit.closed_leaf_local_center[1] = 0.72
	adjusted_contract.stairs = {"stairwell_ceiling_z": 4.0}
	var adjusted = script.new()
	root.add_child(adjusted)
	_check(adjusted.configure_stage(_basement_progress(), {}, _basement_asset(adjusted_contract), adjusted_contract), "adjusted authored contract binds")
	var adjusted_exit: Area3D = adjusted.get_interactable_actors()[1]
	_check(is_equal_approx(adjusted_exit.global_position.z, -3.62), "exit interaction follows authored leaf center")
	_check(not adjusted.contains_playable_position(Vector3(0, 4.8, 0)), "vertical bounds derive from stairwell ceiling")
	adjusted.free()
	await _test_opening(script, contract)
	await _test_opening_feet_contract(script, contract)
	await _test_crossroads(script)
	_test_imported_model_binding(script)
	_finish()

func _test_opening(script: Script, contract: Dictionary) -> void:
	events.clear()
	var opening_contract := contract.duplicate(true)
	opening_contract.opening = {"spawn_node": "PlayerSpawn", "threshold_node": "DoorArrival", "pivot_node": "OpeningDoorPivot", "spawn_eye_height": 1.65}
	opening_contract.opening_manifest = {"door": {"leaf_size_m": [1.12, 0.078, 2.25]}, "arrival": {"position_godot": [0, 0, -17.35], "area_center_godot": [0, 1.125, -17.65], "area_size_godot": [1.05, 2.25, 1.2]}}
	var asset := Node3D.new()
	for entry in [{"name": "PlayerSpawn", "position": Vector3(0, 1.65, 0)}, {"name": "DoorArrival", "position": Vector3(0, 0, -17.35)}, {"name": "OpeningDoorPivot", "position": Vector3(-0.56, 0, -18)}]:
		var marker := Node3D.new()
		marker.name = entry.name
		marker.position = entry.position
		asset.add_child(marker)
	var world = script.new()
	root.add_child(world)
	world.event_requested.connect(_record_event)
	var progress := Director.initial_progress()
	_check(world.configure_stage(progress, {}, asset, opening_contract), "opening uses explicit authored markers")
	_check(is_zero_approx(world.start_position().y), "opening eye marker converts to feet")
	var knock := world.get_node("OpeningDoorKnock") as AudioStreamPlayer3D
	var opening_actor := world.find_child("Chapter1OpeningDoor", false, false) as Area3D
	_check(not world.get_door("opening").is_passable(), "opening stays physically closed before the knock")
	_check(world.get_interactable_actors().is_empty(), "door has no F prompt before the knock finishes")
	_check(not world.interact(opening_actor), "early F cannot queue an opening request")
	world.update_authored_events(6.49, Vector3(0, 0, -17), Vector3.FORWARD)
	_check(not knock.playing and events.is_empty(), "knock cannot start before 6.5 seconds of exploration")
	world.set_exploration_paused(true)
	world.update_authored_events(30.0, Vector3(0, 0, -17), Vector3.FORWARD)
	_check(not knock.playing, "paused exploration does not count toward the knock")
	world.set_exploration_paused(false)
	world.update_authored_events(0.02, Vector3(0, 0, -19), Vector3.FORWARD)
	_check(knock.playing, "the knock begins at the authored door after 6.5 seconds")
	_check(knock.global_position.distance_to(Vector3(0, 1.125, -18)) < 0.001, "knock originates from the door leaf center")
	_check(not world.interact(opening_actor), "F remains unavailable during the knock")
	_check(events.is_empty(), "playing the knock and crossing the doorway do not request the basement")
	await create_timer(knock.stream.get_length() + 0.3).timeout
	_check(_count_event("opening_knock_completed") == 1, "finished audio emits one knock completion event")
	progress = Director.dispatch(progress, "opening_knock_completed", {"sequence_id": Director.OPENING_SEQUENCE_ID}).progress
	world.sync_progress(progress)
	_check(not world.get_door("opening").is_passable(), "synchronizing the completed knock does not open the door")
	_check(world.get_interactable_actors().size() == 1, "completed knock exposes one opening actor")
	_check(world.interact(opening_actor), "F after the knock requests the door transition")
	_check(_count_event("opening_door_requested") == 1, "F emits one transition request")
	_check(not world.interact(opening_actor), "repeat F cannot request a second transition")
	_check(world.get_interactable_actors().is_empty(), "the opening prompt disappears after its request")
	_check(not world.get_door("opening").is_passable(), "the cinematic owns opening the leaf after F")
	world.update_authored_events(0.1, Vector3(0, 0, -17), Vector3.FORWARD)
	world.update_authored_events(0.1, Vector3(0, 0, -19), Vector3.FORWARD)
	_check(_count_event("opening_door_crossed") == 0 and _count_event("opening_door_opened") == 0, "doorway movement cannot bypass the cinematic")
	world.free()

func _test_crossroads(script: Script) -> void:
	events.clear()
	var progress := _basement_progress()
	for index in 5:
		var serial := int(progress.transition_serial)
		progress = Director.dispatch(progress, "entrance_threshold_crossed", {"round_token": serial}).progress
		var current := Director.get_current_round(progress)
		progress = Director.dispatch(progress, "npc_help_completed", {"round_token": serial, "npc_id": current.npc_id, "task_id": current.task_id}).progress
		progress = Director.dispatch(progress, "basement_tunnel_entered", {"round_token": serial}).progress
		progress = Director.dispatch(progress, "basement_exit_requested", {"round_token": serial}).progress
	var world = script.new()
	root.add_child(world)
	world.event_requested.connect(_record_event)
	_check(world.configure_stage(progress, {}), "crossroads delegates existing generator")
	_check(world.get_meta("geometry_source") == "RealityFloorGenerator.floor1", "crossroads preserves original geometry source")
	_check(world.get_interactable_actors().size() == 1 and world.get_interactable_items().is_empty(), "crossroads exposes only independent far gate")
	var gate: Area3D = world.get_interactable_actors()[0]
	_check(world.contains_playable_position(gate.global_position), "far gate lies inside original playable boundary")
	_check(not world.contains_playable_position(Vector3(gate.global_position.x, -100, gate.global_position.z)), "crossroads fall below terrain is never playable")
	var missing_app := progress.duplicate(true)
	missing_app.unlocked_app_ids.pop_back()
	world.sync_progress(missing_app)
	_check(not world.interact(gate), "gate rejects missing exact application permission")
	world.sync_progress(progress)
	_check(world.interact(gate), "all earned application permissions allow gate to open")
	await create_timer(0.5).timeout
	world.update_authored_events(0.1, gate.global_position, Vector3.FORWARD)
	world.update_authored_events(0.1, gate.global_position + Vector3(0, 0, -3.0), Vector3.FORWARD)
	_check(_count_event("crossroads_gate_requested") == 1, "actual far gate crossing enters tower")
	world.free()

func _test_opening_feet_contract(script: Script, contract: Dictionary) -> void:
	var explicit_contract := contract.duplicate(true)
	explicit_contract.opening = {"spawn_node": "OpeningSpawn", "spawn_feet_blender": [0, 0, 0.04], "pivot_node": "OpeningDoorPivot", "leaf_node": "OpeningDoor_Leaf", "leaf_local_center": [0.56, 0, 1.125], "leaf_size_blender": [1.12, 0.08, 2.25], "open_blender_z_degrees": 90}
	var asset := Node3D.new()
	for entry in [{"name": "OpeningSpawn", "position": Vector3(0, 0.04, 0)}, {"name": "DoorArrival", "position": Vector3(0, 0, -17.35)}, {"name": "OpeningDoorPivot", "position": Vector3(-0.56, 0, -18)}]:
		var marker := Node3D.new()
		marker.name = entry.name
		marker.position = entry.position
		asset.add_child(marker)
	var pivot := asset.get_node("OpeningDoorPivot") as Node3D
	var leaf := MeshInstance3D.new()
	leaf.name = "OpeningDoor_Leaf"
	leaf.mesh = BoxMesh.new()
	pivot.add_child(leaf)
	var world = script.new()
	root.add_child(world)
	var progress := Director.initial_progress()
	var configured: bool = world.configure_stage(progress, {}, asset, explicit_contract)
	_check(configured, "flat v2 opening contract binds without legacy manifest")
	if configured:
		_check(is_equal_approx(world.start_position().y, 0.04), "v2 feet marker must never subtract old eye height")
		progress = Director.dispatch(progress, "opening_knock_completed", {"sequence_id": Director.OPENING_SEQUENCE_ID}).progress
		world.sync_progress(progress)
		_check(world.get_door("opening").request_open(), "cinematic can open the unlocked authored leaf")
		await create_timer(1.7).timeout
		_check(is_equal_approx(pivot.rotation_degrees.y, 90.0), "v2 door follows explicit positive opening direction")
	world.free()

func _test_imported_model_binding(script: Script) -> void:
	if not ResourceLoader.exists("res://assets/chapter1/Basement_Loop_v2.glb"):
		return
	var world = script.new()
	root.add_child(world)
	var configured: bool = world.configure_stage(_basement_progress(), {})
	_check(configured, "production basement binds: %s" % str(world.diagnostics))
	if configured:
		_check(world.start_position().distance_to(world.anchor_world_position("EntrySpawn")) < 0.001, "production spawn is actual imported marker")
		var npc: Area3D = world.get_interactable_actors()[0]
		_check(npc.global_position.distance_to(world.anchor_world_position("NPCAnchor")) < 0.001, "production NPC follows changed exporter marker")
		_check(world.get_door("entry").is_passable(), "production entry begins physically open")
		_check(not world.get_door("exit").is_passable(), "production exit begins physically locked")
		_check(world.imported_root.find_children("*", "StaticBody3D", true, false).size() > 4, "production model includes imported static collision geometry")
		var imported_lights: Array[Node] = world.imported_root.find_children("*", "Light3D", true, false)
		_check(not imported_lights.is_empty(), "production basement fixture contains the authored GLB lights")
		for imported_light: Light3D in imported_lights:
			if not bool(imported_light.get_meta("fixture_bound", false)):
				_check(not imported_light.is_visible_in_tree(), "runtime basement lighting must suppress imported physical-intensity light: %s" % imported_light.name)
		for anchor_name in ["MainLightAnchor", "RearLightAnchor"]:
			var runtime_light := world.find_child("Chapter%s" % anchor_name, true, false) as OmniLight3D
			_check(runtime_light != null and runtime_light.is_visible_in_tree() and runtime_light.light_energy > 0.0 and runtime_light.light_energy <= 2.0, "basement should use calibrated runtime lighting at %s" % anchor_name)
	world.free()
	if not ResourceLoader.exists("res://assets/chapter1/Opening_WhiteDoor_v2.glb"):
		return
	var opening = script.new()
	root.add_child(opening)
	configured = opening.configure_stage(Director.initial_progress(), {})
	_check(configured, "production opening binds: %s" % str(opening.diagnostics))
	if configured:
		_check(absf(opening.start_position().y - opening.anchor_world_position("OpeningSpawn").y) < 0.001, "production opening feet anchor remains exact")
		opening.update_authored_events(2.1, opening.start_position(), Vector3.FORWARD)
		_check(not opening.get_door("opening").is_passable(), "production opening is physically blocked before the knock and F")
		var opening_lights: Array[Node] = opening.imported_root.find_children("*", "Light3D", true, false)
		_check(not opening_lights.is_empty(), "production opening contains authored door illumination")
		for opening_light: Light3D in opening_lights:
			_check(opening_light.is_visible_in_tree(), "basement lighting override must preserve opening illumination: %s" % opening_light.name)
	opening.free()

func _contract_fixture() -> Dictionary:
	# Exact v2 geometry contract, injected so these tests need no exported GLB.
	return {
		"room": {"x_min": -3.2, "x_max": 3.2, "y_min": -4.2, "y_max": 4.2, "ceiling_z": 2.75},
		"stairs": {"stairwell_ceiling_z": 5.15},
		"partition": {"y": 2.5, "x_max": 1.65, "thickness": 0.16},
		"anchors": {
			"EntrySpawn": {"position": [-2.5, 1.85, 2.72], "godot_yaw_radians": PI},
			"EntrySealTrigger": {"position": [-2.5, 1.22, 2.46], "size": [1.25, 0.25, 2.2]},
			"NPCAnchor": {"position": [0, 3.38, 0.02]},
			"ExitThreshold": {"position": [-3.58, 3.43, 0.02], "size": [0.35, 1.02, 2.2]},
			"TVAnchor": {"position": [2.3, -3.53, 0]},
			"MainLightAnchor": {"position": [0.3, -1.5, 2.5]},
			"RearLightAnchor": {"position": [0, 3.4, 2.5]},
		},
		"doors": {
			"entry": {"pivot_node": "EntryDoorPivot", "leaf_node": "EntryDoor_Leaf", "hinge": [-3.2, 1.34, 2.7], "closed_leaf_local_center": [0, 0.53, 1.1], "leaf_size_blender": [0.055, 1.06, 2.2], "open_blender_z_degrees": 90, "initially_open": true},
			"exit": {"pivot_node": "ExitDoorPivot", "leaf_node": "ExitDoor_Leaf", "hinge": [-3.2, 2.9, 0], "closed_leaf_local_center": [0, 0.53, 1.1], "leaf_size_blender": [0.055, 1.06, 2.2], "open_blender_z_degrees": 90},
		},
	}

func _basement_progress() -> Dictionary:
	var p := Director.initial_progress()
	p = Director.dispatch(p, "opening_knock_completed", {"sequence_id": Director.OPENING_SEQUENCE_ID}).progress
	return Director.dispatch(p, "opening_door_opened").progress

func _basement_asset(contract: Dictionary) -> Node3D:
	var asset := Node3D.new()
	asset.name = "SyntheticBasement"
	for marker_name in contract.anchors:
		var marker := Node3D.new()
		marker.name = marker_name
		var xyz: Array = contract.anchors[marker_name].position
		marker.position = Vector3(xyz[0], xyz[2], -xyz[1])
		asset.add_child(marker)
	for door_id in contract.doors:
		var pivot := Node3D.new()
		pivot.name = contract.doors[door_id].pivot_node
		var xyz: Array = contract.doors[door_id].hinge
		pivot.position = Vector3(xyz[0], xyz[2], -xyz[1])
		asset.add_child(pivot)
		var leaf := MeshInstance3D.new()
		leaf.name = contract.doors[door_id].leaf_node
		leaf.mesh = BoxMesh.new()
		pivot.add_child(leaf)
	var screen := MeshInstance3D.new()
	screen.name = "TV_Screen_Video"
	screen.mesh = QuadMesh.new()
	asset.add_child(screen)
	return asset

func _record_event(event_id: String, payload: Dictionary) -> void:
	events.append({"event_id": event_id, "payload": payload.duplicate(true)})

func _count_event(event_id: String) -> int:
	var count := 0
	for event in events:
		if event.event_id == event_id:
			count += 1
	return count

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("chapter world tests passed")
	quit(0 if failures.is_empty() else 1)
