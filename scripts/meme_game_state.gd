class_name MemeGameState
extends RefCounted

## The phone's apps, in the order a closed foreground window falls back to.
const PHONE_APPS := ["social", "notebook"]

const GameLocaleScript = preload("res://scripts/localization/game_locale.gd")
const PollutionStageScript = preload("res://scripts/world/pollution_stage.gd")
const LanguageCorruptionContentScript = preload("res://scripts/narrative/language_corruption_content.gd")
const LanguageBridgeScript = preload("res://scripts/narrative/language_bridge.gd")
const PickupCharPoolScript = preload("res://scripts/narrative/pickup_char_pool.gd")
const RuleEngineScript = preload("res://scripts/narrative/rule_engine.gd")
const EchoQuoteContentScript = preload("res://scripts/narrative/echo_quote_content.gd")
const NarrativeSessionCatalogScript = preload("res://scripts/game/narrative_session_catalog.gd")
const PropertyBootScript = preload("res://scripts/game/property_boot.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")
const ActionOutcomeScript = preload("res://scripts/game/action_outcome.gd")
const MAX_TOWER_FLOOR := PropertyKeysScript.MAX_TOWER_FLOOR
const POLLUTION_FLOOR_THRESHOLDS := {1: 25, 2: 60, 3: 80}
const HISTORY_FIELD_NAMES := [
	"lineId", "originalSpeaker", "currentSpeaker", "originalText",
	"displayText", "revisionStage", "revisionMarkup",
]
const POLLUTION_FLASHBACK_THRESHOLD := 60
const LANGUAGE_RECIPE_SLOTS := [
	{"id": "subject", "label": "谁 / 什么", "placeholder": "放入主语", "accepted_role": "subject"},
	{"id": "action", "label": "发生了什么", "placeholder": "放入动作", "accepted_role": "action"},
	{"id": "object", "label": "对谁 / 在哪里", "placeholder": "放入落点", "accepted_role": "object"},
]
const REALITY_CORRUPTION_GLYPHS := ["■", "▦", "∴", "//", "□", "▧", "≠", "…"]
const PROTECTED_PUNCTUATION := ["，", "。", "！", "？", "；", "：", "、", "…", ",", ".", "!", "?", ";", ":", "\"", "'", "（", "）", "(", ")"]
## Version 6 dropped daily actions, funds and the day settlement. An older save is refused and the host starts a new run.
const SAVE_DATA_VERSION := 6
## Run fields that still live on this object. Fields kept in models are saved from the PropertyKeys fact table instead.
const SAVE_FIELD_NAMES := [
	"exit_prompt_seen",
	"pollution_flashback_seen",
	"owned_meme_frame_ids",
	"claimed_doll_ids", "doll_choice_results",
	"collected_world_item_ids",
	"cover_watcher_seen_floors",
	"revealed_prerequisite_item_ids", "collected_prerequisite_item_ids", "key_clue_progress",
	"sentence_records",
	"last_clean_sentence", "last_polluted_sentence",
	"npc_understanding", "reality_phase", "relationship_residue", "last_relationship_residue_gain",
	"reality_dialogue_count",
]

var day: int:
	get:
		return _read_run_int(PropertyKeysScript.DAY)
	set(value):
		_write_run_field(PropertyKeysScript.DAY, value)
var pollution: int:
	get:
		return _read_pollution()
	set(value):
		_write_pollution(value)
var tower_floor: int:
	get:
		return _read_run_int(PropertyKeysScript.TOWER_FLOOR)
	set(value):
		_write_run_field(PropertyKeysScript.TOWER_FLOOR, value)
var ending_unlocked: bool:
	get:
		return _read_run_bool(PropertyKeysScript.ENDING_UNLOCKED)
	set(value):
		_write_run_field(PropertyKeysScript.ENDING_UNLOCKED, value)
var ending_language_choice: String:
	get:
		return _read_run_string(PropertyKeysScript.ENDING_LANGUAGE_CHOICE)
	set(value):
		_write_run_field(PropertyKeysScript.ENDING_LANGUAGE_CHOICE, value)
var ending_route: String:
	get:
		return _read_run_string(PropertyKeysScript.ENDING_ROUTE)
	set(value):
		_write_run_field(PropertyKeysScript.ENDING_ROUTE, value)
var formal_floor_three_complete: bool:
	get:
		return _read_run_bool(PropertyKeysScript.FORMAL_FLOOR_THREE_COMPLETE)
	set(value):
		_write_run_field(PropertyKeysScript.FORMAL_FLOOR_THREE_COMPLETE, value)
var pending_floor_transition: int:
	get:
		return _read_run_int(PropertyKeysScript.PENDING_FLOOR_TRANSITION)
	set(value):
		_write_run_field(PropertyKeysScript.PENDING_FLOOR_TRANSITION, value)
var exit_prompt_seen: bool = false
var pollution_flashback_seen: bool = false
## Set when pollution crosses the flashback threshold; the outcome of the interaction that crossed it takes it.
var pollution_flashback_pending: bool = false

var view_state: String:
	get:
		return _read_run_string(PropertyKeysScript.VIEW_STATE)
	set(value):
		_write_run_field(PropertyKeysScript.VIEW_STATE, value)
var phone_open: bool:
	get:
		return _read_run_bool(PropertyKeysScript.PHONE_OPEN)
	set(value):
		_write_run_field(PropertyKeysScript.PHONE_OPEN, value)
var active_app: String:
	get:
		return _read_run_string(PropertyKeysScript.ACTIVE_APP)
	set(value):
		_write_run_field(PropertyKeysScript.ACTIVE_APP, value)
var active_app_window: String:
	get:
		return _read_run_string(PropertyKeysScript.ACTIVE_APP_WINDOW)
	set(value):
		_write_run_field(PropertyKeysScript.ACTIVE_APP_WINDOW, value)
var open_app_windows: Array:
	get:
		return _read_run_array(PropertyKeysScript.OPEN_APP_WINDOWS)

var notebook_tokens: Array:
	get:
		return _read_run_array(PropertyKeysScript.NOTEBOOK_TOKENS)
	set(value):
		_write_run_list(PropertyKeysScript.NOTEBOOK_TOKENS, value)
## Recipe slot id -> token id. A read is a copy.
var draft_slots: Dictionary:
	get:
		return _read_run_map(PropertyKeysScript.DRAFT_SLOTS)
	set(value):
		_write_run_map(PropertyKeysScript.DRAFT_SLOTS, value)
var completed_memes: Array:
	get:
		return _read_run_array(PropertyKeysScript.COMPLETED_MEMES)
	set(value):
		_write_run_list(PropertyKeysScript.COMPLETED_MEMES, value)
var owned_meme_frames: int:
	get:
		return _read_run_int(PropertyKeysScript.OWNED_MEME_FRAMES)
	set(value):
		_write_run_field(PropertyKeysScript.OWNED_MEME_FRAMES, value)
var owned_meme_frame_ids: Array[String] = []
var claimed_doll_ids: Array[String] = []
var doll_choice_results: Dictionary = {}
## Newest first. A read is a copy.
var published_memes: Array:
	get:
		return _read_run_array(PropertyKeysScript.PUBLISHED_MEMES)
	set(value):
		_write_run_list(PropertyKeysScript.PUBLISHED_MEMES, value)
## Newest first. A read is a copy; add through record_event().
var event_log: Array:
	get:
		return _read_run_array(PropertyKeysScript.EVENT_LOG)
	set(value):
		_write_run_list(PropertyKeysScript.EVENT_LOG, value)

var collected_world_item_ids: Array[String] = []
var cover_watcher_seen_floors: Array[int] = []
var revealed_prerequisite_item_ids: Array[String] = []
var collected_prerequisite_item_ids: Array[String] = []
var key_clue_progress: Dictionary = {}
var history_entries: Array:
	get:
		return _read_run_array(PropertyKeysScript.HISTORY_ENTRIES)

var sentence_records: Array = []
var collected_char_units: Array:
	get:
		return _read_run_array(PropertyKeysScript.COLLECTED_CHAR_UNITS)
	set(value):
		_write_run_list(PropertyKeysScript.COLLECTED_CHAR_UNITS, value)
var char_canvas_positions: Dictionary:
	get:
		return _read_run_map(PropertyKeysScript.CHAR_CANVAS_POSITIONS)
## The sentence being composed, in order. A read is a copy.
var free_sentence_units: Array:
	get:
		return _read_run_array(PropertyKeysScript.FREE_SENTENCE_UNITS)
	set(value):
		_write_run_list(PropertyKeysScript.FREE_SENTENCE_UNITS, value)
## Rule key -> the sentence that set it. A read is a copy.
var world_rules: Dictionary:
	get:
		return _read_run_map(PropertyKeysScript.WORLD_RULES)
	set(value):
		_write_run_map(PropertyKeysScript.WORLD_RULES, value)
var floor3_task_complete: bool:
	get:
		return _read_run_bool(PropertyKeysScript.FLOOR3_TASK_COMPLETE)
	set(value):
		_write_run_field(PropertyKeysScript.FLOOR3_TASK_COMPLETE, value)
var floor4_task_complete: bool:
	get:
		return _read_run_bool(PropertyKeysScript.FLOOR4_TASK_COMPLETE)
	set(value):
		_write_run_field(PropertyKeysScript.FLOOR4_TASK_COMPLETE, value)
