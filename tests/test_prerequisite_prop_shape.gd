extends SceneTree
## Prerequisite prop meshes follow the item on the Floor composer plan.
## The floor number does not choose the nameplate, cassette, or page.

const FloorComposerScript = preload("res://scripts/game/floor_composer.gd")
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

const DEFAULT_PROPS := {
	1: {"id": "artifact_named_lamp_tag", "marker": "OldNameplate"},
	2: {"id": "artifact_reversed_tape", "marker": "CassetteBody"},
	3: {"id": "artifact_missing_subject_page", "marker": "MissingSubjectPage"},
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var floor_root := RealityFloorGeneratorScript.new()
	root.add_child(floor_root)
	for floor_number in [1, 2, 3]:
		var expected: Dictionary = DEFAULT_PROPS[floor_number]
		var composed := FloorComposerScript.compose({"day_progress": {"tower_floor": floor_number, "day": 1}})
		floor_root.rebuild(
			floor_number,
			TEST_PALETTE,
			{},
			1,
			false,
			composed.get("items", []),
			[],
			composed.get("display_names", {})
		)
		var prop := _find_prerequisite_item(floor_root)
		var item_id := str(expected["id"])
		var marker := str(expected["marker"])
		_assert_true(prop != null, "floor %d should still place one prerequisite prop" % floor_number)
		if prop == null:
			continue
		_assert_eq(str(prop.get_meta("item_id", "")), item_id, "floor %d should list its catalog prop" % floor_number)
		_assert_true(_has_named_child(prop, marker), "floor %d should show %s" % [floor_number, marker])
		_assert_only_marker(prop, marker, "floor %d" % floor_number)
		_assert_true(not prop.visible, "floor %d prop should stay hidden until the clue" % floor_number)
		floor_root.sync_prerequisite_items([item_id], [])
		_assert_true(prop.visible and prop in floor_root.get_interactable_items(), "floor %d prop should become pickupable after the clue" % floor_number)
	var tape_plan := FloorComposerScript.compose({"day_progress": {"tower_floor": 2, "day": 1}})
	floor_root.rebuild(
		1,
		TEST_PALETTE,
		{},
		1,
		false,
		tape_plan.get("items", []),
		[],
		tape_plan.get("display_names", {})
	)
	var swapped := _find_prerequisite_item(floor_root)
	_assert_eq(int(floor_root.built_floor), 1, "swapping the listed prop should keep floor 1")
	_assert_true(swapped != null, "floor 1 should still place the prop from the swapped plan")
	if swapped != null:
		_assert_eq(str(swapped.get_meta("item_id", "")), "artifact_reversed_tape", "the swapped plan should list the tape")
		_assert_true(_has_named_child(swapped, "CassetteBody"), "floor 1 should show the tape when the plan lists the tape")
		_assert_only_marker(swapped, "CassetteBody", "swapped floor 1")
		floor_root.sync_prerequisite_items(["artifact_reversed_tape"], [])
		_assert_true(swapped.visible and swapped in floor_root.get_interactable_items(), "the swapped tape should still be pickupable")
	floor_root.free()
	if _failures.is_empty():
		print("prerequisite prop shape tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _assert_only_marker(prop: Node, marker: String, label: String) -> void:
	for other_marker in ["OldNameplate", "CassetteBody", "MissingSubjectPage"]:
		if other_marker == marker:
			continue
		_assert_true(not _has_named_child(prop, other_marker), "%s should not show %s" % [label, other_marker])


func _find_prerequisite_item(node: Node) -> Area3D:
	if node is Area3D and bool(node.get_meta("prerequisite_item", false)):
		return node as Area3D
	for child in node.get_children():
		var found := _find_prerequisite_item(child)
		if found != null:
			return found
	return null


func _has_named_child(node: Node, node_name: String) -> bool:
	if node.name == node_name:
		return true
	for child in node.get_children():
		if _has_named_child(child, node_name):
			return true
	return false


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
