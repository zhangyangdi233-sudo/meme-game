class_name CrtLesson
extends RefCounted
## Round one's locked lesson inside the CRT terminal: the old version's beginner tutorial, restored by the planner on
## 2026-11-16 ("教程是旧版"), fitted to #119's rules. It teaches the round's door exit rule, so the player ends it with
## a red post that opens the exit door. The step is read from the models each time they change, like `BasementGuide`:
## nothing is saved and nothing runs on a timer. Leaving the screen and coming back resumes at the derived step; once
## the round's exit stands open the lesson is over for good (also when the player opened it on the phone).
##   post      a lesson word is still missing and the open post offers none of the missing ones: open a post that does
##   collect   the open post offers missing words: pick them up (only those)
##   notebook  every lesson word is held and the notebook is not showing: open it
##   compose   the notebook shows and the sentence is not yet the lesson's words: place them (only those)
##   publish   the sentence is exactly the lesson's words: post it

const ChapterOneProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const NarrativeSessionCatalogScript = preload("res://scripts/game/narrative_session_catalog.gd")
const PickupCharPoolScript = preload("res://scripts/narrative/pickup_char_pool.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const WordDropScript = preload("res://scripts/game/word_drop.gd")

const STEP_POST := "post"
const STEP_COLLECT := "collect"
const STEP_NOTEBOOK := "notebook"
const STEP_COMPOSE := "compose"
const STEP_PUBLISH := "publish"
const STEPS := [STEP_POST, STEP_COLLECT, STEP_NOTEBOOK, STEP_COMPOSE, STEP_PUBLISH]
## The lesson runs in the first basement round only, as the old one did.
const ROUND := 1
## The rule it teaches: the round's door exit, so the lesson ends with the exit door open (#119: a round is left by
## posting "X 是出口").
const RULE := "door_exit"
## The copula a language puts between the subject and "exit"; the lesson adds it only where the round drops it, so the
## lesson's words are always words the round lets the player pick up.
const COPULAS := {"zh": "是", "en": "is", "ja": "は"}
## The old overlay's colours for the open post's words: other text, lesson words already held, lesson words to pick.
const OTHER_TEXT_COLOR := "72796c"
const HELD_COLOR := "84917c"
const LIT_COLOR := "f0ffbe"
## Intents the lesson never refuses: leaving the screen, and the notebook keeping its tiles' resting places.
const ALWAYS_ALLOWED := [UiIntentsScript.TERMINAL_EXIT_REQUESTED, UiIntentsScript.NOTEBOOK_CANVAS_POSITIONS_COMMITTED]


## The lesson's words in a language: the shortest natural sentence of the door exit rule (`WordDrop.sentence_units`)
## with the copula after the subject where the round's own words hold it. Empty when the room offers no such rule.
static func teaching_units(room: Dictionary, locale: String) -> Array:
	var rule := _rule(room)
	if rule.is_empty():
		return []
	var units: Array = WordDropScript.sentence_units(rule, locale, room)
	var copula := str(COPULAS.get(locale, ""))
	var listed: Array = (room.get("words", {}) as Dictionary).get(locale, [])
	if copula.is_empty() or copula not in listed or copula in units:
		return units
	# The predicate's units close the sentence; the copula goes right before them.
	var predicate: Array = WordDropScript.sentence_units({"predicate": rule.get("predicate", "")}, locale, room)
	units.insert(units.size() - predicate.size(), copula)
	return units


## The lesson's step, or empty when there is none: outside round one, once the round's exit is open, or for a room
## without the rule. `held` are the notebook's words in this language, `sentence` the units being composed,
## `open_post_offers` the missing lesson words the open post lets the player pick up (empty with no post open) and
## `notebook_showing` whether the terminal shows the notebook.
static func step(progress: Dictionary, teaching: Array, held: Array, sentence: Array, open_post_offers: Array, notebook_showing: bool) -> String:
	if ChapterOneProgressScript.round_of(progress) != ROUND or ChapterOneProgressScript.exit_open(progress) or teaching.is_empty():
		return ""
	if not missing(teaching, held).is_empty():
		return STEP_COLLECT if not open_post_offers.is_empty() else STEP_POST
	if not notebook_showing:
		return STEP_NOTEBOOK
	return STEP_PUBLISH if is_exact(teaching, sentence) else STEP_COMPOSE


## The lesson's words not yet held, in the lesson's order.
static func missing(teaching: Array, held: Array) -> Array:
	return teaching.filter(func(unit: Variant) -> bool: return unit not in held)


## The missing lesson words a post lets the player pick up, in the lesson's order.
static func offered_by(post_id: String, missing_units: Array, locale: String) -> Array:
	if post_id.is_empty():
		return []
	return missing_units.filter(func(unit: Variant) -> bool: return PickupCharPoolScript.is_unit_seeded_in_post(post_id, str(unit), locale))


## Whether the sentence holds the lesson's words and nothing else. The rule engine reads any word order, so the order the
## words were placed in does not matter.
static func is_exact(teaching: Array, sentence: Array) -> bool:
	return sentence.size() == teaching.size() and stray_index(teaching, sentence) < 0


## The index of the first unit the lesson's sentence cannot keep: a word that is not one of the lesson's, or one more of
## a lesson word than the lesson needs; -1 when every unit belongs. A word placed on the phone before the lesson would
## otherwise leave the compose step with no way on inside the terminal, whose notebook has no take-out control.
static func stray_index(teaching: Array, sentence: Array) -> int:
	var remaining: Array = teaching.duplicate()
	for index in sentence.size():
		var at := remaining.find(sentence[index])
		if at < 0:
			return index
		remaining.remove_at(at)
	return -1


## Whether the lesson lets an intent raised from the terminal through at this step, as the old `tutorial_allows` did.
## `context` carries `teaching`, `missing`, `open_post_id`, `offering_posts` (the feed's post indices that offer a
## missing word) and `unit_posts` (post id for pickups). Leaving the screen is always allowed.
static func allows(current_step: String, intent_name: String, payload: Dictionary, context: Dictionary) -> bool:
	if current_step.is_empty() or intent_name in ALWAYS_ALLOWED:
		return true
	var teaching: Array = context.get("teaching", [])
	match intent_name:
		UiIntentsScript.SOCIAL_CARD_CLICKED:
			return current_step == STEP_POST and int(payload.get(UiIntentsScript.KEY_POST_INDEX, -1)) in (context.get("offering_posts", []) as Array)
		UiIntentsScript.SOCIAL_PICKUP_UNIT_CLICKED:
			return (
				current_step == STEP_COLLECT
				and str(payload.get(UiIntentsScript.KEY_POST_ID, "")) == str(context.get("open_post_id", ""))
				and str(payload.get(UiIntentsScript.KEY_META, "")) in (context.get("missing", []) as Array)
			)
		UiIntentsScript.TERMINAL_APP_SELECTED:
			return current_step == STEP_NOTEBOOK and str(payload.get(UiIntentsScript.KEY_APP_ID, "")) == "notebook"
		UiIntentsScript.NOTEBOOK_COMPOSER_BANK_TAPPED, UiIntentsScript.NOTEBOOK_CANVAS_TILE_DROPPED_OUTSIDE:
			return current_step == STEP_COMPOSE and str(payload.get(UiIntentsScript.KEY_UNIT, "")) in teaching
		UiIntentsScript.NOTEBOOK_CRAFT_REQUESTED:
			return current_step == STEP_PUBLISH
	return false


## The caption of a step in a language, its `%s` filled with the lesson's words joined like the old captions.
static func caption(current_step: String, locale: String, teaching: Array) -> String:
	var text := NarrativeSessionCatalogScript.crt_lesson_caption(current_step, locale)
	if "%s" in text:
		text = text.replace("%s", " / ".join(teaching.map(func(unit: Variant) -> String: return str(unit))))
	return text


## The open post's words as the lesson shows them (the old overlay's rewrite): the words still to pick are lit and
## clickable, lesson words already held are dimmed, and everything else is greyed and inert.
static func lesson_bbcode(source_text: String, locale: String, lit: Array, held: Array, teaching: Array) -> String:
	var units: Array = teaching.duplicate()
	units.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left).length() > str(right).length())
	var result := ""
	var plain := ""
	var index := 0
	while index < source_text.length():
		var matched := ""
		for unit_value: Variant in units:
			var unit := str(unit_value)
			if unit.is_empty() or index + unit.length() > source_text.length():
				continue
			var slice := source_text.substr(index, unit.length())
			if locale == "en":
				if slice.to_lower() != unit.to_lower() or not _word_boundary_ok(source_text, index, unit.length()):
					continue
			elif slice != unit:
				continue
			matched = unit
			break
		if matched.is_empty():
			plain += source_text.substr(index, 1)
			index += 1
			continue
		result += _colored(plain, OTHER_TEXT_COLOR)
		plain = ""
		var shown := _escaped(source_text.substr(index, matched.length()))
		if matched in lit:
			result += "[color=#%s][url=%s][u]%s[/u][/url][/color]" % [LIT_COLOR, matched, shown]
		elif matched in held:
			result += "[color=#%s]%s[/color]" % [HELD_COLOR, shown]
		else:
			result += _colored(source_text.substr(index, matched.length()), OTHER_TEXT_COLOR)
		index += matched.length()
	return result + _colored(plain, OTHER_TEXT_COLOR)


static func _rule(room: Dictionary) -> Dictionary:
	for rule: Variant in room.get("rules", []):
		if rule is Dictionary and str((rule as Dictionary).get("id", "")) == RULE:
			return rule
	return {}


static func _colored(text: String, color: String) -> String:
	return "" if text.is_empty() else "[color=#%s]%s[/color]" % [color, _escaped(text)]


static func _escaped(value: String) -> String:
	var sentinel := String.chr(1)
	return value.replace("[", sentinel).replace("]", "[rb]").replace(sentinel, "[lb]")


static func _word_boundary_ok(text: String, start_index: int, unit_length: int) -> bool:
	if start_index > 0 and PickupCharPoolScript.is_word_character(text.substr(start_index - 1, 1)):
		return false
	var after_index := start_index + unit_length
	return after_index >= text.length() or not PickupCharPoolScript.is_word_character(text.substr(after_index, 1))
