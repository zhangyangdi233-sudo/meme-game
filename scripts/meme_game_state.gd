class_name MemeGameState
extends RefCounted

const GameLocaleScript = preload("res://scripts/localization/game_locale.gd")
const PollutionStageScript = preload("res://scripts/world/pollution_stage.gd")
const LanguageCorruptionContentScript = preload("res://scripts/narrative/language_corruption_content.gd")
const LanguageBridgeScript = preload("res://scripts/narrative/language_bridge.gd")
const TutorialDirectorScript = preload("res://scripts/tutorial/tutorial_director.gd")
const PickupCharPoolScript = preload("res://scripts/narrative/pickup_char_pool.gd")
const RuleEngineScript = preload("res://scripts/narrative/rule_engine.gd")
const EchoQuoteContentScript = preload("res://scripts/narrative/echo_quote_content.gd")
const MAX_TOWER_FLOOR := 4
const POLLUTION_FLOOR_THRESHOLDS := {1: 25, 2: 60, 3: 80}
const PREREQUISITE_ITEMS := {
	1: {
		"id": "artifact_named_lamp_tag",
		"label": "写着“小月亮”的旧名牌",
		"location_hint": "沿主路往前走，在右侧第一盏不亮的路灯脚边。",
	},
	2: {
		"id": "artifact_reversed_tape",
		"label": "两面都录着同一句话的磁带",
		"location_hint": "在与你醒来位置相反的低坡上，贴着一栋亮窗房子的门前。",
	},
	3: {
		"id": "artifact_missing_subject_page",
		"label": "缺少主语的病历页",
		"location_hint": "沿中央通道走过第三排立柱，夹在左侧那扇假窗下面。",
	},
}
const HISTORY_FIELD_NAMES := [
	"lineId", "originalSpeaker", "currentSpeaker", "originalText",
	"displayText", "revisionStage", "revisionMarkup",
]
const POLLUTION_FLASHBACK_THRESHOLD := 60
const BASE_ACTIONS_PER_DAY := 5
const LANGUAGE_RECIPE_SLOTS := [
	{"id": "subject", "label": "谁 / 什么", "placeholder": "放入主语", "accepted_role": "subject"},
	{"id": "action", "label": "发生了什么", "placeholder": "放入动作", "accepted_role": "action"},
	{"id": "object", "label": "对谁 / 在哪里", "placeholder": "放入落点", "accepted_role": "object"},
]
const DOCTOR_DIALOGUES_BY_FLOOR := {
	1: {"line": "把刚才那句再说一遍。不要替它解释。", "result": "医生记下来了。字数和你说的对不上。"},
	2: {"line": "按顺序念。不要按你记得的顺序，按你说过的顺序。", "result": "医生在每个词旁边写下另一种用途。笔尖比你慢半个字。"},
	3: {"line": "只用还登记在你名下的词。说出你现在的位置。", "result": "医生停笔。病历上的主语先一步空了。"},
	4: {"line": "这些词没有登记来源。签字栏是空的。你要在这里写谁。", "result": "没有人受理这句话的说话者。"},
}
const REALITY_CORRUPTION_GLYPHS := ["■", "▦", "∴", "//", "□", "▧", "≠", "…"]
const PROTECTED_PUNCTUATION := ["，", "。", "！", "？", "；", "：", "、", "…", ",", ".", "!", "?", ";", ":", "\"", "'", "（", "）", "(", ")"]
const ENDING_LANGUAGE_CHOICES := [
	{"id": "blank", "label": "空白", "output": "（空白）"},
	{"id": "blocks", "label": "■■■■", "output": "■ ■ ■ ■"},
	{"id": "hajimi", "label": "哈吉米", "output": "哈吉米"},
	{"id": "silence", "label": "沉默", "output": "……"},
]
const PROLOGUE_LINES := [
	"（先确认一件事。你手里拿着什么？）",
	"一部手机。没有信号。我醒来的时候它已经亮着。",
	"（你在等谁的消息？）",
	"不等消息。我在等路面停下来。它每退一步，塔多一层。",
	"城市广播说今天一切正常。它重复了七次。第八次我关掉了。",
	"（从哪里开始？）",
	"从字开始。先拼成一句话。再看这句话到了楼下变成什么。",
]
const EPILOGUE_LINES := [
	"所有帖子都说智者住在顶楼。顶楼没有人。",
	"只有一台发射机。它没有接线。指示灯跟着你的呼吸。",
	"（它在发送什么？）",
	"你把耳朵贴近外壳。里面有人在说你昨天说过的那句话。他说得比你准。",
	"你想说一句普通的话。第七层先开口了。",
]
const SAVE_DATA_VERSION := 5
const SAVE_FIELD_NAMES := [
	"day", "pollution", "tower_floor",
	"ending_unlocked", "ending_language_choice", "ending_route", "formal_floor_three_complete",
	"pending_floor_transition", "autoplay_enabled", "exit_prompt_seen",
	"money", "actions_remaining", "max_actions_per_day",
	"needs_day_settlement", "day_ended_reason", "pollution_flashback_seen", "pollution_flashback_pending",
	"view_state", "phone_visible", "phone_open", "active_app", "active_app_window",
	"notebook_tokens", "draft_slots", "completed_memes", "owned_meme_frames", "owned_meme_frame_ids",
	"claimed_doll_ids", "doll_choice_results",
	"fusion_slots", "fused_meme_pairs", "dialogue_blanks", "published_memes", "last_publish_result",
	"event_log", "social_followed_handles", "social_liked_post_ids", "collected_world_item_ids",
	"cover_watcher_seen_floors",
	"revealed_prerequisite_item_ids", "collected_prerequisite_item_ids", "key_clue_progress",
	"history_entries",
	"language_sentence_slots", "sentence_records", "tutorial_progress",
	"collected_char_units", "last_char_pick_day", "char_canvas_positions",
	"free_sentence_units", "world_rules", "floor3_task_complete", "floor4_task_complete",
	"last_clean_sentence", "last_polluted_sentence",
	"npc_understanding", "reality_phase", "relationship_residue", "last_relationship_residue_gain",
	"last_relationship_money_loss", "reality_dialogue_count",
]

