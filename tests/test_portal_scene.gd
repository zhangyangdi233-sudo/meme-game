extends SceneTree
## The portal in the whole game (planner's design of 2026-10-31; "hold X for three seconds", 2026-11-20). In a basement
## round, X held shows the white door's passage through a frame in the middle of the view; held for three seconds the
## frame stays in the room; walking into it leaves the round for the passage, where the view goes on from where it was;
## the white door's light then leads to the next round. A run goes through once: a frame fixed afterwards is a flat
## print and no way out.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const TEST_SAVE_PATH := "user://test_portal_scene_save.dat"
const TEST_PREFERENCES_PATH := "user://test_portal_scene_preferences.cfg"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	root.size = Vector2i(1600, 900)
	_remove_files()
	await _run()
	_remove_files()
	if _failures.is_empty():
		print("portal scene tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	var game_root = scene.instantiate()
	game_root._save_path = TEST_SAVE_PATH
	root.add_child(game_root)
	await process_frame
	game_root._locale.preferences_path = TEST_PREFERENCES_PATH
	game_root._locale.set_locale("zh")
	game_root.new_game()
	await process_frame
	await _test_round_ones_frame_waits_for_the_lesson(game_root)
	await _test_a_frame_held_up_to_a_wall_is_walked_into_at_the_wall(game_root)
	await _test_the_terminal_takes_the_portal_away(game_root)
	await _test_x_held_looks_into_the_passage_and_three_seconds_fix_it(game_root)
	await _test_walking_into_the_portal_leaves_the_round_for_the_passage(game_root)
	await _test_the_white_door_leads_to_the_next_round(game_root)
	await _test_a_used_up_portal_fixes_as_a_print(game_root)
	await _test_the_fifth_rounds_portal_leads_where_its_passage_does(game_root)
	Input.action_release("reality_xray")
	Input.action_release("reality_forward")
	game_root.queue_free()
	await process_frame


func _test_round_ones_frame_waits_for_the_lesson(game_root) -> void:
	await _jump(game_root, 1)
	var adapter = game_root._reality_scene_adapter
	await _stand(game_root, Vector3(0.6, 0.05, 2.4), 0.0)
	Input.action_press("reality_xray")
	for frame in 4:
		await process_frame
	var portal := _stage(game_root).get_node_or_null("BasementPortal") as BasementPortal
	_assert_true(portal != null and portal.state() == BasementPortal.STATE_PREVIEW, "round one's X-ray should still look into the passage")
	game_root._portal_held = game_root.PORTAL_HOLD_SECONDS - 0.02
	for frame in 6:
		await process_frame
	_assert_true(not adapter.portal_fixed() and game_root._portal_held == 0.0, "round one's frame should not stay before the lesson's post")
	await _let_go(game_root)


func _test_a_frame_held_up_to_a_wall_is_walked_into_at_the_wall(game_root) -> void:
	await _jump(game_root, 2)
	var adapter = game_root._reality_scene_adapter
	# Facing the east wall (x = 3.2) from 0.7 m: nearer than where the other world would begin.
	await _stand(game_root, Vector3(2.5, 0.05, -1.0), -90.0)
	await _fix(game_root)
	var material := (_stage(game_root).get_node("BasementPortal/PortalWindow") as MeshInstance3D).material_override as ShaderMaterial
	var near := float(material.get_shader_parameter("frame_near"))
	_assert_true(adapter.portal_fixed() and near < BasementPortal.NEAR - 0.2 and near >= 0.3, "a frame held up to a wall should begin just short of it: %s" % str(near))
	_assert_eq(ProgressScript.round_of(game_root.game.chapter_one_progress), 2, "fixing at the wall should not take the player at once")
	Input.action_press("reality_forward")
	for frame in 90:
		await physics_frame
		await process_frame
		if ProgressScript.phase_of(game_root.game.chapter_one_progress) != ProgressScript.PHASE_BASEMENT:
			break
	Input.action_release("reality_forward")
	_assert_eq(ProgressScript.phase_of(game_root.game.chapter_one_progress), ProgressScript.PHASE_PASSAGE, "walking at the wall the frame is pasted on should take the player through")


func _test_the_terminal_takes_the_portal_away(game_root) -> void:
	await _jump(game_root, 2)
	var adapter = game_root._reality_scene_adapter
	var reach: Vector3 = adapter.chapter_terminal_position()
	await _stand(game_root, reach + Vector3(0.0, 0.02, 0.0), 0.0)
	await _fix(game_root)
	_assert_true(adapter.portal_fixed(), "a portal should fix at the CRT like anywhere")
	_push_key(game_root, KEY_F)
	await process_frame
	_assert_eq(str(adapter.interaction_outcome().get("kind")), "terminal", "F at the CRT should still enter the terminal")
	_assert_true(not adapter.portal_fixed(), "entering the terminal should take a fixed portal away, so its glass shows")
	_push_key(game_root, KEY_TAB)
	await process_frame


func _test_x_held_looks_into_the_passage_and_three_seconds_fix_it(game_root) -> void:
	await _jump(game_root, 2)
	var adapter = game_root._reality_scene_adapter
	await _stand(game_root, Vector3(0.6, 0.05, 2.4), 0.0)
	_assert_true(not adapter.portal_fixed(), "a round should start with no portal in it")
	# With the phone down over the view the X key does not look, so it frames nothing.
	game_root.set_view_state("phone_down")
	Input.action_press("reality_xray")
	for frame in 4:
		await process_frame
	_assert_true(_stage(game_root).get_node_or_null("BasementPortal") == null and game_root._portal_held == 0.0, "X should frame no portal while the phone is down")
	Input.action_release("reality_xray")
	game_root.set_view_state("npc_up")
	await process_frame
	Input.action_press("reality_xray")
	for frame in 4:
		await process_frame
	var portal := _stage(game_root).get_node_or_null("BasementPortal") as BasementPortal
	_assert_true(portal != null and portal.state() == BasementPortal.STATE_PREVIEW, "X held should look into the passage through its frame")
	_assert_true(game_root._portal_held > 0.0 and game_root._portal_held < 1.0, "the frame should count how long it is held: %s" % str(game_root._portal_held))
	Input.action_release("reality_xray")
	await process_frame
	_assert_true(portal.state() == BasementPortal.STATE_PREVIEW, "a look lost for a moment should go on where it was")
	await create_timer(game_root.PORTAL_LOOK_GRACE + 0.15).timeout
	await process_frame
	_assert_true(portal.state() == BasementPortal.STATE_NONE and game_root._portal_held == 0.0, "letting X go before three seconds should leave nothing")
	# Open settings hold the count.
	Input.action_press("reality_xray")
	for frame in 3:
		await process_frame
	var settings_open = game_root._value_model(PropertyKeysScript.SETTINGS_OPEN)
	settings_open.write(true)
	await create_timer(game_root.PORTAL_LOOK_GRACE + 0.15).timeout
	await process_frame
	_assert_eq(game_root._portal_held, 0.0, "the frame should not be counted under open settings")
	game_root._portal_held = game_root.PORTAL_HOLD_SECONDS - 0.02
	for frame in 4:
		await process_frame
	_assert_true(not adapter.portal_fixed(), "no portal should be fixed under open settings")
	settings_open.write(false)
	Input.action_release("reality_xray")
	await create_timer(game_root.PORTAL_LOOK_GRACE + 0.15).timeout
	await process_frame
	Input.action_press("reality_xray")
	await process_frame
	# Nearly three seconds held: the next frames carry it over.
	game_root._portal_held = game_root.PORTAL_HOLD_SECONDS - 0.02
	for frame in 4:
		await process_frame
		if adapter.portal_fixed():
			break
	if not adapter.portal_fixed():
		await create_timer(0.1).timeout
		await process_frame
	_assert_true(adapter.portal_fixed(), "the frame held for three seconds should stay in the room")
	_assert_true(not _stage(game_root).portal_flat(), "a run's first portal should be a way through")
	for frame in 6:
		await process_frame
	_assert_true(adapter.portal_fixed(), "X still held after fixing should not start over")
	Input.action_release("reality_xray")
	for frame in 3:
		await process_frame
	_assert_true(adapter.portal_fixed(), "the fixed portal should stay once X is let go")
	_assert_eq(ProgressScript.round_of(game_root.game.chapter_one_progress), 2, "fixing a portal should not leave the round")


func _test_walking_into_the_portal_leaves_the_round_for_the_passage(game_root) -> void:
	var adapter = game_root._reality_scene_adapter
	var camera: Camera3D = game_root._camera
	var to_passage: Transform3D = _stage(game_root).portal_to_passage()
	# The frame was fixed looking along -Z from (0.6, 2.4): 1.6 m ahead is inside it.
	adapter.player.position = Vector3(0.6, 0.05, 0.8)
	adapter.player.velocity = Vector3.ZERO
	# The view right before the frame in which the player is taken through.
	var before := camera.global_transform
	for frame in 6:
		before = camera.global_transform
		await physics_frame
		await process_frame
		if ProgressScript.phase_of(game_root.game.chapter_one_progress) != ProgressScript.PHASE_BASEMENT:
			break
	_assert_eq(ProgressScript.phase_of(game_root.game.chapter_one_progress), ProgressScript.PHASE_PASSAGE, "walking into the portal should leave the round for the passage")
	_assert_eq(ProgressScript.passage_round(game_root.game.chapter_one_progress), 3, "the passage should lead to the next round")
	_assert_true(game_root.game.portal_used, "the run should have used its portal")
	_assert_true(Harness.find_node_by_name(game_root, "OpeningWorld") != null and Harness.find_node_by_name(game_root, "BasementRoom") == null, "the white door's world should stand where the room was")
	var landed: Vector3 = adapter.player.position
	_assert_true(Vector2(landed.x - 0.0, landed.z - (11.5 - 1.6)).length() < 0.4, "the player should stand as far into the passage as they walked into the frame: %s" % str(landed))
	# One frame of the view catching up with the player is all that may lie between the two.
	_assert_true(camera.global_position.distance_to(to_passage * before.origin) < 0.35, "the view should go on from where it was, in the passage's space: %s against %s" % [str(camera.global_position), str(to_passage * before.origin)])
	_assert_true((camera.global_basis.z).dot(to_passage.basis * before.basis.z) > 0.98, "the view should keep looking the way it looked")
	_assert_true(absf(wrapf(adapter.yaw, -180.0, 180.0)) < 1.0, "the player should still look the way they walked, at the white door: %s" % str(adapter.yaw))
	# A save made on the way to the white door comes back there, still leading to the next round.
	_assert_true(game_root._save_progress(), "the run should save in the passage")
	game_root.show_main_menu()
	await process_frame
	_assert_true(game_root.continue_game(), "the save should continue")
	await process_frame
	await process_frame
	_assert_eq(ProgressScript.passage_round(game_root.game.chapter_one_progress), 3, "the continued passage should still lead to the next round")
	_assert_true(game_root.game.portal_used, "the continued run should remember its portal is used up")
	_assert_true(Harness.find_node_by_name(game_root, "OpeningWorld") != null, "the continued run should stand in the white door's world")


func _test_the_white_door_leads_to_the_next_round(game_root) -> void:
	var adapter = game_root._reality_scene_adapter
	var door: Vector3 = adapter.chapter_door_position()
	adapter.player.position = Vector3(door.x, adapter.player.position.y, door.z + 2.0)
	adapter.player.velocity = Vector3.ZERO
	adapter.yaw = 0.0
	var before: Dictionary = game_root.game.chapter_one_progress
	Input.action_press("reality_forward")
	for frame in 240:
		await physics_frame
		if game_root.game.chapter_one_progress != before:
			break
	Input.action_release("reality_forward")
	_assert_eq(ProgressScript.round_of(game_root.game.chapter_one_progress), 3, "the white door's light should lead to the round after the one left")
	for frame in 900:
		if str(adapter.interaction_outcome().get("kind")) != "door":
			break
		await process_frame
	for frame in 4:
		await process_frame
	_assert_true(Harness.find_node_by_name(game_root, "BasementRoom") != null, "the next round's room should be built once the white door is walked through")


func _test_a_used_up_portal_fixes_as_a_print(game_root) -> void:
	var adapter = game_root._reality_scene_adapter
	await _stand(game_root, Vector3(0.6, 0.05, 2.4), 0.0)
	Input.action_press("reality_xray")
	for frame in 3:
		await process_frame
	game_root._portal_held = game_root.PORTAL_HOLD_SECONDS - 0.02
	for frame in 4:
		await process_frame
		if adapter.portal_fixed():
			break
	if not adapter.portal_fixed():
		await create_timer(0.1).timeout
		await process_frame
	Input.action_release("reality_xray")
	await process_frame
	_assert_true(adapter.portal_fixed() and _stage(game_root).portal_flat(), "after its one use the portal should fix as a flat print")
	adapter.player.position = Vector3(0.6, 0.05, 0.8)
	adapter.player.velocity = Vector3.ZERO
	for frame in 4:
		await physics_frame
		await process_frame
	_assert_eq(ProgressScript.round_of(game_root.game.chapter_one_progress), 3, "nobody walks out through a print")


func _test_the_fifth_rounds_portal_leads_where_its_passage_does(game_root) -> void:
	# A jump gives the run its portal back.
	await _jump(game_root, 5)
	var adapter = game_root._reality_scene_adapter
	await _stand(game_root, Vector3(0.6, 0.05, 2.4), 0.0)
	Input.action_press("reality_xray")
	for frame in 3:
		await process_frame
	game_root._portal_held = game_root.PORTAL_HOLD_SECONDS - 0.02
	for frame in 4:
		await process_frame
		if adapter.portal_fixed():
			break
	if not adapter.portal_fixed():
		await create_timer(0.1).timeout
		await process_frame
	Input.action_release("reality_xray")
	await process_frame
	_assert_true(adapter.portal_fixed() and not _stage(game_root).portal_flat(), "the fifth round's portal should be a way through after a jump")
	adapter.player.position = Vector3(0.6, 0.05, 0.8)
	adapter.player.velocity = Vector3.ZERO
	for frame in 4:
		await physics_frame
		await process_frame
	_assert_eq(ProgressScript.phase_of(game_root.game.chapter_one_progress), ProgressScript.PHASE_PASSAGE, "the fifth round's portal should lead into the passage")
	_assert_eq(str(game_root.game.chapter_one_progress.get("passage_to")), ProgressScript.PHASE_DEMO_END, "the fifth round's passage should lead to the demo's end")
	_assert_eq(ProgressScript.passage_round(game_root.game.chapter_one_progress), 0, "the fifth round's passage leads to no further round")


## Holds X until the frame is fixed (the count is put just short of its end), then lets go.
func _fix(game_root) -> void:
	var adapter = game_root._reality_scene_adapter
	Input.action_press("reality_xray")
	for frame in 3:
		await process_frame
	game_root._portal_held = game_root.PORTAL_HOLD_SECONDS - 0.02
	for frame in 4:
		await process_frame
		if adapter.portal_fixed():
			break
	if not adapter.portal_fixed():
		await create_timer(0.1).timeout
		await process_frame
	await _let_go(game_root)


## Lets X go and waits until the look counts as over.
func _let_go(game_root) -> void:
	Input.action_release("reality_xray")
	await create_timer(game_root.PORTAL_LOOK_GRACE + 0.15).timeout
	await process_frame


func _push_key(game_root, keycode: Key) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = keycode
		key.physical_keycode = keycode
		key.pressed = pressed
		game_root.get_viewport().push_input(key, true)


func _stage(game_root) -> ChapterOneStage:
	return game_root.find_child("ChapterOneStage", true, false) as ChapterOneStage


func _jump(game_root, round_number: int) -> void:
	GameEventBus.raise(UiIntentsScript.CHAPTER_ROUND_JUMP_REQUESTED, {UiIntentsScript.KEY_INDEX: round_number})
	await process_frame
	await process_frame


## Stands the player at `feet` looking along `yaw_degrees` and lets the view catch up.
func _stand(game_root, feet: Vector3, yaw_degrees: float) -> void:
	var adapter = game_root._reality_scene_adapter
	adapter.player.position = feet
	adapter.player.velocity = Vector3.ZERO
	adapter.yaw = yaw_degrees
	adapter.pitch = 0.0
	for frame in 6:
		await physics_frame
	for step in 60:
		game_root._process(0.1)
	await process_frame


func _remove_files() -> void:
	for path in [TEST_SAVE_PATH, TEST_PREFERENCES_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
