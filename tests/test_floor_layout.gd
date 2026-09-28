extends SceneTree
## A complete layout plan chooses the street shape, room count, and map size.
## The tower floor number does not. An incomplete plan is one fixed street on every floor.
## The four authored plans still build today's walkable streets.
## The generator stays in Game and does not answer room-count or crowd-count queries.

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


const UNPLANNED_STREET := {
	"room_count": 0,
	"shape": "shared_street",
	"width": 34.0,
	"length": 230.0,
}


func _run() -> void:
	var floor_root := RealityFloorGeneratorScript.new()
	root.add_child(floor_root)
	for floor_number in [1, 2, 3, 4]:
		floor_root.rebuild(floor_number, TEST_PALETTE, {})
		_assert_street(floor_root, UNPLANNED_STREET, "floor %d without a plan should use the fixed street" % floor_number)
	floor_root.rebuild(2, TEST_PALETTE, {}, 1, false, [], [], {}, [], {"room_count": 99})
	_assert_street(floor_root, UNPLANNED_STREET, "an incomplete layout should stay on the fixed street")
	floor_root.rebuild(3, TEST_PALETTE, {}, 1, false, [], [], {}, [], {"shape": "irregular_disc", "room_count": 8})
	_assert_street(floor_root, UNPLANNED_STREET, "an incomplete disc layout should stay on the fixed street")
	var layout_street := {
		"room_count": 7,
		"shape": "shared_street",
		"width": 36.0,
		"length": 200.0,
	}
	for street_floor in [1, 2, 4]:
		floor_root.rebuild(street_floor, TEST_PALETTE, {}, 1, false, [], [], {}, [], _layout_dict(layout_street))
		_assert_street(floor_root, layout_street, "floor %d should take its street from a shared-street layout" % street_floor)
		_assert_eq(_logical_room_count(floor_root), 7, "floor %d rooms should follow the shared-street layout" % street_floor)
		_assert_walkable(floor_root, "floor %d shared-street layout" % street_floor)
		_assert_true(floor_root.find_child("IrregularDiscGround", true, false) == null, "floor %d shared-street layout should not build a disc" % street_floor)
	var disc_layout := {
		"room_count": 8,
		"shape": "irregular_disc",
		"width": 120.0,
		"length": 140.0,
	}
	for disc_floor in [1, 2, 4]:
		floor_root.rebuild(disc_floor, TEST_PALETTE, {}, 1, false, [], [], {}, [], _layout_dict(disc_layout))
		_assert_street(floor_root, disc_layout, "floor %d should take its disc from an irregular-disc layout" % disc_floor)
		_assert_eq(_logical_room_count(floor_root), 8, "floor %d rooms should follow the irregular-disc layout" % disc_floor)
		_assert_true(floor_root.contains_playable_position(Vector3(20.0, 0.08, 0.0)), "a point inside the layout disc should stay walkable")
		_assert_true(not floor_root.contains_playable_position(Vector3(100.0, 0.08, 0.0)), "a point outside the layout disc should stay outside")
		_assert_disc_walkable(floor_root, "floor %d disc layout" % disc_floor)
	var gallery_layout := {
		"room_count": 5,
		"shape": "skylit_overgrown_gallery",
		"width": 50.0,
		"length": 180.0,
	}
	for gallery_floor in [1, 3, 4]:
		floor_root.rebuild(gallery_floor, TEST_PALETTE, {}, 1, false, [], [], {}, [], _layout_dict(gallery_layout))
		_assert_street(floor_root, gallery_layout, "floor %d should take its gallery from a skylit layout" % gallery_floor)
		_assert_eq(_logical_room_count(floor_root), 5, "floor %d rooms should follow the gallery layout" % gallery_floor)
		_assert_true(floor_root.contains_playable_position(Vector3(20.0, 0.08, 0.0)), "a point inside the layout gallery should stay walkable")
		_assert_true(not floor_root.contains_playable_position(Vector3(30.0, 0.08, 0.0)), "a point outside the layout gallery should stay outside")
		_assert_walkable(floor_root, "floor %d gallery layout" % gallery_floor)
		_assert_true(bool(floor_root.get_meta("gallery_continuous", false)), "a layout gallery should stay one continuous corridor")
	var two_pedestrians := [
		{"id": "npc_a", "kind": "npc"},
		{"id": "npc_b", "kind": "npc"},
	]
	floor_root.rebuild(1, TEST_PALETTE, {}, 1, false, [], two_pedestrians, {}, [], _layout_dict(layout_street))
	var placed_on_floor_one := int(floor_root.get_meta("ordinary_npc_count", -1))
	floor_root.rebuild(4, TEST_PALETTE, {}, 1, false, [], two_pedestrians, {}, [], _layout_dict(layout_street))
	_assert_eq(placed_on_floor_one, 2, "two listed pedestrians should be placed on floor 1")
	_assert_eq(int(floor_root.get_meta("ordinary_npc_count", -1)), placed_on_floor_one, "the same pedestrian list should not change count on floor 4")
	floor_root.rebuild(2, TEST_PALETTE, {}, 1, false, [], [], {}, [], _layout_dict(disc_layout))
	_assert_eq(int(floor_root.get_meta("ordinary_npc_count", -1)), 0, "an empty pedestrian list should place nobody on the disc")
	floor_root.rebuild(2, TEST_PALETTE, {}, 1, false, [], [], {}, [], _layout_dict(CURRENT_STREETS[2]))
	_assert_street(floor_root, CURRENT_STREETS[2], "floor 2 plan layout should keep today's disc")
	_assert_eq(_logical_room_count(floor_root), 6, "floor 2 plan layout should keep today's six rooms")
	_assert_disc_walkable(floor_root, "floor 2 plan layout")
	_assert_true(floor_root.contains_playable_position(Vector3(100.0, 0.08, 0.0)), "today's disc should still include the inner clearing")
	_assert_true(not floor_root.contains_playable_position(Vector3(200.0, 0.08, 0.0)), "today's disc should still exclude the outer clearing")
	_assert_eq(str(floor_root.get_meta("lighting_profile", "")), "near_black_disc", "floor 2 should keep its near-black disc light")
	_assert_eq(str(floor_root.get_meta("atmosphere_mode", "")), "slow_burn_suspense", "floor 2 atmosphere should stay slow-burn suspense")
	for street_floor in [1, 4]:
		floor_root.rebuild(street_floor, TEST_PALETTE, {}, 1, false, [], [], {}, [], _layout_dict(CURRENT_STREETS[street_floor]))
		_assert_street(floor_root, CURRENT_STREETS[street_floor], "floor %d plan layout should keep today's street" % street_floor)
		_assert_eq(_logical_room_count(floor_root), int(CURRENT_STREETS[street_floor]["room_count"]), "floor %d plan layout should keep today's room count" % street_floor)
		_assert_walkable(floor_root, "floor %d plan layout" % street_floor)
		if street_floor == 1:
			_assert_eq(str(floor_root.get_meta("lighting_profile", "")), "open_daylight", "floor 1 should stay a daylight street")
			_assert_eq(str(floor_root.get_meta("atmosphere_mode", "")), "open_daylight", "floor 1 atmosphere should stay open daylight")
		else:
			_assert_eq(str(floor_root.get_meta("lighting_profile", "")), "slow_burn_suspense", "floor 4 should keep its existing street light")
	floor_root.rebuild(3, TEST_PALETTE, {}, 1, false, [], [], {}, [], _layout_dict(CURRENT_STREETS[3]))
	_assert_street(floor_root, CURRENT_STREETS[3], "floor 3 plan layout should keep today's gallery")
	_assert_eq(_logical_room_count(floor_root), 9, "floor 3 plan layout should keep today's nine rooms")
	_assert_walkable(floor_root, "floor 3 plan layout")
	_assert_true(floor_root.contains_playable_position(Vector3(10.0, 0.08, 0.0)), "today's gallery should still include the inner walk")
	_assert_true(not floor_root.contains_playable_position(Vector3(30.0, 0.08, 0.0)), "today's gallery should still exclude the outer walk")
	_assert_eq(str(floor_root.get_meta("lighting_profile", "")), "natural_skylight", "floor 3 should stay a daylight corridor")
	_assert_eq(str(floor_root.get_meta("atmosphere_mode", "")), "slow_burn_suspense", "floor 3 atmosphere should stay slow-burn suspense")
	_assert_true(bool(floor_root.get_meta("gallery_continuous", false)), "floor 3 plan layout should stay one continuous corridor")
	var generator_source := FileAccess.get_file_as_string("res://scripts/reality_floor_generator.gd")
	_assert_true(not generator_source.contains("func room_count_for_floor"), "the generator should not offer a floor-number room count")
	_assert_true(not generator_source.contains("_street_from_floor_number"), "the generator should not build a street from the floor number")
	_assert_true(FileAccess.file_exists("res://scripts/reality_floor_generator.gd"), "the generator should stay in Game")
	_assert_true(not FileAccess.file_exists("res://framework/reality_floor_generator.gd"), "the generator should not move into Framework")
	floor_root.free()
	if _failures.is_empty():
		print("floor layout tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _layout_dict(street: Dictionary) -> Dictionary:
	return {
		"room_count": int(street["room_count"]),
		"shape": str(street["shape"]),
		"map_size": {"width": float(street["width"]), "length": float(street["length"])},
	}


func _logical_room_count(floor_root: Node) -> int:
	var count := 0
	for node in floor_root.find_children("*", "Node3D", true, false):
		if bool(node.get_meta("logical_room", false)):
			count += 1
	return count


func _assert_walkable(floor_root, message: String) -> void:
	_assert_true(floor_root.contains_playable_position(floor_root.start_position()), "%s should keep the start inside the street" % message)
	var ground := floor_root.find_child("StreetGround", true, false) as StaticBody3D
	_assert_true(ground != null and ground.get_node_or_null("Collision") != null, "%s should keep a walkable ground" % message)


func _assert_disc_walkable(floor_root, message: String) -> void:
	_assert_true(floor_root.contains_playable_position(floor_root.start_position()), "%s should keep the start inside the disc" % message)
	_assert_true(floor_root.contains_playable_position(Vector3.ZERO), "%s should keep the center walkable" % message)
	var ground := floor_root.find_child("IrregularDiscGround", true, false) as StaticBody3D
	_assert_true(ground != null and ground.get_node_or_null("Collision") != null, "%s should keep a walkable disc" % message)


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