var day: int = 1
var pollution: int = 0
var tower_floor: int = 1
var ending_unlocked: bool = false
var ending_language_choice: String = ""
var ending_route: String = ""
var formal_floor_three_complete: bool = false
var pending_floor_transition: int = 0
var autoplay_enabled: bool = false
var exit_prompt_seen: bool = false
var money: int = 18
var actions_remaining: int = 5
var max_actions_per_day: int = 5
var needs_day_settlement: bool = false
var day_ended_reason: String = ""
var pollution_flashback_seen: bool = false
var pollution_flashback_pending: bool = false

var view_state: String = "phone_down"
var phone_visible: bool = true
var phone_open: bool = true
var active_app: String = "social"
var active_app_window: String = "social"

var notebook_tokens: Array = []
var draft_slots: Dictionary = {}
var completed_memes: Array = []
var owned_meme_frames: int = 0
var owned_meme_frame_ids: Array[String] = []
var claimed_doll_ids: Array[String] = []
var doll_choice_results: Dictionary = {}
var fusion_slots: Dictionary = {}
var fused_meme_pairs: Array[String] = []
var dialogue_blanks: Dictionary = {}
var published_memes: Array = []
var last_publish_result: Dictionary = {}
var event_log: Array[String] = []
var social_followed_handles: Array[String] = []
var social_liked_post_ids: Array[String] = []

var collected_world_item_ids: Array[String] = []
var cover_watcher_seen_floors: Array[int] = []
var revealed_prerequisite_item_ids: Array[String] = []
var collected_prerequisite_item_ids: Array[String] = []
var key_clue_progress: Dictionary = {}
var history_entries: Array = []

var language_sentence_slots: Dictionary = {}
var sentence_records: Array = []
var tutorial_progress: Dictionary = {}
var collected_char_units: Array = []
var last_char_pick_day: int = 0
var char_canvas_positions: Dictionary = {}
var free_sentence_units: Array = []
var world_rules: Dictionary = {}
var floor3_task_complete: bool = false
var floor4_task_complete: bool = false
var last_clean_sentence: String = ""
var last_polluted_sentence: String = ""
var npc_understanding: int = 100
var reality_phase: String = "npc_speaking"
var relationship_residue: int = 0
var last_relationship_residue_gain: int = 0
var last_relationship_money_loss: int = 0
var reality_dialogue_count: int = 0
var conversation_phase: String = "idle"
var conversation_actor_id: String = ""
var conversation_actor_type: String = "npc"
var conversation_actor_label: String = ""
var conversation_prompt: String = ""
var conversation_result_line: String = ""
var conversation_choices: Array = []
var conversation_selected_choice_id: String = ""
var conversation_clean_sentence: String = ""
var conversation_revealed_units: Array = []
var conversation_reveal_index: int = 0
var conversation_attempts: int = 0
var conversation_understood: bool = false
var conversation_understanding_rolls: Array[int] = []
var conversation_feedback: String = ""
var conversation_locale: String = "zh"
var conversation_clean_units: Array[String] = []
var conversation_mode: String = "authored"
var conversation_world: String = "reality"
var conversation_selected_token_ids: Array[String] = []
var conversation_turns: Array = []
var conversation_turn_index: int = 0
var conversation_history: Array = []
var conversation_can_continue: bool = false
var conversation_completed: bool = false
var conversation_interrupted: bool = false
var conversation_interrupt_line: String = ""
var conversation_action_spent: bool = false
var conversation_reward: Dictionary = {}


func new_run() -> void:
	day = 1
	pollution = 0
	tower_floor = 1
	ending_unlocked = false
	ending_language_choice = ""
	ending_route = ""
	formal_floor_three_complete = false
	pending_floor_transition = 0
	autoplay_enabled = false
	exit_prompt_seen = false
	money = 18
	max_actions_per_day = BASE_ACTIONS_PER_DAY
	actions_remaining = max_actions_per_day
	needs_day_settlement = false
	day_ended_reason = ""
	pollution_flashback_seen = false
	pollution_flashback_pending = false
	view_state = "phone_down"
	phone_visible = true
	phone_open = true
	active_app = "social"
	active_app_window = "social"
	notebook_tokens = []
	draft_slots = {}
	completed_memes = []
	owned_meme_frames = 0
	owned_meme_frame_ids = []
	claimed_doll_ids = []
	doll_choice_results = {}
	fusion_slots = {}
	fused_meme_pairs = []
	dialogue_blanks = {}
	published_memes = []
	last_publish_result = {}
	event_log = []
	social_followed_handles = []
	social_liked_post_ids = []
	collected_world_item_ids = []
	cover_watcher_seen_floors = []
	revealed_prerequisite_item_ids = []
	collected_prerequisite_item_ids = []
	key_clue_progress = {}
	history_entries = []
	language_sentence_slots = {}
	sentence_records = []
	collected_char_units = []
	last_char_pick_day = 0
	char_canvas_positions = {}
	free_sentence_units = []
	world_rules = {}
	floor3_task_complete = false
	floor4_task_complete = false
	tutorial_progress = TutorialDirectorScript.initial_progress()
	last_clean_sentence = ""
	last_polluted_sentence = ""
	npc_understanding = 100
	reality_phase = "npc_speaking"
	relationship_residue = 0
	last_relationship_residue_gain = 0
	last_relationship_money_loss = 0
	reality_dialogue_count = 0
	reset_typed_reality_conversation()


func notify_tutorial(event_id: String, payload: Dictionary = {}) -> Dictionary:
	tutorial_progress = TutorialDirectorScript.notify(tutorial_progress, StringName(event_id), payload)
	return get_tutorial_step()


func get_tutorial_step() -> Dictionary:
	return TutorialDirectorScript.current_step(tutorial_progress)


func skip_tutorial() -> void:
	tutorial_progress = TutorialDirectorScript.skip(tutorial_progress)


