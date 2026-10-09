extends Node3D
## A visual hinge and an independent doorway blocker. The caller owns both nodes.
## bind() captures the pivot's authored closed Y angle. For an initially open entry,
## bind(..., 90.0, 0.0), set_locked(false), then request_open() completes immediately.
## close_and_lock() permanently seals this instance; a new visit uses a new instance.

signal opened
signal closed

enum Motion { CLOSED, OPENING, OPEN, CLOSING }

var _pivot: Node3D
var _blocker: CollisionShape3D
var _closed_angle: float = 0.0
var _open_angle: float = PI * 0.5
var _duration: float = 0.4
var _locked: bool = true
var _sealed: bool = false
var _motion: Motion = Motion.CLOSED
var _tween: Tween


func bind(pivot: Node3D, blocker: CollisionShape3D, open_angle_degrees: float = 90.0, duration: float = 0.4) -> void:
	_stop_motion()
	_set_blocked(true)
	_pivot = pivot
	_blocker = blocker
	_closed_angle = pivot.rotation.y if is_instance_valid(pivot) else 0.0
	_open_angle = _closed_angle + deg_to_rad(open_angle_degrees)
	_duration = maxf(duration, 0.0)
	_motion = Motion.CLOSED
	_set_blocked(true)


func set_locked(value: bool) -> void:
	_locked = value or _sealed
	if _locked:
		_close()


func set_paused(value: bool) -> void:
	if _tween == null or not _tween.is_valid():
		return
	if value:
		_tween.pause()
	else:
		_tween.play()


## Returns true only when this request begins an opening. Pending/duplicate requests
## return false. Positive-duration animation requires the component in the scene tree.
func request_open() -> bool:
	if _locked or _sealed or _motion == Motion.OPEN or _motion == Motion.OPENING:
		return false
	if not is_instance_valid(_pivot) or not is_instance_valid(_blocker):
		return false
	if _duration > 0.0 and not is_inside_tree():
		return false
	_stop_motion()
	_set_blocked(true)
	_motion = Motion.OPENING
	if is_zero_approx(_duration):
		_pivot.rotation.y = _open_angle
		_finish_open()
	else:
		_tween = create_tween()
		_tween.tween_property(_pivot, "rotation:y", _open_angle, _duration)
		_tween.tween_callback(_finish_open)
	return true


func close_and_lock() -> void:
	_sealed = true
	_locked = true
	_close()


func is_passable() -> bool:
	return _motion == Motion.OPEN and not _locked and not _sealed and is_instance_valid(_blocker) and _blocker.disabled


func _close() -> void:
	_set_blocked(true)
	if _motion == Motion.CLOSED or _motion == Motion.CLOSING:
		return
	_stop_motion()
	_motion = Motion.CLOSING
	if not is_instance_valid(_pivot) or is_zero_approx(_duration) or not is_inside_tree():
		if is_instance_valid(_pivot):
			_pivot.rotation.y = _closed_angle
		_finish_close()
	else:
		_tween = create_tween()
		_tween.tween_property(_pivot, "rotation:y", _closed_angle, _duration)
		_tween.tween_callback(_finish_close)


func _finish_open() -> void:
	_tween = null
	if _motion != Motion.OPENING or _locked or _sealed:
		return
	_motion = Motion.OPEN
	_set_blocked(false)
	opened.emit()


func _finish_close() -> void:
	_tween = null
	_motion = Motion.CLOSED
	closed.emit()


func _set_blocked(blocked: bool) -> void:
	if not is_instance_valid(_blocker):
		return
	# Threshold signals may arrive while physics queries are flushing.
	if Engine.is_in_physics_frame():
		_blocker.set_deferred("disabled", not blocked)
	else:
		_blocker.disabled = not blocked


func _stop_motion() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _exit_tree() -> void:
	_cleanup()


func _notification(what: int) -> void:
	# Never-tree bindings have no _exit_tree callback. Their external blocker must
	# still become solid when this independently owned controller is freed.
	if what == NOTIFICATION_PREDELETE:
		_cleanup()


func _cleanup() -> void:
	_stop_motion()
	_motion = Motion.CLOSED
	_set_blocked(true)
