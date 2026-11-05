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
const RoomContentScript = preload("res://scripts/game/room_content.gd")

const OPENING_WALK_DISTANCE := 29.5

var _failures: Array[String] = []
var _knocks_heard := 0
var _exits_crossed := 0
var _passages_entered := 0


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
	bus.subscribe(GameEventsScript.BASEMENT_EXIT_CROSSED, func(_payload: Dictionary) -> void: _exits_crossed += 1)
	bus.subscribe(GameEventsScript.PASSAGE_DOOR_ENTERED, func(_payload: Dictionary) -> void: _passages_entered += 1)
	await _test_the_opening_starts_far_from_the_white_door()
	await _test_the_door_waits_for_the_narration_and_the_knock()
	await _test_the_knock_plays_on_its_line_once_and_pauses()
	await _test_opening_the_door_walks_through_into_the_basement()
	await _test_the_basement_is_a_room_to_walk_in()
	await _test_the_room_state_changes_the_basement()
	await _test_a_pose_saved_in_another_stage_starts_on_the_spawn()
	await _test_the_crt_answers_in_reach_in_the_basement_only()
	await _test_the_terminal_frames_the_screen_and_leaving_restores_the_look()
	await _test_the_terminal_display_shows_on_the_crt()
	await _test_a_missing_knock_recording_does_not_lock_the_door()
	await _test_the_tower_street_still_builds_without_chapter_progress()
	await _test_each_round_stands_its_npc_in_reach()
	await _test_a_round_without_its_npc_stands_nobody()
	await _test_the_entry_door_shuts_behind_the_player()
	await _test_the_exit_opens_once_delivered_and_walking_out_is_reported()
	await _test_the_exit_door_stays_locked_while_another_object_is_the_exit()
	await _test_every_exit_object_stands_in_every_round()
	await _test_an_object_answers_f_only_once_it_is_the_exit()
	await _test_every_exit_object_leaves_through_one_shared_transition()
	await _test_settings_hold_the_exit_transition()
	await _test_a_new_round_starts_again_at_the_top_of_the_stairs()
	await _test_the_fifth_exit_leads_to_the_white_door_passage()
	await _test_walking_into_the_light_is_reported_once_and_walks_the_player_through()
	await _test_the_phone_lies_on_the_table_until_it_is_picked_up()
	await _test_an_owned_phone_is_not_laid_on_the_table_again()


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


func _test_the_crt_answers_in_reach_in_the_basement_only() -> void:
	var adapter = await _adapter(_basement())
	_stand_at_terminal(adapter)
	adapter.refresh_nearby_actor(_deps(_basement()))
	var outcome: Dictionary = adapter.nearby_outcome()
	_assert_eq(str(outcome.get("kind")), "terminal", "the CRT should answer in reach in the basement")
	_assert_eq(str(outcome.get("action")), "enter_terminal", "the CRT's action should be to enter it")
	_assert_true(adapter.chapter_contains(adapter.chapter_terminal_position()), "the CRT's reach should stand inside the room")
	adapter.player.position = adapter.chapter_terminal_position() + Vector3(0.0, 0.0, -3.0)
	adapter.refresh_nearby_actor(_deps(_basement()))
	_assert_eq(str(adapter.nearby_outcome().get("kind")), "none", "the CRT should not answer from across the room")
	await _free(adapter)
	var opening = await _adapter(ProgressScript.initial())
	_assert_eq(opening.chapter_terminal_position(), Vector3.ZERO, "the opening should have no CRT")
	_assert_eq(opening.terminal_screen_uv(Vector3.ZERO, Vector3.FORWARD), Vector2(-1, -1), "the opening should have no screen to point at")
	await _free(opening)


