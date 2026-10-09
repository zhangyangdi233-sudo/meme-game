extends SceneTree

const Atmosphere = preload("res://scripts/world/basement_atmosphere.gd")
const Generator = preload("res://scripts/reality_floor_generator.gd")
const Binding = preload("res://scripts/world/chapter_asset_binding.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_grounded_portrait()
	for round_index in 5:
		var host := Node3D.new()
		root.add_child(host)
		var asset: Node3D = load("res://assets/chapter1/Basement_Loop_v2.glb").instantiate()
		host.add_child(asset)
		for prefix in ["Main", "Rear"]:
			var light := OmniLight3D.new()
			light.name = "Chapter%sLightAnchor" % prefix
			host.add_child(light)
		var crt := OmniLight3D.new()
		crt.name = "ChapterCRTGreenGlow"
		host.add_child(crt)
		var atmosphere := Atmosphere.new()
		host.add_child(atmosphere)
		atmosphere.configure(asset, {}, {"round_index": round_index, "transition_serial": round_index + 1, "decoration_seed": 1701})
		_check(atmosphere.interaction_actor() != null, "wall switch exposes interaction in visit %d" % round_index)
		for prefix in ["Main", "Rear"]:
			var light := host.find_child("Chapter%sLightAnchor" % prefix, true, false) as OmniLight3D
			_check(str(light.get_parent().name) == prefix + "_OpalGlobe", "light is a child of the visible globe")
			var bulb := light.get_parent() as MeshInstance3D
			_check(bulb.get_aabb().has_point(light.position), "actual source remains inside the reduced bulb")
			_check(bulb.scale.x < 0.8 and light.light_energy < 0.8, "fixture and intensity reduced")
			_check((bulb.material_override as StandardMaterial3D).emission_enabled, "visible globe emits its own light")
		_check(is_equal_approx(crt.light_energy, 0.47), "CRT local spill increased independently")
		var ceiling := Binding.find_node(asset, "Ceiling_Main") as MeshInstance3D
		_check(is_equal_approx((ceiling.transform * ceiling.get_aabb()).position.x, -1.48), "ceiling opening clears upper handrail")
		var stool := Binding.find_node(asset, "Prop_TealChair") as Node3D
		_check(not stool.visible, "small child chair retired")
		var table := Binding.find_node(asset, "Prop_ChildTable") as Node3D
		_check(table.position.x < -1.0, "table moved alongside staircase")
		_check(atmosphere.find_children("SettledStorageBox*", "Node3D", true, false).size() == 5, "five additional supported storage boxes")
		for mesh: MeshInstance3D in asset.find_children("*", "MeshInstance3D", true, false):
			if str(mesh.name) == "Room_Floor" or str(mesh.name) == "Wall_Front":
				var mat := mesh.material_override as StandardMaterial3D
				_check(mat != null and mat.normal_enabled and mat.normal_texture != null and mat.uv1_world_triplanar, "wall/carpet have consistent-scale maps and surface relief")
		atmosphere.toggle_lights()
		_check(not atmosphere.lights_are_on(), "switch turns actual fixture lights off")
		_check(crt.visible, "room switch preserves CRT power")
		atmosphere.toggle_lights()
		_check(atmosphere.lights_are_on(), "switch restores room lights")
		# User interaction intentionally cancels an anomaly; reset only for this
		# isolated visit simulation, then exercise timer boundaries below.
		atmosphere._anomaly_cancelled = false
		atmosphere.update_visit(100.0, false)
		_check(atmosphere.lights_are_on(), "anomalies cannot begin while player remains on entrance landing")
		if round_index == 1:
			var saw_dark := false
			var saw_light := false
			for frame in 68:
				atmosphere.update_visit(0.1, true)
				saw_dark = saw_dark or not atmosphere.lights_are_on()
				saw_light = saw_light or atmosphere.lights_are_on()
			_check(saw_dark and saw_light and atmosphere.lights_are_on(), "second visit flickers for a bounded period and recovers")
		elif round_index == 2:
			atmosphere.update_visit(3.1, true)
			_check(not atmosphere.lights_are_on(), "third visit switches off after arrival")
			atmosphere.update_visit(20.0, true)
			_check(not atmosphere.lights_are_on(), "outage persists until player uses wall switch")
			atmosphere.toggle_lights()
			atmosphere.update_visit(20.0, true)
			_check(atmosphere.lights_are_on(), "manual recovery does not immediately retrigger")
		elif round_index == 3:
			_check(atmosphere._clock_hands.size() == 18, "fourth visit has eighteen wall clocks")
		elif round_index == 4:
			var clues := atmosphere.find_children("XRayHandwritten*", "Node3D", true, false)
			_check(clues.size() == 5, "fifth visit has precisely five handwritten missing numerals")
			for clue in clues:
				for geometry: GeometryInstance3D in clue.find_children("*", "GeometryInstance3D", true, false):
					_check(geometry.layers == 1 << 19, "hidden numerals only use the X-ray layer")
		var decoration := str(atmosphere.get_meta("exit_table_prop"))
		_check(decoration in ["book", "vase"], "exit table chooses one prop")
		host.free()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("basement atmosphere tests passed")
	quit(0 if failures.is_empty() else 1)

func _test_grounded_portrait() -> void:
	var image := Image.create(100, 100, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(30, 5, 40, 75), Color.WHITE)
	var factory := Generator.new()
	var actor := factory._make_actor("TestNPC", "npc", "Test", Vector3.ZERO, ImageTexture.create_from_image(image), 0)
	var sprite := actor.get_node("Billboard") as Sprite3D
	var overlay := actor.get_node("FaceScribbleOverlay") as Sprite3D
	_check(sprite.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y, "close camera pitch cannot tilt standing NPC")
	var shoe_y := sprite.position.y - 0.5 * 100 * sprite.pixel_size + 20 * sprite.pixel_size
	_check(absf(shoe_y) < 0.001, "opaque shoe bottom rests on actor floor, not texture canvas bottom")
	_check(overlay.position == sprite.position and overlay.billboard == sprite.billboard, "face overlay stays registered after grounding")
	actor.free()
	factory.free()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
