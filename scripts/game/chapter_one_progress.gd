class_name ChapterOneProgress
extends RefCounted
## Chapter one's progress rules on one progress dictionary: the opening narration is read one line at a time, the
## knock sounds on its line, and the door opens into the basement only once the narration is read and the knock heard.
## The basement is played in five rounds: a round is delivered when one of its room's escapes holds (`RoomRules.escaped`),
## which opens its exit; leaving through it starts the next round, and the fifth exit leads to the
## white door passage. Walking into its light reaches the next level of `LEVEL_ORDER`.
## Every rule returns the next progress; a refused step returns the progress unchanged. `MemeGameState` keeps the
## dictionary in the `chapter_one_progress` model and saves it with the run.

const PHASE_OPENING := "opening"
const PHASE_BASEMENT := "basement"
## The black water and the white door between two levels, without narration or knock.
const PHASE_PASSAGE := "passage"
## The demo's last level: its end screen.
const PHASE_DEMO_END := "demo_end"
## A run that skipped chapter one, or a save made before chapter one existed: the tower street.
const PHASE_TOWER := "tower"
const PHASES := [PHASE_OPENING, PHASE_BASEMENT, PHASE_PASSAGE, PHASE_DEMO_END, PHASE_TOWER]
## The order the levels are played in, the only place that says which level follows which. A new level also brings its
## own phase and stage; the white door passage leads to it from here.
const LEVEL_ORDER := [PHASE_OPENING, PHASE_BASEMENT, PHASE_DEMO_END]
## Spoken lines in the opening narration (the catalog's `opening` list).
const OPENING_LINE_COUNT := 29
## The line shown when the knock sounds: the one right after the manuscript's knock stage direction.
const KNOCK_LINE_INDEX := 26
const BASEMENT_ROUND_COUNT := 5
## A basement round's NPC, and the one-route conversation it holds (no choices, no button).
const BASEMENT_NPC_ACTOR_TYPE := "basement_npc"
const LINEAR_CONVERSATION_MODE := "linear"

## A new run's progress. `PropertyKeys` uses it as the model's initial value.
const INITIAL := {
	"phase": PHASE_OPENING,
	"line_index": 0,
	"narration_complete": false,
	"knock_complete": false,
	"round": 0,
	"delivered": false,
	"passage_to": "",
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
	if phase == PHASE_OPENING or not door_ready(progress):
		return progress
	progress["phase"] = phase
	if phase == PHASE_BASEMENT:
		progress["round"] = clampi(_integer_or(source.get("round", 1), 1), 1, BASEMENT_ROUND_COUNT)
		progress["delivered"] = _is_true(source.get("delivered", false))
	elif phase == PHASE_PASSAGE:
		var passage_to: Variant = source.get("passage_to", "")
		var ahead := LEVEL_ORDER.find(passage_to) > LEVEL_ORDER.find(PHASE_BASEMENT)
		progress["passage_to"] = passage_to if ahead else next_level(PHASE_BASEMENT)
	return progress


static func phase_of(progress: Dictionary) -> String:
	return str(progress.get("phase", PHASE_OPENING))


## The level after `level` in `order`, or empty after the last one or for a level off the table.
static func next_level(level: String, order: Array = LEVEL_ORDER) -> String:
	var index := order.find(level)
	if index < 0 or index + 1 >= order.size():
		return ""
	return str(order[index + 1])


## The demo's end has been reached.
static func demo_ended(progress: Dictionary) -> bool:
	return phase_of(progress) == PHASE_DEMO_END


## The run has left the basement behind, so nothing it earned there can be missing.
static func past_basement(progress: Dictionary) -> bool:
	return phase_of(progress) in [PHASE_PASSAGE, PHASE_DEMO_END, PHASE_TOWER]


## The basement round being played, or zero outside the basement (the opening and the tower).
static func round_of(progress: Dictionary) -> int:
	if phase_of(progress) != PHASE_BASEMENT:
		return 0
	return int(progress.get("round", 0))


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
	return _enter_level(progress, next_level(PHASE_OPENING))


## One of the round's escapes held: the round is delivered and stays so until the player leaves it.
static func deliver(progress: Dictionary, escaped: bool) -> Dictionary:
	if phase_of(progress) != PHASE_BASEMENT or bool(progress.get("delivered", false)) or not escaped:
		return progress
	var next := progress.duplicate(true)
	next["delivered"] = true
	return next


## The basement exit is open once this round is delivered.
static func exit_open(progress: Dictionary) -> bool:
	return phase_of(progress) == PHASE_BASEMENT and bool(progress.get("delivered", false))


## The player walked out through the open exit: the next round begins, or after the fifth the white door passage to
## the level `order` puts after the basement. Without one the exit holds.
static func leave_round(progress: Dictionary, order: Array = LEVEL_ORDER) -> Dictionary:
	if not exit_open(progress):
		return progress
	var next := progress.duplicate(true)
	next["delivered"] = false
	if round_of(progress) < BASEMENT_ROUND_COUNT:
		next["round"] = round_of(progress) + 1
		return next
	var passage_to := next_level(PHASE_BASEMENT, order)
	if passage_to.is_empty():
		return progress
	next["phase"] = PHASE_PASSAGE
	next["round"] = 0
	next["passage_to"] = passage_to
	return next


## The player walked into the white door's light: the level the passage leads to begins.
static func cross_passage(progress: Dictionary) -> Dictionary:
	if phase_of(progress) != PHASE_PASSAGE:
		return progress
	return _enter_level(progress, str(progress.get("passage_to", "")))


## Whether a run that got this far must already carry the phone: it lies on the basement's table in round one, so
## any later round or anything past the basement has it. Used where nobody saw it picked up (a jump, a save made
## before it existed).
static func phone_earned(progress: Dictionary) -> bool:
	return past_basement(progress) or round_of(progress) > 1


## Development seam: starts a basement round fresh, as if the opening had been played. Out-of-range rounds are refused.
static func jump_to_round(progress: Dictionary, round_number: int) -> Dictionary:
	if round_number < 1 or round_number > BASEMENT_ROUND_COUNT:
		return progress
	var next := initial()
	next["line_index"] = OPENING_LINE_COUNT - 1
	next["narration_complete"] = true
	next["knock_complete"] = true
	next["phase"] = PHASE_BASEMENT
	next["round"] = round_number
	return next


## Starts `level` from its beginning; only the basement has rounds.
static func _enter_level(progress: Dictionary, level: String) -> Dictionary:
	var next := progress.duplicate(true)
	next["phase"] = level
	next["round"] = 1 if level == PHASE_BASEMENT else 0
	next["delivered"] = false
	next["passage_to"] = ""
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
