class_name FlyToTargetLayer
extends Control
## 拾字飞行动画层:被拾取的字从帖子原位放大飞到屏幕正中央短暂定格,
## 再加速缩入左上角笔记本窗口。节拍与缓动依据 docs/research/pickup_anim_deep_research.md:
## P1 弧线放大飞中央(QUINT/OUT)→ P2 定格确认 → P3 加速缩入笔记本(CUBIC/IN)→ 落地信号。
## 恐怖氛围适配:聚焦靠背景压暗,不靠发光;缓动禁 Elastic/Bounce;无随机调用。

signal pickup_landed(unit: String)

const FLY_IN_DURATION := 0.36
const HOLD_DURATION := 0.50
const FLY_OUT_DURATION := 0.30
const CENTER_SCALE := 2.6
const LAND_SCALE := 0.55
const ARC_LIFT := 64.0
const BACKDROP_ALPHA := 0.38
const GLYPH_FONT_SIZE := 34

var _backdrop: ColorRect
var _active_count := 0
var _backdrop_tween: Tween
var _flight_tweens: Array[Tween] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop = ColorRect.new()
	_backdrop.name = "PickupFlightBackdrop"
	_backdrop.color = Color(0, 0, 0, 1)
	_backdrop.modulate.a = 0.0
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)


func is_animating() -> bool:
	return _active_count > 0


func play_pickup(unit_text: String, from_global: Vector2, target_getter: Callable, text_color: Color = Color(0.96, 0.98, 0.9)) -> void:
	var glyph := Label.new()
	glyph.name = "PickupFlightGlyph"
	glyph.text = unit_text
	glyph.set_meta("flashback_text", true)
	glyph.add_theme_font_size_override("font_size", GLYPH_FONT_SIZE)
	glyph.add_theme_color_override("font_color", text_color)
	glyph.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	glyph.add_theme_constant_override("shadow_offset_y", 2)
	glyph.z_index = 5
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glyph)
	glyph.size = glyph.get_minimum_size()
	glyph.pivot_offset = glyph.size * 0.5
	glyph.position = from_global - glyph.pivot_offset
	glyph.scale = Vector2.ONE

	_active_count += 1
	_fade_backdrop(BACKDROP_ALPHA, 0.14)

	var center := get_viewport_rect().size * 0.5
	var flight := create_tween()
	flight.tween_method(_glide_fixed.bind(glyph, from_global, center), 0.0, 1.0, FLY_IN_DURATION).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	flight.parallel().tween_property(glyph, "scale", Vector2.ONE * CENTER_SCALE, FLY_IN_DURATION).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	flight.tween_interval(HOLD_DURATION)
	flight.tween_method(_glide_tracked.bind(glyph, center, target_getter), 0.0, 1.0, FLY_OUT_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	flight.parallel().tween_property(glyph, "scale", Vector2.ONE * LAND_SCALE, FLY_OUT_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	flight.tween_callback(_finish_glyph.bind(glyph, unit_text))
	_flight_tweens.append(flight)


## 造句台的短飞行:词库瓦片 → 答案区,无居中定格、无压暗,0.18s 直达。
func play_place_flight(unit_text: String, from_global: Vector2, target_getter: Callable, text_color: Color = Color(0.96, 0.98, 0.9)) -> void:
	var glyph := Label.new()
	glyph.name = "PlaceFlightGlyph"
	glyph.text = unit_text
	glyph.set_meta("flashback_text", true)
	glyph.set_meta("skip_localization", true)
	glyph.add_theme_font_size_override("font_size", 24)
	glyph.add_theme_color_override("font_color", text_color)
	glyph.z_index = 5
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glyph)
	glyph.size = glyph.get_minimum_size()
	glyph.pivot_offset = glyph.size * 0.5
	glyph.position = from_global - glyph.pivot_offset
	_active_count += 1
	var flight := create_tween()
	flight.tween_method(_glide_tracked.bind(glyph, from_global, target_getter), 0.0, 1.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	flight.parallel().tween_property(glyph, "scale", Vector2.ONE * 0.9, 0.18)
	flight.tween_callback(_finish_glyph.bind(glyph, unit_text, true))
	_flight_tweens.append(flight)


func finish_all_immediately() -> void:
	for flight in _flight_tweens:
		if flight != null and flight.is_valid():
			flight.kill()
	_flight_tweens.clear()
	for child in get_children():
		if child is Label:
			(child as Label).queue_free()
	_active_count = 0
	_fade_backdrop(0.0, 0.05)


func _glide_fixed(progress: float, glyph: Variant, from_position: Vector2, to_position: Vector2) -> void:
	if not (glyph is Label) or not is_instance_valid(glyph):
		return
	var control_point := (from_position + to_position) * 0.5 + Vector2(0.0, -ARC_LIFT)
	(glyph as Label).position = _quadratic_bezier(from_position, control_point, to_position, progress) - (glyph as Label).pivot_offset


func _glide_tracked(progress: float, glyph: Variant, from_position: Vector2, target_getter: Callable) -> void:
	if not (glyph is Label) or not is_instance_valid(glyph):
		return
	var to_position: Vector2 = from_position
	if target_getter.is_valid():
		to_position = target_getter.call()
	var control_point := (from_position + to_position) * 0.5 + Vector2(0.0, -ARC_LIFT * 0.4)
	(glyph as Label).position = _quadratic_bezier(from_position, control_point, to_position, progress) - (glyph as Label).pivot_offset


func _quadratic_bezier(a: Vector2, control_point: Vector2, b: Vector2, t: float) -> Vector2:
	var leg_one := a.lerp(control_point, t)
	var leg_two := control_point.lerp(b, t)
	return leg_one.lerp(leg_two, t)


func _finish_glyph(glyph: Variant, unit_text: String, silent: bool = false) -> void:
	if glyph is Label and is_instance_valid(glyph):
		(glyph as Label).queue_free()
	_active_count = maxi(0, _active_count - 1)
	if _active_count == 0:
		_fade_backdrop(0.0, 0.18)
	_flight_tweens = _flight_tweens.filter(func(flight: Tween) -> bool: return flight != null and flight.is_valid())
	if not silent:
		pickup_landed.emit(unit_text)


func _fade_backdrop(target_alpha: float, duration: float) -> void:
	if _backdrop == null:
		return
	if _backdrop_tween != null and _backdrop_tween.is_valid():
		_backdrop_tween.kill()
	_backdrop_tween = create_tween()
	_backdrop_tween.tween_property(_backdrop, "modulate:a", target_alpha, duration)
