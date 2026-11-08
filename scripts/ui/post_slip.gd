class_name PostSlip
extends RefCounted
## The slip under a post button: the player's last post, red when the world obeyed it and green when it did not. A
## filled or hollow mark says the same without the color. Under a green slip a line says to try again, and why when
## pollution voided the sentence (#125).

const ChapterOneProgressScript = preload("res://scripts/game/chapter_one_progress.gd")

const TIER_RULE := "rule"
## Under a green post: nothing answered it.
const MISSED_LINE := "没有东西回应它。换一种说法，再试一次。"
## Under a post pollution voided: its polluted subject cannot move anything any more.
const VOIDED_LINE := "被污染的字说不动它了。换一样东西，再试一次。"


## The newest sentence post of this basement round among `published` (newest first), or empty. A new round's room
## starts over, so an earlier round's post no longer shows. Outside the basement the round is zero.
static func latest(published: Array, progress: Dictionary) -> Dictionary:
	var current_round := ChapterOneProgressScript.round_of(progress)
	for record in published:
		if record is Dictionary and str(record.get("kind", "")) == "free_sentence" and int(record.get("round", 0)) == current_round:
			return record
	return {}


static func add_to(parent: Control, post: Dictionary, theme: GameUiTheme) -> void:
	if post.is_empty():
		return
	var is_red := str(post.get("tier", "")) == TIER_RULE
	var text := "%s %s" % ["■" if is_red else "□", post.get("shown_text", post.get("text", ""))]
	var slip := theme.label(text, 15, theme.theme_color("ink")) as Label
	slip.name = "LastPostSlip"
	theme.set_font_role(slip, "error" if is_red else "accent")
	slip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slip.set_meta("skip_localization", true)
	parent.add_child(slip)
	if is_red:
		return
	var hint := theme.label(VOIDED_LINE if bool(post.get("voided", false)) else MISSED_LINE, 13, theme.theme_color("muted")) as Label
	hint.name = "PostRetryHint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(hint)