var last_clean_sentence: String = ""
var last_polluted_sentence: String = ""
var npc_understanding: int = 100
var reality_phase: String = "npc_speaking"
var relationship_residue: int = 0
var last_relationship_residue_gain: int = 0
var reality_dialogue_count: int = 0
var conversation_phase: String:
	get:
		return _read_run_string(PropertyKeysScript.CONVERSATION_PHASE)
	set(value):
		_write_run_field(PropertyKeysScript.CONVERSATION_PHASE, value)
var conversation_actor_id: String = ""
var conversation_actor_type: String:
	get:
		return _read_run_string(PropertyKeysScript.CONVERSATION_ACTOR_TYPE)
	set(value):
		_write_run_field(PropertyKeysScript.CONVERSATION_ACTOR_TYPE, value)
var conversation_actor_label: String:
	get:
		return _read_run_string(PropertyKeysScript.CONVERSATION_ACTOR_LABEL)
	set(value):
		_write_run_field(PropertyKeysScript.CONVERSATION_ACTOR_LABEL, value)
var conversation_prompt: String:
	get:
		return _read_run_string(PropertyKeysScript.CONVERSATION_PROMPT)
	set(value):
		_write_run_field(PropertyKeysScript.CONVERSATION_PROMPT, value)
var conversation_result_line: String:
	get:
		return _read_run_string(PropertyKeysScript.CONVERSATION_RESULT_LINE)
	set(value):
		_write_run_field(PropertyKeysScript.CONVERSATION_RESULT_LINE, value)
var conversation_choices: Array:
	get:
		return _read_run_array(PropertyKeysScript.CONVERSATION_CHOICES)
	set(value):
		_write_run_list(PropertyKeysScript.CONVERSATION_CHOICES, value)
var conversation_selected_choice_id: String = ""
var conversation_clean_sentence: String = ""
var conversation_revealed_units: Array:
	get:
		return _read_run_array(PropertyKeysScript.CONVERSATION_REVEALED_UNITS)
	set(value):
		_write_run_list(PropertyKeysScript.CONVERSATION_REVEALED_UNITS, value)
var conversation_reveal_index: int:
	get:
		return _read_run_int(PropertyKeysScript.CONVERSATION_REVEAL_INDEX)
	set(value):
		_write_run_field(PropertyKeysScript.CONVERSATION_REVEAL_INDEX, value)
var conversation_attempts: int = 0
var conversation_understood: bool = false
var conversation_understanding_rolls: Array[int] = []
var conversation_feedback: String:
	get:
		return _read_run_string(PropertyKeysScript.CONVERSATION_FEEDBACK)
	set(value):
		_write_run_field(PropertyKeysScript.CONVERSATION_FEEDBACK, value)
var conversation_locale: String = "zh"
var conversation_clean_units: Array[String] = []
var conversation_mode: String:
	get:
		return _read_run_string(PropertyKeysScript.CONVERSATION_MODE)
	set(value):
		_write_run_field(PropertyKeysScript.CONVERSATION_MODE, value)
var conversation_world: String = "reality"
var conversation_turns: Array = []
var conversation_turn_index: int = 0
var conversation_history: Array = []
var conversation_can_continue: bool:
	get:
		return _read_run_bool(PropertyKeysScript.CONVERSATION_CAN_CONTINUE)
	set(value):
		_write_run_field(PropertyKeysScript.CONVERSATION_CAN_CONTINUE, value)
var conversation_completed: bool = false
var conversation_interrupted: bool = false
var conversation_interrupt_line: String = ""
## Whether this conversation already counted toward the dialogue count.
var conversation_counted: bool = false
var conversation_reward: Dictionary = {}


func new_run() -> void:
	PropertyBootScript.reset_run()
	exit_prompt_seen = false
	pollution_flashback_seen = false
	pollution_flashback_pending = false
	open_app_window(active_app_window)
	owned_meme_frame_ids = []
	claimed_doll_ids = []
	doll_choice_results = {}
	collected_world_item_ids = []
	cover_watcher_seen_floors = []
	revealed_prerequisite_item_ids = []
	collected_prerequisite_item_ids = []
	key_clue_progress = {}
	sentence_records = []
	last_clean_sentence = ""
	last_polluted_sentence = ""
	npc_understanding = 100
	reality_phase = "npc_speaking"
	relationship_residue = 0
	last_relationship_residue_gain = 0
	reality_dialogue_count = 0
	reset_typed_reality_conversation()


func _read_save_field(field_name: String) -> Variant:
	if PropertyKeysScript.is_run(field_name):
		var model: PropertyModel = _run_model(field_name)
		if model == null:
			return null
		return model.read()
	return get(field_name)


func _write_run_field(field_name: String, value: Variant) -> void:
	var model: ValuePropertyModel = _run_model(field_name) as ValuePropertyModel
	if model == null:
		return
	model.write(value)


func _read_pollution() -> int:
	var model: ValuePropertyModel = _pollution_model()
	if model == null:
		return 0
	return int(model.read())


func _write_pollution(value: int) -> void:
	var model: ValuePropertyModel = _pollution_model()
	if model == null:
		return
	model.write(value)


func _pollution_model() -> ValuePropertyModel:
	return _run_model(PropertyKeysScript.POLLUTION) as ValuePropertyModel


func _read_run_int(property_name: String) -> int:
	var model: ValuePropertyModel = _run_model(property_name) as ValuePropertyModel
	if model == null:
		return 0
	return int(model.read())


func _read_run_bool(property_name: String) -> bool:
	var model: ValuePropertyModel = _run_model(property_name) as ValuePropertyModel
	if model == null:
		return false
	return bool(model.read())


func _read_run_string(property_name: String) -> String:
	var model: ValuePropertyModel = _run_model(property_name) as ValuePropertyModel
	if model == null:
		return ""
	return str(model.read())


func _read_run_array(property_name: String) -> Array:
	var model: ListPropertyModel = _run_model(property_name) as ListPropertyModel
	if model == null:
		return []
	return model.read() as Array


func _write_run_list(property_name: String, items: Array) -> void:
	var model: ListPropertyModel = _run_model(property_name) as ListPropertyModel
	if model == null:
		return
	model.replace_all(items)


func _run_list(property_name: String) -> ListPropertyModel:
	return _run_model(property_name) as ListPropertyModel


func _read_run_map(property_name: String) -> Dictionary:
	var model: MapPropertyModel = _run_model(property_name) as MapPropertyModel
	if model == null:
		return {}
	return model.read() as Dictionary


func _write_run_map(property_name: String, entries: Dictionary) -> void:
	var model: MapPropertyModel = _run_model(property_name) as MapPropertyModel
	if model == null:
		return
	model.replace_all(entries)


## Adds the key or replaces what it holds.
func _put_run_map_entry(property_name: String, key: Variant, value: Variant) -> void:
	var model: MapPropertyModel = _run_model(property_name) as MapPropertyModel
	if model == null:
		return
	if (model.read() as Dictionary).has(key):
		model.replace(key, value)
	else:
		model.add(key, value)


## A save writes each run field back through its model. A list or map of the wrong shape is refused and keeps the reset value.
func _load_run_field(field_name: String, value: Variant) -> void:
	var model: PropertyModel = _run_model(field_name)
	if model is ListPropertyModel:
		if value is Array:
			(model as ListPropertyModel).replace_all(value)
		else:
			push_error("Save field '%s' is not a list and was skipped" % field_name)
		return
	if model is MapPropertyModel:
		if value is Dictionary:
			(model as MapPropertyModel).replace_all(value)
		else:
			push_error("Save field '%s' is not a map and was skipped" % field_name)
		return
	_write_run_field(field_name, value)


func _run_model(property_name: String) -> PropertyModel:
	PropertyBootScript.install()
	var manager: PropertyManager = ServiceRegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	if manager == null:
		return null
	return manager.model(property_name)


func to_save_data() -> Dictionary:
	var state_data := {}
	for field_name in _save_field_names():
		var value: Variant = _read_save_field(field_name)
		state_data[field_name] = value.duplicate(true) if value is Array or value is Dictionary else value
	return {
		"version": SAVE_DATA_VERSION,
		"state": state_data,
	}


## Every saved run model, then the fields this object still holds.
func _save_field_names() -> Array[String]:
	var names: Array[String] = []
	names.append_array(PropertyKeysScript.names_saved_as(PropertyKeysScript.SAVED_WITH_RUN))
	for field_name in SAVE_FIELD_NAMES:
		names.append(str(field_name))
	return names


func load_save_data(save_data: Dictionary) -> bool:
	if int(save_data.get("version", -1)) != SAVE_DATA_VERSION:
		return false
	var state_data: Variant = save_data.get("state", {})
	if not state_data is Dictionary:
		return false
	new_run()
	for field_name in _save_field_names():
		if not state_data.has(field_name):
			continue
		var value: Variant = state_data[field_name]
		if PropertyKeysScript.is_run(field_name):
			_load_run_field(field_name, value)
			continue
		set(field_name, value.duplicate(true) if value is Array or value is Dictionary else value)
	pollution = clampi(pollution, 0, 100)
	var normalized_watcher_floors: Array[int] = []
	for floor_value in cover_watcher_seen_floors:
		var floor_number := clampi(int(floor_value), 1, MAX_TOWER_FLOOR)
		if floor_number not in normalized_watcher_floors:
			normalized_watcher_floors.append(floor_number)
	cover_watcher_seen_floors = normalized_watcher_floors
	_normalize_doll_state()
	_normalize_notebook_tokens()
	_drop_retired_apps()
	if view_state != "phone_down" and view_state != "npc_up":
		view_state = "phone_down"
	if view_state == "npc_up":
		phone_open = false
		active_app_window = ""
	open_app_window(active_app_window)
	reset_typed_reality_conversation()
	# 读档防御:规则已活而任务旗标缺失的异常档,按当前楼层重扫一次锁存。
	_latch_ultimate_tasks_for_current_floor()
	return true


