class_name PropertyKeys
extends RefCounted
## Model names and the save list each name belongs to.

const POLLUTION := "pollution"
const HAS_SAVE := "has_save"
const MONEY := "money"
const ACTIONS_REMAINING := "actions_remaining"
const AUTOPLAY_ENABLED := "autoplay_enabled"
const LOCALE := "locale"
const MASTER_VOLUME := "master_volume"
const ENDING_LANGUAGE_CHOICE := "ending_language_choice"
const PHONE_OPEN := "phone_open"
const ACTIVE_APP := "active_app"
const ACTIVE_APP_WINDOW := "active_app_window"
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

const RUN: Array[String] = [POLLUTION, MONEY, ACTIONS_REMAINING, AUTOPLAY_ENABLED, ENDING_LANGUAGE_CHOICE, PHONE_OPEN, ACTIVE_APP, ACTIVE_APP_WINDOW,
	NOTEBOOK_TOKENS, COLLECTED_CHAR_UNITS, COMPLETED_MEMES, CHAR_CANVAS_POSITIONS,
	SOCIAL_FOLLOWED_HANDLES, SOCIAL_LIKED_POST_IDS,
	CONVERSATION_PHASE, CONVERSATION_MODE, CONVERSATION_ACTOR_TYPE, CONVERSATION_ACTOR_LABEL, CONVERSATION_PROMPT,
	CONVERSATION_RESULT_LINE, CONVERSATION_CHOICES, CONVERSATION_CAN_CONTINUE, CONVERSATION_FEEDBACK,
	CONVERSATION_REVEAL_INDEX, CONVERSATION_REVEALED_UNITS]
const PREFERENCES: Array[String] = [LOCALE, MASTER_VOLUME]
const UNSAVED: Array[String] = [HAS_SAVE]
