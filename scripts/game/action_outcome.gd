extends RefCounted
## What one valid interaction (a post, a finished conversation, a pickup) did: whether it counted, whether the
## pollution flashback is due, and whether the progress check that ran after it moved the floor.

var succeeded := false
var flashback := false
var floor_changed := false


## The narrative beat's settlement; empty when nothing needs to play.
func settlement() -> Dictionary:
	if not flashback:
		return {}
	return {"flashback": true}
