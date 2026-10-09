extends SceneTree

const World = preload("res://scripts/world/chapter_world.gd")
const Binding = preload("res://scripts/world/chapter_asset_binding.gd")
const Director = preload("res://scripts/progression/basement_loop_director.gd")
const LABELS := ["护灯人", "迟到者", "回声住户", "抄写员", "无名信徒"]
const APP_IDS := ["social", "notebook"]

var failures: Array[String] = []
var checks := 0
var events: Array[Dictionary] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(World.CONTRACT_PATH))
	var textures := _textures()
	_test_round_identities(contract, textures)
	_test_terminal(contract)
	_test_crossroads_gate()
	await _test_authored_terminal()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("chapter tutorial world tests passed (%d checks)" % checks)
	quit(0 if failures.is_empty() else 1)


func _test_round_identities(contract: Dictionary, textures: Dictionary) -> void:
	var world = World.new()
	root.add_child(world)
	var accepts_textures := _accepts_textures(world)
	_check(accepts_textures, "configure_stage appends optional actor_textures as fifth argument")
	for index in 5:
		var progress := _progress(index)
		var configured: bool
		if accepts_textures:
			configured = world.call("configure_stage", progress, {}, _asset(contract), contract, textures)
		else:
			configured = world.configure_stage(progress, {}, _asset(contract), contract)
		_check(configured, "round %d binds" % (index + 1))
		var npcs := _actors_of_type(world, "chapter1_npc")
		_check(npcs.size() == 1, "round %d exposes exactly its one NPC" % (index + 1))
		if npcs.size() != 1:
			continue
		var npc: Area3D = npcs[0]
		var source_type := "key_npc" if index == 0 else "npc"
		var source_name := "KeyNPC" if index == 0 else "NPC%d" % (index - 1)
		_check(npc.get_meta("actor_id") == Director.NPC_IDS[index], "stable NPC ID remains round-specific")
		_check(npc.get_meta("task_id") == Director.TASK_IDS[index], "stable task ID remains round-specific")
		_check(npc.get_meta("source_actor_id", "") == "%s_1_%s" % [source_type, source_name.to_lower()], "canonical legacy source actor ID survives")
		_check(npc.get_meta("source_actor_type", "") == source_type, "source actor type survives")
		_check(npc.get_meta("source_actor_index", -99) == index - 1, "source index avoids NPC0 fallback")
		_check(npc.get_meta("display_name", "") == LABELS[index], "original first-floor display name survives")
		var billboard := npc.get_node_or_null("Billboard") as Sprite3D
		var expected: Texture2D = textures.key_npc if index == 0 else textures.npcs[index - 1]
		_check(billboard != null and billboard.texture == expected, "current NPC uses its original supplied texture")
		_check(npc.global_position.is_equal_approx(world.anchor_world_position("NPCAnchor")), "NPC feet stay on actual authored marker")
		_check(_actors_of_type(world, "chapter1_terminal").size() == 1, "rebuild retains one terminal without accumulating NPCs")
	world.free()


func _test_terminal(contract: Dictionary) -> void:
	events.clear()
	var world = World.new()
	root.add_child(world)
	world.position = Vector3(20, 0.4, -11)
	world.rotation.y = 0.7
	world.event_requested.connect(func(id: String, payload: Dictionary): events.append({"id": id, "payload": payload}))
	var progress := _progress(2)
	_check(world.configure_stage(progress, {}, _asset(contract), contract), "terminal binds in transformed host using original four arguments")
	var terminals := _actors_of_type(world, "chapter1_terminal")
	_check(terminals.size() == 1, "basement has one CRT terminal actor")
	var has_interfaces := true
	for method in ["get_video_screen", "get_screen_mesh", "terminal_camera_position", "terminal_camera_target"]:
		_check(world.has_method(method), "terminal API exists: %s" % method)
		has_interfaces = has_interfaces and world.has_method(method)
	if has_interfaces:
		var art: Dictionary = contract.art_direction
		var center: Vector3 = world.imported_root.to_global(Binding.blender_vector(art.crt_screen_center_blender))
		var forward: Vector3 = (world.imported_root.global_basis * Binding.blender_vector(art.crt_screen_forward_blender)).normalized()
		_check(world.get_video_screen() == world.get_node("ChapterVideoScreen"), "terminal exposes the existing sole video controller")
		_check(world.get_screen_mesh() == world.imported_root.get_node("TV_Screen_Video"), "terminal exposes actual authored screen mesh")
		_check(world.terminal_camera_target().is_equal_approx(center), "camera target follows contract front center in global coordinates")
		var camera_offset: Vector3 = world.terminal_camera_position() - center
		_check(camera_offset.normalized().is_equal_approx(forward), "camera is squarely in front of the authored screen")
		_check(camera_offset.length() >= 0.22 and camera_offset.length() <= 0.55, "CRT close-up uses bounded near-screen distance")
		var projected_height := 0.375 / (2.0 * camera_offset.length() * tan(deg_to_rad(29.0)))
		_check(absf(projected_height - 0.72) < 0.01, "screen occupies about 72 percent of a 58 degree view height")
		if terminals.size() == 1:
			var terminal: Area3D = terminals[0]
			var offset: Vector3 = terminal.global_position - center
			var planar_offset := Vector3(offset.x, 0, offset.z)
			_check(planar_offset.distance_to(forward * 1.0) < 0.05, "terminal stands about one metre in front of CRT")
			_check(is_equal_approx(terminal.global_position.y, world.global_position.y + 0.02), "terminal interaction origin stays at floor feet")
			_check(world.contains_playable_position(terminal.global_position), "terminal stand point stays in basement")
			_check(world.is_actor_reachable(terminal, terminal.global_position + forward * 0.5), "terminal is reachable from its walk-up side")
			_check(not world.is_actor_reachable(terminal, terminal.global_position + forward * 1.2), "terminal requires the player inside the reduced 1.15 metre reach")
			_check(terminal.find_children("*", "StaticBody3D", true, false).is_empty(), "terminal adds no blocking cabinet/body collider")
			_check(world.interact(terminal), "F requests CRT tutorial")
			_check(events.size() == 1 and events[0].id == "terminal_requested" and events[0].payload.get("round_token") == 3, "terminal event binds current round token")
			world.set_exploration_paused(true)
			_check(not world.interact(terminal), "paused exploration cannot send another terminal event")
			world.set_exploration_paused(false)
			world.sync_progress(_progress(3))
			_check(not world.interact(terminal), "stale terminal cannot request next visit's tutorial")
	world.free()


