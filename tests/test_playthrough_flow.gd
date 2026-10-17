extends SceneTree

var _failures: Array[String] = []
var _state_script: Script = null


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("playthrough flow tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_state_script = load("res://scripts/meme_game_state.gd") as Script
	_assert_true(_state_script != null, "meme game state script should exist")
	if _state_script == null:
		return
	test_five_action_phone_day_carries_published_words_into_doctor_dialogue()


func test_five_action_phone_day_carries_published_words_into_doctor_dialogue() -> void:
	var game: RefCounted = _state_script.new()
	game.new_run()

	_assert_true(game.pick_token("d1", _token("subject", "我", "speaker.self", "subject", "本账号", "患者")), "first action should pick a subject")
	_assert_true(game.pick_token("d1", _token("action", "看见", "perceive.see", "action", "捕获", "报告")), "second action should pick an action")
	_assert_true(game.pick_token("d1", _token("object", "塔", "place.tower", "object", "信号塔", "病区")), "third action should pick an object")
	_assert_eq(game.pollution, 0, "collecting words alone should not increase pollution")
	_assert_true(game.place_token_in_slot("subject", "d1-subject-1"), "subject should enter the sentence")
	_assert_true(game.place_token_in_slot("action", "d1-action-1"), "action should enter the sentence")
	_assert_true(game.place_token_in_slot("object", "d1-object-1"), "object should enter the sentence")
	_assert_true(game.confirm_craft(), "fourth action should compose a complete phone sentence")
	_assert_eq(str(game.completed_memes[0].get("clean_text", "")), "我看见塔。", "crafted data should preserve the player's clean sentence")
	_assert_eq(str(game.completed_memes[0].get("text", "")), "本账号捕获信号塔。", "the phone world should display its authored wording")
	game.place_meme_in_blank("blank_1", str(game.completed_memes[0]["id"]))
	_assert_true(game.confirm_dialogue(), "fifth action should publish the complete sentence")
	_assert_eq(game.actions_remaining, 0, "three pickups, one composition, and one publish should deplete the day")
	_assert_true(game.needs_day_settlement, "the fifth effective action should request automatic day settlement")
	for token: Dictionary in game.notebook_tokens:
		_assert_true("phone" in token.get("used_worlds", []), "all three published words should become phone-world language")
	game.change_pollution(25 - game.pollution)
	_assert_true(game.settle_day_if_needed(), "settlement should run after the fifth effective action")

	_assert_eq(game.day, 2, "settlement should advance to day two")
	_assert_eq(game.actions_remaining, 5, "new day should restore five actions")
	_assert_eq(game.tower_floor, 2, "the 25 percent boundary should advance to level two")
	_assert_true(not game.has_method("get_required_legacy_tiles"), "the next level should not impose an inherited phrase")

	_assert_true(game.start_typed_reality_conversation("doctor_floor2", "doctor", "医生"), "the level-two doctor should accept a sentence")
	_assert_eq(game.get_language_token_options("doctor").size(), 3, "only the three published words should be available in the doctor world")
	_assert_true(game.place_language_token("subject", "d1-subject-1", "doctor"), "published subject should cross worlds")
	_assert_true(game.place_language_token("action", "d1-action-1", "doctor"), "published action should cross worlds")
	_assert_true(game.place_language_token("object", "d1-object-1", "doctor"), "published object should cross worlds")
	var doctor_preview: Dictionary = game.get_language_sentence_preview("doctor")
	_assert_eq(str(doctor_preview.get("world_sentence", "")), "患者报告病区。", "the same lexemes should become an authored doctor sentence")
	var money_before: int = game.money
	var pollution_before: int = game.pollution
	_assert_true(game.confirm_doctor_sentence().succeeded, "doctor sentence should resolve without any legacy tile")
	_assert_eq(game.actions_remaining, 4, "doctor confirmation should spend one action")
	_assert_eq(game.money, money_before, "doctor dialogue should not change money")
	_assert_true(game.pollution > pollution_before, "cross-world reuse should increase pollution")
	_assert_eq(str(game.sentence_records[0].get("clean_sentence", "")), "我看见塔。", "the sentence record should preserve what the player originally assembled")


func _token(
	token_id: String,
	text: String,
	lexeme_id: String,
	role: String,
	phone_surface: String,
	doctor_surface: String
) -> Dictionary:
	return {
		"id": token_id,
		"text": text,
		"lexeme_id": lexeme_id,
		"grammar_roles": [role],
		"phone_surface": phone_surface,
		"doctor_surface": doctor_surface,
		"doll_surface": text,
		"tags": ["test"],
		"rarity": 1,
	}


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s. Expected %s, got %s" % [message, str(expected), str(actual)])
