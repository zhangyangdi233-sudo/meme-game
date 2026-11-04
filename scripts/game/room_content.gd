class_name RoomContent
extends RefCounted
## Loads a floor's room data from JSON: the floor's rule box, then one room per round, with its words, the rules of the
## box it offers, its escapes, its state and its one-shot events. See ADR 0009. Rooms are read-only; `RoomRules` judges
## against them.

const ChapterOneProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const ContentJsonScript = preload("res://framework/content_json.gd")
const PickupCharPoolScript = preload("res://scripts/narrative/pickup_char_pool.gd")
const PollutionPolicyScript = preload("res://scripts/game/pollution_policy.gd")
const RoomRulesScript = preload("res://scripts/game/room_rules.gd")

const ROOMS_PATH := "res://content/basement_rooms.json"
const SUPPORTED_LOCALES := ["zh", "ja", "en"]
## The room objects the chapter stage can show or hide. A room can only name these.
const OBJECTS := ["exit_lamp"]


## The room of a round, or empty when there is none, with the rules it offers taken from the floor's rule box. Callers
## do not change it.
static func room(round_number: int, path: String = ROOMS_PATH) -> Dictionary:
	var catalog: Dictionary = ContentJsonScript.load_dictionary_cached(path, "RoomContent")
	var authored: Variant = (catalog.get("rooms", {}) as Dictionary).get(str(round_number))
	return _resolved(authored, _rule_box(catalog)) if authored is Dictionary else {}


## The words a round offers in a language. A language the room has not written keeps the whole pool.
static func words(round_number: int, locale_code: String, path: String = ROOMS_PATH) -> Array:
	var listed: Array = (room(round_number, path).get("words", {}) as Dictionary).get(locale_code, [])
	return listed.duplicate() if not listed.is_empty() else PickupCharPoolScript.get_unit_pool(locale_code)


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
	var box := _rule_box(catalog)
	var rooms: Dictionary = catalog.get("rooms", {})
	for round_number in range(1, room_count + 1):
		if not rooms.get(str(round_number)) is Dictionary:
			problems.append("round %d has no room" % round_number)
			continue
		_check_room(rooms[str(round_number)], box, "round %d" % round_number, problems)
	return problems


## The box's rules by id. A rule without an id, or one repeating an id, is left out; `_check_rule_box` reports it.
static func _rule_box(catalog: Dictionary) -> Dictionary:
	var box := {}
	var listed: Variant = catalog.get("rule_box")
	for rule: Variant in listed if listed is Array else []:
		if rule is Dictionary and not str(rule.get("id", "")).is_empty() and not box.has(str(rule["id"])):
			box[str(rule["id"])] = rule
	return box


## The room as callers read it: its rule ids replaced by the box's rules, in the room's order. An id the box lacks is
## dropped; `_check_room` reports it.
static func _resolved(authored: Dictionary, box: Dictionary) -> Dictionary:
	var resolved := authored.duplicate()
	var rules: Array = []
	var listed: Variant = authored.get("rules")
	for rule_id: Variant in listed if listed is Array else []:
		if rule_id is String and box.has(rule_id):
			rules.append(box[rule_id])
	resolved["rules"] = rules
	return resolved


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


static func _check_room(checked: Dictionary, box: Dictionary, label: String, problems: Array[String]) -> void:
	for field_name: String in ["words", "state"]:
		if not checked.get(field_name) is Dictionary:
			problems.append("%s has no %s" % [label, field_name])
			return
	for field_name: String in ["rules", "escapes", "events"]:
		if not checked.get(field_name) is Array:
			problems.append("%s has no %s" % [label, field_name])
			return
	for locale_code: String in SUPPORTED_LOCALES:
		if not (checked["words"] as Dictionary).get(locale_code) is Array:
			problems.append("%s has no word list for %s" % [label, locale_code])
	var state: Dictionary = checked["state"]
	for field_name: String in ["brightness", "hum"]:
		if not (state.get(field_name) is float or state.get(field_name) is int):
			problems.append("%s has no %s" % [label, field_name])
	if not state.get("objects") is Dictionary:
		problems.append("%s has no objects" % label)
		return
	_check_objects(state, label, problems)
	_check_offered(checked, box, label, problems)
	var resolved := _resolved(checked, box)
	for rule: Dictionary in resolved["rules"]:
		_check_writable(rule, resolved, label, problems)
	_check_escapes(resolved, label, problems)
	var event_ids: Array[String] = []
	for event: Variant in checked["events"]:
		if not event is Dictionary or str(event.get("id", "")).is_empty() or str(event.get("trigger", "")).is_empty():
			problems.append("%s has an event without an id or a trigger" % label)
		elif str(event["id"]) in event_ids:
			problems.append("%s repeats the event %s" % [label, event["id"]])
		else:
			event_ids.append(str(event["id"]))


## A room nobody can leave would stop the run, and a rule escape naming no rule of its room would never open.
static func _check_escapes(checked: Dictionary, label: String, problems: Array[String]) -> void:
	if (checked["escapes"] as Array).is_empty():
		problems.append("%s has no escape" % label)
	var rule_ids: Array = []
	for rule: Variant in checked["rules"]:
		if rule is Dictionary:
			rule_ids.append(rule.get("id"))
	for escape: Variant in checked["escapes"]:
		if not escape is Dictionary or escape.get("kind") not in RoomRulesScript.ESCAPE_KINDS:
			problems.append("%s has an unknown escape %s" % [label, escape])
		elif escape["kind"] == RoomRulesScript.ESCAPE_RULE and escape.get("rule") not in rule_ids:
			problems.append("%s has an escape naming no rule of its room: %s" % [label, escape.get("rule")])


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
static func _check_writable(rule: Variant, checked: Dictionary, label: String, problems: Array[String]) -> void:
	if not rule is Dictionary:
		return
	for locale_code: String in SUPPORTED_LOCALES:
		var listed: Array = (checked["words"] as Dictionary).get(locale_code, [])
		if not listed.is_empty() and not RoomRulesScript.can_be_written(rule, listed, locale_code, checked):
			problems.append("%s rule %s cannot be written with its %s words" % [label, rule.get("id", ""), locale_code])


static func _check_objects(state: Dictionary, label: String, problems: Array[String]) -> void:
	for object_name: Variant in (state.get("objects", {}) as Dictionary):
		if object_name not in OBJECTS:
			problems.append("%s names an unknown object %s" % [label, object_name])
