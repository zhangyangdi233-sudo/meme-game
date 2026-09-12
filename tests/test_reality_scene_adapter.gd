extends SceneTree
## RealitySceneAdapter static floor tables without the Node3D host.

const RealitySceneAdapterScript = preload("res://scripts/world/reality_scene_adapter.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("reality scene adapter tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_assert_eq(RealitySceneAdapterScript.room_count_for_floor(1), 4, "floor one should begin with four rooms")
	_assert_eq(RealitySceneAdapterScript.room_count_for_floor(2), 6, "floor two should add two rooms")
	_assert_eq(RealitySceneAdapterScript.room_count_for_floor(3), 9, "floor three should add three rooms")
	_assert_eq(RealitySceneAdapterScript.room_count_for_floor(4), 11, "hidden floor four should retain the final authored expansion")
	for floor_number in range(2, 5):
		var growth: int = RealitySceneAdapterScript.room_count_for_floor(floor_number) - RealitySceneAdapterScript.room_count_for_floor(floor_number - 1)
		_assert_true(growth == 2 or growth == 3, "each ascent should add two or three rooms")
	var expected_npc_counts := [4, 3, 2, 0]
	for floor_index in expected_npc_counts.size():
		var floor_number := floor_index + 1
		_assert_eq(
			RealitySceneAdapterScript.npc_count_for_floor(floor_number),
			expected_npc_counts[floor_index],
			"ordinary NPC population should follow the reduced floor sequence"
		)
		if floor_index > 0:
			_assert_true(expected_npc_counts[floor_index] < expected_npc_counts[floor_index - 1], "ordinary NPC population should strictly decrease on every ascent")


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
