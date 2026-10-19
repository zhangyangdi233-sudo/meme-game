extends SceneTree
## The settings intent handler takes the settings window's intents off an empty bus, writes the volume and autoplay
## models and the exit prompt, and returns what the host should present. No main scene is opened.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const BootScript = preload("res://scripts/game/property_boot.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const IntentResultScript = preload("res://scripts/game/intent_result.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const SettingsIntentHandlerScript = preload("res://scripts/game/settings_intent_handler.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")

var _failures: Array[String] = []
var _game: MemeGameState
var _handler: SettingsIntentHandler
var _results: Array = []


func _init() -> void:
	_test_it_claims_every_settings_intent_and_nothing_else()
	_test_volume_and_autoplay_are_written_to_their_models()
	_test_the_settings_intent_leaves_the_open_model_to_the_panel()
	_test_an_exit_request_marks_the_prompt_seen()
	_test_window_and_flow_intents_name_their_presentation()
	RegistryScript.clear()
	if _failures.is_empty():
		print("settings intent handler tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


## A clean registry, the models, an empty bus and a stand-in host that routes the settings intents to the handler.
func _boot() -> void:
	RegistryScript.clear()
	BootScript.install()
	_game = Harness.new_state()
	_handler = SettingsIntentHandlerScript.new()
	_handler.configure(_game)
	var bus := GameEventBusScript.new()
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	_results.clear()
	bus.intent_emitted.connect(func(intent_name: String, payload: Dictionary) -> void:
		if _handler.handles(intent_name):
			_results.append(_handler.handle(intent_name, payload)))


func _raise(intent_name: String, payload: Dictionary = {}) -> IntentResult:
	var heard := _results.size()
	GameEventBus.raise(intent_name, payload)
	_assert_eq(_results.size(), heard + 1, "the handler should answer %s once" % intent_name)
	return _results.back() if _results.size() > heard else null


func _model(property_name: String) -> ValuePropertyModel:
	var manager := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	return manager.model(property_name) as ValuePropertyModel


func _test_it_claims_every_settings_intent_and_nothing_else() -> void:
	_boot()
	for intent_name in [
		UiIntentsScript.VOLUME_CHANGED,
		UiIntentsScript.AUTOPLAY_TOGGLED,
		UiIntentsScript.VHS_TOGGLED,
		UiIntentsScript.MANUAL_SAVE_PRESSED,
		UiIntentsScript.RETURN_MAIN_MENU_PRESSED,
		UiIntentsScript.EXIT_GAME_REQUESTED,
		UiIntentsScript.EXIT_CONFIRMED,
		UiIntentsScript.HISTORY_TOGGLE_REQUESTED,
		UiIntentsScript.SETTINGS_PRESSED,
	]:
		_assert_true(_handler.handles(intent_name), "the handler should claim %s" % intent_name)
	for intent_name in [
		UiIntentsScript.EXIT_GAME,
		UiIntentsScript.LANGUAGE_SELECTED,
		UiIntentsScript.NOTEBOOK_CRAFT_REQUESTED,
	]:
		_assert_true(not _handler.handles(intent_name), "the handler should leave %s to the host" % intent_name)


func _test_volume_and_autoplay_are_written_to_their_models() -> void:
	_boot()
	var volume := _raise(UiIntentsScript.VOLUME_CHANGED, {UiIntentsScript.KEY_VALUE: 37.0})
	_assert_eq(float(_model(PropertyKeysScript.MASTER_VOLUME).read()), 37.0, "a volume intent should write the volume model")
	_assert_presents(volume, IntentResultScript.NONE, "a volume change")
	var autoplay := _raise(UiIntentsScript.AUTOPLAY_TOGGLED, {UiIntentsScript.KEY_VALUE: true})
	_assert_eq(bool(_model(PropertyKeysScript.AUTOPLAY_ENABLED).read()), true, "an autoplay intent should write the autoplay model")
	_assert_presents(autoplay, IntentResultScript.NONE, "an autoplay toggle")
	_raise(UiIntentsScript.AUTOPLAY_TOGGLED, {UiIntentsScript.KEY_VALUE: false})
	_assert_eq(bool(_model(PropertyKeysScript.AUTOPLAY_ENABLED).read()), false, "a second autoplay intent should write the model again")


## The settings panel owns the open model and only toggles it once it is built, so the host presents the toggle.
func _test_the_settings_intent_leaves_the_open_model_to_the_panel() -> void:
	_boot()
	var pressed := _raise(UiIntentsScript.SETTINGS_PRESSED)
	_assert_eq(bool(_model(PropertyKeysScript.SETTINGS_OPEN).read()), false, "a settings intent should not open the settings before the panel does")
	_assert_presents(pressed, SettingsIntentHandlerScript.SETTINGS_TOGGLED, "a settings press")


func _test_an_exit_request_marks_the_prompt_seen() -> void:
	_boot()
	var result := _raise(UiIntentsScript.EXIT_GAME_REQUESTED)
	_assert_true(_game.exit_prompt_seen, "an exit request should mark the exit prompt seen")
	_assert_presents(result, SettingsIntentHandlerScript.QUIT_PROMPTED, "an exit request")


func _test_window_and_flow_intents_name_their_presentation() -> void:
	_boot()
	var vhs := _raise(UiIntentsScript.VHS_TOGGLED, {UiIntentsScript.KEY_VALUE: false})
	_assert_presents(vhs, SettingsIntentHandlerScript.VHS_TOGGLED, "a VHS toggle")
	if vhs != null:
		_assert_eq(vhs.value, false, "a VHS toggle should carry the new setting")
	_assert_presents(_raise(UiIntentsScript.MANUAL_SAVE_PRESSED), SettingsIntentHandlerScript.SAVE_REQUESTED, "a save press")
	_assert_presents(_raise(UiIntentsScript.RETURN_MAIN_MENU_PRESSED), SettingsIntentHandlerScript.MAIN_MENU_REQUESTED, "a return to menu")
	_assert_presents(_raise(UiIntentsScript.EXIT_CONFIRMED), SettingsIntentHandlerScript.QUIT_CONFIRMED, "an exit confirm")
	_assert_presents(_raise(UiIntentsScript.HISTORY_TOGGLE_REQUESTED), SettingsIntentHandlerScript.HISTORY_TOGGLED, "a history toggle")


func _assert_presents(result: IntentResult, presentation: String, label: String) -> void:
	_assert_true(result != null, "%s should return a result" % label)
	if result != null:
		_assert_eq(result.presentation, presentation, "%s should ask the host for the right presentation" % label)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
