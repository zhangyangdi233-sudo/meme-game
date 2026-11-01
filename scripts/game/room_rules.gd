class_name RoomRules
extends RefCounted
## Pure rules over a room's data (ADR 0009): `judge` reads a sentence with the rule engine and looks it up in the room,
## and `world_state` lays the rules in force over the room's own state. A red post is a sentence that hit a rule.

const RuleEngineScript = preload("res://scripts/narrative/rule_engine.gd")


## Answers the same fields as `RuleEngine.parse`, plus the room's `rule_id`. The tier is `rule` (a red post) only for a
## rule of this room; every other sentence is `misread` or `noise` (a green post). An exact reading comes first; the
## loose match then accepts a rule whose words all lie somewhere in the sentence.
static func judge(units: Array, locale: String, room: Dictionary) -> Dictionary:
	var subjects := _vocabulary(room, "subjects", locale)
	var predicates := _vocabulary(room, "predicates", locale)
	var result := RuleEngineScript.read_sentence(units, locale, subjects, predicates)
	result["tier"] = "noise" if str(result["subject"]).is_empty() and str(result["predicate"]).is_empty() else "misread"
	result["rule_key"] = ""
	result["rule_id"] = ""
	var rule := _exact_rule(room, result)
	if rule.is_empty():
		rule = _loose_rule(room, units, locale, bool(result["negated"]), subjects, predicates)
	if rule.is_empty():
		return result
	result["tier"] = "rule"
	result["subject"] = str(rule["subject"])
	result["predicate"] = str(rule["predicate"])
	result["rule_key"] = "%s|%s" % [rule["subject"], rule["predicate"]]
	result["rule_id"] = str(rule["id"])
	return result


## The room's state with the rules in force laid over it, in the room's rule order. `rules` is the world rules map; only
## rules made in `round_number` count, at their newest polarity. Empty for no room.
static func world_state(room: Dictionary, rules: Dictionary, round_number: int) -> Dictionary:
	if room.is_empty():
		return {}
	var state: Dictionary = (room.get("state", {}) as Dictionary).duplicate(true)
	for rule: Dictionary in room.get("rules", []):
		var entry: Variant = rules.get("%s|%s" % [rule.get("subject", ""), rule.get("predicate", "")])
		if not entry is Dictionary or int(entry.get("round", 0)) != round_number:
			continue
		if bool(entry.get("negated", false)) == bool(rule.get("negated", false)):
			_lay_over(state, rule.get("state", {}))
	return state


static func _lay_over(state: Dictionary, change: Dictionary) -> void:
	for field_name: String in change:
		if field_name == "objects":
			(state["objects"] as Dictionary).merge(change["objects"], true)
		else:
			state[field_name] = change[field_name]


static func _exact_rule(room: Dictionary, reading: Dictionary) -> Dictionary:
	for rule: Dictionary in room.get("rules", []):
		if (
			rule.get("subject") == reading["subject"]
			and rule.get("predicate") == reading["predicate"]
			and bool(rule.get("negated", false)) == reading["negated"]
		):
			return rule
	return {}


static func _loose_rule(room: Dictionary, units: Array, locale: String, negated: bool, subjects: Dictionary, predicates: Dictionary) -> Dictionary:
	var all_subjects: Dictionary = (RuleEngineScript.SUBJECT_CANON.get(locale, {}) as Dictionary).merged(subjects, true)
	var all_predicates: Dictionary = (RuleEngineScript.PREDICATE_CANON.get(locale, {}) as Dictionary).merged(predicates, true)
	for rule: Dictionary in room.get("rules", []):
		if bool(rule.get("negated", false)) != negated:
			continue
		if _names_lie_in(all_subjects, rule.get("subject"), units, locale) and _names_lie_in(all_predicates, rule.get("predicate"), units, locale):
			return rule
	return {}


## Whether a sentence of `listed` units can say the rule. `RoomContent.validate` asks, so an unwritable rule fails a test.
static func can_be_written(rule: Dictionary, listed: Array, locale: String, room: Dictionary) -> bool:
	var all_subjects: Dictionary = (RuleEngineScript.SUBJECT_CANON.get(locale, {}) as Dictionary).merged(_vocabulary(room, "subjects", locale), true)
	var all_predicates: Dictionary = (RuleEngineScript.PREDICATE_CANON.get(locale, {}) as Dictionary).merged(_vocabulary(room, "predicates", locale), true)
	return _names_lie_in(all_subjects, rule.get("subject"), listed, locale) and _names_lie_in(all_predicates, rule.get("predicate"), listed, locale)


## Whether every unit of some word meaning `meaning` is in the sentence, in any order.
static func _names_lie_in(canon: Dictionary, meaning: Variant, units: Array, locale: String) -> bool:
	for word: String in canon:
		if canon[word] == meaning and RuleEngineScript.word_units(word, locale).all(func(unit: String) -> bool: return unit in units):
			return true
	return false


static func _vocabulary(room: Dictionary, part: String, locale: String) -> Dictionary:
	return ((room.get("vocabulary", {}) as Dictionary).get(part, {}) as Dictionary).get(locale, {})