func replay_tutorial() -> void:
	tutorial_progress = TutorialDirectorScript.replay(tutorial_progress)


func to_save_data() -> Dictionary:
	var state_data := {}
	for field_name in SAVE_FIELD_NAMES:
		var value: Variant = get(field_name)
		state_data[field_name] = value.duplicate(true) if value is Array or value is Dictionary else value
	return {
		"version": SAVE_DATA_VERSION,
		"state": state_data,
	}


func load_save_data(save_data: Dictionary) -> bool:
	var loaded_version := int(save_data.get("version", -1))
	if loaded_version not in [1, 2, 3, 4, SAVE_DATA_VERSION]:
		return false
	var state_data: Variant = save_data.get("state", {})
	if not state_data is Dictionary:
		return false
	var saved_floor := int((state_data as Dictionary).get("tower_floor", 1))
	new_run()
	for field_name in SAVE_FIELD_NAMES:
		if not state_data.has(field_name):
			continue
		var value: Variant = state_data[field_name]
		set(field_name, value.duplicate(true) if value is Array or value is Dictionary else value)
	day = maxi(1, day)
	tower_floor = clampi(tower_floor, 1, MAX_TOWER_FLOOR)
	max_actions_per_day = maxi(1, max_actions_per_day)
	actions_remaining = clampi(actions_remaining, 0, max_actions_per_day)
	pollution = clampi(pollution, 0, 100)
	if loaded_version < 4 and saved_floor >= 4:
		tower_floor = 3
		ending_unlocked = false
		ending_route = ""
		formal_floor_three_complete = false
		pending_floor_transition = 0
	if loaded_version < 4 and saved_floor < 4:
		_migrate_legacy_hidden_route_data(state_data as Dictionary)
	var normalized_watcher_floors: Array[int] = []
	for floor_value in cover_watcher_seen_floors:
		var floor_number := clampi(int(floor_value), 1, MAX_TOWER_FLOOR)
		if floor_number not in normalized_watcher_floors:
			normalized_watcher_floors.append(floor_number)
	cover_watcher_seen_floors = normalized_watcher_floors
	_normalize_removed_shop_state()
	_normalize_doll_state()
	_normalize_language_bridge_state(loaded_version)
	tutorial_progress = TutorialDirectorScript.normalize_progress(tutorial_progress)
	if view_state != "phone_down" and view_state != "npc_up":
		view_state = "phone_down"
	reset_typed_reality_conversation()
	# 读档防御:规则已活而任务旗标缺失的异常档,按当前楼层重扫一次锁存。
	_latch_ultimate_tasks_for_current_floor()
	return true


func _normalize_language_bridge_state(loaded_version: int) -> void:
	var normalized_tokens: Array = []
	for token_index in notebook_tokens.size():
		var token_value: Variant = notebook_tokens[token_index]
		if token_value is Dictionary:
			var token: Dictionary = (token_value as Dictionary).duplicate(true)
			if not token.get("grammar_roles", null) is Array or (token.get("grammar_roles", []) as Array).is_empty():
				token["grammar_roles"] = [str(LANGUAGE_RECIPE_SLOTS[token_index % LANGUAGE_RECIPE_SLOTS.size()].get("accepted_role", "subject"))]
			if str(token.get("lexeme_id", "")).is_empty():
				token["lexeme_id"] = str(token.get("id", "token-%d" % token_index))
			normalized_tokens.append(LanguageBridgeScript.normalized_token(token))
	notebook_tokens = normalized_tokens
	if loaded_version <= 4:
		language_sentence_slots.clear()
		reality_phase = "npc_speaking"
	var filtered_log: Array[String] = []
	for entry in event_log:
		var text := str(entry)
		if not text.contains("遗产规则"):
			filtered_log.append(text)
	event_log = filtered_log


func _migrate_legacy_hidden_route_data(state_data: Dictionary) -> void:
	var legacy_fragments: Array = state_data.get("collected_echo_fragment_ids", [])
	var legacy_fragment_ids := ["echo_room_name", "echo_safe_place", "echo_blank_voice"]
	var item_ids := get_prerequisite_item_ids()
	for index in legacy_fragment_ids.size():
		if legacy_fragment_ids[index] not in legacy_fragments:
			continue
		var item_id := str(item_ids[index])
		if item_id not in revealed_prerequisite_item_ids:
			revealed_prerequisite_item_ids.append(item_id)
		if item_id not in collected_prerequisite_item_ids:
			collected_prerequisite_item_ids.append(item_id)
		if item_id not in collected_world_item_ids:
			collected_world_item_ids.append(item_id)
	var legacy_keys: Array = state_data.get("completed_dialogue_key_ids", [])
	var legacy_key_to_floor := {
		"dialogue_key_name": 1,
		"dialogue_key_source": 2,
		"dialogue_key_voice": 3,
	}
	for legacy_key in legacy_keys:
		var floor_number := int(legacy_key_to_floor.get(str(legacy_key), 0))
		if floor_number == 0:
			continue
		var item_id := str(item_ids[floor_number - 1])
		if item_id not in revealed_prerequisite_item_ids:
			revealed_prerequisite_item_ids.append(item_id)


func _normalize_removed_shop_state() -> void:
	if active_app == "shop":
		active_app = "social"
	if active_app_window == "shop":
		active_app_window = "social" if phone_open else ""


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
	phone_visible = value
	if not value:
		active_app_window = ""


func set_view_state(value: String) -> bool:
	if value != "phone_down" and value != "npc_up":
		return false
	view_state = value
	if view_state == "phone_down":
		phone_visible = true
		phone_open = true
		if active_app_window.is_empty():
			active_app_window = active_app
	else:
		phone_visible = false
		phone_open = false
		active_app_window = ""
		reset_reality_phase_for_day()
	return true


func is_world_item_collected(item_id: String) -> bool:
	return item_id in collected_world_item_ids


func get_prerequisite_item_ids() -> Array[String]:
	var ids: Array[String] = []
	for floor_number in [1, 2, 3]:
		ids.append(str((PREREQUISITE_ITEMS[floor_number] as Dictionary).get("id", "")))
	return ids


