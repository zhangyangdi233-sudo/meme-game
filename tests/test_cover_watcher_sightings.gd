extends SceneTree
## Cover watcher sightings: it subscribes to the watcher's game events itself, marks the floor seen when the watcher
## appears, and records its withdrawal line when it vanishes. Does not load the main scene.

const BootScript = preload("res://scripts/game/property_boot.gd")
const CoverWatcherSightingsScript = preload("res://scripts/game/cover_watcher_sightings.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const GameEventsScript = preload("res://scripts/game_events.gd")
const MemeGameStateScript = preload("res://scripts/meme_game_state.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")

const VANISHED_LINE := "掩体后的人影缩了回去。它没有留下脸。"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_appearance_marks_the_floor_seen()
	_test_vanishing_records_the_withdrawal_line()
	_test_detached_sightings_ignore_events()
	_test_configure_points_at_the_current_run()
	_test_appearance_reaches_every_subscriber()
	RegistryScript.clear()
	if _failures.is_empty():
		print("cover watcher sightings tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _mount() -> Dictionary:
	RegistryScript.clear()
	BootScript.install()
	var bus: GameEventBus = GameEventBusScript.new()
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	var game := MemeGameStateScript.new()
	game.new_run()
	var sightings = CoverWatcherSightingsScript.new()
	sightings.configure(game)
	sightings.attach(bus)
	return {"bus": bus, "game": game, "sightings": sightings}


func _appeared(floor_number: int) -> void:
	GameEventBusScript.raise_event(GameEventsScript.COVER_WATCHER_APPEARED, {GameEventsScript.KEY_FLOOR: floor_number})


func _vanished(floor_number: int) -> void:
	GameEventBusScript.raise_event(GameEventsScript.COVER_WATCHER_VANISHED, {GameEventsScript.KEY_FLOOR: floor_number})


func _test_appearance_marks_the_floor_seen() -> void:
	var mounted := _mount()
	var game: MemeGameState = mounted["game"]
	_appeared(2)
	_assert_true(game.has_seen_cover_watcher(2), "an appearance should mark its floor seen")
	_assert_true(not game.has_seen_cover_watcher(3), "an appearance should mark only its own floor")
	_assert_true(not game.event_log.has(VANISHED_LINE), "an appearance should not record the withdrawal line")


func _test_vanishing_records_the_withdrawal_line() -> void:
	var mounted := _mount()
	var game: MemeGameState = mounted["game"]
	_vanished(2)
	_assert_eq(game.event_log.front() if not game.event_log.is_empty() else "", VANISHED_LINE, "a vanished watcher should record its withdrawal line")
	_assert_true(not game.has_seen_cover_watcher(2), "vanishing alone should not mark the floor seen")


func _test_detached_sightings_ignore_events() -> void:
	var mounted := _mount()
	var game: MemeGameState = mounted["game"]
	mounted["sightings"].detach()
	_appeared(2)
	_assert_true(not game.has_seen_cover_watcher(2), "detached sightings should not mark a floor")
	mounted["sightings"].attach(mounted["bus"])
	_appeared(2)
	_assert_true(game.has_seen_cover_watcher(2), "re-attached sightings should mark the floor again")


func _test_configure_points_at_the_current_run() -> void:
	var mounted := _mount()
	var first: MemeGameState = mounted["game"]
	var second := MemeGameStateScript.new()
	mounted["sightings"].configure(second)
	_appeared(4)
	_assert_true(second.cover_watcher_seen_floors.has(4), "an appearance should mark the run the sightings were last pointed at")
	_assert_true(not first.cover_watcher_seen_floors.has(4), "an appearance should leave an earlier run alone")


func _test_appearance_reaches_every_subscriber() -> void:
	var mounted := _mount()
	var game: MemeGameState = mounted["game"]
	var heard: Array = []
	var listener := func(payload: Dictionary) -> void: heard.append(payload.get(GameEventsScript.KEY_FLOOR))
	(mounted["bus"] as GameEventBus).subscribe(GameEventsScript.COVER_WATCHER_APPEARED, listener)
	_appeared(3)
	_assert_eq(heard, [3], "another subscriber should hear the same appearance")
	_assert_true(game.has_seen_cover_watcher(3), "the sightings should still mark the floor beside another subscriber")


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
