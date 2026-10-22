class_name PropertyKeys
extends RefCounted
## Model names and the fact table: one row per name with its initial value, bounds, and save list.
## Boot, new run, save, and load all read the table.

const ChapterOneProgressScript = preload("res://scripts/game/chapter_one_progress.gd")

const POLLUTION := "pollution"
const HAS_SAVE := "has_save"
const DAY := "day"
const TOWER_FLOOR := "tower_floor"
const PENDING_FLOOR_TRANSITION := "pending_floor_transition"
const AUTOPLAY_ENABLED := "autoplay_enabled"
const LOCALE := "locale"
const MASTER_VOLUME := "master_volume"
## Whether the basement CRT terminal shows its own VHS look. A preference apart from the full-screen VHS.
const TERMINAL_VHS_ENABLED := "terminal_vhs_enabled"
const ENDING_LANGUAGE_CHOICE := "ending_language_choice"
const PHONE_OPEN := "phone_open"
const ACTIVE_APP := "active_app"
const ACTIVE_APP_WINDOW := "active_app_window"
const OPEN_APP_WINDOWS := "open_app_windows"
const VIEW_STATE := "view_state"
const NOTEBOOK_TOKENS := "notebook_tokens"
const COLLECTED_CHAR_UNITS := "collected_char_units"
const COMPLETED_MEMES := "completed_memes"
const CHAR_CANVAS_POSITIONS := "char_canvas_positions"
const SOCIAL_FOLLOWED_HANDLES := "social_followed_handles"
const SOCIAL_LIKED_POST_IDS := "social_liked_post_ids"
const CONVERSATION_PHASE := "conversation_phase"
const CONVERSATION_MODE := "conversation_mode"
const CONVERSATION_ACTOR_TYPE := "conversation_actor_type"
const CONVERSATION_ACTOR_LABEL := "conversation_actor_label"
const CONVERSATION_PROMPT := "conversation_prompt"
const CONVERSATION_RESULT_LINE := "conversation_result_line"
const CONVERSATION_CHOICES := "conversation_choices"
const CONVERSATION_CAN_CONTINUE := "conversation_can_continue"
const CONVERSATION_FEEDBACK := "conversation_feedback"
const CONVERSATION_REVEAL_INDEX := "conversation_reveal_index"
const CONVERSATION_REVEALED_UNITS := "conversation_revealed_units"
const ENDING_UNLOCKED := "ending_unlocked"
const ENDING_ROUTE := "ending_route"
const FORMAL_FLOOR_THREE_COMPLETE := "formal_floor_three_complete"
const FLOOR3_TASK_COMPLETE := "floor3_task_complete"
const FLOOR4_TASK_COMPLETE := "floor4_task_complete"
const EVENT_LOG := "event_log"
const HISTORY_ENTRIES := "history_entries"
const DRAFT_SLOTS := "draft_slots"
const OWNED_MEME_FRAMES := "owned_meme_frames"
const PUBLISHED_MEMES := "published_memes"
const FREE_SENTENCE_UNITS := "free_sentence_units"
const WORLD_RULES := "world_rules"
## Chapter one's progress dictionary (`ChapterOneProgress`): the opening narration line, the knock, the basement round.
const CHAPTER_ONE_PROGRESS := "chapter_one_progress"
const SETTINGS_OPEN := "settings_open"
const SAVE_STATUS := "save_status"
## The line the desk log shows after the last player action. Not saved: the next action writes a new one.
const FEEDBACK_TEXT := "feedback_text"
## Seconds START has been held on the title, zero when it is not held. Not saved; the debug panel shows it.
const START_HOLD_SECONDS := "start_hold_seconds"

const MAX_TOWER_FLOOR := 4
const DEFAULT_LOCALE := "zh"
const DEFAULT_MASTER_VOLUME := 80.0
const DEFAULT_APP := "social"
const DEFAULT_VIEW_STATE := "phone_down"
const DEFAULT_CONVERSATION_PHASE := "idle"
const DEFAULT_CONVERSATION_MODE := "authored"
const DEFAULT_CONVERSATION_ACTOR_TYPE := "npc"

## Saved with the run; a new run resets it.
const SAVED_WITH_RUN := "saved_with_run"
## A new run resets it but the save leaves it out: loading rebuilds it (the conversation progress).
const RESET_WITH_RUN := "reset_with_run"
## Saved apart from the run, in the preferences file; a new run keeps it.
const PREFERENCE := "preference"
## Not saved and not reset by a new run (has_save: the file is the source).
const NOT_SAVED := "not_saved"

