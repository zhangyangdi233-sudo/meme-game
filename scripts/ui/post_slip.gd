class_name PostSlip
extends RefCounted
## The slip under a post button: the player's last post, red when the world obeyed it and green when it did not. A
## filled or hollow mark says the same without the color.

const TIER_RULE := "rule"


## The newest sentence post among `published` (newest first), or empty.
static func latest(published: Array) -> Dictionary:
	for record in published:
		if record is Dictionary and str(record.get("kind", "")) == "free_sentence":
			return record
	return {}


static func add_to(parent: Control, post: Dictionary, theme: GameUiTheme) -> void:
	if post.is_empty():
		return
	var is_red := str(post.get("tier", "")) == TIER_RULE
	var text := "%s %s" % ["■" if is_red else "□", post.get("text", "")]
	var slip := theme.label(text, 15, theme.theme_color("error" if is_red else "accent")) as Label
	slip.name = "LastPostSlip"
	slip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slip.set_meta("skip_localization", true)
	parent.add_child(slip)
