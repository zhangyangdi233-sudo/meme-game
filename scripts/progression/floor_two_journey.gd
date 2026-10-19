class_name FloorTwoJourney
extends RefCounted

const TURN_IDS := ["turn_1", "turn_2"]
const XRAY_OBSERVATION_IDS := ["xray_intro", "hidden_path", "exit"]
const WAYFINDER := "floor2_wayfinder"
const CARTOGRAPHER := "floor2_cartographer"
const PROGRESS_VERSION := 2


static func normalize(raw: Variant = {}) -> Dictionary:
	var result := {"version": PROGRESS_VERSION, "accepted": false, "visited_turn_ids": [], "map_unlocked": false, "map_intro_completed": false, "note_read": false, "xray_observed_ids": [], "exit_reached": false}
	if not raw is Dictionary:
		return result
	result.accepted = _is_true(raw.get("accepted", false))
	result.note_read = _is_true(raw.get("note_read", false))
	# Before v2, completing the first NPC was the sole valid map grant. Preserve
	# that reward, but never infer it from a bare map flag or a malformed version.
	var legacy_reward: bool = not raw.has("version") and result.accepted
	var raw_version: Variant = raw.get("version", 0)
	var current_reward: bool = (raw_version is int or raw_version is float) and raw_version == PROGRESS_VERSION and _is_true(raw.get("map_intro_completed", false))
	result.map_intro_completed = legacy_reward or current_reward
	result.map_unlocked = result.map_intro_completed
	var visited: Variant = raw.get("visited_turn_ids", [])
	if result.map_unlocked and (visited is Array or visited is PackedStringArray):
		# Retain the optional walking history without inventing or reordering it.
		for index in mini(visited.size(), TURN_IDS.size()):
			if visited[index] != TURN_IDS[index]:
				break
			result.visited_turn_ids.append(TURN_IDS[index])
	var observed: Variant = raw.get("xray_observed_ids", [])
	if result.map_unlocked and (observed is Array or observed is PackedStringArray):
		for index in mini(observed.size(), XRAY_OBSERVATION_IDS.size()):
			if observed[index] != XRAY_OBSERVATION_IDS[index]:
				break
			result.xray_observed_ids.append(XRAY_OBSERVATION_IDS[index])
	result.exit_reached = result.xray_observed_ids.size() == XRAY_OBSERVATION_IDS.size() and _is_true(raw.get("exit_reached", false))
	return result


static func needs_map_intro(progress: Dictionary) -> bool:
	return not normalize(progress).map_intro_completed


static func complete_map_intro(progress: Dictionary) -> Dictionary:
	var result := normalize(progress)
	result.map_intro_completed = true
	result.map_unlocked = true
	return result


static func mark_note_read(progress: Dictionary) -> Dictionary:
	var result := normalize(progress)
	result.note_read = true
	return result


static func record_xray_observation(progress: Dictionary, observation_id: String) -> Dictionary:
	# The caller verifies the real tracked frame, distance, projection and occlusion.
	# This pure transition only validates the ordered lesson and persists discovery.
	var result := normalize(progress)
	var next_index: int = result.xray_observed_ids.size()
	if result.map_unlocked and next_index < XRAY_OBSERVATION_IDS.size() and observation_id == XRAY_OBSERVATION_IDS[next_index]:
		result.xray_observed_ids.append(observation_id)
	return result


static func can_exit(progress: Dictionary) -> bool:
	return normalize(progress).xray_observed_ids.size() == XRAY_OBSERVATION_IDS.size()


static func visit_turn(progress: Dictionary, checkpoint_id: String) -> Dictionary:
	var result := normalize(progress)
	var next_index: int = result.visited_turn_ids.size()
	if result.map_unlocked and next_index < TURN_IDS.size() and checkpoint_id == TURN_IDS[next_index]:
		result.visited_turn_ids.append(checkpoint_id)
	return result


static func finish_dialogue(progress: Dictionary, _actor_id: String) -> Dictionary:
	# Retained for older callers. The second-floor NPCs no longer grant tasks or
	# map access; only the completed phone introduction may unlock the app.
	return normalize(progress)


static func dialogue_for(actor_id: String, progress: Dictionary) -> Dictionary:
	var state := normalize(progress)
	if actor_id == WAYFINDER:
		if not state.accepted:
			return _dialogue("receive_map", "这里的路会绕回来。地图会记住你走过的地方。", "我带着地图往前走。", "地图已解锁。按 Tab 打开手机。")
		return _dialogue("remember_map", "地图在手机里。沿着街道继续走。", "我继续沿着街道走。", "用双手围成框，看看墙后的路。")
	if actor_id == CARTOGRAPHER:
		if state.map_unlocked:
			return _dialogue("continue_route", "把双手围成框，看看墙后。", "我继续往前走。", "看过的出口会被记住。")
		return _dialogue("ask_wayfinder", "先去和入口处的引路人说说话。", "我先问清楚这条路。", "我在这里等你回来。")
	return {}


static func _dialogue(id: String, line: String, sentence: String, result: String) -> Dictionary:
	return {"line": line, "result": result, "choices": [{"id": id, "sentence": sentence}]}


static func _is_true(value: Variant) -> bool:
	return value is bool and value
