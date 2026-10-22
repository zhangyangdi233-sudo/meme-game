class_name ChapterOneProgress
extends RefCounted
## Chapter one's progress rules on one progress dictionary: the opening narration is read one line at a time, the
## knock sounds on its line, and the door opens into the basement only once the narration is read and the knock heard.
## Every rule returns the next progress; a refused step returns the progress unchanged. `MemeGameState` keeps the
## dictionary in the `chapter_one_progress` model and saves it with the run.

const PHASE_OPENING := "opening"
const PHASE_BASEMENT := "basement"
## A run that skipped chapter one, or a save made before chapter one existed: the tower street.
const PHASE_TOWER := "tower"
const PHASES := [PHASE_OPENING, PHASE_BASEMENT, PHASE_TOWER]
## Spoken lines in the opening narration (the catalog's `opening` list).
const OPENING_LINE_COUNT := 29
## The line shown when the knock sounds: the one right after the manuscript's knock stage direction.
const KNOCK_LINE_INDEX := 26
const BASEMENT_ROUND_COUNT := 5

## A new run's progress. `PropertyKeys` uses it as the model's initial value.
const INITIAL := {
	"phase": PHASE_OPENING,
	"line_index": 0,
	"narration_complete": false,
	"knock_complete": false,
	"round": 0,
}


static func initial() -> Dictionary:
	return INITIAL.duplicate(true)


static func tower() -> Dictionary:
	var progress := initial()
	progress["phase"] = PHASE_TOWER
	return progress


## Reads any saved value back into a progress the rules accept. Unknown or broken values start the opening over;
## a step that was never earned (a knock before its line, a basement without the door) is dropped.
static func normalize(raw: Variant) -> Dictionary:
	var progress := initial()
	if not raw is Dictionary:
		return progress
	var source: Dictionary = raw
	var phase: Variant = source.get("phase", PHASE_OPENING)
	if not phase is String or phase not in PHASES:
		return progress
	if phase == PHASE_TOWER:
		return tower()
	progress["line_index"] = clampi(_integer_or(source.get("line_index", 0), 0), 0, OPENING_LINE_COUNT - 1)
	progress["narration_complete"] = _is_true(source.get("narration_complete", false))
	if progress["narration_complete"]:
		progress["line_index"] = OPENING_LINE_COUNT - 1
	progress["knock_complete"] = _is_true(source.get("knock_complete", false)) and int(progress["line_index"]) >= KNOCK_LINE_INDEX
	if phase == PHASE_BASEMENT and door_ready(progress):
		progress["phase"] = PHASE_BASEMENT
		progress["round"] = clampi(_integer_or(source.get("round", 1), 1), 1, BASEMENT_ROUND_COUNT)
	return progress


static func phase_of(progress: Dictionary) -> String:
	return str(progress.get("phase", PHASE_OPENING))


## The opening narration is on screen: movement, look and the phone stay locked.
static func is_reading_narration(progress: Dictionary) -> bool:
	return phase_of(progress) == PHASE_OPENING and not bool(progress.get("narration_complete", false))


## The knock should sound now: its line is shown (or already read) and it has not been heard to the end.
static func knock_due(progress: Dictionary) -> bool:
	if phase_of(progress) != PHASE_OPENING or bool(progress.get("knock_complete", false)):
		return false
	return bool(progress.get("narration_complete", false)) or int(progress.get("line_index", 0)) >= KNOCK_LINE_INDEX


static func door_ready(progress: Dictionary) -> bool:
	return (
		phase_of(progress) == PHASE_OPENING
		and bool(progress.get("narration_complete", false))
		and bool(progress.get("knock_complete", false))
	)


## Shows the next line, or completes the narration after the last one.
static func advance_narration(progress: Dictionary) -> Dictionary:
	if not is_reading_narration(progress):
		return progress
	var next := progress.duplicate(true)
	var line_index := int(progress.get("line_index", 0))
	if line_index >= OPENING_LINE_COUNT - 1:
		next["narration_complete"] = true
	else:
		next["line_index"] = line_index + 1
	return next


## The knock played to its end.
static func complete_knock(progress: Dictionary) -> Dictionary:
	if not knock_due(progress):
		return progress
	var next := progress.duplicate(true)
	next["knock_complete"] = true
	return next


## The player opened the white door: the basement's first round begins.
static func open_door(progress: Dictionary) -> Dictionary:
	if not door_ready(progress):
		return progress
	var next := progress.duplicate(true)
	next["phase"] = PHASE_BASEMENT
	next["round"] = 1
	return next


static func _integer_or(raw: Variant, fallback: int) -> int:
	if raw is int:
		return raw
	# A JSON number reads back as a float; accept whole numbers only, never text.
	if raw is float and is_finite(raw) and raw == floorf(raw):
		return int(raw)
	return fallback


static func _is_true(raw: Variant) -> bool:
	return raw is bool and raw
