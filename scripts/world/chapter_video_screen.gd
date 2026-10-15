extends Node3D
## An optional video source for a separately owned mesh surface. No resource is loaded
## implicitly and no playback starts on bind/set_stream. Powered screens default to
## green standby; stop()/natural completion restore standby, power_off() shows black.
## Supply a supported VideoStream (normally imported .ogv), then call play() in-tree.
## This component follows Godot's VideoStreamPlayer -> SubViewport -> material route:
## https://docs.godotengine.org/en/4.6/tutorials/animation/playing_videos.html

signal playback_finished
signal playback_failed(reason: String)
signal playback_stopped
signal power_changed(powered_on: bool)

const DEFAULT_STANDBY_COLOR := Color("69D875")

var _mesh: MeshInstance3D
var _surface_index: int = 0
var _original_material: Material
var _material: StandardMaterial3D
var _viewport: SubViewport
var _player: VideoStreamPlayer
var _standby_color: Color = DEFAULT_STANDBY_COLOR
var _powered_on: bool = true
var _display_owner: WeakRef
var _display_material: Material
var _display_playback_material: Material
var _signal_material: StandardMaterial3D
var _signal_override := false
var _pause_before_signal := false
var _ambient_playback := false


func is_bound_to(mesh: MeshInstance3D, surface_index: int = 0) -> bool:
	return is_instance_valid(_mesh) and _mesh == mesh and _surface_index == surface_index


## A borrowed GUI display participates in the same power/playback controller.
## Playback overrides it temporarily; stop/finish restore it while powered on.
func attach_display(owner: Object, material: Material, playback_effect_material: Material = null) -> bool:
	if not is_instance_valid(owner) or material == null or not is_instance_valid(_mesh):
		return false
	if _display_owner != null and _display_owner.get_ref() != null and _display_owner.get_ref() != owner:
		return false
	if not _owns_surface_material():
		return false
	# Keep ownership recognizable when the same owner replaces either material.
	_mesh.set_surface_override_material(_surface_index, _material)
	_display_owner = weakref(owner)
	_display_material = material
	_display_playback_material = playback_effect_material
	_refresh_display_material()
	return true


func detach_display(owner: Object) -> void:
	if _display_owner == null or _display_owner.get_ref() != owner:
		return
	var owns_surface := _owns_surface_material()
	_display_owner = null
	_display_material = null
	_display_playback_material = null
	if owns_surface:
		_mesh.set_surface_override_material(_surface_index, _material)
		_refresh_display_material()


func _owns_surface_material() -> bool:
	if not is_instance_valid(_mesh) or _mesh.mesh == null or _surface_index >= _mesh.mesh.get_surface_count():
		return false
	var current := _mesh.get_surface_override_material(_surface_index)
	return current == _material or (_display_material != null and current == _display_material) or (_display_playback_material != null and current == _display_playback_material) or (_signal_material != null and current == _signal_material)


func _refresh_display_material() -> void:
	if not _owns_surface_material():
		return
	var display_alive := _display_owner != null and _display_owner.get_ref() != null
	var next: Material = _material
	if _signal_override:
		next = _signal_material
	elif _powered_on and display_alive:
		if _ambient_playback or not _has_active_display():
			next = _display_material
		elif _display_playback_material != null:
			next = _display_playback_material
	_mesh.set_surface_override_material(_surface_index, next)


## Temporarily replace the signal without touching power, stream, UI ownership,
## or playback position. Used by the fifth-room synchronized CRT interruption.
func set_signal_override(color: Color) -> void:
	_ensure_runtime()
	if not _signal_override:
		_pause_before_signal = _player.paused
		_signal_override = true
		_player.paused = true
	if _signal_material == null:
		_signal_material = StandardMaterial3D.new()
		_signal_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_signal_material.albedo_color = color
	_refresh_display_material()


func clear_signal_override() -> void:
	if not _signal_override:
		return
	_signal_override = false
	if is_instance_valid(_player) and _player.is_inside_tree():
		_player.paused = _pause_before_signal
	_refresh_display_material()


func set_playback_paused(value: bool) -> void:
	if not is_instance_valid(_player):
		return
	if _signal_override:
		_pause_before_signal = value
	_player.paused = value or _signal_override


func set_looping(value: bool) -> void:
	_ensure_runtime()
	_player.loop = value


## Background room video yields its surface to an attached interactive terminal.
## Detaching the terminal reveals the same live playback without restarting it.
func set_ambient_playback(value: bool) -> void:
	_ambient_playback = value
	_refresh_display_material()


func set_volume_db(value: float) -> void:
	_ensure_runtime()
	_player.volume_db = value


func get_playback_texture() -> Texture2D:
	_ensure_runtime()
	return _viewport.get_texture()


