extends RefCounted
class_name NarrativeBeat
## One narrative beat. The host supplies a settlement result and whether the ending is unlocked.
## Segments stay in narrative; gameplay or ending is requested only when the beat exits.

var _segments: Array[String] = []
var _index := 0
var _finished := true
var _ending_unlocked := false
var _modes: Array[String] = []


func play(settlement: Dictionary, ending_unlocked: bool) -> void:
	_segments = _plan(settlement)
	_index = 0
	_finished = _segments.is_empty()
	_ending_unlocked = ending_unlocked
	_modes = []
	if _finished:
		return
	_modes.append("narrative")


func current_segment() -> String:
	if _finished or _index < 0 or _index >= _segments.size():
		return ""
	return _segments[_index]


func is_finished() -> bool:
	return _finished


func is_last_segment() -> bool:
	return not _finished and _segments.size() > 0 and _index == _segments.size() - 1


func note_ending_unlocked(unlocked: bool) -> void:
	if unlocked:
		_ending_unlocked = true


func advance() -> void:
	if _finished:
		return
	_index += 1
	if _index < _segments.size():
		return
	_finished = true
	_modes.append("ending" if _ending_unlocked else "gameplay")


func exit_mode() -> String:
	if not _finished or _modes.is_empty():
		return ""
	return str(_modes[_modes.size() - 1])


func mode_requests() -> Array:
	return _modes.duplicate()


func _plan(settlement: Dictionary) -> Array[String]:
	var plan: Array[String] = []
	if settlement.has("actions_before") and settlement.has("actions_after"):
		if int(settlement.get("actions_after", 0)) < int(settlement.get("actions_before", 0)):
			plan.append("action_spend")
	if bool(settlement.get("day_transition", false)):
		plan.append("day_transition")
	if bool(settlement.get("flashback", false)):
		plan.append("flashback")
	return plan
