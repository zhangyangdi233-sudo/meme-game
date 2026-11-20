extends SceneTree
## 玩家投稿回流:论坛引用你写过的句子(三阶递进,零随机)。

const StateScript = preload("res://scripts/meme_game_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("player echo quote tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _post_door_sentence(game: RefCounted) -> void:
	game.free_sentence_units = ["门", "可", "以", "打", "开"]
	game.submit_free_sentence("zh")


func _run() -> void:
	_test_stages()
	_test_only_a_post_in_the_language_shown_is_quoted()


func _test_stages() -> void:
	var game = StateScript.new()
	game.new_run()
	_assert_eq_text(game.get_player_echo_quote("zh"), "", "with nothing posted there is nothing to quote")

	_post_door_sentence(game)
	game.pollution = 10
	_assert_eq_text(game.get_player_echo_quote("zh"), "门可以打开", "stage 1 quotes the sentence verbatim")

	game.pollution = 35
	_assert_eq_text(game.get_player_echo_quote("zh"), "门可以打", "stage 2 truncates the final unit")

	game.pollution = 70
	var stage_three := game.get_player_echo_quote("zh")
	_assert_true(stage_three.contains("门可以打开"), "stage 3 keeps the sentence readable")
	_assert_true(stage_three.contains("有人比你先写过这句"), "stage 3 reattributes the sentence to someone else")
	_assert_eq_int(game.get_player_quote_stage(), 3, "80-percent pollution should reach the final stage")

	var english = StateScript.new()
	english.new_run()
	english.free_sentence_units = ["the", "door", "can", "be", "opened"]
	english.submit_free_sentence("en")
	english.pollution = 70
	_assert_true(english.get_player_echo_quote("en").contains("Someone else wrote it first"), "the English locale reattributes in English")
	english.pollution = 35
	_assert_eq_text(english.get_player_echo_quote("en"), "the door can be", "English truncation joins with spaces")

	game.pollution = 35
	_assert_eq_text(game.get_player_echo_quote("zh"), game.get_player_echo_quote("zh"), "quotes must be deterministic")


## The planner's 2026-11-20 report: after a switch to Japanese the feed quoted the earlier language's post.
func _test_only_a_post_in_the_language_shown_is_quoted() -> void:
	var game = StateScript.new()
	game.new_run()
	game.pollution = 10
	_post_door_sentence(game)
	_assert_eq_text(game.get_player_echo_quote("zh"), "门可以打开", "a zh post should be quoted while zh is shown")
	_assert_eq_text(game.get_player_echo_quote("ja"), "", "a zh post should not be quoted once ja is shown")
	game.pollution = 35
	_assert_eq_text(game.get_player_echo_quote("ja"), "", "the truncated stage should not quote a zh post in ja either")
	game.pollution = 10
	game.free_sentence_units = ["ドア", "は", "あく"]
	game.submit_free_sentence("ja")
	_assert_eq_text(game.get_player_echo_quote("ja"), "ドアはあく", "a ja post should be quoted while ja is shown")
	_assert_eq_text(game.get_player_echo_quote("zh"), "门可以打开", "back in zh the zh post should be quoted again")
	game.pollution = 35
	_assert_eq_text(game.get_player_echo_quote("ja"), "ドアは", "the truncated stage should cut the ja post's own units")


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq_int(value: int, expected: int, message: String) -> void:
	if value != expected:
		_failures.append("%s (got %d, expected %d)" % [message, value, expected])


func _assert_eq_text(value: String, expected: String, message: String) -> void:
	if value != expected:
		_failures.append("%s (got %s, expected %s)" % [message, value, expected])
