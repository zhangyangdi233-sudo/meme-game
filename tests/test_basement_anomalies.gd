extends SceneTree
## #114: the basement's five rounds each show their anomaly, read from the room data through the Reality scene adapter.
## Round one hangs one clock; round two whispers and flickers once, 2.5 s after the entry shuts; round three's outage
## leaves only the CRT's green until the wall switch brings the light back over a seeded pile of chairs; round four hangs
## a wall of clocks and, once, the sealed door banged from inside behind the player; round five's half clock hides its numbers from all but the X-ray, and the room's middle turns every
## light and screen black, then red. Events start once, are reported once, and their clock stops while the world is held.
## What the room shows is solid (planner, 2026-11-20): the pile's chairs and round five's sunken screens stop the player
## while they show, and the chairs the pile stands in for stop nobody. Round five's screens are the console's CRT and
## play one looping recording, which the console's glass gives up to the terminal's display and to a signal.

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
	await _test_round_four_bangs_the_sealed_door_once_after_the_player_walks_away()
	await _test_a_held_world_holds_the_door_bang_and_a_saved_bang_is_not_played_again()
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
	var hidden_screens := (stage.get_node("SunkenCrts") as Node3D).find_children("Body", "StaticBody3D", true, false)
	_assert_eq(hidden_screens.size(), 12, "the sunken screens should be built with their solid boxes")
	_assert_true(hidden_screens.all(func(body: StaticBody3D) -> bool: return body.collision_layer == 0), "screens the room does not show should stop nobody")
	_assert_true(stage.find_children("*", "VideoStreamPlayer", true, false).is_empty(), "no recording should play outside round five")
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
	_assert_true(_model_chairs_solid(stage), "the chairs standing in the dark should stop the player")
	var waiting := (stage.get_node("ScatteredChairs") as Node3D).find_children("Body", "StaticBody3D", true, false)
	_assert_true(waiting.size() == DecorScript.SCATTERED_CHAIR_COUNT and waiting.all(func(body: StaticBody3D) -> bool: return body.collision_layer == 0), "a pile the room does not show should lie ready and stop nobody: %d" % waiting.size())
	await physics_frame
	# The model's colliders are hollow meshes that only stop what comes from outside, so the ball stands beside the chair.
	var standing := stage.find_child("PropCollision_WindsorA", true, false) as CollisionObject3D
	_assert_true(_meets(stage, standing, standing.global_position + Vector3(0.45, 0.0, 0.0)), "a standing chair should be solid in the physics world")
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
	var bodies := pile.find_children("Body", "StaticBody3D", true, false)
	_assert_eq(bodies.size(), DecorScript.SCATTERED_CHAIR_COUNT, "every chair of the pile should have its solid box")
	_assert_true(bodies.all(func(body: StaticBody3D) -> bool: return body.collision_layer == 1), "the pile's chairs should stop the player")
	_assert_true(not _model_chairs_solid(stage), "the chairs that left their places should stop nobody")
	await physics_frame
	await physics_frame
	_assert_true(bodies.all(func(body: StaticBody3D) -> bool: return _meets(stage, body, body.global_position)), "every chair of the pile should be solid in the physics world")
	var plan: Dictionary = stage._floor_plan()
	var laid: Array = DecorScript.scattered_chairs(1701, plan)
	_assert_true(laid.all(func(chair: Dictionary) -> bool: return bool(chair["solid"])) and DecorScript.leaves_walkable(laid, plan), "the pile should leave the room walkable from the foot of the stairs")
	var on_the_floor := pile.get_children().map(func(chair: Node3D) -> Vector2: return Vector2(chair.position.x, chair.position.z))
	var planned := laid.map(func(chair: Dictionary) -> Vector2: return Vector2((chair["position"] as Vector3).x, (chair["position"] as Vector3).z))
	_assert_eq(on_the_floor, planned, "the pile on the floor should be the one laid for the room's own floor plan")
	_assert_true((plan["reach"] as Array).size() >= 9, "the walk should be checked to the door, the CRT, the tables, the lamps, the clock and the switch: %d" % (plan["reach"] as Array).size())
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


