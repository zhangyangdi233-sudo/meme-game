extends SceneTree
## The words a basement round drops follow the pollution so far: every round can still spell three exit rules nobody
## has used up, whatever the player posted before, and a save brings the same words back.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const LanguageMaterialScript = preload("res://scripts/game/language_material.gd")
const PolicyScript = preload("res://scripts/game/pollution_policy.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const RoomContentScript = preload("res://scripts/game/room_content.gd")
const RoomRulesScript = preload("res://scripts/game/room_rules.gd")
const StateScript = preload("res://scripts/meme_game_state.gd")
const WordDropScript = preload("res://scripts/game/word_drop.gd")

const GUARANTEED := 3

var _failures: Array[String] = []


func _init() -> void:
	test_every_round_drops_three_clean_exit_rules()
	test_the_drop_moves_past_a_used_exit()
	test_many_red_posts_in_one_round_keep_three_for_later()
	test_red_posts_after_the_exit_opens_pollute_nothing_new()
	test_other_rules_do_not_touch_the_exit_rules()
	test_the_save_brings_the_same_drop_back()
	test_the_crt_and_the_phone_drop_the_same_words()
	test_the_tower_keeps_the_whole_pool()
	test_the_guarantee_comes_from_the_floor_data()
	if _failures.is_empty():
		print("word drop tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


## Whatever exit the player uses in each round, the next round still drops three clean ones.
func test_every_round_drops_three_clean_exit_rules() -> void:
	for pick in [0, 1, 2]:
		var game := _basement()
		for round_number in range(1, ProgressScript.BASEMENT_ROUND_COUNT + 1):
			var clean := _clean_exits(game)
			_assert_true(clean.size() >= GUARANTEED, "round %d should drop three clean exit rules, picking the %d. each time: %s" % [round_number, pick + 1, _ids(clean)])
			if clean.is_empty():
				return
			_escape_by(game, clean[mini(pick, clean.size() - 1)])
			if round_number < ProgressScript.BASEMENT_ROUND_COUNT:
				_assert_true(game.leave_basement_round(), "the opened exit should lead to round %d" % (round_number + 1))


func test_the_drop_moves_past_a_used_exit() -> void:
	var game := _basement()
	var first := _clean_exits(game)
	_escape_by(game, first[0])
	_assert_true(game.leave_basement_round(), "the exit rule should have opened the exit")
	var second := _clean_exits(game)
	_assert_true(first[0]["id"] not in _ids(second), "a used exit rule should not count in the next round")
	for unit: String in WordDropScript.sentence_units(first[0], "zh", _room(game)):
		if unit in game.get_polluted_units("zh"):
			_assert_true(unit not in _exit_units(second, game), "the drop should not need the used subject's word %s" % unit)


func test_many_red_posts_in_one_round_keep_three_for_later() -> void:
	var game := _basement()
	for rule: Dictionary in _clean_exits(game):
		_post(game, WordDropScript.sentence_units(rule, "zh", _room(game)))
	_post(game, ["房", "间", "亮"])
	_assert_eq(PolicyScript.polluted_units(game.polluted_words, "zh", _room(game), game.pollution_policy).size(), 1, "only the first exit rule's subject should be polluted")
	for round_number in range(2, ProgressScript.BASEMENT_ROUND_COUNT + 1):
		_assert_true(game.leave_basement_round(), "the exit should lead to round %d" % round_number)
		var clean := _clean_exits(game)
		_assert_true(clean.size() >= GUARANTEED, "round %d should still drop three: %s" % [round_number, _ids(clean)])
		for rule: Dictionary in clean:
			_post(game, WordDropScript.sentence_units(rule, "zh", _room(game)))


func test_red_posts_after_the_exit_opens_pollute_nothing_new() -> void:
	var game := _basement()
	var clean := _clean_exits(game)
	_assert_eq(_post(game, WordDropScript.sentence_units(clean[0], "zh", _room(game))).get("tier"), "rule", "an exit rule should be a red post")
	_assert_true(ProgressScript.exit_open(game.chapter_one_progress), "an exit rule should open the exit")
	var polluted: Array = game.get_polluted_units("zh")
	_assert_eq(_post(game, WordDropScript.sentence_units(clean[1], "zh", _room(game))).get("tier"), "rule", "a second exit rule should still be red")
	_assert_eq(game.get_polluted_units("zh"), polluted, "a red post after the exit opened should pollute nothing new")


func test_other_rules_do_not_touch_the_exit_rules() -> void:
	var game := _basement()
	var before := _ids(_clean_exits(game))
	_assert_eq(_post(game, ["房", "间", "亮"]).get("tier"), "rule", "房间亮 should be a red post of round one")
	_assert_true(not game.get_polluted_units("zh").is_empty(), "the other rule should pollute its own subject")
	_assert_true(not ProgressScript.exit_open(game.chapter_one_progress), "a rule that is no exit should open nothing")
	_assert_eq(_ids(_clean_exits(game)), before, "polluting another rule should leave the exit rules as they were")
	for rule: Dictionary in RoomRulesScript.exit_rules(_room(game)):
		_assert_true(not WordDropScript.used_up(rule, "zh", _room(game), game.polluted_words, game.pollution_policy), "%s should stay clean" % rule["id"])


func test_the_save_brings_the_same_drop_back() -> void:
	var game := _basement()
	_escape_by(game, _clean_exits(game)[0])
	_assert_true(game.leave_basement_round(), "the exit should lead on")
	var loaded := StateScript.new()
	_assert_true(loaded.load_save_data(game.to_save_data()), "the save should load")
	_assert_eq(loaded.get_pickup_unit_pool("zh"), game.get_pickup_unit_pool("zh"), "the save should drop the same words")
	_assert_eq(_ids(_clean_exits(loaded)), _ids(_clean_exits(game)), "the save should keep the same exit rules")
	_assert_true(_clean_exits(loaded).size() >= GUARANTEED, "the loaded round should still drop three")


func test_the_crt_and_the_phone_drop_the_same_words() -> void:
	var game := _basement()
	_escape_by(game, _clean_exits(game)[0])
	_assert_true(game.leave_basement_round(), "the exit should lead on")
	var material := LanguageMaterialScript.new()
	material.configure(game, null)
	_assert_eq(material.offered_units("zh"), game.get_pickup_unit_pool("zh"), "both feeds read the posts' words from one place")


func test_the_tower_keeps_the_whole_pool() -> void:
	var game := Harness.new_state()
	game.skip_chapter_one()
	_assert_eq(game.get_pickup_unit_pool("zh"), preload("res://scripts/narrative/pickup_char_pool.gd").get_unit_pool("zh"), "the tower should drop the whole pool")


func test_the_guarantee_comes_from_the_floor_data() -> void:
	var room: Dictionary = RoomContentScript.room(1)
	_assert_eq(room.get("guaranteed_exit_rules"), GUARANTEED, "the floor should say how many exit rules a round drops")
	_assert_eq(WordDropScript.exit_rules(room, "zh", {}, PolicyScript.settings()).size(), GUARANTEED, "a clean round should drop that many")
	var fewer := room.duplicate(true)
	fewer["guaranteed_exit_rules"] = 1
	_assert_eq(WordDropScript.exit_rules(fewer, "zh", {}, PolicyScript.settings()).size(), 1, "changing the number in the data should change the drop")
	var none := room.duplicate(true)
	none["guaranteed_exit_rules"] = 0
	_assert_eq(WordDropScript.units(none, "zh", {}, PolicyScript.settings()), (room["words"] as Dictionary)["zh"], "without a guarantee a round drops its own words only")


## The room's exit rules the posts' words can spell now and pollution has not voided.
func _clean_exits(game: MemeGameState) -> Array[Dictionary]:
	var room := _room(game)
	var drop: Array = game.get_pickup_unit_pool("zh")
	var clean: Array[Dictionary] = []
	for rule: Dictionary in RoomRulesScript.exit_rules(room):
		var units: Array = WordDropScript.sentence_units(rule, "zh", room)
		if units.all(func(unit: String) -> bool: return unit in drop) and not PolicyScript.sentence_voids(units, "zh", room, game.polluted_words, game.pollution_policy):
			clean.append(rule)
	return clean


func _exit_units(rules: Array[Dictionary], game: MemeGameState) -> Array:
	var units: Array = []
	for rule: Dictionary in rules:
		units.append_array(WordDropScript.sentence_units(rule, "zh", _room(game)))
	return units


func _escape_by(game: MemeGameState, rule: Dictionary) -> void:
	_assert_eq(_post(game, WordDropScript.sentence_units(rule, "zh", _room(game))).get("tier"), "rule", "%s should be a red post" % rule["id"])
	_assert_true(ProgressScript.exit_open(game.chapter_one_progress), "%s should open the exit" % rule["id"])


func _room(game: MemeGameState) -> Dictionary:
	return RoomContentScript.room(ProgressScript.round_of(game.chapter_one_progress))


func _ids(rules: Array) -> Array:
	return rules.map(func(rule: Dictionary) -> Variant: return rule.get("id"))


func _basement() -> MemeGameState:
	var game := Harness.new_state()
	while game.advance_opening_narration():
		pass
	game.complete_opening_knock()
	game.open_opening_door()
	_assert_eq(ProgressScript.round_of(game.chapter_one_progress), 1, "setup should reach round one")
	return game


func _post(game: MemeGameState, units: Array) -> Dictionary:
	game.free_sentence_units = units
	return game.submit_free_sentence("zh")


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if str(actual) != str(expected):
		_failures.append("%s (got %s, expected %s)" % [message, actual, expected])
