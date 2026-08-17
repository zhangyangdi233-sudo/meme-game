class_name TutorialDirector
extends RefCounted


const SCHEMA_VERSION := 1
const TUTORIAL_ID := "stitched_guide_onboarding"

const STEPS: Array[Dictionary] = [
	{
		"id": "find_guide",
		"event_id": "guide_found",
		"required_count": 1,
		"focus_target": "guide_doll",
		"guide_line": "先找到我。别急着相信我。",
		"test_instruction": "测试提示：转动镜头并靠近缝线布偶。",
	},
	{
		"id": "open_social",
		"event_id": "social_opened",
		"required_count": 1,
		"focus_target": "social_app",
		"guide_line": "拿起手机，打开社交媒体。那里有人替你准备了词。",
		"test_instruction": "测试提示：拿起手机并打开社交媒体 App。",
	},
	{
		"id": "open_post",
		"event_id": "post_opened",
		"required_count": 1,
		"focus_target": "social_post",
		"guide_line": "打开一篇帖子。先读，再拿走。",
		"test_instruction": "测试提示：点击任意瀑布流卡片进入帖子详情。",
	},
	{
		"id": "collect_words",
		"event_id": "collect_word",
		"required_count": 3,
		"focus_target": "post_word_tokens",
		"guide_line": "拾取三个词。三个才够拼成一句不会立刻散掉的话。",
		"test_instruction": "测试提示：在帖子详情中累计拾取 3 个词。",
	},
	{
		"id": "open_notebook",
		"event_id": "notebook_opened",
		"required_count": 1,
		"focus_target": "notebook_app",
		"guide_line": "打开笔记本。你拿走的词都在里面。",
		"test_instruction": "测试提示：打开笔记本 App。",
	},
	{
		"id": "compose_sentence",
		"event_id": "sentence_composed",
		"required_count": 1,
		"focus_target": "sentence_slots",
		"guide_line": "把拾到的字点进句子。让它先成为一句话。",
		"test_instruction": "测试提示：用拾取的词填满句槽并完成组句。",
	},
	{
		"id": "publish_sentence",
		"event_id": "sentence_published",
		"required_count": 1,
		"focus_target": "publish_button",
		"guide_line": "把这句话投稿出去。被看见的字会记住你。",
		"test_instruction": "测试提示：确认发布刚刚组成的完整句子。",
	},
	{
		"id": "speak_to_doctor",
		"event_id": "doctor_spoken",
		"required_count": 1,
		"focus_target": "doctor",
		"guide_line": "放下手机，去和医生说同一句话。听听它到了那里还剩什么。",
		"test_instruction": "测试提示：放下手机，靠近医生并完成一次对话。",
	},
	{
		"id": "complete",
		"event_id": "",
		"required_count": 0,
		"focus_target": "",
		"guide_line": "你已经会自己走了。至少现在是。",
		"test_instruction": "教程完成：继续正常游戏。",
	},
]


static func initial_progress() -> Dictionary:
	return {
		"version": SCHEMA_VERSION,
		"tutorial_id": TUTORIAL_ID,
		"current_step_id": str(STEPS[0].get("id", "find_guide")),
		"completed_step_ids": [],
		"event_counts": {},
		"skipped": false,
		"is_complete": false,
		"replay_count": 0,
	}


static func normalize_progress(progress: Dictionary) -> Dictionary:
	var normalized := initial_progress()
	var source := progress.duplicate(true)

	normalized["event_counts"] = _normalize_event_counts(
		source.get("event_counts", source.get("counts", {}))
	)
	normalized["replay_count"] = maxi(
		0,
		int(source.get("replay_count", source.get("replays", 0)))
	)

	var skipped := bool(source.get("skipped", source.get("is_skipped", false)))
	var marked_complete := bool(source.get("is_complete", source.get("finished", false)))
	var raw_completed: Variant = source.get(
		"completed_step_ids",
		source.get("completed_steps", [])
	)
	var completed_prefix := _completed_prefix(raw_completed)
	var requested_step_id := _legacy_current_step_id(source)

	if skipped:
		normalized["completed_step_ids"] = completed_prefix
		normalized["current_step_id"] = "complete"
		normalized["skipped"] = true
		normalized["is_complete"] = true
		return normalized

	if marked_complete or requested_step_id == "complete":
		normalized["completed_step_ids"] = _all_action_step_ids()
		normalized["current_step_id"] = "complete"
		normalized["is_complete"] = true
		return normalized

	var requested_index := _step_index(requested_step_id)
	if requested_index >= 0:
		normalized["completed_step_ids"] = _step_ids_before(requested_index)
		normalized["current_step_id"] = requested_step_id
	else:
		var next_index := mini(completed_prefix.size(), STEPS.size() - 1)
		normalized["completed_step_ids"] = _step_ids_before(next_index)
		normalized["current_step_id"] = str(STEPS[next_index].get("id", "complete"))

	normalized["is_complete"] = str(normalized.get("current_step_id", "")) == "complete"
	return normalized


