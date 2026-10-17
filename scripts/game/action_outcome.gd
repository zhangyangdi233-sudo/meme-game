extends RefCounted
## What one player action did: whether it worked, whether it spent a daily
## action, which feedback line to show, and what the host must settle next.

const PUBLISH_DONE := "publish_done"
const PUBLISH_EMPTY := "publish_empty"
const PUBLISH_NO_ACTION := "publish_no_action"
const FUSION_DONE := "fusion_done"
const FUSION_REJECTED := "fusion_rejected"

var succeeded := false
var spent_action := false
var feedback_key := ""
## Text filled into the feedback line, such as the fused meme's title.
var feedback_detail := ""
## The meme the host selects after a success; empty clears the selection.
var selected_meme_id := ""
var flashback := false
var day_transition := false
var actions_before := 0
var actions_after := 0


## The narrative beat's settlement; empty when nothing needs to play.
func settlement() -> Dictionary:
	if not spent_action and not flashback:
		return {}
	var result := {
		"day_transition": day_transition,
		"flashback": flashback,
	}
	if spent_action:
		result["actions_before"] = actions_before
		result["actions_after"] = actions_after
	return result