func _test_crossroads_gate() -> void:
	var progress := _progress(4)
	progress.phase = "crossroads"
	progress.transition_serial = 6
	progress.completed_task_ids = Director.TASK_IDS.duplicate()
	var cases := [
		{"apps": [], "items": ["chapter1_gate_item_01", "chapter1_gate_item_02", "chapter1_gate_item_03"], "tasks": Director.TASK_IDS.duplicate(), "ready": false, "label": "legacy gate items cannot grant phone permissions"},
		{"apps": ["social"], "items": [], "tasks": Director.TASK_IDS.duplicate(), "ready": false, "label": "missing notebook permission keeps gate closed"},
		{"apps": ["notebook"], "items": [], "tasks": Director.TASK_IDS.duplicate(), "ready": false, "label": "missing social permission keeps gate closed"},
		{"apps": APP_IDS.duplicate(), "items": [], "tasks": Director.TASK_IDS.slice(0, 4), "ready": false, "label": "permissions without all five tasks keep gate closed"},
		{"apps": APP_IDS.duplicate(), "items": [], "tasks": Director.TASK_IDS.duplicate(), "ready": true, "label": "both app permissions and five tasks open gate without keys or retired Babel app"},
	]
	for scenario in cases:
		progress.unlocked_app_ids = scenario.apps
		progress.gate_item_ids = scenario.items
		progress.completed_task_ids = scenario.tasks
		var world = World.new()
		root.add_child(world)
		_check(world.configure_stage(progress, {}), "crossroads configures")
		var actors: Array = world.get_interactable_actors()
		_check(actors.size() == 1 and actors[0].get_meta("actor_type") == "chapter1_gate", "crossroads has only the independent far gate")
		_check(world.get_interactable_items().is_empty(), "crossroads exposes no task pickup hotspots")
		_check(world.imported_root.get_interactable_actors().is_empty() and world.imported_root.get_interactable_items().is_empty(), "original generator population remains empty")
		_check(world.find_child("CrossRoad", true, false) != null and world.find_child("CrossroadGround", true, false) != null, "original crossroads geometry and collision remain")
		_check(world.interact(actors[0]) == scenario.ready, scenario.label)
		world.free()


func _test_authored_terminal() -> void:
	var world = World.new()
	root.add_child(world)
	_check(world.configure_stage(_progress(0), {}), "actual GLB binds the tutorial world")
	var terminals := _actors_of_type(world, "chapter1_terminal")
	_check(terminals.size() == 1, "actual GLB gets one terminal")
	if terminals.size() == 1:
		await physics_frame
		var terminal: Area3D = terminals[0]
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.22
		capsule.height = 1.70
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY, terminal.global_position + Vector3(0, 0.88, 0))
		query.collision_mask = 1
		_check(world.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "actual CRT stand point fits player capsule without cabinet/chair collision")
	world.free()


func _actors_of_type(world: Node, actor_type: String) -> Array[Area3D]:
	var result: Array[Area3D] = []
	for actor: Area3D in world.get_interactable_actors():
		if actor.get_meta("actor_type", "") == actor_type:
			result.append(actor)
	return result


func _progress(index: int) -> Dictionary:
	var progress := Director.initial_progress()
	progress.phase = "basement"
	progress.narrator_completed = true
	progress.opening_knock_completed = true
	progress.entrance_locked = true
	progress.round_index = index
	progress.transition_serial = index + 1
	progress.completed_task_ids = Director.TASK_IDS.slice(0, index)
	return progress


func _asset(contract: Dictionary) -> Node3D:
	var asset := Node3D.new()
	asset.name = "SyntheticTutorialBasement"
	for marker_name in Binding.required_names("basement", contract):
		var marker := Node3D.new()
		marker.name = marker_name
		if contract.anchors.has(marker_name):
			marker.position = Binding.blender_vector(contract.anchors[marker_name].position)
		for data: Dictionary in contract.doors.values():
			if data.pivot_node == marker_name:
				marker.position = Binding.blender_vector(data.hinge)
		asset.add_child(marker)
	var screen := MeshInstance3D.new()
	screen.name = "TV_Screen_Video"
	var screen_quad := QuadMesh.new()
	screen_quad.size = Vector2(0.5, 0.375)
	screen.mesh = screen_quad
	asset.add_child(screen)
	return asset


func _textures() -> Dictionary:
	var textures: Array[Texture2D] = []
	for index in 5:
		var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		image.fill(Color.from_hsv(float(index) / 5.0, 0.5, 0.8))
		textures.append(ImageTexture.create_from_image(image))
	return {"key_npc": textures[0], "npcs": textures.slice(1)}


func _accepts_textures(world: Node) -> bool:
	for info in world.get_method_list():
		if info.name == "configure_stage":
			return info.args.size() == 5
	return false


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
