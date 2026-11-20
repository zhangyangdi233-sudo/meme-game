extends SceneTree
## Round one's locked CRT lesson (the old tutorial, planner 2026-11-16): its words are the shortest natural sentence of
## the door exit rule in each language, with the copula only where the round drops it; posting exactly them in round
## one is a red post that opens the exit door. The step is read from the models alone, the lesson refuses what would
## break its step, and once the round's exit is open it is gone.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const LessonScript = preload("res://scripts/game/crt_lesson.gd")
const NarrativeCatalogScript = preload("res://scripts/game/narrative_session_catalog.gd")
const PickupCharPoolScript = preload("res://scripts/narrative/pickup_char_pool.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const RoomContentScript = preload("res://scripts/game/room_content.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")

const EXPECTED := {"zh": ["门", "是", "出", "口"], "en": ["door", "is", "exit"], "ja": ["ドア", "でぐち"]}

var _failures: Array[String] = []


func _init() -> void:
	test_the_lesson_words_are_the_door_exit_sentence_in_each_language()
	test_posting_exactly_the_lesson_words_opens_the_door_in_each_language()
	test_every_lesson_word_lies_in_a_post_of_round_one()
	test_the_step_follows_the_models()
	test_the_words_are_spread_over_more_than_one_post_in_chinese()
	test_an_open_exit_ends_the_lesson()
	test_only_round_one_has_a_lesson()
	test_the_lesson_refuses_what_would_break_its_step()
	test_the_captions_are_the_old_ones_in_every_language()
	test_the_open_post_lights_only_the_missing_words()
	test_a_word_the_sentence_cannot_keep_is_found()
	if _failures.is_empty():
		print("crt lesson tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_the_lesson_words_are_the_door_exit_sentence_in_each_language() -> void:
	for locale: String in EXPECTED:
		_assert_eq(LessonScript.teaching_units(RoomContentScript.room(1), locale), EXPECTED[locale], "the %s lesson words" % locale)


func test_posting_exactly_the_lesson_words_opens_the_door_in_each_language() -> void:
	for locale: String in EXPECTED:
		var game := _round_one()
		var units := LessonScript.teaching_units(RoomContentScript.room(1), locale)
		for unit: String in units:
			var post_id := _post_offering(unit, locale)
			_assert_true(bool(game.pick_social_char(post_id, unit, locale).get("picked", false)), "%s: %s should be picked up from %s" % [locale, unit, post_id])
			_assert_true(game.free_sentence_place(unit, locale), "%s: %s should be placed" % [locale, unit])
		var posted: Dictionary = game.submit_free_sentence(locale)
		_assert_eq(str(posted.get("tier", "")), "rule", "%s: the lesson sentence should be a red post" % locale)
		_assert_eq(game.basement_exits(), ["door"], "%s: the lesson sentence should open the exit door" % locale)


func test_every_lesson_word_lies_in_a_post_of_round_one() -> void:
	for locale: String in EXPECTED:
		var pool := RoomContentScript.words(1, locale)
		for unit: String in LessonScript.teaching_units(RoomContentScript.room(1), locale):
			_assert_true(unit in pool, "%s: round one should drop %s" % [locale, unit])
			_assert_true(not _post_offering(unit, locale).is_empty(), "%s: some post should offer %s" % [locale, unit])


func test_the_step_follows_the_models() -> void:
	var progress := _progress()
	var teaching: Array = EXPECTED["zh"]
	_assert_eq(LessonScript.step(progress, teaching, [], [], [], false), LessonScript.STEP_POST, "nothing held and no post open should ask for a post")
	_assert_eq(LessonScript.step(progress, teaching, [], [], ["门"], false), LessonScript.STEP_COLLECT, "an open post with a missing word should ask to pick it")
	_assert_eq(LessonScript.step(progress, teaching, ["门"], [], [], false), LessonScript.STEP_POST, "a word still missing elsewhere should ask for the next post")
	_assert_eq(LessonScript.step(progress, teaching, teaching, [], [], false), LessonScript.STEP_NOTEBOOK, "every word held should ask for the notebook")
	_assert_eq(LessonScript.step(progress, teaching, teaching, [], [], true), LessonScript.STEP_COMPOSE, "the notebook showing should ask for the sentence")
	_assert_eq(LessonScript.step(progress, teaching, teaching, ["门", "出"], [], true), LessonScript.STEP_COMPOSE, "a partial sentence should still ask for the sentence")
	_assert_eq(LessonScript.step(progress, teaching, teaching, ["口", "门", "出", "是"], [], true), LessonScript.STEP_PUBLISH, "the lesson words in any order should ask to post")
	_assert_eq(LessonScript.step(progress, teaching, teaching, ["门", "是", "出", "口"], [], false), LessonScript.STEP_NOTEBOOK, "leaving the notebook should ask for it again")
	_assert_eq(LessonScript.step(progress, teaching, teaching + ["房"], ["门", "是", "出", "口"], [], true), LessonScript.STEP_PUBLISH, "other held words should not matter")


## A word placed on the phone before the lesson must not leave the compose step stuck: the lesson names it to take out.
func test_a_word_the_sentence_cannot_keep_is_found() -> void:
	var teaching: Array = EXPECTED["zh"]
	_assert_eq(LessonScript.stray_index(teaching, []), -1, "an empty sentence has nothing to take out")
	_assert_eq(LessonScript.stray_index(teaching, ["门", "是"]), -1, "lesson words belong in the sentence")
	_assert_eq(LessonScript.stray_index(teaching, ["我", "门"]), 0, "a word that is not the lesson's should be taken out")
	_assert_eq(LessonScript.stray_index(teaching, ["门", "是", "门"]), 2, "a second copy of a lesson word should be taken out")
	_assert_true(not LessonScript.is_exact(teaching, ["门", "门", "出", "口"]), "a repeated word is not the lesson's sentence")
	_assert_eq(LessonScript.step(_progress(), teaching, teaching, ["我"], [], true), LessonScript.STEP_COMPOSE, "a stray word should keep the compose step")


func test_the_words_are_spread_over_more_than_one_post_in_chinese() -> void:
	var teaching := LessonScript.teaching_units(RoomContentScript.room(1), "zh")
	var first_post := _post_offering(str(teaching[0]), "zh")
	var offered := LessonScript.offered_by(first_post, teaching, "zh")
	_assert_true(not offered.is_empty() and offered.size() < teaching.size(), "one post should not offer every Chinese lesson word: %s" % [offered])


func test_an_open_exit_ends_the_lesson() -> void:
	var opened := ProgressScript.deliver(_progress(), ["door"])
	_assert_eq(LessonScript.step(opened, EXPECTED["zh"], [], [], [], false), "", "an open exit should end the lesson")
	var other_exit := ProgressScript.deliver(_progress(), ["tv"])
	_assert_eq(LessonScript.step(other_exit, EXPECTED["zh"], [], [], [], false), "", "an exit opened another way (on the phone) should end it too")


func test_only_round_one_has_a_lesson() -> void:
	var game := Harness.new_state()
	_assert_true(game.jump_to_basement_round(2), "setup should reach round two")
	_assert_eq(LessonScript.step(game.chapter_one_progress, EXPECTED["zh"], [], [], [], false), "", "round two should have no lesson")
	_assert_eq(LessonScript.step(ProgressScript.tower(), EXPECTED["zh"], [], [], [], false), "", "the tower should have no lesson")
	_assert_eq(LessonScript.step(_progress(), [], [], [], [], false), "", "a room without the door rule should have no lesson")


func test_the_lesson_refuses_what_would_break_its_step() -> void:
	var context := {"teaching": EXPECTED["zh"], "missing": ["是", "出"], "open_post_id": "floor_13", "offering_posts": [2]}
	_assert_true(LessonScript.allows(LessonScript.STEP_POST, UiIntentsScript.SOCIAL_CARD_CLICKED, {UiIntentsScript.KEY_POST_INDEX: 2}, context), "the lit post should open")
	_assert_true(not LessonScript.allows(LessonScript.STEP_POST, UiIntentsScript.SOCIAL_CARD_CLICKED, {UiIntentsScript.KEY_POST_INDEX: 0}, context), "another post should not open")
	_assert_true(not LessonScript.allows(LessonScript.STEP_COLLECT, UiIntentsScript.SOCIAL_CARD_CLICKED, {UiIntentsScript.KEY_POST_INDEX: 2}, context), "no post should open while collecting")
	_assert_true(LessonScript.allows(LessonScript.STEP_COLLECT, UiIntentsScript.SOCIAL_PICKUP_UNIT_CLICKED, {UiIntentsScript.KEY_META: "是", UiIntentsScript.KEY_POST_ID: "floor_13"}, context), "a missing lesson word should be picked")
	_assert_true(not LessonScript.allows(LessonScript.STEP_COLLECT, UiIntentsScript.SOCIAL_PICKUP_UNIT_CLICKED, {UiIntentsScript.KEY_META: "房", UiIntentsScript.KEY_POST_ID: "floor_13"}, context), "another word should not be picked")
	_assert_true(not LessonScript.allows(LessonScript.STEP_COLLECT, UiIntentsScript.SOCIAL_LIKE_PRESSED, {UiIntentsScript.KEY_POST_ID: "floor_13"}, context), "a like should be refused")
	_assert_true(not LessonScript.allows(LessonScript.STEP_COLLECT, UiIntentsScript.TERMINAL_APP_SELECTED, {UiIntentsScript.KEY_APP_ID: "notebook"}, context), "the notebook tab should wait until every word is held")
	_assert_true(LessonScript.allows(LessonScript.STEP_NOTEBOOK, UiIntentsScript.TERMINAL_APP_SELECTED, {UiIntentsScript.KEY_APP_ID: "notebook"}, context), "the notebook tab should open the notebook")
	_assert_true(LessonScript.allows(LessonScript.STEP_COMPOSE, UiIntentsScript.NOTEBOOK_COMPOSER_BANK_TAPPED, {UiIntentsScript.KEY_UNIT: "门"}, context), "a lesson word should be placed")
	_assert_true(not LessonScript.allows(LessonScript.STEP_COMPOSE, UiIntentsScript.NOTEBOOK_COMPOSER_BANK_TAPPED, {UiIntentsScript.KEY_UNIT: "房"}, context), "another word should not be placed")
	_assert_true(not LessonScript.allows(LessonScript.STEP_COMPOSE, UiIntentsScript.NOTEBOOK_CRAFT_REQUESTED, {}, context), "an unfinished sentence should not be posted")
	_assert_true(LessonScript.allows(LessonScript.STEP_PUBLISH, UiIntentsScript.NOTEBOOK_CRAFT_REQUESTED, {}, context), "the lesson sentence should be posted")
	for current_step: String in LessonScript.STEPS:
		_assert_true(LessonScript.allows(current_step, UiIntentsScript.TERMINAL_EXIT_REQUESTED, {}, context), "leaving the screen should always work (%s)" % current_step)
	_assert_true(LessonScript.allows("", UiIntentsScript.SOCIAL_LIKE_PRESSED, {}, context), "without a lesson nothing is refused")


## The old captions (report 1.2 B), with the adaptations the planner reviews: `collect` names no count, `notebook` is
## the old guide line, `compose` points at this notebook's tray and sentence bar and says tap, not drag.
func test_the_captions_are_the_old_ones_in_every_language() -> void:
	_assert_eq(LessonScript.caption(LessonScript.STEP_POST, "zh", EXPECTED["zh"]), "先打开这一条\n亮着的帖子。", "the post caption")
	_assert_eq(LessonScript.caption(LessonScript.STEP_COLLECT, "zh", EXPECTED["zh"]), "点亮的字：\n门 / 是 / 出 / 口。\n把它们拾进笔记本。", "the collect caption names the words")
	_assert_eq(LessonScript.caption(LessonScript.STEP_PUBLISH, "en", EXPECTED["en"]), "Click\nPublish", "the publish caption")
	_assert_eq(LessonScript.caption(LessonScript.STEP_COMPOSE, "ja", EXPECTED["ja"]), "下のトレイの\nドア / でぐち を\nタップして上の文へ。", "the compose caption in Japanese")
	for current_step: String in LessonScript.STEPS:
		for locale: String in EXPECTED:
			_assert_true(not NarrativeCatalogScript.crt_lesson_caption(current_step, locale).is_empty(), "the %s caption in %s" % [current_step, locale])
	_assert_true(bool(NarrativeCatalogScript.validate().get("ok", false)), "the catalog should be valid: %s" % [NarrativeCatalogScript.validate().get("problems")])


func test_the_open_post_lights_only_the_missing_words() -> void:
	var bbcode := LessonScript.lesson_bbcode("门开着。没人出来。", "zh", ["出"], ["门"], EXPECTED["zh"])
	_assert_true("[url=出]" in bbcode, "a missing lesson word should be a link: %s" % bbcode)
	_assert_true("[url=门]" not in bbcode and "#84917c]门" in bbcode, "a held lesson word should be dimmed and inert: %s" % bbcode)
	_assert_true("[url=没]" not in bbcode and "#72796c" in bbcode, "other words should be greyed and inert: %s" % bbcode)
	var english := LessonScript.lesson_bbcode("The door is open.", "en", ["door"], [], EXPECTED["en"])
	_assert_true("[url=door]" in english and "[url=is]" not in english, "English should light whole words only: %s" % english)


func _round_one() -> MemeGameState:
	var game := Harness.new_state()
	_assert_true(game.jump_to_basement_round(1), "setup should reach round one")
	return game


func _progress() -> Dictionary:
	return _round_one().chapter_one_progress


func _post_offering(unit: String, locale: String) -> String:
	for post_id in PickupCharPoolScript.get_post_ids():
		if PickupCharPoolScript.is_unit_seeded_in_post(str(post_id), unit, locale):
			return str(post_id)
	return ""


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])