static func notify(progress: Dictionary, event_id: StringName, payload: Dictionary = {}) -> Dictionary:
	var next_progress := normalize_progress(progress)
	if bool(next_progress.get("is_complete", false)):
		return next_progress

	var step := current_step(next_progress)
	var expected_event := str(step.get("event_id", ""))
	var received_event := str(event_id)
	if expected_event.is_empty() or received_event != expected_event:
		return next_progress

	var amount := clampi(int(payload.get("amount", 1)), 0, 1000)
	if amount == 0:
		return next_progress
	var event_counts: Dictionary = (next_progress.get("event_counts", {}) as Dictionary).duplicate(true)
	event_counts[received_event] = int(event_counts.get(received_event, 0)) + amount
	next_progress["event_counts"] = event_counts

	if int(event_counts.get(received_event, 0)) < int(step.get("required_count", 1)):
		return next_progress

	var completed: Array = (next_progress.get("completed_step_ids", []) as Array).duplicate()
	var completed_step_id := str(step.get("id", ""))
	if not completed_step_id.is_empty() and completed_step_id not in completed:
		completed.append(completed_step_id)
	next_progress["completed_step_ids"] = completed

	var next_index := mini(_step_index(completed_step_id) + 1, STEPS.size() - 1)
	var next_step_id := str(STEPS[next_index].get("id", "complete"))
	next_progress["current_step_id"] = next_step_id
	next_progress["is_complete"] = next_step_id == "complete"
	return next_progress


static func current_step(progress: Dictionary) -> Dictionary:
	var normalized := normalize_progress(progress)
	var step_index := _step_index(str(normalized.get("current_step_id", "find_guide")))
	if step_index < 0:
		step_index = 0
	var step: Dictionary = STEPS[step_index].duplicate(true)
	var event_id := str(step.get("event_id", ""))
	var event_counts: Dictionary = normalized.get("event_counts", {}) as Dictionary
	var event_count := int(event_counts.get(event_id, 0)) if not event_id.is_empty() else 0
	var required_count := int(step.get("required_count", 0))
	step["event_count"] = event_count
	step["remaining_count"] = maxi(0, required_count - event_count)
	step["is_complete"] = str(step.get("id", "")) == "complete"
	return step


static func skip(progress: Dictionary) -> Dictionary:
	var next_progress := normalize_progress(progress)
	if bool(next_progress.get("is_complete", false)):
		return next_progress
	next_progress["current_step_id"] = "complete"
	next_progress["skipped"] = true
	next_progress["is_complete"] = true
	return next_progress


static func replay(progress: Dictionary) -> Dictionary:
	var previous := normalize_progress(progress)
	var restarted := initial_progress()
	restarted["replay_count"] = int(previous.get("replay_count", 0)) + 1
	return restarted


static func _normalize_event_counts(value: Variant) -> Dictionary:
	var normalized_counts := {}
	if not value is Dictionary:
		return normalized_counts
	for raw_event_id in (value as Dictionary).keys():
		var event_id := str(raw_event_id).strip_edges()
		if event_id.is_empty():
			continue
		normalized_counts[event_id] = maxi(0, int((value as Dictionary).get(raw_event_id, 0)))
	return normalized_counts


static func _completed_prefix(value: Variant) -> Array[String]:
	var supplied_ids: Array[String] = []
	if value is Array or value is PackedStringArray:
		for raw_id in value:
			var step_id := str(raw_id)
			if step_id not in supplied_ids:
				supplied_ids.append(step_id)
	var prefix: Array[String] = []
	for index in STEPS.size() - 1:
		var step_id := str(STEPS[index].get("id", ""))
		if step_id not in supplied_ids:
			break
		prefix.append(step_id)
	return prefix


static func _legacy_current_step_id(source: Dictionary) -> String:
	var raw_step: Variant = source.get(
		"current_step_id",
		source.get("current_step", source.get("step", ""))
	)
	var step_id := str(raw_step)
	if _step_index(step_id) >= 0:
		return step_id
	if source.has("step_index"):
		var step_index := clampi(int(source.get("step_index", 0)), 0, STEPS.size() - 1)
		return str(STEPS[step_index].get("id", "find_guide"))
	return ""


static func _step_index(step_id: String) -> int:
	for index in STEPS.size():
		if str(STEPS[index].get("id", "")) == step_id:
			return index
	return -1


static func _step_ids_before(end_index: int) -> Array[String]:
	var result: Array[String] = []
	for index in clampi(end_index, 0, STEPS.size() - 1):
		result.append(str(STEPS[index].get("id", "")))
	return result


static func _all_action_step_ids() -> Array[String]:
	return _step_ids_before(STEPS.size() - 1)
