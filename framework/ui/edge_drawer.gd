class_name EdgeDrawer
extends Node
## Left-edge slide-out panel: hover/touch reveal, auto-close, and pinned touch dismiss.

signal expanded_changed(expanded: bool)

var enabled := true

var _panel: Control
var _reveal_zone: Control
var _companions: Array[Control] = []
var _exclusions: Array[Control] = []
var _expanded := false
var _touch_pinned := false
var _close_countdown := -1.0
var _drawer_tween: Tween
var _rail_width := 158.0
var _open_duration := 0.26
var _close_duration := 0.18
var _close_delay := 0.22


func attach(panel: Control, reveal_zone: Control) -> void:
	_companions.clear()
	_exclusions.clear()
	reset_runtime_state()
	_panel = panel
	_reveal_zone = reveal_zone
	if _panel != null:
		if not _panel.mouse_entered.is_connected(_on_panel_pointer_entered):
			_panel.mouse_entered.connect(_on_panel_pointer_entered)
		if not _panel.mouse_exited.is_connected(schedule_close):
			_panel.mouse_exited.connect(schedule_close)
	if _reveal_zone != null:
		if not _reveal_zone.mouse_entered.is_connected(_on_reveal_zone_entered):
			_reveal_zone.mouse_entered.connect(_on_reveal_zone_entered)
		if not _reveal_zone.mouse_exited.is_connected(schedule_close):
			_reveal_zone.mouse_exited.connect(schedule_close)
		if not _reveal_zone.gui_input.is_connected(_on_reveal_zone_gui_input):
			_reveal_zone.gui_input.connect(_on_reveal_zone_gui_input)


func add_companion(control: Control) -> void:
	if control != null and control not in _companions:
		_companions.append(control)


func add_exclusion(control: Control) -> void:
	if control != null and control not in _exclusions:
		_exclusions.append(control)


func configure(rail_width: float, open_duration: float, close_duration: float, close_delay: float) -> void:
	_rail_width = rail_width
	_open_duration = open_duration
	_close_duration = close_duration
	_close_delay = close_delay


func set_expanded(expanded: bool, animate: bool = true) -> void:
	if _panel == null:
		return
	if _expanded != expanded:
		expanded_changed.emit(expanded)
	_expanded = expanded
	_close_countdown = -1.0
	_panel.set_meta("drawer_state", "expanded" if expanded else "collapsed")
	_panel.set_meta("motion_easing", "easeOutQuint" if expanded else "easeInQuint")
	if not expanded:
		_hide_companions()
	if _drawer_tween != null and _drawer_tween.is_valid():
		_drawer_tween.kill()
	_drawer_tween = null
	var target_position := Vector2(panel_x(expanded), _panel.position.y)
	if not animate or not is_inside_tree():
		_panel.position = target_position
		_panel.set_meta("motion_phase", "idle")
		return
	_panel.set_meta("motion_phase", "opening" if expanded else "closing")
	var duration := _open_duration if expanded else _close_duration
	var ease := Tween.EASE_OUT if expanded else Tween.EASE_IN
	_drawer_tween = create_tween()
	_drawer_tween.tween_property(_panel, "position", target_position, duration).set_trans(Tween.TRANS_QUINT).set_ease(ease)
	_drawer_tween.finished.connect(_finish_motion.bind(_drawer_tween), CONNECT_ONE_SHOT)


func is_expanded() -> bool:
	return _expanded


func panel_x(expanded: bool) -> float:
	return 0.0 if expanded else -_rail_width


func layout_panel_x() -> float:
	if _panel == null:
		return 0.0
	if _drawer_tween != null and _drawer_tween.is_valid():
		return _panel.position.x
	return panel_x(_expanded)


func schedule_close() -> void:
	if not _expanded or _touch_pinned:
		return
	_close_countdown = _close_delay


func handle_global_input(event: InputEvent) -> bool:
	if not enabled or not _expanded or not _touch_pinned or not event is InputEventScreenTouch:
		return false
	var touch := event as InputEventScreenTouch
	if not touch.pressed:
		return false
	if _contains_point(_panel, touch.position):
		return false
	if _any_contains_point(_companions, touch.position):
		return false
	if _any_contains_point(_exclusions, touch.position):
		return false
	_touch_pinned = false
	set_expanded(false)
	get_viewport().set_input_as_handled()
	return true


func tick(delta: float) -> void:
	if not enabled or not _expanded or _touch_pinned or _panel == null:
		return
	if _is_pointer_over_drawer():
		_close_countdown = -1.0
		return
	if _close_countdown < 0.0:
		_close_countdown = _close_delay
		return
	_close_countdown -= delta
	if _close_countdown <= 0.0:
		set_expanded(false)


## Clears motion/touch state. Registration is rebuilt by attach() on each UI rebuild.
func reset_runtime_state() -> void:
	if _drawer_tween != null and _drawer_tween.is_valid():
		_drawer_tween.kill()
	_drawer_tween = null
	_expanded = false
	_touch_pinned = false
	_close_countdown = -1.0
	if _panel != null and is_instance_valid(_panel):
		_panel.position.x = panel_x(false)
		_panel.set_meta("motion_phase", "idle")
		_panel.set_meta("drawer_state", "collapsed")


func _finish_motion(completed_tween: Tween) -> void:
	if completed_tween != _drawer_tween or _panel == null:
		return
	_panel.position.x = panel_x(_expanded)
	_panel.set_meta("motion_phase", "idle")
	_drawer_tween = null


func _on_reveal_zone_entered() -> void:
	if not enabled:
		return
	_touch_pinned = false
	set_expanded(true)


func _on_panel_pointer_entered() -> void:
	if not enabled:
		return
	_close_countdown = -1.0
	if not _expanded:
		set_expanded(true)


func _on_reveal_zone_gui_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		pressed = mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed
	if not pressed or not enabled:
		return
	_touch_pinned = true
	set_expanded(true)
	get_viewport().set_input_as_handled()


func _is_pointer_over_drawer() -> bool:
	var pointer := get_viewport().get_mouse_position()
	if _contains_point(_panel, pointer):
		return true
	if _contains_point(_reveal_zone, pointer):
		return true
	return _any_contains_point(_companions, pointer)


func _contains_point(control: Control, point: Vector2) -> bool:
	return control != null and control.visible and control.get_global_rect().has_point(point)


func _any_contains_point(controls: Array[Control], point: Vector2) -> bool:
	for control in controls:
		if _contains_point(control, point):
			return true
	return false


func _hide_companions() -> void:
	for companion in _companions:
		if companion != null:
			companion.visible = false