func get_prerequisite_item_for_floor(floor_number: int) -> Dictionary:
	return (PREREQUISITE_ITEMS.get(floor_number, {}) as Dictionary).duplicate(true)


func get_key_clue_progress(floor_number: int) -> Dictionary:
	return (key_clue_progress.get(str(clampi(floor_number, 1, 3)), {}) as Dictionary).duplicate(true)


func reveal_prerequisite_item_for_floor(floor_number: int) -> bool:
	var item := get_prerequisite_item_for_floor(floor_number)
	var item_id := str(item.get("id", ""))
	if item_id.is_empty() or item_id in revealed_prerequisite_item_ids:
		return false
	revealed_prerequisite_item_ids.append(item_id)
	event_log.push_front(str(item.get("location_hint", "这一层有一件东西正等着被找到。")))
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
	event_log.push_front("你收起了这一层不该留下的东西。")
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
	for index in history_entries.size():
		if str(history_entries[index].get("lineId", "")) == line_id:
			history_entries[index] = normalized
			return true
	history_entries.append(normalized)
	return true


func get_history_entries() -> Array:
	return history_entries.duplicate(true)


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
		event_log.push_front("第四层没有登记记录。")
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
	event_log.push_front("你抵达了第 %d 层。" % tower_floor)
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


func collect_world_item(item_data: Dictionary) -> bool:
	var item_id := str(item_data.get("id", "")).strip_edges()
	return collect_prerequisite_item(item_id)


func get_ending_language_choices() -> Array:
	return ENDING_LANGUAGE_CHOICES.duplicate(true)


func choose_ending_language(choice_id: String) -> bool:
	if not ending_unlocked or not ending_language_choice.is_empty():
		return false
	for choice in ENDING_LANGUAGE_CHOICES:
		if str(choice.get("id", "")) == choice_id:
			ending_language_choice = choice_id
			return true
	return false


func get_ending_language_output() -> String:
	for choice in ENDING_LANGUAGE_CHOICES:
		if str(choice.get("id", "")) == ending_language_choice:
			return str(choice.get("output", ""))
	return ""


func set_active_app(app_id: String) -> void:
	active_app = app_id
	if view_state == "phone_down":
		active_app_window = app_id


func spend_action(action_type: String) -> bool:
	if actions_remaining <= 0:
		actions_remaining = 0
		needs_day_settlement = true
		day_ended_reason = "actions-depleted"
		return false
	actions_remaining = maxi(0, actions_remaining - 1)
	if actions_remaining == 0:
		needs_day_settlement = true
		day_ended_reason = action_type
	return true


func can_spend_action() -> bool:
	return actions_remaining > 0


func is_social_following(handle: String) -> bool:
	return handle in social_followed_handles


func toggle_social_follow(handle: String) -> bool:
	var normalized := handle.strip_edges()
	if normalized.is_empty():
		return false
	if normalized in social_followed_handles:
		social_followed_handles.erase(normalized)
		return false
	social_followed_handles.append(normalized)
	return true


func is_social_post_liked(post_id: String) -> bool:
	return post_id in social_liked_post_ids


func toggle_social_like(post_id: String) -> bool:
	var normalized := post_id.strip_edges()
	if normalized.is_empty():
		return false
	if normalized in social_liked_post_ids:
		social_liked_post_ids.erase(normalized)
		return false
	social_liked_post_ids.append(normalized)
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
	actions_remaining = 0
	needs_day_settlement = true
	day_ended_reason = "pollution-flashback"
	return true


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


func reset_reality_phase_for_day() -> void:
	reality_phase = "npc_speaking"


func start_typed_reality_conversation(actor_id: String, actor_type: String, actor_label: String) -> bool:
	if not can_spend_action():
		return false
	conversation_actor_id = actor_id
	conversation_actor_type = actor_type if actor_type in ["npc", "key_npc", "doll", "doctor"] else "npc"
	conversation_actor_label = actor_label
	conversation_mode = "lexeme" if conversation_actor_type == "doctor" else "authored"
	conversation_world = "doctor" if conversation_actor_type == "doctor" else "reality"
	conversation_selected_token_ids = []
	language_sentence_slots.clear()
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
	conversation_action_spent = false
	conversation_reward = {}
	conversation_attempts = 0
	conversation_locale = "zh"
	_load_typed_reality_turn(0)
	conversation_phase = "composing" if conversation_mode == "lexeme" else "choosing"
	if conversation_mode == "lexeme":
		reality_phase = "player_composing"
	return true


func reset_typed_reality_conversation() -> void:
	conversation_phase = "idle"
	conversation_actor_id = ""
	conversation_actor_type = "npc"
	conversation_actor_label = ""
	conversation_prompt = ""
	conversation_result_line = ""
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
	conversation_selected_token_ids = []
	conversation_turns = []
	conversation_turn_index = 0
	conversation_history = []
	conversation_can_continue = false
	conversation_completed = false
	conversation_interrupted = false
	conversation_interrupt_line = ""
	conversation_action_spent = false
	conversation_reward = {}


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
		"action_spent": conversation_action_spent,
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
	conversation_choices = (turn.get("choices", []) as Array).duplicate(true)
	if conversation_actor_type == "doll":
		for choice_index in conversation_choices.size():
			var choice: Dictionary = (conversation_choices[choice_index] as Dictionary).duplicate(true)
			choice["locked"] = _doll_choice_is_locked(choice)
			if bool(choice["locked"]) and not str(choice.get("locked_summary", "")).is_empty():
				choice["summary"] = str(choice.get("locked_summary", ""))
			conversation_choices[choice_index] = choice
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
	if not conversation_clean_sentence.is_empty():
		conversation_clean_units = _conversation_units(conversation_clean_sentence)


