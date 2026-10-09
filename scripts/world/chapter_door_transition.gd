extends Node
## Owns the camera approach and blackout; the caller replaces the room when
## room_requested fires and keeps gameplay locked until finished fires.

signal room_requested
signal finished
signal cancelled

const APPROACH_SECONDS := 0.35
const FADE_SECONDS := 0.35
const BLACK_HOLD_SECONDS := 0.12

enum Phase { IDLE, APPROACH, OPENING, FADE_OUT, BLACK_HOLD, FADE_IN }

var _phase: Phase = Phase.IDLE
var _paused: bool = false
var _camera: Camera3D
var _ui_root: Control
var _door: Node3D
var _overlay: ColorRect
var _tween: Tween
var _camera_start: Transform3D
var _camera_destination: Transform3D


func begin(camera: Camera3D, ui_root: Control, door: Node3D, camera_position: Vector3, look_target: Vector3, cover_color: Color = Color.BLACK) -> bool:
	if is_active() or not is_inside_tree():
		return false
	for participant in [camera, ui_root, door]:
		if not is_instance_valid(participant) or participant.is_queued_for_deletion() or not participant.is_inside_tree():
			return false
	if not door.has_method("request_open") or not door.has_method("set_paused") or not door.has_signal("opened"):
		return false
	var view_direction := look_target - camera_position
	if not camera_position.is_finite() or not look_target.is_finite() or view_direction.is_zero_approx():
		return false
	if view_direction.normalized().cross(Vector3.UP).is_zero_approx():
		return false
	_camera = camera
	_ui_root = ui_root
	_door = door
	_paused = false
	_phase = Phase.APPROACH
	_camera_start = camera.global_transform
	_camera_destination = Transform3D(Basis.looking_at(view_direction, Vector3.UP), camera_position)
	_camera.tree_exiting.connect(_participant_exiting)
	_ui_root.tree_exiting.connect(_participant_exiting)
	_door.tree_exiting.connect(_participant_exiting)
	_door.connect("opened", _door_opened)
	_overlay = ColorRect.new()
	_overlay.name = "ChapterDoorTransitionOverlay"
	_overlay.color = Color(cover_color, 0.0)
	_overlay.z_index = 25
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_move_camera, 0.0, 1.0, APPROACH_SECONDS)
	_tween.tween_callback(_begin_opening)
	return true


func is_active() -> bool:
	return _phase != Phase.IDLE


func set_paused(value: bool) -> void:
	_paused = value
	if _tween != null and _tween.is_valid():
		if value:
			_tween.pause()
		else:
			_tween.play()
	if is_instance_valid(_door):
		_door.call("set_paused", value)


## Notify the owner after cleanup so it can release input and recreate the
## interrupted door. Owner teardown and successful completion suppress this.
func cancel(notify_cancelled: bool = true) -> void:
	var was_active := is_active()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	if is_instance_valid(_door) and _phase == Phase.OPENING:
		_door.call("set_paused", true)
	_release_door()
	_release_camera()
	if is_instance_valid(_ui_root) and _ui_root.tree_exiting.is_connected(_participant_exiting):
		_ui_root.tree_exiting.disconnect(_participant_exiting)
	_ui_root = null
	if is_instance_valid(_overlay):
		_overlay.hide()
		_overlay.queue_free()
	_overlay = null
	_phase = Phase.IDLE
	_paused = false
	if was_active and notify_cancelled:
		cancelled.emit()


func _move_camera(weight: float) -> void:
	if is_instance_valid(_camera):
		_camera.global_transform = _camera_start.interpolate_with(_camera_destination, weight)


func _begin_opening() -> void:
	_tween = null
	if not is_active() or not is_instance_valid(_door):
		cancel()
		return
	_phase = Phase.OPENING
	if not _door.call("request_open"):
		cancel()


func _door_opened() -> void:
	if _phase != Phase.OPENING:
		return
	_phase = Phase.FADE_OUT
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_overlay, "color:a", 1.0, FADE_SECONDS)
	_tween.tween_callback(_request_room)
	set_paused(_paused)


func _request_room() -> void:
	_phase = Phase.BLACK_HOLD
	# Room replacement may immediately free both the old door and old camera.
	# Drop their connections before invoking the receiver, and never use them
	# after the signal. Create the next tween first so a receiver can pause it.
	_release_door()
	_release_camera()
	_tween = create_tween()
	_tween.tween_interval(BLACK_HOLD_SECONDS)
	_tween.tween_callback(_fade_in)
	set_paused(_paused)
	room_requested.emit()


func _fade_in() -> void:
	_phase = Phase.FADE_IN
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_overlay, "color:a", 0.0, FADE_SECONDS)
	_tween.tween_callback(_finish)
	set_paused(_paused)


func _finish() -> void:
	cancel(false)
	finished.emit()


func _release_door() -> void:
	if is_instance_valid(_door):
		if _door.is_connected("opened", _door_opened):
			_door.disconnect("opened", _door_opened)
		if _door.tree_exiting.is_connected(_participant_exiting):
			_door.tree_exiting.disconnect(_participant_exiting)
	_door = null


func _release_camera() -> void:
	if is_instance_valid(_camera) and _camera.tree_exiting.is_connected(_participant_exiting):
		_camera.tree_exiting.disconnect(_participant_exiting)
	_camera = null


func _participant_exiting() -> void:
	cancel()


func _exit_tree() -> void:
	cancel(false)