func bind_screen(mesh: MeshInstance3D, surface_index: int = 0) -> void:
	stop()
	_restore_material()
	if not is_instance_valid(mesh) or mesh.mesh == null:
		return
	if surface_index < 0 or surface_index >= mesh.mesh.get_surface_count():
		return
	_ensure_runtime()
	_mesh = mesh
	_surface_index = surface_index
	_original_material = mesh.get_surface_override_material(surface_index)
	mesh.set_surface_override_material(surface_index, _material)


func set_stream(stream: VideoStream) -> void:
	_ensure_runtime()
	stop()
	_player.stream = stream
	var texture := _player.get_video_texture()
	if texture != null and texture.get_width() > 0 and texture.get_height() > 0:
		_viewport.size = Vector2i(texture.get_width(), texture.get_height())


## Standby is a flat unshaded color, independent of any old video frame. Changing
## this setting during playback takes effect at the next stop or completion.
func set_standby_color(color: Color) -> void:
	_standby_color = color
	if not _has_active_display():
		_apply_idle_display()


func is_powered_on() -> bool:
	return _powered_on


func power_off() -> void:
	var changed := _powered_on
	_powered_on = false
	stop()
	if changed:
		power_changed.emit(false)


## Switching on restores standby only; it never autoplays the configured stream.
func power_on() -> void:
	var changed := not _powered_on
	_powered_on = true
	if not _has_active_display():
		_apply_idle_display()
	if changed:
		power_changed.emit(true)


## A true result means the player accepted playback, not that media/audio has been
## externally validated. Without a stream or valid mesh binding this safely returns false.
## Failed requests emit playback_failed with not_in_tree, unbound_screen, no_stream,
## or playback_not_started. Missing optional media is a normal no_stream result.
func play(from_seconds: float = 0.0) -> bool:
	if not is_inside_tree():
		return _fail_playback("not_in_tree")
	if not is_instance_valid(_mesh):
		return _fail_playback("unbound_screen")
	if not is_instance_valid(_player) or _player.stream == null:
		return _fail_playback("no_stream")
	_player.paused = false
	_player.play()
	if from_seconds > 0.0:
		var duration := _player.get_stream_length()
		_player.stream_position = fmod(from_seconds, duration) if duration > 0.0 else from_seconds
	if not _player.is_playing():
		return _fail_playback("playback_not_started")
	var power_was_off := not _powered_on
	_powered_on = true
	_player.visible = true
	_material.albedo_color = Color.WHITE
	_material.albedo_texture = _viewport.get_texture()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_refresh_display_material()
	if power_was_off:
		power_changed.emit(true)
	return true


func stop() -> void:
	var was_active := _has_active_display()
	_clear_playback()
	if was_active:
		playback_stopped.emit()


func _on_playback_finished() -> void:
	var was_active := _has_active_display()
	_clear_playback()
	if was_active:
		playback_finished.emit()


func _fail_playback(reason: String) -> bool:
	stop()
	playback_failed.emit(reason)
	return false


func _has_active_display() -> bool:
	# The engine stops playing before emitting finished; the visible player still
	# identifies that playback until the terminal callback clears it.
	return is_instance_valid(_player) and (_player.visible or _player.is_playing())


func _clear_playback() -> void:
	if is_instance_valid(_player):
		_player.stop()
		_player.paused = false
		_player.visible = false
	if is_instance_valid(_viewport):
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_apply_idle_display()


func _apply_idle_display() -> void:
	if _material != null:
		# A stopped or disabled viewport can contain black/stale pixels. Detach it
		# completely so standby color is never multiplied by the previous frame.
		_material.albedo_texture = null
		_material.albedo_color = _standby_color if _powered_on else Color.BLACK
	_refresh_display_material()


func _ensure_runtime() -> void:
	if is_instance_valid(_viewport):
		return
	_viewport = SubViewport.new()
	_viewport.name = "VideoViewport"
	_viewport.size = Vector2i(640, 480)
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_player = VideoStreamPlayer.new()
	_player.name = "VideoPlayer"
	_player.autoplay = false
	_player.expand = false
	_player.visible = false
	_viewport.add_child(_player)
	# The parent's _exit_tree runs after its children have already exited. Clear pause
	# while this player is still in-tree; Godot checks can_process() when unpausing.
	_player.tree_exiting.connect(stop)
	_player.finished.connect(_on_playback_finished)
	_material = StandardMaterial3D.new()
	_material.resource_local_to_scene = true
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_texture_force_srgb = true
	_apply_idle_display()


func _restore_material() -> void:
	if _owns_surface_material():
		_mesh.set_surface_override_material(_surface_index, _original_material)
	_mesh = null
	_original_material = null
	_display_owner = null
	_display_material = null
	_display_playback_material = null
	_signal_override = false


func _exit_tree() -> void:
	_cleanup()


func _notification(what: int) -> void:
	# A screen may be bound before being attached to the scene tree. Its mesh is
	# externally owned and must not retain our material after direct free().
	if what == NOTIFICATION_PREDELETE:
		_cleanup()


func _cleanup() -> void:
	stop()
	_restore_material()
