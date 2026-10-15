extends Node3D
## Fifth visit: sunk 1990s CRTs plus a single, pause-safe room interruption.
## No timers/coroutines outlive the room. The host persists started immediately.

signal started

const VideoScreen = preload("res://scripts/world/chapter_video_screen.gd")
const STATIC_PATH := "res://assets/audio/sfx/tv_static_diarchangeli.ogg"
const DEFAULT_VIDEO_PATH := "res://assets/video/basement_crt_loop.ogv"
const BLACK_SECONDS := 2.0
const RED_SECONDS := 6.0
const RECOVERY_BLACK_SECONDS := 0.18
const CENTER_RADIUS := 0.65
const RED := Color(1.0, 0.0, 0.0)

var _world: Node3D
var _screens: Array[Node] = []
var _red_lights: Array[OmniLight3D] = []
var _primary: Node
var _static: AudioStreamPlayer
var _paused := false
var _phase := "waiting"
var _time := 0.0
var _light_states: Array[Dictionary] = []
var _material_states: Array[Dictionary] = []
var _environment_states: Array[Dictionary] = []
var _wall_count := 0
var _stream: VideoStream


func configure(world: Node3D, asset: Node3D, progress: Dictionary, video_path: String = DEFAULT_VIDEO_PATH) -> void:
	_world = world
	global_transform = asset.global_transform
	if int(progress.get("round_index", -1)) != 4:
		_phase = "complete"
		return
	_phase = "complete" if progress.get("basement_crt_event_played", false) == true else "waiting"
	_static = AudioStreamPlayer.new()
	_static.name = "TVStatic"
	_static.stream = AudioStreamOggVorbis.load_from_file(STATIC_PATH)
	_static.volume_db = -16.0
	add_child(_static)
	# The clear middle is the trigger; neither it nor the NPC/door path is blocked.
	var layouts := [
		[Vector3(2.40, -0.18, 2.80), -2.65, -0.08, false],
		[Vector3(2.55, -0.20, 0.85), -1.55, 0.06, false],
		[Vector3(2.05, -0.24, -1.15), -0.90, -0.05, false],
		[Vector3(-0.75, -0.19, 2.80), 2.65, 0.04, false],
		[Vector3(-1.13, -0.23, 0.65), 1.20, -0.08, false],
		[Vector3(0.75, -0.22, 1.65), 2.75, 0.08, false],
		[Vector3(2.40, -0.18, -3.20), -1.25, 0.05, false],
		[Vector3(-0.95, -0.20, -3.75), 0.45, -0.04, false],
		[Vector3(3.18, 0.72, 2.20), -PI / 2.0, 0.0, true],
		[Vector3(3.18, 1.48, -0.55), -PI / 2.0, 0.0, true],
		[Vector3(-0.55, 1.30, 4.18), PI, 0.0, true],
		[Vector3(1.90, 0.82, -4.18), 0.0, 0.0, true],
	]
	var stream: VideoStream
	if not video_path.is_empty() and FileAccess.file_exists(video_path):
		var theora := VideoStreamTheora.new()
		theora.file = video_path
		stream = theora
	_stream = stream
	set_meta("video_source_path", video_path)
	set_meta("video_source_available", stream != null)
	for index in layouts.size():
		var plan: Array = layouts[index]
		_build_monitor(index, plan[0], plan[1], plan[2], plan[3], stream)


func bind_primary_screen(video: Node) -> void:
	_primary = video
	if is_instance_valid(_primary) and _stream != null:
		_primary.set_ambient_playback(true)
		_primary.set_stream(_stream)
		_primary.set_volume_db(-80.0)
		_primary.set_looping(true)
		_primary.play(12.0 * 1.73)


func update_visit(delta: float, entrance_locked: bool, player_local: Vector3) -> void:
	if _paused or _phase == "complete":
		return
	if _phase == "waiting":
		if entrance_locked and player_local.is_finite() and absf(player_local.y) < 1.8 and Vector2(player_local.x, player_local.z).length() <= CENTER_RADIUS:
			_capture_room_state()
			_phase = "black"
			_apply_signal(Color.BLACK)
			started.emit()
		return
	_time += maxf(delta, 0.0)
	if _time < BLACK_SECONDS:
		return
	if _time < BLACK_SECONDS + RED_SECONDS:
		if _phase != "red":
			_phase = "red"
			_apply_signal(RED)
			_static.play(_time - BLACK_SECONDS)
		return
	if _phase == "red" or _phase == "black":
		_phase = "recovery_black"
		_static.stop()
		_apply_signal(Color.BLACK)
	if _time >= BLACK_SECONDS + RED_SECONDS + RECOVERY_BLACK_SECONDS:
		cancel()


