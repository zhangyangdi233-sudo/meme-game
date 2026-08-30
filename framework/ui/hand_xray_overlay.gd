class_name HandXRayOverlay
extends Control

const THUMB_TIP_INDEX := 4
const INDEX_TIP_INDEX := 8
const LOST_HAND_TIMEOUT_MSEC := 420
const MIN_FRAME_SIZE := Vector2(0.07, 0.06)
const SMOOTHING_WEIGHT := 0.36
const SIGNAL_GLITCH_MIN_INTERVAL := 1.15
const SIGNAL_GLITCH_MAX_INTERVAL := 2.80
const SIGNAL_GLITCH_MIN_DURATION := 0.12
const SIGNAL_GLITCH_MAX_DURATION := 0.22
const MAX_TEAR_OFFSET_PX := 18.0
const EDGE_PACKET_COUNT := 14

var _layer_texture: Texture2D
var _tracking_enabled := false
var _frame_active := false
var _frame_shape := "rectangle"
var _smoothed_rect := Rect2()
var _last_hands_msec := 0
var _fingertips: Array[Vector2] = []
var _effect_phase := 0.0
var _next_glitch_phase := 2.65
var _glitch_duration := 0.0
var _glitch_remaining := 0.0
var _glitch_strength := 0.0
var _glitch_serial := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	set_meta("xray_mode", "two_hand_thumb_index_bbox")
	set_meta("rectangle_gesture", "two_hand_thumb_index_bbox")
	set_meta("border_effect", "babel_signal_contamination_v2")
	set_meta("effect_components", ["acid_chromatic_split", "broken_edge_packets", "horizontal_frame_desync", "crawl_code", "irregular_breath"])
	set_meta("effect_scope", "xray_window_only")
	set_meta("max_tear_offset_px", MAX_TEAR_OFFSET_PX)
	set_meta("effect_intensity", "readable_local_interference")


func set_layer_texture(texture: Texture2D) -> void:
	_layer_texture = texture
	queue_redraw()


func set_tracking_enabled(value: bool) -> void:
	_tracking_enabled = value
	if not value:
		_frame_active = false
		_fingertips.clear()
	_set_runtime_metadata()
	queue_redraw()


func ingest_hands(hands: Array, timestamp_msec: int = -1) -> bool:
	_last_hands_msec = Time.get_ticks_msec() if timestamp_msec < 0 else timestamp_msec
	if not _tracking_enabled or hands.size() < 2:
		return _deactivate_frame()
	var next_tips: Array[Vector2] = []
	for hand_index in 2:
		var hand: Variant = hands[hand_index]
		if not hand is Dictionary:
			return _deactivate_frame()
		var landmarks: Variant = hand.get("landmarks", [])
		if not landmarks is Array or landmarks.size() <= INDEX_TIP_INDEX:
			return _deactivate_frame()
		for tip_index in [THUMB_TIP_INDEX, INDEX_TIP_INDEX]:
			var point: Variant = landmarks[tip_index]
			if not point is Dictionary:
				return _deactivate_frame()
			next_tips.append(Vector2(
				clampf(float(point.get("x", 0.0)), 0.0, 1.0),
				clampf(float(point.get("y", 0.0)), 0.0, 1.0)
			))
	var target := _bounds_for_points(next_tips)
	if target.size.x < MIN_FRAME_SIZE.x or target.size.y < MIN_FRAME_SIZE.y:
		return _deactivate_frame()
	_fingertips = next_tips
	if _frame_active:
		_smoothed_rect = Rect2(
			_smoothed_rect.position.lerp(target.position, SMOOTHING_WEIGHT),
			_smoothed_rect.size.lerp(target.size, SMOOTHING_WEIGHT)
		)
	else:
		_smoothed_rect = target
	_frame_shape = "rectangle"
	_frame_active = true
	_set_runtime_metadata()
	queue_redraw()
	return true


func is_frame_active() -> bool:
	return _frame_active and _tracking_enabled and _layer_texture != null


func get_frame_rect_normalized() -> Rect2:
	return _smoothed_rect


func get_frame_shape() -> String:
	return _frame_shape


