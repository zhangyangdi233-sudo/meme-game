extends SceneTree

const RealityFloorGeneratorScript = preload("res://scripts/reality_floor_generator.gd")
const FloorComposerScript = preload("res://scripts/game/floor_composer.gd")
const MemeGameStateScript = preload("res://scripts/meme_game_state.gd")
const LanguageCorruptionContentScript = preload("res://scripts/narrative/language_corruption_content.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var palette := {
		"bg": "B7D957", "surface": "FFF1C9", "ink": "10140F",
		"accent": "365B2D", "muted": "DDEB8A", "flash_text": "9CFF24",
	}
	var texture := load("res://assets/generated/characters/npc_late_arrival.png") as Texture2D
	var doll_texture := load("res://assets/generated/characters/guide_doll.png") as Texture2D
	_assert_true(doll_texture != null, "the user's guide doll artwork should import as a Godot texture")
	for floor_number in [1, 2, 3]:
		var state := MemeGameStateScript.new()
		state.new_run()
		state.tower_floor = floor_number
		var item: Dictionary = state.get_prerequisite_item_for_floor(floor_number)
		var floor_root := RealityFloorGeneratorScript.new()
		root.add_child(floor_root)
		await process_frame
		var composed: Dictionary = FloorComposerScript.compose({"day_progress": {"tower_floor": floor_number}})
		floor_root.rebuild(floor_number, palette, {
			"key_npc": texture,
			"npcs": [texture],
			"doll": doll_texture,
		}, 1, false, composed.get("items", []), composed.get("people", []), composed.get("display_names", {}), [], composed.get("layout", {}))
		var key_npc := _find_actor(floor_root, "key_npc")
		_assert_true(key_npc != null, "floor %d should place one key NPC at the authored nearby test position" % floor_number)
		_assert_true(_find_actor(floor_root, "merchant") == null, "floor %d should contain no merchant actor" % floor_number)
		if key_npc != null:
			_assert_true(key_npc.position.distance_to(floor_root.start_position()) < 35.0, "floor %d key NPC should remain near the player for testing" % floor_number)
			_assert_true(floor_root.contains_playable_position(key_npc.position, 0.0), "floor %d key NPC must stand inside the playable area" % floor_number)
		var doll := _find_actor(floor_root, "doll")
		_assert_true(doll != null, "floor %d should hide one guide doll in the physical world" % floor_number)
		if doll != null:
			var encounter: Dictionary = LanguageCorruptionContentScript.get_doll_encounter_for_floor(floor_number)
			_assert_eq(str(doll.get_meta("actor_id", "")), str(encounter.get("doll_id", "")), "world doll should use the authored stable id")
			_assert_true(floor_root.contains_playable_position(doll.position, 0.0), "floor %d doll must be reachable" % floor_number)
			_assert_true(doll.get_node_or_null("Billboard") is Sprite3D, "the doll should use the user's camera-facing artwork")
			_assert_true(doll.get_node_or_null("FaceScribbleOverlay") == null, "the guide doll should keep its native stitched face instead of NPC scribbles")
			floor_root.sync_claimed_dolls([str(encounter.get("doll_id", ""))])
			_assert_true(bool(doll.get_meta("claimed", false)), "claimed state should survive a floor rebuild sync")
		var prerequisite := _find_prerequisite_item(floor_root)
		_assert_true(prerequisite != null, "floor %d should build exactly one authored prerequisite" % floor_number)
		if prerequisite != null:
			_assert_eq(str(prerequisite.get_meta("item_id", "")), str(item.get("id", "")), "world item should use the state-owned prerequisite ID")
			_assert_eq(str(prerequisite.get_meta("display_name", "")), str(item.get("label", "")), "world item should keep the catalog label for pickup")
			_assert_true(floor_root.contains_playable_position(prerequisite.position, 1.0), "floor %d prerequisite must be inside the traversable map" % floor_number)
			_assert_true(not prerequisite.visible, "the item should remain hidden before the key NPC clue")
			floor_root.sync_prerequisite_items([str(item.get("id", ""))], [])
			_assert_true(prerequisite.visible and prerequisite in floor_root.get_interactable_items(), "the clue should reveal the physical world item")
			floor_root.sync_prerequisite_items([str(item.get("id", ""))], [str(item.get("id", ""))])
			_assert_true(not prerequisite.visible, "a collected prerequisite should disappear permanently")
		floor_root.queue_free()
		await process_frame
	_assert_true(_failures.is_empty(), "key NPC world item assertions should pass")
	if _failures.is_empty():
		print("key NPC world item tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _find_actor(node: Node, actor_type: String) -> Area3D:
	if node is Area3D and str(node.get_meta("actor_type", "")) == actor_type:
		return node as Area3D
	for child in node.get_children():
		var found := _find_actor(child, actor_type)
		if found != null:
			return found
	return null


func _find_prerequisite_item(node: Node) -> Area3D:
	if node is Area3D and bool(node.get_meta("prerequisite_item", false)):
		return node as Area3D
	for child in node.get_children():
		var found := _find_prerequisite_item(child)
		if found != null:
			return found
	return null


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
