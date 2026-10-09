extends Node3D
## Authored chapter host. Spatial APIs use world coordinates; feet positions retain
## the authored elevation. No marker or missing v2 model is silently substituted.

signal cover_watcher_appeared(floor_number: int)
signal cover_watcher_vanished(floor_number: int)
signal event_requested(event_id: String, payload: Dictionary)

const Binding = preload("res://scripts/world/chapter_asset_binding.gd")
const Door = preload("res://scripts/world/chapter_door.gd")
const VideoScreen = preload("res://scripts/world/chapter_video_screen.gd")
const Director = preload("res://scripts/progression/basement_loop_director.gd")
const Generator = preload("res://scripts/reality_floor_generator.gd")
const Atmosphere = preload("res://scripts/world/basement_atmosphere.gd")
const CONTRACT_PATH := "res://assets/chapter1/asset_contract.json"
const OPENING_MANIFEST_PATH := "res://assets/chapter1/opening_manifest.json"
const MODEL_PATHS := {"opening": "res://assets/chapter1/Opening_WhiteDoor_v2.glb", "basement": "res://assets/chapter1/Basement_Loop_v2.glb"}
const BODY_CENTER := Vector3(0, 0.88, 0)
const REACH_DISTANCE := 3.0
const OPENING_WAIT_SECONDS := 6.5
const OPENING_BLACK_SECONDS := 2.0
const OPENING_WALK_DISTANCE := 29.5
const TERMINAL_REACH_DISTANCE := 1.15
const OPENING_KNOCK_PATH := "res://assets/audio/sfx/opening_door_knock.ogg"
const XRAY_RENDER_LAYER := 1 << 19
const BASEMENT_NPC_NAMES := ["护灯人", "迟到者", "回声住户", "抄写员", "无名信徒"]

var diagnostics: Array[String] = []
var stage_ready := false
var stage := ""
var imported_root: Node3D:
	get:
		return _asset
var _progress: Dictionary = {}
var _contract: Dictionary = {}
var _actor_textures: Dictionary = {}
var _asset: Node3D
var _delegate: Node3D
var _spawn := Vector3.ZERO
var _spawn_yaw := 0.0
var _bound_token := -1
var _bound_round := -1
var _actors: Array[Area3D] = []
var _doors: Dictionary = {}
var _triggers: Dictionary = {}
var _emitted: Dictionary = {}
var _previous_position := Vector3.ZERO
var _has_previous := false
var _playtest_assist := false
var _video: Node3D
var _screen_mesh: MeshInstance3D
var _terminal_center := Vector3.ZERO
var _terminal_front := Vector3.FORWARD
var _bounds: Array[AABB] = []
var _opening_plane_z := 0.0
var _gate_plane_z := 0.0
var _opening_elapsed := 0.0
var _opening_knock_started := false
var _opening_requested := false
var _exploration_paused := false
var _opening_knock: AudioStreamPlayer3D
var _opening_actor: Area3D
var _exit_requested := false
var _next_room_preview: Node3D
var _exit_camera_pose := Transform3D.IDENTITY
var _atmosphere: Node3D
var _palette: Dictionary = {}
var _destination_camera: Camera3D
var _destination_frame := Transform3D.IDENTITY
var _destination_mapping := Transform3D.IDENTITY
var _destination_material: ShaderMaterial
var _destination_viewport: SubViewport


func _process(_delta: float) -> void:
	# 3D playback starts on a physics frame; a pause requested in the same
	# frame as play() must also be applied once the audio playback exists.
	if _opening_knock_started and is_instance_valid(_opening_knock) and _opening_knock.stream_paused != _exploration_paused:
		_opening_knock.stream_paused = _exploration_paused
	if is_instance_valid(_destination_camera):
		_update_destination_portal()


func configure_stage(progress: Dictionary, palette: Dictionary, imported_root: Node3D = null, injected_contract: Dictionary = {}, actor_textures: Dictionary = {}) -> bool:
	_clear_stage()
	_progress = progress.duplicate(true)
	_actor_textures = actor_textures.duplicate()
	_palette = palette.duplicate(true)
	stage = str(progress.get("phase", ""))
	_bound_token = int(progress.get("transition_serial", -1))
	_bound_round = int(progress.get("round_index", -1))
	_contract = injected_contract.duplicate(true) if not injected_contract.is_empty() else _read_dictionary(CONTRACT_PATH)
	if stage == "crossroads":
		_build_crossroads(palette)
		stage_ready = true
		sync_progress(progress)
		return true
	if stage not in MODEL_PATHS:
		return _fail("Unsupported authored chapter stage: %s" % stage)
	if _contract.is_empty():
		return _fail("Missing or invalid chapter asset contract: %s" % CONTRACT_PATH)
	if imported_root != null:
		_asset = imported_root
	else:
		var model_path: String = MODEL_PATHS[stage]
		if not ResourceLoader.exists(model_path):
			return _fail("Required authored v2 model is unavailable: %s" % model_path)
		var scene := load(model_path) as PackedScene
		if scene == null:
			return _fail("Chapter model did not import as PackedScene: %s" % model_path)
		_asset = scene.instantiate() as Node3D
	if _asset == null:
		return _fail("Chapter model must have a Node3D root")
	_isolate_xray_marks(_asset)
	add_child(_asset)
	diagnostics.append_array(Binding.validate(_asset, stage, _contract))
	if not diagnostics.is_empty():
		return false
	var configured := _build_basement() if stage == "basement" else _build_opening()
	if not configured:
		return false
	_build_environment()
	if stage == "basement":
		_atmosphere = Atmosphere.new()
		_atmosphere.name = "BasementAtmosphere"
		add_child(_atmosphere)
		_atmosphere.configure(_asset, _contract, _progress)
		var switch_actor: Area3D = _atmosphere.interaction_actor()
		if switch_actor != null:
			_actors.append(switch_actor)
		_build_next_room_preview()
	stage_ready = true
	sync_progress(progress)
	return true