func expire_tracking_for_test() -> void:
	_last_hands_msec = Time.get_ticks_msec() - LOST_HAND_TIMEOUT_MSEC - 1
	_process(0.0)


func force_signal_glitch_for_test() -> void:
	_begin_signal_glitch()
	_process(_glitch_duration * 0.45)


func _process(delta: float) -> void:
	if _frame_active:
		_effect_phase += delta
		_update_signal_glitch(delta)
		queue_redraw()
	if _frame_active and Time.get_ticks_msec() - _last_hands_msec > LOST_HAND_TIMEOUT_MSEC:
		_deactivate_frame()


func _draw() -> void:
	if not is_frame_active():
		return
	var texture_size := Vector2(_layer_texture.get_width(), _layer_texture.get_height())
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var pulse := clampf(
		0.50 + sin(_effect_phase * 1.67) * 0.20 + sin(_effect_phase * 4.91 + 0.8) * 0.08,
		0.0,
		1.0
	)
	var destination := Rect2(_smoothed_rect.position * size, _smoothed_rect.size * size)
	var source := Rect2(_smoothed_rect.position * texture_size, _smoothed_rect.size * texture_size)
	draw_rect(destination.grow(11.0), Color(0.01, 0.045, 0.018, 0.58), true)
	draw_texture_rect_region(_layer_texture, destination, source, Color(0.81, 0.92, 0.72, 0.965))
	_draw_horizontal_tear(destination, source)
	_draw_chromatic_signal_frame(destination, pulse)
	var scan_y := lerpf(destination.position.y + 2.0, destination.end.y - 2.0, fmod(_effect_phase * 0.16, 1.0))
	var scan_visibility := pow(maxf(0.0, sin(_effect_phase * 0.71 + 1.1)), 8.0)
	draw_line(
		Vector2(destination.position.x + 2.0, scan_y),
		Vector2(destination.end.x - 2.0, scan_y),
		Color(0.87, 1.0, 0.55, 0.018 + scan_visibility * 0.095),
		1.0,
		true
	)
	_draw_edge_packet_noise(destination, pulse)
	_draw_crawling_scar(destination, pulse)
	_draw_frame_corners(destination)
	for fingertip in _fingertips:
		var point := fingertip * size
		draw_circle(point + Vector2(-3.0 - _glitch_strength * 5.0, 1.5), 6.0, Color(0.58, 0.10, 0.08, 0.34))
		draw_circle(point, 8.0, Color(0.05, 0.10, 0.03, 0.88))
		draw_circle(point, 4.5, Color(0.91, 1.0, 0.57, 0.88))


func _update_signal_glitch(delta: float) -> void:
	if _glitch_remaining > 0.0:
		_glitch_remaining = maxf(0.0, _glitch_remaining - delta)
		var progress := 1.0 - _glitch_remaining / maxf(_glitch_duration, 0.001)
		_glitch_strength = sin(clampf(progress, 0.0, 1.0) * PI)
		if _glitch_remaining <= 0.0:
			_glitch_strength = 0.0
	elif _effect_phase >= _next_glitch_phase:
		_begin_signal_glitch()
	set_meta("signal_burst_active", _glitch_remaining > 0.0)
	set_meta("signal_burst_strength", _glitch_strength)


func _begin_signal_glitch() -> void:
	_glitch_serial += 1
	var duration_mix := absf(sin(float(_glitch_serial) * 3.17 + 0.4))
	_glitch_duration = lerpf(SIGNAL_GLITCH_MIN_DURATION, SIGNAL_GLITCH_MAX_DURATION, duration_mix)
	_glitch_remaining = _glitch_duration
	var interval_mix := absf(sin(float(_glitch_serial) * 7.31 + 1.9))
	_next_glitch_phase = _effect_phase + lerpf(SIGNAL_GLITCH_MIN_INTERVAL, SIGNAL_GLITCH_MAX_INTERVAL, interval_mix)


