extends Node3D
## Editable dressing and per-visit anomalies for the authored basement.
## All positions below are Godot metres in the imported room's local space.
## The original GLB remains intact; this module corrects its runtime instance.

const Binding = preload("res://scripts/world/chapter_asset_binding.gd")
const XRAY_LAYER := 1 << 19
const TEXTURE_DIR := "res://assets/chapter1/atmosphere/"
const FLICKER_VISIT := 1 # zero-based: second visit
const BLACKOUT_VISIT := 2
const CLOCK_WALL_VISIT := 3
const BROKEN_CLOCK_VISIT := 4
const FLICKER_SECONDS := 3.6

var _asset: Node3D
var _switch: Area3D
var _round := 0
var _elapsed := 0.0
var _anomaly_started := false
var _anomaly_cancelled := false
var _lights_on := true
var _lights: Array[OmniLight3D] = []
var _bulb_materials: Array[StandardMaterial3D] = []
var _switch_rocker: Node3D
var _clock_hands: Array[Node3D] = []
var _textures: Dictionary = {}
var _clock_time := 0.0


func configure(asset: Node3D, _contract: Dictionary, progress: Dictionary) -> void:
	_asset = asset
	_round = int(progress.get("round_index", 0))
	global_transform = asset.global_transform
	_ground_npcs()
	# Synthetic chapter fixtures intentionally have no furniture. Do not add
	# production dressing to tests or unrelated replacement room contracts.
	if Binding.find_node(asset, "Prop_LightSwitch") == null:
		return
	_repair_stairwell()
	_apply_surface_materials()
	_bind_fixture_lights()
	_dress_furniture()
	_build_switch(int(progress.get("transition_serial", 0)))
	_build_clocks()
	_dress_exit_table(int(progress.get("decoration_seed", 1701)))
	set_meta("anomaly", ["normal", "flicker", "blackout", "clock_wall", "xray_broken_clock"][clampi(_round, 0, 4)])


func interaction_actor() -> Area3D:
	return _switch


func toggle_lights() -> bool:
	if _switch == null:
		return false
	_anomaly_cancelled = true
	_apply_light_state(not _lights_on)
	return true


func lights_are_on() -> bool:
	return _lights_on


func update_visit(delta: float, entrance_locked: bool) -> void:
	_clock_time += maxf(delta, 0.0)
	for hand in _clock_hands:
		hand.rotation.z = float(hand.get_meta("initial_angle", 0.0)) - _clock_time * TAU / 60.0
	if not entrance_locked or _lights.is_empty() or _anomaly_cancelled:
		return
	_elapsed += maxf(delta, 0.0)
	if _round == FLICKER_VISIT and _elapsed >= 2.5:
		_anomaly_started = true
		var t := _elapsed - 2.5
		if t < FLICKER_SECONDS:
			var phase := int(t * 11.0)
			_apply_light_state(phase % 5 != 1 and phase % 7 != 2)
		else:
			_apply_light_state(true)
			_anomaly_cancelled = true
	elif _round == BLACKOUT_VISIT and _elapsed >= 3.0 and not _anomaly_started:
		_anomaly_started = true
		_apply_light_state(false)


func _ground_npcs() -> void:
	for actor: Area3D in get_parent().find_children("*", "Area3D", true, false):
		if str(actor.get_meta("actor_type", "")) != "chapter1_npc":
			continue
		if bool(actor.get_meta("grounded_horizontal_billboard", false)):
			continue
		var portrait := actor.get_node_or_null("Billboard") as Sprite3D
		var bottom_padding := 0.0
		if portrait != null and portrait.texture != null:
			var pixels := portrait.texture.get_image()
			if pixels != null and not pixels.is_empty():
				var used := pixels.get_used_rect()
				bottom_padding = float(pixels.get_height() - used.end.y) * portrait.pixel_size
		for sprite: Sprite3D in actor.find_children("*", "Sprite3D", true, false):
			sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			sprite.position.y -= bottom_padding
			sprite.set_meta("grounded_horizontal_billboard", true)
		actor.set_meta("grounded_horizontal_billboard", true)


