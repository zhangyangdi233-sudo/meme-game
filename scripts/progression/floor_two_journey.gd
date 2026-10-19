class_name FloorTwoJourney
extends RefCounted

const TURN_IDS := ["turn_1", "turn_2"]
const XRAY_OBSERVATION_IDS := ["xray_intro", "hidden_path", "exit"]
const WAYFINDER := "floor2_wayfinder"
const CARTOGRAPHER := "floor2_cartographer"


static func normalize(raw: Variant = {}) -> Dictionary:
	var result := {"accepted": false, "visited_turn_ids": [], "map_unlocked": false, "xray_observed_ids": [], "exit_reached": false}
	if not raw is Dictionary or not _is_true(raw.get("accepted", false)):
		return result
	result.accepted = true
	var visited: Variant = raw.get("visited_turn_ids", [])
	if visited is Array or visited is PackedStringArray:
		# Retain the optional walking history without inventing or reordering it.
		for index in mini(visited.size(), TURN_IDS.size()):
			if visited[index] != TURN_IDS[index]:
				break
			result.visited_turn_ids.append(TURN_IDS[index])
	# Acceptance is written only when the first NPC dialogue completes. It now
	# grants the map directly, including old saves still waiting at the turns.
	# A map flag by itself cannot reach this branch without accepted == true.
	result.map_unlocked = true
	var observed: Variant = raw.get("xray_observed_ids", [])
	if result.map_unlocked and (observed is Array or observed is PackedStringArray):
		for index in mini(observed.size(), XRAY_OBSERVATION_IDS.size()):
			if observed[index] != XRAY_OBSERVATION_IDS[index]:
				break
			result.xray_observed_ids.append(XRAY_OBSERVATION_IDS[index])
	result.exit_reached = result.xray_observed_ids.size() == XRAY_OBSERVATION_IDS.size() and _is_true(raw.get("exit_reached", false))
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
	if result.accepted and next_index < TURN_IDS.size() and checkpoint_id == TURN_IDS[next_index]:
		result.visited_turn_ids.append(checkpoint_id)
	return result


static func finish_dialogue(progress: Dictionary, actor_id: String) -> Dictionary:
	var result := normalize(progress)
	if actor_id == WAYFINDER:
		result.accepted = true
		result.map_unlocked = true
	return result


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
