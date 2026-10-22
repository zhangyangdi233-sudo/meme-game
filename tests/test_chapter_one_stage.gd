extends SceneTree
## The Reality scene adapter builds chapter one's opening and basement from the imported models: the player starts
## 29.5 m from the white door, the door is only reachable once the narration is read and the knock heard, opening it
## walks the player through before the basement replaces the opening, and the knock is played once and pauses.

const RealitySceneAdapterScript = preload("res://scripts/world/reality_scene_adapter.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const GameEventsScript = preload("res://scripts/game_events.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")

const OPENING_WALK_DISTANCE := 29.5

var _failures: Array[String] = []
var _knocks_heard := 0


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	await _run()
	RegistryScript.clear()
	if _failures.is_empty():
		print("chapter one stage tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	for action_name in ["reality_forward", "reality_back", "reality_left", "reality_right", "reality_sprint"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
	var bus := GameEventBusScript.new()
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	bus.subscribe(GameEventsScript.OPENING_KNOCK_FINISHED, func(_payload: Dictionary) -> void: _knocks_heard += 1)
	await _test_the_opening_starts_far_from_the_white_door()
	await _test_the_door_waits_for_the_narration_and_the_knock()
	await _test_the_knock_plays_on_its_line_once_and_pauses()
	await _test_opening_the_door_walks_through_into_the_basement()
	await _test_the_basement_is_a_room_to_walk_in()
	await _test_a_pose_saved_in_another_stage_starts_on_the_spawn()
	await _test_a_missing_knock_recording_does_not_lock_the_door()
	await _test_the_tower_street_still_builds_without_chapter_progress()


func _test_the_opening_starts_far_from_the_white_door() -> void:
	var adapter = await _adapter(ProgressScript.initial())
	var pose: Dictionary = adapter.pose()
	var start: Vector3 = pose.get("player_position")
	var door: Vector3 = adapter.chapter_door_position()
	var flat := Vector2(start.x - door.x, start.z - door.z)
	_assert_near(flat.length(), OPENING_WALK_DISTANCE, 0.05, "the opening should start 29.5 m from the white door")
	_assert_near(float(pose.get("yaw")), 0.0, 0.01, "the opening should face the white door")
	_assert_true(adapter.get_parent().find_child("OpeningKnock", true, false) != null, "the opening should carry the knock at the door")
	for frame in 30:
		adapter.update_player(1.0 / 60.0, _deps(ProgressScript.initial()))
		await physics_frame
	var settled: Vector3 = adapter.pose().get("player_position")
	_assert_true(absf(settled.y - start.y) < 0.2, "the player should stand on the black water, not fall: %s" % str(settled))
	await _free(adapter)


func _test_the_door_waits_for_the_narration_and_the_knock() -> void:
	var reading := _at_line(ProgressScript.KNOCK_LINE_INDEX)
	var adapter = await _adapter(reading)
	_stand_at_door(adapter)
	adapter.refresh_nearby_actor(_deps(reading))
	_assert_eq(str(adapter.nearby_outcome().get("kind")), "none", "the door should not answer while the narration is read")
	var read_unknocked := _read_to_end(reading)
	adapter.refresh_nearby_actor(_deps(read_unknocked))
	_assert_eq(str(adapter.nearby_outcome().get("kind")), "none", "the door should not answer before the knock finishes")
	var ready := ProgressScript.complete_knock(read_unknocked)
	adapter.refresh_nearby_actor(_deps(ready))
	var outcome: Dictionary = adapter.nearby_outcome()
	_assert_eq(str(outcome.get("kind")), "door", "the door should answer once the narration is read and the knock heard")
	_assert_eq(str(outcome.get("action")), "open_door", "the door's action should be to open it")
	adapter.player.position = adapter.pose().get("player_position") + Vector3(0, 0, 6)
	adapter.refresh_nearby_actor(_deps(ready))
	_assert_eq(str(adapter.nearby_outcome().get("kind")), "none", "the door should not answer from afar")
	await _free(adapter)


func _test_the_knock_plays_on_its_line_once_and_pauses() -> void:
	var before := _at_line(ProgressScript.KNOCK_LINE_INDEX - 1)
	var adapter = await _adapter(before)
	var knock := adapter.get_parent().find_child("OpeningKnock", true, false) as AudioStreamPlayer3D
	adapter.ensure_floor_current(_deps(before))
	_assert_true(knock != null and not knock.playing, "the knock should wait for its line")
	var due := ProgressScript.advance_narration(before)
	adapter.set_paused(true)
	adapter.ensure_floor_current(_deps(due))
	_assert_true(not knock.playing, "a paused opening should hold the knock back")
	adapter.set_paused(false)
	adapter.ensure_floor_current(_deps(due))
	_assert_true(knock.playing, "the knock should sound on its line")
	# A 3D player registers its playback on the next physics frame; only then can it be paused.
	await physics_frame
	await physics_frame
	adapter.set_paused(true)
	_assert_true(knock.stream_paused, "opening settings should pause the knock")
	adapter.set_paused(false)
	_assert_true(not knock.stream_paused, "closing settings should resume the knock")
	var heard_before := _knocks_heard
	knock.finished.emit()
	_assert_eq(_knocks_heard, heard_before + 1, "a finished knock should be reported on the event bus")
	adapter.ensure_floor_current(_deps(due))
	knock.finished.emit()
	_assert_eq(_knocks_heard, heard_before + 1, "the knock should be reported once")
	await _free(adapter)
	var heard := ProgressScript.complete_knock(due)
	var rebuilt = await _adapter(heard)
	var rebuilt_knock := rebuilt.get_parent().find_child("OpeningKnock", true, false) as AudioStreamPlayer3D
	rebuilt.ensure_floor_current(_deps(heard))
	_assert_true(rebuilt_knock != null and not rebuilt_knock.playing, "a knock already heard should not play again")
	await _free(rebuilt)


func _test_opening_the_door_walks_through_into_the_basement() -> void:
	var ready := ProgressScript.complete_knock(_read_to_end(_at_line(ProgressScript.KNOCK_LINE_INDEX)))
	var adapter = await _adapter(ready)
	_stand_at_door(adapter)
	adapter.refresh_nearby_actor(_deps(ready))
	var started: Dictionary = adapter.apply_interaction({"action": "open_door"})
	_assert_eq(str(started.get("kind")), "door", "opening the door should report a door outcome")
	_assert_true(bool(started.get("interaction_active")), "the door opening should hold the player")
	var opened := ProgressScript.open_door(ready)
	var before: Vector3 = adapter.pose().get("player_position")
	adapter.apply_interaction({"action": "end"})
	_assert_eq(str(adapter.interaction_outcome().get("kind")), "door", "leaving an interaction should not cancel the door opening")
	adapter.ensure_floor_current(_deps(opened))
	_assert_true(adapter.get_parent().find_child("OpeningKnock", true, false) != null, "the opening should stay built while the door opens")
	adapter.set_paused(true)
	adapter.update_player(0.5, _deps(opened))
	_assert_near(float(adapter.interaction_outcome().get("progress")), 0.0, 0.001, "a paused door should not move")
	adapter.set_paused(false)
	adapter.update_player(0.5, _deps(opened))
	var midway: Dictionary = adapter.interaction_outcome()
	_assert_true(float(midway.get("progress")) > 0.0 and float(midway.get("progress")) < 1.0, "the door opening should report its progress")
	var moved: Vector3 = adapter.pose().get("player_position")
	_assert_true(moved.z < before.z, "the camera should push toward the door while it opens")
	for step in 20:
		adapter.update_player(0.25, _deps(opened))
	_assert_eq(str(adapter.interaction_outcome().get("kind")), "none", "the door opening should end")
	adapter.ensure_floor_current(_deps(opened))
	_assert_true(adapter.get_parent().find_child("OpeningKnock", true, false) == null, "the opening should be gone once the door has opened")
	_assert_true(adapter.get_parent().find_child("BasementRoom", true, false) != null, "the basement should replace the opening")
	await _free(adapter)


func _test_the_basement_is_a_room_to_walk_in() -> void:
	var basement := ProgressScript.open_door(ProgressScript.complete_knock(_read_to_end(_at_line(ProgressScript.KNOCK_LINE_INDEX))))
	var adapter = await _adapter(basement)
	var start: Vector3 = adapter.pose().get("player_position")
	_assert_true(adapter.chapter_contains(start), "the basement should start the player inside the room")
	_assert_eq(str(adapter.nearby_outcome().get("kind")), "none", "the first basement round should be an empty room")
	for frame in 30:
		adapter.update_player(1.0 / 60.0, _deps(basement))
		await physics_frame
	var settled: Vector3 = adapter.pose().get("player_position")
	_assert_true(absf(settled.y - start.y) < 0.3, "the player should stand on the basement landing: %s -> %s" % [str(start), str(settled)])
	Input.action_press("reality_forward")
	for frame in 90:
		adapter.update_player(1.0 / 60.0, _deps(basement))
		await physics_frame
	Input.action_release("reality_forward")
	var walked: Vector3 = adapter.pose().get("player_position")
	_assert_true(walked.distance_to(settled) > 0.5, "the player should walk in the basement: %s -> %s" % [str(settled), str(walked)])
	_assert_true(adapter.chapter_contains(walked), "walking should stay inside the basement: %s" % str(walked))
	await _free(adapter)


## A save made while the white door opened is already in the basement but holds a pose from the opening.
func _test_a_pose_saved_in_another_stage_starts_on_the_spawn() -> void:
	var basement := ProgressScript.open_door(ProgressScript.complete_knock(_read_to_end(_at_line(ProgressScript.KNOCK_LINE_INDEX))))
	var adapter = await _adapter(basement)
	var spawn: Vector3 = adapter.pose().get("player_position")
	adapter.restore_world_pose({"player_position": Vector3(0.0, 0.04, -17.6), "yaw": 0.0, "pitch": 0.0})
	var restored: Vector3 = adapter.pose().get("player_position")
	_assert_true(restored.distance_to(spawn) < 0.01, "a pose outside the basement should start on its spawn: %s" % str(restored))
	await _free(adapter)


func _test_a_missing_knock_recording_does_not_lock_the_door() -> void:
	var due := _at_line(ProgressScript.KNOCK_LINE_INDEX)
	var adapter = await _adapter(due)
	var knock := adapter.get_parent().find_child("OpeningKnock", true, false) as AudioStreamPlayer3D
	knock.stream = null
	var heard_before := _knocks_heard
	adapter.ensure_floor_current(_deps(due))
	_assert_eq(_knocks_heard, heard_before + 1, "a knock with no recording should count as heard so the door can open")
	await _free(adapter)


func _test_the_tower_street_still_builds_without_chapter_progress() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var adapter = RealitySceneAdapterScript.new()
	adapter.attach_to(host)
	adapter.build_world_nodes()
	adapter.rebuild_floor({"day_progress": {"tower_floor": 1}, "palette": UiPalette.PALETTE_1})
	_assert_true(adapter.get_parent().find_child("OpeningKnock", true, false) == null, "deps without chapter progress should build no opening")
	_assert_true(adapter.floor.room_count > 0, "deps without chapter progress should build the tower street")
	host.queue_free()
	await process_frame


func _adapter(progress: Dictionary):
	var host := Node3D.new()
	host.name = "ChapterStageHost"
	root.add_child(host)
	var adapter = RealitySceneAdapterScript.new()
	adapter.attach_to(host)
	adapter.build_world_nodes()
	adapter.rebuild_floor(_deps(progress))
	await process_frame
	return adapter


func _deps(progress: Dictionary) -> Dictionary:
	return {
		"day_progress": {"tower_floor": 1, "day": 1},
		"chapter_one_progress": progress,
		"view_state": "npc_up",
	}


func _stand_at_door(adapter) -> void:
	var door: Vector3 = adapter.chapter_door_position()
	adapter.player.position = Vector3(door.x, adapter.player.position.y, door.z + 0.9)


func _free(adapter) -> void:
	var host: Node = adapter.get_parent()
	host.queue_free()
	await process_frame


func _at_line(line_index: int) -> Dictionary:
	var progress := ProgressScript.initial()
	for step in line_index:
		progress = ProgressScript.advance_narration(progress)
	return progress


func _read_to_end(progress: Dictionary) -> Dictionary:
	var read := progress
	while ProgressScript.is_reading_narration(read):
		read = ProgressScript.advance_narration(read)
	return read


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])


func _assert_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
