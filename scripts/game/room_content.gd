class_name RoomContent
extends RefCounted
## Loads a floor's room data from JSON: the floor's rule box, its shared vocabulary and how many exit rules each round
## must drop the words of, then one room per round, with its words, the rules of the box it offers, its escapes, its
## state and its one-shot events. See ADR 0009. Rooms are read-only; `RoomRules` judges against them and `WordDrop`
## decides their words.

const ChapterOneProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const ContentJsonScript = preload("res://framework/content_json.gd")
const PickupCharPoolScript = preload("res://scripts/narrative/pickup_char_pool.gd")
const PollutionPolicyScript = preload("res://scripts/game/pollution_policy.gd")
const RoomRulesScript = preload("res://scripts/game/room_rules.gd")
const WordDropScript = preload("res://scripts/game/word_drop.gd")

const ROOMS_PATH := "res://content/basement_rooms.json"
const SUPPORTED_LOCALES := ["zh", "ja", "en"]
## The room objects the chapter stage can show or hide. A room can only name these.
const OBJECTS := ["exit_lamp"]
## The things of the room a rule can make the way out (#144): an exit rule names one as its `object`, and the chapter
## stage answers F at every one of them (any chair, any clock).
const EXIT_OBJECTS := ["door", "stairs", "tv", "table", "chair", "clock", "light"]


## The room of a round, or empty when there is none, with the rules it offers taken from the floor's rule box, the
## floor's vocabulary under its own and the floor's `guaranteed_exit_rules`. Callers do not change it.
static func room(round_number: int, path: String = ROOMS_PATH) -> Dictionary:
	var catalog: Dictionary = ContentJsonScript.load_dictionary_cached(path, "RoomContent")
	var authored: Variant = (catalog.get("rooms", {}) as Dictionary).get(str(round_number))
	return _resolved(authored, catalog) if authored is Dictionary else {}


## The words a round drops in a language with the run's pollution so far (`WordDrop`). A language the room has not
## written keeps the whole pool.
static func words(round_number: int, locale_code: String, path: String = ROOMS_PATH, polluted: Dictionary = {}, policy: Dictionary = PollutionPolicyScript.settings()) -> Array:
	return WordDropScript.units(room(round_number, path), locale_code, polluted, policy)


## A rule's authored wording, or empty when the language has none yet or the room has no such rule.
static func rule_text(round_number: int, rule_key: String, negated: bool, locale_code: String, path: String = ROOMS_PATH) -> String:
	for rule: Dictionary in room(round_number, path).get("rules", []):
		var key := "%s|%s" % [rule.get("subject", ""), rule.get("predicate", "")]
		if key == rule_key and bool(rule.get("negated", false)) == negated:
			return str((rule.get("text", {}) as Dictionary).get(locale_code, ""))
	return ""


static func events(round_number: int, path: String = ROOMS_PATH) -> Array:
	return ContentJsonScript.duplicate_array(room(round_number, path).get("events", []))


static func validate(path: String = ROOMS_PATH, room_count: int = ChapterOneProgressScript.BASEMENT_ROUND_COUNT) -> Dictionary:
	var problems := problems_in(ContentJsonScript.load_dictionary_cached(path, "RoomContent"), room_count)
	return {"ok": problems.is_empty(), "problems": problems}


## Names everything wrong with a floor's catalog, so an authoring slip fails a test instead of a playthrough.
static func problems_in(catalog: Dictionary, room_count: int = ChapterOneProgressScript.BASEMENT_ROUND_COUNT, policy: Dictionary = PollutionPolicyScript.settings()) -> Array[String]:
	var problems: Array[String] = []
	_check_rule_box(catalog, policy, problems)
	var rooms: Dictionary = catalog.get("rooms", {})
	var resolved: Array[Dictionary] = []
	for round_number in range(1, room_count + 1):
		if not rooms.get(str(round_number)) is Dictionary:
			problems.append("round %d has no room" % round_number)
			continue
		if _check_room(rooms[str(round_number)], catalog, "round %d" % round_number, problems):
			resolved.append(_resolved(rooms[str(round_number)], catalog))
	if problems.is_empty() and int(catalog.get("guaranteed_exit_rules", 0)) > 0:
		_check_drop_guarantee(resolved, catalog, policy, problems)
	return problems


