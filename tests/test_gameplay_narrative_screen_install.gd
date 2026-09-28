extends SceneTree
## Gameplay and narrative install their screens on enter and exit. The host does not derive those screens from the current mode string.

const GameplayFlowStateScript = preload("res://scripts/game/flow/gameplay_flow_state.gd")
const NarrativeFlowStateScript = preload("res://scripts/game/flow/narrative_flow_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	test_gameplay_enter_and_exit_install_the_play_screen()
	test_narrative_enter_and_exit_install_its_screen()
	if _failures.is_empty():
		print("gameplay narrative screen install tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_gameplay_enter_and_exit_install_the_play_screen() -> void:
	var host := RecordingHost.new()
	var state = GameplayFlowStateScript.new(host)
	state.enter()
	_assert_eq(
		host.calls,
		["install_play_screen", "install_world_hotkeys"],
		"entering gameplay should install the play screen and the world hotkeys"
	)
	host.calls.clear()
	state.exit()
	_assert_eq(
		host.calls,
		["uninstall_world_hotkeys", "uninstall_play_screen"],
		"leaving gameplay should remove the world hotkeys and the play screen"
	)
	host.free()


func test_narrative_enter_and_exit_install_its_screen() -> void:
	var host := RecordingHost.new()
	var state = NarrativeFlowStateScript.new(host)
	state.enter()
	_assert_eq(
		host.calls,
		["install_narrative_screen", "install_play_screen"],
		"entering narrative should install the narrative screen and keep the play screen underneath"
	)
	host.calls.clear()
	state.exit()
	_assert_eq(
		host.calls,
		["uninstall_play_screen", "uninstall_narrative_screen"],
		"leaving narrative should remove the play screen and the narrative screen"
	)
	host.free()


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


class RecordingHost:
	extends Node

	var calls: Array[String] = []

	func install_play_screen() -> void:
		calls.append("install_play_screen")

	func uninstall_play_screen() -> void:
		calls.append("uninstall_play_screen")

	func install_world_hotkeys() -> void:
		calls.append("install_world_hotkeys")

	func uninstall_world_hotkeys() -> void:
		calls.append("uninstall_world_hotkeys")

	func install_narrative_screen() -> void:
		calls.append("install_narrative_screen")

	func uninstall_narrative_screen() -> void:
		calls.append("uninstall_narrative_screen")
