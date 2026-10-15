extends Node3D
## Original low-poly residential kit. Its occupied parcels are exactly the map's
## # cells; the two roofed passage rooms remain inside their walkable . cells.

const Layout = preload("res://scripts/world/floor_two_maze_layout.gd")
const WhiteGate = preload("res://scripts/world/chapter_white_gate.gd")
var _height: Callable
var _materials: Dictionary = {}
var _window_light_count := 0
var _detail_batches: Dictionary = {}


func build(layout: Dictionary, height_sampler: Callable) -> void:
	name = "FloorTwoResidentialMaze"
	_height = height_sampler
	_make_materials()
	set_meta("original_geometry", true)
	set_meta("visual_reference", "Promesa official 06, 01, 09; original assets")
	set_meta("texture_size", 128)
	set_meta("clear_passage_width", Layout.PASSAGE_WIDTH)
	for data: Dictionary in layout.buildings:
		_build_house(data)
	_build_passage(Layout.WAYFINDER_CELL, false, "WayfinderPassage")
	_build_passage(Layout.CARTOGRAPHER_CELL, true, "CartographerPassage")
	_build_exit(layout.exit_position)
	_flush_detail_batches()


func ground_material() -> StandardMaterial3D:
	return _materials.stone


func _build_house(data: Dictionary) -> void:
	var cell: Vector2i = data.cell
	var rect: Rect2 = data.rect
	var center := rect.get_center()
	var bottom := INF
	var highest_ground := -INF
	for offset in [Vector2.ZERO, Vector2(rect.size.x, 0), rect.size, Vector2(0, rect.size.y), rect.size * 0.5]:
		var height := _sample(rect.position + offset)
		bottom = minf(bottom, height - 0.70)
		highest_ground = maxf(highest_ground, height)
	var top := highest_ground + float(data.height)
	var house := Node3D.new()
	house.name = str(data.id)
	house.set_meta("physical_house", true)
	house.set_meta("maze_cell", cell)
	house.set_meta("floor_count", int(data.storeys))
	house.set_meta("building_footprint", rect)
	house.set_meta("roof_height", top)
	add_child(house)
	var wall_material: StandardMaterial3D = _materials["plaster_%d" % posmod(cell.x + cell.y, 3)]
	_box(house, "SolidResidence", Vector3(8.0, top - bottom, 8.0), Vector3(center.x, (top + bottom) * 0.5, center.y), wall_material, true)
	_box(house, "OverhangingCornice", Vector3(8.26, 0.18, 8.26), Vector3(center.x, top + 0.08, center.y), _materials.trim)
	_box(house, "RoofCap", Vector3(8.16, 0.12, 8.16), Vector3(center.x, top + 0.23, center.y), _materials.roof)
	for direction in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		if not Layout.is_walkable(cell + direction):
			continue
		var face := Node3D.new()
		face.name = "Facade_%d_%d" % [direction.x, direction.y]
		face.position = Vector3(center.x + float(direction.x) * 4.005, 0, center.y + float(direction.y) * 4.005)
		face.rotation.y = atan2(float(direction.x), float(direction.y))
		house.add_child(face)
		var frontage_ground := _sample(center + Vector2(direction) * 3.95)
		var plinth_height := maxf(0.35, frontage_ground + 0.45 - bottom)
		_box(face, "StonePlinth", Vector3(8.0, plinth_height, 0.09), Vector3(0, bottom + plinth_height * 0.5, 0.035), _materials.plinth)
		for storey in int(data.storeys):
			var window_y := highest_ground + 2.05 + float(storey) * 3.2
			for bay in 2:
				var warm := posmod(cell.x * 17 + cell.y * 11 + storey * 7 + bay * 3, 19) == 0
				_window(face, "Window_%d_%d" % [storey, bay], Vector3(-2.15 + float(bay) * 4.3, window_y, 0.065), warm, posmod(cell.x + bay, 3) == 0)
			if storey > 0:
				_box(face, "StoreyBand%d" % storey, Vector3(8.02, 0.12, 0.16), Vector3(0, highest_ground + 0.55 + float(storey) * 3.2, 0.08), _materials.trim)
		_door_recess(face, Vector3(0, frontage_ground, 0.055))