func _isolate_xray_marks(node: Node, inherited: bool = false) -> void:
	var marked := inherited or _has_xray_metadata(node) or _is_contract_xray_guide(str(node.name))
	if marked and node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.layers = XRAY_RENDER_LAYER
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		geometry.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	for child in node.get_children():
		_isolate_xray_marks(child, marked)


func _has_xray_metadata(node: Node) -> bool:
	var direct_flag: Variant = node.get_meta("xray_only", false)
	if direct_flag is bool and direct_flag:
		return true
	# glTF importers may retain custom extras as one metadata dictionary instead
	# of promoting each field to an individual node metadata entry.
	for metadata_key in ["extras", "gltf_extras"]:
		var extras: Variant = node.get_meta(metadata_key, {})
		if extras is Dictionary:
			var extra_flag: Variant = extras.get("xray_only", false)
			if extra_flag is bool and extra_flag:
				return true
	return false


func _is_contract_xray_guide(node_name: String) -> bool:
	var guides: Variant = _contract.get("xray_guides", [])
	if guides is Dictionary:
		guides = guides.get("nodes", [])
	if guides is Array:
		for guide in guides:
			if guide is String and guide == node_name:
				return true
	var exit_guides: Variant = _contract.get("xray_exit_guides", {})
	if exit_guides is Dictionary:
		var marks: Variant = exit_guides.get("marks", [])
		if marks is Array:
			for mark in marks:
				if mark is Dictionary:
					for name_key in ["root", "mesh"]:
						var marked_name: Variant = mark.get(name_key, "")
						if marked_name is String and marked_name == node_name:
							return true
	return false


func sync_progress(progress: Dictionary) -> void:
	_progress = progress.duplicate(true)
	if not stage_ready or not _current_visit():
		return
	if stage == "opening":
		_doors.opening.set_locked(not bool(progress.get("opening_knock_completed", false)))
	elif stage == "basement":
		if bool(progress.get("entrance_locked", false)):
			_doors.entry.close_and_lock()
		_doors.exit.set_locked(not _help_completed())


func _build_basement() -> bool:
	_spawn = _anchor("EntrySpawn")
	_spawn_yaw = rad_to_deg(float(_contract.anchors.EntrySpawn.get("godot_yaw_radians", PI))) + _asset.global_rotation_degrees.y
	var room: Dictionary = _contract.get("room", {})
	if room.is_empty():
		return _fail("Basement contract has no room bounds")
	var stairs: Dictionary = _contract.get("stairs", {})
	var ceiling := maxf(float(room.get("ceiling_z", 2.75)), float(stairs.get("stairwell_ceiling_z", 5.15)))
	_bounds.append(AABB(Vector3(float(room.x_min), -0.3, -float(room.y_max)), Vector3(float(room.x_max) - float(room.x_min), ceiling + 0.55, float(room.y_max) - float(room.y_min))))
	# Authored exit is outside the left wall. Include only its short exterior pad,
	# so crossing the exit never collides with legacy out-of-map recovery first.
	var exit_local := _asset.to_local(_anchor("ExitThreshold"))
	_bounds.append(AABB(Vector3(exit_local.x - 0.8, -0.3, exit_local.z - 0.64), Vector3(1.3, 2.8, 1.28)))
	for door_id in ["entry", "exit"]:
		if not _bind_door(door_id, _contract.doors[door_id], 0.0 if door_id == "entry" else 2.1):
			return false
	_doors.entry.set_locked(false)
	_doors.entry.request_open()
	for trigger_id in ["EntrySealTrigger", "ExitThreshold"]:
		var size := Binding.blender_size(_contract.anchors[trigger_id].size)
		_triggers[trigger_id] = AABB(_asset.to_local(_anchor(trigger_id)) + Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), size)
	var current: Dictionary = Director.get_current_round(_progress)
	if current.is_empty():
		return _fail("Basement stage has no valid current visit")
	_build_current_npc(current)
	var exit_pivot := Binding.find_node(_asset, str(_contract.doors.exit.pivot_node)) as Node3D
	var exit_center := Binding.blender_vector(_contract.doors.exit.closed_leaf_local_center)
	var exit_size := Binding.blender_size(_contract.doors.exit.leaf_size_blender)
	var normal := Vector3.RIGHT if exit_size.x < exit_size.z else Vector3.BACK
	var room_center := _asset.to_global(Vector3((float(room.x_min) + float(room.x_max)) * 0.5, 0, -(float(room.y_min) + float(room.y_max)) * 0.5))
	if (room_center - exit_pivot.to_global(exit_center)).dot(exit_pivot.global_basis * normal) < 0.0:
		normal = -normal
	var exit_position := exit_pivot.to_global(exit_center + normal * 0.55 - Vector3.UP * (exit_size.y * 0.5 - 0.02))
	_make_actor("chapter1_basement_exit", "chapter1_exit", exit_position, "ExitDoor")
	var screen := _find_video_screen(_asset)
	if screen == null:
		return _fail("Basement model requires a mesh whose name contains Screen_Video")
	_screen_mesh = screen
	_video = VideoScreen.new()
	_video.name = "ChapterVideoScreen"
	add_child(_video)
	_video.bind_screen(screen)
	var art_direction: Dictionary = _contract.get("art_direction", {})
	var crt_color := Color(str(art_direction.get("crt_standby_srgb", "#4CFF66")))
	_video.set_standby_color(crt_color)
	var screen_glow := OmniLight3D.new()
	screen_glow.name = "ChapterCRTGreenGlow"
	screen_glow.light_color = crt_color
	screen_glow.light_energy = 0.48
	screen_glow.omni_range = 2.25
	# This represents broad phosphor spill, not a small hard-shadow bulb in
	# front of the cabinet. Room lamps retain their normal scene shadows.
	screen_glow.shadow_enabled = false
	_video.add_child(screen_glow)
	var screen_center := screen.to_global(screen.get_aabb().get_center())
	var screen_front := room_center - screen_center
	screen_front.y = 0.0
	if art_direction.has("crt_screen_center_blender") and art_direction.has("crt_screen_forward_blender"):
		screen_center = _asset.to_global(Binding.blender_vector(art_direction.crt_screen_center_blender))
		screen_front = _asset.global_basis * Binding.blender_vector(art_direction.crt_screen_forward_blender)
	screen_front = screen_front.normalized()
	screen_glow.global_position = screen_center + screen_front * 0.22
	_video.power_changed.connect(func(powered_on: bool): screen_glow.visible = powered_on)
	screen_glow.visible = _video.is_powered_on()
	_terminal_center = screen_center
	_terminal_front = screen_front
	var terminal_feet := _asset.to_local(screen_center + screen_front)
	terminal_feet.y = 0.02
	_make_actor("chapter1_terminal", "chapter1_terminal", _asset.to_global(terminal_feet), "CRT 教学端（开发）")
	if not _open_exit_pocket():
		return false
	return true


