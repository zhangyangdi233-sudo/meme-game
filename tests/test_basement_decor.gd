extends SceneTree
## #114: what the basement shows that changes from run to run comes from the run's seed: the exit table holds a vase
## or a book each round, and round three's chairs scatter the same way every time for one seed.

const DecorScript = preload("res://scripts/game/basement_decor.gd")

var _failures: Array[String] = []


func _init() -> void:
	test_the_exit_table_holds_a_vase_or_a_book_by_the_seed()
	test_the_scattered_chairs_follow_the_seed()
	if _failures.is_empty():
		print("basement decor tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_the_exit_table_holds_a_vase_or_a_book_by_the_seed() -> void:
	var seen := {}
	for seed in range(1, 40):
		for round_number in range(1, 6):
			var prop: String = DecorScript.exit_table_prop(seed, round_number)
			_assert_true(prop in DecorScript.EXIT_TABLE_PROPS, "the exit table should hold a vase or a book: %s" % prop)
			_assert_true(prop == DecorScript.exit_table_prop(seed, round_number), "one seed and round should always pick the same")
			seen[prop] = true
	_assert_true(seen.size() == DecorScript.EXIT_TABLE_PROPS.size(), "runs should see both the vase and the book")


func test_the_scattered_chairs_follow_the_seed() -> void:
	var first: Array = DecorScript.scattered_chairs(1701)
	_assert_true(first.size() == DecorScript.SCATTERED_CHAIR_COUNT, "the pile should have its chairs")
	_assert_true(first == DecorScript.scattered_chairs(1701), "one seed should scatter the chairs the same way")
	_assert_true(first != DecorScript.scattered_chairs(1702), "another seed should scatter them differently")
	for chair: Dictionary in first:
		var at: Vector3 = chair["position"]
		_assert_true(DecorScript.SCATTER_AREA.has_point(Vector2(at.x, at.z)), "a chair should lie in the open room: %s" % at)
		_assert_true(int(chair["model"]) >= 0, "a chair should reuse one of the room's chair models")


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