func _test_the_terminal_frames_the_screen_and_leaving_restores_the_look() -> void:
	var adapter = await _adapter(_basement())
	_stand_at_terminal(adapter)
	adapter.refresh_nearby_actor(_deps(_basement()))
	adapter.yaw = 37.0
	adapter.pitch = -10.0
	var entered: Dictionary = adapter.apply_interaction({"action": "enter_terminal"})
	_assert_eq(str(entered.get("kind")), "terminal", "entering should report a terminal outcome")
	_assert_true(bool(entered.get("interaction_active")), "the terminal should hold the player")
	var pose: Dictionary = adapter.pose()
	_assert_true(pose.has("view_position"), "the terminal should name where the view pushes in to")
	var view: Vector3 = pose.get("view_position", Vector3.ZERO)
	var centre: Vector2 = adapter.terminal_screen_uv(view, _look_direction(pose))
	_assert_true(centre.distance_to(Vector2(0.5, 0.5)) < 0.1, "the pushed-in view should look at the screen's middle: %s" % str(centre))
	_assert_true(view.distance_to(adapter.chapter_terminal_position()) < 2.0, "the pushed-in view should stay at the CRT")
	_assert_eq(adapter.terminal_screen_uv(view, -_look_direction(pose)), Vector2(-1, -1), "a ray away from the screen should miss it")
	adapter.refresh_nearby_actor(_deps(_basement()))
	_assert_eq(str(adapter.nearby_outcome().get("kind")), "none", "nothing else should answer while in the terminal")
	var left: Dictionary = adapter.apply_interaction({"action": "end"})
	_assert_eq(str(left.get("kind")), "none", "leaving should end the terminal")
	_assert_near(float(adapter.pose().get("yaw")), 37.0, 0.001, "leaving should restore the yaw")
	_assert_near(float(adapter.pose().get("pitch")), -10.0, 0.001, "leaving should restore the pitch")
	_assert_true(not adapter.pose().has("view_position"), "leaving should hand the view back to the player")
	adapter.player.position = adapter.chapter_terminal_position() + Vector3(0.0, 0.0, -3.0)
	adapter.refresh_nearby_actor(_deps(_basement()))
	adapter.apply_interaction({"action": "enter_terminal"})
	_assert_eq(str(adapter.interaction_outcome().get("kind")), "none", "the terminal should not open from afar")
	_stand_at_terminal(adapter)
	adapter.refresh_nearby_actor(_deps(_basement()))
	adapter.apply_interaction({"action": "enter_terminal"})
	adapter.rebuild_floor({"day_progress": {"tower_floor": 1, "day": 1}, "chapter_one_progress": ProgressScript.tower(), "view_state": "npc_up"})
	_assert_eq(str(adapter.interaction_outcome().get("kind")), "none", "a stage rebuilt away from the CRT should end the terminal")
	_assert_true(not adapter.pose().has("view_position"), "a rebuilt stage should hand the view back")
	await _free(adapter)


func _test_the_terminal_display_shows_on_the_crt() -> void:
	var adapter = await _adapter(_basement())
	var texture := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGB8))
	adapter.show_terminal_display(texture, false)
	var screen := adapter.get_parent().find_child("*Screen_Video", true, false) as MeshInstance3D
	_assert_true(screen != null, "the basement should carry the CRT's screen")
	if screen == null:
		await _free(adapter)
		return
	var material := screen.get_surface_override_material(0) as ShaderMaterial
	_assert_true(material != null, "the screen should show the terminal display")
	if material != null:
		_assert_eq(material.get_shader_parameter("content_texture"), texture, "the screen should show the given display")
		_assert_eq(material.get_shader_parameter("vhs_enabled"), false, "the screen's VHS should follow its own setting")
		adapter.show_terminal_display(texture, true)
		_assert_eq(material.get_shader_parameter("vhs_enabled"), true, "turning the terminal VHS on should reach the screen")
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


func _test_each_round_stands_its_npc_in_reach() -> void:
	var labels := ["护灯人", "迟到者", "回声住户", "抄写员", "无名信徒"]
	for round_number in range(1, ProgressScript.BASEMENT_ROUND_COUNT + 1):
		var progress := ProgressScript.jump_to_round(ProgressScript.initial(), round_number)
		var adapter = await _adapter(progress)
		adapter.refresh_nearby_actor(_deps(progress))
		_assert_eq(str(adapter.nearby_outcome().get("kind")), "none", "round %d's NPC should be out of reach from the stairs" % round_number)
		var npc: Vector3 = adapter.chapter_npc_position()
		adapter.player.position = Vector3(npc.x, adapter.player.position.y, npc.z + 1.2)
		adapter.refresh_nearby_actor(_deps(progress))
		var nearby: Dictionary = adapter.nearby_outcome()
		_assert_eq(str(nearby.get("action")), "converse", "round %d's NPC should answer in reach" % round_number)
		_assert_eq(str(nearby.get("actor_type")), "basement_npc", "round %d's NPC should be the basement NPC" % round_number)
		_assert_eq(str(nearby.get("actor_label")), labels[round_number - 1], "round %d should stand its own NPC" % round_number)
		var talking: Dictionary = adapter.apply_interaction({"action": "converse", "actor_id": str(nearby.get("actor_id")), "accepted": true})
		_assert_true(bool(talking.get("interaction_active")), "round %d's NPC should start a conversation" % round_number)
		await _free(adapter)