func _repair_stairwell() -> void:
	# The old ceiling edge ended at x=-1.69, inside the upper banister's
	# silhouette. Widen the shaft to -1.48 and close every adjoining face.
	var east := -1.48
	_rebox("Ceiling_Main", Vector3(east, 2.75, -4.36), Vector3(3.36 - east, 0.14, 8.72))
	_rebox("Ceiling_FrontLeft", Vector3(-3.36, 2.75, 2.60), Vector3(east + 3.36, 0.14, 1.76))
	_rebox("Ceiling_RearLeft", Vector3(-3.36, 2.75, -4.36), Vector3(east + 3.36, 0.14, 1.78))
	_rebox("Ceiling_Stairwell", Vector3(-3.36, 5.15, -2.58), Vector3(east + 3.36, 0.14, 5.18))
	_rebox("Stairwell_UpperEast", Vector3(east - 0.16, 2.75, -2.58), Vector3(0.16, 2.4, 5.18))
	_rebox("Stairwell_UpperFront", Vector3(-3.36, 2.75, 2.60), Vector3(east + 3.36, 2.4, 0.16))
	_rebox("Stairwell_UpperRear", Vector3(-3.2, 2.75, -2.58), Vector3(east + 3.2, 2.4, 0.16))
	var trim := _plain(Color("8C9074"))
	_box(self, "StairOpeningFascia", Vector3(0.08, 0.10, 5.20), Vector3(east - 0.01, 2.75, 0.01), trim)
	set_meta("stairwell_opening_east_x", east)


func _rebox(node_name: String, corner: Vector3, size: Vector3) -> void:
	var node := Binding.find_node(_asset, node_name) as MeshInstance3D
	if node == null:
		return
	_disable_matching_collision(node.global_transform * node.get_aabb())
	var material := node.get_active_material(0)
	if material is StandardMaterial3D and node_name.begins_with("Ceiling_"):
		material = material.duplicate()
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE * 2.0
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = corner + size * 0.5
	node.rotation = Vector3.ZERO
	node.material_override = material
	_add_box_collision(node, Vector3.ZERO, size)


func _bind_fixture_lights() -> void:
	for prefix: String in ["Main", "Rear"]:
		var bulb := Binding.find_node(_asset, prefix + "_OpalGlobe") as MeshInstance3D
		var rose := Binding.find_node(_asset, prefix + "_CeilingRose") as Node3D
		var light := Binding.find_node(get_parent(), "Chapter%sLightAnchor" % prefix) as OmniLight3D
		if bulb == null or light == null:
			continue
		# Shrink about the ceiling attachment, preserving contact with the rose.
		var top := bulb.position.y + bulb.get_aabb().end.y
		bulb.scale = Vector3.ONE * 0.73
		bulb.position.y = top - bulb.get_aabb().end.y * 0.73
		if rose != null:
			rose.scale.x *= 0.73
			rose.scale.z *= 0.73
		var material := _plain(Color("D0DBC2"))
		material.emission_enabled = true
		material.emission = Color("D4E7BE")
		material.emission_energy_multiplier = 1.1
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bulb.material_override = material
		# A globe containing its own light must not cast a solid opaque shadow
		# around that light. Room geometry continues to cast normal shadows.
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_bulb_materials.append(material)
		light.reparent(bulb, false)
		light.position = bulb.get_aabb().get_center() - Vector3(0, 0.065, 0)
		light.light_color = Color("D3E4BE")
		light.light_energy = 0.66 if prefix == "Main" else 0.48
		light.omni_range = 6.0 if prefix == "Main" else 4.7
		light.omni_attenuation = 0.8
		light.light_specular = 0.15
		light.light_size = 0.12
		light.shadow_enabled = true
		light.set_meta("fixture_bound", true)
		light.set_meta("base_energy", light.light_energy)
		_lights.append(light)
	var crt := Binding.find_node(get_parent(), "ChapterCRTGreenGlow") as OmniLight3D
	if crt != null:
		crt.light_energy = 0.47
		crt.omni_range = 2.65
		crt.omni_attenuation = 1.2


func _apply_light_state(on: bool) -> void:
	_lights_on = on
	for light in _lights:
		light.visible = on
	for material in _bulb_materials:
		material.emission_energy_multiplier = 1.1 if on else 0.0
		material.albedo_color = Color("D0DBC2") if on else Color("343A2D")
	if _switch_rocker != null:
		_switch_rocker.rotation.z = -0.16 if on else 0.16
	if _switch != null:
		_switch.set_meta("lights_on", on)


