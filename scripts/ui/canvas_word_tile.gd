class_name CanvasWordTile
extends Button
## 笔记本画布上的字词瓦片:在画布内可自由拖动摆放,拖出画布可投放到发布页。
##
## 设计依据 docs/research/social_compose_ui_benchmark.md:
## - 拖动与点击共存,位移阈值区分(参考各社交 App 的 chip 交互);
## - 拖出画布不丢失:未命中投放区就飞回原位,字词永远留在笔记本。

signal tile_moved(unit: String, position: Vector2)
signal tile_dropped_outside(unit: String, global_position: Vector2)
signal tile_tapped(unit: String)

const DRAG_THRESHOLD := 6.0

var unit_text: String = ""

var _pressed_inside := false
var _dragging := false
var _grab_offset := Vector2.ZERO
var _press_global := Vector2.ZERO


func configure_tile(unit: String) -> void:
	unit_text = unit
	text = unit
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_meta("skip_localization", true)
	set_meta("canvas_word_tile", true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button_event := event as InputEventMouseButton
		if button_event.pressed:
			_pressed_inside = true
			_dragging = false
			_press_global = button_event.global_position
			_grab_offset = button_event.position
			accept_event()
		else:
			if _dragging:
				_finish_drag(button_event.global_position)
			elif _pressed_inside:
				tile_tapped.emit(unit_text)
			_pressed_inside = false
			_dragging = false
			z_index = 0
			accept_event()
	elif event is InputEventMouseMotion and _pressed_inside:
		var motion := event as InputEventMouseMotion
		if not _dragging and motion.global_position.distance_to(_press_global) < DRAG_THRESHOLD:
			return
		_dragging = true
		z_index = 20
		var parent_control := get_parent() as Control
		if parent_control != null:
			position = parent_control.get_local_mouse_position() - _grab_offset
		accept_event()


func _finish_drag(release_global: Vector2) -> void:
	var parent_control := get_parent() as Control
	if parent_control == null:
		return
	var canvas_rect := Rect2(parent_control.get_global_rect().position, parent_control.get_global_rect().size)
	if canvas_rect.has_point(release_global):
		tile_moved.emit(unit_text, position)
	else:
		tile_dropped_outside.emit(unit_text, release_global)
