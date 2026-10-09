extends Node3D
## GUI rendered on the authored CRT surface. The host reparents real app Controls
## into get_content_root() and calls route_input() from its normal input route.

const DISPLAY_SIZE := Vector2i(1600, 1200)
const CRT_SHADER := preload("res://shaders/chapter_crt.gdshader")

var _mesh: MeshInstance3D
var _surface_index := 0
var _original_material: Material
var _material: ShaderMaterial
var _playback_material: ShaderMaterial
var _video: Node
var _viewport: SubViewport
var _content: Control
var _triangles: Array[Dictionary] = []
var _active := false
var _vhs_enabled := true
var _last_position := Vector2.ZERO
var _captured_triangle := -1
var _pressed_buttons: Dictionary = {}
var _mouse_inside := false
var _cancelling_input := false


func bind_screen(mesh: MeshInstance3D, surface_index: int = 0, video: Node = null) -> bool:
	if not is_instance_valid(mesh) or mesh.mesh == null or surface_index < 0 or surface_index >= mesh.mesh.get_surface_count():
		return false
	var triangles := _read_triangles(mesh.mesh, surface_index)
	if triangles.is_empty():
		return false
	if video != null and (not video.has_method("is_bound_to") or not video.is_bound_to(mesh, surface_index)):
		return false
	_release_surface()
	_ensure_runtime()
	_mesh = mesh
	_surface_index = surface_index
	_triangles = triangles
	_video = video
	if is_instance_valid(_video):
		_playback_material = _material.duplicate() as ShaderMaterial
		_playback_material.set_shader_parameter("content_texture", _video.get_playback_texture())
		if not _video.attach_display(self, _material, _playback_material):
			_mesh = null
			_video = null
			_playback_material = null
			_triangles.clear()
			return false
	else:
		_original_material = mesh.get_surface_override_material(surface_index)
		mesh.set_surface_override_material(surface_index, _material)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return true


func get_content_root() -> Control:
	_ensure_runtime()
	return _content


func get_display_viewport() -> SubViewport:
	_ensure_runtime()
	return _viewport


func get_texture() -> Texture2D:
	return get_display_viewport().get_texture()


func get_pointer_position() -> Vector2:
	return _last_position


func set_active(active: bool) -> void:
	_active = active
	if not active:
		_cancel_gui_input()
	if is_instance_valid(_viewport):
		_viewport.gui_disable_input = not active


func is_active() -> bool:
	return _active


func set_vhs_enabled(enabled: bool) -> void:
	_vhs_enabled = enabled
	if _material != null:
		_material.set_shader_parameter("vhs_enabled", enabled)
	if _playback_material != null:
		_playback_material.set_shader_parameter("vhs_enabled", enabled)


func is_vhs_enabled() -> bool:
	return _vhs_enabled


func route_input(event: InputEvent, camera: Camera3D) -> bool:
	if _cancelling_input:
		return false
	if not _active or not is_instance_valid(_viewport) or not _viewport.is_inside_tree() or not _has_display():
		_cancel_gui_input()
		return false
	if event is InputEventKey:
		_viewport.push_input(event.duplicate(), true)
		return true
	if not (event is InputEventMouseMotion or event is InputEventMouseButton) or not is_instance_valid(camera):
		return false
	var origin := _mesh.to_local(camera.project_ray_origin(event.position))
	var direction := _mesh.global_transform.basis.inverse() * camera.project_ray_normal(event.position)
	var hit := _ray_hit(origin, direction)
	_set_mouse_inside(not hit.is_empty())
	if hit.is_empty() and not _pressed_buttons.is_empty() and _captured_triangle >= 0:
		hit = _triangle_hit(origin, direction, _captured_triangle, false)
	if hit.is_empty():
		if event is InputEventMouseButton and not event.pressed and _pressed_buttons.has(event.button_index):
			_pressed_buttons.erase(event.button_index)
			_send_mouse(event, Vector2(-100, -100))
			return true
		return false
	var position: Vector2 = hit.uv * Vector2(DISPLAY_SIZE)
	if event is InputEventMouseButton and event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		if event.pressed:
			_pressed_buttons[event.button_index] = true
			_captured_triangle = hit.triangle
		else:
			_pressed_buttons.erase(event.button_index)
			if _pressed_buttons.is_empty():
				_captured_triangle = -1
	# A Control signal may end or pause the session synchronously. Clear release
	# capture before dispatch so such a callback cannot synthesize another release.
	_send_mouse(event, position)
	return true


func get_screen_center() -> Vector3:
	if not is_instance_valid(_mesh) or _triangles.is_empty():
		return global_position
	var weighted := Vector3.ZERO
	var total_area := 0.0
	for triangle in _triangles:
		var a: Vector3 = _mesh.to_global(triangle.a)
		var b: Vector3 = _mesh.to_global(triangle.b)
		var c: Vector3 = _mesh.to_global(triangle.c)
		var area := (b - a).cross(c - a).length()
		weighted += (a + b + c) / 3.0 * area
		total_area += area
	return weighted / maxf(total_area, 0.000001)


func get_screen_forward() -> Vector3:
	if not is_instance_valid(_mesh) or _triangles.is_empty():
		return Vector3.BACK
	var normal := Vector3.ZERO
	for triangle in _triangles:
		var ab: Vector3 = _mesh.global_transform.basis * (triangle.b - triangle.a)
		var ac: Vector3 = _mesh.global_transform.basis * (triangle.c - triangle.a)
		var uv_b: Vector2 = triangle.uv_b - triangle.uv_a
		var uv_c: Vector2 = triangle.uv_c - triangle.uv_a
		# UV y runs downwards, so the viewer-facing direction is down x right.
		var uv_sign := signf(uv_b.cross(uv_c))
		normal -= ab.cross(ac) * uv_sign
	return normal.normalized()


