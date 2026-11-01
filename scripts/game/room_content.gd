class_name RoomContent
extends RefCounted
## Loads the basement's room data from JSON: one room per round, with its words, its rules, its escapes, its state and
## its one-shot events. See ADR 0009. Rooms are read-only; `RoomRules` judges against them.

const ChapterOneProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const ContentJsonScript = preload("res://framework/content_json.gd")
const PickupCharPoolScript = preload("res://scripts/narrative/pickup_char_pool.gd")
const RoomRulesScript = preload("res://scripts/game/room_rules.gd")

const ROOMS_PATH := "res://content/basement_rooms.json"
const SUPPORTED_LOCALES := ["zh", "ja", "en"]
## The room objects the chapter stage can show or hide. A room can only name these.
const OBJECTS := ["exit_lamp"]


## The room of a basement round, or empty when there is none. Callers do not change it.
static func room(round_number: int, path: String = ROOMS_PATH) -> Dictionary:
	var rooms: Dictionary = ContentJsonScript.load_dictionary_cached(path, "RoomContent").get("rooms", {})
	return rooms.get(str(round_number), {})


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


static func validate(path: String = ROOMS_PATH) -> Dictionary:
	var problems := problems_in(ContentJsonScript.load_dictionary_cached(path, "RoomContent"))
	return {"ok": problems.is_empty(), "problems": problems}


## Names everything wrong with a rooms catalog, so an authoring slip fails a test instead of a playthrough.
static func problems_in(catalog: Dictionary, room_count: int = ChapterOneProgressScript.BASEMENT_ROUND_COUNT) -> Array[String]:
	var problems: Array[String] = []
	var rooms: Dictionary = catalog.get("rooms", {})
	for round_number in range(1, room_count + 1):
		if not rooms.get(str(round_number)) is Dictionary:
			problems.append("round %d has no room" % round_number)
			continue
		_check_room(rooms[str(round_number)], "round %d" % round_number, problems)
	return problems


static func _check_room(checked: Dictionary, label: String, problems: Array[String]) -> void:
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
	for rule: Variant in checked["rules"]:
		_check_rule(rule, label, problems)
		_check_writable(rule, checked, label, problems)
	_check_escapes(checked, label, problems)
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
