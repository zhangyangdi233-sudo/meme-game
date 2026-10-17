extends SceneTree
## Language presenter: pickup/place outcomes drive flights and the notebook home.
## Does not load the main scene.

const LanguagePresenterScript = preload("res://scripts/game/language_presenter.gd")
const ActionOutcomeScript = preload("res://scripts/game/action_outcome.gd")

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


func _new_presenter(layer: FlyToTargetLayer) -> LanguagePresenter:
	var presenter := LanguagePresenterScript.new() as LanguagePresenter
	presenter.configure(layer, null, func() -> Vector2: return Vector2(80, 60), func() -> Vector2: return Vector2(200, 300), Color.WHITE, Color.GREEN)
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


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