func _window(parent: Node3D, label: String, position: Vector3, warm: bool, shutters: bool) -> void:
	var window := Node3D.new()
	window.name = label
	window.position = position
	window.set_meta("recess_depth", 0.16)
	parent.add_child(window)
	_box(window, "DarkRecess", Vector3(1.05, 1.42, 0.025), Vector3.ZERO, _materials.warm_window if warm else _materials.window)
	for side in [-1.0, 1.0]:
		_box(window, "Jamb%s" % str(side), Vector3(0.11, 1.64, 0.19), Vector3(side * 0.58, 0, 0.06), _materials.trim)
	_box(window, "Lintel", Vector3(1.27, 0.11, 0.19), Vector3(0, 0.77, 0.06), _materials.trim)
	_box(window, "StoneSill", Vector3(1.38, 0.15, 0.34), Vector3(0, -0.77, 0.13), _materials.trim)
	_box(window, "Mullion", Vector3(0.045, 1.43, 0.045), Vector3(0, 0, 0.065), _materials.wood)
	_box(window, "Transom", Vector3(1.05, 0.045, 0.045), Vector3(0, 0.02, 0.065), _materials.wood)
	if shutters and not warm:
		for side in [-1.0, 1.0]:
			_box(window, "Shutter%s" % str(side), Vector3(0.27, 1.4, 0.055), Vector3(side * 0.39, 0, 0.055), _materials.wood)
			for slat in 7:
				_box(window, "Slat_%s_%d" % [str(side), slat], Vector3(0.29, 0.045, 0.075), Vector3(side * 0.39, -0.58 + float(slat) * 0.19, 0.08), _materials.roof)
	if warm and _window_light_count < 6:
		var light := OmniLight3D.new()
		light.name = "WindowGlow"
		light.position = Vector3(0, 0, 0.5)
		light.light_color = Color("FFC892")
		light.light_energy = 0.42
		light.omni_range = 4.2
		light.shadow_enabled = false
		window.add_child(light)
		_window_light_count += 1


func _door_recess(parent: Node3D, ground: Vector3) -> void:
	var door := Node3D.new()
	door.name = "RecessedResidentialDoor"
	door.position = ground
	parent.add_child(door)
	_box(door, "DoorPanel", Vector3(1.12, 2.28, 0.025), Vector3(0, 1.14, 0), _materials.wood)
	for side in [-1.0, 1.0]:
		_box(door, "DoorJamb%s" % str(side), Vector3(0.14, 2.5, 0.25), Vector3(side * 0.64, 1.25, 0.08), _materials.trim)
	_box(door, "DoorLintel", Vector3(1.42, 0.16, 0.25), Vector3(0, 2.48, 0.08), _materials.trim)
	for panel in 2:
		_box(door, "InsetPanel%d" % panel, Vector3(0.9, 0.7, 0.018), Vector3(0, 0.59 + float(panel) * 1.04, 0.022), _materials.window)
	_box(door, "Handle", Vector3(0.08, 0.19, 0.09), Vector3(0.39, 1.07, 0.07), _materials.trim)


func _build_passage(cell: Vector2i, east_west: bool, label: String) -> void:
	var center := Layout.point_at_cell(cell, _height)
	var room := Node3D.new()
	room.name = label
	room.position = Vector3(center.x, 0, center.z)
	room.rotation.y = PI * 0.5 if east_west else 0.0
	room.set_meta("walkthrough_room", true)
	room.set_meta("logical_room", true)
	room.set_meta("clear_passage_width", Layout.PASSAGE_WIDTH)
	add_child(room)
	var bottom := center.y - 1.0
	var roof := center.y + 3.75
	var wall_index := 0
	for rect in Layout.passage_blocking_rects(cell, east_west):
		var wall_center := rect.get_center()
		# Use world-aligned collision dimensions straight from the shared map
		# rectangles; the rotated passage parent is only decorative trim.
		_box(self, "%sSide%d" % [label, wall_index], Vector3(rect.size.x, roof - bottom, rect.size.y), Vector3(wall_center.x, (roof + bottom) * 0.5, wall_center.y), _materials.plaster_1, true)
		wall_index += 1
	for side in [-1.0, 1.0]:
		_box(room, "RoomBase%s" % str(side), Vector3(0.09, 0.45, 7.9), Vector3(side * 1.36, center.y + 0.22, 0), _materials.plinth)
	_box(room, "PassageCeiling", Vector3(8.1, 0.24, 8.1), Vector3(0, roof + 0.12, 0), _materials.trim, true)
	for end in [-1.0, 1.0]:
		_box(room, "PassageLintel%s" % str(end), Vector3(3.05, 0.25, 0.32), Vector3(0, roof - 0.16, end * 3.93), _materials.trim)
		for side in [-1.0, 1.0]:
			_box(room, "PassageJamb%s_%s" % [str(end), str(side)], Vector3(0.12, roof - center.y, 0.32), Vector3(side * 1.47, (roof + center.y) * 0.5, end * 3.93), _materials.trim)
	# A small warm window belongs to the house; no floating lamp or prop.
	var interior_window := Node3D.new()
	interior_window.position = Vector3(-1.395, center.y + 2.0, -0.7)
	interior_window.rotation.y = PI * 0.5
	room.add_child(interior_window)
	_window(interior_window, "PassageWindow", Vector3.ZERO, true, false)


