extends SceneTree
## A post records the basement round it was made in, so a later ticket can ask whether this round already has one.
## Outside the basement (the opening, the tower) a post belongs to round zero.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")

var _failures: Array[String] = []


func _init() -> void:
	test_a_post_in_the_basement_records_its_round()
	test_a_post_outside_the_basement_records_round_zero()
	test_whether_this_round_has_a_post()
	if _failures.is_empty():
		print("post round tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_a_post_in_the_basement_records_its_round() -> void:
	var game := Harness.new_state()
	_enter_basement(game)
	_load_round(game, 3)
	game.free_sentence_units = ["灯"]
	game.submit_free_sentence("zh")
	_assert_eq(int(game.published_memes[0].get("round", -1)), 3, "a post in basement round three should record round three")


func test_a_post_outside_the_basement_records_round_zero() -> void:
	var game := Harness.new_state()
	game.skip_chapter_one()
	game.free_sentence_units = ["灯"]
	game.submit_free_sentence("zh")
	_assert_eq(int(game.published_memes[0].get("round", -1)), 0, "a post on the tower should record round zero")


func test_whether_this_round_has_a_post() -> void:
	var game := Harness.new_state()
	_enter_basement(game)
	_assert_true(not game.has_posted_this_round(), "a fresh basement round should have no post yet")
	game.free_sentence_units = ["灯"]
	game.submit_free_sentence("zh")
	_assert_true(game.has_posted_this_round(), "a post should mark the current round as posted")
	_load_round(game, 2)
	_assert_true(not game.has_posted_this_round(), "a post from round one should not count for round two")


func _enter_basement(game) -> void:
	while game.advance_opening_narration():
		pass
	game.complete_opening_knock()
	game.open_opening_door()
	_assert_eq(str(game.chapter_one_progress.get("phase")), ProgressScript.PHASE_BASEMENT, "setup should reach the basement")


## A save is the only way into a later round until the basement rounds advance on their own.
func _load_round(game, round_number: int) -> void:
	var save: Dictionary = game.to_save_data()
	save["state"]["chapter_one_progress"]["round"] = round_number
	_assert_true(game.load_save_data(save), "setup should load round %d" % round_number)


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
