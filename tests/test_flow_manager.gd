extends SceneTree
## Framework flow manager: inject fake states, transition exit-then-enter, forward input.

const FlowManagerScript = preload("res://framework/flow/flow_manager.gd")
const RecordingStateScript = preload("res://tests/harness/recording_flow_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	test_injects_states_and_sets_current()
	test_transition_exits_then_enters()
	test_input_reaches_only_current_state()
	test_unknown_id_fails_without_changing_current()
	test_has_registered_ids()
	test_current_state_is_the_entered_object()
	if _failures.is_empty():
		print("flow manager tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_injects_states_and_sets_current() -> void:
	var manager = FlowManagerScript.new()
	var log: Array[String] = []
	manager.register(RecordingStateScript.new("alpha", log))
	manager.register(RecordingStateScript.new("beta", log))
	_assert_true(manager.transition_to("alpha"), "a registered state should become current")
	_assert_eq(manager.current_id(), "alpha", "current identity should be the injected state id")


func test_transition_exits_then_enters() -> void:
	var manager = FlowManagerScript.new()
	var log: Array[String] = []
	manager.register(RecordingStateScript.new("alpha", log))
	manager.register(RecordingStateScript.new("beta", log))
	manager.transition_to("alpha")
	manager.transition_to("beta")
	_assert_eq(log, ["alpha:enter", "alpha:exit", "beta:enter"], "transition should exit the current state before entering the next")
	_assert_eq(manager.current_id(), "beta", "current identity should follow a successful transition")


func test_input_reaches_only_current_state() -> void:
	var manager = FlowManagerScript.new()
	var log: Array[String] = []
	var alpha = RecordingStateScript.new("alpha", log)
	var beta = RecordingStateScript.new("beta", log)
	manager.register(alpha)
	manager.register(beta)
	manager.transition_to("alpha")
	var first := InputEventAction.new()
	first.action = "ui_accept"
	manager.handle_input(first)
	_assert_eq(alpha.inputs.size(), 1, "current state should receive input")
	_assert_eq(beta.inputs.size(), 0, "non-current state should not receive input")
	manager.transition_to("beta")
	var second := InputEventAction.new()
	second.action = "ui_cancel"
	manager.handle_input(second)
	_assert_eq(alpha.inputs.size(), 1, "previous state should not receive later input")
	_assert_eq(beta.inputs.size(), 1, "new current state should receive input")


func test_unknown_id_fails_without_changing_current() -> void:
	var manager = FlowManagerScript.new()
	var log: Array[String] = []
	manager.register(RecordingStateScript.new("alpha", log))
	manager.transition_to("alpha")
	log.clear()
	_assert_true(not manager.transition_to("missing"), "unknown id should fail")
	_assert_eq(manager.current_id(), "alpha", "failed transition should keep the current state")
	_assert_eq(log, [], "failed transition should not exit or enter any state")


func test_current_state_is_the_entered_object() -> void:
	var manager = FlowManagerScript.new()
	var log: Array[String] = []
	var alpha = RecordingStateScript.new("alpha", log)
	manager.register(alpha)
	if not manager.has_method("current_state"):
		_failures.append("flow manager should expose the current state object")
		return
	_assert_true(manager.current_state() == null, "current state should be empty before the first transition")
	manager.transition_to("alpha")
	_assert_true(manager.current_state() == alpha, "current state should be the object that was entered")


func test_has_registered_ids() -> void:
	var manager = FlowManagerScript.new()
	var log: Array[String] = []
	manager.register(RecordingStateScript.new("alpha", log))
	_assert_true(manager.has("alpha"), "a registered id should be present")
	_assert_true(not manager.has("missing"), "an unknown id should be absent")


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(value: Variant, expected: Variant, message: String) -> void:
	if value != expected:
		_failures.append("%s (got %s, expected %s)" % [message, str(value), str(expected)])