## A room that does not open by the NPC's conversation (#120) stands no NPC: nothing answers where it would stand.
func _test_a_round_without_its_npc_stands_nobody() -> void:
	var progress := ProgressScript.jump_to_round(ProgressScript.initial(), 1)
	var deps := _deps(progress)
	deps["basement_npc_stands"] = false
	var adapter = await _adapter_with(deps)
	_assert_true(adapter.get_parent().find_child("BasementNPC", true, false) == null, "a round without its NPC should build none")
	_assert_true(adapter.get_parent().find_child("BasementRoom", true, false) != null, "the round should still build its room")
	adapter.player.position = Vector3(0.0, adapter.player.position.y, -2.5)
	adapter.refresh_nearby_actor(deps)
	_assert_eq(str(adapter.nearby_outcome().get("kind")), "none", "nothing should answer where the NPC would stand")
	await _free(adapter)


func _test_the_entry_door_shuts_behind_the_player() -> void:
	var progress := ProgressScript.jump_to_round(ProgressScript.initial(), 1)
	var adapter = await _adapter(progress)
	var entry := adapter.get_parent().find_child("EntryDoorPivot", true, false) as Node3D
	_assert_true(entry != null and absf(entry.rotation_degrees.y) > 45.0, "the entry door should stand open when the round starts")
	Input.action_press("reality_forward")
	for frame in 150:
		adapter.update_player(1.0 / 60.0, _deps(progress))
		await physics_frame
	Input.action_release("reality_forward")
	for frame in 90:
		await process_frame
	_assert_true(entry != null and absf(entry.rotation_degrees.y) < 1.0, "the entry door should shut once the player goes down the stairs")
	await _free(adapter)


func _test_the_room_state_changes_the_basement() -> void:
	var progress := ProgressScript.jump_to_round(ProgressScript.initial(), 1)
	var deps := _deps(progress)
	deps["room_state"] = {"brightness": 1.0, "hum": 0.0, "objects": {"exit_lamp": false}}
	var adapter = await _adapter_with(deps)
	adapter.ensure_floor_current(deps)
	var stage: Node = root.find_child("ChapterOneStage", true, false)
	var light := stage.get_node("BasementMainLight") as OmniLight3D
	var ambient := (stage.get_node("ChapterOneEnvironment") as WorldEnvironment).environment
	var lamp := stage.get_node("ExitLamp") as Node3D
	var plain_light := light.light_energy
	var plain_ambient := ambient.ambient_light_energy
	_assert_true(not lamp.visible, "the exit lamp should stay away until the room has it")
	deps["room_state"] = {"brightness": 1.5, "hum": 0.0, "objects": {"exit_lamp": true}}
	adapter.ensure_floor_current(deps)
	_assert_true(is_equal_approx(light.light_energy, plain_light * 1.5), "the brightness should scale the lights")
	_assert_true(is_equal_approx(ambient.ambient_light_energy, plain_ambient * 1.5), "the brightness should scale the ambient light")
	_assert_true(lamp.visible, "the room's object should appear")
	await _free(adapter)
	var saved = await _adapter_with(deps)
	stage = root.find_child("ChapterOneStage", true, false)
	_assert_true((stage.get_node("ExitLamp") as Node3D).visible, "a stage built from a changed room should show it at once")
	await _free(saved)


func _test_the_exit_opens_once_delivered_and_walking_out_is_reported() -> void:
	var progress := ProgressScript.jump_to_round(ProgressScript.initial(), 2)
	var adapter = await _adapter(progress)
	_exits_crossed = 0
	var exit: Vector3 = adapter.chapter_exit_position()
	await _walk_out(adapter, exit, progress)
	_assert_eq(_exits_crossed, 0, "a shut exit should not be walked through")
	var walked: Vector3 = adapter.pose().get("player_position")
	_assert_true(walked.x > exit.x, "a shut exit should hold the player inside: %s" % str(walked))
	var delivered := ProgressScript.deliver(progress, ["door"])
	adapter.ensure_floor_current(_deps(delivered))
	for frame in 150:
		await process_frame
	await _walk_out(adapter, exit, delivered)
	_assert_eq(_exits_crossed, 1, "walking out through the open exit should be reported once")
	await _free(adapter)


