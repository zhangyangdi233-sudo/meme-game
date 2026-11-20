extends SceneTree
## Round one's CRT focus cinematic (the old version's first visit, restored by the planner on 2026-11-16), played by the
## Chapter stage as a Room event and read by the host through the Reality scene adapter: coming down across the middle
## of the stairs takes control once; the room goes black but for the CRT under a white spotlight, mirrored on a layer of
## its own; the look turns to the CRT over 0.8 s while the view narrows to 34 degrees; each click shows the next of the
## seven lines; after the last the room comes back, the look returns over 0.65 s and control comes back. Open settings
## hold it. It never plays twice, nor in another round.

const RealitySceneAdapterScript = preload("res://scripts/world/reality_scene_adapter.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const GameEventsScript = preload("res://scripts/game_events.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RoomContentScript = preload("res://scripts/game/room_content.gd")
const RoomRulesScript = preload("res://scripts/game/room_rules.gd")
const StageScript = preload("res://scripts/world/chapter_one_stage.gd")

const STEP := 1.0 / 30.0
const LINES := 7

var _failures: Array[String] = []
var _started: Array = []


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	await _run()
	RegistryScript.clear()
	if _failures.is_empty():
		print("crt focus tests passed")
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
	bus.subscribe(GameEventsScript.ROOM_EVENT_STARTED, func(payload: Dictionary) -> void: _started.append(payload.get(GameEventsScript.KEY_EVENT)))
	_test_round_one_authors_the_cinematic_as_a_room_event()
	await _test_coming_down_the_stairs_isolates_the_crt_and_turns_the_look()
	await _test_clicks_read_the_lines_then_control_comes_back()
	await _test_open_settings_hold_the_cinematic()
	await _test_it_never_plays_twice()
	await _test_only_coming_down_starts_it()
	await _test_no_other_round_plays_it()


func _test_round_one_authors_the_cinematic_as_a_room_event() -> void:
	var events := RoomContentScript.events(1)
	_assert_eq(events, [{"id": "crt_focus", "trigger": "stairs_descended", "cue": "crt_focus"}], "round one should list the cinematic as its event")
	_assert_true(bool(RoomContentScript.validate().get("ok", false)), "the rooms should stay valid: %s" % [RoomContentScript.validate().get("problems")])
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RoomContentScript.ROOMS_PATH))
	catalog["rooms"]["1"]["events"][0]["switch_ends"] = true
	_assert_true(not RoomContentScript.problems_in(catalog).is_empty(), "a read-through cinematic the switch could end should fail validation")


func _test_coming_down_the_stairs_isolates_the_crt_and_turns_the_look() -> void:
	var adapter = await _round(1)
	var stage := _stage(adapter)
	var before: Dictionary = adapter.pose()
	await _come_down_the_stairs(adapter, 1)
	_assert_eq(_started, ["crt_focus"], "coming down across the stairs' middle should start the cinematic once, reported to the state")
	_assert_eq(adapter.interaction_outcome().get("kind"), "crt_focus", "the cinematic should be the interaction")
	_assert_eq(adapter.interaction_outcome().get("line"), -1, "no line should show while the look turns")
	_assert_eq(adapter.pose().get("cull_mask"), StageScript.CRT_FOCUS_LAYER, "the camera should see the CRT's layer only")
	_assert_true(stage.find_child("CrtFocusMirror*", true, false) != null, "the CRT should be mirrored on its layer")
	var spot := stage.find_child("CrtFocusSpotlight", true, false) as SpotLight3D
	_assert_true(spot != null and is_equal_approx(spot.light_energy, 9.0) and is_equal_approx(spot.spot_range, 4.0) and is_equal_approx(spot.spot_angle, 48.0) and not spot.shadow_enabled, "a white spotlight of energy 9, range 4 and 48 degrees without shadow should light the CRT")
	_assert_true(spot != null and spot.global_position.y > (stage.crt_screen().center().y + 1.0), "the spotlight should hang above the glass")
	_assert_eq(_lit_lights(stage), [spot], "every other light of the room should be out")
	var environment := (stage.find_child("ChapterOneEnvironment", true, false) as WorldEnvironment).environment
	_assert_eq(environment.background_color, Color.BLACK, "the room should go black")
	_assert_true(is_zero_approx(environment.ambient_light_energy), "the room should have no ambient light")
	var position: Vector3 = adapter.player.position
	await _advance(adapter, 1, 0.9)
	_assert_true(adapter.player.position.distance_to(position) < 0.05, "the player should not move during the cinematic")
	var turned: Dictionary = adapter.pose()
	_assert_true(is_equal_approx(float(turned.get("fov", 0.0)), 34.0), "the view should narrow to 34 degrees after the turn: %s" % turned.get("fov"))
	var to_crt: Vector3 = stage.crt_screen().center() - (adapter.player.position + Vector3(0.0, RealitySceneAdapterScript.EYE_HEIGHT, 0.0))
	_assert_true(absf(angle_difference(deg_to_rad(float(turned["yaw"])), atan2(-to_crt.x, -to_crt.z))) < 0.01, "the look should face the CRT")
	_assert_eq(adapter.yaw, before["yaw"], "the player's own look should stay untouched")
	_assert_eq(adapter.interaction_outcome().get("line"), 0, "the first line should show once the look has turned")
	adapter.refresh_nearby_actor(_deps(1))
	_assert_eq(adapter.nearby_outcome().get("kind"), "none", "nothing should answer F during the cinematic")
	await _free(adapter)


