extends Container
class_name RadialSelectorRing

signal selection_changed(index: int)

const PAN_STEP_THRESHOLD := 1.35
const ITEM_ANGLE_STEP := 0.46
const ITEM_BASE_SIZE := Vector2(134.0, 54.0)
const SELECTED_ITEM_SCALE := Vector2(1.30, 1.30)
const MOTION_DURATION := 0.34
const MOTION_TRANSITION := Tween.TRANS_QUINT
const MOTION_EASE := Tween.EASE_OUT
const MOTION_PROPERTIES := ["position", "scale", "modulate:a"]

var selected_index := 0
var _pan_accumulator := 0.0
var _ring_color := Color("E7F1DC")
var _inner_color := Color("AAB8A7")
var _focus_color := Color("365B2D")
var _motion_tween: Tween = null
var _animate_next_layout := false
var _has_laid_out := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	gui_input.connect(_on_ring_gui_input)
	resized.connect(_queue_ring_layout)
	_queue_ring_layout()


func _exit_tree() -> void:
	_stop_motion_tween()


func set_palette(ring_color: Color, inner_color: Color, focus_color: Color) -> void:
	_ring_color = ring_color
	_inner_color = inner_color
	_focus_color = focus_color
	queue_redraw()


func get_motion_profile() -> Dictionary:
	return {
		"duration": MOTION_DURATION,
		"transition": MOTION_TRANSITION,
		"ease": MOTION_EASE,
		"properties": MOTION_PROPERTIES.duplicate(),
		"interrupts_previous": true,
	}


func set_selected_index(value: int, emit_change: bool = false) -> void:
	var count := get_child_count()
	var next_index := 0 if count <= 0 else posmod(value, count)
	if selected_index == next_index:
		_queue_ring_layout()
		return
	selected_index = next_index
	_request_ring_layout(true)
	if emit_change:
		selection_changed.emit(selected_index)


func step_selection(direction: int) -> bool:
	if direction == 0 or get_child_count() <= 0:
		return false
	set_selected_index(selected_index + direction, true)
	return true


func handle_navigation_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			return step_selection(-1)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			return step_selection(1)
	if event is InputEventPanGesture:
		var pan := event as InputEventPanGesture
		var dominant_delta := pan.delta.y if absf(pan.delta.y) >= absf(pan.delta.x) else pan.delta.x
		_pan_accumulator += dominant_delta
		if absf(_pan_accumulator) >= PAN_STEP_THRESHOLD:
			var direction := 1 if _pan_accumulator > 0.0 else -1
			_pan_accumulator = 0.0
			return step_selection(direction)
	return false


func _on_ring_gui_input(event: InputEvent) -> void:
	if handle_navigation_event(event):
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_layout_ring_items()


func _draw() -> void:
	_draw_ring()


func _queue_ring_layout() -> void:
	_request_ring_layout(false)


func _request_ring_layout(animate_selection: bool) -> void:
	_stop_motion_tween()
	_animate_next_layout = animate_selection and _has_laid_out
	queue_sort()
	queue_redraw()


func _layout_ring_items() -> void:
	var count := get_child_count()
	if count <= 0:
		_stop_motion_tween()
		_animate_next_layout = false
		_has_laid_out = false
		return
	selected_index = posmod(selected_index, count)
	var should_animate := _animate_next_layout and _has_laid_out and is_inside_tree()
	_animate_next_layout = false
	var tween: Tween = _start_motion_tween() if should_animate else null
	var center := Vector2(size.x * 0.63, size.y * 0.52)
	var radius := minf(size.x, size.y) * 0.365
	for index in count:
		var child := get_child(index) as Control
		if child == null:
			continue
		var cyclic_delta := _cyclic_delta(index, selected_index, count)
		var angle := PI + float(cyclic_delta) * ITEM_ANGLE_STEP
		var is_selected := cyclic_delta == 0
		child.size = ITEM_BASE_SIZE
		child.pivot_offset = child.size * 0.5
		var item_center := center + Vector2(cos(angle), sin(angle)) * radius
		var target_position := item_center - child.size * 0.5
		var target_scale := SELECTED_ITEM_SCALE if is_selected else Vector2.ONE
		var target_alpha := 1.0 if is_selected else clampf(0.92 - float(absi(cyclic_delta)) * 0.12, 0.28, 0.82)
		child.z_index = 8 if is_selected else maxi(1, 6 - absi(cyclic_delta))
		if should_animate:
			child.modulate = Color(1.0, 1.0, 1.0, child.modulate.a)
			_tween_control_property(tween, child, ^"position", target_position)
			_tween_control_property(tween, child, ^"scale", target_scale)
			_tween_control_property(tween, child, ^"modulate:a", target_alpha)
		else:
			child.position = target_position
			child.scale = target_scale
			child.modulate = Color(1.0, 1.0, 1.0, target_alpha)
	_has_laid_out = true


func _start_motion_tween() -> Tween:
	_stop_motion_tween()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(MOTION_TRANSITION)
	tween.set_ease(MOTION_EASE)
	_motion_tween = tween
	tween.finished.connect(_on_motion_tween_finished.bind(tween))
	return tween


func _tween_control_property(tween: Tween, child: Control, property: NodePath, target: Variant) -> void:
	tween.tween_property(child, property, target, MOTION_DURATION).set_trans(MOTION_TRANSITION).set_ease(MOTION_EASE)


func _stop_motion_tween() -> void:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	_motion_tween = null


func _on_motion_tween_finished(tween: Tween) -> void:
	if _motion_tween == tween:
		_motion_tween = null


func _draw_ring() -> void:
	var center := Vector2(size.x * 0.63, size.y * 0.52)
	var radius := minf(size.x, size.y) * 0.365
	draw_arc(center, radius + 24.0, 0.0, TAU, 192, _ring_color, 26.0, true)
	var guide_color := _inner_color.lerp(_focus_color, 0.16)
	guide_color.a *= 0.30
	draw_arc(center, radius, 0.0, TAU, 192, guide_color, 2.0, true)


func _cyclic_delta(index: int, selected: int, count: int) -> int:
	var delta := index - selected
	var half := float(count) * 0.5
	if float(delta) > half:
		delta -= count
	elif float(delta) < -half:
		delta += count
	return delta