func _build_switch(token: int) -> void:
	var model := Binding.find_node(_asset, "Prop_LightSwitch") as Node3D
	_switch = Area3D.new()
	_switch.name = "BasementLightSwitch"
	_switch.collision_layer = 2
	_switch.collision_mask = 0
	_switch.set_meta("actor_id", "chapter1_light_switch")
	_switch.set_meta("actor_type", "chapter1_light_switch")
	_switch.set_meta("display_name", "灯开关")
	_switch.set_meta("round_token", token)
	_switch.set_meta("interaction_radius", 1.5)
	_switch.set_meta("chapter1", true)
	add_child(_switch)
	_switch.global_position = model.global_position
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.12, 0.23, 0.20)
	shape.shape = box
	_switch.add_child(shape)
	# Tiny photoluminescent indicator remains visible during the authored outage.
	var indicator := _plain(Color("72945A"))
	indicator.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_box(self, "SwitchLocator", Vector3(0.008, 0.011, 0.030), Vector3(-3.151, 1.06, 3.16), indicator)
	for candidate: Node3D in model.find_children("*", "Node3D", true, false):
		if "Rocker" in str(candidate.name):
			_switch_rocker = candidate
			break


func _apply_surface_materials() -> void:
	var wall := _surface_material("aged_wall", 0.65, 0.22)
	var carpet := _surface_material("woven_carpet", 5.0, 0.85)
	for mesh: MeshInstance3D in _asset.find_children("*", "MeshInstance3D", true, false):
		var node_name := str(mesh.name)
		if node_name.begins_with("Wall_") or node_name.begins_with("Stairwell_") or node_name == "NPC_Partition":
			mesh.material_override = wall
		elif "Carpet" in node_name or node_name == "Room_Floor" or node_name == "Stair_UpperLanding":
			mesh.material_override = carpet
	var decal := StandardMaterial3D.new()
	decal.albedo_texture = _texture("damp_crack_decal")
	decal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	decal.cull_mode = BaseMaterial3D.CULL_DISABLED
	decal.roughness = 1.0
	# Separate, non-repeating wall wear: damp corners, wallpaper peel/cracks.
	for data: Array in [
		[Vector3(2.25, 1.6, 4.188), Vector2(1.65, 1.8), PI],
		[Vector3(-0.25, 0.95, -2.408), Vector2(1.4, 1.7), 0.0],
		[Vector3(3.188, 1.28, 1.15), Vector2(1.6, 2.2), -PI * 0.5],
		[Vector3(-2.6, 1.3, -4.188), Vector2(1.1, 2.0), 0.0],
	]:
		var patch := MeshInstance3D.new()
		patch.name = "WallDampCrack"
		var quad := QuadMesh.new()
		quad.size = data[1]
		patch.mesh = quad
		patch.material_override = decal
		patch.position = data[0]
		patch.rotation.y = data[2]
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(patch)