func _draw_horizontal_tear(destination: Rect2, source: Rect2) -> void:
	var ambient_desync := 0.22 + absf(sin(_effect_phase * 0.83)) * 0.08
	var strength := maxf(_glitch_strength, ambient_desync)
	var tear_count := 3 if _glitch_strength > 0.015 else 1
	for tear_index in tear_count:
		var seed := float(_glitch_serial * 7 + tear_index * 13) + _effect_phase * (0.19 + tear_index * 0.04)
		var tear_mix := absf(sin(seed * 1.913 + 0.73))
		var tear_y := lerpf(destination.position.y + 5.0, destination.end.y - 9.0, tear_mix)
		var tear_height := minf(9.0, maxf(2.0, destination.size.y * (0.010 + 0.006 * float(tear_index + 1))))
		var normalized_y := (tear_y - destination.position.y) / maxf(destination.size.y, 1.0)
		var source_y := source.position.y + source.size.y * normalized_y
		var source_height := source.size.y * tear_height / maxf(destination.size.y, 1.0)
		var direction := -1.0 if (_glitch_serial + tear_index) % 2 == 0 else 1.0
		var offset := direction * minf(MAX_TEAR_OFFSET_PX, 2.5 + strength * (8.0 + tear_index * 4.5))
		var inset := absf(sin(seed * 2.71)) * destination.size.x * 0.08
		var tear_destination := Rect2(
			Vector2(destination.position.x + inset + offset, tear_y),
			Vector2(destination.size.x - inset * 1.35, tear_height)
		)
		var tear_source := Rect2(
			Vector2(source.position.x + source.size.x * inset / maxf(destination.size.x, 1.0), source_y),
			Vector2(source.size.x * tear_destination.size.x / maxf(destination.size.x, 1.0), source_height)
		)
		draw_texture_rect_region(_layer_texture, tear_destination, tear_source, Color(0.89, 0.96, 0.73, 0.52 + strength * 0.30))
		draw_line(
			Vector2(destination.position.x + inset, tear_y - 1.0),
			Vector2(destination.end.x - inset * 0.35, tear_y - 1.0),
			Color(0.58, 0.10, 0.08, 0.20 + strength * 0.25),
			1.0 + strength,
			true
		)


func _draw_chromatic_signal_frame(rect: Rect2, pulse: float) -> void:
	var red_shift := Vector2(-3.5 - _glitch_strength * 8.5, 1.5 + _glitch_strength * 2.0)
	var teal_shift := Vector2(2.5 + _glitch_strength * 5.5, -1.5)
	draw_rect(
		Rect2(rect.position + red_shift, rect.size),
		Color(0.58, 0.10, 0.08, 0.24 + _glitch_strength * 0.28),
		false,
		2.4,
		true
	)
	draw_rect(
		Rect2(rect.position + teal_shift, rect.size),
		Color(0.24, 0.78, 0.62, 0.19 + _glitch_strength * 0.20),
		false,
		1.8,
		true
	)
	draw_rect(rect, Color(0.87, 1.0, 0.47, 0.79 + pulse * 0.13), false, 2.4, true)
	draw_rect(
		rect.grow(4.0 + pulse * 1.6),
		Color(0.36, 0.75, 0.25, 0.18 + pulse * 0.10),
		false,
		1.2 + pulse * 0.65,
		true
	)


