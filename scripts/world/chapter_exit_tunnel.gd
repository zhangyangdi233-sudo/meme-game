extends Node3D
## A physical continuation of the basement exit. Local -Z leads to the white door.
## All geometry stays in the old visit until the caller covers the view completely.

const Door = preload("res://scripts/world/chapter_door.gd")
const Binding = preload("res://scripts/world/chapter_asset_binding.gd")
const LENGTH := 12.0
const WIDTH := 2.1
const HEIGHT := 2.7
const SEAL_DEPTH := 1.3

var door: Node3D


func build() -> void:
	var concrete := _material(Color("151715"))
	var trim := _material(Color("20231F"))
	var white := _material(Color("DCE0D5"), 0.30)
	var panel := _material(Color("BFC5B8"), 0.13)
	var light := _material(Color.WHITE, 1.0, true)
	_box(self, "TunnelFloor", Vector3(0, -0.1, -5.95), Vector3(WIDTH + 0.3, 0.2, 13.0), concrete, true)
	_box(self, "TunnelCeiling", Vector3(0, HEIGHT + 0.1, -6.0), Vector3(WIDTH + 0.3, 0.2, 12.8), concrete, true)
	for side in [-1.0, 1.0]:
		_box(self, "TunnelWall", Vector3(side * (WIDTH * 0.5 + 0.1), HEIGHT * 0.5, -6.0), Vector3(0.2, HEIGHT, 12.0), concrete, true)
		for rib in range(1, 5):
			_box(self, "WallRib", Vector3(side * 1.015, HEIGHT * 0.5, -float(rib) * 2.5), Vector3(0.07, HEIGHT, 0.10), trim)
		_box(self, "EndWall", Vector3(side * 0.85, HEIGHT * 0.5, -LENGTH), Vector3(0.60, HEIGHT, 0.25), concrete, true)
		_box(self, "DoorFrame", Vector3(side * 0.62, 1.16, -LENGTH + 0.035), Vector3(0.12, 2.32, 0.16), white)
		_box(self, "LightSeam", Vector3(side * 0.558, 1.13, -LENGTH + 0.048), Vector3(0.014, 2.25, 0.014), light)
	_box(self, "EndLintel", Vector3(0, 2.5, -LENGTH), Vector3(1.2, 0.4, 0.25), concrete, true)
	_box(self, "DoorFrameTop", Vector3(0, 2.32, -LENGTH + 0.035), Vector3(1.36, 0.12, 0.16), white)
	_box(self, "LightSeamTop", Vector3(0, 2.252, -LENGTH + 0.048), Vector3(1.13, 0.012, 0.014), light)
	# The light stays behind the moving leaf, filling the opening as it turns.
	_box(self, "WhiteBeyondDoor", Vector3(0, 1.13, -LENGTH - 0.23), Vector3(1.16, 2.3, 0.02), light)
	_box(self, "TunnelEndCollision", Vector3(0, HEIGHT * 0.5, -LENGTH - 0.5), Vector3(WIDTH, HEIGHT, 0.1), concrete, true)
	var pivot := Node3D.new()
	pivot.name = "TunnelWhiteDoorPivot"
	pivot.position = Vector3(-0.56, 0, -LENGTH)
	add_child(pivot)
	_box(pivot, "WhiteDoorLeaf", Vector3(0.56, 1.125, 0), Vector3(1.1, 2.25, 0.07), white)
	for column in [0.29, 0.83]:
		for row in [0.42, 1.14, 1.86]:
			_box(pivot, "RaisedDoorPanel", Vector3(column, row, 0.044), Vector3(0.42, 0.52, 0.025), panel)
	var knob := MeshInstance3D.new()
	knob.name = "WhiteDoorKnob"
	var sphere := SphereMesh.new()
	sphere.radius = 0.045
	sphere.height = 0.09
	knob.mesh = sphere
	knob.position = Vector3(0.98, 1.08, 0.10)
	knob.material_override = _material(Color("777463"))
	pivot.add_child(knob)
	var collision := Binding.build_door_collision(pivot, {"closed_leaf_local_center": [0.56, 0, 1.125], "leaf_size_blender": [1.1, 0.07, 2.25]}, self)
	door = Door.new()
	door.name = "TunnelDoorController"
	add_child(door)
	door.bind(pivot, collision.blocker, 90.0, 1.25)
	var glow := OmniLight3D.new()
	glow.name = "WhiteDoorSpill"
	glow.position = Vector3(0, 1.5, -LENGTH + 0.5)
	glow.light_color = Color("ECF0E8")
	glow.light_energy = 0.65
	glow.omni_range = 3.0
	glow.shadow_enabled = true
	add_child(glow)
	# A little reflected floor light provides depth without illuminating the hall.
	var floor_glow := OmniLight3D.new()
	floor_glow.name = "TunnelFloorBounce"
	floor_glow.position = Vector3(0, 0.35, -7.0)
	floor_glow.light_color = Color("A6B3A1")
	floor_glow.light_energy = 0.035
	floor_glow.omni_range = 5.0
	add_child(floor_glow)


func contains_position(world_position: Vector3, inset: float = 0.0) -> bool:
	var pad := clampf(inset, -0.2, 0.08)
	return AABB(Vector3(-WIDTH * 0.5 + pad, -0.3, -LENGTH - 0.4), Vector3(WIDTH - pad * 2, HEIGHT + 0.6, LENGTH + 0.9)).has_point(to_local(world_position))


func is_safely_inside(world_position: Vector3) -> bool:
	return contains_position(world_position) and to_local(world_position).z <= -SEAL_DEPTH


func interaction_position() -> Vector3:
	return to_global(Vector3(0, 0.02, -LENGTH + 0.7))


func camera_position() -> Vector3:
	return to_global(Vector3(0, 1.35, -LENGTH + 2.4))


func camera_target() -> Vector3:
	return to_global(Vector3(0, 1.15, -LENGTH))


func _material(color: Color, emission: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.94
	material.emission_enabled = emission > 0.0
	material.emission = color
	material.emission_energy_multiplier = emission
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _box(parent: Node3D, label: String, center: Vector3, size: Vector3, material: Material, solid: bool = false) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = center
	mesh.material_override = material
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		body.name = label + "Body"
		parent.add_child(body)
		var collider := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		collider.shape = box_shape
		collider.position = center
		body.add_child(collider)