func _open_exit_pocket() -> bool:
	# The extra exterior box is not a room. Remove its geometry and matching
	# colliders in this instance, leaving the authored frame and door untouched.
	var pocket_bounds: Array[AABB] = []
	for mesh: MeshInstance3D in _asset.find_children("Exit_Vestibule*", "MeshInstance3D", true, false):
		pocket_bounds.append(mesh.global_transform * mesh.get_aabb())
		mesh.hide()
	# Godot strips the -colonly source name on these imported siblings. Match
	# the exact authored mesh bounds, not unstable generated @StaticBody IDs.
	for collider: CollisionShape3D in _asset.find_children("*", "CollisionShape3D", true, false):
		var local_box: AABB
		if collider.shape is ConcavePolygonShape3D:
			var faces := (collider.shape as ConcavePolygonShape3D).get_faces()
			if faces.is_empty():
				continue
			local_box = AABB(faces[0], Vector3.ZERO)
			for point in faces:
				local_box = local_box.expand(point)
		elif collider.shape is BoxShape3D:
			var size := (collider.shape as BoxShape3D).size
			local_box = AABB(-size * 0.5, size)
		else:
			continue
		var world_box: AABB = collider.global_transform * local_box
		for target in pocket_bounds:
			if world_box.position.distance_to(target.position) < 0.02 and world_box.size.distance_to(target.size) < 0.02:
				collider.disabled = true
	set_meta("exit_pocket_opened", true)
	return true


func _build_next_room_preview() -> void:
	if _bound_round == 4:
		_build_crossroads_portal()
		return
	# Align a visual copy of the next entrance with this exit. It has no gameplay
	# actors or collision and is replaced with the real next visit at its spawn.
	_next_room_preview = _asset.duplicate() as Node3D
	_next_room_preview.name = "NextBasementThroughDoor"
	add_child(_next_room_preview)
	if is_instance_valid(_atmosphere):
		for child in _atmosphere.get_children():
			if child is Node3D and not child is CollisionObject3D:
				_next_room_preview.add_child(child.duplicate())
	# The preview is scenery for a door cinematic, never another source of live
	# clues. Keep both authored arrows and atmospheric X-ray marks in this visit.
	for geometry: GeometryInstance3D in _next_room_preview.find_children("*", "GeometryInstance3D", true, false):
		if is_instance_valid(geometry) and (geometry.layers & XRAY_RENDER_LAYER) != 0:
			geometry.free()
	var entry_data: Dictionary = _contract.doors.entry
	var exit_data: Dictionary = _contract.doors.exit
	var entry_pivot := Binding.find_node(_asset, str(entry_data.pivot_node)) as Node3D
	var exit_pivot := Binding.find_node(_asset, str(exit_data.pivot_node)) as Node3D
	# Door pivots may already be opened. Their contract centre is closed-space.
	var entry_center := entry_pivot.position + Binding.blender_vector(entry_data.closed_leaf_local_center)
	var exit_center := exit_pivot.position + Binding.blender_vector(exit_data.closed_leaf_local_center)
	var turn := Basis(Vector3.UP, PI)
	_next_room_preview.global_transform = _asset.global_transform * Transform3D(turn, exit_center - turn * entry_center)
	for body: CollisionObject3D in _next_room_preview.find_children("*", "CollisionObject3D", true, false):
		body.collision_layer = 0
		body.collision_mask = 0
	for light: Light3D in _next_room_preview.find_children("*", "Light3D", true, false):
		if not bool(light.get_meta("fixture_bound", false)):
			light.hide()
	var preview_entry := Binding.find_node(_next_room_preview, str(entry_data.pivot_node)) as Node3D
	if preview_entry != null:
		preview_entry.hide()
	var eye := _asset.to_local(_spawn) + Vector3(0, 1.56, 0)
	var direction := Basis(Vector3.UP, deg_to_rad(_spawn_yaw) - _asset.global_rotation.y) * Vector3.FORWARD
	var arrival_basis := Basis.looking_at(direction, Vector3.UP) * Basis(Vector3.RIGHT, deg_to_rad(-28.0))
	_exit_camera_pose = _next_room_preview.global_transform * Transform3D(arrival_basis, eye)


