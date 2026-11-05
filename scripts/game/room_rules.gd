class_name RoomRules
extends RefCounted
## Pure rules over a room's data (ADR 0009): `judge` reads a sentence with the rule engine and looks it up in the room,
## `world_state` lays the rules in force over the room's own state, and `escaped` answers whether one of the room's
## escapes holds. A red post is a sentence that hit a rule.

const RuleEngineScript = preload("res://scripts/narrative/rule_engine.gd")

## The ways out a room can declare: this round's post and the NPC's conversation, or one of its rules in force.
const ESCAPE_DELIVERY := "delivery"
const ESCAPE_RULE := "rule"
const ESCAPE_KINDS := [ESCAPE_DELIVERY, ESCAPE_RULE]
## What the NPC's help opens: the exit door (#129).
const DELIVERY_EXIT := "door"


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
		rule = _loose_rule(room, units, locale, bool(result["negated"]), predicates)
	if rule.is_empty():
		return result
	result["tier"] = "rule"
	result["subject"] = str(rule["subject"])
	result["predicate"] = str(rule["predicate"])
	result["rule_key"] = "%s|%s" % [rule["subject"], rule["predicate"]]
	result["rule_id"] = str(rule["id"])
	return result


## The room's state with the rules in force laid over it, in the room's rule order. Empty for no room.
static func world_state(room: Dictionary, rules: Dictionary, round_number: int) -> Dictionary:
	if room.is_empty():
		return {}
	var state: Dictionary = (room.get("state", {}) as Dictionary).duplicate(true)
	for rule: Dictionary in _rules_in_force(room, rules, round_number):
		_lay_over(state, rule.get("state", {}))
	return state


## Whether any of the room's escapes holds. `talked_with_post` says the NPC's conversation was just finished with a
## post made in this round.
static func escaped(room: Dictionary, rules: Dictionary, round_number: int, talked_with_post: bool) -> bool:
	return not open_exits(room, rules, round_number, talked_with_post).is_empty()


## The room objects the escapes that hold make exits, once each, in the room's escape order: a `rule` escape makes its
## rule's `object` the exit, and the NPC's help (`delivery`) opens the exit door. `talked_with_post` says the NPC's
## conversation was just finished with a post made in this round.
static func open_exits(room: Dictionary, rules: Dictionary, round_number: int, talked_with_post: bool) -> Array:
	var in_force := _rules_in_force(room, rules, round_number)
	var objects: Array = []
	for escape: Variant in room.get("escapes", []):
		if not escape is Dictionary:
			continue
		var object_name := ""
		match escape.get("kind"):
			ESCAPE_DELIVERY:
				if talked_with_post:
					object_name = DELIVERY_EXIT
			ESCAPE_RULE:
				for rule: Dictionary in in_force:
					if rule.get("id") == escape.get("rule"):
						object_name = str(rule.get("object", ""))
		if not object_name.is_empty() and object_name not in objects:
			objects.append(object_name)
	return objects


## Whether the room stands an NPC to talk it open: it declares the `delivery` escape. A room that opens by its rules
## alone (#120) has nobody to talk to.
static func stands_npc(room: Dictionary) -> bool:
	for escape: Variant in room.get("escapes", []):
		if escape is Dictionary and escape.get("kind") == ESCAPE_DELIVERY:
			return true
	return false


## The room's exit rules: the rules it offers that one of its `rule` escapes names, in the room's rule order.
static func exit_rules(room: Dictionary) -> Array[Dictionary]:
	var escape_ids: Array = []
	for escape: Variant in room.get("escapes", []):
		if escape is Dictionary and escape.get("kind") == ESCAPE_RULE:
			escape_ids.append(escape.get("rule"))
	var result: Array[Dictionary] = []
	for rule: Dictionary in room.get("rules", []):
		if rule.get("id") in escape_ids:
			result.append(rule)
	return result


## The room's rules that hold now, in the room's order: `rules` is the world rules map, and only rules made in
## `round_number` count, at their newest polarity.
static func _rules_in_force(room: Dictionary, rules: Dictionary, round_number: int) -> Array[Dictionary]:
	var in_force: Array[Dictionary] = []
	for rule: Dictionary in room.get("rules", []):
		var entry: Variant = rules.get("%s|%s" % [rule.get("subject", ""), rule.get("predicate", "")])
		if entry is Dictionary and int(entry.get("round", 0)) == round_number and bool(entry.get("negated", false)) == bool(rule.get("negated", false)):
			in_force.append(rule)
	return in_force


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


static func _loose_rule(room: Dictionary, units: Array, locale: String, negated: bool, predicates: Dictionary) -> Dictionary:
	var all_subjects := _all_subjects(locale, room)
	var all_predicates: Dictionary = (RuleEngineScript.PREDICATE_CANON.get(locale, {}) as Dictionary).merged(predicates, true)
	for rule: Dictionary in room.get("rules", []):
		if bool(rule.get("negated", false)) != negated:
			continue
		if _names_lie_in(all_subjects, rule.get("subject"), units, locale) and _names_lie_in(all_predicates, rule.get("predicate"), units, locale):
			return rule
	return {}


## Whether a sentence of `listed` units can say the rule. `RoomContent.validate` asks, so an unwritable rule fails a test.
static func can_be_written(rule: Dictionary, listed: Array, locale: String, room: Dictionary) -> bool:
	var all_subjects := _all_subjects(locale, room)
	var all_predicates := _all_predicates(locale, room)
	return _names_lie_in(all_subjects, rule.get("subject"), listed, locale) and _names_lie_in(all_predicates, rule.get("predicate"), listed, locale)


## The units of every word that means `subject` in a language: one list per word of the synonym group.
static func subject_word_units(subject: String, locale: String, room: Dictionary) -> Array:
	var all_subjects := _all_subjects(locale, room)
	var result: Array = []
	for word: String in all_subjects:
		if all_subjects[word] == subject:
			result.append(RuleEngineScript.word_units(word, locale))
	return result


## The units of every word that means `predicate` in a language: one list per word.
static func predicate_word_units(predicate: String, locale: String, room: Dictionary) -> Array:
	var all_predicates := _all_predicates(locale, room)
	var result: Array = []
	for word: String in all_predicates:
		if all_predicates[word] == predicate:
			result.append(RuleEngineScript.word_units(word, locale))
	return result


## Whether every unit of some word meaning `meaning` is in the sentence, in any order.
static func _names_lie_in(canon: Dictionary, meaning: Variant, units: Array, locale: String) -> bool:
	for word: String in canon:
		if canon[word] == meaning and RuleEngineScript.word_units(word, locale).all(func(unit: String) -> bool: return unit in units):
			return true
	return false


static func _all_predicates(locale: String, room: Dictionary) -> Dictionary:
	return (RuleEngineScript.PREDICATE_CANON.get(locale, {}) as Dictionary).merged(_vocabulary(room, "predicates", locale), true)


static func _all_subjects(locale: String, room: Dictionary) -> Dictionary:
	return (RuleEngineScript.SUBJECT_CANON.get(locale, {}) as Dictionary).merged(_vocabulary(room, "subjects", locale), true)


static func _vocabulary(room: Dictionary, part: String, locale: String) -> Dictionary:
	return ((room.get("vocabulary", {}) as Dictionary).get(part, {}) as Dictionary).get(locale, {})