func _reality_dialogue_for_actor(actor_id: String, actor_type: String) -> Dictionary:
	var floor_number := clampi(tower_floor, 1, 3)
	if actor_type == "doctor":
		var doctor_dialogue: Dictionary = DOCTOR_DIALOGUES_BY_FLOOR.get(clampi(tower_floor, 1, 4), DOCTOR_DIALOGUES_BY_FLOOR[1])
		return {
			"line": str(doctor_dialogue.get("line", "用你从屏幕里带回来的词说一句完整的话。")),
			"result": str(doctor_dialogue.get("result", "医生把句子写了下来。")),
			"choices": [],
		}
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
		"action_spent": false,
		"understood": false,
		"locked_out": false,
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
	conversation_revealed_units.append({
		"clean": clean_character,
		"display": display_character,
		"corrupted": corrupted,
		"roll": roll,
	})
	conversation_reveal_index += 1
	result["advanced"] = true
	if conversation_reveal_index < conversation_clean_units.size():
		return result

	result["completed"] = true
	var is_key_npc_final_turn := conversation_actor_type == "key_npc" and conversation_turn_index + 1 >= conversation_turns.size()
	var is_claimed_doll_repeat := conversation_actor_type == "doll" and is_doll_claimed(conversation_actor_id)
	var should_spend_now := conversation_actor_type != "doll" and (conversation_actor_type != "key_npc" or is_key_npc_final_turn) and not is_claimed_doll_repeat
	if not conversation_action_spent and should_spend_now:
		if not spend_action("typed-reality-dialogue"):
			conversation_phase = "result"
			conversation_interrupted = true
			conversation_feedback = "今天已经没有能说出口的行动。"
			result["locked_out"] = true
			result["interrupted"] = true
			return result
		conversation_action_spent = true
		result["action_spent"] = true
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
	var item := get_prerequisite_item_for_floor(floor_number)
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
		"kind": "guide_tutorial",
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
	event_log.push_front("缝线布偶指向了下一步。")
	notify_tutorial("guide_found", {"doll_id": conversation_actor_id})
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
	if not completed_memes.is_empty() and posmod(roll + character_index, 3) == 0:
		var meme_index := posmod(roll + conversation_attempts + character_index, completed_memes.size())
		var meme: Dictionary = completed_memes[meme_index]
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


func settle_day_if_needed() -> bool:
	if not needs_day_settlement:
		return false
	_resolve_tower_step()
	day += 1
	actions_remaining = max_actions_per_day
	needs_day_settlement = false
	day_ended_reason = ""
	pollution_flashback_pending = false
	draft_slots.clear()
	fusion_slots.clear()
	dialogue_blanks.clear()
	language_sentence_slots.clear()
	reset_reality_phase_for_day()
	reset_typed_reality_conversation()
	return true


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
	if not spend_action("pick-token"):
		return false
	notebook_tokens.append(note)
	notify_tutorial("collect_word", {"token_id": str(note.get("id", ""))})
	return true


func get_pickup_unit_pool(locale_code: String = "zh") -> Array:
	return PickupCharPoolScript.get_unit_pool(locale_code)


func is_social_char_collected(unit: String, locale_code: String = "zh") -> bool:
	for entry in collected_char_units:
		if entry is Dictionary and str((entry as Dictionary).get("unit", "")) == unit and str((entry as Dictionary).get("locale", "zh")) == locale_code:
			return true
	return false


func get_collected_char_units(locale_code: String = "zh") -> Array[String]:
	var result: Array[String] = []
	for entry in collected_char_units:
		if entry is Dictionary and str((entry as Dictionary).get("locale", "zh")) == locale_code:
			var unit := str((entry as Dictionary).get("unit", ""))
			if not unit.is_empty() and unit not in result:
				result.append(unit)
	return result


## 拾取帖文中的单个语言单位(中文单字/日文单词/英文单词)。
## 计费规则:每天第一次拾字消耗 1 行动,相当于刷一次手机;当天后续拾字免费。
func pick_social_char(post_id: String, unit: String, locale_code: String = "zh") -> Dictionary:
	var result := {"picked": false, "reason": "", "action_spent": false}
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
	var needs_action := last_char_pick_day != day
	if needs_action:
		if not can_spend_action():
			result["reason"] = "no-actions"
			return result
		if not spend_action("pick-char"):
			result["reason"] = "no-actions"
			return result
		result["action_spent"] = true
	collected_char_units.append({
		"unit": normalized_unit,
		"locale": locale_code,
		"source_post_id": post_id,
		"day": day,
	})
	last_char_pick_day = day
	result["picked"] = true
	notify_tutorial("collect_word", {"token_id": "char-%s-%s" % [locale_code, normalized_unit]})
	return result


## ============ 自由造句(多邻国式词库,无固定主谓宾)与世界规则 ============

func get_free_sentence_units() -> Array:
	return free_sentence_units.duplicate()


func free_sentence_place(unit: String, locale_code: String = "zh") -> bool:
	var normalized_unit := unit.strip_edges()
	if normalized_unit.is_empty():
		return false
	if not is_social_char_collected(normalized_unit, locale_code):
		return false
	if normalized_unit in free_sentence_units:
		return false
	free_sentence_units.append(normalized_unit)
	return true


func free_sentence_remove(unit_index: int) -> bool:
	if unit_index < 0 or unit_index >= free_sentence_units.size():
		return false
	free_sentence_units.remove_at(unit_index)
	return true


## 拖拽支持:把词库单位放到指定位置(index 越界即追加句尾)。
func free_sentence_place_at(unit: String, insert_index: int, locale_code: String = "zh") -> bool:
	var normalized_unit := unit.strip_edges()
	if normalized_unit.is_empty() or not is_social_char_collected(normalized_unit, locale_code):
		return false
	if normalized_unit in free_sentence_units:
		return false
	free_sentence_units.insert(clampi(insert_index, 0, free_sentence_units.size()), normalized_unit)
	return true


## 拖拽支持:答案区内重排。to_index 是移除后的目标位置(越界即句尾)。
func free_sentence_move(from_index: int, to_index: int) -> bool:
	if from_index < 0 or from_index >= free_sentence_units.size():
		return false
	var moved_unit: Variant = free_sentence_units[from_index]
	free_sentence_units.remove_at(from_index)
	free_sentence_units.insert(clampi(to_index, 0, free_sentence_units.size()), moved_unit)
	return true


