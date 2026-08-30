extends SceneTree

const SessionInputScript = preload("res://scripts/game/session_input.gd")

var _failures: Array[String] = []


func _init() -> void:
	test_owner_from_flag_table()
	test_input_gate_helpers()
	if _failures.is_empty():
		print("session input tests passed")
		quit(0)
	else:
		for failure in _failures:
			print("session input test failure: %s" % failure)
			push_error(failure)
		quit(1)


func test_owner_from_flag_table() -> void:
	_assert_eq(
		SessionInputScript.owner_from(true, false, true),
		SessionInputScript.Owner.PROLOGUE,
		"visible prologue should own input even after the run has started"
	)
	_assert_eq(
		SessionInputScript.owner_from(true, true, true),
		SessionInputScript.Owner.PROLOGUE,
		"prologue visibility should outrank the narrative input lock"
	)
	_assert_eq(
		SessionInputScript.owner_from(false, true, true),
		SessionInputScript.Owner.NARRATIVE_LOCK,
		"director input lock should own input during overlays"
	)
	_assert_eq(
		SessionInputScript.owner_from(false, false, false),
		SessionInputScript.Owner.MAIN_MENU,
		"a run that has not started should leave input with the main menu"
	)
	_assert_eq(
		SessionInputScript.owner_from(false, false, true),
		SessionInputScript.Owner.GAMEPLAY,
		"started gameplay without overlays should own input"
	)


func test_input_gate_helpers() -> void:
	_assert_true(
		SessionInputScript.blocks_world_pointer(SessionInputScript.Owner.PROLOGUE),
		"prologue should block 3D pointer and window routing"
	)
	_assert_true(
		SessionInputScript.blocks_world_pointer(SessionInputScript.Owner.NARRATIVE_LOCK),
		"narrative lock should block 3D pointer and window routing"
	)
	_assert_true(
		not SessionInputScript.blocks_world_pointer(SessionInputScript.Owner.MAIN_MENU),
		"main menu should keep the existing _input() path"
	)
	_assert_true(
		SessionInputScript.blocks_unhandled_gameplay(SessionInputScript.Owner.PROLOGUE),
		"prologue should also block unhandled gameplay keys"
	)
	_assert_true(
		SessionInputScript.blocks_unhandled_gameplay(SessionInputScript.Owner.MAIN_MENU),
		"main menu should block unhandled gameplay keys"
	)
	_assert_true(
		not SessionInputScript.blocks_unhandled_gameplay(SessionInputScript.Owner.GAMEPLAY),
		"gameplay should accept unhandled input"
	)


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
