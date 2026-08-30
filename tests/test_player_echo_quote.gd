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


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq_int(value: int, expected: int, message: String) -> void:
	if value != expected:
		_failures.append("%s (got %d, expected %d)" % [message, value, expected])


func _assert_eq_text(value: String, expected: String, message: String) -> void:
	if value != expected:
		_failures.append("%s (got %s, expected %s)" % [message, value, expected])