func _test_clicks_read_the_lines_then_control_comes_back() -> void:
	var adapter = await _round(1)
	var stage := _stage(adapter)
	await _come_down_the_stairs(adapter, 1)
	adapter.apply_interaction({"action": "advance_crt_focus"})
	_assert_eq(adapter.interaction_outcome().get("line"), -1, "a click during the turn should show nothing")
	await _advance(adapter, 1, 0.9)
	for line in LINES - 1:
		adapter.apply_interaction({"action": "advance_crt_focus"})
		_assert_eq(adapter.interaction_outcome().get("line"), line + 1, "a click should show the next line")
	adapter.apply_interaction({"action": "enter_terminal"})
	_assert_eq(adapter.interaction_outcome().get("kind"), "crt_focus", "nothing else should start during the cinematic")
	adapter.apply_interaction({"action": "advance_crt_focus"})
	_assert_eq(adapter.interaction_outcome().get("line"), -1, "after the seventh line the look should turn back")
	_assert_true(not adapter.pose().has("cull_mask"), "the room should come back as the look turns back")
	_assert_true(stage.find_child("CrtFocusSpotlight", true, false) == null, "the spotlight should go")
	_assert_true(_lamps_lit(stage), "the room's lamps should be lit again")
	await _advance(adapter, 1, 0.3)
	_assert_eq(adapter.interaction_outcome().get("kind"), "crt_focus", "the turn back should take 0.65 s")
	await _advance(adapter, 1, 0.4)
	_assert_eq(adapter.interaction_outcome().get("kind"), "none", "control should come back after the turn back")
	_assert_true(is_equal_approx(float(adapter.pose().get("fov", 58.0)), 58.0), "the view should widen again")
	_assert_eq(adapter.pose().get("yaw"), adapter.yaw, "the look should be the player's own again")
	var environment := (stage.find_child("ChapterOneEnvironment", true, false) as WorldEnvironment).environment
	_assert_true(environment.background_color != Color.BLACK or environment.ambient_light_energy > 0.0, "the room's own environment should come back")
	_assert_eq(_started, ["crt_focus"], "the cinematic should have started once")
	await _free(adapter)


func _test_open_settings_hold_the_cinematic() -> void:
	var adapter = await _round(1)
	await _come_down_the_stairs(adapter, 1)
	adapter.set_paused(true)
	await _advance(adapter, 1, 2.0)
	_assert_eq(adapter.interaction_outcome().get("line"), -1, "open settings should hold the turn")
	adapter.set_paused(false)
	await _advance(adapter, 1, 0.9)
	adapter.set_paused(true)
	adapter.apply_interaction({"action": "advance_crt_focus"})
	_assert_eq(adapter.interaction_outcome().get("line"), 0, "a click with settings open should show no next line")
	adapter.set_paused(false)
	await _free(adapter)


