extends RefCounted
## Authored white door shared by the crossroads and residential exit.
## Hosts own the hinge and gameplay collision at these same human-scale sizes.

const Binding = preload("res://scripts/world/chapter_asset_binding.gd")
const SOURCE_PATH := "res://assets/chapter1/Opening_WhiteDoor_v2.glb"
const SOURCE_LEAF_SIZE := Vector3(1.12, 2.25, 0.08)
const TARGET_LEAF_SIZE := SOURCE_LEAF_SIZE


static func attach(pivot: Node3D, host: Node3D) -> void:
	var source := (load(SOURCE_PATH) as PackedScene).instantiate() as Node3D
	var source_pivot := Binding.find_node(source, "OpeningDoorPivot") as Node3D
	assert(source_pivot != null, "The authored white door must retain its named hinge")
	var size_scale := TARGET_LEAF_SIZE / SOURCE_LEAF_SIZE
	# Preserve the source door's proportions; hosts center the hinge and size
	# their collision from TARGET_LEAF_SIZE instead of stretching the leaf.
	var moving := Node3D.new()
	moving.name = "ChapterFarGateLeaf"
	moving.scale = size_scale
	moving.set_meta("visual_source", SOURCE_PATH)
	pivot.add_child(moving)
	for mesh: MeshInstance3D in source_pivot.find_children("*", "MeshInstance3D", true, false):
		var copy := _copy_mesh(mesh)
		copy.transform = _relative_transform(mesh, source_pivot)
		moving.add_child(copy)
	var fixed := Node3D.new()
	fixed.name = "CrossroadsWhiteDoor"
	fixed.position = pivot.position + Vector3(TARGET_LEAF_SIZE.x * 0.5, 0, 0)
	fixed.scale = size_scale
	fixed.set_meta("visual_source", SOURCE_PATH)
	host.add_child(fixed)
	var source_center := _relative_transform(source_pivot, source).origin + Vector3(SOURCE_LEAF_SIZE.x * 0.5, 0, 0)
	for mesh: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		var node_name := str(mesh.name)
		if not (node_name.begins_with("Frame_") or node_name.begins_with("LightSeam_") or node_name == "OpeningDoor_LightPlane"):
			continue
		var copy := _copy_mesh(mesh)
		copy.transform = _relative_transform(mesh, source)
		copy.position -= source_center
		fixed.add_child(copy)
	var glow := OmniLight3D.new()
	glow.name = "CrossroadsWhiteDoorGlow"
	glow.position = Vector3(0.0, 1.25, 0.5)
	glow.light_color = Color("FFF8EA")
	glow.light_energy = 0.65
	glow.omni_range = 3.3
	glow.shadow_enabled = false
	fixed.add_child(glow)
	# The original scene contains its own black ground, markers and collision
	# proxies. None are added to the crossroads, and no source resource is edited.
	source.free()


static func _copy_mesh(source: MeshInstance3D) -> MeshInstance3D:
	var copy := source.duplicate() as MeshInstance3D
	copy.name = source.name
	for surface in source.mesh.get_surface_count():
		var original := source.get_active_material(surface) as StandardMaterial3D
		if original == null or not original.emission_enabled:
			continue
		var material := original.duplicate() as StandardMaterial3D
		# Daylit crossroads need the raised panels readable; the white portal and
		# light seams keep their authored intensity while the enamel is softened.
		if not str(source.name).begins_with("LightSeam_") and source.name != "OpeningDoor_LightPlane":
			material.emission_energy_multiplier *= 0.035
			var paint_scale := 0.44 if str(source.name).ends_with("_Recess") else 0.55
			material.albedo_color = Color(original.albedo_color.r * paint_scale, original.albedo_color.g * paint_scale, original.albedo_color.b * paint_scale, original.albedo_color.a)
		copy.set_surface_override_material(surface, material)
	if source.name == "OpeningDoor_LightPlane" or str(source.name).begins_with("LightSeam_"):
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return copy


static func _relative_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != ancestor and parent is Node3D:
		result = (parent as Node3D).transform * result
		parent = parent.get_parent()
	return result