func set_paused(value: bool) -> void:
	_paused = value
	if is_instance_valid(_static):
		_static.stream_paused = value
	for video in _screens:
		video.set_playback_paused(value)
	if is_instance_valid(_primary):
		_primary.set_playback_paused(value)


func is_active() -> bool:
	return _phase in ["black", "red", "recovery_black"]


func event_phase() -> String:
	return _phase


func is_static_playing() -> bool:
	return is_instance_valid(_static) and _static.playing


func get_monitor_count() -> int:
	return _screens.size()


func get_wall_monitor_count() -> int:
	return _wall_count


func active_red_light_count() -> int:
	var count := 0
	for light in _red_lights:
		if light.visible:
			count += 1
	return count


func cancel() -> void:
	if is_instance_valid(_static):
		_static.stop()
	if is_active():
		_restore_room_state()
	_phase = "complete"


func _exit_tree() -> void:
	cancel()


func _capture_room_state() -> void:
	for light: Light3D in _world.find_children("*", "Light3D", true, false):
		if light is OmniLight3D and light in _red_lights:
			continue
		_light_states.append({"node": light, "visible": light.visible})
		light.visible = false
	var captured_materials: Array[Material] = []
	for mesh: MeshInstance3D in _world.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as StandardMaterial3D
			if material == null or not material.emission_enabled or material in captured_materials:
				continue
			captured_materials.append(material)
			_material_states.append({"material": material, "emission": material.emission_energy_multiplier, "albedo": material.albedo_color})
			material.emission_energy_multiplier = 0.0
			# Unshaded opal bulbs must also lose their visible lit surface.
			if material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
				material.albedo_color = Color.BLACK
	for node: WorldEnvironment in _world.find_children("*", "WorldEnvironment", true, false):
		var environment := node.environment
		if environment == null:
			continue
		_environment_states.append({"environment": environment, "ambient": environment.ambient_light_energy})
		environment.ambient_light_energy = 0.0


func _apply_signal(color: Color) -> void:
	for video in _screens:
		video.set_signal_override(color)
	if is_instance_valid(_primary):
		_primary.set_signal_override(color)
	for light in _red_lights:
		light.visible = color == RED


func _restore_room_state() -> void:
	for state in _light_states:
		if is_instance_valid(state.node):
			state.node.visible = state.visible
	for state in _material_states:
		state.material.emission_energy_multiplier = state.emission
		state.material.albedo_color = state.albedo
	for state in _environment_states:
		state.environment.ambient_light_energy = state.ambient
	for video in _screens:
		if is_instance_valid(video):
			video.clear_signal_override()
	if is_instance_valid(_primary):
		_primary.clear_signal_override()
	for light in _red_lights:
		if is_instance_valid(light):
			light.visible = false
	_light_states.clear()
	_material_states.clear()
	_environment_states.clear()