## The planner's old fourth-visit bang, restored now that nobody stands behind the door (2026-11-16): once the entry has
## shut and the player has come within 2.6 m of the door and walked on past it, the door is hit from inside once, with
## its leaf, knob and tape jolting at each hit, for 3 s.
func _test_round_four_bangs_the_sealed_door_once_after_the_player_walks_away() -> void:
	var adapter = await _round(4)
	var stage := _stage(adapter)
	# The planner's 2026-11-20 request: round four's door answers a talk, but only after the bang, and never knocks.
	_assert_eq(adapter.chapter_npc_position(), Vector3.ZERO, "round four's door should offer nobody to talk to before the bang")
	var early_knock := stage.find_child("SealedDoorKnock", true, false) as AudioStreamPlayer3D
	_assert_true(early_knock == null or not early_knock.playing, "nothing should knock before the bang")
	var door := stage.find_child("StairCloset_Door", true, false) as Node3D
	var rest: Vector3 = door.global_position
	await _advance(adapter, 4, 3.0)
	_assert_eq(_started, [], "the door should not bang while the entry is open")
	await _walk_down(adapter, 4)
	await _advance(adapter, 4, 3.0)
	_assert_eq(_started, [], "the door should not bang before the player came near it")
	adapter.player.position = Vector3(-1.0, 0.05, -1.0)
	await _advance(adapter, 4, 1.0)
	_assert_eq(_started, [], "the door should not bang while the player is near it")
	adapter.player.position = Vector3(-1.0, 0.05, -0.2)
	await _advance(adapter, 4, 0.5)
	_assert_eq(_started, [], "walking away while still inside 2.6 m should not bang yet")
	adapter.player.position = Vector3(-1.0, 0.05, 1.5)
	var deps := _deps(4)
	var elapsed := -1.0
	var shaken: Array = []
	var rested_early := true
	var rested_late := true
	for step in 140:
		adapter.update_player(STEP, deps)
		if elapsed < 0.0 and not _started.is_empty():
			elapsed = 0.0
		elif elapsed >= 0.0:
			elapsed += STEP
		if elapsed < 0.0:
			continue
		var offset: float = (door.global_position - rest).x
		_assert_true(absf(offset) <= 0.0125 and absf((door.global_position - rest).z) < 0.0001, "the door should jolt along its normal by at most 1.2 cm")
		for hit_start in [0.0, 0.42, 0.84, 1.94]:
			if elapsed > hit_start + 0.02 and elapsed < hit_start + 0.16 and absf(offset) > 0.001:
				shaken.append(hit_start)
		if (elapsed > 0.25 and elapsed < 0.38) or (elapsed > 1.1 and elapsed < 1.9):
			rested_early = rested_early and absf(offset) < 0.0001
		if elapsed > 2.3:
			rested_late = rested_late and absf(offset) < 0.0001
	_assert_eq(_started, ["door_bang"], "the bang should start once and be reported to the state")
	_assert_true(adapter.chapter_npc_position() != Vector3.ZERO, "after the bang round four's door should offer the talk")
	for hit_start in [0.0, 0.42, 0.84, 1.94]:
		_assert_true(hit_start in shaken, "the door should jolt at %.2f s" % hit_start)
	_assert_true(rested_early, "the door should be still between its hits")
	_assert_true(rested_late, "the door should be back at rest once the bang is over")
	var knock := stage.find_child("SealedDoorKnock", true, false) as AudioStreamPlayer3D
	_assert_true(knock != null, "the bang should play the knocking recording from the door")
	if knock != null:
		_assert_true(knock.stream != null and not knock.playing, "the recording should have played and stopped after its 3 s piece")
		_assert_true(knock.attenuation_filter_cutoff_hz < 2000.0, "the knocking should be muffled, heard through the door")
		_assert_true(knock.position.distance_to(ChapterOneStage.SEALED_DOOR_ANCHOR) < 1.5, "the knocking should come from the sealed door")
	adapter.player.position = Vector3(-1.0, 0.05, -1.0)
	await _advance(adapter, 4, 1.0)
	adapter.player.position = Vector3(-1.0, 0.05, 1.5)
	await _advance(adapter, 4, 1.0)
	_assert_eq(_started, ["door_bang"], "the door should bang only once a run")
	await _free(adapter)