func _test_the_exit_door_stays_locked_while_another_object_is_the_exit() -> void:
	var progress := ProgressScript.deliver(ProgressScript.jump_to_round(ProgressScript.initial(), 2), ["chair"])
	var adapter = await _adapter(progress)
	_exits_crossed = 0
	for frame in 150:
		await process_frame
	var pivot := adapter.get_parent().find_child("ExitDoorPivot", true, false) as Node3D
	_assert_true(absf(pivot.rotation_degrees.y) < 0.01, "the exit door should stay locked while only the chair is the exit")
	var exit: Vector3 = adapter.chapter_exit_position()
	await _walk_out(adapter, exit, progress)
	_assert_eq(_exits_crossed, 0, "the locked door should not be walked through")
	adapter.player.position = Vector3(exit.x + 0.5, 0.1, exit.z)
	adapter.refresh_nearby_actor(_deps(progress))
	_assert_true(str(adapter.nearby_outcome().get("object", "")) != "door", "the locked door should offer no way out")
	await _free(adapter)


func _test_every_exit_object_stands_in_every_round() -> void:
	for round_number in range(1, ProgressScript.BASEMENT_ROUND_COUNT + 1):
		var adapter = await _adapter(ProgressScript.jump_to_round(ProgressScript.initial(), round_number))
		for object_name: String in RoomContentScript.EXIT_OBJECTS:
			var reaches: Array = adapter.chapter_exit_reaches(object_name)
			_assert_true(not reaches.is_empty(), "round %d should stand the %s" % [round_number, object_name])
			for reach: Vector3 in reaches:
				_assert_true(adapter.chapter_contains(reach), "round %d's %s should be reachable inside the room: %s" % [round_number, object_name, reach])
		_assert_true(adapter.chapter_exit_reaches("chair").size() >= 3, "every chair of the room should count")
		_assert_true(adapter.chapter_exit_reaches("table").size() >= 2, "every table of the room should count")
		_assert_true(adapter.chapter_exit_reaches("light").size() >= 2, "every lamp of the room should count")
		_assert_eq(adapter.chapter_exit_reaches("piano"), [], "an object the room lacks should stand nowhere")
		_assert_true(adapter.get_parent().find_child("BasementClock", true, false) != null, "round %d should hang a clock" % round_number)
		await _free(adapter)


func _test_an_object_answers_f_only_once_it_is_the_exit() -> void:
	var fresh := ProgressScript.jump_to_round(ProgressScript.initial(), 1)
	var adapter = await _adapter(fresh)
	for object_name: String in RoomContentScript.EXIT_OBJECTS:
		var open := ProgressScript.deliver(fresh, [object_name])
		for reach: Vector3 in adapter.chapter_exit_reaches(object_name):
			adapter.player.position = Vector3(reach.x, adapter.player.position.y, reach.z)
			adapter.refresh_nearby_actor(_deps(fresh))
			_assert_true(str(adapter.nearby_outcome().get("kind")) != "exit", "the %s should offer no way out before its rule holds" % object_name)
			adapter.refresh_nearby_actor(_deps(open))
			var nearby: Dictionary = adapter.nearby_outcome()
			_assert_eq(str(nearby.get("kind")), "exit", "the %s at %s should answer F once it is the exit" % [object_name, reach])
			_assert_eq(str(nearby.get("action")), "leave_by_exit", "the exit's action should be to leave by it")
			_assert_eq(str(nearby.get("object")), object_name, "the exit should name its object")
	var reach: Vector3 = adapter.chapter_exit_reaches("chair")[0]
	adapter.player.position = Vector3(reach.x + 4.0, adapter.player.position.y, reach.z)
	adapter.refresh_nearby_actor(_deps(ProgressScript.deliver(fresh, ["chair"])))
	_assert_true(str(adapter.nearby_outcome().get("kind")) != "exit", "the chair should not answer from afar")
	await _free(adapter)


