class_name CinematicBars
extends Control
## Letterbox bars: height from target aspect, capped by max_bar_ratio. Viewport size is passed in.

const TOP_BAR_NAME := "CinematicTopBar"
const BOTTOM_BAR_NAME := "CinematicBottomBar"
const BAR_Z_INDEX := 8

var bar_color := Color.BLACK:
	set(value):
		bar_color = value
		_apply_bar_color()

var _target_aspect := 2.35
var _max_bar_ratio := 0.12
var _top_bar: ColorRect
var _bottom_bar: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_ensure_bars()


func configure(target_aspect: float, max_bar_ratio: float) -> void:
	_target_aspect = target_aspect
	_max_bar_ratio = max_bar_ratio
	_ensure_bars()
	_apply_bar_color()


func relayout(viewport_size: Vector2) -> void:
	_ensure_bars()
	var height := bar_height(viewport_size)
	_top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_bar.offset_left = 0.0
	_top_bar.offset_top = 0.0
	_top_bar.offset_right = 0.0
	_top_bar.offset_bottom = height
	_bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom_bar.offset_left = 0.0
	_bottom_bar.offset_top = -height
	_bottom_bar.offset_right = 0.0
	_bottom_bar.offset_bottom = 0.0


func bar_height(viewport_size: Vector2) -> float:
	if _target_aspect <= 0.0:
		return 0.0
	var picture_height := viewport_size.x / _target_aspect
	return clampf((viewport_size.y - picture_height) * 0.5, 0.0, viewport_size.y * _max_bar_ratio)


func set_bars_visible(value: bool) -> void:
	_ensure_bars()
	_top_bar.visible = value
	_bottom_bar.visible = value


func _ensure_bars() -> void:
	if _top_bar != null and _bottom_bar != null:
		return
	_top_bar = _make_bar(TOP_BAR_NAME)
	_bottom_bar = _make_bar(BOTTOM_BAR_NAME)
	_apply_bar_color()


func _make_bar(bar_name: String) -> ColorRect:
	var bar := ColorRect.new()
	bar.name = bar_name
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.z_index = BAR_Z_INDEX
	add_child(bar)
	return bar


func _apply_bar_color() -> void:
	if _top_bar == null or _bottom_bar == null:
		return
	_top_bar.color = bar_color
	_bottom_bar.color = bar_color