## The box's rules by id. A rule without an id, or one repeating an id, is left out; `_check_rule_box` reports it.
static func _rule_box(catalog: Dictionary) -> Dictionary:
	var box := {}
	var listed: Variant = catalog.get("rule_box")
	for rule: Variant in listed if listed is Array else []:
		if rule is Dictionary and not str(rule.get("id", "")).is_empty() and not box.has(str(rule["id"])):
			box[str(rule["id"])] = rule
	return box


## The room as callers read it: its rule ids replaced by the box's rules, in the room's order, the floor's vocabulary
## under the room's own and the floor's guarantee. An id the box lacks is dropped; `_check_room` reports it.
static func _resolved(authored: Dictionary, catalog: Dictionary) -> Dictionary:
	var box := _rule_box(catalog)
	var resolved := authored.duplicate()
	var rules: Array = []
	var listed: Variant = authored.get("rules")
	for rule_id: Variant in listed if listed is Array else []:
		if rule_id is String and box.has(rule_id):
			rules.append(box[rule_id])
	resolved["rules"] = rules
	resolved["vocabulary"] = _merged_vocabulary(catalog.get("vocabulary"), authored.get("vocabulary"))
	resolved["guaranteed_exit_rules"] = int(catalog.get("guaranteed_exit_rules", 0))
	return resolved


## The floor's words for subjects and predicates with the room's laid over them, per language.
static func _merged_vocabulary(floor_words: Variant, room_words: Variant) -> Dictionary:
	var merged := {}
	for part: String in ["subjects", "predicates"]:
		var by_locale := {}
		for source: Variant in [floor_words, room_words]:
			var listed: Variant = (source as Dictionary).get(part) if source is Dictionary else null
			for locale_code: Variant in listed if listed is Dictionary else {}:
				if listed[locale_code] is Dictionary:
					(by_locale.get_or_add(locale_code, {}) as Dictionary).merge(listed[locale_code], true)
		merged[part] = by_locale
	return merged


static func _check_rule_box(catalog: Dictionary, policy: Dictionary, problems: Array[String]) -> void:
	if not catalog.get("rule_box") is Array:
		problems.append("the floor has no rule box")
		return
	var ids: Array[String] = []
	for rule: Variant in catalog["rule_box"]:
		_check_rule(rule, "the rule box", problems)
		if not rule is Dictionary:
			continue
		var rule_id := str(rule.get("id", ""))
		if not rule_id.is_empty() and rule_id in ids:
			problems.append("the rule box repeats the rule %s" % rule_id)
		ids.append(rule_id)
		if PollutionPolicyScript.is_barred(rule.get("subject"), policy):
			problems.append("the rule box rule %s has a barred subject, so it could never hold" % rule.get("id", ""))


## A room names the box's rules it offers by id; an id the box lacks would be a rule nobody can ever hit.
static func _check_offered(checked: Dictionary, box: Dictionary, label: String, problems: Array[String]) -> void:
	var offered: Array[String] = []
	for rule_id: Variant in checked["rules"]:
		if not rule_id is String:
			problems.append("%s offers a rule that is not an id of the rule box: %s" % [label, rule_id])
		elif not box.has(rule_id):
			problems.append("%s offers a rule the rule box lacks: %s" % [label, rule_id])
		elif rule_id in offered:
			problems.append("%s offers the rule %s twice" % [label, rule_id])
		else:
			offered.append(rule_id)