func _test_every_exit_object_leaves_through_one_shared_transition() -> void:
	var fresh := ProgressScript.jump_to_round(ProgressScript.initial(), 1)
	var durations: Array = []
	for object_name: String in RoomContentScript.EXIT_OBJECTS:
		var open := ProgressScript.deliver(fresh, [object_name])
		var adapter = await _adapter(open)
		var room: Node = adapter.get_parent().find_child("BasementRoom", true, false)
		var reach: Vector3 = adapter.chapter_exit_reaches(object_name)[0]
		adapter.player.position = Vector3(reach.x, adapter.player.position.y, reach.z)
		var eye: Vector3 = adapter.player.position + Vector3(0.0, 1.56, 0.0)
		adapter.refresh_nearby_actor(_deps(open))
		var leaving: Dictionary = adapter.apply_interaction({"action": "leave_by_exit", "object": object_name})
		_assert_eq(str(leaving.get("kind")), "exit", "leaving by the %s should play the exit transition" % object_name)
		_assert_true(bool(leaving.get("interaction_active")), "the transition should hold the player")
		var next := ProgressScript.leave_round(open, object_name)
		var elapsed := 0.0
		var pushed := false
		while str(adapter.interaction_outcome().get("kind")) == "exit":
			adapter.update_player(0.1, _deps(next))
			adapter.ensure_floor_current(_deps(next))
			elapsed += 0.1
			var pose: Dictionary = adapter.pose()
			if pose.has("view_position") and (pose["view_position"] as Vector3).distance_to(eye) > 0.2:
				pushed = true
			if str(adapter.interaction_outcome().get("kind")) == "exit":
				_assert_true(adapter.get_parent().find_child("BasementRoom", true, false) == room, "the %s's round should stay built while the view pushes in" % object_name)
			if elapsed > 10.0:
				break
		_assert_true(pushed, "leaving by the %s should push the view in toward it" % object_name)
		durations.append(snappedf(elapsed, 0.1))
		adapter.ensure_floor_current(_deps(next))
		await process_frame
		var rebuilt: Node = adapter.get_parent().find_child("BasementRoom", true, false)
		_assert_true(rebuilt != null and rebuilt != room, "the next round should be built once the transition ends")
		var spawn: Vector3 = adapter.pose().get("player_position")
		_assert_true(spawn.distance_to(ChapterOneStage.BASEMENT_SPAWN) < 0.01, "the %s should lead to the next round's start: %s" % [object_name, spawn])
		_assert_true(not adapter.pose().has("view_position"), "the next round should give the view back")
		await _free(adapter)
	for duration in durations:
		_assert_eq(duration, durations[0], "every exit object should share one transition: %s" % [durations])


func _test_settings_hold_the_exit_transition() -> void:
	var open := ProgressScript.deliver(ProgressScript.jump_to_round(ProgressScript.initial(), 1), ["light"])
	var adapter = await _adapter(open)
	var reach: Vector3 = adapter.chapter_exit_reaches("light")[0]
	adapter.player.position = Vector3(reach.x, adapter.player.position.y, reach.z)
	adapter.apply_interaction({"action": "leave_by_exit", "object": "light"})
	adapter.update_player(0.2, _deps(open))
	var before := float(adapter.interaction_outcome().get("progress"))
	adapter.set_paused(true)
	adapter.update_player(5.0, _deps(open))
	_assert_near(float(adapter.interaction_outcome().get("progress")), before, 0.001, "open settings should hold the transition")
	adapter.set_paused(false)
	adapter.update_player(0.2, _deps(open))
	_assert_true(float(adapter.interaction_outcome().get("progress")) > before, "closing settings should let the transition go on")
	await _free(adapter)


func _test_a_new_round_starts_again_at_the_top_of_the_stairs() -> void:
	var progress := ProgressScript.jump_to_round(ProgressScript.initial(), 1)
	var adapter = await _adapter(progress)
	var spawn: Vector3 = adapter.pose().get("player_position")
	adapter.player.position = Vector3(0.0, 0.1, 0.0)
	var next := ProgressScript.leave_round(ProgressScript.deliver(progress, ["door"]), "door")
	adapter.ensure_floor_current(_deps(next))
	await process_frame
	var restarted: Vector3 = adapter.pose().get("player_position")
	_assert_true(restarted.distance_to(spawn) < 0.01, "the next round should start at the top of the stairs: %s" % str(restarted))
	var npc: Vector3 = adapter.chapter_npc_position()
	adapter.player.position = Vector3(npc.x, adapter.player.position.y, npc.z + 1.2)
	adapter.refresh_nearby_actor(_deps(next))
	_assert_eq(str(adapter.nearby_outcome().get("actor_label")), "迟到者", "the next round should stand the next NPC")
	var entry := adapter.get_parent().find_child("EntryDoorPivot", true, false) as Node3D
	_assert_true(entry != null and absf(entry.rotation_degrees.y) > 45.0, "the next round's entry should stand open again")
	await _free(adapter)


