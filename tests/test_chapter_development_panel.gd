extends SceneTree

var failures: Array[String] = []
var events: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "res://scripts/ui/chapter_development_panel.gd"
	if not FileAccess.file_exists(path):
		failures.append("chapter development panel must exist")
		_finish()
		return
	var script := load(path) as Script
	var panel = script.new()
	root.add_child(panel)
	panel.event_requested.connect(func(id: String, payload: Dictionary): events.append([id, payload]))
	panel.configure(false)
	_check(not panel.visible and panel.get_child_count() == 0, "normal startup has no developer controls")
	panel.configure(true)
	panel.show_progress({"phase": "opening", "round_index": 0, "transition_serial": 0, "narrator_completed": false})
	_check(events.is_empty(), "showing diagnostics must never complete narration")
	var title := panel.find_child("ChapterDevelopmentTitle", true, false) as Label
	_check(title != null and title.text.contains("DEVELOPMENT"), "development controls are explicitly labelled")
	var narration := panel.find_child("ChapterDevNarration", true, false) as Button
	var help := panel.find_child("ChapterDevHelp", true, false) as Button
	_check(narration != null and not narration.disabled, "only opening can request narrator completion")
	_check(help != null and help.disabled, "help unavailable before a basement actor is in range")
	narration.pressed.emit()
	_check(events.size() == 1 and events[0][0] == "narration_completed", "narrator button sends an event instead of moving the player")
	_check(events[0][1].get("sequence_id") == "chapter1_opening", "narrator event names the expected sequence")
	panel.show_progress({"phase": "basement", "round_index": 2, "transition_serial": 3, "entrance_locked": true})
	_check(narration.disabled and help.disabled, "basement controls still require actor proximity")
	panel.set_help_available(true)
	_check(not help.disabled, "explicit proximity permits a help request")
	help.pressed.emit()
	_check(events.size() == 2 and events[1][1].get("round_token") == 3, "help carries the current visit token")
	_check(events[1][1].get("task_id") == "basement_help_03" and events[1][1].get("npc_id") == "basement_npc_03", "help uses stable task and NPC IDs")
	panel.show_progress({"phase": "basement", "round_index": 3, "transition_serial": 4, "entrance_locked": false})
	_check(help.disabled, "changing visits clears stale actor availability")
	panel.configure(false)
	_check(not panel.visible, "developer controls can be disabled")
	narration.pressed.emit()
	help.pressed.emit()
	_check(events.size() == 2, "disabled panel callbacks cannot emit progress events")
	panel.queue_free()
	await process_frame
	_finish()


func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _finish() -> void:
	for message in failures:
		push_error(message)
	if failures.is_empty():
		print("chapter development panel tests passed")
	quit(0 if failures.is_empty() else 1)