func _build_crossroads_portal() -> void:
	# The final door opens into the actual destination renderer. A portal-sized
	# frustum keeps this wide outdoor world inside the physical door aperture;
	# its camera reaches the exact receiving spawn as our camera reaches the leaf.
	_next_room_preview = Node3D.new()
	_next_room_preview.name = "NextBasementThroughDoor"
	_next_room_preview.set_meta("destination", "crossroads")
	add_child(_next_room_preview)
	var viewport := SubViewport.new()
	_destination_viewport = viewport
	viewport.name = "CrossroadsPortalViewport"
	viewport.size = Vector2i(384, 800)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_next_room_preview.add_child(viewport)
	var destination := Generator.new()
	viewport.add_child(destination)
	destination.rebuild(1, _palette, {}, 1, true, {}, false)
	_destination_camera = Camera3D.new()
	destination.add_child(_destination_camera)
	_destination_camera.current = true
	_destination_camera.cull_mask = 0xFFFFF & ~XRAY_RENDER_LAYER
	var arrival_eye: Vector3 = destination.start_position() + Vector3(0, 1.56, 0)
	var arrival_basis := Basis(Vector3.UP, deg_to_rad(destination.start_yaw_degrees()))
	var arrival_pose := Transform3D(arrival_basis, arrival_eye)
	var exit_data: Dictionary = _contract.doors.exit
	var pivot := Binding.find_node(_asset, str(exit_data.pivot_node)) as Node3D
	var center := pivot.position + Binding.blender_vector(exit_data.closed_leaf_local_center)
	_destination_frame = _asset.global_transform * Transform3D(Basis(Vector3.UP, PI * 0.5), center)
	_next_room_preview.global_transform = _destination_frame
	_exit_camera_pose = _destination_frame * Transform3D(Basis.IDENTITY, Vector3(0, 0.46, 0.03))
	_destination_mapping = arrival_pose * _exit_camera_pose.affine_inverse()
	var aperture := MeshInstance3D.new()
	aperture.name = "CrossroadsDoorAperture"
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.055, 2.195)
	aperture.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = "shader_type spatial; render_mode unshaded, cull_back, shadows_disabled; uniform sampler2D destination_tex : filter_linear; uniform bool screen_space = false; void fragment() { ALBEDO = texture(destination_tex, screen_space ? SCREEN_UV : UV).rgb; }"
	material.set_shader_parameter("destination_tex", viewport.get_texture())
	_destination_material = material
	aperture.material_override = material
	aperture.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_next_room_preview.add_child(aperture)
	_update_destination_portal()


func _update_destination_portal() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera == _destination_camera:
		return
	var eye := _destination_frame.affine_inverse() * camera.global_position
	_destination_camera.global_position = _destination_mapping * camera.global_position
	var fills_view := eye.z < 0.4 and absf(eye.x) < 0.05
	_destination_material.set_shader_parameter("screen_space", fills_view)
	if fills_view:
		# Once the physical aperture fills the screen, capture the ordinary view
		# directly. This avoids magnifying a handful of near-plane portal pixels.
		_destination_viewport.size = Vector2i(get_viewport().get_visible_rect().size * 0.75)
		_destination_camera.global_basis = _destination_mapping.basis * camera.global_basis
		_destination_camera.set_perspective(camera.fov, 0.05, 400.0)
		return
	_destination_viewport.size = Vector2i(384, 800)
	# Keep the capture parallel to the aperture. The offset frustum generates
	# the correct perspective through the door even while the viewer approaches.
	_destination_camera.global_basis = _destination_mapping.basis * _destination_frame.basis
	_destination_camera.set_frustum(2.195, Vector2(-eye.x, -eye.y), maxf(eye.z, 0.005), 400.0)


func _build_current_npc(current: Dictionary) -> void:
	var index: int = Director.NPC_IDS.find(str(current.npc_id))
	var source_index := index - 1
	var source_type := "key_npc" if index == 0 else "npc"
	var source_name := "KeyNPC" if index == 0 else "NPC%d" % source_index
	var npc_textures: Array = _actor_textures.get("npcs", [])
	var texture := _actor_textures.get("key_npc") as Texture2D
	if index > 0:
		texture = npc_textures[source_index] as Texture2D if source_index < npc_textures.size() else null
	# Reuse the original billboard/veil setup while retaining chapter IDs for
	# visit guards and canonical source IDs for old dialogue and hidden rewards.
	var factory := Generator.new()
	factory.built_floor = 1
	var npc := factory._make_actor(source_name, source_type, BASEMENT_NPC_NAMES[index], Vector3.ZERO, texture, maxi(source_index, 0) % 3)
	factory.free()
	npc.set_meta("source_actor_id", npc.get_meta("actor_id"))
	npc.set_meta("source_actor_type", source_type)
	npc.set_meta("source_actor_index", source_index)
	npc.set_meta("source_actor_node_name", source_name)
	npc.set_meta("actor_id", str(current.npc_id))
	npc.set_meta("actor_type", "chapter1_npc")
	npc.set_meta("task_id", str(current.task_id))
	npc.set_meta("chapter1", true)
	npc.set_meta("round_token", _bound_token)
	npc.name = str(current.npc_id).to_pascal_case()
	add_child(npc)
	npc.global_position = _anchor("NPCAnchor")
	_actors.append(npc)
	if texture == null:
		var body := MeshInstance3D.new()
		body.name = "DevelopmentNPCPlaceholder"
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.22
		capsule.height = 1.45
		body.mesh = capsule
		body.position.y = 0.74
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("46413D")
		body.material_override = material
		npc.add_child(body)
		npc.set_meta("development_placeholder", true)