func _normalize_notebook_tokens() -> void:
	var normalized_tokens: Array = []
	var saved_tokens := notebook_tokens
	for token_index in saved_tokens.size():
		var token_value: Variant = saved_tokens[token_index]
		if token_value is Dictionary:
			var token: Dictionary = (token_value as Dictionary).duplicate(true)
			if not token.get("grammar_roles", null) is Array or (token.get("grammar_roles", []) as Array).is_empty():
				token["grammar_roles"] = [str(LANGUAGE_RECIPE_SLOTS[token_index % LANGUAGE_RECIPE_SLOTS.size()].get("accepted_role", "subject"))]
			if str(token.get("lexeme_id", "")).is_empty():
				token["lexeme_id"] = str(token.get("id", "token-%d" % token_index))
			normalized_tokens.append(LanguageBridgeScript.normalized_token(token))
	notebook_tokens = normalized_tokens


func _normalize_doll_state() -> void:
	var known_doll_ids: Array[String] = LanguageCorruptionContentScript.get_doll_ids()
	var normalized_claims: Array[String] = []
	for doll_id in claimed_doll_ids:
		var normalized_id := str(doll_id)
		if normalized_id in known_doll_ids and normalized_id not in normalized_claims:
			normalized_claims.append(normalized_id)
	claimed_doll_ids = normalized_claims

	var normalized_results := {}
	for doll_id in claimed_doll_ids:
		var result: Variant = doll_choice_results.get(doll_id, {})
		if not result is Dictionary:
			continue
		var encounter: Dictionary = LanguageCorruptionContentScript.get_doll_encounter_by_id(doll_id)
		var choice_id := str((result as Dictionary).get("choice_id", ""))
		var choice: Dictionary = _doll_choice_by_id(encounter, choice_id)
		if choice.is_empty():
			continue
		normalized_results[doll_id] = {
			"choice_id": choice_id,
			"day": maxi(1, int((result as Dictionary).get("day", 1))),
			"floor": clampi(int((result as Dictionary).get("floor", 1)), 1, 3),
		}
	doll_choice_results = normalized_results

	var normalized_frame_ids: Array[String] = []
	for frame_id in owned_meme_frame_ids:
		var normalized_id := str(frame_id).strip_edges()
		if not normalized_id.is_empty():
			normalized_frame_ids.append(normalized_id)
	owned_meme_frame_ids = normalized_frame_ids
	owned_meme_frames = maxi(0, owned_meme_frames)
	while owned_meme_frame_ids.size() < owned_meme_frames:
		owned_meme_frame_ids.append("legacy_frame_%d" % (owned_meme_frame_ids.size() + 1))
	if owned_meme_frame_ids.size() > owned_meme_frames:
		owned_meme_frames = owned_meme_frame_ids.size()


func set_phone_open(value: bool) -> void:
	phone_open = value
	if not value:
		active_app_window = ""


func set_view_state(value: String) -> bool:
	if value != "phone_down" and value != "npc_up":
		return false
	if view_state == value:
		return true
	view_state = value
	if view_state == "phone_down":
		phone_open = true
		if active_app_window.is_empty():
			active_app_window = active_app
		open_app_window(active_app_window)
	else:
		phone_open = false
		active_app_window = ""
		reset_reality_phase()
	return true


func get_phone_shell_snapshot() -> Dictionary:
	return {"view_state": view_state}


## A save may still name an app the phone no longer has (the tower app); the phone comes back on one it has.
func _drop_retired_apps() -> void:
	for app_id in open_app_windows:
		if str(app_id) not in PHONE_APPS:
			close_app_window(str(app_id))
	if active_app not in PHONE_APPS:
		active_app = PropertyKeysScript.DEFAULT_APP
	if not active_app_window.is_empty() and active_app_window not in PHONE_APPS:
		active_app_window = active_app


func is_app_window_open(app_id: String) -> bool:
	return open_app_windows.has(app_id)


func open_app_window(app_id: String) -> void:
	var normalized := app_id.strip_edges()
	var model: ListPropertyModel = _run_list(PropertyKeysScript.OPEN_APP_WINDOWS)
	if normalized.is_empty() or model == null or is_app_window_open(normalized):
		return
	model.add(normalized)


func close_app_window(app_id: String) -> void:
	var normalized := app_id.strip_edges()
	if normalized.is_empty():
		return
	var model: ListPropertyModel = _run_list(PropertyKeysScript.OPEN_APP_WINDOWS)
	var open_index := open_app_windows.find(normalized)
	if model != null and open_index >= 0:
		model.remove_at(open_index)
	if active_app_window == normalized:
		active_app_window = ""
		for candidate in PHONE_APPS:
			if is_app_window_open(candidate):
				active_app = candidate
				if view_state == "phone_down":
					active_app_window = candidate
				break


func is_world_item_collected(item_id: String) -> bool:
	return item_id in collected_world_item_ids


func get_prerequisite_item_ids() -> Array[String]:
	return NarrativeSessionCatalogScript.prerequisite_item_ids()


func get_prerequisite_item_for_floor(floor_number: int, locale_code: String = "zh") -> Dictionary:
	return NarrativeSessionCatalogScript.prerequisite_item(floor_number, locale_code)


func get_key_clue_progress(floor_number: int) -> Dictionary:
	return (key_clue_progress.get(str(clampi(floor_number, 1, 3)), {}) as Dictionary).duplicate(true)


func reveal_prerequisite_item_for_floor(floor_number: int) -> bool:
	var item := get_prerequisite_item_for_floor(floor_number, "zh")
	var item_id := str(item.get("id", ""))
	if item_id.is_empty() or item_id in revealed_prerequisite_item_ids:
		return false
	revealed_prerequisite_item_ids.append(item_id)
	record_event(str(item.get("location_hint", "这一层有一件东西正等着被找到。")))
	return true


func is_prerequisite_item_revealed(item_id: String) -> bool:
	return item_id in revealed_prerequisite_item_ids


func collect_prerequisite_item(item_id: String) -> bool:
	var normalized_id := item_id.strip_edges()
	if normalized_id not in get_prerequisite_item_ids():
		return false
	if normalized_id not in revealed_prerequisite_item_ids or normalized_id in collected_prerequisite_item_ids:
		return false
	collected_prerequisite_item_ids.append(normalized_id)
	if normalized_id not in collected_world_item_ids:
		collected_world_item_ids.append(normalized_id)
	record_event("你收起了这一层不该留下的东西。")
	return true


func is_hidden_layer_unlocked() -> bool:
	return _contains_all_ids(collected_prerequisite_item_ids, get_prerequisite_item_ids())


func record_history_line(line_data: Dictionary) -> bool:
	var line_id := str(line_data.get("lineId", "")).strip_edges()
	if line_id.is_empty():
		return false
	var normalized := {}
	for field_name in HISTORY_FIELD_NAMES:
		normalized[field_name] = line_data.get(field_name, 0 if field_name == "revisionStage" else "")
	normalized["lineId"] = line_id
	normalized["revisionStage"] = clampi(int(normalized["revisionStage"]), 0, 3)
	var model: ListPropertyModel = _run_list(PropertyKeysScript.HISTORY_ENTRIES)
	if model == null:
		return false
	var saved: Array = model.read()
	for index in saved.size():
		if str(saved[index].get("lineId", "")) == line_id:
			model.replace_at(index, normalized)
			return true
	model.add(normalized)
	return true


func get_history_entries() -> Array:
	return history_entries


## Puts a line at the front of the event log.
func record_event(text: String) -> void:
	var model: ListPropertyModel = _run_list(PropertyKeysScript.EVENT_LOG)
	if model != null:
		model.insert_at(0, text)


func complete_floor_three() -> String:
	if tower_floor != 3:
		return ""
	# 第三层终极任务:必须先让「门可以打开」成为世界规则,任何结局才会开门。
	if not floor3_task_complete:
		return "floor-three-task-incomplete"
	formal_floor_three_complete = true
	if pollution >= int(POLLUTION_FLOOR_THRESHOLDS[3]) and is_hidden_layer_unlocked():
		tower_floor = 4
		pending_floor_transition = 0
		ending_route = "hidden"
		ending_unlocked = false
		record_event("第四层没有登记记录。")
		_latch_ultimate_tasks_for_current_floor()
		return "hidden-floor"
	ending_route = "normal"
	ending_unlocked = true
	pending_floor_transition = 0
	return "normal-ending"


func request_floor_transition_for_pollution() -> int:
	if pending_floor_transition > tower_floor:
		return pending_floor_transition
	if tower_floor == 1 and pollution >= int(POLLUTION_FLOOR_THRESHOLDS[1]):
		pending_floor_transition = 2
	elif tower_floor == 2 and pollution >= int(POLLUTION_FLOOR_THRESHOLDS[2]):
		pending_floor_transition = 3
	return pending_floor_transition


func resolve_floor_transition_at_boundary() -> int:
	request_floor_transition_for_pollution()
	if pending_floor_transition != tower_floor + 1 or pending_floor_transition > 3:
		return tower_floor
	tower_floor = pending_floor_transition
	pending_floor_transition = 0
	record_event("你抵达了第 %d 层。" % tower_floor)
	_latch_ultimate_tasks_for_current_floor()
	return tower_floor


