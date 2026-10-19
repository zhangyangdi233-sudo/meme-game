extends Node

# Explicit frame time avoids deferred callbacks from an earlier conversation.
var pending := false
var remaining_seconds := 0.0
var reply_finished := false
var ready_to_close := false


func begin_reply(text: String) -> void:
	remaining_seconds = reading_seconds(text)
	pending = true
	reply_finished = false
	ready_to_close = false


func cancel() -> void:
	pending = false
	remaining_seconds = 0.0
	reply_finished = false
	ready_to_close = false


func advance(delta: float, paused: bool) -> bool:
	if not pending or paused:
		return false
	remaining_seconds = maxf(0.0, remaining_seconds - maxf(0.0, delta))
	if remaining_seconds > 0.0:
		return false
	pending = false
	reply_finished = true
	return true


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
	# Count the visible writing rather than locale, so mixed-language lines also
	# receive reading time. No upper cap truncates a long authored response.
	return maxf(0.6, 0.2 + float(east_asian_characters) / 18.0 + float(western_words) / 5.0)
