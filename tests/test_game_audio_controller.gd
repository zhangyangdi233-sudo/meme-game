extends SceneTree
## Game audio controller: it subscribes to SFX_REQUESTED itself and plays the cue's one-shot; a settled day re-syncs the mix.
## Does not load the main scene.

const GameAudioControllerScript = preload("res://scripts/integrations/game_audio_controller.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const GameEventsScript = preload("res://scripts/game_events.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_cue_plays_its_player()
	_test_repeated_cue_restarts_instead_of_stacking()
	_test_unknown_cue_plays_nothing()
	_test_controller_out_of_the_tree_stops_listening()
	_test_cover_watcher_appearance_plays_the_stinger()
	_test_cover_watcher_vanishing_lets_the_stinger_finish()
	await _test_settled_day_resyncs_the_mix_from_the_host_state()
	await _test_settled_day_reads_the_mix_after_every_listener()
	await _test_controller_out_of_the_tree_ignores_a_settled_day()
	RegistryScript.clear()
	if _failures.is_empty():
		print("game audio controller tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _mount() -> Dictionary:
	RegistryScript.clear()
	var bus: GameEventBus = GameEventBusScript.new()
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	var host := Node.new()
	root.add_child(host)
	var controller = GameAudioControllerScript.new()
	controller.attach_to(host)
	controller.build_players({})
	return {"host": host, "controller": controller, "bus": bus}


func _cue(cue: String) -> void:
	GameEventBusScript.raise_event(GameEventsScript.SFX_REQUESTED, {GameEventsScript.KEY_CUE: cue})


func _test_cue_plays_its_player() -> void:
	var mounted := _mount()
	var controller = mounted["controller"]
	_cue(GameEventsScript.CUE_PICKUP_PRESS)
	_assert_true(controller.pickup_press_audio.playing, "the pickup press cue should play the press sound")
	_assert_true(not controller.pickup_land_audio.playing, "the press cue should leave the land sound alone")
	_cue(GameEventsScript.CUE_PICKUP_LAND)
	_cue(GameEventsScript.CUE_NOTEBOOK_HINGE)
	_assert_true(controller.pickup_land_audio.playing, "the pickup land cue should play the land sound")
	_assert_true(controller.notebook_hinge_audio.playing, "the notebook hinge cue should play the hinge sound")
	(mounted["host"] as Node).free()


func _test_repeated_cue_restarts_instead_of_stacking() -> void:
	var mounted := _mount()
	var controller = mounted["controller"]
	var press: AudioStreamPlayer = controller.pickup_press_audio
	_cue(GameEventsScript.CUE_PICKUP_PRESS)
	press.seek(0.05)
	_assert_true(press.get_playback_position() > 0.04, "sanity: the press sound can be moved past its start")
	_cue(GameEventsScript.CUE_PICKUP_PRESS)
	_assert_true(press.playing, "a repeated cue should still be playing")
	_assert_true(press.get_playback_position() < 0.01, "a repeated cue should start the sound over")
	_assert_eq(press.max_polyphony, 1, "a repeated cue should replace the voice, not stack a second one")
	(mounted["host"] as Node).free()


func _test_unknown_cue_plays_nothing() -> void:
	var mounted := _mount()
	var controller = mounted["controller"]
	_cue("no_such_cue")
	for player in [controller.pickup_press_audio, controller.pickup_land_audio, controller.notebook_hinge_audio]:
		_assert_true(not (player as AudioStreamPlayer).playing, "an unknown cue should play nothing")
	(mounted["host"] as Node).free()


func _test_controller_out_of_the_tree_stops_listening() -> void:
	var mounted := _mount()
	var host: Node = mounted["host"]
	var controller = mounted["controller"]
	host.remove_child(controller)
	_cue(GameEventsScript.CUE_PICKUP_PRESS)
	_assert_true(not controller.pickup_press_audio.playing, "a controller out of the tree should not hear cues")
	host.add_child(controller)
	_cue(GameEventsScript.CUE_PICKUP_PRESS)
	_assert_true(controller.pickup_press_audio.playing, "a controller back in the tree should hear cues again")
	controller.free()
	_cue(GameEventsScript.CUE_PICKUP_PRESS)
	host.free()


func _test_cover_watcher_appearance_plays_the_stinger() -> void:
	var mounted := _mount()
	var controller = mounted["controller"]
	GameEventBusScript.raise_event(GameEventsScript.COVER_WATCHER_APPEARED, {GameEventsScript.KEY_FLOOR: 2})
	_assert_true(controller.cover_watcher_stinger.playing, "a watcher appearance should play the stinger")
	(mounted["host"] as Node).remove_child(controller)
	controller.cover_watcher_stinger.stop()
	GameEventBusScript.raise_event(GameEventsScript.COVER_WATCHER_APPEARED, {GameEventsScript.KEY_FLOOR: 2})
	_assert_true(not controller.cover_watcher_stinger.playing, "a controller out of the tree should not hear the appearance")
	controller.free()
	(mounted["host"] as Node).free()


## The stinger is allowed to finish after the figure has withdrawn.
func _test_cover_watcher_vanishing_lets_the_stinger_finish() -> void:
	var mounted := _mount()
	var controller = mounted["controller"]
	GameEventBusScript.raise_event(GameEventsScript.COVER_WATCHER_APPEARED, {GameEventsScript.KEY_FLOOR: 2})
	GameEventBusScript.raise_event(GameEventsScript.COVER_WATCHER_VANISHED, {GameEventsScript.KEY_FLOOR: 2})
	_assert_true(controller.cover_watcher_stinger.playing, "a vanished watcher should let the stinger finish")
	(mounted["host"] as Node).free()


func _settled_run_deps() -> Dictionary:
	return {
		"game": RefCounted.new(),
		"game_started": true,
		"day_progress": {"tower_floor": 1},
		"phone_shell": {"view_state": "phone_down"},
		"reality_interaction_active": false,
		"reality_conversation": {},
		"pollution_stage": {"music_db": -20.0},
	}


func _settle_day() -> void:
	GameEventBusScript.raise_event(GameEventsScript.DAY_SETTLED, {GameEventsScript.KEY_DAY: 2, GameEventsScript.KEY_FROM_FLASHBACK: false})


func _test_settled_day_resyncs_the_mix_from_the_host_state() -> void:
	var mounted := _mount()
	var controller = mounted["controller"]
	controller.set_state_source(_settled_run_deps)
	_assert_eq(float(controller.pollution_ambience.get_meta("target_volume_db", 0.0)), -60.0, "sanity: the mix should start silent before a run")
	_settle_day()
	await process_frame
	_assert_eq(float(controller.pollution_ambience.get_meta("target_volume_db", 0.0)), -20.0, "a settled day should aim the pollution layer at the new day's stage")
	_assert_eq(float(controller.phone_ambience.get_meta("target_volume_db", 0.0)), -8.0, "a settled day should aim the phone layer at the current view")
	(mounted["host"] as Node).free()


## A listener that subscribed after the controller still reacts before the mix is read.
func _test_settled_day_reads_the_mix_after_every_listener() -> void:
	var mounted := _mount()
	var controller = mounted["controller"]
	var street := {"interaction_active": true}
	controller.set_state_source(func() -> Dictionary:
		var deps := _settled_run_deps()
		deps["phone_shell"] = {"view_state": "npc_up"}
		deps["reality_interaction_active"] = street["interaction_active"]
		deps["reality_conversation"] = {"phase": "typing"}
		return deps)
	(mounted["bus"] as GameEventBus).subscribe(GameEventsScript.DAY_SETTLED, func(_payload: Dictionary) -> void: street["interaction_active"] = false)
	_settle_day()
	await process_frame
	_assert_eq(float(controller.reality_ambience.get_meta("target_volume_db", 0.0)), -10.0, "the mix should read the street idle once a later listener ended the conversation")
	(mounted["host"] as Node).free()


func _test_controller_out_of_the_tree_ignores_a_settled_day() -> void:
	var mounted := _mount()
	var controller = mounted["controller"]
	controller.set_state_source(_settled_run_deps)
	(mounted["host"] as Node).remove_child(controller)
	_settle_day()
	await process_frame
	_assert_eq(float(controller.pollution_ambience.get_meta("target_volume_db", 0.0)), -60.0, "a controller out of the tree should not hear a settled day")
	controller.free()
	(mounted["host"] as Node).free()


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
