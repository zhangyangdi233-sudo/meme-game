extends SceneTree
## GameEventBus: an intent carries its name and an answer payload; the bus is a shared service.

const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const GameEventsScript = preload("res://scripts/game_events.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("game event bus tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_intent_carries_its_payload()
	_test_intent_without_answer_carries_an_empty_payload()
	_test_main_menu_intent_names()
	_test_bus_binds_once_under_its_service_key()
	_test_subscriber_hears_its_event()
	_test_unsubscribed_event_is_not_delivered()
	_test_unsubscribed_listener_hears_nothing_more()
	_test_game_events_do_not_touch_the_intent_listener()
	_test_raise_event_reaches_the_bound_bus()


func _test_intent_carries_its_payload() -> void:
	var bus: GameEventBus = GameEventBusScript.new()
	var heard: Array = []
	bus.intent_emitted.connect(func(intent_name: String, payload: Dictionary) -> void:
		heard.append([intent_name, payload])
	)
	bus.emit_intent(UiIntentsScript.LANGUAGE_SELECTED, {"locale": "ja"})
	_assert_eq(heard, [[UiIntentsScript.LANGUAGE_SELECTED, {"locale": "ja"}]], "an intent should carry its name and payload")


func _test_intent_without_answer_carries_an_empty_payload() -> void:
	var bus: GameEventBus = GameEventBusScript.new()
	var heard: Array = []
	bus.intent_emitted.connect(func(intent_name: String, payload: Dictionary) -> void:
		heard.append([intent_name, payload])
	)
	bus.emit_intent(UiIntentsScript.START_GAME)
	_assert_eq(heard, [[UiIntentsScript.START_GAME, {}]], "an intent without an answer should carry an empty payload")


func _test_main_menu_intent_names() -> void:
	_assert_eq(UiIntentsScript.START_GAME, "start_game", "start keeps its intent name")
	_assert_eq(UiIntentsScript.CONTINUE_GAME, "continue_game", "continue keeps its intent name")
	_assert_eq(UiIntentsScript.EXIT_GAME, "exit_game", "exit keeps its intent name")
	_assert_eq(UiIntentsScript.LANGUAGE_PICKER, "language_picker", "the language button keeps its intent name")
	_assert_eq(UiIntentsScript.LANGUAGE_SELECTED, "language_selected", "language choice has its own intent name")


func _test_bus_binds_once_under_its_service_key() -> void:
	RegistryScript.clear()
	var bus: GameEventBus = GameEventBusScript.new()
	var other: GameEventBus = GameEventBusScript.new()
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, other)
	_assert_true(RegistryScript.resolve(ServiceKeysScript.UI_EVENT_BUS) == bus, "binding the bus twice should keep the first bus")
	RegistryScript.clear()
	_assert_true(not RegistryScript.has(ServiceKeysScript.UI_EVENT_BUS), "clear should drop the bound bus")


func _test_subscriber_hears_its_event() -> void:
	var bus: GameEventBus = GameEventBusScript.new()
	var first: Array = []
	var second: Array = []
	bus.subscribe(GameEventsScript.SFX_REQUESTED, func(payload: Dictionary) -> void: first.append(payload))
	bus.subscribe(GameEventsScript.SFX_REQUESTED, func(payload: Dictionary) -> void: second.append(payload))
	bus.emit_event(GameEventsScript.SFX_REQUESTED, {"cue": "pickup_press"})
	_assert_eq(first, [{"cue": "pickup_press"}], "a subscriber should hear its event with the payload")
	_assert_eq(second, [{"cue": "pickup_press"}], "a game event may have more than one listener")


func _test_unsubscribed_event_is_not_delivered() -> void:
	var bus: GameEventBus = GameEventBusScript.new()
	var heard: Array = []
	bus.subscribe(GameEventsScript.SFX_REQUESTED, func(payload: Dictionary) -> void: heard.append(payload))
	bus.emit_event("some_other_event", {"cue": "pickup_press"})
	_assert_eq(heard, [], "a listener should not hear an event it did not subscribe to")


func _test_unsubscribed_listener_hears_nothing_more() -> void:
	var bus: GameEventBus = GameEventBusScript.new()
	var heard: Array = []
	var listener := func(payload: Dictionary) -> void: heard.append(payload)
	bus.subscribe(GameEventsScript.SFX_REQUESTED, listener)
	bus.subscribe(GameEventsScript.SFX_REQUESTED, listener)
	bus.emit_event(GameEventsScript.SFX_REQUESTED, {"cue": "pickup_press"})
	_assert_eq(heard.size(), 1, "subscribing the same listener twice should deliver once")
	bus.unsubscribe(GameEventsScript.SFX_REQUESTED, listener)
	bus.emit_event(GameEventsScript.SFX_REQUESTED, {"cue": "pickup_land"})
	_assert_eq(heard.size(), 1, "a listener that left should hear nothing more")


func _test_game_events_do_not_touch_the_intent_listener() -> void:
	var bus: GameEventBus = GameEventBusScript.new()
	var intents: Array = []
	var events: Array = []
	bus.intent_emitted.connect(func(intent_name: String, _payload: Dictionary) -> void: intents.append(intent_name))
	bus.subscribe(UiIntentsScript.START_GAME, func(payload: Dictionary) -> void: events.append(payload))
	bus.emit_event(GameEventsScript.SFX_REQUESTED, {"cue": "pickup_press"})
	bus.emit_intent(UiIntentsScript.START_GAME)
	_assert_eq(intents, [UiIntentsScript.START_GAME], "a game event should not reach the intent listener")
	_assert_eq(events, [], "an intent should reach only the intent listener, never an event subscriber")
	_assert_eq(bus.intent_emitted.get_connections().size(), 1, "subscribing to a game event should not add an intent listener")


func _test_raise_event_reaches_the_bound_bus() -> void:
	RegistryScript.clear()
	GameEventBusScript.raise_event(GameEventsScript.SFX_REQUESTED, {"cue": "pickup_press"})
	var bus: GameEventBus = GameEventBusScript.new()
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	var heard: Array = []
	bus.subscribe(GameEventsScript.SFX_REQUESTED, func(payload: Dictionary) -> void: heard.append(payload))
	GameEventBusScript.raise_event(GameEventsScript.SFX_REQUESTED, {"cue": "pickup_land"})
	_assert_eq(heard, [{"cue": "pickup_land"}], "raising an event should reach the bound bus's subscribers")
	RegistryScript.clear()


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
