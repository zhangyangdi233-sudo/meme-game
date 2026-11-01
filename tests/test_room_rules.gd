extends SceneTree
## A room's data decides its words, its rules and how a red post changes the world: `RoomRules` reads a sentence with
## the rule engine and looks it up in the room, `RoomContent` loads and checks the authored rooms.

const RoomRulesScript = preload("res://scripts/game/room_rules.gd")
const RoomContentScript = preload("res://scripts/game/room_content.gd")
const PoolScript = preload("res://scripts/narrative/pickup_char_pool.gd")

const ROOM := {
	"vocabulary": {"subjects": {"zh": {"电灯": "light"}}, "predicates": {"zh": {"点亮": "lit"}}},
	"rules": [
		{"id": "door_opens", "subject": "door", "predicate": "can_open", "text": {"zh": "门可以打开"}, "state": {"brightness": 0.5}},
		{"id": "light_on", "subject": "light", "predicate": "lit", "text": {"zh": "灯亮"}, "state": {"brightness": 1.6}},
		{"id": "light_off", "subject": "light", "predicate": "lit", "negated": true, "text": {"zh": "灯不亮"}, "state": {"brightness": 0.2}},
		{"id": "exit_shown", "subject": "exit", "predicate": "exists", "text": {"zh": "出口存在"}, "state": {"objects": {"exit_lamp": true}}},
	],
	"state": {"brightness": 1.0, "hum": 0.3, "objects": {"exit_lamp": false}},
	"events": [],
}

var _failures: Array[String] = []