func _test_the_fifth_exit_leads_to_the_white_door_passage() -> void:
	var fifth := ProgressScript.deliver(ProgressScript.jump_to_round(ProgressScript.initial(), 5), ["door"])
	var adapter = await _adapter(fifth)
	var passage := ProgressScript.leave_round(fifth, "door")
	adapter.ensure_floor_current(_deps(passage))
	await process_frame
	var parent: Node = adapter.get_parent()
	_assert_true(parent.find_child("OpeningWorld", true, false) != null, "the passage should reuse the opening's world")
	_assert_true(parent.find_child("BasementRoom", true, false) == null, "the passage should replace the basement")
	_assert_true(not adapter.floor.visible, "the passage should not show the tower's street")
	_assert_true(parent.find_child("OpeningKnock", true, false) == null, "the passage should have no knock")
	var door: Vector3 = adapter.chapter_door_position()
	var spawn: Vector3 = adapter.pose().get("player_position")
	_assert_true(absf(Vector2(spawn.x - door.x, spawn.z - door.z).length() - ChapterOneStage.OPENING_WALK_DISTANCE) < 0.1, "the passage should start as far from the door as the opening")
	var light := parent.find_child(ChapterOneStage.OPENING_DOOR_LIGHT_PLANE, true, false) as Node3D
	_assert_true(light != null and light.visible, "the white light should show in the doorway")
	adapter.player.position = Vector3(door.x, adapter.player.position.y, door.z + 1.0)
	adapter.refresh_nearby_actor(_deps(passage))
	_assert_eq(str(adapter.nearby_outcome().get("kind", "none")), "none", "the passage door is walked into and offers no F")
	await _free(adapter)


func _test_walking_into_the_light_is_reported_once_and_walks_the_player_through() -> void:
	var passage := ProgressScript.leave_round(ProgressScript.deliver(ProgressScript.jump_to_round(ProgressScript.initial(), 5), ["door"]), "door")
	var adapter = await _adapter(passage)
	var door: Vector3 = adapter.chapter_door_position()
	var parent: Node = adapter.get_parent()
	var light := parent.find_child(ChapterOneStage.OPENING_DOOR_LIGHT_PLANE, true, false) as Node3D
	var pivot := parent.find_child(ChapterOneStage.OPENING_DOOR_PIVOT, true, false) as Node3D
	var height: float = adapter.player.position.y
	adapter.player.position = Vector3(door.x, height, door.z + 6.0)
	adapter.update_player(0.016, _deps(passage))
	_assert_eq(_passages_entered, 0, "the door should wait for the player to walk in")
	adapter.player.position = Vector3(door.x, height, door.z + 0.9)
	adapter.update_player(0.016, _deps(passage))
	adapter.update_player(0.016, _deps(passage))
	_assert_eq(_passages_entered, 1, "walking in should be reported once")
	adapter.apply_interaction({"action": "enter_passage"})
	_assert_eq(str(adapter.interaction_outcome().get("kind")), "door", "the walk through should be a door outcome")
	var ended := ProgressScript.cross_passage(passage)
	adapter.update_player(1.0, _deps(ended))
	_assert_true(light.visible and absf(pivot.rotation_degrees.y) < 0.01, "the door should stay shut and full of light during the walk")
	adapter.update_player(2.0, _deps(ended))
	_assert_eq(str(adapter.interaction_outcome().get("kind")), "none", "the walk through should end")
	adapter.ensure_floor_current(_deps(ended))
	await process_frame
	_assert_true(parent.find_child("OpeningWorld", true, false) != null, "the demo's end should stay on the passage behind its screen")
	_assert_true(not adapter.floor.visible, "the demo's end should not build the tower's street")
	await _free(adapter)


