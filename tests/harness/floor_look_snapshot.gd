extends RefCounted
## Builds a floor with every authored event and records every color it shows, so a test can
## compare what the player sees before and after a refactor. Colors are stored as [r, g, b, a].
## Grass blade colors are left out: the headless renderer answers every MultiMesh instance color black.

const FloorComposerScript = preload("res://scripts/game/floor_composer.gd")
const EVERY_EVENT := [
	{"id": "light_memory", "kind": "light_memory"},
	{"id": "dead_sign", "kind": "dead_sign"},
	{"id": "distant_mirage", "kind": "distant_mirage"},
	{"id": "cover_watcher", "kind": "cover_watcher"},
]


## Builds `floor_number` from the composer's day-2 floor with every event, blank portraits, the
## playtest markers on and every doll claimed.
static func build(floor_root: RealityFloorGenerator, floor_number: int, palette: Dictionary) -> void:
	var composed: Dictionary = FloorComposerScript.compose({"day_progress": {"tower_floor": floor_number, "day": 2}})
	var portrait := ImageTexture.create_from_image(Image.create(4, 8, false, Image.FORMAT_RGBA8))
	floor_root.set_playtest_assist_enabled(true)
	floor_root.rebuild(
		floor_number,
		palette,
		{"key_npc": portrait, "npcs": [portrait], "doll": portrait},
		2,
		false,
		composed.get("items", []),
		composed.get("people", []),
		composed.get("display_names", {}),
		EVERY_EVENT,
		composed.get("layout", {})
	)
	var doll_ids: Array[String] = []
	for actor in floor_root.get_interactable_actors():
		if str(actor.get_meta("actor_type", "")) == "doll":
			doll_ids.append(str(actor.get_meta("actor_id", "")))
	floor_root.sync_claimed_dolls(doll_ids)


static func capture(floor_root: RealityFloorGenerator) -> Dictionary:
	var environment := {}
	var world := floor_root.find_child("RealityWorldEnvironment", true, false) as WorldEnvironment
	if world != null and world.environment != null:
		environment = {
			"background": encode(world.environment.background_color),
			"ambient": encode(world.environment.ambient_light_color),
			"fog": encode(world.environment.fog_light_color),
		}
	var materials := {}
	var emissions := {}
	for node in floor_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var material := mesh_instance.material_override as StandardMaterial3D
		if material == null or not mesh_instance.has_meta("theme_role"):
			continue
		var role := str(mesh_instance.get_meta("theme_role"))
		_record(materials, role, encode(material.albedo_color))
		if material.emission_enabled:
			_record(emissions, role, encode(material.emission))
	var lights := {}
	for node in floor_root.find_children("*", "Light3D", true, false):
		lights[str(floor_root.get_path_to(node))] = encode((node as Light3D).light_color)
	var tints := {}
	for node in floor_root.find_children("*", "SpriteBase3D", true, false):
		tints[str(floor_root.get_path_to(node))] = encode((node as SpriteBase3D).modulate)
	for node in floor_root.find_children("*", "Label3D", true, false):
		var label := node as Label3D
		tints[str(floor_root.get_path_to(label))] = encode(label.modulate)
		tints["%s:outline" % floor_root.get_path_to(label)] = encode(label.outline_modulate)
	for node in floor_root.find_children("*", "GeometryInstance3D", true, false):
		var shader_material := (node as GeometryInstance3D).material_override as ShaderMaterial
		if shader_material != null and shader_material.get_shader_parameter("ink_color") != null:
			tints["%s:ink" % floor_root.get_path_to(node)] = encode(shader_material.get_shader_parameter("ink_color"))
	return {
		"environment": environment,
		"materials": materials,
		"emissions": emissions,
		"lights": lights,
		"tints": tints,
	}


static func encode(color: Color) -> Array:
	return [color.r, color.g, color.b, color.a]


## One role painted two colors on the same floor is recorded as "mixed" so a comparison catches it.
static func _record(table: Dictionary, role: String, color: Array) -> void:
	if table.has(role) and table[role] != color:
		table[role] = "mixed"
	elif not table.has(role):
		table[role] = color


## Turns every [r, g, b, a] back into a Color, so a capture compares with one read from JSON
## (JSON keeps fewer digits than a float, the Color conversion rounds both to the same color).
static func decode(value: Variant) -> Variant:
	if value is Array and value.size() == 4 and (value as Array).all(func(part): return part is float or part is int):
		return Color(value[0], value[1], value[2], value[3])
	if value is Dictionary:
		var decoded := {}
		for key in value:
			decoded[key] = decode(value[key])
		return decoded
	return value