func has_seen_cover_watcher(floor_number: int) -> bool:
	return clampi(floor_number, 1, MAX_TOWER_FLOOR) in cover_watcher_seen_floors


func mark_cover_watcher_seen(floor_number: int) -> bool:
	var safe_floor := clampi(floor_number, 1, MAX_TOWER_FLOOR)
	if safe_floor in cover_watcher_seen_floors:
		return false
	cover_watcher_seen_floors.append(safe_floor)
	return true


## A world item pickup is a valid interaction: once the item is taken the progress check runs.
func collect_world_item(item_data: Dictionary) -> bool:
	var item_id := str(item_data.get("id", "")).strip_edges()
	if not collect_prerequisite_item(item_id):
		return false
	_finish_interaction()
	return true


func get_ending_language_choices(locale_code: String = "zh") -> Array:
	return NarrativeSessionCatalogScript.ending_language_choices(locale_code)


func choose_ending_language(choice_id: String) -> bool:
	if not ending_unlocked or not ending_language_choice.is_empty():
		return false
	if not NarrativeSessionCatalogScript.has_ending_language_choice(choice_id):
		return false
	ending_language_choice = choice_id
	return true


func get_ending_language_output(locale_code: String = "zh") -> String:
	return str(NarrativeSessionCatalogScript.ending_language_choice(ending_language_choice, locale_code).get("output", ""))


func set_active_app(app_id: String) -> void:
	active_app = app_id
	if view_state == "phone_down":
		active_app_window = app_id
		open_app_window(app_id)


func set_autoplay_enabled(value: bool) -> void:
	_write_run_field(PropertyKeysScript.AUTOPLAY_ENABLED, value)


func mark_exit_prompt_seen() -> void:
	exit_prompt_seen = true


## The followed authors, a copy. They change only through the follow methods below.
func get_social_followed_handles() -> Array[String]:
	var result: Array[String] = []
	for handle in _read_run_array(PropertyKeysScript.SOCIAL_FOLLOWED_HANDLES):
		result.append(str(handle))
	return result


func replace_social_followed_handles(handles: Array[String]) -> void:
	_write_run_list(PropertyKeysScript.SOCIAL_FOLLOWED_HANDLES, handles)


func is_social_following(handle: String) -> bool:
	return handle in _read_run_array(PropertyKeysScript.SOCIAL_FOLLOWED_HANDLES)


func toggle_social_follow(handle: String) -> bool:
	return _toggle_in_run_list(PropertyKeysScript.SOCIAL_FOLLOWED_HANDLES, handle)


func is_social_post_liked(post_id: String) -> bool:
	return post_id in _read_run_array(PropertyKeysScript.SOCIAL_LIKED_POST_IDS)


func toggle_social_like(post_id: String) -> bool:
	return _toggle_in_run_list(PropertyKeysScript.SOCIAL_LIKED_POST_IDS, post_id)


## Adds the entry when absent and removes it when present. Returns whether it is in the list afterwards.
func _toggle_in_run_list(property_name: String, entry: String) -> bool:
	var normalized := entry.strip_edges()
	var model := _run_list(property_name)
	if normalized.is_empty() or model == null:
		return false
	var index := (model.read() as Array).find(normalized)
	if index >= 0:
		model.remove_at(index)
		return false
	model.add(normalized)
	return true


func check_pollution_flashback(previous_pollution: int) -> bool:
	if pollution_flashback_seen:
		return false
	if previous_pollution >= POLLUTION_FLASHBACK_THRESHOLD:
		return false
	if pollution < POLLUTION_FLASHBACK_THRESHOLD:
		return false
	pollution_flashback_seen = true
	pollution_flashback_pending = true
	return true


func get_day_progress_snapshot() -> Dictionary:
	return {
		"day": day,
		"pollution": pollution,
		"tower_floor": tower_floor,
		"pending_floor_transition": pending_floor_transition,
	}


func change_pollution(amount: int) -> int:
	var previous_pollution := pollution
	pollution = clampi(pollution + amount, 0, 100)
	request_floor_transition_for_pollution()
	check_pollution_flashback(previous_pollution)
	return pollution - previous_pollution


func consume_pollution_flashback() -> bool:
	if not pollution_flashback_pending:
		return false
	pollution_flashback_pending = false
	return true


func begin_reality_player_turn() -> bool:
	if reality_phase == "reality_result":
		return false
	reality_phase = "player_composing"
	return true


func reset_reality_phase() -> void:
	reality_phase = "npc_speaking"


func start_typed_reality_conversation(actor_id: String, actor_type: String, actor_label: String) -> bool:
	conversation_actor_id = actor_id
	conversation_actor_type = actor_type if actor_type in ["npc", "key_npc", "doll"] else "npc"
	conversation_actor_label = actor_label
	conversation_mode = "authored"
	conversation_world = "reality"
	var dialogue := _reality_dialogue_for_actor(actor_id, conversation_actor_type)
	conversation_turns = [{
		"line": str(dialogue.get("line", "你打算说什么？")),
		"result": str(dialogue.get("result", "%s移开了视线。" % actor_label)),
		"choices": (dialogue.get("choices", []) as Array).duplicate(true),
	}]
	for followup in dialogue.get("continuation_turns", []):
		conversation_turns.append((followup as Dictionary).duplicate(true))
	conversation_turn_index = 0
	conversation_history = []
	conversation_can_continue = false
	conversation_completed = false
	conversation_interrupted = false
	conversation_interrupt_line = str(dialogue.get("interrupt", ""))
	conversation_counted = false
	conversation_reward = {}
	conversation_attempts = 0
	conversation_locale = "zh"
	_load_typed_reality_turn(0)
	conversation_phase = "choosing"
	return true


## The player leaves the conversation. One in which they spoke at least once was a valid interaction, so the
## progress check runs after it; leaving before speaking checks nothing.
func end_typed_reality_conversation() -> ActionOutcomeScript:
	var spoken := not conversation_history.is_empty()
	reset_typed_reality_conversation()
	if not spoken:
		return _refused_outcome()
	return _finish_interaction()


func reset_typed_reality_conversation() -> void:
	conversation_phase = "idle"
	conversation_actor_id = ""
	conversation_actor_type = "npc"
	conversation_actor_label = ""
	conversation_prompt = ""
	conversation_result_line = ""
	conversation_choices = []
	conversation_selected_choice_id = ""
	conversation_clean_sentence = ""
	conversation_revealed_units = []
	conversation_reveal_index = 0
	conversation_attempts = 0
	conversation_understood = false
	conversation_understanding_rolls = []
	conversation_feedback = ""
	conversation_locale = "zh"
	conversation_clean_units = []
	conversation_mode = "authored"
	conversation_world = "reality"
	conversation_turns = []
	conversation_turn_index = 0
	conversation_history = []
	conversation_can_continue = false
	conversation_completed = false
	conversation_interrupted = false
	conversation_interrupt_line = ""
	conversation_counted = false
	conversation_reward = {}


func get_reality_conversation_snapshot() -> Dictionary:
	return {
		"phase": conversation_phase,
		"mode": conversation_mode,
		"actor_type": conversation_actor_type,
		"actor_label": conversation_actor_label,
		"prompt": conversation_prompt,
		"result_line": conversation_result_line,
		"choices": conversation_choices.duplicate(true),
		"can_continue": conversation_can_continue,
		"feedback": conversation_feedback,
		"reveal_index": conversation_reveal_index,
		"revealed_units": conversation_revealed_units.duplicate(true),
	}


func get_typed_reality_choices() -> Array:
	return conversation_choices.duplicate(true)


func get_typed_reality_progress() -> Dictionary:
	return {
		"phase": conversation_phase,
		"turn_index": conversation_turn_index,
		"turn_number": conversation_turn_index + 1 if not conversation_turns.is_empty() else 0,
		"total_turns": conversation_turns.size(),
		"can_continue": conversation_can_continue,
		"completed": conversation_completed,
		"interrupted": conversation_interrupted,
		"history_count": conversation_history.size(),
		"reward": conversation_reward.duplicate(true),
	}


func get_typed_reality_history() -> Array:
	return conversation_history.duplicate(true)


func continue_typed_reality_conversation() -> bool:
	if conversation_phase != "result" or not conversation_can_continue:
		return false
	var next_turn := conversation_turn_index + 1
	if next_turn >= conversation_turns.size():
		return false
	conversation_can_continue = false
	_load_typed_reality_turn(next_turn)
	conversation_phase = "choosing"
	return true


func _load_typed_reality_turn(turn_index: int) -> void:
	if turn_index < 0 or turn_index >= conversation_turns.size():
		return
	var turn: Dictionary = conversation_turns[turn_index]
	conversation_turn_index = turn_index
	conversation_prompt = str(turn.get("line", "你打算说什么？"))
	conversation_result_line = str(turn.get("result", "%s移开了视线。" % conversation_actor_label))
	var turn_choices: Array = (turn.get("choices", []) as Array).duplicate(true)
	if conversation_actor_type == "doll":
		for choice_index in turn_choices.size():
			var choice: Dictionary = (turn_choices[choice_index] as Dictionary).duplicate(true)
			choice["locked"] = _doll_choice_is_locked(choice)
			if bool(choice["locked"]) and not str(choice.get("locked_summary", "")).is_empty():
				choice["summary"] = str(choice.get("locked_summary", ""))
			turn_choices[choice_index] = choice
	conversation_choices = turn_choices
	conversation_selected_choice_id = ""
	conversation_clean_sentence = ""
	conversation_revealed_units = []
	conversation_reveal_index = 0
	conversation_understood = false
	conversation_understanding_rolls = []
	conversation_feedback = ""
	conversation_clean_units = []