func _build_monitor(index: int, location: Vector3, yaw: float, tilt: float, embedded: bool, stream: VideoStream) -> void:
	var monitor := Node3D.new()
	monitor.name = "SunkenCRT%02d" % (index + 1)
	monitor.position = location
	monitor.rotation = Vector3(tilt, yaw, 0)
	monitor.set_meta("embedded_in_wall", embedded)
	monitor.set_meta("case_depth_metres", 0.75)
	monitor.set_meta("video_start_seconds", float(index) * 1.73)
	add_child(monitor)
	if embedded:
		_wall_count += 1
	var plastic := _material(Color("858777") if index % 3 else Color("444B43"))
	var dark := _material(Color("252C27"))
	var trim := _material(Color("BEC0A7"))
	var body := MeshInstance3D.new()
	body.name = "DeepTaperedCabinet"
	body.mesh = _cabinet_mesh()
	body.material_override = plastic
	monitor.add_child(body)
	_box(monitor, "FrontBezel", Vector3(0.79, 0.65, 0.12), Vector3(0, 0.36, 0.21), plastic)
	_box(monitor, "BlackGlassSurround", Vector3(0.67, 0.49, 0.014), Vector3(-0.025, 0.40, 0.278), dark)
	var glass := MeshInstance3D.new()
	glass.name = "CurvedGlass"
	glass.mesh = _glass_mesh()
	glass.position = Vector3(-0.025, 0.40, 0.29)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	monitor.add_child(glass)
	for slit in 7:
		_box(monitor, "SpeakerSlot%02d" % slit, Vector3(0.26, 0.006, 0.008), Vector3(-0.15, 0.101 + slit * 0.009, 0.276), dark)
	for slit in 6:
		_box(monitor, "SideVent%02d" % slit, Vector3(0.009, 0.19, 0.012), Vector3(0.357 - slit * 0.006, 0.38, -0.04 - slit * 0.046), dark)
	for button in 2:
		var knob := MeshInstance3D.new()
		knob.name = "ControlDial%d" % button
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.027
		cylinder.bottom_radius = 0.027
		cylinder.height = 0.018
		cylinder.radial_segments = 10
		knob.mesh = cylinder
		knob.material_override = dark
		knob.position = Vector3(0.21 + button * 0.08, 0.111, 0.281)
		knob.rotation.x = PI / 2.0
		monitor.add_child(knob)
	_box(monitor, "BrandPlate", Vector3(0.10, 0.018, 0.008), Vector3(0.23, 0.655, 0.272), trim)
	var video := VideoScreen.new()
	video.name = "LoopingVideo"
	monitor.add_child(video)
	video.bind_screen(glass)
	video.set_standby_color(Color("396946"))
	video.set_volume_db(-80.0)
	video.set_looping(true)
	if stream != null:
		video.set_stream(stream)
		video.play(float(index) * 1.73)
	_screens.append(video)
	var glow := OmniLight3D.new()
	glow.name = "RedScreenLight"
	glow.position = Vector3(0, 0.40, 0.53)
	glow.light_color = RED
	glow.light_energy = 0.85
	glow.omni_range = 3.3
	glow.omni_attenuation = 0.85
	glow.shadow_enabled = false
	glow.visible = false
	monitor.add_child(glow)
	_red_lights.append(glow)


func _cabinet_mesh() -> ArrayMesh:
	# Wide CRT face and visibly tapered, deep tube housing. About 40 triangles.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := [
		[Vector3(-0.39, 0.04, 0.20), Vector3(0.39, 0.04, 0.20), Vector3(0.39, 0.68, 0.20), Vector3(-0.39, 0.68, 0.20)],
		[Vector3(-0.36, 0.055, -0.09), Vector3(0.36, 0.055, -0.09), Vector3(0.36, 0.65, -0.09), Vector3(-0.36, 0.65, -0.09)],
		[Vector3(-0.23, 0.12, -0.48), Vector3(0.23, 0.12, -0.48), Vector3(0.23, 0.55, -0.48), Vector3(-0.23, 0.55, -0.48)],
	]
	for ring in 2:
		for side in 4:
			var next := (side + 1) % 4
			for vertex: Vector3 in [rings[ring][side], rings[ring][next], rings[ring + 1][side], rings[ring][next], rings[ring + 1][next], rings[ring + 1][side]]:
				surface.add_vertex(vertex)
	for vertex: Vector3 in [rings[2][0], rings[2][1], rings[2][3], rings[2][1], rings[2][2], rings[2][3]]:
		surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()


func _glass_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 6:
		for column in 8:
			for corner: Vector2 in [Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
				var uv := Vector2((column + corner.x) / 8.0, (row + corner.y) / 6.0)
				var offset := uv - Vector2(0.5, 0.5)
				var bulge := 0.027 * maxf(0.0, 1.0 - 2.0 * offset.length_squared())
				surface.set_uv(Vector2(uv.x, 1.0 - uv.y))
				surface.set_normal(Vector3.BACK)
				surface.add_vertex(Vector3(offset.x * 0.60, offset.y * 0.43, bulge))
	return surface.commit()


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.87
	return material


func _box(parent: Node3D, node_name: String, size: Vector3, location: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = location
	instance.material_override = material
	parent.add_child(instance)
