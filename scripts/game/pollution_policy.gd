class_name PollutionPolicy
extends RefCounted
## Word pollution's rules in one place: what a red post pollutes and whether a sentence is void for it. The settings
## live in `content/pollution_policy.json`, so changing a rule changes that file. `polluted` is the run's polluted-words
## map: `units` (locale -> the units red posts used) and `subjects` (the synonym groups used up, by their rule subject).

const ContentJsonScript = preload("res://framework/content_json.gd")
const RoomRulesScript = preload("res://scripts/game/room_rules.gd")
const RuleEngineScript = preload("res://scripts/narrative/rule_engine.gd")

const POLICY_PATH := "res://content/pollution_policy.json"
const GLYPHS := ["■", "▦", "∴", "□", "▧", "≠"]


static func settings(path: String = POLICY_PATH) -> Dictionary:
	return ContentJsonScript.load_dictionary_cached(path, "PollutionPolicy")


## Whether a red post may pollute, given whether this round's exit stood open before it.
static func may_pollute(exit_was_open: bool, policy: Dictionary) -> bool:
	return not exit_was_open or bool(policy.get("pollute_after_exit_opens", false))


## `polluted` after a red post of `units` on `subject`. A subject of skeleton words alone pollutes nothing.
static func pollute(polluted: Dictionary, units: Array, subject: String, locale: String, room: Dictionary, policy: Dictionary) -> Dictionary:
	var pollutable := _pollutable(_subject_units_in(units, subject, locale, room), locale, policy)
	if pollutable.is_empty():
		return polluted
	var next := polluted.duplicate(true)
	var by_locale: Dictionary = next.get_or_add("units", {})
	var listed: Array = by_locale.get_or_add(locale, [])
	for unit: String in pollutable:
		if unit not in listed:
			listed.append(unit)
	if bool(policy.get("pollute_synonyms", false)):
		var subjects: Array = next.get_or_add("subjects", [])
		if subject not in subjects:
			subjects.append(subject)
	return next


## The polluted units of a language: those red posts used and those of every word in a used-up synonym group, also the
## words this room adds to the group.
static func polluted_units(polluted: Dictionary, locale: String, room: Dictionary, policy: Dictionary) -> Array:
	var result: Array = ((polluted.get("units", {}) as Dictionary).get(locale, []) as Array).duplicate()
	for subject: Variant in polluted.get("subjects", []):
		for word_units: Array in RoomRulesScript.subject_word_units(str(subject), locale, room):
			for unit: String in _pollutable(word_units, locale, policy):
				if unit not in result:
					result.append(unit)
	return result


## Whether pollution voids a sentence the room judged. Only a red judgement has something to lose.
static func voids(judged: Dictionary, units: Array, locale: String, room: Dictionary, polluted: Dictionary, policy: Dictionary) -> bool:
	if str(judged.get("tier", "")) != "rule":
		return false
	var subject := str(judged.get("subject", ""))
	if is_barred(subject, policy):
		return true
	var polluted_now := polluted_units(polluted, locale, room, policy)
	if bool(policy.get("subject_voids_rule", false)):
		return subject in polluted.get("subjects", []) or _subject_units_in(units, subject, locale, room).any(func(unit: String) -> bool: return unit in polluted_now)
	var polluted_count := units.filter(func(unit: Variant) -> bool: return unit in polluted_now).size()
	return float(polluted_count) / float(units.size()) > float(policy.get("void_ratio", 1.0))


## Whether no rule can hold on this subject.
static func is_barred(subject: Variant, policy: Dictionary) -> bool:
	return subject in policy.get("barred_subjects", [])


## A judgement pollution voided: a green post that says why.
static func voided(judged: Dictionary) -> Dictionary:
	return judged.merged({"tier": "misread", "rule_key": "", "rule_id": "", "voided": true}, true)


## Whether posting `units` in this room would hit a rule that pollution voids.
static func sentence_voids(units: Array, locale: String, room: Dictionary, polluted: Dictionary, policy: Dictionary) -> bool:
	return voids(RoomRulesScript.judge(units, locale, room), units, locale, room, polluted, policy)


## The sentence as the player sees it: polluted units are garbled, what the sentence says stays.
static func shown_units(units: Array, polluted_list: Array) -> Array:
	return units.map(func(unit: Variant) -> String: return garbled(str(unit)) if unit in polluted_list else str(unit))


## Authored wording with its polluted units garbled.
static func shown_text(text: String, polluted_list: Array) -> String:
	for unit: String in polluted_list:
		text = text.replace(unit, garbled(unit))
	return text


## One glyph per character, always the same for the same word.
static func garbled(unit: String) -> String:
	var text := ""
	for index in unit.length():
		text += GLYPHS[posmod(hash(unit) + index, GLYPHS.size())]
	return text


## The units of the words meaning `subject` that all lie in the sentence.
static func _subject_units_in(units: Array, subject: String, locale: String, room: Dictionary) -> Array:
	var result: Array = []
	for word_units: Array in RoomRulesScript.subject_word_units(subject, locale, room):
		if word_units.all(func(unit: String) -> bool: return unit in units):
			result.append_array(word_units)
	return result


static func _pollutable(units: Array, locale: String, policy: Dictionary) -> Array:
	var skeleton: Array = []
	for word: Variant in (policy.get("skeleton_words", {}) as Dictionary).get(locale, []):
		skeleton.append_array(RuleEngineScript.word_units(str(word), locale))
	return units.filter(func(unit: String) -> bool: return unit not in skeleton)
