extends SceneTree
## RealitySceneAdapter floor tables and fake-floor approach / interaction outcomes.

const RealitySceneAdapterScript = preload("res://scripts/world/reality_scene_adapter.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("reality scene adapter tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_assert_eq(RealitySceneAdapterScript.room_count_for_floor(1), 4, "floor one should begin with four rooms")
	_assert_eq(RealitySceneAdapterScript.room_count_for_floor(2), 6, "floor two should add two rooms")
	_assert_eq(RealitySceneAdapterScript.room_count_for_floor(3), 9, "floor three should add three rooms")
	_assert_eq(RealitySceneAdapterScript.room_count_for_floor(4), 11, "hidden floor four should retain the final authored expansion")
	for floor_number in range(2, 5):
		var growth: int = RealitySceneAdapterScript.room_count_for_floor(floor_number) - RealitySceneAdapterScript.room_count_for_floor(floor_number - 1)
		_assert_true(growth == 2 or growth == 3, "each ascent should add two or three rooms")
	var expected_npc_counts := [4, 3, 2, 0]
	for floor_index in expected_npc_counts.size():
		var floor_number := floor_index + 1
		_assert_eq(
			RealitySceneAdapterScript.npc_count_for_floor(floor_number),
			expected_npc_counts[floor_index],
			"ordinary NPC population should follow the reduced floor sequence"
		)
		if floor_index > 0:
			_assert_true(expected_npc_counts[floor_index] < expected_npc_counts[floor_index - 1], "ordinary NPC population should strictly decrease on every ascent")
	_test_nearby_actor_returns_converse_outcome()
	_test_nearby_item_returns_collect_outcome()
	_test_far_actor_returns_none()
	_test_refresh_exposes_nearby_outcome()
	_test_look_delta_updates_pose()
	_test_rebuild_uses_intent_snapshot_not_live_game()
	_test_day_change_replaces_scenes_without_rebuilding_the_floor()
	_test_collect_item_by_id_clears_nearby_item()
	_test_face_actor_by_id_updates_pose()
	_test_collect_outcome_picks_up_without_opening_a_conversation()
	_test_accepted_conversation_faces_the_actor()
	_test_ending_conversation_restores_gaze_and_walking()
	_test_rejected_conversation_leaves_no_stuck_state()
	_test_rebuilding_the_floor_drops_a_conversation_without_restoring_old_gaze()
	_test_host_applies_interaction_outcomes_instead_of_orchestrating_them()
	_test_hiding_the_street_hides_characters_until_restored()
	_test_theme_palette_recolors_the_street()
	_test_host_does_not_paint_floor_nodes()
	_test_floor_three_door_follows_task_progress()
	_test_floor_four_exit_follows_task_progress()
	_test_other_floors_omit_ultimate_task_props()
	_test_host_asks_adapter_to_sync_ultimate_task_props()


func _test_nearby_actor_returns_converse_outcome() -> void:
	var setup := _make_adapter_with_fake_floor()
	var adapter = setup["adapter"]
	var fake: FakeFloor = setup["floor"]
	fake.add_actor("guide_doll", "doll", "缝合向导", Vector3(0.0, 0.0, 1.4))
	adapter.player.position = Vector3.ZERO
	var outcome: Dictionary = adapter.probe_interaction(_walk_deps())
	_assert_eq(str(outcome.get("action", "")), "converse", "approaching a fake-floor actor should probe converse")
	_assert_eq(str(outcome.get("actor_id", "")), "guide_doll", "converse outcome should identify the actor")
	_assert_eq(str(outcome.get("actor_type", "")), "doll", "converse outcome should include actor type")
	_assert_eq(str(outcome.get("actor_label", "")), "缝合向导", "converse outcome should include actor label")
	_assert_true(outcome.get("actor") == null, "converse outcome must not leak the live Area3D")
	setup["host"].free()


func _test_nearby_item_returns_collect_outcome() -> void:
	var setup := _make_adapter_with_fake_floor()
	var adapter = setup["adapter"]
	var fake: FakeFloor = setup["floor"]
	fake.add_item(
		"floor1_key",
		"荧光钥匙",
		Vector3(0.0, 0.0, 1.0),
		{"effect": "unlock", "value": 1, "description": "楼层前置物。"}
	)
	adapter.player.position = Vector3.ZERO
	var outcome: Dictionary = adapter.probe_interaction(_walk_deps())
	_assert_eq(str(outcome.get("action", "")), "collect", "approaching a fake-floor item should probe collect")
	var item_data: Dictionary = outcome.get("item_data", {})
	_assert_eq(str(item_data.get("id", "")), "floor1_key", "collect outcome should identify the item")
	_assert_eq(str(item_data.get("label", "")), "荧光钥匙", "collect outcome should include the item label")
	_assert_eq(str(item_data.get("description", "")), "楼层前置物。", "collect outcome should include the item description")
	_assert_true(outcome.get("item") == null, "collect outcome must not leak the live Area3D")
	setup["host"].free()


func _test_far_actor_returns_none() -> void:
	var setup := _make_adapter_with_fake_floor()
	var adapter = setup["adapter"]
	var fake: FakeFloor = setup["floor"]
	fake.add_actor("latecomer", "npc", "迟到者", Vector3(0.0, 0.0, 8.0))
	adapter.player.position = Vector3.ZERO
	var outcome: Dictionary = adapter.probe_interaction(_walk_deps())
	_assert_eq(str(outcome.get("action", "")), "none", "an actor outside interaction distance should not probe")
	setup["host"].free()


func _test_refresh_exposes_nearby_outcome() -> void:
	var setup := _make_adapter_with_fake_floor()
	var adapter = setup["adapter"]
	var fake: FakeFloor = setup["floor"]
	fake.add_actor("latecomer", "npc", "迟到者", Vector3(0.0, 0.0, 1.2))
	adapter.player.position = Vector3.ZERO
	adapter.refresh_nearby_actor(_walk_deps())
	var nearby: Dictionary = adapter.nearby_outcome()
	_assert_eq(str(nearby.get("kind", "")), "actor", "refresh should expose a nearby actor outcome")
	_assert_eq(str(nearby.get("actor_id", "")), "latecomer", "nearby outcome should identify the actor")
	_assert_eq(str(nearby.get("actor_label", "")), "迟到者", "nearby outcome should include the prompt label")
	_assert_true(nearby.get("actor") == null, "nearby outcome must not leak the live Area3D")
	setup["host"].free()


func _test_look_delta_updates_pose() -> void:
	var setup := _make_adapter_with_fake_floor()
	var adapter = setup["adapter"]
	adapter.apply_look_delta(Vector2(10.0, 5.0), 1.0)
	var look_pose: Dictionary = adapter.pose()
	_assert_true(is_equal_approx(float(look_pose.get("yaw", 0.0)), -10.0), "look delta should update pose yaw")
	_assert_true(is_equal_approx(float(look_pose.get("pitch", 0.0)), -5.0), "look delta should update pose pitch")
	_assert_true(look_pose.get("player_position") is Vector3, "pose should include player position")
	setup["host"].free()


func _test_rebuild_uses_intent_snapshot_not_live_game() -> void:
	var setup := _make_adapter_with_fake_floor()
	var adapter = setup["adapter"]
	var fake: FakeFloor = setup["floor"]
	adapter.rebuild_floor({
		"day_progress": {"tower_floor": 2, "day": 3},
		"palette": {"ink": Color.BLACK},
		"load_texture": func(_path: String) -> Texture2D: return null,
		"npc_character_paths": [],
		"guide_doll_path": "",
		"playtest_assist_enabled": false,
		"locale": "zh",
		"cover_watcher_seen": true,
		"collected_world_item_ids": ["floor1_key"],
		"revealed_prerequisite_item_ids": ["floor2_key"],
		"collected_prerequisite_item_ids": [],
		"claimed_doll_ids": ["guide_doll"],
	})
	_assert_eq(int(fake.last_rebuild.get("floor_number", 0)), 2, "rebuild should use tower_floor from day_progress")
	_assert_eq(int(fake.last_rebuild.get("day_number", 0)), 3, "rebuild should use day from day_progress")
	_assert_true(bool(fake.last_rebuild.get("cover_watcher_seen", false)), "rebuild should use cover_watcher_seen from the snapshot")
	var items: Array = fake.last_rebuild.get("items", [])
	_assert_eq(items.size(), 1, "rebuild should place the composer's item list")
	_assert_eq(str((items[0] as Dictionary).get("id", "")), "artifact_reversed_tape", "the item id should come from the composer, not the host")
	_assert_eq(str((items[0] as Dictionary).get("kind", "")), "prerequisite", "the placed item should be a prerequisite")
	var people: Array = fake.last_rebuild.get("people", [])
	_assert_eq(people.size(), 5, "rebuild should place the floor-two cast from the composer")
	_assert_eq(str((people[0] as Dictionary).get("id", "")), "key_npc_2_keynpc", "rebuild should forward the key resident id")
	_assert_eq(str((people[1] as Dictionary).get("kind", "")), "doll", "rebuild should forward the doll")
	var names: Dictionary = fake.last_rebuild.get("display_names", {})
	_assert_eq(str(names.get("key_npc_2_keynpc", "")), "两醒者", "display names should travel beside the roster")
	var textures: Dictionary = fake.last_rebuild.get("actor_textures", {})
	_assert_true(not textures.has("key_npc_label"), "names should not ride inside the texture bag")
	_assert_true(not textures.has("doll_encounter"), "the doll encounter should not ride inside the texture bag")
	_assert_eq(fake.last_sync_collected, ["floor1_key"] as Array[String], "rebuild should sync collected item ids from the snapshot")
	_assert_eq(fake.last_sync_dolls, ["guide_doll"] as Array[String], "rebuild should sync claimed doll ids from the snapshot")
	var events: Array = fake.last_rebuild.get("events", [])
	_assert_eq(events.size(), 1, "rebuild should place the composer's scene list")
	_assert_eq(str((events[0] as Dictionary).get("kind", "")), "dead_sign", "floor two day three should schedule only the dead sign")
	var layout: Dictionary = fake.last_rebuild.get("layout", {})
	_assert_eq(int(layout.get("room_count", 0)), 6, "rebuild should forward the floor-two room count")
	_assert_eq(str(layout.get("shape", "")), "irregular_disc", "rebuild should forward the floor-two shape")
	var map_size: Dictionary = layout.get("map_size", {})
	_assert_true(is_equal_approx(float(map_size.get("width", 0.0)), 252.0), "rebuild should forward the floor-two map width")
	_assert_true(is_equal_approx(float(map_size.get("length", 0.0)), 264.0), "rebuild should forward the floor-two map length")
	setup["host"].free()


func _test_day_change_replaces_scenes_without_rebuilding_the_floor() -> void:
	var setup := _make_adapter_with_fake_floor()
	var adapter = setup["adapter"]
	var fake: FakeFloor = setup["floor"]
	var day_one := {
		"day_progress": {"tower_floor": 2, "day": 1},
		"palette": {"ink": Color.BLACK},
	}
	adapter.rebuild_floor(day_one)
	adapter.player.position = Vector3(3.0, 0.08, 4.0)
	adapter.yaw = 12.0
	adapter.pitch = -3.0
	var rebuilds_before_day := fake.rebuild_count
	var day_two := day_one.duplicate(true)
	(day_two["day_progress"] as Dictionary)["day"] = 2
	adapter.ensure_floor_current(day_two)
	_assert_eq(fake.rebuild_count, rebuilds_before_day, "a day change should not rebuild the floor")
	_assert_eq(fake.scene_replacements.size(), 1, "a day change should ask the generator to replace scenes")
	var replaced: Array = fake.scene_replacements[0]
	_assert_eq(str((replaced[0] as Dictionary).get("id", "")), "light_memory", "day two should replace the list with the light memory")
	_assert_eq(str((replaced[0] as Dictionary).get("kind", "")), "light_memory", "the replaced scene kind should stay light_memory")
	_assert_true(adapter.player.position.is_equal_approx(Vector3(3.0, 0.08, 4.0)), "a day change should leave the player where they stand")
	_assert_true(is_equal_approx(adapter.yaw, 12.0), "a day change should leave look yaw alone")
	_assert_true(is_equal_approx(adapter.pitch, -3.0), "a day change should leave look pitch alone")
	var next_floor := day_two.duplicate(true)
	(next_floor["day_progress"] as Dictionary)["tower_floor"] = 3
	adapter.ensure_floor_current(next_floor)
	_assert_eq(fake.rebuild_count, rebuilds_before_day + 1, "a floor change should still rebuild the whole floor")
	_assert_eq(int(fake.last_rebuild.get("floor_number", 0)), 3, "the floor rebuild should use the new tower floor")
	setup["host"].free()


func _test_collect_item_by_id_clears_nearby_item() -> void:
	var setup := _make_adapter_with_fake_floor()
	var adapter = setup["adapter"]
	var fake: FakeFloor = setup["floor"]
	fake.add_item("floor1_key", "荧光钥匙", Vector3(0.0, 0.0, 1.0))
	adapter.player.position = Vector3.ZERO
	_assert_eq(str(adapter.probe_interaction(_walk_deps()).get("action", "")), "collect", "item should be collectable before pickup")
	adapter.apply_item_collected("floor1_key")
	_assert_eq(str(adapter.nearby_outcome().get("kind", "")), "none", "collecting by id should clear the nearby item")
	_assert_eq(str(adapter.probe_interaction(_walk_deps()).get("action", "")), "none", "a collected item should no longer probe as collect")
	setup["host"].free()


func _test_theme_palette_recolors_the_street() -> void:
	var setup := _make_adapter_with_fake_floor()
	var adapter = setup["adapter"]
	var fake: FakeFloor = setup["floor"]
	var road := _add_street_road(fake)
	adapter.apply_palette({"name": "palette_1", "accent": "365B2D"})
	_assert_eq(_road_hex(road), "192a15", "the calm theme should paint the street road")
	adapter.apply_palette({"name": "pollution_palette_5", "accent": "2F6B1F"})
	_assert_eq(_road_hex(road), "16310e", "switching theme should repaint the street road")
	setup["host"].free()


func _test_floor_three_door_follows_task_progress() -> void:
	var setup := _make_adapter_with_fake_floor()
	var adapter = setup["adapter"]
	var fake: FakeFloor = setup["floor"]
	if not adapter.has_method("sync_ultimate_task_props"):
		_failures.append("the reality scene adapter should sync ultimate task props")
		setup["host"].free()
		return
	adapter.sync_ultimate_task_props(_task_prop_deps(3, false, false))
	var sealed := fake.get_node_or_null("FloorThreeSealedDoor") as StaticBody3D
	var open_frame := fake.get_node_or_null("FloorThreeDoorOpenFrame") as MeshInstance3D
	_assert_true(sealed != null and sealed.visible, "floor three should show the sealed door before the task")
	_assert_true(sealed != null and sealed.position.is_equal_approx(Vector3(0.0, 1.6, -7.0)), "the sealed door should stand at the floor-three threshold")
	var door_collision: CollisionShape3D = null
	if sealed != null:
		door_collision = sealed.get_node_or_null("DoorCollision") as CollisionShape3D
	_assert_true(door_collision != null and not door_collision.disabled, "the sealed door must physically block the player")
	_assert_true(open_frame != null and not open_frame.visible, "the open frame should wait for the rule")
	_assert_true(open_frame != null and open_frame.position.is_equal_approx(Vector3(0.0, 1.7, -7.0)), "the open frame should stand in the sealed door's place")
	adapter.sync_ultimate_task_props(_task_prop_deps(3, true, false))
	_assert_true(sealed != null and not sealed.visible, "completing the task should retire the sealed door")
	_assert_true(door_collision != null and door_collision.disabled, "the opened door must stop blocking")
	_assert_true(open_frame != null and open_frame.visible, "completing the task should reveal the open door frame")
	setup["host"].free()


func _test_floor_four_exit_follows_task_progress() -> void:
	var setup := _make_adapter_with_fake_floor()
	var adapter = setup["adapter"]
	var fake: FakeFloor = setup["floor"]
	adapter.sync_ultimate_task_props(_task_prop_deps(4, true, false))
	var exit_frame := fake.get_node_or_null("FloorFourExitFrame") as MeshInstance3D
	_assert_true(exit_frame != null and not exit_frame.visible, "the floor-four exit should not exist before its rule")
	_assert_true(exit_frame != null and exit_frame.position.is_equal_approx(Vector3(0.0, 1.7, -6.0)), "the exit frame should stand at the floor-four threshold")
	_assert_true(fake.get_node_or_null("FloorThreeSealedDoor") == null, "floor four should not raise the floor-three door")
	adapter.sync_ultimate_task_props(_task_prop_deps(4, true, true))
	_assert_true(exit_frame != null and exit_frame.visible, "the exit frame should appear the moment the rule holds")
	setup["host"].free()


func _test_other_floors_omit_ultimate_task_props() -> void:
	var setup := _make_adapter_with_fake_floor()
	var adapter = setup["adapter"]
	var fake: FakeFloor = setup["floor"]
	adapter.sync_ultimate_task_props(_task_prop_deps(2, false, false))
	_assert_true(fake.get_node_or_null("FloorThreeSealedDoor") == null, "floor two should not raise the sealed door")
	_assert_true(fake.get_node_or_null("FloorFourExitFrame") == null, "floor two should not raise the exit frame")
	setup["host"].free()


func _test_host_asks_adapter_to_sync_ultimate_task_props() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/babel_meme_game.gd")
	_assert_true(
		not main_source.contains('get_node_or_null("RealityFloor")'),
		"the host should not find the floor by node name to place ultimate task props"
	)
	_assert_true(
		not main_source.contains("func _ensure_task_prop_body") and not main_source.contains("func _ensure_task_prop_mesh"),
		"the host should not build ultimate task props itself"
	)
	_assert_true(
		main_source.contains("_reality_scene_adapter.sync_ultimate_task_props("),
		"the host should ask the reality scene adapter to sync ultimate task props"
	)


func _task_prop_deps(tower_floor: int, floor3_complete: bool, floor4_complete: bool) -> Dictionary:
	return {
		"day_progress": {"tower_floor": tower_floor},
		"floor3_task_complete": floor3_complete,
		"floor4_task_complete": floor4_complete,
		"palette": {"ink": "10140F", "flash_text": "9CFF24"},
	}


func _test_host_does_not_paint_floor_nodes() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/babel_meme_game.gd")
	_assert_true(
		not main_source.contains("_reality_scene_adapter.floor.apply_palette"),
		"the host should not paint floor nodes"
	)
	_assert_true(
		main_source.contains("_reality_scene_adapter.apply_palette("),
		"the host should ask the reality scene adapter to apply the theme palette"
	)


func _add_street_road(parent: Node3D) -> MeshInstance3D:
	var road := MeshInstance3D.new()
	road.name = "StreetRoad"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(4.0, 0.08, 12.0)
	road.mesh = mesh
	road.set_meta("theme_role", "road")
	road.material_override = StandardMaterial3D.new()
	parent.add_child(road)
	return road


func _road_hex(road: MeshInstance3D) -> String:
	var material := road.material_override as StandardMaterial3D
	if material == null:
		return ""
	return material.albedo_color.to_html(false)


func _test_hiding_the_street_hides_characters_until_restored() -> void:
	var setup := _make_adapter_with_fake_floor()
	var adapter = setup["adapter"]
	var fake: FakeFloor = setup["floor"]
	var actor := fake.add_actor("latecomer", "npc", "迟到者", Vector3(1.0, 0.0, 1.0))
	_assert_true(fake.visible, "the street should start shown")
	_assert_true(adapter.player.visible, "the player should start shown")
	adapter.set_street_shown(false)
	_assert_true(not fake.visible, "hiding the street should hide the floor")
	_assert_true(not adapter.player.visible, "hiding the street should hide the player")
	var look_pose: Dictionary = adapter.pose()
	_assert_true(bool(look_pose.get("has_player", false)), "hiding the street should leave look pose readable")
	adapter.set_street_shown(true)
	_assert_true(fake.visible, "showing the street should restore the floor")
	_assert_true(adapter.player.visible, "showing the street should restore the player")
	_assert_true(actor.visible, "showing the street should leave the character's own visibility alone")
	setup["host"].free()


func _test_face_actor_by_id_updates_pose() -> void:
	var setup := _make_adapter_with_fake_floor()
	var adapter = setup["adapter"]
	var fake: FakeFloor = setup["floor"]
	fake.add_actor("latecomer", "npc", "迟到者", Vector3(2.0, 0.0, 0.0))
	adapter.player.position = Vector3.ZERO
	adapter.face_actor("latecomer")
	var look_pose: Dictionary = adapter.pose()
	_assert_true(is_equal_approx(float(look_pose.get("yaw", 0.0)), -90.0), "facing an actor to the right should yaw the view")
	_assert_true(is_equal_approx(float(look_pose.get("pitch", 0.0)), -2.0), "facing an npc should use the conversation pitch")
	adapter.remember_actor("latecomer")
	var active: Dictionary = adapter.active_actor_outcome()
	_assert_eq(str(active.get("actor_id", "")), "latecomer", "remembered actor should be readable as an outcome")
	_assert_true(active.get("actor") == null, "active actor outcome must not leak the live Area3D")
	setup["host"].free()


func _test_collect_outcome_picks_up_without_opening_a_conversation() -> void:
	var setup := _make_adapter_with_fake_floor()
	var adapter = setup["adapter"]
	var fake: FakeFloor = setup["floor"]
	fake.add_item("floor1_key", "荧光钥匙", Vector3(0.0, 0.0, 1.0))
	adapter.player.position = Vector3.ZERO
	adapter.yaw = 12.0
	adapter.pitch = -6.0
	var outcome: Dictionary = adapter.apply_interaction({"action": "collect", "item_id": "floor1_key"})
	_assert_eq(str(outcome.get("interaction_active", true)), "false", "picking up should not open a conversation")
	_assert_true(not bool(adapter.interaction_outcome().get("interaction_active", true)), "a pickup should leave the street idle")
	_assert_eq(str(adapter.probe_interaction(_walk_deps()).get("action", "")), "none", "the collected item should leave the approach")
	_assert_true(is_equal_approx(adapter.yaw, 12.0), "picking up should leave look yaw alone")
	_assert_true(is_equal_approx(adapter.pitch, -6.0), "picking up should leave look pitch alone")
	setup["host"].free()


func _test_accepted_conversation_faces_the_actor() -> void:
	var setup := _make_adapter_with_fake_floor()
	var adapter = setup["adapter"]
	var fake: FakeFloor = setup["floor"]
	fake.add_actor("latecomer", "npc", "迟到者", Vector3(2.0, 0.0, 0.0))
	adapter.player.position = Vector3.ZERO
	adapter.yaw = 12.0
	adapter.pitch = -6.0
	var outcome: Dictionary = adapter.apply_interaction({
		"action": "converse",
		"actor_id": "latecomer",
		"accepted": true,
	})
	_assert_true(bool(outcome.get("interaction_active", false)), "an accepted conversation should report interaction active")
	_assert_eq(str(outcome.get("action", "")), "converse", "an accepted conversation should stay a converse outcome")
	_assert_eq(str(outcome.get("actor_id", "")), "latecomer", "the conversation outcome should identify the actor")
	_assert_true(outcome.get("actor") == null, "the conversation outcome must not leak the live Area3D")
	var look_pose: Dictionary = adapter.pose()
	_assert_true(is_equal_approx(float(look_pose.get("yaw", 0.0)), -90.0), "starting a conversation should face the actor")
	_assert_true(is_equal_approx(float(look_pose.get("pitch", 0.0)), -2.0), "starting a conversation should use the conversation pitch")
	_assert_eq(str(adapter.active_actor_outcome().get("actor_id", "")), "latecomer", "starting a conversation should remember the actor")
	setup["host"].free()


func _test_ending_conversation_restores_gaze_and_walking() -> void:
	var setup := _make_adapter_with_fake_floor()
	var adapter = setup["adapter"]
	var fake: FakeFloor = setup["floor"]
	fake.add_actor("latecomer", "npc", "迟到者", Vector3(2.0, 0.0, 0.0))
	adapter.player.position = Vector3.ZERO
	adapter.yaw = 12.0
	adapter.pitch = -6.0
	_press_reality_forward()
	adapter.apply_interaction({"action": "converse", "actor_id": "latecomer", "accepted": true})
	adapter.player.velocity = Vector3.ZERO
	adapter.update_player(0.5, {"view_state": "npc_up", "interaction_active": false})
	var blocked_speed: float = Vector2(adapter.player.velocity.x, adapter.player.velocity.z).length()
	_assert_true(blocked_speed < 0.01, "a host idle flag should not let the player walk during a conversation")
	var ended: Dictionary = adapter.apply_interaction({"action": "end"})
	_assert_true(not bool(ended.get("interaction_active", true)), "ending a conversation should report the street idle")
	_assert_true(not bool(adapter.interaction_outcome().get("interaction_active", true)), "the street should stay idle after the conversation ends")
	_assert_eq(str(adapter.active_actor_outcome().get("kind", "")), "none", "ending a conversation should forget the actor")
	var look_pose: Dictionary = adapter.pose()
	_assert_true(is_equal_approx(float(look_pose.get("yaw", 0.0)), 12.0), "ending a conversation should restore look yaw")
	_assert_true(is_equal_approx(float(look_pose.get("pitch", 0.0)), -6.0), "ending a conversation should restore look pitch")
	adapter.player.velocity = Vector3.ZERO
	adapter.update_player(0.5, {"view_state": "npc_up", "interaction_active": true})
	var restored_speed: float = Vector2(adapter.player.velocity.x, adapter.player.velocity.z).length()
	_assert_true(restored_speed > 0.5, "a host interaction flag should not keep the player stuck after the conversation ends")
	_release_reality_forward()
	setup["host"].free()


func _test_rejected_conversation_leaves_no_stuck_state() -> void:
	var setup := _make_adapter_with_fake_floor()
	var adapter = setup["adapter"]
	var fake: FakeFloor = setup["floor"]
	fake.add_actor("latecomer", "npc", "迟到者", Vector3(2.0, 0.0, 0.0))
	adapter.player.position = Vector3.ZERO
	adapter.yaw = 12.0
	adapter.pitch = -6.0
	var rejected: Dictionary = adapter.apply_interaction({
		"action": "converse",
		"actor_id": "latecomer",
		"accepted": false,
	})
	_assert_true(not bool(rejected.get("interaction_active", true)), "a rejected conversation should not become active")
	_assert_true(is_equal_approx(adapter.yaw, 12.0), "a rejected conversation should not turn the view")
	_assert_true(is_equal_approx(adapter.pitch, -6.0), "a rejected conversation should not pitch the view")
	_assert_eq(str(adapter.active_actor_outcome().get("kind", "")), "none", "a rejected conversation should not remember an actor")
	adapter.apply_interaction({"action": "converse", "actor_id": "missing", "accepted": true})
	_assert_true(not bool(adapter.interaction_outcome().get("interaction_active", true)), "a missing actor should not leave the street interacting")
	_assert_true(is_equal_approx(adapter.yaw, 12.0), "a missing actor should not leave the view turned")
	adapter.apply_interaction({"action": "converse", "actor_id": "latecomer", "accepted": true})
	adapter.apply_interaction({"action": "converse", "actor_id": "latecomer", "accepted": false})
	_assert_true(not bool(adapter.interaction_outcome().get("interaction_active", true)), "failing after a conversation starts should clear the interaction")
	_assert_true(is_equal_approx(adapter.yaw, 12.0), "failing after a conversation starts should restore look yaw")
	_assert_true(is_equal_approx(adapter.pitch, -6.0), "failing after a conversation starts should restore look pitch")
	_assert_eq(str(adapter.active_actor_outcome().get("kind", "")), "none", "failing after a conversation starts should forget the actor")
	setup["host"].free()


func _test_rebuilding_the_floor_drops_a_conversation_without_restoring_old_gaze() -> void:
	var setup := _make_adapter_with_fake_floor()
	var adapter = setup["adapter"]
	var fake: FakeFloor = setup["floor"]
	fake.add_actor("latecomer", "npc", "迟到者", Vector3(2.0, 0.0, 0.0))
	adapter.player.position = Vector3.ZERO
	adapter.yaw = 15.0
	adapter.pitch = -4.0
	adapter.apply_interaction({"action": "converse", "actor_id": "latecomer", "accepted": true})
	adapter.rebuild_floor({"day_progress": {"tower_floor": 1, "day": 1}})
	_assert_true(not bool(adapter.interaction_outcome().get("interaction_active", true)), "rebuilding the floor should drop the conversation")
	_assert_true(is_equal_approx(adapter.yaw, 0.0), "rebuilding the floor should reset look yaw")
	adapter.apply_interaction({"action": "end"})
	_assert_true(is_equal_approx(adapter.yaw, 0.0), "ending after a rebuild should not snap back to the old gaze")
	_assert_true(is_equal_approx(adapter.pitch, 0.0), "ending after a rebuild should not snap back to the old pitch")
	setup["host"].free()


func _test_host_applies_interaction_outcomes_instead_of_orchestrating_them() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/babel_meme_game.gd")
	_assert_true(
		main_source.contains("_reality_scene_adapter.apply_interaction("),
		"the host should apply pickup and conversation through an interaction outcome"
	)
	_assert_true(
		not main_source.contains("var _reality_interaction_active"),
		"the host should not remember an interaction flag to run the street lifecycle"
	)
	_assert_true(
		not main_source.contains("_reality_scene_adapter.face_actor("),
		"the host should not face actors itself"
	)
	_assert_true(
		not main_source.contains("_reality_scene_adapter.remember_actor("),
		"the host should not remember actors itself"
	)
	_assert_true(
		not main_source.contains("_reality_scene_adapter.clear_active_actor("),
		"the host should not clear the active actor itself"
	)
	_assert_true(
		not main_source.contains("_reality_scene_adapter.apply_item_collected("),
		"the host should not collect items outside the interaction outcome"
	)


func _press_reality_forward() -> void:
	_ensure_reality_walk_actions()
	Input.action_press("reality_forward")


func _release_reality_forward() -> void:
	if InputMap.has_action("reality_forward"):
		Input.action_release("reality_forward")


func _ensure_reality_walk_actions() -> void:
	var keys := {
		"reality_forward": KEY_W,
		"reality_back": KEY_S,
		"reality_left": KEY_A,
		"reality_right": KEY_D,
		"reality_sprint": KEY_SHIFT,
	}
	for action_name in keys.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			var key_event := InputEventKey.new()
			key_event.physical_keycode = int(keys[action_name])
			InputMap.action_add_event(action_name, key_event)


func _make_adapter_with_fake_floor() -> Dictionary:
	var host := Node3D.new()
	host.name = "RealityAdapterTestHost"
	root.add_child(host)
	var adapter = RealitySceneAdapterScript.new()
	adapter.attach_to(host)
	adapter.build_world_nodes()
	if adapter.floor != null:
		adapter.floor.free()
	var fake := FakeFloor.new()
	fake.name = "RealityFloor"
	host.add_child(fake)
	adapter.floor = fake
	return {"host": host, "adapter": adapter, "floor": fake}


func _walk_deps() -> Dictionary:
	return {
		"view_state": "npc_up",
		"interaction_active": false,
	}


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


class FakeFloor extends RealityFloorGenerator:
	var fake_actors: Array[Area3D] = []
	var fake_items: Array[Area3D] = []
	var last_rebuild: Dictionary = {}
	var last_sync_collected: Array[String] = []
	var last_sync_dolls: Array[String] = []
	var rebuild_count := 0
	var scene_replacements: Array = []

	func rebuild(
		floor_number: int,
		palette: Dictionary,
		actor_textures: Dictionary,
		day_number: int = 1,
		cover_watcher_seen: bool = false,
		items: Array = [],
		people: Array = [],
		display_names: Dictionary = {},
		events: Array = [],
		layout: Dictionary = {}
	) -> void:
		rebuild_count += 1
		last_rebuild = {
			"floor_number": floor_number,
			"palette": palette,
			"actor_textures": actor_textures,
			"day_number": day_number,
			"cover_watcher_seen": cover_watcher_seen,
			"items": items,
			"people": people,
			"display_names": display_names,
			"events": events,
			"layout": layout,
		}

	func configure_authored_events(day_number: int, palette: Dictionary, events: Array = []) -> void:
		scene_replacements.append(events)
		set_meta("authored_event_day", day_number)
		set_meta("palette_present", not palette.is_empty())

	func get_interactable_actors() -> Array[Area3D]:
		return fake_actors

	func get_interactable_items() -> Array[Area3D]:
		var live_items: Array[Area3D] = []
		for item in fake_items:
			if is_instance_valid(item) and item.visible and not bool(item.get_meta("collected", false)):
				live_items.append(item)
		return live_items

	func sync_collected_items(collected_ids: Array[String]) -> void:
		last_sync_collected = collected_ids.duplicate()

	func sync_claimed_dolls(claimed_ids: Array[String]) -> void:
		last_sync_dolls = claimed_ids.duplicate()

	func contains_playable_position(_position: Vector3, _inset: float = 0.0) -> bool:
		return true

	func start_position() -> Vector3:
		return Vector3(0.0, 0.08, 0.0)

	func clamp_to_playable_position(position: Vector3, _inset: float = 1.2) -> Vector3:
		return position

	func add_actor(actor_id: String, actor_type: String, label: String, pos: Vector3) -> Area3D:
		var actor := Area3D.new()
		actor.name = actor_id
		actor.position = pos
		actor.set_meta("actor_id", actor_id)
		actor.set_meta("actor_type", actor_type)
		actor.set_meta("display_name", label)
		add_child(actor)
		fake_actors.append(actor)
		return actor

	func add_item(item_id: String, label: String, pos: Vector3, extra: Dictionary = {}) -> Area3D:
		var item := Area3D.new()
		item.name = item_id
		item.position = pos
		item.set_meta("item_id", item_id)
		item.set_meta("display_name", label)
		item.set_meta("item_effect", str(extra.get("effect", "")))
		item.set_meta("item_value", extra.get("value", 0))
		item.set_meta("item_description", str(extra.get("description", "信号已经写入。")))
		add_child(item)
		fake_items.append(item)
		return item
