extends RefCounted
## What one player action did: whether it worked, whether it spent a daily
## action, which feedback line to show, and what the host must settle next.

var succeeded := false
var spent_action := false
var feedback_key := ""
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
