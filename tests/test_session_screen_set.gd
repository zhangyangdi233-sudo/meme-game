extends SceneTree
## Each Session mode declares the screen set its enter installs. The host does not apply that set from the current mode string.

const MainMenuFlowStateScript = preload("res://scripts/game/flow/main_menu_flow_state.gd")
const PrologueFlowStateScript = preload("res://scripts/game/flow/prologue_flow_state.gd")
const GameplayFlowStateScript = preload("res://scripts/game/flow/gameplay_flow_state.gd")
const NarrativeFlowStateScript = preload("res://scripts/game/flow/narrative_flow_state.gd")
const EndingFlowStateScript = preload("res://scripts/game/flow/ending_flow_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	test_each_mode_declares_its_current_screen_set()
	if _failures.is_empty():
		print("session screen set tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_each_mode_declares_its_current_screen_set() -> void:
	_assert_eq(
		_screen_ids(MainMenuFlowStateScript.new(null)),
		["title"],
		"main menu should declare the title screen"
	)
	_assert_eq(
		_screen_ids(PrologueFlowStateScript.new(null)),
		["prologue", "play"],
		"prologue should declare the opening plus the play chrome underneath it"
	)
	_assert_eq(
		_screen_ids(GameplayFlowStateScript.new(null)),
		["play"],
		"gameplay should declare the play chrome"
	)
	_assert_eq(
		_screen_ids(NarrativeFlowStateScript.new(null)),
		["narrative", "play"],
		"narrative should declare the narrative screen plus the play chrome underneath it"
	)
	_assert_eq(
		_screen_ids(EndingFlowStateScript.new(null)),
		["ending"],
		"ending should declare only the ending screen"
	)


func _screen_ids(state) -> Array:
	if state == null or not state.has_method("screen_set"):
		return []
	var declared: PackedStringArray = state.screen_set()
	var ids: Array[String] = []
	for screen_id in declared:
		ids.append(str(screen_id))
	return ids


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