func _draw_edge_packet_noise(rect: Rect2, pulse: float) -> void:
	for packet_index in EDGE_PACKET_COUNT:
		var seed := float(packet_index) * 19.417 + float(_glitch_serial) * 2.31
		var drift := _effect_phase * (0.012 + absf(sin(seed)) * 0.018)
		var progress := fmod(absf(sin(seed * 0.37)) + drift, 1.0)
		var packet_length := 0.007 + absf(sin(seed * 1.71 + 0.4)) * 0.023
		var start := _point_on_rect_perimeter(rect, progress)
		var finish := _point_on_rect_perimeter(rect, progress + packet_length)
		if start.distance_to(finish) > 92.0:
			continue
		var tangent := (finish - start).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var jitter := roundf(sin(seed + _effect_phase * 4.3) * (1.5 + _glitch_strength * 6.5))
		start += normal * jitter
		finish += normal * jitter
		draw_line(start, finish, Color(0.015, 0.035, 0.015, 0.82), 5.8, false)
		var packet_color := Color(0.90, 1.0, 0.50, 0.35 + pulse * 0.28)
		if packet_index % 4 == 0:
			packet_color = Color(0.64, 0.12, 0.09, 0.45 + _glitch_strength * 0.28)
		draw_line(start, finish, packet_color, 1.4 + float(packet_index % 3) * 0.45, false)
		if packet_index % 3 == 0:
			var block_size := Vector2(3.0 + float(packet_index % 4) * 2.0, 2.0 + _glitch_strength * 3.0)
			draw_rect(Rect2(start - block_size * 0.5, block_size), packet_color, true)
	for dropout_index in 4:
		var dropout_progress := fmod(0.11 + float(dropout_index) * 0.239 + _effect_phase * 0.009, 1.0)
		var dropout_start := _point_on_rect_perimeter(rect, dropout_progress)
		var dropout_end := _point_on_rect_perimeter(rect, dropout_progress + 0.006 + _glitch_strength * 0.006)
		if dropout_start.distance_to(dropout_end) <= 42.0:
			draw_line(dropout_start, dropout_end, Color(0.01, 0.025, 0.01, 0.94), 4.2, false)


func _draw_crawling_scar(rect: Rect2, pulse: float) -> void:
	var scar_progress := fmod(_effect_phase * 0.047 + 0.17, 1.0)
	var scar_start := _point_on_rect_perimeter(rect, scar_progress)
	var scar_end := _point_on_rect_perimeter(rect, scar_progress + 0.018 + pulse * 0.006)
	draw_line(scar_start, scar_end, Color(0.96, 0.97, 0.57, 0.28 + pulse * 0.12), 2.8, true)
	var afterimage := Vector2(1.8 + _glitch_strength * 2.2, 0.8)
	draw_line(scar_start + afterimage, scar_end + afterimage, Color(0.45, 0.12, 0.10, 0.13), 1.1, true)


func _point_on_rect_perimeter(rect: Rect2, progress: float) -> Vector2:
	var width := rect.size.x
	var height := rect.size.y
	var perimeter := (width + height) * 2.0
	var distance := wrapf(progress, 0.0, 1.0) * perimeter
	if distance <= width:
		return rect.position + Vector2(distance, 0.0)
	distance -= width
	if distance <= height:
		return Vector2(rect.end.x, rect.position.y + distance)
	distance -= height
	if distance <= width:
		return Vector2(rect.end.x - distance, rect.end.y)
	distance -= width
	return Vector2(rect.position.x, rect.end.y - distance)


func _draw_frame_corners(rect: Rect2) -> void:
	var length := minf(28.0, minf(rect.size.x, rect.size.y) * 0.22)
	var color := Color(0.91, 1.0, 0.57, 0.92)
	var top_left := rect.position
	var top_right := Vector2(rect.end.x, rect.position.y)
	var bottom_left := Vector2(rect.position.x, rect.end.y)
	var bottom_right := rect.end
	for segment in [
		[top_left, top_left + Vector2(length, 0.0)], [top_left, top_left + Vector2(0.0, length)],
		[top_right, top_right + Vector2(-length, 0.0)], [top_right, top_right + Vector2(0.0, length)],
		[bottom_left, bottom_left + Vector2(length, 0.0)], [bottom_left, bottom_left + Vector2(0.0, -length)],
		[bottom_right, bottom_right + Vector2(-length, 0.0)], [bottom_right, bottom_right + Vector2(0.0, -length)],
	]:
		draw_line(segment[0], segment[1], color, 4.6, true)


func _bounds_for_points(points: Array[Vector2]) -> Rect2:
	var minimum := Vector2(1.0, 1.0)
	var maximum := Vector2.ZERO
	for point in points:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum)


func _deactivate_frame() -> bool:
	_frame_active = false
	_fingertips.clear()
	_set_runtime_metadata()
	queue_redraw()
	return false


func _set_runtime_metadata() -> void:
	set_meta("frame_active", _frame_active)
	set_meta("frame_shape", _frame_shape if _frame_active else "none")
	set_meta("frame_rect_normalized", _smoothed_rect)