func _build_exit(position: Vector3) -> void:
	var host := Node3D.new()
	host.name = "FloorTwoWhiteExit"
	host.position = Vector3(position.x, _sample(Vector2(position.x, position.z - 3.6)), position.z - 3.6)
	add_child(host)
	var pivot := Node3D.new()
	pivot.name = "WhiteExitPivot"
	pivot.position.x = -WhiteGate.TARGET_LEAF_SIZE.x * 0.5
	host.add_child(pivot)
	WhiteGate.attach(pivot, host)
	for mesh: MeshInstance3D in host.find_children("*", "MeshInstance3D", true, false):
		if str(mesh.name).begins_with("LightSeam_") or mesh.name == "OpeningDoor_LightPlane":
			continue
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as StandardMaterial3D
			if original == null:
				continue
			var paint := original.duplicate() as StandardMaterial3D
			paint.albedo_color = Color("E7E3D8")
			paint.emission_enabled = true
			paint.emission = Color("E7E3D8")
			paint.emission_energy_multiplier = 0.22
			paint.roughness = 0.9
			mesh.set_surface_override_material(surface, paint)
	host.set_meta("exit_visual_only", true)
	# The original house behind this authored door remains a solid boundary.
	# Gameplay handles F at floor2_exit and transitions without walking outside.


func _box(parent: Node3D, label: String, size: Vector3, position: Vector3, material: Material, collision := false) -> void:
	if not collision:
		var key := material.get_instance_id()
		if not _detail_batches.has(key):
			_detail_batches[key] = {"material": material, "transforms": []}
		var local_transform := Transform3D(Basis.IDENTITY.scaled(size), position)
		_detail_batches[key].transforms.append(global_transform.affine_inverse() * parent.global_transform * local_transform)
		return
	var holder := StaticBody3D.new()
	holder.name = label
	holder.position = position
	parent.add_child(holder)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	holder.add_child(mesh)
	holder.collision_layer = 1
	holder.collision_mask = 1
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	holder.add_child(collider)


func _flush_detail_batches() -> void:
	var unit_box := BoxMesh.new()
	unit_box.size = Vector3.ONE
	var count := 0
	for bucket: Dictionary in _detail_batches.values():
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = unit_box
		instances.instance_count = bucket.transforms.size()
		for index in instances.instance_count:
			instances.set_instance_transform(index, bucket.transforms[index])
		var batch := MultiMeshInstance3D.new()
		batch.name = "ResidentialDetailBatch%d" % count
		batch.multimesh = instances
		batch.material_override = bucket.material
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)
		count += 1
	set_meta("detail_material_batch_count", count)
	_detail_batches.clear()


func _sample(flat: Vector2) -> float:
	return float(_height.call(flat.x, flat.y))


func _make_materials() -> void:
	var plaster_texture := _texture("plaster")
	for index in 3:
		var colors := [Color("CBC8B9"), Color("BDBDB6"), Color("D5D0C2")]
		_materials["plaster_%d" % index] = _material(colors[index], plaster_texture, 0.19)
	_materials.stone = _material(Color("A5A7AC"), _texture("stone"), 0.24)
	# The preserved radial terrain uses its existing mixed winding; keep both
	# sides visible, as the original generator material did.
	_materials.stone.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials.trim = _material(Color("B4B3AB"), plaster_texture, 0.35)
	_materials.plinth = _material(Color("6E747C"), _texture("stone"), 0.30)
	_materials.roof = _material(Color("343945"), _texture("roof"), 0.24)
	_materials.wood = _material(Color("41454B"), _texture("wood"), 0.42)
	_materials.window = _material(Color("080E1A"))
	_materials.warm_window = _material(Color("B8996C"))
	_materials.warm_window.emission_enabled = true
	_materials.warm_window.emission = Color("E6B36F")
	_materials.warm_window.emission_energy_multiplier = 0.75


func _material(color: Color, texture: Texture2D = null, scale_value := 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_texture = texture
	material.roughness = 0.98
	material.metallic_specular = 0.08
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if texture != null:
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE * scale_value
	return material


func _texture(kind: String) -> ImageTexture:
	var image := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var block_hash := posmod((x / 3) * 73856093 ^ (y / 3) * 19349663, 101)
			var fine_hash := posmod(x * 727 + y * 991, 97)
			var value := 0.86 + float(block_hash) * 0.0011 + float(fine_hash) * 0.00045
			if kind == "plaster":
				var stain := sin(float(x / 4) * 1.7) * cos(float(y / 6) * 0.8)
				value -= maxf(0.0, stain - 0.32) * 0.11
			elif kind == "stone":
				var row := y / 12
				var stone_x := posmod(x + (row % 2) * 9, 18)
				value = 0.64 + float(posmod((x / 18) * 43 + row * 17, 17)) * 0.013 + float(fine_hash) * 0.0008
				if y % 12 < 2 or stone_x < 2:
					value *= 0.76
			elif kind == "wood":
				value = 0.72 + float(posmod(x / 3, 7)) * 0.028 + float(fine_hash) * 0.0008
			elif kind == "roof":
				value = 0.70 + float(block_hash) * 0.0015
				if y % 12 < 2 or posmod(x + (y / 12 % 2) * 6, 12) < 1:
					value *= 0.70
			image.set_pixel(x, y, Color(value, value, value))
	return ImageTexture.create_from_image(image)
