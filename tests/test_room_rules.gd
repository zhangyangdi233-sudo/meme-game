extends SceneTree
## A room's data decides its words, its rules and how a red post changes the world: `RoomRules` reads a sentence with
## the rule engine and looks it up in the room, `RoomContent` loads and checks the authored rooms.

const RoomRulesScript = preload("res://scripts/game/room_rules.gd")
const ChapterOneProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const ContentJsonScript = preload("res://framework/content_json.gd")
const RoomContentScript = preload("res://scripts/game/room_content.gd")
const PoolScript = preload("res://scripts/narrative/pickup_char_pool.gd")
const PolicyScript = preload("res://scripts/game/pollution_policy.gd")

const ROOM := {
	"vocabulary": {"subjects": {"zh": {"电灯": "light"}}, "predicates": {"zh": {"点亮": "lit"}}},
	"rules": [
		{"id": "door_opens", "subject": "door", "predicate": "can_open", "text": {"zh": "门可以打开"}, "state": {"brightness": 0.5}},
		{"id": "light_on", "subject": "light", "predicate": "lit", "text": {"zh": "灯亮"}, "state": {"brightness": 1.6}},
		{"id": "light_off", "subject": "light", "predicate": "lit", "negated": true, "object": "light", "text": {"zh": "灯不亮"}, "state": {"brightness": 0.2}},
		{"id": "exit_shown", "subject": "exit", "predicate": "exists", "object": "table", "text": {"zh": "出口存在"}, "state": {"objects": {"exit_lamp": true}}},
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
	test_any_of_a_rooms_escapes_opens_the_exit()
	test_a_rule_escape_asks_for_its_rule_in_force()
	test_round_one_opens_only_by_its_exit_rules()
	test_an_escape_makes_its_object_the_exit()
	test_each_exit_subject_names_its_own_object()
	test_no_round_opens_by_the_post_and_the_npc()
	test_every_round_has_its_own_rules_and_more_than_one_way_out()
	test_an_xray_escape_opens_its_object_once_seen()
	test_round_five_hides_an_xray_way_out_at_the_clock()
	test_the_authored_rooms_are_valid()
	test_round_one_comes_from_its_data()
	test_every_round_one_word_can_be_picked_up()
	test_the_rule_escape_fixture_is_valid()
	test_a_room_can_carry_state_and_one_shot_events()
	test_validation_names_broken_rooms()
	test_a_floor_shares_one_rule_box()
	test_every_authored_round_draws_from_the_rule_box()
	test_validation_names_broken_rule_boxes()
	test_validation_holds_the_drop_guarantee()
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


func test_any_of_a_rooms_escapes_opens_the_exit() -> void:
	var room := ROOM.duplicate(true)
	room["escapes"] = [{"kind": "delivery"}, {"kind": "rule", "rule": "exit_shown"}]
	var exit_rule := {"exit|exists": {"negated": false, "round": 1}}
	_assert_true(not _escaped(room, {}, 1, false), "nothing done should open nothing")
	_assert_true(_escaped(room, {}, 1, true), "the post and the NPC alone should open a room with both escapes")
	_assert_true(_escaped(room, exit_rule, 1, false), "the rule alone should open a room with both escapes")
	var talk_only := ROOM.duplicate(true)
	talk_only["escapes"] = [{"kind": "delivery"}]
	_assert_true(not _escaped(talk_only, exit_rule, 1, false), "a rule should open only a room that declares it")
	var rule_only := ROOM.duplicate(true)
	rule_only["escapes"] = [{"kind": "rule", "rule": "exit_shown"}]
	_assert_true(not _escaped(rule_only, {}, 1, true), "the NPC should open only a room that declares it")
	_assert_true(not _escaped({}, exit_rule, 0, true), "no room should have no escape")


func test_a_rule_escape_asks_for_its_rule_in_force() -> void:
	var room := ROOM.duplicate(true)
	room["escapes"] = [{"kind": "rule", "rule": "light_off"}]
	_assert_true(_escaped(room, {"light|lit": {"negated": true, "round": 1}}, 1, false), "a negated rule can be the way out")
	_assert_true(not _escaped(room, {"light|lit": {"negated": false, "round": 1}}, 1, false), "the other polarity is another rule")
	_assert_true(not _escaped(room, {"light|lit": {"negated": true, "round": 2}}, 1, false), "another round's rule should not open this exit")
	_assert_true(not _escaped(room, {"light|lit": "broken"}, 1, false), "a broken saved rule should open nothing")


func test_an_escape_makes_its_object_the_exit() -> void:
	var room := ROOM.duplicate(true)
	room["escapes"] = [{"kind": "delivery"}, {"kind": "rule", "rule": "exit_shown"}, {"kind": "rule", "rule": "light_off"}]
	_assert_eq(RoomRulesScript.open_exits(room, {}, 1, false), [], "nothing done should make nothing an exit")
	_assert_eq(RoomRulesScript.open_exits(room, {"exit|exists": {"negated": false, "round": 1}}, 1, false), ["table"], "a rule escape should make the rule's object the exit")
	_assert_eq(RoomRulesScript.open_exits(room, {}, 1, true), ["door"], "the NPC's help should open the exit door")
	var both := {"exit|exists": {"negated": false, "round": 1}, "light|lit": {"negated": true, "round": 1}}
	_assert_eq(RoomRulesScript.open_exits(room, both, 1, true), ["door", "table", "light"], "every escape that holds should name its object once, in the room's order")
	_assert_eq(RoomRulesScript.open_exits(room, {"exit|exists": {"negated": false, "round": 2}}, 1, false), [], "another round's rule should make nothing an exit")


func test_each_exit_subject_names_its_own_object() -> void:
	var expected := {"door": "door", "stairs": "stairs", "tv": "tv", "table": "table", "chair": "chair", "clock": "clock", "light": "light"}
	for round_number in range(1, ChapterOneProgressScript.BASEMENT_ROUND_COUNT + 1):
		var room: Dictionary = RoomContentScript.room(round_number)
		for rule: Dictionary in RoomRulesScript.exit_rules(room):
			var rules := {"%s|%s" % [rule["subject"], rule["predicate"]]: {"negated": false, "round": round_number}}
			_assert_eq(RoomRulesScript.open_exits(room, rules, round_number, false), [expected[rule["subject"]]], "round %d's %s should make its own object the exit" % [round_number, rule["id"]])
	var objects: Array = RoomContentScript.EXIT_OBJECTS.duplicate()
	objects.sort()
	_assert_eq(objects, ["chair", "clock", "door", "light", "stairs", "table", "tv"], "the stage should know the seven exit objects")


func test_round_one_opens_only_by_its_exit_rules() -> void:
	var room: Dictionary = RoomContentScript.room(1)
	_assert_true({"kind": "delivery"} not in room.get("escapes"), "round one should not open by the post and the NPC (#120)")
	_assert_eq(RoomRulesScript.exit_rules(room).size(), 7, "round one should offer the seven exit rules")
	_assert_true(not _escaped(room, {}, 1, true), "a finished conversation should not open round one")
	_assert_true(_escaped(room, {"door|exit": {"negated": false, "round": 1}}, 1, false), "门是出口 should open round one")
	_assert_true(not _escaped(room, {"room|lit": {"negated": false, "round": 1}}, 1, false), "a rule that is no exit should leave round one shut")


## #127: the standing NPCs are gone; every round opens by its own escapes, none by the post and a conversation.
func test_no_round_opens_by_the_post_and_the_npc() -> void:
	for round_number in range(1, ChapterOneProgressScript.BASEMENT_ROUND_COUNT + 1):
		var room: Dictionary = RoomContentScript.room(round_number)
		_assert_true({"kind": "delivery"} not in room.get("escapes"), "round %d should not open by the post and the NPC (#127)" % round_number)
		_assert_true(not RoomRulesScript.stands_npc(room), "round %d should stand no NPC" % round_number)
		_assert_eq(RoomRulesScript.exit_rules(room).size(), 7, "round %d should offer the seven exit rules" % round_number)
		_assert_true(not _escaped(room, {}, round_number, true), "a finished conversation should not open round %d" % round_number)


## Each round says something of its own besides the ways out, with words it drops itself, and offers at least two ways out.
func test_every_round_has_its_own_rules_and_more_than_one_way_out() -> void:
	var others_seen: Array = []
	for round_number in range(1, ChapterOneProgressScript.BASEMENT_ROUND_COUNT + 1):
		var room: Dictionary = RoomContentScript.room(round_number)
		_assert_true((room.get("escapes") as Array).size() >= 2, "round %d should offer at least two ways out" % round_number)
		var exits := RoomRulesScript.exit_rules(room)
		var others: Array = (room.get("rules") as Array).filter(func(rule: Dictionary) -> bool: return rule not in exits)
		_assert_true(not others.is_empty(), "round %d should offer a rule that is no way out" % round_number)
		for rule: Dictionary in others:
			_assert_true(rule["id"] not in others_seen, "round %d's rule %s should be its own" % [round_number, rule["id"]])
			others_seen.append(rule["id"])
			_assert_true(RoomRulesScript.can_be_written(rule, (room["words"] as Dictionary)["zh"], "zh", room), "round %d should drop the words of %s" % [round_number, rule["id"]])
			var lamp: Variant = ((rule.get("state", {}) as Dictionary).get("objects", {}) as Dictionary).get("exit_lamp", false)
			_assert_true(lamp != true, "round %d's %s opens nothing, so it should not light the exit lamp" % [round_number, rule["id"]])
			var wording := str((rule.get("text", {}) as Dictionary).get("zh", ""))
			_assert_true(not wording.is_empty(), "round %d's %s should be worded" % [round_number, rule["id"]])
			var units: Array = Array(wording.split("", false))
			_assert_eq(RoomRulesScript.judge(units, "zh", room).get("rule_id"), rule["id"], "round %d should hear its wording %s as its rule" % [round_number, wording])


## #127: a room can hide a way out the X-ray shows: its object becomes the exit once the player looks at it through
## the X-ray, with no post and no rule.
func test_an_xray_escape_opens_its_object_once_seen() -> void:
	var room := ROOM.duplicate(true)
	room["escapes"] = [{"kind": "rule", "rule": "exit_shown"}, {"kind": "xray", "object": "clock"}]
	_assert_eq(RoomRulesScript.xray_objects(room), ["clock"], "the room should say which object the X-ray shows as a way out")
	_assert_eq(RoomRulesScript.open_exits(room, {}, 1, false), [], "an unseen X-ray way out should stay shut")
	_assert_eq(RoomRulesScript.open_exits(room, {}, 1, false, ["clock"]), ["clock"], "the clock seen through the X-ray should be the exit")
	_assert_eq(RoomRulesScript.open_exits(room, {}, 1, false, ["tv"]), [], "seeing another object through the X-ray should open nothing")
	_assert_eq(RoomRulesScript.xray_objects(ROOM), [], "a room without an X-ray way out should show none")
	var plain := ROOM.duplicate(true)
	plain["escapes"] = [{"kind": "rule", "rule": "exit_shown"}]
	_assert_eq(RoomRulesScript.open_exits(plain, {}, 1, false, ["clock"]), [], "the X-ray should open only a room that declares it")


## #142 Q1: the X-ray works from the start, unannounced; only round five hides a way out in it, at the clock its clue
## points to (#114).
func test_round_five_hides_an_xray_way_out_at_the_clock() -> void:
	for round_number in range(1, ChapterOneProgressScript.BASEMENT_ROUND_COUNT):
		_assert_eq(RoomRulesScript.xray_objects(RoomContentScript.room(round_number)), [], "round %d should hide nothing in the X-ray" % round_number)
	var round_five: Dictionary = RoomContentScript.room(5)
	_assert_eq(RoomRulesScript.xray_objects(round_five), ["clock"], "round five should hide its X-ray way out at the clock")
	_assert_eq(RoomRulesScript.open_exits(round_five, {}, 5, false, ["clock"]), ["clock"], "the clock seen through the X-ray should open round five")


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
	_assert_eq(RoomRulesScript.judge(["房", "间", "亮"], "zh", room).get("tier"), "rule", "房间亮 should be round one's rule")
	_assert_eq(RoomRulesScript.judge(["门", "是", "出", "口"], "zh", room).get("rule_id"), "door_exit", "门是出口 should be round one's exit rule")
	_assert_eq(RoomRulesScript.judge(["楼", "梯", "是", "出", "口"], "zh", room).get("rule_id"), "stairs_exit", "the floor's vocabulary should reach every room")
	_assert_eq(RoomRulesScript.judge(["ドア", "でぐち"], "ja", room).get("rule_id"), "door_exit", "an exit rule should already read in Japanese through the engine's words")
	_assert_eq(RoomRulesScript.judge(["door", "is", "exit"], "en", room).get("rule_id"), "door_exit", "an exit rule should already read in English through the engine's words")
	_assert_eq(RoomContentScript.rule_text(1, "room|lit", false, "zh"), "房间亮", "a rule should have its authored wording")
	_assert_eq(RoomContentScript.rule_text(1, "room|lit", false, "en"), "", "an unwritten language should have no wording yet")
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
	_assert_eq(RoomContentScript.words(1, "zh", "res://tests/fixtures/floor_two_rooms.json"), PoolScript.get_unit_pool("zh"), "a room without its words should keep the whole pool")
	for round_number in range(2, ChapterOneProgressScript.BASEMENT_ROUND_COUNT + 1):
		_assert_true(RoomContentScript.words(round_number, "zh") != PoolScript.get_unit_pool("zh"), "round %d should drop its own words, not the whole pool" % round_number)
		for word in RoomContentScript.words(round_number, "zh"):
			_assert_true(word in seeded, "round %d's %s should lie in some post" % [round_number, word])


func test_the_rule_escape_fixture_is_valid() -> void:
	var catalog: Dictionary = ContentJsonScript.load_dictionary_cached("res://tests/fixtures/rooms_rule_escape.json", "test_room_rules")
	_assert_eq(RoomContentScript.problems_in(catalog, 2), [] as Array[String], "the test rooms should follow the authored rooms' shape")


func test_a_room_can_carry_state_and_one_shot_events() -> void:
	var rooms := {"rule_box": [], "rooms": {"1": {
		"words": {"zh": [], "ja": [], "en": []},
		"rules": [],
		"escapes": [{"kind": "delivery"}],
		"state": {"brightness": 0.0, "hum": 0.8, "objects": {"exit_lamp": false}},
		"events": [{"id": "whisper", "trigger": "entry_sealed", "delay": 2.5, "duration": 8.0, "cue": "whisper_flicker"}],
	}}}
	_assert_eq(RoomContentScript.problems_in(rooms, 1), [] as Array[String], "a room with state and an event should be valid")
	var event: Dictionary = (rooms["rooms"]["1"]["events"] as Array)[0]
	var again := {"rule_box": [], "rooms": {"1": rooms["rooms"]["1"].duplicate(true)}}
	(again["rooms"]["1"]["events"] as Array).append(event.duplicate())
	_assert_true(not RoomContentScript.problems_in(again, 1).is_empty(), "a one-shot event's id should be unique in its room")
	var round_two: Array = RoomContentScript.events(2)
	_assert_eq(round_two.size(), 1, "the authored rounds should be able to hold an event")
	_assert_eq((round_two[0] as Dictionary).get("trigger"), "entry_sealed", "an event should say what starts it")


func test_validation_names_broken_rooms() -> void:
	_assert_true(not RoomContentScript.problems_in({}, 1).is_empty(), "no rooms should be a problem")
	var good := {"rule_box": [], "rooms": {"1": {"words": {"zh": [], "ja": [], "en": []}, "rules": [], "escapes": [{"kind": "delivery"}], "state": {"brightness": 1.0, "hum": 0.0, "objects": {}}, "events": []}}}
	_assert_eq(RoomContentScript.problems_in(good, 1), [] as Array[String], "a plain room should be valid")
	var seen := good.duplicate(true)
	seen["rooms"]["1"]["escapes"] = [{"kind": "xray", "object": "clock"}]
	_assert_eq(RoomContentScript.problems_in(seen, 1), [] as Array[String], "a room with an X-ray way out should be valid")
	for breakage in [
		func(catalog: Dictionary) -> void: catalog["rooms"]["1"].erase("state"),
		func(catalog: Dictionary) -> void: catalog["rooms"]["1"]["words"] = {"zh": []},
		func(catalog: Dictionary) -> void: catalog["rooms"]["1"]["state"]["objects"] = {"piano": true},
		func(catalog: Dictionary) -> void: _offer(catalog, {"id": "x", "subject": "light", "text": {}, "state": {}}),
		func(catalog: Dictionary) -> void: _offer(catalog, {"id": "x", "subject": "light", "predicate": "lit", "text": {}, "state": {"objects": {"piano": true}}}),
		func(catalog: Dictionary) -> void: catalog["rooms"]["1"]["events"] = [{"id": "x"}],
		func(catalog: Dictionary) -> void: catalog["rooms"]["1"]["state"].erase("objects"),
		func(catalog: Dictionary) -> void: catalog["rooms"]["1"].erase("escapes"),
		func(catalog: Dictionary) -> void: catalog["rooms"]["1"]["escapes"] = [],
		func(catalog: Dictionary) -> void: catalog["rooms"]["1"]["escapes"] = ["delivery"],
		func(catalog: Dictionary) -> void: catalog["rooms"]["1"]["escapes"] = [{"kind": "wish"}],
		func(catalog: Dictionary) -> void: catalog["rooms"]["1"]["escapes"] = [{"kind": "rule"}],
		func(catalog: Dictionary) -> void: catalog["rooms"]["1"]["escapes"] = [{"kind": "rule", "rule": "no_such_rule"}],
		func(catalog: Dictionary) -> void: catalog["rooms"]["1"]["escapes"] = [{"kind": "xray"}],
		func(catalog: Dictionary) -> void: catalog["rooms"]["1"]["escapes"] = [{"kind": "xray", "object": "piano"}],
		func(catalog: Dictionary) -> void:
			_offer(catalog, {"id": "x", "subject": "light", "predicate": "lit", "text": {}, "state": {}})
			catalog["rooms"]["1"]["escapes"] = [{"kind": "rule", "rule": "x"}],
		func(catalog: Dictionary) -> void:
			_offer(catalog, {"id": "x", "subject": "light", "predicate": "lit", "object": "piano", "text": {}, "state": {}})
			catalog["rooms"]["1"]["escapes"] = [{"kind": "rule", "rule": "x"}],
		func(catalog: Dictionary) -> void:
			catalog["rooms"]["1"]["words"]["zh"] = ["灯"]
			_offer(catalog, {"id": "x", "subject": "light", "predicate": "lit", "text": {}, "state": {}}),
	]:
		var broken := good.duplicate(true)
		breakage.call(broken)
		_assert_true(not RoomContentScript.problems_in(broken, 1).is_empty(), "a broken room should be reported: %s" % [broken])


## A second floor's fake data: three rooms draw on one box, and a rule two rooms offer is the same rule in both.
func test_a_floor_shares_one_rule_box() -> void:
	var path := "res://tests/fixtures/floor_two_rooms.json"
	var catalog: Dictionary = ContentJsonScript.load_dictionary_cached(path, "test_room_rules")
	_assert_eq(RoomContentScript.problems_in(catalog, 3), [] as Array[String], "a floor other than the basement should validate")
	_assert_true(RoomContentScript.validate(path, 3).get("ok"), "a floor should validate with its own room count: %s" % [RoomContentScript.validate(path, 3).get("problems")])
	var first: Dictionary = RoomContentScript.room(1, path)
	var second: Dictionary = RoomContentScript.room(2, path)
	_assert_eq((first["rules"] as Array).map(func(rule: Dictionary) -> String: return rule["id"]), ["light_on", "door_opens"], "a room should offer its rules in its own order")
	_assert_eq(first["rules"][1], catalog["rule_box"][0], "a room's rule should be the box's rule")
	_assert_eq(second["rules"][0], first["rules"][1], "two rooms should share one rule")
	_assert_eq(RoomRulesScript.judge(["门", "可", "以", "打", "开"], "zh", second).get("rule_id"), "door_opens", "a shared rule should be judged in every room offering it")
	_assert_eq(RoomRulesScript.judge(["灯", "亮"], "zh", second).get("tier"), "misread", "a rule of the box the room does not offer should stay green")
	_assert_eq(RoomContentScript.rule_text(2, "place|exists", false, "zh", path), "地方存在", "a shared rule should keep its wording")
	_assert_eq(RoomContentScript.rule_text(3, "door|can_open", false, "zh", path), "", "a room should have no wording for a rule it does not offer")
	_assert_true(_escaped(second, {"place|exists": {"negated": false, "round": 2}}, 2, false), "a shared rule should open the room declaring it")
	_assert_eq(RoomRulesScript.world_state(first, {"door|can_open": {"negated": false, "round": 1}}, 1).get("objects"), {"exit_lamp": true}, "a shared rule should change the room")


func test_every_authored_round_draws_from_the_rule_box() -> void:
	var catalog: Dictionary = ContentJsonScript.load_dictionary_cached(RoomContentScript.ROOMS_PATH, "test_room_rules")
	var ids: Array = (catalog.get("rule_box", []) as Array).map(func(rule: Dictionary) -> Variant: return rule.get("id"))
	_assert_true(not ids.is_empty(), "the basement should have a rule box")
	for round_number in range(1, ChapterOneProgressScript.BASEMENT_ROUND_COUNT + 1):
		for listed: Variant in catalog["rooms"][str(round_number)]["rules"]:
			_assert_true(listed is String and listed in ids, "round %d should name a rule of the box, not %s" % [round_number, listed])
	_assert_eq((RoomContentScript.room(1)["rules"] as Array).slice(0, 2).map(func(rule: Dictionary) -> String: return rule["id"]), ["light_on", "light_off"], "round one should offer the light rules")
	var subjects: Array = RoomRulesScript.exit_rules(RoomContentScript.room(1)).map(func(rule: Dictionary) -> String: return rule["subject"])
	subjects.sort()
	_assert_eq(subjects, ["chair", "clock", "door", "light", "stairs", "table", "tv"], "the box should hold the seven exit subjects")


func test_validation_names_broken_rule_boxes() -> void:
	var good := {"rule_box": [{"id": "light_on", "subject": "light", "predicate": "lit", "object": "light", "text": {}, "state": {}}], "rooms": {"1": {"words": {"zh": [], "ja": [], "en": []}, "rules": ["light_on"], "escapes": [{"kind": "rule", "rule": "light_on"}], "state": {"brightness": 1.0, "hum": 0.0, "objects": {}}, "events": []}}}
	_assert_eq(RoomContentScript.problems_in(good, 1), [] as Array[String], "a room offering a rule of the box should be valid")
	var unknown := good.duplicate(true)
	(unknown["rooms"]["1"]["rules"] as Array).append("light_off")
	_assert_eq(RoomContentScript.problems_in(unknown, 1), ["round 1 offers a rule the rule box lacks: light_off"] as Array[String], "a room naming a rule the box lacks should be reported")
	for breakage in [
		func(catalog: Dictionary) -> void: catalog["rooms"]["1"]["rules"] = ["light_off"],
		func(catalog: Dictionary) -> void: catalog["rooms"]["1"]["rules"] = ["light_on", "light_on"],
		func(catalog: Dictionary) -> void: catalog["rooms"]["1"]["rules"] = [catalog["rule_box"][0].duplicate()],
		func(catalog: Dictionary) -> void: catalog.erase("rule_box"),
		func(catalog: Dictionary) -> void: (catalog["rule_box"] as Array).append(catalog["rule_box"][0].duplicate()),
		func(catalog: Dictionary) -> void: catalog["rule_box"].append_array([{"subject": "light", "predicate": "lit", "text": {}, "state": {}}, {"subject": "door", "predicate": "can_open", "text": {}, "state": {}}]),
		func(catalog: Dictionary) -> void: catalog["rooms"]["1"]["rules"] = [],
	]:
		var broken := good.duplicate(true)
		breakage.call(broken)
		_assert_true(not RoomContentScript.problems_in(broken, 1).is_empty(), "a broken rule box should be reported: %s" % [broken])


## The content check plays the worst case: each earlier round used one exit up and every other rule was posted.
func test_validation_holds_the_drop_guarantee() -> void:
	var authored: Dictionary = ContentJsonScript.load_dictionary_cached(RoomContentScript.ROOMS_PATH, "test_room_rules")
	_assert_eq(RoomContentScript.problems_in(authored), [] as Array[String], "the authored floor should keep the guarantee")
	var policy: Dictionary = PolicyScript.settings()
	var few_exits := authored.duplicate(true)
	var round_five: Dictionary = few_exits["rooms"]["5"]
	round_five["rules"] = (round_five["rules"] as Array).slice(0, 3)
	round_five["escapes"] = (round_five["escapes"] as Array).filter(func(escape: Dictionary) -> bool: return escape["kind"] != "rule" or escape["rule"] in round_five["rules"])
	_assert_true(_names(RoomContentScript.problems_in(few_exits), "round 5 can drop only"), "a last round with three exit rules cannot keep three after four rounds")
	var shared := authored.duplicate(true)
	(shared["rule_box"] as Array).append({"id": "lamp_lit", "subject": "light", "predicate": "lit", "text": {"zh": "灯亮"}, "state": {}})
	(shared["rooms"]["1"]["rules"] as Array).append("lamp_lit")
	(shared["rooms"]["1"]["words"]["zh"] as Array).append("灯")
	_assert_true(_names(RoomContentScript.problems_in(shared), "the subject light belongs to an exit rule and to another rule"), "another rule on an exit subject should be reported")
	var lasting := policy.merged({"pollute_after_exit_opens": true}, true)
	_assert_true(_names(RoomContentScript.problems_in(authored, ChapterOneProgressScript.BASEMENT_ROUND_COUNT, lasting), "can drop only"), "pollution after the exit opens should break the guarantee")
	var bare_skeleton := policy.duplicate(true)
	bare_skeleton["skeleton_words"]["zh"] = ["出口", "是", "不", "可以"]
	_assert_true(_names(RoomContentScript.problems_in(authored, ChapterOneProgressScript.BASEMENT_ROUND_COUNT, bare_skeleton), "can drop only"), "桌子 and 椅子 sharing a polluted 子 should break the guarantee")
	var unasked := few_exits.duplicate(true)
	unasked.erase("guaranteed_exit_rules")
	for listed: Dictionary in (unasked["rooms"] as Dictionary).values():
		listed["words"]["zh"] = []
	_assert_eq(RoomContentScript.problems_in(unasked), [] as Array[String], "a floor that asks for no guarantee should not be held to one")


func _names(problems: Array[String], part: String) -> bool:
	return problems.any(func(problem: String) -> bool: return part in problem)


## Puts a rule in the box and has room one offer it.
## Whether any of the room's escapes holds: some object is the way out.
func _escaped(room: Dictionary, rules: Dictionary, round_number: int, talked_with_post: bool) -> bool:
	return not RoomRulesScript.open_exits(room, rules, round_number, talked_with_post).is_empty()


func _offer(catalog: Dictionary, rule: Dictionary) -> void:
	(catalog["rule_box"] as Array).append(rule)
	(catalog["rooms"]["1"]["rules"] as Array).append(rule["id"])


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if str(actual) != str(expected):
		_failures.append("%s (got %s, expected %s)" % [message, actual, expected])
