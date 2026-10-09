extends SceneTree

const BINDING_PATH := "res://scripts/world/chapter_asset_binding.gd"

var _binding: Script
var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_assert_true(FileAccess.file_exists(BINDING_PATH), "chapter asset binding helper must exist")
	if FileAccess.file_exists(BINDING_PATH):
		_binding = load(BINDING_PATH) as Script
		_assert_true(_binding != null and _binding.can_instantiate(), "chapter asset binding helper must compile")
	if _binding != null and _binding.can_instantiate():
		_test_coordinate_conversion()
		_test_exact_recursive_lookup_and_authored_transform()
		_test_required_asset_nodes()
		_test_fixed_portal_and_moving_leaf()
	if _failures.is_empty():
		print("chapter asset binding tests passed (%d checks; synthetic transforms and collisions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_coordinate_conversion() -> void:
	_assert_vector(_binding.blender_vector([-2.5, 1.85, 2.72]), Vector3(-2.5, 2.72, -1.85), "Blender feet coordinates must become Godot x,z,-y")
	_assert_vector(_binding.blender_size([-0.055, 1.06, -2.2]), Vector3(0.055, 2.2, 1.06), "collision sizes must swap axes and remain positive")


func _test_exact_recursive_lookup_and_authored_transform() -> void:
	var host := _new_host()
	var asset := Node3D.new()
	asset.name = "Asset"
	asset.position = Vector3(2.0, -1.0, 4.0)
	asset.rotation.y = 0.35
	host.add_child(asset)
	var marker := Node3D.new()
	marker.name = "EntrySpawn"
	marker.position = Vector3(-2.5, 2.72, -1.85)
	marker.rotation.y = PI
	asset.add_child(marker)
	_assert_true(_binding.find_node(host, "EntrySpawn") == marker, "lookup must include nested imported markers")
	_assert_true(_binding.find_node(host, "Asset") == asset, "lookup must find exact names")
	_assert_true(_binding.find_node(host, str(host.name)) == host, "lookup must include its root")
	_assert_true(_binding.find_node(host, "Entry*") == null, "lookup must not treat marker names as glob patterns")
	_assert_true(_binding.find_node(host, "entryspawn") == null, "lookup must preserve exact marker case")
	var actual: Transform3D = _binding.anchor_transform(host, "EntrySpawn")
	_assert_true(actual.is_equal_approx(marker.global_transform), "anchor transform must use the imported marker's actual global transform")
	host.free()


func _test_required_asset_nodes() -> void:
	var contract := {
		"anchors": {"EntrySpawn": {}, "EntrySealTrigger": {}, "ExitThreshold": {}},
		"doors": {
			"entry": {"pivot_node": "EntryDoorPivot", "leaf_node": "EntryDoor_Leaf"},
			"exit": {"pivot_node": "ExitDoorPivot", "leaf_node": "ExitDoor_Leaf"},
		},
		"opening": {"pivot_node": "OpeningDoorPivot", "spawn_node": "AuthoredStart", "threshold_node": "AuthoredThreshold"},
	}
	var host := _new_host()
	var required: Array[String] = _binding.required_names("basement", contract)
	_assert_true(required.size() == 7 and required.has("EntrySpawn") and required.has("ExitDoor_Leaf"), "basement requirements must include contract anchors, pivots and leaves")
	var missing: Array[String] = _binding.validate(host, "basement", contract)
	_assert_true(missing.size() == required.size(), "every missing required marker must produce a validation error")
	for node_name in required:
		var marker := Node3D.new()
		marker.name = node_name
		host.add_child(marker)
	_assert_true(_binding.validate(host, "basement", contract).is_empty(), "complete imported hierarchy must validate")
	var opening_required: Array[String] = _binding.required_names("opening", contract)
	_assert_true(opening_required.has("OpeningDoorPivot") and opening_required.has("AuthoredStart") and opening_required.has("AuthoredThreshold"), "opening must use explicit contract spawn and threshold names")
	_assert_true(_binding.required_names("opening", {"opening": {}}) == ["OpeningDoorPivot"], "pending opening contract must require known pivot without guessing spawn names")
	var plain_marker := Node.new()
	plain_marker.name = "OpeningDoorPivot"
	host.add_child(plain_marker)
	var wrong_type: Array[String] = _binding.validate(host, "opening", {"opening": {}})
	_assert_true(wrong_type.size() == 1 and wrong_type[0].contains("Node3D"), "non-spatial required markers must be rejected before transform lookup")
	_assert_true(_binding.required_names("crossroads", contract).is_empty(), "legacy crossroads must not inherit basement marker requirements")
	host.free()


func _test_fixed_portal_and_moving_leaf() -> void:
	var host := _new_host()
	var asset := Node3D.new()
	asset.position = Vector3(1.0, 0.3, 2.0)
	asset.rotation.y = -0.2
	host.add_child(asset)
	var pivot := Node3D.new()
	pivot.name = "EntryDoorPivot"
	pivot.position = Vector3(-3.2, 2.7, -1.34)
	pivot.rotation.y = 0.15
	asset.add_child(pivot)
	var door_data := {"closed_leaf_local_center": [0, 0.53, 1.10], "leaf_size_blender": [0.055, 1.06, 2.2]}
	var collision: Dictionary = _binding.build_door_collision(pivot, door_data, host)
	var blocker: CollisionShape3D = collision.get("blocker")
	var leaf: StaticBody3D = collision.get("leaf")
	_assert_true(blocker != null and leaf != null, "door binding must provide blocker shape and moving leaf body")
	if blocker == null or leaf == null:
		host.free()
		return
	_assert_true(leaf.get_parent() == pivot, "moving collision must be owned by the visual hinge")
	_assert_true(blocker.get_parent() is StaticBody3D and blocker.get_parent().get_parent() == host, "portal collider must be independently owned under host")
	var leaf_shape := leaf.get_child(0) as CollisionShape3D
	_assert_true(leaf_shape != null and leaf_shape.shape is BoxShape3D, "door leaf must use a physical box shape")
	_assert_true(blocker.shape is BoxShape3D and not blocker.disabled, "portal must start with physical collision enabled")
	_assert_true(leaf.collision_layer == 1 and blocker.get_parent().collision_layer == 1, "both door colliders must occupy world collision layer one")
	if leaf_shape != null:
		var expected_center: Vector3 = pivot.global_transform * Vector3(0.0, 1.1, -0.53)
		_assert_vector(leaf_shape.global_position, expected_center, "leaf center must use Blender-local center in authored pivot transform")
		_assert_vector(blocker.global_position, expected_center, "fixed blocker must occupy authored closed doorway in transformed host")
		_assert_vector(leaf_shape.shape.size, Vector3(0.055, 2.2, 1.06), "leaf box dimensions must follow contract conversion")
		_assert_true(blocker.global_transform.is_equal_approx(leaf_shape.global_transform), "portal orientation must match the closed leaf")
		var closed_portal := blocker.global_transform
		var closed_leaf := leaf_shape.global_transform
		pivot.rotate_y(PI * 0.5)
		_assert_true(blocker.global_transform.is_equal_approx(closed_portal), "portal must stay fixed as pivot opens")
		_assert_true(not leaf_shape.global_transform.is_equal_approx(closed_leaf), "physical leaf must follow opening pivot")
	host.free()


func _new_host() -> Node3D:
	var host := Node3D.new()
	host.position = Vector3(6.0, -2.0, 8.0)
	host.rotation.y = 0.7
	root.add_child(host)
	return host


func _assert_vector(actual: Vector3, expected: Vector3, message: String) -> void:
	_assert_true(actual.is_equal_approx(expected), "%s (expected %s, got %s)" % [message, expected, actual])


func _assert_true(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
