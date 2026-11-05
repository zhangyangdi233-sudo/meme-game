class_name WordDrop
extends RefCounted
## The words a basement round drops into the signal waterfall, the ones its posts let the player pick up. They follow
## the pollution so far instead of a fixed list: the room's own words, plus the words of the first
## `guaranteed_exit_rules` (floor data) of its exit rules that pollution has not used up. The phone and the CRT read the
## same answer through `MemeGameState.get_pickup_unit_pool`. A language the room has not written keeps the whole pool.

const PickupCharPoolScript = preload("res://scripts/narrative/pickup_char_pool.gd")
const PollutionPolicyScript = preload("res://scripts/game/pollution_policy.gd")
const RoomRulesScript = preload("res://scripts/game/room_rules.gd")
const RuleEngineScript = preload("res://scripts/narrative/rule_engine.gd")


## The units a round drops in a language, given the run's polluted-words map.
static func units(room: Dictionary, locale: String, polluted: Dictionary, policy: Dictionary) -> Array:
	var listed: Array = (room.get("words", {}) as Dictionary).get(locale, [])
	if listed.is_empty():
		return PickupCharPoolScript.get_unit_pool(locale)
	var result: Array = listed.duplicate()
	for rule: Dictionary in exit_rules(room, locale, polluted, policy):
		for unit: String in sentence_units(rule, locale, room):
			if unit not in result:
				result.append(unit)
	return result


## The exit rules a round drops the words of: the first ones in the room's order that pollution has not used up.
static func exit_rules(room: Dictionary, locale: String, polluted: Dictionary, policy: Dictionary) -> Array[Dictionary]:
	var wanted := int(room.get("guaranteed_exit_rules", 0))
	var result: Array[Dictionary] = []
	for rule: Dictionary in RoomRulesScript.exit_rules(room):
		if result.size() >= wanted:
			break
		if not used_up(rule, locale, room, polluted, policy):
			result.append(rule)
	return result


## Whether pollution would void the rule, so posting it can change nothing.
static func used_up(rule: Dictionary, locale: String, room: Dictionary, polluted: Dictionary, policy: Dictionary) -> bool:
	var judged := {"tier": "rule", "subject": str(rule.get("subject", ""))}
	return PollutionPolicyScript.voids(judged, sentence_units(rule, locale, room), locale, room, polluted, policy)


## The shortest way to say the rule: a word for its subject, the negation when it has one, a word for its predicate.
## Each word is the first whose units the pool holds, so the drop never names a unit no post can carry.
static func sentence_units(rule: Dictionary, locale: String, room: Dictionary) -> Array:
	var result: Array = []
	result.append_array(_pickable_word(RoomRulesScript.subject_word_units(str(rule.get("subject", "")), locale, room), locale))
	if bool(rule.get("negated", false)):
		var negations: Array = RuleEngineScript.NEGATION_WORDS.get(locale, [])
		if not negations.is_empty():
			result.append_array(RuleEngineScript.word_units(str(negations[0]), locale))
	result.append_array(_pickable_word(RoomRulesScript.predicate_word_units(str(rule.get("predicate", "")), locale, room), locale))
	return result


static func _pickable_word(words: Array, locale: String) -> Array:
	var pool := PickupCharPoolScript.get_unit_pool(locale)
	for word_units: Array in words:
		if word_units.all(func(unit: String) -> bool: return unit in pool):
			return word_units
	return words[0] if not words.is_empty() else []
