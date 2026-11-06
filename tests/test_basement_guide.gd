extends SceneTree
## The CRT's narrator walks the player through a basement round (#125): pick words, put them in a sentence, post it,
## and after a post says whether something answered, until the exit is open. The step follows the models alone, and
## the line for it is authored per round, so a round without lines says nothing.

const GuideScript = preload("res://scripts/game/basement_guide.gd")
const NarrativeCatalogScript = preload("res://scripts/game/narrative_session_catalog.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")

const HELD := [{"unit": "门", "locale": "zh"}]
const GREEN := {"kind": "free_sentence", "text": "我你", "tier": "misread", "round": 1}
const VOIDED := {"kind": "free_sentence", "text": "房间不亮", "tier": "misread", "voided": true, "round": 1}
const RED := {"kind": "free_sentence", "text": "房间亮", "tier": "rule", "round": 1}

var _failures: Array[String] = []


func _init() -> void:
	test_a_fresh_round_starts_with_picking_words()
	test_held_words_ask_for_a_sentence()
	test_a_sentence_asks_to_be_posted()
	test_after_a_post_the_guide_says_what_it_did()
	test_an_open_exit_sends_the_player_out()
	test_outside_the_basement_there_is_no_guide()
	test_round_one_has_a_line_for_every_step_in_every_language()
	test_every_later_round_speaks_after_the_tutorial()
	test_a_step_without_a_line_says_nothing()
	test_the_authored_guide_is_valid()
	test_validation_names_a_broken_guide()
	if _failures.is_empty():
		print("basement guide tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_a_fresh_round_starts_with_picking_words() -> void:
	_assert_eq(GuideScript.step(_round(1), [], [], {}), GuideScript.STEP_PICK, "a round with nothing held should ask for words")


func test_held_words_ask_for_a_sentence() -> void:
	_assert_eq(GuideScript.step(_round(1), HELD, [], {}), GuideScript.STEP_COMPOSE, "held words should ask for a sentence")


func test_a_sentence_asks_to_be_posted() -> void:
	_assert_eq(GuideScript.step(_round(1), HELD, ["门"], {}), GuideScript.STEP_POST, "a sentence should ask to be posted")
	_assert_eq(GuideScript.step(_round(1), HELD, ["门"], GREEN), GuideScript.STEP_POST, "a new sentence after a miss should ask to be posted")


func test_after_a_post_the_guide_says_what_it_did() -> void:
	_assert_eq(GuideScript.step(_round(1), HELD, [], GREEN), GuideScript.STEP_MISSED, "a green post should ask to try again")
	_assert_eq(GuideScript.step(_round(1), HELD, [], VOIDED), GuideScript.STEP_VOIDED, "a voided post should say pollution stopped it")
	_assert_eq(GuideScript.step(_round(1), HELD, [], RED), GuideScript.STEP_HEARD, "a red post with the exit shut should say it was heard")


func test_an_open_exit_sends_the_player_out() -> void:
	var delivered := ProgressScript.deliver(_round(1), ["door"])
	_assert_eq(GuideScript.step(delivered, HELD, ["门"], RED), GuideScript.STEP_OPEN, "an open exit should send the player out")


func test_outside_the_basement_there_is_no_guide() -> void:
	_assert_eq(GuideScript.step(ProgressScript.initial(), [], [], {}), "", "the opening should have no guide")
	_assert_eq(GuideScript.step(ProgressScript.tower(), [], [], {}), "", "the tower should have no guide")
	_assert_eq(GuideScript.line(ProgressScript.tower(), [], [], {}, "zh"), "", "the tower should have no line")


func test_round_one_has_a_line_for_every_step_in_every_language() -> void:
	for step in GuideScript.STEPS:
		for locale_code in ["zh", "ja", "en"]:
			_assert_true(not NarrativeCatalogScript.basement_guide_line(1, step, locale_code).is_empty(), "round one should say %s in %s" % [step, locale_code])
	_assert_eq(GuideScript.line(_round(1), [], [], {}, "zh"), NarrativeCatalogScript.basement_guide_line(1, GuideScript.STEP_PICK, "zh"), "the line should be the step's authored line")


## #127: from round two the player knows how to compose and post, so the narrator only greets the round, answers a
## post and sends the player to the way out; the X-ray is never mentioned (#142 Q1).
func test_every_later_round_speaks_after_the_tutorial() -> void:
	var spoken := [GuideScript.STEP_PICK, GuideScript.STEP_MISSED, GuideScript.STEP_VOIDED, GuideScript.STEP_HEARD, GuideScript.STEP_OPEN]
	for round_number in range(2, ProgressScript.BASEMENT_ROUND_COUNT + 1):
		for step in spoken:
			for locale_code in ["zh", "ja", "en"]:
				var said := NarrativeCatalogScript.basement_guide_line(round_number, step, locale_code)
				_assert_true(not said.is_empty(), "round %d should say %s in %s" % [round_number, step, locale_code])
				_assert_true("X" not in said, "round %d should not hint at the X-ray: %s" % [round_number, said])
		_assert_true(NarrativeCatalogScript.basement_guide_line(round_number, GuideScript.STEP_PICK, "zh") != NarrativeCatalogScript.basement_guide_line(1, GuideScript.STEP_PICK, "zh"), "round %d should greet the player its own way" % round_number)


func test_a_step_without_a_line_says_nothing() -> void:
	_assert_eq(NarrativeCatalogScript.basement_guide_line(2, GuideScript.STEP_COMPOSE, "zh"), "", "round two leaves composing to the player")
	_assert_eq(GuideScript.line(_round(2), HELD, [], {}, "zh"), "", "a step without a line should say nothing")


func test_the_authored_guide_is_valid() -> void:
	var problems: Array[String] = GuideScript.problems_in(NarrativeCatalogScript.load_catalog().get("basement_guide"))
	_assert_true(problems.is_empty(), "the authored guide should be valid: %s" % [problems])


func test_validation_names_a_broken_guide() -> void:
	_assert_true(not GuideScript.problems_in([]).is_empty(), "a guide that is not a table should fail")
	var broken := {
		"9": {"pick": {"zh": "a", "ja": "b", "en": "c"}},
		"1": {"wander": {"zh": "a", "ja": "b", "en": "c"}, "pick": {"zh": "a", "ja": "b"}},
	}
	var problems := " ".join(GuideScript.problems_in(broken))
	_assert_true(problems.contains("round 9"), "a guide for a round the basement lacks should fail: %s" % problems)
	_assert_true(problems.contains("wander"), "an unknown step should fail: %s" % problems)
	_assert_true(problems.contains("pick") and problems.contains("en"), "a line missing a language should fail: %s" % problems)
	_assert_true(GuideScript.problems_in({}).is_empty(), "a floor without a guide should be valid")


func _round(round_number: int) -> Dictionary:
	return ProgressScript.jump_to_round(ProgressScript.initial(), round_number)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