func _surface_material(prefix: String, density: float, relief: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = _texture(prefix + "_albedo")
	material.normal_enabled = true
	material.normal_texture = _texture(prefix + "_normal")
	material.normal_scale = relief
	material.roughness_texture = _texture(prefix + "_roughness")
	material.roughness = 1.0
	# Metric triplanar coordinates keep the wall/floor texel density consistent
	# across differently sized exported boxes without stretched UV islands.
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * density
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return material


func _dress_furniture() -> void:
	var table := Binding.find_node(_asset, "Prop_ChildTable") as Node3D
	if table == null:
		return
	_disable_prop_collision(Vector3(-0.78, 0.285, 0.10))
	_disable_prop_collision(Vector3(-0.73, 0.34, -0.61))
	var stool := Binding.find_node(_asset, "Prop_TealChair") as Node3D
	if stool != null:
		stool.hide()
		table.set_meta("retired_child_stool_hidden", true)
	table.rotation = Vector3.ZERO
	var box := _combined_bounds(table)
	table.scale = Vector3(0.88 / box.size.x, 0.79 / box.size.y, 1.56 / box.size.z)
	table.position = Vector3(-1.18, 0, 0.02)
	_add_box_collision(self, Vector3(-1.18, 0.395, 0.02), Vector3(0.88, 0.79, 1.56))
	for data: Array in [
		["Prop_Windsor_A", Vector3(-0.85, 0.54, -1.96), Vector3(-0.27, 0, 0.47), -1.38],
		["Prop_Windsor_B", Vector3(0.03, 0.54, -1.96), Vector3(-0.34, 0, -0.65), -1.75],
	]:
		var chair := Binding.find_node(_asset, data[0]) as Node3D
		if chair == null:
			continue
		_disable_prop_collision(data[1])
		chair.position = data[2]
		chair.rotation.y = data[3]
		_add_box_collision(chair, Vector3(0, 0.5, 0), Vector3(0.49, 1.0, 0.50))
	var paper := _plain(Color("B4AF89"))
	var brown := _plain(Color("3D3024"))
	_book("TableNotebook", Vector3(-1.12, 0.82, 0.28), 0.22, Color("534638"))
	_book("TableLedger", Vector3(-1.29, 0.82, -0.38), -0.18, Color("354B3D"))
	_box(self, "TableLoosePaper", Vector3(0.25, 0.002, 0.18), Vector3(-1.08, 0.794, -0.06), paper).rotation.y = 0.31
	_cylinder(self, "TableCup", 0.045, 0.064, 0.09, Vector3(-1.4, 0.836, 0.51), _plain(Color("B4B19A")))
	_box(self, "TablePencil", Vector3(0.008, 0.008, 0.16), Vector3(-0.89, 0.8, 0.12), brown).rotation.y = -0.3
	_stack_boxes()


func _stack_boxes() -> void:
	var template := Binding.find_node(_asset, "Prop_Box_Rear") as Node3D
	if template == null:
		return
	# Stable settled poses, with small yaw changes and supported upper boxes.
	# These are deliberately static after placement so saves never reshuffle them.
	var poses := [
		[Vector3(-1.08, 0.015, -1.97), Vector3(0.85, 0.85, 0.85), -0.12],
		[Vector3(-0.57, 0.015, -2.02), Vector3(0.72, 0.65, 0.8), 0.15],
		[Vector3(-0.94, 0.36, -1.99), Vector3(0.66, 0.6, 0.7), 0.08],
		[Vector3(0.63, 0.015, -3.91), Vector3(0.72, 0.85, 0.75), 0.17],
		[Vector3(1.05, 0.42, -3.85), Vector3(0.72, 0.6, 0.65), -0.18],
	]
	for i in poses.size():
		var copy := template.duplicate() as Node3D
		copy.name = "SettledStorageBox%02d" % i
		add_child(copy)
		copy.position = poses[i][0]
		copy.scale = poses[i][1]
		copy.rotation.y = poses[i][2]
		var bounds := _combined_bounds(copy)
		# Place bottom boxes exactly on carpet; upper boxes get their measured
		# support height below instead of looking suspended above the stack.
		if i in [0, 1, 3]:
			copy.position.y -= bounds.position.y - 0.015
		elif i == 2:
			var support := get_node("SettledStorageBox00") as Node3D
			copy.position.y += _combined_bounds(support).end.y - bounds.position.y
		elif i == 4:
			copy.position.y += _combined_bounds(template).end.y - bounds.position.y
		bounds = _combined_bounds(copy)
		_add_box_collision(self, to_local(bounds.get_center()), bounds.size)
	_book("CornerLooseBook", Vector3(-1.35, 0.035, -1.8), -0.6, Color("66523E"))
	_cylinder(self, "CornerPaintTin", 0.075, 0.075, 0.17, Vector3(-1.35, 0.095, -2.23), _plain(Color("818675")))


func _dress_exit_table(decoration_seed: int) -> void:
	# Random between runs, stable within a visit and after continuing a save.
	var rng := RandomNumberGenerator.new()
	rng.seed = decoration_seed + _round * 7919
	var vase_visit := rng.randi_range(0, 1) == 0
	set_meta("exit_table_prop", "vase" if vase_visit else "book")
	if vase_visit:
		var ceramic := _plain(Color("89937A"))
		_cylinder(self, "ExitTableVaseBelly", 0.10, 0.075, 0.18, Vector3(-1.62, 0.83, -3.9), ceramic)
		_cylinder(self, "ExitTableVaseNeck", 0.039, 0.085, 0.11, Vector3(-1.62, 0.975, -3.9), ceramic)
	else:
		_book("ExitTableBook", Vector3(-1.65, 0.766, -3.9), 0.14, Color("554030"))


func _build_clocks() -> void:
	if _round == CLOCK_WALL_VISIT:
		for row in 3:
			for col in 6:
				_clock(Vector3(-0.3 + col * 0.53, 1.10 + row * 0.54, 4.166), 0.44, (row * 7 + col) * 0.42, false)
	else:
		_clock(Vector3(1.63, 2.05, 4.16), 0.62, -0.72, _round == BROKEN_CLOCK_VISIT)


func _clock(at: Vector3, diameter: float, phase: float, broken: bool) -> void:
	var holder := Node3D.new()
	holder.name = "BrokenXRayClock" if broken else "WallClock"
	add_child(holder)
	holder.position = at
	holder.rotation.y = PI
	var scale_factor := diameter / 0.62
	holder.scale = Vector3.ONE * scale_factor
	var frame := _plain(Color("363A2F"))
	var face := _plain(Color("B7B597"))
	if broken:
		# A real half mesh, not a dark patch painted over a complete clock.
		_half_clock(holder, "BrokenFrame", 0.32, 0.075, frame)
		_half_clock(holder, "BrokenFace", 0.287, 0.087, face)
	else:
		var rim := _cylinder(holder, "ClockRim", 0.32, 0.32, 0.075, Vector3.ZERO, frame)
		rim.rotation.x = PI * 0.5
		var dial := _cylinder(holder, "ClockDial", 0.287, 0.287, 0.01, Vector3(0, 0, 0.043), face)
		dial.rotation.x = PI * 0.5
	for number in range(1, 13):
		var angle := float(number) * TAU / 12.0
		if broken and number in range(1, 6):
			_handwritten_digit(holder, number, Vector3(sin(angle) * 0.228 + 0.055, cos(angle) * 0.228, -0.002))
			continue
		var digit := Label3D.new()
		digit.name = "Numeral%d" % number
		digit.text = str(number)
		digit.font_size = 48
		digit.pixel_size = 0.00125
		digit.outline_size = 0
		digit.modulate = Color("272B24")
		digit.no_depth_test = false
		digit.position = Vector3(sin(angle) * 0.228, cos(angle) * 0.228, 0.052)
		digit.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		digit.shaded = true
		holder.add_child(digit)
	var ink := _plain(Color("20271F"))
	for data: Array in [[0.12, -0.9 + phase, "Hour"], [0.21, 0.2 + phase, "Minute"], [0.24, 1.7 + phase, "Second"]]:
		var pivot := Node3D.new()
		pivot.name = data[2] + "Hand"
		pivot.position.z = 0.061
		pivot.rotation.z = data[1]
		holder.add_child(pivot)
		_box(pivot, "Needle", Vector3(0.009 if data[2] == "Second" else 0.015, data[0], 0.005), Vector3(0, data[0] * 0.5, 0), ink)
		if data[2] == "Second":
			pivot.set_meta("initial_angle", data[1])
			_clock_hands.append(pivot)


func _handwritten_digit(parent: Node3D, number: int, at: Vector3) -> void:
	# Original marker strokes rather than a clean typeset face: missing numerals
	# live on the wall and use only the same X-ray render layer as exit clues.
	var paths := {
		1: [Vector2(-0.3, 0.25), Vector2(0.1, 0.5), Vector2(0.05, -0.5)],
		2: [Vector2(-0.35, 0.26), Vector2(-0.2, 0.5), Vector2(0.21, 0.43), Vector2(0.32, 0.14), Vector2(-0.3, -0.43), Vector2(0.33, -0.49)],
		3: [Vector2(-0.35, 0.45), Vector2(0.28, 0.48), Vector2(-0.03, 0.03), Vector2(0.30, -0.14), Vector2(0.17, -0.46), Vector2(-0.34, -0.49)],
		4: [Vector2(0.16, 0.49), Vector2(-0.31, -0.12), Vector2(0.34, -0.07), Vector2(0.19, -0.04), Vector2(0.16, 0.18), Vector2(0.12, -0.51)],
		5: [Vector2(0.32, 0.49), Vector2(-0.28, 0.46), Vector2(-0.32, 0.05), Vector2(0.24, 0.03), Vector2(0.33, -0.26), Vector2(0.07, -0.48), Vector2(-0.33, -0.39)],
	}
	var holder := Node3D.new()
	holder.name = "XRayHandwritten%d" % number
	holder.position = at
	holder.rotation.z = sin(float(number) * 4.1) * 0.13
	holder.set_meta("xray_only", true)
	parent.add_child(holder)
	var ink := _plain(Color("CBD2A6"))
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var points: Array = paths[number]
	for i in points.size() - 1:
		var from: Vector2 = points[i] * 0.063
		var to: Vector2 = points[i + 1] * 0.063
		var segment := _box(holder, "MarkerStroke", Vector3(0.0055, from.distance_to(to) + 0.002, 0.001), Vector3((from.x + to.x) * 0.5, (from.y + to.y) * 0.5, 0), ink)
		segment.rotation.z = (to - from).angle() - PI * 0.5
		segment.layers = XRAY_LAYER
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		segment.gi_mode = GeometryInstance3D.GI_MODE_DISABLED


func _half_clock(parent: Node3D, node_name: String, radius: float, depth: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Vertical jagged break at x=0; left half retains 6 through 12.
	for i in 24:
		var a := PI * float(i) / 24.0
		var b := PI * float(i + 1) / 24.0
		surface.add_vertex(Vector3(0, 0, depth * 0.5))
		surface.add_vertex(Vector3(-sin(a) * radius, cos(a) * radius, depth * 0.5))
		surface.add_vertex(Vector3(-sin(b) * radius, cos(b) * radius, depth * 0.5))
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = surface.commit()
	var two_sided := material.duplicate() as StandardMaterial3D
	two_sided.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = two_sided
	parent.add_child(mesh)


func _book(node_name: String, at: Vector3, yaw: float, color: Color) -> void:
	var holder := Node3D.new()
	holder.name = node_name
	add_child(holder)
	holder.position = at
	holder.rotation.y = yaw
	var cover := _plain(color)
	_box(holder, "Pages", Vector3(0.22, 0.027, 0.30), Vector3.ZERO, _plain(Color("AFA789")))
	for y: float in [-0.017, 0.017]:
		_box(holder, "Cover", Vector3(0.23, 0.007, 0.31), Vector3(0, y, 0), cover)
	_box(holder, "Spine", Vector3(0.01, 0.034, 0.31), Vector3(-0.112, 0, 0), cover)


func _disable_prop_collision(local_center: Vector3) -> void:
	for shape: CollisionShape3D in _asset.find_children("*", "CollisionShape3D", true, false):
		var box := _shape_bounds(shape)
		if box.get_center().distance_to(_asset.to_global(local_center)) < 0.10:
			shape.disabled = true


func _disable_matching_collision(target: AABB) -> void:
	for shape: CollisionShape3D in _asset.find_children("*", "CollisionShape3D", true, false):
		var box := _shape_bounds(shape)
		if box.position.distance_to(target.position) < 0.02 and box.size.distance_to(target.size) < 0.02:
			shape.disabled = true


func _shape_bounds(collider: CollisionShape3D) -> AABB:
	var box := AABB()
	if collider.shape is ConcavePolygonShape3D:
		var points := (collider.shape as ConcavePolygonShape3D).get_faces()
		if points.is_empty():
			return box
		box = AABB(points[0], Vector3.ZERO)
		for point in points:
			box = box.expand(point)
	elif collider.shape is BoxShape3D:
		var size := (collider.shape as BoxShape3D).size
		box = AABB(-size * 0.5, size)
	return collider.global_transform * box


func _combined_bounds(node: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func _add_box_collision(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "DressingCollision"
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)


func _texture(texture_name: String) -> Texture2D:
	if not _textures.has(texture_name):
		var path := TEXTURE_DIR + texture_name + ".png"
		if ResourceLoader.exists(path):
			_textures[texture_name] = load(path) as Texture2D
		else:
			# Also support authoring runs before the first editor asset import.
			var image := Image.load_from_file(path)
			image.generate_mipmaps()
			_textures[texture_name] = ImageTexture.create_from_image(image)
	return _textures[texture_name]


func _plain(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.87
	return material


func _box(parent: Node3D, node_name: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh


func _cylinder(parent: Node3D, node_name: String, top: float, bottom: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top
	cylinder.bottom_radius = bottom
	cylinder.height = height
	cylinder.radial_segments = 32
	cylinder.rings = 1
	mesh.mesh = cylinder
	mesh.position = at
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh
