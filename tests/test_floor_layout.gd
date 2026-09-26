extends SceneTree
## The street still comes from the floor number.
## A layout on the plan sits beside that path and does not replace it.

const RealityFloorGeneratorScript = preload("res://scripts/reality_floor_generator.gd")

const TEST_PALETTE := {
	"bg": "B7D957",
	"surface": "FFF1C9",
	"text": "10140F",
	"ink": "10140F",
	"accent": "365B2D",
	"muted": "DDEB8A",
	"danger_stripe": "365B2D",
	"flash_text": "9CFF24",
}

const CURRENT_STREETS := {
	1: {"room_count": 4, "shape": "shared_street", "width": 34.0, "length": 230.0},
	2: {"room_count": 6, "shape": "irregular_disc", "width": 252.0, "length": 264.0},
	3: {"room_count": 9, "shape": "skylit_overgrown_gallery", "width": 37.0, "length": 355.0},
	4: {"room_count": 11, "shape": "shared_street", "width": 38.5, "length": 402.0},
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var floor_root := RealityFloorGeneratorScript.new()
	root.add_child(floor_root)
	for floor_number in [1, 2, 3, 4]:
		floor_root.rebuild(floor_number, TEST_PALETTE, {})
		_assert_street(floor_root, CURRENT_STREETS[floor_number], "floor %d without a layout should keep the floor-number street" % floor_number)
	floor_root.rebuild(1, TEST_PALETTE, {}, 1, false, [], [], {}, [], {
		"room_count": 8,
		"shape": "irregular_disc",
		"map_size": {"width": 40.0, "length": 240.0},
	})
	_assert_street(floor_root, CURRENT_STREETS[1], "a complete layout should sit beside the floor-number street")
	floor_root.rebuild(1, TEST_PALETTE, {}, 1, false, [], [], {}, [], {"room_count": 99})
	_assert_street(floor_root, CURRENT_STREETS[1], "an incomplete layout should stay on the floor-number path")
	floor_root.free()
	if _failures.is_empty():
		print("floor layout tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _assert_street(floor_root: Node, expected: Dictionary, message: String) -> void:
	_assert_eq(int(floor_root.get_meta("room_count", -1)), int(expected["room_count"]), "%s room count" % message)
	_assert_eq(str(floor_root.get_meta("layout_mode", "")), str(expected["shape"]), "%s shape" % message)
	_assert_true(is_equal_approx(float(floor_root.get_meta("map_width", -1.0)), float(expected["width"])), "%s map width" % message)
	_assert_true(is_equal_approx(float(floor_root.get_meta("map_length", -1.0)), float(expected["length"])), "%s map length" % message)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
