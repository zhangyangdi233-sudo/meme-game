class_name BasementLoopDirector
extends RefCounted

const OPENING_SEQUENCE_ID := "chapter1_opening"
const TASK_IDS := ["basement_help_01", "basement_help_02", "basement_help_03", "basement_help_04", "basement_help_05"]
const NPC_IDS := ["basement_npc_01", "basement_npc_02", "basement_npc_03", "basement_npc_04", "basement_npc_05"]
const REQUIRED_GATE_ITEM_IDS := ["chapter1_gate_item_01", "chapter1_gate_item_02", "chapter1_gate_item_03"]
const REQUIRED_APP_IDS := ["social", "notebook"]
const DEFAULT_TASK_APP_UNLOCKS := {
	"basement_help_01": ["social"],
	"basement_help_03": ["notebook"],
}
# Temporary integration configuration, not an authored story/reward decision.
# A caller may replace reward_config before starting the chapter. Saves retain it.
const DEVELOPMENT_REWARD_CONFIG := {
	"development_only": true,
	"task_app_unlocks": DEFAULT_TASK_APP_UNLOCKS,
	# Read compatibility only: new help events no longer grant gate items.
	"task_rewards": {},
}


static func initial_progress(randomize_decoration: bool = true) -> Dictionary:
	return {
		"phase": "opening",
		"round_index": 0,
		"narrator_completed": false,
		"opening_knock_completed": false,
		"entrance_locked": false,
		"exit_tunnel_entered": false,
		"completed_task_ids": [],
		"gate_item_ids": [],
		"unlocked_app_ids": [],
		"transition_serial": 0,
		"decoration_seed": randi_range(1, 2147483646) if randomize_decoration else 1701,
		"reward_config": DEVELOPMENT_REWARD_CONFIG.duplicate(true),
	}


static func normalize_progress(raw: Dictionary) -> Dictionary:
	var progress := initial_progress(false)
	progress.decoration_seed = clampi(_integer_or(raw.get("decoration_seed", 1701), 1701), 1, 2147483646)
	var raw_config: Variant = raw.get("reward_config", {})
	var legacy_app_schema: bool = not raw.has("unlocked_app_ids") and not (raw_config is Dictionary and raw_config.has("task_app_unlocks"))
	progress.reward_config = _normalize_reward_config(raw.get("reward_config", DEVELOPMENT_REWARD_CONFIG), legacy_app_schema)
	progress.narrator_completed = _is_true(raw.get("narrator_completed", false))
	var phase_value: Variant = raw.get("phase", "opening")
	var phase: String = phase_value if phase_value is String else "opening"
	if phase not in ["opening", "basement", "crossroads", "tower"]:
		phase = "opening"
	progress.opening_knock_completed = _is_true(raw.get("opening_knock_completed", false))
	# Older saves already beyond the opening keep their reached stage. An old
	# opening save still hears the knock; an explicit new flag always wins.
	if not raw.has("opening_knock_completed") and phase != "opening" and progress.narrator_completed:
		progress.opening_knock_completed = true
	# An asserted later phase never supplies a missing knock, task or reward.
	if not progress.opening_knock_completed or phase == "opening":
		return progress

	var round_index := clampi(_integer_or(raw.get("round_index", 0), 0), 0, 4)
	var locked := _is_true(raw.get("entrance_locked", false))
	var claimed_tasks := _known_ids(raw.get("completed_task_ids", []), TASK_IDS)
	var completed: Array = []
	# Retain only the contiguous, actually recorded prefix through this visit.
	for index in range(round_index + 1):
		if TASK_IDS[index] not in claimed_tasks or (index == round_index and not locked):
			break
		completed.append(TASK_IDS[index])
	round_index = mini(round_index, completed.size())
	progress.round_index = round_index
	progress.entrance_locked = locked
	progress.completed_task_ids = completed
	progress.phase = "basement"
	progress.transition_serial = round_index + 1
	# Entering the continuous exit tunnel does not create a new visit. Missing
	# fields in older saves remain false; only a completed current visit may
	# retain this checkpoint. Other reached phases never inherit it.
	# Retired tunnel saves resume on the safe basement platform.
	progress.exit_tunnel_entered = false

	var claimed_items := _known_ids(raw.get("gate_item_ids", []), REQUIRED_GATE_ITEM_IDS)
	var earned_items: Array = []
	var rewards: Dictionary = progress.reward_config.task_rewards
	for item_id in REQUIRED_GATE_ITEM_IDS:
		if item_id not in claimed_items:
			continue
		for task_id in completed:
			if item_id in rewards.get(task_id, []):
				earned_items.append(item_id)
				break
	progress.gate_item_ids = earned_items
	# Only old item-format saves migrate entitlements from validated task history.
	# New saves must contain both a recorded unlock and its completed task; raw
	# app IDs or old gate items never serve as proof of earned permission.
	var claimed_apps := _known_ids(raw.get("unlocked_app_ids", []), REQUIRED_APP_IDS)
	var earned_apps: Array = []
	var app_rewards: Dictionary = progress.reward_config.task_app_unlocks
	for app_id in REQUIRED_APP_IDS:
		if not legacy_app_schema and app_id not in claimed_apps:
			continue
		for task_id in completed:
			if app_id in app_rewards.get(task_id, []):
				earned_apps.append(app_id)
				break
	progress.unlocked_app_ids = earned_apps
	if phase in ["crossroads", "tower"] and completed.size() == TASK_IDS.size() and locked:
		progress.phase = "crossroads"
		progress.transition_serial = 6
		if phase == "tower" and _has_all(earned_apps, REQUIRED_APP_IDS):
			progress.phase = "tower"
			progress.transition_serial = 7
	return progress


