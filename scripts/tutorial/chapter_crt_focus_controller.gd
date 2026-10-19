extends Node
## Owns only the temporary cinematic. The host freezes locomotion while active.

const State = preload("res://scripts/tutorial/chapter_crt_tutorial_state.gd")
const Content = preload("res://scripts/tutorial/chapter_crt_tutorial_content.gd")
const Narration = preload("res://scripts/ui/chapter_opening_narration.gd")
const CRT_LAYER := 1 << 17
const TURN_SECONDS := 0.8
const RETURN_SECONDS := 0.65

var _world: Node
var _camera: Camera3D
var _player: Node3D
var _progress_getter: Callable
var _save: Callable
var _locale: Callable
var _narration: Control
var _active := false
var _paused := false
var _returning := false
var _elapsed := 0.0
var _previous := Vector3.ZERO
var _has_previous := false
var _original_pose := Transform3D.IDENTITY
var _look_pose := Transform3D.IDENTITY
var _original_fov := 58.0
var _original_mask := 1
var _original_environment: Environment
var _frozen_player := Vector3.ZERO
var _visuals: Array[Dictionary] = []
var _lights: Array[Dictionary] = []
var _spot: SpotLight3D
var _beam: MeshInstance3D

func setup(world: Node, camera: Camera3D, player: Node3D, ui_root: Control, progress_getter: Callable, save_callback: Callable, locale_getter: Callable) -> void:
	cancel()
	_world = world
	_camera = camera
	_player = player
	_progress_getter = progress_getter
	_save = save_callback
	_locale = locale_getter
	_has_previous = false
	if not is_instance_valid(_narration):
		_narration = Narration.new()
		ui_root.add_child(_narration)
		_narration.name = "ChapterCRTFocusNarration"

func update(delta: float, paused: bool = false) -> void:
	if not _progress_getter.is_valid() or not is_instance_valid(_world) or not is_instance_valid(_camera) or not is_instance_valid(_player):
		cancel()
		return
	var progress: Dictionary = _progress_getter.call()
	if str(progress.get("phase", "")) != "basement" or int(progress.get("round_index", -1)) != 0 or not bool(_world.get("stage_ready")):
		cancel()
		_has_previous = false
		return
	var data: Dictionary = State.normalize(progress.get("crt_tutorial", {}))
	_paused = paused
	if not _active:
		var current := _player.global_position
		var crossed: bool = _has_previous and _world.crossed_crt_focus_trigger(_previous, current)
		_previous = current
		_has_previous = true
		if paused or data.focus_done or (not data.focus_started and not crossed):
			return
		_begin(data)
		_store(data)
	_player.global_position = _frozen_player
	if _player is CharacterBody3D:
		_player.velocity = Vector3.ZERO
	_narration.set_audio_paused(paused)
	_narration.visible = not paused and not _returning and _elapsed >= TURN_SECONDS
	if paused:
		return
	_elapsed += maxf(delta, 0.0)
	var duration := RETURN_SECONDS if _returning else TURN_SECONDS
	var weight := 0.5 - 0.5 * cos(PI * clampf(_elapsed / duration, 0.0, 1.0))
	_camera.global_transform = _look_pose.interpolate_with(_original_pose, weight) if _returning else _original_pose.interpolate_with(_look_pose, weight)
	_camera.fov = lerpf(34.0, _original_fov, weight) if _returning else lerpf(_original_fov, 34.0, weight)
	if _returning and _elapsed >= RETURN_SECONDS:
		cancel()
		return
	if not _returning:
		for saved in _lights:
			if is_instance_valid(saved.node):
				saved.node.visible = false
		if _narration.visible:
			_narration.show_line(data.focus_line, Content.line(data.focus_line, _locale.call()), Content.hint("click", _locale.call()))

func route_input(event: InputEvent) -> bool:
	if not _active:
		return false
	if _paused or _returning or _elapsed < TURN_SECONDS:
		return true
	var advance: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if advance:
		var progress: Dictionary = _progress_getter.call()
		var data: Dictionary = State.normalize(progress.get("crt_tutorial", {}))
		if data.focus_line < 7:
			data.focus_line += 1
		else:
			data.focus_done = true
			_returning = true
			_elapsed = 0.0
			_restore_lighting()
			_narration.hide()
		_store(data)
	return true

func is_active() -> bool:
	return _active

