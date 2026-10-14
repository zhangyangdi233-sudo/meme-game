extends Node
## A render-only view of the existing world for HandXRayOverlay's clipped window.
## It never owns input, enables hardware, or decides whether the gesture is active.

const XRAY_RENDER_LAYER := 1 << 19

var _source: Camera3D
var _viewport: SubViewport
var _camera: Camera3D


func bind_camera(source: Camera3D) -> void:
	_source = source
	if _viewport == null:
		_viewport = SubViewport.new()
		_viewport.name = "XRayViewport"
		_viewport.size = Vector2i(2, 2)
		_viewport.own_world_3d = false
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_viewport.audio_listener_enable_3d = false
		add_child(_viewport)
		_camera = Camera3D.new()
		_camera.name = "XRayCamera"
		_viewport.add_child(_camera)
		_camera.current = true
	update_view(false, _viewport.size)


func update_view(active: bool, viewport_size: Vector2i) -> void:
	if _viewport == null:
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if not is_instance_valid(_source) or not _source.is_inside_tree():
		return
	_viewport.world_3d = _source.get_world_3d()
	_viewport.size = Vector2i(maxi(1, viewport_size.x), maxi(1, viewport_size.y))
	_camera.global_transform = _source.global_transform
	_camera.projection = _source.projection
	_camera.keep_aspect = _source.keep_aspect
	_camera.fov = _source.fov
	_camera.size = _source.size
	_camera.near = _source.near
	_camera.far = _source.far
	_camera.frustum_offset = _source.frustum_offset
	_camera.h_offset = _source.h_offset
	_camera.v_offset = _source.v_offset
	_camera.environment = _source.environment
	_camera.attributes = _source.attributes
	_camera.cull_mask = _source.cull_mask | XRAY_RENDER_LAYER
	if active:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func get_texture() -> Texture2D:
	return _viewport.get_texture() if _viewport != null else null


func is_rendering() -> bool:
	return is_instance_valid(_viewport) and _viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS


func _exit_tree() -> void:
	if is_instance_valid(_viewport):
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