static func dispatch(progress: Dictionary, event_id: String, payload: Dictionary = {}) -> Dictionary:
	var next := normalize_progress(progress)
	var transition := ""
	match event_id:
		"narration_completed":
			if next.phase == "opening" and not next.narrator_completed and payload.get("sequence_id") == OPENING_SEQUENCE_ID:
				next.narrator_completed = true
				transition = "narration_completed"
		"opening_knock_completed":
			if next.phase == "opening" and not next.opening_knock_completed and payload.get("sequence_id") == OPENING_SEQUENCE_ID:
				next.opening_knock_completed = true
				transition = "opening_knock_completed"
		"opening_door_opened":
			if next.phase == "opening" and next.opening_knock_completed:
				next.phase = "basement"
				next.transition_serial += 1
				transition = "enter_basement"
		"entrance_threshold_crossed":
			if next.phase == "basement" and not next.entrance_locked and _matches_round_token(next, payload):
				next.entrance_locked = true
				transition = "entrance_locked"
		"npc_help_completed":
			if next.phase == "basement" and next.entrance_locked and _matches_round_token(next, payload):
				var current := get_current_round(next)
				if payload.get("task_id") == current.task_id and payload.get("npc_id") == current.npc_id and current.task_id not in next.completed_task_ids:
					next.completed_task_ids.append(current.task_id)
					for app_id in current.reward_app_ids:
						if app_id not in next.unlocked_app_ids:
							next.unlocked_app_ids.append(app_id)
					transition = "help_completed"
		"basement_tunnel_entered":
			if next.phase == "basement" and next.entrance_locked and not next.exit_tunnel_entered and _matches_round_token(next, payload) and TASK_IDS[next.round_index] in next.completed_task_ids:
				next.exit_tunnel_entered = true
				transition = "basement_tunnel_entered"
		"basement_exit_requested":
			if next.phase == "basement" and next.entrance_locked and _matches_round_token(next, payload) and TASK_IDS[next.round_index] in next.completed_task_ids:
				next.exit_tunnel_entered = false
				next.transition_serial += 1
				if next.round_index < 4:
					next.round_index += 1
					next.entrance_locked = false
					transition = "basement_loop"
				else:
					next.phase = "crossroads"
					transition = "enter_crossroads"
		"crossroads_gate_requested":
			if next.phase == "crossroads" and _has_all(next.completed_task_ids, TASK_IDS) and _has_all(next.unlocked_app_ids, REQUIRED_APP_IDS):
				next.phase = "tower"
				next.transition_serial += 1
				transition = "enter_tower"
	return {"accepted": not transition.is_empty(), "progress": normalize_progress(next), "transition": transition}


static func get_current_round(progress: Dictionary) -> Dictionary:
	var normalized := normalize_progress(progress)
	if normalized.phase != "basement":
		return {}
	var index: int = normalized.round_index
	return {
		"npc_id": NPC_IDS[index],
		"task_id": TASK_IDS[index],
		"reward_app_ids": normalized.reward_config.task_app_unlocks.get(TASK_IDS[index], []).duplicate(),
		"reward_item_ids": [],
	}


static func _normalize_reward_config(raw: Variant, legacy_app_schema: bool = false) -> Dictionary:
	var normalized := {"development_only": true, "task_rewards": {}, "task_app_unlocks": {}}
	if not raw is Dictionary:
		return normalized
	normalized.development_only = _is_true(raw.get("development_only", true))
	var mapping: Variant = raw.get("task_rewards", {})
	if mapping is Dictionary:
		for task_id in TASK_IDS:
			var rewards := _known_ids(mapping.get(task_id, []), REQUIRED_GATE_ITEM_IDS)
			if not rewards.is_empty():
				normalized.task_rewards[task_id] = rewards
	var app_mapping: Variant = raw.get("task_app_unlocks", DEFAULT_TASK_APP_UNLOCKS if legacy_app_schema else {})
	if app_mapping is Dictionary:
		for task_id in TASK_IDS:
			var apps := _known_ids(app_mapping.get(task_id, []), REQUIRED_APP_IDS)
			if not apps.is_empty():
				normalized.task_app_unlocks[task_id] = apps
	return normalized


static func _known_ids(raw: Variant, known_ids: Array) -> Array:
	var result: Array = []
	if not raw is Array:
		return result
	for known_id in known_ids:
		if known_id in raw:
			result.append(known_id)
	return result


static func _matches_round_token(progress: Dictionary, payload: Dictionary) -> bool:
	return _integer_or(payload.get("round_token"), -1) == progress.transition_serial


static func _integer_or(raw: Variant, fallback: int) -> int:
	if raw is int:
		return raw
	# JSON numbers load as floats. Accept integers only, without coercing strings.
	if raw is float and is_finite(raw) and raw == floor(raw) and raw >= 0.0 and raw <= 2147483647.0:
		return int(raw)
	return fallback


static func _is_true(raw: Variant) -> bool:
	return raw is bool and raw


static func _has_all(values: Array, required_ids: Array) -> bool:
	for required_id in required_ids:
		if required_id not in values:
			return false
	return true