func free_sentence_clear() -> void:
	free_sentence_units.clear()


func get_free_sentence_text(locale_code: String = "zh") -> String:
	var separator := " " if locale_code == "en" else ""
	var pieces: Array[String] = []
	for unit in free_sentence_units:
		pieces.append(str(unit))
	return separator.join(pieces)


func is_world_rule_active(rule_key: String) -> bool:
	if not world_rules.has(rule_key):
		return false
	return not bool((world_rules[rule_key] as Dictionary).get("negated", false))


func get_world_rules() -> Array:
	var result: Array = []
	for rule_key in world_rules.keys():
		var rule: Dictionary = (world_rules[rule_key] as Dictionary).duplicate(true)
		rule["key"] = str(rule_key)
		result.append(rule)
	return result


## 投稿:随时可结束造句(≥1 个单位即可),消耗 1 行动。
## 三层响应:rule(规则生效,世界异变)/ misread(世界误读)/ noise(噪声回应)。
func submit_free_sentence(locale_code: String = "zh") -> Dictionary:
	var result := {
		"submitted": false, "reason": "", "tier": "", "rule_key": "", "negated": false,
		"sentence": "", "money_gain": 0, "pollution_gain": 0,
		"floor3_task_completed": false, "floor4_task_completed": false,
	}
	if free_sentence_units.is_empty():
		result["reason"] = "empty"
		return result
	if not can_spend_action():
		result["reason"] = "no-actions"
		return result
	var sentence := get_free_sentence_text(locale_code)
	var parsed: Dictionary = RuleEngineScript.parse(free_sentence_units, locale_code)
	if not spend_action("free-sentence-publish"):
		result["reason"] = "no-actions"
		return result
	var unit_count := free_sentence_units.size()
	var tier := str(parsed.get("tier", "noise"))
	var money_gain := 1 + int(unit_count / 2.0) + (2 if tier == "rule" else 0)
	var pollution_gain := clampi(2 + unit_count + (2 if tier == "rule" else 0), 2, 12)
	money += money_gain
	var record := {
		"id": "free-%d-%d" % [day, published_memes.size() + 1],
		"kind": "free_sentence",
		"title": "投稿「%s」" % sentence,
		"text": sentence,
		"units": free_sentence_units.duplicate(),
		"tier": tier,
		"rule_key": str(parsed.get("rule_key", "")),
		"negated": bool(parsed.get("negated", false)),
		"floor": tower_floor,
		"published_day": day,
		"money_gain": money_gain,
		"pollution_gain": pollution_gain,
		"content_locale": locale_code,
	}
	published_memes.push_front(record)
	sentence_records.append(record.duplicate(true))
	last_clean_sentence = sentence
	if tier == "rule":
		var floor3_before := floor3_task_complete
		var floor4_before := floor4_task_complete
		_apply_world_rule(parsed, sentence, locale_code)
		result["floor3_task_completed"] = floor3_task_complete and not floor3_before
		result["floor4_task_completed"] = floor4_task_complete and not floor4_before
	change_pollution(pollution_gain)
	free_sentence_units.clear()
	notify_tutorial("sentence_composed", {"sentence": sentence})
	notify_tutorial("sentence_published", {"sentence": sentence})
	result["submitted"] = true
	result["tier"] = tier
	result["rule_key"] = str(parsed.get("rule_key", ""))
	result["negated"] = bool(parsed.get("negated", false))
	result["sentence"] = sentence
	result["money_gain"] = money_gain
	result["pollution_gain"] = pollution_gain
	return result


func _apply_world_rule(parsed: Dictionary, sentence: String, locale_code: String) -> void:
	var rule_key := str(parsed.get("rule_key", ""))
	if rule_key.is_empty():
		return
	# Baba 式冲突消解:同键新规则覆盖旧规则;否定即压制既有正例。
	world_rules[rule_key] = {
		"negated": bool(parsed.get("negated", false)),
		"source_text": sentence,
		"locale": locale_code,
		"day": day,
		"floor": tower_floor,
	}
	if not bool(parsed.get("negated", false)):
		match rule_key:
			"door|can_open":
				event_log.push_front("有一句话贴上了门。")
			"exit|exists":
				event_log.push_front("有一句话在找它的出口。")
			"light|lit":
				event_log.push_front("有一盏灯听懂了。")
	_latch_ultimate_tasks_for_current_floor()


## 终极任务在规则生效、抵达楼层与读档三个时机都会重扫:
## 早于楼层写下的规则,到层后依然兑现;任务一旦达成即锁存,不被后续否定收回。
## 第四层的隐藏结局不在此立即解锁——按规格只在日结边界结算(见 _resolve_tower_step),
## 玩家先看见出口出现,下一次边界才进入结局。
func _latch_ultimate_tasks_for_current_floor() -> void:
	if tower_floor == 3 and not floor3_task_complete and is_world_rule_active("door|can_open"):
		floor3_task_complete = true
		event_log.push_front("第三层的门开了。")
	if tower_floor == 4 and not floor4_task_complete and is_world_rule_active("exit|exists"):
		floor4_task_complete = true
		event_log.push_front("出口开始存在。")


## ============ 笔记本字词画布:字被拾取后一直留在画布上,位置可自由拖动 ============

const CHAR_CANVAS_SIZE := Vector2(520.0, 300.0)
const CHAR_CANVAS_TILE := Vector2(44.0, 40.0)


func get_char_canvas_position(unit: String, locale_code: String = "zh") -> Vector2:
	var key := "%s|%s" % [locale_code, unit]
	if char_canvas_positions.has(key):
		var stored: Variant = char_canvas_positions[key]
		if stored is Vector2:
			return stored
		if stored is Array and (stored as Array).size() == 2:
			return Vector2(float(stored[0]), float(stored[1]))
	return _default_char_canvas_position(unit, locale_code)


