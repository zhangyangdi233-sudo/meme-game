extends SceneTree
## #128: the basement is the v3b model as the planner made it. Its own materials show untouched, its Blender preview
## lamps do not blow the room out, the clutter is cut down to the tables, two chairs and the phone, the door under the
## landing is the model's taped door (it still holds the player out), and only round five has some of its tape torn off.

const RealitySceneAdapterScript = preload("res://scripts/world/reality_scene_adapter.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RoomContentScript = preload("res://scripts/game/room_content.gd")
const RoomRulesScript = preload("res://scripts/game/room_rules.gd")

## The surfaces the v3b model retextured: walls, ceilings, the floor's carpet and the stairwell.
const RETEXTURED_PREFIXES := ["Wall_", "Ceiling_", "Room_Floor", "Stairwell_"]
## A Godot light this strong is the Blender preview's physical watts read as Godot energy: the room turns white.
const MAX_SANE_ENERGY := 3.0

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, GameEventBusScript.new())
	await _test_the_model_shows_its_own_materials()
	await _test_no_lamp_carries_the_preview_watts()
	await _test_the_clutter_is_cut_to_the_tables_two_chairs_and_the_phone()
	await _test_the_sealed_door_is_the_models_taped_door()
	await _test_only_round_five_has_its_tape_torn()
	RegistryScript.clear()
	if _failures.is_empty():
		print("basement v3b model tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_the_model_shows_its_own_materials() -> void:
	var adapter = await _adapter(1)
	var model := _stage(adapter).find_child("BasementRoom", false, false) as Node3D
	_assert_true(model != null and model.find_child("AssetVersion_v3b", true, false) != null, "the basement should be the v3b model")
	var checked := 0
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not _retextured(mesh.name):
			continue
		checked += 1
		_assert_true(mesh.material_override == null and mesh.get_surface_override_material(0) == null, "%s should keep the model's material" % mesh.name)
		var material := mesh.get_active_material(0) as BaseMaterial3D
		_assert_true(material != null and material.resource_name.begins_with("V3B_"), "%s should wear a v3b material: %s" % [mesh.name, material.resource_name if material else "none"])
		_assert_true(material != null and material.normal_enabled and material.normal_texture != null, "%s should keep its baked normal map" % mesh.name)
	_assert_true(checked >= 10, "the walls, ceilings, floor and stairwell should all be checked: %d" % checked)
	# The model still carries the arrows of an older X-ray tutorial, marked hidden from the normal view.
	for node: Node in model.find_children("*", "Node3D", true, false):
		var extras: Variant = node.get_meta("extras", {})
		if extras is Dictionary and bool((extras as Dictionary).get("normal_view_hidden", false)):
			_assert_true(not (node as Node3D).is_visible_in_tree(), "%s should not show in the normal view" % node.name)
	for index in range(1, 4):
		var arrow := model.find_child("XRAY_EXIT_GUIDE_0%d*" % index, true, false) as Node3D
		_assert_true(arrow == null or not arrow.is_visible_in_tree(), "the old X-ray arrow %d should not show" % index)
	await _free(adapter)


func _test_no_lamp_carries_the_preview_watts() -> void:
	for round_number in range(1, ProgressScript.BASEMENT_ROUND_COUNT + 1):
		var adapter = await _adapter(round_number)
		var stage := _stage(adapter)
		var lit := 0
		for light: Light3D in stage.find_children("*", "Light3D", true, false):
			if not light.is_visible_in_tree():
				continue
			lit += 1
			_assert_true(light.light_energy <= MAX_SANE_ENERGY, "round %d's %s should not carry the preview's watts: %s" % [round_number, light.name, light.light_energy])
		_assert_true(lit >= 2, "round %d should still be lit" % round_number)
		var crt := stage.find_child("CRT_Green_PointLight", true, false) as OmniLight3D
		_assert_true(crt != null and crt.visible and crt.omni_range < 10.0, "the CRT's green light should stay, at the room's scale")
		await _free(adapter)


func _test_the_clutter_is_cut_to_the_tables_two_chairs_and_the_phone() -> void:
	for round_number in range(1, ProgressScript.BASEMENT_ROUND_COUNT + 1):
		var adapter = await _adapter(round_number)
		var stage := _stage(adapter)
		for kept: String in ["Prop_Windsor_A", "Prop_Windsor_B", "Prop_ChildTable", "Prop_RearSideTable", "BasementTable", "Prop_CRT_TV"]:
			var node := stage.find_child(kept, true, false) as Node3D
			# Round three's light coming back swaps the two chairs for their pile; nothing else hides them.
			_assert_true(node != null and node.is_visible_in_tree(), "round %d should keep %s" % [round_number, kept])
		for cut: String in ["Prop_TealChair", "Prop_Box_Rear", "Prop_Box_UnderStairs"]:
			var node := stage.find_child(cut, true, false) as Node3D
			_assert_true(node == null or not node.is_visible_in_tree(), "round %d should leave out %s" % [round_number, cut])
		var stool_body := stage.find_child("PropCollision_TealChair", true, false) as CollisionObject3D
		_assert_true(stool_body == null or stool_body.collision_layer == 0, "the stool left out should not block the floor")
		_assert_eq(adapter.chapter_exit_reaches("chair").size(), 2, "round %d should count the two chairs" % round_number)
		await _free(adapter)
	var first = await _adapter(1)
	_assert_true(_stage(first).find_child("BasementPhone", true, false) != null, "the phone should still lie on its table")
	await _free(first)


func _test_the_sealed_door_is_the_models_taped_door() -> void:
	for round_number: int in [1, 2, 4]:
		var adapter = await _adapter(round_number)
		var stage := _stage(adapter)
		for part: String in ["StairCloset_Door", "StairCloset_Knob", "StairCloset_Tape"]:
			var node := stage.find_child(part, true, false) as Node3D
			_assert_true(node != null and node.is_visible_in_tree(), "round %d's sealed door should show the model's %s" % [round_number, part])
		_assert_true(stage.find_child("ClosetFront", true, false) == null, "the boxes standing in for the door should be gone")
		await physics_frame
		await physics_frame
		var space := stage.get_world_3d().direct_space_state
		for height: float in [0.3, 1.0, 1.8]:
			var query := PhysicsRayQueryParameters3D.create(Vector3(-1.0, height, -2.0), Vector3(-2.6, height, -2.0))
			var hit := space.intersect_ray(query)
			_assert_true(not hit.is_empty() and (hit["position"] as Vector3).x > -1.95, "the taped door should hold the player out at %.1f m in round %d: %s" % [height, round_number, hit])
		if round_number != 1:
			var npc: Vector3 = adapter.chapter_npc_position()
			adapter.player.position = Vector3(npc.x + 0.35, 0.05, npc.z + 0.5)
			adapter.refresh_nearby_actor(_deps(round_number))
			_assert_eq(str(adapter.nearby_outcome().get("action")), "converse", "round %d's door should still let the player talk through it" % round_number)
		await _free(adapter)


func _test_only_round_five_has_its_tape_torn() -> void:
	var intact_triangles := 0
	for round_number in range(1, ProgressScript.BASEMENT_ROUND_COUNT + 1):
		var adapter = await _adapter(round_number)
		var stage := _stage(adapter)
		var tape := stage.find_child("StairCloset_Tape", true, false) as MeshInstance3D
		var torn := stage.find_child("TornTape", true, false) as Node3D
		_assert_true(torn != null, "round %d should have the torn tape ready" % round_number)
		if round_number < 5:
			_assert_true(tape.is_visible_in_tree() and not torn.is_visible_in_tree(), "round %d's tape should be whole" % round_number)
			intact_triangles = _triangles(tape)
			await _free(adapter)
			continue
		_assert_true(not tape.is_visible_in_tree() and torn.is_visible_in_tree(), "round five's tape should be torn")
		var left := torn.find_child("Remaining", true, false) as MeshInstance3D
		_assert_true(left != null and _triangles(left) > 0 and _triangles(left) < intact_triangles, "some strips should be gone: %d of %d" % [_triangles(left) if left else 0, intact_triangles])
		var peeled := torn.find_children("Peeled*", "MeshInstance3D", true, false)
		_assert_true(peeled.size() >= 2, "a few torn strips should hang off the door: %d" % peeled.size())
		await _free(adapter)


func _triangles(mesh_instance: MeshInstance3D) -> int:
	var count := 0
	for surface in mesh_instance.mesh.get_surface_count():
		var arrays := mesh_instance.mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		count += (indices.size() if not indices.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return count


func _retextured(node_name: String) -> bool:
	if node_name.ends_with("-colonly") or node_name.contains("colonly"):
		return false
	for prefix: String in RETEXTURED_PREFIXES:
		if node_name.begins_with(prefix):
			return true
	return false


func _stage(adapter) -> Node3D:
	return adapter.get_parent().find_child("ChapterOneStage", true, false) as Node3D


func _adapter(round_number: int):
	var deps := _deps(round_number)
	var host := Node3D.new()
	host.name = "ChapterStageHost"
	root.add_child(host)
	var adapter = RealitySceneAdapterScript.new()
	adapter.attach_to(host)
	adapter.build_world_nodes()
	adapter.rebuild_floor(deps)
	adapter.ensure_floor_current(deps)
	await process_frame
	return adapter


func _deps(round_number: int) -> Dictionary:
	var progress := ProgressScript.jump_to_round(ProgressScript.initial(), round_number)
	var room := RoomContentScript.room(round_number)
	return {
		"day_progress": {"tower_floor": 1, "day": 1},
		"chapter_one_progress": progress,
		"view_state": "npc_up",
		"room_state": RoomRulesScript.world_state(room, {}, round_number),
		"basement_npc_stands": RoomRulesScript.stands_npc(room),
		"phone_owned": round_number > 1,
	}


func _free(adapter) -> void:
	adapter.get_parent().queue_free()
	await process_frame


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