## Run rows come first, in save order.
const FACTS: Array[Dictionary] = [
	{"name": POLLUTION, "initial": 0, "min": 0, "max": 100, "save": SAVED_WITH_RUN},
	{"name": DAY, "initial": 1, "min": 1, "save": SAVED_WITH_RUN},
	{"name": TOWER_FLOOR, "initial": 1, "min": 1, "max": MAX_TOWER_FLOOR, "save": SAVED_WITH_RUN},
	{"name": PENDING_FLOOR_TRANSITION, "initial": 0, "save": SAVED_WITH_RUN},
	{"name": AUTOPLAY_ENABLED, "initial": false, "save": SAVED_WITH_RUN},
	{"name": ENDING_LANGUAGE_CHOICE, "initial": "", "save": SAVED_WITH_RUN},
	{"name": PHONE_OPEN, "initial": true, "save": SAVED_WITH_RUN},
	{"name": ACTIVE_APP, "initial": DEFAULT_APP, "save": SAVED_WITH_RUN},
	{"name": ACTIVE_APP_WINDOW, "initial": DEFAULT_APP, "save": SAVED_WITH_RUN},
	{"name": OPEN_APP_WINDOWS, "initial": [], "save": SAVED_WITH_RUN},
	{"name": VIEW_STATE, "initial": DEFAULT_VIEW_STATE, "save": SAVED_WITH_RUN},
	{"name": NOTEBOOK_TOKENS, "initial": [], "save": SAVED_WITH_RUN},
	{"name": COLLECTED_CHAR_UNITS, "initial": [], "save": SAVED_WITH_RUN},
	{"name": COMPLETED_MEMES, "initial": [], "save": SAVED_WITH_RUN},
	{"name": CHAR_CANVAS_POSITIONS, "initial": {}, "save": SAVED_WITH_RUN},
	{"name": SOCIAL_FOLLOWED_HANDLES, "initial": [], "save": SAVED_WITH_RUN},
	{"name": SOCIAL_LIKED_POST_IDS, "initial": [], "save": SAVED_WITH_RUN},
	{"name": CONVERSATION_PHASE, "initial": DEFAULT_CONVERSATION_PHASE, "save": RESET_WITH_RUN},
	{"name": CONVERSATION_MODE, "initial": DEFAULT_CONVERSATION_MODE, "save": RESET_WITH_RUN},
	{"name": CONVERSATION_ACTOR_TYPE, "initial": DEFAULT_CONVERSATION_ACTOR_TYPE, "save": RESET_WITH_RUN},
	{"name": CONVERSATION_ACTOR_LABEL, "initial": "", "save": RESET_WITH_RUN},
	{"name": CONVERSATION_PROMPT, "initial": "", "save": RESET_WITH_RUN},
	{"name": CONVERSATION_RESULT_LINE, "initial": "", "save": RESET_WITH_RUN},
	{"name": CONVERSATION_CHOICES, "initial": [], "save": RESET_WITH_RUN},
	{"name": CONVERSATION_CAN_CONTINUE, "initial": false, "save": RESET_WITH_RUN},
	{"name": CONVERSATION_FEEDBACK, "initial": "", "save": RESET_WITH_RUN},
	{"name": CONVERSATION_REVEAL_INDEX, "initial": 0, "save": RESET_WITH_RUN},
	{"name": CONVERSATION_REVEALED_UNITS, "initial": [], "save": RESET_WITH_RUN},
	{"name": ENDING_UNLOCKED, "initial": false, "save": SAVED_WITH_RUN},
	{"name": ENDING_ROUTE, "initial": "", "save": SAVED_WITH_RUN},
	{"name": FORMAL_FLOOR_THREE_COMPLETE, "initial": false, "save": SAVED_WITH_RUN},
	{"name": FLOOR3_TASK_COMPLETE, "initial": false, "save": SAVED_WITH_RUN},
	{"name": FLOOR4_TASK_COMPLETE, "initial": false, "save": SAVED_WITH_RUN},
	{"name": EVENT_LOG, "initial": [], "save": SAVED_WITH_RUN},
	{"name": HISTORY_ENTRIES, "initial": [], "save": SAVED_WITH_RUN},
	{"name": DRAFT_SLOTS, "initial": {}, "save": SAVED_WITH_RUN},
	{"name": OWNED_MEME_FRAMES, "initial": 0, "min": 0, "save": SAVED_WITH_RUN},
	{"name": PUBLISHED_MEMES, "initial": [], "save": SAVED_WITH_RUN},
	{"name": FREE_SENTENCE_UNITS, "initial": [], "save": SAVED_WITH_RUN},
	{"name": WORLD_RULES, "initial": {}, "save": SAVED_WITH_RUN},
	{"name": CHAPTER_ONE_PROGRESS, "initial": ChapterOneProgressScript.INITIAL, "save": SAVED_WITH_RUN},
	{"name": LOCALE, "initial": DEFAULT_LOCALE, "save": PREFERENCE},
	{"name": MASTER_VOLUME, "initial": DEFAULT_MASTER_VOLUME, "min": 0.0, "max": 100.0, "save": PREFERENCE},
	{"name": TERMINAL_VHS_ENABLED, "initial": true, "save": PREFERENCE},
	{"name": HAS_SAVE, "initial": false, "save": NOT_SAVED},
	{"name": SETTINGS_OPEN, "initial": false, "save": NOT_SAVED},
	{"name": SAVE_STATUS, "initial": "", "save": NOT_SAVED},
	{"name": FEEDBACK_TEXT, "initial": "", "save": NOT_SAVED},
	{"name": START_HOLD_SECONDS, "initial": 0.0, "save": NOT_SAVED},
]


## The names whose row has this save list, in table order.
static func names_saved_as(save: String) -> Array[String]:
	var names: Array[String] = []
	for fact in FACTS:
		if fact["save"] == save:
			names.append(str(fact["name"]))
	return names


## The names a new run resets: saved with the run or rebuilt by loading.
static func run_names() -> Array[String]:
	var names := names_saved_as(SAVED_WITH_RUN)
	names.append_array(names_saved_as(RESET_WITH_RUN))
	return names


static func is_run(property_name: String) -> bool:
	return run_names().has(property_name)