func set_char_canvas_position(unit: String, position: Vector2, locale_code: String = "zh") -> void:
	var clamped := Vector2(
		clampf(position.x, 0.0, CHAR_CANVAS_SIZE.x - CHAR_CANVAS_TILE.x),
		clampf(position.y, 0.0, CHAR_CANVAS_SIZE.y - CHAR_CANVAS_TILE.y)
	)
	char_canvas_positions["%s|%s" % [locale_code, unit]] = [clamped.x, clamped.y]


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
	draft_slots[slot_id] = token_id
	return true


func confirm_craft() -> bool:
	var validation: Dictionary = LanguageBridgeScript.validate_recipe(draft_slots, notebook_tokens)
	if not bool(validation.get("valid", false)):
		return false
	var composition: Dictionary = LanguageBridgeScript.compose_sentence(draft_slots, notebook_tokens, "phone", conversation_locale)
	if not bool(composition.get("valid", false)):
		return false
	if not spend_action("craft-meme"):
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
		"fusion_level": 0,
		"unit_count": token_ids.size(),
		"created_day": day,
	}
	completed_memes.push_front(meme)
	draft_slots.clear()
	notify_tutorial("sentence_composed", {"meme_id": str(meme.get("id", ""))})
	return true


func place_meme_in_fusion_slot(slot_id: String, meme_id: String) -> bool:
	if slot_id != "left" and slot_id != "right":
		return false
	if _find_completed_meme_index(meme_id) < 0:
		return false
	var other_slot := "right" if slot_id == "left" else "left"
	if str(fusion_slots.get(other_slot, "")) == meme_id:
		return false
	fusion_slots[slot_id] = meme_id
	return true


func confirm_meme_fusion() -> bool:
	var left_id := str(fusion_slots.get("left", ""))
	var right_id := str(fusion_slots.get("right", ""))
	if left_id.is_empty() or right_id.is_empty() or left_id == right_id:
		return false
	var left_index := _find_completed_meme_index(left_id)
	var right_index := _find_completed_meme_index(right_id)
	if left_index < 0 or right_index < 0:
		return false
	var pair_ids: Array[String] = [left_id, right_id]
	pair_ids.sort()
	var pair_key := "%s+%s" % [pair_ids[0], pair_ids[1]]
	if pair_key in fused_meme_pairs:
		return false
	if not spend_action("fuse-memes"):
		return false
	var left: Dictionary = completed_memes[left_index]
	var right: Dictionary = completed_memes[right_index]
	var fusion_level := mini(3, maxi(int(left.get("fusion_level", 0)), int(right.get("fusion_level", 0))) + 1)
	var tags: Array = _unique((left.get("tags", []) as Array) + (right.get("tags", []) as Array))
	var left_text := str(left.get("text", ""))
	var right_text := str(right.get("text", ""))
	var fused_text := "%s%s" % [left_text, right_text]
	var meme := {
		"id": "fusion-%d-%d" % [day, completed_memes.size() + 1],
		"title": "复合「%s」" % fused_text,
		"text": fused_text,
		"tags": tags,
		"rarity": clampi(maxi(int(left.get("rarity", 1)), int(right.get("rarity", 1))) + 1, 1, 5),
		"pollution_bias": int(left.get("pollution_bias", 0)) + int(right.get("pollution_bias", 0)) + 6 + fusion_level * 2,
		"fusion_level": fusion_level,
		"unit_count": maxi(2, int(left.get("unit_count", 1)) + int(right.get("unit_count", 1))),
		"fused_from": pair_ids,
		"created_day": day,
	}
	completed_memes.push_front(meme)
	fused_meme_pairs.append(pair_key)
	fusion_slots.clear()
	change_pollution(3 + fusion_level * 2)
	event_log.push_front("两个旧梗粘在一起。新梗更响，也更脏。")
	return true


func place_meme_in_blank(blank_id: String, meme_id: String) -> bool:
	dialogue_blanks[blank_id] = meme_id
	return true


func confirm_dialogue() -> bool:
	var meme := _get_first_placed_meme()
	if meme.is_empty():
		return false
	var publish_result := get_publish_result(meme)
	if not spend_action("confirm-dialogue"):
		return false
	last_publish_result = publish_result.duplicate(true)
	money += int(publish_result.get("money_gain", 0))
	change_pollution(int(publish_result.get("pollution_gain", 0)))
	var record: Dictionary = meme.duplicate(true)
	record["floor"] = tower_floor
	record["money_gain"] = int(publish_result.get("money_gain", 0))
	record["pollution_gain"] = int(publish_result.get("pollution_gain", 0))
	record["published_day"] = day
	published_memes.push_front(record)
	var published_token_ids: Array = record.get("token_ids", [])
	if not published_token_ids.is_empty():
		notebook_tokens = LanguageBridgeScript.mark_tokens_used(notebook_tokens, published_token_ids, "phone")
	dialogue_blanks.clear()
	event_log.push_front("发布完成：资金 +%d，污染 +%d%%。" % [
		int(publish_result.get("money_gain", 0)),
		int(publish_result.get("pollution_gain", 0)),
	])
	notify_tutorial("sentence_published", {"meme_id": str(record.get("id", ""))})
	return true


func get_language_token_options(world: String = "doctor") -> Array:
	var result: Array = []
	for token_value in notebook_tokens:
		if not token_value is Dictionary:
			continue
		var token: Dictionary = token_value
		var used_worlds: Array = token.get("used_worlds", [])
		if world == "doctor" and "phone" not in used_worlds:
			continue
		var option := token.duplicate(true)
		option["display_text"] = LanguageBridgeScript.token_surface(token, world)
		result.append(option)
	return result


