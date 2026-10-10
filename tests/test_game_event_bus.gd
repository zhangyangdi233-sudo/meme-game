extends SceneTree
## GameEventBus: an intent carries its name and an answer payload; the bus is a shared service.

const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")

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


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