func _test_it_never_plays_twice() -> void:
	var adapter = await _round(1)
	await _come_down_the_stairs(adapter, 1)
	await _advance(adapter, 1, 0.9)
	for line in LINES:
		adapter.apply_interaction({"action": "advance_crt_focus"})
	await _advance(adapter, 1, 1.0)
	adapter.player.position = Vector3(-2.5, 2.0, -0.5)
	await _advance(adapter, 1, 0.1)
	await _come_down_the_stairs(adapter, 1)
	_assert_eq(_started, ["crt_focus"], "coming down again should not replay the cinematic")
	_assert_eq(adapter.interaction_outcome().get("kind"), "none", "coming down again should keep control")
	await _free(adapter)
	var saved := ProgressScript.start_event(ProgressScript.jump_to_round(ProgressScript.initial(), 1), "crt_focus")
	adapter = await _adapter_with(_deps(1, saved))
	await _come_down_the_stairs(adapter, 1, saved)
	_assert_eq(_started, [], "a cinematic the save already holds should not play again")
	await _free(adapter)


func _test_only_coming_down_starts_it() -> void:
	var adapter = await _round(1)
	await _walk(adapter, 1, Vector3(-2.5, 1.3, 0.7), Vector3(-2.5, 1.6, 0.3))
	_assert_eq(_started, [], "going up across the middle should not start it")
	await _walk(adapter, 1, Vector3(0.5, 0.05, 0.2), Vector3(0.5, 0.05, 0.8))
	_assert_eq(_started, [], "crossing that depth in the room, off the stairs, should not start it")
	await _free(adapter)


func _test_no_other_round_plays_it() -> void:
	var adapter = await _round(2)
	await _come_down_the_stairs(adapter, 2)
	_assert_true("crt_focus" not in _started, "round two should not play the cinematic")
	_assert_true(str(adapter.interaction_outcome().get("kind")) != "crt_focus", "round two should keep control")
	await _free(adapter)


func _come_down_the_stairs(adapter, round_number: int, progress: Dictionary = {}) -> void:
	await _walk(adapter, round_number, Vector3(-2.5, 1.6, 0.3), Vector3(-2.5, 1.3, 0.7), progress)


## Stands the player at `from`, then at `to`, tracking each, then lets the events' clock run a step.
func _walk(adapter, round_number: int, from: Vector3, to: Vector3, progress: Dictionary = {}) -> void:
	var deps := _deps(round_number, progress)
	adapter.player.position = from
	adapter.player.velocity = Vector3.ZERO
	adapter.update_player(STEP, deps)
	adapter.player.position = to
	adapter.player.velocity = Vector3.ZERO
	adapter.update_player(STEP, deps)
	adapter.update_player(STEP, deps)
	await physics_frame


func _round(round_number: int):
	return await _adapter_with(_deps(round_number))


func _adapter_with(deps: Dictionary):
	_started.clear()
	var host := Node3D.new()
	host.name = "CrtFocusHost"
	root.add_child(host)
	var adapter = RealitySceneAdapterScript.new()
	adapter.attach_to(host)
	adapter.build_world_nodes()
	adapter.rebuild_floor(deps)
	await process_frame
	return adapter


func _deps(round_number: int, progress: Dictionary = {}) -> Dictionary:
	var at := progress if not progress.is_empty() else ProgressScript.jump_to_round(ProgressScript.initial(), round_number)
	var room := RoomContentScript.room(round_number)
	return {
		"day_progress": {"tower_floor": 1, "day": 1},
		"chapter_one_progress": at,
		"view_state": "npc_up",
		"room_state": RoomRulesScript.world_state(room, {}, round_number, ProgressScript.started_events(at), ProgressScript.ended_events(at)),
		"room_events": room.get("events", []),
		"basement_npc_stands": RoomRulesScript.stands_npc(room),
		"run_seed": 1701,
	}


func _advance(adapter, round_number: int, seconds: float, progress: Dictionary = {}) -> void:
	var deps := _deps(round_number, progress)
	for step in int(round(seconds / STEP)):
		adapter.update_player(STEP, deps)
	await process_frame


func _stage(adapter) -> Node3D:
	return adapter.get_parent().find_child("ChapterOneStage", true, false) as Node3D


func _lit_lights(stage: Node3D) -> Array:
	return stage.find_children("*", "Light3D", true, false).filter(func(light: Node) -> bool: return (light as Light3D).is_visible_in_tree())


func _lamps_lit(stage: Node3D) -> bool:
	for light_name in ["BasementMainLight", "BasementRearLight"]:
		if not (stage.get_node(light_name) as Light3D).visible:
			return false
	return true


func _free(adapter) -> void:
	adapter.get_parent().queue_free()
	await process_frame


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