## Stands the player in front of the exit and walks west into it.
func _test_the_phone_lies_on_the_table_until_it_is_picked_up() -> void:
	var progress := _basement()
	var deps := _deps(progress)
	deps["phone_owned"] = false
	var adapter = await _adapter_with(deps)
	var host: Node = adapter.get_parent()
	_assert_true(host.find_child("BasementTable", true, false) != null, "round one should stand a small table in the room")
	var phone: Vector3 = adapter.chapter_phone_position()
	_assert_true(phone != Vector3.ZERO, "the phone should lie on the table while nobody owns it")
	_assert_true(adapter.chapter_contains(phone), "the table should stand inside the room")
	_assert_true(phone.y > 0.5, "the phone should lie on the table, not on the floor: %s" % str(phone))
	adapter.refresh_nearby_actor(deps)
	_assert_eq(str(adapter.nearby_outcome().get("kind")), "none", "the phone should be out of reach from the stairs")
	adapter.player.position = Vector3(phone.x, adapter.player.position.y, phone.z + 0.8)
	adapter.refresh_nearby_actor(deps)
	var nearby: Dictionary = adapter.nearby_outcome()
	_assert_eq(str(nearby.get("kind")), "phone", "the phone should answer in reach")
	_assert_eq(str(nearby.get("action")), "pick_up_phone", "the phone's action should be to pick it up")
	var picked: Dictionary = adapter.apply_interaction({"action": "pick_up_phone"})
	_assert_true(not bool(picked.get("interaction_active")), "picking up the phone should not hold the player")
	_assert_eq(adapter.chapter_phone_position(), Vector3.ZERO, "the picked-up phone should leave the table")
	_assert_true(host.find_child("BasementPhone", true, false) == null, "the picked-up phone should be gone from the room")
	deps["phone_owned"] = true
	adapter.refresh_nearby_actor(deps)
	_assert_eq(str(adapter.nearby_outcome().get("kind")), "none", "nothing should be left to pick up")
	_assert_true(host.find_child("BasementTable", true, false) != null, "the table should stay")
	await _free(adapter)


func _test_an_owned_phone_is_not_laid_on_the_table_again() -> void:
	var deps := _deps(_basement())
	deps["phone_owned"] = true
	var adapter = await _adapter_with(deps)
	_assert_eq(adapter.chapter_phone_position(), Vector3.ZERO, "an owned phone should not lie on the table again")
	_assert_true(adapter.get_parent().find_child("BasementPhone", true, false) == null, "a rebuilt round should build no second phone")
	await _free(adapter)
	var unknown = await _adapter(_basement())
	_assert_eq(unknown.chapter_phone_position(), Vector3.ZERO, "deps that do not say the phone is missing should build no phone")
	await _free(unknown)
	var opening_deps := _deps(ProgressScript.initial())
	opening_deps["phone_owned"] = false
	var opening = await _adapter_with(opening_deps)
	_assert_eq(opening.chapter_phone_position(), Vector3.ZERO, "the opening should have no phone")
	await _free(opening)


func _walk_out(adapter, exit: Vector3, progress: Dictionary) -> void:
	adapter.player.position = Vector3(exit.x + 0.7, 0.1, exit.z)
	adapter.player.velocity = Vector3.ZERO
	adapter.yaw = 90.0
	Input.action_press("reality_forward")
	for frame in 120:
		adapter.update_player(1.0 / 60.0, _deps(progress))
		await physics_frame
	Input.action_release("reality_forward")


func _adapter(progress: Dictionary):
	return await _adapter_with(_deps(progress))


func _adapter_with(deps: Dictionary):
	var host := Node3D.new()
	host.name = "ChapterStageHost"
	root.add_child(host)
	var adapter = RealitySceneAdapterScript.new()
	adapter.attach_to(host)
	adapter.build_world_nodes()
	adapter.rebuild_floor(deps)
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


func _stand_at_terminal(adapter) -> void:
	var reach: Vector3 = adapter.chapter_terminal_position()
	adapter.player.position = Vector3(reach.x, adapter.player.position.y, reach.z)


func _basement() -> Dictionary:
	return ProgressScript.open_door(ProgressScript.complete_knock(_read_to_end(_at_line(ProgressScript.KNOCK_LINE_INDEX))))


func _look_direction(pose: Dictionary) -> Vector3:
	var look := Basis.from_euler(Vector3(deg_to_rad(float(pose.get("pitch"))), deg_to_rad(float(pose.get("yaw"))), 0.0))
	return look * Vector3.FORWARD


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
