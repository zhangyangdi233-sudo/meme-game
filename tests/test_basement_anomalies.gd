extends SceneTree
## #114: the basement's five rounds each show their anomaly, read from the room data through the Reality scene adapter.
## Round one hangs one clock; round two whispers and flickers once, 2.5 s after the entry shuts; round three's outage
## leaves only the CRT's green until the wall switch brings the light back over a seeded pile of chairs; round four hangs
## a wall of clocks; round five's half clock hides its numbers from all but the X-ray, and the room's middle turns every
## light and screen black, then red. Events start once, are reported once, and their clock stops while the world is held.

const RealitySceneAdapterScript = preload("res://scripts/world/reality_scene_adapter.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const GameEventsScript = preload("res://scripts/game_events.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RoomContentScript = preload("res://scripts/game/room_content.gd")
const RoomRulesScript = preload("res://scripts/game/room_rules.gd")
const DecorScript = preload("res://scripts/game/basement_decor.gd")

const STEP := 1.0 / 30.0

var _failures: Array[String] = []
var _started: Array = []


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	await _run()
	RegistryScript.clear()
	if _failures.is_empty():
		print("basement anomalies tests passed")
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
	await _test_round_one_hangs_one_clock_under_normal_light()
	await _test_round_two_whispers_once_after_the_entry_shuts()
	await _test_a_held_world_stops_the_events_clock()
	await _test_a_started_event_is_not_played_again()
	await _test_the_switch_ends_the_whisper_early()
	await _test_round_three_goes_dark_but_keeps_the_crts_green()
	await _test_the_switch_lights_round_three_over_seeded_chairs()
	await _test_round_four_hangs_a_wall_of_clocks_over_normal_chairs()
	await _test_round_fives_missing_numbers_show_only_through_the_xray()
	await _test_round_five_turns_black_then_red_from_the_rooms_middle()
	await _test_the_exit_table_holds_the_seeds_vase_or_book()
	await _test_the_hum_follows_the_room()


func _test_round_one_hangs_one_clock_under_normal_light() -> void:
	var adapter = await _round(1)
	var stage := _stage(adapter)
	_assert_true((stage.get_node("BasementClock") as Node3D).visible, "round one should hang its wall clock")
	_assert_true(not (stage.get_node("ClockWall") as Node3D).visible, "round one should have no wall of clocks")
	_assert_eq(adapter.chapter_exit_reaches("clock").size(), 1, "round one's one clock should be the clock")
	_assert_true(_lamps_lit(stage), "round one's lamps should be lit")
	await _walk_down(adapter, 1)
	await _advance(adapter, 1, 20.0)
	_assert_eq(_started, [], "round one should play no event")
	await _free(adapter)


func _test_round_two_whispers_once_after_the_entry_shuts() -> void:
	var adapter = await _round(2)
	var stage := _stage(adapter)
	await _advance(adapter, 2, 5.0)
	_assert_eq(_started, [], "nothing should start while the entry is still open")
	await _walk_down(adapter, 2)
	await _advance(adapter, 2, 2.3)
	_assert_eq(_started, [], "the whisper should wait 2.5 s after the entry shuts")
	await _advance(adapter, 2, 0.4)
	_assert_eq(_started, ["whisper"], "the whisper should start once, reported to the state")
	_assert_true((stage.get_node("BasementWhisper") as AudioStreamPlayer).playing, "the whisper should be heard")
	var flickered := false
	for step in 60:
		await _advance(adapter, 2, 0.1)
		flickered = flickered or not _lamps_lit(stage)
	_assert_true(flickered, "the lamps should flicker with the whisper")
	await _advance(adapter, 2, 3.0)
	_assert_true(_lamps_lit(stage), "the lamps should stay lit once the 8 s are over")
	_assert_true(not (stage.get_node("BasementWhisper") as AudioStreamPlayer).playing, "the whisper should stop after its 8 s")
	await _advance(adapter, 2, 20.0)
	_assert_eq(_started, ["whisper"], "the whisper should never start again")
	await _free(adapter)


func _test_a_held_world_stops_the_events_clock() -> void:
	var adapter = await _round(2)
	await _walk_down(adapter, 2)
	var phone_up := _deps(2)
	phone_up["view_state"] = "phone_down"
	for step in 120:
		adapter.update_player(STEP, phone_up)
	_assert_eq(_started, [], "an open phone should hold the whisper's clock")
	adapter.set_paused(true)
	await _advance(adapter, 2, 4.0)
	adapter.set_paused(false)
	_assert_eq(_started, [], "open settings or a lost focus should hold the whisper's clock")
	adapter.player.position = adapter.chapter_terminal_position() + Vector3(0.0, 0.05, 0.0)
	adapter.refresh_nearby_actor(_deps(2))
	adapter.apply_interaction({"action": "enter_terminal"})
	_assert_eq(adapter.interaction_outcome().get("kind"), "terminal", "setup should enter the CRT")
	await _advance(adapter, 2, 4.0)
	_assert_eq(_started, [], "the CRT should hold the whisper's clock")
	adapter.apply_interaction({"action": "end"})
	await _advance(adapter, 2, 2.6)
	_assert_eq(_started, ["whisper"], "the clock should go on once the world is back")
	await _free(adapter)


func _test_a_started_event_is_not_played_again() -> void:
	var progress := ProgressScript.start_event(ProgressScript.jump_to_round(ProgressScript.initial(), 2), "whisper")
	var adapter = await _adapter_with(_deps(2, progress))
	var stage := _stage(adapter)
	await _walk_down(adapter, 2, progress)
	await _advance(adapter, 2, 12.0, progress)
	_assert_eq(_started, [], "a whisper the save already holds should not play again")
	_assert_true(_lamps_lit(stage), "a whisper the save already holds should not flicker")
	await _free(adapter)


func _test_the_switch_ends_the_whisper_early() -> void:
	var adapter = await _round(2)
	var stage := _stage(adapter)
	await _walk_down(adapter, 2)
	await _stand_at_switch(adapter, 2)
	_assert_true(str(adapter.nearby_outcome().get("kind")) != "switch", "the switch should offer nothing while the room is calm")
	await _advance(adapter, 2, 2.6)
	adapter.refresh_nearby_actor(_deps(2))
	var nearby: Dictionary = adapter.nearby_outcome()
	_assert_eq(nearby.get("kind"), "switch", "the switch should answer F during the whisper")
	_assert_eq(nearby.get("events"), ["whisper"], "the switch should name the event it ends")
	adapter.apply_interaction({"action": "press_switch"})
	_assert_true(_lamps_lit(stage), "the switch should end the flicker")
	_assert_true(not (stage.get_node("BasementWhisper") as AudioStreamPlayer).playing, "the switch should end the whisper")
	for step in 30:
		await _advance(adapter, 2, 0.1)
		_assert_true(_lamps_lit(stage), "an ended whisper should not flicker again")
	adapter.refresh_nearby_actor(_deps(2))
	_assert_true(str(adapter.nearby_outcome().get("kind")) != "switch", "the switch should offer nothing once the whisper is over")
	await _free(adapter)


func _test_round_three_goes_dark_but_keeps_the_crts_green() -> void:
	var adapter = await _round(3)
	var stage := _stage(adapter)
	await _walk_down(adapter, 3)
	await _advance(adapter, 3, 1.2)
	_assert_eq(_started, ["blackout"], "round three's outage should start once the player is down")
	var dark := ProgressScript.start_event(ProgressScript.jump_to_round(ProgressScript.initial(), 3), "blackout")
	adapter.ensure_floor_current(_deps(3, dark))
	_assert_true(not _lamps_lit(stage), "the outage should put every lamp out")
	var green := stage.find_child("CRT_Green_PointLight", true, false) as Light3D
	_assert_true(green != null and green.visible and green.light_energy > 0.0, "the CRT's green should stay in the dark")
	_assert_true(_original_chairs_shown(stage), "the chairs should stand normally in the dark")
	_assert_true(not (stage.get_node("ScatteredChairs") as Node3D).visible, "no pile of chairs should lie in the dark")
	await _free(adapter)


func _test_the_switch_lights_round_three_over_seeded_chairs() -> void:
	var dark := ProgressScript.start_event(ProgressScript.jump_to_round(ProgressScript.initial(), 3), "blackout")
	var adapter = await _adapter_with(_deps(3, dark))
	var stage := _stage(adapter)
	await _stand_at_switch(adapter, 3, dark)
	var nearby: Dictionary = adapter.nearby_outcome()
	_assert_eq(nearby.get("kind"), "switch", "the switch should answer F in the dark, also after a load")
	_assert_eq(nearby.get("events"), ["blackout"], "the switch should end the outage")
	adapter.apply_interaction({"action": "press_switch"})
	var lit := ProgressScript.end_events(dark, ["blackout"])
	adapter.ensure_floor_current(_deps(3, lit))
	_assert_true(_lamps_lit(stage), "the switch should bring the lamps back")
	var pile := stage.get_node("ScatteredChairs") as Node3D
	_assert_true(pile.visible, "the chairs should lie in a pile once the light is back")
	_assert_true(not _original_chairs_shown(stage), "the chairs should have left their places")
	_assert_eq(pile.get_child_count(), DecorScript.SCATTERED_CHAIR_COUNT, "the pile should reuse the room's chairs")
	_assert_true(adapter.chapter_exit_reaches("chair").size() == DecorScript.SCATTERED_CHAIR_COUNT, "any chair of the pile should count as the chair")
	var first := _chair_transforms(pile)
	await _free(adapter)
	var again = await _adapter_with(_deps(3, lit))
	_assert_eq(_chair_transforms(_stage(again).get_node("ScatteredChairs")), first, "the same seed should lay the same pile")
	await _free(again)
	var other_deps := _deps(3, lit)
	other_deps["run_seed"] = 99
	var other = await _adapter_with(other_deps)
	_assert_true(_chair_transforms(_stage(other).get_node("ScatteredChairs")) != first, "another run's seed should lay another pile")
	await _free(other)


func _test_round_four_hangs_a_wall_of_clocks_over_normal_chairs() -> void:
	var adapter = await _round(4)
	var stage := _stage(adapter)
	var wall := stage.get_node("ClockWall") as Node3D
	_assert_true(wall.visible, "round four should hang its wall of clocks")
	_assert_eq(wall.get_child_count(), 18, "the wall should hold 18 clocks")
	_assert_true(not (stage.get_node("BasementClock") as Node3D).visible, "the wall should replace the single clock")
	_assert_eq(adapter.chapter_exit_reaches("clock").size(), 18, "any clock of the wall should count as the clock")
	_assert_true(_original_chairs_shown(stage), "round four's chairs should stand normally again")
	await _free(adapter)


func _test_round_fives_missing_numbers_show_only_through_the_xray() -> void:
	var adapter = await _round(5)
	var stage := _stage(adapter)
	var half := stage.get_node("HalfClock") as Node3D
	_assert_true(half.visible, "round five should hang the half clock")
	_assert_eq(adapter.chapter_exit_reaches("clock").size(), 1, "the half clock should be the clock")
	var hidden := half.find_children("XRayNumeral*", "", true, false)
	_assert_eq(hidden.size(), 5, "the half clock should hide its five missing numbers")
	_assert_true(hidden.all(func(numeral: Node3D) -> bool: return not numeral.is_visible_in_tree()), "the missing numbers should not show in the plain view")
	adapter.set_xray_looking(true)
	_assert_true(hidden.all(func(numeral: Node3D) -> bool: return numeral.is_visible_in_tree()), "the X-ray should show the missing numbers")
	adapter.set_xray_looking(false)
	_assert_true(hidden.all(func(numeral: Node3D) -> bool: return not numeral.is_visible_in_tree()), "the numbers should hide again once the X-ray is down")
	await _free(adapter)
	var four = await _round(4)
	four.set_xray_looking(true)
	_assert_true(not (_stage(four).get_node("HalfClock") as Node3D).is_visible_in_tree(), "the X-ray should show no half clock where none hangs")
	await _free(four)


func _test_round_five_turns_black_then_red_from_the_rooms_middle() -> void:
	var adapter = await _round(5)
	var stage := _stage(adapter)
	var sunk := stage.get_node("SunkenCrts") as Node3D
	_assert_true(sunk.visible, "round five should sink its screens")
	_assert_eq(sunk.get_child_count(), 12, "twelve screens should join the CRT")
	await _walk_down(adapter, 5)
	await _advance(adapter, 5, 3.0)
	_assert_eq(_started, [], "the screens should wait for the room's middle")
	adapter.player.position = Vector3(0.0, 0.05, 0.0)
	await _advance(adapter, 5, 0.5)
	_assert_eq(_started, ["red_screens"], "reaching the middle should start the screens once")
	_assert_true(not _lamps_lit(stage), "the lamps should go black")
	_assert_true(not (stage.find_child("CRT_Green_PointLight", true, false) as Light3D).visible, "the CRT's green should go black too")
	_assert_eq(stage.screen_color(), Color.BLACK, "every screen should be black for the first 2 s")
	await _advance(adapter, 5, 2.0)
	_assert_eq(stage.screen_color(), Color.RED, "every screen should turn red")
	_assert_true(stage.find_children("RedScreenLight", "OmniLight3D", true, false).all(func(light: OmniLight3D) -> bool: return light.visible), "the screens should cast red")
	_assert_true((stage.get_node("ScreenStatic") as AudioStreamPlayer).playing, "the red should hiss")
	adapter.refresh_nearby_actor(_deps(5))
	_assert_true(str(adapter.nearby_outcome().get("kind")) != "switch", "the switch should not end the red screens")
	var hiss := stage.get_node("ScreenStatic") as AudioStreamPlayer
	var hum := stage.get_node("BasementHum") as AudioStreamPlayer
	adapter.set_paused(true)
	for frame in 5:
		adapter.ensure_floor_current(_deps(5))
		await _advance(adapter, 5, 0.1)
	_assert_true(hiss.stream_paused, "open settings should keep the hiss held while the stage refreshes")
	_assert_true(hum.stream_paused or not hum.playing, "open settings should keep the hum held while the stage refreshes")
	_assert_eq(stage.screen_color(), Color.RED, "open settings should hold the red where it is")
	adapter.set_paused(false)
	_assert_true(not hiss.stream_paused, "closing settings should let the hiss go on")
	await _advance(adapter, 5, 6.0)
	_assert_true(_lamps_lit(stage), "the lamps should come back after 8 s")
	_assert_eq(stage.screen_color(), Color(0, 0, 0, 0), "the screens should go back to what they showed")
	_assert_true(not (stage.get_node("ScreenStatic") as AudioStreamPlayer).playing, "the hiss should stop")
	adapter.player.position = Vector3(1.5, 0.05, 1.5)
	await _advance(adapter, 5, 1.0)
	adapter.player.position = Vector3(0.0, 0.05, 0.0)
	await _advance(adapter, 5, 1.0)
	_assert_eq(_started, ["red_screens"], "walking back to the middle should not play it again")
	await _free(adapter)


func _test_the_exit_table_holds_the_seeds_vase_or_book() -> void:
	var seen := {}
	for seed in [3, 5, 8, 13, 21]:
		for round_number in range(1, 6):
			var deps := _deps(round_number)
			deps["run_seed"] = seed
			var adapter = await _adapter_with(deps)
			var stage := _stage(adapter)
			var wanted := DecorScript.exit_table_prop(seed, round_number)
			var vase := stage.get_node("ExitTableVase") as Node3D
			var book := stage.get_node("ExitTableBook") as Node3D
			_assert_eq(vase.visible, wanted == "vase", "the seed should decide the vase in round %d" % round_number)
			_assert_eq(book.visible, wanted == "book", "the seed should decide the book in round %d" % round_number)
			seen[wanted] = true
			await _free(adapter)
	_assert_eq(seen.size(), 2, "the runs should show both")


func _test_the_hum_follows_the_room() -> void:
	var adapter = await _round(1)
	var hum := _stage(adapter).get_node("BasementHum") as AudioStreamPlayer
	_assert_true(hum.playing, "round one's lamps should hum")
	var louder := _deps(1)
	louder["room_state"] = {"brightness": 1.0, "hum": 1.0, "objects": {}}
	var quiet := hum.volume_db
	adapter.ensure_floor_current(louder)
	_assert_true(hum.volume_db > quiet, "a louder room should hum louder")
	var silent := _deps(1)
	silent["room_state"] = {"brightness": 1.0, "hum": 0.0, "objects": {}}
	adapter.ensure_floor_current(silent)
	_assert_true(not hum.playing, "a silent room should not hum")
	await _free(adapter)


func _round(round_number: int):
	return await _adapter_with(_deps(round_number))


func _adapter_with(deps: Dictionary):
	_started.clear()
	var host := Node3D.new()
	host.name = "AnomalyStageHost"
	root.add_child(host)
	var adapter = RealitySceneAdapterScript.new()
	adapter.attach_to(host)
	adapter.build_world_nodes()
	adapter.rebuild_floor(deps)
	await process_frame
	return adapter


## Deps as the host hands them: the round's progress, its room state derived from its data and the events so far, its
## events and the run's seed.
func _deps(round_number: int, progress: Dictionary = {}) -> Dictionary:
	var at := progress if not progress.is_empty() else ProgressScript.jump_to_round(ProgressScript.initial(), round_number)
	var room := RoomContentScript.room(round_number)
	return {
		"day_progress": {"tower_floor": 1, "day": 1},
		"chapter_one_progress": at,
		"view_state": "npc_up",
		"room_state": RoomRulesScript.world_state(room, {}, round_number, ProgressScript.started_events(at), ProgressScript.ended_events(at)),
		"room_events": room.get("events", []),
		"run_seed": 1701,
	}


func _stage(adapter) -> Node3D:
	return adapter.get_parent().find_child("ChapterOneStage", true, false) as Node3D


## Walks the player down past the point where the entry shuts behind them.
func _walk_down(adapter, round_number: int, progress: Dictionary = {}) -> void:
	adapter.player.position = Vector3(-1.0, 0.05, 1.5)
	adapter.update_player(STEP, _deps(round_number, progress))
	await physics_frame


func _advance(adapter, round_number: int, seconds: float, progress: Dictionary = {}) -> void:
	var deps := _deps(round_number, progress)
	var steps := int(round(seconds / STEP))
	for step in steps:
		adapter.update_player(STEP, deps)
	await process_frame


func _stand_at_switch(adapter, round_number: int, progress: Dictionary = {}) -> void:
	var reach: Vector3 = _stage(adapter).switch_reach_position()
	adapter.player.position = reach + Vector3(0.0, 0.05, 0.0)
	adapter.refresh_nearby_actor(_deps(round_number, progress))
	await process_frame


func _lamps_lit(stage: Node3D) -> bool:
	for light_name in ["BasementMainLight", "BasementRearLight"]:
		var light := stage.get_node(light_name) as Light3D
		if not light.visible or light.light_energy <= 0.0:
			return false
	for light_name in ["Main_PointLight", "Rear_PointLight"]:
		var light := stage.find_child(light_name, true, false) as Light3D
		if light != null and not light.visible:
			return false
	return true


func _original_chairs_shown(stage: Node3D) -> bool:
	for chair_name in ["Prop_Windsor_A", "Prop_Windsor_B", "Prop_TealChair"]:
		var chair := stage.find_child(chair_name, true, false) as Node3D
		if chair == null or not chair.visible:
			return false
	return true


func _chair_transforms(pile: Node) -> Array:
	return pile.get_children().map(func(chair: Node3D) -> Transform3D: return chair.transform)


func _free(adapter) -> void:
	var host: Node = adapter.get_parent()
	host.queue_free()
	await process_frame


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