func _build_opening() -> bool:
	var opening: Dictionary = _contract.get("opening", {})
	var manifest: Dictionary = _contract.get("opening_manifest", {})
	if manifest.is_empty():
		manifest = _read_dictionary(OPENING_MANIFEST_PATH)
	var spawn_name := str(opening.get("spawn_node", "PlayerSpawn"))
	var threshold_name := str(opening.get("threshold_node", "DoorArrival"))
	for marker_name in [spawn_name, threshold_name]:
		if not Binding.find_node(_asset, marker_name) is Node3D:
			return _fail("Missing opening asset marker: %s" % marker_name)
	var has_flat_door := opening.has("leaf_local_center") and opening.has("leaf_size_blender")
	if manifest.is_empty() and not opening.has("door") and not has_flat_door:
		return _fail("Opening binding requires the exported opening_manifest.json or explicit opening.door contract")
	# PlayerSpawn in the original exported opening is an EYE anchor; the new
	# contract may explicitly mark it as feet. Never substitute a camera as feet.
	var eye_height := float(opening.get("spawn_eye_height", 0.0 if opening.has("spawn_feet_blender") else 1.65))
	_spawn = _anchor(spawn_name) - _asset.global_basis.y.normalized() * eye_height
	_spawn_yaw = float(opening.get("spawn_yaw_degrees", 0.0)) + _asset.global_rotation_degrees.y
	var door_data: Dictionary = opening.get("door", {}).duplicate(true)
	if door_data.is_empty() and has_flat_door:
		door_data = {
			"pivot_node": str(opening.get("pivot_node", "OpeningDoorPivot")),
			"closed_leaf_local_center": opening.leaf_local_center,
			"leaf_size_blender": opening.leaf_size_blender,
			"open_blender_z_degrees": float(opening.get("open_blender_z_degrees", 90)),
		}
		if opening.has("closed_godot_y_degrees"):
			door_data.closed_godot_y_degrees = opening.closed_godot_y_degrees
	if door_data.is_empty():
		var size: Array = manifest.door.leaf_size_m
		door_data = {"pivot_node": "OpeningDoorPivot", "closed_leaf_local_center": [float(size[0]) * 0.5, 0.0, float(size[2]) * 0.5], "leaf_size_blender": size, "open_blender_z_degrees": -90.0}
	if not _bind_door("opening", door_data, 1.6):
		return false
	var threshold_position := _asset.to_local(_anchor(threshold_name))
	var trigger_size := Vector3(1.05, 2.25, 1.2)
	var offset := Vector3(0.0, 0.0, -0.3)
	if manifest.has("arrival"):
		var arrival: Dictionary = manifest.arrival
		trigger_size = _godot_vector(arrival.area_size_godot)
		offset = _godot_vector(arrival.area_center_godot) - _godot_vector(arrival.position_godot) - Vector3(0, trigger_size.y * 0.5, 0)
	_triggers.opening = AABB(threshold_position + offset - Vector3(trigger_size.x * 0.5, 0, trigger_size.z * 0.5), trigger_size)
	var pivot := Binding.find_node(_asset, str(door_data.pivot_node)) as Node3D
	_opening_plane_z = _asset.to_local(pivot.global_position).z - 0.08
	var center := pivot.to_global(Binding.blender_vector(door_data.closed_leaf_local_center))
	# Normal walking at 3.3 m/s takes roughly 8.5 seconds to interaction range.
	var approach := _spawn - center
	approach.y = 0.0
	if approach.is_zero_approx():
		approach = _asset.global_basis.z
	_spawn = center + approach.normalized() * OPENING_WALK_DISTANCE
	_spawn.y = (_anchor(spawn_name) - _asset.global_basis.y.normalized() * eye_height).y
	_asset.visible = bool(_progress.get("opening_knock_completed", false))
	_opening_actor = _make_actor("chapter1_opening_door", "chapter1_opening", Vector3(center.x, _spawn.y, center.z), "OpeningDoor")
	_opening_knock = AudioStreamPlayer3D.new()
	_opening_knock.name = "OpeningDoorKnock"
	_opening_knock.stream = load(OPENING_KNOCK_PATH) as AudioStream
	if _opening_knock.stream == null:
		_opening_knock.free()
		_opening_knock = null
		return _fail("Opening knock recording could not be loaded")
	_opening_knock.unit_size = 18.0
	_opening_knock.volume_db = -3.0
	add_child(_opening_knock)
	_opening_knock.global_position = center
	_opening_knock.finished.connect(_on_opening_knock_finished)
	# These bounds match the exported 80 m ground centered at Blender y=12.
	_bounds.append(AABB(Vector3(-39.5, -0.3, -51.5), Vector3(79, 4.0, 79)))
	return true


func _bind_door(door_id: String, data: Dictionary, duration: float) -> bool:
	var pivot := Binding.find_node(_asset, str(data.get("pivot_node", ""))) as Node3D
	if pivot == null:
		return _fail("Missing authored door pivot: %s" % data.get("pivot_node", door_id))
	# Exported initial rotation is explicitly described when present. Components
	# always bind the authored closed pose, then enact saved openness themselves.
	if data.has("closed_godot_y_degrees"):
		pivot.rotation_degrees.y = float(data.closed_godot_y_degrees)
	var colliders: Dictionary = Binding.build_door_collision(pivot, data, self)
	if colliders.is_empty():
		return _fail("Invalid door collision contract: %s" % door_id)
	var door := Door.new()
	door.name = "%sDoorController" % door_id.to_pascal_case()
	add_child(door)
	door.bind(pivot, colliders.blocker, float(data.get("open_blender_z_degrees", 90)), duration)
	_doors[door_id] = door
	return true