func place_language_token(slot_id: String, token_id: String, world: String = "doctor") -> bool:
	var token := _find_token(token_id)
	if token.is_empty():
		return false
	var is_available := false
	for option: Dictionary in get_language_token_options(world):
		if str(option.get("id", "")) == token_id:
			is_available = true
			break
	if not is_available:
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
	language_sentence_slots[slot_id] = token_id
	conversation_selected_token_ids = []
	for recipe_slot: Dictionary in LANGUAGE_RECIPE_SLOTS:
		var selected_id := str(language_sentence_slots.get(str(recipe_slot.get("id", "")), ""))
		if not selected_id.is_empty():
			conversation_selected_token_ids.append(selected_id)
	return true


func clear_language_sentence() -> void:
	language_sentence_slots.clear()
	conversation_selected_token_ids.clear()


func get_language_sentence_preview(world: String = "doctor") -> Dictionary:
	return LanguageBridgeScript.compose_sentence(language_sentence_slots, notebook_tokens, world, conversation_locale)


func confirm_doctor_sentence() -> bool:
	if conversation_mode != "lexeme" or conversation_phase != "composing":
		return false
	var composition := get_language_sentence_preview("doctor")
	if not bool(composition.get("valid", false)):
		return false
	if not spend_action("doctor-dialogue"):
		return false

	var token_ids: Array = composition.get("token_ids", [])
	var doctor_sentence := str(composition.get("world_sentence", ""))
	last_clean_sentence = str(composition.get("clean_sentence", doctor_sentence))
	last_polluted_sentence = pollute_reality_sentence(doctor_sentence, pollution)
	notebook_tokens = LanguageBridgeScript.mark_tokens_used(notebook_tokens, token_ids, "doctor")
	var shifted_token_count := _token_count_with_world_shift(token_ids, "doctor")
	var distortion_penalty := 10 if last_polluted_sentence != doctor_sentence else 0
	npc_understanding = clampi(100 - int(round(float(pollution) * 0.45)) - shifted_token_count * 7 - distortion_penalty, 0, 100)
	reality_dialogue_count += 1
	last_relationship_residue_gain = maxi(0, int(ceil(float(maxi(0, 80 - npc_understanding)) / 12.0)))
	relationship_residue = clampi(relationship_residue + last_relationship_residue_gain, 0, 100)
	last_relationship_money_loss = 0
	change_pollution(clampi(2 + shifted_token_count, 2, 8))
	conversation_clean_sentence = last_clean_sentence
	conversation_revealed_units = []
	for index in last_polluted_sentence.length():
		var clean_unit := last_clean_sentence.substr(index, 1) if index < last_clean_sentence.length() else ""
		var display_unit := last_polluted_sentence.substr(index, 1)
		conversation_revealed_units.append({"clean": clean_unit, "display": display_unit, "corrupted": clean_unit != display_unit, "roll": -1})
	conversation_reveal_index = conversation_revealed_units.size()
	conversation_clean_units = _conversation_units(last_clean_sentence)
	conversation_understood = npc_understanding >= 45
	conversation_action_spent = true
	conversation_completed = true
	conversation_feedback = conversation_result_line
	conversation_phase = "result"
	reality_phase = "reality_result"
	var record := {
		"id": "sentence-%d-%d" % [day, sentence_records.size() + 1],
		"world": "doctor",
		"floor": tower_floor,
		"day": day,
		"token_ids": token_ids.duplicate(),
		"lexeme_ids": (composition.get("lexeme_ids", []) as Array).duplicate(),
		"clean_sentence": last_clean_sentence,
		"world_sentence": doctor_sentence,
		"spoken_sentence": last_polluted_sentence,
		"pollution": pollution,
		"understanding": npc_understanding,
	}
	sentence_records.append(record)
	conversation_history.append(record.duplicate(true))
	clear_language_sentence()
	notify_tutorial("doctor_spoken", {"sentence_id": str(record.get("id", ""))})
	return true


func confirm_reality_dialogue() -> bool:
	return confirm_doctor_sentence()


func get_relationship_state_label() -> String:
	if relationship_residue < 20:
		return "仍能认出你"
	if relationship_residue < 45:
		return "句子留下裂痕"
	if relationship_residue < 70:
		return "只剩熟悉的语气"
	return "彼此已无法确认"


func pollute_reality_sentence(sentence: String, pollution_value: int, _unused_rules: Array = []) -> String:
	return PollutionStageScript.corrupt_sentence_reality(sentence, pollution_value, day)


func _get_first_placed_meme() -> Dictionary:
	for meme_id in dialogue_blanks.values():
		for meme in completed_memes:
			if str(meme.get("id", "")) == str(meme_id):
				return meme
	return {}


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


func _token_count_with_world_shift(token_ids: Array, world: String) -> int:
	var shifted := 0
	for token_id_value in token_ids:
		var token := _find_token(str(token_id_value))
		if not token.is_empty() and LanguageBridgeScript.token_surface(token, world) != str(token.get("text", "")):
			shifted += 1
	return shifted


func get_gameplay_metrics() -> Dictionary:
	return {"money": money, "pollution": pollution}


func get_publish_result(meme: Dictionary) -> Dictionary:
	if meme.is_empty():
		return {}
	var rarity := clampi(int(meme.get("rarity", 1)), 1, 5)
	var fusion_level := clampi(int(meme.get("fusion_level", 0)), 0, 3)
	var pollution_bias := maxi(0, int(meme.get("pollution_bias", 0)))
	return {
		"money_gain": 2 + rarity * 2 + fusion_level,
		"pollution_gain": clampi(2 + rarity + fusion_level * 2 + pollution_bias, 1, 30),
	}


func _resolve_tower_step() -> void:
	resolve_floor_transition_at_boundary()
	if tower_floor == 3 and pollution >= int(POLLUTION_FLOOR_THRESHOLDS[3]) and not formal_floor_three_complete:
		complete_floor_three()
	# 第四层终极任务完成后,隐藏结局只在日结边界解锁,不打断出口出现的当下。
	if tower_floor == 4 and ending_route == "hidden" and floor4_task_complete and not ending_unlocked:
		ending_unlocked = true
		event_log.push_front("出口承认了你。")


func _find_completed_meme_index(meme_id: String) -> int:
	for index in completed_memes.size():
		if str(completed_memes[index].get("id", "")) == meme_id:
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