func configure_conversation_locale(locale_code: String, _unused_legacy_texts: Array[String] = []) -> void:
	conversation_locale = locale_code if locale_code in ["zh", "ja", "en"] else "zh"
	_localize_conversation_display()
	if not conversation_clean_sentence.is_empty():
		conversation_clean_units = _conversation_units(conversation_clean_sentence)


func _localize_conversation_display() -> void:
	if conversation_locale == "zh":
		return
	var locale: BabelGameLocale = GameLocaleScript.for_locale(conversation_locale)
	conversation_actor_label = locale.translate(conversation_actor_label)
	conversation_prompt = locale.translate(conversation_prompt)
	conversation_result_line = locale.translate(conversation_result_line)
	var localized_choices: Array = []
	for choice in conversation_choices:
		var localized_choice: Dictionary = (choice as Dictionary).duplicate(true)
		localized_choice["summary"] = locale.translate(str(localized_choice.get("summary", "")))
		localized_choice["sentence"] = locale.translate(str(localized_choice.get("sentence", "")))
		localized_choices.append(localized_choice)
	conversation_choices = localized_choices


func _reality_dialogue_for_actor(actor_id: String, actor_type: String) -> Dictionary:
	var floor_number := clampi(tower_floor, 1, 3)
	if actor_type == "doll":
		var encounter: Dictionary = LanguageCorruptionContentScript.get_doll_encounter_by_id(actor_id)
		if encounter.is_empty():
			encounter = LanguageCorruptionContentScript.get_doll_encounter_for_floor(floor_number)
		var doll_turns: Array = encounter.get("turns", [])
		if doll_turns.is_empty():
			return {"line": "布偶的缝线动了一下。", "result": "它没有留下任何东西。", "choices": []}
		var first_doll_turn: Dictionary = (doll_turns[0] as Dictionary).duplicate(true)
		first_doll_turn["continuation_turns"] = doll_turns.slice(1).duplicate(true)
		return first_doll_turn
	if actor_type == "key_npc":
		var key_dialogue: Dictionary = LanguageCorruptionContentScript.get_key_npc_dialogue_for_floor(floor_number)
		var key_turns: Array = key_dialogue.get("turns", [])
		if key_turns.is_empty():
			return {"line": "你来得太早了。", "result": "对方没有再开口。", "choices": []}
		var first_turn: Dictionary = (key_turns[0] as Dictionary).duplicate(true)
		first_turn["continuation_turns"] = key_turns.slice(1).duplicate(true)
		return first_turn
	var entries: Array = LanguageCorruptionContentScript.get_dialogues_for_floor(floor_number)
	var actor_index := _reality_actor_index(actor_id)
	if entries.is_empty():
		return {"line_id": "fallback", "speaker": "", "line": "你打算说什么？", "result": "对方没有马上回答。", "choices": []}
	var dialogue: Dictionary = (entries[actor_index % entries.size()] as Dictionary).duplicate(true)
	var arc: Dictionary = LanguageCorruptionContentScript.get_followups_for_archetype(actor_index)
	dialogue["continuation_turns"] = (arc.get("turns", []) as Array).duplicate(true)
	dialogue["interrupt"] = str(arc.get("interrupt", ""))
	return dialogue


func _reality_actor_index(actor_id: String) -> int:
	for index in 8:
		if actor_id.ends_with("npc%d" % index):
			return index
	return 0


func preview_typed_reality_choice(choice_id: String) -> String:
	for choice in conversation_choices:
		if str(choice.get("id", "")) == choice_id:
			if bool(choice.get("locked", false)):
				return ""
			return str(choice.get("sentence", "")).strip_edges()
	return ""


func select_typed_reality_choice(choice_id: String) -> bool:
	if conversation_phase != "choosing":
		return false
	for choice: Dictionary in conversation_choices:
		if str(choice.get("id", "")) == choice_id and bool(choice.get("locked", false)):
			return false
	var sentence := preview_typed_reality_choice(choice_id)
	if sentence.is_empty():
		return false
	conversation_selected_choice_id = choice_id
	conversation_clean_sentence = sentence
	conversation_clean_units = _conversation_units(sentence)
	conversation_revealed_units = []
	conversation_reveal_index = 0
	conversation_understood = false
	conversation_understanding_rolls = []
	conversation_phase = "typing"
	return true


func advance_typed_reality_character() -> Dictionary:
	var result := {
		"advanced": false,
		"completed": false,
		"understood": false,
		"conversation_completed": false,
		"can_continue": false,
		"interrupted": false,
		"reward": {},
	}
	if conversation_phase != "typing":
		return result
	if conversation_reveal_index >= conversation_clean_units.size():
		return result
	var clean_character := conversation_clean_units[conversation_reveal_index]
	var roll := _conversation_roll("character", conversation_reveal_index, 0)
	var garble_percent := mini(pollution, 65)
	var corrupted := roll < garble_percent and clean_character not in PROTECTED_PUNCTUATION
	var display_character := clean_character
	if corrupted:
		display_character = _conversation_corruption_text(roll, conversation_reveal_index)
	var revealed_units := conversation_revealed_units
	revealed_units.append({
		"clean": clean_character,
		"display": display_character,
		"corrupted": corrupted,
		"roll": roll,
	})
	conversation_revealed_units = revealed_units
	conversation_reveal_index += 1
	result["advanced"] = true
	if conversation_reveal_index < conversation_clean_units.size():
		return result

	result["completed"] = true
	var is_key_npc_final_turn := conversation_actor_type == "key_npc" and conversation_turn_index + 1 >= conversation_turns.size()
	var is_claimed_doll_repeat := conversation_actor_type == "doll" and is_doll_claimed(conversation_actor_id)
	var should_count_now := conversation_actor_type != "doll" and (conversation_actor_type != "key_npc" or is_key_npc_final_turn) and not is_claimed_doll_repeat
	if not conversation_counted and should_count_now:
		conversation_counted = true
		reality_dialogue_count += 1
	conversation_attempts += 1
	last_clean_sentence = conversation_clean_sentence
	last_polluted_sentence = get_typed_reality_spoken_sentence()
	var understood := true
	if conversation_actor_type in ["key_npc", "doll"]:
		conversation_understanding_rolls = []
		npc_understanding = 100
	else:
		understood = _resolve_typed_reality_understanding()
	conversation_understood = understood
	result["understood"] = understood
	if not understood:
		last_relationship_residue_gain = clampi(1 + int(pollution / 18.0), 1, 14)
		relationship_residue = clampi(relationship_residue + last_relationship_residue_gain, 0, 100)
	conversation_feedback = conversation_result_line
	conversation_history.append({
		"turn_index": conversation_turn_index,
		"prompt": conversation_prompt,
		"choice_id": conversation_selected_choice_id,
		"clean_sentence": conversation_clean_sentence,
		"spoken_sentence": last_polluted_sentence,
		"understood": understood,
		"understanding_rolls": conversation_understanding_rolls.duplicate(),
		"result": conversation_result_line,
	})
	conversation_phase = "result"
	if not understood:
		conversation_can_continue = false
		conversation_interrupted = true
		if not conversation_interrupt_line.is_empty():
			conversation_feedback += "\n" + conversation_interrupt_line
		result["interrupted"] = true
		return result

	if conversation_turn_index + 1 < conversation_turns.size():
		conversation_can_continue = true
		result["can_continue"] = true
		return result

	conversation_can_continue = false
	conversation_completed = true
	result["conversation_completed"] = true
	if conversation_actor_type == "key_npc":
		conversation_reward = _resolve_key_npc_clue_attempt()
		result["reward"] = conversation_reward.duplicate(true)
		conversation_feedback += "\n" + str(conversation_reward.get("feedback", ""))
	elif conversation_actor_type == "doll":
		conversation_reward = _resolve_doll_choice_attempt()
		result["reward"] = conversation_reward.duplicate(true)
		conversation_feedback += "\n" + str(conversation_reward.get("feedback", ""))
	return result


func _resolve_key_npc_clue_attempt() -> Dictionary:
	var floor_number := clampi(tower_floor, 1, 3)
	var key_dialogue: Dictionary = LanguageCorruptionContentScript.get_key_npc_dialogue_for_floor(floor_number)
	var turns: Array = key_dialogue.get("turns", [])
	var selected_ids: Array[String] = []
	for history_entry: Dictionary in conversation_history:
		selected_ids.append(str(history_entry.get("choice_id", "")))
	var correct_count := 0
	for turn_index in mini(turns.size(), selected_ids.size()):
		var turn: Dictionary = turns[turn_index]
		for choice: Dictionary in turn.get("choices", []):
			if bool(choice.get("correct", false)) and str(choice.get("id", "")) == selected_ids[turn_index]:
				correct_count += 1
				break
	var solved := turns.size() == 2 and correct_count == turns.size()
	var progress_key := str(floor_number)
	var previous: Dictionary = (key_clue_progress.get(progress_key, {}) as Dictionary).duplicate(true)
	var progress := {
		"attempts": int(previous.get("attempts", 0)) + 1,
		"correct_answers": correct_count,
		"last_answers": selected_ids.duplicate(),
		"solved": bool(previous.get("solved", false)) or solved,
	}
	key_clue_progress[progress_key] = progress
	var item := get_prerequisite_item_for_floor(floor_number, "zh")
	var item_id := str(item.get("id", ""))
	var newly_revealed := false
	var feedback := str(key_dialogue.get("failure_line", "对方没有说出地点。"))
	if solved:
		newly_revealed = reveal_prerequisite_item_for_floor(floor_number)
		feedback = "%s\n%s" % [
			str(key_dialogue.get("success_line", "对方终于说出了地点。")),
			str(item.get("location_hint", "这一层有一件东西正等着被找到。")),
		]
	# 第三层的门规则叙事:由现有 key NPC 对话尾部立起(不新增 NPC、不新增对话节点)。
	if floor_number == 3 and not floor3_task_complete:
		feedback += "\n这扇门是下一层的入口。它现在还打不开。"
	return {
		"kind": "prerequisite_clue",
		"floor": floor_number,
		"item_id": item_id,
		"correct_answers": correct_count,
		"solved": solved,
		"newly_revealed": newly_revealed,
		"feedback": feedback,
	}


