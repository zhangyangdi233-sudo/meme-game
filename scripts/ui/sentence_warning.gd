class_name SentenceWarning
extends RefCounted
## What a composer shows of word pollution, read from the models: the polluted units of the current room, and the line
## above a post button that says this sentence would be void.

const ChapterOneProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const PollutionPolicyScript = preload("res://scripts/game/pollution_policy.gd")
const RoomContentScript = preload("res://scripts/game/room_content.gd")

const LINE := "这句话已被污染，发布后不会生效"


static func polluted_units(polluted: Dictionary, progress: Dictionary, locale_code: String) -> Array:
	return PollutionPolicyScript.polluted_units(polluted, locale_code, _room(progress), PollutionPolicyScript.settings())


static func add_to(parent: Control, units: Array, polluted: Dictionary, progress: Dictionary, locale_code: String, theme: GameUiTheme) -> void:
	if not PollutionPolicyScript.sentence_voids(units, locale_code, _room(progress), polluted, PollutionPolicyScript.settings()):
		return
	var warning := theme.label(LINE, 14, theme.theme_color("error")) as Label
	warning.name = "SentenceVoidWarning"
	theme.set_font_role(warning, "error")
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(warning)


static func _room(progress: Dictionary) -> Dictionary:
	return RoomContentScript.room(ChapterOneProgressScript.round_of(progress))