func _begin(data: Dictionary) -> void:
	_original_pose = _camera.global_transform
	_original_fov = _camera.fov
	_frozen_player = _player.global_position
	if data.focus_started and data.focus_pose.size() == 12 and data.focus_player.size() == 3:
		var p: Array = data.focus_pose
		_original_pose = Transform3D(Basis(Vector3(p[0], p[1], p[2]), Vector3(p[3], p[4], p[5]), Vector3(p[6], p[7], p[8])), Vector3(p[9], p[10], p[11]))
		_frozen_player = Vector3(data.focus_player[0], data.focus_player[1], data.focus_player[2])
		_original_fov = data.focus_fov
	else:
		var b := _original_pose.basis
		var o := _original_pose.origin
		data.focus_pose = [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z, o.x, o.y, o.z]
		data.focus_player = [_frozen_player.x, _frozen_player.y, _frozen_player.z]
		data.focus_fov = _original_fov
	data.focus_started = true
	_original_mask = _camera.cull_mask
	_original_environment = _camera.environment
	_look_pose = _original_pose.looking_at(_world.terminal_camera_target(), Vector3.UP)
	for mesh in _world.get_crt_focus_visuals():
		_visuals.append({"node": mesh, "layers": mesh.layers})
		mesh.layers |= CRT_LAYER
	for candidate in get_tree().root.find_children("*", "Light3D", true, false):
		if candidate.get_world_3d() == _camera.get_world_3d():
			_lights.append({"node": candidate, "visible": candidate.visible})
			candidate.visible = false
	var black := Environment.new()
	black.background_mode = Environment.BG_COLOR
	black.background_color = Color.BLACK
	black.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	black.ambient_light_color = Color.BLACK
	black.ambient_light_energy = 0.0
	_camera.environment = black
	_camera.cull_mask = CRT_LAYER
	_spot = SpotLight3D.new()
	_spot.name = "CRTFirstVisitWhiteSpotlight"
	_spot.layers = CRT_LAYER
	_world.add_child(_spot)
	var target: Vector3 = _world.terminal_camera_target()
	var front: Vector3 = (_world.terminal_camera_position() - target).normalized()
	var apex := target + Vector3(0, 1.25, 0) + front * 0.35
	_spot.global_position = apex
	_spot.look_at(_world.terminal_camera_target(), Vector3.FORWARD)
	_spot.light_color = Color.WHITE
	_spot.light_energy = 9.0
	_spot.spot_range = 4.0
	_spot.spot_angle = 48.0
	_spot.light_cull_mask = CRT_LAYER
	# Hidden ceiling geometry must not shadow the isolated teaching object.
	_spot.shadow_enabled = false
	_build_beam(apex, target)
	_active = true
	_returning = false
	_elapsed = 0.0
	_narration.line_number = 0

func _store(data: Dictionary) -> void:
	var progress: Dictionary = _progress_getter.call()
	progress["crt_tutorial"] = data
	if _save.is_valid():
		_save.call()

func _restore_lighting() -> void:
	if is_instance_valid(_camera):
		_camera.cull_mask = _original_mask
		_camera.environment = _original_environment
	for saved in _visuals:
		if is_instance_valid(saved.node):
			saved.node.layers = saved.layers
	for saved in _lights:
		if is_instance_valid(saved.node):
			saved.node.visible = saved.visible
	_visuals.clear()
	_lights.clear()
	if is_instance_valid(_spot):
		_spot.visible = false
		_spot.queue_free()
	_spot = null
	if is_instance_valid(_beam):
		_beam.visible = false
		_beam.queue_free()
	_beam = null

func _build_beam(apex: Vector3, target: Vector3) -> void:
	_beam = MeshInstance3D.new()
	_beam.name = "CRTFirstVisitWhiteLightBeam"
	_beam.layers = CRT_LAYER
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cone := CylinderMesh.new()
	cone.top_radius = 0.025
	cone.bottom_radius = 0.46
	cone.height = apex.distance_to(target)
	cone.radial_segments = 32
	cone.cap_top = false
	cone.cap_bottom = false
	_beam.mesh = cone
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled; void fragment(){ ALBEDO = vec3(0.92,0.95,1.0); ALPHA = 0.055 * smoothstep(0.0,0.16,UV.y) * (1.0-smoothstep(0.82,1.0,UV.y)); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	_beam.material_override = material
	_world.add_child(_beam)
	_beam.global_position = (apex + target) * 0.5
	_beam.global_basis = Basis(Quaternion(Vector3.UP, (apex - target).normalized()))

func cancel() -> void:
	if _active:
		_restore_lighting()
		if is_instance_valid(_camera):
			_camera.global_transform = _original_pose
			_camera.fov = _original_fov
	_active = false
	_returning = false
	if is_instance_valid(_narration):
		_narration.hide()

func _exit_tree() -> void:
	cancel()
	if is_instance_valid(_narration):
		_narration.queue_free()