func is_doll_claimed(doll_id: String) -> bool:
	return doll_id in claimed_doll_ids


func get_doll_choice_result(doll_id: String) -> Dictionary:
	return (doll_choice_results.get(doll_id, {}) as Dictionary).duplicate(true)


func _doll_choice_by_id(encounter: Dictionary, choice_id: String) -> Dictionary:
	for turn: Dictionary in encounter.get("turns", []):
		for choice: Dictionary in turn.get("choices", []):
			if str(choice.get("id", "")) == choice_id:
				return choice.duplicate(true)
	return {}


func _doll_choice_is_locked(choice: Dictionary) -> bool:
	var minimum_pollution := int(choice.get("required_pollution_min", 0))
	var maximum_pollution := int(choice.get("required_pollution_max", 100))
	return pollution < minimum_pollution or pollution > maximum_pollution


func _resolve_doll_choice_attempt() -> Dictionary:
	var encounter: Dictionary = LanguageCorruptionContentScript.get_doll_encounter_by_id(conversation_actor_id)
	var choice: Dictionary = _doll_choice_by_id(encounter, conversation_selected_choice_id)
	var reward := {
		"kind": "doll_guidance",
		"doll_id": conversation_actor_id,
		"choice_id": conversation_selected_choice_id,
		"guided": false,
		"duplicate": false,
		"locked": false,
		"feedback": "布偶把缝线朝向了下一步。",
	}
	if encounter.is_empty() or choice.is_empty():
		return reward
	if is_doll_claimed(conversation_actor_id):
		reward["duplicate"] = true
		reward["feedback"] = str(encounter.get("repeat_line", "布偶重复了一遍刚才的方向。"))
		return reward
	if _doll_choice_is_locked(choice):
		reward["locked"] = true
		reward["feedback"] = "那一段话还没有长到你能听见的位置。"
		return reward

	var result_record := {
		"choice_id": conversation_selected_choice_id,
		"day": day,
		"floor": clampi(tower_floor, 1, 3),
	}
	claimed_doll_ids.append(conversation_actor_id)
	doll_choice_results[conversation_actor_id] = result_record
	reward["guided"] = true
	reward["feedback"] = str(choice.get("guide_feedback", "它让你先照做，理由可以晚一点再问。"))
	record_event("缝线布偶指向了下一步。")
	return reward


func get_typed_reality_spoken_sentence() -> String:
	var pieces: Array[String] = []
	for unit in conversation_revealed_units:
		pieces.append(str(unit.get("display", "")))
	return "".join(pieces)


func get_typed_reality_unrevealed_suffix() -> String:
	if conversation_clean_units.is_empty() or conversation_reveal_index >= conversation_clean_units.size():
		return ""
	var suffix := ""
	for index in range(conversation_reveal_index, conversation_clean_units.size()):
		suffix += conversation_clean_units[index]
	return suffix


func get_typed_reality_unit_count() -> int:
	return conversation_clean_units.size()


func _conversation_units(sentence: String) -> Array[String]:
	return GameLocaleScript.split_dialogue_units(sentence, conversation_locale)


func _conversation_corruption_text(roll: int, character_index: int) -> String:
	var memes := completed_memes
	if not memes.is_empty() and posmod(roll + character_index, 3) == 0:
		var meme_index := posmod(roll + conversation_attempts + character_index, memes.size())
		var meme: Dictionary = memes[meme_index]
		var meme_text := str(meme.get("title", meme.get("text", ""))).strip_edges()
		if not meme_text.is_empty():
			return meme_text.substr(0, mini(4, meme_text.length()))
	return REALITY_CORRUPTION_GLYPHS[posmod(roll + character_index, REALITY_CORRUPTION_GLYPHS.size())]


func _resolve_typed_reality_understanding() -> bool:
	conversation_understanding_rolls = []
	var base_clear_chance := clampi(100 - pollution, 5, 96)
	var check_count := 1
	var understood := false
	for check_index in check_count:
		var roll := _conversation_roll("understanding", 0, check_index)
		conversation_understanding_rolls.append(roll)
		if roll < base_clear_chance:
			understood = true
	npc_understanding = base_clear_chance
	return understood


func _conversation_roll(channel: String, character_index: int, check_index: int) -> int:
	var key := "%s|%s|%d|%d|%d|%d|%s" % [
		conversation_actor_id,
		conversation_selected_choice_id,
		day,
		conversation_attempts,
		character_index,
		check_index,
		channel,
	]
	return posmod(int(hash(key)), 100)


func pick_token(post_id: String, token: Dictionary) -> bool:
	var content_locale := str(token.get("content_locale", "zh"))
	var picked_text := str(token.get("text", "")).strip_edges()
	if picked_text.is_empty():
		return false
	var note := {
		"id": "%s-%s-%d" % [post_id, token.get("id", "token"), day],
		"text": picked_text,
		"lexeme_id": str(token.get("lexeme_id", token.get("id", "token"))),
		"grammar_roles": (token.get("grammar_roles", [str(token.get("grammar_role", "subject"))]) as Array).duplicate(),
		"phone_surface": str(token.get("phone_surface", picked_text)),
		"doctor_surface": str(token.get("doctor_surface", picked_text)),
		"doll_surface": str(token.get("doll_surface", picked_text)),
		"source_text": str(token.get("source_text", token.get("text", ""))),
		"content_locale": content_locale,
		"source_post_id": post_id,
		"tags": token.get("tags", []),
		"rarity": int(token.get("rarity", 1)),
		"picked_day": day,
		"source_card_id": str(token.get("source_card_id", "")),
		"pollution_stage": 0,
		"used_worlds": [],
	}
	note = LanguageBridgeScript.normalized_token(note)
	for existing in notebook_tokens:
		if existing.get("id", "") == note["id"]:
			return false
	_run_list(PropertyKeysScript.NOTEBOOK_TOKENS).add(note)
	return true


func get_pickup_unit_pool(locale_code: String = "zh") -> Array:
	return PickupCharPoolScript.get_unit_pool(locale_code)


func is_social_char_collected(unit: String, locale_code: String = "zh") -> bool:
	for entry in collected_char_units:
		if entry is Dictionary and str((entry as Dictionary).get("unit", "")) == unit and str((entry as Dictionary).get("locale", "zh")) == locale_code:
			return true
	return false


func get_collected_char_units(locale_code: String = "zh") -> Array[String]:
	return char_units_for_locale(collected_char_units, locale_code)


## The held words of one language, in pick order, from the entries the held-word model stores.
static func char_units_for_locale(entries: Array, locale_code: String) -> Array[String]:
	var result: Array[String] = []
	for entry in entries:
		if entry is Dictionary and str((entry as Dictionary).get("locale", "zh")) == locale_code:
			var unit := str((entry as Dictionary).get("unit", ""))
			if not unit.is_empty() and unit not in result:
				result.append(unit)
	return result


## 拾取帖文中的单个语言单位(中文单字/日文单词/英文单词)。拾取不限次数;成功的拾取是一次有效互动,之后检查进度。
func pick_social_char(post_id: String, unit: String, locale_code: String = "zh") -> Dictionary:
	var result := _pick_social_char(post_id, unit, locale_code)
	result["outcome"] = _finish_interaction() if bool(result.get("picked", false)) else _refused_outcome()
	return result


func _pick_social_char(post_id: String, unit: String, locale_code: String) -> Dictionary:
	var result := {"picked": false, "reason": ""}
	var normalized_unit := unit.strip_edges()
	if normalized_unit.is_empty() or not PickupCharPoolScript.is_unit_in_pool(normalized_unit, locale_code):
		result["reason"] = "not-in-pool"
		return result
	if not PickupCharPoolScript.is_unit_seeded_in_post(post_id, normalized_unit, locale_code):
		result["reason"] = "not-in-post"
		return result
	if is_social_char_collected(normalized_unit, locale_code):
		result["reason"] = "duplicate"
		return result
	_run_list(PropertyKeysScript.COLLECTED_CHAR_UNITS).add({
		"unit": normalized_unit,
		"locale": locale_code,
		"source_post_id": post_id,
		"day": day,
	})
	result["picked"] = true
	return result


## ============ 自由造句(多邻国式词库,无固定主谓宾)与世界规则 ============

func get_free_sentence_units() -> Array:
	return free_sentence_units


func free_sentence_place(unit: String, locale_code: String = "zh") -> bool:
	var normalized_unit := unit.strip_edges()
	if normalized_unit.is_empty():
		return false
	if not is_social_char_collected(normalized_unit, locale_code):
		return false
	if normalized_unit in free_sentence_units:
		return false
	_run_list(PropertyKeysScript.FREE_SENTENCE_UNITS).add(normalized_unit)
	return true


