extends SceneTree
## Narrative overlay director: finishing the pollution flashback asks the host to settle, then raises
## FLASHBACK_FINISHED on the bound bus. Does not load the main scene.

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
	_test_finished_flashback_settles_then_raises_its_event()
	_test_finish_without_a_flashback_on_screen_raises_nothing()
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


func _test_finished_flashback_settles_then_raises_its_event() -> void:
	var mounted := _mount()
	var director = mounted["director"]
	director.play_pollution_flashback()
	director.finish_pollution_flashback()
	_assert_eq(mounted["heard"], ["settle_day(true)", "flashback_finished"], "finishing the flashback should settle first, then raise its event")
	_unmount(mounted)


func _test_finish_without_a_flashback_on_screen_raises_nothing() -> void:
	var mounted := _mount()
	mounted["director"].finish_pollution_flashback()
	_assert_eq(mounted["heard"], [], "finishing with no flashback on screen should neither settle nor raise")
	_unmount(mounted)


func _unmount(mounted: Dictionary) -> void:
	(mounted["host"] as Node).free()
	RegistryScript.unbind(ServiceKeysScript.UI_THEME, RegistryScript.resolve(ServiceKeysScript.UI_THEME))


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
