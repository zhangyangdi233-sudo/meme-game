extends SceneTree
## Floor look answers every material, environment, light and tint color the Floor generator painted
## before the colors moved out of it, for every floor and its district style, without building a scene.
## The expected colors are tests/fixtures/floor_look_before.json, recorded from the generator before the move.

const FloorLookScript = preload("res://scripts/game/floor_look.gd")
const BEFORE_PATH := "res://tests/fixtures/floor_look_before.json"
const PALETTES := {"palette_1": UiPalette.PALETTE_1, "pollution_palette_5": UiPalette.POLLUTION_PALETTE_5}

var _failures: Array[String] = []
var _before: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_before = JSON.parse_string(FileAccess.get_file_as_string(BEFORE_PATH))
	_test_material_colors_match_every_floor_before_the_move()
	_test_environment_colors_match_every_floor_before_the_move()
	_test_light_colors_match_every_floor_before_the_move()
	_test_tints_match_before_the_move()
	if _failures.is_empty():
		print("floor look tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_material_colors_match_every_floor_before_the_move() -> void:
	for floor_key in _before["floors"]:
		var floor_entry: Dictionary = _before["floors"][floor_key]
		var style := str(floor_entry["style"])
		for palette_key in PALETTES:
			var materials: Dictionary = floor_entry[palette_key]["materials"]
			for role in _before["roles"]:
				_assert_color(
					FloorLookScript.material_color(str(role), int(floor_key), style, PALETTES[palette_key]),
					materials[role],
					"floor %s (%s) %s %s" % [floor_key, style, palette_key, role]
				)


func _test_environment_colors_match_every_floor_before_the_move() -> void:
	for floor_key in _before["floors"]:
		var floor_entry: Dictionary = _before["floors"][floor_key]
		var style := str(floor_entry["style"])
		for palette_key in PALETTES:
			var environment: Dictionary = floor_entry[palette_key]["environment"]
			for use in ["background", "ambient", "fog"]:
				_assert_color(
					FloorLookScript.environment_color(use, int(floor_key), style, PALETTES[palette_key]),
					environment[use],
					"floor %s (%s) %s %s" % [floor_key, style, palette_key, use]
				)


func _test_light_colors_match_every_floor_before_the_move() -> void:
	for floor_key in _before["floors"]:
		var floor_entry: Dictionary = _before["floors"][floor_key]
		var style := str(floor_entry["style"])
		for palette_key in PALETTES:
			var lights: Dictionary = floor_entry[palette_key]["lights"]
			for use in lights:
				_assert_color(
					FloorLookScript.light_color(str(use), int(floor_key), style, PALETTES[palette_key]),
					lights[use],
					"floor %s (%s) %s %s light" % [floor_key, style, palette_key, use]
				)


func _test_tints_match_before_the_move() -> void:
	var tints: Dictionary = _before["tints"]
	if FloorLookScript.TINTS.has("playtest_marker"):
		_failures.append("Floor look should keep no tint for the removed playtest marker")
	for use in tints:
		var name := str(use)
		if name.begins_with("grass_blade_"):
			var variant := int(name.trim_prefix("grass_blade_"))
			_assert_color(FloorLookScript.grass_blade_tint(variant), tints[use], "grass blade variant %d" % variant)
		else:
			_assert_color(FloorLookScript.tint(name), tints[use], "%s tint" % name)


func _assert_color(actual: Color, expected: Array, message: String) -> void:
	var expected_color := Color(expected[0], expected[1], expected[2], expected[3])
	if actual != expected_color:
		_failures.append("%s should be %s, got %s" % [message, expected_color, actual])
