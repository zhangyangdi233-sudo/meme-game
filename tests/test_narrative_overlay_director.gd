extends SceneTree
## Narrative overlay director: while in the tree it answers FLASHBACK_FINISHED on the bound bus by closing the
## flashback and asking the host to settle; the flashback overlay takes no callback. Does not load the main scene.

const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const GameEventsScript = preload("res://scripts/game_events.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const NarrativeOverlayDirectorScript = preload("res://scripts/game/narrative_overlay_director.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_finished_flashback_event_settles_the_day()
	_test_finished_flashback_event_without_a_flashback_on_screen_settles_nothing()
	_test_director_out_of_the_tree_does_not_answer()
	_test_flashback_overlay_takes_no_callback()
	await _test_played_flashback_raises_its_event_when_it_finishes()
	RegistryScript.clear()
	if _failures.is_empty():
		print("narrative overlay director tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _mount() -> Dictionary:
	RegistryScript.clear()
	var bus: GameEventBus = GameEventBusScript.new()
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	RegistryScript.bind(ServiceKeysScript.UI_THEME, GameUiThemeScript.new())
	var heard: Array = []
	bus.subscribe(GameEventsScript.FLASHBACK_FINISHED, func(_payload: Dictionary) -> void: heard.append("flashback_finished"))
	var host := Node.new()
	root.add_child(host)
	var ui_root := Control.new()
	host.add_child(ui_root)
	var director = NarrativeOverlayDirectorScript.new()
	director.attach_to(host)
	director.apply_deps({
		"ui_root": ui_root,
		"settle_day": func(from_flashback: bool) -> bool:
			heard.append("settle_day(%s)" % str(from_flashback))
			return true,
	})
	director.build_flashback_overlay()
	return {"host": host, "director": director, "heard": heard}


func _flashback_finished() -> void:
	GameEventBusScript.raise_event(GameEventsScript.FLASHBACK_FINISHED)


func _test_finished_flashback_event_settles_the_day() -> void:
	var mounted := _mount()
	var director = mounted["director"]
	director.play_pollution_flashback()
	_flashback_finished()
	_assert_eq(mounted["heard"], ["flashback_finished", "settle_day(true)"], "a finished flashback should ask the host to settle the day")
	_assert_true(not director.flashback_panel.is_playing(), "a finished flashback should close the overlay")
	_flashback_finished()
	_assert_eq(mounted["heard"], ["flashback_finished", "settle_day(true)", "flashback_finished"], "a second finish should not settle again")
	_unmount(mounted)


func _test_finished_flashback_event_without_a_flashback_on_screen_settles_nothing() -> void:
	var mounted := _mount()
	_flashback_finished()
	_assert_eq(mounted["heard"], ["flashback_finished"], "a finish with no flashback on screen should not settle")
	_unmount(mounted)


func _test_director_out_of_the_tree_does_not_answer() -> void:
	var mounted := _mount()
	var director = mounted["director"]
	director.play_pollution_flashback()
	(mounted["host"] as Node).remove_child(director)
	_flashback_finished()
	_assert_eq(mounted["heard"], ["flashback_finished"], "a director out of the tree should not settle")
	director.free()
	_unmount(mounted)


func _test_flashback_overlay_takes_no_callback() -> void:
	var mounted := _mount()
	var panel = mounted["director"].flashback_panel
	for method in (panel.get_script() as Script).get_script_method_list():
		if str(method["name"]) == "mount":
			_assert_eq((method["args"] as Array).size(), 1, "the flashback overlay should mount on its parent alone")
	_unmount(mounted)


func _test_played_flashback_raises_its_event_when_it_finishes() -> void:
	var mounted := _mount()
	mounted["director"].play_pollution_flashback()
	var deadline_msec := Time.get_ticks_msec() + 10000
	while (mounted["heard"] as Array).size() < 2 and Time.get_ticks_msec() < deadline_msec:
		await process_frame
	_assert_eq(mounted["heard"], ["flashback_finished", "settle_day(true)"], "a flashback that plays to its end should raise FLASHBACK_FINISHED once and settle the day")
	_unmount(mounted)


func _unmount(mounted: Dictionary) -> void:
	(mounted["host"] as Node).free()
	RegistryScript.unbind(ServiceKeysScript.UI_THEME, RegistryScript.resolve(ServiceKeysScript.UI_THEME))


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