func _build_crossroads(palette: Dictionary) -> void:
	_delegate = Generator.new()
	_delegate.name = "ExistingCrossroads"
	add_child(_delegate)
	_delegate.rebuild(1, palette, {}, 1, true, {}, false)
	_asset = _delegate
	_spawn = _delegate.to_global(_delegate.start_position())
	_spawn_yaw = _delegate.start_yaw_degrees() + _delegate.global_rotation_degrees.y
	_gate_plane_z = -float(_delegate.map_length) * 0.5 + 14.0
	var pivot := Node3D.new()
	pivot.name = "ChapterFarGatePivot"
	pivot.position = Vector3(-1.5, 0, _gate_plane_z)
	_delegate.add_child(pivot)
	var leaf := MeshInstance3D.new()
	leaf.name = "ChapterFarGateLeaf"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(3.0, 2.6, 0.10)
	leaf.mesh = mesh
	leaf.position = Vector3(1.5, 1.3, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("4C5145")
	leaf.material_override = material
	pivot.add_child(leaf)
	_bind_door("gate", {"pivot_node": "ChapterFarGatePivot", "closed_leaf_local_center": [1.5, 0.0, 1.3], "leaf_size_blender": [3.0, 0.10, 2.6], "open_blender_z_degrees": 90}, 0.4)
	_make_actor("chapter1_crossroads_gate", "chapter1_gate", _delegate.to_global(Vector3(0, 0.02, _gate_plane_z + 1.1)), "TowerGate")
	_triggers.gate = AABB(Vector3(-1.5, 0, _gate_plane_z - 0.8), Vector3(3, 2.6, 1.0))
	set_meta("geometry_source", "RealityFloorGenerator.floor1")


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "ChapterWorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.fog_enabled = false
	if stage == "opening":
		environment.ambient_light_color = Color.BLACK
		environment.ambient_light_energy = 0.0
		# glTF light energies use a different scale from this nonphysical
		# renderer. Preserve the authored glow while retaining door panel detail.
		environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		environment.tonemap_white = 6.0
		for light in _asset.find_children("*", "Light3D", true, false):
			light.light_energy *= 0.0055
		for mesh: MeshInstance3D in _asset.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh == null:
				continue
			for surface in mesh.mesh.get_surface_count():
				var original := mesh.get_active_material(surface) as StandardMaterial3D
				if original != null and original.emission_enabled:
					var softened := original.duplicate() as StandardMaterial3D
					softened.emission_energy_multiplier *= 0.62
					mesh.set_surface_override_material(surface, softened)
	else:
		# GLB punctual lights retain authored physical intensities (4000-8700),
		# which clip this project's nonphysical lighting. Runtime lights below own
		# basement illumination; keep the opening's authored door glow unchanged.
		for imported_light: Light3D in _asset.find_children("*", "Light3D", true, false):
			imported_light.hide()
		# An emissive bulb mesh can glow even with its Light3D disabled. Keep
		# the old optional upstairs fixture absent if an export still includes it.
		for fixture_name in ["Stairs_OpalGlobe", "Stairs_CeilingRose"]:
			var fixture := Binding.find_node(_asset, fixture_name) as Node3D
			if fixture != null:
				fixture.hide()
		# Low green-tinted room light supports the wallpaper while keeping the
		# natural wood readable. The CRT has a separate, close green light.
		environment.ambient_light_color = Color("919E89")
		environment.ambient_light_energy = 0.10
		var warm_colors := [Color("D4F0C9"), Color("D1EDC6"), Color("CEEAC3"), Color("CBE7C0"), Color("C8E4BD")]
		var round_index := clampi(_bound_round, 0, 4)
		for anchor_name in ["MainLightAnchor", "RearLightAnchor"]:
			var light := OmniLight3D.new()
			light.name = "Chapter%s" % anchor_name
			light.light_color = warm_colors[round_index]
			light.light_energy = (0.85 if anchor_name == "MainLightAnchor" else 0.62) * (1.0 - float(round_index) * 0.025)
			light.omni_range = 6.8 if anchor_name == "MainLightAnchor" else 4.5
			light.shadow_enabled = true
			add_child(light)
			light.global_position = _anchor(anchor_name)
	world_environment.environment = environment
	add_child(world_environment)


func interact(actor: Area3D) -> bool:
	if not stage_ready or _exploration_paused or not _current_visit() or not is_instance_valid(actor) or actor not in _actors:
		return false
	match str(actor.get_meta("actor_type", "")):
		"chapter1_opening":
			if not bool(_progress.get("opening_knock_completed", false)) or _opening_requested:
				return false
			_opening_requested = true
			# The authored opaque portal sits immediately behind the closed leaf.
			# Once the leaf turns, it would cover both the moving door and gap.
			var portal := Binding.find_node(_asset, "OpeningDoor_LightPlane") as Node3D
			if portal != null:
				portal.hide()
			event_requested.emit("opening_door_requested", {})
			return true
		"chapter1_npc":
			if not bool(_progress.get("entrance_locked", false)):
				return false
			var current := Director.get_current_round(_progress)
			var payload := _round_payload()
			payload.merge(current)
			event_requested.emit("npc_help_requested", payload)
			return true
		"chapter1_terminal":
			if stage != "basement":
				return false
			event_requested.emit("terminal_requested", _round_payload())
			return true
		"chapter1_light_switch":
			return is_instance_valid(_atmosphere) and _atmosphere.toggle_lights()
		"chapter1_exit":
			if not _help_completed() or not bool(_progress.get("entrance_locked", false)) or _exit_requested:
				return false
			_doors.exit.set_locked(false)
			_exit_requested = true
			event_requested.emit("basement_door_requested", _round_payload())
			return true
		"chapter1_gate":
			if not _gate_ready():
				return false
			_doors.gate.set_locked(false)
			return _doors.gate.request_open()
	return false


func is_actor_reachable(actor: Area3D, player_position: Vector3) -> bool:
	if not stage_ready or not _current_visit() or not is_instance_valid(actor) or actor not in _actors:
		return false
	var displacement := actor.global_position - player_position
	var reach := float(actor.get_meta("interaction_radius", REACH_DISTANCE))
	if str(actor.get_meta("actor_type", "")) == "chapter1_terminal":
		reach = TERMINAL_REACH_DISTANCE
	if absf(displacement.y) > 1.3 or Vector2(displacement.x, displacement.z).length() > reach:
		return false
	if stage == "basement":
		var source := _asset.to_local(player_position)
		var target := _asset.to_local(actor.global_position)
		var partition: Dictionary = _contract.get("partition", {})
		var plane_z := -float(partition.get("y", 2.5))
		if (source.z - plane_z) * (target.z - plane_z) < 0.0:
			var ratio := (plane_z - source.z) / (target.z - source.z)
			var wall_x := lerpf(source.x, target.x, ratio)
			if wall_x < float(partition.get("x_max", 1.65)) + float(partition.get("thickness", 0.16)):
				return false
	return true


func update_authored_events(delta: float, player_position: Vector3, _camera_forward: Vector3) -> void:
	if not stage_ready or _exploration_paused or not _current_visit():
		return
	if stage == "opening":
		_opening_elapsed += maxf(delta, 0.0)
		if _opening_elapsed >= OPENING_BLACK_SECONDS:
			_asset.show()
		if not bool(_progress.get("opening_knock_completed", false)) and not _opening_knock_started:
			if _opening_elapsed >= OPENING_WAIT_SECONDS:
				_opening_knock_started = true
				_opening_knock.play()
		return
	var local := _asset.to_local(player_position)
	if not _has_previous:
		_previous_position = local
		_has_previous = true
		return
	var previous := _previous_position
	_previous_position = local
	if stage == "basement":
		if is_instance_valid(_atmosphere):
			_atmosphere.update_visit(delta, bool(_progress.get("entrance_locked", false)))
		var entrance: AABB = _triggers.EntrySealTrigger
		var seal_z := entrance.get_center().z
		if not bool(_progress.get("entrance_locked", false)) and previous.z < seal_z and local.z >= seal_z and _crossed_plane("EntrySealTrigger", previous, local, 2, seal_z):
			_doors.entry.close_and_lock()
			_emit_once("entrance_threshold_crossed", _round_payload())
	elif stage == "crossroads":
		if _gate_ready() and _doors.gate.is_passable() and previous.z > _gate_plane_z - 0.2 and local.z <= _gate_plane_z - 0.2 and _crossed_plane("gate", previous, local, 2, _gate_plane_z - 0.2):
			_emit_once("crossroads_gate_requested", {})


func _crossed_plane(trigger_id: String, from: Vector3, to: Vector3, axis: int, coordinate: float) -> bool:
	var box: AABB = _triggers[trigger_id]
	var delta := to[axis] - from[axis]
	if is_zero_approx(delta):
		return false
	var ratio := (coordinate - from[axis]) / delta
	if ratio < 0.0 or ratio > 1.0:
		return false
	# Test the point ON the doorway plane, not any part of the motion segment:
	# diagonal movement can leave a trigger through its side without entering.
	return box.has_point(from.lerp(to, ratio) + BODY_CENTER)


func _emit_once(event_id: String, payload: Dictionary) -> void:
	if _emitted.has(event_id):
		return
	_emitted[event_id] = true
	event_requested.emit(event_id, payload)


func _current_visit() -> bool:
	return str(_progress.get("phase", "")) == stage and int(_progress.get("transition_serial", -2)) == _bound_token and int(_progress.get("round_index", -2)) == _bound_round


func _help_completed() -> bool:
	var current := Director.get_current_round(_progress)
	return not current.is_empty() and current.task_id in _progress.get("completed_task_ids", [])


func _gate_ready() -> bool:
	for app_id in Director.REQUIRED_APP_IDS:
		if app_id not in _progress.get("unlocked_app_ids", []):
			return false
	for task_id in Director.TASK_IDS:
		if task_id not in _progress.get("completed_task_ids", []):
			return false
	return stage == "crossroads"


func _round_payload() -> Dictionary:
	return {"round_token": _bound_token}


func _make_actor(actor_id: String, actor_type: String, world_position: Vector3, label: String) -> Area3D:
	var actor := Area3D.new()
	actor.name = actor_id.to_pascal_case()
	actor.collision_layer = 2
	actor.collision_mask = 0
	actor.set_meta("actor_id", actor_id)
	actor.set_meta("actor_type", actor_type)
	actor.set_meta("display_name", label)
	actor.set_meta("chapter1", true)
	actor.set_meta("round_token", _bound_token)
	add_child(actor)
	actor.global_position = world_position
	_actors.append(actor)
	return actor


func start_position() -> Vector3:
	return _spawn


func start_yaw_degrees() -> float:
	return _spawn_yaw


func contains_playable_position(position: Vector3, inset: float = 0.0) -> bool:
	if not stage_ready:
		return false
	if _delegate != null:
		var local := _delegate.to_local(position)
		return local.y >= -3.0 and _delegate.contains_playable_position(local, inset)
	var local := _asset.to_local(position)
	# The 1.25 m stair landing cannot accept the old street's 1.2 m inset.
	var safe_inset := clampf(inset, -2.0, 0.08)
	for box in _bounds:
		var adjusted := AABB(box.position + Vector3(safe_inset, 0, safe_inset), box.size - Vector3(safe_inset * 2, 0, safe_inset * 2))
		if adjusted.has_point(local):
			return true
	return false


func clamp_to_playable_position(position: Vector3, inset: float = 1.2) -> Vector3:
	if not stage_ready:
		return _spawn
	if _delegate != null:
		return _delegate.to_global(_delegate.clamp_to_playable_position(_delegate.to_local(position), inset))
	if contains_playable_position(position, inset):
		return position
	return _spawn


func recovery_position(position: Vector3) -> Vector3:
	return clamp_to_playable_position(position, 0.08)


func get_interactable_actors() -> Array[Area3D]:
	var result: Array[Area3D] = []
	if stage == "opening" and (not bool(_progress.get("opening_knock_completed", false)) or _opening_requested):
		return result
	if stage_ready and _current_visit():
		for actor in _actors:
			if _exit_requested:
				continue
			result.append(actor)
	return result


func _on_opening_knock_finished() -> void:
	if stage_ready and stage == "opening" and _current_visit() and _opening_knock_started:
		_emit_once("opening_knock_completed", {"sequence_id": Director.OPENING_SEQUENCE_ID})


func opening_camera_position() -> Vector3:
	return _opening_actor.global_position + _asset.global_basis * Vector3(0, 1.56, -0.45)


func opening_camera_target() -> Vector3:
	return opening_camera_position() - _asset.global_basis.z * 2.0


func exit_camera_position() -> Vector3:
	return _exit_camera_pose.origin


func exit_camera_target() -> Vector3:
	return _exit_camera_pose.origin - _exit_camera_pose.basis.z * 2.0


func tunnel_camera_position() -> Vector3:
	return exit_camera_position()


func tunnel_camera_target() -> Vector3:
	return exit_camera_target()


func set_exploration_paused(value: bool) -> void:
	_exploration_paused = value
	if is_instance_valid(_opening_knock):
		_opening_knock.stream_paused = value
	for door in _doors.values():
		door.set_paused(value)


func get_interactable_items() -> Array[Area3D]:
	return []


func get_door(door_id: String) -> Node3D:
	return _doors.get(door_id)


func get_video_screen() -> Node:
	return _video


func get_screen_mesh() -> MeshInstance3D:
	return _screen_mesh


func terminal_camera_position() -> Vector3:
	var distance := 0.35
	if is_instance_valid(_screen_mesh):
		var screen_bounds: AABB = _screen_mesh.global_transform * _screen_mesh.get_aabb()
		# Frame the actual screen at 72% of the main camera's 58-degree view.
		# This temporary close-up is independent of the walk-up interaction point.
		distance = clampf(screen_bounds.size.y / (2.0 * tan(deg_to_rad(29.0)) * 0.72), 0.22, 0.55)
	return _terminal_center + _terminal_front * distance


func terminal_camera_target() -> Vector3:
	return _terminal_center


func anchor_world_position(marker_name: String) -> Vector3:
	if _asset == null or not Binding.find_node(_asset, marker_name) is Node3D:
		diagnostics.append("Missing requested chapter marker: %s" % marker_name)
		return Vector3.INF
	return _anchor(marker_name)


func set_playtest_assist_enabled(value: bool) -> void:
	_playtest_assist = value


func sync_collected_items(_collected_ids: Array[String]) -> void:
	pass


func sync_prerequisite_items(_revealed_ids: Array[String], _collected_ids: Array[String]) -> void:
	pass


func sync_claimed_dolls(_claimed_ids: Array[String]) -> void:
	pass


func configure_authored_events(_day_number: int, _palette: Dictionary) -> void:
	pass


func apply_palette(palette: Dictionary) -> void:
	if _delegate != null:
		_delegate.apply_palette(palette)


func _anchor(marker_name: String) -> Vector3:
	return Binding.anchor_transform(_asset, marker_name).origin


func _find_video_screen(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and "Screen_Video" in str(node.name):
		return node
	for child in node.get_children():
		var found := _find_video_screen(child)
		if found != null:
			return found
	return null


func _read_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return result if result is Dictionary else {}


func _godot_vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


func _fail(message: String) -> bool:
	diagnostics.append(message)
	stage_ready = false
	return false


func _clear_stage() -> void:
	stage_ready = false
	_opening_elapsed = 0.0
	_opening_knock_started = false
	_opening_requested = false
	_exploration_paused = false
	_opening_knock = null
	_opening_actor = null
	_exit_requested = false
	_next_room_preview = null
	_atmosphere = null
	_destination_camera = null
	_destination_material = null
	_destination_viewport = null
	_actors.clear()
	_doors.clear()
	_triggers.clear()
	_emitted.clear()
	_bounds.clear()
	_has_previous = false
	_asset = null
	_delegate = null
	_video = null
	_screen_mesh = null
	_terminal_center = Vector3.ZERO
	_terminal_front = Vector3.FORWARD
	_actor_textures.clear()
	diagnostics.clear()
	for child in get_children():
		remove_child(child)
		child.free()
