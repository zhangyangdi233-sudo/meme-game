extends SceneTree
## The Floor generator asks UiPalette for every palette color: a complete palette builds and repaints
## every floor without a report, and a palette with a gap is reported and painted from palette 1.
## The playtest marker and EXIT sign outlines stay UiPalette.OUTLINE after the repaint to pollution palette 5.
## Every floor shows the colors it showed before they moved into Floor look (tests/fixtures/floor_look_before.json),
## and the generator source decides no color of its own.

const RealityFloorGeneratorScript = preload("res://scripts/reality_floor_generator.gd")
const FloorComposerScript = preload("res://scripts/game/floor_composer.gd")
const PaletteErrorLog = preload("res://tests/harness/palette_error_log.gd")
const Snapshot = preload("res://tests/harness/floor_look_snapshot.gd")
const BEFORE_PATH := "res://tests/fixtures/floor_look_before.json"
const GENERATOR_PATH := "res://scripts/reality_floor_generator.gd"
const NEAR_BLACK_OUTLINE := Color("050705")

var _failures: Array[String] = []
var _errors := PaletteErrorLog.new()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.add_logger(_errors)
	await _test_complete_palettes_build_and_repaint_every_floor_without_reports()
	await _test_a_palette_gap_is_reported_and_painted_from_palette_1()
	await _test_every_floor_shows_the_colors_it_showed_before_floor_look()
	_test_the_generator_decides_no_color_of_its_own()
	OS.remove_logger(_errors)
	if _failures.is_empty():
		print("floor palette tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_complete_palettes_build_and_repaint_every_floor_without_reports() -> void:
	var floor_root := RealityFloorGeneratorScript.new()
	root.add_child(floor_root)
	await process_frame
	floor_root.set_playtest_assist_enabled(true)
	var outlined := {}
	for floor_number in [1, 2, 3, 4]:
		var composed: Dictionary = FloorComposerScript.compose({"day_progress": {"tower_floor": floor_number, "day": 2}})
		floor_root.rebuild(
			floor_number,
			UiPalette.PALETTE_1,
			{},
			2,
			false,
			composed.get("items", []),
			composed.get("people", []),
			composed.get("display_names", {}),
			composed.get("events", []),
			composed.get("layout", {})
		)
		floor_root.apply_palette(UiPalette.POLLUTION_PALETTE_5)
		_assert_eq(_errors.take(), [], "floor %d should build and repaint from complete palettes without a report" % floor_number)
		for label in floor_root.find_children("*", "Label3D", true, false):
			if label.name == "PlaytestMarker" or label.name == "DeadSignLabel":
				outlined[str(label.name)] = true
				_assert_eq((label as Label3D).outline_modulate, NEAR_BLACK_OUTLINE, "floor %d %s outline should stay near black under pollution palette 5" % [floor_number, label.name])
	_assert_true(outlined.has("PlaytestMarker"), "some floor should build a playtest marker")
	_assert_true(outlined.has("DeadSignLabel"), "some floor should build the EXIT sign")
	floor_root.free()


func _test_a_palette_gap_is_reported_and_painted_from_palette_1() -> void:
	var floor_root := RealityFloorGeneratorScript.new()
	root.add_child(floor_root)
	await process_frame
	var without_accent := UiPalette.POLLUTION_PALETTE_5.duplicate()
	without_accent.erase("accent")
	floor_root.rebuild(1, without_accent, {})
	var errors := _errors.take()
	_assert_true(not errors.is_empty(), "a palette without accent should be reported")
	for error in errors:
		_assert_true(error.contains("accent"), "only the missing accent should be reported: %s" % error)
	var road := floor_root.find_child("MainRoad", true, false)
	var road_mesh := road.get_node_or_null("Mesh") as MeshInstance3D if road != null else null
	_assert_true(road_mesh != null, "floor 1 should build a main road")
	if road_mesh != null:
		var material := road_mesh.material_override as StandardMaterial3D
		_assert_eq(material.albedo_color, Color("365B2D").darkened(0.54), "the road should take palette 1's accent when the palette has none")
	floor_root.free()


func _test_every_floor_shows_the_colors_it_showed_before_floor_look() -> void:
	var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BEFORE_PATH))
	for floor_key in before["floors"]:
		var floor_entry: Dictionary = before["floors"][floor_key]
		var floor_root := RealityFloorGeneratorScript.new()
		root.add_child(floor_root)
		Snapshot.build(floor_root, int(floor_key), UiPalette.PALETTE_1)
		_assert_same_look(Snapshot.capture(floor_root), floor_entry["built_palette_1"], "floor %s built with palette 1" % floor_key)
		floor_root.apply_palette(UiPalette.POLLUTION_PALETTE_5)
		_assert_same_look(Snapshot.capture(floor_root), floor_entry["repainted_pollution_palette_5"], "floor %s repainted to pollution palette 5" % floor_key)
		Snapshot.build(floor_root, int(floor_key), UiPalette.POLLUTION_PALETTE_5)
		_assert_same_look(Snapshot.capture(floor_root), floor_entry["built_pollution_palette_5"], "floor %s built with pollution palette 5" % floor_key)
		floor_root.free()
		await process_frame
	_assert_eq(_errors.take(), [], "building every floor for the comparison should report no palette gap")


func _test_the_generator_decides_no_color_of_its_own() -> void:
	var source := FileAccess.get_file_as_string(GENERATOR_PATH)
	var color_rule := RegEx.new()
	color_rule.compile("Color\\(|\\.lerp\\(|\\.darkened\\(|\\.lightened\\(|UiPalette(Script)?\\.color\\(")
	var lines := source.split("\n")
	for line_index in lines.size():
		if color_rule.search(lines[line_index]) != null:
			_failures.append("the generator should ask Floor look for colors, line %d: %s" % [line_index + 1, lines[line_index].strip_edges()])


func _assert_same_look(captured: Dictionary, recorded: Dictionary, label: String) -> void:
	var actual: Dictionary = Snapshot.decode(captured)
	var expected: Dictionary = Snapshot.decode(recorded)
	for section in expected:
		var expected_section = expected[section]
		var actual_section = actual.get(section)
		if actual_section == expected_section:
			continue
		if expected_section is Dictionary and actual_section is Dictionary:
			for key in expected_section:
				if actual_section.get(key) != expected_section[key]:
					_failures.append("%s %s %s should stay %s, got %s" % [label, section, key, expected_section[key], actual_section.get(key)])
			for key in actual_section:
				if not expected_section.has(key):
					_failures.append("%s %s gained %s" % [label, section, key])
		else:
			_failures.append("%s %s should stay %s, got %s" % [label, section, expected_section, actual_section])


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