## Reports what is wrong with one room; answers whether it was whole enough to read on.
static func _check_room(checked: Dictionary, catalog: Dictionary, label: String, problems: Array[String]) -> bool:
	var box := _rule_box(catalog)
	for field_name: String in ["words", "state"]:
		if not checked.get(field_name) is Dictionary:
			problems.append("%s has no %s" % [label, field_name])
			return false
	for field_name: String in ["rules", "escapes", "events"]:
		if not checked.get(field_name) is Array:
			problems.append("%s has no %s" % [label, field_name])
			return false
	for locale_code: String in SUPPORTED_LOCALES:
		if not (checked["words"] as Dictionary).get(locale_code) is Array:
			problems.append("%s has no word list for %s" % [label, locale_code])
	var state: Dictionary = checked["state"]
	for field_name: String in ["brightness", "hum"]:
		if not (state.get(field_name) is float or state.get(field_name) is int):
			problems.append("%s has no %s" % [label, field_name])
	if not state.get("objects") is Dictionary:
		problems.append("%s has no objects" % label)
		return false
	_check_objects(state, label, problems)
	_check_offered(checked, box, label, problems)
	var resolved := _resolved(checked, catalog)
	# With a guarantee an exit rule's words come from the drop, so it is checked with the words the drop would add.
	var dropped: Array = RoomRulesScript.exit_rules(resolved) if int(resolved["guaranteed_exit_rules"]) > 0 else []
	for rule: Dictionary in resolved["rules"]:
		_check_writable(rule, resolved, label, problems, rule in dropped)
	_check_escapes(resolved, label, problems)
	var event_ids: Array[String] = []
	for event: Variant in checked["events"]:
		if not event is Dictionary or str(event.get("id", "")).is_empty() or str(event.get("trigger", "")).is_empty():
			problems.append("%s has an event without an id or a trigger" % label)
		elif str(event["id"]) in event_ids:
			problems.append("%s repeats the event %s" % [label, event["id"]])
		else:
			event_ids.append(str(event["id"]))
	return true


## A room nobody can leave would stop the run, and a rule escape naming no rule of its room would never open.
static func _check_escapes(checked: Dictionary, label: String, problems: Array[String]) -> void:
	if (checked["escapes"] as Array).is_empty():
		problems.append("%s has no escape" % label)
	var rule_ids: Array = []
	var objects := {}
	for rule: Variant in checked["rules"]:
		if rule is Dictionary:
			rule_ids.append(rule.get("id"))
			objects[rule.get("id")] = rule.get("object")
	for escape: Variant in checked["escapes"]:
		if not escape is Dictionary or escape.get("kind") not in RoomRulesScript.ESCAPE_KINDS:
			problems.append("%s has an unknown escape %s" % [label, escape])
		elif escape["kind"] == RoomRulesScript.ESCAPE_RULE and escape.get("rule") not in rule_ids:
			problems.append("%s has an escape naming no rule of its room: %s" % [label, escape.get("rule")])
		elif escape["kind"] == RoomRulesScript.ESCAPE_RULE:
			var object_name: Variant = objects[escape["rule"]]
			if object_name not in EXIT_OBJECTS:
				problems.append("%s has an escape whose rule %s names no exit object: %s" % [label, escape["rule"], object_name])


## Every round must drop the words of `guaranteed_exit_rules` exit rules pollution has left clean, in every language
## the floor writes words for, whatever the player did before: each earlier round used up one exit rule (all of them
## when pollution goes on after the exit opens) and every other rule up to this round was posted too.
static func _check_drop_guarantee(rooms: Array[Dictionary], catalog: Dictionary, policy: Dictionary, problems: Array[String]) -> void:
	var wanted := int(catalog.get("guaranteed_exit_rules", 0))
	_check_exit_subjects_apart(rooms, problems)
	for locale_code: String in SUPPORTED_LOCALES:
		if not rooms.any(func(checked: Dictionary) -> bool: return not ((checked["words"] as Dictionary).get(locale_code, []) as Array).is_empty()):
			continue
		var earlier_exits: Array[Dictionary] = []
		var other_rules: Array[Dictionary] = []
		for index in rooms.size():
			var checked: Dictionary = rooms[index]
			var exits := RoomRulesScript.exit_rules(checked)
			for rule: Dictionary in checked["rules"]:
				if rule not in exits and rule not in other_rules:
					other_rules.append(rule)
			var used_count := earlier_exits.size() if bool(policy.get("pollute_after_exit_opens", false)) else mini(index, earlier_exits.size())
			var fewest := _fewest_clean_exits(checked, locale_code, earlier_exits, used_count, other_rules, policy)
			if fewest < wanted:
				problems.append("round %d can drop only %d clean exit rules in %s, not %d" % [index + 1, fewest, locale_code, wanted])
			for rule: Dictionary in exits:
				if rule not in earlier_exits:
					earlier_exits.append(rule)


