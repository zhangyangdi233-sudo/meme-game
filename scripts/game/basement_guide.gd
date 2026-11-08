class_name BasementGuide
extends RefCounted
## The CRT's narrator in a basement round (#125): which step of the round the player is on, read from the models
## alone, and the line authored for it (`basement_guide` in `content/narrative_session.json`, per round). A round with
## no lines says nothing. The steps run: pick words, put them in a sentence, post it; after a post, whether it missed,
## pollution voided it or it was heard without opening the exit; and once the exit is open, walk out.

const ChapterOneProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const NarrativeSessionCatalogScript = preload("res://scripts/game/narrative_session_catalog.gd")

const STEP_PICK := "pick"
const STEP_COMPOSE := "compose"
const STEP_POST := "post"
const STEP_MISSED := "missed"
const STEP_VOIDED := "voided"
const STEP_HEARD := "heard"
const STEP_OPEN := "open"
const STEPS := [STEP_PICK, STEP_COMPOSE, STEP_POST, STEP_MISSED, STEP_VOIDED, STEP_HEARD, STEP_OPEN]


## The step the round is on, or empty outside the basement. `held` is the notebook's words, `sentence` the units being
## composed and `last_post` this round's newest post (`PostSlip.latest`), or empty.
static func step(progress: Dictionary, held: Array, sentence: Array, last_post: Dictionary) -> String:
	if ChapterOneProgressScript.round_of(progress) <= 0:
		return ""
	if ChapterOneProgressScript.exit_open(progress):
		return STEP_OPEN
	if not sentence.is_empty():
		return STEP_POST
	if not last_post.is_empty():
		if str(last_post.get("tier", "")) == "rule":
			return STEP_HEARD
		return STEP_VOIDED if bool(last_post.get("voided", false)) else STEP_MISSED
	return STEP_COMPOSE if not held.is_empty() else STEP_PICK


## The narrator's line for where the round stands, or empty when the round has none.
static func line(progress: Dictionary, held: Array, sentence: Array, last_post: Dictionary, locale_code: String) -> String:
	var current := step(progress, held, sentence, last_post)
	if current.is_empty():
		return ""
	return NarrativeSessionCatalogScript.basement_guide_line(ChapterOneProgressScript.round_of(progress), current, locale_code)


## Names everything wrong with a floor's `basement_guide`: a round the basement lacks, an unknown step, a line missing
## a language. No guide at all is fine.
static func problems_in(guide: Variant) -> Array[String]:
	var problems: Array[String] = []
	if guide == null:
		return problems
	if not guide is Dictionary:
		problems.append("the basement guide is not a table")
		return problems
	for round_key: Variant in guide:
		var round_number := int(str(round_key)) if str(round_key).is_valid_int() else 0
		if round_number < 1 or round_number > ChapterOneProgressScript.BASEMENT_ROUND_COUNT:
			problems.append("the basement guide names round %s, which the basement lacks" % round_key)
			continue
		var steps: Variant = guide[round_key]
		if not steps is Dictionary:
			problems.append("the basement guide of round %d is not a table" % round_number)
			continue
		for step_name: Variant in steps:
			if step_name not in STEPS:
				problems.append("the basement guide of round %d has an unknown step %s" % [round_number, step_name])
				continue
			for locale_code: String in NarrativeSessionCatalogScript.SUPPORTED_LOCALES:
				var localized: Variant = steps[step_name]
				if not localized is Dictionary or str((localized as Dictionary).get(locale_code, "")).is_empty():
					problems.append("the basement guide of round %d has no %s line for %s" % [round_number, locale_code, step_name])
	return problems
