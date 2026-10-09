extends RefCounted
## Binds runtime behavior to exact authored nodes without replacing their geometry.


static func find_node(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	if str(root.name) == node_name:
		return root
	for child in root.get_children():
		var found := find_node(child, node_name)
		if found != null:
			return found
	return null


static func blender_vector(value: Array) -> Vector3:
	assert(value.size() == 3, "A Blender vector must contain exactly three coordinates")
	return Vector3(float(value[0]), float(value[2]), -float(value[1]))


static func blender_size(value: Array) -> Vector3:
	return blender_vector(value).abs()


static func anchor_transform(root: Node3D, node_name: String) -> Transform3D:
	var marker := find_node(root, node_name) as Node3D
	if marker == null:
		push_error("Chapter asset requires a Node3D marker named '%s'; validate before binding" % node_name)
		return Transform3D.IDENTITY
	return marker.global_transform


static func required_names(stage: String, contract: Dictionary) -> Array[String]:
	var names: Array[String] = []
	var stage_data: Dictionary = contract if stage == "basement" else contract.get(stage, {})
	if stage == "opening":
		# This pivot is explicitly named in the v2 contract. Spawn and threshold
		# names must come from the exporter, never from guessed geometry positions.
		_append_name(names, str(stage_data.get("pivot_node", "OpeningDoorPivot")))
	for key in ["pivot_node", "leaf_node", "spawn_node", "threshold_node"]:
		if stage_data.has(key):
			_append_name(names, str(stage_data[key]))
	for node_name in stage_data.get("required_nodes", []):
		_append_name(names, str(node_name))
	var anchors: Dictionary = stage_data.get("anchors", {})
	for node_name in anchors:
		_append_name(names, str(node_name))
	var doors: Dictionary = stage_data.get("doors", {})
	for door_data: Dictionary in doors.values():
		for key in ["pivot_node", "leaf_node"]:
			if door_data.has(key):
				_append_name(names, str(door_data[key]))
	return names


static func validate(root: Node, stage: String, contract: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for node_name in required_names(stage, contract):
		var marker := find_node(root, node_name)
		if marker == null:
			errors.append("Missing %s asset node: %s" % [stage, node_name])
		elif not marker is Node3D:
			errors.append("%s asset node must be Node3D: %s" % [stage, node_name])
	return errors


static func build_door_collision(pivot: Node3D, door_data: Dictionary, host: Node3D) -> Dictionary:
	# The caller normalizes an initially open authored pivot to its closed pose
	# before binding. Capture that pose once so the portal never follows the hinge.
	if pivot == null or host == null:
		push_error("Chapter door collision requires an authored pivot and host")
		return {}
	var center: Array = door_data.get("closed_leaf_local_center", [])
	var dimensions: Array = door_data.get("leaf_size_blender", [])
	if center.size() != 3 or dimensions.size() != 3:
		push_error("Chapter door contract requires closed_leaf_local_center and leaf_size_blender")
		return {}
	var local_center := blender_vector(center)
	var size := blender_size(dimensions)
	if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
		push_error("Chapter door collision dimensions must be positive")
		return {}
	var leaf := StaticBody3D.new()
	leaf.name = "%s_LeafCollision" % pivot.name
	leaf.collision_layer = 1
	leaf.collision_mask = 1
	pivot.add_child(leaf)
	leaf.add_child(_box_shape(local_center, size))
	var portal := StaticBody3D.new()
	portal.name = "%s_PortalCollision" % pivot.name
	portal.collision_layer = 1
	portal.collision_mask = 1
	host.add_child(portal)
	portal.global_transform = pivot.global_transform
	var blocker := _box_shape(local_center, size)
	portal.add_child(blocker)
	return {"blocker": blocker, "leaf": leaf}


static func _append_name(names: Array[String], node_name: String) -> void:
	if not node_name.is_empty() and not names.has(node_name):
		names.append(node_name)


static func _box_shape(center: Vector3, size: Vector3) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = center
	return collision
