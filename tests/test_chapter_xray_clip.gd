extends SceneTree

const OverlayScript = preload("res://scripts/ui/hand_xray_overlay.gd")
const FRAME := Rect2(100, 100, 200, 100)
const SOURCE := Rect2(200, 400, 300, 80)
var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	var overlay = OverlayScript.new()
	_check(overlay.has_method("_clip_texture_region"), "Xray texture tears need clipping that preserves their source mapping")
	if overlay.has_method("_clip_texture_region"):
		_expect_region(overlay, "left edge", Rect2(90, 125, 100, 20), Rect2(100, 125, 90, 20), Rect2(230, 400, 270, 80))
		_expect_region(overlay, "right edge", Rect2(260, 125, 100, 20), Rect2(260, 125, 40, 20), Rect2(200, 400, 120, 80))
		_expect_region(overlay, "top edge", Rect2(140, 95, 80, 20), Rect2(140, 100, 80, 15), Rect2(200, 420, 300, 60))
		_expect_region(overlay, "bottom edge", Rect2(140, 190, 80, 20), Rect2(140, 190, 80, 10), Rect2(200, 400, 300, 40))
		_expect_region(overlay, "already inside", Rect2(140, 125, 80, 20), Rect2(140, 125, 80, 20), SOURCE)
		for outside in [Rect2(10, 120, 80, 20), Rect2(310, 120, 80, 20), Rect2(120, 60, 80, 20), Rect2(120, 210, 80, 20), Rect2(20, 120, 80, 20)]:
			var result: Array = overlay.call("_clip_texture_region", outside, SOURCE, FRAME)
			_check(result.is_empty(), "fully outside or edge-touching texture has no drawable area: %s" % outside)
		for empty in [Rect2(120, 120, 0, 20), Rect2(120, 120, 80, 0)]:
			var result: Array = overlay.call("_clip_texture_region", empty, SOURCE, FRAME)
			_check(result.is_empty(), "zero-area texture never divides by zero: %s" % empty)
	overlay.free()
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("chapter Xray clipping tests passed (%d checks)" % _checks)
	quit(0 if _failures.is_empty() else 1)


func _expect_region(overlay: Control, label: String, original_destination: Rect2, expected_destination: Rect2, expected_source: Rect2) -> void:
	var result: Array = overlay.call("_clip_texture_region", original_destination, SOURCE, FRAME)
	_check(result.size() == 2, "%s should retain a clipped destination/source pair" % label)
	if result.size() != 2:
		return
	var destination: Rect2 = result[0]
	var source: Rect2 = result[1]
	_check(destination.is_equal_approx(expected_destination), "%s clips the texture to the gesture frame" % label)
	_check(source.is_equal_approx(expected_source), "%s preserves texel alignment instead of squeezing the arrow" % label)
	_check(FRAME.encloses(destination), "%s never draws texture pixels beyond the gesture frame" % label)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