func _init() -> void:
	test_synonyms_and_word_orders_hit_one_rule()
	test_a_room_vocabulary_adds_synonyms()
	test_the_loose_match_catches_a_scattered_sentence()
	test_a_wrong_sentence_stays_green()
	test_the_room_replaces_the_written_table()
	test_a_negated_sentence_is_its_own_rule()
	test_rules_change_the_rooms_state()
	test_only_this_rounds_rules_count()
	test_the_authored_rooms_are_valid()
	test_round_one_comes_from_its_data()
	test_every_round_one_word_can_be_picked_up()
	test_a_room_can_carry_state_and_one_shot_events()
	test_validation_names_broken_rooms()
	if _failures.is_empty():
		print("room rules tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_synonyms_and_word_orders_hit_one_rule() -> void:
	for units in [["门", "可", "以", "打", "开"], ["打", "开", "门"], ["开", "门"], ["门", "被", "打", "开"]]:
		var judged: Dictionary = RoomRulesScript.judge(units, "zh", ROOM)
		_assert_eq(judged.get("tier"), "rule", "%s should be the door rule" % [units])
		_assert_eq(judged.get("rule_key"), "door|can_open", "%s should name the door rule" % [units])
		_assert_eq(judged.get("rule_id"), "door_opens", "%s should name the room's rule" % [units])


func test_a_room_vocabulary_adds_synonyms() -> void:
	var judged: Dictionary = RoomRulesScript.judge(["点", "亮", "电", "灯"], "zh", ROOM)
	_assert_eq(judged.get("rule_id"), "light_on", "the room's own words should reach the same rule")


func test_the_loose_match_catches_a_scattered_sentence() -> void:
	var judged: Dictionary = RoomRulesScript.judge(["出", "在", "存", "口"], "zh", ROOM)
	_assert_eq(judged.get("rule_id"), "exit_shown", "a rule's words scattered through the sentence should still hit it")


func test_a_wrong_sentence_stays_green() -> void:
	_assert_eq(RoomRulesScript.judge(["我", "想", "回", "家"], "zh", ROOM).get("tier"), "misread", "a sentence off the room's rules should be misread")
	_assert_eq(RoomRulesScript.judge(["灯"], "zh", ROOM).get("tier"), "misread", "half a rule should be misread")
	_assert_eq(RoomRulesScript.judge(["被", "安", "全"], "zh", ROOM).get("tier"), "noise", "words that mean nothing should be noise")
	_assert_eq(RoomRulesScript.judge(["被", "安", "全"], "zh", ROOM).get("rule_key"), "", "a green post should name no rule")
	_assert_eq(RoomRulesScript.judge([], "zh", ROOM).get("tier"), "noise", "an empty sentence should be noise")


func test_the_room_replaces_the_written_table() -> void:
	var empty_room := {"rules": []}
	_assert_eq(RoomRulesScript.judge(["灯", "亮"], "zh", empty_room).get("tier"), "misread", "a rule the room does not have should not count")
	var new_rule := {"rules": [{"id": "voice", "subject": "voice", "predicate": "stay", "text": {}, "state": {}}]}
	_assert_eq(RoomRulesScript.judge(["声", "音", "留", "下"], "zh", new_rule).get("rule_id"), "voice", "a rule added to the data alone should count")


func test_a_negated_sentence_is_its_own_rule() -> void:
	_assert_eq(RoomRulesScript.judge(["灯", "不", "亮"], "zh", ROOM).get("rule_id"), "light_off", "灯不亮 should hit the negated rule")
	var judged: Dictionary = RoomRulesScript.judge(["出", "口", "不", "存", "在"], "zh", ROOM)
	_assert_eq(judged.get("tier"), "misread", "a negation the room has no rule for should be green")


func test_rules_change_the_rooms_state() -> void:
	var base: Dictionary = RoomRulesScript.world_state(ROOM, {}, 1)
	_assert_eq(base.get("brightness"), 1.0, "with no rule the room should have its own brightness")
	_assert_eq((base.get("objects") as Dictionary).get("exit_lamp"), false, "with no rule the object should stay away")
	var lit: Dictionary = RoomRulesScript.world_state(ROOM, {"light|lit": {"negated": false, "round": 1}, "exit|exists": {"negated": false, "round": 1}}, 1)
	_assert_eq(lit.get("brightness"), 1.6, "the light rule should change the brightness")
	_assert_eq((lit.get("objects") as Dictionary).get("exit_lamp"), true, "the exit rule should bring the object")
	_assert_eq(lit.get("hum"), 0.3, "what no rule touches should stay")
	var dark: Dictionary = RoomRulesScript.world_state(ROOM, {"light|lit": {"negated": true, "round": 1}}, 1)
	_assert_eq(dark.get("brightness"), 0.2, "the rule's newest polarity should decide")


func test_only_this_rounds_rules_count() -> void:
	var state: Dictionary = RoomRulesScript.world_state(ROOM, {"light|lit": {"negated": false, "round": 2}}, 1)
	_assert_eq(state.get("brightness"), 1.0, "another round's rule should not change this room")
	var broken: Dictionary = RoomRulesScript.world_state(ROOM, {"light|lit": "broken", "door|lit": {"negated": false, "round": 1}}, 1)
	_assert_eq(broken.get("brightness"), 1.0, "a broken or unknown saved rule should change nothing")
	_assert_eq(RoomRulesScript.world_state({}, {}, 0), {}, "no room should have no state")


func test_the_authored_rooms_are_valid() -> void:
	var report: Dictionary = RoomContentScript.validate()
	_assert_true(bool(report.get("ok", false)), "the authored rooms should be valid: %s" % [report.get("problems")])
	for round_number in range(1, 6):
		_assert_true(not RoomContentScript.room(round_number).is_empty(), "round %d should have a room" % round_number)
	_assert_true(RoomContentScript.room(0).is_empty(), "there should be no room outside the rounds")
	_assert_true(RoomContentScript.room(6).is_empty(), "there should be no sixth room")


func test_round_one_comes_from_its_data() -> void:
	var room: Dictionary = RoomContentScript.room(1)
	_assert_true(not (room.get("rules", []) as Array).is_empty(), "round one should have rules")
	_assert_eq(RoomRulesScript.judge(["灯", "亮"], "zh", room).get("tier"), "rule", "灯亮 should be round one's rule")
	_assert_eq(RoomRulesScript.judge(["でんき", "つく"], "ja", room).get("tier"), "rule", "a rule should already read in Japanese through the engine's words")
	_assert_eq(RoomRulesScript.judge(["light", "lit"], "en", room).get("tier"), "rule", "a rule should already read in English through the engine's words")
	_assert_eq(RoomContentScript.rule_text(1, "light|lit", false, "zh"), "灯亮", "a rule should have its authored wording")
	_assert_eq(RoomContentScript.rule_text(1, "light|lit", false, "en"), "", "an unwritten language should have no wording yet")
	_assert_eq(RoomContentScript.rule_text(1, "door|lit", false, "zh"), "", "an unknown rule should have no wording")


func test_every_round_one_word_can_be_picked_up() -> void:
	var words: Array = RoomContentScript.words(1, "zh")
	_assert_true(not words.is_empty(), "round one should list its Chinese words")
	var seeded: Array = []
	for post_id in PoolScript.get_post_ids():
		seeded.append_array(PoolScript.get_post_units(post_id, "zh"))
	for word in words:
		_assert_true(word in seeded, "%s should lie in some post" % word)
	_assert_eq(RoomContentScript.words(1, "ja"), PoolScript.get_unit_pool("ja"), "an unwritten language should keep the whole pool")
	_assert_eq(RoomContentScript.words(2, "zh"), PoolScript.get_unit_pool("zh"), "a room without its words should keep the whole pool")


func test_a_room_can_carry_state_and_one_shot_events() -> void:
	var rooms := {"rooms": {"1": {
		"words": {"zh": [], "ja": [], "en": []},
		"rules": [],
		"state": {"brightness": 0.0, "hum": 0.8, "objects": {"exit_lamp": false}},
		"events": [{"id": "whisper", "trigger": "entry_sealed", "delay": 2.5, "duration": 8.0, "cue": "whisper_flicker"}],
	}}}
	_assert_eq(RoomContentScript.problems_in(rooms, 1), [] as Array[String], "a room with state and an event should be valid")
	var event: Dictionary = (rooms["rooms"]["1"]["events"] as Array)[0]
	var again := {"rooms": {"1": rooms["rooms"]["1"].duplicate(true)}}
	(again["rooms"]["1"]["events"] as Array).append(event.duplicate())
	_assert_true(not RoomContentScript.problems_in(again, 1).is_empty(), "a one-shot event's id should be unique in its room")
	var round_two: Array = RoomContentScript.events(2)
	_assert_eq(round_two.size(), 1, "the authored rounds should be able to hold an event")
	_assert_eq((round_two[0] as Dictionary).get("trigger"), "entry_sealed", "an event should say what starts it")


func test_validation_names_broken_rooms() -> void:
	_assert_true(not RoomContentScript.problems_in({}, 1).is_empty(), "no rooms should be a problem")
	var good := {"rooms": {"1": {"words": {"zh": [], "ja": [], "en": []}, "rules": [], "state": {"brightness": 1.0, "hum": 0.0, "objects": {}}, "events": []}}}
	_assert_eq(RoomContentScript.problems_in(good, 1), [] as Array[String], "a plain room should be valid")
	for breakage in [
		func(room: Dictionary) -> void: room.erase("state"),
		func(room: Dictionary) -> void: room["words"] = {"zh": []},
		func(room: Dictionary) -> void: room["state"]["objects"] = {"piano": true},
		func(room: Dictionary) -> void: room["rules"] = [{"id": "x", "subject": "light", "text": {}, "state": {}}],
		func(room: Dictionary) -> void: room["rules"] = [{"id": "x", "subject": "light", "predicate": "lit", "text": {}, "state": {"objects": {"piano": true}}}],
		func(room: Dictionary) -> void: room["events"] = [{"id": "x"}],
		func(room: Dictionary) -> void: room["state"].erase("objects"),
		func(room: Dictionary) -> void:
			room["words"]["zh"] = ["灯"]
			room["rules"] = [{"id": "x", "subject": "light", "predicate": "lit", "text": {}, "state": {}}],
	]:
		var broken := good.duplicate(true)
		breakage.call(broken["rooms"]["1"])
		_assert_true(not RoomContentScript.problems_in(broken, 1).is_empty(), "a broken room should be reported: %s" % [broken])


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if str(actual) != str(expected):
		_failures.append("%s (got %s, expected %s)" % [message, actual, expected])
