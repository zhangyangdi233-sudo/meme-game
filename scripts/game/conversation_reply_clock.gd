class_name ConversationReplyClock
extends RefCounted
## How long an NPC's reply stays on screen before a linear conversation moves on by itself: long enough to read it,
## counted from the writing itself so any language gets its time. A paused clock does not run.

## The least time any reply stays.
const MIN_SECONDS := 2.5

var _remaining := 0.0
var _running := false


static func reading_seconds(text: String) -> float:
	var east_asian_characters := 0
	var western_words := 0
	var inside_word := false
	for character in text:
		var code: int = character.unicode_at(0)
		var east_asian := (code >= 0x3040 and code <= 0x30ff) or (code >= 0x3400 and code <= 0x9fff) or (code >= 0xac00 and code <= 0xd7af)
		if east_asian:
			east_asian_characters += 1
			inside_word = false
		elif character.strip_edges().is_empty() or character in ",.!?:;，。！？：；、":
			inside_word = false
		elif not inside_word:
			western_words += 1
			inside_word = true
	return maxf(MIN_SECONDS, 1.0 + float(east_asian_characters) / 6.0 + float(western_words) / 3.0)


func begin(text: String) -> void:
	_remaining = reading_seconds(text)
	_running = true


func cancel() -> void:
	_running = false
	_remaining = 0.0


func is_running() -> bool:
	return _running


## Runs the clock; true once, on the step the reply's time runs out.
func advance(delta: float, paused: bool) -> bool:
	if not _running or paused:
		return false
	_remaining -= maxf(0.0, delta)
	if _remaining > 0.0:
		return false
	_running = false
	return true