func free_sentence_remove(unit_index: int) -> bool:
	if unit_index < 0 or unit_index >= free_sentence_units.size():
		return false
	_run_list(PropertyKeysScript.FREE_SENTENCE_UNITS).remove_at(unit_index)
	return true


## 拖拽支持:把词库单位放到指定位置(index 越界即追加句尾)。
func free_sentence_place_at(unit: String, insert_index: int, locale_code: String = "zh") -> bool:
	var normalized_unit := unit.strip_edges()
	if normalized_unit.is_empty() or not is_social_char_collected(normalized_unit, locale_code):
		return false
	var units := free_sentence_units
	if normalized_unit in units:
		return false
	_run_list(PropertyKeysScript.FREE_SENTENCE_UNITS).insert_at(clampi(insert_index, 0, units.size()), normalized_unit)
	return true


## 拖拽支持:答案区内重排。to_index 是移除后的目标位置(越界即句尾)。
func free_sentence_move(from_index: int, to_index: int) -> bool:
	var units := free_sentence_units
	if from_index < 0 or from_index >= units.size():
		return false
	var moved_unit: Variant = units[from_index]
	units.remove_at(from_index)
	units.insert(clampi(to_index, 0, units.size()), moved_unit)
	free_sentence_units = units
	return true


func free_sentence_clear() -> void:
	free_sentence_units = []


func get_free_sentence_text(locale_code: String = "zh") -> String:
	return sentence_text(free_sentence_units, locale_code)


## English words are spaced; the other locales join units directly.
static func sentence_text(units: Array, locale_code: String) -> String:
	var separator := " " if locale_code == "en" else ""
	var pieces: Array[String] = []
	for unit in units:
		pieces.append(str(unit))
	return separator.join(pieces)


func is_world_rule_active(rule_key: String) -> bool:
	var rules := world_rules
	if not rules.has(rule_key):
		return false
	return not bool((rules[rule_key] as Dictionary).get("negated", false))


func get_world_rules() -> Array:
	return world_rule_list(world_rules)


## The rules map as a list, each rule carrying its own key.
static func world_rule_list(rules: Dictionary) -> Array:
	var result: Array = []
	for rule_key in rules.keys():
		var rule: Dictionary = (rules[rule_key] as Dictionary).duplicate(true)
		rule["key"] = str(rule_key)
		result.append(rule)
	return result


## 投稿:随时可结束造句(≥1 个单位即可),不限次数;成功的投稿是一次有效互动,之后检查进度。
## 三层响应:rule(规则生效,世界异变)/ misread(世界误读)/ noise(噪声回应)。
func submit_free_sentence(locale_code: String = "zh") -> Dictionary:
	var result := _submit_free_sentence(locale_code)
	if not bool(result.get("submitted", false)):
		result["outcome"] = _refused_outcome()
		return result
	# 刚让出口存在的这一句不立即进入结局:玩家先看见出口,下一次有效互动完成时才结算。
	result["outcome"] = _finish_interaction(bool(result.get("floor4_task_completed", false)))
	return result


func _submit_free_sentence(locale_code: String) -> Dictionary:
	var result := {
		"submitted": false, "reason": "", "tier": "", "rule_key": "", "negated": false,
		"sentence": "", "pollution_gain": 0,
		"floor3_task_completed": false, "floor4_task_completed": false,
	}
	var units := free_sentence_units
	if units.is_empty():
		result["reason"] = "empty"
		return result
	var sentence := sentence_text(units, locale_code)
	var parsed: Dictionary = RuleEngineScript.parse(units, locale_code)
	var unit_count := units.size()
	var tier := str(parsed.get("tier", "noise"))
	var pollution_gain := clampi(2 + unit_count + (2 if tier == "rule" else 0), 2, 12)
	var record := {
		"id": "free-%d-%d" % [day, published_memes.size() + 1],
		"kind": "free_sentence",
		"title": "投稿「%s」" % sentence,
		"text": sentence,
		"units": units,
		"tier": tier,
		"rule_key": str(parsed.get("rule_key", "")),
		"negated": bool(parsed.get("negated", false)),
		"floor": tower_floor,
		"published_day": day,
		"pollution_gain": pollution_gain,
		"content_locale": locale_code,
	}
	_run_list(PropertyKeysScript.PUBLISHED_MEMES).insert_at(0, record)
	sentence_records.append(record.duplicate(true))
	last_clean_sentence = sentence
	if tier == "rule":
		var floor3_before := floor3_task_complete
		var floor4_before := floor4_task_complete
		_apply_world_rule(parsed, sentence, locale_code)
		result["floor3_task_completed"] = floor3_task_complete and not floor3_before
		result["floor4_task_completed"] = floor4_task_complete and not floor4_before
	change_pollution(pollution_gain)
	free_sentence_units = []
	result["submitted"] = true
	result["tier"] = tier
	result["rule_key"] = str(parsed.get("rule_key", ""))
	result["negated"] = bool(parsed.get("negated", false))
	result["sentence"] = sentence
	result["pollution_gain"] = pollution_gain
	return result


func _apply_world_rule(parsed: Dictionary, sentence: String, locale_code: String) -> void:
	var rule_key := str(parsed.get("rule_key", ""))
	if rule_key.is_empty():
		return
	# Baba 式冲突消解:同键新规则覆盖旧规则;否定即压制既有正例。
	_put_run_map_entry(PropertyKeysScript.WORLD_RULES, rule_key, {
		"negated": bool(parsed.get("negated", false)),
		"source_text": sentence,
		"locale": locale_code,
		"day": day,
		"floor": tower_floor,
	})
	if not bool(parsed.get("negated", false)):
		match rule_key:
			"door|can_open":
				record_event("有一句话贴上了门。")
			"exit|exists":
				record_event("有一句话在找它的出口。")
			"light|lit":
				record_event("有一盏灯听懂了。")
	_latch_ultimate_tasks_for_current_floor()


## 终极任务在规则生效、抵达楼层与读档三个时机都会重扫:
## 早于楼层写下的规则,到层后依然兑现;任务一旦达成即锁存,不被后续否定收回。
## 第四层的隐藏结局不在此立即解锁——只在有效互动完成后的进度检查结算(见 _resolve_tower_step),
## 玩家先看见出口出现,下一次有效互动完成时才进入结局。
func _latch_ultimate_tasks_for_current_floor() -> void:
	if tower_floor == 3 and not floor3_task_complete and is_world_rule_active("door|can_open"):
		floor3_task_complete = true
		record_event("第三层的门开了。")
	if tower_floor == 4 and not floor4_task_complete and is_world_rule_active("exit|exists"):
		floor4_task_complete = true
		record_event("出口开始存在。")


## ============ 笔记本字词画布:字被拾取后一直留在画布上,位置可自由拖动 ============

const CHAR_CANVAS_SIZE := Vector2(520.0, 300.0)
const CHAR_CANVAS_TILE := Vector2(44.0, 40.0)


func get_char_canvas_position(unit: String, locale_code: String = "zh") -> Vector2:
	var key := "%s|%s" % [locale_code, unit]
	var positions := char_canvas_positions
	if positions.has(key):
		var stored: Variant = positions[key]
		if stored is Vector2:
			return stored
		if stored is Array and (stored as Array).size() == 2:
			return Vector2(float(stored[0]), float(stored[1]))
	return _default_char_canvas_position(unit, locale_code)


## The canvas hands over every resting tile at once (before it closes, redraws, or saves).
## The map model is written once, and not at all when nothing moved.
func set_char_canvas_positions(tile_positions: Dictionary, locale_code: String = "zh") -> void:
	var positions := char_canvas_positions
	var moved := false
	for unit in tile_positions.keys():
		var position: Vector2 = tile_positions[unit]
		var clamped := Vector2(
			clampf(position.x, 0.0, CHAR_CANVAS_SIZE.x - CHAR_CANVAS_TILE.x),
			clampf(position.y, 0.0, CHAR_CANVAS_SIZE.y - CHAR_CANVAS_TILE.y)
		)
		var key := "%s|%s" % [locale_code, str(unit)]
		var stored: Variant = positions.get(key, null)
		if stored is Array and (stored as Array).size() == 2:
			if Vector2(float(stored[0]), float(stored[1])).is_equal_approx(clamped):
				continue
		positions[key] = [clamped.x, clamped.y]
		moved = true
	if not moved:
		return
	var model: MapPropertyModel = _run_model(PropertyKeysScript.CHAR_CANVAS_POSITIONS) as MapPropertyModel
	if model != null:
		model.replace_all(positions)


## 新拾取的字从画布上方落下:横向按顺序错开,纵向给一点高度差,
## 落地后由物理决定它堆在哪里(像积木一样越堆越高)。
func _default_char_canvas_position(unit: String, locale_code: String) -> Vector2:
	var units: Array[String] = get_collected_char_units(locale_code)
	var index := maxi(0, units.find(unit))
	var columns := maxi(1, int(CHAR_CANVAS_SIZE.x / (CHAR_CANVAS_TILE.x + 12.0)))
	var column := index % columns
	var drop_row := int(index / float(columns))
	return Vector2(
		clampf(float(column) * (CHAR_CANVAS_TILE.x + 12.0) + 10.0, 0.0, CHAR_CANVAS_SIZE.x - CHAR_CANVAS_TILE.x),
		clampf(18.0 + float(drop_row) * 6.0, 0.0, CHAR_CANVAS_SIZE.y - CHAR_CANVAS_TILE.y)
	)


