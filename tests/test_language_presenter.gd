extends SceneTree
## Language presenter: pickup/place outcomes drive flights, the notebook home and the press sound cue.
## Does not load the main scene.

const LanguagePresenterScript = preload("res://scripts/game/language_presenter.gd")
const ActionOutcomeScript = preload("res://scripts/game/action_outcome.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const GameEventsScript = preload("res://scripts/game_events.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("language presenter tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_pickup_success_flies_home()
	_test_pickup_failure_stays_quiet()
	_test_place_flight()
	_test_pickup_asks_for_the_press_sound()
	_test_flights_carry_the_colors_the_host_injects()
	RegistryScript.clear()


func _new_presenter(layer: FlyToTargetLayer) -> LanguagePresenter:
	var presenter := LanguagePresenterScript.new() as LanguagePresenter
	presenter.configure(layer, func() -> Vector2: return Vector2(80, 60), func() -> Vector2: return Vector2(200, 300), Color.WHITE, Color.GREEN)
	return presenter


func _new_layer() -> FlyToTargetLayer:
	var layer := FlyToTargetLayer.new()
	root.add_child(layer)
	return layer


func _test_pickup_success_flies_home() -> void:
	var layer := _new_layer()
	var presenter := _new_presenter(layer)
	var homes: Array = [0]
	presenter.notebook_home_requested.connect(func() -> void: homes[0] += 1)
	var outcome := ActionOutcomeScript.new()
	outcome.succeeded = true
	presenter.present_pickup(outcome, "门", Vector2(10, 10))
	_assert_true(homes[0] == 1, "a successful pickup should ask for the notebook home")
	_assert_true(layer.is_animating(), "a successful pickup should start the hold flight")
	layer.finish_all_immediately()
	layer.queue_free()


func _test_pickup_failure_stays_quiet() -> void:
	var layer := _new_layer()
	var presenter := _new_presenter(layer)
	var homes: Array = [0]
	presenter.notebook_home_requested.connect(func() -> void: homes[0] += 1)
	presenter.present_pickup(ActionOutcomeScript.new(), "门", Vector2.ZERO)
	_assert_true(homes[0] == 0, "a failed pickup should not move the notebook")
	_assert_true(not layer.is_animating(), "a failed pickup should not fly")
	layer.queue_free()


func _test_place_flight() -> void:
	var layer := _new_layer()
	var presenter := _new_presenter(layer)
	presenter.present_place(false, "门", Vector2.ZERO)
	_assert_true(not layer.is_animating(), "a rejected place should not fly")
	presenter.present_place(true, "门", Vector2.ZERO)
	_assert_true(layer.is_animating(), "a placed unit should fly into the answer")
	layer.finish_all_immediately()
	layer.queue_free()
	var bare := LanguagePresenterScript.new() as LanguagePresenter
	var outcome := ActionOutcomeScript.new()
	outcome.succeeded = true
	bare.present_pickup(outcome, "门", Vector2.ZERO)
	bare.present_place(true, "门", Vector2.ZERO)


func _test_pickup_asks_for_the_press_sound() -> void:
	RegistryScript.clear()
	var bus: GameEventBus = GameEventBusScript.new()
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	var cues: Array = []
	bus.subscribe(GameEventsScript.SFX_REQUESTED, func(payload: Dictionary) -> void: cues.append(payload.get(GameEventsScript.KEY_CUE)))
	var presenter := _new_presenter(null)
	presenter.present_pickup(ActionOutcomeScript.new(), "门", Vector2.ZERO)
	_assert_true(cues.is_empty(), "a failed pickup should ask for no sound")
	var outcome := ActionOutcomeScript.new()
	outcome.succeeded = true
	presenter.present_pickup(outcome, "门", Vector2.ZERO)
	_assert_true(cues == [GameEventsScript.CUE_PICKUP_PRESS], "a successful pickup should ask for the press sound once (got %s)" % str(cues))
	presenter.present_place(true, "门", Vector2.ZERO)
	_assert_true(cues.size() == 1, "placing a unit should ask for no sound")


## The host injects the theme's flash_text and accent; the presenter keeps no color of its own.
func _test_flights_carry_the_colors_the_host_injects() -> void:
	var layer := _new_layer()
	var presenter := _new_presenter(layer)
	var outcome := ActionOutcomeScript.new()
	outcome.succeeded = true
	presenter.present_pickup(outcome, "门", Vector2.ZERO)
	presenter.present_place(true, "门", Vector2.ZERO)
	var hold := layer.get_node_or_null("HoldFlightGlyph") as Label
	var place := layer.get_node_or_null("PlaceFlightGlyph") as Label
	_assert_true(hold != null and hold.get_theme_color("font_color") == Color.WHITE, "the hold flight should take the injected hold color")
	_assert_true(place != null and place.get_theme_color("font_color") == Color.GREEN, "the place flight should take the injected place color")
	layer.finish_all_immediately()
	layer.queue_free()


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
