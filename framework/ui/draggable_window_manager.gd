class_name DraggableWindowManager
extends Node
## Title-bar window dragging with viewport clamp. Game supplies ids, enablement, and extra left bounds.

signal window_drag_released(window_id: String)

const DEFAULT_VISIBLE_EDGE := 88.0
const DEFAULT_BOTTOM_INSET := 56.0
const DRAG_Z_INDEX := 24
const MISSING_WINDOW_POSITION := Vector2(INF, INF)

var enabled := true

var _windows: Dictionary = {}
var _min_x_by_id: Dictionary = {}
var _dragged_window: Control
var _dragged_id := ""
var _drag_offset := Vector2.ZERO
var _left_bound := -1.0e6
var _visible_edge := DEFAULT_VISIBLE_EDGE
var _bottom_inset := DEFAULT_BOTTOM_INSET


func register(window: Control, window_id: String, handle: Control) -> void:
	if window == null or handle == null or window_id.is_empty():
		return
	_windows[window_id] = window
	if bool(handle.get_meta("drag_connected", false)) and str(handle.get_meta("drag_window_id", "")) == window_id:
		return
	handle.set_meta("drag_connected", true)
	handle.set_meta("drag_window_id", window_id)
	handle.set_meta("drag_handle", true)
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
	handle.gui_input.connect(_on_handle_gui_input.bind(window_id, window, handle))


func set_clamp_bounds(left: float, visible_edge: float, bottom_inset: float) -> void:
	_left_bound = left
	_visible_edge = visible_edge
	_bottom_inset = bottom_inset


## Per-window floor on X; merged with global left bound and hang-off-screen allowance.
func set_window_min_x(window_id: String, min_x: float) -> void:
	_min_x_by_id[window_id] = min_x


func move_window(window_id: String, delta: Vector2) -> bool:
	if not enabled:
		return false
	var window := get_registered_window(window_id)
	if window == null:
		return false
	window.position += delta
	_raise_window(window)
	_clamp_window(window, window_id)
	return true


## Returns MISSING_WINDOW_POSITION when the id is unknown or the control was freed.
func get_window_position(window_id: String) -> Vector2:
	var window := get_registered_window(window_id)
	if window == null:
		return MISSING_WINDOW_POSITION
	return window.position


func get_registered_window(window_id: String) -> Control:
	if not _windows.has(window_id):
		return null
	var stored: Variant = _windows[window_id]
	if stored == null or not is_instance_valid(stored):
		_windows.erase(window_id)
		return null
	return stored as Control


func clear() -> void:
	_windows.clear()
	_min_x_by_id.clear()
	_dragged_window = null
	_dragged_id = ""
	_drag_offset = Vector2.ZERO


func handle_global_input(event: InputEvent) -> void:
	if not enabled or _dragged_window == null or not is_instance_valid(_dragged_window):
		return
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		_update_drag_position(_dragged_window, _dragged_id, event)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag()
	elif event is InputEventScreenTouch and not event.pressed:
		_finish_drag()


func _on_handle_gui_input(event: InputEvent, window_id: String, window: Control, handle: Control) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(window_id, window, event)
		else:
			_finish_drag()
		if not (handle is Button):
			handle.accept_event()
	elif event is InputEventMouseMotion and _dragged_window == window:
		_update_drag_position(window, window_id, event)
		if not (handle is Button):
			handle.accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_begin_drag(window_id, window, event)
		else:
			_finish_drag()
		handle.accept_event()
	elif event is InputEventScreenDrag and _dragged_window == window:
		_update_drag_position(window, window_id, event)
		handle.accept_event()


func _begin_drag(window_id: String, window: Control, event: InputEvent) -> void:
	_dragged_window = window
	_dragged_id = window_id
	_drag_offset = _pointer_position(event) - window.global_position
	_raise_window(window)


func _finish_drag() -> void:
	var released_id := _dragged_id
	_dragged_window = null
	_dragged_id = ""
	if not released_id.is_empty():
		window_drag_released.emit(released_id)


func _update_drag_position(window: Control, window_id: String, event: InputEvent) -> void:
	window.global_position = _pointer_position(event) - _drag_offset
	_clamp_window(window, window_id)


func _raise_window(window: Control) -> void:
	window.move_to_front()
	if window is CanvasItem:
		(window as CanvasItem).z_index = maxi((window as CanvasItem).z_index, DRAG_Z_INDEX)


func _clamp_window(window: Control, window_id: String) -> void:
	var viewport_size := Vector2.ZERO
	if get_viewport() != null:
		viewport_size = get_viewport().get_visible_rect().size
	var hang_min_x := -maxf(0.0, window.size.x - _visible_edge)
	var min_x := maxf(_left_bound, hang_min_x)
	if _min_x_by_id.has(window_id):
		min_x = maxf(min_x, float(_min_x_by_id[window_id]))
	var max_x := viewport_size.x - _visible_edge
	var max_y := viewport_size.y - _bottom_inset
	window.position = Vector2(
		clampf(window.position.x, min_x, max_x),
		clampf(window.position.y, 0.0, max_y)
	)


func _pointer_position(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return (event as InputEventMouse).global_position
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	if get_viewport() != null:
		return get_viewport().get_mouse_position()
	return Vector2.ZERO
