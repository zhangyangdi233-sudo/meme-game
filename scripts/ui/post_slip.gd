class_name PostSlip
extends RefCounted
## The slip under a post button: the player's last post, red when the world obeyed it and green when it did not. A
## filled or hollow mark says the same without the color.

const ChapterOneProgressScript = preload("res://scripts/game/chapter_one_progress.gd")

const TIER_RULE := "rule"


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