## A subject an exit rule and another rule share would let the other rule use the exit up.
static func _check_exit_subjects_apart(rooms: Array[Dictionary], problems: Array[String]) -> void:
	var exit_subjects: Array = []
	var other_subjects: Array = []
	for checked: Dictionary in rooms:
		var exits := RoomRulesScript.exit_rules(checked)
		for rule: Dictionary in checked["rules"]:
			var subjects := exit_subjects if rule in exits else other_subjects
			if rule.get("subject") not in subjects:
				subjects.append(rule.get("subject"))
	for subject: Variant in exit_subjects:
		if subject in other_subjects:
			problems.append("the subject %s belongs to an exit rule and to another rule" % subject)


## The fewest clean exit rules the room's drop can spell, over every choice of `used_count` used-up earlier exits.
static func _fewest_clean_exits(checked: Dictionary, locale_code: String, earlier_exits: Array[Dictionary], used_count: int, other_rules: Array[Dictionary], policy: Dictionary) -> int:
	var fewest := -1
	for used: Array in _combinations(earlier_exits, used_count):
		var polluted := {}
		for rule: Dictionary in used + other_rules:
			polluted = PollutionPolicyScript.pollute(polluted, WordDropScript.sentence_units(rule, locale_code, checked), str(rule.get("subject", "")), locale_code, checked, policy)
		var drop := WordDropScript.units(checked, locale_code, polluted, policy)
		var clean := 0
		for rule: Dictionary in WordDropScript.dropped_exit_rules(checked, locale_code, polluted, policy):
			var said := WordDropScript.sentence_units(rule, locale_code, checked)
			if said.all(func(unit: String) -> bool: return _seeded_somewhere(unit, locale_code)) and RoomRulesScript.can_be_written(rule, drop, locale_code, checked):
				clean += 1
		fewest = clean if fewest < 0 else mini(fewest, clean)
	return maxi(fewest, 0)


## Whether some post carries the unit, so the player can pick it up once it drops.
static func _seeded_somewhere(unit: String, locale_code: String) -> bool:
	for post_id: Variant in PickupCharPoolScript.get_post_ids():
		if PickupCharPoolScript.is_unit_seeded_in_post(str(post_id), unit, locale_code):
			return true
	return false


## Every way to choose `size` of `items`, in their order.
static func _combinations(items: Array, size: int) -> Array:
	if size <= 0:
		return [[]]
	if items.size() < size:
		return []
	var result: Array = []
	for index in range(items.size() - size + 1):
		for rest: Array in _combinations(items.slice(index + 1), size - 1):
			result.append([items[index]] + rest)
	return result


static func _check_rule(rule: Variant, label: String, problems: Array[String]) -> void:
	if not rule is Dictionary:
		problems.append("%s has a rule that is not a table" % label)
		return
	for field_name: String in ["id", "subject", "predicate"]:
		if str(rule.get(field_name, "")).is_empty():
			problems.append("%s has a rule without %s" % [label, field_name])
	if not rule.get("text") is Dictionary or not rule.get("state") is Dictionary:
		problems.append("%s rule %s needs text and state" % [label, rule.get("id", "")])
		return
	_check_objects(rule["state"], "%s rule %s" % [label, rule.get("id", "")], problems)


## A rule the room's own words cannot say would silently never fire. A language without a word list has the whole pool.
## `dropped` says the drop adds the rule's own words when it is one of the round's exit rules.
static func _check_writable(rule: Variant, checked: Dictionary, label: String, problems: Array[String], dropped: bool = false) -> void:
	if not rule is Dictionary:
		return
	for locale_code: String in SUPPORTED_LOCALES:
		var listed: Array = (checked["words"] as Dictionary).get(locale_code, [])
		if listed.is_empty():
			continue
		if dropped:
			listed = listed + WordDropScript.sentence_units(rule, locale_code, checked)
		if not RoomRulesScript.can_be_written(rule, listed, locale_code, checked):
			problems.append("%s rule %s cannot be written with its %s words" % [label, rule.get("id", ""), locale_code])


static func _check_objects(state: Dictionary, label: String, problems: Array[String]) -> void:
	for object_name: Variant in (state.get("objects", {}) as Dictionary):
		if object_name not in OBJECTS:
			problems.append("%s names an unknown object %s" % [label, object_name])