## ============ 玩家投稿回流:论坛开始引用你写过的句子 ============
##
## 依据 docs/plans/2026-08-17-horror-atmosphere-and-mechanics-plan.md 的 M 系机制:
## 玩家自己的行为是最贵的恐怖素材。三阶递进,污染值越高走得越远:
##   stage 1 原样引用 → stage 2 截断引用(砍掉的正是安全阀)→ stage 3 换主语当旁证。
## 系统永远不提示这句话出自玩家自己。

const ECHO_QUOTE_STAGE_THRESHOLDS := [0, 30, 60]


func get_player_quote_stage() -> int:
	var stage := 0
	for index in ECHO_QUOTE_STAGE_THRESHOLDS.size():
		if pollution >= int(ECHO_QUOTE_STAGE_THRESHOLDS[index]):
			stage = index + 1
	return stage


## 返回一条玩家投稿回流,没有可引用的投稿时返回空串。
## 引用对象取最近一条投稿,与投稿日一起决定表现,不使用随机。
func get_player_echo_quote(locale_code: String = "zh") -> String:
	var source := ""
	for record in published_memes:
		if record is Dictionary and str((record as Dictionary).get("kind", "")) == "free_sentence":
			source = str((record as Dictionary).get("text", "")).strip_edges()
			if not source.is_empty():
				break
	if source.is_empty():
		return ""
	var stage := get_player_quote_stage()
	if stage <= 1:
		return source
	var units: Array = []
	for record in published_memes:
		if record is Dictionary and str((record as Dictionary).get("kind", "")) == "free_sentence":
			units = (record as Dictionary).get("units", [])
			break
	if stage == 2:
		# 截断引用:砍掉最后一个单位 —— 被砍掉的往往正是那句话的限定与保证。
		if units.size() >= 2:
			var kept: Array = units.slice(0, units.size() - 1)
			var separator := " " if locale_code == "en" else ""
			var pieces: Array[String] = []
			for unit in kept:
				pieces.append(str(unit))
			return separator.join(pieces)
		return source
	# stage 3:换主语当旁证 —— 你的句子被安到别人头上(措辞见 echo_quote_content.gd)。
	return EchoQuoteContentScript.reattribute(source, locale_code)


func get_inventory_snapshot() -> Dictionary:
	var craft_slot_fills := {}
	var drafts := draft_slots
	for slot_def: Dictionary in LANGUAGE_RECIPE_SLOTS:
		var slot_id := str(slot_def.get("id", ""))
		if not drafts.has(slot_id):
			continue
		var token := _find_token(str(drafts[slot_id]))
		if not token.is_empty():
			craft_slot_fills[slot_id] = str(token.get("text", ""))
	return {
		"completed_memes": completed_memes,
		"notebook_token_count": notebook_tokens.size(),
		"draft_slots": drafts,
		"craft_slot_fills": craft_slot_fills,
	}


func get_craft_slots() -> Array:
	return LANGUAGE_RECIPE_SLOTS.duplicate(true)


func get_craft_sentence_preview(world: String = "phone") -> Dictionary:
	return LanguageBridgeScript.compose_sentence(draft_slots, notebook_tokens, world, conversation_locale)


func place_token_in_slot(slot_id: String, token_id: String) -> bool:
	var token := _find_token(token_id)
	if token.is_empty():
		return false
	var accepted_role := ""
	for slot: Dictionary in LANGUAGE_RECIPE_SLOTS:
		if str(slot.get("id", "")) == slot_id:
			accepted_role = str(slot.get("accepted_role", ""))
			break
	if accepted_role.is_empty():
		return false
	var token_roles: Array = token.get("grammar_roles", [])
	if accepted_role not in token_roles:
		return false
	_put_run_map_entry(PropertyKeysScript.DRAFT_SLOTS, slot_id, token_id)
	return true


func confirm_craft() -> bool:
	var validation: Dictionary = LanguageBridgeScript.validate_recipe(draft_slots, notebook_tokens)
	if not bool(validation.get("valid", false)):
		return false
	var composition: Dictionary = LanguageBridgeScript.compose_sentence(draft_slots, notebook_tokens, "phone", conversation_locale)
	if not bool(composition.get("valid", false)):
		return false
	var token_ids: Array = composition.get("token_ids", [])
	var tags: Array = []
	var rarity_total := 0
	for token_id_value in token_ids:
		var token := _find_token(str(token_id_value))
		tags.append_array(token.get("tags", []))
		rarity_total += int(token.get("rarity", 1))
	tags = _unique(tags)
	var sentence_text := str(composition.get("world_sentence", composition.get("clean_sentence", "")))
	var meme := {
		"id": "meme-%d-%d" % [day, completed_memes.size() + 1],
		"title": "句子「%s」" % sentence_text,
		"text": sentence_text,
		"clean_text": str(composition.get("clean_sentence", sentence_text)),
		"token_ids": token_ids.duplicate(),
		"lexeme_ids": (composition.get("lexeme_ids", []) as Array).duplicate(),
		"tags": tags,
		"rarity": _meme_rarity_from_tags(tags),
		"pollution_bias": maxi(1, rarity_total - token_ids.size()),
		"unit_count": token_ids.size(),
		"created_day": day,
	}
	_run_list(PropertyKeysScript.COMPLETED_MEMES).insert_at(0, meme)
	draft_slots = {}
	return true


func get_progression_snapshot() -> Dictionary:
	return {
		"ending_unlocked": ending_unlocked,
		"ending_route": ending_route,
		"formal_floor_three_complete": formal_floor_three_complete,
		"floor3_task_complete": floor3_task_complete,
		"floor4_task_complete": floor4_task_complete,
	}


## A valid interaction (a post, a finished conversation, a pickup) completed: the progress check runs, and the
## outcome takes the pending flashback and says whether the floor moved. A post that just made the exit exist
## holds the hidden ending back for the next interaction.
func _finish_interaction(exit_just_appeared: bool = false) -> ActionOutcomeScript:
	var floor_before := tower_floor
	_resolve_tower_step(not exit_just_appeared)
	var outcome := ActionOutcomeScript.new()
	outcome.succeeded = true
	outcome.flashback = consume_pollution_flashback()
	outcome.floor_changed = tower_floor != floor_before
	return outcome


## An attempt that did not count as an interaction checks nothing.
func _refused_outcome() -> ActionOutcomeScript:
	return ActionOutcomeScript.new()


func get_relationship_state_label() -> String:
	if relationship_residue < 20:
		return "仍能认出你"
	if relationship_residue < 45:
		return "句子留下裂痕"
	if relationship_residue < 70:
		return "只剩熟悉的语气"
	return "彼此已无法确认"


func _find_token_text(token_id: String) -> String:
	return str(_find_token(token_id).get("text", ""))


func _find_token(token_id: String) -> Dictionary:
	for token_value in notebook_tokens:
		if token_value is Dictionary and str((token_value as Dictionary).get("id", "")) == token_id:
			return (token_value as Dictionary).duplicate(true)
	return {}


func _find_token_tags(token_id: String) -> Array:
	return (_find_token(token_id).get("tags", []) as Array).duplicate()


func _find_token_rarity(token_id: String) -> int:
	return int(_find_token(token_id).get("rarity", 1))


## The progress check after a valid interaction: the pollution floor step, the floor-three finish and the hidden ending.
func _resolve_tower_step(may_unlock_hidden_ending: bool = true) -> void:
	resolve_floor_transition_at_boundary()
	if tower_floor == 3 and pollution >= int(POLLUTION_FLOOR_THRESHOLDS[3]) and not formal_floor_three_complete:
		complete_floor_three()
	# 第四层终极任务完成后,隐藏结局只在下一次有效互动完成时解锁,不打断出口出现的当下。
	if may_unlock_hidden_ending and tower_floor == 4 and ending_route == "hidden" and floor4_task_complete and not ending_unlocked:
		ending_unlocked = true
		record_event("出口承认了你。")


func _find_completed_meme_index(meme_id: String) -> int:
	var memes := completed_memes
	for index in memes.size():
		if str(memes[index].get("id", "")) == meme_id:
			return index
	return -1


func _meme_rarity_from_tags(tags: Array) -> int:
	return clampi(1 + int(floor(float(tags.size()) / 2.0)), 1, 5)


func _intersect(left: Array, right: Array) -> Array:
	var result: Array = []
	for value in left:
		if value in right and value not in result:
			result.append(value)
	return result


func _contains_all_ids(values: Array, required_ids: Array) -> bool:
	for required_id in required_ids:
		if required_id not in values:
			return false
	return true


func _unique(values: Array) -> Array:
	var result: Array = []
	for value in values:
		if value not in result:
			result.append(value)
	return result


func _first_pickable_character(value: String, locale_code: String = "zh") -> String:
	if locale_code == "en":
		var word_regex := RegEx.new()
		word_regex.compile("[A-Za-z0-9']+")
		var match_result := word_regex.search(value)
		return match_result.get_string() if match_result != null else ""
	var ignored := " \t\r\n　，。！？；：、,.!?;:（）()【】[]《》<>〈〉「」『』〔〕“”\"'—-…・"
	if locale_code == "ja":
		var start := 0
		var end := value.length()
		while start < end and ignored.contains(value.substr(start, 1)):
			start += 1
		while end > start and ignored.contains(value.substr(end - 1, 1)):
			end -= 1
		return value.substr(start, end - start)
	for index in value.length():
		var character := value.substr(index, 1)
		if not ignored.contains(character):
			return character
	return ""