func _test_a_held_world_holds_the_door_bang_and_a_saved_bang_is_not_played_again() -> void:
	var adapter = await _round(4)
	var stage := _stage(adapter)
	await _walk_down(adapter, 4)
	adapter.player.position = Vector3(-1.0, 0.05, -1.0)
	await _advance(adapter, 4, 0.5)
	adapter.player.position = Vector3(-1.0, 0.05, 1.5)
	var phone_up := _deps(4)
	phone_up["view_state"] = "phone_down"
	for step in 120:
		adapter.update_player(STEP, phone_up)
	_assert_eq(_started, [], "an open phone should hold the door's bang")
	await _advance(adapter, 4, 0.1)
	_assert_eq(_started, ["door_bang"], "the bang should come once the world is back")
	var knock := stage.find_child("SealedDoorKnock", true, false) as AudioStreamPlayer3D
	_assert_true(knock != null and knock.playing, "the bang should sound")
	# A 3D player registers its playback on a physics frame, and the engine only keeps the paused flag of a registered
	# playback: without these frames the read below depended on frame timing and failed now and then.
	await physics_frame
	await physics_frame
	for step in 60:
		adapter.update_player(STEP, phone_up)
	_assert_true(knock.stream_paused, "an open phone should hold the bang's sound where its shaking stops")
	await _advance(adapter, 4, 0.1)
	_assert_true(not knock.stream_paused, "the sound should go on with the world")
	await _free(adapter)
	var progress := ProgressScript.start_event(ProgressScript.jump_to_round(ProgressScript.initial(), 4), "door_bang")
	adapter = await _adapter_with(_deps(4, progress))
	await _walk_down(adapter, 4, progress)
	adapter.player.position = Vector3(-1.0, 0.05, -1.0)
	await _advance(adapter, 4, 0.5, progress)
	adapter.player.position = Vector3(-1.0, 0.05, 1.5)
	await _advance(adapter, 4, 6.0, progress)
	_assert_eq(_started, [], "a bang the save already holds should not play again")
	# Round four's door NPC (planner, 2026-11-20) builds the door's sound player up front; it must stay silent.
	var saved_knock := _stage(adapter).find_child("SealedDoorKnock", true, false) as AudioStreamPlayer3D
	_assert_true(saved_knock == null or not saved_knock.playing, "a bang the save already holds should make no sound")
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
	var console_glass := stage.find_child("*Screen_Video", true, false) as MeshInstance3D
	var sunken_glass := sunk.get_child(0).get_node("Glass") as MeshInstance3D
	_assert_true(sunken_glass.mesh == console_glass.mesh, "a sunken screen should be the console's CRT")
	var cabinet := sunk.get_child(0).get_node("Cabinet") as MeshInstance3D
	_assert_true(cabinet.mesh.get_surface_count() >= 1 and cabinet.get_active_material(0) == (stage.find_child("Prop_CRT_TV_CRT_Channel_Knob", true, false) as MeshInstance3D).get_active_material(0), "a sunken screen's cabinet should wear the console CRT's material")
	var screen_bodies := sunk.find_children("Body", "StaticBody3D", true, false)
	_assert_true(screen_bodies.size() == 12 and screen_bodies.all(func(body: StaticBody3D) -> bool: return body.collision_layer == 1), "the sunken screens should stop the player")
	await physics_frame
	await physics_frame
	_assert_true(screen_bodies.all(func(body: StaticBody3D) -> bool: return _meets(stage, body, body.global_position)), "every sunken screen should be solid in the physics world")
	var players := stage.find_children("*", "VideoStreamPlayer", true, false)
	_assert_eq(players.size(), 13, "every sunken screen and the console's CRT should have its player of the recording")
	_assert_true(players.all(func(player: VideoStreamPlayer) -> bool: return player.is_playing() and player.loop and player.volume_db <= -60.0), "the recording should play on every screen, looping and muted")
	var recording := sunken_glass.get_surface_override_material(0) as ShaderMaterial
	_assert_true(recording != null and recording.get_shader_parameter("content_texture") is ViewportTexture, "a sunken screen's glass should show the recording")
	var console_recording := console_glass.get_surface_override_material(0) as ShaderMaterial
	_assert_true(console_recording != null and console_recording != recording and console_recording.get_shader_parameter("content_texture") is ViewportTexture, "the console's CRT should show the recording from its own place")
	var display := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGB8))
	adapter.show_terminal_display(display, false)
	_assert_eq((console_glass.get_surface_override_material(0) as ShaderMaterial).get_shader_parameter("content_texture"), display, "the terminal's display should take the console's glass from the recording")
	stage.crt_screen().clear_display()
	_assert_eq(console_glass.get_surface_override_material(0), console_recording, "the recording should come back once the terminal lets the glass go")
	await _walk_down(adapter, 5)
	await _advance(adapter, 5, 3.0)
	_assert_eq(_started, [], "the screens should wait for the room's middle")
	adapter.player.position = Vector3(0.0, 0.05, 0.0)
	await _advance(adapter, 5, 0.5)
	_assert_eq(_started, ["red_screens"], "reaching the middle should start the screens once")
	_assert_true(not _lamps_lit(stage), "the lamps should go black")
	_assert_true(not (stage.find_child("CRT_Green_PointLight", true, false) as Light3D).visible, "the CRT's green should go black too")
	_assert_eq(stage.screen_color(), Color.BLACK, "every screen should be black for the first 2 s")
	_assert_true((sunken_glass.get_surface_override_material(0) as StandardMaterial3D).albedo_color == Color.BLACK and (console_glass.get_surface_override_material(0) as StandardMaterial3D).albedo_color == Color.BLACK, "the black should cover the recording on every glass")
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
	_assert_true(sunken_glass.get_surface_override_material(0) == recording and console_glass.get_surface_override_material(0) == console_recording, "the recording should show again on every glass")
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
		"basement_npc_stands": RoomRulesScript.stands_npc(room) or RoomRulesScript.door_npc(room),
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
	return true


func _original_chairs_shown(stage: Node3D) -> bool:
	for chair_name in ["Prop_Windsor_A", "Prop_Windsor_B"]:
		var chair := stage.find_child(chair_name, true, false) as Node3D
		if chair == null or not chair.visible:
			return false
	return true


func _model_chairs_solid(stage: Node3D) -> bool:
	for collider_name in ["PropCollision_WindsorA", "PropCollision_WindsorB"]:
		var body := stage.find_child(collider_name, true, false) as CollisionObject3D
		if body == null or body.collision_layer != 1:
			return false
	return true


## Whether a ball of 0.3 m at `at`, on the player's layer, meets `body` itself (not the floor or a wall beside it).
func _meets(stage: Node3D, body: CollisionObject3D, at: Vector3) -> bool:
	var ball := SphereShape3D.new()
	ball.radius = 0.3
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.transform = Transform3D(Basis.IDENTITY, at)
	query.collision_mask = 1
	for hit: Dictionary in stage.get_world_3d().direct_space_state.intersect_shape(query, 16):
		if hit.get("collider") == body:
			return true
	return false


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