func _read_triangles(mesh: Mesh, surface_index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var arrays := mesh.surface_get_arrays(surface_index)
	if arrays.size() <= Mesh.ARRAY_TEX_UV or arrays[Mesh.ARRAY_VERTEX] == null or arrays[Mesh.ARRAY_TEX_UV] == null:
		return result
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	if vertices.size() != uvs.size():
		return result
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for index in vertices.size():
			indices.append(index)
	for offset in range(0, indices.size() - 2, 3):
		var a := indices[offset]
		var b := indices[offset + 1]
		var c := indices[offset + 2]
		if a < 0 or b < 0 or c < 0 or a >= vertices.size() or b >= vertices.size() or c >= vertices.size():
			continue
		if absf((uvs[b] - uvs[a]).cross(uvs[c] - uvs[a])) < 0.000001:
			continue
		result.append({"a": vertices[a], "b": vertices[b], "c": vertices[c], "uv_a": uvs[a], "uv_b": uvs[b], "uv_c": uvs[c]})
	return result


func _ray_hit(origin: Vector3, direction: Vector3) -> Dictionary:
	var nearest: Dictionary = {}
	for index in _triangles.size():
		var hit := _triangle_hit(origin, direction, index, true)
		if not hit.is_empty() and (nearest.is_empty() or hit.distance < nearest.distance):
			nearest = hit
	return nearest


func _triangle_hit(origin: Vector3, direction: Vector3, index: int, bounded: bool) -> Dictionary:
	var triangle := _triangles[index]
	var edge_b: Vector3 = triangle.b - triangle.a
	var edge_c: Vector3 = triangle.c - triangle.a
	var p := direction.cross(edge_c)
	var determinant := edge_b.dot(p)
	if absf(determinant) < 0.000001:
		return {}
	var offset: Vector3 = origin - triangle.a
	var u := offset.dot(p) / determinant
	var q := offset.cross(edge_b)
	var v := direction.dot(q) / determinant
	var distance := edge_c.dot(q) / determinant
	if distance < 0.0 or (bounded and (u < -0.00001 or v < -0.00001 or u + v > 1.00001)):
		return {}
	return {"uv": triangle.uv_a * (1.0 - u - v) + triangle.uv_b * u + triangle.uv_c * v, "distance": distance, "triangle": index}


func _send_mouse(event: InputEventMouse, position: Vector2) -> void:
	if not is_instance_valid(_viewport) or not _viewport.is_inside_tree():
		return
	var forwarded := event.duplicate() as InputEventMouse
	forwarded.position = position
	forwarded.global_position = position
	if forwarded is InputEventMouseMotion:
		forwarded.relative = position - _last_position
	_last_position = position
	_viewport.push_input(forwarded, true)


func _cancel_gui_input() -> void:
	if _cancelling_input:
		return
	_cancelling_input = true
	var buttons := _pressed_buttons.keys()
	_pressed_buttons.clear()
	_captured_triangle = -1
	if is_instance_valid(_viewport) and _viewport.is_inside_tree():
		if not buttons.is_empty():
			# Button release consults its cached hover state, not only the release
			# coordinates. Move away first, or Esc can accidentally activate Exit.
			_send_mouse(InputEventMouseMotion.new(), Vector2(-100, -100))
		_set_mouse_inside(false)
		for button in buttons:
			var release := InputEventMouseButton.new()
			release.button_index = button
			release.pressed = false
			_send_mouse(release, Vector2(-100, -100))
		if is_instance_valid(_viewport) and _viewport.is_inside_tree():
			_viewport.gui_release_focus()
	_cancelling_input = false


func _set_mouse_inside(inside: bool) -> void:
	if _mouse_inside == inside:
		return
	_mouse_inside = inside
	if not is_instance_valid(_viewport) or not _viewport.is_inside_tree():
		return
	if inside:
		_viewport.notify_mouse_entered()
	else:
		_viewport.notify_mouse_exited()


func _has_display() -> bool:
	return is_instance_valid(_mesh) and _mesh.mesh != null and _surface_index < _mesh.mesh.get_surface_count() and _mesh.get_surface_override_material(_surface_index) == _material


func _ensure_runtime() -> void:
	if is_instance_valid(_viewport):
		return
	_viewport = SubViewport.new()
	_viewport.name = "TerminalViewport"
	_viewport.size = DISPLAY_SIZE
	_viewport.disable_3d = true
	_viewport.gui_disable_input = not _active
	_viewport.handle_input_locally = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_content = Control.new()
	_content.name = "ContentRoot"
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_content)
	_material = ShaderMaterial.new()
	_material.resource_local_to_scene = true
	_material.shader = CRT_SHADER
	_material.set_shader_parameter("content_texture", _viewport.get_texture())
	_material.set_shader_parameter("vhs_enabled", _vhs_enabled)


func _release_surface() -> void:
	set_active(false)
	if is_instance_valid(_video):
		_video.detach_display(self)
	elif _has_display():
		_mesh.set_surface_override_material(_surface_index, _original_material)
	if is_instance_valid(_viewport):
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_mesh = null
	_video = null
	_playback_material = null
	_original_material = null
	_triangles.clear()


func _exit_tree() -> void:
	_release_surface()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_release_surface()
